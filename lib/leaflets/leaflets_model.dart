import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/app_services.dart';
import '../data/data_types.dart';
import '../data/firebase/firebase_local_writes.dart';
import '../data/firebase/firebase_services.dart';
import '../data/sample_leaflets.dart';
import '../entity/leaflet_entity.dart';
import '../extension/extension.dart';
import '../helper/device_name.dart';
import '../helper/nickname_policy.dart';
import '../helper/secure_passphrase_store.dart';
import '../helper/time_zones.dart';
import '../helper/trip_widget_publisher.dart';
import '../l10n/l10n.dart';
import '../l10n/write_task.dart';
import '../logger.dart';
import '../notifications/push_coordinator.dart';
import '../sharing/share_code.dart';

/// しおり一覧の状態。購読、年ごとの分類、作成・更新・削除、共同編集を持つ。
class LeafletsModel extends ChangeNotifier {
  /// [services] は接続先。
  LeafletsModel(AppServices services)
    : _leafletRepository = services.leaflets,
      _markRepository = services.marks,
      _noteRepository = services.notes,
      _passphrases = services.passphrases,
      _widget = services.widget,
      _deviceName = services.deviceName,
      push = PushCoordinator(services),
      _auth = services.auth,
      _requireOnline = services.requireOnline {
    _writeFailures = services.localWrites?.failures.listen((failure) {
      if (failure.note) {
        onWriteError?.call(l10n.noteSaveFailed);
      } else if (failure.task case final task?) {
        onWriteError?.call(l10n.writeFailed(task));
      }
    });
  }

  StreamSubscription<FirebaseWriteFailure>? _writeFailures;
  final Future<void> Function()? _requireOnline;

  final FirebaseLeafletRepository _leafletRepository;
  final FirebaseMarkRepository _markRepository;
  final FirebaseNoteRepository _noteRepository;
  final SecurePassphraseStore _passphrases;
  final NativeTripWidgetPublisher _widget;
  final DeviceNameSource _deviceName;

  /// 通知の許可、トークンの登録、受け取り。
  final PushCoordinator push;
  final FirebaseAuthGateway _auth;
  List<LeafletEntity> _leaflets = [];
  bool _hasLoaded = false;
  bool _accountUnavailable = false;
  bool _sessionLost = false;
  bool _signingOut = false;
  bool _disposed = false;
  StreamSubscription<void>? _signedOutSubscription;

  /// サーバーのデータ削除ではなく、失効したログイン状態の解除を行ったか。
  bool get accountUnavailable => _accountUnavailable;

  /// 利用中に、アカウントの削除やログインの失効で、サインアウトされたか。
  ///
  /// 自分で「アカウントとデータを削除」したときは立てない。画面は、知らせてから起動画面へ戻す。
  bool get sessionLost => _sessionLost;

  static const _accountOperationTimeout = Duration(seconds: 15);

  /// 書き込みや復帰の前のアカウント確認を待つ上限。過ぎたら、オフラインとみなして続ける。
  static const _accountCheckTimeout = Duration(seconds: 5);

  /// 書く前に、アカウントがサーバーで有効かを確かめる操作。
  ///
  /// コンソールなどで削除されても、端末の ID トークンは最大 1 時間ほど有効なままで、
  /// Realtime Database は書き込みを受け付けてしまう。新しいデータを作る操作は、先に確かめる。
  static const _accountCheckedTasks = {
    WriteTask.createTrip,
    WriteTask.addSamples,
    WriteTask.enableSharing,
  };

  /// しおりの一覧を、少なくとも 1 回、受け取ったか。
  bool get hasLoaded => _hasLoaded;
  StreamSubscription<List<LeafletEntity>>? _subscription;

  /// 失敗の文言に使う言語。画面が、いまの言語のものを入れる。
  AppLocalizations l10n = AppLocalizationsEn();

  /// 書き込みの失敗を画面へ伝える。画面側が SnackBar などで表示する。
  void Function(String message)? onWriteError;

  /// 一覧の購読を始める。build から呼ばれるため、購読は一度だけ行う。
  void fetchLeafletsEntity() {
    if (_subscription != null) return;
    deviceZoneListenable.addListener(notifyListeners);
    unawaited(push.start());
    _listen();
    _signedOutSubscription = _auth.signedOut.listen((_) {
      if (!_signingOut) unawaited(_loseSession());
    });
  }

  /// 端末の認証状態が解除されたあとの後片付け。サーバーのデータは消さない（権限が無い）。
  Future<void> _loseSession() async {
    if (_sessionLost) return;
    _sessionLost = true;
    logger.w('Signed out while in use; returning to the launch screen');
    unawaited(_subscription?.cancel());
    try {
      await _discardLocalData();
    } on Object catch (e, s) {
      logger.w('Failed to discard local data after sign-out', e, s);
    }
    if (!_disposed) notifyListeners();
  }

  /// 端末に残る、このアカウントの通知・あいことば・ウィジェットを消す。
  ///
  /// 一覧は権限を失うと先に空になりうるため、しおりごとではなく、すべて消す。
  Future<void> _discardLocalData() async {
    await push.dispose().timeout(_accountOperationTimeout);
    await _passphrases.deleteAll().timeout(_accountOperationTimeout);
    await _widget.clear().timeout(_accountOperationTimeout);
  }

  /// アカウントがサーバーで有効かを確かめる。削除・失効していたら、サインアウトして [sessionLost] を立てる。
  ///
  /// 有効、または確かめられない（オフライン、時間切れ）ときは true。アプリが前面に戻ったときにも呼ぶ。
  Future<bool> checkAccount() async {
    if (_sessionLost || _signingOut) return !_sessionLost;
    try {
      if (await _auth.accountExists().timeout(_accountCheckTimeout)) {
        return true;
      }
    } on Exception catch (e, s) {
      logger.w('Account check skipped', e, s);
      return true;
    }
    final lost = _loseSession();
    try {
      await _auth.signOut();
    } on Exception catch (e, s) {
      logger.w('Sign-out after an unavailable account failed', e, s);
    }
    await lost;
    return false;
  }

  void _listen() {
    _subscription = _leafletRepository.watchLeaflets().listen((leaflets) {
      logger.i('leaflets.length: ${leaflets.length}');
      _leaflets = sortLeaflets(leaflets, DateTime.now());
      for (final leaflet in leaflets) {
        unawaited(_widget.updateTitleFor(leaflet.key, leaflet.title));
      }
      _hasLoaded = true;
      notifyListeners();
    }, onError: (Object e) => logger.e('leaflets listen failed', e));
  }

  @override
  void dispose() {
    _disposed = true;
    deviceZoneListenable.removeListener(notifyListeners);
    unawaited(push.dispose());
    unawaited(_subscription?.cancel());
    unawaited(_writeFailures?.cancel());
    unawaited(_signedOutSubscription?.cancel());
    super.dispose();
  }

  /// 自分の uid。
  String? get myUid => _auth.currentUser?.uid;

  /// 自分がしおりのオーナーか。
  bool isOwner(LeafletEntity leaflet) =>
      leaflet.ownerUid != null && leaflet.ownerUid == myUid;

  /// サンプルを作る言語コード。
  String get languageCode => l10n.localeName;

  /// 自分のニックネーム。共同編集のバッジの頭文字になる。
  String? get nickname => _auth.currentUser?.name;

  /// ニックネームを保存する。長さが規則に合わなければ、保存せずに false を返す。
  Future<bool> updateNickname(String name) => _saveNickname(name);

  /// 共同編集で使うニックネームの初期値。保存済みならそれ、無ければ端末の機種名。
  Future<String> suggestedNickname() async {
    final saved = nickname;
    if (saved != null && isValidNickname(saved)) {
      return normalizeNickname(saved);
    }
    return nicknameFromDeviceName(await _deviceName.modelName());
  }

  Future<bool> _saveNickname(String raw, {bool report = true}) async {
    if (!isValidNickname(raw)) {
      if (report) onWriteError?.call(l10n.nicknameInvalid(nicknameMaxLength));
      return false;
    }
    final name = normalizeNickname(raw);
    if (name == nickname) return true;
    try {
      await _auth.updateName(name);
    } on Exception catch (e, s) {
      logger.e('Failed: ${WriteTask.saveNickname.name}', e, s);
      if (report) onWriteError?.call(l10n.writeFailed(WriteTask.saveNickname));
      return false;
    }
    notifyListeners();
    return true;
  }

  /// [key] のしおり。一覧に無ければ null。
  LeafletEntity? leafletByKey(String key) {
    for (final leaflet in _leaflets) {
      if (leaflet.key == key) return leaflet;
    }
    return null;
  }

  /// 一覧の分類名。まだ始まっていないしおりは `Next`、旅行中は `Now`、それ以外は開始年。
  List<String> getLeafletsGroupNames() {
    return groupNamesOf(_leaflets, DateTime.now());
  }

  /// [groupName] に属するしおり。
  List<LeafletEntity> getLeafletsBy(String groupName) {
    return leafletsInGroup(_leaflets, groupName, DateTime.now());
  }

  /// しおりを作る。
  Future<void> addLeaflet(String title) {
    logger.i('addLeaflet title: $title');
    return _write(
      WriteTask.createTrip,
      () => _leafletRepository.addLeaflet(title, coverEmoji: '✈️'),
    );
  }

  /// 試しに眺められるサンプルのしおりを、自分のしおりとして追加する。
  ///
  /// 追加した冊数を返す。失敗したら 0。
  Future<int> addSampleLeaflets({
    void Function(SampleInstallProgress progress)? onProgress,
  }) async {
    var count = 0;
    final ok = await _write(WriteTask.addSamples, () async {
      count = await installSampleLeaflets(
        leaflets: _leafletRepository,
        marks: _markRepository,
        notes: _noteRepository,
        languageCode: languageCode,
        onProgress: onProgress,
      );
    });
    return ok ? count : 0;
  }

  /// タイトルだけを保存する。
  Future<void> updateLeafletTitle(String key, String title) => _write(
    WriteTask.updateTrip,
    () => _leafletRepository.updateLeafletTitle(key, title),
  );

  /// 表紙だけを保存する。
  Future<void> updateLeafletCover(
    String key, {
    String? imageUrl,
    int? coverColor,
  }) => _write(
    WriteTask.updateTrip,
    () => _leafletRepository.updateLeafletCover(
      key,
      imageUrl: imageUrl,
      coverColor: coverColor,
    ),
  );

  /// しおりと、それに紐づく旅程・ノートを削除する。オーナーのみ。
  Future<void> deleteLeaflet(LeafletEntity entity) async {
    logger.i('deleteLeaflet title: ${entity.title}');
    final ok = await _write(
      WriteTask.deleteTrip,
      () => _leafletRepository.deleteLeaflet(entity),
    );
    if (ok) {
      await _passphrases.delete(entity.key);
      await _widget.clearFor(entity.key);
    }
  }

  /// ニックネームを保存してから、共同編集を有効にして、あいことばを設定する。成功したら true。
  ///
  /// ニックネームを先に保存する。サーバーは、参加や停止の通知に、この名前を使うため。
  Future<bool> enableSharing(
    LeafletEntity leaflet,
    String passphrase, {
    required String nickname,
  }) async {
    if (!await _saveNickname(nickname)) return false;
    final ok = await _write(
      WriteTask.enableSharing,
      () => _leafletRepository.enableSharing(leaflet, passphrase),
    );
    if (ok) {
      await _passphrases.write(leaflet.key, passphrase);
      // 参加の通知を受け取れるよう、通知の許可を尋ねる（1 回だけ）。
      unawaited(push.ensurePermission());
    }
    return ok;
  }

  /// 共同編集を停止する。成功したら true。
  Future<bool> disableSharing(LeafletEntity leaflet) async {
    final ok = await _write(
      WriteTask.disableSharing,
      () => _leafletRepository.disableSharing(leaflet),
    );
    if (ok) await _passphrases.delete(leaflet.key);
    return ok;
  }

  /// この端末に保存しているあいことば。オーナーが設定した端末だけが持つ。
  Future<String?> savedPassphrase(LeafletEntity leaflet) =>
      _passphrases.read(leaflet.key);

  /// 参加しているしおりから抜ける。
  ///
  /// 抜けたら、ホーム画面のウィジェットが、そのしおりを表示していたときは、そのデータも消す。
  Future<void> leaveLeaflet(LeafletEntity leaflet) async {
    final ok = await _write(
      WriteTask.leaveTrip,
      () => _leafletRepository.leaveLeaflet(leaflet),
    );
    if (ok) await _widget.clearFor(leaflet.key);
  }

  /// 自分の匿名アカウントと、サーバーにある自分のデータを消す。成功したら true。
  ///
  /// 順番：自分がオーナーのしおりを削除（参加者に「削除」の通知が届く）→ 参加しているしおりから抜ける
  /// （オーナーに「脱退」の通知が届く）→ 索引と通知のトークンを消す → アカウントを削除する。
  /// アカウントを最後にするのは、途中で失敗しても、同じ操作でやり直せるようにするため
  /// （アカウントが先に消えると、データを消す権限が無くなる）。
  /// 他のしおりに自分が書いた旅程とノートは、書いた人を記録していないので、残る。
  Future<bool> deleteAccount() async {
    _accountUnavailable = false;
    // 削除の途中で起きるサインアウトは、自分の操作なので、失効として扱わない。
    _signingOut = true;
    final ok = await _write(WriteTask.deleteAccount, () async {
      if (!await _auth.accountExists().timeout(_accountOperationTimeout)) {
        await _resetUnavailableAccount();
        return;
      }
      await _requireOnline?.call().timeout(_accountOperationTimeout);
      for (final leaflet in List.of(_leaflets)) {
        if (isOwner(leaflet)) {
          // 各段階に上限があり、送信後の時間切れは結果不明として届く。
          await _leafletRepository.deleteLeaflet(leaflet);
        } else {
          await _leafletRepository
              .leaveLeaflet(leaflet)
              .timeout(
                _accountOperationTimeout,
                onTimeout: () => throw const WriteUnconfirmed(),
              );
        }
        await _passphrases
            .delete(leaflet.key)
            .timeout(_accountOperationTimeout);
        await _widget.clearFor(leaflet.key).timeout(_accountOperationTimeout);
      }
      await _leafletRepository.removeMyIndex();
      await push.unregister().timeout(
        _accountOperationTimeout,
        onTimeout: () => throw const WriteUnconfirmed(),
      );
      // アカウントを消すと、一覧の購読は、権限が無くなって、エラーになる。先に止める。
      unawaited(_subscription?.cancel());
      try {
        await _auth.deleteAccount();
      } on FirebaseAuthException catch (error) {
        if (FirebaseAuthGateway.isUnavailableAccount(error)) {
          await _resetUnavailableAccount();
          return;
        }
        _listen();
        rethrow;
      } on Object {
        // 消せなかったときは、アカウントが残るので、一覧の購読を戻す。
        _listen();
        rethrow;
      }
    });
    if (!ok) {
      _signingOut = false;
      // 失敗している間に、失効でサインアウトされていたときは、知らせる。
      if (_auth.currentUser == null) unawaited(_loseSession());
    }
    return ok;
  }

  Future<void> _resetUnavailableAccount() async {
    try {
      await _subscription?.cancel().timeout(_accountOperationTimeout);
      await _discardLocalData();
      await _auth.signOut().timeout(_accountOperationTimeout);
    } on Exception {
      if (_auth.currentUser != null) _listen();
      rethrow;
    }
    _accountUnavailable = true;
    logger.w(
      'Unavailable account signed out; server data deletion unconfirmed',
    );
  }

  /// ニックネームを保存してから、入力された ID とあいことばで参加する。
  ///
  /// ニックネームを先に保存する。サーバーは、参加の通知に、この名前を使うため。
  /// 成功したら null、失敗したら画面に出す説明を返す。
  Future<String?> joinLeaflet(
    String idInput,
    String passphrase, {
    required String nickname,
  }) async {
    final id = normalizeLeafletId(idInput);
    if (id == null) return l10n.tripIdInvalid;
    if (!isValidPassphrase(passphrase)) {
      return l10n.passphraseTooShort(passphraseMinLength);
    }
    if (!isValidNickname(nickname)) {
      return l10n.nicknameInvalid(nicknameMaxLength);
    }
    if (_auth.currentUser == null) {
      unawaited(_loseSession());
      return l10n.sessionLostTitle;
    }
    if (!await checkAccount()) return l10n.sessionLostTitle;
    if (!await _saveNickname(nickname, report: false)) {
      return l10n.writeFailed(WriteTask.saveNickname);
    }
    try {
      await _leafletRepository.joinLeaflet(id, passphrase);
      // 削除と停止の通知を受け取れるよう、通知の許可を尋ねる（1 回だけ）。
      unawaited(push.ensurePermission());
      return null;
    } on JoinFailure catch (e) {
      return switch (e.reason) {
        JoinFailureReason.invalidInput => l10n.joinInvalid,
        JoinFailureReason.rejected => l10n.joinRejected,
        JoinFailureReason.alreadyJoined => l10n.joinAlready,
        JoinFailureReason.network => l10n.joinNetwork,
        JoinFailureReason.unconfirmed => l10n.joinUnconfirmed,
      };
    }
  }

  Future<bool> _write(WriteTask task, Future<void> Function() action) async {
    // 失効でサインアウトされたあとは書けない。黙って失敗させず、起動画面へ戻す流れに乗せる。
    if (task != WriteTask.deleteAccount && _auth.currentUser == null) {
      unawaited(_loseSession());
      return false;
    }
    if (_accountCheckedTasks.contains(task) && !await checkAccount()) {
      return false;
    }
    try {
      await action();
      return true;
    } on WriteUnconfirmed catch (e, s) {
      logger.w('Unconfirmed: ${task.name}', e, s);
      onWriteError?.call(l10n.writeUnconfirmed(task));
      return false;
    } on Exception catch (e, s) {
      logger.e('Failed: ${task.name}', e, s);
      onWriteError?.call(l10n.writeFailed(task));
      return false;
    }
  }
}

/// 開始日の新しい順に並べる。開始日の無いしおりは [now] として扱う。
List<LeafletEntity> sortLeaflets(List<LeafletEntity> leaflets, DateTime now) {
  return [...leaflets]..sort((a, b) {
    final aDate = a.firstDate ?? now;
    final bDate = b.firstDate ?? now;
    return bDate.compareTo(aDate);
  });
}

const _upcomingGroup = 'Next';
const _ongoingGroup = 'Now';

String _groupNameOf(LeafletEntity leaflet, DateTime now) {
  final firstDate = leaflet.firstDate;
  final lastDate = leaflet.lastDate;
  final seconds = now.secondsSinceEpoch();
  if (firstDate == null || firstDate.secondsSinceEpoch() > seconds) {
    return _upcomingGroup;
  }
  if (lastDate != null && lastDate.secondsSinceEpoch() > seconds) {
    return _ongoingGroup;
  }
  return formatInZone(firstDate, leaflet.firstTimeZoneId ?? '', 'yyyy');
}

/// 区分の並び。`Next`、`Now`、過去の年（新しい順）。
int _groupRank(String name) => switch (name) {
  _upcomingGroup => 0,
  _ongoingGroup => 1,
  _ => 2,
};

/// 一覧の分類名を、`Next`、`Now`、過去の年（新しい順）の順に、重複なく返す。
List<String> groupNamesOf(List<LeafletEntity> leaflets, DateTime now) {
  final names = <String>{
    for (final leaflet in leaflets) _groupNameOf(leaflet, now),
  }.toList();
  return names..sort((a, b) {
    final rank = _groupRank(a).compareTo(_groupRank(b));
    return rank != 0 ? rank : b.compareTo(a);
  });
}

/// [groupName] に属するしおりを返す。
List<LeafletEntity> leafletsInGroup(
  List<LeafletEntity> leaflets,
  String groupName,
  DateTime now,
) {
  return [
    for (final leaflet in leaflets)
      if (_groupNameOf(leaflet, now) == groupName) leaflet,
  ];
}
