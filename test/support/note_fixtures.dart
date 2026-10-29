import 'dart:async';
import 'dart:convert';

import 'package:flutter_quill/quill_delta.dart';
import 'package:koala/data/app_services.dart';
import 'package:koala/data/firebase/firebase_services.dart';
import 'package:koala/notes/note_document.dart';

class NoteRepositoryProbe implements FirebaseNoteRepository {
  NoteRepositoryProbe(this.base);

  final FirebaseNoteRepository base;
  final batches = <Map<String, NoteLine>>[];
  int resets = 0;
  bool fail = false;
  Exception? resetError;
  Object? readError;
  Stream<Object?>? readStream;
  Completer<void>? delay;

  @override
  String newNoteId() => base.newNoteId();

  @override
  Future<void> createNote(String key, NoteDocument document) =>
      base.createNote(key, document);

  @override
  Stream<Object?> watchNote(String key) {
    if (readStream != null) return readStream!;
    final error = readError;
    return error == null
        ? base.watchNote(key)
        : Stream<Object?>.multi((controller) => controller.addErrorSync(error));
  }

  @override
  Future<bool> resetNote(
    String key,
    Object? expected,
    NoteDocument next,
  ) async {
    resets++;
    await delay?.future;
    if (fail) throw Exception('permission-denied');
    if (resetError case final error?) throw error;
    return base.resetNote(key, expected, next);
  }

  @override
  Future<void> saveNoteLines(
    String key,
    String generation,
    Map<String, NoteLine> changes,
  ) async {
    batches.add(Map.of(changes));
    await delay?.future;
    if (fail) throw Exception('permission-denied');
    await base.saveNoteLines(key, generation, changes);
  }
}

AppServices withNoteRepository(
  AppServices base,
  FirebaseNoteRepository notes,
) => AppServices(
  auth: base.auth,
  leaflets: base.leaflets,
  marks: base.marks,
  notes: notes,
  presence: base.presence,
  passphrases: base.passphrases,
  widget: base.widget,
  deviceName: base.deviceName,
  push: base.push,
  deviceTokens: base.deviceTokens,
);

Future<void> seedNote(
  FirebaseNoteRepository notes,
  String key,
  String delta,
) async {
  final expected = await notes.watchNote(key).first;
  final note = NoteDocument.fromDelta(
    Delta.fromJson(jsonDecode(delta) as List<Object?>),
    notes.newNoteId(),
    notes.newNoteId,
  );
  if (!await notes.resetNote(key, expected, note)) {
    throw StateError('The fixture was changed concurrently');
  }
}
