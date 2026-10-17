#!/usr/bin/env python3
"""Cuts the Studio photo-booth captures (4x2 grid of ViewportFrames on pure magenta) into transparent
pet / egg PNGs in icons_raw/, then tools/outline.py gives them the shared ink edge + drop shadow.
Captures: Workspace.FWP_PetShowroom models, ViewportFrame lighting like PetModel.viewport, yaw 25."""
import json, os, re, sys
import numpy as np
from PIL import Image

M = np.array([255, 0, 255], float)


def key(cell):
    a = np.asarray(cell.convert('RGB'), float)
    d = np.sqrt(((a - M) ** 2).sum(-1))
    alpha = np.clip((d - 28) / 70, 0, 1)
    # unmix the magenta fringe: c = (p - (1-a) M) / a
    al = alpha[..., None]
    col = np.where(al > 0.02, (a - (1 - al) * M) / np.maximum(al, 0.02), 0)
    col = np.clip(col, 0, 255)
    out = np.dstack([col, alpha * 255]).astype('uint8')
    im = Image.fromarray(out, 'RGBA')
    bb = im.getbbox()
    return im.crop(bb) if bb else im


def slug(path):
    fam, name = path.split('/')
    if fam.startswith('Egg_'):
        return 'egg_' + name.lower()
    t = 't3' if name.endswith('_T3') else 't2' if name.endswith('_T2') else 't1'
    return 'pet_' + re.sub(r'(?<!^)(?=[A-Z])', '_', fam).lower() + '_' + t


if __name__ == '__main__':
    shots = json.load(open(sys.argv[1]))      # [[capture_path, [item, ...]], ...] later entries win
    os.makedirs('icons_raw', exist_ok=True)
    for cap, items in shots:
        img = Image.open(cap)
        W, H = img.size
        for i, it in enumerate(items):
            c, r = i % 4, i // 4
            cell = img.crop((round(c * W / 4) + 2, round(r * H / 2) + 2, round((c + 1) * W / 4) - 2, round((r + 1) * H / 2) - 2))
            key(cell).save(os.path.join('icons_raw', slug(it) + '.png'))
    print(len(os.listdir('icons_raw')), 'cut')
