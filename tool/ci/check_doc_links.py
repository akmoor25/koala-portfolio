#!/usr/bin/env python3
"""README と doc/ の Markdown と、doc/legal/ の HTML が張っている、リポジトリ内のリンクと画像が実在することを検査する。

http(s) とページ内のリンク（`#...`）は対象にしない。
doc/legal/ は、GitHub Pages で公開するプライバシーポリシーと利用規約の 4 つの HTML（日英）と共通の CSS が揃っていて、
日本語と英語のページが互いにリンクしていることも、検査する。あわせて、公開する文書として守る中身
（共通の CSS を読む、見出しの数が日英で同じ、JavaScript と外部の資源を使わない、アプリに同梱と書かない、
冒頭でポートフォリオ用で専門家の確認を受けていないと断る）も検査する。
使い方: python tool/ci/check_doc_links.py   （リポジトリのルートで実行）
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LEGAL = ROOT / "doc" / "legal"
LINK = re.compile(r"\]\(([^)\s]+)\)|(?:src|href)=\"([^\"]+)\"")
LEGAL_PAGES = [
    f"{name}.{lang}.html" for name in ("privacy", "terms") for lang in ("ja", "en")
]
# 冒頭で断る文。ページの言語ごと。
LEGAL_NOTICES = {
    "ja": ["法律の専門家の確認は受けていません", "GitHub Pages で提供し"],
    "en": ["not been reviewed by a legal professional", "provided on GitHub Pages"],
}
# GitHub Pages で公開するので、アプリに同梱しているとは書かない。
LEGAL_BUNDLED = ["同梱", "bundled"]


def count_tag(html: str, tag: str) -> int:
    return len(re.findall(rf"<{tag}[ >]", html))


def legal_contents(name: str, html: str) -> list[str]:
    """1 ページの中身の検査。リンク切れは別に検査する。"""
    where = f"doc/legal/{name}"
    problems = []
    if not html.strip():
        return [f"{where}: 中身が空です"]
    if 'href="style.css"' not in html:
        problems.append(f"{where}: 共通の style.css を読んでいません")
    # 外部の資源を読まず、スクリプトも動かさない、静的なページにしておく。
    if "<script" in html:
        problems.append(f"{where}: JavaScript を使っています")
    if re.search(r'<link[^>]+href="https?:', html) or re.search(r'src="https?:', html):
        problems.append(f"{where}: 外部の資源を読んでいます")
    for word in LEGAL_BUNDLED:
        if word in html:
            problems.append(f"{where}: アプリに同梱していると読める「{word}」があります")
    for notice in LEGAL_NOTICES["ja" if ".ja." in name else "en"]:
        if notice not in html:
            problems.append(f"{where}: 冒頭の断り「{notice}」がありません")
    return problems


def legal_headings(texts: dict[str, str]) -> list[str]:
    """日英で、見出しの数が同じこと（訳し漏れの目安）。"""
    problems = []
    for doc in ("privacy", "terms"):
        ja = texts.get(f"{doc}.ja.html")
        en = texts.get(f"{doc}.en.html")
        if ja is None or en is None:
            continue
        for tag in ("h1", "h2", "h3"):
            if count_tag(ja, tag) != count_tag(en, tag):
                problems.append(
                    f"doc/legal/{doc}: {tag} の数が日英で違います"
                    f"（ja {count_tag(ja, tag)}、en {count_tag(en, tag)}）"
                )
        if count_tag(ja, "h2") == 0:
            problems.append(f"doc/legal/{doc}: h2 の見出しがありません")
    return problems


def broken_links(path: Path, text: str) -> list[str]:
    problems = []
    for match in LINK.finditer(text):
        target = (match.group(1) or match.group(2)).split("#")[0]
        if not target or re.match(r"[a-z]+:", target):
            continue
        if not (path.parent / target).resolve().exists():
            problems.append(f"{path.relative_to(ROOT).as_posix()}: {target}")
    return problems


def check_legal() -> list[str]:
    problems = []
    style = LEGAL / "style.css"
    if not style.is_file():
        problems.append("doc/legal/style.css: ファイルがありません")
    elif not style.read_text(encoding="utf-8").strip():
        problems.append("doc/legal/style.css: 中身が空です")
    texts = {}
    for name in LEGAL_PAGES:
        path = LEGAL / name
        if not path.is_file():
            problems.append(f"doc/legal/{name}: ファイルがありません")
            continue
        texts[name] = path.read_text(encoding="utf-8")
        problems += legal_contents(name, texts[name])
        # コメント（TODO など）の中は、リンクではない。
        text = re.sub(r"<!--.*?-->", "", texts[name], flags=re.S)
        problems += broken_links(path, text)
        other = name.replace(".ja.", ".en.") if ".ja." in name else name.replace(".en.", ".ja.")
        if f'href="{other}"' not in text:
            problems.append(f"doc/legal/{name}: 別の言語のページ {other} へのリンクがありません")
    problems += legal_headings(texts)
    return problems


def main() -> int:
    files = [ROOT / "README.md"] + sorted((ROOT / "doc").rglob("README.md"))
    problems = []
    for path in files:
        raw = path.read_text(encoding="utf-8-sig")
        # コードブロックの中は、リンクではない。
        text = re.sub(r"```.*?```", "", raw, flags=re.S)
        problems += broken_links(path, text)
    problems += check_legal()
    if problems:
        print("文書に問題があります:")
        for problem in problems:
            print(f"  {problem}")
        return 1
    print(
        f"文書のリンクと doc/legal/ の中身: OK（{len(files)} ファイル、"
        f"doc/legal/ の {len(LEGAL_PAGES)} ページ）"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
