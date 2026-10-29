import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/sharing/leaflet_id_field.dart';
import 'package:koala/theme/app_theme.dart';

import '../support/localized_app.dart';

const _caution = '入力内容をお確かめください';

Future<LeafletIdController> _pump(WidgetTester tester) async {
  final controller = LeafletIdController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    localizedApp(
      home: Scaffold(body: LeafletIdField(controller: controller)),
    ),
  );
  return controller;
}

Finder _segment(int index) => find.byType(TextField).at(index);

void main() {
  testWidgets('shows three boxes separated by hyphens', (tester) async {
    await _pump(tester);

    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.text('-'), findsNWidgets(2));
    expect(find.textContaining(_caution, findRichText: true), findsNothing);
  });

  testWidgets('joins the three boxes into one id without changing letters', (
    tester,
  ) async {
    final controller = await _pump(tester);

    await tester.enterText(_segment(0), '0123');
    await tester.enterText(_segment(1), '4567');
    await tester.enterText(_segment(2), '89AB');

    expect(controller.value, '0123456789AB');
    expect(controller.isComplete, isTrue);
    expect(controller.hasInvalidCharacters, isFalse);
  });

  testWidgets('does not convert lower case or look-alike characters', (
    tester,
  ) async {
    final controller = await _pump(tester);

    await tester.enterText(_segment(0), 'abIL');

    expect(controller.value, 'abIL');
    expect(controller.hasInvalidCharacters, isTrue);
  });

  testWidgets('warns and marks the unusable characters in red', (tester) async {
    await _pump(tester);

    await tester.enterText(_segment(0), '01UO');
    await tester.pump();

    expect(find.textContaining(_caution), findsOneWidget);
    final editable = tester.widget<EditableText>(
      find.byType(EditableText).first,
    );
    final span = editable.controller.buildTextSpan(
      context: tester.element(find.byType(EditableText).first),
      withComposing: false,
    );
    final colors = {
      for (final child in span.children!.cast<TextSpan>())
        child.text: child.style?.color,
    };
    expect(colors['0'], isNull);
    expect(colors['1'], isNull);
    final danger = Theme.of(tester.element(find.byType(EditableText).first))
        .koala
        .dangerText;
    expect(colors['U'], danger);
    expect(colors['O'], danger);
  });

  testWidgets('the warning goes away once the characters are fixed', (
    tester,
  ) async {
    await _pump(tester);
    await tester.enterText(_segment(0), '01UO');
    await tester.pump();

    await tester.enterText(_segment(0), '0123');
    await tester.pump();

    expect(find.textContaining(_caution), findsNothing);
  });

  testWidgets('a pasted id is split across the boxes', (tester) async {
    final controller = await _pump(tester);

    await tester.enterText(_segment(0), '0123-4567 89AB');

    expect(controller.value, '0123456789AB');
    final texts = tester
        .widgetList<TextField>(find.byType(TextField))
        .map((field) => field.controller!.text);
    expect(texts, ['0123', '4567', '89AB']);
  });

  testWidgets('setting the value from a QR code fills every box', (
    tester,
  ) async {
    final controller = await _pump(tester);
    await tester.enterText(_segment(2), 'ZZZZ');

    controller.value = '0123456789AB';
    await tester.pump();

    final texts = tester
        .widgetList<TextField>(find.byType(TextField))
        .map((field) => field.controller!.text);
    expect(texts, ['0123', '4567', '89AB']);
  });

  testWidgets('moves to the next box when one is filled', (tester) async {
    await _pump(tester);

    await tester.enterText(_segment(0), '0123');
    await tester.pump();

    final second = tester.widget<TextField>(_segment(1));
    expect(second.focusNode!.hasFocus, isTrue);
  });
}
