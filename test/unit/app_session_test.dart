import 'package:flutter_test/flutter_test.dart';
import 'package:koala/data/app_session.dart';

import '../support/demo_database.dart';

void main() {
  test('has no connection until one is started', () {
    expect(AppSession().services, isNull);
  });

  test('starting a session notifies listeners', () {
    final session = AppSession();
    var notified = 0;
    session.addListener(() => notified++);

    session.start(DemoDatabase().services);

    expect(session.services, isNotNull);
    expect(notified, 1);
  });
}
