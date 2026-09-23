import 'package:flutter_test/flutter_test.dart';
import 'package:secure_token_manager/secure_token_manager.dart';
import '../helpers/failing_token_storage.dart';
import '../helpers/fake_clock.dart';

void main() {
  group('TokenManager Lifecycle & Storage Edge Cases', () {
    late FakeClock clock;
    final now = DateTime.utc(2026, 1, 1, 12, 0, 0);

    setUp(() {
      clock = FakeClock(now);
    });

    test(
        'storage failure during setTokens preserves memory integrity and throws',
        () async {
      final failingStorage = FailingTokenStorage(shouldFailSave: true);
      final manager = TokenManager(
        storage: failingStorage,
        refreshToken: (r) async => TokenData(accessToken: 'new'),
      );

      final tokens = TokenData(accessToken: 'some_access');

      await expectLater(
        () => manager.setTokens(tokens),
        throwsA(isA<TokenStorageException>()),
      );

      expect(manager.currentTokens, isNull);
    });

    test('storage failure during initialize sets AuthStateError and throws',
        () async {
      final failingStorage = FailingTokenStorage(shouldFailRead: true);
      final manager = TokenManager(
        storage: failingStorage,
        refreshToken: (r) async => TokenData(accessToken: 'new'),
      );

      await expectLater(
        manager.initialize(),
        throwsA(isA<TokenStorageException>()),
      );

      expect(manager.currentAuthState, isA<AuthStateError>());
    });

    test('proactively refreshes token within clock skew leeway window',
        () async {
      var refreshCount = 0;
      final memoryStorage = MemoryTokenStorage();

      final manager = TokenManager(
        storage: memoryStorage,
        options: TokenManagerOptions(
          clock: clock,
          clockSkewLeeway: const Duration(seconds: 60),
        ),
        refreshToken: (refreshToken) async {
          refreshCount++;
          return TokenData(
            accessToken: 'refreshed_access_leeway',
            refreshToken: 'refreshed_refresh_leeway',
            expiresAt: clock.now.add(const Duration(hours: 1)),
          );
        },
      );

      // Token expires in 45 seconds (which is less than the 60 second leeway window)
      await manager.setTokens(
        TokenData(
          accessToken: 'about_to_expire',
          refreshToken: 'refresh_tok',
          expiresAt: now.add(const Duration(seconds: 45)),
        ),
      );

      // Retrieval should proactively trigger refresh due to leeway
      final token = await manager.getValidAccessToken();

      expect(refreshCount, 1);
      expect(token, 'refreshed_access_leeway');
    });

    test(
        'supports token rotation when refresh response provides new refresh token',
        () async {
      final memoryStorage = MemoryTokenStorage();

      final manager = TokenManager(
        storage: memoryStorage,
        options: TokenManagerOptions(clock: clock),
        refreshToken: (oldRefreshToken) async {
          expect(oldRefreshToken, 'initial_refresh');
          return TokenData(
            accessToken: 'second_access',
            refreshToken: 'rotated_refresh_token',
            expiresAt: clock.now.add(const Duration(hours: 1)),
          );
        },
      );

      await manager.setTokens(
        TokenData(
          accessToken: 'first_access',
          refreshToken: 'initial_refresh',
          expiresAt: now.subtract(const Duration(seconds: 1)),
        ),
      );

      await manager.getValidAccessToken();

      expect(manager.currentTokens?.accessToken, 'second_access');
      expect(manager.currentTokens?.refreshToken, 'rotated_refresh_token');

      // Verify persisted in storage
      final stored = await memoryStorage.read();
      expect(stored?.refreshToken, 'rotated_refresh_token');
    });

    test('custom isAuthInvalidatingError decider classifies errors accurately',
        () async {
      final memoryStorage = MemoryTokenStorage();

      final manager = TokenManager(
        storage: memoryStorage,
        options: TokenManagerOptions(
          clock: clock,
          isAuthInvalidatingError: (error, st) {
            return error is CustomHttpException && error.statusCode == 401;
          },
        ),
        refreshToken: (_) async {
          throw const CustomHttpException(401, 'Unauthorized');
        },
      );

      await manager.setTokens(
        TokenData(
          accessToken: 'expired',
          refreshToken: 'refresh_tok',
          expiresAt: now.subtract(const Duration(seconds: 1)),
        ),
      );

      await expectLater(
        manager.getValidAccessToken(),
        throwsA(isA<TokenRefreshRejectedException>()),
      );

      // Session should be cleared
      expect(
          manager.currentAuthState, equals(const AuthStateUnauthenticated()));
      expect(manager.currentTokens, isNull);
    });
  });
}

class CustomHttpException implements Exception {
  const CustomHttpException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  @override
  String toString() => 'CustomHttpException($statusCode, $message)';
}
