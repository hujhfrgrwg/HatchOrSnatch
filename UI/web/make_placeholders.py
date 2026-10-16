#!/usr/bin/env python3
"""Stand-in art so the HTML previews render before the real assets are in place.

    stud.png              stand-in stud texture (4x4 studs, tiled at 112 px, overlay blend). Written ONLY if
                          stud.png is missing: drop the real ui-resources.com "Stud texture" in its place
                          (roblox-ui-maker UI_RESOURCES.md) and it is used instead. Not committed.
    icons/emote_slot.png  empty dashed image slot for an emote's picture. Runtime always overwrites
                          Icon.Image with the emote's own image, so this never shows in game.

Usage: python3 make_placeholders.py   (from UI/web/)
"""
import os

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))


def stud_tile(size=448, n=4):
    """Neutral grey (128 = no change under overlay blend) with a lit top-left rim and a shaded
    bottom-right rim per stud, so plates read as studded plastic in their own colour."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    p = size / n
    cx = (x % p) - p / 2
    cy = (y % p) - p / 2
    r = np.hypot(cx, cy) / (p * 0.31)
    img = np.full((size, size), 128.0, np.float32)
    ring = (r > 0.80) & (r < 1.08)
    light = (-cx - cy) / (np.hypot(cx, cy) + 1e-6)  # +1 toward the top-left
    img[ring] += 46 * light[ring]
    top = r <= 0.80
    img[top] += 10 - 14 * np.clip(r[top], 0, 1)
    shadow = (r >= 1.08) & (r < 1.32)
    img[shadow] -= 22 * np.clip(-light[shadow], 0, 1)
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), 'L').convert('RGB')


def emote_slot(size=256):
    im = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    m, w, dash = 14, 10, 26
    box = (m, m, size - m, size - m)
    d.rounded_rectangle(box, radius=40, fill=(255, 255, 255, 46))
    # dashed outline: draw the outline, then punch gaps along each edge
    d.rounded_rectangle(box, radius=40, outline=(255, 255, 255, 200), width=w)
    a = np.array(im)
    for i in range(m + 48, size - m - 48, dash * 2):
        a[m - 2:m + w + 2, i:i + dash] = 0
        a[size - m - w - 2:size - m + 2, i:i + dash] = 0
        a[i:i + dash, m - 2:m + w + 2] = 0
        a[i:i + dash, size - m - w - 2:size - m + 2] = 0
    a[m + w + 1:size - m - w - 1, m + w + 1:size - m - w - 1] = (255, 255, 255, 46)
    return Image.fromarray(a, 'RGBA')


if __name__ == '__main__':
    os.makedirs(os.path.join(HERE, 'icons'), exist_ok=True)
    stud = os.path.join(HERE, 'stud.png')
    if not os.path.exists(stud):
        stud_tile().save(stud)
        print('wrote stand-in stud.png (replace with the ui-resources Stud texture)')
    emote_slot().save(os.path.join(HERE, 'icons', 'emote_slot.png'))
    print('wrote icons/emote_slot.png')
