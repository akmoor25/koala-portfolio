import 'package:flutter_test/flutter_test.dart';
import 'package:koala/leaflets/leaflet_card.dart';

import '../support/jst.dart';

void main() {
  group('dateRangeText', () {
    test('is null without a start date', () {
      expect(dateRangeText(null, null), isNull);
      expect(dateRangeText(null, jst(2026, 10, 12)), isNull);
    });

    test('shows one day when there is no end or it is the same day', () {
      expect(dateRangeText(jst(2026, 10, 10), null), '10/10');
      expect(
        dateRangeText(jst(2026, 10, 10, 9), jst(2026, 10, 10, 18)),
        '10/10',
      );
    });

    test('shows the range across days', () {
      expect(
        dateRangeText(jst(2026, 10, 10), jst(2026, 10, 12)),
        '10/10～10/12',
      );
    });
  });
}
