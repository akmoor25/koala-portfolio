import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/notifications/push_gateway.dart';
import 'package:koala/notifications/push_message.dart';

class _FakeMessaging extends Fake implements FirebaseMessaging {
  _FakeMessaging(this.initial);

  final RemoteMessage? initial;

  @override
  Future<RemoteMessage?> getInitialMessage() async => initial;
}

void main() {
  group('pushPermissionOf', () {
    test('provisional counts as authorized', () {
      expect(
        pushPermissionOf(AuthorizationStatus.authorized),
        PushPermission.authorized,
      );
      expect(
        pushPermissionOf(AuthorizationStatus.provisional),
        PushPermission.authorized,
      );
    });

    test('both kinds of refusal count as denied', () {
      expect(
        pushPermissionOf(AuthorizationStatus.denied),
        PushPermission.denied,
      );
      expect(
        pushPermissionOf(AuthorizationStatus.deniedPermanently),
        PushPermission.denied,
      );
    });

    test('not asked yet stays not determined', () {
      expect(
        pushPermissionOf(AuthorizationStatus.notDetermined),
        PushPermission.notDetermined,
      );
    });
  });

  group('pushMessagesOf', () {
    test(
      'passes readable messages in order and drops unreadable ones',
      () async {
        final incoming = StreamController<RemoteMessage>();
        final messages = pushMessagesOf(incoming.stream);

        final received = expectLater(
          messages.map((m) => (m.kind, m.leafletId)),
          emitsInOrder([
            (NotificationKind.joined, 'A'),
            (NotificationKind.deleted, 'B'),
            emitsDone,
          ]),
        );
        incoming
          ..add(const RemoteMessage(data: {'type': 'joined', 'leafletId': 'A'}))
          ..add(
            const RemoteMessage(data: {'type': 'unknown', 'leafletId': 'X'}),
          )
          ..add(const RemoteMessage())
          ..add(
            const RemoteMessage(data: {'type': 'deleted', 'leafletId': 'B'}),
          );
        await incoming.close();
        await received;
      },
    );
  });

  group('FirebasePushGateway.initialMessage', () {
    test('is null when the app was not opened from a notification', () async {
      final gateway = FirebasePushGateway(_FakeMessaging(null));
      expect(await gateway.initialMessage(), isNull);
    });

    test('reads the notification that opened the app', () async {
      final gateway = FirebasePushGateway(
        _FakeMessaging(
          const RemoteMessage(data: {'type': 'stopped', 'leafletId': 'L'}),
        ),
      );
      final message = await gateway.initialMessage();
      expect(message?.kind, NotificationKind.stopped);
      expect(message?.leafletId, 'L');
    });

    test('is null when the notification cannot be read', () async {
      final gateway = FirebasePushGateway(
        _FakeMessaging(const RemoteMessage(data: {'type': 'unknown'})),
      );
      expect(await gateway.initialMessage(), isNull);
    });
  });
}
