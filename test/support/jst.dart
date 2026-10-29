import 'package:koala/helper/time_zones.dart';

/// 東京の現地時刻 [year]-[month]-[day] [hour]:[minute] が指す絶対時刻。
///
/// 実行する機械のタイムゾーンに左右されないテストの日時を作る。
DateTime jst(int year, int month, int day, [int hour = 0, int minute = 0]) =>
    instantOf('Asia/Tokyo', DateTime(year, month, day, hour, minute));
