import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../l10n/l10n.dart';
import '../theme/app_theme.dart';

/// ノートで選べる文字色。
///
/// 黒・白のように、ライトかダークの一方の背景に溶けて読めなくなる色は含めない。
/// どの色も、両方の背景に対してコントラスト比 3 以上（大きな文字の目安）を保つ。
enum NoteTextColor {
  /// 赤。
  red('#E53935'),

  /// オレンジ。
  orange('#EF6C00'),

  /// 緑。
  green('#43A047'),

  /// 青緑。
  teal('#00897B'),

  /// 青。
  blue('#1E88E5'),

  /// 紫。
  purple('#AB47BC'),

  /// ピンク。
  pink('#D81B60'),

  /// 茶。
  brown('#8D6E63');

  const NoteTextColor(this.hex);

  /// Quill の `color` 属性に保存する値（`#RRGGBB`）。
  final String hex;

  /// 表示に使う色。
  Color get color => Color(int.parse('FF${hex.substring(1)}', radix: 16));

  /// 画面に出す色の名前。
  String label(AppLocalizations l10n) => switch (this) {
    red => l10n.noteColorRed,
    orange => l10n.noteColorOrange,
    green => l10n.noteColorGreen,
    teal => l10n.noteColorTeal,
    blue => l10n.noteColorBlue,
    purple => l10n.noteColorPurple,
    pink => l10n.noteColorPink,
    brown => l10n.noteColorBrown,
  };
}

/// 文字色の読みやすさを測る、ライトとダークの背景。
const noteLightBackground = Colors.white;

/// ノートのリンクの色。ライトとダークのどちらの背景でも読める青にする。
final Color noteLinkColor = NoteTextColor.blue.color;

/// ダークテーマの背景（[buildAppTheme] と同じ種から作る面の色）。
final Color noteDarkBackground = ColorScheme.fromSeed(
  seedColor: lightPrimaryColor,
  brightness: Brightness.dark,
).surface;

/// 読める文字色とみなす、背景とのコントラスト比の下限。
///
/// 新しく選べる色は 3 以上（WCAG の大きな文字の基準）にしている。ここは、保存済みの色を
/// 打ち消すかどうかの判断なので、明らかに背景に溶ける色だけを対象にする。
const double _minReadableContrast = 2;

/// [a] と [b] のコントラスト比（1 から 21）。
///
/// WCAG の定義どおり、明るい方と暗い方の相対輝度に 0.05 を足して割る
/// （https://www.w3.org/TR/WCAG21/#dfn-contrast-ratio）。
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// 保存済みの文字色を、そのまま表示しても読めるか。
///
/// 他の端末や以前の版で付いた黒・白などは、ライトかダークの一方で背景に溶ける。
/// その場合は、データは変えずに、表示だけ既定の文字色にする。
bool isReadableNoteTextColor(Color color) =>
    contrastRatio(color, noteLightBackground) >= _minReadableContrast &&
    contrastRatio(color, noteDarkBackground) >= _minReadableContrast;

/// `#RRGGBB` などの文字色の値。読めなければ null。
///
/// 6 桁（RGB）は不透明として扱い、8 桁（ARGB）はそのまま使う。
Color? _parseColor(Object? value) {
  if (value is! String) return null;
  final hex = value.startsWith('#') ? value.substring(1) : value;
  final argb = switch (hex.length) {
    6 => int.tryParse('FF$hex', radix: 16),
    8 => int.tryParse(hex, radix: 16),
    _ => null,
  };
  return argb == null ? null : Color(argb);
}

/// ノートの表示で、読めなくなる書式を打ち消す（QuillEditor の customStyleBuilder）。
///
/// - 文字色：背景に溶ける色（黒・白など）は、[defaultColor] で表示する。
/// - 背景色：選べないようにしたので、保存済みの値も表示しない（文字色との組み合わせで読めなくなるため）。
TextStyle noteDisplayStyle(Attribute<dynamic> attribute, Color? defaultColor) {
  if (attribute.key == Attribute.color.key) {
    final color = _parseColor(attribute.value);
    if (color != null && !isReadableNoteTextColor(color)) {
      return TextStyle(color: defaultColor);
    }
  }
  if (attribute.key == Attribute.background.key && attribute.value != null) {
    return const TextStyle(backgroundColor: Colors.transparent);
  }
  return const TextStyle();
}

/// 文字色を選ぶダイアログを出し、選んだ色を [controller] の選択範囲に付ける。
Future<void> showNoteColorDialog(
  BuildContext context,
  QuillController controller,
) async {
  final current = controller
      .getSelectionStyle()
      .attributes[Attribute.color.key]
      ?.value;
  final l10n = context.l10n;
  final picked = await showDialog<_ColorChoice>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.noteColorTitle),
      content: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final color in NoteTextColor.values)
            Tooltip(
              message: color.label(l10n),
              child: Semantics(
                button: true,
                selected: color.hex == current,
                label: color.label(l10n),
                child: InkResponse(
                  onTap: () => Navigator.of(context).pop(_ColorChoice(color)),
                  radius: 24,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.color,
                      shape: BoxShape.circle,
                    ),
                    child: color.hex == current
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(const _ColorChoice(null)),
          child: Text(l10n.noteColorDefault),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
      ],
    ),
  );
  if (picked == null) return;
  controller.formatSelection(ColorAttribute(picked.color?.hex));
}

class _ColorChoice {
  const _ColorChoice(this.color);

  /// null は、既定の文字色に戻す。
  final NoteTextColor? color;
}
