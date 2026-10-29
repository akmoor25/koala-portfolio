import 'dart:convert';

import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/data/sample_leaflets.dart';
import 'package:koala/entity/mark_entity.dart';
import 'package:koala/helper/current_step.dart';
import 'package:koala/helper/time_zones.dart';
import 'package:koala/leaflets/leaflets_model.dart';
import 'package:koala/notes/note_colors.dart';
import 'package:koala/notes/note_document.dart';

import '../support/demo_database.dart';
import '../support/samples.dart';

const _home = 'Asia/Tokyo';

/// 旅程のどこにも、東京以外のタイムゾーンが無い（国内の）旅か。
bool _isDomestic(SampleLeaflet sample) => sample.marks.every(
  (mark) => mark.startZoneId == _home && mark.endZoneId == _home,
);

void main() {
  final now = instantOf('Asia/Tokyo', DateTime(2026, 10, 10, 12, 30));

  group('buildSampleLeaflets', () {
    final samples = buildSampleLeaflets(now);
    final domestic = samples.takeWhile(_isDomestic).toList();
    final abroad = samples.skip(domestic.length).toList();

    test('names are unique, and domestic trips come first', () {
      final titles = samples.map((s) => s.title).toList();
      expect(titles, everyElement(isNotEmpty));
      expect(titles.toSet(), hasLength(titles.length));
      expect(domestic, isNotEmpty);
      expect(abroad, isNotEmpty);
      expect(abroad.where(_isDomestic), isEmpty, reason: '国内の旅は、先にまとめて並ぶ');
    });

    test('SampleTrip (used by the widget tests) follows the order', () {
      expect(domestic.length, SampleTrip.asia.index);
      final asia = samples[SampleTrip.asia.index];
      expect(asia.marks.map((m) => m.endZoneId), contains('Asia/Seoul'));
    });

    test('domestic trips last three days', () {
      for (final sample in domestic) {
        final days = {
          for (final mark in sample.marks)
            DateTime(
              wallOf(mark.startZoneId, mark.startDate).year,
              wallOf(mark.startZoneId, mark.startDate).month,
              wallOf(mark.startZoneId, mark.startDate).day,
            ),
        }.toList()..sort();
        expect(days, hasLength(3), reason: sample.title);
        expect(days.last.difference(days.first).inDays, 2);
      }
    });

    test('marks are in order and each ends after it starts', () {
      for (final sample in samples) {
        final starts = sample.marks.map((m) => m.startDate).toList();
        expect([...starts]..sort(), starts, reason: sample.title);
        for (final mark in sample.marks) {
          expect(mark.endDate!.isAfter(mark.startDate), isTrue);
        }
      }
    });

    test('each trip abroad stays in one region besides Tokyo', () {
      for (final sample in abroad) {
        final zones = {
          for (final mark in sample.marks) ...[
            mark.startZoneId,
            mark.endZoneId,
          ],
        };
        for (final zone in zones) {
          expect(isValidZoneId(zone), isTrue, reason: zone);
        }
        final regions = {
          for (final zone in zones)
            if (zone != _home) zone.split('/').first,
        };
        expect(regions, hasLength(1), reason: '${sample.title}: $zones');
      }
    });

    test('the trips abroad cover all the pinned cities', () {
      final zones = {
        for (final sample in abroad)
          for (final mark in sample.marks) ...[
            mark.startZoneId,
            mark.endZoneId,
          ],
      };
      expect(zones, containsAll(pinnedZoneIds));
    });

    test('every trip abroad comes back to Tokyo', () {
      for (final sample in abroad) {
        expect(sample.marks.last.endZoneId, _home, reason: sample.title);
      }
    });

    test('regional transfers arrive before the next stop', () {
      for (final sample in abroad) {
        final transfers = sample.marks
            .where((mark) => mark.endTimeZoneId.isNotEmpty)
            .toList();
        expect(transfers, isNotEmpty, reason: sample.title);
        for (final transfer in transfers) {
          expect(transfer.endZoneId, isNot(transfer.startZoneId));
          final index = sample.marks.indexOf(transfer);
          // 帰国の便は、旅の最後の旅程。
          if (index == sample.marks.length - 1) continue;
          final next = sample.marks[index + 1];
          expect(
            next.startDate.isAfter(transfer.endDate!),
            isTrue,
            reason: '${transfer.title} の到着の後に ${next.title}',
          );
        }
      }
    });

    test('has varied covers, dense plans, and detailed remarks', () {
      expect(
        samples.map((sample) => sample.emoji).toSet(),
        hasLength(samples.length),
      );
      for (final sample in domestic) {
        expect(sample.marks.length, greaterThanOrEqualTo(14));
      }
      for (final sample in abroad) {
        expect(
          sample.marks.length,
          greaterThanOrEqualTo(26),
          reason: sample.title,
        );
        expect(
          sample.marks.where((mark) => mark.remark.length >= 40).length,
          greaterThanOrEqualTo(4),
          reason: sample.title,
        );
        expect(sample.noteText.length, greaterThanOrEqualTo(300));
      }
    });

    test('fits the length limits of the database rules', () {
      for (final sample in samples) {
        expect(sample.title.length, lessThanOrEqualTo(100));
        for (final mark in sample.marks) {
          expect(mark.title.length, lessThanOrEqualTo(200));
          expect(mark.remark.length, lessThanOrEqualTo(2000));
        }
      }
    });

    test('the notes are valid Quill documents within the editing limits', () {
      for (final sample in samples) {
        final ops = jsonDecode(sample.noteText) as List<Object?>;
        expect(ops, isNotEmpty);
        expect((ops.last! as Map<String, Object?>)['insert'], '\n');
        expect(
          acceptsNoteChange(Delta()..insert('\n'), Delta.fromJson(ops)),
          isTrue,
          reason: sample.title,
        );
      }
    });

    test(
      'stay consistent across daylight saving changes, whenever created',
      () {
        // 夏時間の切り替えをまたぐ日付を含めて、旅程の前後関係が崩れないこと。
        for (var days = 0; days < 800; days += 9) {
          final created = now.add(Duration(days: days));
          for (final sample in buildSampleLeaflets(created)) {
            for (var i = 0; i < sample.marks.length - 1; i++) {
              final mark = sample.marks[i];
              final next = sample.marks[i + 1];
              final reason = '$days日後 ${sample.title}: ${mark.title}';
              expect(
                mark.endDate!.isAfter(mark.startDate),
                isTrue,
                reason: reason,
              );
              expect(
                next.startDate.isAfter(mark.startDate),
                isTrue,
                reason: reason,
              );
              if (mark.endTimeZoneId.isNotEmpty) {
                expect(
                  next.startDate.isAfter(mark.endDate!),
                  isTrue,
                  reason: reason,
                );
              }
            }
          }
        }
      },
    );

    test(
      'Okinawa and Hokkaido are ahead, Sydney is under way, the rest are over',
      () {
        List<MarkEntity> marksOf(SampleTrip trip) => samples[trip.index].marks;

        for (final trip in [SampleTrip.okinawa, SampleTrip.hokkaido]) {
          expect(marksOf(trip).first.startDate.isAfter(now), isTrue);
        }
        expect(
          marksOf(SampleTrip.sydney).first.startDate.isBefore(now),
          isTrue,
        );
        expect(marksOf(SampleTrip.sydney).last.endDate!.isAfter(now), isTrue);
        for (final trip in [
          SampleTrip.kyoto,
          SampleTrip.asia,
          SampleTrip.europe,
          SampleTrip.mediterranean,
          SampleTrip.americas,
        ]) {
          expect(marksOf(trip).last.endDate!.isBefore(now), isTrue);
        }
      },
    );

    test('Sydney shows both a current and a next step', () {
      final step = resolveCurrentStep(
        samples[SampleTrip.sydney.index].marks,
        now,
        startOf: (m) => m.startDate,
        endOf: (m) => m.endDate,
      );
      expect(step.current, isNotNull);
      expect(step.next, isNotNull);
    });

    test('the notes use rich formatting', () {
      for (final sample in samples) {
        final attributes = <String>{
          for (final op in jsonDecode(sample.noteText) as List<Object?>)
            ...?((op! as Map<String, Object?>)['attributes']
                    as Map<String, Object?>?)
                ?.entries
                .map((e) => e.key == 'list' ? 'list:${e.value}' : e.key),
        };
        expect(
          attributes,
          containsAll(['header', 'bold', 'blockquote']),
          reason: sample.title,
        );
        expect(
          attributes.where((a) => a.startsWith('list:')),
          isNotEmpty,
          reason: sample.title,
        );
      }
      final all = {
        for (final sample in samples)
          for (final op in jsonDecode(sample.noteText) as List<Object?>)
            ...?((op! as Map<String, Object?>)['attributes']
                    as Map<String, Object?>?)
                ?.entries
                .map((e) => e.key == 'list' ? 'list:${e.value}' : e.key),
      };
      // サンプル全体で、エディタの主な書式を一通り使う。
      expect(
        all,
        containsAll([
          'color',
          'underline',
          'strike',
          'link',
          'indent',
          'list:bullet',
          'list:ordered',
          'list:checked',
          'list:unchecked',
        ]),
      );
      // 背景色は、文字色との組み合わせで読めなくなるため使わない。
      expect(all, isNot(contains('background')));
    });

    test('note text colors come only from the readable palette', () {
      final palette = NoteTextColor.values.map((c) => c.hex).toSet();
      for (final sample in samples) {
        for (final op in jsonDecode(sample.noteText) as List<Object?>) {
          final attributes =
              (op! as Map<String, Object?>)['attributes']
                  as Map<String, Object?>?;
          final color = attributes?['color'];
          if (color != null) {
            expect(palette, contains(color), reason: sample.title);
          }
        }
      }
    });
  });

  group('installSampleLeaflets', () {
    test('adds all leaflets with marks, notes and dates', () async {
      final services = DemoDatabase().servicesFor('newcomer');

      final count = await installSampleLeaflets(
        leaflets: services.leaflets,
        marks: services.marks,
        notes: services.notes,
        now: now,
      );
      final leaflets = await services.leaflets.watchLeaflets().first;
      final samples = buildSampleLeaflets(now);

      expect(count, samples.length);
      expect(leaflets.map((l) => l.title), samples.map((s) => s.title));
      // 海外の旅も、東京から出発して、東京へ帰る。
      final lastAbroad = leaflets.last;
      expect(lastAbroad.firstTimeZoneId, 'Asia/Tokyo');
      expect(lastAbroad.lastTimeZoneId, 'Asia/Tokyo');
      for (final leaflet in leaflets) {
        expect(leaflet.ownerUid, 'newcomer');
        expect(leaflet.firstDate, isNotNull);
        expect(leaflet.lastDate!.isAfter(leaflet.firstDate!), isTrue);
        expect(leaflet.coverColor, isNotNull);
        expect(await services.marks.watchMarks(leaflet.key).first, isNotEmpty);
        expect(await services.notes.watchNote(leaflet.key).first, isNotNull);
      }
    });

    test('the list shows Next, Now and the past years in order', () async {
      final services = DemoDatabase().servicesFor('newcomer');
      await installSampleLeaflets(
        leaflets: services.leaflets,
        marks: services.marks,
        notes: services.notes,
        now: now,
      );
      final leaflets = sortLeaflets(
        await services.leaflets.watchLeaflets().first,
        now,
      );
      final groups = {
        for (final name in groupNamesOf(leaflets, now))
          name: [
            for (final leaflet in leafletsInGroup(leaflets, name, now))
              leaflet.title,
          ],
      };

      String title(SampleTrip trip) => sampleTitle(trip);
      expect(groups, {
        'Next': [title(SampleTrip.okinawa), title(SampleTrip.hokkaido)],
        'Now': [title(SampleTrip.sydney)],
        '2026': [title(SampleTrip.americas), title(SampleTrip.mediterranean)],
        '2025': [
          title(SampleTrip.europe),
          title(SampleTrip.asia),
          title(SampleTrip.kyoto),
        ],
      });
      expect(groups.keys, orderedEquals(['Next', 'Now', '2026', '2025']));
    });

    test('reports write progress through completion', () async {
      final services = DemoDatabase().servicesFor('newcomer');
      final updates = <SampleInstallProgress>[];

      await installSampleLeaflets(
        leaflets: services.leaflets,
        marks: services.marks,
        notes: services.notes,
        now: now,
        onProgress: updates.add,
      );

      expect(updates.first.completed, 0);
      expect(updates.last.completed, updates.last.total);
      expect(updates.last.fraction, 1);
      expect(
        updates.map((update) => update.completed),
        orderedEquals(List.generate(updates.length, (index) => index)),
      );
    });
  });
}
