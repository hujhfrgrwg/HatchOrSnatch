# Scroll Tanuki own ability textures (HOS-PET-022 v2): a shape-shift puff with a leaf cut-out, a transformation seal
# (a brush glyph in a ring), a scroll strip that unrolls and tears. The leaf and ofuda sprites from vfx/tanuki are kept.
import os, sys
sys.path.insert(0, r"C:\Users\hunte\.claude\skills\roblox-vfx\scripts")
import numpy
import vfxtex as vt
HERE = os.path.dirname(os.path.abspath(__file__))
vt.OUTPUT_DIR = os.path.join(HERE, "out")
os.makedirs(vt.OUTPUT_DIR, exist_ok=True)
NOISE = vt.tex_noise(256, scale=6, seed=71)

# Shape-shift puff: a lumpy cel puff with swirl lines, a leaf-shaped hole punched through as it breaks apart.
def puff(t, size):
    x, y = vt.tex_coords(size)
    wx, wy = vt.tex_warp(x, y, amount=0.08, scale=4, seed=5, t=t * 0.3)
    radius = 0.22 + 0.4 * vt.tex_ease(t * 2.2)
    body = vt.tex_blob(wx, wy, radius=radius, lumps=8, roughness=0.7, seed=9)
    lit = vt.tex_blob(wx + 0.1, wy - 0.1, radius=radius, lumps=8, roughness=0.7, seed=9)
    lx, ly = (x - 0.05) * 0.87 - (y + 0.02) * 0.5, (x - 0.05) * 0.5 + (y + 0.02) * 0.87
    rr = 0.3 * radius / 0.6
    leaf = numpy.minimum(rr - numpy.hypot(lx - rr * 0.7, ly), rr - numpy.hypot(lx + rr * 0.7, ly)) if t > 0.35 else numpy.full_like(x, -1.0)
    holes = vt.tex_sample(NOISE, x * 0.45 + 0.3, y * 0.45 + t * 0.2) - t * 1.25 + 0.62
    alpha = vt.tex_edge(body, soft=0.006) * vt.tex_edge(holes + body * 0.4, soft=0.01) * (1 - vt.tex_edge(leaf, soft=0.01))
    th = numpy.arctan2(wy, wx) + numpy.hypot(wx, wy) * 6
    swirl = vt.tex_edge(0.12 - numpy.abs(numpy.sin(th * 1.5)), soft=0.05) * (numpy.hypot(wx, wy) < radius * 0.8)
    return alpha, numpy.clip(0.5 + 0.5 * vt.tex_edge(lit, 0.03, soft=0.006) - 0.25 * swirl, 0.2, 1)

# Transformation seal: a brush-drawn ring (uneven width) round an abstract three-stroke glyph and two dots.
def seal(size):
    x, y = vt.tex_coords(size)
    th = numpy.linspace(0.1, 2 * numpy.pi - 0.2, 60)
    ring = numpy.stack([numpy.cos(th) * 0.8, numpy.sin(th) * 0.8], 1)
    f = vt.tex_stroke(x, y, ring, lambda u: 0.035 + 0.03 * numpy.sin(u * numpy.pi * 3) ** 2)
    for pts, w in ((((-0.35, 0.35), (-0.15, 0.1), (-0.3, -0.4)), [0.07, 0.05, 0.02]),
                   (((0.0, 0.45), (0.05, 0.0), (0.0, -0.45)), [0.08, 0.06, 0.03]),
                   (((0.15, 0.2), (0.35, 0.05), (0.42, -0.3)), [0.06, 0.05, 0.015])):
        f = numpy.maximum(f, vt.tex_stroke(x, y, vt.tex_curve(list(pts), 16), w))
    f = numpy.maximum(f, 0.05 - numpy.hypot(x - 0.4, y - 0.4))
    f = numpy.maximum(f, 0.04 - numpy.hypot(x + 0.45, y + 0.45))
    return vt.tex_edge(f, soft=0.006)

# Scroll strip: a paper band that unrolls left to right with glyph marks, then tears into strips and flutters off.
def scroll(t, size):
    x, y = vt.tex_coords(size)
    out = vt.tex_ease(t * 2.5)
    band = numpy.minimum(0.16 - numpy.abs(y + 0.04 * numpy.sin(x * 3 + t * 4)), (-0.85 + 1.7 * out) - x)
    band = numpy.minimum(band, x + 0.85)
    roll = 0.13 - numpy.hypot((x - (-0.85 + 1.7 * out)) * 1.6, y)
    tear = numpy.abs(numpy.sin(x * 18)) - 0.25 - 1.5 * numpy.clip(t - 0.55, 0, 1)
    f = numpy.maximum(numpy.minimum(band, tear if t > 0.55 else band), roll if t < 0.6 else -1.0)
    marks = vt.tex_edge(0.02 - numpy.abs(((x * 5) % 1) - 0.5) * 0.12 - numpy.abs(y) * 0.1, soft=0.01)
    a = vt.tex_edge(f, soft=0.006)
    return a, numpy.clip(1 - 0.5 * marks, 0.4, 1)

vt.draw_flipbook("TanukiShiftPuff", puff, grid=4, fps=16)
vt.draw_texture("TanukiSeal", seal, size=512)
vt.draw_flipbook("TanukiScroll", scroll, grid=4, fps=20)
print("done")
