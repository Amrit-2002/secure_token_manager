import 'package:flutter_test/flutter_test.dart';
import 'package:secure_token_manager/secure_token_manager.dart';

void main() {
  group('AuthState', () {
    test('AuthStateUnknown properties', () {
      const state = AuthStateUnknown();
      expect(state.isUnknown, isTrue);
      expect(state.isAuthenticated, isFalse);
      expect(state.isUnauthenticated, isFalse);
      expect(state.isRefreshing, isFalse);
      expect(state.isError, isFalse);
      expect(state.toString(), equals('AuthState.unknown'));
      expect(state, equals(const AuthStateUnknown()));
    });

    test('AuthStateUnauthenticated properties', () {
      const state = AuthStateUnauthenticated();
      expect(state.isUnauthenticated, isTrue);
      expect(state.isAuthenticated, isFalse);
      expect(state.toString(), equals('AuthState.unauthenticated'));
      expect(state, equals(const AuthStateUnauthenticated()));
    });

    test('AuthStateAuthenticated properties', () {
      final expiry = DateTime.utc(2026, 5, 1, 10, 0);
      final state1 =
          AuthStateAuthenticated(expiresAt: expiry, tokenType: 'Bearer');
      final state2 =
          AuthStateAuthenticated(expiresAt: expiry, tokenType: 'Bearer');

      expect(state1.isAuthenticated, isTrue);
      expect(state1.expiresAt, expiry);
      expect(state1.tokenType, 'Bearer');
      expect(state1, equals(state2));
      expect(state1.hashCode, equals(state2.hashCode));
      expect(state1.toString(), contains('AuthState.authenticated'));
    });

    test('AuthStateRefreshing properties', () {
      final expiry = DateTime.utc(2026, 5, 1, 10, 0);
      final state = AuthStateRefreshing(previousExpiresAt: expiry);

      expect(state.isRefreshing, isTrue);
      expect(state.previousExpiresAt, expiry);
      expect(state.toString(), equals('AuthState.refreshing'));
    });

    test('AuthStateError properties', () {
      const ex = TokenNotFoundException('Missing credentials');
      const state = AuthStateError(ex);

      expect(state.isError, isTrue);
      expect(state.exception, equals(ex));
      expect(state.toString(), contains('AuthState.error'));
    });
  });

  group('AuthEvent', () {
    test('AuthEvent subclasses instantiate cleanly without secrets', () {
      const start = RefreshStartedEvent();
      expect(start.toString(), contains('RefreshStartedEvent'));

      final success =
          RefreshSucceededEvent(expiresAt: DateTime.utc(2026, 1, 1));
      expect(success.toString(), contains('RefreshSucceededEvent'));

      const fail =
          RefreshFailedEvent(TokenRefreshTransientException('Offline'));
      expect(fail.toString(), contains('RefreshFailedEvent'));

      const logout = LoggedOutEvent();
      expect(logout.toString(), contains('LoggedOutEvent'));

      const invalid = SessionInvalidatedEvent(reason: 'Revoked by admin');
      expect(invalid.toString(),
          contains('SessionInvalidatedEvent(reason: Revoked by admin)'));
    });
  });
}
