import 'package:flutter/material.dart';

/// テーマから、アプリ共通の色を取り出す。`buildAppTheme` を通さないテーマでも、明暗に合う色を返す。
extension KoalaTheme on ThemeData {
  /// アプリ共通の色。
  KoalaColors get koala =>
      extension<KoalaColors>() ??
      (brightness == Brightness.dark ? KoalaColors.dark : KoalaColors.light);
}

/// アプリ共通の色（トークン）。明暗ごとに値を持つ。
///
/// 主色（`0xff13b1f2`）とアクセント（`0xFFFFEB3B`）は変えない。主色の上の文字とアイコンは白にする
/// （旧サービス「行程さん」のデザインを踏襲。白と主色は 2.4:1 で、基準には届かない割り切り）。
/// 黄色は、白い地の上では 1.2:1 で見えないので、白い地では「インクの縁を付けた面」にし、
/// 線や文字には使わない。
///
/// 組み合わせと比率は、`test/unit/koala_colors_test.dart` が検査する。
@immutable
class KoalaColors extends ThemeExtension<KoalaColors> {
  /// すべての色を指定する。
  const KoalaColors({
    required this.brand,
    required this.onBrand,
    required this.brandSurface,
    required this.onBrandSurface,
    required this.brandDeep,
    required this.brandSoft,
    required this.accent,
    required this.onAccent,
    required this.onAccentBorder,
    required this.accentSoft,
    required this.onAccentSoft,
    required this.hot,
    required this.onHot,
    required this.onHotBorder,
    required this.danger,
    required this.onDanger,
    required this.dangerText,
    required this.focusRing,
  });

  /// 主色の上の文字とアイコンの色。濃い紺。
  static const ink = Color(0xFF042436);

  /// ライトの主色。
  static const brandLight = Color(0xff13b1f2);

  /// ダークの、面（アプリバー、吹き出し）の主色。白い文字を載せても読める濃さ。
  static const brandDark = Color(0xff0f7cab);

  /// アクセントの黄色。
  static const accentYellow = Color(0xFFFFEB3B);

  /// 「いま」の珊瑚色。白い文字を載せて 4.6:1。
  static const hotCoral = Color(0xFFD2421F);

  /// ライトの値。
  static const light = KoalaColors(
    brand: brandLight,
    onBrand: Colors.white,
    brandSurface: brandLight,
    onBrandSurface: Colors.white,
    brandDeep: Color(0xFF0A6A93),
    brandSoft: Color(0xFFF1FAFE),
    accent: accentYellow,
    onAccent: ink,
    onAccentBorder: ink,
    accentSoft: Color(0xFFFFF8C5),
    onAccentSoft: ink,
    hot: hotCoral,
    onHot: Colors.white,
    onHotBorder: hotCoral,
    danger: Color(0xFFB3261E),
    onDanger: Colors.white,
    dangerText: Color(0xFFB3261E),
    focusRing: ink,
  );

  /// ダークの値。操作の面は、地に映える明るい主色にして、アプリバーなどの広い面は、濃い主色にする。
  static const dark = KoalaColors(
    brand: brandLight,
    onBrand: Colors.white,
    brandSurface: brandDark,
    onBrandSurface: Colors.white,
    brandDeep: brandLight,
    brandSoft: Color(0xFF16262F),
    accent: accentYellow,
    onAccent: ink,
    onAccentBorder: ink,
    accentSoft: Color(0xFF3A3614),
    onAccentSoft: Color(0xFFFFF4B0),
    hot: hotCoral,
    onHot: Colors.white,
    onHotBorder: hotCoral,
    danger: Color(0xFFB3261E),
    onDanger: Colors.white,
    dangerText: Color(0xFFFF8A80),
    focusRing: accentYellow,
  );

  /// 操作（ボタン、リンク）の主色の面。
  final Color brand;

  /// [brand] の上の文字とアイコン。白。
  final Color onBrand;

  /// アプリバー、吹き出し、縦の線など、広い面の主色。ダークでは濃い。
  final Color brandSurface;

  /// [brandSurface] の上の文字とアイコン。白。
  final Color onBrandSurface;

  /// 地の上に置く、文字、縁、線の主色。白い地で 6:1、ダークの地では明るい主色。
  final Color brandDeep;

  /// ごく薄い空色の面。
  final Color brandSoft;

  /// アクセントの黄色。
  final Color accent;

  /// [accent] の上の文字とアイコン。
  final Color onAccent;

  /// [accent] の縁の色。
  final Color onAccentBorder;

  /// 薄い黄色の面（注意書きなど）。
  final Color accentSoft;

  /// [accentSoft] の上の文字とアイコン。
  final Color onAccentSoft;

  /// 「いま」の色。あたたかい珊瑚色。
  final Color hot;

  /// [hot] の上の文字。
  final Color onHot;

  /// [hot] の縁の色。
  final Color onHotBorder;

  /// 危険な操作（削除、退出）のボタンの面。
  final Color danger;

  /// [danger] の上の文字。
  final Color onDanger;

  /// 地の上に置く、危険を示す文字の色。
  final Color dangerText;

  /// フォーカスのリングの色。ボタンの面の外に描くので、地と同じ明暗にならない色にする。
  final Color focusRing;

  @override
  KoalaColors copyWith({
    Color? brand,
    Color? onBrand,
    Color? brandSurface,
    Color? onBrandSurface,
    Color? brandDeep,
    Color? brandSoft,
    Color? accent,
    Color? onAccent,
    Color? onAccentBorder,
    Color? accentSoft,
    Color? onAccentSoft,
    Color? hot,
    Color? onHot,
    Color? onHotBorder,
    Color? danger,
    Color? onDanger,
    Color? dangerText,
    Color? focusRing,
  }) {
    return KoalaColors(
      brand: brand ?? this.brand,
      onBrand: onBrand ?? this.onBrand,
      brandSurface: brandSurface ?? this.brandSurface,
      onBrandSurface: onBrandSurface ?? this.onBrandSurface,
      brandDeep: brandDeep ?? this.brandDeep,
      brandSoft: brandSoft ?? this.brandSoft,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      onAccentBorder: onAccentBorder ?? this.onAccentBorder,
      accentSoft: accentSoft ?? this.accentSoft,
      onAccentSoft: onAccentSoft ?? this.onAccentSoft,
      hot: hot ?? this.hot,
      onHot: onHot ?? this.onHot,
      onHotBorder: onHotBorder ?? this.onHotBorder,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
      dangerText: dangerText ?? this.dangerText,
      focusRing: focusRing ?? this.focusRing,
    );
  }

  @override
  KoalaColors lerp(ThemeExtension<KoalaColors>? other, double t) {
    if (other is! KoalaColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return KoalaColors(
      brand: mix(brand, other.brand),
      onBrand: mix(onBrand, other.onBrand),
      brandSurface: mix(brandSurface, other.brandSurface),
      onBrandSurface: mix(onBrandSurface, other.onBrandSurface),
      brandDeep: mix(brandDeep, other.brandDeep),
      brandSoft: mix(brandSoft, other.brandSoft),
      accent: mix(accent, other.accent),
      onAccent: mix(onAccent, other.onAccent),
      onAccentBorder: mix(onAccentBorder, other.onAccentBorder),
      accentSoft: mix(accentSoft, other.accentSoft),
      onAccentSoft: mix(onAccentSoft, other.onAccentSoft),
      hot: mix(hot, other.hot),
      onHot: mix(onHot, other.onHot),
      onHotBorder: mix(onHotBorder, other.onHotBorder),
      danger: mix(danger, other.danger),
      onDanger: mix(onDanger, other.onDanger),
      dangerText: mix(dangerText, other.dangerText),
      focusRing: mix(focusRing, other.focusRing),
    );
  }
}
