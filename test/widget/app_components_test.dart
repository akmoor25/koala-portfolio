import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/components/app_badge.dart';
import 'package:koala/components/app_button.dart';
import 'package:koala/components/app_dialog_actions.dart';
import 'package:koala/components/notice_banner.dart';
import 'package:koala/theme/app_theme.dart';

import '../support/contrast.dart';

Widget _app(
  Widget child, {
  Brightness brightness = Brightness.light,
  double textScale = 1,
  double width = 320,
}) {
  return MaterialApp(
    theme: buildAppTheme(brightness, useGoogleFonts: false),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: Center(
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('AppBadge', () {
    for (final brightness in Brightness.values) {
      for (final tone in AppBadgeTone.values) {
        testWidgets('${tone.name} is readable (${brightness.name})', (
          tester,
        ) async {
          await tester.pumpWidget(
            _app(
              AppBadge(label: 'label', tone: tone),
              brightness: brightness,
            ),
          );
          final fill = AppBadgeColors.of(
            tone,
            buildAppTheme(brightness, useGoogleFonts: false),
          ).fill;

          final text = tester.widget<Text>(find.text('label'));
          expect(
            contrast(text.style!.color!, fill),
            greaterThanOrEqualTo(textContrast),
          );
          expect(text.style?.fontWeight, FontWeight.bold);
        });
      }
    }

    testWidgets('now is coral and next is yellow', (tester) async {
      final k = buildAppTheme(Brightness.light, useGoogleFonts: false).koala;
      final theme = buildAppTheme(Brightness.light, useGoogleFonts: false);
      expect(AppBadgeColors.of(AppBadgeTone.now, theme).fill, k.hot);
      expect(AppBadgeColors.of(AppBadgeTone.next, theme).fill, k.accent);
    });

    testWidgets('shows an icon, and does not overflow at large text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const AppBadge(
            label: 'A rather long city name → another one',
            tone: AppBadgeTone.shared,
            icon: Icons.group,
          ),
          textScale: 2,
          width: 140,
        ),
      );
      expect(find.byIcon(Icons.group), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('NoticeBanner', () {
    for (final brightness in Brightness.values) {
      for (final kind in NoticeKind.values) {
        testWidgets('${kind.name} is readable (${brightness.name})', (
          tester,
        ) async {
          await tester.pumpWidget(
            _app(
              NoticeBanner(kind: kind, title: 'Title', message: 'Message'),
              brightness: brightness,
            ),
          );
          final fill =
              (tester
                          .widget<Container>(find.byType(Container).first)
                          .decoration!
                      as BoxDecoration)
                  .color!;
          final text = tester.widget<Text>(find.text('Message'));
          expect(
            contrast(text.style!.color!, fill),
            greaterThanOrEqualTo(4.5),
            reason: '${kind.name} ${brightness.name}',
          );
        });
      }
    }

    testWidgets('shows the title, the message and the default icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const NoticeBanner(
            kind: NoticeKind.warning,
            title: 'Heads up',
            message: 'Details',
          ),
        ),
      );
      expect(find.text('Heads up'), findsOneWidget);
      expect(find.text('Details'), findsOneWidget);
      expect(find.byIcon(Icons.lightbulb_outline), findsOneWidget);
    });

    testWidgets('does not overflow at 2x text', (tester) async {
      await tester.pumpWidget(
        _app(
          const NoticeBanner(
            title: 'A title',
            message: 'A message that wraps.',
          ),
          textScale: 2,
          width: 300,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('AppDialogActions', () {
    testWidgets('calls confirm and cancel', (tester) async {
      var confirmed = 0;
      var cancelled = 0;
      await tester.pumpWidget(
        _app(
          AppDialogActions(
            confirmLabel: 'OK',
            cancelLabel: 'Cancel',
            onConfirm: () => confirmed++,
            onCancel: () => cancelled++,
          ),
        ),
      );
      await tester.tap(find.text('OK'));
      await tester.tap(find.text('Cancel'));
      expect((confirmed, cancelled), (1, 1));
    });

    testWidgets('has no cancel button without onCancel', (tester) async {
      await tester.pumpWidget(
        _app(AppDialogActions(confirmLabel: 'OK', onConfirm: () {})),
      );
      expect(find.byType(AppButton), findsOneWidget);
    });

    testWidgets('the kind follows danger and accent', (tester) async {
      AppButtonKind kindOf(WidgetTester t) =>
          t.widgetList<AppButton>(find.byType(AppButton)).last.kind;

      await tester.pumpWidget(
        _app(AppDialogActions(confirmLabel: 'OK', onConfirm: () {})),
      );
      expect(kindOf(tester), AppButtonKind.primary);

      await tester.pumpWidget(
        _app(
          AppDialogActions(confirmLabel: 'OK', accent: true, onConfirm: () {}),
        ),
      );
      expect(kindOf(tester), AppButtonKind.accent);

      await tester.pumpWidget(
        _app(
          AppDialogActions(confirmLabel: 'OK', danger: true, onConfirm: () {}),
        ),
      );
      expect(kindOf(tester), AppButtonKind.danger);
    });

    testWidgets('a disabled confirm cannot be tapped', (tester) async {
      await tester.pumpWidget(
        _app(const AppDialogActions(confirmLabel: 'OK', onConfirm: null)),
      );
      final button = tester.widget<AppButton>(find.byType(AppButton));
      expect(button.onPressed, isNull);
    });
  });
}
