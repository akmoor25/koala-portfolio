import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'spacing.dart';

/// 注意書きの種類。
enum NoticeKind {
  /// 知らせ。薄い空色。
  info,

  /// 注意。薄い黄色。
  warning,

  /// 危険、エラー。
  danger,
}

/// 面に色を付けた、注意書きの帯。アイコン、見出し（省略できる）、本文。
class NoticeBanner extends StatelessWidget {
  /// 本文は [message]。
  const NoticeBanner({
    super.key,
    required this.message,
    this.title,
    this.kind = NoticeKind.info,
    this.icon,
    this.trailing,
  });

  /// 本文。
  final String message;

  /// 見出し。
  final String? title;

  /// 種類。
  final NoticeKind kind;

  /// 左のアイコン。null なら、種類に合うアイコン。
  final IconData? icon;

  /// 右に置くウィジェット。
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final k = theme.koala;
    final (fill, content) = switch (kind) {
      NoticeKind.info => (k.brandSoft, theme.colorScheme.onSurface),
      NoticeKind.warning => (k.accentSoft, k.onAccentSoft),
      NoticeKind.danger => (
        theme.isDark ? const Color(0xFF3B1B19) : const Color(0xFFFDECEA),
        theme.isDark ? k.dangerText : k.danger,
      ),
    };
    final iconColor = switch (kind) {
      NoticeKind.info => k.brandDeep,
      _ => content,
    };
    final defaultIcon = switch (kind) {
      NoticeKind.info => Icons.info_outline,
      NoticeKind.warning => Icons.lightbulb_outline,
      NoticeKind.danger => Icons.error_outline,
    };
    final textTheme = theme.textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: content.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? defaultIcon, color: iconColor),
          const HGap.small(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: content,
                    ),
                  ),
                  const VGap.xsmall(),
                ],
                Text(
                  message,
                  style: textTheme.bodySmall?.copyWith(color: content),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
