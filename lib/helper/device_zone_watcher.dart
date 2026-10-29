import 'dart:async';

import 'package:flutter/widgets.dart';

import 'time_zones.dart';

/// 端末のタイムゾーンの変更を、アプリを再起動せずに反映する。
///
/// 端末側でタイムゾーンを変えても、アプリへは通知されない。そのため、アプリが前面に戻った
/// ときと、前面にある間は一定の間隔で、端末のタイムゾーンを読み直す（分割画面で、設定を
/// 変えた場合にも気づけるようにするため）。変わっていれば [deviceZoneListenable] で知らせる。
class DeviceZoneWatcher extends StatefulWidget {
  /// [child] を包む。見た目は変えない。
  const DeviceZoneWatcher({
    super.key,
    required this.child,
    this.interval = const Duration(seconds: 3),
  });

  /// 包む対象。
  final Widget child;

  /// 前面にある間に、読み直す間隔。
  ///
  /// 変更が数秒で表示に表れる一方、読み直し（ネイティブの呼び出し）が頻繁になりすぎない長さ。
  final Duration interval;

  @override
  State<DeviceZoneWatcher> createState() => _DeviceZoneWatcherState();
}

class _DeviceZoneWatcherState extends State<DeviceZoneWatcher>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(
      widget.interval,
      (_) => unawaited(refreshDeviceZone()),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refreshDeviceZone());
      _start();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
