#!/usr/bin/env python3
"""Build a static "prompt picker" page from a thumbnail requests file.

Usage:
    python3 build_picker.py requests.txt [-w ../wrapper.txt] [-o picker.html] [--title "My Game thumbnails"]

Requests file format (blocks separated by a line containing only ===):

    ID. Title | optional summary | OPTIONAL OVERLAY TEXT | optional group
    Request paragraph, one or more lines.
    ===

The page embeds the wrapper and every request, so it works offline from file://
and can be published as a single static page.
"""
import argparse
import html
import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
HEADER = re.compile(r"^\s*([A-Za-z]*\d+[A-Za-z]*)[.)]\s+(.*)$")


def parse_requests(text):
    items = []
    for block in re.split(r"^\s*===\s*$", text, flags=re.M):
        lines = [l for l in block.strip().splitlines()]
        if not lines:
            continue
        m = HEADER.match(lines[0])
        if not m:
            raise SystemExit(f"Bad header line (want 'ID. Title | ...'): {lines[0]!r}")
        fields = [f.strip() for f in m.group(2).split("|")] + ["", "", ""]
        title, summary, overlay, group = fields[:4]
        req = "\n".join(lines[1:]).strip()
        if not req:
            raise SystemExit(f"Request {m.group(1)} has no body")
        if not overlay:  # fall back to the last quoted string in the request
            quoted = re.findall(r'"([^"]+)"', req)
            overlay = quoted[-1] if quoted else ""
        items.append({"id": m.group(1), "title": title, "summary": summary,
                      "text": overlay, "group": group, "req": req})
    ids = [i["id"] for i in items]
    dupes = {i for i in ids if ids.count(i) > 1}
    if dupes:
        raise SystemExit(f"Duplicate ids: {sorted(dupes)}")
    return items


def js_literal(value):
    # json.dumps is valid JS; escape "</" so a request can never close the <script> tag.
    return json.dumps(value, ensure_ascii=False).replace("</", "<\\/")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("requests", type=Path)
    ap.add_argument("-w", "--wrapper", type=Path, default=HERE.parent / "wrapper.txt")
    ap.add_argument("-t", "--template", type=Path, default=HERE / "picker_template.html")
    ap.add_argument("-o", "--out", type=Path, default=Path("picker.html"))
    ap.add_argument("--title", default="Thumbnail prompts")
    a = ap.parse_args()

    items = parse_requests(a.requests.read_text(encoding="utf-8"))
    wrapper = a.wrapper.read_text(encoding="utf-8").rstrip() + "\n"
    page = a.template.read_text(encoding="utf-8")
    for marker in ("/*DATA*/", "/*TITLE*/"):
        if marker not in page:
            raise SystemExit(f"Template is missing {marker}")
    data = f"const WRAPPER={js_literal(wrapper)};\nconst ITEMS={js_literal(items)};"
    page = page.replace("/*DATA*/", data).replace("/*TITLE*/", html.escape(a.title))
    a.out.write_text(page, encoding="utf-8")
    print(f"Wrote {a.out} with {len(items)} prompts")


if __name__ == "__main__":
    main()
