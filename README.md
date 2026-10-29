# 旅のしおりアプリ

家族や友人と、旅の予定（旅程）とメモ（ノート）を、リアルタイムに共同編集できる「旅のしおり」アプリです。Flutter（Android と iOS のアプリを、1 つのソースから作る仕組み）で作り、iOS と Android で動きます。

## 1. このリポジトリについて

本リポジトリは、個人開発アプリのソースコードと設計を紹介するポートフォリオです。

- 本アプリはポートフォリオ専用です。予告なく機能の変更や停止、データの削除を行うことがあり、アプリが利用できなくなる場合があります。大切な情報は入力しないでください。
- App Store・Google Play では配布していません。
- Issue やプルリクエストは受け付けていません。
- 利用条件は [ライセンス](#8-ライセンス) を参照してください。

この README が全体の概要です。初めての方は、[3. 主な機能](#3-主な機能) と [7. ギャラリー](#7-ギャラリー) で何ができるアプリかを見てから、必要な文書へ進むと読みやすいです。各分野の詳細は、次の文書に分けてまとめています。

| 読みたいこと                                                    | ドキュメント                                                                                   |
| --------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| 設計の理由・データモデル・ノート同期・テスト方針・既知の制限    | [アーキテクチャと設計](doc/architecture/README.md)                                             |
| 通知の判定・送信・再試行とサーバー処理の流れ                    | [Cloud Functions の解説](doc/functions/README.md)                                              |
| Firebase の設定・監視・掃除・公開終了                           | [Firebase の運用](doc/operations/README.md)                                                    |
| 手元の検査・CI（自動の検査）の起動条件・APK・撮影              | [CI/CD の仕組み](doc/ci_cd/README.md)                                                          |
| 利用条件・取得する情報・保存期間と削除                          | [利用規約](doc/legal/terms.ja.html)・[プライバシーポリシー](doc/legal/privacy.ja.html)（日英） |

## 2. デモ動画

Android と iOS の 2 台で、1 つのしおりを共同編集している様子です。

<video src="https://github.com/user-attachments/assets/e7c0a7a4-9b3a-4c84-b296-155bdb85d7f0" width="720" autoplay loop muted playsinline>
  <a href="https://github.com/user-attachments/assets/e7c0a7a4-9b3a-4c84-b296-155bdb85d7f0">デモ動画（mp4）</a>
</video>

## 3. 主な機能

- 旅程タイムライン：予定を現地の時刻で時系列に並べ、「いま」（進行中の予定）と「つぎ」（次の予定）に印を付けます。アプリを開かなくても、ホーム画面ウィジェットで「いま・つぎ」を確認できます。
- 共同編集：アカウントを登録しない匿名のまま、QR コードか、しおりの ID と「あいことば」（しおりごとに決める合言葉）で参加し、旅程とノートを一緒に編集できます。
- ノートの同期：2 人が同じノートを同時に書くと、相手の保存で自分の入力が消えてしまうことがあります。そこで、ノートを段落ごとに同期し、ぶつかるのは同じ段落を同時に直したときだけにしました。そのときは、後から保存したほうが残り（後勝ち）、削除は編集より優先します。
- 通知：参加・脱退・削除・共同編集の停止を、プッシュ通知で知らせます（Android で確認）。
- そのほか：日本語・英語、オフラインでの閲覧・編集、絵文字の表紙に対応します。利用規約とプライバシーポリシーをアプリから開け、自分のアカウントとデータも削除できます。

試すときは、 [最新APK](https://github.com/akmoor25/koala-portfolio/releases) を入れて「はじめる」を押し、一覧の「サンプルのしおりを追加」で始めます。共同編集は、しおりを長押しして有効にし、別の端末の「しおりに参加する」から、QR コードか ID とあいことばで参加します。各機能の制限は、[アーキテクチャと設計](doc/architecture/README.md#トレードオフと今後の課題) にまとめています。

## 4. 技術スタック

独自のサーバーを持つと、外から呼べる窓口が増え、守る範囲が広がります。そこで、サーバーは Firebase（Google のアプリ向けクラウドサービス）にまとめ、アプリから直接読み書きし、データの守りはセキュリティルール（Firebase がサーバー側で行う、読み書きの検査）に置きました。構成と判断の理由は、[アーキテクチャと設計](doc/architecture/README.md) にあります。

| 分類         | 使用技術                                                                                                                                                    |
| ------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| アプリ       | Flutter / Dart, Provider（状態の管理）, flutter_quill（リッチテキストの編集）, flutter_secure_storage（端末内の安全な保存）, timezone, gen_l10n（多言語化） |
| バックエンド | Firebase（Realtime Database, Authentication, Cloud Functions, Cloud Messaging, Crashlytics）                                                                |
| ネイティブ   | Swift（WidgetKit）, Kotlin（Glance）。どちらもホーム画面ウィジェットの仕組み                                                                                |
| テスト       | flutter_test、Firebase Emulator（手元で動く Firebase の模擬環境）+ Mocha（セキュリティルール、通知と掃除の関数）                                            |
| CI/CD        | GitHub Actions（エミュレータでの画面の撮影を含む）                                                                                                          |

Firebase の各サービスの役割は、次のとおりです。Realtime Database はリアルタイムに同期するデータベース、Authentication はログイン、Cloud Functions はデータの変化や時刻を契機に動く関数、Cloud Messaging はプッシュ通知の配信、Crashlytics はエラーの収集です。

## 5. 開発

```sh
flutter pub get
flutter run --flavor development   # production も選べます

# テスト
bash tool/check.sh                 # CI と同じ検査（整形、国際化、静的解析、テスト）。Windows は Git Bash から
npm ci
npm run test:rules                 # Firebase Emulator を使います
```

Flutter は 3.47.2（stable）、Android は JDK 17 です。開発環境は、各公式の手順で入れます（[Flutter SDK archive](https://docs.flutter.dev/install/archive)、[Set up Android development](https://docs.flutter.dev/platform-integration/android/setup)、iOS は [Set up iOS development](https://docs.flutter.dev/platform-integration/ios/setup)）。`flutter doctor` で、「Flutter」と「Android toolchain」（iOS は「Xcode」も）に `[✓]` が付けば準備完了です。

- flavor（同じソースから、設定の違うアプリを作り分ける Android の仕組み）：`development` と `production` の 2 つは、出力される APK の名前が違うだけで、同じ振る舞いです（接続先などの仕分けはしていません）。`--flavor` は省略できません。
- ビルドの表示：配った APK がどのソースから作られたかを確かめられるよう、CI は、コミットのハッシュを `--dart-define=GIT_COMMIT=...` で入れ、「このアプリについて」に表示します。手元のビルドでは、`dev` と表示されます。
- 文言：文言（ARB：翻訳ファイル）を変えたときは、`flutter gen-l10n` で、そこから作られるコード（生成物）を更新します（生成物はコミット済み）。

リリースビルドの署名（アプリの作成者を示す、鍵による証明）には `android/app/key.properties` が必要です（リポジトリには含めていません）。無いときは、デバッグ署名になります。

## 6. 謝辞

本アプリは、旅のしおり作成・共有サービス「行程さん」（2020 年 6 月にサービス終了）の使い心地に惚れ込み、その体験を参考にして開発しました。現在時刻に合わせた行程のハイライトや、移動手段のアイコンで行程をつなぐ表示など、多くの着想をいただきました。素晴らしいサービスを提供してくださった運営者の皆様に感謝いたします。

本プロジェクトは「行程さん」とは無関係の個人開発です。「行程さん」のコード、画像、ロゴなどは使用していません。

アイコンは、次のものを使っています。

- 移動手段のアイコン：[ICOOON MONO](https://icooon-mono.com/)（[利用規約](https://icooon-mono.com/license/)）
- そのほかの画面のアイコン：Google の [Material Icons](https://fonts.google.com/icons)（[Apache License 2.0](https://developers.google.com/fonts/docs/material_icons#licensing)）
- アプリのアイコン：AI で生成した原案を、自分で調整したもの

## 7. ギャラリー

各画面を、Android（日本語）と iOS（英語）で並べています。

|                   | 始める                                                | しおり一覧（初期）                                                | ドロワーメニュー                                                |
| ----------------- | ----------------------------------------------------- | ----------------------------------------------------------------- | --------------------------------------------------------------- |
| Android（日本語） | <img src="doc/gallery/01_始める_aos.png" width="150"> | <img src="doc/gallery/02_しおり一覧（初期）_aos.png" width="150"> | <img src="doc/gallery/06_ドロワーメニュー_aos.png" width="150"> |
| iOS（英語）       | <img src="doc/gallery/01_始める_ios.png" width="150"> | <img src="doc/gallery/02_しおり一覧（初期）_ios.png" width="150"> | <img src="doc/gallery/06_ドロワーメニュー_ios.png" width="150"> |

|                   | しおり一覧                                                                | 旅程                                                | ノート                                                |
| ----------------- | ------------------------------------------------------------------------- | --------------------------------------------------- | ----------------------------------------------------- |
| Android（日本語） | <img src="doc/gallery/03_しおり一覧（しおり追加後）_aos.png" width="150"> | <img src="doc/gallery/04_旅程_aos.png" width="150"> | <img src="doc/gallery/05_ノート_aos.png" width="150"> |
| iOS（英語）       | <img src="doc/gallery/03_しおり一覧（しおり追加後）_ios.png" width="150"> | <img src="doc/gallery/04_旅程_ios.png" width="150"> | <img src="doc/gallery/05_ノート_ios.png" width="150"> |

|                   | このアプリについて                                                | 利用規約                                                | アクセシビリティ（大きな文字）                                             |
| ----------------- | ----------------------------------------------------------------- | ------------------------------------------------------- | -------------------------------------------------------------------------- |
| Android（日本語） | <img src="doc/gallery/07_このアプリについて_aos.png" width="150"> | <img src="doc/gallery/08_利用規約_aos.png" width="150"> | <img src="doc/gallery/10_アクセシビリティ_大きな文字_aos.png" width="150"> |
| iOS（英語）       | <img src="doc/gallery/07_このアプリについて_ios.png" width="150"> | <img src="doc/gallery/08_利用規約_ios.png" width="150"> | <img src="doc/gallery/10_アクセシビリティ_大きな文字_ios.png" width="150"> |

画面の幅（small・medium・large）に合わせて、レイアウトを切り替えます（レスポンシブデザイン）。

|            | small                                                                             | medium                                                                             | large                                                                             |
| ---------- | --------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| しおり一覧 | <img src="doc/gallery/11_レスポンシブデザイン_しおり一覧_small.jpg" height="300"> | <img src="doc/gallery/11_レスポンシブデザイン_しおり一覧_medium.jpg" height="300"> | <img src="doc/gallery/11_レスポンシブデザイン_しおり一覧_large.jpg" height="300"> |
| 旅程       | <img src="doc/gallery/12_レスポンシブデザイン_旅程_small.jpg" height="300">       | <img src="doc/gallery/12_レスポンシブデザイン_旅程_medium.jpg" height="300">       | <img src="doc/gallery/12_レスポンシブデザイン_旅程_large.jpg" height="300">       |

## 8. ライセンス

© 2026 akmoor25. All rights reserved.

コードの閲覧は自由ですが、オープンソースのライセンスは付与していません。複製、改変、再配布、他のプロジェクトへの利用はご遠慮ください。
