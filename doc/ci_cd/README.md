# CI/CD の仕組み

GitHub Actions で、品質の確認、APK のビルド、端末ごとの画面の確認までを自動化しています。
Firebase などの秘密情報（Secrets）は使いません。

## ワークフローの一覧

| ワークフロー      | 起動                             | 役割                                     |
| ----------------- | -------------------------------- | ---------------------------------------- |
| ci.yml            | push と PR（アプリの変更）       | 整形、国際化、デザイン、静的解析、テスト |
| light.yml         | push と PR（毎回）               | 秘密情報の検査、文書のリンクの検査       |
| rules.yml         | push と PR（ルールの変更）       | セキュリティルールのテスト               |
| functions.yml     | push と PR（関数・ルールの変更） | 関数の型の検査とテスト                   |
| android-build.yml | push と PR（Android の変更）     | デバッグ APK のビルド                    |
| build-apk.yml     | タグ `apk-*`                     | 配布用の APK と、起動の確認              |
| device-matrix.yml | タグ `devices-*`                 | 7 端末のスクリーンショット集             |

- push と PR は、どれも `main` ブランチが対象です。
- `ci.yml` は、文書（公開する法務文書 `doc/legal/` を含む）、ルール、関数、`package*.json`、`firebase.json`、`tool/admin/` だけの変更では動きません。
- `light.yml` は約 1 分で終わるため、毎回動かします。
- `rules.yml` はルールとそのテスト、`functions.yml` は `functions/` とルールの変更で動きます。どちらも `package*.json` と `firebase.json` の変更でも動き、Firebase の Emulator を使います（関数のテストでは、FCM と Authentication を差し替えます）。
- `android-build.yml` は、`android/`、`pubspec.yaml`、`pubspec.lock`、`lib/firebase_options.dart` の変更で動き、x86_64 のデバッグ APK を署名鍵なしでビルドします。Gradle・Kotlin・プラグインの変更による不具合を見つけるためです。
- `build-apk.yml` は、リリースビルド（`--release --flavor production`）の APK を、リリース用の鍵が無いためデバッグ用の鍵で署名し、チェックサムとビルド情報をつけ、エミュレータで起動を確かめます。
- `device-matrix.yml` は、7 つの端末（うち 2 つは英語）で同じ画面を開き、スクリーンショットを 1 つの HTML にまとめます。

実行方法は、タグを push するか、Actions 画面の「Run workflow」から手動で実行します（`build-apk.yml`、`device-matrix.yml`、`android-build.yml`）。

```bash
git tag devices-1 && git push origin devices-1       # 端末ごとの画面の確認
git tag apk-1 && git push origin apk-1               # APK
```

リポジトリの既定ブランチは `main` です。手動実行（`workflow_dispatch`）は、既定ブランチにあるワークフローが対象で、実行するブランチには `main` を選びます。

## 品質の確認（ci.yml ほか）

起動条件は [ワークフローの一覧](#ワークフローの一覧) にまとめています。ここでは検査の基準と運用上の理由を補足します。

- `ci.yml` は `dart format`（80 桁）、国際化（日本語の直書き、ARB の日英の不一致、生成物の更新漏れ）、デザインの部品、`flutter analyze --fatal-infos`（指摘 0 件）、`flutter test --coverage` を検査します。テスト結果とカバレッジは成果物に残します。
- `light.yml` は gitleaks で履歴全体を検査します。例外は [.gitleaks.toml](../../.gitleaks.toml) に理由つきで記録します。文書のリンクと画像の実在と、公開する法務文書（`doc/legal/`）の中身（日英の相互リンク、見出しの数、外部の資源を使わないことなど）も、[check_doc_links.py](../../tool/ci/check_doc_links.py) で検査します。
- Dart のコードだけの変更は、`ci.yml` の解析とテストで見ます（Dart のコンパイルエラーは、解析とテストで見つかります）。
- 法務文書の中身の検査は、Flutter のテストではなく、毎回動く `light.yml` に置いています。テストに置いて `ci.yml` を文書の変更で動かさないと、文書の変更で壊れた検査に、後の無関係なコミットで気づくためです（2026 年 10 月に、4 回続けて起きました）。ネイティブのコードや Gradle の設定は `android/` にあるため、変更すれば `android-build.yml` が動きます。
- 同じブランチで続けて push したときは、古い実行を止めます（`concurrency`）。
- `permissions: contents: read` だけにしています。
- 外部の Action は、コミットの SHA で固定しています（コメントにバージョンを書く）。Dependabot が、毎週、更新を提案します（[dependabot.yml](../../.github/dependabot.yml)）。

### push の前に手元で確かめる

`ci.yml` の `flutter` ジョブと同じ検査（整形、国際化、デザインの部品、静的解析、テスト）を、手元で行えます。Windows では Git Bash から実行します。

```bash
bash tool/check.sh
```

push のたびに自動で行うときは、フック（[.githooks/pre-push](../../.githooks/pre-push)）を有効にします（1 回だけ）。`ci.yml` と同じく、文書（`doc/`、`*.md`）や関数・ルールだけの変更では、検査を飛ばします。

フックは、pushするコミットの差分で検査の要否を判断しますが、`tool/check.sh` が検査するのは現在の作業ディレクトリです。push対象を別の場所へ展開して検査する仕組みではありません。手元では、変更をコミットしたうえで `git status --short` が空で、push対象がHEADと一致することを確認します。CIはチェックアウトしたコミットを検査します。除外条件はフックと `ci.yml` のpush・PRで別々に持つため、変更時は双方を合わせます。相互参照コメントは注意喚起であり、一致を自動検証するものではありません。

```bash
git config core.hooksPath .githooks   # 有効にする（止めるときは git config --unset core.hooksPath）
git push --no-verify                  # 1 回だけ飛ばす
```

## APK（build-apk.yml）

- デバッグ署名です。`android/app/key.properties` が無いとき、`build.gradle.kts` が自動でデバッグ署名を選びます。リリース用のキーストアは使いません。
- `release` ビルド（デバッグ署名、全 ABI）で、約 80 MB です。デバッグビルド（約 250 MB）より小さく、速く動きます。
- ファイル名は `koala-portfolio-<バージョン>-b<ビルド番号>-<コミットの短いハッシュ>.apk` です。
  - SHA-256 を `.apk.sha256` に、コミットとビルド環境を `build-manifest.json` に書きます。
  - アプリの「このアプリについて」にも、同じコミットのハッシュが出ます。配ったアプリがどのソースから作られたかを突き合わせられます。
- ビルドの後、エミュレータ（Pixel 6、API 34）に入れて起動し、すぐに落ちないこと（クラッシュ、ANR が無いこと）を確かめます。
- 通知の文言は、サーバーが名前（`title_loc_key` / `body_loc_key`）だけを送り、端末が文字列のリソースを探します。コードから参照されないため、リリースビルドのリソースの縮小で消えると、通知の本文が空になります。[keep_notifications.xml](../../android/app/src/main/res/raw/keep_notifications.xml) で残し、ビルドの後に、サーバーが送るキーがすべて APK に残っていることを `aapt2` で確かめます。
- 成果物は 90 日残ります。必要においじて、ローカルにも保存すること。

## 端末ごとの画面の確認（device-matrix.yml）

[integration_test/screens_test.dart](../../integration_test/screens_test.dart) が、通信しない偽のデータ（`test/support/`）で、本物のアプリを動かします。起動画面、一覧、旅程、編集ダイアログ、ノート、共同編集の設定、参加、メニューなど、13 画面でスクリーンショットを撮ります。

| 端末                 | 画面      | API | 条件               |
| -------------------- | --------- | :-: | ------------------ |
| 小型                 | 480×800   | 29  | 最低の API         |
| 標準                 | 1080×2400 | 34  |                    |
| 大型                 | 1440×3120 | 35  | 新しい API         |
| タブレット           | 2560×1800 | 34  | 横向き             |
| 標準＋文字サイズ最大 | 1080×2400 | 34  | 文字サイズ 2.0 倍  |
| 小型（英語）         | 480×800   | 29  | 英語の画面         |
| タブレット（英語）   | 2560×1800 | 34  | 横向き、英語の画面 |

- 画面は 15 枚です（13 画面に、アジア周遊の旅程 2 画面を足した）。プライバシーポリシーと利用規約は、アプリ内ブラウザ（Custom Tabs、SFSafariViewController）で開くため、Flutter の画面として撮れず、対象外です。
- 英語は、文が長く、崩れやすいため、小型とタブレットだけで撮ります（全端末にすると、分数が倍になる）。言語は端末の設定ではなく、ビルド時（`--dart-define=SCREENSHOT_LOCALE=en`）に決めます。テスト用 APK は日本語用と英語用を 1 回ずつ作り、端末で使い回します。
- 端末ごとに、レイアウトの例外（はみ出し）やクラッシュが出たら失敗にします。logcat も保存し、ANR は警告にとどめます（ソフトウェア描画の 2 コアのエミュレータは遅く、大きな画面では ANR になることがあるため）。
- 最後に、全端末の画像を [tool/ci/make_gallery.py](../../tool/ci/make_gallery.py) で 1 つの HTML にまとめます。行が画面、列が端末です。
- 自動のチェックでは、「文字が折り返された」「重なった」「切れた」は検出できません。 ギャラリーは、人の目で見るための成果物です。実際に、このギャラリーで、文字サイズを大きくしたときの旅程の時刻の折り返しと、一覧のカードの期間タブの重なりを見つけて直しました。
- QR コードの読み取り（カメラ）は、エミュレータでは確かめられません。実機で確認します。

## 実行時間の目安

実測の目安です。公開リポジトリでは、GitHub が提供する標準のランナーの実行時間は無料です（[GitHub Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions)）。時間を抑えるのは、待ち時間を短くするためです。

2026 年 10 月 1 日から 12 日の実測は、合計 1,340 分でした（実行 86 回）。内訳は、品質の確認（`ci.yml`）669 分（74 回、1 回あたり平均 9 分）、`devices-*` 482 分（9 回、1 回あたり平均 54 分）などです。開発の山の 1 日（10 月 11 日）だけで約 1,000 分を使いました。そこで、次の見直しをしました。

- ワークフローを、役割ごとに分けた。文書だけの変更は約 1 分、コードの変更は約 5 分で済む（以前は、どの変更でも約 10 分）。
- APK のビルド（約 4 分）は、`android/` などの変更のときだけにした。
- 続けて push したときは、古い実行を止める（`concurrency`。もとからある）。
- コミットは、まとめてから push する。

| 実行                     | 所要（合計） | 備考                                                                                             |
| ------------------------ | :----------: | ------------------------------------------------------------------------------------------------ |
| `light.yml`（push ごと） |   約 1 分    | 文書だけの変更は、これだけ                                                                       |
| `ci.yml`（コードの変更） |   約 4 分    | 整形、解析、テスト（約 3 分）                                                                    |
| `android-build.yml`      |   約 6 分    | `android/` などの変更のときだけ                                                                  |
| `rules.yml`              |   約 1 分    | ルールの変更のときだけ                                                                           |
| `functions.yml`          |   約 2 分    | `functions/` の変更のときだけ                                                                    |
| `devices-*`              |   約 59 分   | ビルド 17 分（日本語用と英語用の 2 つ） ＋ 端末 7 台 × 5〜7 分（並列なので、待ち時間は約 24 分） |
| `apk-*`                  |   約 19 分   | ビルド 16 分 ＋ 起動確認 3 分                                                                    |

- 1 日に何度も push しないこと、`devices-*` は必要なときだけにすることで、待ち時間を抑えます。
- Gradle のキャッシュは、既定ブランチ（`main`）の実行だけが保存し、タグの実行（`devices-*`、`apk-*`）は、それを読みます。GitHub のキャッシュは、タグの実行からは、既定ブランチのものしか読めないためです。保存するのは `android-build.yml` なので、`android/` や `pubspec.*` を変えた後の push で、キャッシュが新しくなります。キャッシュが無いと、ビルドは約 12 分かかります（キャッシュが効くと約 4 分）。
- iOS のビルドは CI では行わず、手元の iOS Simulator で確かめています（[トレードオフと今後の課題](../architecture/README.md#トレードオフと今後の課題)）。
