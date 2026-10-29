import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'build_info.dart';

/// 想定外のエラーを Firebase Crashlytics へ送る。
///
/// アプリが付けるのは、エラーの内容とスタックトレース、ビルドしたコミット（カスタムキー `commit`）だけ。
/// ユーザー ID は設定せず、しおりの内容も付けない。ただし、Crashlytics の SDK が、機種・OS・アプリの版と、
/// インストールごとの識別子（Crashlytics Installation UUID、Firebase installation ID）を自動で付ける。
/// 画面側は、この具象クラスだけを知っていればよい。
/// テストでは、これを `implements` した偽物に差し替える。
class CrashReporter {
  /// Firebase の初期化のあとで作る。
  const CrashReporter();

  FirebaseCrashlytics get _crashlytics => FirebaseCrashlytics.instance;

  /// 送信を有効にし、ビルドしたコミットを記録する。
  Future<void> start() async {
    await _crashlytics.setCrashlyticsCollectionEnabled(true);
    await _crashlytics.setCustomKey('commit', gitCommit);
  }

  /// Flutter のフレームワーク内のエラーを送る。アプリは落ちないので、致命的ではない扱い。
  void recordFlutterError(FlutterErrorDetails details) {
    unawaited(_crashlytics.recordFlutterError(details));
  }

  /// どこにも捕捉されなかったエラーを送る。アプリは落ちないので、致命的ではない扱い。
  void recordError(Object error, StackTrace? stack, {String? reason}) {
    unawaited(_crashlytics.recordError(error, stack, reason: reason));
  }
}
