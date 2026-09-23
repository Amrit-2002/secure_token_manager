import '../core/models/token_data.dart';

/// Contract defining persistence operations for [TokenData].
///
/// Implementations must store, retrieve, and clear authentication tokens
/// securely according to the platform's security mechanisms.
abstract interface class TokenStorage {
  /// Securely persists [tokens].
  ///
  /// Must execute atomically so that access token and refresh token updates
  /// cannot be partially written.
  /// Throws [TokenStorageException] if the operation fails.
  Future<void> save(TokenData tokens);

  /// Reads and returns the currently stored [TokenData], or null if none is stored.
  ///
  /// Throws [TokenStorageException] if storage cannot be read.
  Future<TokenData?> read();

  /// Removes all stored tokens from persistence.
  ///
  /// Throws [TokenStorageException] if the clear operation fails.
  Future<void> clear();
}
