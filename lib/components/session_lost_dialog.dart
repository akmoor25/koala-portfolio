import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'app_button.dart';

/// アカウントの削除やログインの失効で、サインアウトされたことを知らせる。OK で閉じる。
///
/// [onLaunch] は、起動画面で出すとき true。すでに起動画面にいるので、「戻ります」を省く。
/// 戻る、外側のタップでは閉じない。閉じたあとの遷移は、呼び出し元が行う。
Future<void> showSessionLostDialog(
  BuildContext context, {
  bool onLaunch = false,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (context) {
      final l10n = context.l10n;
      return PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(l10n.sessionLostTitle),
          content: SingleChildScrollView(
            child: Text(
              onLaunch ? l10n.sessionLostOnLaunchBody : l10n.sessionLostBody,
            ),
          ),
          actions: [
            AppButton(onPressed: () => Navigator.pop(context), label: l10n.ok),
          ],
        ),
      );
    },
  );
}
