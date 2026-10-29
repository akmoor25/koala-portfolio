import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';

/// プライバシーポリシーと利用規約を公開している場所（GitHub Pages。リポジトリ `akmoor25/.github` の `koala/`）。
///
/// 文書の元は、このリポジトリの `doc/legal/` にある。
const legalBaseUrl = 'https://akmoor25.github.io/.github/koala';

/// アプリから開く文書。
enum LegalDocument {
  /// 利用規約（`terms.{言語}.html`）。
  terms('terms'),

  /// プライバシーポリシー（`privacy.{言語}.html`）。
  privacy('privacy');

  const LegalDocument(this.fileName);

  /// 拡張子と言語を除いたファイル名。
  final String fileName;
}

/// [locale] の言語で読む [document] の URL。日本語なら `.ja.html`、それ以外は `.en.html`。
///
/// 言語の決め方は、アプリの画面と同じ（[resolveAppLocale]）。
String legalUrl(LegalDocument document, Locale locale) {
  final language = resolveAppLocale([locale], supportedAppLocales).languageCode;
  return '$legalBaseUrl/${document.fileName}.$language.html';
}

/// 文書を、アプリ内のブラウザ（Android は Custom Tabs、iOS は SFSafariViewController）で開く。
///
/// テストでは、これを `implements` した偽物を `Provider<LegalLauncher>` で差し込む。
class LegalLauncher {
  /// 何も受け取らない。
  const LegalLauncher();

  /// [url] を開く。開けなかったとき（オフラインなど）は false。
  Future<bool> open(Uri url) async {
    try {
      return await launchUrl(url, mode: LaunchMode.inAppBrowserView);
    } on Exception {
      return false;
    }
  }
}

/// [document] を、いまの言語で開く。開けなかったときは、SnackBar で知らせ、URL をコピーできるようにする。
Future<void> openLegalDocument(
  BuildContext context,
  LegalDocument document,
) async {
  final url = legalUrl(document, Localizations.localeOf(context));
  final launcher = context.read<LegalLauncher?>() ?? const LegalLauncher();
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  if (await launcher.open(Uri.parse(url))) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text(l10n.legalOpenFailed),
      action: SnackBarAction(
        label: l10n.legalCopyUrl,
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: url));
          messenger.showSnackBar(SnackBar(content: Text(l10n.legalUrlCopied)));
        },
      ),
    ),
  );
}

/// 利用規約とプライバシーポリシーへのリンク。起動画面と「このアプリについて」で使う。
class LegalLinks extends StatelessWidget {
  /// 何も受け取らない。
  const LegalLinks({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        TextButton(
          onPressed: () => openLegalDocument(context, LegalDocument.terms),
          child: Text(l10n.termsOfUse),
        ),
        TextButton(
          onPressed: () => openLegalDocument(context, LegalDocument.privacy),
          child: Text(l10n.privacyPolicy),
        ),
      ],
    );
  }
}
