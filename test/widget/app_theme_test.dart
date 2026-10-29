import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/theme/app_theme.dart';

import '../support/app_flows.dart';
import '../support/contrast.dart';
import '../support/demo_database.dart';

void main() {
  for (final brightness in Brightness.values) {
    test('the app bar text and icons are readable, without shadows '
        '(${brightness.name})', () {
      final bar = buildAppTheme(brightness, useGoogleFonts: false).appBarTheme;
      // ライトの主色の上の白は、旧サービスを踏襲した割り切り。ダークは基準を満たす。
      final minimum = brightness == Brightness.light
          ? brandWhiteContrast
          : textContrast;
      for (final color in [
        bar.titleTextStyle!.color!,
        bar.iconTheme!.color!,
        bar.actionsIconTheme!.color!,
      ]) {
        expect(
          contrast(color, bar.backgroundColor!),
          greaterThanOrEqualTo(minimum),
        );
      }
      // 縁取り（影の重ね描き）は、描画が重く、画面がカクついたため、やめた。
      expect(bar.titleTextStyle?.shadows, isNull);
      expect(bar.iconTheme?.shadows, isNull);
      expect(bar.actionsIconTheme?.shadows, isNull);
    });

    test('the app bar has a drop shadow that stays when scrolled '
        '(${brightness.name})', () {
      final bar = buildAppTheme(brightness, useGoogleFonts: false).appBarTheme;
      expect(bar.elevation, greaterThan(0));
      expect(bar.scrolledUnderElevation, bar.elevation);
      expect(bar.shadowColor, isNotNull);
    });

    testWidgets(
      'the drawer icons are tinted and visible (${brightness.name})',
      (tester) async {
        await openLeafletList(
          tester,
          DemoDatabase().services,
          brightness: brightness,
        );
        await openDrawer(tester);

        final theme = buildAppTheme(brightness, useGoogleFonts: false);
        final surface =
            theme.drawerTheme.backgroundColor ?? theme.colorScheme.surface;
        for (final icon in [
          Icons.group_add,
          Icons.auto_awesome,
          Icons.badge_outlined,
          Icons.info_outline,
        ]) {
          final tile = find.ancestor(
            of: inDrawer(find.byIcon(icon)),
            matching: find.byType(ListTile),
          );
          final color = IconTheme.of(
            tester.element(
              find.descendant(of: tile, matching: find.byIcon(icon)),
            ),
          ).color;
          // 本文の色ではなく、色をつけたアイコン。主色を使うため、白い地では割り切りの基準になる。
          expect(color, isNot(theme.colorScheme.onSurface), reason: '$icon');
          expect(
            contrast(color!, surface),
            greaterThanOrEqualTo(brandWhiteContrast),
            reason: '$icon',
          );
        }
      },
    );
  }
}
