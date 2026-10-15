#!/usr/bin/env python3
"""Colour variants of ingested icons (icons_ai/<base>.png -> icons_ai/<variant>.png) for shop items that share
one drawing, e.g. Sparkle vs Ember trail. Real PNGs rather than CSS filters so the Studio export gets them too.
Run after tools/ingest_ai_icons.py:
    python3 tools/icon_variants.py"""
import os
import numpy as np
from PIL import Image

HERE = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
AI = os.path.join(HERE, 'icons_ai')

# variant: (base, hue shift 0-255 | 'rainbow' | ('set', hue), saturation multiplier)
VARIANTS = {
    'trail_ember':    ('trail', 125, 1.1),
    'trail_rainbow':  ('trail', 'rainbow', 1.25),
    'case_frost':     ('case', 110, .85),
    'case_sunset':    ('case', -14, 1.15),
    'abilityfx_gold': ('abilityfx', ('set', 30), 1.15),
}


def shift(im, hue, sat):
    rgba = im.convert('RGBA')
    hsv = np.array(rgba.convert('RGB').convert('HSV')).astype(int)
    if hue == 'rainbow':
        h, w = hsv.shape[:2]
        hsv[..., 0] = (hsv[..., 0] + (np.arange(w)[None, :] * 255 // w) + (np.arange(h)[:, None] * 60 // h)) % 256
    elif isinstance(hue, tuple):
        hsv[..., 0] = hue[1]
    else:
        hsv[..., 0] = (hsv[..., 0] + hue) % 256
    hsv[..., 1] = np.clip(hsv[..., 1] * sat, 0, 255)
    out = Image.fromarray(hsv.astype('uint8'), 'HSV').convert('RGBA')
    out.putalpha(rgba.getchannel('A'))
    return out


if __name__ == '__main__':
    n = 0
    for name, (base, hue, sat) in VARIANTS.items():
        src = os.path.join(AI, base + '.png')
        if os.path.exists(src):
            shift(Image.open(src), hue, sat).save(os.path.join(AI, name + '.png'))
            n += 1
    print('wrote', n, 'variants')
