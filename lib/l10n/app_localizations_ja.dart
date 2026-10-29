// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appName => '旅のしおり';

  @override
  String get launchTagline => '家族や友人と、「旅のしおり」を一緒に作ろう';

  @override
  String get start => 'はじめる';

  @override
  String get connectFailed => '接続できませんでした。通信状況を確認して、もう一度お試しください。';

  @override
  String get portfolioNoticeTitle => 'ポートフォリオ専用のアプリです';

  @override
  String get portfolioNoticeBody =>
      'このアプリは開発者のポートフォリオとして公開しているもので、一般向けのサービスではありません。予告なく機能の変更や停止を行ったり、データを削除したりすることがあり、アプリが利用できなくなる場合があります。大切な情報は入力しないでください。';

  @override
  String get crashTestSent => 'テストのエラーを Crashlytics に送りました';

  @override
  String get launchAgreement => 'はじめると、利用規約と\nプライバシーポリシーに同意したものとします。';

  @override
  String get termsOfUse => '利用規約';

  @override
  String get privacyPolicy => 'プライバシーポリシー';

  @override
  String get legalOpenFailed => '文書を開けませんでした。ネットワークをご確認ください。';

  @override
  String get legalCopyUrl => 'URL をコピー';

  @override
  String get legalUrlCopied => 'URL をコピーしました';

  @override
  String get crashTestUnavailable => 'Crashlytics に接続していません';

  @override
  String get cancel => 'キャンセル';

  @override
  String get save => '保存';

  @override
  String get ok => 'OK';

  @override
  String get editMode => '編集';

  @override
  String get doneEditing => '編集を終える';

  @override
  String get editMark => 'この予定を編集';

  @override
  String get addToDay => 'この日に予定を追加';

  @override
  String get addAfterMark => 'この予定の後に追加';

  @override
  String get openNote => 'ノート';

  @override
  String get copy => 'コピー';

  @override
  String get delete => '削除する';

  @override
  String get keep => '削除しない';

  @override
  String get deleteWarning => '削除すると元には戻せません';

  @override
  String deleteQuestion(String title) {
    return '「$title」を削除する？';
  }

  @override
  String get joinTrip => 'しおりに参加する';

  @override
  String get newTrip => '新しいしおり';

  @override
  String get emptyTrips => 'まだしおりがありません。\n右上の ＋ で作るか、サンプルを追加して試せます。';

  @override
  String get addSamples => 'サンプルのしおりを追加';

  @override
  String get samplesSubtitle => '国内旅行 3 つと、地域別の海外旅行 5 つ';

  @override
  String get nickname => 'ニックネーム';

  @override
  String get nicknameNotSet => '未設定';

  @override
  String nicknameHelper(int max) {
    return 'ほかの人に表示される、あなたの名前です。通知にも使われます（$max 文字まで）';
  }

  @override
  String nicknameInvalid(int max) {
    return 'ニックネームは、1〜$max 文字で入力してください';
  }

  @override
  String get qrFilled => '読み取りました。ニックネームを確認して、「参加する」を押してください。';

  @override
  String get notifJoinedTitle => '共同編集に参加がありました';

  @override
  String notifJoinedBody(String title, String nickname) {
    return '「$title」に$nicknameが参加しました';
  }

  @override
  String notifJoinedBodyAnonymous(String title) {
    return '「$title」にフレンドが参加しました';
  }

  @override
  String get notifLeftTitle => '共同編集から脱退がありました';

  @override
  String notifLeftBody(String title, String nickname) {
    return '「$title」から$nicknameが脱退しました';
  }

  @override
  String notifLeftBodyAnonymous(String title) {
    return '「$title」からフレンドが脱退しました';
  }

  @override
  String get notifUnavailableTitle => 'しおりにアクセスできなくなりました';

  @override
  String notifDeletedBody(String owner, String title) {
    return '$ownerが「$title」を削除しました';
  }

  @override
  String notifDeletedBodyAnonymous(String title) {
    return '「$title」が削除されました';
  }

  @override
  String notifStoppedBody(String owner, String title) {
    return '$ownerが「$title」の共同編集を停止しました';
  }

  @override
  String notifStoppedBodyAnonymous(String title) {
    return '「$title」の共同編集が停止されました';
  }

  @override
  String get aboutApp => 'このアプリについて';

  @override
  String get joinedTrip => 'しおりに参加しました';

  @override
  String samplesAdded(int count) {
    return 'サンプルのしおりを $count つ追加しました';
  }

  @override
  String addingSamplesProgress(int completed, int total) {
    return '$completed / $total 件を書き込み中';
  }

  @override
  String buildLabel(String commit) {
    return 'ビルド：$commit';
  }

  @override
  String get newTripDialogTitle => '新しいしおり';

  @override
  String get titleLabel => 'タイトル';

  @override
  String get create => 'つくる';

  @override
  String get changeTitle => 'タイトルを変える';

  @override
  String get changeCover => '表紙を変える（絵文字）';

  @override
  String get sharedEditingSettings => '共同編集の設定（共有中）';

  @override
  String get startSharedEditing => '共同編集にする';

  @override
  String get deleteTrip => 'このしおりを削除する';

  @override
  String get leaveTrip => 'このしおりから抜ける';

  @override
  String get coverDialogTitle => '表紙の絵文字と背景色';

  @override
  String get emojiLabel => '絵文字を入力';

  @override
  String leaveQuestion(String title) {
    return '「$title」から抜ける？';
  }

  @override
  String get leaveBody => '一覧から消えます。しおり自体は残り、ID とあいことばがあればまた参加できます。';

  @override
  String get leave => '抜ける';

  @override
  String get taskSaveNickname => 'ニックネームの保存';

  @override
  String get taskCreateTrip => 'しおりの作成';

  @override
  String get taskAddSamples => 'サンプルの追加';

  @override
  String get taskUpdateTrip => 'しおりの更新';

  @override
  String get taskDeleteTrip => 'しおりの削除';

  @override
  String get taskEnableSharing => '共同編集の設定';

  @override
  String get taskDisableSharing => '共同編集の停止';

  @override
  String get taskLeaveTrip => 'しおりから抜ける操作';

  @override
  String get taskUpdatePeriod => 'しおりの期間の更新';

  @override
  String get taskAddPlan => '旅程の追加';

  @override
  String get taskUpdatePlan => '旅程の更新';

  @override
  String get taskDeletePlan => '旅程の削除';

  @override
  String get taskDeleteAccount => 'アカウントとデータの削除';

  @override
  String get deleteAccountTitle => 'アカウントとデータを削除';

  @override
  String get deleteAccountSubtitle => 'この端末の匿名アカウントと、サーバーにある自分のデータを消します';

  @override
  String get deleteAccountConfirmTitle => 'アカウントとデータを削除しますか？';

  @override
  String get deleteAccountConfirmBody =>
      'あなたがオーナーのしおりは、すべて削除されます（参加者にも見えなくなります）。参加しているしおりからは、抜けます。通知の登録と、匿名のユーザー ID、ニックネームも削除します。元には戻せません。\n\n他のしおりに書いた旅程とノートは、そのしおりに残ります。\n\n端末の中のキャッシュは、アプリを削除すると消えます。';

  @override
  String get deleteAccountProgress => '削除しています…';

  @override
  String get deleteAccountDone => 'アカウントとデータを削除しました。';

  @override
  String get deleteAccountUnavailable =>
      'アカウントが削除済み、またはログインが無効なため、ログイン状態を解除しました。サーバー上のデータ削除は確認できていません。';

  @override
  String get sessionLostTitle => 'ログインが無効になりました';

  @override
  String get sessionLostBody =>
      'このアカウントは削除されたか、ログインが無効になりました。起動画面に戻ります。「はじめる」を押すと、新しい匿名ユーザーで始められます。';

  @override
  String get sessionLostOnLaunchBody =>
      'このアカウントは削除されたか、ログインが無効になりました。「はじめる」を押すと、新しい匿名ユーザーで始められます。';

  @override
  String taskFailed(String task) {
    return '$taskに失敗しました。通信状況を確認してください。';
  }

  @override
  String taskUnconfirmed(String task) {
    return '$taskの結果を確認できませんでした。通信が戻ると反映される場合があります。';
  }

  @override
  String get noteSaveFailed => 'ノートを保存できませんでした。通信状況を確認してください。';

  @override
  String get noteResetUnconfirmed =>
      'ノートの初期化の結果を確認できませんでした。通信が戻ると反映される場合があります。';

  @override
  String get noteLimit => '1段落1000文字・500段落までです。変更は反映されませんでした。';

  @override
  String get noteUnsupported => 'テキストと文字の書式のみ使用できます。';

  @override
  String get noteReceivedLimit =>
      '受信したノートが上限を超えています。内容は保持しています。1段落1000文字・500段落以内になるよう減らしてください。';

  @override
  String get noteResetRemotely => 'ほかのメンバーがノートを初期化しました。';

  @override
  String get noteLineDeleted => '編集中の段落が、ほかのメンバーに削除されました。';

  @override
  String get noteUnreadable =>
      'このノートは現在の形式では読み込めません。破棄して空のノートから始めますか？元に戻すことはできません。';

  @override
  String get noteDiscard => 'ノートを破棄';

  @override
  String get noteRetry => '再試行';

  @override
  String get noteKeepEditing => '編集を続ける';

  @override
  String get noteLeaveUnsaved => '保存を待たずに閉じる';

  @override
  String get noteReadFailed => 'ノートを読み込めませんでした。通信状況を確認してください。';

  @override
  String get noteColorTitle => '文字の色';

  @override
  String get noteColorDefault => '既定の色に戻す';

  @override
  String get noteColorRed => '赤';

  @override
  String get noteColorOrange => 'オレンジ';

  @override
  String get noteColorGreen => '緑';

  @override
  String get noteColorTeal => '青緑';

  @override
  String get noteColorBlue => '青';

  @override
  String get noteColorPurple => '紫';

  @override
  String get noteColorPink => 'ピンク';

  @override
  String get noteColorBrown => '茶';

  @override
  String get tripIdInvalid => 'しおり ID は 12 文字です。入力を確認してください。';

  @override
  String passphraseTooShort(int min) {
    return 'あいことばは $min 文字以上で入力してください。';
  }

  @override
  String get joinInvalid => '入力を確認してください。';

  @override
  String get joinRejected => 'しおり ID かあいことばが違うか、共同編集が停止されています。';

  @override
  String get joinAlready => 'このしおりにはすでに参加しています。';

  @override
  String get joinNetwork => '通信に失敗しました。通信状況を確認してください。';

  @override
  String get joinUnconfirmed => '参加の結果を確認できませんでした。通信が戻ると反映される場合があります。';

  @override
  String get joinIdCheck => '公開用しおり ID の入力内容をお確かめください。';

  @override
  String get joinIntro =>
      'フレンドから教えてもらった QR コードを読み取るか、公開用しおり ID とあいことばを入力します。「参加する」を押すと、参加します。';

  @override
  String get scanQr => 'QR コードを読み取る';

  @override
  String get passphrase => 'あいことば';

  @override
  String get join => '参加する';

  @override
  String get cameraDenied =>
      'カメラの使用が許可されていません。設定で許可するか、前の画面で ID とあいことばを入力してください。';

  @override
  String get cameraFailed => 'カメラを使えませんでした。前の画面で ID とあいことばを入力してください。';

  @override
  String get notOurQr => 'このアプリの共同編集用の QR コードではありません';

  @override
  String get tripId => '公開用しおり ID';

  @override
  String get tripIdCheckInput => '入力内容をお確かめください（赤字の文字は使えません）';

  @override
  String get copied => 'コピーしました';

  @override
  String get stopSharingQuestion => '共同編集を停止する？';

  @override
  String get stopSharingBody =>
      '新しく参加できなくなり、参加していたほかの人は、このしおりから外れて見られなくなります。再び共同編集を有効にしたときは、もう一度参加してもらう必要があります。';

  @override
  String get tripNoLongerAvailable => 'このしおりは利用できなくなりました。共同編集が停止された可能性があります。';

  @override
  String get stop => '停止する';

  @override
  String get sharedEditing => '共同編集';

  @override
  String get changePassphraseIntro =>
      '新しいあいことばを決めます。すでに参加している人は、そのまま編集を続けられます。';

  @override
  String get enableSharingIntro =>
      '共同編集を有効にすると、公開用しおり ID とあいことばを知っている人が、このしおりに参加して一緒に編集できます。';

  @override
  String passphraseMinHelper(int min) {
    return '$min 文字以上';
  }

  @override
  String get generate => '自動で決める';

  @override
  String get changePassphrase => 'あいことばを変更する';

  @override
  String get enableSharing => '共同編集を有効にする';

  @override
  String get friendHint => 'フレンドは、この QR コードを読み取るか、上の ID とあいことばを入力すると参加できます。';

  @override
  String get qrWarning => 'QR コードにはあいことばが含まれます。信頼できる相手にだけ見せてください。';

  @override
  String get passphraseNotSaved =>
      'あいことばは、設定した端末にだけ保存されます。この端末には保存されていないため、ID とあいことばは再表示できません。新しいあいことばを設定してください。';

  @override
  String get stopSharing => '共同編集を停止する';

  @override
  String get endBeforeStart => '終了は開始より後にしてください';

  @override
  String get startLabel => '開始';

  @override
  String get endLabel => '終了';

  @override
  String get timeZone => 'タイムゾーン';

  @override
  String get approxLabel => '頃';

  @override
  String get approxMark => '頃';

  @override
  String get remarkLabel => '吹き出しメモ';

  @override
  String get linkLabel => 'リンク';

  @override
  String get iconLabel => 'アイコン';

  @override
  String get zoneSearchHint => '都市名で探す';

  @override
  String deviceZone(String id) {
    return '$id（端末）';
  }

  @override
  String othersEditing(int count) {
    return '他のメンバー（$count人）が編集中です';
  }
}
