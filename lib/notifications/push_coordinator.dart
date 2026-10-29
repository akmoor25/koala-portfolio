import 'dart:async';

import '../data/app_services.dart';
import '../data/firebase/firebase_services.dart';
import '../logger.dart';
import 'push_gateway.dart';
import 'push_message.dart';

/// 通知の許可、トークンの登録、受け取りをまとめる。
///
/// 通知は、あくまで補助。どこかで失敗しても（Play 開発者サービスが無い、APNs が使えない、
/// 通信できないなど）、記録に残すだけで、アプリの動作には影響させない。
class PushCoordinator {
  /// [services] の通知の口を使う。
  PushCoordinator(AppServices services)
    : _push = services.push,
      _tokens = services.deviceTokens;

  final FirebasePushGateway _push;
  final FirebaseDeviceTokenRepository _tokens;

  StreamSubscription<String>? _refreshes;
  String? _registered;

  /// アプリが前面にあるときに届いた通知。
  Stream<PushMessage> get foregroundMessages => _push.foregroundMessages;

  /// 通知のタップでアプリが開かれたとき（背面から）。
  Stream<PushMessage> get openedMessages => _push.openedMessages;

  /// 終了していたアプリが、通知のタップで起動したときの通知。
  Future<PushMessage?> initialMessage() async {
    try {
      return await _push.initialMessage();
    } on Exception catch (e, s) {
      logger.e('initial message failed', e, s);
      return null;
    }
  }

  /// すでに許可されていれば、この端末のトークンを登録し、更新も追う。
  ///
  /// 許可を尋ねはしない（尋ねるのは [ensurePermission]）。何度呼んでも、害はない。
  Future<void> start() async {
    try {
      if (await _push.permission() == PushPermission.authorized) {
        await _registerAndFollow();
      }
    } on Exception catch (e, s) {
      logger.e('push start failed', e, s);
    }
  }

  /// まだ尋ねていなければ、通知の許可を 1 回だけ尋ねる。許可されたら、トークンを登録する。
  ///
  /// 拒否されていれば、もう尋ねない。共同編集を有効にした直後と、しおりに参加した直後に呼ぶ。
  Future<void> ensurePermission() async {
    try {
      var permission = await _push.permission();
      if (permission == PushPermission.notDetermined) {
        permission = await _push.requestPermission();
      }
      if (permission == PushPermission.authorized) await _registerAndFollow();
    } on Exception catch (e, s) {
      logger.e('push permission failed', e, s);
    }
  }

  Future<void> _registerAndFollow() async {
    final token = await _push.token();
    if (token != null) await _register(token);
    _refreshes ??= _push.tokenRefreshes.listen(
      (token) => unawaited(_register(token)),
      onError: (Object e) => logger.e('token refresh failed', e),
    );
  }

  Future<void> _register(String token) async {
    if (token == _registered) return;
    try {
      await _tokens.register(token);
      _registered = token;
    } on Exception catch (e, s) {
      logger.e('token registration failed', e, s);
    }
  }

  /// 購読を止める。
  Future<void> dispose() async {
    await _refreshes?.cancel();
    _refreshes = null;
  }

  /// この端末の通知の登録を、サーバーと FCM から外す。アカウントの削除のときに呼ぶ。
  ///
  /// 先に更新の購読を止める（止めないと、消した直後に、新しいトークンが登録し直される）。
  /// サーバーの登録と FCM のトークンの破棄は、どちらも、失敗してもアカウントの削除を止めない。
  /// 登録が残っても、アカウントが消えたあとの、毎日の掃除が消す（ルールが古いなどで拒否されたときも、同じ）。
  Future<void> unregister() async {
    await dispose();
    _registered = null;
    try {
      await _tokens.removeAll();
    } on Exception catch (e, s) {
      logger.w('Token removal failed; the daily cleanup will remove it', e, s);
    }
    try {
      await _push.deleteToken();
    } on Exception catch (e, s) {
      logger.w('FCM token deletion failed', e, s);
    }
  }
}
