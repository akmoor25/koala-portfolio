import '../helper/act_type.dart';

/// サンプルの旅程で、日本の旅の基準にするタイムゾーン。
const sampleHomeZone = 'Asia/Tokyo';

/// サンプルの旅程 1 件分。日は旅の初日からの経過日数。
///
/// 時刻は、[zone] の現地時刻。終了は、現地時刻 [end]（[endZone] の時刻。無ければ
/// [zone]）か、所要時間 [duration] で決める。
class SampleStep {
  /// 現地時刻の開始と終了で決める旅程。
  const SampleStep(
    this.day,
    this.start,
    this.end,
    this.title, {
    this.type,
    this.remark = '',
    this.link = '',
    this.about = false,
    this.zone = sampleHomeZone,
  }) : duration = null,
       endZone = null;

  /// 所要時間で終了を決める、移動の旅程。到着地のタイムゾーンは [endZone]。
  const SampleStep.leg(
    this.day,
    this.start,
    Duration this.duration,
    this.title, {
    this.type,
    this.remark = '',
    this.zone = sampleHomeZone,
    required String this.endZone,
  }) : end = null,
       link = '',
       about = false;

  /// 旅の初日からの経過日数（初日は 0）。
  final int day;

  /// 開始の現地時刻（時, 分）。
  final (int, int) start;

  /// 終了の現地時刻（時, 分）。[duration] があるときは使わない。
  final (int, int)? end;

  /// 移動の所要時間。
  final Duration? duration;

  /// 予定の名前。
  final String title;

  /// 移動手段。
  final ActType? type;

  /// 備考。
  final String remark;

  /// 関連するリンク。
  final String link;

  /// 「およその予定」か。
  final bool about;

  /// 開始のタイムゾーン。
  final String zone;

  /// 終了のタイムゾーン。無ければ [zone] と同じ。
  final String? endZone;
}
