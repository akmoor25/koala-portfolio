extension ListExtension<T> on List<T> {
  T? tryGet(int index) => index < 0 || index >= length ? null : this[index];
}

extension DateTimeExt on DateTime {
  bool isSameDate(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }

  /// DB とウィジェットに渡す、エポック秒。ミリ秒以下は切り捨てる。
  int secondsSinceEpoch() =>
      millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond;
}

DateTime fromSecondsSinceEpoch(int secondsSinceEpoch) {
  return DateTime.fromMillisecondsSinceEpoch(
    secondsSinceEpoch * Duration.millisecondsPerSecond,
  );
}

extension StringExt on String {
  String withoutNewLineCode() {
    return replaceAll("\n", " ");
  }
}
