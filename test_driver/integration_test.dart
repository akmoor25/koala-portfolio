import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// `flutter drive` の実行側。テストが撮ったスクリーンショットを、
/// 環境変数 SCREENSHOT_DIR（無ければ screenshots/）に PNG で保存する。
Future<void> main() async {
  final dir = Directory(Platform.environment['SCREENSHOT_DIR'] ?? 'screenshots')
    ..createSync(recursive: true);

  await integrationDriver(
    onScreenshot: (name, image, [args]) async {
      File('${dir.path}/$name.png').writeAsBytesSync(image);
      return true;
    },
  );
}
