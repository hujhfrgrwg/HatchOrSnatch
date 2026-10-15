#!/usr/bin/env python3
"""Contact sheet for a folder of thumbnail outputs (needs Pillow: pip install pillow).

    python3 contact_sheet.py out/ -o sheet.jpg              # labelled overview grid
    python3 contact_sheet.py out/ -o squint.jpg --squint    # 256 px tiles, blurred: the Discover-page test
    python3 contact_sheet.py a.png b.png c.png --cols 3     # explicit files

Each tile is labelled with its filename. Images that are not 16:9 (within 1%)
get a red border and a warning on stdout, so square or letterboxed outputs
are caught before upload.
"""
import argparse
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

EXTS = {".png", ".jpg", ".jpeg", ".webp"}


def collect(paths):
    files = []
    for p in map(Path, paths):
        if p.is_dir():
            files += sorted(f for f in p.iterdir() if f.suffix.lower() in EXTS and not f.name.startswith("_"))
        elif p.suffix.lower() in EXTS:
            files.append(p)
    return files


def font(size):
    for name in ("Arial Bold.ttf", "Arial.ttf", "DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("inputs", nargs="+", help="folders and/or image files")
    ap.add_argument("-o", "--out", default="contact_sheet.jpg")
    ap.add_argument("--cols", type=int, default=0, help="columns (default: auto)")
    ap.add_argument("--width", type=int, default=320, help="tile width in px")
    ap.add_argument("--squint", action="store_true", help="256 px tiles with a light blur")
    ap.add_argument("--no-labels", action="store_true")
    a = ap.parse_args()

    files = collect(a.inputs)
    if not files:
        sys.exit("No images found")
    tw = 256 if a.squint else a.width
    th = round(tw * 9 / 16)
    cols = a.cols or min(len(files), 6 if a.squint else 5)
    rows = -(-len(files) // cols)
    gap, label_h = 6, (0 if a.no_labels else 18)
    sheet = Image.new("RGB", (cols * (tw + gap) + gap, rows * (th + label_h + gap) + gap), (18, 18, 18))
    draw, f = ImageDraw.Draw(sheet), font(12)

    bad = 0
    for i, path in enumerate(files):
        im = Image.open(path).convert("RGB")
        w, h = im.size
        off_ratio = abs((w / h) / (16 / 9) - 1) > 0.01
        # Cover-fit into the 16:9 tile so every tile is the same size.
        scale = max(tw / w, th / h)
        im = im.resize((max(tw, round(w * scale)), max(th, round(h * scale))), Image.LANCZOS)
        left, top = (im.width - tw) // 2, (im.height - th) // 2
        im = im.crop((left, top, left + tw, top + th))
        if a.squint:
            im = im.filter(ImageFilter.GaussianBlur(1.2))
        x = gap + (i % cols) * (tw + gap)
        y = gap + (i // cols) * (th + label_h + gap)
        sheet.paste(im, (x, y))
        if off_ratio:
            bad += 1
            draw.rectangle([x, y, x + tw - 1, y + th - 1], outline=(230, 40, 40), width=4)
            print(f"WARN not 16:9: {path.name} is {w}x{h}")
        if label_h:
            draw.text((x + 2, y + th + 3), path.stem[:40], fill=(220, 220, 220), font=f)

    sheet.save(a.out, quality=88)
    print(f"Wrote {a.out}: {len(files)} images, {bad} not 16:9")


if __name__ == "__main__":
    main()
