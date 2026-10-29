import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/components/act_icon.dart';
import 'package:koala/helper/act_type.dart';
import 'package:koala/leaflets/leaflet_card.dart';
import 'package:koala/theme/app_theme.dart';

import '../support/app_flows.dart';
import '../support/contrast.dart';
import '../support/demo_database.dart';
import '../support/localized_app.dart';

ThemeData _themeOf(WidgetTester tester, Finder finder) =>
    Theme.of(tester.element(finder.first));

/// 画面上の、円形の縁取りの色（予定の丸や日付の円）。
Iterable<Color> _circleBorderColors(WidgetTester tester) sync* {
  for (final box in tester.widgetList<DecoratedBox>(
    find.byType(DecoratedBox),
  )) {
    final decoration = box.decoration;
    if (decoration is! BoxDecoration || decoration.shape != BoxShape.circle) {
      continue;
    }
    final border = decoration.border;
    if (border is Border) yield border.top.color;
  }
}

Future<void> _openFirstLeaflet(
  WidgetTester tester,
  Brightness brightness,
) async {
  await openLeafletList(
    tester,
    DemoDatabase().services,
    brightness: brightness,
  );
  await tester.tap(find.byType(LeafletCard).first);
  await tester.pumpAndSettle();
}

void main() {
  group('buildAppTheme', () {
    test('has a light and a dark variant', () {
      final light = buildAppTheme(Brightness.light, useGoogleFonts: false);
      final dark = buildAppTheme(Brightness.dark, useGoogleFonts: false);

      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
      expect(
        light.scaffoldBackgroundColor.computeLuminance(),
        greaterThan(0.9),
      );
      expect(dark.scaffoldBackgroundColor.computeLuminance(), lessThan(0.05));
    });

    test('keeps the light accent and darkens it for dark mode', () {
      final light = buildAppTheme(Brightness.light, useGoogleFonts: false);
      final dark = buildAppTheme(Brightness.dark, useGoogleFonts: false);

      expect(light.primaryColor, lightPrimaryColor);
      expect(dark.primaryColor, darkPrimaryColor);
      // 白い文字を載せる背景（アプリバーや吹き出し）なので、読める濃さにする。
      expect(contrast(Colors.white, dark.primaryColor), greaterThan(4.5));
      expect(
        contrast(Colors.white, dark.appBarTheme.backgroundColor!),
        greaterThan(textContrast),
      );
    });

    test('derived colors follow the brightness', () {
      final light = buildAppTheme(Brightness.light, useGoogleFonts: false);
      final dark = buildAppTheme(Brightness.dark, useGoogleFonts: false);

      expect(light.isDark, isFalse);
      expect(dark.isDark, isTrue);
      expect(
        contrast(dark.subtleColor, dark.scaffoldBackgroundColor),
        greaterThan(4.5),
      );
      expect(
        contrast(light.subtleColor, light.scaffoldBackgroundColor),
        greaterThan(4.5),
      );
      expect(
        contrast(dark.accentTextColor, dark.scaffoldBackgroundColor),
        greaterThan(4.5),
      );
      // 白い地の上の主色系の文字は、主色（2.4:1）のままでは読めないため、読める濃さにする。
      expect(
        contrast(light.accentTextColor, light.scaffoldBackgroundColor),
        greaterThan(4.5),
      );
    });
  });

  group('dark mode screens', () {
    testWidgets('the leaflet list uses dark surfaces', (tester) async {
      await openLeafletList(
        tester,
        DemoDatabase().services,
        brightness: Brightness.dark,
      );

      final theme = _themeOf(tester, find.byType(LeafletCard));
      expect(theme.brightness, Brightness.dark);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(
        scaffold.backgroundColor ?? theme.scaffoldBackgroundColor,
        isNot(Colors.white),
      );
      final card = tester.widget<Card>(inCard(find.byType(Card)));
      expect(card.color!.computeLuminance(), lessThan(0.2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the leaflet list keeps light cards in light mode', (
      tester,
    ) async {
      await openLeafletList(
        tester,
        DemoDatabase().services,
        brightness: Brightness.light,
      );

      final card = tester.widget<Card>(inCard(find.byType(Card)));
      expect(card.color!.computeLuminance(), greaterThan(0.9));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the launch screen follows the dark theme', (tester) async {
      await tester.pumpWidget(
        buildTestApp(DemoDatabase().services, brightness: Brightness.dark),
      );

      final theme = _themeOf(tester, find.byType(Scaffold));
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, isNot(Colors.white));
      expect(find.text(ja.start), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the itinerary draws timeline circles visible on dark', (
      tester,
    ) async {
      await _openFirstLeaflet(tester, Brightness.dark);

      final page = _themeOf(
        tester,
        find.byType(Scaffold),
      ).scaffoldBackgroundColor;
      final colors = _circleBorderColors(tester).toList();
      expect(colors, isNotEmpty);
      for (final color in colors) {
        expect(contrast(color, page), greaterThanOrEqualTo(lineContrast));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('transport icons are tinted only in dark mode', (tester) async {
      await _openFirstLeaflet(tester, Brightness.dark);
      final darkIcons = tester.widgetList<ActIcon>(find.byType(ActIcon));
      expect(darkIcons, isNotEmpty);
      for (final image in tester.widgetList<Image>(
        find.descendant(of: find.byType(ActIcon), matching: find.byType(Image)),
      )) {
        expect(image.color, isNotNull);
        expect(image.colorBlendMode, BlendMode.srcIn);
      }

      await tester.pumpWidget(const SizedBox());
      await _openFirstLeaflet(tester, Brightness.light);
      for (final image in tester.widgetList<Image>(
        find.descendant(of: find.byType(ActIcon), matching: find.byType(Image)),
      )) {
        expect(image.color, isNull);
      }
    });

    testWidgets('the mark dialog and icon picker open in dark mode', (
      tester,
    ) async {
      await _openFirstLeaflet(tester, Brightness.dark);
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();

      expect(find.byType(SimpleDialog), findsOneWidget);
      // 一覧の「頃」と区別するため、ダイアログの中だけを探す。
      final approx = inDialog(find.text(ja.approxLabel));
      expect(approx, findsOneWidget);
      final label = tester.widget<Text>(approx);
      final surface = tester
          .widget<Material>(inDialog(find.byType(Material)).first)
          .color!;
      expect(
        contrast(label.style!.color!, surface),
        greaterThanOrEqualTo(textContrast),
      );

      await tester.tap(find.byType(OutlinedButton).last);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(ActIcon), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('transport icon widget renders every type', (tester) async {
      await tester.pumpWidget(
        localizedApp(
          brightness: Brightness.dark,
          home: Scaffold(
            body: Wrap(children: [for (final t in ActType.values) ActIcon(t)]),
          ),
        ),
      );

      expect(find.byType(ActIcon), findsNWidgets(ActType.values.length));
      expect(tester.takeException(), isNull);
    });
  });
}
