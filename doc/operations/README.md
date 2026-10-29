# Firebase の運用

ポートフォリオアプリ用の Firebase プロジェクト `koala-portfolio` の構成、濫用への備え、通知の関数、掃除と終了の手順をまとめます。

## 構成

| 項目               | 内容                                                           |
| ------------------ | -------------------------------------------------------------- |
| プロジェクト       | `koala-portfolio`（Blaze プラン）                              |
| データベース       | Realtime Database（`asia-southeast1`）                         |
| 認証               | 匿名認証のみ                                                   |
| ルール             | database.rules.json（Emulator で検証）                         |
| 通知の関数         | `onMembersChange`（[下記](#通知の関数cloud-functions)）        |
| 掃除の関数         | `dailyCleanup`（[下記](#掃除)）                                |
| クラッシュレポート | Firebase Crashlytics（[下記](#クラッシュレポートcrashlytics)） |
| アプリの設定       | lib/firebase_options.dart（`flutterfire configure` で生成）    |

- Blaze プランは、通知と掃除の関数（Cloud Functions）のためです。予算アラートを設定しています（Google Cloud コンソールの「お支払い」→「予算とアラート」）。アラートは、メールで知らせるだけで、自動では止めません。
- 認証にサインアップの画面はありません。起動画面の「はじめる」で、匿名でサインインします。
- 関数はどちらも Cloud Functions の第 2 世代（Node.js 22）で、リージョンは `asia-southeast1` です。掃除は、毎日 4:00（日本時間）に Cloud Scheduler が動かします。
- Crashlytics は、アプリの想定外のエラーを集めます。

家族用の既存プロジェクトとは完全に分けています。このリポジトリにも、既存プロジェクトの設定は含みません。

## 濫用への備え

通知の関数は、データベースの書き込みでしか動かず、書き込みはルールで制限しています。掃除の関数は、Cloud Scheduler のジョブだけが呼べ、外から直接は呼べません。持ち主のいなくなったデータは、毎日の掃除で消します。
アプリには「ポートフォリオ専用のため、予告なく利用できなくなることがある」という説明を表示しています（起動画面と About）。
ノート保存や共同編集が失敗したときは、アプリが通知します（連続した失敗は 1 回だけ）。

## ノート形式の更新

旧形式（全文の `text`）と段落形式に書き込み互換性はありません。保存構造・入力上限・同期の動作は [共同編集ノート](../architecture/README.md#共同編集ノート) を参照してください。形式を更新するときは、次を確認します。

1. 配布前に、ルールのテストと新アプリのビルドを通します。ルールの本番反映と新APKの配布は、別の明示的な運用作業です。
2. 新ルールでは旧形式の `text` への保存を拒否します。旧APKの利用者には、新APKへの入れ替えが必要です。ルール反映前の新APKも、新形式を保存できません。
3. 旧形式や壊れたデータは自動変換しません。新アプリで確認ダイアログを表示し、利用者が破棄を選んだ場合だけ空の新形式へ置き換えます。元に戻せないことを表示し、キャンセルでは何も消しません。
4. 確認中に別の端末が内容を変えた場合は、その確認で破棄しません。初期化の世代を変え、古い保存要求が新しいノートを上書きすることを防ぎます。

容量の監視では、削除済み段落の挿入位置・削除記録も蓄積し、自動圧縮されない点に注意してください。しおりの削除・掃除ではノート全体を消します。画面を保存を待たずに閉じる選択や OS の強制終了では、未送信入力の保存は保証しません。

## 濫用への備え

匿名認証と、アプリに埋め込まれた API キーは、誰でも使えます。API キーは秘密ではなく、ルールが守りの本体です。

| リスク                     | 対策                                     |
| -------------------------- | ---------------------------------------- |
| 他人のしおりを読む・書く   | ルールでメンバーだけに限定               |
| あいことばの総当たり       | ハッシュだけを保存し、ルールの内部で照合 |
| 巨大データによる容量の消費 | ルールで各フィールドの長さと型を検証     |
| 作成時刻の偽装             | `createdAt` はサーバー時刻だけを許可     |
| API キーの悪用             | キーは識別用。守りの本体はルール         |
| App Check                  | 導入しない（既知の制限）                 |

- しおり ID は 12 文字の Crockford Base32（60 ビット）です。ID を知らない第三者は、あいことばを試せません。
- あいことばは、SHA-256 を 1 万回反復したハッシュだけを保存します。ただし、ルールだけでは試行の回数を制限できません。
- ノートの総段落数と見た目の文字数はアプリの制御で、改造クライアントによる総量までは保証しません。
- `createdAt` は、未来の値と後からの変更を拒否します。いまの掃除は使わず、作成時刻の記録として残しています。
- API キーの署名による制限と App Check は、CI のたびに署名が変わるデバッグ署名の APK では使えません。

残るリスクは「匿名ユーザーが大量にしおりを作って容量を埋める」ことです。
毎日の掃除は、持ち主のユーザーが Authentication にいなくなったしおりだけを消します。使われているしおりは、古くても消しません。
そのため、持ち主のアカウントが残っている間は、しおりも残ります。匿名アカウントは、次のいずれかで消えます。

- 自動：Authentication を Identity Platform にアップグレードして、自動クリーンアップを有効にしています（`koala-portfolio`）。作成から 30 日以上たった匿名アカウントが、自動で削除されます（[Anonymous Authentication](https://firebase.google.com/docs/auth/web/anonymous-auth#auto-cleanup)）。基準は作成からの日数で、最後に使った日ではありません。そのため、使っているアカウントも、作成から 30 日あまりで消え、そのアカウントがオーナーのしおりも、翌朝の掃除で消えます。
- 利用者：メニューの「アカウントとデータを削除」で、自分の匿名アカウントと、自分のデータを消します。
- 手動：Firebase コンソールの「Authentication」で、ユーザーを削除します。

アカウントが消えたあとは、翌朝 4:00 の掃除で、そのしおりと関連データが消えます。すぐに消したいときは、手動のツール（[下記](#掃除)）を使い、必要なら、コンソールで匿名認証を止めます。

## クラッシュレポート（Crashlytics）

アプリの想定外のエラーを、Firebase Crashlytics に送ります（[Get started](https://firebase.google.com/docs/crashlytics/flutter/get-started)）。

- 送信する情報と保存期間は [プライバシーポリシー](../legal/privacy.ja.html#collect) に集約しています。アプリがユーザー ID やしおりの内容を付けていないことは、[crash_reporter.dart](../../lib/crash_reporter.dart) で確認できます。
- 「はじめる」の前は送りません：Android のマニフェスト（`firebase_crashlytics_collection_enabled`、`firebase_messaging_auto_init_enabled`）と iOS の `Info.plist`（`FirebaseCrashlyticsCollectionEnabled`、`FirebaseMessagingAutoInitEnabled`）で、どちらも止めてあります。「はじめる」を押したあと（`connectToFirebase`。起動のたびに通る）に、[lib/helper/data_collection.dart](../../lib/helper/data_collection.dart) が有効にします。利用者が送信を止める設定は、ありません。
  - 確かめ方：実機で、`adb shell pm clear io.akmoor25.koala_portfolio` でアプリのデータ（Firebase の未送信の記録を含む）を消してから起動し、「はじめる」を押さずに、`adb logcat` に `TRuntime.CctTransportBackend`（Firebase の送信）の行が出ないことを確かめます。マニフェストと plist の値は、`test/unit/data_collection_test.dart` が検査します。
  - 確認の結果：Android（SM-X730）で、データを消してから起動し、「はじめる」の前に、送信の行が出ないことを確認しました（2026-10-17）。データを消さずに起動したときに出た送信は、以前の版で溜まった未送信の記録でした。
  - 限界：Android は、起動時に Firebase 自体が自動で初期化されます（送信はしません）。
- 送るもの：次の 3 種類です。
  - アプリが落ちたとき（Android と iOS のネイティブのクラッシュ。Crashlytics が自動で集める）。
  - Flutter のフレームワーク内のエラー（`FlutterError.onError`）。
  - どこにも捕捉されなかった非同期のエラー（`PlatformDispatcher.onError`）。この 2 つは、アプリが落ちないため、致命的でないエラーとして送ります。
- 実装：[lib/crash_reporter.dart](../../lib/crash_reporter.dart) が Crashlytics を包み、[lib/error_handlers.dart](../../lib/error_handlers.dart) が、ログに残すと同時に送ります。Firebase の初期化の前のエラーは、ログだけに残ります。送信の失敗で、エラーの処理が失敗することはありません。
- 確認の方法：「このアプリについて」の「ビルド」の行を長押しすると、テストのエラーを 1 件送ります。Firebase コンソールの「Crashlytics」に、数分で現れます（[Test your implementation](https://firebase.google.com/docs/crashlytics/flutter/test-implementation)）。
- 初めて使うとき：Firebase コンソールの「Crashlytics」を開き、「有効にする」を押します（1 回だけ）。
- Android：Gradle プラグイン（`com.google.firebase.crashlytics`）が、ビルドのときに設定します。デバッグ署名の APK でも送れます。
- iOS の制限：Windows 環境のため、dSYM をアップロードする Run Script のビルドフェーズを、Xcode で追加できていません。追加するまで、iOS のスタックトレースは、読めない形（シンボル化されない）で届きます（[Get started](https://firebase.google.com/docs/crashlytics/flutter/get-started)）。

## 通知の関数（Cloud Functions）

通知の判定・送信・再試行は [Cloud Functions の解説](../functions/README.md) に、ここではデプロイと確認の手順をまとめています。

- ソース：[functions/](../../functions/)（TypeScript）。通知はデータベースの変化、掃除は Cloud Scheduler を契機に動きます。
- デプロイ（手元の CLI。CI では行いません。秘密情報を CI に置かないため）：

  ```powershell
  firebase deploy --only functions,database --project koala-portfolio --force
  ```

  - `--force` は、再試行を有効にした関数のデプロイの確認を省きます。再試行と古いイベントの打ち切り条件は [関数の品質対策](../functions/README.md#4-品質のためのユースケース) を参照してください。
  - 初回は、Eventarc、Cloud Build などの API の有効化と、権限の反映に時間がかかり、失敗して、再実行が要ることがあります。掃除の関数（`dailyCleanup`）は、Cloud Scheduler の API も使います（ほとんどの Firebase プロジェクトで、すでに有効です）。デプロイすると、ジョブ `firebase-schedule-dailyCleanup-asia-southeast1` と、それが呼ぶ関数が作られます。
- ログの確認：

  ```powershell
  firebase functions:log --only onMembersChange --project koala-portfolio
  ```

  各実行の結果（種類、送った数、消したトークンの数）が、ログに残ります。通知の中身（ニックネーム、タイトル）は、ログに出しません。
- 容量の確認：1 回の通知で増える制御用の記録は数十バイトです。パスと寿命は [関数の記録一覧](../functions/README.md#5-データベースの記録の一覧)、削除対象は [掃除](#掃除) を参照してください。
- iOS で受け取るには（私の環境では未確認）：Apple Developer Program に加入し、Xcode で、Runner に Push Notifications の権限と、Background Modes の Remote notifications を追加します。Firebase コンソールの「プロジェクトの設定」→「Cloud Messaging」に、APNs の認証キーを登録します（[Firebase Cloud Messaging の Apple の設定](https://firebase.google.com/docs/cloud-messaging/ios/client)）。個人のチームでは、Push Notifications の権限が使えず、署名が通らなくなるため、プロジェクトには入れていません。

## 掃除

持ち主のユーザーが Authentication にいなくなったしおりと、その関連データを、消します。使われているしおりは、古くても消しません。
毎日 4:00（日本時間）に、Cloud Functions の `dailyCleanup`（Cloud Scheduler が呼ぶ）が、自動で行います。同じ処理を、手元から動かすツール（[tool/admin/cleanup.js](../../tool/admin/cleanup.js)）もあります。
処理は、[functions/src/cleanup.ts](../../functions/src/cleanup.ts) にあり、関数とツールが同じものを使います。

消すもの：

- 持ち主（`ownerUid`）が Authentication にいないしおりと、その旅程・ノート・カーソル・あいことば・メンバー・閉鎖の記録・各人の索引。参加者が残っていても消します（持ち主がいないしおりは、削除も、あいことばの変更も、できないため）。
- しおりが無いのに残っている、旅程・ノート・カーソル・あいことば・メンバー・閉鎖の記録、先がなくなった `userLeaflets` の索引。
- Authentication にいないユーザーの、端末のトークン（`users/{uid}`）と、自分のしおりの索引（`userLeaflets/{uid}`）。
- 作られて 1 日以上たった、通知の二重送信の防止と連打の抑制の記録（`notificationLog`、`notificationThrottle`）。

消さないもの：

- 持ち主の記録（`ownerUid`）が無いしおり。誰のものか判断できないためです。件数だけを、ログに残します。
- いなくなった参加者の、他人のしおりの中のメンバーの記録（`leafletMembers/{lid}/{uid}`）。消すと、オーナーに「脱退」の通知が飛ぶためです。

安全のための作りです。

- Authentication に問い合わせられなかったとき（障害、権限、上限など）は、何も消さずに失敗します。「見つかりませんでした」と答えられたユーザーだけを、いないものとして扱います。
- 持ち主のトークンは、しおりより先に消します。しおりを消すと、メンバーの記録の削除が、通知の関数を動かすためです。
- 失敗したら、次の日に、もう一度試します（再試行の設定はありません）。
- ログには、件数だけを残します（しおりのタイトルや ID は出しません）。

### 自動の掃除の確認

- ログ：

  ```powershell
  firebase functions:log --only dailyCleanup --project koala-portfolio
  ```

  `daily cleanup finished` の行に、消したしおりの数などが出ます。
- すぐに動かす：Google Cloud コンソールの「Cloud Scheduler」で、ジョブ `firebase-schedule-dailyCleanup-asia-southeast1` を「強制実行」します。
- 初めてデプロイしたあとは、先に手動のツール（確認だけ）で、何が消えるかを見てから、強制実行すると安全です。
- Cloud Functions の実行環境からのデータベースと Authentication への接続は、実際にデプロイして動かすまで、確かめられていません。最初の実行のログを、必ず確認してください。

### 手動のツール

ルールを通らない管理者権限で動くため、サービスアカウントのキーが要ります。キーはリポジトリに入れません。

1. Firebase コンソール →「プロジェクトの設定」→「サービス アカウント」→「新しい秘密鍵を生成」。
2. ダウンロードした JSON のパスを、環境変数に入れ、関数と同じ処理をビルドする。

```powershell
npm ci
npm --prefix functions ci
npm --prefix functions run build
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\secure\koala-portfolio-admin.json"
```

既定は確認だけで、何も消しません。

```powershell
# 何が消えるかを、一覧にする（何も消さない）
node tool/admin/cleanup.js --project koala-portfolio

# 実際に消す
node tool/admin/cleanup.js --project koala-portfolio --apply
```

| 引数             | 意味                                     |
| ---------------- | ---------------------------------------- |
| `--project`      | 必須。Firebase のプロジェクト ID         |
| `--database-url` | 別のリージョンなど、URL が既定と違うとき |
| `--apply`        | 付けたときだけ消す                       |

### テスト

掃除の処理は、Realtime Database の Emulator で、通知の関数のテストと一緒に動かします（実環境には触れません。Authentication への問い合わせは差し替えます）。

```powershell
npm run test:functions
```

## 脆弱性の確認

- 既知の脆弱性やマルウェアを含む依存パッケージは、GitHub Dependabot が検出して知らせます。Dependabot は毎週、依存パッケージ（アプリ、Cloud Functions）と Action の更新を提案します（[dependabot.yml](../../.github/dependabot.yml)）。秘密情報の混入は、CI が gitleaks で検査します（[.gitleaks.toml](../../.gitleaks.toml)）。
- 大きな脆弱性が公表されたときは、このアプリが使っている技術と通信先に照らして影響を調べ、結果をここに残します。

### 2026 年 10 月の事例
- PHP の RCE（「php2shell」、CVE-2026-109618 / CVE-2026-109619、CVSS 9.2）。認証なしで任意のコードを実行されるおそれ
  - [PHPの脆弱性対策について(CVE-2026-109618、CVE-2026-109619：PHP2shell)](https://www.ipa.go.jp/security/security-alert/2026/alert20261022.html)
  - 影響なし。PHP を使っていない（クライアントは Flutter、サーバーは Node.js 22 の Cloud Functions）
- eMudhra の中間証明書 8 件の秘密鍵が復元できた問題。任意のサイトになりすます証明書を作られるおそれ
  - [eMudhra: Private key compromise of Intermediate Certificates](https://bugzilla.mozilla.org/show_bug.cgi?id=2083449)
  - 影響なし。自前の証明書や信頼設定を持たず、通信先は Firebase（Google Trust Services の証明書）だけで、Android と iOS は OS 側で遮断済み。
  - 失効を確かめない Node.js の Cloud Functions には理論上のリスクが残るが、通信は Google のネットワーク内で完結するため、ランタイムの更新を待つ

## 法務文書の公開（GitHub Pages）

プライバシーポリシーと利用規約（日英）は、[doc/legal/](../legal/) にあり、  
公開リポジトリ `akmoor25/.github` の `koala/` を、GitHub Pages で公開しています  
（アプリが開く URL は、[lib/legal/legal_links.dart](../../lib/legal/legal_links.dart) の `legalBaseUrl`）。

文書を直したときは、先にこのリポジトリへ commit と push をしてから、次のスクリプトで公開ページへ反映します。

```powershell
powershell -ExecutionPolicy Bypass -File tool\publish_legal.ps1            # 反映して、公開内容を確かめる
powershell -ExecutionPolicy Bypass -File tool\publish_legal.ps1 -DryRun    # 差分を見るだけ（push しない）
```

[tool/publish_legal.ps1](../../tool/publish_legal.ps1) は、公開用リポジトリを一時フォルダにクローンし、`doc/legal/` をコピーして、差分があるときだけ commit と push をします。そのあと、公開された 4 ページが、手元と同じ内容かを確かめます（反映まで、1 分ほどかかることがあります）。差分が無ければ、確認だけを行います。

## ポートフォリオアプリの公開終了後

ポートフォリオアプリの公開を終了したら、次の順に片付けます。

1. 通知の関数と、掃除の関数を消す（呼び出されなくするため）。

   ```powershell
   firebase functions:delete onMembersChange dailyCleanup --region asia-southeast1 --project koala-portfolio --force
   ```

   掃除の関数のジョブ（`firebase-schedule-dailyCleanup-asia-southeast1`）が、Cloud Scheduler に残っていないかも、コンソールで確かめます。残っていたら消します。

2. データを全て消す。

   ```powershell
   firebase database:remove / --project koala-portfolio --force
   ```

3. 匿名ユーザーを消す。Firebase コンソール →「Authentication」→ ユーザーを全選択して削除。
   （止めるだけなら「Sign-in method」で匿名を無効にする）
4. プロジェクトごと消すなら（Blaze の課金も、止まります）、コンソールの「プロジェクトの設定」→「プロジェクトを削除」。
   30 日以内なら復元できます。
5. 配布した APK は Firebase に接続できなくなり、起動はするが、共同編集とノートの保存はできなくなります。

## 自分の Firebase で動かす

接続先を切り替える仕組み（`--dart-define` など）は作っていません。Android の `development` と `production` の flavor は、ビルドの名前を分けるだけで、どちらも同じ Firebase に接続します。差し替えは次の手順だけで済みます。

1. Firebase でプロジェクトを作り、Realtime Database（リージョンは任意）と匿名認証を有効にする。
2. 設定ファイルを作り直す。

   ```powershell
   flutterfire configure --project=<自分のプロジェクト ID>
   ```

   `lib/firebase_options.dart` が置き換わります。
3. ルールをデプロイする。

   ```powershell
   firebase deploy --only database --project <自分のプロジェクト ID>
   ```

接続先の URL は `firebase_options.dart` の `databaseURL` から読むため、リージョンが違っても追加の修正は要りません。
手動の掃除ツールだけは、リージョンが違うとき `--database-url` で URL を渡してください。通知と掃除の関数を自分のプロジェクトで使うときは、`functions/src/index.ts` の `REGION` も、データベースと同じリージョンにします。
