import 'package:firebase_messaging/firebase_messaging.dart';

import '../crash_reporter.dart';
import '../error_handlers.dart';
import '../logger.dart';

/// 外部への送信を、利用者の操作（「はじめる」）のあとに始める。
///
/// Android のマニフェストと iOS の Info.plist で、Crashlytics の収集と FCM の自動初期化を止めてある。
/// 「はじめる」を押したあとに [start] を呼んで、有効にする。
class DataCollection {
  /// 既定では、Firebase を使う。テストでは、[startCrashReports] と [startMessaging] を差し替える。
  const DataCollection({
    this.startCrashReports = _startCrashReports,
    this.startMessaging = _startMessaging,
  });

  /// Crashlytics の送信を始める。
  final Future<void> Function() startCrashReports;

  /// FCM の自動初期化を有効にする。
  final Future<void> Function() startMessaging;

  /// 「はじめる」のあとに呼ぶ。Crashlytics の送信を始め、FCM の自動初期化を有効にする。
  ///
  /// どちらかが失敗しても、アプリの起動は止めない。何度呼んでも害はない。
  Future<void> start() async {
    try {
      await startCrashReports();
    } on Object catch (e, s) {
      logger.e('Crashlytics start failed', e, s);
    }
    try {
      await startMessaging();
    } on Object catch (e, s) {
      logger.e('FCM auto init failed', e, s);
    }
  }
}

Future<void> _startCrashReports() async {
  const reporter = CrashReporter();
  await reporter.start();
  useCrashReporter(reporter);
}

Future<void> _startMessaging() {
  return FirebaseMessaging.instance.setAutoInitEnabled(true);
}
