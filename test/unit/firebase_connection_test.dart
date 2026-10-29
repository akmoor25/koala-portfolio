import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/data/data_types.dart';
import 'package:koala/data/firebase/firebase_services.dart';
import 'package:koala/entity/leaflet_entity.dart';
import 'package:koala/notes/note_document.dart';

/// `.info/connected` と、読み取り・書き込みの応答を、テストから操作する。
class _Server {
  final changes = StreamController<bool>.broadcast();
  bool? initial;
  int listeners = 0;
  bool hangReads = false;
  bool hangWrites = false;

  void connect(bool value) => changes.add(value);
}

class _Reference implements DatabaseReference {
  _Reference(this.server, this.path);

  final _Server server;

  @override
  final String path;

  @override
  String? get key => path.split('/').last;

  @override
  DatabaseReference child(String path) => _Reference(
    server,
    [this.path, path].where((part) => part.isNotEmpty).join('/'),
  );

  @override
  Stream<DatabaseEvent> get onValue => Stream.multi((controller) {
    expect(path, '.info/connected');
    server.listeners++;
    if (server.initial case final value?) {
      controller.add(_Event(_Snapshot(key, value)));
    }
    final subscription = server.changes.stream.listen(
      (value) => controller.add(_Event(_Snapshot(key, value))),
    );
    controller.onCancel = () {
      server.listeners--;
      return subscription.cancel();
    };
  });

  @override
  Future<DataSnapshot> get() => server.hangReads
      ? Completer<DataSnapshot>().future
      : Future.value(_Snapshot(key, null));

  Future<void> _write() =>
      server.hangWrites ? Completer<void>().future : Future.value();

  @override
  Future<void> update(Map<String, Object?> value) => _write();

  @override
  Future<void> remove() => _write();

  @override
  Future<TransactionResult> runTransaction(
    TransactionHandler transactionHandler, {
    bool applyLocally = true,
  }) => Completer<TransactionResult>().future;

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
  Iterable<DataSnapshot> get children => const [];

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

final _trip = LeafletEntity(
  'TRIPKEY00001',
  'Trip',
  'A',
  null,
  null,
  null,
  ownerUid: 'owner',
);

Matcher _disconnected() => throwsA(
  isA<FirebaseException>().having((e) => e.code, 'code', 'disconnected'),
);

void main() {
  late _Server server;
  late _Reference root;
  late FirebaseLeafletRepository leaflets;

  setUp(() {
    server = _Server();
    root = _Reference(server, '');
    leaflets = FirebaseLeafletRepository(root, _Auth());
  });

  tearDown(() => unawaited(server.changes.close()));

  group('requireFirebaseConnection', () {
    test('an initial true succeeds without waiting', () async {
      server.initial = true;
      await requireFirebaseConnection(root).timeout(const Duration(seconds: 1));
      expect(server.listeners, 0);
    });

    testWidgets('true arriving within 2 seconds after false succeeds', (
      tester,
    ) async {
      server.initial = false;
      var done = false;
      unawaited(requireFirebaseConnection(root).then((_) => done = true));
      await tester.pump(const Duration(milliseconds: 1500));
      expect(done, isFalse);
      server.connect(true);
      await tester.pump();
      expect(done, isTrue);
      expect(server.listeners, 0);
    });

    testWidgets('remaining false for 2 seconds is disconnected', (
      tester,
    ) async {
      server.initial = false;
      final result = expectLater(
        requireFirebaseConnection(root),
        _disconnected(),
      );
      await tester.pump(const Duration(milliseconds: 1999));
      expect(server.listeners, 1);
      await tester.pump(const Duration(milliseconds: 1));
      await result;
      expect(server.listeners, 0);
    });

    testWidgets('no value within 15 seconds is disconnected', (tester) async {
      final result = expectLater(
        requireFirebaseConnection(root),
        _disconnected(),
      );
      await tester.pump(const Duration(seconds: 15));
      await result;
      expect(server.listeners, 0);
    });

    testWidgets('repositories use the injected grace period', (tester) async {
      server.initial = false;
      var failed = false;
      unawaited(
        FirebaseLeafletRepository(
          root,
          _Auth(),
          connectionGrace: const Duration(milliseconds: 500),
        ).deleteLeaflet(_trip).catchError((Object _) => failed = true),
      );
      await tester.pump(const Duration(milliseconds: 499));
      expect(failed, isFalse);
      await tester.pump(const Duration(milliseconds: 1));
      expect(failed, isTrue);
      expect(server.listeners, 0);
    });
  });

  group('server write timeouts', () {
    setUp(() => server.initial = true);

    Future<void> expectAfterTimeout(
      WidgetTester tester,
      Future<Object?> operation,
      Matcher matcher,
    ) async {
      final result = expectLater(operation, matcher);
      await tester.pump();
      await tester.pump(const Duration(seconds: 15));
      await result;
    }

    testWidgets('a sent deletion is unconfirmed, not failed', (tester) async {
      server.hangWrites = true;
      await expectAfterTimeout(
        tester,
        leaflets.deleteLeaflet(_trip),
        throwsA(isA<WriteUnconfirmed>()),
      );
    });

    testWidgets('a stalled read before deletion stays a failure', (
      tester,
    ) async {
      server.hangReads = true;
      await expectAfterTimeout(
        tester,
        leaflets.deleteLeaflet(_trip),
        throwsA(isA<TimeoutException>()),
      );
    });

    testWidgets('a sent sharing stop is unconfirmed', (tester) async {
      server.hangWrites = true;
      await expectAfterTimeout(
        tester,
        leaflets.disableSharing(_trip),
        throwsA(isA<WriteUnconfirmed>()),
      );
    });

    testWidgets('a sent join is unconfirmed, a stalled read is a failure', (
      tester,
    ) async {
      Matcher reason(JoinFailureReason value) =>
          throwsA(isA<JoinFailure>().having((e) => e.reason, 'reason', value));
      server.hangWrites = true;
      await expectAfterTimeout(
        tester,
        leaflets.joinLeaflet(_trip.key, 'password'),
        reason(JoinFailureReason.unconfirmed),
      );
      server
        ..hangWrites = false
        ..hangReads = true;
      await expectAfterTimeout(
        tester,
        leaflets.joinLeaflet(_trip.key, 'password'),
        reason(JoinFailureReason.network),
      );
    });

    testWidgets('a sent index removal is unconfirmed', (tester) async {
      server.hangWrites = true;
      await expectAfterTimeout(
        tester,
        leaflets.removeMyIndex(),
        throwsA(isA<WriteUnconfirmed>()),
      );
    });

    testWidgets('a sent note reset is unconfirmed', (tester) async {
      await expectAfterTimeout(
        tester,
        FirebaseNoteRepository(root)
            .resetNote(_trip.key, null, const NoteDocument('next', {})),
        throwsA(isA<WriteUnconfirmed>()),
      );
    });

    testWidgets('an offline operation is disconnected without waiting 15s', (
      tester,
    ) async {
      server.initial = false;
      final result = expectLater(
        leaflets.deleteLeaflet(_trip),
        _disconnected(),
      );
      await tester.pump(const Duration(seconds: 2));
      await result;
    });
  });
}
