import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../../entity/leaflet_entity.dart';
import '../../entity/mark_entity.dart';
import '../../extension/extension.dart';
import '../../helper/deep_equals.dart';
import '../../l10n/write_task.dart';
import '../../logger.dart';
import '../../notes/note_document.dart';
import '../../notes/remote_caret.dart';
import '../../notifications/token_key.dart';
import '../../sharing/share_code.dart';
import '../data_types.dart';
import 'firebase_local_writes.dart';

const _serverTimeout = Duration(seconds: 15);

/// 接続前の `false` の後に `true` が届くまで待つ既定の上限。
/// `.info/connected` は接続の確立前にまず `false` を流すため、起動・復帰直後の一時的な
/// `false` をオフラインと誤判定しないよう待つ。
const _connectionGrace = Duration(seconds: 2);

FirebaseException _disconnected() => FirebaseException(
  plugin: 'firebase_database',
  code: 'disconnected',
  message: 'This operation requires a server connection.',
);

/// 送信済みの書き込みを待つ。上限を過ぎたら、失敗ではなく結果不明として扱う。
Future<T> _awaitWrite<T>(Future<T> write) => write.timeout(
  _serverTimeout,
  onTimeout: () => throw const WriteUnconfirmed(),
);

/// サーバー確認が必要な操作は、オフラインでキューに入れる前に失敗させる。
///
/// 最初の値が `false` のときだけ短く待つ（理由は [_connectionGrace]）。
/// 何も送信していないので、値が届かない場合も切断として扱う。
/// [grace] は `false` の後に `true` を待つ上限。テストでは短くできる。
Future<void> requireFirebaseConnection(
  DatabaseReference root, {
  Duration grace = _connectionGrace,
}) {
  final result = Completer<void>();
  Timer? graceTimer;

  void fail() {
    if (!result.isCompleted) result.completeError(_disconnected());
  }

  final initial = Timer(_serverTimeout, fail);
  final subscription = root
      .child('.info/connected')
      .onValue
      .listen(
        (event) {
          initial.cancel();
          if (event.snapshot.value == true) {
            if (!result.isCompleted) result.complete();
          } else {
            graceTimer ??= Timer(grace, fail);
          }
        },
        onError: (Object error, StackTrace stack) {
          if (!result.isCompleted) result.completeError(error, stack);
        },
      );
  return result.future.whenComplete(() {
    initial.cancel();
    graceTimer?.cancel();
    // 解除の完了を待って、確認の結果を遅らせない。
    unawaited(subscription.cancel());
  });
}

/// Firebase Authentication を使う認証。アカウント登録は求めず、匿名で入る。
class FirebaseAuthGateway {
  /// 既定の [FirebaseAuth] を使う。
  FirebaseAuthGateway([FirebaseAuth? auth])
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  /// サインイン中のユーザー。まだなら null。
  AppUser? get currentUser {
    final user = _auth.currentUser;
    return user == null ? null : AppUser(uid: user.uid, name: user.displayName);
  }

  /// 匿名でサインインする。すでにサインインしていればそのユーザーを返す。
  Future<AppUser> signInAnonymously() async {
    var user = _auth.currentUser;
    if (user == null) {
      user = (await _auth.signInAnonymously()).user;
      if (user == null) throw StateError('Anonymous sign-in returned no user');
    }
    return AppUser(uid: user.uid, name: user.displayName);
  }

  /// 共同編集で他の人に見せるニックネームを保存する。
  Future<void> updateName(String name) async {
    await _auth.currentUser?.updateDisplayName(name);
  }

  /// データ削除前に、端末に残るユーザーがサーバーでも有効か確認する。
  Future<bool> accountExists() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      await user.reload().timeout(_serverTimeout);
      return _auth.currentUser != null;
    } on FirebaseAuthException catch (error, stack) {
      if (!isUnavailableAccount(error)) rethrow;
      logger.w('Account is no longer available', error, stack);
      return false;
    }
  }

  /// 端末の認証状態が解除されたときに流す。
  ///
  /// Firebase Auth は、トークンの更新でユーザーの削除・無効化・失効を知ると、端末でもサインアウトする。
  /// 購読した直後にも、その時点でサインインしていなければ流す。
  Stream<void> get signedOut =>
      _auth.authStateChanges().where((user) => user == null).map((_) {});

  /// 削除済み、または失効した認証状態。通信障害や再認証要求とは区別する。
  static bool isUnavailableAccount(FirebaseAuthException error) =>
      error.code == 'user-not-found' ||
      error.code == 'user-token-expired' ||
      error.code == 'invalid-user-token';

  /// 端末に残った認証状態を解除する。サーバーのデータ削除は行わない。
  Future<void> signOut() => _auth.signOut().timeout(_serverTimeout);

  /// 匿名ユーザー（Authentication のアカウント）を削除する。
  ///
  /// 削除すると、同じ端末でも、同じ uid には戻れない。サインインが古すぎるときは
  /// [FirebaseAuthException]（`requires-recent-login`）を投げる。
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user != null) await _awaitWrite(user.delete());
  }
}

/// Realtime Database でしおりの一覧・作成・更新・削除・共有を扱う。
///
/// データの構造と認可はサーバー側のルール（`database.rules.json`）が決める。
class FirebaseLeafletRepository {
  /// [root] は Realtime Database のルート、[auth] は自分の uid を得るために使う。
  /// [connectionGrace] は接続確認で `true` を待つ上限（[requireFirebaseConnection]）。
  FirebaseLeafletRepository(
    this._root,
    this._auth, {
    FirebaseLocalWrites? writes,
    Duration connectionGrace = _connectionGrace,
  }) : _writes = writes ?? FirebaseLocalWrites(),
       _grace = connectionGrace;

  final DatabaseReference _root;
  final FirebaseAuthGateway _auth;
  final FirebaseLocalWrites _writes;
  final Duration _grace;

  Future<void> _requireConnection() =>
      requireFirebaseConnection(_root, grace: _grace);

  /// 参加の書き込みを待つ最長の時間。オフラインで待ち続けないための上限。
  static const _joinTimeout = Duration(seconds: 15);

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Not signed in');
    return uid;
  }

  DatabaseReference _leaflet(String key) => _root.child('leaflets').child(key);

  /// しおり 1 冊の最新値。削除された、または形式が不正なときは null。
  /// 権限喪失などの購読エラーは呼び出し元へ流す。
  Stream<LeafletEntity?> watchLeaflet(String key) =>
      _leaflet(key).onValue.map((event) {
        final value = event.snapshot.value;
        return value is Map<Object?, Object?>
            ? LeafletEntity.tryBuild(key, value)
            : null;
      });

  /// 自分が参加しているしおりの一覧の変更を流す。
  ///
  /// 自分の索引（`userLeaflets/{uid}`）を購読し、載っている各しおりを購読する。
  /// 購読を止めるには listen の戻り値を cancel する。
  Stream<List<LeafletEntity>> watchLeaflets() {
    final uid = _uid;
    final index = _root.child('userLeaflets').child(uid);
    final subscriptions = <String, StreamSubscription<DatabaseEvent>>{};
    final loaded = <String, LeafletEntity?>{};
    final pending = <String>{};
    final denied = <String>{};
    final retried = <String>{};
    final recovering = <String>{};
    var active = true;
    StreamSubscription<DatabaseEvent>? indexSubscription;
    StreamSubscription<DatabaseEvent>? connectionSubscription;
    late final StreamController<List<LeafletEntity>> controller;
    late void Function(String key) subscribe;

    Future<void> cacheContents(String key, bool enabled) async {
      for (final collection in ['marks', 'rich_notes']) {
        if (enabled && (!active || !subscriptions.containsKey(key))) return;
        try {
          await _root.child(collection).child(key).keepSynced(enabled);
        } on Exception catch (error, stack) {
          logger.w(
            'offline cache configuration failed: $collection/$key',
            error,
            stack,
          );
        }
      }
    }

    // すべてのしおりの最初の値がそろってから流し、一覧のちらつきを防ぐ。
    void emit() {
      if (pending.isNotEmpty || controller.isClosed) return;
      controller.add([for (final leaflet in loaded.values) ?leaflet]);
    }

    void onLeaflet(String key, DataSnapshot snapshot) {
      if (!active || !subscriptions.containsKey(key)) return;
      final value = snapshot.value;
      loaded[key] = value is Map<Object?, Object?>
          ? LeafletEntity.tryBuild(key, value)
          : null;
      pending.remove(key);
      emit();
    }

    Future<void> recover(String key) async {
      if (!active || !denied.contains(key) || !recovering.add(key)) return;
      final previous = subscriptions[key];
      try {
        await _writes.waitForPendingWrites();
        if (!active || !identical(subscriptions[key], previous)) return;
        if (!retried.add(key)) return;
        final member = await _root
            .child('leafletMembers')
            .child(key)
            .child(uid)
            .get()
            .timeout(_serverTimeout);
        if (!active ||
            !identical(subscriptions[key], previous) ||
            !member.exists) {
          return;
        }
        await previous?.cancel();
        if (!active || !identical(subscriptions[key], previous)) return;
        denied.remove(key);
        subscribe(key);
        // 初回の購読が参加権限の同期前に拒否されたキャッシュも登録し直す。
        await cacheContents(key, false);
        if (active && subscriptions.containsKey(key)) {
          await cacheContents(key, true);
        }
      } on Exception catch (error, stack) {
        logger.w('leaflet subscription recovery failed: $key', error, stack);
      } finally {
        recovering.remove(key);
      }
    }

    subscribe = (key) {
      subscriptions[key] = _leaflet(key).onValue.listen(
        (event) => onLeaflet(key, event.snapshot),
        onError: (Object error, StackTrace stack) {
          if (!active || !subscriptions.containsKey(key)) return;
          logger.w('leaflet listen failed: $key', error, stack);
          loaded[key] = null;
          pending.remove(key);
          emit();
          if (error is FirebaseException && error.code == 'permission-denied') {
            denied.add(key);
            unawaited(recover(key));
          } else {
            controller.addError(error, stack);
          }
        },
      );
    };

    void onIndex(DatabaseEvent event) {
      final keys = {for (final child in event.snapshot.children) ?child.key};
      for (final key in subscriptions.keys.toList()) {
        if (keys.contains(key)) continue;
        unawaited(subscriptions.remove(key)?.cancel() ?? Future<void>.value());
        loaded.remove(key);
        pending.remove(key);
        denied.remove(key);
        retried.remove(key);
        unawaited(cacheContents(key, false));
      }
      for (final key in keys) {
        if (subscriptions.containsKey(key)) continue;
        pending.add(key);
        subscribe(key);
        unawaited(cacheContents(key, true));
      }
      emit();
    }

    controller = StreamController<List<LeafletEntity>>(
      onListen: () {
        connectionSubscription = _root.child('.info/connected').onValue.listen((
          event,
        ) {
          if (event.snapshot.value != true) return;
          retried.clear();
          for (final key in denied.toList()) {
            unawaited(recover(key));
          }
        }, onError: controller.addError);
        indexSubscription = index.onValue.listen(
          onIndex,
          onError: controller.addError,
        );
      },
      onCancel: () async {
        active = false;
        await connectionSubscription?.cancel();
        await indexSubscription?.cancel();
        await Future.wait(subscriptions.values.map((s) => s.cancel()));
        await Future.wait(
          subscriptions.keys.map((key) => cacheContents(key, false)),
        );
        subscriptions.clear();
      },
    );
    return controller.stream;
  }

  /// 新しいしおりを作る。作った人がオーナーになる。作ったしおりのキーを返す。
  Future<String> addLeaflet(String title, {required String coverEmoji}) async {
    final uid = _uid;
    final key = generateLeafletId();
    // 途中の状態を残さないよう、1 回の更新で作る。
    final values = <String, Object?>{
      'leaflets/$key': {
        'title': title,
        'imageUrl': coverEmoji,
        'ownerUid': uid,
        // クライアントの時計に依存しない作成時刻を記録する。
        'createdAt': ServerValue.timestamp,
      },
      'leafletMembers/$key/$uid': true,
      'userLeaflets/$uid/$key': true,
    };
    final index = _root.child('userLeaflets').child(uid).child(key);
    await _writes.write(
      index,
      () => _root.update(values),
      (snapshot) => snapshot.value == true,
      task: WriteTask.createTrip,
    );
    await FirebaseMarkRepository(_root, writes: _writes).createMarks(key, []);
    // 新規 ID に限り、既存のノートを上書きする危険なく初期化できる。
    await FirebaseNoteRepository(_root, writes: _writes).createNote(
      key,
      NoteDocument(key, {
        'empty': NoteLine(
          id: 'empty',
          generation: key,
          afterId: '',
          order: 1,
          writeId: key,
          delta: '[{"insert":"\\n"}]',
        ),
      }),
    );
    return key;
  }

  /// 旅程から導出した期間だけを保存する。
  Future<void> updateLeafletPeriod(
    String key, {
    DateTime? firstDate,
    DateTime? lastDate,
    String? firstTimeZoneId,
    String? lastTimeZoneId,
  }) => _writes.update(_leaflet(key), {
    'firstDate': firstDate?.secondsSinceEpoch(),
    'lastDate': lastDate?.secondsSinceEpoch(),
    'firstTimeZoneId': firstTimeZoneId,
    'lastTimeZoneId': lastTimeZoneId,
  }, task: WriteTask.updatePeriod);

  /// タイトルだけを保存する。
  Future<void> updateLeafletTitle(String key, String title) => _writes.update(
    _leaflet(key),
    {'title': title},
    task: WriteTask.updateTrip,
  );

  /// 表紙の絵文字・背景色だけを保存する。
  Future<void> updateLeafletCover(
    String key, {
    String? imageUrl,
    int? coverColor,
  }) => _writes.update(_leaflet(key), {
    'imageUrl': imageUrl,
    'coverColor': coverColor,
  }, task: WriteTask.updateTrip);

  /// しおりと、それに紐づく旅程・ノートを削除する。オーナーだけが呼べる。
  Future<void> deleteLeaflet(LeafletEntity leaflet) async {
    final uid = _uid;
    final key = leaflet.key;
    final others = await _otherMembers(key);
    await _awaitWrite(
      _root.update({
        'leaflets/$key': null,
        'marks/$key': null,
        'rich_notes/$key': null,
        'leafletSecrets/$key': null,
        'userLeaflets/$uid/$key': null,
        // 参加者への通知（サーバー）が、削除と停止を見分け、タイトルを知るための記録。
        'leafletClosures/$key': _closure('deleted', leaflet.title),
        for (final other in others) ...{
          'leafletMembers/$key/$other': null,
          'userLeaflets/$other/$key': null,
        },
      }),
    );
    // 自分の参加記録は、しおりが無くなってから消せる（ルールで途中放棄を防ぐ）。
    await _awaitWrite(
      _root.child('leafletMembers').child(key).child(uid).remove(),
    );
  }

  /// 削除と停止の「閉鎖の記録」。同じ更新に含めて書き、サーバーが通知の種類とタイトルを知る。
  Map<String, Object?> _closure(String kind, String title) => {
    'kind': kind,
    'title': title,
    'at': ServerValue.timestamp,
  };

  /// オーナー以外のメンバーの uid。オーナーだけが読める。
  Future<List<String>> _otherMembers(String key) async {
    await _requireConnection();
    final members = await _root
        .child('leafletMembers')
        .child(key)
        .get()
        .timeout(_serverTimeout);
    return [
      for (final child in members.children)
        if (child.key case final member? when member != _uid) member,
    ];
  }

  /// 共同編集を有効にし、あいことばを設定する。すでに有効なら変更する。
  ///
  /// オーナーだけが呼べる。
  Future<void> enableSharing(LeafletEntity leaflet, String passphrase) {
    return _writes.write(
      _leaflet(leaflet.key).child('shared'),
      () => _root.update({
        'leafletSecrets/${leaflet.key}': hashPassphrase(
          leaflet.key,
          passphrase,
        ),
        'leaflets/${leaflet.key}/shared': true,
      }),
      (snapshot) => snapshot.value == true,
      task: WriteTask.enableSharing,
    );
  }

  /// 共同編集を停止する。オーナー以外のメンバーは、しおりから外れて見えなくなる。
  ///
  /// 再び有効にしても、外れたメンバーは、もう一度参加する必要がある。
  /// オーナーだけが呼べる。
  Future<void> disableSharing(LeafletEntity leaflet) async {
    final key = leaflet.key;
    final others = await _otherMembers(key);
    await _awaitWrite(
      _root.update({
        'leafletSecrets/$key': null,
        'leaflets/$key/shared': null,
        'leafletClosures/$key': _closure('stopped', leaflet.title),
        for (final other in others) ...{
          'leafletMembers/$key/$other': null,
          'userLeaflets/$other/$key': null,
        },
      }),
    );
  }

  /// 公開用しおり ID とあいことばで、共同編集のしおりに参加する。
  ///
  /// 失敗したときは [JoinFailure] を投げる。
  Future<void> joinLeaflet(String leafletId, String passphrase) async {
    final uid = _uid;
    final member = _root.child('leafletMembers').child(leafletId).child(uid);
    try {
      await _requireConnection();
      final existing = await member.get().timeout(_joinTimeout);
      if (existing.exists) {
        throw const JoinFailure(JoinFailureReason.alreadyJoined);
      }
      await _root
          .update({
            'leafletMembers/$leafletId/$uid': hashPassphrase(
              leafletId,
              passphrase,
            ),
            'userLeaflets/$uid/$leafletId': true,
          })
          .timeout(
            _joinTimeout,
            onTimeout: () =>
                throw const JoinFailure(JoinFailureReason.unconfirmed),
          );
    } on FirebaseException catch (e) {
      throw JoinFailure(
        e.code == 'permission-denied'
            ? JoinFailureReason.rejected
            : JoinFailureReason.network,
      );
    } on TimeoutException {
      throw const JoinFailure(JoinFailureReason.network);
    }
  }

  /// 参加しているしおりから抜ける。オーナーは呼べない。
  Future<void> leaveLeaflet(LeafletEntity leaflet) {
    final uid = _uid;
    return _writes.write(
      _root.child('userLeaflets').child(uid).child(leaflet.key),
      () => _root.update({
        'leafletMembers/${leaflet.key}/$uid': null,
        'userLeaflets/$uid/${leaflet.key}': null,
      }),
      (snapshot) => snapshot.value == null,
      task: WriteTask.leaveTrip,
    );
  }

  /// 自分のしおりの索引（`userLeaflets/{uid}`）を、丸ごと消す。アカウントの削除の仕上げに使う。
  Future<void> removeMyIndex() =>
      _awaitWrite(_root.child('userLeaflets').child(_uid).remove());
}

/// Realtime Database で、1 つのしおりに属する旅程を扱う。
class FirebaseMarkRepository {
  /// [root] は Realtime Database のルート。
  FirebaseMarkRepository(this._root, {FirebaseLocalWrites? writes})
    : _writes = writes ?? FirebaseLocalWrites();

  final DatabaseReference _root;
  final FirebaseLocalWrites _writes;

  DatabaseReference _marks(String leafletKey) =>
      _root.child('marks').child(leafletKey);

  /// [leafletKey] の旅程を開始日時の昇順で流す。
  Stream<List<MarkEntity>> watchMarks(String leafletKey) {
    return _marks(leafletKey).onValue.map((event) {
      final marks = <MarkEntity>[];
      for (final snapshot in event.snapshot.children) {
        final key = snapshot.key;
        final value = snapshot.value;
        if (key == null || value is! Map<Object?, Object?>) continue;
        final mark = MarkEntity.tryBuild(key, value);
        if (mark != null) marks.add(mark);
      }
      // 未取得の並べ替えクエリは、オフラインで onValue が届かないことがある。
      return marks..sort((a, b) {
        final date = a.startDate.compareTo(b.startDate);
        return date != 0 ? date : a.key.compareTo(b.key);
      });
    });
  }

  /// 旅程を追加する。
  Future<void> addMark(String leafletKey, MarkEntity mark) {
    return _writes.set(
      _marks(leafletKey).push(),
      mark.toJson(),
      task: WriteTask.addPlan,
    );
  }

  /// 新規作成したしおりの旅程全体を保存する。既存の旅程には使わない。
  ///
  /// 個別の子だけの書き込みでは、オフラインで親の onValue が届かない。
  Future<void> createMarks(String leafletKey, List<MarkEntity> marks) {
    final reference = _marks(leafletKey);
    return _writes.set(reference, {
      for (final mark in marks) reference.push().key!: mark.toJson(),
    }, task: WriteTask.addSamples);
  }

  /// 旅程を保存する。
  Future<void> updateMark(String leafletKey, MarkEntity mark) {
    return _writes.set(
      _marks(leafletKey).child(mark.key),
      mark.toJson(),
      task: WriteTask.updatePlan,
    );
  }

  /// 旅程を削除する。
  Future<void> deleteMark(String leafletKey, MarkEntity mark) {
    return _writes.set(
      _marks(leafletKey).child(mark.key),
      null,
      task: WriteTask.deletePlan,
    );
  }
}

/// Realtime Database で、世代と段落IDごとのDeltaを持つノートを扱う。
class FirebaseNoteRepository {
  /// [root] は Realtime Database のルート。
  /// [connectionGrace] は接続確認で `true` を待つ上限（[requireFirebaseConnection]）。
  FirebaseNoteRepository(
    this._root, {
    FirebaseLocalWrites? writes,
    Duration connectionGrace = _connectionGrace,
  }) : _writes = writes ?? FirebaseLocalWrites(),
       _grace = connectionGrace;

  final DatabaseReference _root;
  final FirebaseLocalWrites _writes;
  final Duration _grace;

  DatabaseReference _note(String leafletKey) =>
      _root.child('rich_notes').child(leafletKey);

  Stream<Object?> watchNote(String leafletKey) =>
      _note(leafletKey).onValue.map((event) => event.snapshot.value);

  String newNoteId() => _root.push().key!;

  /// この端末で新規作成したしおりだけに使う。既存ノートの置換には resetNote を使う。
  Future<void> createNote(String leafletKey, NoteDocument document) =>
      _writes.set(_note(leafletKey), document.toJson(), note: true);

  /// 確認した内容から変わっていない場合だけ初期化する。
  Future<bool> resetNote(
    String leafletKey,
    Object? expected,
    NoteDocument replacement,
  ) async {
    await requireFirebaseConnection(_root, grace: _grace);
    final result = await _awaitWrite(
      _note(leafletKey).runTransaction((value) {
        if (!mapEqualsDeep(value, expected)) return Transaction.abort();
        return Transaction.success(replacement.toJson());
      }, applyLocally: false),
    );
    return result.committed;
  }

  Future<void> saveNoteLines(
    String leafletKey,
    String generation,
    Map<String, NoteLine> changes,
  ) => _writes.update(_note(leafletKey), {
    for (final line in changes.values) 'lines/${line.id}': line.toJson(),
  }, note: true);
}

/// Realtime Database で、共同編集中のメンバーのカーソル位置（プレゼンス）を扱う。
///
/// 本文の再配信を避けるため、`rich_notes` の外（`presence/notes`）に置く。
class FirebasePresenceRepository {
  /// [root] は Realtime Database のルート、[auth] は自分の uid を得るために使う。
  FirebasePresenceRepository(
    this._root,
    this._auth, {
    FirebaseLocalWrites? writes,
  }) : _writes = writes ?? FirebaseLocalWrites();

  final DatabaseReference _root;
  final FirebaseAuthGateway _auth;
  final FirebaseLocalWrites _writes;

  DatabaseReference _presence(String leafletKey) =>
      _root.child('presence').child('notes').child(leafletKey);

  DatabaseReference? _mine(String leafletKey) {
    final uid = _auth.currentUser?.uid;
    return uid == null ? null : _presence(leafletKey).child(uid);
  }

  /// 自分以外のメンバーの編集状況を流す。
  Stream<Collaborators> watchCollaborators(String leafletKey) {
    final myUid = _auth.currentUser?.uid;
    return _presence(leafletKey).onValue.map((event) {
      final others = event.snapshot.children.where((c) => c.key != myUid);
      return Collaborators(
        editingCount: others.length,
        carets: parseRemoteCarets(event.snapshot.value, myUid),
      );
    });
  }

  /// 自分のカーソル位置を書き込む。[index] が null ならフォーカスなしを表す。
  Future<void> writeMyCaret(
    String leafletKey, {
    required String name,
    required int? index,
    String? generation,
    String? lineId,
  }) async {
    final mine = _mine(leafletKey);
    if (mine == null) return;
    await _writes.set(
      mine,
      presencePayload(
        at: ServerValue.timestamp,
        name: name,
        index: index,
        generation: generation,
        lineId: lineId,
      ),
    );
  }

  /// 自分のカーソルを消す。
  Future<void> clearMyCaret(String leafletKey) async {
    final mine = _mine(leafletKey);
    if (mine != null) await _writes.set(mine, null);
  }

  /// 接続が切れたときに自分のカーソルが消えるよう登録する。
  ///
  /// 再接続のたびに登録し直す必要があるため、接続状態を監視する。
  /// 接続を確認できたとき、または再接続したときに [onConnected] を呼ぶ。
  /// 戻り値の関数を呼ぶと、登録と監視を解除する。
  Future<void Function()> keepMyCaretCleanedOnDisconnect(
    String leafletKey, {
    required void Function() onConnected,
  }) async {
    final mine = _mine(leafletKey);
    if (mine == null) return () {};

    // onDisconnect は一度発火するとサーバーから消えるため、再接続のたびに登録し直す。
    final subscription = _root.child('.info/connected').onValue.listen((
      event,
    ) async {
      if (event.snapshot.value != true) return;
      try {
        await mine.onDisconnect().remove();
        onConnected();
      } on Exception catch (e, s) {
        logger.w('onDisconnect registration failed', e, s);
      }
    });

    return () {
      unawaited(subscription.cancel());
      unawaited(mine.onDisconnect().cancel());
    };
  }
}

/// Realtime Database で、通知の宛先になる端末のトークン（`users/{uid}/fcmTokens/{tokenKey}`）を扱う。
///
/// 書けるのは本人だけ（ルールで決まる）。サーバー（Cloud Functions）だけが、これを読んで通知を送り、
/// 無効になったトークンを消す。アプリは、トークンを消さない（サインアウトの操作が無いため）。
class FirebaseDeviceTokenRepository {
  /// [root] は Realtime Database のルート、[auth] は自分の uid を得るために使う。
  FirebaseDeviceTokenRepository(
    this._root,
    this._auth, {
    FirebaseLocalWrites? writes,
  }) : _writes = writes ?? FirebaseLocalWrites();

  final DatabaseReference _root;
  final FirebaseAuthGateway _auth;
  final FirebaseLocalWrites _writes;

  DatabaseReference _entry(String key) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Not signed in');
    return _root.child('users').child(uid).child('fcmTokens').child(key);
  }

  /// この端末のトークンを登録する。すでにあれば、時刻だけ更新する。
  ///
  /// キーはトークンのハッシュ（[deviceTokenKey]）で、トークンそのものは値に持つ。
  Future<void> register(String token) async {
    _writes.enqueue(
      () => _entry(deviceTokenKey(token)).set({
        'token': token,
        'at': ServerValue.timestamp,
        'platform': defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
      }),
    );
    if (!RegExp(r'[.#$\[\]/]').hasMatch(token)) {
      _writes.enqueue(() => _entry(token).remove());
    }
  }

  /// トークンが更新されると古い登録が残るため、キーを指定せず、この利用者の
  /// 登録された端末のトークンを丸ごと消す（`users/{uid}`）。
  Future<void> removeAll() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Not signed in');
    await _root.child('users').child(uid).remove().timeout(_serverTimeout);
  }
}
