import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/data/app_services.dart';
import 'package:koala/data/data_types.dart';
import 'package:koala/data/firebase/firebase_services.dart';
import 'package:koala/entity/leaflet_entity.dart';
import 'package:koala/l10n/write_task.dart';
import 'package:koala/leaflets/leaflets_model.dart';
import 'package:koala/sharing/share_code.dart';

import '../support/demo_database.dart';
import '../support/localized_app.dart';

void main() {
  late DemoDatabase db;
  late LeafletsModel alice;
  late LeafletsModel bob;
  late LeafletEntity trip;

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() async {
    db = DemoDatabase();
    alice = LeafletsModel(db.servicesFor('alice', name: 'alice'))
      ..fetchLeafletsEntity();
    bob = LeafletsModel(db.servicesFor('bob', name: 'bob'))
      ..l10n = ja
      ..fetchLeafletsEntity();
    await alice.addLeaflet('北海道');
    await settle();
    trip = alice.getLeafletsBy(alice.getLeafletsGroupNames().single).single;
  });

  tearDown(() {
    alice.dispose();
    bob.dispose();
  });

  List<String> titles(LeafletsModel model) => [
    for (final group in model.getLeafletsGroupNames())
      for (final leaflet in model.getLeafletsBy(group)) leaflet.title,
  ];

  test('the creator is the owner and others see nothing yet', () async {
    expect(alice.isOwner(trip), isTrue);
    expect(trip.shared, isFalse);
    expect(titles(bob), isEmpty);
  });

  test('the public id is a well-formed, hand-enterable id', () {
    expect(normalizeLeafletId(trip.key), trip.key);
  });

  test('a friend joins with the id and passphrase', () async {
    await alice.enableSharing(trip, 'hokkaido-2026', nickname: 'アキ');
    await settle();

    final error = await bob.joinLeaflet(
      trip.key,
      'hokkaido-2026',
      nickname: 'ボブ',
    );
    await settle();

    expect(error, isNull);
    expect(titles(bob), ['北海道']);
    expect(bob.isOwner(bob.leafletByKey(trip.key)!), isFalse);
  });

  test('the id may be typed in lower case with hyphens', () async {
    await alice.enableSharing(trip, 'hokkaido-2026', nickname: 'アキ');
    final typed = '${trip.key.substring(0, 4)}-${trip.key.substring(4)}';

    expect(
      await bob.joinLeaflet(
        typed.toLowerCase(),
        'hokkaido-2026',
        nickname: 'ボブ',
      ),
      isNull,
    );
  });

  test('a wrong passphrase is rejected without revealing which part', () async {
    await alice.enableSharing(trip, 'hokkaido-2026', nickname: 'アキ');

    final wrongPassphrase = await bob.joinLeaflet(
      trip.key,
      'not-the-word',
      nickname: 'ボブ',
    );
    final wrongId = await bob.joinLeaflet(
      'ZZZZZZZZZZZZ',
      'hokkaido-2026',
      nickname: 'ボブ',
    );

    expect(wrongPassphrase, isNotNull);
    expect(wrongPassphrase, wrongId);
    expect(titles(bob), isEmpty);
  });

  test('joining fails while sharing is off and after it stops', () async {
    expect(
      await bob.joinLeaflet(trip.key, 'hokkaido-2026', nickname: 'ボブ'),
      isNotNull,
    );

    await alice.enableSharing(trip, 'hokkaido-2026', nickname: 'アキ');
    await alice.disableSharing(trip);

    expect(
      await bob.joinLeaflet(trip.key, 'hokkaido-2026', nickname: 'ボブ'),
      isNotNull,
    );
  });

  test('stopping sharing removes the other members', () async {
    await alice.enableSharing(trip, 'hokkaido-2026', nickname: 'アキ');
    await bob.joinLeaflet(trip.key, 'hokkaido-2026', nickname: 'ボブ');
    await settle();
    expect(titles(bob), ['北海道']);

    await alice.disableSharing(trip);
    await settle();

    expect(titles(bob), isEmpty);
    expect(titles(alice), ['北海道']);
    // 再び有効にしても、もう一度参加が要る。
    await alice.enableSharing(trip, 'hokkaido-2026', nickname: 'アキ');
    await settle();
    expect(titles(bob), isEmpty);
    expect(
      await bob.joinLeaflet(trip.key, 'hokkaido-2026', nickname: 'ボブ'),
      isNull,
    );
  });

  test('invalid input is explained before any request', () async {
    expect(
      await bob.joinLeaflet('short', 'hokkaido-2026', nickname: 'ボブ'),
      contains('12'),
    );
    expect(
      await bob.joinLeaflet(trip.key, 'short', nickname: 'ボブ'),
      contains('8'),
    );
  });

  test('joining twice is reported', () async {
    await alice.enableSharing(trip, 'hokkaido-2026', nickname: 'アキ');
    await bob.joinLeaflet(trip.key, 'hokkaido-2026', nickname: 'ボブ');

    expect(
      await bob.joinLeaflet(trip.key, 'hokkaido-2026', nickname: 'ボブ'),
      contains('すでに参加'),
    );
  });

  test('the owner can change the passphrase; members stay', () async {
    await alice.enableSharing(trip, 'hokkaido-2026', nickname: 'アキ');
    await bob.joinLeaflet(trip.key, 'hokkaido-2026', nickname: 'ボブ');

    await alice.enableSharing(trip, 'new-passphrase', nickname: 'アキ');
    await settle();

    expect(titles(bob), ['北海道']);
    final carol = LeafletsModel(db.servicesFor('carol'));
    expect(
      await carol.joinLeaflet(trip.key, 'hokkaido-2026', nickname: 'ボブ'),
      isNotNull,
    );
    expect(
      await carol.joinLeaflet(trip.key, 'new-passphrase', nickname: 'ボブ'),
      isNull,
    );
    carol.dispose();
  });

  test('a participant can leave and rejoin; the owner keeps it', () async {
    await alice.enableSharing(trip, 'hokkaido-2026', nickname: 'アキ');
    await bob.joinLeaflet(trip.key, 'hokkaido-2026', nickname: 'ボブ');
    await settle();

    await bob.leaveLeaflet(bob.leafletByKey(trip.key)!);
    await settle();

    expect(titles(bob), isEmpty);
    expect(titles(alice), contains('北海道'));
    expect(
      await bob.joinLeaflet(trip.key, 'hokkaido-2026', nickname: 'ボブ'),
      isNull,
    );
  });

  test('deleting removes the leaflet for every member', () async {
    await alice.enableSharing(trip, 'hokkaido-2026', nickname: 'アキ');
    await bob.joinLeaflet(trip.key, 'hokkaido-2026', nickname: 'ボブ');
    await settle();

    await alice.deleteLeaflet(trip);
    await settle();

    expect(titles(alice), isNot(contains('北海道')));
    expect(titles(bob), isEmpty);
  });

  test('a participant cannot change the sharing state', () async {
    await alice.enableSharing(trip, 'hokkaido-2026', nickname: 'アキ');
    await bob.joinLeaflet(trip.key, 'hokkaido-2026', nickname: 'ボブ');
    await settle();
    final seen = bob.leafletByKey(trip.key)!;

    var failed = false;
    bob.onWriteError = (_) => failed = true;
    await bob.disableSharing(seen);

    expect(failed, isTrue);
    // 失敗したので、あいことばはまだ有効。
    final carol = LeafletsModel(db.servicesFor('carol'));
    expect(
      await carol.joinLeaflet(trip.key, 'hokkaido-2026', nickname: 'ボブ'),
      isNull,
    );
    carol.dispose();
  });

  test('a participant edit keeps the owner and sharing state', () async {
    await alice.enableSharing(trip, 'hokkaido-2026', nickname: 'アキ');
    await bob.joinLeaflet(trip.key, 'hokkaido-2026', nickname: 'ボブ');
    await settle();
    final mine = bob.leafletByKey(trip.key)!;

    await bob.updateLeafletTitle(mine.key, '北海道 2 泊 3 日');
    await settle();

    final seen = alice.leafletByKey(trip.key)!;
    expect(seen.title, '北海道 2 泊 3 日');
    expect(seen.ownerUid, 'alice');
    expect(seen.shared, isTrue);
  });

  test('the owner re-reads the passphrase on the device that set it', () async {
    await alice.enableSharing(trip, 'hokkaido-2026', nickname: 'アキ');
    expect(await alice.savedPassphrase(trip), 'hokkaido-2026');

    await alice.disableSharing(trip);
    expect(await alice.savedPassphrase(trip), isNull);
  });

  test('an invalid nickname stops turning sharing on', () async {
    var reported = '';
    alice.onWriteError = (message) => reported = message;

    final ok = await alice.enableSharing(
      trip,
      'hokkaido-2026',
      nickname: '   ',
    );
    await settle();

    expect(ok, isFalse);
    expect(reported, isNotEmpty);
    expect(alice.leafletByKey(trip.key)!.shared, isFalse);
    expect(await alice.savedPassphrase(trip), isNull);
  });

  test('turning sharing on saves the nickname first', () async {
    await alice.enableSharing(trip, 'hokkaido-2026', nickname: ' アキ ');

    expect(alice.nickname, 'アキ');
    expect(alice.leafletByKey(trip.key)!.shared, isTrue);
  });

  test(
    'joining with an invalid nickname is refused before any request',
    () async {
      await alice.enableSharing(trip, 'hokkaido-2026', nickname: 'アキ');

      final error = await bob.joinLeaflet(
        trip.key,
        'hokkaido-2026',
        nickname: 'あ' * 21,
      );
      await settle();

      expect(error, contains('20'));
      expect(titles(bob), isEmpty);
      expect(bob.nickname, 'bob');
    },
  );

  test('joining saves the nickname that was typed', () async {
    await alice.enableSharing(trip, 'hokkaido-2026', nickname: 'アキ');

    final error = await bob.joinLeaflet(
      trip.key,
      'hokkaido-2026',
      nickname: ' ボブ ',
    );

    expect(error, isNull);
    expect(bob.nickname, 'ボブ');
  });

  test(
    'the suggested nickname is the saved one, else the device model',
    () async {
      expect(await bob.suggestedNickname(), 'bob');

      final fresh = LeafletsModel(db.servicesFor('carol'))..l10n = ja;
      addTearDown(fresh.dispose);
      expect(await fresh.suggestedNickname(), 'Pixel 10a');
    },
  );

  test('the nickname is saved for the badge initial', () async {
    await bob.updateNickname('さくら');
    expect(bob.nickname, 'さくら');
  });

  test(
    'deleting and leaving ask the home widget to clear the leaflet',
    () async {
      await alice.enableSharing(trip, 'hokkaido-2026', nickname: 'アキ');
      await bob.joinLeaflet(trip.key, 'hokkaido-2026', nickname: 'ボブ');
      await settle();

      await bob.leaveLeaflet(bob.leafletByKey(trip.key)!);
      expect(db.widget.cleared, [trip.key]);

      await alice.deleteLeaflet(trip);
      expect(db.widget.cleared, [trip.key, trip.key]);
    },
  );

  test('a failed delete or leave leaves the home widget alone', () async {
    await alice.enableSharing(trip, 'hokkaido-2026', nickname: 'アキ');
    await bob.joinLeaflet(trip.key, 'hokkaido-2026', nickname: 'ボブ');
    await settle();
    bob.onWriteError = (_) {};

    // 参加者は削除できず、オーナーは抜けられない。
    await bob.deleteLeaflet(bob.leafletByKey(trip.key)!);
    await alice.leaveLeaflet(trip);

    expect(db.widget.cleared, isEmpty);
  });

  group('unconfirmed server writes', () {
    late List<String> messages;

    setUp(() async {
      await alice.enableSharing(trip, 'hokkaido-2026', nickname: 'アキ');
      messages = [];
      alice
        ..l10n = ja
        ..onWriteError = messages.add;
      db.serverWriteError = const WriteUnconfirmed();
    });

    test('deleting a trip keeps local data and reports unconfirmed', () async {
      await alice.deleteLeaflet(trip);
      expect(messages, [ja.writeUnconfirmed(WriteTask.deleteTrip)]);
      expect(await alice.savedPassphrase(trip), 'hokkaido-2026');
      expect(db.widget.cleared, isEmpty);
    });

    test(
      'stopping sharing keeps the passphrase and reports unconfirmed',
      () async {
        expect(await alice.disableSharing(trip), isFalse);
        expect(messages, [ja.writeUnconfirmed(WriteTask.disableSharing)]);
        expect(await alice.savedPassphrase(trip), 'hokkaido-2026');
      },
    );

    test('deleting the account reports unconfirmed', () async {
      expect(await alice.deleteAccount(), isFalse);
      expect(messages, [ja.writeUnconfirmed(WriteTask.deleteAccount)]);
      expect(db.deletedAccounts, isEmpty);
      expect(alice.accountUnavailable, isFalse);
    });

    test('joining reports unconfirmed', () async {
      db.serverWriteError = const JoinFailure(JoinFailureReason.unconfirmed);
      expect(
        await bob.joinLeaflet(trip.key, 'hokkaido-2026', nickname: 'ボブ'),
        ja.joinUnconfirmed,
      );
    });

    test('ordinary failures keep the failure message', () async {
      db.serverWriteError = Exception('permission-denied');
      await alice.deleteLeaflet(trip);
      expect(messages, [ja.writeFailed(WriteTask.deleteTrip)]);
    });
  });

  group('losing the session while in use', () {
    test(
      'a server-side deletion is reported and local data is cleared',
      () async {
        await alice.enableSharing(trip, 'hokkaido-2026', nickname: 'アキ');
        var notified = 0;
        alice.addListener(() => notified++);

        db.expireSession('alice');
        await settle();
        await settle();

        expect(alice.sessionLost, isTrue);
        expect(notified, greaterThan(0));
        expect(alice.myUid, isNull);
        expect(await alice.savedPassphrase(trip), isNull);
        expect(db.widget.clearedAll, 1);
        // サーバーのデータには触らない（権限が無い）。
        expect(db.deletedAccounts, isEmpty);
        expect(bob.sessionLost, isFalse);
      },
    );

    test('writing after the sign-out does not throw and is reported', () async {
      db.expireSession('alice');
      await settle();
      String? message;
      alice.onWriteError = (value) => message = value;

      await alice.addLeaflet('次の旅');
      expect(await alice.addSampleLeaflets(), 0);
      await settle();

      expect(alice.sessionLost, isTrue);
      expect(message, isNull);
      expect(titles(alice), ['北海道']);
    });

    test('joining after the sign-out returns an explanation', () async {
      await alice.enableSharing(trip, 'hokkaido-2026', nickname: 'アキ');
      db.expireSession('bob');
      await settle();

      expect(
        await bob.joinLeaflet(trip.key, 'hokkaido-2026', nickname: 'ボブ'),
        ja.sessionLostTitle,
      );
      await settle();
      expect(bob.sessionLost, isTrue);
    });

    test('deleting the account is not reported as a lost session', () async {
      expect(await alice.deleteAccount(), isTrue);
      await settle();
      expect(alice.sessionLost, isFalse);
    });

    group('while the device token is still valid', () {
      // コンソールで削除しても、トークンが有効な間は、端末はサインアウトされず、書き込みも通る。
      setUp(() => db.accountExists = false);

      test('creating a trip is refused and reported', () async {
        String? message;
        alice.onWriteError = (value) => message = value;

        await alice.addLeaflet('次の旅');
        await settle();

        expect(alice.sessionLost, isTrue);
        expect(db.signedOutAccounts, ['alice']);
        expect(message, isNull);
        final saved = await db
            .servicesFor('alice')
            .leaflets
            .watchLeaflets()
            .first;
        expect([for (final leaflet in saved) leaflet.title], ['北海道']);
      });

      test('adding the samples is refused', () async {
        expect(await alice.addSampleLeaflets(), 0);
        final saved = await db
            .servicesFor('alice')
            .leaflets
            .watchLeaflets()
            .first;
        expect(saved, hasLength(1));
        expect(alice.sessionLost, isTrue);
      });

      test('enabling sharing is refused', () async {
        expect(
          await alice.enableSharing(trip, 'hokkaido-2026', nickname: 'アキ'),
          isFalse,
        );
        expect(alice.sessionLost, isTrue);
        expect(await alice.savedPassphrase(trip), isNull);
      });

      test('joining is refused with an explanation', () async {
        expect(
          await bob.joinLeaflet(trip.key, 'hokkaido-2026', nickname: 'ボブ'),
          ja.sessionLostTitle,
        );
        expect(bob.sessionLost, isTrue);
      });

      test('checking the account on resume reports it', () async {
        expect(await alice.checkAccount(), isFalse);
        expect(alice.sessionLost, isTrue);
        expect(alice.myUid, isNull);
      });

      test('ordinary edits are not delayed by a check', () async {
        await alice.updateLeafletTitle(trip.key, '道東');
        await settle();
        expect(titles(alice), ['道東']);
        expect(alice.sessionLost, isFalse);
      });
    });

    test('an offline account check still creates the trip', () async {
      db.accountCheckError = Exception('network-request-failed');

      await alice.addLeaflet('次の旅');
      await settle();

      expect(alice.sessionLost, isFalse);
      expect(titles(alice), containsAll(['北海道', '次の旅']));
    });

    testWidgets('a stalled account check creates the trip after 5 seconds', (
      tester,
    ) async {
      final pending = Completer<void>();
      db.accountCheckWait = pending.future;

      final adding = alice.addLeaflet('次の旅');
      await tester.pump(const Duration(seconds: 5));
      await adding;
      await tester.pump();

      expect(alice.sessionLost, isFalse);
      expect(titles(alice), containsAll(['北海道', '次の旅']));
      pending.complete();
    });

    test('a sign-out during a failed deletion is reported', () async {
      db.accountCheckError = Exception('network-request-failed');
      final deleting = alice.deleteAccount();
      db.expireSession('alice');
      expect(await deleting, isFalse);
      await settle();
      await settle();
      expect(alice.sessionLost, isTrue);
    });
  });

  group('deleting the account', () {
    test(
      'an account removed during deletion signs out with a warning',
      () async {
        db.accountDeleteError = FirebaseAuthException(code: 'user-not-found');
        expect(await alice.deleteAccount(), isTrue);
        expect(alice.accountUnavailable, isTrue);
        expect(db.signedOutAccounts, ['alice']);
        expect(alice.myUid, isNull);
        expect(db.deletedAccounts, isEmpty);
      },
    );

    test(
      'an unavailable account signs out without deleting server data',
      () async {
        await alice.enableSharing(trip, 'hokkaido-2026', nickname: 'アキ');
        db.accountExists = false;

        expect(await alice.deleteAccount(), isTrue);
        expect(alice.accountUnavailable, isTrue);
        expect(db.signedOutAccounts, ['alice']);
        expect(db.deletedAccounts, isEmpty);
        expect(await alice.savedPassphrase(trip), isNull);
        expect(db.widget.clearedAll, 1);
        expect(
          await db.servicesFor('alice').leaflets.watchLeaflets().first,
          contains(predicate<LeafletEntity>((value) => value.key == trip.key)),
        );
        // 自分の操作によるサインアウトは、失効として扱わない。
        await settle();
        expect(alice.sessionLost, isFalse);
      },
    );

    test(
      'a failed account check preserves data and does not sign out',
      () async {
        db.accountCheckError = Exception('network-request-failed');
        String? message;
        alice.onWriteError = (value) => message = value;

        expect(await alice.deleteAccount(), isFalse);
        expect(alice.accountUnavailable, isFalse);
        expect(db.signedOutAccounts, isEmpty);
        expect(db.deletedAccounts, isEmpty);
        expect(titles(alice), ['北海道']);
        expect(message, isNotNull);
      },
    );

    test(
      'deletes owned trips, leaves joined ones and removes the account',
      () async {
        await alice.enableSharing(trip, 'hokkaido-2026', nickname: 'アキ');
        await bob.joinLeaflet(trip.key, 'hokkaido-2026', nickname: 'ボブ');
        await bob.addLeaflet('ボブの旅');
        await settle();
        final bobsOwn = bob
            .getLeafletsBy(bob.getLeafletsGroupNames().single)
            .firstWhere((l) => l.title == 'ボブの旅');
        expect(db.deviceTokens['bob'], isNotEmpty);

        final deleted = await bob.deleteAccount();
        await settle();

        expect(deleted, isTrue);
        expect(db.deletedAccounts, ['bob']);
        // 自分のしおりは消え、参加していたしおりは、オーナーの側に残る。
        expect(titles(alice), ['北海道']);
        expect(titles(bob), isEmpty);
        expect(
          await db.servicesFor('carol').leaflets.watchLeaflets().first,
          isEmpty,
        );
        expect(db.widget.cleared, containsAll([trip.key, bobsOwn.key]));
        // 通知の登録は、サーバーと FCM の両方から外れる。
        expect(db.deviceTokens['bob'], isNull);
        expect(db.pushFor('bob').tokenDeletions, 1);
      },
    );

    test(
      'an owner who deletes the account removes the trip for everyone',
      () async {
        await alice.enableSharing(trip, 'hokkaido-2026', nickname: 'アキ');
        await bob.joinLeaflet(trip.key, 'hokkaido-2026', nickname: 'ボブ');
        await settle();

        expect(await alice.deleteAccount(), isTrue);
        await settle();

        expect(db.deletedAccounts, ['alice']);
        expect(titles(bob), isEmpty);
        expect(await alice.savedPassphrase(trip), isNull);
      },
    );

    test('a failure keeps the account so it can be tried again', () async {
      await alice.enableSharing(trip, 'hokkaido-2026', nickname: 'アキ');
      await settle();
      db.accountDeleteError = Exception('requires-recent-login');
      String? message;
      alice.onWriteError = (m) => message = m;

      expect(await alice.deleteAccount(), isFalse);
      expect(db.deletedAccounts, isEmpty);
      expect(message, isNotNull);

      // 失敗したあとも、一覧の購読は続く（アカウントが残っているため）。
      await alice.addLeaflet('次の旅');
      await settle();
      expect(titles(alice), contains('次の旅'));

      // 原因が直ったら、同じ操作で、最後まで進む（データは、もう消えている）。
      db.accountDeleteError = null;
      expect(await alice.deleteAccount(), isTrue);
      expect(db.deletedAccounts, ['alice']);
    });

    test(
      'a rejected token removal does not stop the account deletion',
      () async {
        final base = db.servicesFor('dan');
        final failing = AppServices(
          auth: base.auth,
          leaflets: base.leaflets,
          marks: base.marks,
          notes: base.notes,
          presence: base.presence,
          passphrases: base.passphrases,
          widget: base.widget,
          deviceName: base.deviceName,
          push: base.push,
          deviceTokens: _FailingTokens(),
        );
        final dan = LeafletsModel(failing)..fetchLeafletsEntity();
        addTearDown(dan.dispose);
        var failed = false;
        dan.onWriteError = (_) => failed = true;

        // 通知の登録を消せなくても（ルールが古いなど）、アカウントは削除する。登録は、掃除が消す。
        expect(await dan.deleteAccount(), isTrue);

        expect(failed, isFalse);
        expect(db.deletedAccounts, ['dan']);
      },
    );
  });
}

class _FailingTokens implements FirebaseDeviceTokenRepository {
  @override
  Future<void> register(String token) async {}

  @override
  Future<void> removeAll() => Future.error(Exception('permission-denied'));
}
