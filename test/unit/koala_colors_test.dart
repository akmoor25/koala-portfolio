import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/theme/app_theme.dart';

import '../support/contrast.dart';

void main() {
  for (final brightness in Brightness.values) {
    final theme = buildAppTheme(brightness, useGoogleFonts: false);
    final k = theme.koala;
    final page = theme.scaffoldBackgroundColor;
    final isDark = theme.isDark;

    group('colors (${brightness.name})', () {
      void atLeast(String name, Color a, Color b, double ratio) {
        test('$name is at least $ratio:1', () {
          expect(contrast(a, b), greaterThanOrEqualTo(ratio));
        });
      }

      // 文字は 4.5:1。
      // 主色の上の白い文字は、旧サービス「行程さん」のデザインを踏襲する割り切り。
      // ライトは 2.44:1 で基準（4.5:1）に届かない（下の「white text」のテストで、悪化しないことを守る）。
      // ダークの広い面（アプリバーなど）は、濃い主色にして、基準を満たす。
      if (isDark) {
        atLeast(
          'white on the dark brand surface',
          k.onBrandSurface,
          k.brandSurface,
          4.5,
        );
      }
      atLeast('on accent', k.onAccent, k.accent, 4.5);
      atLeast('on accent soft', k.onAccentSoft, k.accentSoft, 4.5);
      atLeast('on hot', k.onHot, k.hot, 4.5);
      atLeast('on danger', k.onDanger, k.danger, 4.5);
      atLeast('deep brand text on the page', k.brandDeep, page, 4.5);
      atLeast(
        'deep brand text on the soft fill',
        k.brandDeep,
        k.brandSoft,
        4.5,
      );
      atLeast('danger text on the page', k.dangerText, page, 4.5);
      atLeast('subtle text on the page', theme.subtleColor, page, 4.5);
      atLeast(
        'accent text color on the page',
        theme.accentTextColor,
        page,
        4.5,
      );
      atLeast(
        'body text on the soft fill',
        theme.colorScheme.onSurface,
        k.brandSoft,
        4.5,
      );

      // 線、リング、縁は 3:1。
      atLeast('focus ring on the page', k.focusRing, page, 3);
      atLeast('deep brand lines on the page', k.brandDeep, page, 3);
      atLeast(
        'input border on the page',
        over(theme.colorScheme.onSurface, isDark ? 0.38 : 0.55, page),
        page,
        3,
      );
      if (!isDark) {
        atLeast('sticker border on the page', k.onAccentBorder, page, 3);
        atLeast('sticker border on the accent', k.onAccentBorder, k.accent, 3);
      }
    });

    group('the two brand colors (${brightness.name})', () {
      test('keep the primary and the accent', () {
        expect(k.brand, const Color(0xff13b1f2));
        expect(k.accent, const Color(0xFFFFEB3B));
        expect(theme.colorScheme.primary, k.brand);
        expect(theme.colorScheme.secondary, k.accent);
      });

      test('white text on the brand color is a known trade-off', () {
        // 縁取りは、描画が重くなり、見た目もよくなかったため、やめた。白い文字のままにする
        // （読みやすさを少し犠牲にする）。2.4:1 より悪くしないことだけを守る。
        expect(k.onBrand, Colors.white);
        expect(k.onBrandSurface, Colors.white);
        expect(contrast(k.onBrand, k.brand), greaterThanOrEqualTo(2.4));
        expect(contrast(Colors.white, k.brand), lessThan(3));
      });

      test('yellow is not used for text or lines on a white page', () {
        if (isDark) return;
        expect(contrast(k.accent, page), lessThan(1.5));
        expect(k.onAccentBorder, isNot(Colors.transparent));
      });
    });
  }

  test('the light primary keeps its value and the dark surface is deeper', () {
    expect(lightPrimaryColor, const Color(0xff13b1f2));
    expect(darkPrimaryColor, const Color(0xff0f7cab));
    expect(contrast(Colors.white, darkPrimaryColor), greaterThan(4.5));
  });
}
