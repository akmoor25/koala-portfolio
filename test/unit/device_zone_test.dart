import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/helper/device_zone_watcher.dart';
import 'package:koala/helper/time_zones.dart';

void main() {
  late Future<String> Function() original;
  late String current;
  late int reads;

  setUp(() {
    original = readDeviceZoneId;
    current = 'Asia/Tokyo';
    reads = 0;
    readDeviceZoneId = () async {
      reads++;
      return current;
    };
    setDeviceZoneForTest('Asia/Tokyo');
  });

  tearDown(() {
    readDeviceZoneId = original;
    setDeviceZoneForTest('Asia/Tokyo');
  });

  group('refreshDeviceZone', () {
    test('notifies when the device time zone changed', () async {
      final seen = <String>[];
      deviceZoneListenable.addListener(() => seen.add(deviceZoneId));
      addTearDown(() => seen.clear());

      current = 'America/New_York';
      await refreshDeviceZone();

      expect(deviceZoneId, 'America/New_York');
      expect(seen, ['America/New_York']);
    });

    test('does not notify when nothing changed', () async {
      var notified = 0;
      void listener() => notified++;
      deviceZoneListenable.addListener(listener);
      addTearDown(() => deviceZoneListenable.removeListener(listener));

      await refreshDeviceZone();

      expect(notified, 0);
    });

    test('ignores an unknown id', () async {
      current = 'Mars/Olympus';

      await refreshDeviceZone();

      expect(deviceZoneId, 'Asia/Tokyo');
    });

    test('keeps the old zone when reading fails', () async {
      readDeviceZoneId = () async => throw StateError('no platform');

      await refreshDeviceZone();

      expect(deviceZoneId, 'Asia/Tokyo');
    });

    test('formatting follows the new device zone for a legacy step', () async {
      final instant = DateTime.utc(2026, 10, 10, 0, 30);
      expect(formatInZone(instant, '', 'HH:mm'), '09:30');

      current = 'America/New_York';
      await refreshDeviceZone();

      expect(formatInZone(instant, '', 'HH:mm'), '20:30');
    });
  });

  group('DeviceZoneWatcher', () {
    testWidgets('notices a change while the app stays in front', (
      tester,
    ) async {
      await tester.pumpWidget(
        const DeviceZoneWatcher(
          interval: Duration(seconds: 1),
          child: SizedBox.shrink(),
        ),
      );

      current = 'Europe/Paris';
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(deviceZoneId, 'Europe/Paris');
    });

    testWidgets('checks right away when the app comes back', (tester) async {
      await tester.pumpWidget(
        const DeviceZoneWatcher(
          interval: Duration(minutes: 5),
          child: SizedBox.shrink(),
        ),
      );
      current = 'Australia/Sydney';

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(deviceZoneId, 'Australia/Sydney');
    });

    testWidgets('does not poll while in the background', (tester) async {
      await tester.pumpWidget(
        const DeviceZoneWatcher(
          interval: Duration(seconds: 1),
          child: SizedBox.shrink(),
        ),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      final before = reads;

      await tester.pump(const Duration(seconds: 5));

      expect(reads, before);
    });
  });
}
