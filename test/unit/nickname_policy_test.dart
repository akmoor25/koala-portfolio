import 'package:flutter_test/flutter_test.dart';
import 'package:koala/helper/nickname_policy.dart';

void main() {
  group('normalizeNickname', () {
    test('trims and collapses whitespace', () {
      expect(normalizeNickname('  a \n\t b  '), 'a b');
      expect(normalizeNickname('さくら　ちゃん'), 'さくら ちゃん');
    });

    test('turns control and direction-changing characters into spaces', () {
      expect(normalizeNickname('a\u0000b\u202Ec'), 'a b c');
    });

    test('keeps a normal name as it is', () {
      expect(normalizeNickname('Pixel 10a'), 'Pixel 10a');
    });
  });

  group('isValidNickname', () {
    test('needs at least one visible character', () {
      expect(isValidNickname(''), isFalse);
      expect(isValidNickname('   '), isFalse);
      expect(isValidNickname('\u0000'), isFalse);
      expect(isValidNickname('a'), isTrue);
    });

    test('allows up to 20 visible characters', () {
      expect(isValidNickname('あ' * 20), isTrue);
      expect(isValidNickname('あ' * 21), isFalse);
      // 絵文字の家族は、1 文字として数える。
      expect(isValidNickname('👨‍👩‍👧' * 20), isTrue);
      expect(isValidNickname('👨‍👩‍👧' * 21), isFalse);
    });
  });

  group('nicknameFromDeviceName', () {
    test('uses the model name as it is when it fits', () {
      expect(nicknameFromDeviceName('Pixel 10a'), 'Pixel 10a');
      expect(nicknameFromDeviceName('iPhone 15 Pro'), 'iPhone 15 Pro');
    });

    test('cuts a long name and tidies it', () {
      final name = nicknameFromDeviceName(' ${'x' * 30} ');
      expect(name, 'x' * 20);
      expect(isValidNickname(name), isTrue);
    });

    test('is empty when the device gives nothing', () {
      expect(nicknameFromDeviceName(''), '');
      expect(nicknameFromDeviceName('  '), '');
    });
  });
}
