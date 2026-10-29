import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'remote_caret.dart';

/// [child] に置いた [QuillEditor] の上に、他メンバーのキャレットとイニシャルを描く。
class RemoteCaretOverlay extends StatefulWidget {
  const RemoteCaretOverlay({
    super.key,
    required this.carets,
    required this.editorKey,
    required this.controller,
    required this.scrollController,
    required this.child,
  });

  final List<RemoteCaret> carets;
  final GlobalKey<EditorState> editorKey;
  final QuillController controller;
  final ScrollController scrollController;
  final Widget child;

  @override
  State<RemoteCaretOverlay> createState() => _RemoteCaretOverlayState();
}

class _RemoteCaretOverlayState extends State<RemoteCaretOverlay> {
  final GlobalKey _paintKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.carets.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                key: _paintKey,
                painter: _RemoteCaretPainter(
                  carets: widget.carets,
                  editorKey: widget.editorKey,
                  controller: widget.controller,
                  paintKey: _paintKey,
                  // スクロールや自分の編集では、このウィジェットを再ビルドせずにキャレットが動く。
                  repaint: Listenable.merge([
                    widget.scrollController,
                    widget.controller,
                  ]),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RemoteCaretPainter extends CustomPainter {
  _RemoteCaretPainter({
    required this.carets,
    required this.editorKey,
    required this.controller,
    required this.paintKey,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final List<RemoteCaret> carets;
  final GlobalKey<EditorState> editorKey;
  final QuillController controller;
  final GlobalKey paintKey;

  static const _caretWidth = 2.0;
  static const _badgeSize = 16.0;

  @override
  void paint(Canvas canvas, Size size) {
    final renderEditor = editorKey.currentState?.renderEditor;
    final overlayBox =
        paintKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderEditor == null ||
        !renderEditor.attached ||
        !renderEditor.hasSize ||
        overlayBox == null) {
      return;
    }

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final documentLength = controller.document.length;
    for (final caret in carets) {
      final position = TextPosition(offset: caret.clampedIndex(documentLength));
      final Rect localRect;
      try {
        localRect = renderEditor.getLocalRectForCaret(position);
      } on Exception catch (_) {
        // 相手の変更で文書を差し替えた直後はエディタが再ビルド中のことがある。次のフレームで描き直す。
        continue;
      } on Error catch (_) {
        // 描画中の不整合（範囲外など）は Error として投げられる。同様に次のフレームで描き直す。
        continue;
      }
      final topLeft = overlayBox.globalToLocal(
        renderEditor.localToGlobal(localRect.topLeft),
      );
      final rect = Rect.fromLTWH(
        topLeft.dx,
        topLeft.dy,
        _caretWidth,
        localRect.height,
      );
      _paintCaret(canvas, rect, caret);
    }
    canvas.restore();
  }

  void _paintCaret(Canvas canvas, Rect rect, RemoteCaret caret) {
    final paint = Paint()..color = caret.color;
    canvas.drawRect(rect, paint);

    // 表示中の先頭行では上に余白がないので、バッジをキャレットの下に出す。
    final above = rect.top >= _badgeSize;
    final badge = Rect.fromLTWH(
      rect.left,
      above ? rect.top - _badgeSize + 2 : rect.bottom - 2,
      _badgeSize,
      _badgeSize,
    );
    const radius = Radius.circular(4);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        badge,
        topLeft: above ? radius : Radius.zero,
        topRight: radius,
        bottomLeft: above ? Radius.zero : radius,
        bottomRight: radius,
      ),
      paint,
    );

    final text = TextPainter(
      text: TextSpan(
        text: caret.name,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, badge.center - Offset(text.width / 2, text.height / 2));
    text.dispose();
  }

  @override
  bool shouldRepaint(_RemoteCaretPainter oldDelegate) =>
      oldDelegate.carets != carets;
}
