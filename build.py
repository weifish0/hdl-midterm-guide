"""Build the static site: src/pages/*.html -> docs/*.html (GitHub Pages serves /docs).

Directives inside a page:
  <!--meta {"title": "...", "nav": "sv", "mermaid": true}-->   first line of every page
  <!--#code exam2023/exam1_A.sv | optional title-->            inline a file from code/
Run:  python build.py
"""
import html
import json
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).parent
SRC = ROOT / "src"
OUT = ROOT / "docs"
CODE = ROOT / "code"

NAV = [
    ("index", "總覽"),
    ("sv", "SystemVerilog 語法"),
    ("design", "設計模式"),
    ("fpga", "FPGA 實作"),
    ("tb", "模擬與 Testbench"),
    ("labs", "Lab 1–5"),
    ("exams", "歷屆考題"),
    ("mock", "模擬考"),
    ("cheat", "考場速查"),
]

# seven-segment logo: segments a..g as polygons in a 16x28 box
SEG_SHAPES = {
    "a": "3,1 13,1 11,3 5,3", "b": "14,2 14,13 12,12 12,4", "c": "14,15 14,26 12,24 12,16",
    "d": "3,27 13,27 11,25 5,25", "e": "2,15 4,16 4,24 2,26", "f": "2,2 4,4 4,12 2,13",
    "g": "3,14 5,13 11,13 13,14 11,15 5,15",
}
SEG_FONT = {"L": "def", "A": "abcefg", "B": "cdefg", "5": "acdfg", "E": "adefg", "X": "bcefg", "1": "bc",
            "M": "abcef", "-": "g"}


def seg_logo(text):
    out = ['<span class="seg" aria-hidden="true">']
    for ch in text:
        on = SEG_FONT.get(ch, "")
        polys = "".join(f'<polygon points="{pts}" class="{"on" if s in on else "off"}"/>' for s, pts in SEG_SHAPES.items())
        out.append(f'<svg viewBox="0 0 16 28">{polys}</svg>')
    out.append("</span>")
    return "".join(out)


def code_block(m):
    arg = m.group(1).strip()
    path, _, title = (x.strip() for x in arg.partition("|"))
    text = (CODE / path).read_text(encoding="utf-8").replace("\r\n", "\n")
    lang = "tcl" if path.endswith(".tcl") else "dat" if path.endswith(".dat") else "sv"
    if path.endswith(".py"):
        lang = "text"
    title = title or path.split("/")[-1]
    return (f'<pre class="code" data-lang="{lang}" data-title="{html.escape(title)}" '
            f'data-src="code/{html.escape(path)}">{html.escape(text)}</pre>')


LAYOUT = """<!doctype html>
<html lang="zh-Hant">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>{title}</title>
<meta name="description" content="{desc}">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Chakra+Petch:wght@500;600;700&family=JetBrains+Mono:wght@400;600&family=Noto+Sans+TC:wght@400;500;700&display=swap">
<link rel="stylesheet" href="assets/style.css">
<script>try{{var t=localStorage.getItem("hdl-theme");if(t&&t!=="system")document.documentElement.setAttribute("data-theme",t)}}catch(e){{}}</script>
</head>
<body>
<header class="top">
  <div class="top-inner">
    <div class="brand-row">
      <a class="brand" href="index.html">{logo}<span><span class="brand-name">HDL Exam 1 Prep</span><br><span class="brand-sub">硬體設計與實驗 · 期中上機考 · SystemVerilog</span></span></a>
      <button type="button" class="theme-btn" id="theme-btn">主題：系統</button>
    </div>
    <nav class="pagenav" aria-label="頁面">{nav}</nav>
  </div>
</header>
<main>
{body}
</main>
<footer>
  自學整理用，題目內容為重點摘要。所有解答程式碼都在 Vivado 2022.1 xsim 模擬或合成驗證過；FPGA 題沒有上板實測，行為以題目與助教 demo 為準。
  原始碼：<a href="https://github.com/weifish0/hdl-midterm-guide">GitHub</a>
</footer>
{mermaid}<script src="assets/app.js"></script>
</body>
</html>
"""


def build():
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir()
    shutil.copytree(SRC / "assets", OUT / "assets")
    shutil.copytree(CODE, OUT / "code")
    (OUT / ".nojekyll").write_text("")
    logo = seg_logo("LAB5")
    for page in sorted((SRC / "pages").glob("*.html")):
        raw = page.read_text(encoding="utf-8")
        m = re.match(r"<!--meta (.*?)-->\s*", raw, re.S)
        meta = json.loads(m.group(1))
        body = raw[m.end():]
        body = re.sub(r"<!--#code (.*?)-->", code_block, body)
        nav = "".join(
            f'<a href="{key}.html"{" aria-current=\"page\"" if key == meta["nav"] else ""}>{label}</a>'
            for key, label in NAV)
        mer = ('<script src="https://cdn.jsdelivr.net/npm/mermaid@10.9.1/dist/mermaid.min.js"></script>\n'
               if meta.get("mermaid") else "")
        out = LAYOUT.format(title=html.escape(meta["title"]), desc=html.escape(meta.get("desc", "")),
                            logo=logo, nav=nav, body=body, mermaid=mer)
        (OUT / page.name).write_text(out, encoding="utf-8")
        print("built", page.name)


if __name__ == "__main__":
    build()
