import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/entity/mark_entity.dart';
import 'package:koala/helper/act_type.dart';
import 'package:koala/helper/trip_widget_publisher.dart';

MarkEntity _mark(String key, DateTime start, [DateTime? end]) =>
    MarkEntity(key, false, ActType.values.first, key, '', '', '', start, end);

void main() {
  final t = DateTime(2026, 5, 1, 9);
  final marks = [
    _mark('a', t),
    _mark(
      'b',
      t.add(const Duration(hours: 2)),
      t.add(const Duration(hours: 3)),
    ),
    _mark('c', t.add(const Duration(hours: 5))),
  ];

  List<String> titles(String json) =>
      ((jsonDecode(json) as Map<String, dynamic>)['steps'] as List<dynamic>)
          .map((s) => (s as Map<String, dynamic>)['title'] as String)
          .toList();

  group('encodeWidgetPayload', () {
    test('before the trip includes every step', () {
      final json = encodeWidgetPayload(
        'Trip',
        marks,
        t.subtract(const Duration(hours: 1)),
      );
      expect(titles(json), ['a', 'b', 'c']);
      expect((jsonDecode(json) as Map)['leaflet'], 'Trip');
    });

    test('drops steps before the current one', () {
      final json = encodeWidgetPayload(
        'Trip',
        marks,
        t.add(const Duration(hours: 2, minutes: 30)),
      );
      expect(titles(json), ['b', 'c']);
    });

    test('after the last start keeps the last step', () {
      final json = encodeWidgetPayload(
        'Trip',
        marks,
        t.add(const Duration(days: 1)),
      );
      expect(titles(json), ['c']);
    });

    test('writes epoch seconds and omits a missing end', () {
      final json = encodeWidgetPayload(
        'Trip',
        marks,
        t.subtract(const Duration(hours: 1)),
      );
      final steps =
          ((jsonDecode(json) as Map<String, dynamic>)['steps'] as List<dynamic>)
              .cast<Map<String, dynamic>>();
      expect(steps[0]['start'], t.millisecondsSinceEpoch ~/ 1000);
      expect(steps[0].containsKey('end'), isFalse);
      expect(
        steps[1]['end'],
        t.add(const Duration(hours: 3)).millisecondsSinceEpoch ~/ 1000,
      );
    });

    test('writes remark only when present', () {
      final withRemark = [
        MarkEntity('r', false, null, 'r', 'memo', '', '', t, null),
        ...marks,
      ];
      final json = encodeWidgetPayload(
        'Trip',
        withRemark,
        t.subtract(const Duration(hours: 1)),
      );
      final steps =
          ((jsonDecode(json) as Map<String, dynamic>)['steps'] as List<dynamic>)
              .cast<Map<String, dynamic>>();
      expect(steps[0]['remark'], 'memo');
      expect(steps[1].containsKey('remark'), isFalse);
    });

    test('caps the number of steps', () {
      final many = List.generate(
        50,
        (i) => _mark('$i', t.add(Duration(hours: i))),
      );
      final json = encodeWidgetPayload(
        'Trip',
        many,
        t.subtract(const Duration(hours: 1)),
      );
      expect(titles(json).length, widgetMaxSteps);
    });
  });

  test('widgetBoundaryTimes returns sorted future start/end times', () {
    final times = widgetBoundaryTimes(marks, t.add(const Duration(hours: 1)));
    expect(times, [
      t.add(const Duration(hours: 2)),
      t.add(const Duration(hours: 3)),
      t.add(const Duration(hours: 5)),
    ]);
  });

  group('NativeTripWidgetPublisher', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('home_widget');
    late List<MethodCall> calls;
    Object? Function(MethodCall)? onCall;

    setUp(() {
      calls = [];
      onCall = (_) => true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return onCall!(call);
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    });

    test('init sets the app group', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await const NativeTripWidgetPublisher().init();

      expect(calls.single.method, 'setAppGroupId');
      expect(
        (calls.single.arguments as Map)['groupId'],
        'group.io.akmoor25.koala-portfolio',
      );
    });

    test('publish saves the payload and refreshes the widget (iOS)', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await const NativeTripWidgetPublisher().publish('Trip', marks);

      expect(calls.map((c) => c.method), ['saveWidgetData', 'updateWidget']);
      final saved = calls.first.arguments as Map;
      expect(saved['id'], 'koala_trip');
      expect(
        jsonDecode(saved['data'] as String),
        containsPair('leaflet', 'Trip'),
      );
    });

    test('publish also schedules updates on Android', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await const NativeTripWidgetPublisher().publish('Trip', marks);

      expect(calls.map((c) => c.method), [
        'saveWidgetData',
        'updateWidget',
        'scheduleWidgetUpdates',
      ]);
    });

    test('does nothing on unsupported platforms', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      const publisher = NativeTripWidgetPublisher();
      await publisher.init();
      await publisher.publish('Trip', marks);

      expect(calls, isEmpty);
    });

    test('a platform failure is swallowed, not thrown', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      onCall = (_) => throw PlatformException(code: 'boom');

      await expectLater(
        const NativeTripWidgetPublisher().publish('Trip', marks),
        completes,
      );
    });

    test('publish includes the leaflet key when given', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await const NativeTripWidgetPublisher().publish(
        'Trip',
        marks,
        leafletKey: 'KEY1',
      );

      final saved = calls.first.arguments as Map;
      expect(
        jsonDecode(saved['data'] as String),
        containsPair('leafletKey', 'KEY1'),
      );
    });

    group('updateTitleFor', () {
      test('changes only the current title, not steps or schedules', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final payload = jsonDecode(
          encodeWidgetPayload('Old', marks, t, leafletKey: 'K'),
        ) as Map<String, dynamic>;
        onCall = (call) =>
            call.method == 'getWidgetData' ? jsonEncode(payload) : true;

        await const NativeTripWidgetPublisher().updateTitleFor('K', 'Latest');

        final save = calls.singleWhere((c) => c.method == 'saveWidgetData');
        expect(jsonDecode((save.arguments as Map)['data'] as String), {
          ...payload,
          'leaflet': 'Latest',
        });
        expect(calls.map((c) => c.method), contains('updateWidget'));
        expect(
          calls.map((c) => c.method),
          isNot(
            anyOf(
              contains('scheduleWidgetUpdates'),
              contains('cancelScheduledWidgetUpdates'),
            ),
          ),
        );
      });

      test('does not switch leaflets or rewrite unchanged titles', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        onCall = (call) => call.method == 'getWidgetData'
            ? encodeWidgetPayload('Trip', marks, t, leafletKey: 'K')
            : true;

        const publisher = NativeTripWidgetPublisher();
        await publisher.updateTitleFor('OTHER', 'Other');
        await publisher.updateTitleFor('K', 'Trip');
        expect(calls.where((c) => c.method == 'saveWidgetData'), isEmpty);
      });

      test('missing, keyless and malformed data are left alone', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        for (final saved in [null, 'invalid JSON', '[]', '{"leaflet":"Old"}']) {
          onCall = (call) => call.method == 'getWidgetData' ? saved : true;
          await const NativeTripWidgetPublisher().updateTitleFor('K', 'Latest');
        }
        expect(calls.where((c) => c.method == 'saveWidgetData'), isEmpty);
      });

      test('does nothing on unsupported platforms or on failure', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        const publisher = NativeTripWidgetPublisher();
        await publisher.updateTitleFor('K', 'Latest');
        expect(calls, isEmpty);

        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        onCall = (_) => throw PlatformException(code: 'boom');
        await expectLater(publisher.updateTitleFor('K', 'Latest'), completes);
      });
    });

    test(
      'serializes publish, title refresh and clear across instances',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final blocked = Completer<void>();
        final entered = Completer<void>();
        String? stored;
        var saves = 0;
        onCall = (call) {
          if (call.method == 'getWidgetData') return stored;
          if (call.method == 'saveWidgetData') {
            saves++;
            if (saves == 1) {
              entered.complete();
              return blocked.future.then((_) {
                stored = (call.arguments as Map)['data'] as String?;
                return true;
              });
            }
            stored = (call.arguments as Map)['data'] as String?;
          }
          return true;
        };
        final first = const NativeTripWidgetPublisher().publish(
          'Old',
          marks,
          leafletKey: 'K',
        );
        await entered.future;
        final title = const NativeTripWidgetPublisher().updateTitleFor(
          'K',
          'Latest',
        );
        final clear = const NativeTripWidgetPublisher().clearFor('K');
        await Future<void>.delayed(Duration.zero);
        expect(calls.map((c) => c.method), ['saveWidgetData']);
        blocked.complete();
        await Future.wait([first, title, clear]);
        expect(stored, isNull);
        final saved = calls.where((c) => c.method == 'saveWidgetData').toList();
        expect(saved, hasLength(3));
        expect(
          jsonDecode((saved[1].arguments as Map)['data'] as String),
          containsPair('leaflet', 'Latest'),
        );
        expect(calls.last.method, 'cancelScheduledWidgetUpdates');
      },
    );

    test(
      'a title refresh cannot resurrect a cleared or replaced trip',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        String? stored;
        onCall = (call) {
          if (call.method == 'getWidgetData') return stored;
          if (call.method == 'saveWidgetData') {
            stored = (call.arguments as Map)['data'] as String?;
          }
          return true;
        };
        const publisher = NativeTripWidgetPublisher();
        await publisher.publish('Old', marks, leafletKey: 'K');
        await Future.wait([
          publisher.clearFor('K'),
          publisher.updateTitleFor('K', 'Stale'),
        ]);
        expect(stored, isNull);

        await Future.wait([
          publisher.publish('Other', marks, leafletKey: 'OTHER'),
          publisher.updateTitleFor('K', 'Stale'),
        ]);
        expect(jsonDecode(stored!) as Map, containsPair('leafletKey', 'OTHER'));
        expect(jsonDecode(stored!) as Map, containsPair('leaflet', 'Other'));
      },
    );

    group('clearFor', () {
      String payload(String? key) =>
          encodeWidgetPayload('Trip', marks, t, leafletKey: key);

      test(
        'removes the data when the widget shows that leaflet (iOS)',
        () async {
          debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
          onCall = (call) =>
              call.method == 'getWidgetData' ? payload('K') : true;

          await const NativeTripWidgetPublisher().clearFor('K');

          expect(calls.map((c) => c.method), [
            'getWidgetData',
            'getWidgetData',
            'saveWidgetData',
            'updateWidget',
          ]);
          final save = calls.firstWhere((c) => c.method == 'saveWidgetData');
          expect((save.arguments as Map)['id'], 'koala_trip');
          expect((save.arguments as Map)['data'], isNull);
        },
      );

      test('also cancels the scheduled updates on Android', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        onCall = (call) => call.method == 'getWidgetData' ? payload('K') : true;

        await const NativeTripWidgetPublisher().clearFor('K');

        expect(calls.map((c) => c.method), contains('saveWidgetData'));
        expect(calls.last.method, 'cancelScheduledWidgetUpdates');
      });

      test('keeps the data of another leaflet', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        onCall = (call) =>
            call.method == 'getWidgetData' ? payload('OTHER') : true;

        await const NativeTripWidgetPublisher().clearFor('K');

        expect(calls.map((c) => c.method), ['getWidgetData']);
      });

      test('keeps data without a key, and nothing saved', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        onCall = (call) =>
            call.method == 'getWidgetData' ? payload(null) : true;
        await const NativeTripWidgetPublisher().clearFor('K');
        expect(calls.map((c) => c.method), ['getWidgetData']);

        calls.clear();
        onCall = (_) => null;
        await const NativeTripWidgetPublisher().clearFor('K');
        expect(calls.map((c) => c.method), ['getWidgetData']);
      });

      test('does nothing on unsupported platforms or on failure', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        await const NativeTripWidgetPublisher().clearFor('K');
        expect(calls, isEmpty);

        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        onCall = (_) => throw PlatformException(code: 'boom');
        await expectLater(
          const NativeTripWidgetPublisher().clearFor('K'),
          completes,
        );
      });
    });
  });
}
