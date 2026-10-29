import 'package:flutter_test/flutter_test.dart';
import 'package:koala/marks/marks_screen.dart';
import 'package:koala/notifications/push_message.dart';

import '../support/app_flows.dart';
import '../support/demo_database.dart';
import '../support/localized_app.dart';

const _title = '北海道';
const _actor = 'アキ';

PushMessage _message(
  NotificationKind kind,
  String leafletId, {
  String title = _title,
  String actor = _actor,
}) => PushMessage(kind: kind, leafletId: leafletId, title: title, actor: actor);

void main() {
  late DemoDatabase db;

  setUp(() => db = DemoDatabase());

  Future<String> addTrip(String uid) async {
    final services = db.servicesFor(uid);
    await services.leaflets.addLeaflet(_title, coverEmoji: '❄️');
    return (await services.leaflets.watchLeaflets().first).single.key;
  }

  testWidgets('a notification while the app is open is shown on the screen', (
    tester,
  ) async {
    final key = await addTrip('alice');
    await openLeafletList(tester, db.servicesFor('alice'));

    db.pushFor('alice').deliver(_message(NotificationKind.joined, key));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining(ja.notifJoinedTitle), findsOneWidget);
    expect(
      find.textContaining(ja.notifJoinedBody(_title, _actor)),
      findsOneWidget,
    );
  });

  testWidgets('a leave notification is shown and opens that trip', (
    tester,
  ) async {
    final key = await addTrip('alice');
    await openLeafletList(tester, db.servicesFor('alice'));

    db.pushFor('alice').deliver(_message(NotificationKind.left, key));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.textContaining(ja.notifLeftBody(_title, _actor)),
      findsOneWidget,
    );

    db.pushFor('alice').open(_message(NotificationKind.left, key));
    await tester.pumpAndSettle();
    expect(find.byType(MarksScreen), findsOneWidget);
  });

  testWidgets('tapping a join notification opens that trip', (tester) async {
    final key = await addTrip('alice');
    await openLeafletList(tester, db.servicesFor('alice'));
    expect(find.byType(MarksScreen), findsNothing);

    db.pushFor('alice').open(_message(NotificationKind.joined, key));
    await tester.pumpAndSettle();

    expect(find.byType(MarksScreen), findsOneWidget);
  });

  testWidgets('a join notification of a trip that is gone says so', (
    tester,
  ) async {
    await addTrip('alice');
    await openLeafletList(tester, db.servicesFor('alice'));

    db.pushFor('alice').open(_message(NotificationKind.joined, 'ZZZZZZZZZZZZ'));
    await tester.pumpAndSettle();

    expect(find.byType(MarksScreen), findsNothing);
    expect(find.text(ja.notifUnavailableTitle), findsOneWidget);
  });

  for (final kind in [NotificationKind.deleted, NotificationKind.stopped]) {
    testWidgets('tapping a ${kind.name} notification explains it', (
      tester,
    ) async {
      final key = await addTrip('alice');
      await openLeafletList(tester, db.servicesFor('alice'));

      db.pushFor('alice').open(_message(kind, key));
      await tester.pumpAndSettle();

      expect(find.byType(MarksScreen), findsNothing);
      expect(find.text(ja.notifUnavailableTitle), findsOneWidget);
    });
  }

  testWidgets('a notification that started the app is handled after loading', (
    tester,
  ) async {
    final key = await addTrip('alice');
    db.pushFor('alice').initial = _message(NotificationKind.joined, key);

    await openLeafletList(tester, db.servicesFor('alice'));
    await tester.pumpAndSettle();

    expect(find.byType(MarksScreen), findsOneWidget);
  });

  testWidgets('leaves an open trip when the notification says it is gone', (
    tester,
  ) async {
    final key = await addTrip('alice');
    await openLeafletList(tester, db.servicesFor('alice'));
    db.pushFor('alice').open(_message(NotificationKind.joined, key));
    await tester.pumpAndSettle();
    expect(find.byType(MarksScreen), findsOneWidget);

    db.pushFor('alice').open(_message(NotificationKind.deleted, key));
    await tester.pumpAndSettle();

    expect(find.byType(MarksScreen), findsNothing);
    expect(find.text(ja.notifUnavailableTitle), findsOneWidget);
  });
}
