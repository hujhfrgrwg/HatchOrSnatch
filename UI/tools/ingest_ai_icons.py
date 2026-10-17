#!/usr/bin/env python3
"""Takes ChatGPT icons (docs/ui/chatgpt_icon_prompt.md) dropped in icons_ai/inbox/<slug>.png|jpg|webp,
removes a white/light background outside the dark outline (flood fill from the edges), trims, pads to a
square and writes icons_ai/<slug>.png (512 px, transparent). build.py then prefers icons_ai/<slug>.png.
    python3 tools/ingest_ai_icons.py"""
import os
import numpy as np
from PIL import Image, ImageFilter
from collections import deque

HERE = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
INBOX, OUT = os.path.join(HERE, 'icons_ai', 'inbox'), os.path.join(HERE, 'icons_ai')


def cut(im):
    im = im.convert('RGBA')
    a = np.array(im)
    if (a[..., 3] < 250).mean() > .2:          # already transparent
        return im
    rgb = a[..., :3].astype(int)
    light = (rgb.min(-1) > 205) & (rgb.max(-1) - rgb.min(-1) < 40)   # near-white, low saturation
    H, W = light.shape
    bg = np.zeros_like(light)
    q = deque([(y, x) for y in (0, H - 1) for x in range(W)] + [(y, x) for x in (0, W - 1) for y in range(H)])
    while q:
        y, x = q.popleft()
        if 0 <= y < H and 0 <= x < W and light[y, x] and not bg[y, x]:
            bg[y, x] = True
            q.extend(((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)))
    alpha = Image.fromarray(((~bg) * 255).astype('uint8')).filter(ImageFilter.GaussianBlur(.8))
    im.putalpha(alpha)
    return im


if __name__ == '__main__':
    os.makedirs(INBOX, exist_ok=True)
    n = 0
    for f in sorted(os.listdir(INBOX)):
        slug, ext = os.path.splitext(f)
        if ext.lower() not in ('.png', '.jpg', '.jpeg', '.webp'):
            continue
        im = cut(Image.open(os.path.join(INBOX, f)))
        a = np.array(im)
        a[..., 3][a[..., 3] < 12] = 0                      # faint haze some exports leave around the art
        im = Image.fromarray(a)
        im = im.crop(Image.fromarray(((a[..., 3] > 24) * 255).astype('uint8')).getbbox())
        s = max(im.size) + 16
        sq = Image.new('RGBA', (s, s), (0, 0, 0, 0))
        sq.alpha_composite(im, ((s - im.width) // 2, (s - im.height) // 2))
        sq.resize((512, 512), Image.LANCZOS).save(os.path.join(OUT, slug + '.png'))
        n += 1
    print('ingested', n, 'icons')
