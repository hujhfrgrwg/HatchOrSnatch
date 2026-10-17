# Shrine Lion own ability textures (HOS-PET-024 v2): komainu mane curls, a temple bell, shide paper zigzags, a
# shimenawa rope ring and a twisted-rope beam strip.
import os, sys
sys.path.insert(0, r"C:\Users\hunte\.claude\skills\roblox-vfx\scripts")
import numpy
import vfxtex as vt
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
vt.OUTPUT_DIR = os.path.join(HERE, "out")
os.makedirs(vt.OUTPUT_DIR, exist_ok=True)
NOISE = vt.tex_noise(256, scale=6, seed=91)

# Mane curls: three fat komainu curls (spiral tufts) that roll out and break apart.
CURLS = [(-0.35, 0.15, 0.32, 0.0), (0.3, 0.25, 0.28, 1.2), (0.0, -0.35, 0.3, 2.3)]
def curls(t, size):
    x, y = vt.tex_coords(size)
    f = numpy.full_like(x, -1.0)
    g = vt.tex_ease(t * 3)
    for cx, cy, r0, a0 in CURLS:
        th = numpy.linspace(0, 2.4 * numpy.pi * g + 0.3, 40)
        r = r0 * (1 - 0.8 * th / (2.4 * numpy.pi + 0.3))
        pts = numpy.stack([cx + numpy.cos(a0 + th) * r, cy + numpy.sin(a0 + th) * r], 1)[::-1]
        f = numpy.maximum(f, vt.tex_stroke(x, y, pts, lambda u: (0.2 * u + 0.03) * (1 - 0.5 * t)))
    holes = vt.tex_sample(NOISE, x * 0.5 + 0.2, y * 0.5 + t * 0.4) - t * 1.3 + 0.85
    return vt.tex_edge(f, soft=0.007) * vt.tex_edge(holes, soft=0.02)

# Temple bell: a precise bell shape with a slot, a crown loop and a clapper ball, lit / shadow halves.
def bell(size):
    x, y = vt.tex_coords(size)
    ball = 0.62 - numpy.hypot(x, y + 0.08)
    loop = 0.05 - numpy.abs(numpy.hypot(x, y - 0.66) - 0.13)
    slit = numpy.minimum(0.035 - numpy.abs(y + 0.22), 0.42 - numpy.abs(x))
    ends = numpy.maximum(0.07 - numpy.hypot(x - 0.42, y + 0.22), 0.07 - numpy.hypot(x + 0.42, y + 0.22))
    cut = slit
    a = vt.tex_edge(numpy.maximum(numpy.minimum(ball, -cut), loop), soft=0.006)
    band = vt.tex_edge(0.03 - numpy.abs(y - 0.12), soft=0.006) * (ball > 0)
    v = (0.62 + 0.38 * vt.tex_edge(0.3 - numpy.hypot(x + 0.18, y - 0.18), soft=0.25)) * (1 - 0.3 * band)
    return numpy.dstack([v, v, v, a])


# Shide: a zigzag paper streamer (four folds), crisp.
def shide(size):
    x, y = vt.tex_coords(size)
    f = numpy.full_like(x, -1.0)
    pts = [(-0.05, 0.85), (0.25, 0.45), (-0.2, 0.05), (0.25, -0.35), (-0.15, -0.8)]
    for (a, b) in zip(pts, pts[1:]):
        f = numpy.maximum(f, vt.tex_stroke(x, y, numpy.array([a, b]), [0.13, 0.13]))
    return vt.tex_edge(f, soft=0.006)

# Shimenawa ring: a thick twisted rope ring with shide hanging at four points (symbol).
def ropering(size):
    x, y = vt.tex_coords(size)
    r, a = vt.tex_polar(x, y)
    band = 0.08 - numpy.abs(r - 0.74)
    twist = numpy.abs(numpy.sin(a * 18 + (r - 0.74) * 40))
    rope = vt.tex_edge(band, soft=0.006)
    hang = numpy.full_like(x, -1.0)
    for k in range(4):
        ang = k * numpy.pi / 2 + numpy.pi / 4
        cx, cy = numpy.cos(ang) * 0.74, numpy.sin(ang) * 0.74
        d = numpy.array([numpy.cos(ang), numpy.sin(ang)])
        pts = [(cx, cy), (cx + d[0] * 0.08 + d[1] * 0.06, cy + d[1] * 0.08 - d[0] * 0.06), (cx + d[0] * 0.16 - d[1] * 0.05, cy + d[1] * 0.16 + d[0] * 0.05), (cx + d[0] * 0.24, cy + d[1] * 0.24)]
        hang = numpy.maximum(hang, vt.tex_stroke(x, y, numpy.array(pts), [0.035, 0.035, 0.03, 0.025]))
    a = numpy.maximum(rope, vt.tex_edge(hang, soft=0.006))
    v = numpy.clip(1 - 0.35 * twist * rope, 0.5, 1)
    return numpy.dstack([v, v, v, a])

vt.draw_flipbook("LionCurls", curls, grid=4, fps=24)
vt.draw_texture("LionBell", bell, size=256)
vt.draw_texture("LionShide", shide, size=256)
vt.draw_texture("LionRopeRing", ropering, size=512)
# twisted rope beam strip
H, W = 512, 128
yy, xx = numpy.mgrid[0:H, 0:W].astype(numpy.float32)
u = (xx / W - 0.5) * 2
v = yy / H * 2 * numpy.pi * 3
a = (numpy.abs(u) < 0.42).astype(numpy.float32)
twist = numpy.abs(numpy.sin(v + u * 3))
val = numpy.clip(0.6 + 0.4 * twist, 0, 1)
Image.fromarray((numpy.dstack([val, val, val, a]) * 255).astype(numpy.uint8), "RGBA").save(os.path.join(vt.OUTPUT_DIR, "LionRope.png"))
print("done")
