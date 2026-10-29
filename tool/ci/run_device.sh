#!/usr/bin/env bash
# 起動中のエミュレータで、統合テスト（既定は integration_test/screens_test.dart）を実行する。
# 事前に、テスト用の APK（--target=<テストのファイル> でビルド）を用意しておく。
#
# 環境変数:
#   APK         テスト用 APK のパス（必須）
#   OUT         出力先のディレクトリ（既定: out）
#   TARGET      実行するテストのファイル（既定: integration_test/screens_test.dart）
#   ROTATE      1 なら横向きにする
#   FONT_SCALE  文字サイズの倍率（例: 2.0）
#   DARK        1 ならダークモード、0 ならライトモードにする（Android 10 以上）
#   TIME_ZONE   端末のタイムゾーン（例: Asia/Tokyo）
set -uo pipefail

apk="${APK:?APK を指定してください}"
out="${OUT:-out}"
target="${TARGET:-integration_test/screens_test.dart}"
mkdir -p "$out/shots"

if [ "${ROTATE:-0}" = "1" ]; then
  adb shell settings put system accelerometer_rotation 0
  adb shell settings put system user_rotation 1
fi
if [ -n "${FONT_SCALE:-}" ]; then
  adb shell settings put system font_scale "$FONT_SCALE"
fi
if [ "${DARK:-}" = "1" ]; then
  adb shell cmd uimode night yes
elif [ "${DARK:-}" = "0" ]; then
  adb shell cmd uimode night no
fi
if [ -n "${TIME_ZONE:-}" ]; then
  # AlarmManager の setTimeZone（サービスの呼び出し番号 3）で、再起動せずにタイムゾーンを変える。
  adb shell service call alarm 3 s16 "$TIME_ZONE" > /dev/null
fi

{
  echo "size:    $(adb shell wm size | tr -d '\r' | tail -1)"
  echo "density: $(adb shell wm density | tr -d '\r' | tail -1)"
  echo "api:     $(adb shell getprop ro.build.version.sdk | tr -d '\r')"
  echo "rotate:  ${ROTATE:-0}"
  echo "font:    ${FONT_SCALE:-1.0}"
  echo "night:   $(adb shell cmd uimode night | tr -d '\r')"
  echo "zone:    $(adb shell getprop persist.sys.timezone | tr -d '\r')"
} | tee "$out/device.txt"

adb logcat -c
status=0
# flutter drive は、起動直後に VM サービスへつなぐ処理が、まれに失敗したり（"Sentinel kind: Collected"）、
# 止まったまま戻らなかったりする。1 回を 8 分までにして、テストが始まる前に失敗したときだけ、やり直す。
for attempt in 1 2 3; do
  adb logcat -c
  SCREENSHOT_DIR="$out/shots" timeout 480 flutter drive \
    --driver=test_driver/integration_test.dart \
    --target="$target" \
    --use-application-binary="$apk" \
    --flavor development \
    -d emulator-5554 2>&1 | tee "$out/drive.txt"
  status="${PIPESTATUS[0]}"
  [ "$status" -eq 0 ] && break
  if grep -qE "Some tests failed|\[E\]" "$out/drive.txt"; then break; fi
  echo "::warning::テストが始まる前に失敗しました。やり直します（$attempt 回目）"
done

adb logcat -d > "$out/logcat.txt"

# 例外が握りつぶされていないかを、logcat でも確かめる。
# このアプリのものだけを見る（システムのアプリは、遅いエミュレータで ANR になることがある）。
package="io.akmoor25.koala_portfolio"
{
  grep -E "RenderFlex overflowed" "$out/logcat.txt"
  grep -A3 "FATAL EXCEPTION" "$out/logcat.txt" | grep -E "Process: $package"
} > "$out/problems.txt" || true
if [ -s "$out/problems.txt" ]; then
  echo "::error::logcat に、このアプリのはみ出し・クラッシュの記録があります（problems.txt を確認）"
  head -20 "$out/problems.txt"
  status=1
else
  rm -f "$out/problems.txt"
fi

# ソフトウェア描画の 2 コアのエミュレータは遅く、大きな画面では ANR になることがある。
# テストが通っていれば、実機の性能の問題とは言えないので、警告にとどめる。
if grep -E "ANR in $package" "$out/logcat.txt" > "$out/anr.txt"; then
  echo "::warning::このアプリの ANR の記録があります（遅いエミュレータの影響の可能性。anr.txt を確認）"
else
  rm -f "$out/anr.txt"
fi

echo "撮ったスクリーンショット: $(ls "$out/shots" | wc -l) 枚"
exit "$status"
