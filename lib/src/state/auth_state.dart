import 'package:meta/meta.dart';
import '../core/errors/token_exceptions.dart';

/// Represents the observable authentication state of the token manager.
///
/// Security:
/// - Subclasses of [AuthState] deliberately **never** expose raw access tokens
///   or refresh tokens, preventing accidental leaks via UI widgets or state logs.
@immutable
sealed class AuthState {
  /// Base constructor.
  const AuthState();

  /// Whether the session is currently authenticated with a valid token.
  bool get isAuthenticated => this is AuthStateAuthenticated;

  /// Whether there is no active authenticated session.
  bool get isUnauthenticated => this is AuthStateUnauthenticated;

  /// Whether a token refresh is currently in progress.
  bool get isRefreshing => this is AuthStateRefreshing;

  /// Whether the manager has not yet completed initialization.
  bool get isUnknown => this is AuthStateUnknown;

  /// Whether the manager encountered a transient error during operations.
  bool get isError => this is AuthStateError;
}

/// The initial state before [TokenManager.initialize] has completed reading storage.
final class AuthStateUnknown extends AuthState {
  /// Creates an [AuthStateUnknown].
  const AuthStateUnknown();

  @override
  String toString() => 'AuthState.unknown';

  @override
  bool operator ==(Object other) => other is AuthStateUnknown;

  @override
  int get hashCode => 0;
}

/// Indicates that no credentials exist or the user has explicitly logged out.
final class AuthStateUnauthenticated extends AuthState {
  /// Creates an [AuthStateUnauthenticated].
  const AuthStateUnauthenticated();

  @override
  String toString() => 'AuthState.unauthenticated';

  @override
  bool operator ==(Object other) => other is AuthStateUnauthenticated;

  @override
  int get hashCode => 1;
}

/// Indicates an active, authenticated session with stored credentials.
final class AuthStateAuthenticated extends AuthState {
  /// Creates an [AuthStateAuthenticated].
  const AuthStateAuthenticated({
    this.expiresAt,
    this.tokenType = 'Bearer',
  });

  /// The expiration timestamp of the active access token, if known.
  final DateTime? expiresAt;

  /// The token type (e.g. `'Bearer'`).
  final String? tokenType;

  @override
  String toString() {
    final exp = expiresAt?.toIso8601String() ?? 'none';
    return 'AuthState.authenticated(expiresAt: $exp, tokenType: $tokenType)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthStateAuthenticated &&
          other.expiresAt?.millisecondsSinceEpoch ==
              expiresAt?.millisecondsSinceEpoch &&
          other.tokenType == tokenType;

  @override
  int get hashCode => Object.hash(expiresAt?.millisecondsSinceEpoch, tokenType);
}

/// Indicates that a single-flight token refresh operation is currently underway.
final class AuthStateRefreshing extends AuthState {
  /// Creates an [AuthStateRefreshing].
  const AuthStateRefreshing({
    this.previousExpiresAt,
    this.tokenType = 'Bearer',
  });

  /// The expiration timestamp of the token prior to starting refresh.
  final DateTime? previousExpiresAt;

  /// The token type.
  final String? tokenType;

  @override
  String toString() => 'AuthState.refreshing';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthStateRefreshing &&
          other.previousExpiresAt?.millisecondsSinceEpoch ==
              previousExpiresAt?.millisecondsSinceEpoch &&
          other.tokenType == tokenType;

  @override
  int get hashCode =>
      Object.hash(previousExpiresAt?.millisecondsSinceEpoch, tokenType);
}

/// Indicates that a transient error occurred while managing or refreshing tokens.
final class AuthStateError extends AuthState {
  /// Creates an [AuthStateError].
  const AuthStateError(this.exception);

  /// The typed token exception that caused this state.
  final TokenException exception;

  @override
  String toString() => 'AuthState.error($exception)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthStateError &&
          other.exception.runtimeType == exception.runtimeType &&
          other.exception.message == exception.message;

  @override
  int get hashCode => Object.hash(exception.runtimeType, exception.message);
}
