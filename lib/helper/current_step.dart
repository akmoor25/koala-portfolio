/// 「いま」と「つぎ」の工程を判定する純粋関数。
///
/// ネイティブウィジェット (Glance / WidgetKit) も同じ規則で判定するため、
/// 仕様をここに一本化してテストで固定する。
///
/// - `next`: `now` より後に始まる最初の工程
/// - `current`: `next` の直前の工程 (`next` が無ければ最後の工程)。
///   ただし `endDate` が過ぎていれば `null`
class CurrentStep<T> {
  final T? current;
  final T? next;

  const CurrentStep(this.current, this.next);
}

CurrentStep<T> resolveCurrentStep<T>(
  List<T> steps,
  DateTime now, {
  required DateTime Function(T) startOf,
  required DateTime? Function(T) endOf,
}) {
  final nextIndex = steps.indexWhere((s) => startOf(s).isAfter(now));

  T? current;
  T? next;
  if (nextIndex != -1) {
    next = steps[nextIndex];
    if (nextIndex > 0) current = steps[nextIndex - 1];
  } else if (steps.isNotEmpty) {
    current = steps.last;
  }

  if (current != null) {
    final end = endOf(current);
    if (end != null && end.isBefore(now)) current = null;
  }

  return CurrentStep(current, next);
}
