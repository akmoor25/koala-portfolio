import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/data/app_services.dart';
import 'package:koala/data/app_session.dart';
import 'package:koala/launch/launch_screen.dart';
import 'package:provider/provider.dart';

import '../support/app_flows.dart';
import '../support/demo_data.dart';
import '../support/demo_database.dart';
import '../support/localized_app.dart';
import '../support/samples.dart';

Widget _app({Future<AppServices> Function()? connect}) {
  return ChangeNotifierProvider<AppSession>(
    create: (_) => AppSession(),
    child: localizedApp(
      home: LaunchScreen(
        connect: connect ?? () async => DemoDatabase().services,
      ),
    ),
  );
}

Future<void> _start(WidgetTester tester) =>
    tapVisible(tester, find.text(ja.start));

void main() {
  testWidgets('the start button opens the leaflet list', (tester) async {
    await tester.pumpWidget(_app());
    expect(find.text(ja.start), findsOneWidget);

    await _start(tester);

    expect(tester.takeException(), isNull);
    expect(find.text(demoTripTitle), findsWidgets);
  });

  testWidgets('the app icon keeps its size so the rounded corners show', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    expect(tester.getSize(find.byType(ClipRRect).first), const Size(96, 96));
  });

  testWidgets('the launch screen explains the app is portfolio-only', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    expect(find.text(ja.portfolioNoticeTitle), findsOneWidget);
  });

  testWidgets('a failed connection is explained and can be retried', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      _app(
        connect: () async {
          attempts++;
          if (attempts == 1) throw Exception('offline');
          return DemoDatabase().services;
        },
      ),
    );

    await _start(tester);
    expect(find.textContaining(ja.connectFailed), findsOneWidget);
    expect(find.text(ja.start), findsOneWidget);

    await _start(tester);
    expect(find.text(demoTripTitle), findsWidgets);
  });

  testWidgets('a deleted saved account is explained and can start anew', (
    tester,
  ) async {
    final db = DemoDatabase()..accountExists = false;
    final services = db.services;
    await tester.pumpWidget(
      _app(
        connect: () async {
          // 本番の connectToFirebase と同じく、サインインしてから返す。
          await services.auth.signInAnonymously();
          return services;
        },
      ),
    );

    await _start(tester);

    expect(tester.takeException(), isNull);
    expect(find.text(ja.sessionLostTitle), findsOneWidget);
    expect(find.text(ja.sessionLostOnLaunchBody), findsOneWidget);
    expect(db.signedOutAccounts, [demoUserId]);
    await tester.tap(find.text(ja.ok));
    await tester.pumpAndSettle();
    expect(find.text(ja.sessionLostTitle), findsNothing);
    expect(find.text(ja.start), findsOneWidget);
    expect(find.text(demoTripTitle), findsNothing);

    await _start(tester);
    expect(find.text(ja.sessionLostTitle), findsNothing);
    expect(find.text(demoTripTitle), findsWidgets);
  });

  testWidgets('opening a leaflet shows its timeline', (tester) async {
    await tester.pumpWidget(_app());
    await _start(tester);

    await openLeaflet(tester, demoTripTitle);

    expect(tester.takeException(), isNull);
    expect(find.text(demoNowStepTitle), findsOneWidget);
  });

  testWidgets('the owner can open the sharing settings of a leaflet', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await _start(tester);

    await openLeafletMenu(tester, demoTripTitle);
    expect(find.text(ja.leaveTrip), findsNothing);
    await tapVisible(tester, find.text(ja.startSharedEditing));

    expect(find.text(ja.enableSharing), findsOneWidget);
  });

  testWidgets('enabling sharing shows the id, passphrase and QR code', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await _start(tester);
    await openSharingSettings(tester, demoTripTitle);

    await enableSharing(tester);

    expect(tester.takeException(), isNull);
    expect(find.text(ja.tripId), findsOneWidget);
    expect(find.text(ja.passphrase), findsOneWidget);
    await tester.dragUntilVisible(
      find.text(ja.stopSharing),
      find.byType(ListView),
      const Offset(0, -200),
    );
    expect(find.text(ja.stopSharing), findsOneWidget);
  });

  testWidgets('a new user can add the samples from the empty list', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(connect: () async => DemoDatabase().servicesFor('newcomer')),
    );
    await _start(tester);
    expect(find.text(ja.addSamples), findsOneWidget);

    await addSamplesFromEmptyList(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Next'), findsOneWidget);
    // 一覧は Next、Now、過去の年の順。下の区分は、スクロールして確かめる。
    for (final trip in [
      SampleTrip.okinawa,
      SampleTrip.hokkaido,
      SampleTrip.sydney,
      SampleTrip.americas,
      SampleTrip.kyoto,
    ]) {
      await scrollUntilVisible(tester, find.text(sampleTitle(trip)));
      expect(find.text(sampleTitle(trip)), findsWidgets);
    }
  });

  testWidgets('the join screen shows an explanation on a wrong input', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await _start(tester);

    await openJoinScreen(tester);
    await tester.enterText(find.byType(TextField).first, 'ABC');
    await tester.enterText(find.byType(TextField).at(3), 'short');
    await tester.ensureVisible(find.text(ja.join));
    await tester.pumpAndSettle();

    // 入力がそろうまで、「参加する」は押せない。
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });
}
