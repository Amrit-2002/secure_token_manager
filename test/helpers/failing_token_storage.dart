import 'package:secure_token_manager/secure_token_manager.dart';

/// A [TokenStorage] implementation that can be configured to fail on demand
/// to test error handling and edge cases.
class FailingTokenStorage implements TokenStorage {
  /// Creates a [FailingTokenStorage].
  FailingTokenStorage({
    this.shouldFailRead = false,
    this.shouldFailSave = false,
    this.shouldFailClear = false,
    TokenData? initialTokens,
  }) : _tokens = initialTokens;

  bool shouldFailRead;
  bool shouldFailSave;
  bool shouldFailClear;

  TokenData? _tokens;
  int readCount = 0;
  int saveCount = 0;
  int clearCount = 0;

  @override
  Future<TokenData?> read() async {
    readCount++;
    if (shouldFailRead) {
      throw const TokenStorageException('Simulated storage read failure');
    }
    return _tokens?.copyWith();
  }

  @override
  Future<void> save(TokenData tokens) async {
    saveCount++;
    if (shouldFailSave) {
      throw const TokenStorageException('Simulated storage save failure');
    }
    _tokens = tokens.copyWith();
  }

  @override
  Future<void> clear() async {
    clearCount++;
    if (shouldFailClear) {
      throw const TokenStorageException('Simulated storage clear failure');
    }
    _tokens = null;
  }
}
