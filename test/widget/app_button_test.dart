import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/components/app_button.dart';
import 'package:koala/components/pressable_scale.dart';
import 'package:koala/theme/app_theme.dart';

import '../support/contrast.dart';

Widget _app(
  Widget child, {
  Brightness brightness = Brightness.light,
  bool disableAnimations = false,
  double textScale = 1,
}) {
  return MaterialApp(
    theme: buildAppTheme(brightness, useGoogleFonts: false),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: disableAnimations,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}

ButtonStyle _styleOf(WidgetTester tester) => tester
    .widget<ButtonStyleButton>(find.bySubtype<ButtonStyleButton>())
    .style!;

Color? _fill(ButtonStyle s, Set<WidgetState> states) =>
    s.backgroundColor?.resolve(states);

Color? _content(ButtonStyle s, Set<WidgetState> states) =>
    s.foregroundColor?.resolve(states);

double _scale(WidgetTester tester) =>
    tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

// 色の名前（トークン）ではなく、見え方（読める、見分けられる、押すと変わる）を確かめる。
// 色を調整しても、見え方の基準を満たしていれば、テストは直さずに済む。
void main() {
  final theme = buildAppTheme(Brightness.light, useGoogleFonts: false);
  final page = theme.scaffoldBackgroundColor;

  /// 面を塗るボタン。ほかは、ページの上に文字（と枠）だけを描く。
  const filledKinds = {
    AppButtonKind.primary,
    AppButtonKind.accent,
    AppButtonKind.danger,
  };

  group('AppButton states', () {
    for (final kind in AppButtonKind.values) {
      final filled = filledKinds.contains(kind);
      final minimum = kind == AppButtonKind.primary
          ? brandWhiteContrast
          : textContrast;

      testWidgets('${kind.name}: normal, and the label is readable', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(AppButton(kind: kind, label: 'Go', onPressed: () {})),
        );
        final style = _styleOf(tester);
        final fill = _fill(style, {})!;
        expect(fill.a, filled ? 1 : 0);
        expect(
          contrast(_content(style, {})!, seenOn(fill, page)),
          greaterThanOrEqualTo(minimum),
        );
        expect(style.elevation?.resolve({}), 0);
      });

      testWidgets('${kind.name}: hover, focus and press are each stronger', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(AppButton(kind: kind, label: 'Go', onPressed: () {})),
        );
        final overlay = _styleOf(tester).overlayColor!;
        double strength(Set<WidgetState> states) => overlay.resolve(states)!.a;
        expect(strength({}), 0);
        expect(strength({WidgetState.hovered}), greaterThan(0));
        expect(
          strength({WidgetState.focused}),
          greaterThanOrEqualTo(strength({WidgetState.hovered})),
        );
        expect(
          strength({WidgetState.pressed}),
          greaterThan(strength({WidgetState.focused})),
        );
        if (kind == AppButtonKind.primary) {
          // 主色の面は、押すと暗くなる（白を重ねても、押した感じが出ないため）。
          final fill = _fill(_styleOf(tester), {})!;
          final pressed = seenOn(overlay.resolve({WidgetState.pressed})!, fill);
          expect(pressed.computeLuminance(), lessThan(fill.computeLuminance()));
        }
      });

      testWidgets('${kind.name}: disabled looks dimmed', (tester) async {
        await tester.pumpWidget(
          _app(AppButton(kind: kind, label: 'Go', onPressed: () {})),
        );
        final enabledFill = _fill(_styleOf(tester), {});
        await tester.pumpWidget(
          _app(AppButton(kind: kind, label: 'Go', onPressed: null)),
        );
        final style = _styleOf(tester);
        final states = {WidgetState.disabled};
        expect(_content(style, states)!.a, lessThan(1));
        if (filled) {
          expect(_fill(style, states), isNot(enabledFill));
        } else {
          expect(_fill(style, states)!.a, 0);
        }
      });

      testWidgets('${kind.name}: busy keeps its colors and cannot be pressed', (
        tester,
      ) async {
        var taps = 0;
        await tester.pumpWidget(
          _app(
            AppButton(
              kind: kind,
              label: 'Go',
              busy: true,
              onPressed: () => taps++,
            ),
          ),
        );
        final style = _styleOf(tester);
        final states = {WidgetState.disabled};
        expect(_fill(style, states), _fill(style, {}));
        expect(_content(style, states), _content(style, {}));
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        await tester.tap(find.byType(AppButton), warnIfMissed: false);
        await tester.pump();
        expect(taps, 0);
      });

      testWidgets('${kind.name}: is at least 48dp high', (tester) async {
        await tester.pumpWidget(
          _app(AppButton(kind: kind, label: 'Go', onPressed: () {})),
        );
        expect(
          tester.getSize(find.byType(AppButton)).height,
          greaterThanOrEqualTo(48),
        );
      });
    }

    for (final brightness in Brightness.values) {
      testWidgets(
        'the yellow accent button stands out from the page (${brightness.name})',
        (tester) async {
          final page = buildAppTheme(
            brightness,
            useGoogleFonts: false,
          ).scaffoldBackgroundColor;
          await tester.pumpWidget(
            _app(
              AppButton(
                kind: AppButtonKind.accent,
                label: 'Go',
                onPressed: () {},
              ),
              brightness: brightness,
            ),
          );
          await tester.pumpAndSettle();
          // 白いページの黄色は見分けにくいため、面か枠のどちらかが、ページから見分けられる。
          final style = _styleOf(tester);
          final side = style.side?.resolve({});
          final edges = [
            contrast(_fill(style, {})!, page),
            if (side != null && side.width > 0) contrast(side.color, page),
          ];
          expect(
            edges.reduce((a, b) => a > b ? a : b),
            greaterThanOrEqualTo(lineContrast),
          );
        },
      );
    }

    testWidgets(
      'the secondary button has a visible border, dim when disabled',
      (tester) async {
        await tester.pumpWidget(
          _app(
            AppButton(
              kind: AppButtonKind.secondary,
              label: 'Go',
              onPressed: () {},
            ),
          ),
        );
        final enabled = contrast(
          _styleOf(tester).side!.resolve({})!.color,
          page,
        );
        expect(enabled, greaterThanOrEqualTo(lineContrast));
        await tester.pumpWidget(
          _app(
            const AppButton(
              kind: AppButtonKind.secondary,
              label: 'Go',
              onPressed: null,
            ),
          ),
        );
        final disabled = _styleOf(tester).side!
            .resolve({WidgetState.disabled})!
            .color;
        expect(contrast(seenOn(disabled, page), page), lessThan(enabled));
      },
    );

    testWidgets('calls onPressed when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(AppButton(label: 'Go', onPressed: () => taps++)),
      );
      await tester.tap(find.byType(AppButton));
      expect(taps, 1);
    });

    testWidgets('draws the label and icon without shadows', (tester) async {
      // 縁取り（影の重ね描き）は、描画が重く、画面がカクついたため、やめた。再び入れないための番人。
      await tester.pumpWidget(
        _app(AppButton(label: 'Go', icon: Icons.play_arrow, onPressed: () {})),
      );
      final style = _styleOf(tester);
      expect(style.textStyle!.resolve({})?.shadows, isNull);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.play_arrow)).shadows,
        isNull,
      );
    });

    testWidgets('shows an icon before the label', (tester) async {
      await tester.pumpWidget(
        _app(AppButton(label: 'Go', icon: Icons.play_arrow, onPressed: () {})),
      );
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.text('Go'), findsOneWidget);
    });
  });

  group('AppButton focus and press feedback', () {
    testWidgets('draws a ring outside the button while focused', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(AppButton(label: 'Go', onPressed: () {}, autofocus: true)),
      );
      await tester.pumpAndSettle();

      // 位置や余白の値ではなく、リングがボタンを囲み、ページの上で見えることを確かめる。
      expect(find.byKey(AppButton.focusRingKey), findsOneWidget);
      final button = tester.getRect(find.bySubtype<ButtonStyleButton>());
      final ring = tester.getRect(find.byKey(AppButton.focusRingKey));
      expect(ring.left, lessThanOrEqualTo(button.left));
      expect(ring.top, lessThanOrEqualTo(button.top));
      expect(ring.right, greaterThanOrEqualTo(button.right));
      expect(ring.bottom, greaterThanOrEqualTo(button.bottom));
      expect(ring.size, isNot(button.size));
      final decoration =
          tester
                  .widget<DecoratedBox>(find.byKey(AppButton.focusRingKey))
                  .decoration
              as BoxDecoration;
      final border = decoration.border!;
      expect(border.top.width, greaterThanOrEqualTo(2));
      expect(
        contrast(border.top.color, page),
        greaterThanOrEqualTo(lineContrast),
      );
    });

    testWidgets('has no ring when it is not focused', (tester) async {
      await tester.pumpWidget(_app(AppButton(label: 'Go', onPressed: () {})));
      expect(find.byKey(AppButton.focusRingKey), findsNothing);
    });

    testWidgets('the ring follows a state set from outside', (tester) async {
      final controller = WidgetStatesController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          AppButton(
            label: 'Go',
            onPressed: () {},
            statesController: controller,
          ),
        ),
      );
      controller.update(WidgetState.focused, true);
      await tester.pump();
      expect(find.byKey(AppButton.focusRingKey), findsOneWidget);
      controller.update(WidgetState.focused, false);
      await tester.pump();
      expect(find.byKey(AppButton.focusRingKey), findsNothing);
    });

    testWidgets('shrinks while pressed and comes back', (tester) async {
      await tester.pumpWidget(_app(AppButton(label: 'Go', onPressed: () {})));
      expect(_scale(tester), 1);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(AppButton)),
      );
      await tester.pump();
      expect(_scale(tester), PressableScale.pressedScale);

      await gesture.up();
      await tester.pump();
      expect(_scale(tester), 1);
    });

    testWidgets('does not shrink when disabled', (tester) async {
      await tester.pumpWidget(
        _app(const AppButton(label: 'Go', onPressed: null)),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(AppButton)),
      );
      await tester.pump();
      expect(_scale(tester), 1);
      await gesture.up();
    });

    testWidgets('does not shrink when animations are reduced', (tester) async {
      await tester.pumpWidget(
        _app(AppButton(label: 'Go', onPressed: () {}), disableAnimations: true),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(AppButton)),
      );
      await tester.pump();
      expect(_scale(tester), 1);
      await gesture.up();
    });
  });

  group('AppIconButton', () {
    testWidgets('is at least 48dp and has a tooltip', (tester) async {
      await tester.pumpWidget(
        _app(AppIconButton(icon: Icons.add, tooltip: 'Add', onPressed: () {})),
      );
      final size = tester.getSize(find.byType(IconButton));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(find.byTooltip('Add'), findsOneWidget);
    });

    testWidgets('filled and tonal icons are visible, and dim when disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          AppIconButton(
            icon: Icons.add,
            tooltip: 'Add',
            kind: AppIconButtonKind.filled,
            onPressed: () {},
          ),
        ),
      );
      var style = tester.widget<IconButton>(find.byType(IconButton)).style!;
      final filled = style.backgroundColor!.resolve({})!;
      expect(
        contrast(style.foregroundColor!.resolve({})!, filled),
        greaterThanOrEqualTo(brandWhiteContrast),
      );
      expect(
        style.backgroundColor!.resolve({WidgetState.disabled}),
        isNot(filled),
      );

      await tester.pumpWidget(
        _app(
          AppIconButton(
            icon: Icons.add,
            tooltip: 'Add',
            kind: AppIconButtonKind.tonal,
            onPressed: () {},
          ),
        ),
      );
      style = tester.widget<IconButton>(find.byType(IconButton)).style!;
      final tonal = seenOn(style.backgroundColor!.resolve({})!, page);
      expect(tonal, isNot(page));
      expect(
        contrast(style.foregroundColor!.resolve({})!, tonal),
        greaterThanOrEqualTo(lineContrast),
      );
    });

    testWidgets('draws a plain white icon on the brand color', (tester) async {
      await tester.pumpWidget(
        _app(
          AppIconButton(
            icon: Icons.add,
            tooltip: 'Add',
            kind: AppIconButtonKind.filled,
            onPressed: () {},
          ),
        ),
      );
      expect(tester.widget<Icon>(find.byIcon(Icons.add)).shadows, isNull);
    });

    testWidgets('shrinks while pressed', (tester) async {
      await tester.pumpWidget(
        _app(AppIconButton(icon: Icons.add, tooltip: 'Add', onPressed: () {})),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(IconButton)),
      );
      await tester.pump();
      expect(_scale(tester), PressableScale.pressedScale);
      await gesture.up();
    });
  });
}
