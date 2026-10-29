import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/crash_reporter.dart';
import 'package:koala/error_handlers.dart';

class _FakeReporter implements CrashReporter {
  _FakeReporter({this.failing = false});

  final bool failing;
  final flutterErrors = <FlutterErrorDetails>[];
  final errors = <Object>[];

  @override
  Future<void> start() async {}

  @override
  void recordFlutterError(FlutterErrorDetails details) {
    if (failing) throw StateError('send failed');
    flutterErrors.add(details);
  }

  @override
  void recordError(Object error, StackTrace? stack, {String? reason}) {
    if (failing) throw StateError('send failed');
    errors.add(error);
  }
}

void main() {
  late FlutterExceptionHandler? originalOnError;
  late bool Function(Object, StackTrace)? originalDispatcherOnError;

  setUp(() {
    originalOnError = FlutterError.onError;
    originalDispatcherOnError = PlatformDispatcher.instance.onError;
  });

  tearDown(() {
    useCrashReporter(null);
    FlutterError.onError = originalOnError;
    PlatformDispatcher.instance.onError = originalDispatcherOnError;
  });

  test('replaces both hooks', () {
    installErrorHandlers();

    expect(FlutterError.onError, isNot(originalOnError));
    expect(PlatformDispatcher.instance.onError, isNotNull);
  });

  test('uncaught asynchronous errors are handled, not rethrown', () {
    installErrorHandlers();

    final handled = PlatformDispatcher.instance.onError!(
      StateError('boom'),
      StackTrace.current,
    );

    expect(handled, isTrue);
  });

  test('framework errors are reported without throwing', () {
    installErrorHandlers();

    expect(
      () => FlutterError.onError!(
        FlutterErrorDetails(exception: StateError('boom')),
      ),
      returnsNormally,
    );
  });

  test('errors are sent to the reporter once it is set', () {
    final reporter = _FakeReporter();
    installErrorHandlers();
    useCrashReporter(reporter);

    FlutterError.onError!(FlutterErrorDetails(exception: StateError('a')));
    PlatformDispatcher.instance.onError!(StateError('b'), StackTrace.current);

    expect(reporter.flutterErrors, hasLength(1));
    expect(reporter.errors, hasLength(1));
  });

  test('errors before the reporter is set only go to the log', () {
    installErrorHandlers();

    expect(reportTestError(), isFalse);
    expect(
      PlatformDispatcher.instance.onError!(StateError('b'), StackTrace.current),
      isTrue,
    );
  });

  test('a failing reporter does not break error handling', () {
    installErrorHandlers();
    useCrashReporter(_FakeReporter(failing: true));

    expect(
      () => FlutterError.onError!(
        FlutterErrorDetails(exception: StateError('a')),
      ),
      returnsNormally,
    );
    expect(
      PlatformDispatcher.instance.onError!(StateError('b'), StackTrace.current),
      isTrue,
    );
  });

  test('the test error is sent when a reporter is set', () {
    final reporter = _FakeReporter();
    useCrashReporter(reporter);

    expect(reportTestError(), isTrue);
    expect(reporter.errors, hasLength(1));
  });
}
