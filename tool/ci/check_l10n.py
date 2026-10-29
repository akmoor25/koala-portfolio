#!/usr/bin/env python3
"""画面の文言の直書きと、翻訳の漏れを検査する。

- `lib/` の Dart で、日本語を含む文字列リテラルが、翻訳の仕組み（`lib/l10n/`）の外に残っていないこと。
  例外はサンプルのしおり（日本語が本文のため）だけ。コメントは対象にしない。
- `app_en.arb` と `app_ja.arb` のキーが一致し、プレースホルダーも同じであること。

使い方: python tool/ci/check_l10n.py   （リポジトリのルートで実行）
失敗したら終了コード 1。
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LIB = ROOT / "lib"
ARB_DIR = LIB / "l10n"

# 日本語が本文のファイル（ja のサンプル。英語は、sample_texts_en.dart と、地域ごとのファイルの表で置き換える）。
ALLOWED = {
    LIB / "data" / "sample_leaflets.dart",
    LIB / "data" / "sample_texts_en.dart",
    LIB / "data" / "sample_tours_americas.dart",
    LIB / "data" / "sample_tours_asia_pacific.dart",
    LIB / "data" / "sample_tours_europe.dart",
}
# ひらがな・カタカナ・漢字。記号（`～` など）は、言語に依らない表記なので対象にしない。
CJK = re.compile(r"[\u3040-\u30ff\u3400-\u9fff]")
STRING = re.compile(r"""'(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*\"""")


def strip_comments(source: str) -> str:
    """文字列の中の `//` を壊さないように、行ごとに、コメントだけを取り除く。"""
    out = []
    in_block = False
    for line in source.splitlines():
        result = []
        i = 0
        quote = None
        while i < len(line):
            two = line[i : i + 2]
            ch = line[i]
            if in_block:
                if two == "*/":
                    in_block = False
                    i += 2
                else:
                    i += 1
                continue
            if quote:
                result.append(ch)
                if ch == "\\":
                    result.append(line[i + 1 : i + 2])
                    i += 2
                    continue
                if ch == quote:
                    quote = None
                i += 1
                continue
            if two == "//":
                break
            if two == "/*":
                in_block = True
                i += 2
                continue
            if ch in "'\"":
                quote = ch
            result.append(ch)
            i += 1
        out.append("".join(result))
    return "\n".join(out)


def check_literals() -> list[str]:
    problems = []
    for path in sorted(LIB.rglob("*.dart")):
        if ARB_DIR in path.parents or path in ALLOWED:
            continue
        text = strip_comments(path.read_text(encoding="utf-8"))
        for number, line in enumerate(text.splitlines(), start=1):
            for literal in STRING.findall(line):
                if CJK.search(literal):
                    rel = path.relative_to(ROOT).as_posix()
                    problems.append(f"{rel}:{number}: {literal}")
    return problems


def placeholders(message: str) -> set[str]:
    # ICU の {name} と、plural/select の引数名だけを取り出す。
    names = set(re.findall(r"\{(\w+)(?:,|\})", message))
    return {n for n in names if n not in {"plural", "select"}}


def check_arb() -> list[str]:
    problems = []
    en = json.loads((ARB_DIR / "app_en.arb").read_text(encoding="utf-8"))
    ja = json.loads((ARB_DIR / "app_ja.arb").read_text(encoding="utf-8"))
    keys_en = {k for k in en if not k.startswith("@")}
    keys_ja = {k for k in ja if not k.startswith("@")}
    for key in sorted(keys_en - keys_ja):
        problems.append(f"app_ja.arb に訳がありません: {key}")
    for key in sorted(keys_ja - keys_en):
        problems.append(f"app_en.arb にありません（基準にない訳）: {key}")
    for key in sorted(keys_en & keys_ja):
        if placeholders(en[key]) != placeholders(ja[key]):
            problems.append(
                f"プレースホルダーが違います: {key} "
                f"(en={sorted(placeholders(en[key]))}, ja={sorted(placeholders(ja[key]))})"
            )
        if not ja[key].strip() or not en[key].strip():
            problems.append(f"空の文言があります: {key}")
    return problems


def snake_to_camel(key: str) -> str:
    head, *rest = key.split("_")
    return head + "".join(part.capitalize() for part in rest)


def check_notification_texts() -> list[str]:
    """通知の文言が、サーバー、Android、iOS、アプリ内（ARB）の 4 か所で、そろっていること。

    サーバー（functions/src/payload.ts）が送るキーが、Android の strings.xml と iOS の
    Localizable.strings（日本語と英語）、アプリ内の ARB（前面で受け取ったとき用）にあり、
    引数の数が同じこと。通知の本文は OS が、端末の言語で、端末の中の文言から引く。
    """
    problems = []
    payload = (ROOT / "functions" / "src" / "payload.ts").read_text(encoding="utf-8")
    keys = sorted(set(re.findall(r'"(notif_[a-z_]+)"', payload)))
    if not keys:
        return ["functions/src/payload.ts に、通知のキー（notif_...）がありません"]

    texts: dict[str, dict[str, str]] = {}
    res = ROOT / "android" / "app" / "src" / "main" / "res"
    for lang, folder in (("en", "values"), ("ja", "values-ja")):
        xml = (res / folder / "strings.xml").read_text(encoding="utf-8")
        texts[f"android-{lang}"] = dict(
            re.findall(r'<string name="(notif_[a-z_]+)">(.*?)</string>', xml)
        )
    for lang in ("en", "ja"):
        strings = (ROOT / "ios" / "Runner" / f"{lang}.lproj" / "Localizable.strings").read_text(
            encoding="utf-8"
        )
        texts[f"ios-{lang}"] = dict(re.findall(r'"(notif_[a-z_]+)"\s*=\s*"((?:[^"\\]|\\.)*)";', strings))
    for lang in ("en", "ja"):
        arb = json.loads((ARB_DIR / f"app_{lang}.arb").read_text(encoding="utf-8"))
        texts[f"arb-{lang}"] = {
            key: arb[snake_to_camel(key)] for key in keys if snake_to_camel(key) in arb
        }

    def arg_count(source: str, message: str) -> int:
        if source.startswith("android"):
            numbers = re.findall(r"%(\d+)\$s", message)
        elif source.startswith("ios"):
            numbers = re.findall(r"%(\d+)\$@", message)
        else:
            numbers = re.findall(r"\{(\w+)\}", message)
        return len(set(numbers))

    for key in keys:
        counts = {}
        for source, table in texts.items():
            if key not in table:
                problems.append(f"{source} に通知の文言がありません: {key}")
            elif not table[key].strip():
                problems.append(f"{source} の通知の文言が空です: {key}")
            else:
                counts[source] = arg_count(source, table[key])
        if len(set(counts.values())) > 1:
            problems.append(f"通知の文言の引数の数が違います: {key} {counts}")
    return problems


def main() -> int:
    problems = check_literals() + check_arb() + check_notification_texts()
    if problems:
        print("国際化の検査に失敗しました:")
        for problem in problems:
            print(f"  {problem}")
        return 1
    print("国際化の検査: OK（日本語の直書きなし、ARB の en/ja が一致、通知の文言が 4 か所でそろっている）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
