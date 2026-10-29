import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/leaflets/leaflet_card.dart';
import 'package:koala/leaflets/leaflets_screen.dart';

import '../support/app_flows.dart';
import '../support/demo_database.dart';

void main() {
  group('leafletGridColumns', () {
    test('画面が広いほど列が増える', () {
      expect(leafletGridColumns(288), 2);
      expect(leafletGridColumns(358), 2);
      expect(leafletGridColumns(736), 5);
      expect(leafletGridColumns(2000), 6, reason: '多すぎる列は 6 までにする');
    });

    test('文字が大きいほど列が減り、最小でも 1 列', () {
      expect(leafletGridColumns(358, textFactor: 1.3), 2);
      expect(leafletGridColumns(358, textFactor: 2), 1);
      expect(leafletGridColumns(100, textFactor: 2), 1);
    });
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('小さい画面で文字 $scale 倍でも、期間のタブがカードの幅に収まる', (tester) async {
      useScreen(tester, const Size(320, 568), textScale: scale);
      await openLeafletList(tester, DemoDatabase().services);

      expect(tester.takeException(), isNull);
      final cards = find.byType(LeafletCard);
      expect(cards, findsWidgets);
      for (final card in cards.evaluate()) {
        final cardBox = card.renderObject! as RenderBox;
        final cardRight = cardBox
            .localToGlobal(Offset(cardBox.size.width, 0))
            .dx;
        final dates = find.descendant(
          of: find.byWidget(card.widget),
          matching: find.textContaining('/'),
        );
        for (final date in dates.evaluate()) {
          final box = date.renderObject! as RenderBox;
          // FittedBox で縮めた文字も、変形を含めた右端で比べる。
          final right = box.localToGlobal(Offset(box.size.width, 0)).dx;
          expect(right, lessThanOrEqualTo(cardRight + 0.5));
        }
      }
    });
  }
}
