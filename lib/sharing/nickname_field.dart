import 'package:flutter/material.dart';

import '../helper/nickname_policy.dart';
import '../l10n/l10n.dart';

/// ニックネームの入力欄。共同編集を有効にする画面と、しおりに参加する画面で使う。
///
/// 決まった値（保存済みか、端末の機種名）があらかじめ入る。利用者が確かめてから進めるよう、
/// 規則に合わないあいだは、呼び出し側のボタンを押せなくする（[isValidNickname]）。
class NicknameField extends StatelessWidget {
  /// 入力を [controller] で持つ。
  const NicknameField({
    super.key,
    required this.controller,
    this.enabled = true,
  });

  /// 入力された文字。
  final TextEditingController controller;

  /// 入力できるか。
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final text = controller.text;
        final invalid = text.isNotEmpty && !isValidNickname(text);
        return TextField(
          controller: controller,
          enabled: enabled,
          maxLength: nicknameMaxLength,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: context.l10n.nickname,
            helperText: context.l10n.nicknameHelper(nicknameMaxLength),
            helperMaxLines: 2,
            errorText: invalid
                ? context.l10n.nicknameInvalid(nicknameMaxLength)
                : null,
          ),
        );
      },
    );
  }
}
