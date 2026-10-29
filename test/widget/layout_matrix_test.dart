import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/data/sample_leaflets.dart';
import 'package:koala/notes/note_screen.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../support/app_flows.dart';
import '../support/demo_database.dart';
import '../support/samples.dart';

/// 画面の大きさ、文字の大きさ、言語の組み合わせで、主な画面が崩れない（はみ出さない）ことを確かめる。
///
/// 組み合わせは、崩れる原因になる条件（狭い幅、低い高さ、大きい文字、日本語より長い英語）で選ぶ。
/// 1.6 倍で崩れなければ、1.0 倍でもほぼ崩れないため、小さい端末は大きい文字だけにする。
/// 明暗は配置を変えないため、ここでは扱わない（色は dark_mode_test で確かめる）。
/// 実機の見た目は、CI のエミュレータで撮るスクリーンショット（integration_test）で確かめる。
class _Case {
  const _Case(this.name, this.locale, this.size, this.textScale);

  final String name;
  final Locale locale;
  final Size size;
  final double textScale;
}

const _ja = Locale('ja', 'JP');
const _en = Locale('en', 'US');

const _cases = [
  _Case('ja 小さい端末（320×568）文字 1.6 倍', _ja, Size(320, 568), 1.6),
  _Case('ja 横向き（844×390）文字 1.6 倍', _ja, Size(844, 390), 1.6),
  _Case('ja タブレットの横（1024×768）文字 1.0 倍', _ja, Size(1024, 768), 1),
  _Case('en 小さい端末（320×568）文字 1.6 倍', _en, Size(320, 568), 1.6),
  _Case('en 標準の縦（390×844）文字 1.6 倍', _en, Size(390, 844), 1.6),
  _Case('en タブレットの横（1024×768）文字 1.6 倍', _en, Size(1024, 768), 1.6),
];

/// [screen] で、レイアウトの例外（はみ出しなど）が出ていないこと。
void _expectIntact(WidgetTester tester, String screen) {
  expect(tester.takeException(), isNull, reason: '$screen が崩れた');
}

/// 長い旅程を、見える分ずつ作りながら読み進める。
Future<void> _readThrough(
  WidgetTester tester,
  String screen, {
  required int steps,
  double distance = 300,
}) async {
  for (var i = 0; i < steps; i++) {
    await tester.drag(
      find.byType(ScrollablePositionedList),
      Offset(0, -distance),
    );
    await tester.pump();
    _expectIntact(tester, '$screen（$i 回目のスクロール）');
  }
}

void main() {
  for (final c in _cases) {
    testWidgets('主な画面が崩れない：${c.name}', (tester) async {
      final lang = c.locale.languageCode;
      final l10n = l10nFor(c.locale);
      final okinawa = sampleTitle(SampleTrip.okinawa, lang);
      final kyoto = sampleTitle(SampleTrip.kyoto, lang);
      final asia = sampleTitle(SampleTrip.asia, lang);
      useScreen(tester, c.size, textScale: c.textScale);
      final services = DemoDatabase().servicesFor('me');
      await installSampleLeaflets(
        leaflets: services.leaflets,
        marks: services.marks,
        notes: services.notes,
        now: DateTime.now(),
        languageCode: lang,
      );

      await tester.pumpWidget(buildTestApp(services, locale: c.locale));
      _expectIntact(tester, '起動画面');

      await openLeafletList(tester, services, locale: c.locale);
      _expectIntact(tester, 'しおり一覧');

      await openDrawer(tester);
      _expectIntact(tester, 'メニュー');
      tester.firstState<ScaffoldState>(find.byType(Scaffold)).closeDrawer();
      await tester.pumpAndSettle();

      await openLeafletMenu(tester, kyoto);
      expect(find.text(l10n.changeCover), findsOneWidget);
      _expectIntact(tester, 'しおりのメニュー');
      await goBack(tester);

      // 備考が長い旅程は、折り返したときの高さがずれると、はみ出す。
      await openLeaflet(tester, okinawa);
      _expectIntact(tester, '旅程');
      await _readThrough(tester, '旅程', steps: 12);

      await openMarkEditDialog(tester);
      expect(find.text(l10n.remarkLabel), findsOneWidget);
      _expectIntact(tester, '旅程の編集ダイアログ');
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();

      await openNote(tester);
      expect(find.byType(NoteScreen), findsOneWidget);
      _expectIntact(tester, 'ノート');
      await goBack(tester);
      await goBack(tester);

      await openSharingSettings(tester, kyoto, locale: c.locale);
      _expectIntact(tester, '共同編集の設定');
      await enableSharing(tester, locale: c.locale);
      // 画面に収まらないときは、スクロールして読める。
      await tester.ensureVisible(find.text(l10n.tripId));
      expect(find.text(l10n.tripId), findsOneWidget);
      _expectIntact(tester, '共同編集の情報');
      await goBack(tester);

      await openJoinScreen(tester, locale: c.locale);
      _expectIntact(tester, '参加画面');
      // 画面に収まらないときは、スクロールして押せる。
      await tester.dragUntilVisible(
        find.text(l10n.join),
        find.byType(ListView),
        const Offset(0, -100),
      );
      expect(find.text(l10n.join), findsOneWidget);
      await goBack(tester);

      // タイムゾーンをまたぐ旅程（都市名のバッジと、到着地の現地時刻）を、最後まで読み進める。
      await openLeaflet(tester, asia);
      _expectIntact(tester, 'アジア旅行の旅程');
      await _readThrough(tester, 'アジア旅行の旅程', steps: 40, distance: 600);
    });
  }
}
