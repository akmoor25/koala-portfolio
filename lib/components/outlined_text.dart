import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';

class OutlineStyle {
  final Color color;
  final double strokeWidth;

  const OutlineStyle({required this.color, required this.strokeWidth});
}

class OutlinedAutoSizeText extends StatelessWidget {
  final String text;
  final List<OutlineStyle> outlines;
  final TextStyle style;
  final TextAlign textAlign;
  final int maxLines;
  final double minFontSize;

  const OutlinedAutoSizeText(
    this.text, {
    super.key,
    required this.outlines,
    required this.style,
    this.textAlign = TextAlign.center,
    this.maxLines = 2,
    this.minFontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    final autoSizeGroup = AutoSizeGroup();

    final stackChildren = <Widget>[];

    // 縁取りを外側（リスト末尾）から内側（リスト先頭）の順に描く
    for (var outline in outlines.reversed) {
      stackChildren.add(
        AutoSizeText(
          text,
          textAlign: textAlign,
          maxLines: maxLines,
          minFontSize: minFontSize,
          group: autoSizeGroup,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeJoin = StrokeJoin.round
              ..strokeWidth = outline.strokeWidth
              ..color = outline.color,
            color: null, // foreground を使うときは color を null にする必要がある
          ),
        ),
      );
    }

    // 最後に塗りの文字を重ねる
    stackChildren.add(
      AutoSizeText(
        text,
        textAlign: textAlign,
        maxLines: maxLines,
        minFontSize: minFontSize,
        group: autoSizeGroup,
        style: style,
      ),
    );

    return Stack(alignment: Alignment.center, children: stackChildren);
  }
}
