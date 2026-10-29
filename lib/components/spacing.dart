import 'package:flutter/widgets.dart';

/// 余白の段階。画面と部品の余白は、この値から選ぶ。
abstract final class AppSpace {
  /// 4。文字と文字の間など、ごく小さい間隔。
  static const double xsmall = 4;

  /// 8。関連する部品の間。
  static const double small = 8;

  /// 16。標準。画面の端の余白や、まとまりの間。
  static const double medium = 16;

  /// 24。大きなまとまりの間。
  static const double large = 24;

  /// 32。区切りの間。
  static const double xlarge = 32;
}

/// 四方に同じ余白を取る [EdgeInsets]。段階は [AppSpace] と同じ。
///
/// 向きごとに違う値や、4 つの段階にない値は、[AppSpace] を使って `EdgeInsets` を直接書く。
abstract final class AppInsets {
  /// 4。
  static const xsmall = EdgeInsets.all(AppSpace.xsmall);

  /// 8。
  static const small = EdgeInsets.all(AppSpace.small);

  /// 16。
  static const medium = EdgeInsets.all(AppSpace.medium);

  /// 24。
  static const large = EdgeInsets.all(AppSpace.large);
}

/// 縦の間隔。`const VGap.medium()` のように、段階の名前で指定する。
class VGap extends SizedBox {
  /// 4。
  const VGap.xsmall({super.key}) : super(height: AppSpace.xsmall);

  /// 8。
  const VGap.small({super.key}) : super(height: AppSpace.small);

  /// 16。
  const VGap.medium({super.key}) : super(height: AppSpace.medium);

  /// 24。
  const VGap.large({super.key}) : super(height: AppSpace.large);

  /// 32。
  const VGap.xlarge({super.key}) : super(height: AppSpace.xlarge);
}

/// 横の間隔。`const HGap.small()` のように、段階の名前で指定する。
class HGap extends SizedBox {
  /// 4。
  const HGap.xsmall({super.key}) : super(width: AppSpace.xsmall);

  /// 8。
  const HGap.small({super.key}) : super(width: AppSpace.small);

  /// 16。
  const HGap.medium({super.key}) : super(width: AppSpace.medium);

  /// 24。
  const HGap.large({super.key}) : super(width: AppSpace.large);

  /// 32。
  const HGap.xlarge({super.key}) : super(width: AppSpace.xlarge);
}
