#!/usr/bin/env python3
"""Merge the icon sources into set/icons/<slug>.png, the one folder pages and the Studio export use:
icons_ai/<slug>.png (Hunter's ChatGPT set + variants) wins over icons/<slug>.png (drawn stand-ins, pets, eggs).
Images are capped at 512 px (Roblox shows them at most ~520 design px).
    python3 tools/merge_icons.py"""
import os
import shutil
from PIL import Image

HERE = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
OUT = os.path.join(HERE, 'set', 'icons')
os.makedirs(OUT, exist_ok=True)
n = 0
for src in ('icons', 'icons_ai'):          # later wins
    d = os.path.join(HERE, src)
    for f in sorted(os.listdir(d)):
        if not f.endswith('.png'):
            continue
        im = Image.open(os.path.join(d, f))
        if max(im.size) > 512:
            im.thumbnail((512, 512), Image.LANCZOS)
            im.save(os.path.join(OUT, f))
        else:
            shutil.copyfile(os.path.join(d, f), os.path.join(OUT, f))
        n += 1
print('merged', n, 'files ->', len(os.listdir(OUT)), 'icons in set/icons')
