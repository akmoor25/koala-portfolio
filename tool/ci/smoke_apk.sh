#!/usr/bin/env bash
# 作った APK をエミュレータに入れて起動し、すぐに落ちないことを確かめる。
# 使い方: smoke_apk.sh <apk> <出力先のディレクトリ>
# release ビルドは R8 による縮小が入るため、プラグインが壊れていないかを見る目的。
set -euo pipefail

apk="$1"
out="$2"
package="io.akmoor25.koala_portfolio"
mkdir -p "$out"

adb install -r "$apk"
adb logcat -c
adb shell am start -W -n "$package/.MainActivity"
# 起動後の初期化（Firebase、プラグイン）が終わるまで待つ。
sleep 20

adb exec-out screencap -p > "$out/launch.png"
adb logcat -d > "$out/logcat.txt"
pid="$(adb shell pidof "$package" || true)"

status=0
if [ -z "$pid" ]; then
  echo "::error::起動後にプロセスが終了しています"
  status=1
fi
if grep -E "FATAL EXCEPTION|ANR in $package" "$out/logcat.txt" >/dev/null; then
  echo "::error::logcat に FATAL EXCEPTION または ANR があります"
  grep -E -B2 -A12 "FATAL EXCEPTION|ANR in $package" "$out/logcat.txt" | head -60 || true
  status=1
fi
exit "$status"
