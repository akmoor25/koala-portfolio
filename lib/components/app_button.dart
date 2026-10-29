import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'pressable_scale.dart';

export '../theme/button_styles.dart' show AppButtonKind, AppIconButtonKind;

/// フォーカスのリングと、ボタンの縁との間隔。ボタンの面の色に埋もれないよう、外側に離す。
const double _focusRingGap = 5;

/// フォーカスのリングの太さ。
const double _focusRingWidth = 3;

/// 処理中のスピナーの大きさ。ボタンのアイコンと同じ程度にする。
const double _spinnerSize = 18;

/// アプリ共通のボタン。種類（[AppButtonKind]）ごとに、ノーマル、ホバー、フォーカス、押している、
/// 無効、処理中の見た目が決まっている（`doc/design/README.md`）。
///
/// - 押せる大きさは、高さ 48dp 以上。
/// - 押している間は、少し縮む（[PressableScale]）。
/// - フォーカスされたときは、ボタンの外側に、3dp のリングを描く。
/// - [busy] のときは、アイコンがスピナーに変わり、押せない。
/// - [onPressed] が null なら、無効。
class AppButton extends StatefulWidget {
  /// [label] と [onPressed] で作る。
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = AppButtonKind.primary,
    this.icon,
    this.busy = false,
    this.expand = false,
    this.statesController,
    this.autofocus = false,
  });

  /// フォーカスのリングの目印（テスト用）。
  static const focusRingKey = ValueKey<String>('app-button-focus-ring');

  /// ボタンの文字。
  final String label;

  /// 押したときの処理。null なら、無効。
  final VoidCallback? onPressed;

  /// ボタンの種類。
  final AppButtonKind kind;

  /// 文字の前に置くアイコン。
  final IconData? icon;

  /// 処理中か。true なら、スピナーを出し、押せない。
  final bool busy;

  /// true なら、幅いっぱいに広げる。
  final bool expand;

  /// 状態（押している、フォーカスなど）を外から見る、または動かすための入れ物。主にテスト用。
  final WidgetStatesController? statesController;

  /// 最初にフォーカスを受け取るか。
  final bool autofocus;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  WidgetStatesController? _own;
  bool _focused = false;

  WidgetStatesController get _controller =>
      widget.statesController ?? (_own ??= WidgetStatesController());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onStates);
  }

  @override
  void didUpdateWidget(AppButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.statesController != widget.statesController) {
      (oldWidget.statesController ?? _own)?.removeListener(_onStates);
      _controller.addListener(_onStates);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onStates);
    _own?.dispose();
    super.dispose();
  }

  void _onStates() {
    final focused = _controller.value.contains(WidgetState.focused);
    if (focused == _focused) return;
    setState(() => _focused = focused);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = appButtonStyle(widget.kind, theme, busy: widget.busy);
    final onPressed = widget.busy ? null : widget.onPressed;
    final leading = widget.busy
        ? Builder(
            builder: (context) => SizedBox.square(
              dimension: _spinnerSize,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: IconTheme.of(context).color,
              ),
            ),
          )
        : (widget.icon == null ? null : Icon(widget.icon));
    final label = Text(widget.label);

    final Widget button = switch (widget.kind) {
      AppButtonKind.secondary =>
        leading == null
            ? OutlinedButton(
                onPressed: onPressed,
                style: style,
                statesController: _controller,
                autofocus: widget.autofocus,
                child: label,
              )
            : OutlinedButton.icon(
                onPressed: onPressed,
                style: style,
                statesController: _controller,
                autofocus: widget.autofocus,
                icon: leading,
                label: label,
              ),
      AppButtonKind.text || AppButtonKind.dangerText =>
        leading == null
            ? TextButton(
                onPressed: onPressed,
                style: style,
                statesController: _controller,
                autofocus: widget.autofocus,
                child: label,
              )
            : TextButton.icon(
                onPressed: onPressed,
                style: style,
                statesController: _controller,
                autofocus: widget.autofocus,
                icon: leading,
                label: label,
              ),
      _ =>
        leading == null
            ? FilledButton(
                onPressed: onPressed,
                style: style,
                statesController: _controller,
                autofocus: widget.autofocus,
                child: label,
              )
            : FilledButton.icon(
                onPressed: onPressed,
                style: style,
                statesController: _controller,
                autofocus: widget.autofocus,
                icon: leading,
                label: label,
              ),
    };

    return PressableScale(
      enabled: onPressed != null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (widget.expand)
            SizedBox(width: double.infinity, child: button)
          else
            button,
          if (_focused)
            Positioned(
              left: -_focusRingGap,
              top: -_focusRingGap,
              right: -_focusRingGap,
              bottom: -_focusRingGap,
              child: IgnorePointer(
                child: DecoratedBox(
                  key: AppButton.focusRingKey,
                  decoration: BoxDecoration(
                    // 外側に広げた分だけ角も丸め、ボタンの角と平行な輪にする。
                    borderRadius: BorderRadius.circular(
                      appButtonRadius + _focusRingGap,
                    ),
                    border: Border.all(
                      color: theme.koala.focusRing,
                      width: _focusRingWidth,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// アプリ共通のアイコンのボタン。押せる大きさは 48dp、[tooltip] は必須（読み上げと長押しの説明）。
class AppIconButton extends StatelessWidget {
  /// [icon]、[tooltip]、[onPressed] で作る。
  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.kind = AppIconButtonKind.standard,
    this.color,
    this.iconSize,
  });

  /// アイコン。
  final IconData icon;

  /// 長押しと、読み上げの説明。
  final String tooltip;

  /// 押したときの処理。null なら、無効。
  final VoidCallback? onPressed;

  /// 見た目の種類。
  final AppIconButtonKind kind;

  /// アイコンの色。[AppIconButtonKind.standard] のときだけ使う。null なら、テーマの色。
  final Color? color;

  /// アイコンの大きさ。
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PressableScale(
      enabled: onPressed != null,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        iconSize: iconSize,
        style: appIconButtonStyle(kind, theme, color: color),
        icon: Icon(icon),
      ),
    );
  }
}
