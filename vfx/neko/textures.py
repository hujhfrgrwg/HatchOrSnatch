# Veil Nekomata ability textures (HOS-PET-028): onibi ghost-fire, a veil that unfurls and tears, a slit cat eye,
# a three-claw scratch; AllVFX Smoke/12 for the spirit mist.
import os, sys
sys.path.insert(0, r"C:\Users\hunte\.claude\skills\roblox-vfx\scripts")
import numpy
import vfxtex as vt
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
vt.OUTPUT_DIR = os.path.join(HERE, "out")
os.makedirs(vt.OUTPUT_DIR, exist_ok=True)
NOISE = vt.tex_noise(256, scale=6, seed=31)

# Onibi: a teardrop flame that licks up, forks into two tongues (the nekomata's twin tails), then thins away.
def onibi(t, size):
    x, y = vt.tex_coords(size)
    wx, wy = vt.tex_warp(x, y, amount=0.08, scale=3, seed=5, t=t * 0.8)
    grow = vt.tex_ease(t * 3)
    fade = 1 - 0.55 * numpy.clip(t - 0.3, 0, 1)
    body = vt.tex_blob(wx, wy + 0.32, radius=0.4 * grow * fade, lumps=7, roughness=0.3, seed=7)
    fork = 0.04 + 0.16 * numpy.clip(t * 1.6, 0, 1)
    tl = vt.tex_curve([(0.0, -0.3), (-fork, 0.2), (-fork - 0.12, 0.8)], 24)
    tr = vt.tex_curve([(0.02, -0.3), (fork + 0.04, 0.15), (fork + 0.18, 0.66)], 24)
    w = lambda u: 0.36 * (1 - u) ** 1.1 * grow * fade
    tongues = numpy.maximum(vt.tex_stroke(wx, wy, tl, w, end=0.25 + 0.75 * grow), vt.tex_stroke(wx, wy, tr, w, end=0.25 + 0.75 * grow))
    shape = numpy.maximum(body, tongues)
    holes = vt.tex_sample(NOISE, x * 0.5, y * 0.5 - t * 0.6) - t * 1.3 + 0.85
    alpha = vt.tex_edge(shape, soft=0.008) * vt.tex_edge(holes, soft=0.02)
    value = numpy.clip(0.55 + 0.45 * vt.tex_edge(-(wy + 0.05), soft=0.25), 0, 1)
    return alpha, value

# Veil: a wide cloth ribbon that sweeps on in an arc, then tears into hanging strips from the top.
VEIL = vt.tex_curve([(-0.85, 0.5), (-0.4, 0.75), (0.2, 0.7), (0.75, 0.4), (0.9, -0.1)], 40)
def veil(t, size):
    x, y = vt.tex_coords(size)
    wx, wy = vt.tex_warp(x, y, amount=0.05, scale=3, seed=12, t=t * 0.4)
    def width(u):
        return 0.42 * numpy.sin(numpy.clip(u, 0, 1) * numpy.pi) ** 0.5 * (1 - 0.3 * t)
    band = vt.tex_stroke(wx, wy, VEIL, width, end=0.1 + 0.9 * vt.tex_ease(t * 3))
    strips = numpy.abs(numpy.sin((wx + 0.15 * wy) * 14)) - 0.2 - 1.6 * numpy.clip(t - 0.35, 0, 1)
    hang = vt.tex_edge(strips, soft=0.03) if t > 0.35 else 1.0
    holes = vt.tex_sample(NOISE, x * 0.6 + 0.4, y * 0.6 + t * 0.4) - t * 1.1 + 0.75
    return vt.tex_edge(band, soft=0.008) * hang * vt.tex_edge(holes, soft=0.02)

# A slit cat eye: an almond with a vertical slit cut through it (a symbol, drawn precise).
def eye(size):
    x, y = vt.tex_coords(size)
    almond = 0.42 - numpy.abs(y) - 0.42 * (x / 0.9) ** 2
    slit = 0.07 * numpy.clip(1 - (y / 0.42) ** 2, 0, 1) - numpy.abs(x)
    return vt.tex_edge(numpy.minimum(almond, -slit), soft=0.006) * (numpy.abs(x) < 0.92)

# Three-claw scratch: three tapered strokes raked down on a slant, drawn on, then thinning and breaking.
CLAWS = [vt.tex_curve([(-0.55 + d, 0.7 - 0.08 * i), (-0.25 + d, 0.1), (0.05 + d, -0.65 + 0.06 * i)], 24) for i, d in enumerate((0.0, 0.27, 0.52))]
def claw(t, size):
    x, y = vt.tex_coords(size)
    wx, wy = vt.tex_warp(x, y, amount=0.03, scale=3, seed=4)
    field = numpy.full_like(x, -1.0)
    for i, c in enumerate(CLAWS):
        lag = 0.06 * i
        w = lambda u, i=i: (0.09 - 0.012 * i) * (1 - u) ** 0.7 * numpy.sin(numpy.clip(u * 5, 0, 1) * numpy.pi / 2) * (1 - 0.7 * t)
        field = numpy.maximum(field, vt.tex_stroke(wx, wy, c, w, start=numpy.clip((t - 0.45 - lag) * 1.6, 0, 1),
                                                   end=numpy.clip(0.1 + vt.tex_ease((t - lag) * 3.5), 0, 1)))
    return vt.tex_edge(field, soft=0.006)

vt.draw_flipbook("NekoOnibi", onibi, grid=4, fps=24)
vt.draw_flipbook("NekoVeil", veil, grid=4, fps=24)
vt.draw_flipbook("NekoClaw", claw, grid=4, fps=30)
vt.draw_texture("NekoEye", eye, size=256)
SRC = os.path.join(HERE, "..", "..", "Assets", "AllVFX", "vfx-texture-pack-2-flipbooks", "2_Flipbooks")
Image.open(os.path.join(SRC, "Smoke/12.png")).convert("RGBA").resize((1024, 1024), Image.LANCZOS).save(os.path.join(vt.OUTPUT_DIR, "NekoMist.flipbook.png"))
print("done")
