import 'package:flutter_test/flutter_test.dart';
import 'package:secure_token_manager/secure_token_manager.dart';

void main() {
  group('SecureTokenStorage', () {
    test('constructs default qualified key', () {
      final storage = SecureTokenStorage();
      expect(storage.qualifiedKey, 'secure_token_manager.auth_tokens');
    });

    test(
        'supports custom namespace and storageKey for multi-account partitioning',
        () {
      final storage = SecureTokenStorage(
        namespace: 'account_user_42',
        storageKey: 'oauth_session',
      );
      expect(storage.qualifiedKey, 'account_user_42.oauth_session');
    });
  });
}
