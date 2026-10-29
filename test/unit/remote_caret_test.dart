import 'package:flutter_test/flutter_test.dart';
import 'package:koala/notes/remote_caret.dart';

void main() {
  group('parseRemoteCarets', () {
    test('returns empty for null or non-map values', () {
      expect(parseRemoteCarets(null, 'me'), isEmpty);
      expect(parseRemoteCarets(123, 'me'), isEmpty);
    });

    test('excludes my own entry and entries without index', () {
      final carets = parseRemoteCarets({
        'me': {'at': 1, 'name': 'M', 'index': 3},
        'bob': {'at': 1, 'name': 'B', 'index': 5},
        'carol': {'at': 1, 'name': 'C'},
      }, 'me');
      expect(carets, [const RemoteCaret(uid: 'bob', name: 'B', index: 5)]);
    });

    test('skips malformed entries such as legacy numeric presence', () {
      final carets = parseRemoteCarets({
        'legacy': 1700000000000,
        'neg': {'name': 'N', 'index': -1},
        'str': {'name': 'S', 'index': '4'},
      }, 'me');
      expect(carets, isEmpty);
    });

    test('falls back to ? when name is missing and sorts by uid', () {
      final carets = parseRemoteCarets({
        'zed': {'index': 1},
        'amy': {'name': 'A', 'index': 0},
      }, null);
      expect(carets.map((c) => c.uid), ['amy', 'zed']);
      expect(carets.last.name, '?');
    });
  });

  group('RemoteCaret.clampedIndex', () {
    const caret = RemoteCaret(uid: 'u', name: 'U', index: 10);

    test('keeps index inside the document', () {
      expect(caret.clampedIndex(20), 10);
    });

    test('clamps to before the trailing newline when document shrank', () {
      expect(caret.clampedIndex(4), 3);
      expect(caret.clampedIndex(0), 0);
    });
  });

  group('presencePayload', () {
    test('omits index when not focused', () {
      expect(presencePayload(at: 1, name: 'M'), {'at': 1, 'name': 'M'});
      expect(presencePayload(at: 1, name: 'M', index: 2), {
        'at': 1,
        'name': 'M',
        'index': 2,
      });
    });
  });

  group('initialOf', () {
    test('uses upper-cased first character of the nickname', () {
      expect(initialOf('moro'), 'M');
      expect(initialOf('1abc'), '1');
      expect(initialOf('さくら'), 'さ');
    });

    test('returns ? when the nickname is not set', () {
      expect(initialOf(null), '?');
      expect(initialOf(''), '?');
    });
  });

  group('colorForUid', () {
    test('is deterministic', () {
      expect(colorForUid('abc'), colorForUid('abc'));
    });

    test('spreads different uids across the palette', () {
      final colors = List.generate(50, (i) => colorForUid('user$i')).toSet();
      expect(colors.length, greaterThan(3));
    });
  });

  group('LatestValueThrottle', () {
    testWidgets(
      'fires first value immediately and latest value after interval',
      (tester) async {
        final fired = <int>[];
        final throttle = LatestValueThrottle<int>(
          const Duration(milliseconds: 150),
          fired.add,
        );

        throttle.add(1);
        throttle.add(2);
        throttle.add(3);
        expect(fired, [1]);

        await tester.pump(const Duration(milliseconds: 150));
        expect(fired, [1, 3]);

        await tester.pump(const Duration(milliseconds: 150));
        expect(fired, [1, 3]);
        throttle.cancel();
      },
    );

    testWidgets('cancel drops pending value', (tester) async {
      final fired = <int>[];
      final throttle = LatestValueThrottle<int>(
        const Duration(milliseconds: 150),
        fired.add,
      );

      throttle.add(1);
      throttle.add(2);
      throttle.cancel();
      await tester.pump(const Duration(milliseconds: 300));
      expect(fired, [1]);

      throttle.add(4);
      expect(fired, [1, 4]);
      throttle.cancel();
    });
  });
}
