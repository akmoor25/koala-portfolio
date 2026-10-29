import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/data/app_services.dart';
import 'package:koala/data/data_types.dart';
import 'package:koala/data/firebase/firebase_local_writes.dart';
import 'package:koala/data/firebase/firebase_services.dart';
import 'package:koala/data/sample_leaflets.dart';
import 'package:koala/entity/leaflet_entity.dart';
import 'package:koala/entity/mark_entity.dart';
import 'package:koala/l10n/write_task.dart';
import 'package:koala/leaflets/leaflets_model.dart';
import 'package:koala/marks/marks_list_items.dart';
import 'package:koala/marks/marks_model.dart';
import 'package:koala/marks/marks_screen.dart';
import 'package:koala/notes/note_document.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../support/app_flows.dart';
import '../support/demo_database.dart';
import '../support/localized_app.dart';

/// SDK のローカルイベントと、再接続まで完了しないサーバー応答を分ける。
class _Database {
  final data = <String, Object?>{};
  final changes = StreamController<void>.broadcast();
  final pending = <Completer<void>>[];
  final deniedPaths = <String>{};
  final reads = <String>[];
  final syncedPaths = <String>{};
  final queries = <String>[];
  final completeMarkLists = <String>{};
  bool connected = false;
  int nextKey = 0;

  _Reference get root => _Reference(this, '');

  Object? read(String path) {
    if (path == '.info/connected') return connected;
    Object? value = data;
    for (final part in path.split('/').where((part) => part.isNotEmpty)) {
      if (value is! Map) return null;
      value = value[part];
    }
    return value;
  }

  void put(String path, Object? value) {
    if (path.startsWith('marks/') && path.split('/').length == 2) {
      completeMarkLists.add(path);
    }
    final parts = path.split('/').where((part) => part.isNotEmpty).toList();
    var target = data;
    for (final part in parts.take(parts.length - 1)) {
      target = target.putIfAbsent(
        part,
        () => <String, Object?>{},
      ) as Map<String, Object?>;
    }
    if (value == null) {
      target.remove(parts.last);
    } else {
      target[parts.last] = value;
    }
  }

  Future<void> update(String path, Map<String, Object?> values) {
    for (final entry in values.entries) {
      put(
        [path, entry.key].where((part) => part.isNotEmpty).join('/'),
        _normalize(entry.value),
      );
    }
    changes.add(null);
    final server = Completer<void>();
    pending.add(server);
    return server.future;
  }

  void reconnect() {
    for (final server in pending) {
      if (!server.isCompleted) server.complete();
    }
  }

  Future<void> dispose() async {
    reconnect();
    await changes.close();
  }
}

Object? _normalize(Object? value) {
  if (value is! Map) return value;
  if (value['.sv'] == 'timestamp') return 1800000000000;
  if (value.isEmpty) return null;
  return <String, Object?>{
    for (final entry in value.entries)
      if (entry.value != null) entry.key as String: _normalize(entry.value),
  };
}

class _Reference implements DatabaseReference {
  _Reference(this.db, this.path);

  final _Database db;

  @override
  final String path;

  @override
  String? get key => path.split('/').last;

  @override
  DatabaseReference child(String path) => _Reference(
    db,
    [this.path, path].where((part) => part.isNotEmpty).join('/'),
  );

  @override
  DatabaseReference push() => child('id${db.nextKey++}');

  @override
  Query orderByChild(String path) {
    db.queries.add('${this.path}:$path');
    return _UncachedQuery();
  }

  @override
  Future<void> keepSynced(bool value) async {
    if (value) {
      db.syncedPaths.add(path);
    } else {
      db.syncedPaths.remove(path);
    }
  }

  @override
  Stream<DatabaseEvent> get onValue => Stream.multi((controller) {
    void emit() {
      if (!db.connected &&
          path.startsWith('marks/') &&
          path.split('/').length == 2 &&
          !db.completeMarkLists.contains(path)) {
        return;
      }
      if (db.deniedPaths.contains(path)) {
        controller.addError(
          FirebaseException(
            plugin: 'firebase_database',
            code: 'permission-denied',
          ),
        );
        unawaited(controller.close());
        return;
      }
      controller.add(
        _Event(_Snapshot(key, jsonDecode(jsonEncode(db.read(path))))),
      );
    }

    final subscription = db.changes.stream.listen((_) => emit());
    emit();
    controller.onCancel = subscription.cancel;
  });

  @override
  Future<void> update(Map<String, Object?> values) => db.update(path, values);

  @override
  Future<void> set(Object? value) => db.update('', {path: value});

  @override
  Future<void> remove() => set(null);

  @override
  Future<DataSnapshot> get() async {
    db.reads.add(path);
    return _Snapshot(key, jsonDecode(jsonEncode(db.read(path))));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 書き込み済みでも、オンラインで一度も取得していないクエリは値を返さない。
class _UncachedQuery implements Query {
  @override
  Stream<DatabaseEvent> get onValue => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Snapshot implements DataSnapshot {
  _Snapshot(this.key, this.value);

  @override
  final String? key;

  @override
  final Object? value;

  @override
  bool get exists => value != null;

  @override
  DataSnapshot child(String path) {
    var next = value;
    for (final part in path.split('/')) {
      next = next is Map ? next[part] : null;
    }
    return _Snapshot(path.split('/').last, next);
  }

  @override
  Iterable<DataSnapshot> get children {
    final current = value;
    if (current is! Map) return const [];
    return [
      for (final entry in current.entries)
        _Snapshot(entry.key as String, entry.value),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Event implements DatabaseEvent {
  _Event(this.snapshot);

  @override
  final DataSnapshot snapshot;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements FirebaseAuthGateway {
  @override
  AppUser get currentUser => const AppUser(uid: 'owner');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Database db;
  late FirebaseLocalWrites writes;
  late FirebaseLeafletRepository leaflets;
  late FirebaseMarkRepository marks;
  late FirebaseNoteRepository notes;

  setUp(() {
    db = _Database();
    writes = FirebaseLocalWrites();
    // 接続確認の待機は firebase_connection_test で検証済み。ここでは待たない。
    leaflets = FirebaseLeafletRepository(
      db.root,
      _Auth(),
      writes: writes,
      connectionGrace: Duration.zero,
    );
    marks = FirebaseMarkRepository(db.root, writes: writes);
    notes = FirebaseNoteRepository(
      db.root,
      writes: writes,
      connectionGrace: Duration.zero,
    );
  });

  tearDown(() => db.dispose());

  Future<void> settle() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test(
    'sample timelines open offline after synchronization without a query',
    () async {
      final base = DemoDatabase().services;
      final services = AppServices(
        auth: base.auth,
        leaflets: leaflets,
        marks: marks,
        notes: notes,
        presence: base.presence,
        passphrases: base.passphrases,
        widget: base.widget,
        deviceName: base.deviceName,
        push: base.push,
        deviceTokens: base.deviceTokens,
      );
      final samples = buildSampleLeaflets(DateTime(2026, 10, 19));
      final installed = <LeafletEntity>[];
      final subscription = leaflets.watchLeaflets().listen((items) {
        installed
          ..clear()
          ..addAll(items);
      });
      await installSampleLeaflets(
        leaflets: leaflets,
        marks: marks,
        notes: notes,
        now: DateTime(2026, 10, 19),
      );
      db.connected = true;
      db.reconnect();
      db.changes.add(null);
      await settle();
      expect(installed, hasLength(samples.length));
      db.connected = false;
      for (var i = 0; i < installed.length; i++) {
        final leaflet = installed[i];
        expect(
          db.syncedPaths,
          containsAll(['marks/${leaflet.key}', 'rich_notes/${leaflet.key}']),
        );
        final model = MarksModel(leaflet, services)..fetchMarksEntity();
        await settle();
        expect(model.leaflet?.title, samples[i].title);
        expect(model.marks, hasLength(samples[i].marks.length));
        expect(
          model.listItems.whereType<ActionItem>(),
          hasLength(samples[i].marks.length),
        );
        model.dispose();
      }
      expect(db.queries, isEmpty);
      await subscription.cancel();
      await settle();
      expect(db.syncedPaths, isEmpty);
    },
  );

  testWidgets(
    'Okinawa opens with a populated timeline after going offline again',
    (tester) async {
      final base = DemoDatabase().services;
      final services = AppServices(
        auth: base.auth,
        leaflets: leaflets,
        marks: marks,
        notes: notes,
        presence: base.presence,
        passphrases: base.passphrases,
        widget: base.widget,
        deviceName: base.deviceName,
        push: base.push,
        deviceTokens: base.deviceTokens,
      );
      await tester.runAsync(() async {
        await installSampleLeaflets(
          leaflets: leaflets,
          marks: marks,
          notes: notes,
        );
        db.connected = true;
        db.reconnect();
        await settle();
      });
      await openLeafletList(tester, services);
      db.connected = false;
      await openLeaflet(tester, '沖縄２泊３日');
      expect(find.byType(MarksScreen), findsOneWidget);
      expect(find.text('沖縄２泊３日'), findsOneWidget);
      expect(
        tester
            .widget<ScrollablePositionedList>(
              find.byType(ScrollablePositionedList),
            )
            .itemCount,
        greaterThan(14),
      );
      expect(db.queries, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  test('unfiltered cached marks are sorted by start date then key', () async {
    Map<String, Object?> plan(String title, int start) => {
      'title': title,
      'startDate': start,
    };
    db.put('marks/trip', <String, Object?>{
      'z': plan('last', 300),
      'b': plan('same-b', 100),
      'a': plan('same-a', 100),
      'invalid': {'title': 'no date'},
    });
    final result = await marks.watchMarks('trip').first;
    expect(result.map((mark) => mark.title), ['same-a', 'same-b', 'last']);
    expect(db.queries, isEmpty);
  });

  test(
    'denied reconnect listeners recover after queued creation is accepted',
    () async {
      final seen = <List<String>>[];
      final subscription = leaflets.watchLeaflets().listen(
        (items) => seen.add(items.map((item) => item.title).toList()),
      );
      addTearDown(subscription.cancel);
      final first = await leaflets.addLeaflet('First', coverEmoji: 'A');
      final second = await leaflets.addLeaflet('Second', coverEmoji: 'B');
      await settle();
      expect(seen.last, ['First', 'Second']);

      db.deniedPaths.addAll(['leaflets/$first', 'leaflets/$second']);
      db.changes.add(null);
      await settle();
      expect(seen.last, isEmpty);
      expect(db.reads, isEmpty, reason: '権限の書き込みが承認される前は再試行しない');

      db.deniedPaths.clear();
      db.reconnect();
      await settle();
      expect(seen.last, ['First', 'Second']);
      expect(
        db.reads,
        containsAll([
          'leafletMembers/$first/owner',
          'leafletMembers/$second/owner',
        ]),
      );
    },
  );

  test(
    'actual access loss is not restored and index removal cancels recovery',
    () async {
      final seen = <List<String>>[];
      final subscription = leaflets.watchLeaflets().listen(
        (items) => seen.add(items.map((item) => item.title).toList()),
      );
      addTearDown(subscription.cancel);
      final key = await leaflets.addLeaflet('Lost', coverEmoji: 'A');
      await settle();
      db.deniedPaths.add('leaflets/$key');
      db.put('leafletMembers/$key/owner', null);
      db.changes.add(null);
      await settle();
      db.reconnect();
      await settle();
      expect(seen.last, isEmpty);
      expect(db.reads, ['leafletMembers/$key/owner']);

      db.put('userLeaflets/owner/$key', null);
      db.changes.add(null);
      await settle();
      db.deniedPaths.clear();
      db.put('leafletMembers/$key/owner', true);
      db.changes.add(null);
      await settle();
      expect(seen.last, isEmpty);
    },
  );

  test('permanent denial retries only once instead of looping', () async {
    final subscription = leaflets.watchLeaflets().listen((_) {});
    addTearDown(subscription.cancel);
    final key = await leaflets.addLeaflet('Denied', coverEmoji: 'A');
    await settle();
    db.deniedPaths.add('leaflets/$key');
    db.changes.add(null);
    await settle();
    db.reconnect();
    await settle();
    expect(db.reads, ['leafletMembers/$key/owner']);
  });

  test('a later connection retries a previously denied subscription', () async {
    final seen = <List<String>>[];
    final subscription = leaflets.watchLeaflets().listen(
      (items) => seen.add(items.map((item) => item.title).toList()),
    );
    addTearDown(subscription.cancel);
    final key = await leaflets.addLeaflet('Trip', coverEmoji: 'A');
    await settle();
    db.deniedPaths.add('leaflets/$key');
    db.changes.add(null);
    await settle();
    db.reconnect();
    await settle();
    expect(seen.last, isEmpty);
    expect(db.reads, hasLength(1));

    db.deniedPaths.clear();
    db.connected = true;
    db.changes.add(null);
    await settle();
    expect(seen.last, ['Trip']);
    expect(db.reads, hasLength(2));
  });

  test(
    'index removal during pending synchronization prevents recovery',
    () async {
      final seen = <List<String>>[];
      final subscription = leaflets.watchLeaflets().listen(
        (items) => seen.add(items.map((item) => item.title).toList()),
      );
      addTearDown(subscription.cancel);
      final key = await leaflets.addLeaflet('Trip', coverEmoji: 'A');
      await settle();
      db.deniedPaths.add('leaflets/$key');
      db.changes.add(null);
      await settle();
      db.put('userLeaflets/owner/$key', null);
      db.changes.add(null);
      await settle();
      db.deniedPaths.clear();
      db.reconnect();
      await settle();
      expect(seen.last, isEmpty);
      expect(db.reads, isEmpty);
    },
  );

  test(
    'canceling the list while writes are pending prevents recovery',
    () async {
      final subscription = leaflets.watchLeaflets().listen((_) {});
      final key = await leaflets.addLeaflet('Trip', coverEmoji: 'A');
      await settle();
      db.deniedPaths.add('leaflets/$key');
      db.changes.add(null);
      await settle();
      await subscription.cancel();
      db.reconnect();
      await settle();
      expect(db.reads, isEmpty);
      expect(db.changes.hasListener, isFalse);
    },
  );

  test(
    'new trips and their empty notes finish before server acknowledgement',
    () async {
      final key = await leaflets
          .addLeaflet('Trip', coverEmoji: 'A')
          .timeout(const Duration(seconds: 2));
      expect(db.read('leaflets/$key/title'), 'Trip');
      expect(db.read('userLeaflets/owner/$key'), true);
      final note = NoteDocument.parse(db.read('rich_notes/$key'));
      expect(note.visibleLines.single.delta, '[{"insert":"\\n"}]');
      expect(db.pending, hasLength(3));
      expect(db.pending.every((server) => !server.isCompleted), isTrue);
      expect(db.changes.hasListener, isFalse);
    },
  );

  test(
    'sample installation reaches 100% without any server acknowledgement',
    () async {
      final progress = <SampleInstallProgress>[];
      final now = DateTime(2026, 10, 19);
      final count = await installSampleLeaflets(
        leaflets: leaflets,
        marks: marks,
        notes: notes,
        now: now,
        onProgress: progress.add,
      ).timeout(const Duration(seconds: 5));

      final samples = buildSampleLeaflets(now);
      expect(count, samples.length);
      expect(progress.first.completed, 0);
      expect(progress.last.fraction, 1);
      expect(
        progress.map((update) => update.completed),
        List.generate(progress.length, (index) => index),
      );
      final installed = await leaflets.watchLeaflets().first;
      expect(installed, hasLength(samples.length));
      for (var i = 0; i < installed.length; i++) {
        final leaflet = installed[i];
        final sample = samples[i];
        expect(leaflet.title, sample.title);
        expect(leaflet.coverColor, sample.coverColor);
        expect(leaflet.firstDate, sample.marks.first.startDate);
        expect(leaflet.lastDate, sample.marks.last.endDate);
        expect(
          await marks.watchMarks(leaflet.key).first,
          hasLength(sample.marks.length),
        );
        expect(
          NoteDocument.parse(await notes.watchNote(leaflet.key).first)
              .visibleLines,
          isNotEmpty,
        );
      }
      expect(db.pending.every((server) => !server.isCompleted), isTrue);
      final seen = <List<String>>[];
      final subscription = leaflets.watchLeaflets().listen(
        (items) => seen.add(items.map((item) => item.title).toList()),
      );
      addTearDown(subscription.cancel);
      await settle();
      expect(seen.last, samples.map((sample) => sample.title));
      db.deniedPaths.addAll(
        installed.map((leaflet) => 'leaflets/${leaflet.key}'),
      );
      db.changes.add(null);
      await settle();
      expect(seen.last, isEmpty);
      db.deniedPaths.clear();
      db.reconnect();
      await settle();
      expect(seen.last, samples.map((sample) => sample.title));
      expect(db.read('userLeaflets/owner'), isNotEmpty);
    },
  );

  test(
    'trip and plan edits, deletions and note saves complete locally',
    () async {
      final key = await leaflets.addLeaflet('Trip', coverEmoji: 'A');
      await leaflets.updateLeafletTitle(key, 'Renamed');
      await leaflets.updateLeafletCover(key);
      await leaflets.updateLeafletPeriod(key);
      expect(db.read('leaflets/$key/title'), 'Renamed');
      expect(db.read('leaflets/$key/imageUrl'), isNull);

      final mark = MarkEntity(
        'plan',
        false,
        null,
        'First',
        '',
        '',
        '',
        DateTime(2030),
        null,
      );
      await marks.addMark(key, mark);
      final added = (await marks.watchMarks(key).first).single;
      added.title = 'Changed';
      await marks.updateMark(key, added);
      expect((await marks.watchMarks(key).first).single.title, 'Changed');
      await marks.deleteMark(key, added);
      expect(await marks.watchMarks(key).first, isEmpty);

      final note = NoteDocument.parse(await notes.watchNote(key).first);
      final line = note.visibleLines.single.edit(
        '[{"insert":"offline\\n"}]',
        'w2',
      );
      await notes.saveNoteLines(key, note.generation, {line.id: line});
      expect(
        NoteDocument.parse(await notes.watchNote(key).first)
            .visibleLines
            .single
            .delta,
        '[{"insert":"offline\\n"}]',
      );
      expect(db.pending.every((server) => !server.isCompleted), isTrue);
    },
    timeout: const Timeout(Duration(seconds: 5)),
  );

  test('late server rejection is reported to the visible screen', () async {
    final base = DemoDatabase().services;
    final messages = <String>[];
    final model =
        LeafletsModel(
            AppServices(
              auth: base.auth,
              leaflets: leaflets,
              marks: marks,
              notes: notes,
              presence: base.presence,
              passphrases: base.passphrases,
              widget: base.widget,
              deviceName: base.deviceName,
              push: base.push,
              deviceTokens: base.deviceTokens,
              localWrites: writes,
            ),
          )
          ..l10n = ja
          ..onWriteError = messages.add;
    addTearDown(model.dispose);

    await leaflets.updateLeafletTitle('trip', 'Offline');
    final error = FirebaseException(
      plugin: 'firebase_database',
      code: 'permission-denied',
    );
    db.pending.last.completeError(error);
    await Future<void>.delayed(Duration.zero);
    expect(messages, [ja.writeFailed(WriteTask.updateTrip)]);
  });

  test('immediate failures propagate and do not leak a listener', () async {
    final error = FirebaseException(
      plugin: 'firebase_database',
      code: 'permission-denied',
    );
    await expectLater(
      writes.write(
        db.root.child('trip'),
        () => Future<void>.error(error),
        (_) => false,
      ),
      throwsA(same(error)),
    );
    expect(db.changes.hasListener, isFalse);
  });

  test(
    'sharing, leaving, presence and token registration do not wait for sync',
    () async {
      final key = await leaflets.addLeaflet('Trip', coverEmoji: 'A');
      final leaflet = (await leaflets.watchLeaflets().first).single;
      await leaflets.enableSharing(leaflet, 'password');
      expect(db.read('leaflets/$key/shared'), true);

      final presence = FirebasePresenceRepository(
        db.root,
        _Auth(),
        writes: writes,
      );
      await presence.writeMyCaret(
        key,
        name: 'Owner',
        index: 0,
        generation: key,
        lineId: 'empty',
      );
      expect(db.read('presence/notes/$key/owner/index'), 0);
      await presence.clearMyCaret(key);
      expect(db.read('presence/notes/$key/owner'), isNull);

      await FirebaseDeviceTokenRepository(
        db.root,
        _Auth(),
        writes: writes,
      ).register('token.with.invalid/key');
      expect(db.read('users/owner/fcmTokens'), isNotEmpty);
      await leaflets.leaveLeaflet(leaflet);
      expect(db.read('userLeaflets/owner/$key'), isNull);
      expect(db.pending.every((server) => !server.isCompleted), isTrue);
    },
    timeout: const Timeout(Duration(seconds: 5)),
  );

  test(
    'late note rejection remains observable after local save completes',
    () async {
      final failures = <FirebaseWriteFailure>[];
      final subscription = writes.failures.listen(failures.add);
      addTearDown(subscription.cancel);
      final key = await leaflets.addLeaflet('Trip', coverEmoji: 'A');
      final note = NoteDocument.parse(await notes.watchNote(key).first);
      final line = note.visibleLines.single.edit(
        '[{"insert":"edited\\n"}]',
        'w2',
      );
      await notes.saveNoteLines(key, note.generation, {line.id: line});
      db.pending.last.completeError(
        FirebaseException(
          plugin: 'firebase_database',
          code: 'permission-denied',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(failures, hasLength(1));
      expect(failures.single.note, isTrue);
    },
  );

  test(
    'server-required operations fail offline without enqueueing changes',
    () async {
      final key = await leaflets.addLeaflet('Trip', coverEmoji: 'A');
      final leaflet = (await leaflets.watchLeaflets().first).single;
      final before = db.pending.length;
      await expectLater(
        leaflets.deleteLeaflet(leaflet),
        throwsA(isA<FirebaseException>()),
      );
      await expectLater(
        leaflets.disableSharing(leaflet),
        throwsA(isA<FirebaseException>()),
      );
      await expectLater(
        notes.resetNote(
          key,
          db.read('rich_notes/$key'),
          const NoteDocument('replacement', {}),
        ),
        throwsA(isA<FirebaseException>()),
      );
      await expectLater(
        leaflets.joinLeaflet(key, 'password'),
        throwsA(isA<JoinFailure>()),
      );
      expect(db.pending, hasLength(before));
    },
  );
}
