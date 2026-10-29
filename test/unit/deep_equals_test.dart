import 'package:flutter_test/flutter_test.dart';
import 'package:koala/helper/deep_equals.dart';

void main() {
  test('compares scalar values using their existing equality', () {
    expect(mapEqualsDeep(null, null), isTrue);
    expect(mapEqualsDeep('a', 'a'), isTrue);
    expect(mapEqualsDeep(1, 1.0), isTrue);
    expect(mapEqualsDeep(true, true), isTrue);
    for (final value in [false, 0, '', <String, Object?>{}, <Object?>[]]) {
      expect(mapEqualsDeep(null, value), isFalse);
      expect(mapEqualsDeep(value, null), isFalse);
    }
    expect(mapEqualsDeep(1, '1'), isFalse);
    expect(mapEqualsDeep(true, false), isFalse);
  });

  test('compares nested maps without depending on key order', () {
    final a = {
      'lines': [
        {'text': 'one', 'deleted': false},
        null,
      ],
      'generation': 'g',
    };
    final b = {
      'generation': 'g',
      'lines': [
        {'deleted': false, 'text': 'one'},
        null,
      ],
    };
    expect(mapEqualsDeep(a, b), isTrue);
    expect(mapEqualsDeep(a, {...b, 'generation': 'next'}), isFalse);
    expect(mapEqualsDeep({'a': null}, {'b': null}), isFalse);
    expect(mapEqualsDeep({'a': null}, <String, Object?>{}), isFalse);
  });

  test('distinguishes list order, length, contents and collection type', () {
    expect(mapEqualsDeep(<Object?>[], <Object?>[]), isTrue);
    expect(mapEqualsDeep([1, 2], [2, 1]), isFalse);
    expect(mapEqualsDeep([1], [1, 2]), isFalse);
    expect(mapEqualsDeep([1, 2], [1, 3]), isFalse);
    expect(
      mapEqualsDeep(
        [
          [1],
        ],
        [
          [2],
        ],
      ),
      isFalse,
    );
    expect(mapEqualsDeep(<Object?>[], <String, Object?>{}), isFalse);
  });
}
