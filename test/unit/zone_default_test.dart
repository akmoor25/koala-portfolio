import 'package:flutter_test/flutter_test.dart';
import 'package:koala/entity/mark_entity.dart';
import 'package:koala/helper/time_zones.dart';
import 'package:koala/marks/marks_model.dart';

import '../support/jst.dart';

MarkEntity _mark(
  String key,
  DateTime start, {
  DateTime? end,
  String zone = 'Asia/Tokyo',
  String endZone = '',
}) => MarkEntity(
  key,
  false,
  null,
  key,
  '',
  '',
  zone,
  start,
  end,
  endTimeZoneId: endZone,
);

void main() {
  group('defaultZoneIdFor', () {
    test('the first step uses the device time zone', () {
      setDeviceZoneForTest('Asia/Tokyo');

      expect(defaultZoneIdFor([], jst(2026, 10, 10, 9)), 'Asia/Tokyo');
    });

    test('the first step uses the device even in another country', () {
      setDeviceZoneForTest('America/Los_Angeles');
      addTearDown(() => setDeviceZoneForTest('Asia/Tokyo'));

      expect(defaultZoneIdFor([], jst(2026, 10, 10, 9)), 'America/Los_Angeles');
    });

    test('follows the zone of the previous step', () {
      final marks = [_mark('a', jst(2026, 10, 10, 9), zone: 'Europe/Paris')];

      expect(defaultZoneIdFor(marks, jst(2026, 10, 10, 20)), 'Europe/Paris');
    });

    test('after an arrival, uses the zone of the arrival', () {
      final marks = [
        _mark(
          'flight',
          jst(2026, 10, 10, 9),
          end: jst(2026, 10, 10, 21),
          endZone: 'America/New_York',
        ),
      ];

      expect(defaultZoneIdFor(marks, jst(2026, 10, 11, 0)), 'America/New_York');
    });

    test('a step without an arrival zone ends in its own zone', () {
      final marks = [
        _mark(
          'a',
          jst(2026, 10, 10, 9),
          end: jst(2026, 10, 10, 10),
          zone: 'Asia/Bangkok',
        ),
      ];

      expect(defaultZoneIdFor(marks, jst(2026, 10, 10, 12)), 'Asia/Bangkok');
    });

    test('inserting in the middle uses the step just before', () {
      final marks = [
        _mark('tokyo', jst(2026, 10, 10, 9)),
        _mark(
          'flight',
          jst(2026, 10, 10, 12),
          end: jst(2026, 10, 10, 22),
          endZone: 'Europe/Paris',
        ),
        _mark('paris', jst(2026, 10, 11, 9), zone: 'Europe/Rome'),
      ];

      expect(defaultZoneIdFor(marks, jst(2026, 10, 10, 10)), 'Asia/Tokyo');
      expect(defaultZoneIdFor(marks, jst(2026, 10, 10, 23)), 'Europe/Paris');
      expect(defaultZoneIdFor(marks, jst(2026, 10, 11, 12)), 'Europe/Rome');
    });

    test('before the first step, uses the device time zone', () {
      setDeviceZoneForTest('Asia/Tokyo');
      final marks = [_mark('a', jst(2026, 10, 10, 9), zone: 'Europe/Paris')];

      expect(defaultZoneIdFor(marks, jst(2026, 10, 9, 9)), 'Asia/Tokyo');
    });

    test('an unknown zone on the previous step falls back to the device', () {
      setDeviceZoneForTest('Asia/Tokyo');
      final marks = [_mark('a', jst(2026, 10, 10, 9), zone: 'Mars/Olympus')];

      expect(defaultZoneIdFor(marks, jst(2026, 10, 10, 12)), 'Asia/Tokyo');
    });
  });
}
