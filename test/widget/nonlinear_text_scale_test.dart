import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/marks/marks_screen.dart';

import '../support/app_flows.dart';
import '../support/demo_data.dart';
import '../support/demo_database.dart';

/// Android 14 以降の「非線形」な文字拡大を真似る。小さい文字ほど大きく拡大し、
/// 大きい文字（24 以上）はほとんど拡大しない。
class _NonlinearTextScaler extends TextScaler {
  const _NonlinearTextScaler(this.maxFactor);

  final double maxFactor;

  @override
  double scale(double fontSize) {
    if (fontSize >= 24) return fontSize;
    final t = (24 - fontSize).clamp(0, 12) / 12;
    return fontSize * (1 + (maxFactor - 1) * t);
  }

  @override
  double get textScaleFactor => scale(14) / 14;

  @override
  bool operator ==(Object other) =>
      other is _NonlinearTextScaler && other.maxFactor == maxFactor;

  @override
  int get hashCode => maxFactor.hashCode;
}

void main() {
  for (final factor in [1.0, 1.3, 2.0]) {
    testWidgets('文字を拡大（最大 $factor 倍）しても、日付の円と旅程の線が同じ縦線に並ぶ', (tester) async {
      useScreen(tester, const Size(768, 1024));
      await openLeafletList(
        tester,
        DemoDatabase().services,
        textScaler: _NonlinearTextScaler(factor),
      );
      await openLeaflet(tester, demoTripTitle);

      // 縦線は、日付ヘッダでも旅程でも、幅 4 の色つきの箱。
      final lines = find
          .descendant(
            of: find.byType(MarksScreen),
            matching: find.byType(ColoredBox),
          )
          .evaluate()
          .where((e) => (e.renderObject! as RenderBox).size.width == 4)
          .map(
            (e) => (e.renderObject! as RenderBox)
                .localToGlobal(const Offset(2, 0))
                .dx,
          )
          .toSet();
      expect(lines, hasLength(1), reason: '縦線の位置がそろっていない: $lines');

      // 乗り物のアイコンは、右端が縦線の左端に接する。
      final icons = find.descendant(
        of: find.byType(MarksScreen),
        matching: find.byType(RotatedBox),
      );
      expect(icons, findsWidgets);
      for (final icon in icons.evaluate()) {
        final box = icon.renderObject! as RenderBox;
        expect(
          box.localToGlobal(Offset(box.size.width, 0)).dx,
          lines.single - 2,
        );
      }
    });
  }

  for (final factor in [1.3, 2.0]) {
    testWidgets('非線形に文字を拡大（最大 $factor 倍）しても、旅程の時刻が折り返されない', (tester) async {
      useScreen(tester, const Size(768, 1024));
      await openLeafletList(
        tester,
        DemoDatabase().services,
        textScaler: _NonlinearTextScaler(factor),
      );
      await openLeaflet(tester, demoTripTitle);

      expect(tester.takeException(), isNull);
      final times = find.textContaining(RegExp(r'^[～]?\d\d:\d\d$'));
      expect(times, findsWidgets);
      for (final time in times.evaluate()) {
        final box = time.renderObject! as RenderBox;
        // 1 行なら、高さは文字の大きさ（最大でも 14 を 1.3 倍）の 2 倍に届かない。
        expect(
          box.size.height,
          lessThan(14 * 1.3 * 2),
          reason: '時刻が折り返されている: ${(time.widget as Text).data}',
        );
      }
    });
  }
}
