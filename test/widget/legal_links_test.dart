import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/legal/legal_links.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../support/app_flows.dart';
import '../support/demo_database.dart';
import '../support/localized_app.dart';

class _FakeLauncher implements LegalLauncher {
  _FakeLauncher({this.succeeds = true});

  final bool succeeds;
  final opened = <Uri>[];

  @override
  Future<bool> open(Uri url) async {
    opened.add(url);
    return succeeds;
  }
}

void main() {
  group('legalUrl', () {
    test('Japanese opens the .ja.html documents', () {
      const locale = Locale('ja', 'JP');
      expect(
        legalUrl(LegalDocument.privacy, locale),
        '$legalBaseUrl/privacy.ja.html',
      );
      expect(
        legalUrl(LegalDocument.terms, locale),
        '$legalBaseUrl/terms.ja.html',
      );
    });

    test('any other language opens the .en.html documents', () {
      for (final locale in const [
        Locale('en', 'US'),
        Locale('fr'),
        Locale('zh', 'CN'),
      ]) {
        expect(
          legalUrl(LegalDocument.privacy, locale),
          '$legalBaseUrl/privacy.en.html',
          reason: '$locale',
        );
        expect(
          legalUrl(LegalDocument.terms, locale),
          '$legalBaseUrl/terms.en.html',
          reason: '$locale',
        );
      }
    });

    test('the URL is a single https constant without a trailing slash', () {
      expect(legalBaseUrl, startsWith('https://'));
      expect(legalBaseUrl, isNot(endsWith('/')));
    });
  });

  group('launch screen', () {
    testWidgets('has an agreement sentence and both links', (tester) async {
      await tester.pumpWidget(buildTestApp(DemoDatabase().services));

      expect(find.text(ja.launchAgreement), findsOneWidget);
      expect(find.text(ja.termsOfUse), findsOneWidget);
      expect(find.text(ja.privacyPolicy), findsOneWidget);
    });

    testWidgets('tapping a link opens that document in Japanese', (
      tester,
    ) async {
      final launcher = _FakeLauncher();
      await tester.pumpWidget(
        buildTestApp(DemoDatabase().services, legalLauncher: launcher),
      );

      await tester.tap(find.text(ja.privacyPolicy));
      await tester.pump();
      await tester.tap(find.text(ja.termsOfUse));
      await tester.pump();

      expect(launcher.opened.map((u) => u.toString()), [
        '$legalBaseUrl/privacy.ja.html',
        '$legalBaseUrl/terms.ja.html',
      ]);
    });

    testWidgets('English opens the English documents', (tester) async {
      final launcher = _FakeLauncher();
      await tester.pumpWidget(
        buildTestApp(
          DemoDatabase().services,
          locale: const Locale('en', 'US'),
          legalLauncher: launcher,
        ),
      );

      expect(find.text(en.launchAgreement), findsOneWidget);
      await tester.ensureVisible(find.text(en.privacyPolicy));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.privacyPolicy));
      await tester.pump();

      expect(
        launcher.opened.single.toString(),
        '$legalBaseUrl/privacy.en.html',
      );
    });

    testWidgets('a failure is explained and the URL can be copied', (
      tester,
    ) async {
      String? copied;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String?;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final launcher = _FakeLauncher(succeeds: false);
      await tester.pumpWidget(
        buildTestApp(DemoDatabase().services, legalLauncher: launcher),
      );

      await tester.tap(find.text(ja.termsOfUse));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(ja.legalOpenFailed), findsOneWidget);

      await tester.tap(find.text(ja.legalCopyUrl));
      await tester.pumpAndSettle();

      expect(copied, '$legalBaseUrl/terms.ja.html');
      expect(find.text(ja.legalUrlCopied), findsOneWidget);
    });
  });

  group('About dialog', () {
    setUp(() {
      PackageInfo.setMockInitialValues(
        appName: '旅のしおり',
        packageName: 'io.akmoor25.koala_portfolio',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
      );
    });

    testWidgets('has both links, and they open the documents', (tester) async {
      final launcher = _FakeLauncher();
      await openLeafletList(
        tester,
        DemoDatabase().services,
        legalLauncher: launcher,
      );
      await openDrawer(tester);
      await tester.tap(find.text(ja.aboutApp));
      await tester.pumpAndSettle();

      expect(find.text(ja.termsOfUse), findsOneWidget);
      expect(find.text(ja.privacyPolicy), findsOneWidget);

      await tester.tap(find.text(ja.privacyPolicy));
      await tester.pump();

      expect(
        launcher.opened.single.toString(),
        '$legalBaseUrl/privacy.ja.html',
      );
    });

    testWidgets('the English About dialog opens the English terms', (
      tester,
    ) async {
      final launcher = _FakeLauncher();
      await openLeafletList(
        tester,
        DemoDatabase().services,
        locale: const Locale('en', 'US'),
        legalLauncher: launcher,
      );
      await openDrawer(tester);
      await tester.tap(find.text(en.aboutApp));
      await tester.pumpAndSettle();

      await tester.tap(find.text(en.termsOfUse));
      await tester.pump();

      expect(launcher.opened.single.toString(), '$legalBaseUrl/terms.en.html');
    });
  });

  group('layout of the entry points', () {
    for (final scale in const [1.0, 2.0]) {
      for (final brightness in Brightness.values) {
        testWidgets('launch screen 文字 $scale 倍 ${brightness.name}', (
          tester,
        ) async {
          useScreen(tester, const Size(320, 568), textScale: scale);

          await tester.pumpWidget(
            Provider<LegalLauncher?>.value(
              value: _FakeLauncher(),
              child: buildTestApp(
                DemoDatabase().services,
                brightness: brightness,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text(ja.launchAgreement), findsOneWidget);
        });
      }
    }
  });
}
