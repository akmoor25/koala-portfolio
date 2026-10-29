import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:koala/l10n/l10n.dart';
import 'package:koala/theme/app_theme.dart';

/// テストで使う、アプリと同じローカライズの設定。
const testLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
  FlutterQuillLocalizations.delegate,
];

/// 既定のテストの言語。画面の文言を、日本語で確かめるテストが多いため日本語にする。
const testLocale = Locale('ja', 'JP');

/// 本物のアプリと同じローカライズ設定の [MaterialApp] を作る。
///
/// [brightness] を渡すと、アプリ本物のテーマ（Google Fonts は除く）を、その明暗で使う。
/// 省くと、Flutter 既定のテーマになる。
MaterialApp localizedApp({
  required Widget home,
  Locale locale = testLocale,
  TransitionBuilder? builder,
  Brightness? brightness,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: testLocalizationsDelegates,
    supportedLocales: supportedAppLocales,
    builder: builder,
    theme: brightness == null
        ? null
        : buildAppTheme(Brightness.light, useGoogleFonts: false),
    darkTheme: brightness == null
        ? null
        : buildAppTheme(Brightness.dark, useGoogleFonts: false),
    themeMode: switch (brightness) {
      Brightness.dark => ThemeMode.dark,
      Brightness.light => ThemeMode.light,
      null => ThemeMode.system,
    },
    home: home,
  );
}

/// 日本語の文言。テストで画面の文字を探すのに使う。
final ja = AppLocalizationsJa();

/// 英語の文言。
final en = AppLocalizationsEn();
