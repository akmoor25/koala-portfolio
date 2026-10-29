import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/data/app_services.dart';
import 'package:koala/data/app_session.dart';
import 'package:koala/l10n/l10n.dart';
import 'package:koala/launch/launch_screen.dart';
import 'package:koala/leaflets/leaflet_card.dart';
import 'package:koala/legal/legal_links.dart';
import 'package:provider/provider.dart';

import 'localized_app.dart';

/// テストで画面を操作する手順。
///
/// 画面の流れや文言が変わったときに、直す場所をここ 1 か所にするため、
/// 各テストは、ここの関数を組み合わせて画面を進める。文言は [AppLocalizations] から引く。

/// [locale] の文言。
AppLocalizations l10nFor(Locale locale) =>
    locale.languageCode == 'ja' ? ja : en;

/// 画面の大きさ（論理ピクセル）と、文字の大きさを決める。テストの終わりに元へ戻す。
void useScreen(WidgetTester tester, Size size, {double? textScale}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  if (textScale != null) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
}

/// 本物のアプリと同じローカライズ設定で、起動画面から始まるアプリを作る。
///
/// [services] を接続先として返す。Google Fonts は通信が要るため使わない。
Widget buildTestApp(
  AppServices services, {
  TextScaler? textScaler,
  Locale locale = testLocale,
  Brightness? brightness,
  LegalLauncher? legalLauncher,
}) {
  final app = ChangeNotifierProvider<AppSession>(
    create: (_) => AppSession(),
    child: localizedApp(
      locale: locale,
      brightness: brightness,
      builder: textScaler == null
          ? null
          : (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: child!,
            ),
      home: LaunchScreen(connect: () async => services),
    ),
  );
  if (legalLauncher == null) return app;
  return Provider<LegalLauncher?>.value(value: legalLauncher, child: app);
}

/// 起動画面で「はじめる」（英語なら Get started）を押して、しおり一覧を開く。
Future<void> openLeafletList(
  WidgetTester tester,
  AppServices services, {
  TextScaler? textScaler,
  Locale locale = testLocale,
  Brightness? brightness,
  LegalLauncher? legalLauncher,
}) async {
  await tester.pumpWidget(
    buildTestApp(
      services,
      textScaler: textScaler,
      locale: locale,
      brightness: brightness,
      legalLauncher: legalLauncher,
    ),
  );
  // 小さい画面や横向きでは、起動画面をスクロールしないとボタンが見えない。
  await tapVisible(tester, find.text(l10nFor(locale).start));
}

/// [finder] を見えるところまでスクロールして、押す。
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

/// [finder] が作られるまで、最初の一覧を読み進めてから、見えるところまでスクロールする。
///
/// 長い一覧や、文字が大きいときは、見えていない部分がまだ作られていない。
/// 下へ読み進めて見つからなければ、上へ戻って探す。
Future<void> scrollUntilVisible(WidgetTester tester, Finder finder) async {
  final lists = find.byType(ListView);
  final scrollable = lists.evaluate().isNotEmpty
      ? lists.first
      : find.byType(Scrollable).first;
  for (final dy in [-300.0, 300.0]) {
    for (var i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
      await tester.drag(scrollable, Offset(0, dy));
      await tester.pump();
    }
  }
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
}

/// しおり一覧の、[title] のカード。
Finder leafletCard(String title) => find.widgetWithText(LeafletCard, title);

/// [finder] のうち、開いているダイアログ（AlertDialog、SimpleDialog など）の中にあるもの。
///
/// 同じ文字が、ダイアログの後ろの画面にもあるとき（例：一覧とダイアログの両方の「頃」）に使う。
Finder inDialog(Finder finder) =>
    find.descendant(of: find.byType(Dialog), matching: finder);

/// [finder] のうち、しおりのカード（[title] を省くと、最初のカード）の中にあるもの。
Finder inCard(Finder finder, {String? title}) => find.descendant(
  of: (title == null ? find.byType(LeafletCard) : leafletCard(title)).first,
  matching: finder,
);

/// [finder] のうち、開いているメニュー（ドロワー）の中にあるもの。
Finder inDrawer(Finder finder) =>
    find.descendant(of: find.byType(Drawer), matching: finder);

/// しおり一覧から、[title] のしおりの旅程を開く。
Future<void> openLeaflet(WidgetTester tester, String title) async {
  await scrollUntilVisible(tester, leafletCard(title));
  await tester.tap(leafletCard(title).first, warnIfMissed: false);
  await tester.pumpAndSettle();
}

/// しおり一覧で、[title] のしおりを長押しして、メニューを開く。
Future<void> openLeafletMenu(WidgetTester tester, String title) async {
  await scrollUntilVisible(tester, leafletCard(title));
  await tester.longPress(leafletCard(title).first, warnIfMissed: false);
  await tester.pumpAndSettle();
}

/// しおり一覧から、[title] のしおりの共同編集の設定を開く（共有前でも、共有中でも）。
Future<void> openSharingSettings(
  WidgetTester tester,
  String title, {
  Locale locale = testLocale,
}) async {
  final l10n = l10nFor(locale);
  await openLeafletMenu(tester, title);
  final start = find.text(l10n.startSharedEditing);
  await tapVisible(
    tester,
    start.evaluate().isNotEmpty ? start : find.text(l10n.sharedEditingSettings),
  );
}

/// 共同編集の設定で、共同編集を有効にする。
Future<void> enableSharing(
  WidgetTester tester, {
  Locale locale = testLocale,
}) async {
  await tapVisible(tester, find.text(l10nFor(locale).enableSharing));
}

/// しおり一覧から、参加画面を開く。
Future<void> openJoinScreen(
  WidgetTester tester, {
  Locale locale = testLocale,
}) async {
  await tester.tap(find.byTooltip(l10nFor(locale).joinTrip));
  await tester.pumpAndSettle();
}

/// 旅程の画面で編集モードにして、最初の旅程の編集ダイアログを開く。
Future<void> openMarkEditDialog(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.edit));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.edit_outlined).hitTestable().first);
  await tester.pumpAndSettle();
}

/// 旅程の画面から、ノートを開く。
Future<void> openNote(WidgetTester tester) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
}

/// 空のしおり一覧で、サンプルのしおりを追加する。
Future<void> addSamplesFromEmptyList(
  WidgetTester tester, {
  Locale locale = testLocale,
}) async {
  await tester.tap(find.text(l10nFor(locale).addSamples));
  await tester.pumpAndSettle();
}

/// しおり一覧の左上のメニュー（ドロワー）を開く。
Future<void> openDrawer(WidgetTester tester) async {
  tester.firstState<ScaffoldState>(find.byType(Scaffold)).openDrawer();
  await tester.pumpAndSettle();
}

/// 1 つ前の画面へ戻る。
Future<void> goBack(WidgetTester tester) async {
  tester.state<NavigatorState>(find.byType(Navigator).first).pop();
  await tester.pumpAndSettle();
}
