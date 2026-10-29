import 'package:flutter/foundation.dart';

import 'crash_reporter.dart';
import 'logger.dart';

CrashReporter? _reporter;

/// エラーの送信先を決める。Firebase の初期化のあとに呼ぶ。`null` で送信を止める。
void useCrashReporter(CrashReporter? reporter) => _reporter = reporter;

/// 想定外のエラーを、握りつぶさずにログへ残し、送信先があれば Crashlytics へ送る。
///
/// - フレームワーク内のエラー（ビルド、描画など）：既定の表示（デバッグ時の
///   赤い画面やコンソール出力）を維持したうえでログにも残す。
/// - どこにも捕捉されなかった非同期のエラー：ログに残して、アプリは落とさない。
///
/// 送信先は [useCrashReporter] で決める。それまで（Firebase の初期化前）のエラーは、
/// ログだけに残る。送信に失敗しても、エラーの処理自体は失敗させない。
void installErrorHandlers() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    logger.e(
      'Flutter error: ${details.context}',
      details.exception,
      details.stack,
    );
    _report(() => _reporter?.recordFlutterError(details));
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    logger.e('Uncaught error', error, stack);
    _report(() => _reporter?.recordError(error, stack));
    return true;
  };
}

/// 送信の動作確認用に、テストのエラーを 1 件送る。送信先が無ければ false。
bool reportTestError() {
  final reporter = _reporter;
  if (reporter == null) return false;
  _report(
    () => reporter.recordError(
      StateError('Crashlytics test error'),
      StackTrace.current,
      reason: 'manual test',
    ),
  );
  return true;
}

void _report(void Function() send) {
  try {
    send();
  } on Object catch (e, stack) {
    logger.e('Crash report failed', e, stack);
  }
}
