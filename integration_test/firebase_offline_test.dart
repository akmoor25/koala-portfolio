import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:koala/data/app_services.dart';
import 'package:koala/data/firebase/firebase_local_writes.dart';
import 'package:koala/data/firebase/firebase_services.dart';
import 'package:koala/data/sample_leaflets.dart';
import 'package:koala/helper/time_zones.dart';
import 'package:koala/marks/marks_screen.dart';
import 'package:koala/notes/note_document.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../test/support/app_flows.dart';
import '../test/support/demo_database.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native SDK opens every sample without ever connecting', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await initTimeZones();
    final app = await Firebase.initializeApp(
      name: 'offline-regression',
      options: const FirebaseOptions(
        apiKey: 'offline-regression-key',
        appId: '1:123456789:android:offline',
        messagingSenderId: '123456789',
        projectId: 'demo-koala-offline',
        databaseURL: 'http://127.0.0.1:1?ns=demo-koala-offline',
      ),
    );
    final database = FirebaseDatabase.instanceFor(app: app);
    // 本番には接続しない。エミュレーターも不要で、接続を一度も開始しない。
    await database.goOffline().timeout(const Duration(seconds: 10));
    debugPrint('native offline: database disconnected');
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await app.delete();
    });
    final root = database.ref();
    final writes = FirebaseLocalWrites();
    final base = DemoDatabase().services;
    final leaflets = FirebaseLeafletRepository(root, base.auth, writes: writes);
    final marks = FirebaseMarkRepository(root, writes: writes);
    final notes = FirebaseNoteRepository(root, writes: writes);
    final services = AppServices(
      auth: base.auth,
      leaflets: leaflets,
      marks: marks,
      notes: notes,
      presence: base.presence,
      passphrases: base.passphrases,
      widget: base.widget,
      deviceName: base.deviceName,
      push: base.push,
      deviceTokens: base.deviceTokens,
    );

    Future<void> verifyDatabase() async {
      // 以前の保存単位では、子の値だけがあり親の onValue は届かないことを固定する。
      final child = root.child('incomplete/one');
      await writes
          .set(child, {'title': 'cached child'})
          .timeout(const Duration(seconds: 5));
      debugPrint('native offline: individual child saved');
      await expectLater(
        root
            .child('incomplete')
            .onValue
            .first
            .timeout(const Duration(milliseconds: 500)),
        throwsA(isA<TimeoutException>()),
      );
      debugPrint('native offline: incomplete parent reproduced');

      // サンプル追加前に取得済みの、空のしおり索引を再現する。
      await writes
          .set(root.child('userLeaflets/${base.auth.currentUser!.uid}'), {})
          .timeout(const Duration(seconds: 5));
      final now = DateTime.now();
      final samples = buildSampleLeaflets(now);
      final progress = <SampleInstallProgress>[];
      final count = await installSampleLeaflets(
        leaflets: leaflets,
        marks: marks,
        notes: notes,
        now: now,
        onProgress: progress.add,
      ).timeout(const Duration(seconds: 30));
      expect(count, samples.length);
      expect(progress.last.fraction, 1);
      debugPrint('native offline: samples installed');
      final installed = await leaflets.watchLeaflets().first.timeout(
        const Duration(seconds: 5),
      );
      expect(installed, hasLength(samples.length));
      for (var i = 0; i < samples.length; i++) {
        final leaflet = installed.singleWhere(
          (leaflet) => leaflet.title == samples[i].title,
        );
        expect(
          await marks
              .watchMarks(leaflet.key)
              .first
              .timeout(const Duration(seconds: 5)),
          hasLength(samples[i].marks.length),
        );
        expect(
          NoteDocument.parse(
            await notes
                .watchNote(leaflet.key)
                .first
                .timeout(const Duration(seconds: 5)),
          ).visibleLines,
          isNotEmpty,
        );
      }
    }

    await verifyDatabase();
    await openLeafletList(tester, services);
    await openLeaflet(tester, '沖縄２泊３日');
    expect(find.byType(MarksScreen), findsOneWidget);
    expect(
      tester
          .widget<ScrollablePositionedList>(
            find.byType(ScrollablePositionedList),
          )
          .itemCount,
      greaterThan(14),
    );
    expect(tester.takeException(), isNull);
  });
}
