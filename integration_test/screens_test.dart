import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:koala/data/app_session.dart';
import 'package:koala/data/sample_leaflets.dart';
import 'package:koala/helper/time_zones.dart';
import 'package:koala/main.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../test/support/app_flows.dart';
import '../test/support/demo_database.dart';
import '../test/support/samples.dart';

/// 端末ごとの見た目を確かめるための統合テスト。
///
/// 通信しない偽の接続先（`test/support/`）で、実機と同じアプリ（`MyApp`、本物のテーマ）を動かし、
/// 主な画面ごとにスクリーンショットを撮る。レイアウトの例外（はみ出しなど）が出たら失敗にする。
/// 撮った画像は、CI の端末マトリクスで集めて、人の目で確かめる。
/// 撮る言語。`--dart-define=SCREENSHOT_LOCALE=en` でビルドすると、英語の画面を撮る。
const _locale = String.fromEnvironment('SCREENSHOT_LOCALE', defaultValue: 'ja');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  var surfaceConverted = false;

  Future<void> shoot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    // Android では、画面を撮る前に Flutter の描画面を画像に変える必要がある（最初の 1 回だけ）。
    if (!surfaceConverted) {
      await binding.convertFlutterSurfaceToImage();
      surfaceConverted = true;
    }
    await tester.pumpAndSettle();
    await binding.takeScreenshot(name);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    // 文字が大きいと、一覧の見えていない部分は、まだ作られていない。見つかるまで読み進める。
    await scrollUntilVisible(tester, find.text(text));
    await tester.tap(find.text(text).first);
    await tester.pumpAndSettle();
  }

  testWidgets('主な画面を一通り開く', (tester) async {
    await initTimeZones();
    final l10n = l10nFor(const Locale(_locale));
    final db = DemoDatabase();
    // 端末の言語と同じように、サンプルの文章もその言語で作る（海外旅行の画面も撮る）。
    await installSampleLeaflets(
      leaflets: db.services.leaflets,
      marks: db.services.marks,
      notes: db.services.notes,
      languageCode: _locale,
    );
    final okinawa = sampleTitle(SampleTrip.okinawa, _locale);
    final asiaTour = sampleTitle(SampleTrip.asia, _locale);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppSession>(
        create: (_) => AppSession(),
        child: MyApp(
          connect: () async => db.services,
          locale: const Locale(_locale),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await shoot(tester, '01_launch');

    // しおり一覧
    await tapText(tester, l10n.start);
    await shoot(tester, '02_list');

    // 旅程
    await tapText(tester, okinawa);
    await shoot(tester, '03_marks');

    // 旅程の編集と追加・編集ダイアログ
    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();
    await shoot(tester, '04_marks_edit');
    await tester.tap(find.byIcon(Icons.edit_outlined).hitTestable().first);
    await tester.pumpAndSettle();
    await shoot(tester, '05_mark_dialog');
    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();

    // ノート
    await openNote(tester);
    await shoot(tester, '06_note');
    await goBack(tester);
    await goBack(tester);

    // しおりのメニューと共同編集の設定
    await openLeafletMenu(tester, okinawa);
    await shoot(tester, '07_leaflet_menu');
    await tapText(tester, l10n.startSharedEditing);
    await shoot(tester, '08_share_settings');
    await tapText(tester, l10n.enableSharing);
    await shoot(tester, '09_share_info');
    await goBack(tester);

    // 参加画面（使えない文字の警告つき）
    await openJoinScreen(tester, locale: const Locale(_locale));
    await shoot(tester, '10_join');
    await tester.enterText(find.byType(TextField).first, 'abcd');
    await tester.pumpAndSettle();
    await shoot(tester, '11_join_warning');
    await goBack(tester);

    // メニューと「このアプリについて」
    await openDrawer(tester);
    await shoot(tester, '12_drawer');
    await tapText(tester, l10n.aboutApp);
    await shoot(tester, '13_about');
    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();

    // アジア旅行（タイムゾーンの異なる旅程。都市名のバッジと、到着地の現地時刻）
    await tapText(tester, asiaTour);
    await shoot(tester, '14_asia_tour');
    // 途中の都市まで読み進める（長い旅程は、見える分だけが作られるため、位置で動かす）。
    for (var i = 0; i < 6; i++) {
      await tester.drag(
        find.byType(ScrollablePositionedList),
        const Offset(0, -500),
      );
      await tester.pump();
    }
    await shoot(tester, '15_asia_tour_middle');
  });
}
