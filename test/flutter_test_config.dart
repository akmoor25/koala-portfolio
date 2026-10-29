import 'dart:async';

import 'package:koala/helper/time_zones.dart';

/// すべてのテストで、端末のタイムゾーンを東京にそろえる（実行する機械の設定に左右されない）。
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setDeviceZoneForTest('Asia/Tokyo');
  await testMain();
}
