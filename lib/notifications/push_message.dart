import 'package:flutter/foundation.dart';

import '../l10n/app_localizations.dart';

/// 通知の種類。サーバー（Cloud Functions）の `NotificationType` と同じ値。
enum NotificationKind {
  /// フレンドが共同編集に参加した（オーナーへ）。
  joined,

  /// フレンドが共同編集から自分で抜けた（オーナーへ）。
  left,

  /// オーナーがしおりを削除した（参加者へ）。
  deleted,

  /// オーナーが共同編集を停止した（参加者へ）。
  stopped;

  /// サーバーが送る文字列から種類を取り出す。知らない値なら null。
  static NotificationKind? parse(String? value) {
    for (final kind in values) {
      if (kind.name == value) return kind;
    }
    return null;
  }
}

/// 届いた通知の中身（`data`）。しおりの名前とニックネームは、通知の文言を作る材料。
@immutable
class PushMessage {
  /// すべての項目を受け取る。
  const PushMessage({
    required this.kind,
    required this.leafletId,
    required this.title,
    required this.actor,
  });

  /// 通知の種類。
  final NotificationKind kind;

  /// しおりの ID。
  final String leafletId;

  /// しおりのタイトル。
  final String title;

  /// 参加した人（[NotificationKind.joined]）、抜けた人（[NotificationKind.left]）か、操作したオーナーのニックネーム。空なら、名前なしの文言。
  final String actor;

  /// 通知の `data` から作る。形が違えば null（知らない通知は、何もしない）。
  static PushMessage? fromData(Map<String, dynamic> data) {
    final kind = NotificationKind.parse(data['type'] as String?);
    final leafletId = data['leafletId'];
    if (kind == null || leafletId is! String || leafletId.isEmpty) return null;
    return PushMessage(
      kind: kind,
      leafletId: leafletId,
      title: data['title'] is String ? data['title'] as String : '',
      actor: data['actor'] is String ? data['actor'] as String : '',
    );
  }

  /// 通知を開く先が、しおり自体か。参加と脱退の通知は、そのしおりを開く。
  bool get opensLeaflet =>
      kind == NotificationKind.joined || kind == NotificationKind.left;

  /// アプリが前面にあるときに出す、見出し。
  String headline(AppLocalizations l10n) => switch (kind) {
    NotificationKind.joined => l10n.notifJoinedTitle,
    NotificationKind.left => l10n.notifLeftTitle,
    NotificationKind.deleted ||
    NotificationKind.stopped => l10n.notifUnavailableTitle,
  };

  /// アプリが前面にあるときに出す、本文。OS が出す通知（背面のとき）と、同じ文言。
  String body(AppLocalizations l10n) {
    final named = actor.isNotEmpty;
    return switch (kind) {
      NotificationKind.joined =>
        named
            ? l10n.notifJoinedBody(title, actor)
            : l10n.notifJoinedBodyAnonymous(title),
      NotificationKind.left =>
        named
            ? l10n.notifLeftBody(title, actor)
            : l10n.notifLeftBodyAnonymous(title),
      NotificationKind.deleted =>
        named
            ? l10n.notifDeletedBody(actor, title)
            : l10n.notifDeletedBodyAnonymous(title),
      NotificationKind.stopped =>
        named
            ? l10n.notifStoppedBody(actor, title)
            : l10n.notifStoppedBodyAnonymous(title),
    };
  }
}
