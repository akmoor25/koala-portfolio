import 'package:flutter/material.dart';

import 'koala_colors.dart';

/// ボタンの種類。
enum AppButtonKind {
  /// 主色の面。ふつうの主役の操作。
  primary,

  /// 黄色の面（ステッカー）。わくわくする操作（作る、始める、参加する）。
  accent,

  /// 枠だけ。補助の操作。
  secondary,

  /// 文字だけ。取り消しなど、控えめな操作。
  text,

  /// 深い赤の面。削除や退出など、元に戻せない操作。
  danger,

  /// 文字だけの、危険な操作。メニューの中の「削除する」「退出する」。
  dangerText,
}

/// ボタンの角の丸み。
const double appButtonRadius = 14;

/// 押せる最小の高さ。
const double appButtonMinHeight = 48;

/// 文字のボタン以外の、最小の幅。短いラベルでも押しやすい幅にする。
const double _appButtonMinWidth = 64;

// 状態ごとに文字の色を面に重ねる濃さ。Material 3 の状態レイヤーの値に合わせる
// （https://m3.material.io/foundations/interaction/states/state-layers）。
const double _hoverOverlayAlpha = 0.08;
const double _focusOverlayAlpha = 0.10;
const double _pressOverlayAlpha = 0.14;

// 無効のときの、面と文字の濃さ（地の文字色に対する割合）。Material 3 の無効の値に合わせる。
const double disabledContainerAlpha = 0.12;
const double disabledContentAlpha = 0.38;

/// 枠のあるボタンの線の太さ。
const double _borderWidth = 1.5;

/// 薄い面のアイコンのボタン（[AppIconButtonKind.tonal]）の、面の濃さ。
const double _tonalFillAlpha = 0.12;

/// 状態に応じた重ねの色。押している、フォーカス、ホバーの順に優先する。
Color _stateOverlay(Color base, Set<WidgetState> states) {
  if (states.contains(WidgetState.pressed)) {
    return base.withValues(alpha: _pressOverlayAlpha);
  }
  if (states.contains(WidgetState.focused)) {
    return base.withValues(alpha: _focusOverlayAlpha);
  }
  if (states.contains(WidgetState.hovered)) {
    return base.withValues(alpha: _hoverOverlayAlpha);
  }
  return Colors.transparent;
}

/// [kind] のボタンの見た目。ノーマル、ホバー、フォーカス、押している、無効の状態を決める。
///
/// 状態の見た目：
/// - ノーマル：種類ごとの面と文字。
/// - ホバー、フォーカス、押している：文字の色を、8%、10%、14% の濃さで面に重ねる。
/// - 無効：面は地の文字色の 12%、文字は 38%。
///
/// [busy] が true のときは、押せないが、無効の色にはしない（処理中のスピナーを見せるため）。
///
/// 主色の面（[AppButtonKind.primary]）の文字は白。押したときの重ねは、白ではなく、濃い紺（[KoalaColors.ink]）。
ButtonStyle appButtonStyle(
  AppButtonKind kind,
  ThemeData theme, {
  bool busy = false,
}) {
  final k = theme.koala;
  final onSurface = theme.colorScheme.onSurface;
  final (fill, content, border) = switch (kind) {
    AppButtonKind.primary => (k.brand, k.onBrand, null),
    AppButtonKind.accent => (k.accent, k.onAccent, k.onAccentBorder),
    AppButtonKind.danger => (k.danger, k.onDanger, null),
    AppButtonKind.secondary => (Colors.transparent, k.brandDeep, k.brandDeep),
    AppButtonKind.text => (Colors.transparent, k.brandDeep, null),
    AppButtonKind.dangerText => (Colors.transparent, k.dangerText, null),
  };

  bool off(Set<WidgetState> states) =>
      states.contains(WidgetState.disabled) && !busy;

  // 主色の面の重ねは、白（文字の色）だと押した感じが出ないので、濃い紺にする。
  final overlayBase = kind == AppButtonKind.primary ? KoalaColors.ink : content;

  final isFilled = fill != Colors.transparent;
  final hasBorder = border != null && border != Colors.transparent;
  return ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(
      Size(_appButtonMinWidth, appButtonMinHeight),
    ),
    padding: WidgetStatePropertyAll(
      EdgeInsets.symmetric(
        horizontal:
            kind == AppButtonKind.text || kind == AppButtonKind.dangerText
            ? 12
            : 20,
        vertical: 12,
      ),
    ),
    elevation: const WidgetStatePropertyAll(0),
    shape: const WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(appButtonRadius)),
      ),
    ),
    tapTargetSize: MaterialTapTargetSize.padded,
    textStyle: WidgetStatePropertyAll(
      theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) => off(states) && isFilled
          ? onSurface.withValues(alpha: disabledContainerAlpha)
          : fill,
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => off(states)
          ? onSurface.withValues(alpha: disabledContentAlpha)
          : content,
    ),
    iconColor: WidgetStateProperty.resolveWith(
      (states) => off(states)
          ? onSurface.withValues(alpha: disabledContentAlpha)
          : content,
    ),
    overlayColor: WidgetStateProperty.resolveWith(
      (states) => _stateOverlay(overlayBase, states),
    ),
    side: WidgetStateProperty.resolveWith((states) {
      if (off(states) && kind == AppButtonKind.secondary) {
        return BorderSide(
          color: onSurface.withValues(alpha: disabledContainerAlpha),
          width: _borderWidth,
        );
      }
      return hasBorder ? BorderSide(color: border, width: _borderWidth) : null;
    }),
  );
}

/// アイコンのボタンの種類。
enum AppIconButtonKind {
  /// 面なし。
  standard,

  /// 主色の面。アイコンは白。
  filled,

  /// 薄い空色の面。
  tonal,
}

/// [kind] のアイコンのボタンの見た目。押せる大きさは 48dp。
ButtonStyle appIconButtonStyle(
  AppIconButtonKind kind,
  ThemeData theme, {
  Color? color,
}) {
  final k = theme.koala;
  final onSurface = theme.colorScheme.onSurface;
  final (fill, content) = switch (kind) {
    AppIconButtonKind.standard => (Colors.transparent, color),
    AppIconButtonKind.filled => (k.brand, k.onBrand),
    AppIconButtonKind.tonal => (
      k.brandDeep.withValues(alpha: _tonalFillAlpha),
      k.brandDeep,
    ),
  };
  return ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size.square(appButtonMinHeight)),
    tapTargetSize: MaterialTapTargetSize.padded,
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) =>
          states.contains(WidgetState.disabled) && fill != Colors.transparent
          ? onSurface.withValues(alpha: disabledContainerAlpha)
          : fill,
    ),
    foregroundColor: content == null
        ? null
        : WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? onSurface.withValues(alpha: disabledContentAlpha)
                : content,
          ),
    overlayColor: WidgetStateProperty.resolveWith((states) {
      final base = kind == AppIconButtonKind.filled
          ? KoalaColors.ink
          : (content ?? onSurface);
      return _stateOverlay(base, states);
    }),
  );
}
