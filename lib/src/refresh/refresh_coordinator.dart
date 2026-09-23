import 'dart:async';
import '../core/errors/token_exceptions.dart';
import '../core/logging/token_logger.dart';
import '../core/models/token_data.dart';

/// Signature for the application-provided token refresh callback.
///
/// Takes the current [refreshToken] string and returns the new [TokenData] pair.
typedef RefreshTokenCallback = Future<TokenData> Function(String refreshToken);

/// Predicate used to classify whether a given exception represents an
/// authentication-invalidating failure (e.g. 401/403, revoked grant) as opposed
/// to a temporary transient issue (e.g. network dropout, 5xx server error).
typedef RefreshErrorClassifier = bool Function(
    Object error, StackTrace stackTrace);

/// Manages single-flight concurrent token refresh requests.
///
/// Ensures that regardless of how many asynchronous tasks request a token refresh
/// simultaneously, only **one** network request is initiated. All callers share
/// and await the same in-flight [Future].
class RefreshCoordinator {
  /// Creates a [RefreshCoordinator].
  RefreshCoordinator({
    required RefreshTokenCallback onRefresh,
    RefreshErrorClassifier? isAuthInvalidating,
    Duration refreshTimeout = const Duration(seconds: 30),
    TokenLogger logger = const NoOpTokenLogger(),
  })  : _onRefresh = onRefresh,
        _isAuthInvalidating = isAuthInvalidating ?? _defaultErrorClassifier,
        _refreshTimeout = refreshTimeout,
        _logger = logger;

  final RefreshTokenCallback _onRefresh;
  final RefreshErrorClassifier _isAuthInvalidating;
  final Duration _refreshTimeout;
  final TokenLogger _logger;

  Completer<TokenData>? _inFlightCompleter;
  int _activeEpoch = 0;

  /// Default classifier for refresh errors.
  ///
  /// Any [TokenRefreshRejectedException] is always treated as authentication-invalidating.
  static bool _defaultErrorClassifier(Object error, StackTrace stackTrace) {
    if (error is TokenRefreshRejectedException) {
      return true;
    }
    return false;
  }

  /// Whether a single-flight refresh operation is currently in flight.
  bool get isRefreshing => _inFlightCompleter != null;

  /// Executes a single-flight token refresh using [currentTokens].
  ///
  /// If a refresh is already in-flight for [sessionEpoch], this returns the existing
  /// in-flight [Future] without triggering another refresh call.
  ///
  /// If [sessionEpoch] has changed or changes during execution (e.g. user logged out),
  /// the resulting token is safely discarded.
  Future<TokenData> refresh({
    required TokenData currentTokens,
    required int sessionEpoch,
  }) {
    final existingCompleter = _inFlightCompleter;
    if (existingCompleter != null) {
      _logger.log(
        'Concurrent refresh requested; joining existing in-flight operation (epoch: $sessionEpoch).',
        level: TokenLogLevel.debug,
      );
      return existingCompleter.future;
    }

    final refreshToken = currentTokens.refreshToken;
    if (refreshToken == null || refreshToken.trim().isEmpty) {
      const error = TokenExpiredException(
        'Cannot refresh tokens: No refresh token is available in current credentials.',
      );
      _logger.log(
        'Refresh aborted: no refresh token available.',
        level: TokenLogLevel.warning,
        error: error,
      );
      return Future.error(error);
    }

    final completer = Completer<TokenData>();
    _inFlightCompleter = completer;
    _activeEpoch = sessionEpoch;

    _logger.log(
      'Initiating single-flight token refresh (epoch: $sessionEpoch).',
      level: TokenLogLevel.info,
    );

    _executeRefresh(currentTokens, sessionEpoch, completer);

    return completer.future;
  }

  Future<void> _executeRefresh(
    TokenData currentTokens,
    int sessionEpoch,
    Completer<TokenData> completer,
  ) async {
    try {
      final rawFuture = _onRefresh(currentTokens.refreshToken!);
      final refreshedTokens = await rawFuture.timeout(
        _refreshTimeout,
        onTimeout: () {
          throw const TokenRefreshTransientException(
            'Token refresh callback timed out.',
          );
        },
      );

      // Verify that logout or session invalidation did not occur while awaiting response
      if (_activeEpoch != sessionEpoch) {
        _logger.log(
          'Refresh completed but session epoch changed ($sessionEpoch -> $_activeEpoch). Discarding refreshed tokens.',
          level: TokenLogLevel.warning,
        );
        throw const AuthenticationRequiredException(
          'Token refresh completed after session was invalidated or logged out.',
        );
      }

      // Handle token rotation: if the response omitted a refresh token,
      // preserve the existing valid refresh token.
      final finalTokens = refreshedTokens.refreshToken == null
          ? refreshedTokens.copyWith(refreshToken: currentTokens.refreshToken)
          : refreshedTokens;

      _logger.log(
        'Single-flight token refresh succeeded.',
        level: TokenLogLevel.info,
      );

      completer.complete(finalTokens);
    } catch (e, st) {
      final Object reportError;
      if (e is TokenException) {
        reportError = e;
      } else if (e is TimeoutException) {
        reportError = TokenRefreshTransientException(
          'Token refresh operation timed out after ${_refreshTimeout.inSeconds} seconds.',
          cause: e,
          stackTrace: st,
        );
      } else if (_isAuthInvalidating(e, st)) {
        reportError = TokenRefreshRejectedException(
          'Authentication authority rejected token refresh request.',
          cause: e,
          stackTrace: st,
        );
      } else {
        reportError = TokenRefreshTransientException(
          'Transient failure during token refresh: ${e.runtimeType}',
          cause: e,
          stackTrace: st,
        );
      }

      _logger.log(
        'Token refresh failed: ${reportError.runtimeType}',
        level: TokenLogLevel.error,
        error: reportError,
        stackTrace: st,
      );

      completer.completeError(reportError, st);
    } finally {
      if (identical(_inFlightCompleter, completer)) {
        _inFlightCompleter = null;
      }
    }
  }

  /// Cancels and resets the current in-flight refresh (called during logout/invalidation).
  void cancelInFlight(int newEpoch) {
    _activeEpoch = newEpoch;
    _inFlightCompleter = null;
  }
}
