import 'package:flutter_test/flutter_test.dart';
import 'package:secure_token_manager/secure_token_manager.dart';
import '../helpers/fake_clock.dart';

void main() {
  group('Clock', () {
    test('SystemClock returns current system time', () {
      const clock = SystemClock();
      final before = DateTime.now();
      final clockTime = clock.now;
      final after = DateTime.now();

      expect(
        clockTime.isAfter(before.subtract(const Duration(milliseconds: 1))),
        isTrue,
      );
      expect(
        clockTime.isBefore(after.add(const Duration(milliseconds: 1))),
        isTrue,
      );
    });

    test('FakeClock allows time manipulation', () {
      final initial = DateTime.utc(2026, 1, 1, 12, 0, 0);
      final fakeClock = FakeClock(initial);

      expect(fakeClock.now, initial);

      fakeClock.advance(const Duration(minutes: 5));
      expect(fakeClock.now, initial.add(const Duration(minutes: 5)));

      fakeClock.rewind(const Duration(minutes: 2));
      expect(fakeClock.now, initial.add(const Duration(minutes: 3)));

      final newTime = DateTime.utc(2026, 6, 15, 8, 30);
      fakeClock.setTime(newTime);
      expect(fakeClock.now, newTime);
    });
  });
}
