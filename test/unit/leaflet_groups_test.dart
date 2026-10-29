import 'package:flutter_test/flutter_test.dart';
import 'package:koala/entity/leaflet_entity.dart';
import 'package:koala/helper/time_zones.dart';
import 'package:koala/leaflets/leaflets_model.dart';

void main() {
  setUpAll(initTimeZones);

  final now = DateTime.utc(2026, 10, 10, 3);

  LeafletEntity leaflet(String key, DateTime? first, DateTime? last) =>
      LeafletEntity(
        key,
        key,
        null,
        null,
        first,
        last,
        firstTimeZoneId: 'Asia/Tokyo',
      );

  test('upcoming, ongoing and past trips fall into Next, Now and years', () {
    final leaflets = [
      leaflet('future', now.add(const Duration(days: 3)), null),
      leaflet('undated', null, null),
      leaflet(
        'ongoing',
        now.subtract(const Duration(days: 1)),
        now.add(const Duration(days: 1)),
      ),
      leaflet('past', DateTime.utc(2025, 5, 1), DateTime.utc(2025, 5, 3)),
      leaflet('no-end', DateTime.utc(2026, 1, 5), null),
    ];

    List<String> keys(String group) =>
        leafletsInGroup(leaflets, group, now).map((l) => l.key).toList();
    expect(keys('Next'), ['future', 'undated']);
    expect(keys('Now'), ['ongoing']);
    expect(keys('2026'), ['no-end']);
    expect(keys('2025'), ['past']);
  });

  test('a trip that ends exactly now is no longer under way', () {
    final ended = leaflet('ended', now.subtract(const Duration(days: 2)), now);
    expect(groupNamesOf([ended], now), ['2026']);
  });

  test('groups are ordered Next, Now, then years from the newest', () {
    final leaflets = [
      leaflet('old', DateTime.utc(2024, 3, 1), DateTime.utc(2024, 3, 2)),
      leaflet(
        'ongoing',
        now.subtract(const Duration(hours: 1)),
        now.add(const Duration(hours: 1)),
      ),
      leaflet('recent', DateTime.utc(2026, 2, 1), DateTime.utc(2026, 2, 2)),
      leaflet('future', now.add(const Duration(days: 30)), null),
    ];
    expect(groupNamesOf(leaflets, now), ['Next', 'Now', '2026', '2024']);
  });
}
