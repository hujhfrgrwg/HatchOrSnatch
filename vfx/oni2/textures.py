# Drum Oni own ability textures (HOS-PET-025 v2): a mitsudomoe crest, a drumbeat burst of thick sound arcs, ember
# tongues, a studded taiko-rim ring, a braided cord strip.
import os, sys
sys.path.insert(0, r"C:\Users\hunte\.claude\skills\roblox-vfx\scripts")
import numpy
import vfxtex as vt
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
vt.OUTPUT_DIR = os.path.join(HERE, "out")
os.makedirs(vt.OUTPUT_DIR, exist_ok=True)
NOISE = vt.tex_noise(256, scale=6, seed=111)

# Mitsudomoe: three comma heads round a centre with tails sweeping the same way (precise symbol).
def tomoe(size):
    x, y = vt.tex_coords(size)
    f = numpy.full_like(x, -1.0)
    for k in range(3):
        a0 = k * 2 * numpy.pi / 3
        hx_, hy_ = numpy.cos(a0) * 0.32, numpy.sin(a0) * 0.32
        head = 0.26 - numpy.hypot(x - hx_, y - hy_)
        th = numpy.linspace(0, 1.9, 30)
        r = 0.32 + 0.48 * th / 1.9
        tail = numpy.stack([numpy.cos(a0 + th) * r, numpy.sin(a0 + th) * r], 1)
        f = numpy.maximum.reduce([f, head, vt.tex_stroke(x, y, tail, lambda u: 0.26 * (1 - u) ** 1.2 + 0.0)])
    ring = 0.035 - numpy.abs(numpy.hypot(x, y) - 0.9)
    return vt.tex_edge(numpy.maximum(f, ring), soft=0.006)

# Drumbeat: three thick concentric sound arcs (left and right) punching out, then fading into fragments.
def beat(t, size):
    x, y = vt.tex_coords(size)
    r, a = vt.tex_polar(x, y)
    g = vt.tex_ease(t * 2.2)
    f = numpy.full_like(x, -1.0)
    for i, base in enumerate((0.25, 0.48, 0.7)):
        rr = base * (0.4 + 0.75 * g)
        w = 0.06 * (1 - t) * (1 - 0.2 * i)
        arcs = numpy.minimum(w - numpy.abs(r - rr), numpy.abs(numpy.cos(a)) - 0.45)
        f = numpy.maximum(f, arcs)
    holes = vt.tex_sample(NOISE, x * 0.6, y * 0.6 + t * 0.3) - t * 1.3 + 0.9
    return vt.tex_edge(f, soft=0.006) * vt.tex_edge(holes, soft=0.02)

# Ember tongue: a ragged flame that flickers up and breaks into sparks.
def ember(t, size):
    x, y = vt.tex_coords(size)
    wx, wy = vt.tex_warp(x, y, amount=0.09, scale=3, seed=4, t=t)
    grow = vt.tex_ease(t * 3)
    spine = vt.tex_curve([(0.0, -0.8), (0.1, -0.2), (-0.1, 0.35), (0.05, 0.85)], 24)
    f = vt.tex_stroke(wx, wy, spine, lambda u: 0.9 * (1 - u) ** 0.8 * grow * (1 - 0.5 * t), end=0.2 + 0.8 * grow)
    holes = vt.tex_sample(NOISE, x * 0.5, y * 0.5 - t * 0.8) - t * 1.3 + 0.85
    a = vt.tex_edge(f, soft=0.007) * vt.tex_edge(holes, soft=0.02)
    return a, numpy.clip(0.55 + 0.45 * vt.tex_edge(-(wy + 0.3), soft=0.3), 0, 1)

# Taiko rim: a thick ring studded with round tacks (symbol).
def rim(size):
    x, y = vt.tex_coords(size)
    r, a = vt.tex_polar(x, y)
    f = 0.035 - numpy.abs(r - 0.8)
    for k in range(16):
        ang = k * numpy.pi / 8
        f = numpy.maximum(f, 0.065 - numpy.hypot(x - numpy.cos(ang) * 0.8, y - numpy.sin(ang) * 0.8))
    inner = 0.015 - numpy.abs(r - 0.66)
    return vt.tex_edge(numpy.maximum(f, inner), soft=0.006)

vt.draw_texture("OniTomoe", tomoe, size=512)
vt.draw_flipbook("OniBeat", beat, grid=4, fps=24)
vt.draw_flipbook("OniEmber", ember, grid=4, fps=24)
vt.draw_texture("OniRim", rim, size=512)
H, W = 512, 128
yy, xx = numpy.mgrid[0:H, 0:W].astype(numpy.float32)
u = (xx / W - 0.5) * 2
v = yy / H * 2 * numpy.pi * 4
s1 = numpy.abs(u - 0.35 * numpy.sin(v)) < 0.2
s2 = numpy.abs(u + 0.35 * numpy.sin(v)) < 0.2
a = numpy.clip(s1.astype(numpy.float32) + s2, 0, 1)
val = numpy.where(s1 & ~s2, 1.0, 0.65)
Image.fromarray((numpy.dstack([val, val, val, a]) * 255).astype(numpy.uint8), "RGBA").save(os.path.join(vt.OUTPUT_DIR, "OniCord.png"))
print("done")
