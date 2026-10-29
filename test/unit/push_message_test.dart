import 'package:flutter_test/flutter_test.dart';
import 'package:koala/l10n/app_localizations_en.dart';
import 'package:koala/l10n/app_localizations_ja.dart';
import 'package:koala/notifications/push_message.dart';

void main() {
  final ja = AppLocalizationsJa();
  final en = AppLocalizationsEn();

  group('PushMessage.fromData', () {
    test('reads the kind, the trip and the names', () {
      final message = PushMessage.fromData({
        'type': 'joined',
        'leafletId': 'LID',
        'title': '北海道',
        'actor': 'ボブ',
      });

      expect(message?.kind, NotificationKind.joined);
      expect(message?.leafletId, 'LID');
      expect(message?.title, '北海道');
      expect(message?.actor, 'ボブ');
      expect(message?.opensLeaflet, isTrue);
    });

    test('closure notifications do not open the trip', () {
      for (final type in ['deleted', 'stopped']) {
        final message = PushMessage.fromData({'type': type, 'leafletId': 'L'});
        expect(message?.opensLeaflet, isFalse, reason: type);
      }
    });

    test('ignores unknown or incomplete notifications', () {
      expect(PushMessage.fromData({}), isNull);
      expect(
        PushMessage.fromData({'type': 'unknown', 'leafletId': 'L'}),
        isNull,
      );
      expect(PushMessage.fromData({'type': 'joined'}), isNull);
      expect(PushMessage.fromData({'type': 'joined', 'leafletId': ''}), isNull);
    });

    test('missing names become empty', () {
      final message = PushMessage.fromData({
        'type': 'deleted',
        'leafletId': 'L',
      });
      expect(message?.title, '');
      expect(message?.actor, '');
    });
  });

  group('texts follow the language', () {
    PushMessage message(String type, {String actor = 'アキ'}) => PushMessage(
      kind: NotificationKind.parse(type)!,
      leafletId: 'L',
      title: '北海道',
      actor: actor,
    );

    test('joined', () {
      expect(message('joined').headline(ja), '共同編集に参加がありました');
      expect(message('joined').body(ja), '「北海道」にアキが参加しました');
      expect(
        const PushMessage(
          kind: NotificationKind.joined,
          leafletId: 'L',
          title: 'Hokkaido',
          actor: 'Aki',
        ).body(en),
        'Aki joined "Hokkaido"',
      );
    });

    test('left', () {
      expect(message('left').headline(ja), '共同編集から脱退がありました');
      expect(message('left').body(ja), '「北海道」からアキが脱退しました');
      expect(message('left', actor: '').body(ja), '「北海道」からフレンドが脱退しました');
      expect(
        const PushMessage(
          kind: NotificationKind.left,
          leafletId: 'L',
          title: 'Hokkaido',
          actor: 'Aki',
        ).body(en),
        'Aki left "Hokkaido"',
      );
      expect(message('left').opensLeaflet, isTrue);
    });

    test('deleted and stopped share the headline', () {
      expect(message('deleted').headline(ja), 'しおりにアクセスできなくなりました');
      expect(message('stopped').headline(ja), 'しおりにアクセスできなくなりました');
      expect(message('deleted').body(ja), 'アキが「北海道」を削除しました');
      expect(message('stopped').body(ja), 'アキが「北海道」の共同編集を停止しました');
    });

    test('without a name, the nameless wording is used', () {
      expect(message('joined', actor: '').body(ja), '「北海道」にフレンドが参加しました');
      expect(message('deleted', actor: '').body(ja), '「北海道」が削除されました');
      expect(message('stopped', actor: '').body(ja), '「北海道」の共同編集が停止されました');
    });

    test('the same text as the system notification in English', () {
      const trip = 'Kyoto';
      expect(
        const PushMessage(
          kind: NotificationKind.stopped,
          leafletId: 'L',
          title: trip,
          actor: 'Aki',
        ).body(en),
        'Aki stopped shared editing of "Kyoto"',
      );
      expect(
        const PushMessage(
          kind: NotificationKind.deleted,
          leafletId: 'L',
          title: trip,
          actor: '',
        ).body(en),
        '"Kyoto" was deleted',
      );
    });
  });
}
