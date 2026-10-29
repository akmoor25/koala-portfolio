import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../build_info.dart';
import '../components/app_button.dart';
import '../components/app_dialog_actions.dart';
import '../components/confirm_delete_dialog.dart';
import '../components/portfolio_notice.dart';
import '../components/spacing.dart';
import '../entity/leaflet_entity.dart';
import '../error_handlers.dart';
import '../helper/nickname_policy.dart';
import '../l10n/l10n.dart';
import '../legal/legal_links.dart';
import '../logger.dart';
import '../sharing/share_screen.dart';
import 'leaflet_card.dart';
import 'leaflets_model.dart';

/// 表紙に入力できる絵文字の数（見た目の文字数）。壁紙はこの絵文字を順に繰り返して敷き詰める。
const _maxCoverEmojis = 5;

/// 表紙の設定で、変更後の見た目を確かめるカードの幅。一覧のカードと同じくらいの大きさにする。
const double _coverPreviewWidth = 140;

/// ニックネームを入力するダイアログを出す。
Future<void> showNicknameDialog(BuildContext context, LeafletsModel model) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _NicknameDialog(model: model),
  );
}

class _NicknameDialog extends StatefulWidget {
  const _NicknameDialog({required this.model});

  final LeafletsModel model;

  @override
  State<_NicknameDialog> createState() => _NicknameDialogState();
}

class _NicknameDialogState extends State<_NicknameDialog> {
  late final _controller = TextEditingController(
    text: widget.model.nickname ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) => AlertDialog(
        title: Text(context.l10n.nickname),
        content: TextField(
          autofocus: true,
          controller: _controller,
          maxLength: nicknameMaxLength,
          decoration: InputDecoration(
            helperText: context.l10n.nicknameHelper(nicknameMaxLength),
            helperMaxLines: 2,
          ),
        ),
        actions: [
          AppButton(
            kind: AppButtonKind.text,
            onPressed: () => Navigator.pop(context),
            label: context.l10n.cancel,
          ),
          AppButton(
            onPressed: isValidNickname(_controller.text)
                ? () {
                    Navigator.pop(context);
                    unawaited(widget.model.updateNickname(_controller.text));
                  }
                : null,
            label: context.l10n.save,
          ),
        ],
      ),
    );
  }
}

/// 「このアプリについて」を出す。バージョン、ライセンス、ポートフォリオ専用の注意を含む。
Future<void> showAppAboutDialog(BuildContext context) async {
  final info = await PackageInfo.fromPlatform();
  if (!context.mounted) return;
  showAboutDialog(
    context: context,
    applicationName: context.l10n.appName,
    applicationVersion: '${info.version}(${info.buildNumber})',
    applicationIcon: ClipRRect(
      borderRadius: BorderRadius.circular(16.0),
      child: Image.asset('assets/app_icon/app_icon.png', width: 48, height: 48),
    ),
    children: [
      // 長押しで、Crashlytics にテストのエラーを 1 件送れる（送信の動作確認用）。
      GestureDetector(
        onLongPress: () {
          final sent = reportTestError();
          final l10n = context.l10n;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                sent ? l10n.crashTestSent : l10n.crashTestUnavailable,
              ),
            ),
          );
        },
        child: Text(context.l10n.buildLabel(gitCommit)),
      ),
      const VGap.medium(),
      const PortfolioNotice(),
      const VGap.small(),
      const LegalLinks(),
    ],
  );
}

/// アカウントと、サーバーにある自分のデータを、削除してよいかを確かめる。削除するなら true。
Future<bool> showDeleteAccountConfirmDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      final l10n = context.l10n;
      return AlertDialog(
        title: Text(l10n.deleteAccountConfirmTitle),
        content: SingleChildScrollView(
          child: Text(l10n.deleteAccountConfirmBody),
        ),
        actionsAlignment: MainAxisAlignment.spaceAround,
        actions: [
          AppButton(
            kind: AppButtonKind.text,
            onPressed: () => Navigator.pop(context, false),
            label: l10n.cancel,
          ),
          AppButton(
            kind: AppButtonKind.danger,
            onPressed: () => Navigator.pop(context, true),
            label: l10n.delete,
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}

/// 削除の間、操作を止めて、進行中であることを出す。閉じるには、返された関数を呼ぶ。
VoidCallback showDeleteAccountProgress(BuildContext context) {
  final navigator = Navigator.of(context, rootNavigator: true);
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const HGap.large(),
              Expanded(child: Text(context.l10n.deleteAccountProgress)),
            ],
          ),
        ),
      ),
    ),
  );
  return navigator.pop;
}

Future<void> showLeafletCreationDialog(
  BuildContext context,
  LeafletsModel model,
) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      var inputText = "";
      return SimpleDialog(
        title: Text(context.l10n.newTripDialogTitle),
        children: [
          Padding(
            padding: AppInsets.medium,
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(labelText: context.l10n.titleLabel),
              keyboardType: TextInputType.multiline,
              maxLines: null,
              onChanged: (text) {
                inputText = text;
              },
            ),
          ),
          AppDialogActions(
            accent: true,
            confirmLabel: context.l10n.create,
            onConfirm: () {
              unawaited(model.addLeaflet(inputText));
              Navigator.pop(context);
            },
          ),
        ],
      );
    },
  );
}

Future<void> showLeafletOptionDialog(
  BuildContext context,
  LeafletsModel model,
  LeafletEntity leaflet,
) {
  final navigator = Navigator.of(context);
  return showDialog<void>(
    context: context,
    builder: (context) {
      return SimpleDialog(
        title: Text(
          leaflet.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        children: [
          _MenuItem(
            label: context.l10n.changeTitle,
            onPressed: () {
              unawaited(showChangingTitleDialog(context, model, leaflet));
            },
          ),
          _MenuItem(
            label: context.l10n.changeCover,
            onPressed: () {
              unawaited(showChangingCoverEmojiDialog(context, model, leaflet));
            },
          ),
          if (model.isOwner(leaflet)) ...[
            _MenuItem(
              label: leaflet.shared
                  ? context.l10n.sharedEditingSettings
                  : context.l10n.startSharedEditing,
              onPressed: () {
                Navigator.pop(context);
                unawaited(
                  navigator.push(
                    MaterialPageRoute<void>(
                      builder: (context) =>
                          ShareScreen(model: model, leafletKey: leaflet.key),
                    ),
                  ),
                );
              },
            ),
            _MenuItem(
              label: context.l10n.deleteTrip,
              danger: true,
              onPressed: () {
                unawaited(showDeleteLeafletDialog(context, model, leaflet));
              },
            ),
          ] else
            _MenuItem(
              label: context.l10n.leaveTrip,
              danger: true,
              onPressed: () {
                unawaited(showLeaveLeafletDialog(context, model, leaflet));
              },
            ),
        ],
      );
    },
  );
}

Future<void> showChangingTitleDialog(
  BuildContext context,
  LeafletsModel model,
  LeafletEntity leaflet,
) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      var inputText = leaflet.title;
      return SimpleDialog(
        title: Text(leaflet.title),
        children: [
          Padding(
            padding: AppInsets.medium,
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(labelText: context.l10n.titleLabel),
              controller: TextEditingController(text: leaflet.title),
              keyboardType: TextInputType.multiline,
              maxLines: null,
              onChanged: (text) {
                inputText = text;
              },
            ),
          ),
          AppDialogActions(
            confirmLabel: context.l10n.ok,
            onConfirm: () {
              unawaited(model.updateLeafletTitle(leaflet.key, inputText));
              Navigator.pop(context);
              Navigator.pop(context);
            },
          ),
        ],
      );
    },
  );
}

Future<void> showChangingCoverEmojiDialog(
  BuildContext context,
  LeafletsModel model,
  LeafletEntity leaflet,
) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      var inputText = leaflet.coverEmoji;
      var selectedColor = leaflet.coverColor ?? 0xFF2196F3;
      final controller = TextEditingController(text: inputText);
      final colors = [
        0xFFF44336, // 赤色 (Red)
        0xFFFF9800, // 橙色 (Orange)
        0xFFFFC107, // 黄橙色 (Amber)
        0xFFFFEB3B, // 黄色 (Yellow)
        0xFF8BC34A, // 黄緑 (Light Green)
        0xFF4CAF50, // 緑 (Green)
        0xFF009688, // 青緑 (Teal)
        0xFF2196F3, // 青 (Blue)
        0xFF03A9F4, // 緑青 (Light Blue)
        0xFF3F51B5, // 青紫 (Indigo)
        0xFF9C27B0, // 紫 (Purple)
        0xFFE91E63, // 赤紫 (Pink)
        0xFF9E9E9E, // 灰色 (Grey)
      ];

      return StatefulBuilder(
        builder: (context, setState) {
          return SimpleDialog(
            title: Text(context.l10n.coverDialogTitle),
            children: [
              Padding(
                padding: AppInsets.medium,
                child: TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: context.l10n.emojiLabel,
                  ),
                  controller: controller,
                  keyboardType: TextInputType.text,
                  maxLength: _maxCoverEmojis,
                  maxLengthEnforcement:
                      MaxLengthEnforcement.truncateAfterCompositionEnds,
                  onChanged: (text) {
                    setState(() {
                      inputText = text;
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.medium,
                  vertical: AppSpace.small,
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: colors.map((colorValue) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedColor = colorValue;
                        });
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Color(colorValue),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selectedColor == colorValue
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.12),
                            width: selectedColor == colorValue ? 2 : 1,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.medium,
                  vertical: AppSpace.small,
                ),
                child: Center(
                  child: SizedBox(
                    width: _coverPreviewWidth,
                    child: LeafletCard(
                      leaflet: LeafletEntity(
                        leaflet.key,
                        leaflet.title,
                        inputText,
                        selectedColor,
                        leaflet.firstDate,
                        leaflet.lastDate,
                        firstTimeZoneId: leaflet.firstTimeZoneId,
                        lastTimeZoneId: leaflet.lastTimeZoneId,
                        ownerUid: leaflet.ownerUid,
                        shared: leaflet.shared,
                      ),
                    ),
                  ),
                ),
              ),
              AppDialogActions(
                confirmLabel: context.l10n.ok,
                onConfirm: () {
                  if (inputText.isNotEmpty) {
                    unawaited(
                      model.updateLeafletCover(
                        leaflet.key,
                        imageUrl: inputText,
                        coverColor: selectedColor,
                      ),
                    );
                  }
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> showLeaveLeafletDialog(
  BuildContext context,
  LeafletsModel model,
  LeafletEntity leaflet,
) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(context.l10n.leaveQuestion(leaflet.title)),
        content: Text(context.l10n.leaveBody),
        actions: [
          AppButton(
            kind: AppButtonKind.text,
            onPressed: () => Navigator.pop(context),
            label: context.l10n.cancel,
          ),
          AppButton(
            kind: AppButtonKind.danger,
            onPressed: () {
              unawaited(model.leaveLeaflet(leaflet));
              Navigator.pop(context);
              Navigator.pop(context);
            },
            label: context.l10n.leave,
          ),
        ],
      );
    },
  );
}

/// しおりの削除を確かめて実行する。実行したら、呼び出し元のメニューも閉じる。
Future<void> showDeleteLeafletDialog(
  BuildContext context,
  LeafletsModel model,
  LeafletEntity leaflet,
) async {
  logger.i('showDeleteLeafletDialog leaflet: ${leaflet.title}');
  final confirmed = await showConfirmDeleteDialog(
    context,
    title: context.l10n.deleteQuestion(leaflet.title),
  );
  if (!confirmed || !context.mounted) return;
  unawaited(model.deleteLeaflet(leaflet));
  Navigator.pop(context);
}

/// 操作メニューの 1 行。幅いっぱいの、文字だけのボタン。[danger] なら、危険を示す色。
class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.label,
    required this.onPressed,
    this.danger = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.medium,
        vertical: 2,
      ),
      child: AppButton(
        kind: danger ? AppButtonKind.dangerText : AppButtonKind.text,
        label: label,
        expand: true,
        onPressed: onPressed,
      ),
    );
  }
}
