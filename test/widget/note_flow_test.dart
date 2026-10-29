import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/data/app_services.dart';
import 'package:koala/marks/marks_screen.dart';
import 'package:koala/notes/note_colors.dart';
import 'package:koala/notes/note_document.dart';
import 'package:koala/notes/note_model.dart';
import 'package:koala/notes/note_screen.dart';
import 'package:koala/notes/remote_caret.dart';
import 'package:provider/provider.dart';

import '../support/app_flows.dart';
import '../support/demo_data.dart';
import '../support/demo_database.dart';
import '../support/localized_app.dart';
import '../support/note_fixtures.dart';

/// エディタが持つ文書の本文。Quill は文字を `RichText` ではなく独自の描画で出すため、
/// 画面の文字検索では見つからない。
String _noteText(WidgetTester tester) {
  final model = Provider.of<NoteModel>(
    tester.element(find.byType(QuillEditor)),
    listen: false,
  );
  return model.quillController.document.toPlainText();
}

Future<void> _openNote(WidgetTester tester, AppServices services) async {
  await openLeafletList(tester, services);
  await openLeaflet(tester, demoTripTitle);
  await openNote(tester);
}

void main() {
  late DemoDatabase db;

  setUp(() => db = DemoDatabase());

  testWidgets('opens the note of a leaflet with its saved text', (
    tester,
  ) async {
    await _openNote(tester, db.services);

    expect(tester.takeException(), isNull);
    expect(find.byType(NoteScreen), findsOneWidget);
    expect(find.byType(QuillEditor), findsOneWidget);
    expect(_noteText(tester), contains(demoNoteLine));
  });

  testWidgets('text colors exclude black and white, and backgrounds are off', (
    tester,
  ) async {
    await _openNote(tester, db.services);
    final model = Provider.of<NoteModel>(
      tester.element(find.byType(QuillEditor)),
      listen: false,
    );
    model.quillController.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 3),
      ChangeSource.local,
    );
    await tester.pump();

    expect(find.byIcon(Icons.format_color_fill), findsNothing);
    await tester.ensureVisible(find.byIcon(Icons.color_lens));
    await tester.tap(find.byIcon(Icons.color_lens));
    await tester.pumpAndSettle();

    expect(find.text(ja.noteColorTitle), findsOneWidget);
    for (final color in NoteTextColor.values) {
      expect(find.byTooltip(color.label(ja)), findsOneWidget);
    }
    expect(
      tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(Container),
            ),
          )
          .map((c) => (c.decoration as BoxDecoration?)?.color)
          .whereType<Color>(),
      everyElement(predicate<Color>(isReadableNoteTextColor)),
    );

    await tester.tap(find.byTooltip(ja.noteColorBlue));
    await tester.pumpAndSettle();
    final first = model.quillController.document.toDelta().first;
    expect(first.attributes?['color'], NoteTextColor.blue.hex);

    await tester.tap(find.byIcon(Icons.color_lens));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ja.noteColorDefault));
    await tester.pumpAndSettle();
    expect(
      model.quillController.document.toDelta().first.attributes?['color'],
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows who else is editing and where their caret is', (
    tester,
  ) async {
    await _openNote(tester, db.services);
    expect(find.text(ja.othersEditing(1)), findsNothing);

    db.setSimulatedCaret(
      demoTripKey,
      const RemoteCaret(uid: 'demo-friend', name: 'F', index: 3),
    );
    await tester.pumpAndSettle();

    expect(find.text(ja.othersEditing(1)), findsOneWidget);
    expect(tester.takeException(), isNull);

    db.setSimulatedCaret(demoTripKey, null);
    await tester.pumpAndSettle();
    expect(find.text(ja.othersEditing(1)), findsNothing);
  });

  testWidgets('a note changed by someone else appears', (tester) async {
    await _openNote(tester, db.services);

    await seedNote(
      db.servicesFor('demo-friend').notes,
      demoTripKey,
      '[{"insert":"友だちが書いた一文\\n"}]',
    );
    await tester.pumpAndSettle();

    expect(_noteText(tester), contains('友だちが書いた一文'));
  });

  testWidgets('leaving the note clears my presence', (tester) async {
    await _openNote(tester, db.services);

    await goBack(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(QuillEditor), findsNothing);
  });

  for (final buffered in [false, true]) {
    testWidgets(
      'deleting the open trip returns to the list (buffered: $buffered)',
      (tester) async {
        final notes = NoteRepositoryProbe(db.services.notes);
        await _openNote(tester, withNoteRepository(db.services, notes));
        if (buffered) {
          final model = Provider.of<NoteModel>(
            tester.element(find.byType(QuillEditor)),
            listen: false,
          );
          model.quillController.replaceText(0, 0, 'pending', null);
          await tester.pump();
        }
        final leaflet = (await db.services.leaflets.watchLeaflets().first)
            .firstWhere((item) => item.key == demoTripKey);
        await db.services.leaflets.deleteLeaflet(leaflet);
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(NoteScreen), findsNothing);
        expect(find.byType(MarksScreen), findsNothing);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text(ja.tripNoLongerAvailable), findsOneWidget);
        expect(notes.batches, isEmpty);
        expect(notes.resets, 0);
        expect(await db.services.notes.watchNote(demoTripKey).first, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final readFails in [false, true]) {
    testWidgets(
      'access loss closes a saving note before late failure (read error: $readFails)',
      (tester) async {
        final updates = StreamController<Object?>();
        addTearDown(updates.close);
        updates.add(await db.services.notes.watchNote(demoTripKey).first);
        final notes = NoteRepositoryProbe(db.services.notes)
          ..readStream = updates.stream
          ..delay = Completer<void>();
        await _openNote(tester, withNoteRepository(db.services, notes));
        final model = Provider.of<NoteModel>(
          tester.element(find.byType(QuillEditor)),
          listen: false,
        );
        final messages = <String>[];
        final showMessage = model.onWriteError!;
        model.onWriteError = (message) {
          messages.add(message);
          showMessage(message);
        };
        model.quillController.replaceText(0, 0, 'pending', null);
        final saving = model.putText();
        notes.fail = true;
        if (readFails) {
          updates.addError(Exception('permission-denied'));
        } else {
          updates.add(null);
        }
        await tester.pump();
        expect(find.byType(AlertDialog), findsNothing);
        expect(notes.resets, readFails ? 0 : 1);

        final leaflet = (await db.services.leaflets.watchLeaflets().first)
            .firstWhere((item) => item.key == demoTripKey);
        await db.services.leaflets.deleteLeaflet(leaflet);
        await tester.pumpAndSettle();
        final messagesBeforeCompletion = List<String>.of(messages);
        notes.delay!.complete();
        expect(await saving, isFalse);
        await tester.pumpAndSettle();

        expect(find.byType(NoteScreen), findsNothing);
        expect(find.byType(MarksScreen), findsNothing);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text(ja.tripNoLongerAvailable), findsOneWidget);
        expect(messages, messagesBeforeCompletion);
        expect(notes.batches, hasLength(1));
        expect(await db.services.notes.watchNote(demoTripKey).first, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'unreadable data is kept on cancel and discarded only on confirmation',
    (tester) async {
      db.setSimulatedNote(demoTripKey, {'text': 'legacy'});
      await _openNote(tester, db.services);
      await tester.pumpAndSettle();
      expect(inDialog(find.text(ja.noteUnreadable)), findsOneWidget);
      await tester.tap(inDialog(find.text(ja.cancel)));
      await tester.pumpAndSettle();
      expect(await db.services.notes.watchNote(demoTripKey).first, {
        'text': 'legacy',
      });
      expect(find.byType(QuillEditor), findsNothing);
      await tester.tap(find.text(ja.noteRetry));
      await tester.pumpAndSettle();
      await tester.tap(inDialog(find.text(ja.noteDiscard)));
      await tester.pumpAndSettle();
      expect(find.byType(QuillEditor), findsOneWidget);
      expect(_noteText(tester), '\n');
    },
  );

  testWidgets('normal back flushes the buffered edit before leaving', (
    tester,
  ) async {
    await _openNote(tester, db.services);
    final model = Provider.of<NoteModel>(
      tester.element(find.byType(QuillEditor)),
      listen: false,
    );
    model.quillController.replaceText(0, 0, 'saved on back', null);
    await tester.pump();
    await tester.tap(find.byType(BackButton).last);
    await tester.pumpAndSettle();
    expect(find.byType(QuillEditor), findsNothing);
    final note = NoteDocument.parse(
      await db.services.notes.watchNote(demoTripKey).first,
    );
    expect(note.visibleLines.first.delta, contains('saved on back'));
  });

  testWidgets('a read failure preserves data and offers no destructive reset', (
    tester,
  ) async {
    final notes = NoteRepositoryProbe(db.services.notes)
      ..readError = Exception('permission-denied');
    await _openNote(tester, withNoteRepository(db.services, notes));
    expect(find.text(ja.noteReadFailed), findsOneWidget);
    expect(find.text(ja.noteRetry), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(QuillEditor), findsNothing);
    final saved = NoteDocument.parse(
      await db.services.notes.watchNote(demoTripKey).first,
    );
    expect(
      saved.visibleLines.map((line) => line.delta).join(),
      contains(demoNoteLine),
    );
  });

  testWidgets('confirming a reset cannot erase content changed in the dialog', (
    tester,
  ) async {
    db.setSimulatedNote(demoTripKey, {'text': 'legacy'});
    await _openNote(tester, db.services);
    await seedNote(db.services.notes, demoTripKey, '[{"insert":"new\\n"}]');
    await tester.pumpAndSettle();
    await tester.tap(inDialog(find.text(ja.noteDiscard)));
    await tester.pumpAndSettle();
    expect(_noteText(tester), 'new\n');
    expect(find.byType(AlertDialog), findsNothing);
  });

  for (final timeout in [false, true]) {
    testWidgets(
      'failed leave allows retry or explicit unsaved exit (timeout: $timeout)',
      (tester) async {
        final notes = NoteRepositoryProbe(db.services.notes);
        if (timeout) {
          notes.delay = Completer<void>();
        } else {
          notes.fail = true;
        }
        await _openNote(tester, withNoteRepository(db.services, notes));
        final model = Provider.of<NoteModel>(
          tester.element(find.byType(QuillEditor)),
          listen: false,
        );
        model.quillController.replaceText(0, 0, 'pending', null);
        await tester.tap(find.byType(BackButton).last);
        await tester.pump();
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        expect(inDialog(find.text(ja.noteKeepEditing)), findsOneWidget);
        await tester.tap(inDialog(find.text(ja.noteKeepEditing)));
        await tester.pumpAndSettle();
        expect(_noteText(tester), startsWith('pending'));
        expect(model.hasUnsavedChanges, isTrue);
        if (timeout) {
          notes.delay!.complete();
        } else {
          notes.fail = false;
        }
        expect(await model.putText(), isTrue);
        notes.fail = true;
        model.quillController.replaceText(0, 0, 'unsaved', null);
        await tester.tap(find.byType(BackButton).last);
        await tester.pumpAndSettle();
        await tester.tap(inDialog(find.text(ja.noteLeaveUnsaved)));
        await tester.pumpAndSettle();
        expect(find.byType(QuillEditor), findsNothing);
        final saved = NoteDocument.parse(
          await db.services.notes.watchNote(demoTripKey).first,
        );
        expect(saved.visibleLines.first.delta, contains('pending'));
        expect(saved.visibleLines.first.delta, isNot(contains('unsaved')));
      },
    );
  }

  testWidgets(
    'Japanese composing input survives an update to another paragraph',
    (tester) async {
      await seedNote(db.services.notes, demoTripKey, '[{"insert":"a\\nb\\n"}]');
      await _openNote(tester, db.services);
      final model = Provider.of<NoteModel>(
        tester.element(find.byType(QuillEditor)),
        listen: false,
      );
      model.editorFocusNode.requestFocus();
      model.quillController.updateSelection(
        const TextSelection.collapsed(offset: 0),
        ChangeSource.local,
      );
      await tester.pump();
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'かa\nb\n',
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange(start: 0, end: 1),
        ),
      );
      await tester.pump();
      expect(_noteText(tester), 'かa\nb\n');
      final remote = NoteDocument.parse(
        await db.services.notes.watchNote(demoTripKey).first,
      );
      final second = remote.visibleLines[1];
      await db.services.notes.saveNoteLines(demoTripKey, remote.generation, {
        second.id: second.edit('[{"insert":"B\\n"}]', 'remote-edit'),
      });
      await tester.pump();
      expect(_noteText(tester), 'かa\nB\n');
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'かきa\nB\n',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        ),
      );
      await tester.pump();
      expect(_noteText(tester), 'かきa\nB\n');
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'かきa\nB\n',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      model.editorFocusNode.unfocus();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    },
  );
}
