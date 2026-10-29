"""デザインの部品を通すことを検査する。lib/ に、部品を通さないボタンや、色の直書きが無いこと。

- `FilledButton(`、`ElevatedButton(`、`SimpleDialogOption` は、lib/components/app_button.dart の外で使わない（`AppButton` を使う）。
- `Colors.red`、`Colors.yellow`、`Colors.orange`、`Colors.amber` は、使わない（`Theme.of(context).koala` の色を使う）。
  黄色と赤は、地との組み合わせで読めなくなるため、トークンを通す。
- `.withOpacity(` は使わない（`withValues(alpha:)`）。

例外は、理由を書いて ALLOW に足す。使い方: python tool/ci/check_design.py   （リポジトリのルートで実行）
"""

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]

RULES = [
    (re.compile(r"\b(FilledButton|ElevatedButton)(\.icon|\.styleFrom|\.tonal)?\("),
     "AppButton を使う（状態の見た目が決まっている）"),
    (re.compile(r"\bSimpleDialogOption\b"),
     "AppDialogActions か AppButton を使う（ボタンの入れ子を避ける）"),
    (re.compile(r"\bColors\.(red|yellow|orange|amber)\b"),
     "Theme.of(context).koala の色を使う（danger、accent、hot など）"),
    (re.compile(r"\.withOpacity\("), "withValues(alpha:) を使う"),
]

# ファイル（lib からの相対）ごとに、検査しない規則の番号。理由を書く。
ALLOW: dict[str, set[int]] = {
    # AppButton は、Material のボタンを、決まった見た目で包む部品。
    "components/app_button.dart": {0},
}


def main() -> int:
    problems: list[str] = []
    for path in sorted((ROOT / "lib").rglob("*.dart")):
        relative = path.relative_to(ROOT / "lib").as_posix()
        if relative.startswith("l10n/") or relative.startswith("theme/"):
            continue
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if line.lstrip().startswith("//"):
                continue
            for index, (pattern, advice) in enumerate(RULES):
                if index in ALLOW.get(relative, set()):
                    continue
                if pattern.search(line):
                    problems.append(f"lib/{relative}:{number}: {advice}")
    if problems:
        print("デザインの検査: NG")
        print("\n".join(problems))
        return 1
    print("デザインの検査: OK（ボタンは AppButton、色はトークンを通している）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
