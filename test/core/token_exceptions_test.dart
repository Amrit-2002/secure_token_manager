import 'package:flutter_test/flutter_test.dart';
import 'package:secure_token_manager/secure_token_manager.dart';

void main() {
  group('TokenException taxonomy', () {
    test('TokenStorageException formats message and cause', () {
      final cause = Exception('Underlying disk error');
      final ex = TokenStorageException('Write failed', cause: cause);

      expect(ex.message, 'Write failed');
      expect(ex.cause, cause);
      expect(ex.toString(), contains('TokenStorageException: Write failed'));
      expect(ex.toString(), contains('Underlying disk error'));
    });

    test('PlatformNotSupportedException describes platform limitation', () {
      const ex = PlatformNotSupportedException('Web is not supported');
      expect(ex.toString(), contains('PlatformNotSupportedException'));
    });

    test('TokenNotFoundException has intuitive default message', () {
      const ex = TokenNotFoundException();
      expect(ex.message,
          contains('No authentication token is currently available'));
    });

    test('TokenExpiredException has intuitive default message', () {
      const ex = TokenExpiredException();
      expect(ex.message, contains('expired and no refresh token'));
    });

    test('TokenRefreshRejectedException identifies invalidation', () {
      const ex = TokenRefreshRejectedException('401 Unauthorized');
      expect(ex, isA<TokenRefreshException>());
      expect(ex.message, '401 Unauthorized');
    });

    test('TokenRefreshTransientException identifies temporary network error',
        () {
      const ex = TokenRefreshTransientException('Connection timed out');
      expect(ex, isA<TokenRefreshException>());
      expect(ex.message, 'Connection timed out');
    });

    test('AuthenticationRequiredException identifies missing auth', () {
      const ex = AuthenticationRequiredException();
      expect(ex.message, contains('Authentication is required'));
    });

    test('TokenInitializationException contains initialization cause', () {
      const ex = TokenInitializationException('Storage unreadable');
      expect(ex.message, 'Storage unreadable');
    });
  });
}
