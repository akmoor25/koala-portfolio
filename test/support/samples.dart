import 'package:koala/data/sample_leaflets.dart';
import 'package:koala/entity/mark_entity.dart';

/// サンプルのしおり。並びは [buildSampleLeaflets] と同じにする（並びが変わったら、ここだけ直す）。
enum SampleTrip {
  okinawa,
  kyoto,
  hokkaido,
  asia,
  europe,
  mediterranean,
  americas,
  sydney,
}

final _samples = <String, List<SampleLeaflet>>{};

/// [languageCode] の言語のサンプル。画面の文字を探すのに使うため、日付は問わない。
List<SampleLeaflet> samplesIn([String languageCode = 'ja']) =>
    _samples.putIfAbsent(
      languageCode,
      () => buildSampleLeaflets(DateTime.now(), languageCode: languageCode),
    );

/// [trip] の、[languageCode] の言語での名前。
String sampleTitle(SampleTrip trip, [String languageCode = 'ja']) =>
    samplesIn(languageCode)[trip.index].title;

/// [trip] の旅程。
List<MarkEntity> sampleMarks(SampleTrip trip, [String languageCode = 'ja']) =>
    samplesIn(languageCode)[trip.index].marks;

/// [trip] で、初めて [zoneId] に着く移動の旅程。
MarkEntity sampleArrivalIn(
  SampleTrip trip,
  String zoneId, [
  String languageCode = 'ja',
]) => sampleMarks(
  trip,
  languageCode,
).firstWhere((mark) => mark.endZoneId == zoneId);
