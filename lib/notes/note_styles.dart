import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../theme/app_theme.dart';
import 'note_colors.dart';

// Quill の余白と行間は、段落の種類ごとに設定が分かれている。
// - 普通の段落：paragraph の verticalSpacing（段落の上と下）
// - 見出し 1〜6：h1〜h6 の verticalSpacing
// - 箇条書き・チェックリスト・引用：lists・quote の verticalSpacing（まとまりの前後）と
//   lineSpacing（まとまりの中の行の間）。チェック済みと未完了は、別のまとまりになる。
// - 折り返した行の間隔：文字スタイルの height（文字の大きさに対する倍率）
// どの種類でも同じ見え方になるよう、下の定数をそろえて設定する。

/// 普通の段落と見出しの、上と下の余白。
const noteParagraphSpacing = VerticalSpacing(8, 8);

/// 箇条書き・チェックリスト・引用の、まとまりの中の行と、まとまりの前後の上と下の余白。
/// チェック済みと未完了の項目は別のまとまりになるので、前後の余白も同じ値にそろえる。
const noteLineSpacing = VerticalSpacing(2, 2);

/// 本文が折り返したときの行の高さ（文字の大きさに対する倍率）。Quill の既定は 1.15。
const noteLineHeight = 1.5;

/// ノートのエディタの書式（QuillEditorConfig の customStyles）。
///
/// 既定（[DefaultStyles.getInstance]）から、余白・行の高さ・リンクの色だけを変える。
/// 文字のスタイルを空の `TextStyle` に置き換えると、色が無くなり白で描かれるため、既定を引き継ぐ。
DefaultStyles noteEditorStyles(BuildContext context) {
  final base = DefaultStyles.getInstance(context);
  DefaultTextBlockStyle heading(DefaultTextBlockStyle? style) =>
      style!.copyWith(verticalSpacing: noteParagraphSpacing);
  return DefaultStyles(
    h1: heading(base.h1),
    h2: heading(base.h2),
    h3: heading(base.h3),
    h4: heading(base.h4),
    h5: heading(base.h5),
    h6: heading(base.h6),
    paragraph: base.paragraph!.copyWith(
      style: base.paragraph!.style.copyWith(height: noteLineHeight),
      verticalSpacing: noteParagraphSpacing,
    ),
    // 箇条書きの文字のスタイルは、段落の行の高さを上書きするので、同じ値にする。
    // 引用の文字のスタイルは色だけなので、段落の行の高さを引き継ぐ。
    lists: base.lists!.copyWith(
      style: base.lists!.style.copyWith(height: noteLineHeight),
      verticalSpacing: noteLineSpacing,
      lineSpacing: noteLineSpacing,
    ),
    quote: base.quote!.copyWith(
      verticalSpacing: noteLineSpacing,
      lineSpacing: noteLineSpacing,
    ),
    // 既定のリンク色（テーマの secondary）は黄色で、白地では読めない。
    link: base.link!.copyWith(color: noteLinkColor),
  );
}

/// ノートのツールバーのアイコンの見た目。
///
/// Quill は、有効な書式（引用など）のボタンを `IconButton.filled`（塗りの面に白いアイコン）で描く。
/// アプリの IconButtonTheme は、面を透明にしているため、そのままでは白地に白いアイコンになる。
/// 有効なボタンは、アプリの淡い面と濃いアイコン（tonal）で描く。
QuillIconTheme noteToolbarIconTheme(ThemeData theme) => QuillIconTheme(
  iconButtonSelectedData: IconButtonData(
    style: appIconButtonStyle(AppIconButtonKind.tonal, theme),
  ),
);
