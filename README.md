# secure_token_manager

[![pub package](https://img.shields.io/pub/v/secure_token_manager.svg)](https://pub.dev/packages/secure_token_manager)
[![CI](https://github.com/Amrit-2002/secure_token_manager/actions/workflows/ci.yml/badge.svg)](https://github.com/Amrit-2002/secure_token_manager/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A production-grade, platform-aware authentication token lifecycle manager for Flutter applications with single-flight concurrent refresh protection, race condition immunity, and zero coupling to any networking client.

<p align="center">
  <img src="https://raw.githubusercontent.com/Amrit-2002/secure_token_manager/main/doc/images/demo_app_preview.jpg" alt="Secure Token Manager Interactive Demo App" width="850"/>
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/Amrit-2002/secure_token_manager/main/doc/images/concurrency_diagram.jpg" alt="Single-Flight Concurrency Architecture" width="850"/>
</p>

---

## 1. Problem Statement

Flutter applications communicating with authenticated REST/GraphQL APIs commonly face the following challenges:

1. **Insecure storage**: Storing credentials in plaintext `SharedPreferences` or `localStorage`.
2. **Duplicated refresh logic**: Re-implementing token refresh in every HTTP interceptor or service.
3. **Thundering herd (concurrent API calls)**: When 5 or 10 parallel API requests fail with 401s simultaneously, applications mistakenly launch 5 or 10 concurrent refresh calls to the backend, causing rate-limiting, invalidated sessions, or server errors.
4. **Race conditions during logout**: If a refresh request is in flight when the user taps "Logout", the late refresh response often arrives and erroneously writes the new tokens back to storage, resurrecting a logged-out session.
5. **Loss of state on restart**: Inconsistent hydration between secure hardware storage and memory.
6. **Tight HTTP client coupling**: Forcing the authentication state to be coupled directly to Dio, Chopper, or package:http.
7. **Platform inconsistencies**: Handling Android Keystore, iOS/macOS Keychain, Windows DPAPI, and Linux Secret Service manually.
8. **Untestable expiration logic**: Hardcoding `DateTime.now()` making it difficult to write deterministic unit tests.

`secure_token_manager` solves these problems through clean architecture, single-flight concurrency coalescing, session epoch guards, and platform-native secure storage.

---

## 2. Features

- **Single-Flight Concurrency Protection**: Deduplicates multiple simultaneous refresh requests into a single network execution, sharing the result across all waiting callers.
- **Race Condition Immunity**: Uses a monotonically increasing session epoch to guarantee that stale in-flight refresh responses can never revive a logged-out or invalidated session.
- **Hardware-Backed Platform Storage**: Uses AES-GCM via Android KeyStore, Apple Keychain with `first_unlock` accessibility, Windows DPAPI Credential Store, and Linux `libsecret`.
- **Zero Plaintext Fallback**: Never falls back to insecure storage. Explicitly rejects Flutter Web in v1 to avoid false security promises with `localStorage`.
- **Clock-Skew Leeway**: Proactively refreshes tokens slightly ahead of actual expiration (default: 60s), preventing in-flight API requests from failing at the boundary.
- **Secret Redaction**: `TokenData.toString()`, error messages, and log records strictly redact tokens and secrets.
- **Zero Network Coupling**: Works seamlessly with Dio, `package:http`, GraphQL, gRPC, or custom WebSocket layers.
- **Deterministic Testing**: Fully testable using injected `Clock` and `MemoryTokenStorage`.
- **Observable Lifecycle**: Exposes a reactive `Stream<AuthState>` and token-safe `Stream<AuthEvent>`.

---

## 3. Supported Platforms Matrix

| Platform | Supported in v1 | Underlying Mechanism |
| :--- | :---: | :--- |
| **Android** | ✅ Yes | Android KeyStore with AES-GCM data encryption and RSA-OAEP key wrapping |
| **iOS** | ✅ Yes | Apple Keychain Services (`KeychainAccessibility.first_unlock`) |
| **macOS** | ✅ Yes | Apple Keychain Services (`KeychainAccessibility.first_unlock`) |
| **Windows** | ✅ Yes | Windows Data Protection API (DPAPI) via Credential Manager |
| **Linux** | ✅ Yes | Secret Service API (`libsecret`) |
| **Web** | ❌ No | Web browsers lack hardware-backed credential vaults. Using `localStorage` is vulnerable to XSS and strictly disallowed in v1. |

---

## 4. Installation

Add `secure_token_manager` to your `pubspec.yaml`:

```yaml
dependencies:
  secure_token_manager: ^0.1.0
```

Then run:

```bash
flutter pub get
```

---

## 5. Quick Start

```dart
import 'package:secure_token_manager/secure_token_manager.dart';

void main() async {
  // 1. Instantiate TokenManager with your backend's refresh callback
  final tokenManager = TokenManager(
    storage: SecureTokenStorage(), // Platform secure storage
    refreshToken: (String currentRefreshToken) async {
      // Execute your application-specific HTTP call
      final response = await myAuthApi.refreshToken(currentRefreshToken);

      return TokenData(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken, // Supports token rotation
        expiresAt: response.expiresAt,
      );
    },
  );

  // 2. Initialize from secure storage on app launch
  await tokenManager.initialize();

  // 3. Set tokens when the user logs in
  await tokenManager.setTokens(
    TokenData(
      accessToken: 'initial_access_token',
      refreshToken: 'initial_refresh_token',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    ),
  );

  // 4. Retrieve a valid access token for outgoing API calls
  // (Automatically refreshes single-flight if expired or expiring soon)
  final accessToken = await tokenManager.getValidAccessToken();

  // 5. Observe authentication state changes
  tokenManager.authState.listen((AuthState state) {
    if (state.isUnauthenticated) {
      navigateToLoginScreen();
    }
  });

  // 6. Log out
  await tokenManager.logout();
}
```

---

## 6. Architecture & Concurrency Model

<p align="center">
  <img src="https://raw.githubusercontent.com/Amrit-2002/secure_token_manager/main/doc/images/concurrency_diagram.jpg" alt="Single-Flight Concurrency Architecture" width="850"/>
</p>

### Single-Flight Refresh Coalescing

When multiple asynchronous requests require an access token at the same time:

```text
Request 1 (expired) ──┐
Request 2 (expired) ──┼──> [ Single-Flight Refresh Coordinator ] ──> ONE Backend Refresh Call
Request 3 (expired) ──┘                  │
                                         ▼
                                New Token Pair Saved
                                         │
                        ┌────────────────┼────────────────┐
                        ▼                ▼                ▼
                    Request 1        Request 2        Request 3
```

All callers await the exact same internal `Completer<TokenData>`. If the refresh succeeds, all callers receive the new token. If it fails, all callers receive the typed exception.

### Logout Race Condition Guard

```text
Time 0ms:   Token expired -> Refresh initiated (Epoch 1)
Time 150ms: User clicks "Logout" -> Storage cleared, Memory wiped, Epoch incremented to 2
Time 500ms: Refresh HTTP response arrives with new tokens
Result:     Coordinator checks epoch (1 != 2) -> Discards new tokens immediately!
            Storage and Memory remain empty. The session remains logged out.
```

---

## 7. Dio Integration Recipe

The core package does not depend on Dio. You can easily integrate it into your Dio client using an interceptor:

```dart
import 'package:dio/dio.dart';
import 'package:secure_token_manager/secure_token_manager.dart';

class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor(this._tokenManager, this._dio);

  final TokenManager _tokenManager;
  final Dio _dio;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await _tokenManager.getValidAccessToken();
      options.headers['Authorization'] = 'Bearer $token';
      handler.next(options);
    } on TokenException catch (e) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: e,
          type: DioExceptionType.cancel,
        ),
      );
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Handle unexpected 401 (e.g. token revoked prematurely on server)
    if (err.response?.statusCode == 401 && err.requestOptions.extra['retry'] != true) {
      try {
        // Trigger single-flight refresh
        await _tokenManager.refreshTokens();

        // Retry the original request once
        final retryOptions = err.requestOptions;
        retryOptions.extra['retry'] = true;
        final token = await _tokenManager.getValidAccessToken();
        retryOptions.headers['Authorization'] = 'Bearer $token';

        final response = await _dio.fetch(retryOptions);
        return handler.resolve(response);
      } catch (_) {
        // If refresh fails or is rejected, let original error propagate
      }
    }
    handler.next(err);
  }
}
```

---

## 8. HTTP Client (`package:http`) Integration Recipe

```dart
import 'package:http/http.dart' as http;
import 'package:secure_token_manager/secure_token_manager.dart';

class AuthenticatedHttpClient extends http.BaseClient {
  AuthenticatedHttpClient(this._inner, this._tokenManager);

  final http.Client _inner;
  final TokenManager _tokenManager;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final token = await _tokenManager.getValidAccessToken();
    request.headers['Authorization'] = 'Bearer $token';
    return _inner.send(request);
  }
}
```

---

## 9. Error Taxonomy

All exceptions extend the sealed class `TokenException`:

- `TokenStorageException`: Failure in underlying storage (e.g. disk or platform vault error).
- `PlatformNotSupportedException`: Attempting to use `SecureTokenStorage` on unsupported platforms (e.g. Flutter Web in v1).
- `TokenNotFoundException`: When requesting a token but no session exists.
- `TokenExpiredException`: Token expired and no refresh token is available to renew it.
- `TokenRefreshTransientException`: Temporary failure (network failure, timeout, 5xx server error). **Credentials are preserved.**
- `TokenRefreshRejectedException`: Authentication-invalidating failure (401/403, revoked session, invalid grant). **Credentials are cleared automatically.**
- `TokenInitializationException`: Raised when initialization fails.
- `AuthenticationRequiredException`: Attempting an action requiring an authenticated user when unauthenticated or logged out.

---

## 10. Security Considerations & Realistic Guarantees

1. **No Plaintext Fallback**: `SecureTokenStorage` uses platform-native hardware keystores. If a platform cannot securely store credentials, an explicit exception is thrown.
2. **Secrets Redaction**: `TokenData.toString()` prints `TokenData(accessToken: [REDACTED], refreshToken: [REDACTED], ...)`. Tokens never appear in logs or exceptions.
3. **Memory Security in Dart**: Dart strings are managed by the Dart VM garbage collector. Like virtually all managed runtimes (Java, Swift, JavaScript), Dart does not provide a guaranteed mechanism to wipe arbitrary strings from memory immediately. This package minimizes memory residency and avoids unnecessary copying or string conversions.
4. **Transport Security (HTTPS)**: Client-side storage cannot compensate for unencrypted network traffic. All authentication endpoints must use HTTPS with valid TLS certificates.
5. **Backend Refresh Rotation**: It is strongly recommended that your backend issues a new refresh token on every refresh invocation (refresh token rotation) and revokes old refresh tokens.

---

## 11. Testing & Mocking

Use `MemoryTokenStorage` and `FakeClock` to write deterministic tests without delays:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_token_manager/secure_token_manager.dart';

void main() {
  test('refreshes token deterministically', () async {
    final storage = MemoryTokenStorage();
    final manager = TokenManager(
      storage: storage,
      refreshToken: (r) async => TokenData(accessToken: 'new_token'),
    );

    await manager.setTokens(TokenData(accessToken: 'old_token'));
    expect(await manager.getValidAccessToken(), 'old_token');
  });
}
```

---

## 12. Roadmap

- **v1.x**:
  - Optional biometric challenge integration for high-security applications.
  - Storage key migration helpers.
- **v2.0**:
  - Web platform support with explicit security boundaries and Web Crypto API.
  - Multi-account / multi-tenant concurrent session manager.

---

## 13. Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on code style, analyzer rules, and running tests.

---

## 14. License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

