/// An abstraction over the system clock to allow deterministic testing
/// of time-dependent features like token expiration and clock skew.
abstract interface class Clock {
  /// Returns the current date and time.
  DateTime get now;
}
