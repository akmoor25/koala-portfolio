import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/notes/note_styles.dart';

import '../support/app_flows.dart';
import '../support/demo_data.dart';
import '../support/demo_database.dart';
import '../support/note_fixtures.dart';

/// ノートの各段落の描画（RichText）。キーは段落の文字。
Map<String, RichText> _lines(WidgetTester tester) => {
  for (final element
      in find
          .descendant(
            of: find.byType(QuillEditor),
            matching: find.byType(RichText),
          )
          .evaluate())
    (element.widget as RichText).text.toPlainText().trim():
        element.widget as RichText,
};

String _line(String text, [String? attributes]) =>
    '{"insert":"$text"},{"insert":"\\n"'
    '${attributes == null ? '' : ',"attributes":$attributes'}}';

const _long =
    'This paragraph is long enough to wrap onto several lines in the editor '
    'so that the height of each wrapped line can be measured precisely here';

Future<void> _openNoteWith(WidgetTester tester, List<String> lines) async {
  final services = DemoDatabase().services;
  await seedNote(services.notes, demoTripKey, '[${lines.join(',')}]');
  await openLeafletList(tester, services);
  await openLeaflet(tester, demoTripTitle);
  await openNote(tester);
}

void main() {
  // 段落・見出し・まとまりの境目と、まとまりの中の行の間の、描画上の間隔。
  final between = noteParagraphSpacing.bottom + noteParagraphSpacing.top;
  final within = noteLineSpacing.bottom + noteLineSpacing.top;

  testWidgets('every kind of paragraph, including headings, gets the gaps', (
    tester,
  ) async {
    await _openNoteWith(tester, [
      _line('plain one'),
      _line('heading one', '{"header":1}'),
      _line('plain two'),
      _line('heading two', '{"header":2}'),
      _line('heading three', '{"header":3}'),
      _line('plain three'),
      _line('bullet one', '{"list":"bullet"}'),
      _line('bullet two', '{"list":"bullet"}'),
      _line('todo one', '{"list":"unchecked"}'),
      _line('todo two', '{"list":"checked"}'),
      _line('quote one', '{"blockquote":true}'),
      _line('quote two', '{"blockquote":true}'),
    ]);

    final lines = _lines(tester);
    Rect rect(String text) => tester.getRect(find.byWidget(lines[text]!));
    for (final (above, below, gap) in [
      ('plain one', 'heading one', between),
      ('heading one', 'plain two', between),
      ('plain two', 'heading two', between),
      ('heading two', 'heading three', between),
      ('heading three', 'plain three', between),
      // 段落の下の余白と、まとまりの上の余白。
      (
        'plain three',
        'bullet one',
        noteParagraphSpacing.bottom + noteLineSpacing.top,
      ),
      ('bullet one', 'bullet two', within),
      // 未完了とチェック済みは、別のまとまりになる。まとまりの前後の余白も同じ値。
      ('bullet two', 'todo one', within),
      ('todo one', 'todo two', within),
      ('todo two', 'quote one', within),
      ('quote one', 'quote two', within),
    ]) {
      expect(
        rect(below).top - rect(above).bottom,
        closeTo(gap, 0.5),
        reason: '$above → $below',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('wrapped lines use the note line height', (tester) async {
    await _openNoteWith(tester, [
      _line(_long),
      _line('$_long.', '{"list":"bullet"}'),
      _line('$_long!', '{"blockquote":true}'),
    ]);

    final lines = _lines(tester);
    for (final text in [_long, '$_long.', '$_long!']) {
      final paragraph = tester.renderObject<RenderParagraph>(
        find.byWidget(lines[text]!),
      );
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: text.length),
        boxHeightStyle: ui.BoxHeightStyle.max,
      );
      final lineCount = {for (final box in boxes) box.top.round()}.length;
      expect(lineCount, greaterThan(1), reason: '折り返している：$text');
      final fontSize = paragraph.text.style!.fontSize!;
      expect(
        paragraph.size.height / lineCount,
        closeTo(fontSize * noteLineHeight, 1),
        reason: text,
      );
    }
  });
}
