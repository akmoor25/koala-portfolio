import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../firebase_options.dart';
import '../helper/data_collection.dart';
import '../helper/device_name.dart';
import '../helper/secure_passphrase_store.dart';
import '../helper/trip_widget_publisher.dart';
import '../notifications/push_gateway.dart';
import 'firebase/firebase_local_writes.dart';
import 'firebase/firebase_services.dart';

/// アプリが使うデータアクセスの一式。画面と Model はこれだけに依存する。
///
/// 各項目は具象クラスのまま持つ。テストでは、それぞれの具象クラスを
/// `implements` した偽物に差し替える（Dart では、`base` や `final` などの
/// 修飾子を付けないクラスは、暗黙的にインターフェースも持つ）。
class AppServices {
  /// すべてのリポジトリを受け取る。
  const AppServices({
    required this.auth,
    required this.leaflets,
    required this.marks,
    required this.notes,
    required this.presence,
    required this.passphrases,
    required this.widget,
    required this.deviceName,
    required this.push,
    required this.deviceTokens,
    this.localWrites,
    this.requireOnline,
  });

  /// 認証。
  final FirebaseAuthGateway auth;

  /// しおり。
  final FirebaseLeafletRepository leaflets;

  /// 旅程。
  final FirebaseMarkRepository marks;

  /// ノート。
  final FirebaseNoteRepository notes;

  /// 共同編集中のカーソル。
  final FirebasePresenceRepository presence;

  /// オーナーのあいことば（端末内）。
  final SecurePassphraseStore passphrases;

  /// ホーム画面ウィジェット。
  final NativeTripWidgetPublisher widget;

  /// 端末の機種名（ニックネームの初期値）。
  final DeviceNameSource deviceName;

  /// プッシュ通知（FCM）。
  final FirebasePushGateway push;

  /// 通知の宛先になる、この端末のトークン。
  final FirebaseDeviceTokenRepository deviceTokens;

  /// 本番の書き込みキュー。ローカル反映後の同期エラーを通知する。
  final FirebaseLocalWrites? localWrites;

  /// アカウント削除の前提となる接続確認。偽物では不要。
  final Future<void> Function()? requireOnline;
}

/// Firebase を初期化し、匿名でサインインして、接続先を返す。
///
/// アカウント登録は求めない。すでにサインイン済みなら同じユーザーで続ける。
/// Crashlytics の収集と FCM の自動初期化は、マニフェストと Info.plist で止めてあり、
/// ここ（利用者が「はじめる」を押したあと）で、初めて有効にする。起動のたびに通る。
Future<AppServices> connectToFirebase() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseDatabase.instance.setPersistenceEnabled(true);
  }
  await const DataCollection().start();
  final services = createFirebaseServices();
  await services.auth.signInAnonymously();
  await services.widget.init();
  return services;
}

/// Firebase に接続する [AppServices] を作る。
AppServices createFirebaseServices() {
  final root = FirebaseDatabase.instance.ref();
  final auth = FirebaseAuthGateway();
  final writes = FirebaseLocalWrites();
  return AppServices(
    auth: auth,
    leaflets: FirebaseLeafletRepository(root, auth, writes: writes),
    marks: FirebaseMarkRepository(root, writes: writes),
    notes: FirebaseNoteRepository(root, writes: writes),
    presence: FirebasePresenceRepository(root, auth, writes: writes),
    passphrases: const SecurePassphraseStore(),
    widget: const NativeTripWidgetPublisher(),
    deviceName: const DeviceNameSource(),
    push: FirebasePushGateway(),
    deviceTokens: FirebaseDeviceTokenRepository(root, auth, writes: writes),
    localWrites: writes,
    requireOnline: () => requireFirebaseConnection(root),
  );
}
