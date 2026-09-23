import 'package:meta/meta.dart';

/// Base class for all exceptions thrown by the `secure_token_manager` package.
///
/// Security:
/// - Exceptions deliberately NEVER include token strings or secret headers
///   in their messages or diagnostic output.
@immutable
sealed class TokenException implements Exception {
  /// Creates a [TokenException].
  const TokenException(
    this.message, {
    this.cause,
    this.stackTrace,
  });

  /// A descriptive, non-sensitive message explaining the error.
  final String message;

  /// The underlying error or cause, if any.
  final Object? cause;

  /// The original stack trace associated with [cause], if available.
  final StackTrace? stackTrace;

  @override
  String toString() {
    final causeDesc = cause != null ? ' (Cause: $cause)' : '';
    return '$runtimeType: $message$causeDesc';
  }
}

/// Thrown when an error occurs while reading, writing, or clearing credentials
/// in the underlying storage adapter.
final class TokenStorageException extends TokenException {
  /// Creates a [TokenStorageException].
  const TokenStorageException(
    super.message, {
    super.cause,
    super.stackTrace,
  });
}

/// Thrown when secure storage is invoked on a platform that does not support
/// native hardware-backed secure storage (e.g. Flutter Web in v1).
final class PlatformNotSupportedException extends TokenException {
  /// Creates a [PlatformNotSupportedException].
  const PlatformNotSupportedException(
    super.message, {
    super.cause,
    super.stackTrace,
  });
}

/// Thrown when an access token is requested but no token is found in storage
/// or memory.
final class TokenNotFoundException extends TokenException {
  /// Creates a [TokenNotFoundException].
  const TokenNotFoundException([
    super.message =
        'No authentication token is currently available in storage.',
    Object? cause,
    StackTrace? stackTrace,
  ]) : super(cause: cause, stackTrace: stackTrace);
}

/// Thrown when an access token has expired and cannot be refreshed (for example,
/// because no refresh token was provided).
final class TokenExpiredException extends TokenException {
  /// Creates a [TokenExpiredException].
  const TokenExpiredException([
    super.message =
        'Access token has expired and no refresh token is available to renew it.',
    Object? cause,
    StackTrace? stackTrace,
  ]) : super(cause: cause, stackTrace: stackTrace);
}

/// Base class for all exceptions encountered during token refresh operations.
sealed class TokenRefreshException extends TokenException {
  /// Creates a [TokenRefreshException].
  const TokenRefreshException(
    super.message, {
    super.cause,
    super.stackTrace,
  });
}

/// Thrown when a token refresh operation fails due to a temporary condition,
/// such as a network timeout, connectivity loss, or server-side 5xx error.
///
/// When this exception is raised, existing credentials and session state are
/// intentionally **retained**, allowing the application to retry when
/// connectivity returns.
final class TokenRefreshTransientException extends TokenRefreshException {
  /// Creates a [TokenRefreshTransientException].
  const TokenRefreshTransientException(
    super.message, {
    super.cause,
    super.stackTrace,
  });
}

/// Thrown when a token refresh operation is definitively rejected by the
/// authentication authority (for example, HTTP 401/403, invalid refresh grant,
/// or revoked session).
///
/// When this exception is raised, existing credentials are automatically cleared
/// and the manager transitions to an unauthenticated state.
final class TokenRefreshRejectedException extends TokenRefreshException {
  /// Creates a [TokenRefreshRejectedException].
  const TokenRefreshRejectedException(
    super.message, {
    super.cause,
    super.stackTrace,
  });
}

/// Thrown when initialization of the [TokenManager] fails (e.g. unreadable storage).
final class TokenInitializationException extends TokenException {
  /// Creates a [TokenInitializationException].
  const TokenInitializationException(
    super.message, {
    super.cause,
    super.stackTrace,
  });
}

/// Thrown when an action requiring an authenticated user is attempted while in an
/// unauthenticated or unknown state.
final class AuthenticationRequiredException extends TokenException {
  /// Creates a [AuthenticationRequiredException].
  const AuthenticationRequiredException([
    super.message = 'Authentication is required to perform this action.',
    Object? cause,
    StackTrace? stackTrace,
  ]) : super(cause: cause, stackTrace: stackTrace);
}
