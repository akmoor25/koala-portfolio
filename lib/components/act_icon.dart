import 'package:flutter/material.dart';

import '../helper/act_type.dart';
import '../theme/app_theme.dart';

/// 交通手段のアイコン。画像は黒一色なので、ダークテーマでは文字色で塗って見えるようにする。
class ActIcon extends StatelessWidget {
  /// [type] のアイコンを [size] の大きさで描く。
  const ActIcon(this.type, {super.key, this.size = defaultSize});

  /// 既定の大きさ。Material のアイコンの標準の大きさに合わせる。
  static const double defaultSize = 24;

  /// 交通手段。
  final ActType type;

  /// 幅と高さ。
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Image.asset(
      type.assetsPath(),
      width: size,
      height: size,
      color: theme.isDark ? theme.colorScheme.onSurface : null,
      colorBlendMode: theme.isDark ? BlendMode.srcIn : null,
    );
  }
}
