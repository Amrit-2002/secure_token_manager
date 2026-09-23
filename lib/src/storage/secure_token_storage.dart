import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/errors/token_exceptions.dart';
import '../core/models/token_data.dart';
import 'token_storage.dart';

/// Platform-aware secure implementation of [TokenStorage].
///
/// Uses native hardware-backed or OS-level encrypted storage:
/// - **Android**: Android KeyStore with AES-GCM data encryption and RSA-OAEP key wrapping.
/// - **iOS / macOS**: Apple Keychain Services with `first_unlock` accessibility.
/// - **Windows**: Windows Data Protection API (DPAPI) via Windows Credential Store.
/// - **Linux**: Secret Service API via `libsecret`.
///
/// Platform Support:
/// - Supported in v1: Android, iOS, macOS, Windows, Linux.
/// - Unsupported in v1: **Web**. Web browsers do not provide hardware-backed
///   isolated credential storage equivalent to Keychain/Keystore. Using
///   insecure `localStorage` or `sessionStorage` fallback is strictly disallowed.
///   Attempting to use [SecureTokenStorage] in a web environment throws
///   [PlatformNotSupportedException].
class SecureTokenStorage implements TokenStorage {
  /// Creates a [SecureTokenStorage] instance.
  ///
  /// [namespace] partitions storage keys, preventing collisions between apps or accounts.
  /// [storageKey] defines the base storage key within the partition.
  /// [storage] allows injecting a custom [FlutterSecureStorage] instance for testing.
  SecureTokenStorage({
    this.namespace = 'secure_token_manager',
    this.storageKey = 'auth_tokens',
    FlutterSecureStorage? storage,
    AndroidOptions? androidOptions,
    IOSOptions? iosOptions,
    MacOsOptions? macOsOptions,
    LinuxOptions? linuxOptions,
    WindowsOptions? windowsOptions,
  }) : _storage = storage ??
            FlutterSecureStorage(
              aOptions: androidOptions ?? const AndroidOptions(),
              iOptions: iosOptions ??
                  const IOSOptions(
                    accessibility: KeychainAccessibility.first_unlock,
                  ),
              mOptions: macOsOptions ??
                  const MacOsOptions(
                    accessibility: KeychainAccessibility.first_unlock,
                  ),
              lOptions: linuxOptions ?? const LinuxOptions(),
              wOptions: windowsOptions ?? const WindowsOptions(),
            );

  /// Key prefix / namespace to isolate credentials.
  final String namespace;

  /// Identifier for the token payload entry.
  final String storageKey;

  final FlutterSecureStorage _storage;

  /// The fully-qualified storage key.
  String get qualifiedKey => '$namespace.$storageKey';

  void _assertPlatformSupported() {
    if (kIsWeb) {
      throw const PlatformNotSupportedException(
        'SecureTokenStorage is not supported on Flutter Web in v1. '
        'Web browsers lack native hardware-backed isolated credential vaults. '
        'Using insecure localStorage/sessionStorage as a fallback is prohibited for security. '
        'Use an in-memory session or provide a custom TokenStorage implementation with explicit '
        'trade-off acknowledgments.',
      );
    }
  }

  @override
  Future<void> save(TokenData tokens) async {
    _assertPlatformSupported();
    try {
      final jsonPayload = jsonEncode(tokens.toJson());
      await _storage.write(
        key: qualifiedKey,
        value: jsonPayload,
      );
    } on PlatformNotSupportedException {
      rethrow;
    } catch (e, st) {
      throw TokenStorageException(
        'Failed to securely persist authentication tokens.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<TokenData?> read() async {
    _assertPlatformSupported();
    try {
      final rawJson = await _storage.read(key: qualifiedKey);
      if (rawJson == null || rawJson.trim().isEmpty) {
        return null;
      }

      final decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
            'Decoded token payload is not a JSON object.');
      }
      return TokenData.fromJson(decoded);
    } on PlatformNotSupportedException {
      rethrow;
    } catch (e, st) {
      throw TokenStorageException(
        'Failed to read authentication tokens from secure storage.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> clear() async {
    _assertPlatformSupported();
    try {
      await _storage.delete(key: qualifiedKey);
    } on PlatformNotSupportedException {
      rethrow;
    } catch (e, st) {
      throw TokenStorageException(
        'Failed to clear authentication tokens from secure storage.',
        cause: e,
        stackTrace: st,
      );
    }
  }
}
