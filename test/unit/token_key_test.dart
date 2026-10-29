import 'package:flutter_test/flutter_test.dart';
import 'package:koala/notifications/token_key.dart';

void main() {
  group('deviceTokenKey', () {
    test('is the first 32 hex characters of the SHA-256', () {
      // サーバー（functions/test/handler.test.ts の同じ値）と合わせて、2 つの実装の式が同じことを固定する。
      expect(deviceTokenKey('abc'), 'ba7816bf8f01cfea414140de5dae2223');
    });

    test('is a valid database key whatever the token contains', () {
      for (final token in ['a.b#c\$d[e]f/g', 'ふつうの文字', 't' * 300]) {
        expect(deviceTokenKey(token), matches(RegExp(r'^[0-9a-f]{32}$')));
      }
    });

    test('differs between tokens', () {
      expect(deviceTokenKey('token-a'), isNot(deviceTokenKey('token-b')));
    });
  });
}
