import 'package:flutter/foundation.dart';

import '../data/app_services.dart';
import '../logger.dart';

/// 接続先を用意する処理。
typedef Connector = Future<AppServices> Function();

/// 起動画面の状態。「はじめる」で接続先を用意する。
class LaunchModel extends ChangeNotifier {
  /// [connect] を省くと Firebase に匿名で接続する。テストでは差し替える。
  LaunchModel({Connector? connect}) : _connect = connect ?? connectToFirebase;

  final Connector _connect;

  /// 起動時のアカウント確認を待つ上限。過ぎたら、オフラインとみなして続ける。
  static const _accountCheckTimeout = Duration(seconds: 5);

  bool _busy = false;
  bool _failed = false;
  bool _accountLost = false;

  /// 接続中か。
  bool get busy => _busy;

  /// 直近の接続に失敗したか。成功した、またはまだなら false。
  bool get failed => _failed;

  /// 直近の接続で、端末に残っていたアカウントが、削除済み・失効と分かったか。
  ///
  /// そのときはサインアウト済みで、もう一度「はじめる」を押すと、新しい匿名ユーザーになる。
  bool get accountLost => _accountLost;

  /// 接続先を用意する。失敗したら null を返し、[failed] を true にする。
  ///
  /// 端末に残っていたアカウントが使えなくなっていたら、端末側の後片付けとサインアウトをして、
  /// null を返し、[accountLost] を true にする。確認できない（オフラインなど）ときは、そのまま続ける。
  Future<AppServices?> start() async {
    if (_busy) return null;
    _busy = true;
    _failed = false;
    _accountLost = false;
    notifyListeners();
    try {
      final services = await _connect();
      if (await _isUnavailable(services)) {
        await _discard(services);
        _accountLost = true;
        return null;
      }
      return services;
    } on Exception catch (e, s) {
      logger.e('Failed to connect', e, s);
      _failed = true;
      return null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> _isUnavailable(AppServices services) async {
    try {
      return !await services.auth.accountExists().timeout(_accountCheckTimeout);
    } on Exception catch (e, s) {
      logger.w('Account check skipped', e, s);
      return false;
    }
  }

  Future<void> _discard(AppServices services) async {
    logger.w('Saved account is no longer available; signing out');
    await services.passphrases.deleteAll();
    await services.widget.clear();
    await services.auth.signOut();
  }
}
