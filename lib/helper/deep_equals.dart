/// JSON形式のMap・Listを内容で比べる。Mapのキー順は問わず、Listの順序は区別する。
bool mapEqualsDeep(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every(
          (key) => b.containsKey(key) && mapEqualsDeep(a[key], b[key]),
        );
  }
  if (a is List && b is List) {
    return a.length == b.length &&
        List.generate(
          a.length,
          (i) => i,
        ).every((i) => mapEqualsDeep(a[i], b[i]));
  }
  return a == b;
}
