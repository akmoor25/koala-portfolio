import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:koala/data/app_services.dart';
import 'package:koala/launch/launch_model.dart';

import '../support/demo_data.dart';
import '../support/demo_database.dart';

void main() {
  test('is busy while connecting and returns the services', () async {
    final services = DemoDatabase().services;
    final connection = Completer<AppServices>();
    final model = LaunchModel(connect: () => connection.future);
    final busyOnNotify = <bool>[];
    model.addListener(() => busyOnNotify.add(model.busy));

    final started = model.start();
    expect(model.busy, isTrue);

    connection.complete(services);
    expect(await started, same(services));
    expect(model.busy, isFalse);
    expect(model.failed, isFalse);
    expect(busyOnNotify, [true, false]);
  });

  test('a failed connection returns null and is reported', () async {
    final model = LaunchModel(connect: () async => throw Exception('offline'));
    var notified = 0;
    model.addListener(() => notified++);

    expect(await model.start(), isNull);

    expect(model.failed, isTrue);
    expect(model.busy, isFalse);
    expect(notified, 2);
  });

  test('retrying clears the failure and can succeed', () async {
    var attempts = 0;
    final services = DemoDatabase().services;
    final model = LaunchModel(
      connect: () async {
        attempts++;
        if (attempts == 1) throw Exception('offline');
        return services;
      },
    );
    await model.start();
    expect(model.failed, isTrue);

    final failedOnNotify = <bool>[];
    model.addListener(() => failedOnNotify.add(model.failed));
    expect(await model.start(), same(services));

    expect(model.failed, isFalse);
    expect(failedOnNotify, [false, false]);
  });

  test('a second start while connecting does not connect twice', () async {
    var attempts = 0;
    final connection = Completer<AppServices>();
    final model = LaunchModel(
      connect: () {
        attempts++;
        return connection.future;
      },
    );

    final first = model.start();
    expect(await model.start(), isNull);
    expect(attempts, 1);

    connection.complete(DemoDatabase().services);
    expect(await first, isNotNull);
    expect(model.busy, isFalse);
  });

  group('a saved account', () {
    test('that was deleted on the server is signed out and reported', () async {
      final db = DemoDatabase();
      final services = db.services;
      await services.passphrases.write('trip', 'hokkaido-2026');
      db.accountExists = false;
      final model = LaunchModel(connect: () async => services);

      expect(await model.start(), isNull);

      expect(model.accountLost, isTrue);
      expect(model.failed, isFalse);
      expect(model.busy, isFalse);
      expect(db.signedOutAccounts, [demoUserId]);
      expect(db.deletedAccounts, isEmpty);
      expect(await services.passphrases.read('trip'), isNull);
      expect(db.widget.clearedAll, 1);
    });

    test('starts again as a new anonymous user', () async {
      final db = DemoDatabase()..accountExists = false;
      final services = db.services;
      final model = LaunchModel(
        connect: () async {
          await services.auth.signInAnonymously();
          return services;
        },
      );
      expect(await model.start(), isNull);
      expect(model.accountLost, isTrue);

      expect(await model.start(), same(services));
      expect(model.accountLost, isFalse);
    });

    test('that cannot be checked (offline) is kept', () async {
      final db = DemoDatabase()
        ..accountCheckError = Exception('network-request-failed');
      final services = db.services;
      final model = LaunchModel(connect: () async => services);

      expect(await model.start(), same(services));

      expect(model.accountLost, isFalse);
      expect(db.signedOutAccounts, isEmpty);
    });

    testWidgets('is kept when the check stalls for 5 seconds', (tester) async {
      final pending = Completer<void>();
      final db = DemoDatabase()..accountCheckWait = pending.future;
      final services = db.services;
      final model = LaunchModel(connect: () async => services);

      final started = model.start();
      await tester.pump(const Duration(seconds: 5));

      expect(await started, same(services));
      expect(model.accountLost, isFalse);
      expect(db.signedOutAccounts, isEmpty);
      pending.complete();
    });
  });
}
