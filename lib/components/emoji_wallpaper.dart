import 'package:flutter/material.dart';

const double _defaultEmojiSize = 24;
const double _defaultSpacing = 18;

/// 1 行ごとに横へずらす量。1.5 マス分ずらし、同じ絵文字が縦にそろわず、斜めの模様に見えるようにする。
const double _defaultOffsetStepPerLine =
    (_defaultEmojiSize + _defaultSpacing) * 1.5;

/// 行のずれで左端に隙間が出ないよう、左にはみ出して描き始めるマスの数。
const _leadingColumns = 2;

/// 表紙の絵文字を、行ごとにずらした格子状に敷き詰める壁紙。
class EmojiWallpaper extends StatelessWidget {
  final String emoji;
  final Color backgroundColor;
  final double emojiSize;
  final double spacing;
  final double offsetStepPerLine;

  const EmojiWallpaper({
    super.key,
    required this.emoji,
    this.backgroundColor = const Color(0xFFF0F4F8), // 既定の明るい背景色
    this.emojiSize = _defaultEmojiSize,
    this.spacing = _defaultSpacing,
    this.offsetStepPerLine = _defaultOffsetStepPerLine,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      child: ClipRect(
        child: CustomPaint(
          painter: _EmojiPatternPainter(
            emoji: emoji,
            emojiSize: emojiSize,
            spacing: spacing,
            offsetStepPerLine: offsetStepPerLine,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _EmojiPatternPainter extends CustomPainter {
  final String emoji;
  final double emojiSize;
  final double spacing;
  final double offsetStepPerLine;

  _EmojiPatternPainter({
    required this.emoji,
    required this.emojiSize,
    required this.spacing,
    required this.offsetStepPerLine,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (emoji.isEmpty) return;

    final emojiList = emoji.characters.toList();
    final textStyle = TextStyle(fontSize: emojiSize);

    final stepX = emojiSize + spacing;
    final stepY = emojiSize + spacing;

    // 絵文字を行ごとにずらした格子状に描く
    var row = 0;
    for (var y = -stepY; y < size.height + stepY; y += stepY) {
      final totalShiftX = row * offsetStepPerLine;
      final logicalShift = (totalShiftX ~/ stepX);
      final visualShift = totalShiftX % stepX;

      var logicalCol = -_leadingColumns;
      for (
        var x = -stepX * _leadingColumns;
        x < size.width + stepX;
        x += stepX
      ) {
        final actualX = x + visualShift;

        var emojiIndex = (logicalCol - logicalShift) % emojiList.length;
        if (emojiIndex < 0) {
          emojiIndex += emojiList.length;
        }

        final currentEmoji = emojiList[emojiIndex];
        final span = TextSpan(text: currentEmoji, style: textStyle);
        final painter = TextPainter(
          text: span,
          textDirection: TextDirection.ltr,
        );
        painter.layout();

        canvas.save();
        canvas.translate(actualX + stepX / 2, y + stepY / 2);
        painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
        canvas.restore();

        logicalCol++;
      }
      row++;
    }
  }

  @override
  bool shouldRepaint(covariant _EmojiPatternPainter oldDelegate) {
    return oldDelegate.emoji != emoji ||
        oldDelegate.emojiSize != emojiSize ||
        oldDelegate.spacing != spacing ||
        oldDelegate.offsetStepPerLine != offsetStepPerLine;
  }
}
