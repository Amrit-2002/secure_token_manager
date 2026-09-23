import 'package:meta/meta.dart';
import '../core/errors/token_exceptions.dart';

/// Base class for observability events emitted by [TokenManager].
///
/// Security:
/// - These events intentionally **never** include sensitive credentials,
///   allowing safe recording into analytics, Crashlytics, or APM monitoring tools.
@immutable
sealed class AuthEvent {
  /// Base constructor.
  const AuthEvent({DateTime? timestamp})
      : timestamp = timestamp ?? const _DefaultTimestamp();

  /// The timestamp when the event occurred.
  final Object? timestamp;

  @override
  String toString() => '$runtimeType()';
}

class _DefaultTimestamp {
  const _DefaultTimestamp();
  @override
  String toString() => DateTime.now().toUtc().toIso8601String();
}

/// Emitted when a single-flight token refresh process begins.
final class RefreshStartedEvent extends AuthEvent {
  /// Creates a [RefreshStartedEvent].
  const RefreshStartedEvent();
}

/// Emitted when a token refresh operation succeeds and the new tokens are persisted.
final class RefreshSucceededEvent extends AuthEvent {
  /// Creates a [RefreshSucceededEvent].
  const RefreshSucceededEvent({this.expiresAt});

  /// The new expiration time, if known.
  final DateTime? expiresAt;
}

/// Emitted when a token refresh operation fails.
final class RefreshFailedEvent extends AuthEvent {
  /// Creates a [RefreshFailedEvent].
  const RefreshFailedEvent(this.exception);

  /// The typed failure exception.
  final TokenException exception;

  @override
  String toString() => 'RefreshFailedEvent(exception: $exception)';
}

/// Emitted when tokens are directly supplied or updated (e.g. following login).
final class TokensUpdatedEvent extends AuthEvent {
  /// Creates a [TokensUpdatedEvent].
  const TokensUpdatedEvent({this.expiresAt});

  /// The expiration timestamp of the new tokens, if known.
  final DateTime? expiresAt;
}

/// Emitted when the user explicitly logs out and credentials are removed.
final class LoggedOutEvent extends AuthEvent {
  /// Creates a [LoggedOutEvent].
  const LoggedOutEvent();
}

/// Emitted when a session is invalidated (e.g. refresh token rejected or revoked).
final class SessionInvalidatedEvent extends AuthEvent {
  /// Creates a [SessionInvalidatedEvent].
  const SessionInvalidatedEvent({required this.reason});

  /// A non-sensitive diagnostic explanation for the invalidation.
  final String reason;

  @override
  String toString() => 'SessionInvalidatedEvent(reason: $reason)';
}
