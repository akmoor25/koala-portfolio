import 'dart:async';

import 'package:koala/data/firebase/firebase_services.dart';
import 'package:koala/notifications/push_gateway.dart';
import 'package:koala/notifications/push_message.dart';

/// FCM の偽物。許可の状態、トークン、届く通知を、テストから操作できる。
class FakePushGateway implements FirebasePushGateway {
  /// 許可の状態と、トークンを決める。
  FakePushGateway({
    this.state = PushPermission.notDetermined,
    this.grantOnRequest = true,
    this.currentToken = 'fake-token',
  });

  /// いまの許可の状態。
  PushPermission state;

  /// 許可を尋ねたときに、許可されるか（OS の確認で「許可」を押す）。
  bool grantOnRequest;

  /// この端末のトークン。null なら、取れない。
  String? currentToken;

  /// 許可を尋ねた回数。
  int requests = 0;

  /// 終了していたアプリが、通知のタップで起動したときの通知。
  PushMessage? initial;

  final _refreshes = StreamController<String>.broadcast();
  final _foreground = StreamController<PushMessage>.broadcast();
  final _opened = StreamController<PushMessage>.broadcast();

  /// トークンが更新されたことにする。
  void refreshToken(String token) {
    currentToken = token;
    _refreshes.add(token);
  }

  /// アプリが前面にあるときに、通知が届いたことにする。
  void deliver(PushMessage message) => _foreground.add(message);

  /// 通知のタップで、アプリが開かれたことにする。
  void open(PushMessage message) => _opened.add(message);

  @override
  Future<PushPermission> permission() async => state;

  @override
  Future<PushPermission> requestPermission() async {
    requests++;
    state = grantOnRequest ? PushPermission.authorized : PushPermission.denied;
    return state;
  }

  @override
  Future<String?> token() async => currentToken;

  @override
  Stream<String> get tokenRefreshes => _refreshes.stream;

  @override
  Stream<PushMessage> get foregroundMessages => _foreground.stream;

  @override
  Stream<PushMessage> get openedMessages => _opened.stream;

  @override
  Future<PushMessage?> initialMessage() async => initial;

  /// トークンを破棄した回数。
  int tokenDeletions = 0;

  @override
  Future<void> deleteToken() async {
    tokenDeletions++;
    currentToken = null;
  }
}

/// 端末のトークンの置き場の偽物。利用者ごとの登録を、メモリ上に持つ。
class FakeDeviceTokens implements FirebaseDeviceTokenRepository {
  /// [uid] の利用者として、[store] に登録する。
  FakeDeviceTokens(this.uid, this.store);

  /// 自分の uid。
  final String uid;

  /// 利用者ごとのトークン。
  final Map<String, Set<String>> store;

  @override
  Future<void> register(String token) async {
    store.putIfAbsent(uid, () => {}).add(token);
  }

  @override
  Future<void> removeAll() async {
    store.remove(uid);
  }
}
