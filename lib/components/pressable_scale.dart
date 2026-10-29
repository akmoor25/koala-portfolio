import 'package:flutter/widgets.dart';

/// 押している間だけ、少し縮む（離すと戻る）。ボタンやカードに、押した手ごたえを足す。
///
/// 指やポインターの動きを聞くだけで、中のウィジェットのタップは奪わない。
/// OS の「アニメーションを減らす」が有効なときは、縮まない。
class PressableScale extends StatefulWidget {
  /// [child] を包む。[enabled] が false なら、縮まない。
  const PressableScale({
    super.key,
    required this.child,
    this.enabled = true,
    this.scale = pressedScale,
  });

  /// 押している間の大きさ。
  static const double pressedScale = 0.97;

  /// 縮む、戻る動きの長さ。
  static const Duration duration = Duration(milliseconds: 90);

  /// 包むウィジェット。
  final Widget child;

  /// false なら、縮まない（無効なボタン）。
  final bool enabled;

  /// 押している間の大きさ。
  final double scale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _set(bool pressed) {
    if (_pressed == pressed) return;
    setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final shrink =
        _pressed && widget.enabled && !MediaQuery.disableAnimationsOf(context);
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: shrink ? widget.scale : 1,
        duration: PressableScale.duration,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
