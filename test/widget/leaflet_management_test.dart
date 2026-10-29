import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/components/readable_width.dart';
import 'package:koala/l10n/write_task.dart';
import 'package:koala/marks/marks_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../support/app_flows.dart';
import '../support/demo_data.dart';
import '../support/demo_database.dart';
import '../support/localized_app.dart';
import '../support/samples.dart';

void main() {
  late DemoDatabase db;

  setUp(() => db = DemoDatabase());

  testWidgets('creates a leaflet from the plus button', (tester) async {
    const title = '九州 3 泊 4 日';
    await openLeafletList(tester, db.services);

    await tester.tap(find.byTooltip(ja.newTrip));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), title);
    await tester.tap(find.text(ja.create));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(title), findsWidgets);
  });

  testWidgets('renames a leaflet', (tester) async {
    const renamed = '石垣島';
    await openLeafletList(tester, db.services);

    await openLeafletMenu(tester, demoTripTitle);
    await tester.tap(find.text(ja.changeTitle));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), renamed);
    await tester.tap(find.text(ja.ok));
    await tester.pumpAndSettle();

    expect(find.text(renamed), findsWidgets);
    expect(find.text(demoTripTitle), findsNothing);
  });

  testWidgets('changes the cover emoji and color', (tester) async {
    await openLeafletList(tester, db.services);

    await openLeafletMenu(tester, demoTripTitle);
    await tester.tap(find.text(ja.changeCover));
    await tester.pumpAndSettle();
    expect(find.text(ja.coverDialogTitle), findsOneWidget);
    await tester.enterText(find.byType(TextField), '🏝️');
    await tester.pump();
    await tester.tap(find.text(ja.ok));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final saved = (await db.services.leaflets.watchLeaflets().first).first;
    expect(saved.coverEmoji, '🏝️');
    expect(saved.coverColor, isNotNull);
  });

  testWidgets('title dialog preserves period and cover changes while open', (
    tester,
  ) async {
    final services = db.services;
    await openLeafletList(tester, services);
    final leaflet = (await services.leaflets.watchLeaflets().first).single;
    await openLeafletMenu(tester, demoTripTitle);
    await tester.tap(find.text(ja.changeTitle));
    await tester.pumpAndSettle();
    final first = DateTime(2030, 1, 1);
    final last = DateTime(2030, 1, 3);
    await services.leaflets.updateLeafletPeriod(
      leaflet.key,
      firstDate: first,
      lastDate: last,
      firstTimeZoneId: 'Asia/Tokyo',
      lastTimeZoneId: 'Europe/Paris',
    );
    await services.leaflets.updateLeafletCover(
      leaflet.key,
      imageUrl: '🌴',
      coverColor: 0xFF123456,
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Latest');
    await tester.tap(find.text(ja.ok));
    await tester.pumpAndSettle();

    final saved = await services.leaflets.watchLeaflet(leaflet.key).first;
    expect(saved!.title, 'Latest');
    expect(saved.firstDate, first);
    expect(saved.lastDate, last);
    expect(saved.lastTimeZoneId, 'Europe/Paris');
    expect(saved.imageUrl, '🌴');
    expect(saved.coverColor, 0xFF123456);
  });

  testWidgets('cover dialog preserves period and title changes while open', (
    tester,
  ) async {
    final services = db.services;
    await openLeafletList(tester, services);
    final leaflet = (await services.leaflets.watchLeaflets().first).single;
    await openLeafletMenu(tester, demoTripTitle);
    await tester.tap(find.text(ja.changeCover));
    await tester.pumpAndSettle();
    final first = DateTime(2030, 1, 1);
    final last = DateTime(2030, 1, 3);
    await services.leaflets.updateLeafletPeriod(
      leaflet.key,
      firstDate: first,
      lastDate: last,
      firstTimeZoneId: 'Asia/Tokyo',
      lastTimeZoneId: 'Europe/Paris',
    );
    await services.leaflets.updateLeafletTitle(leaflet.key, 'Latest');
    await tester.pump();
    await tester.enterText(find.byType(TextField), '🏝️');
    await tester.pump();
    await tester.tap(find.text(ja.ok));
    await tester.pumpAndSettle();

    final saved = await services.leaflets.watchLeaflet(leaflet.key).first;
    expect(saved!.title, 'Latest');
    expect(saved.firstDate, first);
    expect(saved.lastDate, last);
    expect(saved.lastTimeZoneId, 'Europe/Paris');
    expect(saved.coverEmoji, '🏝️');
  });

  testWidgets('trip title follows subscription and still opens the note', (
    tester,
  ) async {
    final services = db.services;
    await openLeafletList(tester, services);
    final leaflet = (await services.leaflets.watchLeaflets().first).single;
    await openLeaflet(tester, demoTripTitle);
    await services.leaflets.updateLeafletTitle(leaflet.key, 'Latest');
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Latest', findRichText: true),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip(ja.openNote));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Note')),
      findsOneWidget,
    );
    expect(find.byType(MarksScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deleting asks first, then removes the leaflet', (tester) async {
    await openLeafletList(tester, db.services);
    await openLeafletMenu(tester, demoTripTitle);

    await tester.tap(find.text(ja.deleteTrip));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ja.keep));
    await tester.pumpAndSettle();
    expect(find.text(demoTripTitle), findsWidgets);

    await tester.tap(find.text(ja.deleteTrip));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, ja.delete));
    await tester.pumpAndSettle();

    expect(find.text(demoTripTitle), findsNothing);
    expect(find.text(ja.addSamples), findsOneWidget);
  });

  testWidgets('a participant can leave but not delete', (tester) async {
    const title = '北海道';
    final alice = db.servicesFor('alice');
    final key = await alice.leaflets.addLeaflet(title, coverEmoji: '❄️');
    final created = (await alice.leaflets.watchLeaflets().first).single;
    await alice.leaflets.enableSharing(created, 'hokkaido-2026');
    final bob = db.servicesFor('bob');
    await bob.leaflets.joinLeaflet(key, 'hokkaido-2026');

    await openLeafletList(tester, bob);
    expect(find.byIcon(Icons.group), findsOneWidget);

    await openLeafletMenu(tester, title);
    expect(find.text(ja.deleteTrip), findsNothing);
    expect(find.text(ja.startSharedEditing), findsNothing);
    await tester.tap(find.text(ja.leaveTrip));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ja.leave));
    await tester.pumpAndSettle();

    expect(find.text(title), findsNothing);
    expect((await alice.leaflets.watchLeaflets().first).single.title, title);
  });

  testWidgets('saves the nickname from the menu', (tester) async {
    final me = db.servicesFor('me');
    await openLeafletList(tester, me);
    await openDrawer(tester);
    expect(find.text(ja.nicknameNotSet), findsOneWidget);

    await tester.tap(find.text(ja.nickname));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'さくら');
    await tester.pump();
    await tester.tap(find.text(ja.save));
    await tester.pumpAndSettle();

    expect(me.auth.currentUser?.name, 'さくら');
  });

  testWidgets('the nickname dialog does not accept a blank or long name', (
    tester,
  ) async {
    final me = db.servicesFor('me');
    await openLeafletList(tester, me);
    await openDrawer(tester);

    await tester.tap(find.text(ja.nickname));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();

    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, ja.save),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('deleting the account returns to the launch screen', (
    tester,
  ) async {
    await openLeafletList(tester, db.services);
    await openDrawer(tester);

    final item = find.text(ja.deleteAccountTitle);
    await tester.ensureVisible(item);
    await tester.pumpAndSettle();
    await tester.tap(item);
    await tester.pumpAndSettle();
    expect(find.text(ja.deleteAccountConfirmTitle), findsOneWidget);

    await tester.tap(find.text(ja.delete));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(db.deletedAccounts, [demoUserId]);
    expect(find.text(ja.start), findsOneWidget);
    expect(find.text(ja.deleteAccountDone), findsOneWidget);
    expect(find.text(demoTripTitle), findsNothing);
  });

  testWidgets('cancelling the confirmation deletes nothing', (tester) async {
    await openLeafletList(tester, db.services);
    await openDrawer(tester);

    final item = find.text(ja.deleteAccountTitle);
    await tester.ensureVisible(item);
    await tester.pumpAndSettle();
    await tester.tap(item);
    await tester.pumpAndSettle();
    await tester.tap(find.text(ja.cancel));
    await tester.pumpAndSettle();

    expect(db.deletedAccounts, isEmpty);
    expect(find.text(demoTripTitle), findsWidgets);
  });

  testWidgets('an already deleted account returns to launch with a warning', (
    tester,
  ) async {
    await openLeafletList(tester, db.services);
    // 起動時の確認のあとで、サーバーから消えたとする。
    db.accountExists = false;
    await openDrawer(tester);
    final item = find.text(ja.deleteAccountTitle);
    await tester.ensureVisible(item);
    await tester.pumpAndSettle();
    await tester.tap(item);
    await tester.pumpAndSettle();
    await tester.tap(find.text(ja.delete));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(db.signedOutAccounts, [demoUserId]);
    expect(db.deletedAccounts, isEmpty);
    expect(find.text(ja.start), findsOneWidget);
    expect(find.text(ja.deleteAccountUnavailable), findsOneWidget);
    expect(find.text(ja.deleteAccountDone), findsNothing);
    expect(find.text(ja.deleteAccountProgress), findsNothing);
  });

  testWidgets('a failed deletion is explained and stays on the list', (
    tester,
  ) async {
    db.accountDeleteError = Exception('requires-recent-login');
    await openLeafletList(tester, db.services);
    await openDrawer(tester);

    final item = find.text(ja.deleteAccountTitle);
    await tester.ensureVisible(item);
    await tester.pumpAndSettle();
    await tester.tap(item);
    await tester.pumpAndSettle();
    await tester.tap(find.text(ja.delete));
    await tester.pumpAndSettle();

    expect(db.deletedAccounts, isEmpty);
    expect(find.text(ja.writeFailed(WriteTask.deleteAccount)), findsOneWidget);
    expect(find.text(ja.start), findsNothing);
  });

  group('a session lost while in use', () {
    Future<void> confirmAndReturn(WidgetTester tester) async {
      expect(tester.takeException(), isNull);
      expect(find.text(ja.sessionLostTitle), findsOneWidget);
      expect(find.text(ja.sessionLostBody), findsOneWidget);
      // 戻るでは閉じず、OK でだけ進む。
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(ja.sessionLostTitle), findsOneWidget);

      await tester.tap(find.text(ja.ok));
      await tester.pumpAndSettle();

      expect(find.text(ja.sessionLostTitle), findsNothing);
      expect(find.text(ja.start), findsOneWidget);
      expect(find.text(demoTripTitle), findsNothing);
      expect(db.deletedAccounts, isEmpty);
    }

    testWidgets('on the list is explained and returns to launch', (
      tester,
    ) async {
      await openLeafletList(tester, db.services);

      db.expireSession();
      await tester.pumpAndSettle();

      await confirmAndReturn(tester);
    });

    testWidgets('on a trip is explained and closes every screen', (
      tester,
    ) async {
      await openLeafletList(tester, db.services);
      await openLeaflet(tester, demoTripTitle);

      db.expireSession();
      await tester.pumpAndSettle();

      expect(find.text(ja.tripNoLongerAvailable), findsNothing);
      await confirmAndReturn(tester);
      expect(find.byType(MarksScreen), findsNothing);
    });

    testWidgets('creating a trip afterwards is not silently ignored', (
      tester,
    ) async {
      await openLeafletList(tester, db.services);
      await tester.tap(find.byTooltip(ja.newTrip));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '九州');

      db.expireSession();
      await tester.tap(find.text(ja.create));
      await tester.pumpAndSettle();

      await confirmAndReturn(tester);
    });

    // コンソールで削除しても、トークンが有効な間は、端末はサインアウトされない。
    testWidgets('a deletion is noticed before creating a trip', (tester) async {
      const title = '九州';
      await openLeafletList(tester, db.services);
      db.accountExists = false;

      await tester.tap(find.byTooltip(ja.newTrip));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), title);
      await tester.tap(find.text(ja.create));
      await tester.pumpAndSettle();

      expect(find.text(title), findsNothing);
      await confirmAndReturn(tester);
      expect(db.signedOutAccounts, [demoUserId]);
    });

    testWidgets('a deletion is noticed when the app comes back', (
      tester,
    ) async {
      await openLeafletList(tester, db.services);
      db.accountExists = false;

      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();

      await confirmAndReturn(tester);
    });

    testWidgets('coming back with a valid account keeps the list', (
      tester,
    ) async {
      await openLeafletList(tester, db.services);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text(ja.sessionLostTitle), findsNothing);
      expect(find.text(demoTripTitle), findsWidgets);
    });
  });

  testWidgets('a stalled account check closes progress after 15 seconds', (
    tester,
  ) async {
    final pending = Completer<void>();
    await openLeafletList(tester, db.services);
    db.accountCheckWait = pending.future;
    await openDrawer(tester);
    final item = find.text(ja.deleteAccountTitle);
    await tester.ensureVisible(item);
    await tester.pumpAndSettle();
    await tester.tap(item);
    await tester.pumpAndSettle();
    await tester.tap(find.text(ja.delete));
    await tester.pump();
    expect(find.text(ja.deleteAccountProgress), findsOneWidget);

    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    expect(find.text(ja.deleteAccountProgress), findsNothing);
    expect(find.text(ja.writeFailed(WriteTask.deleteAccount)), findsOneWidget);
    expect(find.text(ja.start), findsNothing);
    expect(db.signedOutAccounts, isEmpty);
    expect(db.deletedAccounts, isEmpty);

    pending.complete();
    await tester.pumpAndSettle();
    expect(db.deletedAccounts, isEmpty);
    expect(find.text(demoTripTitle), findsWidgets);
  });

  testWidgets('shows the version and the portfolio notice in About', (
    tester,
  ) async {
    PackageInfo.setMockInitialValues(
      appName: '旅のしおり',
      packageName: 'io.akmoor25.koala_portfolio',
      version: '1.2.3',
      buildNumber: '45',
      buildSignature: '',
    );
    await openLeafletList(tester, db.services);
    await openDrawer(tester);

    await tester.tap(find.text(ja.aboutApp));
    await tester.pumpAndSettle();

    expect(find.text('1.2.3(45)'), findsOneWidget);
    expect(find.text(ja.portfolioNoticeTitle), findsOneWidget);
  });

  testWidgets('keeps the About dialog narrow on a wide tablet', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: '旅のしおり',
      packageName: 'io.akmoor25.koala_portfolio',
      version: '1.2.3',
      buildNumber: '45',
      buildSignature: '',
    );
    useScreen(tester, const Size(1024, 768));
    await openLeafletList(tester, db.services, brightness: Brightness.light);
    await openDrawer(tester);

    await tester.tap(find.text(ja.aboutApp));
    await tester.pumpAndSettle();

    // AlertDialog 自体は画面いっぱいの領域を持つ。見えている面（Material）の幅を測る。
    final surface = inDialog(find.byType(Material));
    expect(
      tester.getSize(surface.first).width,
      lessThanOrEqualTo(AppWidth.form),
    );
  });

  testWidgets('adds the samples from the menu', (tester) async {
    await openLeafletList(tester, db.servicesFor('newcomer'));
    await openDrawer(tester);

    await tester.tap(find.widgetWithText(ListTile, ja.addSamples));
    await tester.pumpAndSettle();

    expect(find.text(sampleTitle(SampleTrip.hokkaido)), findsWidgets);
    expect(find.text(ja.samplesAdded(samplesIn().length)), findsOneWidget);
  });

  testWidgets('blocks interaction and shows progress while adding samples', (
    tester,
  ) async {
    final slowDb = DemoDatabase(writeDelay: const Duration(milliseconds: 5));
    final blockingBarrier = find.byWidgetPredicate(
      (widget) => widget is ModalBarrier && widget.color == Colors.black54,
    );
    await openLeafletList(tester, slowDb.servicesFor('newcomer'));

    await tester.tap(find.text(ja.addSamples));
    await tester.pump();

    expect(blockingBarrier, findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text(ja.taskAddSamples), findsOneWidget);
    expect(find.textContaining(' / '), findsOneWidget);

    await tester.tap(find.byTooltip(ja.joinTrip), warnIfMissed: false);
    await tester.pump();
    expect(find.text(ja.joinIntro), findsNothing);

    await tester.pumpAndSettle();
    expect(blockingBarrier, findsNothing);
    expect(find.text(ja.samplesAdded(samplesIn().length)), findsOneWidget);
  });
}
