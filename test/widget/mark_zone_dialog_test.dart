import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/entity/leaflet_entity.dart';
import 'package:koala/entity/mark_entity.dart';
import 'package:koala/helper/time_zones.dart';
import 'package:koala/marks/mark_dialogs.dart';
import 'package:koala/marks/marks_model.dart';

import '../support/app_flows.dart';
import '../support/demo_database.dart';
import '../support/jst.dart';
import '../support/localized_app.dart';

/// [zoneId] の、ダイアログに出る名前（日本語の都市名と、2026/10/10 時点の UTC との差）。
String _label(String zoneId) => zoneLabel(zoneId, jst(2026, 10, 10, 9), 'ja');

/// 東京 10/10 22:00 発、ニューヨーク（現地 10/10 22:00）着の便がある旅。
MarkEntity _flight() => MarkEntity(
  '',
  false,
  null,
  'flight',
  '',
  '',
  'Asia/Tokyo',
  jst(2026, 10, 10, 22),
  jst(2026, 10, 10, 22).add(const Duration(hours: 13)),
  endTimeZoneId: 'America/New_York',
);

class _Harness {
  _Harness(this.model, this.leaflet, this.db);

  final MarksModel model;
  final LeafletEntity leaflet;
  final DemoDatabase db;
}

Future<_Harness> _setUp(WidgetTester tester, {bool withFlight = false}) async {
  useScreen(tester, const Size(800, 1400));
  final db = DemoDatabase();
  final services = db.servicesFor('me');
  final key = await services.leaflets.addLeaflet('t', coverEmoji: '🐨');
  final leaflet = (await services.leaflets.watchLeaflets().first).firstWhere(
    (l) => l.key == key,
  );
  if (withFlight) await services.marks.addMark(key, _flight());
  final model = MarksModel(leaflet, services)..fetchMarksEntity();
  addTearDown(model.dispose);
  await tester.pump();
  await tester.pump();
  return _Harness(model, leaflet, db);
}

Future<void> _open(
  WidgetTester tester,
  _Harness h, {
  MarkEntity? mark,
  DateTime? initialWall,
  String? zoneHint,
}) async {
  await tester.pumpWidget(
    localizedApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showMarkInputDialog(
              context,
              h.model,
              mark: mark,
              initialWall: initialWall,
              zoneHint: zoneHint,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the first step starts in the device time zone', (tester) async {
    setDeviceZoneForTest('Asia/Tokyo');
    final h = await _setUp(tester);

    await _open(tester, h, initialWall: DateTime(2026, 10, 10, 9));

    expect(find.text(_label('Asia/Tokyo')), findsOneWidget);
    expect(find.text('09:00'), findsOneWidget);
  });

  testWidgets('the first step follows a device in another country', (
    tester,
  ) async {
    setDeviceZoneForTest('America/Los_Angeles');
    addTearDown(() => setDeviceZoneForTest('Asia/Tokyo'));
    final h = await _setUp(tester);

    await _open(tester, h, initialWall: DateTime(2026, 10, 10, 9));

    expect(find.text(_label('America/Los_Angeles')), findsOneWidget);
  });

  testWidgets('a step after an arrival starts in the arrival zone', (
    tester,
  ) async {
    final h = await _setUp(tester, withFlight: true);

    await _open(
      tester,
      h,
      initialWall: DateTime(2026, 10, 10, 19),
      zoneHint: 'America/New_York',
    );

    expect(find.text(_label('America/New_York')), findsOneWidget);
    expect(find.text('19:00'), findsOneWidget);
  });

  testWidgets('editing keeps the zone of the step', (tester) async {
    final h = await _setUp(tester, withFlight: true);
    final flight = h.model.marks.single;

    await _open(tester, h, mark: flight);

    // 開始は東京、終了はニューヨーク。
    expect(find.text(_label('Asia/Tokyo')), findsOneWidget);
    expect(find.text(_label('America/New_York')), findsOneWidget);
    expect(find.text('22:00'), findsNWidgets(2)); // 東京の出発と、ニューヨークの到着
  });

  testWidgets('changing the zone keeps the wall clock and saves the zone', (
    tester,
  ) async {
    final h = await _setUp(tester);
    await _open(tester, h, initialWall: DateTime(2026, 10, 10, 9));
    await tester.enterText(find.byType(TextField).first, '朝食');

    await tester.tap(find.text(_label('Asia/Tokyo')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'paris');
    await tester.pumpAndSettle();
    await tester.tap(find.text(_label('Europe/Paris')));
    await tester.pumpAndSettle();

    expect(find.text(_label('Europe/Paris')), findsOneWidget);
    expect(find.text('09:00'), findsOneWidget); // 現地の時刻は変わらない

    await tester.ensureVisible(find.text(ja.ok));
    await tester.tap(find.text(ja.ok));
    await tester.pumpAndSettle();
    await tester.pump();

    final saved = h.model.marks.single;
    expect(saved.timeZoneId, 'Europe/Paris');
    expect(
      saved.startDate,
      instantOf('Europe/Paris', DateTime(2026, 10, 10, 9)),
    );
    expect(saved.endTimeZoneId, '');
  });

  testWidgets('the arrival zone can differ, and is saved only then', (
    tester,
  ) async {
    final h = await _setUp(tester);
    await _open(tester, h, initialWall: DateTime(2026, 10, 10, 9));
    await tester.enterText(find.byType(TextField).first, '便');

    // 終了を有効にすると、終了のタイムゾーンの行が出る（開始と同じ）。
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text(_label('Asia/Tokyo')), findsNWidgets(2));

    await tester.tap(find.text(_label('Asia/Tokyo')).last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'rome');
    await tester.pumpAndSettle();
    await tester.tap(find.text(_label('Europe/Rome')));
    await tester.pumpAndSettle();

    expect(find.text(_label('Asia/Tokyo')), findsOneWidget);
    expect(find.text(_label('Europe/Rome')), findsOneWidget);

    await tester.ensureVisible(find.text(ja.ok));
    await tester.tap(find.text(ja.ok));
    await tester.pumpAndSettle();
    await tester.pump();

    final saved = h.model.marks.single;
    expect(saved.timeZoneId, 'Asia/Tokyo');
    expect(saved.endTimeZoneId, 'Europe/Rome');
  });

  testWidgets('the end must not be before the start in absolute time', (
    tester,
  ) async {
    final h = await _setUp(tester);
    await _open(tester, h, initialWall: DateTime(2026, 10, 10, 9));
    await tester.enterText(find.byType(TextField).first, '便');

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    // 同じ現地時刻でも、終了を UTC+9 より東のシドニー（UTC+11）にすると、絶対時刻では早くなる。
    await tester.tap(find.text(_label('Asia/Tokyo')).last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'sydney');
    await tester.pumpAndSettle();
    await tester.tap(find.text(_label('Australia/Sydney')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(ja.ok));
    await tester.tap(find.text(ja.ok));
    await tester.pumpAndSettle();

    expect(find.text(ja.endBeforeStart), findsOneWidget);
    expect(h.model.marks, isEmpty);
  });
}
