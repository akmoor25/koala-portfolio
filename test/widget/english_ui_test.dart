import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/data/app_services.dart';
import 'package:koala/helper/time_zones.dart';

import '../support/app_flows.dart';
import '../support/demo_data.dart';
import '../support/demo_database.dart';
import '../support/localized_app.dart';
import '../support/samples.dart';

const _english = Locale('en', 'US');

Future<void> _start(WidgetTester tester, AppServices services) async {
  useScreen(tester, const Size(390, 844), textScale: 1);
  await openLeafletList(tester, services, locale: _english);
}

Future<void> _addSamples(WidgetTester tester) =>
    addSamplesFromEmptyList(tester, locale: _english);

void main() {
  testWidgets('the launch screen is in English with the portfolio notice', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(DemoDatabase().services, locale: _english),
    );

    expect(find.text(en.appName), findsWidgets);
    expect(find.text(en.start), findsOneWidget);
    expect(find.text(en.portfolioNoticeTitle), findsOneWidget);
    expect(find.text(ja.start), findsNothing);
  });

  testWidgets('a failed connection is explained in English', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        locale: _english,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );
    expect(en.connectFailed, contains('connect'));
  });

  testWidgets('English samples are added from the empty list', (tester) async {
    await _start(tester, DemoDatabase().servicesFor('newcomer'));

    expect(find.text(en.emptyTrips), findsOneWidget);
    await _addSamples(tester);

    expect(find.text(en.samplesAdded(samplesIn('en').length)), findsOneWidget);
    expect(find.text(sampleTitle(SampleTrip.hokkaido, 'en')), findsWidgets);
    expect(find.text(sampleTitle(SampleTrip.hokkaido)), findsNothing);
    // 過去の旅は、一覧の下のほうにある。
    await scrollUntilVisible(
      tester,
      find.text(sampleTitle(SampleTrip.asia, 'en')),
    );
    expect(find.text(sampleTitle(SampleTrip.asia, 'en')), findsWidgets);
  });

  testWidgets('the menu is in English', (tester) async {
    await _start(tester, DemoDatabase().servicesFor('newcomer'));

    await openDrawer(tester);

    expect(find.text(en.joinTrip), findsWidgets);
    expect(find.text(en.addSamples), findsWidgets);
    expect(find.text(en.samplesSubtitle), findsOneWidget);
    expect(find.text(en.nickname), findsOneWidget);
    expect(find.text(en.nicknameNotSet), findsOneWidget);
    expect(find.text(en.aboutApp), findsOneWidget);
  });

  testWidgets('the Asia trip shows English city names and times', (
    tester,
  ) async {
    await _start(tester, DemoDatabase().servicesFor('newcomer'));
    await _addSamples(tester);
    await openLeaflet(tester, sampleTitle(SampleTrip.asia, 'en'));

    final marks = sampleMarks(SampleTrip.asia, 'en');
    final flight = sampleArrivalIn(SampleTrip.asia, 'Asia/Seoul', 'en');
    final afterLanding = marks[marks.indexOf(flight) + 1];
    await tester.dragUntilVisible(
      find.text(flight.title).first,
      find.byType(Scrollable).first,
      const Offset(0, -300),
    );

    expect(find.text(flight.title), findsWidgets);
    expect(find.textContaining(afterLanding.title), findsWidgets);
    // 端末（東京）と違うタイムゾーンの旅程には、都市名を英語で出す。
    expect(find.text(cityNameOf('Asia/Seoul', 'en')), findsWidgets);
    expect(find.text(cityNameOf('Asia/Seoul', 'ja')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dates and times keep the same notation in both languages', (
    tester,
  ) async {
    Future<List<String>> texts(Locale locale) async {
      final services = DemoDatabase().services;
      await tester.pumpWidget(const SizedBox());
      await openLeafletList(tester, services, locale: locale);
      await openLeaflet(tester, demoTripTitle);
      return [
        for (final widget in tester.widgetList<Text>(find.byType(Text)))
          if (RegExp(r'^[～]?\d{1,2}[:/]\d{2}|^\d\d/\d\d')
              .hasMatch(widget.data ?? ''))
            widget.data!,
      ];
    }

    final inJapanese = await texts(testLocale);
    final inEnglish = await texts(_english);

    expect(inJapanese, isNotEmpty);
    expect(inEnglish, inJapanese);
    // 曜日は、言語に依らず、英語の 3 文字（Sun など）のまま。
    const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    expect(inEnglish.any((t) => weekdays.any(t.contains)), isTrue);
  });

  testWidgets('the dialogs are in English', (tester) async {
    final services = DemoDatabase().servicesFor('newcomer');
    await _start(tester, services);

    await tester.tap(find.byTooltip(en.newTrip));
    await tester.pumpAndSettle();
    expect(find.text(en.newTripDialogTitle), findsOneWidget);
    expect(find.text(en.titleLabel), findsOneWidget);
    expect(find.text(en.create), findsOneWidget);
  });

  testWidgets('the join screen is in English and explains a wrong input', (
    tester,
  ) async {
    await _start(tester, DemoDatabase().servicesFor('newcomer'));

    await openJoinScreen(tester, locale: _english);
    expect(find.text(en.joinIntro), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'ABC');
    await tester.enterText(find.byType(TextField).at(3), 'short');
    await tester.ensureVisible(find.text(en.join));
    await tester.pumpAndSettle();

    // The Join button stays off until the ID, the passphrase and the nickname are valid.
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(find.text(en.nickname), findsOneWidget);
  });
}
