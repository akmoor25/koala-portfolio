import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// ラベルの種類。
enum AppBadgeTone {
  /// 「いま」。あたたかい珊瑚色。どきどきする、今この瞬間。
  now,

  /// 「つぎ」。黄色。次の出会いの合図。
  next,

  /// 補足（都市名など）。薄い空色。
  info,

  /// 共同編集中。薄い空色に、アイコン。
  shared,

  /// 注意。薄い黄色。
  warning,
}

/// [AppBadgeTone] の面の色と文字の色。
@immutable
class AppBadgeColors {
  /// 面と文字を指定する。
  const AppBadgeColors({
    required this.fill,
    required this.content,
    this.border,
  });

  /// 面の色。
  final Color fill;

  /// 文字とアイコンの色。
  final Color content;

  /// 縁の色。null なら縁なし。
  final Color? border;

  /// [tone] の色を、[theme] から決める。
  factory AppBadgeColors.of(AppBadgeTone tone, ThemeData theme) {
    final k = theme.koala;
    return switch (tone) {
      AppBadgeTone.now => AppBadgeColors(
        fill: k.hot,
        content: k.onHot,
        border: k.onHotBorder == Colors.transparent ? null : k.onHotBorder,
      ),
      AppBadgeTone.next => AppBadgeColors(
        fill: k.accent,
        content: k.onAccent,
        border: k.onAccentBorder == Colors.transparent
            ? null
            : k.onAccentBorder,
      ),
      AppBadgeTone.info => AppBadgeColors(
        fill: k.brandSoft,
        content: k.brandDeep,
        border: k.brandDeep.withValues(alpha: 0.4),
      ),
      AppBadgeTone.shared => AppBadgeColors(
        fill: k.brandSoft,
        content: k.brandDeep,
        border: k.brandDeep.withValues(alpha: 0.4),
      ),
      AppBadgeTone.warning => AppBadgeColors(
        fill: k.accentSoft,
        content: k.onAccentSoft,
        border: k.onAccentSoft.withValues(alpha: 0.35),
      ),
    };
  }
}

/// 小さなラベル。角が丸く、太い文字。種類ごとに色が決まっている（`doc/design/README.md`）。
class AppBadge extends StatelessWidget {
  /// 文字は [label]、種類は [tone]。
  const AppBadge({
    super.key,
    required this.label,
    this.tone = AppBadgeTone.info,
    this.icon,
    this.fontSize = 12,
  });

  /// ラベルの文字。
  final String label;

  /// 種類。
  final AppBadgeTone tone;

  /// 文字の前に置くアイコン。
  final IconData? icon;

  /// 文字の大きさ。
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colors = AppBadgeColors.of(tone, Theme.of(context));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.fill,
        borderRadius: BorderRadius.circular(6),
        border: colors.border == null
            ? null
            : Border.all(color: colors.border!),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: fontSize + 2, color: colors.content),
              const SizedBox(width: 3),
            ],
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: colors.content,
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
