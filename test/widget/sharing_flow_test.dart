import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/data/app_services.dart';
import 'package:koala/data/data_types.dart';
import 'package:koala/entity/leaflet_entity.dart';
import 'package:koala/sharing/share_code.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../support/app_flows.dart';
import '../support/demo_database.dart';
import '../support/localized_app.dart';

const _title = '北海道';
const _passphrase = 'hokkaido-2026';

/// [owner] が共同編集のしおりを作り、そのしおりを返す。
Future<LeafletEntity> _sharedLeaflet(AppServices owner) async {
  await owner.leaflets.addLeaflet(_title, coverEmoji: '❄️');
  final leaflet = (await owner.leaflets.watchLeaflets().first).single;
  await owner.leaflets.enableSharing(leaflet, _passphrase);
  return leaflet;
}

Future<void> _enterId(WidgetTester tester, String id) async {
  await tester.enterText(find.byType(TextField).at(0), id.substring(0, 4));
  await tester.enterText(find.byType(TextField).at(1), id.substring(4, 8));
  await tester.enterText(find.byType(TextField).at(2), id.substring(8, 12));
}

Future<void> _openJoin(WidgetTester tester, AppServices services) async {
  await openLeafletList(tester, services);
  await openJoinScreen(tester);
}

Future<void> _tapJoin(WidgetTester tester) =>
    tapVisible(tester, find.text(ja.join));

void main() {
  late DemoDatabase db;

  setUp(() => db = DemoDatabase());

  group('joining', () {
    testWidgets('joins with the id typed into three boxes', (tester) async {
      final leaflet = await _sharedLeaflet(db.servicesFor('alice'));
      await _openJoin(tester, db.servicesFor('bob'));

      await _enterId(tester, leaflet.key);
      await tester.enterText(find.byType(TextField).at(3), _passphrase);
      await _tapJoin(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(_title), findsWidgets);
      expect(find.text(ja.joinedTrip), findsOneWidget);
    });

    testWidgets('a pasted id fills the boxes', (tester) async {
      final leaflet = await _sharedLeaflet(db.servicesFor('alice'));
      await _openJoin(tester, db.servicesFor('bob'));

      await tester.enterText(
        find.byType(TextField).at(0),
        '${leaflet.key.substring(0, 4)}-${leaflet.key.substring(4, 8)}-'
        '${leaflet.key.substring(8)}',
      );
      await tester.enterText(find.byType(TextField).at(3), _passphrase);
      await _tapJoin(tester);

      expect(find.text(_title), findsWidgets);
    });

    testWidgets('a wrong passphrase is explained and the form stays', (
      tester,
    ) async {
      final leaflet = await _sharedLeaflet(db.servicesFor('alice'));
      await _openJoin(tester, db.servicesFor('bob'));

      await _enterId(tester, leaflet.key);
      await tester.enterText(find.byType(TextField).at(3), 'wrong-passphrase');
      await _tapJoin(tester);

      expect(find.text(ja.joinRejected), findsOneWidget);
      expect(find.text(ja.join), findsOneWidget);
    });

    testWidgets('an unusable character blocks the request', (tester) async {
      await _openJoin(tester, db.servicesFor('bob'));

      await tester.enterText(find.byType(TextField).at(0), 'abcd');
      await tester.enterText(find.byType(TextField).at(3), _passphrase);
      await _tapJoin(tester);

      expect(find.text(ja.tripIdCheckInput), findsOneWidget);
      expect(find.text(ja.join), findsOneWidget);
    });

    testWidgets('joining twice is reported', (tester) async {
      final leaflet = await _sharedLeaflet(db.servicesFor('alice'));
      final bob = db.servicesFor('bob');
      await bob.leaflets.joinLeaflet(leaflet.key, _passphrase);
      await _openJoin(tester, bob);

      await _enterId(tester, leaflet.key);
      await tester.enterText(find.byType(TextField).at(3), _passphrase);
      await _tapJoin(tester);

      expect(find.text(ja.joinAlready), findsOneWidget);
    });
  });

  group('sharing settings', () {
    Future<void> scrollTo(WidgetTester tester, Finder target) async {
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
    }

    testWidgets('enabling shows the id, the passphrase and a QR code', (
      tester,
    ) async {
      final owner = db.servicesFor('alice');
      await owner.leaflets.addLeaflet(_title, coverEmoji: '❄️');
      await openLeafletList(tester, owner);

      await openSharingSettings(tester, _title);
      await tester.enterText(find.byType(TextField).first, _passphrase);
      await enableSharing(tester);

      expect(find.text(_passphrase), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      final leaflet = (await owner.leaflets.watchLeaflets().first).single;
      expect(leaflet.shared, isTrue);
      expect(await owner.passphrases.read(leaflet.key), _passphrase);
    });

    testWidgets('a too-short passphrase cannot be set', (tester) async {
      final owner = db.servicesFor('alice');
      await owner.leaflets.addLeaflet(_title, coverEmoji: '❄️');
      await openLeafletList(tester, owner);

      await openSharingSettings(tester, _title);
      await tester.enterText(find.byType(TextField).first, 'short');
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      expect(
        find.text(ja.passphraseTooShort(passphraseMinLength)),
        findsOneWidget,
      );
    });

    testWidgets('changing the passphrase keeps sharing on', (tester) async {
      final owner = db.servicesFor('alice');
      final leaflet = await _sharedLeaflet(owner);
      await owner.passphrases.write(leaflet.key, _passphrase);
      await openLeafletList(tester, owner);

      await openSharingSettings(tester, _title);
      await scrollTo(
        tester,
        find.widgetWithText(OutlinedButton, ja.changePassphrase),
      );
      await tester.tap(
        find.widgetWithText(OutlinedButton, ja.changePassphrase),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'brand-new-word');
      await tester.tap(find.widgetWithText(FilledButton, ja.changePassphrase));
      await tester.pumpAndSettle();

      expect(find.text('brand-new-word'), findsOneWidget);
      expect(await owner.passphrases.read(leaflet.key), 'brand-new-word');
      final friend = db.servicesFor('carol');
      await expectLater(
        friend.leaflets.joinLeaflet(leaflet.key, _passphrase),
        throwsA(isA<JoinFailure>()),
      );
      await friend.leaflets.joinLeaflet(leaflet.key, 'brand-new-word');
    });

    testWidgets('stopping asks first and turns sharing off', (tester) async {
      final owner = db.servicesFor('alice');
      final leaflet = await _sharedLeaflet(owner);
      await owner.passphrases.write(leaflet.key, _passphrase);
      await openLeafletList(tester, owner);

      await openSharingSettings(tester, _title);
      await scrollTo(tester, find.widgetWithText(FilledButton, ja.stopSharing));
      await tester.tap(find.widgetWithText(FilledButton, ja.stopSharing));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ja.cancel));
      await tester.pumpAndSettle();
      expect(
        (await owner.leaflets.watchLeaflets().first).single.shared,
        isTrue,
      );

      await tester.tap(find.widgetWithText(FilledButton, ja.stopSharing));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ja.stop));
      await tester.pumpAndSettle();

      expect(find.text(ja.enableSharing), findsOneWidget);
      expect(
        (await owner.leaflets.watchLeaflets().first).single.shared,
        isFalse,
      );
      expect(await owner.passphrases.read(leaflet.key), isNull);
    });

    testWidgets('a participant inside the trip is sent back to the list', (
      tester,
    ) async {
      final owner = db.servicesFor('alice');
      final leaflet = await _sharedLeaflet(owner);
      final bob = db.servicesFor('bob');
      await bob.leaflets.joinLeaflet(leaflet.key, _passphrase);
      await openLeafletList(tester, bob);
      await openLeaflet(tester, _title);
      expect(find.byType(FloatingActionButton), findsOneWidget);

      await owner.leaflets.disableSharing(leaflet);
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.text(ja.tripNoLongerAvailable), findsOneWidget);
      expect(find.text(_title), findsNothing);
    });

    testWidgets('explains when the passphrase is not on this device', (
      tester,
    ) async {
      final owner = db.servicesFor('alice');
      await _sharedLeaflet(owner);
      await openLeafletList(tester, owner);

      await openSharingSettings(tester, _title);

      expect(find.text(ja.passphraseNotSaved), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
    });
  });
}
