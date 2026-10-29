import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../entity/mark_entity.dart';
import '../extension/extension.dart';
import '../logger.dart';

const _appGroupId = 'group.io.akmoor25.koala-portfolio';
const _dataKey = 'koala_trip';
const _iOSName = 'KoalaWidget';
const _qualifiedAndroidName =
    'io.akmoor25.koala_portfolio.widget.KoalaWidgetReceiver';

/// ウィジェットに渡す工程の最大数（SharedPreferences / UserDefaults の肥大化防止）。
const widgetMaxSteps = 20;

/// ホーム画面ウィジェット（Android Glance / iOS WidgetKit）へ旅程を渡す。
///
/// ウィジェットは「今どの工程か」を自前で判定するため、
/// 判定結果ではなく今後の工程リストそのものを渡す。
/// これによりアプリを開かなくても時間経過で表示が進む。
class NativeTripWidgetPublisher {
  /// 何も受け取らない。
  const NativeTripWidgetPublisher();

  // データの保存先は全インスタンスで共通。read-modify-write も同じ列に並べる。
  static Future<void> _pending = Future<void>.value();

  bool get _isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// 起動時に一度だけ初期化する。
  Future<void> init() async {
    if (!_isSupported) return;
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  /// [leafletTitle] と [marks] をウィジェットに反映する。
  ///
  /// [leafletKey] は、あとで [clearFor] が「このしおりの分か」を判定するために、データに含める。
  Future<void> publish(
    String leafletTitle,
    List<MarkEntity> marks, {
    String? leafletKey,
  }) {
    if (!_isSupported) return Future<void>.value();
    final now = DateTime.now();
    final json = encodeWidgetPayload(
      leafletTitle,
      marks,
      now,
      leafletKey: leafletKey,
    );
    final boundaries = widgetBoundaryTimes(marks, now);
    return _enqueue('publish', () async {
      await HomeWidget.saveWidgetData<String>(_dataKey, json);
      await HomeWidget.updateWidget(
        iOSName: _iOSName,
        qualifiedAndroidName: _qualifiedAndroidName,
      );
      if (defaultTargetPlatform == TargetPlatform.android) {
        await HomeWidget.scheduleWidgetUpdates(
          boundaries,
          qualifiedAndroidName: _qualifiedAndroidName,
        );
      }
    });
  }

  /// 表示中のしおりとキーが一致するときだけタイトルを更新する。
  /// 呼び出し元（しおり一覧など）は工程を持たないため、工程、更新時刻、予約済みの
  /// 表示切り替えは変更しない。
  Future<void> updateTitleFor(String leafletKey, String title) =>
      _enqueue('updateTitleFor', () async {
        final saved = await HomeWidget.getWidgetData<String>(_dataKey);
        if (saved == null) return;
        final decoded = jsonDecode(saved);
        if (decoded is! Map<String, dynamic> ||
            decoded['leafletKey'] != leafletKey ||
            decoded['leaflet'] == title) {
          return;
        }
        decoded['leaflet'] = title;
        await HomeWidget.saveWidgetData<String>(_dataKey, jsonEncode(decoded));
        await HomeWidget.updateWidget(
          iOSName: _iOSName,
          qualifiedAndroidName: _qualifiedAndroidName,
        );
      });

  Future<void> _enqueue(String operation, Future<void> Function() action) {
    if (!_isSupported) return Future<void>.value();
    final next = _pending.then((_) async {
      try {
        await action();
      } on Exception catch (e, s) {
        logger.w('NativeTripWidgetPublisher.$operation failed', e, s);
      }
    });
    // 予期しない Error が起きても、後続の clear や publish を妨げない。
    _pending = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  /// ウィジェットが [leafletKey] のしおりを表示しているときだけ、そのデータを消す。
  ///
  /// しおりの削除と脱退のあとに呼ぶ。別のしおりを表示していれば何もしない。
  /// キーを持たない古いデータは、どのしおりのものか分からないので消さない。
  Future<void> clearFor(String leafletKey) => _enqueue('clearFor', () async {
    final saved = await HomeWidget.getWidgetData<String>(_dataKey);
    if (saved == null || _keyOf(saved) != leafletKey) return;
    await _clearSaved();
  });

  /// どのしおりを表示していても、ウィジェットのデータを消す。
  ///
  /// アカウントが使えなくなったときに使う。そのアカウントのしおりは、もう読めないため。
  Future<void> clear() => _enqueue('clear', () async {
    final saved = await HomeWidget.getWidgetData<String>(_dataKey);
    if (saved == null) return;
    await _clearSaved();
  });

  Future<void> _clearSaved() async {
    await HomeWidget.saveWidgetData<String>(_dataKey, null);
    await HomeWidget.updateWidget(
      iOSName: _iOSName,
      qualifiedAndroidName: _qualifiedAndroidName,
    );
    if (defaultTargetPlatform == TargetPlatform.android) {
      await HomeWidget.cancelScheduledWidgetUpdates(
        qualifiedAndroidName: _qualifiedAndroidName,
      );
    }
  }

  static String? _keyOf(String json) {
    try {
      final decoded = jsonDecode(json);
      final key = decoded is Map<String, dynamic>
          ? decoded['leafletKey']
          : null;
      return key is String ? key : null;
    } on FormatException {
      return null;
    }
  }
}

/// 現在の工程（終了済みでないもの）以降を最大 [widgetMaxSteps] 件だけ JSON 化する。
///
/// [leafletKey] があれば、`leafletKey` として含める（ネイティブ側は読まない）。
String encodeWidgetPayload(
  String leafletTitle,
  List<MarkEntity> marks,
  DateTime now, {
  String? leafletKey,
}) {
  final nextIndex = marks.indexWhere((m) => m.startDate.isAfter(now));
  final from = nextIndex == -1
      ? (marks.isEmpty ? 0 : marks.length - 1)
      : (nextIndex > 0 ? nextIndex - 1 : 0);
  final steps = marks
      .skip(from)
      .take(widgetMaxSteps)
      .map(
        (m) => {
          'title': m.title,
          if (m.remark.isNotEmpty) 'remark': m.remark,
          'start': m.startDate.secondsSinceEpoch(),
          'end': ?_secondsOf(m.endDate),
          'tz': m.startZoneId,
          if (m.endDate != null && m.endZoneId != m.startZoneId)
            'endTz': m.endZoneId,
          'actIcon': ?m.actType?.index,
          'isAbout': m.isAbout,
        },
      );
  return jsonEncode({
    'leaflet': leafletTitle,
    'leafletKey': ?leafletKey,
    'updatedAt': now.secondsSinceEpoch(),
    'steps': steps.toList(),
  });
}

int? _secondsOf(DateTime? time) => time?.secondsSinceEpoch();

/// 表示が切り替わる時刻（各工程の開始・終了）のうち未来のもの。
List<DateTime> widgetBoundaryTimes(List<MarkEntity> marks, DateTime now) {
  final times = <DateTime>{
    for (final m in marks) ...[m.startDate, ?m.endDate],
  }.where((t) => t.isAfter(now)).toList()..sort();
  return times.take(widgetMaxSteps * 2).toList();
}
