"""Bastion Beetle per-level looks (Hunter 17 Oct: "The beetle needs to look different from l1-l3").
Recolours the baked L1 maps into an L2 "Gilded" and an L3 "Royal" look by material class (ivory plates, bronze
rims, dark body, cyan crystals), so the levels read apart from the front at follower size without new geometry
(L3 is at 1,905 of the 2,000-triangle cap).
  python tools/pets/beetle_level_looks.py            -> docs/pets/bastion_beetle/tex/levels/*.png + preview
"""
import os
import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "docs", "pets", "bastion_beetle")
TEX = os.path.join(ROOT, "tex")
OUT = os.path.join(TEX, "levels")
os.makedirs(OUT, exist_ok=True)


def hx(h):
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32) / 255


def rgb_to_hsv(c):
    r, g, b = c[..., 0], c[..., 1], c[..., 2]
    mx, mn = c.max(-1), c.min(-1)
    d = mx - mn
    h = np.zeros_like(mx)
    m = d > 1e-6
    rr = (mx == r) & m
    gg = (mx == g) & m & ~rr
    bb = m & ~rr & ~gg
    h[rr] = ((g - b)[rr] / d[rr]) % 6
    h[gg] = (b - r)[gg] / d[gg] + 2
    h[bb] = (r - g)[bb] / d[bb] + 4
    return h * 60, np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0), mx


LOOKS = {
    # class: (target colour at the class's mean brightness)
    2: {"ivory": "f6f3ec", "bronze": "f7c443", "dark": "26304a", "crystal": "7ae6ff"},     # Gilded: pearl + polished gold
    3: {"ivory": "24346e", "bronze": "ffcf45", "dark": "15121f", "crystal": "c8f6ff"},     # Royal: royal-blue enamel + gold
}


def classes(c):
    h, s, v = rgb_to_hsv(c)
    crystal = (h > 170) & (h < 215) & (s > 0.35) & (v > 0.35)
    bronze = (h > 15) & (h < 50) & (s > 0.35) & (v > 0.18) & ~crystal
    ivory = (s < 0.3) & (v > 0.55) & ~crystal & ~bronze
    dark = (v <= 0.55) & (s < 0.35) & (v > 0.04) & ~crystal & ~bronze
    return {"ivory": ivory, "bronze": bronze, "dark": dark, "crystal": crystal}, v


def recolour(c, level):
    cls, v = classes(c)
    out = c.copy()
    for name, mask in cls.items():
        if not mask.any():
            continue
        tgt = hx(LOOKS[level][name])
        mean = max(float(v[mask].mean()), 1e-3)
        shade = np.clip(v / mean, 0.35, 1.6)[..., None]            # keep the painted light / dark detail
        out[mask] = np.clip(tgt * shade, 0, 1)[mask]
    return out, cls


def boost_emit(e, cls, level):
    g = e.copy()
    k = {2: 1.25, 3: 1.5}[level]
    g = np.clip(g * k, 0, 1)
    g[cls["crystal"]] = np.maximum(g[cls["crystal"]], 0.85 if level == 2 else 1.0)
    if level == 3:
        g[cls["bronze"]] = np.maximum(g[cls["bronze"]], 0.12)        # a faint gold sheen on the rims
    return g


def load(n):
    return np.asarray(Image.open(os.path.join(TEX, n + ".png")).convert("RGB"), np.float32) / 255


def save(a, n):
    Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)).save(os.path.join(OUT, n + ".png"))


for part in ("Body", "L2", "L3"):
    col = load("Beetle_" + part)
    emit = load("Beetle_" + part + "_emit") if os.path.exists(os.path.join(TEX, "Beetle_" + part + "_emit.png")) else None
    for lv in (2, 3):
        rc, cls = recolour(col, lv)
        save(rc, "Beetle_%s_L%d" % (part, lv))
        if emit is not None:
            save(boost_emit(emit, cls, lv), "Beetle_%s_emit_L%d" % (part, lv))

# quick look: the existing L1 / L2 / L3 renders recoloured the same way (an approximation for the look call)
src = np.asarray(Image.open(os.path.join(ROOT, "bastion_beetle_levels.jpg")).convert("RGB"), np.float32) / 255
w = src.shape[1] // 3
panels = [src[:, :w], recolour(src[:, w:2 * w], 2)[0], recolour(src[:, 2 * w:3 * w], 3)[0]]
# keep the grey backdrop / ground out of the recolour: only pixels the classes caught changed
Image.fromarray((np.concatenate(panels, 1) * 255 + 0.5).astype(np.uint8)).save(os.path.join(OUT, "beetle_levels_preview.jpg"), quality=92)
print("wrote", sorted(os.listdir(OUT)))
