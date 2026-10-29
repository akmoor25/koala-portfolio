import 'dart:async';
import 'dart:convert';

import 'package:flutter_quill/quill_delta.dart';
import 'package:koala/data/app_services.dart';
import 'package:koala/data/data_types.dart';
import 'package:koala/data/firebase/firebase_services.dart';
import 'package:koala/entity/leaflet_entity.dart';
import 'package:koala/entity/mark_entity.dart';
import 'package:koala/helper/deep_equals.dart';
import 'package:koala/helper/device_name.dart';
import 'package:koala/helper/secure_passphrase_store.dart';
import 'package:koala/helper/trip_widget_publisher.dart';
import 'package:koala/notes/note_document.dart';
import 'package:koala/notes/remote_caret.dart';
import 'package:koala/sharing/share_code.dart';

import 'demo_data.dart';
import 'demo_store.dart';
import 'fake_push.dart';

/// メモリ上だけに保持するデータの一式。Firebase に接続しない。
///
/// 各クラスは Firebase 実装を `implements` した偽物で、同じ [AppServices] として
/// 画面と Model から使える。Dart では、修飾子（`base`、`final` など）を付けない
/// クラスは暗黙的にインターフェースも持つので、本番のコードに抽象クラスを足さずに
/// 差し替えられる。
/// 複数の利用者を [servicesFor] で作れるため、共同編集（共有と参加）も
/// 1 つのデータで再現できる。
class DemoDatabase {
  /// [now] を基準にサンプルデータを入れて作る。
  DemoDatabase({DateTime? now, this.writeDelay = Duration.zero}) {
    for (final demo in buildDemoLeaflets(now ?? DateTime.now())) {
      _leaflets.value = [..._leaflets.value, demo.leaflet];
      _members[demo.leaflet.key] = {demoUserId};
      _marks[demo.leaflet.key] = LiveValue(demo.marks);
      final generation = 'demo-${demo.leaflet.key}';
      final bodies = splitNoteDelta(
        Delta.fromJson(jsonDecode(demo.noteText) as List<Object?>),
      );
      final lines = <String, NoteLine>{};
      for (var i = 0; i < bodies.length; i++) {
        final id = 'line-$i';
        lines[id] = NoteLine(
          id: id,
          generation: generation,
          afterId: i == 0 ? '' : 'line-${i - 1}',
          order: i + 1,
          writeId: id,
          delta: bodies[i],
        );
      }
      _notes[demo.leaflet.key] = LiveValue<Object?>(
        NoteDocument(generation, lines).toJson(),
      );
    }
  }

  /// 書き込みを完了するまでの待ち時間。進行中の UI を確認するテストで使う。
  final Duration writeDelay;

  Future<void> _waitForWrite() {
    if (writeDelay == Duration.zero) return Future<void>.value();
    return Future<void>.delayed(writeDelay);
  }

  final LiveValue<List<LeafletEntity>> _leaflets = LiveValue([]);
  final Map<String, Set<String>> _members = {};
  final Map<String, String> _secrets = {};
  final Map<String, LiveValue<List<MarkEntity>>> _marks = {};
  final Map<String, LiveValue<Object?>> _notes = {};
  final Map<String, LiveValue<Collaborators>> _carets = {};
  final Map<String, Map<String, RemoteCaret?>> _presenceEntries = {};
  final Map<String, String> _simulatedCaretIds = {};
  int _nextKey = 0;

  /// 既定の利用者（[demoUserId]）の [AppServices]。
  AppServices get services => servicesFor(demoUserId);

  /// [uid] の利用者としての [AppServices]。
  final Map<String, FakePushGateway> _pushes = {};

  /// 利用者ごとに、登録された端末のトークン。
  final Map<String, Set<String>> deviceTokens = {};

  /// [uid] の端末の FCM の偽物。同じ [uid] には、同じものを返す。
  FakePushGateway pushFor(String uid) =>
      _pushes.putIfAbsent(uid, FakePushGateway.new);

  AppServices servicesFor(String uid, {String? name}) {
    final auth = _DemoAuthGateway(this, uid, name);
    return AppServices(
      auth: auth,
      leaflets: _DemoLeafletRepository(this, uid),
      marks: _DemoMarkRepository(this),
      notes: _DemoNoteRepository(this),
      presence: _DemoPresenceRepository(this, uid),
      passphrases: _passphrases,
      widget: widget,
      deviceName: const FakeDeviceName(),
      push: pushFor(uid),
      deviceTokens: FakeDeviceTokens(uid, deviceTokens),
    );
  }

  /// 削除された匿名アカウントの uid。
  final List<String> deletedAccounts = [];

  /// 設定すると、アカウントの削除がこの例外で失敗する（`requires-recent-login` の再現など）。
  Exception? accountDeleteError;

  /// 設定すると、サーバー確認が必要な書き込み（削除・停止・参加・索引の削除）がこの例外で終わる。
  Exception? serverWriteError;

  void _throwServerWriteError() {
    if (serverWriteError case final error?) throw error;
  }

  /// サーバーから削除済みのアカウントを再現する。
  bool accountExists = true;
  Exception? accountCheckError;
  Future<void>? accountCheckWait;
  final List<String> signedOutAccounts = [];
  final StreamController<String> _signOuts = StreamController.broadcast();

  /// [uid] のアカウントが、利用中にサーバーで削除された（自動の掃除やコンソールでの削除）ことを再現する。
  ///
  /// Firebase Auth は、トークンの更新で気づいて、端末でもサインアウトする。
  void expireSession([String uid = demoUserId]) {
    accountExists = false;
    _signOuts.add(uid);
  }

  /// ホーム画面ウィジェットの偽物。全員で共有する。
  final FakeTripWidget widget = FakeTripWidget();

  final _MemoryPassphraseStore _passphrases = _MemoryPassphraseStore();

  String _newKey() => 'demo-new-${_nextKey++}';

  /// 一覧の購読者へ、メンバーの変化を知らせる。
  void _notifyLeaflets() => _leaflets.value = [..._leaflets.value];

  LiveValue<List<MarkEntity>> _marksOf(String key) =>
      _marks.putIfAbsent(key, () => LiveValue(const []));

  LiveValue<Object?> _noteOf(String key) =>
      _notes.putIfAbsent(key, () => LiveValue<Object?>(null));

  LiveValue<Collaborators> _caretsOf(String key) =>
      _carets.putIfAbsent(key, () => LiveValue(Collaborators.none));

  /// 読めない保存データも、破棄確認のテストで再現する。
  void setSimulatedNote(String leafletKey, Object? value) {
    _noteOf(leafletKey).value = value;
  }

  /// 疑似メンバーのカーソルを置く。共同編集の画面で、他のメンバーの表示を確かめるために使う。
  void setSimulatedCaret(String leafletKey, RemoteCaret? caret) {
    final entries = _presenceEntries.putIfAbsent(leafletKey, () => {});
    final previous = _simulatedCaretIds.remove(leafletKey);
    if (previous != null) entries.remove(previous);
    if (caret != null) {
      var anchored = caret;
      if (caret.generation == null) {
        final note = NoteDocument.parse(_noteOf(leafletKey).value);
        var start = 0;
        for (final line in note.visibleLines) {
          final length = lineLength(line.delta!);
          if (caret.index < start + length) {
            anchored = RemoteCaret(
              uid: caret.uid,
              name: caret.name,
              index: caret.index - start,
              generation: note.generation,
              lineId: line.id,
            );
            break;
          }
          start += length;
        }
      }
      _simulatedCaretIds[leafletKey] = caret.uid;
      entries[caret.uid] = anchored;
    }
    _emitCarets(leafletKey);
  }

  void _emitCarets(String key) {
    final entries = _presenceEntries[key] ?? {};
    _caretsOf(key).value = Collaborators(
      editingCount: entries.length,
      carets: [for (final caret in entries.values) ?caret],
    );
  }
}

/// オーナーでない人が、オーナーだけの操作をしたことを表す。
///
/// 本物の接続先では、データベースのルールが `permission-denied` で拒否する。
class DemoPermissionDenied implements Exception {
  /// 何も受け取らない。
  const DemoPermissionDenied();

  @override
  String toString() => 'DemoPermissionDenied';
}

class _DemoAuthGateway implements FirebaseAuthGateway {
  _DemoAuthGateway(this._db, this._uid, this._name) {
    _db._signOuts.stream
        .where((uid) => uid == _uid)
        .listen((_) => _signedOut = true);
  }

  final DemoDatabase _db;
  final String _uid;
  String? _name;
  bool _signedOut = false;

  @override
  AppUser? get currentUser =>
      _signedOut ? null : AppUser(uid: _uid, name: _name);

  @override
  Stream<void> get signedOut async* {
    if (_signedOut) yield null;
    yield* _db._signOuts.stream.where((uid) => uid == _uid).map((_) {});
  }

  @override
  Future<AppUser> signInAnonymously() async {
    if (_signedOut) {
      // サインアウトのあとのサインインは、新しい匿名アカウントになる。
      _db.accountExists = true;
    }
    _signedOut = false;
    return AppUser(uid: _uid, name: _name);
  }

  @override
  Future<void> updateName(String name) async => _name = name;

  @override
  Future<bool> accountExists() async {
    await _db.accountCheckWait;
    final error = _db.accountCheckError;
    if (error != null) throw error;
    return _db.accountExists;
  }

  @override
  Future<void> signOut() async {
    _signedOut = true;
    _db.signedOutAccounts.add(_uid);
    _db._signOuts.add(_uid);
  }

  @override
  Future<void> deleteAccount() async {
    final error = _db.accountDeleteError;
    if (error != null) throw error;
    _db.deletedAccounts.add(_uid);
  }
}

class _DemoLeafletRepository implements FirebaseLeafletRepository {
  _DemoLeafletRepository(this._db, this._uid);

  final DemoDatabase _db;
  final String _uid;

  LeafletEntity? _find(String key) {
    for (final leaflet in _db._leaflets.value) {
      if (leaflet.key == key) return leaflet;
    }
    return null;
  }

  void _replace(LeafletEntity next) {
    _db._leaflets.value = [
      for (final item in _db._leaflets.value)
        if (item.key == next.key) next else item,
    ];
  }

  @override
  Stream<List<LeafletEntity>> watchLeaflets() {
    return _db._leaflets.watch().map(
      (all) => [
        for (final leaflet in all)
          if (_db._members[leaflet.key]?.contains(_uid) ?? false) leaflet,
      ],
    );
  }

  @override
  Stream<LeafletEntity?> watchLeaflet(String key) => watchLeaflets().map(
    (all) => all.where((leaflet) => leaflet.key == key).firstOrNull,
  );

  @override
  Future<String> addLeaflet(String title, {required String coverEmoji}) async {
    await _db._waitForWrite();
    final leaflet = LeafletEntity(
      generateLeafletId(),
      title,
      coverEmoji,
      null,
      null,
      null,
      ownerUid: _uid,
    );
    _db._members[leaflet.key] = {_uid};
    _db._leaflets.value = [..._db._leaflets.value, leaflet];
    return leaflet.key;
  }

  @override
  Future<void> updateLeafletPeriod(
    String key, {
    DateTime? firstDate,
    DateTime? lastDate,
    String? firstTimeZoneId,
    String? lastTimeZoneId,
  }) async {
    await _db._waitForWrite();
    final stored = _find(key);
    if (stored == null) return;
    _replace(
      LeafletEntity(
        key,
        stored.title,
        stored.imageUrl,
        stored.coverColor,
        firstDate,
        lastDate,
        firstTimeZoneId: firstTimeZoneId,
        lastTimeZoneId: lastTimeZoneId,
        ownerUid: stored.ownerUid,
        shared: stored.shared,
      ),
    );
  }

  @override
  Future<void> updateLeafletTitle(String key, String title) async {
    await _db._waitForWrite();
    final stored = _find(key);
    if (stored == null) return;
    _replace(
      LeafletEntity(
        key,
        title,
        stored.imageUrl,
        stored.coverColor,
        stored.firstDate,
        stored.lastDate,
        firstTimeZoneId: stored.firstTimeZoneId,
        lastTimeZoneId: stored.lastTimeZoneId,
        ownerUid: stored.ownerUid,
        shared: stored.shared,
      ),
    );
  }

  @override
  Future<void> updateLeafletCover(
    String key, {
    String? imageUrl,
    int? coverColor,
  }) async {
    await _db._waitForWrite();
    final stored = _find(key);
    if (stored == null) return;
    _replace(
      LeafletEntity(
        key,
        stored.title,
        imageUrl,
        coverColor,
        stored.firstDate,
        stored.lastDate,
        firstTimeZoneId: stored.firstTimeZoneId,
        lastTimeZoneId: stored.lastTimeZoneId,
        ownerUid: stored.ownerUid,
        shared: stored.shared,
      ),
    );
  }

  @override
  Future<void> deleteLeaflet(LeafletEntity leaflet) async {
    _requireOwner(leaflet.key);
    _db._throwServerWriteError();
    _db._marks.remove(leaflet.key);
    _db._notes.remove(leaflet.key);
    _db._members.remove(leaflet.key);
    _db._secrets.remove(leaflet.key);
    _db._leaflets.value = [
      for (final item in _db._leaflets.value)
        if (item.key != leaflet.key) item,
    ];
  }

  void _requireOwner(String key) {
    if (_find(key)?.ownerUid != _uid) throw const DemoPermissionDenied();
  }

  void _setShared(LeafletEntity leaflet, {required bool shared}) {
    final stored = _find(leaflet.key);
    if (stored == null) return;
    _replace(
      LeafletEntity(
        stored.key,
        stored.title,
        stored.imageUrl,
        stored.coverColor,
        stored.firstDate,
        stored.lastDate,
        firstTimeZoneId: stored.firstTimeZoneId,
        lastTimeZoneId: stored.lastTimeZoneId,
        ownerUid: stored.ownerUid,
        shared: shared,
      ),
    );
  }

  @override
  Future<void> enableSharing(LeafletEntity leaflet, String passphrase) async {
    _requireOwner(leaflet.key);
    _db._secrets[leaflet.key] = hashPassphrase(leaflet.key, passphrase);
    _setShared(leaflet, shared: true);
  }

  @override
  Future<void> disableSharing(LeafletEntity leaflet) async {
    _requireOwner(leaflet.key);
    _db._throwServerWriteError();
    _db._secrets.remove(leaflet.key);
    _db._members[leaflet.key]?.removeWhere((uid) => uid != _uid);
    _setShared(leaflet, shared: false);
  }

  @override
  Future<void> joinLeaflet(String leafletId, String passphrase) async {
    _db._throwServerWriteError();
    final members = _db._members[leafletId];
    if (members != null && members.contains(_uid)) {
      throw const JoinFailure(JoinFailureReason.alreadyJoined);
    }
    final secret = _db._secrets[leafletId];
    if (members == null ||
        secret == null ||
        secret != hashPassphrase(leafletId, passphrase)) {
      throw const JoinFailure(JoinFailureReason.rejected);
    }
    members.add(_uid);
    _db._notifyLeaflets();
  }

  @override
  Future<void> leaveLeaflet(LeafletEntity leaflet) async {
    if (_find(leaflet.key)?.ownerUid == _uid) {
      throw const DemoPermissionDenied();
    }
    _db._members[leaflet.key]?.remove(_uid);
    _db._notifyLeaflets();
  }

  @override
  Future<void> removeMyIndex() async => _db._throwServerWriteError();
}

class _DemoMarkRepository implements FirebaseMarkRepository {
  _DemoMarkRepository(this._db);

  final DemoDatabase _db;

  @override
  Future<void> createMarks(String leafletKey, List<MarkEntity> marks) async {
    await _db._waitForWrite();
    _set(leafletKey, [
      for (final mark in marks) mark.copy()..key = _db._newKey(),
    ]);
  }

  @override
  Stream<List<MarkEntity>> watchMarks(String leafletKey) =>
      _db._marksOf(leafletKey).watch();

  void _set(String leafletKey, List<MarkEntity> marks) {
    final sorted = [...marks]
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    _db._marksOf(leafletKey).value = sorted;
  }

  @override
  Future<void> addMark(String leafletKey, MarkEntity mark) async {
    await _db._waitForWrite();
    mark.key = _db._newKey();
    _set(leafletKey, [..._db._marksOf(leafletKey).value, mark]);
  }

  @override
  Future<void> updateMark(String leafletKey, MarkEntity mark) async {
    _set(leafletKey, [
      for (final item in _db._marksOf(leafletKey).value)
        if (item.key == mark.key) mark else item,
    ]);
  }

  @override
  Future<void> deleteMark(String leafletKey, MarkEntity mark) async {
    _set(leafletKey, [
      for (final item in _db._marksOf(leafletKey).value)
        if (item.key != mark.key) item,
    ]);
  }
}

class _DemoNoteRepository implements FirebaseNoteRepository {
  _DemoNoteRepository(this._db);

  final DemoDatabase _db;

  @override
  Stream<Object?> watchNote(String leafletKey) =>
      _db._noteOf(leafletKey).watch();

  @override
  String newNoteId() => _db._newKey();

  @override
  Future<void> createNote(String leafletKey, NoteDocument document) async {
    await _db._waitForWrite();
    _db._noteOf(leafletKey).value = document.toJson();
  }

  @override
  Future<bool> resetNote(
    String leafletKey,
    Object? expected,
    NoteDocument replacement,
  ) async {
    await _db._waitForWrite();
    if (!mapEqualsDeep(_db._noteOf(leafletKey).value, expected)) return false;
    _db._noteOf(leafletKey).value = replacement.toJson();
    return true;
  }

  @override
  Future<void> saveNoteLines(
    String leafletKey,
    String generation,
    Map<String, NoteLine> changes,
  ) async {
    await _db._waitForWrite();
    final current = NoteDocument.parse(_db._noteOf(leafletKey).value);
    if (current.generation != generation ||
        changes.values.any(
          (line) => current.lines[line.id]?.deleted == true && !line.deleted,
        )) {
      throw const DemoPermissionDenied();
    }
    _db._noteOf(leafletKey).value = NoteDocument(generation, {
      ...current.lines,
      ...changes,
    }).toJson();
  }
}

class _DemoPresenceRepository implements FirebasePresenceRepository {
  _DemoPresenceRepository(this._db, this._uid);

  final DemoDatabase _db;
  final String _uid;

  @override
  Stream<Collaborators> watchCollaborators(String leafletKey) => _db
      ._caretsOf(leafletKey)
      .watch()
      .map(
        (value) => Collaborators(
          editingCount:
              value.editingCount -
              ((_db._presenceEntries[leafletKey]?.containsKey(_uid) ?? false)
                  ? 1
                  : 0),
          carets: value.carets.where((caret) => caret.uid != _uid).toList(),
        ),
      );

  @override
  Future<void> writeMyCaret(
    String leafletKey, {
    required String name,
    required int? index,
    String? generation,
    String? lineId,
  }) async {
    _db._presenceEntries.putIfAbsent(leafletKey, () => {})[_uid] = index == null
        ? null
        : RemoteCaret(
            uid: _uid,
            name: name,
            index: index,
            generation: generation,
            lineId: lineId,
          );
    _db._emitCarets(leafletKey);
  }

  @override
  Future<void> clearMyCaret(String leafletKey) async {
    _db._presenceEntries[leafletKey]?.remove(_uid);
    _db._emitCarets(leafletKey);
  }

  @override
  Future<void Function()> keepMyCaretCleanedOnDisconnect(
    String leafletKey, {
    required void Function() onConnected,
  }) async {
    return () {};
  }
}

class _MemoryPassphraseStore implements SecurePassphraseStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String leafletId) async => _values[leafletId];

  @override
  Future<void> write(String leafletId, String passphrase) async =>
      _values[leafletId] = passphrase;

  @override
  Future<void> delete(String leafletId) async => _values.remove(leafletId);

  @override
  Future<void> deleteAll() async => _values.clear();
}

/// 端末の機種名の偽物。既定は、Pixel 10a。
class FakeDeviceName implements DeviceNameSource {
  /// [name] を機種名として返す。
  const FakeDeviceName([this.name = 'Pixel 10a']);

  /// 返す機種名。
  final String name;

  @override
  Future<String> modelName() async => name;
}

/// ホーム画面ウィジェットの偽物。消された（[clearFor]）しおりのキーを記録する。
class FakeTripWidget implements NativeTripWidgetPublisher {
  /// 何も受け取らない。
  FakeTripWidget();

  /// [clearFor] に渡されたしおりのキー。
  final List<String> cleared = [];

  /// 最後に公開した、現在の表示対象。
  String? leafletKey;
  String? title;
  List<MarkEntity> marks = [];

  @override
  Future<void> init() async {}

  @override
  Future<void> publish(
    String leafletTitle,
    List<MarkEntity> marks, {
    String? leafletKey,
  }) async {
    this.leafletKey = leafletKey;
    title = leafletTitle;
    this.marks = List.of(marks);
  }

  @override
  Future<void> updateTitleFor(String leafletKey, String title) async {
    if (this.leafletKey == leafletKey) this.title = title;
  }

  @override
  Future<void> clearFor(String leafletKey) async {
    cleared.add(leafletKey);
    if (this.leafletKey != leafletKey) return;
    this.leafletKey = null;
    title = null;
    marks = [];
  }

  /// [clear] が呼ばれた回数。
  int clearedAll = 0;

  @override
  Future<void> clear() async {
    clearedAll++;
    leafletKey = null;
    title = null;
    marks = [];
  }
}
