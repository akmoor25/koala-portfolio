import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/data/app_services.dart';
import 'package:koala/data/data_types.dart';
import 'package:koala/data/firebase/firebase_services.dart';
import 'package:koala/entity/leaflet_entity.dart';
import 'package:koala/notes/note_document.dart';
import 'package:koala/notes/note_model.dart';
import 'package:koala/notes/remote_caret.dart';

import '../support/demo_database.dart';
import '../support/localized_app.dart';
import '../support/note_fixtures.dart';

Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DemoDatabase db;
  late AppServices services;
  late LeafletEntity leaflet;
  late NoteRepositoryProbe notes;

  setUp(() async {
    db = DemoDatabase();
    services = db.services;
    leaflet = (await services.leaflets.watchLeaflets().first).first;
    notes = NoteRepositoryProbe(services.notes);
    await seedNote(notes, leaflet.key, '[{"insert":"one\\ntwo\\n"}]');
  });

  Future<NoteModel> open([FirebaseNoteRepository? repository]) async {
    final model = NoteModel(
      leaflet,
      withNoteRepository(services, repository ?? notes),
    );
    model.l10n = ja;
    addTearDown(model.dispose);
    await model.fetchNote();
    await settle();
    return model;
  }

  String text(NoteModel model) => model.quillController.document.toPlainText();

  test(
    'reads formatted paragraphs and never echoes received changes',
    () async {
      final model = await open();
      expect(text(model), 'one\ntwo\n');
      expect(notes.batches, isEmpty);
      await seedNote(
        notes,
        leaflet.key,
        '[{"insert":"bold","attributes":{"bold":true}},{"insert":"\\n"}]',
      );
      await settle();
      expect(text(model), 'bold\n');
      expect(notes.batches, isEmpty);
    },
  );

  testWidgets(
    'debounces edits for 300ms and sends only the changed paragraph',
    (tester) async {
      final model = NoteModel(leaflet, withNoteRepository(services, notes));
      addTearDown(model.dispose);
      await model.fetchNote();
      await tester.pump();
      model.quillController.replaceText(0, 0, 'a', null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 299));
      expect(notes.batches, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(notes.batches, hasLength(1));
      expect(notes.batches.single, hasLength(1));
      expect(
        notes.batches.single.values.single.delta,
        '[{"insert":"aone\\n"}]',
      );
    },
  );

  test('different pending paragraphs are preserved on both clients', () async {
    final a = await open();
    final b = await open(services.notes);
    a.quillController.replaceText(0, 0, 'A', null);
    b.quillController.replaceText(4, 0, 'B', null);
    await settle();
    await a.putText();
    await settle();
    expect(text(b), 'Aone\nBtwo\n');
    await b.putText();
    await settle();
    expect(text(a), 'Aone\nBtwo\n');
    expect(text(b), text(a));
  });

  test('same paragraph uses last saved content', () async {
    final a = await open();
    final b = await open(services.notes);
    a.quillController.replaceText(0, 0, 'A', null);
    b.quillController.replaceText(0, 0, 'B', null);
    await settle();
    await a.putText();
    await settle();
    await b.putText();
    await settle();
    expect(text(a), 'Bone\ntwo\n');
    expect(text(b), text(a));
  });

  test(
    'paragraph and inline formatting are saved without echoing or flattening',
    () async {
      final a = await open();
      final b = await open(services.notes);
      a.quillController.formatText(0, 3, Attribute.bold);
      a.quillController.formatText(0, 4, Attribute.h1);
      a.quillController.formatText(4, 4, Attribute.ul);
      await a.putText();
      await settle();
      expect(
        b.quillController.document.toDelta(),
        a.quillController.document.toDelta(),
      );
      final ops = b.quillController.document.toDelta().toJson();
      expect(ops.first['attributes'], {'bold': true});
      expect(ops[1]['attributes'], {'header': 1});
      expect(ops.last['attributes'], {'list': 'bullet'});
    },
  );

  test(
    'undoing my change retains another paragraph received meanwhile',
    () async {
      final a = await open();
      final b = await open(services.notes);
      a.quillController.replaceText(0, 0, 'A', null);
      b.quillController.replaceText(4, 0, 'B', null);
      await b.putText();
      await settle();
      a.quillController.undo();
      await settle();
      expect(text(a), 'one\nBtwo\n');
      await a.putText();
      await settle();
      expect(text(b), text(a));
    },
  );

  test('a deleted paragraph cannot be restored by a pending edit', () async {
    final a = await open();
    final b = await open(services.notes);
    b.quillController.replaceText(4, 0, 'B', null);
    a.quillController.replaceText(3, 4, '', null);
    await settle();
    await a.putText();
    await settle();
    await b.putText();
    await settle();
    expect(text(a), 'one\n');
    expect(text(b), text(a));
  });

  test(
    'deleting a whole paragraph does not delete edits to the next paragraph',
    () async {
      final a = await open();
      final b = await open(services.notes);
      a.quillController.replaceText(0, 4, '', null);
      b.quillController.replaceText(4, 0, 'B', null);
      await a.putText();
      await settle();
      expect(text(b), 'Btwo\n');
      await b.putText();
      await settle();
      expect(text(a), text(b));
      expect(notes.batches.single, hasLength(1));
      expect(notes.batches.single.values.single.deleted, isTrue);
    },
  );

  test(
    'new edits during an in-flight save are not cleared by its completion',
    () async {
      final model = await open();
      notes.delay = Completer<void>();
      model.quillController.replaceText(0, 0, 'a', null);
      await settle();
      final saving = model.putText();
      model.quillController.replaceText(1, 0, 'b', null);
      await settle();
      notes.delay!.complete();
      await saving;
      await settle();
      expect(notes.batches, hasLength(2));
      expect(text(model), 'abone\ntwo\n');
      expect(model.hasUnsavedChanges, isFalse);
    },
  );

  test('failed saves retain edits and report once until success', () async {
    final model = await open();
    final messages = <String>[];
    model.onWriteError = messages.add;
    notes.fail = true;
    model.quillController.replaceText(0, 0, 'a', null);
    await settle();
    expect(await model.putText(), isFalse);
    expect(await model.putText(), isFalse);
    expect(model.hasUnsavedChanges, isTrue);
    expect(messages, [ja.noteSaveFailed]);
    notes.fail = false;
    expect(await model.putText(), isTrue);
    expect(text(model), 'aone\ntwo\n');
  });

  for (final fail in [false, true]) {
    test(
      'closing the editor stops follow-up saves and notifications (failure: $fail)',
      () async {
        final model = await open();
        final messages = <String>[];
        model.onWriteError = messages.add;
        notes.delay = Completer<void>();
        notes.fail = fail;
        model.quillController.replaceText(0, 0, 'a', null);
        final saving = model.putText();
        model.quillController.replaceText(1, 0, 'b', null);
        var notifications = 0;
        model.addListener(() => notifications++);
        model.stopEditing();
        expect(model.ready, isFalse);
        model.quillController.replaceText(0, 0, 'ignored', null);
        notes.delay!.complete();
        expect(await saving, !fail);
        await settle();
        expect(notes.batches, hasLength(1));
        expect(notes.batches.single.values.single.delta, contains('aone'));
        expect(text(model), 'abone\ntwo\n');
        expect(messages, isEmpty);
        expect(notifications, 0);
      },
    );
  }

  test(
    'a read error never authorizes discarding a previously unreadable note',
    () async {
      db.setSimulatedNote(leaflet.key, {'text': 'legacy'});
      final model = await open();
      notes.readError = Exception('permission-denied');
      await model.retryRead();
      await settle();
      expect(model.readFailed, isTrue);
      expect(model.ready, isFalse);
      expect(await model.resetUnreadableNote(model.unreadableValue), isFalse);
      expect(await services.notes.watchNote(leaflet.key).first, {
        'text': 'legacy',
      });
      notes.readError = null;
      await model.retryRead();
      await settle();
      expect(model.readFailed, isFalse);
      expect(model.invalidFormat, isTrue);
    },
  );

  test(
    'received excess is retained, reported, and can only be reduced',
    () async {
      final model = await open();
      final messages = <String>[];
      model.onWriteError = messages.add;
      await seedNote(notes, leaflet.key, '[{"insert":"${r'\n' * 501}"}]');
      await settle();
      expect(
        model.quillController.document.toDelta(),
        Delta()..insert('\n' * 501),
      );
      expect(messages, contains(ja.noteReceivedLimit));
      model.quillController.replaceText(0, 0, '\n', null);
      expect(text(model), '\n' * 501);
      model.quillController.replaceText(0, 1, '', null);
      expect(text(model), '\n' * 500);
      expect(await model.putText(), isTrue);
    },
  );

  test(
    'a rejected batch retains another paragraph when one was deleted',
    () async {
      final a = await open();
      final b = await open(services.notes);
      a.quillController.replaceText(0, 0, 'A', null);
      a.quillController.replaceText(5, 0, 'B', null);
      notes.delay = Completer<void>();
      final saving = a.putText();
      b.quillController.replaceText(3, 4, '', null);
      await b.putText();
      await settle();
      notes.delay!.complete();
      expect(await saving, isFalse);
      expect(a.hasUnsavedChanges, isTrue);
      expect(text(a), 'Aone\n');
      expect(await a.putText(), isTrue);
      await settle();
      expect(text(b), 'Aone\n');
    },
  );

  test(
    'accepts and saves 1000 characters but rejects a whole over-limit edit',
    () async {
      final model = await open();
      final messages = <String>[];
      model.onWriteError = messages.add;
      model.quillController.replaceText(0, 0, 'x' * 998, null);
      await settle();
      expect(text(model), 'one\ntwo\n');
      expect(messages, [ja.noteLimit]);
      expect(notes.batches, isEmpty);
      model.quillController.replaceText(0, 0, 'x' * 997, null);
      await settle();
      final expected = '${'x' * 997}one\ntwo\n';
      expect(text(model), expected);
      expect(messages, [ja.noteLimit]);
      model.quillController.replaceText(0, 0, 'x', null);
      await settle();
      expect(text(model), expected);
      expect(messages, [ja.noteLimit, ja.noteLimit]);
      expect(await model.putText(), isTrue);
      final reopened = await open();
      expect(text(reopened), expected);
    },
  );

  test(
    'new note initializes once; unreadable data requires explicit reset',
    () async {
      db.setSimulatedNote(leaflet.key, {'text': 'old data'});
      final model = await open();
      expect(model.invalidFormat, isTrue);
      expect(model.ready, isFalse);
      expect(await services.notes.watchNote(leaflet.key).first, {
        'text': 'old data',
      });
      expect(await model.resetUnreadableNote(model.unreadableValue), isTrue);
      await settle();
      expect(model.ready, isTrue);
      expect(text(model), '\n');
    },
  );

  test('failed initialization is reported and can be retried without discarding data', () async {
    db.setSimulatedNote(leaflet.key, null);
    notes.fail = true;
    final model = await open();
    expect(model.ready, isFalse);
    expect(model.readFailed, isTrue);
    expect(model.invalidFormat, isFalse);
    expect(await services.notes.watchNote(leaflet.key).first, isNull);
    notes.fail = false;
    await model.retryRead();
    await settle();
    expect(model.ready, isTrue);
    expect(text(model), '\n');
  });

  test(
    'remote carets follow their paragraph and ignore unknown generations',
    () async {
      final model = await open();
      db.setSimulatedCaret(
        leaflet.key,
        const RemoteCaret(uid: 'friend', name: 'F', index: 5),
      );
      await settle();
      expect(model.remoteCarets.single.index, 5);
      model.quillController.replaceText(0, 0, 'new\n', null);
      await settle();
      expect(model.remoteCarets.single.index, 9);
      db.setSimulatedCaret(
        leaflet.key,
        const RemoteCaret(
          uid: 'friend',
          name: 'F',
          index: 1,
          generation: 'stale',
          lineId: 'missing',
        ),
      );
      await settle();
      expect(model.remoteCarets, isEmpty);
    },
  );

  test('stale generation writes fail after a reset', () async {
    final before = NoteDocument.parse(await notes.watchNote(leaflet.key).first);
    final replacement = NoteDocument.fromDelta(
      Delta()..insert('\n'),
      notes.newNoteId(),
      notes.newNoteId,
    );
    expect(
      await notes.resetNote(leaflet.key, before.toJson(), replacement),
      isTrue,
    );
    expect(
      notes.saveNoteLines(leaflet.key, before.generation, before.lines),
      throwsA(isA<DemoPermissionDenied>()),
    );
  });

  test('paragraph edits and splitting support undo and redo', () async {
    final model = await open();
    model.quillController.replaceText(1, 0, '\n', null);
    await settle();
    expect(text(model), 'o\nne\ntwo\n');
    await model.putText();
    model.quillController.undo();
    await settle();
    expect(text(model), 'one\ntwo\n');
    await model.putText();
    model.quillController.redo();
    await settle();
    await model.putText();
    expect(text(model), 'o\nne\ntwo\n');
  });

  testWidgets('hiding the app flushes a change without waiting 300ms', (
    tester,
  ) async {
    final model = NoteModel(leaflet, withNoteRepository(services, notes));
    addTearDown(model.dispose);
    await model.fetchNote();
    await tester.pump();
    model.quillController.replaceText(0, 0, 'a', null);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    expect(notes.batches, hasLength(1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 150));
  });

  test('an unconfirmed reset is reported separately from a failure', () async {
    db.setSimulatedNote(leaflet.key, {'text': 'old'});
    final model = await open();
    final messages = <String>[];
    model.onWriteError = messages.add;
    notes.resetError = const WriteUnconfirmed();
    expect(await model.resetUnreadableNote(model.unreadableValue), isFalse);
    expect(messages, [model.l10n.noteResetUnconfirmed]);
    notes.resetError = Exception('permission-denied');
    expect(await model.resetUnreadableNote(model.unreadableValue), isFalse);
    expect(messages.last, model.l10n.noteSaveFailed);
  });

  test(
    'a confirmation cannot discard data changed while the dialog is open',
    () async {
      db.setSimulatedNote(leaflet.key, {'text': 'old'});
      final model = await open();
      final confirmed = model.unreadableValue;
      await seedNote(notes, leaflet.key, '[{"insert":"new\\n"}]');
      await settle();
      expect(await model.resetUnreadableNote(confirmed), isFalse);
      expect(text(model), 'new\n');
    },
  );

  test(
    'a previously absent note initializes only once for both clients',
    () async {
      db.setSimulatedNote(leaflet.key, null);
      final a = await open();
      final b = await open();
      expect(a.ready, isTrue);
      expect(b.ready, isTrue);
      a.quillController.replaceText(0, 0, 'new', null);
      await settle();
      await a.putText();
      await settle();
      expect(text(b), 'new\n');
    },
  );

  test(
    'same-position concurrent paragraph insertion keeps both and converges',
    () async {
      final a = await open();
      final b = await open();
      a.quillController.replaceText(4, 0, 'A\n', null);
      b.quillController.replaceText(4, 0, 'B\n', null);
      await settle();
      await b.putText();
      await settle();
      await a.putText();
      await settle();
      expect(text(a), text(b));
      expect(text(a), contains('A\n'));
      expect(text(a), contains('B\n'));
      expect(text(a).split('\n'), hasLength(5));
    },
  );

  testWidgets('continuous typing is sent by the two-second deadline', (
    tester,
  ) async {
    final model = NoteModel(leaflet, withNoteRepository(services, notes));
    addTearDown(model.dispose);
    await model.fetchNote();
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      model.quillController.replaceText(0, 0, 'x', null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pump();
    expect(notes.batches, hasLength(1));
    expect(notes.batches.single.values.single.delta, contains('xxxxxxxxxxone'));
  });
}
