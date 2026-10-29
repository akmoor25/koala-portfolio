import 'package:flutter_test/flutter_test.dart';
import 'package:koala/helper/current_step.dart';

class _Step {
  final String id;
  final DateTime start;
  final DateTime? end;
  _Step(this.id, this.start, [this.end]);
}

CurrentStep<_Step> _resolve(List<_Step> steps, DateTime now) =>
    resolveCurrentStep(
      steps,
      now,
      startOf: (s) => s.start,
      endOf: (s) => s.end,
    );

void main() {
  final t = DateTime(2026, 5, 1, 9);
  final a = _Step('a', t);
  final b = _Step(
    'b',
    t.add(const Duration(hours: 2)),
    t.add(const Duration(hours: 3)),
  );
  final c = _Step('c', t.add(const Duration(hours: 5)));
  final steps = [a, b, c];

  test('empty list', () {
    final r = _resolve([], t);
    expect(r.current, isNull);
    expect(r.next, isNull);
  });

  test('before the trip: no current, next is the first step', () {
    final r = _resolve(steps, t.subtract(const Duration(minutes: 1)));
    expect(r.current, isNull);
    expect(r.next, a);
  });

  test('exactly at a start time the step becomes current', () {
    final r = _resolve(steps, t);
    expect(r.current, a);
    expect(r.next, b);
  });

  test('during a step with an end time', () {
    final r = _resolve(steps, t.add(const Duration(hours: 2, minutes: 30)));
    expect(r.current, b);
    expect(r.next, c);
  });

  test('gap after a step ended: no current, next still shown', () {
    final r = _resolve(steps, t.add(const Duration(hours: 4)));
    expect(r.current, isNull);
    expect(r.next, c);
  });

  test('last step without end time stays current', () {
    final r = _resolve(steps, t.add(const Duration(days: 3)));
    expect(r.current, c);
    expect(r.next, isNull);
  });

  test('last step with a past end time: trip is over', () {
    final r = _resolve([a, b], t.add(const Duration(hours: 4)));
    expect(r.current, isNull);
    expect(r.next, isNull);
  });
}
