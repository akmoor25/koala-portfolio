import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'app_services.dart';
import 'app_session.dart';

/// アプリ全体で共有する [AppServices] を [BuildContext] から取り出す。
extension AppServicesContext on BuildContext {
  /// 画面と Model が使うデータアクセス。接続先（本番は Firebase、テストはメモリ上の偽物）は意識しない。
  ///
  /// 接続先が選ばれていない状態では呼べない。
  AppServices get services {
    final services = read<AppSession>().services;
    if (services == null) {
      throw StateError(
        'No connection has been chosen. Start from the launch screen.',
      );
    }
    return services;
  }

  /// 接続先を選ぶための窓口。
  AppSession get session => read<AppSession>();
}
