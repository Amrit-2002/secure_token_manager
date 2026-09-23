import 'package:flutter_test/flutter_test.dart';
import 'package:secure_token_manager/secure_token_manager.dart';

void main() {
  group('MemoryTokenStorage', () {
    test('starts empty when no initial tokens supplied', () async {
      final storage = MemoryTokenStorage();
      expect(await storage.read(), isNull);
      expect(storage.hasTokens, isFalse);
    });

    test('stores and reads tokens accurately', () async {
      final storage = MemoryTokenStorage();
      final tokens = TokenData(
        accessToken: 'access_1',
        refreshToken: 'refresh_1',
      );

      await storage.save(tokens);
      final read = await storage.read();

      expect(read, equals(tokens));
      expect(storage.hasTokens, isTrue);
    });

    test('clears stored tokens', () async {
      final storage = MemoryTokenStorage(
        initialTokens: TokenData(accessToken: 'init_token'),
      );
      expect(await storage.read(), isNotNull);

      await storage.clear();
      expect(await storage.read(), isNull);
      expect(storage.hasTokens, isFalse);
    });

    test('returns independent copies to prevent external mutation', () async {
      final storage = MemoryTokenStorage();
      final tokens = TokenData(accessToken: 'access_imm');

      await storage.save(tokens);
      final read1 = await storage.read();
      final read2 = await storage.read();

      expect(read1, equals(read2));
      expect(identical(read1, read2), isFalse);
    });
  });
}
