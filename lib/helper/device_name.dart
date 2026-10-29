import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

import '../logger.dart';

/// 端末の機種名（Pixel 10a など）。ニックネームの初期値に使う。
///
/// 利用者が端末に付けた名前（「〇〇の Pixel」など）は、個人の名前を含みうるので使わない。
/// テストでは、これを `implements` した偽物に差し替える。
class DeviceNameSource {
  /// 何も受け取らない。
  const DeviceNameSource();

  /// 機種名。取れなければ空の文字列。
  Future<String> modelName() async {
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) return (await plugin.androidInfo).model;
      if (Platform.isIOS) return (await plugin.iosInfo).modelName;
    } on Exception catch (e, s) {
      logger.e('Could not read the device model', e, s);
    }
    return '';
  }
}
