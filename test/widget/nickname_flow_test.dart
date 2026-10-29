import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/data/app_services.dart';
import 'package:koala/entity/leaflet_entity.dart';
import 'package:koala/leaflets/leaflets_model.dart';
import 'package:koala/sharing/join_screen.dart';
import 'package:koala/sharing/share_code.dart';

import '../support/app_flows.dart';
import '../support/demo_database.dart';
import '../support/localized_app.dart';

const _title = '北海道';
const _passphrase = 'hokkaido-2026';

/// 読み取りの画面の代わり。カメラを使わず、すぐに読み取り結果を返す。
Widget _fakeScan(BuildContext context, JoinCredentials credentials) {
  return Builder(
    builder: (context) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.pop(context, credentials);
      });
      return const Scaffold(body: Text('scanning'));
    },
  );
}

Future<LeafletEntity> _ownedLeaflet(AppServices owner) async {
  await owner.leaflets.addLeaflet(_title, coverEmoji: '❄️');
  return (await owner.leaflets.watchLeaflets().first).single;
}

Finder _nicknameField() => find.widgetWithText(TextField, ja.nickname);

void main() {
  late DemoDatabase db;

  setUp(() => db = DemoDatabase());

  group('turning on shared editing', () {
    testWidgets('asks for the nickname and fills in the device model', (
      tester,
    ) async {
      final owner = db.servicesFor('alice');
      await _ownedLeaflet(owner);
      await openLeafletList(tester, owner);

      await openSharingSettings(tester, _title);

      final field = tester.widget<TextField>(_nicknameField());
      expect(field.controller?.text, 'Pixel 10a');
      expect(find.text(ja.nicknameHelper(20)), findsOneWidget);
    });

    testWidgets('prefers the nickname that is already saved', (tester) async {
      final owner = db.servicesFor('alice', name: 'さくら');
      await _ownedLeaflet(owner);
      await openLeafletList(tester, owner);

      await openSharingSettings(tester, _title);

      final field = tester.widget<TextField>(_nicknameField());
      expect(field.controller?.text, 'さくら');
    });

    testWidgets('cannot be turned on while the nickname is blank', (
      tester,
    ) async {
      final owner = db.servicesFor('alice');
      await _ownedLeaflet(owner);
      await openLeafletList(tester, owner);
      await openSharingSettings(tester, _title);

      await tester.enterText(_nicknameField(), '   ');
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('saves the typed nickname together with the passphrase', (
      tester,
    ) async {
      final owner = db.servicesFor('alice');
      await _ownedLeaflet(owner);
      await openLeafletList(tester, owner);
      await openSharingSettings(tester, _title);

      await tester.enterText(_nicknameField(), '  アキ  ');
      await tester.pump();
      await tester.ensureVisible(find.text(ja.enableSharing));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ja.enableSharing));
      await tester.pumpAndSettle();

      expect(owner.auth.currentUser?.name, 'アキ');
      final leaflet = (await owner.leaflets.watchLeaflets().first).single;
      expect(leaflet.shared, isTrue);
    });

    testWidgets('does not ask again when only the passphrase changes', (
      tester,
    ) async {
      final owner = db.servicesFor('alice', name: 'アキ');
      final leaflet = await _ownedLeaflet(owner);
      await owner.leaflets.enableSharing(leaflet, _passphrase);
      await owner.passphrases.write(leaflet.key, _passphrase);
      await openLeafletList(tester, owner);
      await openSharingSettings(tester, _title);

      await tester.ensureVisible(find.text(ja.changePassphrase));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ja.changePassphrase));
      await tester.pumpAndSettle();

      expect(_nicknameField(), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('joining', () {
    Future<(AppServices, JoinCredentials)> setUpJoin(
      WidgetTester tester, {
      String? name,
    }) async {
      final owner = db.servicesFor('alice');
      final leaflet = await _ownedLeaflet(owner);
      await owner.leaflets.enableSharing(leaflet, _passphrase);
      final friend = db.servicesFor('bob', name: name);
      final model = LeafletsModel(friend)..l10n = ja;
      addTearDown(model.dispose);
      final credentials = JoinCredentials(leaflet.key, _passphrase);
      await tester.pumpWidget(
        localizedApp(
          home: JoinScreen(
            model: model,
            scanBuilder: (context) => _fakeScan(context, credentials),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (friend, credentials);
    }

    testWidgets('a scanned QR code only fills in the id and the passphrase', (
      tester,
    ) async {
      final (friend, credentials) = await setUpJoin(tester);

      await tester.tap(find.text(ja.scanQr));
      await tester.pumpAndSettle();

      expect(find.text(ja.qrFilled), findsOneWidget);
      expect(find.text(credentials.passphrase), findsOneWidget);
      // まだ参加していない。
      expect(
        await db.servicesFor('bob').leaflets.watchLeaflets().first,
        isEmpty,
      );
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('joins only after the join button, saving the nickname', (
      tester,
    ) async {
      final (friend, _) = await setUpJoin(tester);
      await tester.tap(find.text(ja.scanQr));
      await tester.pumpAndSettle();

      await tester.enterText(_nicknameField(), 'ボブ');
      await tester.pump();
      await tester.ensureVisible(find.text(ja.join));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ja.join));
      await tester.pumpAndSettle();

      expect(friend.auth.currentUser?.name, 'ボブ');
      expect(await friend.leaflets.watchLeaflets().first, hasLength(1));
    });

    testWidgets('the device model is the default nickname', (tester) async {
      final (friend, _) = await setUpJoin(tester);
      await tester.tap(find.text(ja.scanQr));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text(ja.join));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ja.join));
      await tester.pumpAndSettle();

      expect(friend.auth.currentUser?.name, 'Pixel 10a');
    });

    testWidgets('cannot join while the nickname is blank', (tester) async {
      await setUpJoin(tester);
      await tester.tap(find.text(ja.scanQr));
      await tester.pumpAndSettle();

      await tester.enterText(_nicknameField(), '');
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });
  });
}
