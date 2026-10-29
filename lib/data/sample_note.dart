import 'dart:convert';

import '../notes/note_colors.dart';

/// サンプルのノートの、書式付きの文字列。
///
/// 文章は日本語で書き、作るときに、しおりの言語へ訳す（`sample_texts_en.dart`）。
class SampleText {
  /// [text] に、文字の書式を付ける。
  const SampleText(
    this.text, {
    this.bold = false,
    this.underline = false,
    this.strike = false,
    this.color,
    this.link,
  });

  /// 文章。改行は含めない。
  final String text;

  /// 太字。
  final bool bold;

  /// 下線。
  final bool underline;

  /// 取り消し線。
  final bool strike;

  /// 文字色。黒・白は、一方のテーマで読めなくなるので選べない。
  final NoteTextColor? color;

  /// リンク先の URL。
  final String? link;

  Map<String, Object?> get _attributes => {
    if (bold) 'bold': true,
    if (underline) 'underline': true,
    if (strike) 'strike': true,
    'color': ?color?.hex,
    'link': ?link,
  };
}

/// 段落の種類。
enum SampleBlock {
  /// 普通の段落。
  plain,

  /// 見出し。
  heading,

  /// 小見出し。
  subheading,

  /// 箇条書き。
  bullet,

  /// 番号付きの箇条書き。
  numbered,

  /// チェックリスト（未完了）。
  todo,

  /// チェックリスト（完了）。
  done,

  /// 引用。
  quote,
}

/// サンプルのノートの 1 段落。
class SampleParagraph {
  /// [spans] は、`String`（書式なし）か [SampleText]。
  const SampleParagraph(
    this.spans, {
    this.block = SampleBlock.plain,
    this.indent = 0,
  });

  /// 段落の中身。
  final List<Object> spans;

  /// 段落の種類。
  final SampleBlock block;

  /// 字下げの段数（箇条書きの入れ子など）。
  final int indent;

  Map<String, Object?> get _attributes => {
    ...switch (block) {
      SampleBlock.plain => const <String, Object?>{},
      // Quill の見出しの段（h2・h3）。
      SampleBlock.heading => const {'header': 2},
      SampleBlock.subheading => const {'header': 3},
      SampleBlock.bullet => const {'list': 'bullet'},
      SampleBlock.numbered => const {'list': 'ordered'},
      SampleBlock.todo => const {'list': 'unchecked'},
      SampleBlock.done => const {'list': 'checked'},
      SampleBlock.quote => const {'blockquote': true},
    },
    if (indent > 0) 'indent': indent,
  };
}

/// サンプルで使う文字色。ノートの文字色の選択肢（[NoteTextColor]）から選ぶ。
abstract final class SampleColor {
  /// 赤（注意）。
  static const red = NoteTextColor.red;

  /// 青（情報）。
  static const blue = NoteTextColor.blue;

  /// 緑（済み・おすすめ）。
  static const green = NoteTextColor.green;

  /// オレンジ（楽しみ）。
  static const orange = NoteTextColor.orange;

  /// 紫（思い出）。
  static const purple = NoteTextColor.purple;
}

/// 見出し。
SampleParagraph heading(String text) =>
    SampleParagraph([text], block: SampleBlock.heading);

/// 小見出し。
SampleParagraph subheading(String text) =>
    SampleParagraph([text], block: SampleBlock.subheading);

/// 普通の段落。
SampleParagraph para(List<Object> spans) => SampleParagraph(spans);

/// 箇条書き。
SampleParagraph bullet(List<Object> spans, {int indent = 0}) =>
    SampleParagraph(spans, block: SampleBlock.bullet, indent: indent);

/// 番号付きの箇条書き。
SampleParagraph numbered(List<Object> spans, {int indent = 0}) =>
    SampleParagraph(spans, block: SampleBlock.numbered, indent: indent);

/// チェックリストの項目。[done] なら、済み。
SampleParagraph todo(List<Object> spans, {bool done = false, int indent = 0}) =>
    SampleParagraph(
      spans,
      block: done ? SampleBlock.done : SampleBlock.todo,
      indent: indent,
    );

/// 引用。
SampleParagraph quote(List<Object> spans) =>
    SampleParagraph(spans, block: SampleBlock.quote);

/// 太字。
SampleText bold(String text, {NoteTextColor? color}) =>
    SampleText(text, bold: true, color: color);

/// 色付きの文字。
SampleText colored(String text, NoteTextColor color, {bool bold = false}) =>
    SampleText(text, color: color, bold: bold);

/// 取り消し線。予定を変えた跡などに使う。
SampleText struck(String text) => SampleText(text, strike: true);

/// 下線。
SampleText underlined(String text) => SampleText(text, underline: true);

/// リンク。
SampleText link(String text, String url) => SampleText(text, link: url);

/// [paragraphs] を、[t] で訳して、Quill の Delta JSON にする。
String sampleNoteJson(
  List<SampleParagraph> paragraphs,
  String Function(String) t,
) {
  final ops = <Map<String, Object?>>[];
  for (final paragraph in paragraphs) {
    for (final span in paragraph.spans) {
      final text = span is SampleText ? span : SampleText(span as String);
      if (text.text.contains('\n')) {
        throw ArgumentError.value(
          text.text,
          'span',
          'must not contain a newline',
        );
      }
      final attributes = text._attributes;
      ops.add({
        'insert': t(text.text),
        if (attributes.isNotEmpty) 'attributes': attributes,
      });
    }
    final attributes = paragraph._attributes;
    ops.add({
      'insert': '\n',
      if (attributes.isNotEmpty) 'attributes': attributes,
    });
  }
  return jsonEncode(ops);
}
