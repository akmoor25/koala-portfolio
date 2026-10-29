import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/app_services.dart';
import '../data/firebase/firebase_services.dart';
import '../entity/leaflet_entity.dart';
import '../entity/mark_entity.dart';
import '../extension/extension.dart';
import '../helper/current_step.dart';
import '../helper/time_zones.dart';
import '../helper/trip_widget_publisher.dart';
import '../l10n/l10n.dart';
import '../l10n/write_task.dart';
import '../logger.dart';
import 'marks_list_items.dart';

/// 旅程画面の状態。旅程の購読、「いま・つぎ」の判定、編集モードを持つ。
class MarksModel extends ChangeNotifier {
  /// [leaflet] の旅程を扱う。[services] は接続先。
  MarksModel(LeafletEntity leaflet, AppServices services)
    : _leafletKey = leaflet.key,
      _marks = services.marks,
      _leaflets = services.leaflets,
      _widget = services.widget;

  final String _leafletKey;
  LeafletEntity? _leaflet;

  /// 購読済みの最新のしおり。初回取得前、削除・権限喪失時は null。
  LeafletEntity? get leaflet => _leaflet;

  final FirebaseMarkRepository _marks;
  final FirebaseLeafletRepository _leaflets;
  final NativeTripWidgetPublisher _widget;

  /// 画面に並べる項目。日付ヘッダ、工程、末尾の余白を含む。
  List<MarksListItem> listItems = [];

  /// 購読している旅程（開始日時の昇順）。追加するときの、タイムゾーンの既定値に使う。
  List<MarkEntity> marks = [];

  /// 編集モードかどうか。
  bool isEditMode = false;

  /// 初期表示でスクロールする位置。表示する項目が無ければ null。
  int? nowItemIndex;

  /// 失敗の文言に使う言語。画面が、いまの言語のものを入れる。
  AppLocalizations l10n = AppLocalizationsEn();

  /// 書き込みの失敗を画面へ伝える。画面側が SnackBar などで表示する。
  void Function(String message)? onWriteError;

  StreamSubscription<List<MarkEntity>>? _marksSubscription;
  StreamSubscription<LeafletEntity?>? _leafletSubscription;
  bool _hasMarks = false;
  bool _disposed = false;

  /// 旅程の購読を始める。
  void fetchMarksEntity() {
    if (_marksSubscription != null || _disposed) return;
    deviceZoneListenable.addListener(_onDeviceZoneChanged);
    _leafletSubscription = _leaflets
        .watchLeaflet(_leafletKey)
        .listen(
          (leaflet) {
            if (_disposed) return;
            final first = _leaflet == null;
            _leaflet = leaflet;
            if (leaflet == null) {
              unawaited(_widget.clearFor(_leafletKey));
            } else {
              if (first && _hasMarks) {
                _updateLeafletIfNeeded(marks);
                _publish();
              } else {
                unawaited(_widget.updateTitleFor(_leafletKey, leaflet.title));
              }
            }
            notifyListeners();
          },
          onError: (Object e) {
            if (_disposed) return;
            logger.e('leaflet listen failed', e);
            _leaflet = null;
            unawaited(_widget.clearFor(_leafletKey));
            notifyListeners();
          },
          cancelOnError: true,
        );
    _marksSubscription = _marks.watchMarks(_leafletKey).listen((markEntities) {
      if (_disposed) return;
      logger.i('markEntities.length: ${markEntities.length}');
      _hasMarks = true;
      _updateLeafletIfNeeded(markEntities);
      _updateListItems(markEntities);
      _publish();
    }, onError: (Object e) => logger.e('marks listen failed', e));
  }

  void _publish() {
    final leaflet = _leaflet;
    if (leaflet == null || !_hasMarks) return;
    unawaited(_widget.publish(leaflet.title, marks, leafletKey: _leafletKey));
  }

  /// 端末のタイムゾーンが変わったら、それに依存する表示（都市名のバッジなど）を作り直す。
  void _onDeviceZoneChanged() {
    listItems = buildListItems(marks, DateTime.now());
    notifyListeners();
    _publish();
  }

  @override
  void dispose() {
    _disposed = true;
    deviceZoneListenable.removeListener(_onDeviceZoneChanged);
    unawaited(_marksSubscription?.cancel());
    unawaited(_leafletSubscription?.cancel());
    super.dispose();
  }

  /// しおりの期間を旅程に合わせて書き戻す。
  ///
  /// 期間は旅程から一意に決まる導出値で、違うときだけ書くため、複数の端末が
  /// 同時に実行しても同じ値に収束する。
  void _updateLeafletIfNeeded(List<MarkEntity> markEntities) {
    final leaflet = _leaflet;
    if (leaflet == null) return;
    if (markEntities.isEmpty) {
      if (leaflet.firstDate == null &&
          leaflet.lastDate == null &&
          leaflet.firstTimeZoneId == null &&
          leaflet.lastTimeZoneId == null) {
        return;
      }
      unawaited(
        _write(
          WriteTask.updatePeriod,
          () => _leaflets.updateLeafletPeriod(_leafletKey),
        ),
      );
      return;
    }
    final firstMark = markEntities.first;
    final firstDate = firstMark.startDate;
    final lastMark = markEntities.last;
    final lastDate = lastMark.endDate ?? lastMark.startDate;
    final lastZone = lastMark.endDate != null
        ? lastMark.endZoneId
        : lastMark.startZoneId;

    if (leaflet.firstDate?.secondsSinceEpoch() !=
            firstDate.secondsSinceEpoch() ||
        leaflet.lastDate?.secondsSinceEpoch() != lastDate.secondsSinceEpoch() ||
        leaflet.firstTimeZoneId != firstMark.startZoneId ||
        leaflet.lastTimeZoneId != lastZone) {
      unawaited(
        _write(
          WriteTask.updatePeriod,
          () => _leaflets.updateLeafletPeriod(
            _leafletKey,
            firstDate: firstDate,
            lastDate: lastDate,
            firstTimeZoneId: firstMark.startZoneId,
            lastTimeZoneId: lastZone,
          ),
        ),
      );
    }
  }

  void _updateListItems(List<MarkEntity> markEntities) {
    if (markEntities.isEmpty) isEditMode = true;
    marks = markEntities;
    listItems = buildListItems(markEntities, DateTime.now());
    nowItemIndex = initialScrollIndex(listItems);
    notifyListeners();
  }

  /// 編集モードを切り替える。
  void toggleEditMode() {
    logger.i('toggleEditMode ${!isEditMode}');
    isEditMode = !isEditMode;
    notifyListeners();
  }

  /// 旅程を追加する。
  Future<void> addMark(MarkEntity mark) =>
      _write(WriteTask.addPlan, () => _marks.addMark(_leafletKey, mark));

  /// 旅程を更新する。
  Future<void> updateMark(MarkEntity mark) =>
      _write(WriteTask.updatePlan, () => _marks.updateMark(_leafletKey, mark));

  /// 旅程を削除する。
  Future<void> deleteMark(MarkEntity mark) =>
      _write(WriteTask.deletePlan, () => _marks.deleteMark(_leafletKey, mark));

  Future<void> _write(WriteTask task, Future<void> Function() action) async {
    try {
      await action();
    } on Exception catch (e, s) {
      logger.e('Failed: ${task.name}', e, s);
      onWriteError?.call(l10n.writeFailed(task));
    }
  }
}

/// 画面に並べる項目を作る。
///
/// 日が変わるたびに日付ヘッダを入れ、「いま」と「つぎ」の工程に印を付ける。
/// 旅程が無いときは、日付の無いヘッダだけを置く。末尾には必ず [EndItem] を置く。
List<MarksListItem> buildListItems(List<MarkEntity> marks, DateTime now) {
  final step = resolveCurrentStep<MarkEntity>(
    marks,
    now,
    startOf: (m) => m.startDate,
    endOf: (m) => m.endDate,
  );
  final nowKey = step.current?.key;
  final nextKey = step.next?.key;

  final items = <MarksListItem>[];
  DateTime? lastDay;
  for (final mark in marks) {
    final wall = wallOf(mark.startZoneId, mark.startDate);
    final day = DateTime(wall.year, wall.month, wall.day);
    if (lastDay == null || !day.isSameDate(lastDay)) {
      items.add(
        DayHeaderItem(
          isTop: lastDay == null,
          startDate: day,
          zoneId: mark.startZoneId,
        ),
      );
      lastDay = day;
    }
    items.add(
      ActionItem(mark)
        ..isNow = mark.key == nowKey
        ..isNext = mark.key == nextKey,
    );
  }

  if (items.isEmpty) {
    items.add(DayHeaderItem(isTop: true, startDate: null, zoneId: null));
  }
  items.add(EndItem());
  return items;
}

/// 初期表示でスクロールする位置。
///
/// 「いま」、無ければ「つぎ」の 1 つ前の項目の位置。どちらも無ければ null。
int? initialScrollIndex(List<MarksListItem> items) {
  var index = items.indexWhere((item) => item is ActionItem && item.isNow);
  if (index == -1) {
    index = items.indexWhere((item) => item is ActionItem && item.isNext);
  }
  if (index == -1) return null;
  return index > 0 ? index - 1 : 0;
}

/// 旅程を追加するときの、タイムゾーンの既定値。
///
/// 開始日時 [start] 以前で、いちばん近い旅程の「終了側」のタイムゾーン（例：ニューヨークに
/// 到着する旅程の後は、ニューヨーク）。そのような旅程が無ければ、端末のタイムゾーン。
/// [marks] は開始日時の昇順。
String defaultZoneIdFor(List<MarkEntity> marks, DateTime start) {
  for (final mark in marks.reversed) {
    if (!mark.startDate.isAfter(start)) return mark.endZoneId;
  }
  return deviceZoneId;
}
