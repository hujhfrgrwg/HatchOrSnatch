"""Bastion Beetle touch-up (HOS-PET-REDO, 17 Oct; Hunter: "would you recommend redoing bastion beetle" -> touch-up):
scratches and engraved bronze filigree on the ivory plates (colour + carved into the normal map), and an engraved-line
mask (tex/levels/*_engrave.png) that the L2 / L3 emissive masks light up, so the levels read further apart.
Runs on docs/pets/bastion_beetle/tex (the v4 bake), before beetle_level_looks.py.
    python tools/pets/beetle_engrave.py
"""
import os
import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "docs", "pets", "bastion_beetle")
TEX = os.path.join(ROOT, "tex")
OUT = os.path.join(TEX, "levels")
os.makedirs(OUT, exist_ok=True)


def load(p):
    return np.asarray(Image.open(p).convert("RGB"), np.float32) / 255


def save(a, p):
    Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)).save(p)


def ivory_mask(c):
    mx, mn = c.max(-1), c.min(-1)
    sat = (mx - mn) / np.maximum(mx, 1e-6)
    return ((mx > 0.5) & (sat < 0.3)).astype(np.float32)


def erode(m, r):
    out = m.copy()
    for dy in range(-r, r + 1, max(1, r // 2)):
        for dx in range(-r, r + 1, max(1, r // 2)):
            out = np.minimum(out, np.roll(np.roll(m, dy, 0), dx, 1))
    return out


def lines(h, w, n, seed, length, width):
    """n short random scratch segments, anti-aliased."""
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    acc = np.zeros((h, w), np.float32)
    for _ in range(n):
        x0, y0 = rng.random() * w, rng.random() * h
        a = rng.random() * np.pi
        L = length * (0.4 + rng.random())
        x1, y1 = x0 + np.cos(a) * L, y0 + np.sin(a) * L
        bx0, bx1 = int(max(0, min(x0, x1) - 3)), int(min(w, max(x0, x1) + 4))
        by0, by1 = int(max(0, min(y0, y1) - 3)), int(min(h, max(y0, y1) + 4))
        if bx1 <= bx0 or by1 <= by0:
            continue
        X, Y = xx[by0:by1, bx0:bx1], yy[by0:by1, bx0:bx1]
        dx, dy = x1 - x0, y1 - y0
        t = np.clip(((X - x0) * dx + (Y - y0) * dy) / (dx * dx + dy * dy), 0, 1)
        d = np.hypot(X - x0 - t * dx, Y - y0 - t * dy)
        acc[by0:by1, bx0:bx1] = np.maximum(acc[by0:by1, bx0:bx1], np.clip(1 - d / width, 0, 1))
    return acc


def filigree(h, w, cell):
    """an engraved chevron-and-diamond rune pattern on a grid (reads as engraving at follower size)."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    u, v = (xx / cell) % 1.0, (yy / cell) % 1.0
    chev = np.abs(np.abs(u - 0.5) * 1.2 - (v - 0.2)) < 0.035
    diamond = np.abs(np.abs(u - 0.5) + np.abs(v - 0.72) - 0.12) < 0.03
    return (chev | diamond).astype(np.float32) * ((v > 0.15) & (v < 0.9)).astype(np.float32)


def carve_normal(nrm_map, groove):
    """dent the tangent-space normal map along a groove mask (gradient of -groove as a height)."""
    hgt = -groove
    gx = np.roll(hgt, -1, 1) - np.roll(hgt, 1, 1)
    gy = np.roll(hgt, -1, 0) - np.roll(hgt, 1, 0)
    n = nrm_map * 2 - 1
    n[..., 0] -= gx * 1.6
    n[..., 1] += gy * 1.6
    n /= np.linalg.norm(n, axis=-1, keepdims=True) + 1e-6
    return n * 0.5 + 0.5


BRONZE_DK = np.array([0.42, 0.27, 0.11], np.float32)
for name, cell in (("Beetle_Body", 18), ("Beetle_L2", 16), ("Beetle_L3", 16)):
    cp = os.path.join(TEX, name + ".png")
    c = load(cp)
    h, w = c.shape[:2]
    iv = ivory_mask(c)
    inner = erode(iv, 1)
    scratch = lines(h, w, int(h * w / 900), hash(name) % 1000, h * 0.02, 1.0) * iv
    eng = filigree(h, w, cell) * inner
    c = c * (1 - 0.28 * scratch[..., None])                                         # fine dark scratches
    c = c * (1 - 0.85 * eng[..., None]) + BRONZE_DK * (0.85 * eng[..., None])      # engraved bronze filigree
    save(c, cp)
    np_ = os.path.join(TEX, name + "_normal.png")
    if os.path.exists(np_):
        save(carve_normal(load(np_), np.clip(eng + 0.5 * scratch, 0, 1)), np_)
    save(np.repeat(eng[..., None], 3, -1), os.path.join(OUT, name + "_engrave.png"))
    print(name, "ivory %.2f" % iv.mean(), "engrave %.3f" % eng.mean(), "scratch %.3f" % scratch.mean())
