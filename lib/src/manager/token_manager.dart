import 'dart:async';
import '../core/errors/token_exceptions.dart';
import '../core/logging/token_logger.dart';
import '../core/models/token_data.dart';
import '../refresh/refresh_coordinator.dart';
import '../state/auth_event.dart';
import '../state/auth_state.dart';
import '../storage/secure_token_storage.dart';
import '../storage/token_storage.dart';
import 'token_manager_options.dart';

/// Central coordinator for authentication token lifecycle management in Flutter.
///
/// Features:
/// - Single-flight concurrent refresh deduplication.
/// - Epoch-based race condition protection (e.g. logout during in-flight refresh).
/// - Platform-aware secure persistence abstraction.
/// - Atomic storage writes with memory caching.
/// - Clock-skew leeway and proactive expiration detection.
/// - Observable [authState] and [events] streams with zero secret exposure.
class TokenManager {
  /// Creates a [TokenManager].
  ///
  /// [refreshToken]: The asynchronous callback responsible for contacting your
  /// backend API to exchange a refresh token for a new [TokenData] pair.
  /// [storage]: Persistence adapter. Defaults to [SecureTokenStorage].
  /// [options]: Configuration parameters for clock-skew, timeouts, and logging.
  TokenManager({
    required RefreshTokenCallback refreshToken,
    TokenStorage? storage,
    TokenManagerOptions options = const TokenManagerOptions(),
  })  : _storage = storage ?? SecureTokenStorage(),
        _options = options {
    _refreshCoordinator = RefreshCoordinator(
      onRefresh: refreshToken,
      isAuthInvalidating: options.isAuthInvalidatingError,
      refreshTimeout: options.refreshTimeout,
      logger: options.logger,
    );
  }

  final TokenStorage _storage;
  final TokenManagerOptions _options;
  late final RefreshCoordinator _refreshCoordinator;

  final StreamController<AuthState> _authStateController =
      StreamController<AuthState>.broadcast();
  final StreamController<AuthEvent> _eventsController =
      StreamController<AuthEvent>.broadcast();

  TokenData? _tokens;
  AuthState _currentAuthState = const AuthStateUnknown();
  Completer<void>? _initCompleter;
  int _sessionEpoch = 0;
  bool _isDisposed = false;

  /// The currently cached [TokenData], or null if unauthenticated.
  TokenData? get currentTokens => _tokens?.copyWith();

  /// Synchronous snapshot of the current [AuthState].
  AuthState get currentAuthState => _currentAuthState;

  /// Observable broadcast stream of authentication state transitions.
  ///
  /// Does not expose raw token strings.
  Stream<AuthState> get authState => _authStateController.stream;

  /// Observable broadcast stream of non-sensitive diagnostic/lifecycle events.
  Stream<AuthEvent> get events => _eventsController.stream;

  /// Whether [initialize] has successfully finished executing.
  bool get isInitialized =>
      _initCompleter != null && _initCompleter!.isCompleted;

  /// Initializes the token manager by reading credentials from secure persistence.
  ///
  /// Safe to call multiple times; concurrent or repeated calls return the same [Future].
  Future<void> initialize() {
    if (_isDisposed) {
      return Future.error(
        const TokenInitializationException(
          'Cannot initialize a disposed TokenManager instance.',
        ),
      );
    }

    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    final completer = Completer<void>();
    _initCompleter = completer;

    _options.logger.log(
      'Initializing TokenManager session from storage.',
      level: TokenLogLevel.info,
    );

    _executeInitialize(completer);
    return completer.future;
  }

  Future<void> _executeInitialize(Completer<void> completer) async {
    try {
      final loadedTokens = await _storage.read();
      if (loadedTokens != null) {
        _tokens = loadedTokens;
        _updateAuthState(
          AuthStateAuthenticated(
            expiresAt: loadedTokens.expiresAt,
            tokenType: loadedTokens.tokenType,
          ),
        );
        _options.logger.log(
          'Initialized session: active credentials restored.',
          level: TokenLogLevel.info,
        );
      } else {
        _tokens = null;
        _updateAuthState(const AuthStateUnauthenticated());
        _options.logger.log(
          'Initialized session: no credentials found.',
          level: TokenLogLevel.info,
        );
      }
      completer.complete();
    } catch (e, st) {
      final TokenException exception = e is TokenException
          ? e
          : TokenInitializationException(
              'Failed to read storage during TokenManager initialization.',
              cause: e,
              stackTrace: st,
            );
      _updateAuthState(AuthStateError(exception));
      _options.logger.log(
        'Initialization failed: ${exception.message}',
        level: TokenLogLevel.error,
        error: e,
        stackTrace: st,
      );
      _initCompleter = null;
      completer.completeError(exception, st);
    }
  }

  Future<void> _ensureInitialized() async {
    if (!isInitialized) {
      await initialize();
    }
  }

  /// Sets new authentication tokens (e.g. after a user successfully logs in).
  ///
  /// This operation:
  /// 1. Persists [tokens] to secure storage.
  /// 2. Updates the in-memory cache upon persistence success.
  /// 3. Emits [AuthStateAuthenticated] and [TokensUpdatedEvent].
  ///
  /// If storage persistence fails, in-memory state is preserved and
  /// [TokenStorageException] is thrown.
  Future<TokenData> setTokens(TokenData tokens) async {
    _checkDisposed();
    await _ensureInitialized();

    _options.logger.log(
      'Persisting new authentication tokens.',
      level: TokenLogLevel.debug,
    );

    // Atomic storage write first
    await _storage.save(tokens);

    // Update in-memory state only after successful write
    _tokens = tokens;
    _updateAuthState(
      AuthStateAuthenticated(
        expiresAt: tokens.expiresAt,
        tokenType: tokens.tokenType,
      ),
    );
    _emitEvent(TokensUpdatedEvent(expiresAt: tokens.expiresAt));

    return tokens;
  }

  /// Returns a valid access token for authorizing outgoing API requests.
  ///
  /// Lifecycle:
  /// 1. Ensures the manager is initialized.
  /// 2. Validates whether the current access token is valid or expiring soon
  ///    (using [TokenManagerOptions.clockSkewLeeway]).
  /// 3. If valid, returns the access token immediately.
  /// 4. If expired or expiring soon, automatically executes a single-flight refresh
  ///    (if [TokenManagerOptions.autoRefreshOnAccess] is enabled) and returns
  ///    the newly refreshed token.
  ///
  /// Throws [TokenNotFoundException] if no tokens are stored,
  /// or [TokenException] if refresh fails.
  Future<String> getValidAccessToken() async {
    _checkDisposed();
    await _ensureInitialized();

    final current = _tokens;
    if (current == null) {
      throw const TokenNotFoundException();
    }

    final isExpired = current.isExpired(
      clock: _options.clock,
      leeway: _options.clockSkewLeeway,
    );

    if (!isExpired) {
      return current.accessToken;
    }

    if (!_options.autoRefreshOnAccess) {
      throw const TokenExpiredException(
        'Access token is expired and autoRefreshOnAccess is disabled.',
      );
    }

    _options.logger.log(
      'Access token is expired or within clock-skew leeway. Triggering refresh.',
      level: TokenLogLevel.info,
    );

    final refreshed = await refreshTokens();
    return refreshed.accessToken;
  }

  /// Proactively refreshes the current token pair using single-flight protection.
  ///
  /// Concurrent callers await the same underlying refresh callback execution.
  /// If [logout] is called while refresh is in flight, the refreshed token is
  /// safely discarded.
  Future<TokenData> refreshTokens() async {
    _checkDisposed();
    await _ensureInitialized();

    final current = _tokens;
    if (current == null) {
      throw const TokenNotFoundException(
        'Cannot refresh tokens: No active session is present.',
      );
    }

    final refreshToken = current.refreshToken;
    if (refreshToken == null || refreshToken.trim().isEmpty) {
      throw const TokenExpiredException(
        'Cannot refresh tokens: No refresh token is available in current session.',
      );
    }

    final activeEpoch = _sessionEpoch;
    _updateAuthState(
      AuthStateRefreshing(
        previousExpiresAt: current.expiresAt,
        tokenType: current.tokenType,
      ),
    );
    _emitEvent(const RefreshStartedEvent());

    try {
      final refreshed = await _refreshCoordinator.refresh(
        currentTokens: current,
        sessionEpoch: activeEpoch,
      );

      // Check for logout race condition
      if (_sessionEpoch != activeEpoch) {
        throw const AuthenticationRequiredException(
          'Session was logged out while token refresh was completing.',
        );
      }

      // Atomically persist to storage
      await _storage.save(refreshed);

      // Update in-memory state
      _tokens = refreshed;
      _updateAuthState(
        AuthStateAuthenticated(
          expiresAt: refreshed.expiresAt,
          tokenType: refreshed.tokenType,
        ),
      );
      _emitEvent(RefreshSucceededEvent(expiresAt: refreshed.expiresAt));

      return refreshed;
    } catch (e, st) {
      if (e is TokenRefreshRejectedException) {
        _options.logger.log(
          'Refresh rejected by authority. Invalidating session.',
          level: TokenLogLevel.warning,
          error: e,
        );

        if (_options.clearTokensOnInvalidation) {
          _sessionEpoch++;
          _tokens = null;
          try {
            await _storage.clear();
          } catch (storageError, storageSt) {
            _options.logger.log(
              'Failed to clear storage after token rejection.',
              level: TokenLogLevel.error,
              error: storageError,
              stackTrace: storageSt,
            );
          }
          _updateAuthState(const AuthStateUnauthenticated());
          _emitEvent(
            const SessionInvalidatedEvent(
              reason: 'Refresh token rejected or revoked by server.',
            ),
          );
        } else {
          _updateAuthState(AuthStateError(e));
        }
      } else if (e is TokenRefreshTransientException) {
        // Transient network issue: retain existing credentials
        _options.logger.log(
          'Transient refresh failure. Retaining existing credentials.',
          level: TokenLogLevel.warning,
          error: e,
        );
        if (_tokens != null) {
          _updateAuthState(
            AuthStateAuthenticated(
              expiresAt: _tokens!.expiresAt,
              tokenType: _tokens!.tokenType,
            ),
          );
        } else {
          _updateAuthState(const AuthStateUnauthenticated());
        }
      } else if (e is! AuthenticationRequiredException) {
        _updateAuthState(
          AuthStateError(
            e is TokenException
                ? e
                : TokenRefreshTransientException(
                    'Unexpected error during token refresh: ${e.runtimeType}',
                    cause: e,
                    stackTrace: st,
                  ),
          ),
        );
      }

      final reportableException = e is TokenException
          ? e
          : TokenRefreshTransientException(
              'Refresh failure: $e',
              cause: e,
              stackTrace: st,
            );
      _emitEvent(RefreshFailedEvent(reportableException));
      rethrow;
    }
  }

  /// Clears stored credentials and logs out the user.
  ///
  /// Increments the session epoch to guarantee that any in-flight refresh
  /// operation is immediately cancelled and discarded, preventing stale
  /// session resurrection.
  Future<void> logout() async {
    _checkDisposed();

    _options.logger.log(
      'Logging out. Incrementing session epoch and clearing credentials.',
      level: TokenLogLevel.info,
    );

    // Invalidate any in-flight refresh immediately
    _sessionEpoch++;
    _refreshCoordinator.cancelInFlight(_sessionEpoch);

    // Clear memory immediately
    _tokens = null;

    // Clear storage
    try {
      await _storage.clear();
    } catch (e, st) {
      _options.logger.log(
        'Failed to clear storage during logout.',
        level: TokenLogLevel.error,
        error: e,
        stackTrace: st,
      );
      throw TokenStorageException(
        'Failed to clear credentials from storage during logout.',
        cause: e,
        stackTrace: st,
      );
    }

    _updateAuthState(const AuthStateUnauthenticated());
    _emitEvent(const LoggedOutEvent());
  }

  /// Alias for [logout]. Clears all credentials and resets authentication state.
  Future<void> clear() => logout();

  void _updateAuthState(AuthState newState) {
    if (_currentAuthState == newState || _isDisposed) {
      return;
    }
    _currentAuthState = newState;
    _authStateController.add(newState);
  }

  void _emitEvent(AuthEvent event) {
    if (_isDisposed) {
      return;
    }
    _eventsController.add(event);
  }

  void _checkDisposed() {
    if (_isDisposed) {
      throw StateError('Cannot use TokenManager after it has been disposed.');
    }
  }

  /// Disposes internal stream controllers and releases resources.
  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _sessionEpoch++;
    _refreshCoordinator.cancelInFlight(_sessionEpoch);
    await _authStateController.close();
    await _eventsController.close();
  }
}
