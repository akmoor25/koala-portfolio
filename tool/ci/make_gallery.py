#!/usr/bin/env python3
"""端末ごとのスクリーンショットを、1 枚の HTML にまとめる。

使い方: make_gallery.py <入力のディレクトリ> <出力のディレクトリ>

入力は、端末ごとのサブディレクトリ（中に shots/*.png と device.txt がある）。
出力は index.html と、画像のコピー。行が画面、列が端末で、人の目で見比べる。
"""
import html
import shutil
import sys
from pathlib import Path


def main() -> int:
    src = Path(sys.argv[1])
    dst = Path(sys.argv[2])
    dst.mkdir(parents=True, exist_ok=True)

    devices = sorted(p for p in src.iterdir() if (p / "shots").is_dir())
    screens = sorted({png.stem for d in devices for png in (d / "shots").glob("*.png")})

    for d in devices:
        target = dst / d.name
        target.mkdir(exist_ok=True)
        for png in (d / "shots").glob("*.png"):
            shutil.copy(png, target / png.name)

    def info(d: Path) -> str:
        f = d / "device.txt"
        return html.escape(f.read_text(encoding="utf-8")) if f.exists() else ""

    head = "".join(
        f"<th>{html.escape(d.name)}<pre>{info(d)}</pre></th>" for d in devices
    )
    rows = []
    for screen in screens:
        cells = []
        for d in devices:
            png = d / "shots" / f"{screen}.png"
            if png.exists():
                rel = f"{d.name}/{screen}.png"
                cells.append(f'<td><a href="{rel}"><img src="{rel}" loading="lazy"></a></td>')
            else:
                cells.append('<td class="missing">なし</td>')
        rows.append(f"<tr><th>{html.escape(screen)}</th>{''.join(cells)}</tr>")

    (dst / "index.html").write_text(
        f"""<!doctype html>
<html lang="ja"><head><meta charset="utf-8">
<title>端末別のスクリーンショット</title>
<style>
body {{ font-family: sans-serif; margin: 16px; }}
table {{ border-collapse: collapse; }}
th, td {{ border: 1px solid #ccc; padding: 6px; vertical-align: top; }}
th pre {{ font-weight: normal; font-size: 11px; text-align: left; margin: 4px 0 0; }}
td img {{ max-width: 240px; max-height: 420px; display: block; }}
.missing {{ color: #b00; text-align: center; }}
</style></head><body>
<h1>端末別のスクリーンショット</h1>
<p>行が画面、列が端末です。画像をクリックすると原寸で開きます。はみ出し・欠け・重なり・読めない文字がないか、目で確かめてください。</p>
<table><tr><th></th>{head}</tr>{''.join(rows)}</table>
</body></html>""",
        encoding="utf-8",
    )
    print(f"{len(devices)} 端末 × {len(screens)} 画面")
    return 0


if __name__ == "__main__":
    sys.exit(main())
