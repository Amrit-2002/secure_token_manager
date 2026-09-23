import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_token_manager/secure_token_manager.dart';
import 'package:secure_token_manager/src/refresh/refresh_coordinator.dart';

void main() {
  group('RefreshCoordinator', () {
    test('deduplicates concurrent refresh calls into a single invocation',
        () async {
      var refreshInvocationCount = 0;
      final completer = Completer<TokenData>();

      final coordinator = RefreshCoordinator(
        onRefresh: (refreshToken) async {
          refreshInvocationCount++;
          return completer.future;
        },
      );

      final current = TokenData(
        accessToken: 'old_access',
        refreshToken: 'valid_refresh',
      );

      // Launch 5 simultaneous refresh calls
      final futures = List<Future<TokenData>>.generate(
        5,
        (_) => coordinator.refresh(currentTokens: current, sessionEpoch: 1),
      );

      expect(coordinator.isRefreshing, isTrue);
      expect(refreshInvocationCount, 1);

      // Complete the in-flight refresh
      final newTokens = TokenData(
        accessToken: 'new_access',
        refreshToken: 'new_refresh',
      );
      completer.complete(newTokens);

      final results = await Future.wait(futures);

      expect(refreshInvocationCount, 1);
      expect(results.length, 5);
      for (final result in results) {
        expect(result.accessToken, 'new_access');
        expect(result.refreshToken, 'new_refresh');
      }
      expect(coordinator.isRefreshing, isFalse);
    });

    test('propagates error to all concurrent awaiting callers', () async {
      var refreshCount = 0;
      final completer = Completer<TokenData>();

      final coordinator = RefreshCoordinator(
        onRefresh: (_) async {
          refreshCount++;
          return completer.future;
        },
      );

      final current = TokenData(
        accessToken: 'old_access',
        refreshToken: 'valid_refresh',
      );

      final f1 = coordinator.refresh(currentTokens: current, sessionEpoch: 1);
      final f2 = coordinator.refresh(currentTokens: current, sessionEpoch: 1);

      completer.completeError(
        const TokenRefreshRejectedException('Revoked token'),
      );

      await expectLater(f1, throwsA(isA<TokenRefreshRejectedException>()));
      await expectLater(f2, throwsA(isA<TokenRefreshRejectedException>()));
      expect(refreshCount, 1);
      expect(coordinator.isRefreshing, isFalse);
    });

    test('aborts with TokenExpiredException if refreshToken is missing',
        () async {
      var called = false;
      final coordinator = RefreshCoordinator(
        onRefresh: (_) async {
          called = true;
          return TokenData(accessToken: 'new');
        },
      );

      final current = TokenData(accessToken: 'only_access');

      await expectLater(
        () => coordinator.refresh(currentTokens: current, sessionEpoch: 1),
        throwsA(isA<TokenExpiredException>()),
      );
      expect(called, isFalse);
    });

    test(
        'preserves old refreshToken if new response omits one (token rotation)',
        () async {
      final coordinator = RefreshCoordinator(
        onRefresh: (_) async {
          return TokenData(accessToken: 'new_access');
        },
      );

      final current = TokenData(
        accessToken: 'old_access',
        refreshToken: 'retained_refresh',
      );

      final result = await coordinator.refresh(
        currentTokens: current,
        sessionEpoch: 1,
      );

      expect(result.accessToken, 'new_access');
      expect(result.refreshToken, 'retained_refresh');
    });

    test(
        'times out and throws TokenRefreshTransientException if refresh takes too long',
        () async {
      final coordinator = RefreshCoordinator(
        onRefresh: (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return TokenData(accessToken: 'too_late');
        },
        refreshTimeout: const Duration(milliseconds: 20),
      );

      final current = TokenData(
        accessToken: 'old',
        refreshToken: 'refresh_tok',
      );

      await expectLater(
        () => coordinator.refresh(currentTokens: current, sessionEpoch: 1),
        throwsA(isA<TokenRefreshTransientException>()),
      );
    });

    test('discards tokens and throws if session epoch changes during execution',
        () async {
      final completer = Completer<TokenData>();
      final coordinator = RefreshCoordinator(
        onRefresh: (_) => completer.future,
      );

      final current = TokenData(
        accessToken: 'old',
        refreshToken: 'refresh_tok',
      );

      final future = coordinator.refresh(
        currentTokens: current,
        sessionEpoch: 1,
      );

      // User logs out, changing epoch to 2
      coordinator.cancelInFlight(2);

      // Now network completes
      completer.complete(TokenData(accessToken: 'stale_token'));

      await expectLater(
        future,
        throwsA(isA<AuthenticationRequiredException>()),
      );
    });
  });
}
