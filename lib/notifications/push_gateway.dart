import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'push_message.dart';

/// 通知の許可の状態。
enum PushPermission {
  /// まだ尋ねていない。
  notDetermined,

  /// 許可されている。
  authorized,

  /// 拒否されている。
  denied,
}

/// Firebase Cloud Messaging（FCM）を包む。
///
/// 画面と Model は、これだけに依存する。テストでは、これを `implements` した偽物に差し替える。
class FirebasePushGateway {
  /// 既定の [FirebaseMessaging] を使う。
  FirebasePushGateway([FirebaseMessaging? messaging])
    : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  /// いまの許可の状態。
  Future<PushPermission> permission() async {
    final settings = await _messaging.getNotificationSettings();
    return pushPermissionOf(settings.authorizationStatus);
  }

  /// 許可を尋ねる（OS の確認が出る）。結果の状態を返す。
  Future<PushPermission> requestPermission() async {
    final settings = await _messaging.requestPermission();
    return pushPermissionOf(settings.authorizationStatus);
  }

  /// この端末の FCM のトークン。取れなければ null。
  Future<String?> token() => _messaging.getToken();

  /// この端末の FCM のトークンを破棄する（FCM が、このトークンへの送信を止める）。
  Future<void> deleteToken() => _messaging.deleteToken();

  /// トークンが更新されたとき。
  Stream<String> get tokenRefreshes => _messaging.onTokenRefresh;

  /// アプリが前面にあるときに届いた通知。
  Stream<PushMessage> get foregroundMessages =>
      pushMessagesOf(FirebaseMessaging.onMessage);

  /// 背面にあるアプリが、通知のタップで開かれたとき。
  Stream<PushMessage> get openedMessages =>
      pushMessagesOf(FirebaseMessaging.onMessageOpenedApp);

  /// 終了していたアプリが、通知のタップで起動したときの通知。無ければ null。
  Future<PushMessage?> initialMessage() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : PushMessage.fromData(message.data);
  }
}

/// FCM の許可の状態を、アプリの 3 つの状態にまとめる。
///
/// 仮の許可（provisional）でも通知は届くので、許可として扱う。
PushPermission pushPermissionOf(AuthorizationStatus status) {
  return switch (status) {
    AuthorizationStatus.authorized ||
    AuthorizationStatus.provisional => PushPermission.authorized,
    AuthorizationStatus.denied ||
    AuthorizationStatus.deniedPermanently => PushPermission.denied,
    AuthorizationStatus.notDetermined => PushPermission.notDetermined,
  };
}

/// 届いた FCM のメッセージを、アプリの通知に変える。読めないものは捨てる。
Stream<PushMessage> pushMessagesOf(Stream<RemoteMessage> messages) => messages
    .map((message) => PushMessage.fromData(message.data))
    .where((message) => message != null)
    .cast<PushMessage>();
