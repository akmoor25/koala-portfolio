import 'package:flutter/widgets.dart';

/// 内容の幅の上限。
abstract final class AppWidth {
  /// フォームや設定の画面。ボタンと入力欄が横に伸びすぎない幅。
  static const double form = 560;

  /// 文章を読み書きする画面（旅程、ノート）。
  static const double reading = 720;
}

/// 幅が広い画面（タブレットの横など）で、内容を [maxWidth] までにして、中央に寄せる。
///
/// 狭い画面では、何もしない。スクロールする画面では、スクロールの内側に置く
/// （余白の部分でも、指でスクロールできる）。内側に置けないリストは、[ReadableWidth.padding] の
/// 余白を、リストの `padding` に渡す。
class ReadableWidth extends StatelessWidget {
  /// [child] の幅を、[maxWidth] までにする。
  const ReadableWidth({
    super.key,
    required this.child,
    this.maxWidth = AppWidth.form,
  });

  /// 幅を制限する内容。
  final Widget child;

  /// 内容の幅の上限。
  final double maxWidth;

  /// 画面の幅 [width] のうち、[maxWidth] を超える分を、左右に半分ずつ取った余白。
  ///
  /// リスト自体をスクロールの内側に置けないとき（`ScrollablePositionedList` など）に、
  /// リストの `padding` として使う。余白の部分も、リストの一部なので、スクロールできる。
  static EdgeInsets padding(double width, {double maxWidth = AppWidth.form}) {
    final side = ((width - maxWidth) / 2).clamp(0.0, double.infinity);
    return EdgeInsets.symmetric(horizontal: side);
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
