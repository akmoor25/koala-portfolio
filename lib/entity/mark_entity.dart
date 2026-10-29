import '../extension/extension.dart';
import '../helper/act_type.dart';
import '../helper/time_zones.dart';

/// 旅程の 1 つの工程。
class MarkEntity {
  /// すべての項目を指定して作る。
  MarkEntity(
    this.key,
    this.isAbout,
    this.actType,
    this.title,
    this.remark,
    this.link,
    this.timeZoneId,
    this.startDate,
    this.endDate, {
    this.endTimeZoneId = '',
  });

  /// Realtime Database のキー。
  String key;

  /// 時刻が目安であることを表す。
  bool isAbout;

  /// 移動手段。未設定なら null。
  ActType? actType;

  /// 工程の名前。
  String title;

  /// 備考。
  String remark;

  /// 関連リンクの URL。
  String link;

  /// 開始時刻のタイムゾーン ID（現地時刻で入力・表示する）。空や未知の ID は端末のタイムゾーン。
  String timeZoneId;

  /// 開始日時。
  DateTime startDate;

  /// 終了日時。未設定なら null。
  DateTime? endDate;

  /// 終了時刻のタイムゾーン ID。空なら開始と同じ。飛行機のように、到着地が違うときに使う。
  String endTimeZoneId;

  /// 開始時刻の表示に使うタイムゾーン ID（必ず有効な ID）。
  String get startZoneId => resolveZoneId(timeZoneId);

  /// 終了時刻の表示に使うタイムゾーン ID（必ず有効な ID）。
  String get endZoneId =>
      endTimeZoneId.isEmpty ? startZoneId : resolveZoneId(endTimeZoneId);

  /// 編集中の値を元の旅程に反映させないための複製。
  MarkEntity copy() => MarkEntity(
    key,
    isAbout,
    actType,
    title,
    remark,
    link,
    timeZoneId,
    startDate,
    endDate,
    endTimeZoneId: endTimeZoneId,
  );

  /// DB の値から作る。形式が不正で作れない場合は null を返す。
  ///
  /// 1 件の不正なデータのせいで、旅程全体の購読が止まらないようにする。
  static MarkEntity? tryBuild(String key, Map<Object?, Object?> map) {
    final start = map['startDate'];
    if (start is! num) return null;

    final endValue = map['endDate'];
    final actIcon = map['actIcon'];
    return MarkEntity(
      key,
      map['isAbout'] == true,
      actIcon is int ? ActType.values.tryGet(actIcon) : null,
      _stringOf(map['title']),
      _stringOf(map['remark']),
      _stringOf(map['link']),
      _stringOf(map['timeZoneId']),
      fromSecondsSinceEpoch(start.toInt()),
      endValue is num ? fromSecondsSinceEpoch(endValue.toInt()) : null,
      endTimeZoneId: _stringOf(map['endTimeZoneId']),
    );
  }

  /// DB に保存する形式。
  Map<String, Object?> toJson() {
    return {
      'startDate': startDate.secondsSinceEpoch(),
      'endDate': endDate?.secondsSinceEpoch(),
      'actIcon': actType?.index,
      'isAbout': isAbout,
      'title': title,
      'remark': remark,
      'link': link,
      'timeZoneId': timeZoneId,
      'endTimeZoneId': endTimeZoneId.isEmpty ? null : endTimeZoneId,
    };
  }
}

String _stringOf(Object? value) => value is String ? value : '';
