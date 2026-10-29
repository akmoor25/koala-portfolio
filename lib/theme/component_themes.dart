import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/readable_width.dart';
import 'button_styles.dart';
import 'koala_colors.dart';

/// 部品ごとのテーマ。生の Material のウィジェットも、アプリの見た目になる。
class AppComponentThemes {
  /// [scheme] と [koala] から作る。
  AppComponentThemes(this.theme, this.scheme, this.koala);

  /// 元になるテーマ（文字の大きさと色の参照用）。
  final ThemeData theme;

  /// 色の組。
  final ColorScheme scheme;

  /// アプリ共通の色。
  final KoalaColors koala;

  bool get _isDark => scheme.brightness == Brightness.dark;

  static const _appBarElevation = 3.0;

  /// アプリバーの下の縁と、タブの指示子の、黄色の線の太さ。
  static const _accentLineWidth = 4.0;

  // 入力欄の枠の太さ。フォーカスしたときだけ太くし、入力中の欄を見分けやすくする。
  static const _inputBorderWidth = 1.0;
  static const _inputErrorBorderWidth = 1.5;
  static const _inputFocusedBorderWidth = 2.5;

  /// ダイアログの最小の幅。Material 3 のダイアログの最小幅に合わせる。
  static const _dialogMinWidth = 280.0;

  /// 塗りのボタン。
  FilledButtonThemeData get filledButton => FilledButtonThemeData(
    style: appButtonStyle(AppButtonKind.primary, theme),
  );

  /// 枠のボタン。
  OutlinedButtonThemeData get outlinedButton => OutlinedButtonThemeData(
    style: appButtonStyle(AppButtonKind.secondary, theme),
  );

  /// 文字のボタン。
  TextButtonThemeData get textButton =>
      TextButtonThemeData(style: appButtonStyle(AppButtonKind.text, theme));

  /// アイコンのボタン。
  IconButtonThemeData get iconButton => IconButtonThemeData(
    style: appIconButtonStyle(AppIconButtonKind.standard, theme),
  );

  /// 浮かぶボタン。黄色の面（ライトは、インクの縁付き）。
  FloatingActionButtonThemeData get floatingActionButton =>
      FloatingActionButtonThemeData(
        backgroundColor: koala.accent,
        foregroundColor: koala.onAccent,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: koala.onAccentBorder == Colors.transparent
              ? BorderSide.none
              : BorderSide(color: koala.onAccentBorder, width: 1.0),
        ),
      );

  /// アプリバー。黒い面に白い文字。下の縁は黄色。
  AppBarTheme get appBar => AppBarTheme(
    backgroundColor: Colors.black,
    foregroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    // 薄い影。スクロールしても、同じ濃さのまま。
    elevation: _appBarElevation,
    scrolledUnderElevation: _appBarElevation,
    shadowColor: Colors.black.withValues(alpha: 1.0),
    shape: Border(
      bottom: BorderSide(color: koala.accent, width: _accentLineWidth),
    ),
    iconTheme: const IconThemeData(color: Colors.white),
    actionsIconTheme: const IconThemeData(color: Colors.white),
    titleTextStyle: theme.textTheme.titleLarge?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.bold,
    ),
    systemOverlayStyle: SystemUiOverlayStyle.light,
  );

  /// 下のナビゲーションバー。
  NavigationBarThemeData get navigationBar =>
      theme.navigationBarTheme.copyWith(backgroundColor: koala.brandSurface);

  /// タブ。指示子は黄色。
  TabBarThemeData get tabBar => TabBarThemeData(
    indicator: UnderlineTabIndicator(
      borderSide: BorderSide(color: koala.accent, width: _accentLineWidth),
    ),
    labelColor: koala.onBrandSurface,
    unselectedLabelColor: koala.onBrandSurface.withValues(alpha: 0.7),
  );

  /// 入力欄。塗りと、角の丸い枠。フォーカスで枠が太くなる。
  InputDecorationTheme get inputDecoration {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
    final outline = scheme.onSurface.withValues(alpha: _isDark ? 0.38 : 0.55);
    return InputDecorationTheme(
      filled: true,
      fillColor: koala.brandSoft,
      border: border(outline, _inputBorderWidth),
      enabledBorder: border(outline, _inputBorderWidth),
      focusedBorder: border(koala.brandDeep, _inputFocusedBorderWidth),
      errorBorder: border(koala.dangerText, _inputErrorBorderWidth),
      focusedErrorBorder: border(koala.dangerText, _inputFocusedBorderWidth),
      disabledBorder: border(
        scheme.onSurface.withValues(alpha: disabledContainerAlpha),
        _inputBorderWidth,
      ),
      floatingLabelStyle: TextStyle(color: koala.brandDeep),
    );
  }

  /// カード。角を丸く、細い縁。
  CardThemeData get card => CardThemeData(
    color: _isDark ? scheme.surfaceContainerHigh : Colors.white,
    elevation: _isDark ? 0 : 1,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: scheme.onSurface.withValues(alpha: _isDark ? 0.16 : 0.08),
      ),
    ),
  );

  /// ダイアログ。幅が広い画面（タブレットの横）でも、[AppWidth.form] を超えない。
  DialogThemeData get dialog => DialogThemeData(
    backgroundColor: _isDark ? scheme.surfaceContainerHigh : Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    constraints: const BoxConstraints(
      minWidth: _dialogMinWidth,
      maxWidth: AppWidth.form,
    ),
  );

  /// リストの行。
  ListTileThemeData get listTile => ListTileThemeData(
    iconColor: koala.brandDeep,
    selectedColor: koala.brandDeep,
    selectedTileColor: koala.brandSoft,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );

  /// 進捗の表示。
  ProgressIndicatorThemeData get progress => ProgressIndicatorThemeData(
    color: koala.brandDeep,
    linearTrackColor: koala.brandSoft,
  );

  /// スナックバー。
  SnackBarThemeData get snackBar => SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: _isDark ? scheme.surfaceContainerHighest : KoalaColors.ink,
    contentTextStyle: TextStyle(
      color: _isDark ? scheme.onSurface : Colors.white,
    ),
    actionTextColor: koala.accent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}
