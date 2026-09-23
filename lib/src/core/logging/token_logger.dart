/// Severity levels for [TokenLogger].
enum TokenLogLevel {
  /// Verbose diagnostic messages.
  debug,

  /// General informational progress messages.
  info,

  /// Warnings indicating potential issues or transient failures.
  warning,

  /// Critical errors resulting in failure.
  error,
}

/// An interface for logging lifecycle events within `secure_token_manager`.
///
/// Implementations must **never** record access tokens, refresh tokens,
/// or sensitive authorization headers.
abstract interface class TokenLogger {
  /// Records a log [message] at the specified [level].
  void log(
    String message, {
    TokenLogLevel level = TokenLogLevel.info,
    Object? error,
    StackTrace? stackTrace,
  });
}

/// A silent [TokenLogger] implementation that discards all log messages.
///
/// This is the default logger used by [TokenManager].
final class NoOpTokenLogger implements TokenLogger {
  /// Creates a [NoOpTokenLogger].
  const NoOpTokenLogger();

  @override
  void log(
    String message, {
    TokenLogLevel level = TokenLogLevel.info,
    Object? error,
    StackTrace? stackTrace,
  }) {
    // Intentionally no-op.
  }
}

/// A simple [TokenLogger] that outputs sanitized messages using Dart's standard print.
///
/// Intended for debugging during development.
final class PrintTokenLogger implements TokenLogger {
  /// Creates a [PrintTokenLogger].
  const PrintTokenLogger({this.prefix = '[secure_token_manager]'});

  /// The prefix prepended to all logged lines.
  final String prefix;

  @override
  void log(
    String message, {
    TokenLogLevel level = TokenLogLevel.info,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final buffer =
        StringBuffer('$prefix [${level.name.toUpperCase()}] $message');
    if (error != null) {
      buffer.write(' - Error: $error');
    }
    // ignore: avoid_print
    print(buffer.toString());
  }
}
