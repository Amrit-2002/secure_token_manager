import 'package:secure_token_manager/secure_token_manager.dart';

/// A deterministic [Clock] implementation for unit tests.
class FakeClock implements Clock {
  /// Creates a [FakeClock] initialized to [initialTime] (or Jan 1, 2026 UTC).
  FakeClock([DateTime? initialTime])
      : _currentTime = initialTime ?? DateTime.utc(2026, 1, 1, 12, 0, 0);

  DateTime _currentTime;

  @override
  DateTime get now => _currentTime;

  /// Sets the clock directly to [time].
  void setTime(DateTime time) {
    _currentTime = time;
  }

  /// Advances the clock forward by [duration].
  void advance(Duration duration) {
    _currentTime = _currentTime.add(duration);
  }

  /// Rewinds the clock backward by [duration].
  void rewind(Duration duration) {
    _currentTime = _currentTime.subtract(duration);
  }
}
