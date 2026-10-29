import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:koala/helper/data_collection.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late int crashStarted;
  late int messagingStarted;
  late DataCollection collection;

  setUp(() {
    crashStarted = 0;
    messagingStarted = 0;
    collection = DataCollection(
      startCrashReports: () async => crashStarted++,
      startMessaging: () async => messagingStarted++,
    );
  });

  group('DataCollection', () {
    test('sends nothing until start is called', () {
      expect(crashStarted, 0);
      expect(messagingStarted, 0);
    });

    test('start enables crash reports and FCM', () async {
      await collection.start();

      expect(crashStarted, 1);
      expect(messagingStarted, 1);
    });

    test('a failure in one step does not stop the other', () async {
      final failing = DataCollection(
        startCrashReports: () => Future.error(StateError('crashlytics')),
        startMessaging: () async => messagingStarted++,
      );

      await expectLater(failing.start(), completes);
      expect(messagingStarted, 1);
    });
  });

  group('platform settings stop sending before the user starts', () {
    test('AndroidManifest.xml turns off Crashlytics and FCM auto init', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();

      for (final name in [
        'firebase_crashlytics_collection_enabled',
        'firebase_messaging_auto_init_enabled',
      ]) {
        expect(
          RegExp('android:name="$name"\\s+android:value="false"')
              .hasMatch(manifest),
          isTrue,
          reason: name,
        );
      }
    });

    test('Info.plist turns off Crashlytics and FCM auto init', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();

      for (final key in [
        'FirebaseCrashlyticsCollectionEnabled',
        'FirebaseMessagingAutoInitEnabled',
      ]) {
        expect(
          RegExp('<key>$key</key>\\s*<false\\s*/>').hasMatch(plist),
          isTrue,
          reason: key,
        );
      }
    });

    test('collection is switched on only in the connection flow', () {
      final callers = [
        for (final file in Directory('lib').listSync(recursive: true))
          if (file is File &&
              file.path.endsWith('.dart') &&
              file.readAsStringSync().contains('const DataCollection().start('))
            file.path.replaceAll(r'\', '/'),
      ];

      expect(callers, ['lib/data/app_services.dart']);
    });
  });
}
