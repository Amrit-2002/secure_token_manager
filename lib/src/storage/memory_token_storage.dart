import '../core/models/token_data.dart';
import 'token_storage.dart';

/// An in-memory, non-persistent implementation of [TokenStorage].
///
/// **WARNING**: This storage does **not** persist across app restarts and does
/// **not** encrypt tokens in memory. It is intended solely for unit testing,
/// mocked environments, and fast headless development.
class MemoryTokenStorage implements TokenStorage {
  /// Creates a [MemoryTokenStorage] with an optional [initialTokens].
  MemoryTokenStorage({TokenData? initialTokens, this.namespace = 'default'})
      : _tokens = initialTokens;

  /// Optional storage namespace or account partition.
  final String namespace;

  TokenData? _tokens;

  @override
  Future<void> save(TokenData tokens) async {
    // Retain immutable copy
    _tokens = tokens.copyWith();
  }

  @override
  Future<TokenData?> read() async {
    return _tokens?.copyWith();
  }

  @override
  Future<void> clear() async {
    _tokens = null;
  }

  /// Whether a token is currently stored in this in-memory instance.
  bool get hasTokens => _tokens != null;
}
