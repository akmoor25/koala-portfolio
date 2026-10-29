import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/data/sample_leaflets.dart';
import 'package:koala/notes/note_colors.dart';

import '../support/app_flows.dart';
import '../support/demo_database.dart';
import '../support/samples.dart';

/// ノートの画面で描かれた文字と、その実際の色（親の段落から引き継いだ色を含む）。
List<(String, Color?)> _renderedNoteText(WidgetTester tester) {
  final spans = <(String, Color?)>[];
  void walk(InlineSpan span, Color? inherited) {
    final color = span.style?.color ?? inherited;
    if (span is! TextSpan) return;
    final text = span.text ?? '';
    // チェック済みの印などのアイコン（私用領域の文字）は、色付きの四角の上に描かれるので除く。
    final isIcon = text.runes.every((r) => r >= 0xE000 && r <= 0xF8FF);
    if (text.trim().isNotEmpty && !isIcon) spans.add((text, color));
    for (final child in span.children ?? const <InlineSpan>[]) {
      walk(child, color);
    }
  }

  for (final element
      in find
          .descendant(
            of: find.byType(QuillEditor),
            matching: find.byType(RichText),
          )
          .evaluate()) {
    walk((element.widget as RichText).text, null);
  }
  return spans;
}

void main() {
  for (final brightness in Brightness.values) {
    for (final trip in SampleTrip.values) {
      testWidgets(
        'note text of ${trip.name} is readable in ${brightness.name} mode',
        (tester) async {
          final services = DemoDatabase().servicesFor('me');
          await installSampleLeaflets(
            leaflets: services.leaflets,
            marks: services.marks,
            notes: services.notes,
          );
          await openLeafletList(tester, services, brightness: brightness);
          await openLeaflet(tester, sampleTitle(trip));
          await openNote(tester);

          final background = Theme.of(tester.element(find.byType(QuillEditor)))
              .scaffoldBackgroundColor;
          final spans = _renderedNoteText(tester);
          expect(spans, isNotEmpty);
          for (final (text, color) in spans) {
            // 色が無い文字は、Flutter では白で描かれ、ライトの白地で見えなくなる。
            expect(color, isNotNull, reason: text);
            expect(
              contrastRatio(Color.alphaBlend(color!, background), background),
              greaterThanOrEqualTo(2),
              reason: '$text: $color on $background',
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
