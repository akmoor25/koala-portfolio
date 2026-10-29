import 'package:flutter_test/flutter_test.dart';
import 'package:koala/data/app_services.dart';
import 'package:koala/entity/leaflet_entity.dart';
import 'package:koala/leaflets/leaflets_model.dart';
import 'package:koala/notifications/push_coordinator.dart';
import 'package:koala/notifications/push_gateway.dart';
import 'package:koala/notifications/push_message.dart';

import '../support/demo_database.dart';
import '../support/fake_push.dart';
import '../support/localized_app.dart';

void main() {
  late DemoDatabase db;

  setUp(() => db = DemoDatabase());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('PushCoordinator', () {
    test(
      'does not ask or register while the permission is undecided',
      () async {
        final coordinator = PushCoordinator(db.servicesFor('bob'));

        await coordinator.start();

        expect(db.pushFor('bob').requests, 0);
        expect(db.deviceTokens['bob'], isNull);
        await coordinator.dispose();
      },
    );

    test('registers the token at start when already allowed', () async {
      db.pushFor('bob').state = PushPermission.authorized;
      final coordinator = PushCoordinator(db.servicesFor('bob'));

      await coordinator.start();

      expect(db.deviceTokens['bob'], {'fake-token'});
      expect(db.pushFor('bob').requests, 0);
      await coordinator.dispose();
    });

    test('registers a refreshed token as well', () async {
      db.pushFor('bob').state = PushPermission.authorized;
      final coordinator = PushCoordinator(db.servicesFor('bob'));
      await coordinator.start();

      db.pushFor('bob').refreshToken('second-token');
      await settle();

      expect(db.deviceTokens['bob'], {'fake-token', 'second-token'});
      await coordinator.dispose();
    });

    test('asks once and registers when the user allows', () async {
      final coordinator = PushCoordinator(db.servicesFor('bob'));

      await coordinator.ensurePermission();
      await coordinator.ensurePermission();

      expect(db.pushFor('bob').requests, 1);
      expect(db.deviceTokens['bob'], {'fake-token'});
      await coordinator.dispose();
    });

    test('does not register, and never asks again, after a refusal', () async {
      db.pushFor('bob').grantOnRequest = false;
      final coordinator = PushCoordinator(db.servicesFor('bob'));

      await coordinator.ensurePermission();
      await coordinator.ensurePermission();

      expect(db.pushFor('bob').requests, 1);
      expect(db.deviceTokens['bob'], isNull);
      await coordinator.dispose();
    });

    test('does not ask when the system already refused', () async {
      db.pushFor('bob').state = PushPermission.denied;
      final coordinator = PushCoordinator(db.servicesFor('bob'));

      await coordinator.ensurePermission();

      expect(db.pushFor('bob').requests, 0);
      expect(db.deviceTokens['bob'], isNull);
    });

    test(
      'does nothing when there is no token (no Play services, no APNs)',
      () async {
        db.pushFor('bob')
          ..state = PushPermission.authorized
          ..currentToken = null;
        final coordinator = PushCoordinator(db.servicesFor('bob'));

        await coordinator.start();

        expect(db.deviceTokens['bob'], isNull);
        await coordinator.dispose();
      },
    );

    test('a failing gateway never throws into the app', () async {
      final base = db.servicesFor('bob');
      final services = AppServices(
        auth: base.auth,
        leaflets: base.leaflets,
        marks: base.marks,
        notes: base.notes,
        presence: base.presence,
        passphrases: base.passphrases,
        widget: base.widget,
        deviceName: base.deviceName,
        push: _ThrowingPush(),
        deviceTokens: base.deviceTokens,
      );
      final coordinator = PushCoordinator(services);

      await coordinator.start();
      await coordinator.ensurePermission();
      expect(await coordinator.initialMessage(), isNull);

      expect(db.deviceTokens['bob'], isNull);
      await coordinator.dispose();
    });
  });

  group(
    'turning on sharing and joining ask for the notification permission',
    () {
      late LeafletsModel alice;
      late LeafletsModel bob;

      setUp(() async {
        alice = LeafletsModel(db.servicesFor('alice'))
          ..l10n = ja
          ..fetchLeafletsEntity();
        bob = LeafletsModel(db.servicesFor('bob'))
          ..l10n = ja
          ..fetchLeafletsEntity();
        await alice.addLeaflet('北海道');
        await settle();
      });

      tearDown(() {
        alice.dispose();
        bob.dispose();
      });

      LeafletEntity trip() =>
          alice.getLeafletsBy(alice.getLeafletsGroupNames().single).single;

      test('the owner is asked after turning sharing on', () async {
        final leaflet = trip();

        await alice.enableSharing(leaflet, 'hokkaido-2026', nickname: 'アキ');
        await settle();

        expect(db.pushFor('alice').requests, 1);
        expect(db.deviceTokens['alice'], {'fake-token'});
      });

      test('the owner is not asked when turning on fails', () async {
        final leaflet = trip();

        await alice.enableSharing(leaflet, 'hokkaido-2026', nickname: '  ');
        await settle();

        expect(db.pushFor('alice').requests, 0);
      });

      test(
        'the friend is asked after joining, not after a failed join',
        () async {
          final leaflet = trip();
          await alice.enableSharing(leaflet, 'hokkaido-2026', nickname: 'アキ');

          final wrong = await bob.joinLeaflet(
            leaflet.key,
            'wrong-word-1',
            nickname: 'ボブ',
          );
          await settle();
          expect(wrong, isNotNull);
          expect(db.pushFor('bob').requests, 0);

          final ok = await bob.joinLeaflet(
            leaflet.key,
            'hokkaido-2026',
            nickname: 'ボブ',
          );
          await settle();
          expect(ok, isNull);
          expect(db.pushFor('bob').requests, 1);
          expect(db.deviceTokens['bob'], {'fake-token'});
        },
      );
    },
  );
}

/// 何をしても失敗する FCM（Play 開発者サービスが無い端末や、APNs が使えない環境の代わり）。
class _ThrowingPush extends FakePushGateway {
  @override
  Future<PushPermission> permission() async => throw Exception('unavailable');

  @override
  Future<PushPermission> requestPermission() async =>
      throw Exception('unavailable');

  @override
  Future<String?> token() async => throw Exception('unavailable');

  @override
  Future<PushMessage?> initialMessage() async => throw Exception('unavailable');
}
