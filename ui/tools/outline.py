#!/usr/bin/env python3
"""Shared icon finish: trim, ink outline (alpha dilation), hard drop shadow, pad to a square.
    python3 tools/outline.py icons_raw/x.png icons/x.png [--ol 14] [--size 256]
Run with no args to process every icons_raw/*.png into icons/ at 256 px."""
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

INK = (26, 14, 38)


def finish(src, dst, ol=14, size=256, drop=8):
    im = Image.open(src).convert('RGBA')
    bb = im.getbbox()
    im = im.crop(bb)
    pad = ol + drop + 6
    W, H = im.width + pad * 2, im.height + pad * 2
    base = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    base.alpha_composite(im, (pad, pad))
    a = np.array(base.split()[3])
    mask = Image.fromarray(((a > 40) * 255).astype('uint8'))
    grown = mask.filter(ImageFilter.MaxFilter(ol * 2 + 1)).filter(ImageFilter.GaussianBlur(1.2))
    ink = Image.new('RGBA', (W, H), INK + (0,))
    ink.putalpha(grown)
    shadow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    sh = Image.new('RGBA', (W, H), (10, 4, 20, 0))
    sh.putalpha(grown.point(lambda v: int(v * .45)))
    shadow.alpha_composite(sh, (0, drop))
    out = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    out.alpha_composite(shadow)
    out.alpha_composite(ink)
    out.alpha_composite(base)
    s = max(W, H)
    sq = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    sq.alpha_composite(out, ((s - W) // 2, (s - H) // 2))
    sq.resize((size, size), Image.LANCZOS).save(dst)


if __name__ == '__main__':
    if len(sys.argv) > 2:
        finish(sys.argv[1], sys.argv[2])
    else:
        os.makedirs('icons', exist_ok=True)
        for f in sorted(os.listdir('icons_raw')):
            if f.endswith('.png'):
                finish(os.path.join('icons_raw', f), os.path.join('icons', f), ol=16, size=320)
                print('finished', f)
