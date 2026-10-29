import 'package:flutter/painting.dart';

/// 色 [a] と [b] のコントラスト比（WCAG）。
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// [fg] を [alpha] で [bg] に重ねた色。
Color over(Color fg, double alpha, Color bg) =>
    Color.alphaBlend(fg.withValues(alpha: alpha), bg);

/// 半透明かもしれない [fg] を、そのまま [bg] に重ねた、見た目の色。
Color seenOn(Color fg, Color bg) => Color.alphaBlend(fg, bg);

/// 文字の最低のコントラスト比（WCAG AA）。
const textContrast = 4.5;

/// 線、アイコン、枠、フォーカスリングの最低のコントラスト比（WCAG の非テキスト）。
const lineContrast = 3.0;

/// 主色の上の白い文字・アイコンの最低のコントラスト比。
///
/// 旧サービス「行程さん」のデザインを踏襲した割り切りで、[textContrast] に届かない。
/// 悪化させないことだけを守る（koala_colors_test の「white text」を参照）。
const brandWhiteContrast = 2.4;
