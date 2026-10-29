import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:koala/entity/leaflet_entity.dart';
import 'package:koala/entity/mark_entity.dart';
import 'package:koala/helper/act_type.dart';
import 'package:koala/helper/time_zones.dart';
import 'package:koala/helper/trip_widget_publisher.dart';
import 'package:koala/leaflets/leaflet_card.dart';
import 'package:koala/leaflets/leaflets_model.dart';
import 'package:koala/marks/marks_list_items.dart';
import 'package:koala/marks/marks_model.dart';

import '../support/demo_database.dart';
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
  ActType.values.first,
  key,
  '',
  '',
  zone,
  start,
  end,
  endTimeZoneId: endZone,
);

/// 東京 → ニューヨークの旅。出発は東京の 10/10 夜、到着はニューヨークの同じ 10/10 の朝。
List<MarkEntity> _tokyoToNewYork() => [
  _mark('tokyo', jst(2026, 10, 10, 9), end: jst(2026, 10, 10, 11)),
  _mark(
    'flight',
    jst(2026, 10, 10, 22),
    end: jst(2026, 10, 10, 22).add(const Duration(hours: 13)),
    endZone: 'America/New_York',
  ),
  _mark(
    'newyork',
    instantOf('America/New_York', DateTime(2026, 10, 10, 18)),
    zone: 'America/New_York',
  ),
];

void main() {
  group('MarkEntity', () {
    test('keeps the arrival zone in the database format', () {
      final mark = _mark(
        'f',
        jst(2026, 10, 10, 22),
        end: jst(2026, 10, 11, 8),
        endZone: 'Europe/Paris',
      );

      final restored = MarkEntity.tryBuild('f', mark.toJson())!;

      expect(restored.timeZoneId, 'Asia/Tokyo');
      expect(restored.endTimeZoneId, 'Europe/Paris');
      expect(restored.startDate, mark.startDate);
      expect(restored.endDate, mark.endDate);
    });

    test('does not write an arrival zone when it is the same as the start', () {
      final json = _mark('a', jst(2026, 10, 10, 9)).toJson();

      expect(json['endTimeZoneId'], isNull);
    });

    test('old data without a zone follows the device', () {
      setDeviceZoneForTest('America/New_York');
      addTearDown(() => setDeviceZoneForTest('Asia/Tokyo'));

      final old = MarkEntity.tryBuild('a', {
        'startDate': 1000,
        'title': 'old',
      })!;

      expect(old.timeZoneId, '');
      expect(old.startZoneId, 'America/New_York');
      expect(old.endZoneId, 'America/New_York');
    });

    test('an unknown arrival zone is not trusted', () {
      final mark = _mark(
        'a',
        jst(2026, 10, 10, 9),
        end: jst(2026, 10, 10, 10),
        zone: 'Europe/Paris',
        endZone: 'Mars/Olympus',
      );

      expect(mark.endZoneId, 'Asia/Tokyo'); // 端末（東京）にもどる
    });

    test('copy keeps the arrival zone', () {
      final mark = _mark(
        'a',
        jst(2026, 10, 10, 9),
        end: jst(2026, 10, 10, 10),
        endZone: 'Europe/Rome',
      );

      expect(mark.copy().endTimeZoneId, 'Europe/Rome');
    });
  });

  group('LeafletEntity', () {
    test('round-trips the zones of the first and last dates', () {
      final leaflet = LeafletEntity(
        'K',
        't',
        null,
        null,
        jst(2026, 10, 10),
        jst(2026, 10, 12),
        firstTimeZoneId: 'Asia/Tokyo',
        lastTimeZoneId: 'Australia/Sydney',
      );

      final restored = LeafletEntity.tryBuild('K', leaflet.toJson())!;

      expect(restored.firstTimeZoneId, 'Asia/Tokyo');
      expect(restored.lastTimeZoneId, 'Australia/Sydney');
    });

    test('old data has no zones', () {
      final old = LeafletEntity.tryBuild('K', {'title': 't'})!;

      expect(old.firstTimeZoneId, isNull);
      expect(old.lastTimeZoneId, isNull);
    });
  });

  group('days are split by the local date of each step', () {
    test('a step in another zone starts a new local day', () {
      // 東京 10/10 22:00 に出発し、ニューヨークに 10/10 の昼に着く。
      // 日付は、10/10（東京）、10/10（ニューヨークの旅程。同じ日）となる。
      final items = buildListItems(_tokyoToNewYork(), jst(2026, 10, 9));
      final headers = items.whereType<DayHeaderItem>().toList();

      expect(headers.map((h) => h.startDate), [DateTime(2026, 10, 10)]);
      expect(headers.single.zoneId, 'Asia/Tokyo');
    });

    test('the same calendar date in another zone adds no header', () {
      final marks = [
        _mark('a', jst(2026, 10, 10, 23)),
        _mark(
          'b',
          // 東京の 10/11 0:30 は、ロサンゼルスでは 10/10 8:30。
          instantOf('Asia/Tokyo', DateTime(2026, 10, 11, 0, 30)),
          zone: 'America/Los_Angeles',
        ),
      ];

      final headers = buildListItems(
        marks,
        jst(2026, 10, 9),
      ).whereType<DayHeaderItem>().toList();

      // 東京の 10/10 の次は、ロサンゼルスの 10/10（現地の日付は同じなので、見出しは 1 つ）。
      expect(headers.map((h) => h.startDate), [DateTime(2026, 10, 10)]);
    });

    test('a header is added when the local date changes in the same zone', () {
      final marks = [
        _mark('a', jst(2026, 10, 10, 23)),
        _mark('b', jst(2026, 10, 11, 0, 30)),
      ];

      final headers = buildListItems(
        marks,
        jst(2026, 10, 9),
      ).whereType<DayHeaderItem>().toList();

      expect(headers.map((h) => h.startDate), [
        DateTime(2026, 10, 10),
        DateTime(2026, 10, 11),
      ]);
    });

    test('the local day does not depend on the device time zone', () {
      final marks = _tokyoToNewYork();

      List<DateTime?> days() => buildListItems(
        marks,
        jst(2026, 10, 9),
      ).whereType<DayHeaderItem>().map((h) => h.startDate).toList();

      final onTokyo = days();
      setDeviceZoneForTest('America/Los_Angeles');
      addTearDown(() => setDeviceZoneForTest('Asia/Tokyo'));

      expect(days(), onTokyo);
    });
  });

  group('now and next use absolute time', () {
    test('are the same whichever zone the device is in', () {
      final marks = _tokyoToNewYork();
      final now = jst(2026, 10, 10, 23); // 飛行中

      List<(bool, bool)> flags() => [
        for (final item in buildListItems(marks, now))
          if (item is ActionItem) (item.isNow, item.isNext),
      ];

      final onTokyo = flags();
      setDeviceZoneForTest('Europe/London');
      addTearDown(() => setDeviceZoneForTest('Asia/Tokyo'));

      expect(flags(), onTokyo);
      expect(onTokyo, [(false, false), (true, false), (false, true)]);
    });
  });

  group('the span of the trip', () {
    test('shows each end in its own zone', () {
      expect(
        dateRangeText(
          jst(2026, 10, 10, 9),
          instantOf('Australia/Sydney', DateTime(2026, 10, 22, 20)),
          firstZoneId: 'Asia/Tokyo',
          lastZoneId: 'Australia/Sydney',
        ),
        '10/10～10/22',
      );
    });

    test('uses the device zone when the zone is unknown', () {
      setDeviceZoneForTest('America/Los_Angeles');
      addTearDown(() => setDeviceZoneForTest('Asia/Tokyo'));

      // 東京の 10/10 9:00 は、ロサンゼルスでは 10/9 17:00。
      expect(dateRangeText(jst(2026, 10, 10, 9), null), '10/9');
    });

    test(
      'is written to the leaflet from the first and the last step',
      () async {
        final db = DemoDatabase();
        final services = db.servicesFor('me');
        final key = await services.leaflets.addLeaflet('世界', coverEmoji: '🌏');
        final leaflet = (await services.leaflets.watchLeaflets().first)
            .firstWhere((l) => l.key == key);
        for (final mark in _tokyoToNewYork()) {
          await services.marks.addMark(key, mark);
        }

        final model = MarksModel(leaflet, services)..fetchMarksEntity();
        addTearDown(model.dispose);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final saved = (await services.leaflets.watchLeaflets().first)
            .firstWhere((l) => l.key == key);
        expect(saved.firstTimeZoneId, 'Asia/Tokyo');
        expect(saved.lastTimeZoneId, 'America/New_York');
      },
    );

    test('the last zone is the arrival zone of the last step', () async {
      final db = DemoDatabase();
      final services = db.servicesFor('me');
      final key = await services.leaflets.addLeaflet('便', coverEmoji: '✈️');
      final leaflet = (await services.leaflets.watchLeaflets().first)
          .firstWhere((l) => l.key == key);
      await services.marks.addMark(
        key,
        _mark(
          'flight',
          jst(2026, 10, 10, 22),
          end: jst(2026, 10, 11, 8),
          endZone: 'Europe/Paris',
        ),
      );

      final model = MarksModel(leaflet, services)..fetchMarksEntity();
      addTearDown(model.dispose);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final saved = (await services.leaflets.watchLeaflets().first).firstWhere(
        (l) => l.key == key,
      );
      expect(saved.firstTimeZoneId, 'Asia/Tokyo');
      expect(saved.lastTimeZoneId, 'Europe/Paris');
    });
  });

  group('the year group follows the zone of the first date', () {
    LeafletEntity leafletAt(DateTime first, String zone) => LeafletEntity(
      'K',
      't',
      null,
      null,
      first,
      first.add(const Duration(days: 1)),
      firstTimeZoneId: zone,
    );

    test('New Year in Tokyo is still the old year in New York', () {
      final now = jst(2027, 6, 1);
      // 2027-01-01 00:30（東京）は、ニューヨークでは 2026-12-31 10:30。
      final first = jst(2027, 1, 1, 0, 30);

      expect(groupNamesOf([leafletAt(first, 'Asia/Tokyo')], now), ['2027']);
      expect(groupNamesOf([leafletAt(first, 'America/New_York')], now), [
        '2026',
      ]);
    });
  });

  group('the home-screen widget', () {
    List<Map<String, dynamic>> steps(String json) =>
        ((jsonDecode(json) as Map<String, dynamic>)['steps'] as List<dynamic>)
            .cast<Map<String, dynamic>>();

    test('carries the zone of each step so it can show local time', () {
      final json = encodeWidgetPayload(
        't',
        _tokyoToNewYork(),
        jst(2026, 10, 10, 12),
      );

      final list = steps(json);

      expect(list.map((s) => s['tz']), contains('America/New_York'));
      final flight = list.firstWhere((s) => s['title'] == 'flight');
      expect(flight['tz'], 'Asia/Tokyo');
      expect(flight['endTz'], 'America/New_York');
      final tokyo = list.firstWhere((s) => s['title'] == 'tokyo');
      expect(tokyo.containsKey('endTz'), isFalse);
    });
  });

  group('services', () {
    test('DemoDatabase keeps the zones when a leaflet is updated', () async {
      final s = DemoDatabase().servicesFor('me');
      final key = await s.leaflets.addLeaflet('t', coverEmoji: '🐨');
      await s.leaflets.updateLeafletPeriod(
        key,
        firstTimeZoneId: 'Europe/Paris',
      );

      final saved = (await s.leaflets.watchLeaflets().first).firstWhere(
        (l) => l.key == key,
      );
      expect(saved.firstTimeZoneId, 'Europe/Paris');
    });
  });

  group('when the device time zone changes', () {
    test('the steps without a zone are shown in the new zone', () async {
      final services = DemoDatabase().servicesFor('me');
      final key = await services.leaflets.addLeaflet('旧', coverEmoji: '🐨');
      final leaflet = (await services.leaflets.watchLeaflets().first)
          .firstWhere((l) => l.key == key);
      // 東京の 10/10 9:00。ゾーンの無い旧データ。
      await services.marks.addMark(
        key,
        _mark('old', jst(2026, 10, 10, 9), zone: ''),
      );
      final model = MarksModel(leaflet, services)..fetchMarksEntity();
      addTearDown(model.dispose);
      await Future<void>.delayed(Duration.zero);
      DateTime? firstDay() =>
          model.listItems.whereType<DayHeaderItem>().first.startDate;
      expect(firstDay(), DateTime(2026, 10, 10));
      var notified = 0;
      model.addListener(() => notified++);

      // ロサンゼルスの端末では、同じ時刻が 10/9 の 17:00。
      setDeviceZoneForTest('America/Los_Angeles');
      addTearDown(() => setDeviceZoneForTest('Asia/Tokyo'));

      expect(notified, 1);
      expect(firstDay(), DateTime(2026, 10, 9));
    });

    test('the badge of another zone follows the device', () async {
      final services = DemoDatabase().servicesFor('me');
      final key = await services.leaflets.addLeaflet('旅', coverEmoji: '🐨');
      final leaflet = (await services.leaflets.watchLeaflets().first)
          .firstWhere((l) => l.key == key);
      await services.marks.addMark(
        key,
        _mark('paris', jst(2026, 10, 10, 9), zone: 'Europe/Paris'),
      );
      final model = MarksModel(leaflet, services)..fetchMarksEntity();
      addTearDown(model.dispose);
      await Future<void>.delayed(Duration.zero);
      var notified = 0;
      model.addListener(() => notified++);

      setDeviceZoneForTest('Europe/Paris');
      addTearDown(() => setDeviceZoneForTest('Asia/Tokyo'));

      expect(notified, 1); // 端末がパリになれば、バッジは要らなくなる
    });

    test('the list of leaflets is refreshed', () async {
      final services = DemoDatabase().servicesFor('me');
      final model = LeafletsModel(services)..fetchLeafletsEntity();
      addTearDown(model.dispose);
      var notified = 0;
      model.addListener(() => notified++);

      setDeviceZoneForTest('America/New_York');
      addTearDown(() => setDeviceZoneForTest('Asia/Tokyo'));

      expect(notified, 1);
    });
  });
}
