import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/entity/mark_entity.dart';
import 'package:koala/marks/marks_list_items.dart';
import 'package:koala/marks/marks_model.dart';

import '../support/app_flows.dart';
import '../support/demo_database.dart';
import '../support/jst.dart';
import '../support/localized_app.dart';

/// 備考が長く、リンクのアイコンもあるとき、狭い幅で折り返しても、高さが合う。
void main() {
  for (final width in [240.0, 260.0, 300.0, 360.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('長い備考とリンクが、幅 $width・文字 $scale 倍で収まる', (tester) async {
        useScreen(tester, Size(width, 800), textScale: scale);
        final services = DemoDatabase().servicesFor('me');
        final key = await services.leaflets.addLeaflet('t', coverEmoji: '🐨');
        final leaflet = (await services.leaflets.watchLeaflets().first)
            .firstWhere((l) => l.key == key);
        final model = MarksModel(leaflet, services);
        final mark = MarkEntity(
          'k',
          false,
          null,
          'Drive to Churaumi Aquarium',
          'The expressway gets busy on holidays, so leave the hotel early '
              'and have breakfast on the way',
          'https://churaumi.okinawa/',
          'Asia/Tokyo',
          jst(2026, 10, 10, 8, 30),
          jst(2026, 10, 10, 10, 30),
        );

        await tester.pumpWidget(
          localizedApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Builder(
                  builder: (context) => ActionItem(mark).build(context, model),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
      });
    }
  }
}
