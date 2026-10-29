import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_button.dart';
import 'spacing.dart';

/// ダイアログの下の、ボタンの並び。取り消す（文字だけ）と、決める（塗り）。
///
/// 余白、高さ、並び順をそろえる。決めるボタンは、[danger] なら深い赤、[accent] なら黄色、
/// それ以外は主色。[onCancel] が null なら、取り消すボタンを出さない。
class AppDialogActions extends StatelessWidget {
  /// 決めるボタンは [confirmLabel] と [onConfirm]。
  const AppDialogActions({
    super.key,
    required this.confirmLabel,
    required this.onConfirm,
    this.cancelLabel,
    this.onCancel,
    this.danger = false,
    this.accent = false,
    this.confirmBusy = false,
  });

  /// 決めるボタンの文字。
  final String confirmLabel;

  /// 決めるボタンを押したときの処理。null なら、無効。
  final VoidCallback? onConfirm;

  /// 取り消すボタンの文字。
  final String? cancelLabel;

  /// 取り消すボタンを押したときの処理。null なら、取り消すボタンを出さない。
  final VoidCallback? onCancel;

  /// 元に戻せない操作か。
  final bool danger;

  /// 黄色（わくわくする操作）にするか。
  final bool accent;

  /// 決める操作の処理中か。
  final bool confirmBusy;

  @override
  Widget build(BuildContext context) {
    final cancel = onCancel;
    final kind = danger
        ? AppButtonKind.danger
        : (accent ? AppButtonKind.accent : AppButtonKind.primary);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.medium,
        AppSpace.small,
        AppSpace.medium,
        12,
      ),
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: [
          if (cancel != null)
            AppButton(
              kind: AppButtonKind.text,
              label:
                  cancelLabel ??
                  MaterialLocalizations.of(context).cancelButtonLabel,
              onPressed: cancel,
            ),
          AppButton(
            kind: kind,
            label: confirmLabel,
            busy: confirmBusy,
            onPressed: onConfirm,
          ),
        ],
      ),
    );
  }
}

/// 地の上に置く、危険を示す文字のスタイル（削除、退出のラベルなど）。
TextStyle dangerTextStyle(BuildContext context) =>
    TextStyle(color: Theme.of(context).koala.dangerText);
