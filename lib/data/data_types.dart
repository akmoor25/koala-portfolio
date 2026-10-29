import '../notes/remote_caret.dart';

/// 認証されたユーザー。
class AppUser {
  /// [uid] はユーザーを一意に表し、[name] は共同編集で他の人に見せる名前。
  const AppUser({required this.uid, this.name});

  /// ユーザーを一意に表す ID。
  final String uid;

  /// ニックネーム。まだ決めていなければ null。
  final String? name;
}

/// 共同編集への参加に失敗した理由。
enum JoinFailureReason {
  /// しおり ID かあいことばの形式が正しくない。
  invalidInput,

  /// ID またはあいことばが違う、または共同編集が停止されている。
  ///
  /// 総当たりの手がかりを与えないよう、どちらが違うかは区別しない。
  rejected,

  /// すでにそのしおりのメンバーである。
  alreadyJoined,

  /// 通信に失敗した。
  network,

  /// 参加の書き込みを送ったが、サーバーの結果を確認できなかった。
  unconfirmed,
}

/// しおりへの参加に失敗したことを表す。
class JoinFailure implements Exception {
  /// 失敗の理由を指定して作る。
  const JoinFailure(this.reason);

  /// 失敗の理由。
  final JoinFailureReason reason;

  @override
  String toString() => 'JoinFailure($reason)';
}

/// 送信済みの書き込みについて、待機の上限までにサーバーの結果を確認できなかった。
///
/// 待機をやめても送信は取り消されないため、失敗ではなく結果不明として扱う。
/// 通信が戻った後に反映される場合がある。
class WriteUnconfirmed implements Exception {
  /// 何も受け取らない。
  const WriteUnconfirmed();

  @override
  String toString() => 'WriteUnconfirmed';
}

/// 自分以外のメンバーの編集状況。
class Collaborators {
  /// [editingCount] 人が開いていて、そのうち [carets] がカーソルを持つ。
  const Collaborators({required this.editingCount, required this.carets});

  /// 誰もいない状態。
  static const none = Collaborators(editingCount: 0, carets: []);

  /// ノートを開いている自分以外のメンバー数（フォーカスなしも含む）。
  final int editingCount;

  /// エディタにフォーカスがあるメンバーのカーソル。
  final List<RemoteCaret> carets;
}
