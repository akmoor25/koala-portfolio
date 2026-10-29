import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';
export 'app_localizations_en.dart';
export 'app_localizations_ja.dart';

/// アプリが対応する言語。基準は英語で、日本語を足している。
const supportedAppLocales = [Locale('en', 'US'), Locale('ja', 'JP')];

/// 端末の言語から、アプリの言語を決める。
///
/// 端末の最優先の言語が日本語（`ja`。地域は問わない）なら日本語、それ以外はすべて英語にする。
Locale resolveAppLocale(
  List<Locale>? deviceLocales,
  Iterable<Locale> supported,
) {
  final first = deviceLocales == null || deviceLocales.isEmpty
      ? null
      : deviceLocales.first;
  return first?.languageCode == 'ja'
      ? supportedAppLocales[1]
      : supportedAppLocales[0];
}

/// 画面の文言と言語を、`context.l10n` で取り出す。
extension AppLocalizationsContext on BuildContext {
  /// いまの言語の文言。
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// いまの言語コード（`en` か `ja`）。
  String get languageCode => Localizations.localeOf(this).languageCode;
}
