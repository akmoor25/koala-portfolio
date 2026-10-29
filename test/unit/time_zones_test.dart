import 'package:flutter_test/flutter_test.dart';
import 'package:koala/helper/time_zones.dart';

void main() {
  group('instantOf / wallOf', () {
    test('the same wall clock is a different instant in each zone', () {
      final wall = DateTime(2026, 10, 10, 9);

      final tokyo = instantOf('Asia/Tokyo', wall);
      final paris = instantOf('Europe/Paris', wall);

      expect(tokyo.toUtc(), DateTime.utc(2026, 10, 10, 0));
      expect(paris.toUtc(), DateTime.utc(2026, 10, 10, 7)); // 夏時間（UTC+2）
      expect(paris.isAfter(tokyo), isTrue);
    });

    test('wallOf is the inverse of instantOf', () {
      for (final zone in pinnedZoneIds) {
        final wall = DateTime(2026, 7, 4, 13, 45);
        expect(wallOf(zone, instantOf(zone, wall)), wall, reason: zone);
      }
    });

    test('shows one instant as the local time of each city', () {
      final instant = DateTime.utc(2026, 1, 15, 12);

      expect(wallOf('Asia/Tokyo', instant), DateTime(2026, 1, 15, 21));
      expect(wallOf('Europe/London', instant), DateTime(2026, 1, 15, 12));
      expect(wallOf('America/New_York', instant), DateTime(2026, 1, 15, 7));
      expect(wallOf('America/Los_Angeles', instant), DateTime(2026, 1, 15, 4));
      expect(wallOf('Australia/Sydney', instant), DateTime(2026, 1, 15, 23));
      expect(wallOf('Asia/Bangkok', instant), DateTime(2026, 1, 15, 19));
    });

    test('the date can differ between zones for the same instant', () {
      final instant = DateTime.utc(2026, 10, 10, 20);

      expect(wallOf('Asia/Tokyo', instant).day, 11);
      expect(wallOf('America/Los_Angeles', instant).day, 10);
    });
  });

  group('daylight saving time', () {
    test('a time that does not exist moves to just after the gap', () {
      // 2026-03-08 02:30 は、ニューヨークでは存在しない（02:00 → 03:00）。
      final instant = instantOf(
        'America/New_York',
        DateTime(2026, 3, 8, 2, 30),
      );

      expect(wallOf('America/New_York', instant), DateTime(2026, 3, 8, 3, 30));
    });

    test('a time that happens twice means the first one', () {
      // 2026-11-01 01:30 は、ニューヨークでは 2 回ある（夏時間と標準時）。
      final instant = instantOf(
        'America/New_York',
        DateTime(2026, 11, 1, 1, 30),
      );

      expect(instant.toUtc(), DateTime.utc(2026, 11, 1, 5, 30)); // 夏時間（UTC-4）
    });

    test('the UTC offset follows the date', () {
      final summer = DateTime.utc(2026, 7, 1);
      final winter = DateTime.utc(2026, 1, 1);

      expect(utcOffsetLabel('America/New_York', summer), 'UTC-4');
      expect(utcOffsetLabel('America/New_York', winter), 'UTC-5');
      expect(utcOffsetLabel('Australia/Sydney', summer), 'UTC+10');
      expect(utcOffsetLabel('Australia/Sydney', winter), 'UTC+11');
    });
  });

  group('labels', () {
    test('writes half-hour offsets with minutes', () {
      expect(utcOffsetLabel('Asia/Kolkata', DateTime.utc(2026)), 'UTC+5:30');
    });

    test('shows the city name', () {
      expect(cityNameOf('Asia/Tokyo'), 'Tokyo');
      expect(cityNameOf('America/New_York'), 'New York');
      expect(cityNameOf('America/Argentina/Buenos_Aires'), 'Buenos Aires');
      expect(cityNameOf('UTC'), 'UTC');
    });

    test('joins the city and the offset', () {
      expect(
        zoneLabel('Europe/Paris', DateTime.utc(2026, 1, 1)),
        'Paris (UTC+1)',
      );
    });
  });

  group('zone ids', () {
    test('knows the real ids and the 12 cities, including aliases', () {
      for (final id in [
        ...pinnedZoneIds,
        'Europe/Amsterdam',
        'Asia/Calcutta',
      ]) {
        expect(isValidZoneId(id), isTrue, reason: id);
      }
    });

    test('rejects empty and unknown ids, which fall back to the device', () {
      setDeviceZoneForTest('Asia/Tokyo');

      expect(isValidZoneId(''), isFalse);
      expect(isValidZoneId('Mars/Olympus'), isFalse);
      expect(resolveZoneId(''), 'Asia/Tokyo');
      expect(resolveZoneId('Mars/Olympus'), 'Asia/Tokyo');
      expect(resolveZoneId('Europe/Paris'), 'Europe/Paris');
    });

    test('the choices are real region ids, without legacy aliases', () {
      final ids = selectableZoneIds();

      expect(ids, containsAll(pinnedZoneIds));
      expect(ids, contains('UTC'));
      expect(ids.any((id) => id.startsWith('US/')), isFalse);
      expect(ids.any((id) => id.startsWith('Etc/')), isFalse);
      expect(ids, orderedEquals([...ids]..sort()));
    });

    test('the 12 pinned cities are all different', () {
      expect(pinnedZoneIds.toSet(), hasLength(12));
    });
  });

  group('the device time zone does not change the local time', () {
    final instant = DateTime.utc(2026, 10, 10, 0, 30);

    for (final device in ['Asia/Tokyo', 'America/New_York', 'UTC']) {
      test('with the device in $device', () {
        setDeviceZoneForTest(device);
        addTearDown(() => setDeviceZoneForTest('Asia/Tokyo'));

        expect(formatInZone(instant, 'Asia/Tokyo', 'HH:mm'), '09:30');
        expect(
          formatInZone(instant, 'Europe/Paris', 'M/d HH:mm'),
          '10/10 02:30',
        );
      });
    }

    test('only the empty zone follows the device', () {
      setDeviceZoneForTest('America/New_York');
      addTearDown(() => setDeviceZoneForTest('Asia/Tokyo'));

      expect(formatInZone(instant, '', 'HH:mm'), '20:30');
    });
  });

  group('formats do not depend on the language', () {
    test('uses English month and weekday names', () {
      expect(formatWall(DateTime(2026, 10, 25), 'MM/dd\nEEE'), '10/25\nSun');
      expect(formatWall(DateTime(2026, 1, 2, 3, 4), 'M/d HH:mm'), '1/2 03:04');
    });
  });
}
