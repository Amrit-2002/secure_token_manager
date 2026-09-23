import 'clock.dart';

/// Default implementation of [Clock] backed by [DateTime.now].
final class SystemClock implements Clock {
  /// Creates a [SystemClock].
  const SystemClock();

  @override
  DateTime get now => DateTime.now();
}
