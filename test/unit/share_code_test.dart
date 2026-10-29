import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:koala/sharing/share_code.dart';

void main() {
  group('leaflet id', () {
    test('has the documented length and only unambiguous characters', () {
      final id = generateLeafletId(Random(1));
      expect(id, hasLength(leafletIdLength));
      expect(id, matches(RegExp(r'^[0-9A-HJKMNP-TV-Z]+$')));
    });

    test('differs between calls', () {
      expect(generateLeafletId(), isNot(generateLeafletId()));
    });

    test('is normalized for hand entry', () {
      final id = generateLeafletId(Random(2));
      expect(normalizeLeafletId(id.toLowerCase()), id);
      expect(
        normalizeLeafletId('${id.substring(0, 4)} - ${id.substring(4)}'),
        id,
      );
    });

    test('reads look-alike characters as the intended digits', () {
      expect(normalizeLeafletId('OIl000000000'), '011000000000');
    });

    test('rejects wrong length and characters', () {
      expect(normalizeLeafletId('ABC'), isNull);
      expect(normalizeLeafletId('ABCDEFGHJKMU'), isNull);
      expect(normalizeLeafletId(''), isNull);
    });
  });

  group('passphrase', () {
    test('generated passphrases are valid', () {
      expect(isValidPassphrase(generatePassphrase()), isTrue);
    });

    test('enforces the length range', () {
      expect(isValidPassphrase('1234567'), isFalse);
      expect(isValidPassphrase('12345678'), isTrue);
      expect(isValidPassphrase('a' * 65), isFalse);
    });

    test('hash is 64 hex characters and deterministic', () {
      final hash = hashPassphrase('ID000000000A', 'secret-word');
      expect(hash, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(hashPassphrase('ID000000000A', 'secret-word'), hash);
    });

    test('hash depends on both the leaflet id and the passphrase', () {
      final hash = hashPassphrase('ID000000000A', 'secret-word');
      expect(hashPassphrase('ID000000000B', 'secret-word'), isNot(hash));
      expect(hashPassphrase('ID000000000A', 'secret-wor'), isNot(hash));
    });
  });

  group('join link', () {
    test('round-trips the id and passphrase', () {
      final id = generateLeafletId(Random(3));
      final credentials = parseJoinLink(buildJoinLink(id, 'p@ss word 1'))!;
      expect(credentials.leafletId, id);
      expect(credentials.passphrase, 'p@ss word 1');
    });

    test('rejects other text', () {
      expect(parseJoinLink('https://example.com'), isNull);
      expect(parseJoinLink('koala-portfolio://join?id=ABC&p=12345678'), isNull);
      expect(
        parseJoinLink('koala-portfolio://join?id=0123456789AB&p=short'),
        isNull,
      );
      expect(parseJoinLink(''), isNull);
    });
  });
}
