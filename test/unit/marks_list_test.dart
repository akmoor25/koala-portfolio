import 'package:flutter_test/flutter_test.dart';
import 'package:koala/entity/mark_entity.dart';
import 'package:koala/helper/time_zones.dart';
import 'package:koala/marks/marks_list_items.dart';
import 'package:koala/marks/marks_model.dart';

MarkEntity _mark(String key, DateTime start, [DateTime? end]) =>
    MarkEntity(key, false, null, key, '', '', 'Asia/Tokyo', start, end);

void main() {
  // 東京の 10/10 と 10/11 の 0 時（実行する機械のタイムゾーンに左右されない絶対時刻）。
  final day1 = instantOf('Asia/Tokyo', DateTime(2026, 10, 10));
  final day2 = instantOf('Asia/Tokyo', DateTime(2026, 10, 11));

  group('buildListItems', () {
    test('an empty trip has a headerless day and the end marker', () {
      final items = buildListItems([], day1);

      expect(items, hasLength(2));
      final header = items.first as DayHeaderItem;
      expect(header.startDate, isNull);
      expect(header.isTop, isTrue);
      expect(items.last, isA<EndItem>());
    });

    test('adds one header per day, in front of that day\'s steps', () {
      final marks = [
        _mark('a', day1.add(const Duration(hours: 9))),
        _mark('b', day1.add(const Duration(hours: 12))),
        _mark('c', day2.add(const Duration(hours: 8))),
      ];

      final items = buildListItems(marks, day1);

      expect(items.map((i) => i.runtimeType), [
        DayHeaderItem,
        ActionItem,
        ActionItem,
        DayHeaderItem,
        ActionItem,
        EndItem,
      ]);
      expect((items[0] as DayHeaderItem).isTop, isTrue);
      expect((items[3] as DayHeaderItem).isTop, isFalse);
      expect((items[3] as DayHeaderItem).startDate, DateTime(2026, 10, 11));
    });

    test('marks the current and the next step', () {
      final marks = [
        _mark(
          'a',
          day1.add(const Duration(hours: 9)),
          day1.add(const Duration(hours: 11)),
        ),
        _mark('b', day1.add(const Duration(hours: 13))),
      ];

      final items = buildListItems(marks, day1.add(const Duration(hours: 10)));
      final actions = items.whereType<ActionItem>().toList();

      expect(actions[0].isNow, isTrue);
      expect(actions[0].isNext, isFalse);
      expect(actions[1].isNow, isFalse);
      expect(actions[1].isNext, isTrue);
    });

    test('marks nothing once the trip is over', () {
      final marks = [
        _mark(
          'a',
          day1.add(const Duration(hours: 9)),
          day1.add(const Duration(hours: 10)),
        ),
      ];

      final items = buildListItems(marks, day2);

      expect(
        items.whereType<ActionItem>().any((a) => a.isNow || a.isNext),
        isFalse,
      );
    });
  });

  group('initialScrollIndex', () {
    final marks = [
      _mark(
        'a',
        day1.add(const Duration(hours: 9)),
        day1.add(const Duration(hours: 11)),
      ),
      _mark('b', day1.add(const Duration(hours: 13))),
    ];

    test('is the item before the current step', () {
      final items = buildListItems(marks, day1.add(const Duration(hours: 10)));
      // [header, a(now), b(next), end]
      expect(initialScrollIndex(items), 0);
    });

    test('falls back to the item before the next step', () {
      final items = buildListItems(marks, day1.add(const Duration(hours: 12)));
      // [header, a, b(next), end]
      expect(initialScrollIndex(items), 1);
    });

    test('is null when there is neither a current nor a next step', () {
      final finished = [
        _mark(
          'a',
          day1.add(const Duration(hours: 9)),
          day1.add(const Duration(hours: 10)),
        ),
      ];
      expect(initialScrollIndex(buildListItems(finished, day2)), isNull);
      expect(initialScrollIndex(buildListItems([], day1)), isNull);
    });
  });
}
