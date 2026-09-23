import 'package:flutter_test/flutter_test.dart';
import 'package:secure_token_manager/secure_token_manager.dart';
import '../helpers/fake_clock.dart';

void main() {
  group('TokenManager Core API', () {
    late MemoryTokenStorage storage;
    late FakeClock clock;
    final now = DateTime.utc(2026, 1, 1, 12, 0, 0);

    setUp(() {
      storage = MemoryTokenStorage();
      clock = FakeClock(now);
    });

    test('initializes to AuthStateUnauthenticated when storage is empty',
        () async {
      final manager = TokenManager(
        storage: storage,
        refreshToken: (r) async => TokenData(accessToken: 'new'),
      );

      expect(manager.isInitialized, isFalse);
      expect(manager.currentAuthState, equals(const AuthStateUnknown()));

      await manager.initialize();

      expect(manager.isInitialized, isTrue);
      expect(
          manager.currentAuthState, equals(const AuthStateUnauthenticated()));
      expect(manager.currentTokens, isNull);
    });

    test(
        'initializes to AuthStateAuthenticated when storage has valid credentials',
        () async {
      final saved = TokenData(
        accessToken: 'saved_access',
        refreshToken: 'saved_refresh',
        expiresAt: now.add(const Duration(hours: 1)),
      );
      await storage.save(saved);

      final manager = TokenManager(
        storage: storage,
        options: TokenManagerOptions(clock: clock),
        refreshToken: (r) async => TokenData(accessToken: 'new'),
      );

      await manager.initialize();

      expect(manager.isInitialized, isTrue);
      expect(manager.currentAuthState, isA<AuthStateAuthenticated>());
      expect(manager.currentTokens?.accessToken, 'saved_access');
    });

    test('repeated calls to initialize are idempotent and safe', () async {
      final manager = TokenManager(
        storage: storage,
        refreshToken: (r) async => TokenData(accessToken: 'new'),
      );

      final f1 = manager.initialize();
      final f2 = manager.initialize();

      await Future.wait([f1, f2]);
      expect(manager.isInitialized, isTrue);
    });

    test('setTokens updates storage, cache, state, and emits events', () async {
      final manager = TokenManager(
        storage: storage,
        options: TokenManagerOptions(clock: clock),
        refreshToken: (r) async => TokenData(accessToken: 'new'),
      );

      final states = <AuthState>[];
      final events = <AuthEvent>[];
      final subState = manager.authState.listen(states.add);
      final subEvent = manager.events.listen(events.add);

      final tokens = TokenData(
        accessToken: 'access_login',
        refreshToken: 'refresh_login',
        expiresAt: now.add(const Duration(hours: 2)),
      );

      await manager.setTokens(tokens);

      expect(manager.currentTokens?.accessToken, 'access_login');
      expect(manager.currentAuthState, isA<AuthStateAuthenticated>());

      final persisted = await storage.read();
      expect(persisted?.accessToken, 'access_login');

      await Future<void>.delayed(Duration.zero);
      expect(states.last, isA<AuthStateAuthenticated>());
      expect(events.last, isA<TokensUpdatedEvent>());

      await subState.cancel();
      await subEvent.cancel();
    });

    test('getValidAccessToken returns cached token when still valid', () async {
      final manager = TokenManager(
        storage: storage,
        options: TokenManagerOptions(clock: clock),
        refreshToken: (r) async => TokenData(accessToken: 'refreshed'),
      );

      await manager.setTokens(
        TokenData(
          accessToken: 'valid_access_now',
          expiresAt: now.add(const Duration(minutes: 30)),
        ),
      );

      final token = await manager.getValidAccessToken();
      expect(token, 'valid_access_now');
    });

    test(
        'getValidAccessToken throws TokenNotFoundException if no session exists',
        () async {
      final manager = TokenManager(
        storage: storage,
        refreshToken: (r) async => TokenData(accessToken: 'new'),
      );

      await expectLater(
        manager.getValidAccessToken(),
        throwsA(isA<TokenNotFoundException>()),
      );
    });

    test('logout clears memory, storage, resets state and emits LoggedOutEvent',
        () async {
      final manager = TokenManager(
        storage: storage,
        refreshToken: (r) async => TokenData(accessToken: 'new'),
      );

      await manager.setTokens(TokenData(accessToken: 'active'));
      expect(manager.currentTokens, isNotNull);
      expect(await storage.read(), isNotNull);

      final events = <AuthEvent>[];
      final sub = manager.events.listen(events.add);

      await manager.logout();

      expect(manager.currentTokens, isNull);
      expect(await storage.read(), isNull);
      expect(
          manager.currentAuthState, equals(const AuthStateUnauthenticated()));

      await Future<void>.delayed(Duration.zero);
      expect(events.last, isA<LoggedOutEvent>());

      await sub.cancel();
    });

    test('dispose closes stream controllers and disallows further usage',
        () async {
      final manager = TokenManager(
        storage: storage,
        refreshToken: (r) async => TokenData(accessToken: 'new'),
      );

      await manager.initialize();
      await manager.dispose();

      expect(
        () => manager.setTokens(TokenData(accessToken: 't1')),
        throwsStateError,
      );
    });
  });
}
