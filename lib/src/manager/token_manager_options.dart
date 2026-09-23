import 'package:meta/meta.dart';
import '../core/clock/clock.dart';
import '../core/clock/system_clock.dart';
import '../core/logging/token_logger.dart';
import '../refresh/refresh_coordinator.dart';

/// Configuration options for [TokenManager].
@immutable
class TokenManagerOptions {
  /// Creates a [TokenManagerOptions] configuration.
  const TokenManagerOptions({
    this.clockSkewLeeway = const Duration(seconds: 60),
    this.refreshTimeout = const Duration(seconds: 30),
    this.autoRefreshOnAccess = true,
    this.clearTokensOnInvalidation = true,
    this.isAuthInvalidatingError,
    this.clock = const SystemClock(),
    this.logger = const NoOpTokenLogger(),
  });

  /// Window of time before actual token expiration during which the token
  /// is considered expired/needs refresh.
  ///
  /// Prevents API requests from failing in-flight right at the expiration boundary
  /// and accounts for clock skew between client and authentication servers.
  /// Defaults to 60 seconds.
  final Duration clockSkewLeeway;

  /// Maximum duration to wait for a refresh callback to complete before timing out.
  /// Defaults to 30 seconds.
  final Duration refreshTimeout;

  /// Whether [TokenManager.getValidAccessToken] should automatically refresh
  /// an expired or expiring-soon token before returning.
  ///
  /// Defaults to `true`.
  final bool autoRefreshOnAccess;

  /// Whether [TokenManager] should automatically remove persisted tokens
  /// when an authentication-invalidating refresh failure occurs (e.g. HTTP 401/403,
  /// revoked token).
  ///
  /// Defaults to `true`.
  final bool clearTokensOnInvalidation;

  /// Custom predicate to classify whether an exception thrown by the refresh
  /// callback is authentication-invalidating (e.g. 401) vs transient (e.g. offline).
  final RefreshErrorClassifier? isAuthInvalidatingError;

  /// Time provider abstraction. Inject a `FakeClock` in tests for deterministic
  /// expiration scenarios.
  final Clock clock;

  /// Logger for diagnostic and lifecycle messages.
  ///
  /// Defaults to [NoOpTokenLogger]. Sensitive tokens are guaranteed never to be logged.
  final TokenLogger logger;
}
