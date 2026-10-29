import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/notes/note_colors.dart';
import 'package:koala/notes/note_model.dart';
import 'package:provider/provider.dart';

import '../support/app_flows.dart';
import '../support/demo_data.dart';
import '../support/demo_database.dart';
import '../support/note_fixtures.dart';

/// [icon] のツールバーのボタンの、アイコンの色と、画面上の面の色。
(Color, Color) _iconAndSurface(WidgetTester tester, IconData icon) {
  final iconFinder = find.descendant(
    of: find.byType(QuillSimpleToolbar),
    matching: find.byIcon(icon),
  );
  final iconElement = tester.element(iconFinder);
  final iconColor =
      (iconElement.widget as Icon).color ?? IconTheme.of(iconElement).color!;
  final scaffold = Theme.of(iconElement).scaffoldBackgroundColor;
  // ボタンの面（Material）を、画面の背景に重ねた色。
  final surface = tester
      .widgetList<Material>(
        find.ancestor(of: iconFinder, matching: find.byType(Material)),
      )
      .map((material) => material.color)
      .whereType<Color>()
      .first;
  return (iconColor, Color.alphaBlend(surface, scaffold));
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'active toolbar icons stay visible in ${brightness.name} mode',
      (tester) async {
        final services = DemoDatabase().services;
        await seedNote(
          services.notes,
          demoTripKey,
          '[{"insert":"quoted"},{"insert":"\\n","attributes":{"blockquote":true}},'
          '{"insert":"bold","attributes":{"bold":true}},{"insert":"\\n"}]',
        );
        await openLeafletList(tester, services, brightness: brightness);
        await openLeaflet(tester, demoTripTitle);
        await openNote(tester);
        final controller = Provider.of<NoteModel>(
          tester.element(find.byType(QuillEditor)),
          listen: false,
        ).quillController;

        for (final (offset, icon) in const [
          (2, Icons.format_quote),
          (9, Icons.format_bold),
        ]) {
          controller.updateSelection(
            TextSelection.collapsed(offset: offset),
            ChangeSource.local,
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byIcon(icon).first);
          await tester.pumpAndSettle();

          final (iconColor, surface) = _iconAndSurface(tester, icon);
          final scaffold = Theme.of(tester.element(find.byType(QuillEditor)))
              .scaffoldBackgroundColor;
          // 有効なボタンとして、面に色が付いている（無効なボタンは透明）。
          expect(surface, isNot(scaffold), reason: '$icon');
          expect(
            contrastRatio(Color.alphaBlend(iconColor, surface), surface),
            greaterThanOrEqualTo(3),
            reason: '$icon: $iconColor on $surface',
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
