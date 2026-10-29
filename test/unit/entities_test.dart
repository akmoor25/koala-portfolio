import 'package:flutter_test/flutter_test.dart';
import 'package:koala/entity/leaflet_entity.dart';
import 'package:koala/entity/mark_entity.dart';
import 'package:koala/helper/act_type.dart';

void main() {
  group('MarkEntity.tryBuild', () {
    test('builds a valid mark', () {
      final mark = MarkEntity.tryBuild('m1', {
        'startDate': 1000,
        'endDate': 2000,
        'actIcon': 5,
        'isAbout': true,
        'title': '新幹線',
        'remark': '指定席',
        'link': 'https://example.com',
        'timeZoneId': 'Asia/Tokyo',
      })!;

      expect(mark.key, 'm1');
      expect(mark.actType, ActType.train);
      expect(mark.isAbout, isTrue);
      expect(mark.title, '新幹線');
      expect(mark.timeZoneId, 'Asia/Tokyo');
      expect(mark.endDate, isNotNull);
    });

    test('skips a mark whose start date is missing or not a number', () {
      expect(MarkEntity.tryBuild('m', {'title': 'x'}), isNull);
      expect(MarkEntity.tryBuild('m', {'startDate': 'tomorrow'}), isNull);
    });

    test('falls back to defaults for wrongly typed optional fields', () {
      final mark = MarkEntity.tryBuild('m', {
        'startDate': 1000,
        'endDate': 'later',
        'actIcon': 'train',
        'isAbout': 'yes',
        'title': 5,
        'remark': null,
      })!;

      expect(mark.endDate, isNull);
      expect(mark.actType, isNull);
      expect(mark.isAbout, isFalse);
      expect(mark.title, '');
      expect(mark.remark, '');
      expect(mark.timeZoneId, '');
    });

    test('ignores an out-of-range icon', () {
      final mark = MarkEntity.tryBuild('m', {
        'startDate': 1000,
        'actIcon': 99,
      })!;
      expect(mark.actType, isNull);
    });

    test('keeps the time zone when written back', () {
      final mark = MarkEntity.tryBuild('m', {
        'startDate': 1000,
        'timeZoneId': 'Asia/Tokyo',
      })!;
      expect(mark.toJson()['timeZoneId'], 'Asia/Tokyo');
    });
  });

  group('LeafletEntity', () {
    test('requires a title', () {
      expect(LeafletEntity.tryBuild('k', {'imageUrl': '✈️'}), isNull);
      expect(LeafletEntity.tryBuild('k', {'title': 3}), isNull);
    });

    test('reads the owner and the sharing flag', () {
      final leaflet = LeafletEntity.tryBuild('k', {
        'title': '北海道',
        'ownerUid': 'alice',
        'shared': true,
      })!;
      expect(leaflet.ownerUid, 'alice');
      expect(leaflet.shared, isTrue);
    });

    test('treats missing or mistyped ownership as not shared', () {
      final leaflet = LeafletEntity.tryBuild('k', {
        'title': '北海道',
        'ownerUid': 5,
        'shared': 'yes',
      })!;
      expect(leaflet.ownerUid, isNull);
      expect(leaflet.shared, isFalse);
    });

    test('does not write the owner or the sharing flag back', () {
      final json = LeafletEntity(
        'k',
        't',
        null,
        null,
        null,
        null,
        ownerUid: 'alice',
        shared: true,
      ).toJson();
      expect(json.keys, isNot(contains('ownerUid')));
      expect(json.keys, isNot(contains('shared')));
    });
  });
}
