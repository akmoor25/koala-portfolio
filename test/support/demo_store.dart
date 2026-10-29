import 'dart:async';

/// 現在の値を保持し、購読の開始時にその値をすぐ流す、変更通知付きの値。
///
/// Firebase の `onValue` と同じ使い勝手にして、画面と Model が
/// 接続先の違いを意識しないようにする。
class LiveValue<T> {
  /// [_value] を最初の値にする。
  LiveValue(this._value);

  T _value;
  final Set<MultiStreamController<T>> _listeners = {};

  /// 現在の値。
  T get value => _value;

  /// 値を更新して、購読者へ流す。
  set value(T next) {
    _value = next;
    for (final listener in _listeners.toList()) {
      listener.addSync(next);
    }
  }

  /// 現在の値を最初に流し、以降は変更のたびに流す。
  ///
  /// 購読の開始と最初の値の間に更新が入っても、取りこぼさない。
  Stream<T> watch() {
    return Stream<T>.multi((controller) {
      _listeners.add(controller);
      controller.addSync(_value);
      controller.onCancel = () {
        _listeners.remove(controller);
      };
    });
  }
}
