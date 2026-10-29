import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/city_names.dart';
import '../logger.dart';

// 時刻は絶対時刻（エポック秒）で保存し、タイムゾーンは入力と表示にだけ使う。
// 「現地の日時」は、年月日時分だけを持つ `DateTime`（端末のタイムゾーンとは無関係）で表す。

bool _ready = false;
final ValueNotifier<String> _deviceZone = ValueNotifier<String>('UTC');

/// 端末のタイムゾーン ID（例：`Asia/Tokyo`）。取得できなければ `UTC`。
String get deviceZoneId => _deviceZone.value;

/// 端末のタイムゾーンが変わったことを知らせる。
///
/// 端末側でタイムゾーンを変えても、アプリへは通知されないため、[refreshDeviceZone] で調べる。
ValueListenable<String> get deviceZoneListenable => _deviceZone;

/// タイムゾーンのデータベースを読み込む。何度呼んでもよい。
void ensureTimeZonesInitialized() {
  if (_ready) return;
  tz_data.initializeTimeZones();
  _ready = true;
}

/// 端末のタイムゾーン ID を読む処理。テストで差し替える。
@visibleForTesting
Future<String> Function() readDeviceZoneId = () async {
  final info = await FlutterTimezone.getLocalTimezone();
  return info.identifier;
};

/// 端末のタイムゾーンを読み直す。変わっていれば [deviceZoneListenable] で知らせる。
Future<void> refreshDeviceZone() async {
  ensureTimeZonesInitialized();
  try {
    final id = await readDeviceZoneId();
    if (isValidZoneId(id)) _deviceZone.value = id;
  } on Object catch (e, s) {
    logger.w('Could not read the device time zone', e, s);
  }
}

/// 起動時に一度だけ、データベースの読み込みと端末のタイムゾーンの取得を行う。
Future<void> initTimeZones() => refreshDeviceZone();

/// テストで、端末のタイムゾーンを決める。
@visibleForTesting
void setDeviceZoneForTest(String id) {
  ensureTimeZonesInitialized();
  assert(isValidZoneId(id), 'Unknown time zone: $id');
  _deviceZone.value = id;
}

/// [id] がタイムゾーンのデータベースにあるか。
bool isValidZoneId(String id) {
  if (id.isEmpty) return false;
  ensureTimeZonesInitialized();
  return tz.timeZoneDatabase.locations.containsKey(id);
}

/// [id] が使えるならそのまま、空や未知のときは端末のタイムゾーンを返す。
String resolveZoneId(String id) => isValidZoneId(id) ? id : deviceZoneId;

tz.Location _locationOf(String id) => tz.getLocation(resolveZoneId(id));

/// [zoneId] の現地の日時 [wall]（年月日時分）が指す、絶対時刻。
///
/// 夏時間で存在しない時刻は、直後の時刻にずらす。2 回ある時刻は、先の方を選ぶ。
DateTime instantOf(String zoneId, DateTime wall) {
  final location = _locationOf(zoneId);
  final converted = tz.TZDateTime(
    location,
    wall.year,
    wall.month,
    wall.day,
    wall.hour,
    wall.minute,
  );
  return DateTime.fromMillisecondsSinceEpoch(converted.millisecondsSinceEpoch);
}

/// 絶対時刻 [instant] の、[zoneId] での現地の日時。
DateTime wallOf(String zoneId, DateTime instant) {
  final converted = tz.TZDateTime.from(instant, _locationOf(zoneId));
  return DateTime(
    converted.year,
    converted.month,
    converted.day,
    converted.hour,
    converted.minute,
    converted.second,
  );
}

/// [instant] を、[zoneId] の現地時刻で [pattern] の書式にする。
///
/// 書式の言語は固定する（端末の言語で表記が変わらないように）。
String formatInZone(DateTime instant, String zoneId, String pattern) {
  return DateFormat(pattern, 'en_US').format(wallOf(zoneId, instant));
}

/// [wall] を [pattern] の書式にする。書式の言語は固定する。
String formatWall(DateTime wall, String pattern) =>
    DateFormat(pattern, 'en_US').format(wall);

/// [instant] の時点での、[zoneId] の UTC との差。
Duration offsetOf(String zoneId, DateTime instant) {
  final converted = tz.TZDateTime.from(instant, _locationOf(zoneId));
  return converted.timeZoneOffset;
}

/// `UTC+9`、`UTC-4`、`UTC+5:30` のような表記。
String utcOffsetLabel(String zoneId, DateTime instant) {
  final offset = offsetOf(zoneId, instant);
  final sign = offset.isNegative ? '-' : '+';
  final minutes = offset.inMinutes.abs();
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  final text = rest == 0
      ? '$hours'
      : '$hours:${rest.toString().padLeft(2, '0')}';
  return 'UTC$sign$text';
}

/// `Asia/Tokyo` → `Tokyo`（[languageCode] が `ja` なら `東京`）。
String cityNameOf(String zoneId, [String languageCode = 'en']) =>
    cityNameFor(zoneId, languageCode);

/// `Tokyo (UTC+9)` のような、選択肢と表示用の名前。
String zoneLabel(
  String zoneId,
  DateTime instant, [
  String languageCode = 'en',
]) =>
    '${cityNameOf(zoneId, languageCode)} '
    '(${utcOffsetLabel(zoneId, instant)})';

/// 旅程の入力で、先頭に並べる 12 都市。
const pinnedZoneIds = <String>[
  'Asia/Tokyo',
  'Europe/Paris',
  'America/New_York',
  'Australia/Sydney',
  'Europe/London',
  'Europe/Berlin',
  'Europe/Amsterdam',
  'Asia/Bangkok',
  'Europe/Athens',
  'America/Los_Angeles',
  'Europe/Rome',
  'Europe/Madrid',
];

const _regionPrefixes = [
  'Africa/',
  'America/',
  'Antarctica/',
  'Asia/',
  'Atlantic/',
  'Australia/',
  'Europe/',
  'Indian/',
  'Pacific/',
];

/// 選べるタイムゾーンの ID。古い別名（`US/Eastern` など）は含めない。
List<String> selectableZoneIds() {
  ensureTimeZonesInitialized();
  final ids =
      tz.timeZoneDatabase.locations.keys
          .where((id) => id == 'UTC' || _regionPrefixes.any(id.startsWith))
          .toList()
        ..sort();
  return ids;
}
