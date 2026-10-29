import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'component_themes.dart';
import 'koala_colors.dart';

export 'button_styles.dart';
export 'koala_colors.dart';

/// ライトテーマの主色。
const lightPrimaryColor = KoalaColors.brandLight;

/// ダークテーマの、面（アプリバーなど）の主色。白い文字を載せても読めるよう、ライトより濃くする。
const darkPrimaryColor = KoalaColors.brandDark;

/// アプリのテーマを作る。[brightness] で、ライトとダークを切り替える。
///
/// 色は [KoalaColors]、部品ごとの見た目は [AppComponentThemes]。
/// [useGoogleFonts] が false のときは、通信が要る Google Fonts を使わない（テスト用）。
ThemeData buildAppTheme(Brightness brightness, {bool useGoogleFonts = true}) {
  final isDark = brightness == Brightness.dark;
  final koala = isDark ? KoalaColors.dark : KoalaColors.light;
  final seeded = ColorScheme.fromSeed(
    seedColor: lightPrimaryColor,
    brightness: brightness,
  );
  final scheme = seeded.copyWith(
    primary: koala.brand,
    onPrimary: koala.onBrand,
    primaryContainer: koala.brandSoft,
    onPrimaryContainer: koala.brandDeep,
    secondary: koala.accent,
    onSecondary: koala.onAccent,
    secondaryContainer: koala.accentSoft,
    onSecondaryContainer: koala.onAccentSoft,
    error: koala.dangerText,
    onError: isDark ? KoalaColors.ink : Colors.white,
    // ライトは白地。ダークは Material の暗い面を使う。
    surface: isDark ? seeded.surface : Colors.white,
  );
  final base = ThemeData(colorScheme: scheme, extensions: [koala]);
  final themes = AppComponentThemes(base, scheme, koala);
  return base.copyWith(
    textTheme: useGoogleFonts
        ? GoogleFonts.bizUDPGothicTextTheme(base.textTheme)
        : base.textTheme,
    primaryColor: koala.brandSurface,
    scaffoldBackgroundColor: scheme.surface,
    // 波紋とハイライトは、地に映える色にする（ライトはインク、ダークは黄色）。
    splashColor: isDark
        ? koala.accent.withValues(alpha: 0.18)
        : KoalaColors.ink.withValues(alpha: 0.10),
    highlightColor: isDark
        ? koala.accent.withValues(alpha: 0.10)
        : KoalaColors.ink.withValues(alpha: 0.06),
    navigationBarTheme: themes.navigationBar,
    floatingActionButtonTheme: themes.floatingActionButton,
    appBarTheme: themes.appBar,
    tabBarTheme: themes.tabBar,
    filledButtonTheme: themes.filledButton,
    outlinedButtonTheme: themes.outlinedButton,
    textButtonTheme: themes.textButton,
    iconButtonTheme: themes.iconButton,
    inputDecorationTheme: themes.inputDecoration,
    cardTheme: themes.card,
    dialogTheme: themes.dialog,
    listTileTheme: themes.listTile,
    progressIndicatorTheme: themes.progress,
    snackBarTheme: themes.snackBar,
  );
}

/// テーマの明暗に合わせて決まる、アプリ共通の色。
extension AppThemeColors on ThemeData {
  /// ダークテーマか。
  bool get isDark => brightness == Brightness.dark;

  /// 補足の文字や罫線に使う、弱めの文字色。Material の中程度の強調（54%）に合わせる。
  Color get subtleColor => colorScheme.onSurface.withValues(alpha: 0.54);

  /// 面の上の、細い縁の色。
  Color get outlineColor =>
      isDark ? Colors.grey.shade700 : Colors.grey.shade300;

  /// 小さな文字や線を、主色系で描くときの色。白い地で 6:1、ダークでは明るい主色。
  Color get accentTextColor => koala.brandDeep;
}
