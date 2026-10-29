import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_flows.dart';
import '../support/demo_data.dart';
import '../support/demo_database.dart';
import '../support/localized_app.dart';

const _rewritten = '書き換えた予定';

Future<void> _openFirstLeafletInEditMode(WidgetTester tester) async {
  await openLeafletList(tester, DemoDatabase().services);
  await openLeaflet(tester, demoTripTitle);
  await tester.tap(find.byIcon(Icons.edit));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('cancelling an edit leaves the step unchanged', (tester) async {
    await _openFirstLeafletInEditMode(tester);

    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, _rewritten);
    // ダイアログの外側をタップして閉じる。
    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();

    expect(find.text(_rewritten), findsNothing);
  });

  testWidgets('saving an edit updates the step', (tester) async {
    await _openFirstLeafletInEditMode(tester);

    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, _rewritten);
    await tester.ensureVisible(find.text(ja.ok));
    await tester.tap(find.text(ja.ok));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(_rewritten), findsOneWidget);
  });

  testWidgets('deleting asks for confirmation first', (tester) async {
    await _openFirstLeafletInEditMode(tester);
    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
    final title = tester
        .widget<TextField>(find.byType(TextField).first)
        .controller!
        .text;

    await tester.ensureVisible(find.text(ja.delete));
    await tester.tap(find.text(ja.delete));
    await tester.pumpAndSettle();
    expect(find.text(ja.keep), findsOneWidget);

    await tester.tap(find.text(ja.keep));
    await tester.pumpAndSettle();
    expect(find.text(ja.keep), findsNothing);
    expect(find.byType(TextField), findsWidgets);

    await tester.ensureVisible(find.text(ja.delete));
    await tester.tap(find.text(ja.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, ja.delete));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text(title), findsNothing);
  });
}
