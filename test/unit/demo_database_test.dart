import 'package:flutter_test/flutter_test.dart';
import 'package:koala/data/app_services.dart';
import 'package:koala/entity/mark_entity.dart';
import 'package:koala/helper/current_step.dart';
import 'package:koala/notes/note_document.dart';
import 'package:koala/notes/remote_caret.dart';

import '../support/demo_data.dart';
import '../support/demo_database.dart';
import '../support/demo_store.dart';
import '../support/note_fixtures.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12, 30);

  group('LiveValue', () {
    test('emits the current value first, then every update', () async {
      final live = LiveValue<int>(1);
      final seen = <int>[];
      final sub = live.watch().listen(seen.add);

      live.value = 2;
      live.value = 3;
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(seen, [1, 2, 3]);
    });

    test('does not deliver updates after cancel', () async {
      final live = LiveValue<int>(1);
      final seen = <int>[];
      final sub = live.watch().listen(seen.add);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      live.value = 2;
      await Future<void>.delayed(Duration.zero);

      expect(seen, [1]);
    });

    test('a late subscriber receives the latest value', () async {
      final live = LiveValue<int>(1)..value = 5;
      expect(await live.watch().first, 5);
    });
  });

  group('demo sample data', () {
    test(
      'puts the trip around now so the timeline shows now and next',
      () async {
        final db = DemoDatabase(now: now);
        final leaflet =
            (await db.services.leaflets.watchLeaflets().first).single;
        final marks = await db.services.marks.watchMarks(leaflet.key).first;

        final step = resolveCurrentStep<MarkEntity>(
          marks,
          now,
          startOf: (m) => m.startDate,
          endOf: (m) => m.endDate,
        );
        expect(step.current, isNotNull, reason: 'a step in progress');
        expect(step.next, isNotNull, reason: 'a step coming up');
      },
    );

    test('keeps marks sorted by start time', () async {
      final db = DemoDatabase(now: now);
      final leaflet = (await db.services.leaflets.watchLeaflets().first).single;
      final marks = await db.services.marks.watchMarks(leaflet.key).first;

      final starts = marks.map((m) => m.startDate).toList();
      expect([...starts]..sort(), starts);
    });
  });

  group('demo repositories', () {
    late DemoDatabase db;
    late AppServices services;

    setUp(() {
      db = DemoDatabase(now: now);
      services = db.services;
    });

    test('adds, updates and deletes a leaflet', () async {
      await services.leaflets.addLeaflet('新しい旅', coverEmoji: '✈️');
      var leaflets = await services.leaflets.watchLeaflets().first;
      final added = leaflets.firstWhere((l) => l.title == '新しい旅');

      await services.leaflets.updateLeafletTitle(added.key, '改名した旅');
      leaflets = await services.leaflets.watchLeaflets().first;
      expect(leaflets.map((l) => l.title), contains('改名した旅'));

      await services.leaflets.deleteLeaflet(added);
      leaflets = await services.leaflets.watchLeaflets().first;
      expect(leaflets.map((l) => l.title), isNot(contains('改名した旅')));
    });

    test('adding a mark assigns a key and keeps the order', () async {
      final leaflet = (await services.leaflets.watchLeaflets().first).single;
      final early = MarkEntity(
        '',
        false,
        null,
        '早朝の散歩',
        '',
        '',
        '',
        now.subtract(const Duration(days: 1)),
        null,
      );

      await services.marks.addMark(leaflet.key, early);
      final marks = await services.marks.watchMarks(leaflet.key).first;

      expect(marks.first.title, '早朝の散歩');
      expect(marks.first.key, isNotEmpty);
    });

    test('deleting a mark removes only that mark', () async {
      final leaflet = (await services.leaflets.watchLeaflets().first).single;
      final before = await services.marks.watchMarks(leaflet.key).first;

      await services.marks.deleteMark(leaflet.key, before.first);
      final after = await services.marks.watchMarks(leaflet.key).first;

      expect(after.length, before.length - 1);
      expect(after.map((m) => m.key), isNot(contains(before.first.key)));
    });

    test('a note is saved and streamed back', () async {
      final leaflet = (await services.leaflets.watchLeaflets().first).single;

      await seedNote(services.notes, leaflet.key, '[{"insert":"x\\n"}]');

      expect(
        NoteDocument.parse(await services.notes.watchNote(leaflet.key).first)
            .visibleLines
            .single
            .delta,
        '[{"insert":"x\\n"}]',
      );
    });

    test('a leaflet without a note streams null', () async {
      await services.leaflets.addLeaflet('ノートなし', coverEmoji: '✈️');
      final added = (await services.leaflets.watchLeaflets().first).last;

      expect(await services.notes.watchNote(added.key).first, isNull);
    });

    test('has a signed-in user', () {
      expect(services.auth.currentUser?.uid, demoUserId);
    });
  });

  group('collaborators in the fake database', () {
    test('shows a simulated caret and clears it', () async {
      final db = DemoDatabase(now: now);
      final leaflet = (await db.services.leaflets.watchLeaflets().first).single;
      final stream = db.services.presence.watchCollaborators(leaflet.key);

      expect((await stream.first).editingCount, 0);

      db.setSimulatedCaret(
        leaflet.key,
        const RemoteCaret(uid: 'demo-friend', name: 'F', index: 3),
      );
      final shown = await stream.first;
      expect(shown.editingCount, 1);
      expect(shown.carets.single.index, 3);

      db.setSimulatedCaret(leaflet.key, null);
      expect((await stream.first).editingCount, 0);
    });
  });
}
