import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/components/app_button.dart';
import 'package:koala/components/readable_width.dart';
import 'package:koala/components/spacing.dart';

import '../support/app_flows.dart';
import '../support/demo_data.dart';
import '../support/demo_database.dart';

void main() {
  group('spacing tokens', () {
    test('the scale is 4, 8, 16, 24, 32', () {
      expect(
        [
          AppSpace.xsmall,
          AppSpace.small,
          AppSpace.medium,
          AppSpace.large,
          AppSpace.xlarge,
        ],
        [4, 8, 16, 24, 32],
      );
    });

    test('gaps and insets use the scale', () {
      expect(const VGap.medium().height, AppSpace.medium);
      expect(const HGap.large().width, AppSpace.large);
      expect(AppInsets.small, const EdgeInsets.all(AppSpace.small));
    });
  });

  group('ReadableWidth', () {
    testWidgets('keeps the launch button narrow on a wide tablet', (
      tester,
    ) async {
      useScreen(tester, const Size(1024, 768));
      await tester.pumpWidget(buildTestApp(DemoDatabase().services));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(AppButton)).width, AppWidth.form);
    });

    testWidgets('does not change a phone', (tester) async {
      useScreen(tester, const Size(390, 844));
      await tester.pumpWidget(buildTestApp(DemoDatabase().services));
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byType(AppButton)).width,
        390 - AppSpace.large * 2,
      );
    });

    testWidgets('scrolls the trip from the side margins too', (tester) async {
      useScreen(tester, const Size(1024, 768));
      await openLeafletList(tester, DemoDatabase().services);
      await openLeaflet(tester, demoTripTitle);
      final before = tester.getTopLeft(find.text(demoNowStepTitle)).dy;

      // 画面の左端は、幅の上限（720dp）の外側の余白。
      await tester.dragFrom(const Offset(20, 400), const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.text(demoNowStepTitle)).dy,
        lessThan(before),
      );
    });

    testWidgets('keeps the join form narrow on a wide tablet', (tester) async {
      useScreen(tester, const Size(1024, 768));
      await openLeafletList(tester, DemoDatabase().services);
      await openJoinScreen(tester);

      final widest = find
          .byType(AppButton)
          .evaluate()
          .map((e) => tester.getSize(find.byWidget(e.widget)).width)
          .reduce((a, b) => a > b ? a : b);
      expect(widest, AppWidth.form);
    });
  });
}
