#!/usr/bin/env bash
# push の前に、CI（.github/workflows/ci.yml の flutter ジョブ）と同じ検査を手元で行う。
#
# 使い方（リポジトリのルートで。Windows は Git Bash から）:
#   bash tool/check.sh
# push のたびに自動で行うには、フックを有効にする（1 回だけ。止めるときは --unset）:
#   git config core.hooksPath .githooks
set -euo pipefail

cd "$(dirname "$0")/.."

# Windows の python3 は、ストアを開くだけの代理のことがあるため、動くものを選ぶ。
python=""
for candidate in python3 python; do
  if "$candidate" -c "" >/dev/null 2>&1; then
    python="$candidate"
    break
  fi
done
if [ -z "$python" ]; then
  echo "Python 3 が見つかりません。" >&2
  exit 1
fi

step() {
  echo
  echo "== $1"
}

# lib/l10n の生成物の中身をまとめた値。gen-l10n の前後で比べる。
l10n_digest() {
  find lib/l10n -type f -name '*.dart' -print0 | sort -z | xargs -0 cat | git hash-object --stdin
}

step "整形（dart format）"
dart format --output=none --set-exit-if-changed .

step "国際化の検査（日本語の直書き、en と ja の不一致、生成物の更新漏れ）"
"$python" tool/ci/check_l10n.py
before="$(l10n_digest)"
flutter gen-l10n
if [ "$before" != "$(l10n_digest)" ]; then
  echo "lib/l10n の生成物が ARB と合っていませんでした。flutter gen-l10n で更新したので、差分をコミットしてください。" >&2
  exit 1
fi

step "デザインの部品の検査"
"$python" tool/ci/check_design.py

step "静的解析（flutter analyze --fatal-infos）"
flutter analyze --fatal-infos

step "テスト（flutter test）"
flutter test

echo
echo "すべての検査を通りました。"
