import 'package:flutter/foundation.dart';

import 'app_services.dart';

/// 現在使っている接続先（[AppServices]）。
///
/// アプリの最上位に置き、画面遷移で作られる新しいルートからも読めるようにする。
/// 起動直後は何も選ばれておらず、起動画面で「はじめる」を押すと接続先が決まる。
/// 決めた接続先は、アプリを終了するまで変わらない（サインアウトの操作は無い）。
class AppSession extends ChangeNotifier {
  AppServices? _services;
  Future<AppServices> Function()? _connect;

  /// 選ばれた接続先。まだ選ばれていなければ null。
  AppServices? get services => _services;

  /// 起動画面が使った、接続先を用意する処理。アカウントを削除したあと、同じ起動画面に戻るために覚えておく。
  /// 省かれていた（本番の接続）ときは null。
  Future<AppServices> Function()? get connect => _connect;

  /// 接続先を選んで、画面に知らせる。
  void start(AppServices services, {Future<AppServices> Function()? connect}) {
    _services = services;
    _connect = connect;
    notifyListeners();
  }
}
