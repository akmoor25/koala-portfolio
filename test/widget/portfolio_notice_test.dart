import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/components/portfolio_notice.dart';

import '../support/localized_app.dart';

void main() {
  testWidgets('shows that the app is for the portfolio and may stop', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedApp(home: const Scaffold(body: PortfolioNotice())),
    );

    expect(find.text(ja.portfolioNoticeTitle), findsOneWidget);
    expect(find.text(ja.portfolioNoticeBody), findsOneWidget);
  });
}
