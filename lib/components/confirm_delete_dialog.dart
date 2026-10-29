import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'app_button.dart';

/// 削除してよいかを確かめるダイアログを出す。削除するなら true を返す。
///
/// 外側を閉じたりタップしたりしたときは false。
Future<bool> showConfirmDeleteDialog(
  BuildContext context, {
  required String title,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Text(context.l10n.deleteWarning),
        actionsAlignment: MainAxisAlignment.spaceAround,
        actions: [
          AppButton(
            kind: AppButtonKind.text,
            onPressed: () => Navigator.pop(context, false),
            label: context.l10n.keep,
          ),
          AppButton(
            kind: AppButtonKind.danger,
            onPressed: () => Navigator.pop(context, true),
            label: context.l10n.delete,
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
