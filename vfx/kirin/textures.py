# Aegis Kirin ability textures (HOS-PET-029): kirin fire tongues, a scale shard, an auspicious cloud curl, the aegis
# seal; AllVFX Impact "DetailedImpact.3" (2x2) for the hoof-stamp eruption.
import os, sys
sys.path.insert(0, r"C:\Users\hunte\.claude\skills\roblox-vfx\scripts")
import numpy
import vfxtex as vt
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
vt.OUTPUT_DIR = os.path.join(HERE, "out")
os.makedirs(vt.OUTPUT_DIR, exist_ok=True)
NOISE = vt.tex_noise(256, scale=6, seed=41)

# Kirin fire: a tall S-curved flame blade (like its mane) that licks up, splits a second tongue, then tears away.
def flame(t, size):
    x, y = vt.tex_coords(size)
    wx, wy = vt.tex_warp(x, y, amount=0.06, scale=3, seed=6, t=t * 0.7)
    grow = vt.tex_ease(t * 3)
    main = vt.tex_curve([(0.05, -0.85), (-0.15, -0.3), (0.12, 0.2), (-0.05, 0.85)], 30)
    side = vt.tex_curve([(0.1, -0.5), (0.35, -0.05), (0.4, 0.45)], 20)
    w = lambda u: 0.46 * (1 - u) ** 0.9 * grow * (1 - 0.5 * t)
    f = numpy.maximum(vt.tex_stroke(wx, wy, main, w, end=0.15 + 0.85 * grow),
                      vt.tex_stroke(wx, wy, side, lambda u: 0.26 * (1 - u) * grow * (1 - 0.6 * t), end=numpy.clip(grow * 1.2 - 0.2, 0.05, 1)))
    holes = vt.tex_sample(NOISE, x * 0.5, y * 0.5 - t * 0.7) - t * 1.3 + 0.85
    alpha = vt.tex_edge(f, soft=0.008) * vt.tex_edge(holes, soft=0.02)
    value = numpy.clip(0.55 + 0.45 * vt.tex_edge(-(wy + 0.2), soft=0.3), 0, 1)
    return alpha, value

# A scale shard: a rounded-top, pointed plate with a centre ridge (lit and shadow tone).
def scale(size):
    x, y = vt.tex_coords(size)
    outline = numpy.minimum(0.62 - numpy.hypot(x * 1.15, y - 0.1), y + 0.85 - 1.6 * numpy.abs(x))
    a = vt.tex_edge(outline, soft=0.008)
    lit = vt.tex_edge(x - 0.02, soft=0.01)
    v = 0.6 + 0.4 * lit
    return numpy.dstack([v, v, v, a])

# Auspicious cloud: a ruyi curl, a fat stroke spiralling in on itself with a trailing tail, puffing out then thinning.
def cloud(t, size):
    x, y = vt.tex_coords(size)
    wx, wy = vt.tex_warp(x, y, amount=0.04, scale=3, seed=9, t=t * 0.3)
    s = 0.7 + 0.3 * vt.tex_ease(t * 2.5)
    th = numpy.linspace(0, 2.6 * numpy.pi, 60)
    r = 0.12 + 0.36 * (th / th[-1])
    spiral = numpy.stack([numpy.cos(th) * r * s + 0.15, numpy.sin(th) * r * s * 0.85 + 0.05], 1)[::-1]
    tail = vt.tex_curve([tuple(spiral[0]), (-0.3, -0.35), (-0.75, -0.3)], 20)
    w = lambda u: (0.27 * (1 - 0.6 * u) + 0.03) * (1 - 0.55 * t)
    f = numpy.maximum(vt.tex_stroke(wx, wy, spiral, w, end=0.2 + 0.8 * vt.tex_ease(t * 3)),
                      vt.tex_stroke(wx, wy, tail, lambda u: 0.2 * (1 - u) * (1 - 0.6 * t)))
    holes = vt.tex_sample(NOISE, x * 0.45 + 0.3, y * 0.45 + t * 0.3) - t * 1.15 + 0.8
    return vt.tex_edge(f, soft=0.008) * vt.tex_edge(holes, soft=0.02)

# The aegis seal: a precise ring with a hexagon lattice band and six small scale glyphs (a symbol, symmetric).
def seal(size):
    x, y = vt.tex_coords(size)
    r, a = vt.tex_polar(x, y)
    outer = numpy.maximum(0.025 - numpy.abs(r - 0.9), 0.012 - numpy.abs(r - 0.78))
    hexr = numpy.cos(numpy.pi / 6) / numpy.cos((a % (numpy.pi / 3)) - numpy.pi / 6)
    hexline = 0.018 - numpy.abs(r - 0.6 * hexr)
    band = (r > 0.78) & (r < 0.9)
    ticks = numpy.where(band, 0.012 - numpy.abs(((a * 36 / (2 * numpy.pi)) % 1) - 0.5) * 0.12, -1.0)
    glyphs = numpy.full_like(x, -1.0)
    for k in range(6):
        ang = k * numpy.pi / 3
        cx, cy = numpy.cos(ang) * 0.69, numpy.sin(ang) * 0.69
        glyphs = numpy.maximum(glyphs, numpy.minimum(0.06 - numpy.hypot((x - cx) * 1.1, y - cy - 0.01), (y - cy) + 0.07 - 1.4 * numpy.abs(x - cx)))
    f = numpy.maximum.reduce([outer, hexline, ticks, glyphs])
    return vt.tex_edge(f, soft=0.006)

vt.draw_flipbook("KirinFlame", flame, grid=4, fps=24)
vt.draw_flipbook("KirinCloud", cloud, grid=4, fps=20)
vt.draw_texture("KirinScale", scale, size=256)
vt.draw_texture("KirinSeal", seal, size=512)
SRC = os.path.join(HERE, "..", "..", "Assets", "AllVFX", "vfx-texture-pack-2-flipbooks", "2_Flipbooks", "Impact", "2024-04-15_20-17-47 DetailedImpact.3.2x2.png")
Image.open(SRC).convert("RGBA").resize((1024, 1024), Image.LANCZOS).save(os.path.join(vt.OUTPUT_DIR, "KirinEruption.flipbook.png"))
print("done")

# Tether beam strip (vertical, tiles along the beam): two gold strands twisting round a bright core, with flame flicks.
def beam(size):
    h, w = 512, 128
    yy, xx = numpy.mgrid[0:h, 0:w].astype(numpy.float32)
    u = (xx / w - 0.5) * 2
    v = yy / h * 2 * numpy.pi * 2
    s1 = 0.012 * w - numpy.abs((u - 0.45 * numpy.sin(v)) * w * 0.5)
    s2 = 0.012 * w - numpy.abs((u - 0.45 * numpy.sin(v + numpy.pi)) * w * 0.5)
    core = numpy.exp(-(u / 0.18) ** 2)
    flick = numpy.exp(-((u - 0.55 * numpy.sign(numpy.sin(v * 2))) / 0.12) ** 2) * numpy.clip(numpy.sin(v * 4), 0, 1) ** 4
    a = numpy.clip(numpy.maximum.reduce([vt.tex_edge(s1 / w * 20, soft=0.08), vt.tex_edge(s2 / w * 20, soft=0.08), core, flick * 0.8]), 0, 1)
    return numpy.dstack([numpy.ones_like(a)] * 3 + [a])
img = beam(None)
Image.fromarray((img * 255).astype(numpy.uint8), "RGBA").save(os.path.join(vt.OUTPUT_DIR, "KirinBeam.png"))
print("beam")
