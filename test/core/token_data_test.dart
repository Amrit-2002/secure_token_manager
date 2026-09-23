import 'package:flutter_test/flutter_test.dart';
import 'package:secure_token_manager/secure_token_manager.dart';
import '../helpers/fake_clock.dart';

void main() {
  group('TokenData', () {
    final baseTime = DateTime.utc(2026, 1, 1, 12, 0, 0);

    test('creates valid TokenData instance', () {
      final tokens = TokenData(
        accessToken: 'access_123',
        refreshToken: 'refresh_456',
        expiresAt: baseTime,
        tokenType: 'Bearer',
        metadata: const {'scope': 'read:write'},
      );

      expect(tokens.accessToken, 'access_123');
      expect(tokens.refreshToken, 'refresh_456');
      expect(tokens.expiresAt, baseTime);
      expect(tokens.tokenType, 'Bearer');
      expect(tokens.metadata, {'scope': 'read:write'});
      expect(tokens.hasRefreshToken, isTrue);
    });

    test('throws ArgumentError when accessToken is empty or whitespace', () {
      expect(
        () => TokenData(accessToken: ''),
        throwsArgumentError,
      );
      expect(
        () => TokenData(accessToken: '   '),
        throwsArgumentError,
      );
    });

    test('hasRefreshToken is false when refreshToken is null or empty', () {
      final tokens1 = TokenData(accessToken: 'a1');
      expect(tokens1.hasRefreshToken, isFalse);

      final tokens2 = TokenData(accessToken: 'a1', refreshToken: '');
      expect(tokens2.hasRefreshToken, isFalse);
    });

    test('metadata is unmodifiable', () {
      final map = <String, dynamic>{'role': 'admin'};
      final tokens = TokenData(accessToken: 'a1', metadata: map);

      expect(
        () => tokens.metadata!['role'] = 'guest',
        throwsUnsupportedError,
      );
    });

    test('toString() strictly redacts access token and refresh token', () {
      final tokens = TokenData(
        accessToken: 'SUPER_SECRET_ACCESS_TOKEN_ABC',
        refreshToken: 'SUPER_SECRET_REFRESH_TOKEN_XYZ',
        expiresAt: baseTime,
        tokenType: 'Bearer',
      );

      final str = tokens.toString();

      expect(str, contains('[REDACTED]'));
      expect(str, isNot(contains('SUPER_SECRET_ACCESS_TOKEN_ABC')));
      expect(str, isNot(contains('SUPER_SECRET_REFRESH_TOKEN_XYZ')));
    });

    test('JSON serialization round-trip works accurately', () {
      final original = TokenData(
        accessToken: 'token_abc',
        refreshToken: 'token_xyz',
        expiresAt: baseTime,
        tokenType: 'Bearer',
        metadata: const {'user_id': 42},
      );

      final json = original.toJson();
      final restored = TokenData.fromJson(json);

      expect(restored.accessToken, original.accessToken);
      expect(restored.refreshToken, original.refreshToken);
      expect(
        restored.expiresAt?.toUtc(),
        original.expiresAt?.toUtc(),
      );
      expect(restored.tokenType, original.tokenType);
      expect(restored.metadata, original.metadata);
      expect(restored, equals(original));
    });

    test('fromJson throws FormatException for invalid payloads', () {
      expect(
        () => TokenData.fromJson(const <String, dynamic>{}),
        throwsFormatException,
      );
      expect(
        () => TokenData.fromJson(const <String, dynamic>{'accessToken': 123}),
        throwsFormatException,
      );
    });

    test('equality and hashCode verify value equivalence', () {
      final t1 = TokenData(
        accessToken: 'a1',
        refreshToken: 'r1',
        expiresAt: baseTime,
      );
      final t2 = TokenData(
        accessToken: 'a1',
        refreshToken: 'r1',
        expiresAt: baseTime,
      );
      final t3 = TokenData(
        accessToken: 'a2',
        refreshToken: 'r1',
        expiresAt: baseTime,
      );

      expect(t1, equals(t2));
      expect(t1.hashCode, equals(t2.hashCode));
      expect(t1, isNot(equals(t3)));
    });

    test('copyWith updates specified fields and preserves untouched', () {
      final original = TokenData(
        accessToken: 'a1',
        refreshToken: 'r1',
        expiresAt: baseTime,
      );

      final updated = original.copyWith(
        accessToken: 'a2',
        clearRefreshToken: true,
      );

      expect(updated.accessToken, 'a2');
      expect(updated.refreshToken, isNull);
      expect(updated.expiresAt, baseTime);
    });

    group('Expiration calculations', () {
      test('tokens without expiresAt are never expired and always valid', () {
        final tokens = TokenData(accessToken: 'a1');
        final clock = FakeClock(baseTime);

        expect(tokens.isExpired(clock: clock), isFalse);
        expect(tokens.isValid(clock: clock), isTrue);
        expect(
          tokens.isExpiringSoon(
            clock: clock,
            threshold: const Duration(hours: 1),
          ),
          isFalse,
        );
      });

      test('isExpired detects expiration relative to clock', () {
        final clock = FakeClock(baseTime);
        final tokens = TokenData(
          accessToken: 'a1',
          expiresAt: baseTime.add(const Duration(minutes: 10)),
        );

        // Before expiry
        expect(tokens.isExpired(clock: clock), isFalse);
        expect(tokens.isValid(clock: clock), isTrue);

        // Exactly at expiry
        clock.advance(const Duration(minutes: 10));
        expect(tokens.isExpired(clock: clock), isTrue);
        expect(tokens.isValid(clock: clock), isFalse);

        // Past expiry
        clock.advance(const Duration(minutes: 1));
        expect(tokens.isExpired(clock: clock), isTrue);
      });

      test('clock skew leeway causes token to expire ahead of time', () {
        final clock = FakeClock(baseTime);
        final tokens = TokenData(
          accessToken: 'a1',
          expiresAt: baseTime.add(const Duration(minutes: 5)),
        );

        // 4 minutes elapsed, 1 minute remaining
        clock.advance(const Duration(minutes: 4));

        // Without leeway, it is not expired
        expect(tokens.isExpired(clock: clock), isFalse);

        // With 60s leeway, it is considered expired (in need of refresh)
        expect(
          tokens.isExpired(clock: clock, leeway: const Duration(seconds: 60)),
          isTrue,
        );
        expect(
          tokens.isValid(clock: clock, leeway: const Duration(seconds: 60)),
          isFalse,
        );
      });

      test('isExpiringSoon determines proactive refresh threshold', () {
        final clock = FakeClock(baseTime);
        final tokens = TokenData(
          accessToken: 'a1',
          expiresAt: baseTime.add(const Duration(minutes: 15)),
        );

        // 15 minutes away: not expiring soon for 5m threshold
        expect(
          tokens.isExpiringSoon(
            clock: clock,
            threshold: const Duration(minutes: 5),
          ),
          isFalse,
        );

        // Advance 11 minutes (4 minutes remaining)
        clock.advance(const Duration(minutes: 11));
        expect(
          tokens.isExpiringSoon(
            clock: clock,
            threshold: const Duration(minutes: 5),
          ),
          isTrue,
        );
      });
    });
  });
}
