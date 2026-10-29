import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:koala/data/app_services.dart';
import 'package:koala/data/firebase/firebase_services.dart';
import 'package:koala/entity/leaflet_entity.dart';
import 'package:koala/entity/mark_entity.dart';
import 'package:koala/leaflets/leaflets_model.dart';
import 'package:koala/marks/marks_list_items.dart';
import 'package:koala/marks/marks_model.dart';

import '../support/demo_database.dart';
import '../support/localized_app.dart';

class _RecordingWidget extends FakeTripWidget {
  final List<(String, int)> published = [];

  @override
  Future<void> publish(
    String leafletTitle,
    List<MarkEntity> marks, {
    String? leafletKey,
  }) async {
    published.add((leafletTitle, marks.length));
    await super.publish(leafletTitle, marks, leafletKey: leafletKey);
  }
}

class _ControlledLeaflets implements FirebaseLeafletRepository {
  final stream = StreamController<LeafletEntity?>();
  int listens = 0;

  @override
  Stream<LeafletEntity?> watchLeaflet(String key) {
    listens++;
    return stream.stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingMarks implements FirebaseMarkRepository {
  @override
  Future<void> createMarks(String leafletKey, List<MarkEntity> marks) =>
      Future.error(Exception('permission-denied'));

  @override
  Stream<List<MarkEntity>> watchMarks(String leafletKey) =>
      Stream.value(const []);

  @override
  Future<void> addMark(String leafletKey, MarkEntity mark) =>
      Future.error(Exception('permission-denied'));

  @override
  Future<void> updateMark(String leafletKey, MarkEntity mark) =>
      Future.error(Exception('permission-denied'));

  @override
  Future<void> deleteMark(String leafletKey, MarkEntity mark) =>
      Future.error(Exception('permission-denied'));
}

AppServices _with(
  AppServices base, {
  FirebaseMarkRepository? marks,
  FirebaseLeafletRepository? leaflets,
  FakeTripWidget? widget,
}) => AppServices(
  auth: base.auth,
  leaflets: leaflets ?? base.leaflets,
  marks: marks ?? base.marks,
  notes: base.notes,
  presence: base.presence,
  passphrases: base.passphrases,
  widget: widget ?? base.widget,
  deviceName: base.deviceName,
  push: base.push,
  deviceTokens: base.deviceTokens,
);

MarkEntity _mark(String title, DateTime start, [DateTime? end]) =>
    MarkEntity('', false, null, title, '', '', 'Asia/Tokyo', start, end);

void main() {
  late DemoDatabase db;
  late AppServices services;

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Future<LeafletEntity> newLeaflet(String title) async {
    final key = await services.leaflets.addLeaflet(title, coverEmoji: '✈️');
    final all = await services.leaflets.watchLeaflets().first;
    return all.firstWhere((l) => l.key == key);
  }

  setUp(() {
    db = DemoDatabase();
    services = db.servicesFor('me');
  });

  group('MarksModel', () {
    test('lists the days and steps of the sample trip', () async {
      final demo = (await db.services.leaflets.watchLeaflets().first).first;
      final model = MarksModel(demo, db.services)..fetchMarksEntity();
      addTearDown(model.dispose);
      await settle();

      expect(model.listItems.first, isA<DayHeaderItem>());
      expect(model.listItems.last, isA<EndItem>());
      expect(model.listItems.whereType<ActionItem>(), isNotEmpty);
      expect(model.isEditMode, isFalse);
      expect(model.nowItemIndex, isNotNull);
    });

    test('an empty leaflet opens in edit mode with a headerless day', () async {
      final leaflet = await newLeaflet('空のしおり');
      final model = MarksModel(leaflet, services)..fetchMarksEntity();
      addTearDown(model.dispose);
      await settle();

      expect(model.isEditMode, isTrue);
      expect(model.listItems, hasLength(2));
      expect(model.nowItemIndex, isNull);
    });

    test('toggling the edit mode notifies listeners', () async {
      final leaflet = await newLeaflet('x');
      final model = MarksModel(leaflet, services);
      addTearDown(model.dispose);
      var notified = 0;
      model.addListener(() => notified++);

      model.toggleEditMode();
      expect(model.isEditMode, isTrue);
      model.toggleEditMode();
      expect(model.isEditMode, isFalse);
      expect(notified, 2);
    });

    test('adding, updating and deleting a step updates the list', () async {
      final leaflet = await newLeaflet('旅');
      final model = MarksModel(leaflet, services)..fetchMarksEntity();
      addTearDown(model.dispose);
      final start = DateTime.now().add(const Duration(days: 1));

      await model.addMark(_mark('新幹線', start));
      await settle();
      List<ActionItem> steps() =>
          model.listItems.whereType<ActionItem>().toList();
      expect(steps().map((s) => s.mark.title), ['新幹線']);

      final added = steps().single.mark..title = '特急';
      await model.updateMark(added);
      await settle();
      expect(steps().map((s) => s.mark.title), ['特急']);

      await model.deleteMark(added);
      await settle();
      expect(steps(), isEmpty);
    });

    test('writes the span of the trip back to the leaflet', () async {
      final leaflet = await newLeaflet('旅');
      final first = DateTime(2030, 1, 1, 9);
      final last = DateTime(2030, 1, 3, 18);
      await services.marks.addMark(leaflet.key, _mark('a', first));
      await services.marks.addMark(
        leaflet.key,
        _mark('b', DateTime(2030, 1, 3, 15), last),
      );

      final model = MarksModel(leaflet, services)..fetchMarksEntity();
      addTearDown(model.dispose);
      await settle();
      await settle();

      final saved = (await services.leaflets.watchLeaflets().first).firstWhere(
        (l) => l.key == leaflet.key,
      );
      expect(saved.firstDate, first);
      expect(saved.lastDate, last);
    });

    test('publishes the steps to the home-screen widget', () async {
      final leaflet = await newLeaflet('旅');
      await services.marks.addMark(
        leaflet.key,
        _mark('a', DateTime.now().add(const Duration(hours: 1))),
      );
      final widget = _RecordingWidget();

      final model = MarksModel(leaflet, _with(services, widget: widget))
        ..fetchMarksEntity();
      addTearDown(model.dispose);
      await settle();

      expect(widget.published.last, ('旅', 1));
    });

    test('period updates preserve another client title and cover', () async {
      final stale = await newLeaflet('Old');
      await services.leaflets.updateLeafletTitle(stale.key, 'Latest');
      await services.leaflets.updateLeafletCover(
        stale.key,
        imageUrl: '🌴',
        coverColor: 0xFF123456,
      );
      final first = DateTime(2030, 1, 1, 9);
      await services.marks.addMark(stale.key, _mark('a', first));
      final model = MarksModel(stale, services)..fetchMarksEntity();
      addTearDown(model.dispose);
      await settle();

      final saved = await services.leaflets.watchLeaflet(stale.key).first;
      expect(saved!.title, 'Latest');
      expect(saved.imageUrl, '🌴');
      expect(saved.coverColor, 0xFF123456);
      expect(saved.firstDate, first);
      expect(model.leaflet!.title, 'Latest');
      expect(stale.title, 'Old');
    });

    test('title updates refresh the widget without new marks', () async {
      final leaflet = await newLeaflet('Old');
      await services.marks.addMark(
        leaflet.key,
        _mark('a', DateTime(2030, 1, 1)),
      );
      final model = MarksModel(leaflet, services)..fetchMarksEntity();
      addTearDown(model.dispose);
      await settle();
      final marks = db.widget.marks;

      await services.leaflets.updateLeafletTitle(leaflet.key, 'Latest');
      await settle();
      expect(model.leaflet!.title, 'Latest');
      expect(db.widget.title, 'Latest');
      expect(db.widget.marks, same(marks));
    });

    test('deleting the last mark clears only the period', () async {
      final leaflet = await newLeaflet('Trip');
      await services.leaflets.updateLeafletCover(
        leaflet.key,
        imageUrl: '🌴',
        coverColor: 0xFF123456,
      );
      await services.marks.addMark(
        leaflet.key,
        _mark('a', DateTime(2030, 1, 1)),
      );
      final model = MarksModel(leaflet, services)..fetchMarksEntity();
      addTearDown(model.dispose);
      await settle();
      await model.deleteMark(model.marks.single);
      await settle();

      final saved = await services.leaflets.watchLeaflet(leaflet.key).first;
      expect(saved!.firstDate, isNull);
      expect(saved.lastDate, isNull);
      expect(saved.firstTimeZoneId, isNull);
      expect(saved.lastTimeZoneId, isNull);
      expect(saved.title, 'Trip');
      expect(saved.imageUrl, '🌴');
      expect(saved.coverColor, 0xFF123456);
    });

    test('list subscription only refreshes the current widget title', () async {
      final current = await newLeaflet('Current');
      final other = await newLeaflet('Other');
      final marks = [_mark('a', DateTime(2030, 1, 1))];
      await db.widget.publish('Current', marks, leafletKey: current.key);
      final publishedMarks = db.widget.marks;
      final model = LeafletsModel(services)..fetchLeafletsEntity();
      addTearDown(model.dispose);
      await settle();

      await services.leaflets.updateLeafletTitle(other.key, 'Other renamed');
      await settle();
      expect(db.widget.leafletKey, current.key);
      expect(db.widget.title, 'Current');
      expect(db.widget.marks, same(publishedMarks));

      await services.leaflets.updateLeafletTitle(current.key, 'Latest');
      await settle();
      expect(db.widget.leafletKey, current.key);
      expect(db.widget.title, 'Latest');
      expect(db.widget.marks, same(publishedMarks));
    });

    test('removes a deleted leaflet and never republishes its title', () async {
      final leaflet = await newLeaflet('Deleted');
      final model = MarksModel(leaflet, services)..fetchMarksEntity();
      addTearDown(model.dispose);
      await settle();
      await services.leaflets.deleteLeaflet(leaflet);
      await settle();
      expect(model.leaflet, isNull);
      expect(db.widget.title, isNull);

      await services.marks.addMark(leaflet.key, _mark('a', DateTime(2030)));
      await settle();
      expect(db.widget.title, isNull);
    });

    test(
      'waits for the first leaflet, clears on error, cancels once',
      () async {
        final leaflet = await newLeaflet('Stale');
        final repository = _ControlledLeaflets();
        final widget = _RecordingWidget();
        final model = MarksModel(
          leaflet,
          _with(services, leaflets: repository, widget: widget),
        )..fetchMarksEntity();
        await settle();
        expect(model.leaflet, isNull);
        expect(widget.published, isEmpty);
        model.fetchMarksEntity();
        expect(repository.listens, 1);

        final latest = LeafletEntity(
          leaflet.key,
          'Latest',
          null,
          null,
          null,
          null,
        );
        repository.stream.add(latest);
        await settle();
        expect(model.leaflet, same(latest));
        expect(widget.title, 'Latest');

        repository.stream.addError(Exception('permission-denied'));
        await settle();
        expect(model.leaflet, isNull);
        expect(widget.title, isNull);
        expect(repository.stream.hasListener, isFalse);
        repository.stream.add(latest);
        await settle();
        expect(model.leaflet, isNull);
        model.dispose();
        await repository.stream.close();
      },
    );

    test('dispose cancels the leaflet subscription', () async {
      final repository = _ControlledLeaflets();
      final leaflet = await newLeaflet('x');
      final model = MarksModel(leaflet, _with(services, leaflets: repository))
        ..fetchMarksEntity();
      await settle();
      expect(repository.stream.hasListener, isTrue);
      model.dispose();
      await settle();
      expect(repository.stream.hasListener, isFalse);
      await repository.stream.close();
    });

    test('a failed write is reported with what failed', () async {
      final leaflet = await newLeaflet('旅');
      final model = MarksModel(
        leaflet,
        _with(services, marks: _FailingMarks()),
      );
      addTearDown(model.dispose);
      final messages = <String>[];
      model
        ..l10n = ja
        ..onWriteError = messages.add;
      final mark = _mark('a', DateTime.now());

      await model.addMark(mark);
      await model.updateMark(mark);
      await model.deleteMark(mark);

      expect(messages, hasLength(3));
      expect(messages[0], contains('旅程の追加'));
      expect(messages[1], contains('旅程の更新'));
      expect(messages[2], contains('旅程の削除'));
    });
  });
}
