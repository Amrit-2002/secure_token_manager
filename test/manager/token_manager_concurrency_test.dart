import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_token_manager/secure_token_manager.dart';
import '../helpers/fake_clock.dart';

void main() {
  group('TokenManager Concurrency & Race Protection', () {
    late MemoryTokenStorage storage;
    late FakeClock clock;
    final now = DateTime.utc(2026, 1, 1, 12, 0, 0);

    setUp(() {
      storage = MemoryTokenStorage();
      clock = FakeClock(now);
    });

    test(
        '10 simultaneous calls to getValidAccessToken() trigger refresh exactly ONCE',
        () async {
      var refreshCallbackCount = 0;
      final refreshCompleter = Completer<TokenData>();

      final manager = TokenManager(
        storage: storage,
        options: TokenManagerOptions(clock: clock),
        refreshToken: (refreshToken) async {
          refreshCallbackCount++;
          return refreshCompleter.future;
        },
      );

      // Seed an expired token
      await manager.setTokens(
        TokenData(
          accessToken: 'expired_access_token',
          refreshToken: 'valid_refresh_token',
          expiresAt: now.subtract(const Duration(minutes: 5)),
        ),
      );

      // Launch 10 simultaneous requests for a valid access token
      final futures = List.generate(
        10,
        (_) => manager.getValidAccessToken(),
      );

      // Yield event loop to allow tasks to trigger refresh
      await Future<void>.delayed(Duration.zero);

      // Only one refresh should be in flight
      expect(refreshCallbackCount, 1);
      expect(manager.currentAuthState, isA<AuthStateRefreshing>());

      // Resolve the refresh network call
      refreshCompleter.complete(
        TokenData(
          accessToken: 'new_refreshed_access_token',
          refreshToken: 'new_refresh_token',
          expiresAt: now.add(const Duration(hours: 1)),
        ),
      );

      final results = await Future.wait(futures);

      // Critical assertion: Callback was invoked strictly ONCE
      expect(refreshCallbackCount, 1);

      // Critical assertion: All 10 callers received the same valid access token
      expect(results.length, 10);
      for (final token in results) {
        expect(token, 'new_refreshed_access_token');
      }

      // Storage and cache hold the new token
      expect(manager.currentTokens?.accessToken, 'new_refreshed_access_token');
      expect((await storage.read())?.accessToken, 'new_refreshed_access_token');
      expect(manager.currentAuthState, isA<AuthStateAuthenticated>());
    });

    test(
        'refresh failure with rejected error propagates to all concurrent callers and clears session',
        () async {
      var refreshCallbackCount = 0;
      final refreshCompleter = Completer<TokenData>();

      final manager = TokenManager(
        storage: storage,
        options: TokenManagerOptions(clock: clock),
        refreshToken: (_) async {
          refreshCallbackCount++;
          return refreshCompleter.future;
        },
      );

      await manager.setTokens(
        TokenData(
          accessToken: 'expired_access',
          refreshToken: 'revoked_refresh',
          expiresAt: now.subtract(const Duration(minutes: 10)),
        ),
      );

      final futures = List.generate(
        5,
        (_) => manager.getValidAccessToken(),
      );

      await Future<void>.delayed(Duration.zero);
      expect(refreshCallbackCount, 1);

      // Reject refresh with authentication invalidation
      refreshCompleter.completeError(
        const TokenRefreshRejectedException('Token was revoked by server'),
      );

      for (final future in futures) {
        await expectLater(
          future,
          throwsA(isA<TokenRefreshRejectedException>()),
        );
      }

      // Credentials must be wiped from storage and cache
      expect(manager.currentTokens, isNull);
      expect(await storage.read(), isNull);
      expect(
          manager.currentAuthState, equals(const AuthStateUnauthenticated()));
    });

    test(
        'refresh failure with transient error retains credentials for all callers',
        () async {
      final refreshCompleter = Completer<TokenData>();

      final manager = TokenManager(
        storage: storage,
        options: TokenManagerOptions(clock: clock),
        refreshToken: (_) => refreshCompleter.future,
      );

      await manager.setTokens(
        TokenData(
          accessToken: 'expired_access',
          refreshToken: 'refresh_tok',
          expiresAt: now.subtract(const Duration(seconds: 10)),
        ),
      );

      final futures = List.generate(
        3,
        (_) => manager.getValidAccessToken(),
      );

      await Future<void>.delayed(Duration.zero);

      // Fail with network offline error
      refreshCompleter.completeError(
        const TokenRefreshTransientException(
            'Socket exception: network unreachable'),
      );

      for (final future in futures) {
        await expectLater(
          future,
          throwsA(isA<TokenRefreshTransientException>()),
        );
      }

      // Credentials are kept
      expect(manager.currentTokens, isNotNull);
      expect(await storage.read(), isNotNull);
    });

    test(
        'race condition: logout during in-flight refresh discards refreshed tokens',
        () async {
      final refreshCompleter = Completer<TokenData>();

      final manager = TokenManager(
        storage: storage,
        options: TokenManagerOptions(clock: clock),
        refreshToken: (_) => refreshCompleter.future,
      );

      await manager.setTokens(
        TokenData(
          accessToken: 'expiring_soon',
          refreshToken: 'refresh_old',
          expiresAt: now.subtract(const Duration(minutes: 1)),
        ),
      );

      // Start token retrieval which triggers refresh
      final refreshFuture = manager.getValidAccessToken();

      await Future<void>.delayed(Duration.zero);
      expect(manager.currentAuthState, isA<AuthStateRefreshing>());

      // USER LOGS OUT WHILE REFRESH IS IN FLIGHT
      await manager.logout();

      expect(
          manager.currentAuthState, equals(const AuthStateUnauthenticated()));
      expect(manager.currentTokens, isNull);
      expect(await storage.read(), isNull);

      // Now the network refresh finally returns a token
      refreshCompleter.complete(
        TokenData(
          accessToken: 'zombie_access_token',
          refreshToken: 'zombie_refresh_token',
          expiresAt: now.add(const Duration(hours: 1)),
        ),
      );

      // Waiting caller receives AuthenticationRequiredException
      await expectLater(
        refreshFuture,
        throwsA(isA<AuthenticationRequiredException>()),
      );

      // CRITICAL ASSERTION: The newly arrived tokens MUST NOT be stored in memory or persistence!
      expect(manager.currentTokens, isNull);
      expect(await storage.read(), isNull);
      expect(
          manager.currentAuthState, equals(const AuthStateUnauthenticated()));
    });

    test(
        'simultaneous initialize and getValidAccessToken executes without deadlock',
        () async {
      final initialTokens = TokenData(
        accessToken: 'init_access',
        refreshToken: 'init_refresh',
        expiresAt: now.add(const Duration(hours: 1)),
      );
      await storage.save(initialTokens);

      final manager = TokenManager(
        storage: storage,
        options: TokenManagerOptions(clock: clock),
        refreshToken: (r) async => TokenData(accessToken: 'new'),
      );

      // Call getValidAccessToken without awaiting initialize first
      final f1 = manager.getValidAccessToken();
      final f2 = manager.initialize();
      final f3 = manager.getValidAccessToken();

      final results = await Future.wait([f1, f2.then((_) => 'init_done'), f3]);

      expect(results[0], 'init_access');
      expect(results[1], 'init_done');
      expect(results[2], 'init_access');
    });
  });
}
