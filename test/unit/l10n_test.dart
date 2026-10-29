import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/data/sample_leaflets.dart';
import 'package:koala/data/sample_texts_en.dart';
import 'package:koala/helper/time_zones.dart';
import 'package:koala/l10n/city_names.dart';
import 'package:koala/l10n/l10n.dart';
import 'package:koala/l10n/write_task.dart';

final _cjk = RegExp(r'[\u3040-\u30ff\u3400-\u9fff]');

void main() {
  group('resolveAppLocale', () {
    Locale resolve(List<Locale>? locales) =>
        resolveAppLocale(locales, supportedAppLocales);

    test('a Japanese device gets Japanese', () {
      expect(resolve(const [Locale('ja', 'JP')]).languageCode, 'ja');
      expect(resolve(const [Locale('ja')]).languageCode, 'ja');
      expect(
        resolve([
          const Locale.fromSubtags(languageCode: 'ja', scriptCode: 'Jpan'),
        ]).languageCode,
        'ja',
      );
    });

    test('every other language gets English', () {
      for (final locale in const [
        Locale('en', 'US'),
        Locale('en', 'GB'),
        Locale('fr', 'FR'),
        Locale('zh', 'CN'),
        Locale('ko', 'KR'),
        Locale('de'),
      ]) {
        expect(resolve([locale]).languageCode, 'en', reason: '$locale');
      }
    });

    test('English is the default when the device reports nothing', () {
      expect(resolve(null).languageCode, 'en');
      expect(resolve(const []).languageCode, 'en');
    });

    test('only the first language of the device counts', () {
      expect(
        resolve(const [Locale('en', 'US'), Locale('ja', 'JP')]).languageCode,
        'en',
      );
      expect(
        resolve(const [Locale('ja', 'JP'), Locale('en', 'US')]).languageCode,
        'ja',
      );
    });

    test('the app supports exactly English and Japanese', () {
      expect(
        AppLocalizations.supportedLocales.map((l) => l.languageCode),
        unorderedEquals(['en', 'ja']),
      );
    });
  });

  group('messages', () {
    test('a write failure names the task in each language', () {
      expect(
        AppLocalizationsEn().writeFailed(WriteTask.addPlan),
        'Adding the plan failed. Check your connection.',
      );
      expect(
        AppLocalizationsJa().writeFailed(WriteTask.addPlan),
        contains('旅程の追加'),
      );
    });

    test('plurals follow English grammar', () {
      final en = AppLocalizationsEn();
      expect(en.samplesAdded(1), 'Added 1 sample trip');
      expect(en.samplesAdded(4), 'Added 4 sample trips');
      expect(en.othersEditing(1), '1 other member is editing');
      expect(en.othersEditing(3), '3 other members are editing');
    });

    test('Japanese messages carry the numbers', () {
      final ja = AppLocalizationsJa();
      expect(ja.samplesAdded(4), contains('4'));
      expect(ja.othersEditing(2), contains('2'));
      expect(ja.passphraseTooShort(8), contains('8'));
    });

    test('the English messages contain no Japanese', () {
      final en = AppLocalizationsEn();
      for (final text in [
        en.appName,
        en.launchTagline,
        en.portfolioNoticeBody,
        en.emptyTrips,
        en.joinIntro,
        en.passphraseNotSaved,
        en.deleteWarning,
      ]) {
        expect(_cjk.hasMatch(text), isFalse, reason: text);
      }
    });
  });

  group('city names', () {
    test('the 12 cities have Japanese names', () {
      for (final id in pinnedZoneIds) {
        expect(cityNameFor(id, 'ja'), matches(_cjk), reason: id);
        expect(cityNameFor(id, 'en'), isNot(matches(_cjk)), reason: id);
      }
    });

    test('shows the requested cities in each language', () {
      expect(cityNameFor('Asia/Tokyo', 'ja'), '東京');
      expect(cityNameFor('Asia/Tokyo', 'en'), 'Tokyo');
      expect(cityNameFor('America/New_York', 'ja'), 'ニューヨーク');
      expect(cityNameFor('America/New_York', 'en'), 'New York');
      expect(cityNameFor('Asia/Seoul', 'ja'), 'ソウル');
      expect(cityNameFor('Asia/Taipei', 'ja'), '台北');
      expect(cityNameFor('Europe/Brussels', 'ja'), 'ブリュッセル');
      expect(cityNameFor('America/Toronto', 'ja'), 'トロント');
    });

    test('a city without a Japanese name falls back to English', () {
      expect(cityNameFor('Asia/Shanghai', 'ja'), 'Shanghai');
    });

    test('labels follow the language', () {
      final instant = DateTime.utc(2026, 1, 1);
      expect(zoneLabel('Europe/Paris', instant, 'ja'), 'パリ (UTC+1)');
      expect(zoneLabel('Europe/Paris', instant, 'en'), 'Paris (UTC+1)');
    });
  });

  group('sample trips', () {
    final now = DateTime.utc(2026, 10, 10, 3);
    final ja = buildSampleLeaflets(now);
    final en = buildSampleLeaflets(now, languageCode: 'en');

    test('have the same shape in both languages', () {
      expect(en.length, ja.length);
      for (var i = 0; i < ja.length; i++) {
        expect(en[i].marks.length, ja[i].marks.length);
        for (var j = 0; j < ja[i].marks.length; j++) {
          // 時刻は言語に依らない。
          expect(en[i].marks[j].startDate, ja[i].marks[j].startDate);
          expect(en[i].marks[j].endDate, ja[i].marks[j].endDate);
          expect(en[i].marks[j].timeZoneId, ja[i].marks[j].timeZoneId);
        }
      }
    });

    test('every English text is translated', () {
      for (final sample in en) {
        expect(sample.title, isNot(matches(_cjk)), reason: sample.title);
        for (final mark in sample.marks) {
          expect(mark.title, isNot(matches(_cjk)), reason: mark.title);
          expect(mark.remark, isNot(matches(_cjk)), reason: mark.remark);
        }
        final ops = jsonDecode(sample.noteText) as List<Object?>;
        for (final op in ops) {
          final insert = (op! as Map<String, Object?>)['insert']! as String;
          expect(insert, isNot(matches(_cjk)), reason: insert);
        }
      }
    });

    test('the translation table has no unused entries', () {
      final used = <String>{};
      for (final sample in ja) {
        used.add(sample.title);
        for (final mark in sample.marks) {
          used
            ..add(mark.title)
            ..add(mark.remark);
        }
        final ops = jsonDecode(sample.noteText) as List<Object?>;
        for (final op in ops) {
          used.add((op! as Map<String, Object?>)['insert']! as String);
        }
      }
      final unused = sampleTextsEn.keys.where((key) => !used.contains(key));
      expect(unused, isEmpty);
    });

    test('keep the database length limits in English too', () {
      for (final sample in en) {
        expect(sample.title.length, lessThanOrEqualTo(100));
        for (final mark in sample.marks) {
          expect(mark.title.length, lessThanOrEqualTo(200));
          expect(mark.remark.length, lessThanOrEqualTo(2000));
        }
      }
    });
  });
}
