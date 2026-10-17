# Riot Hound own ability textures (HOS-PET-020 v2): snapping fang jaws, jagged howl waves, a gold paw sigil, a spiky
# ruff ring, a double-line bolt strip.
import os, sys
sys.path.insert(0, r"C:\Users\hunte\.claude\skills\roblox-vfx\scripts")
import numpy
import vfxtex as vt
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
vt.OUTPUT_DIR = os.path.join(HERE, "out")
os.makedirs(vt.OUTPUT_DIR, exist_ok=True)
NOISE = vt.tex_noise(256, scale=6, seed=121)

# Fang jaws: an upper and a lower row of uneven fangs that slam together, then shatter.
def jaws(t, size):
    x, y = vt.tex_coords(size)
    close = vt.tex_ease(t * 4)
    gap = 0.5 * (1 - close) + 0.02
    f = numpy.full_like(x, -1.0)
    xs = [-0.6, -0.36, -0.12, 0.12, 0.36, 0.6]
    ls = [0.18, 0.26, 0.36, 0.36, 0.26, 0.18]
    for fx, L in zip(xs, ls):
        for side in (1, -1):
            off = 0.12 if side < 0 else 0.0
            w = 0.11
            tri = numpy.minimum(w * ((y * side - gap) / L) - numpy.abs(x - fx - off), (gap + 0.4) - y * side)
            f = numpy.maximum(f, numpy.minimum(tri, y * side - gap))
    gum = numpy.minimum(0.05 - numpy.abs(numpy.abs(y) - (gap + 0.42)), 0.78 - numpy.abs(x))
    f = numpy.maximum(f, gum)
    crack = vt.tex_sample(NOISE, x * 0.7, y * 0.7) - numpy.clip(t - 0.5, 0, 1) * 1.8 + 0.6
    return vt.tex_edge(f, soft=0.006) * vt.tex_edge(crack, soft=0.02)


# Howl: three jagged (sawtooth) arcs blasting forward in a cone, breaking up.
def howl(t, size):
    x, y = vt.tex_coords(size)
    r, a = vt.tex_polar(x + 0.8, y)
    g = vt.tex_ease(t * 2.2)
    f = numpy.full_like(x, -1.0)
    for i, base in enumerate((0.45, 0.85, 1.25)):
        rr = base * (0.5 + 0.7 * g) + 0.06 * numpy.abs(((a * 9) % 1) - 0.5)
        w = 0.06 * (1 - t)
        f = numpy.maximum(f, numpy.minimum(w - numpy.abs(r - rr), 0.7 - numpy.abs(a)))
    holes = vt.tex_sample(NOISE, x * 0.6, y * 0.6 + t * 0.3) - t * 1.3 + 0.9
    return vt.tex_edge(f, soft=0.006) * vt.tex_edge(holes, soft=0.02)

# Fang sigil: two big curved fangs facing each other with a bolt between them, inside a thin ring (symbol).
def paw(size):
    x, y = vt.tex_coords(size)
    f = numpy.full_like(x, -1.0)
    for side in (-1, 1):
        fang = vt.tex_curve([(side * 0.42, 0.55), (side * 0.48, 0.1), (side * 0.3, -0.35), (side * 0.08, -0.6)], 30)
        f = numpy.maximum(f, vt.tex_stroke(x, y, fang, lambda u: 0.17 * (1 - u) ** 0.9))
    bolt = numpy.array([(0.06, 0.5), (-0.08, 0.1), (0.07, 0.02), (-0.05, -0.38)])
    f = numpy.maximum(f, vt.tex_stroke(x, y, bolt, [0.06, 0.06, 0.05, 0.0]))
    ring = 0.025 - numpy.abs(numpy.hypot(x, y) - 0.88)
    return vt.tex_edge(numpy.maximum(f, ring), soft=0.006)


# Ruff ring: a ring of uneven spiky fur tufts pointing outward (a jagged wolf ruff).
def ruff(size):
    x, y = vt.tex_coords(size)
    r, a = vt.tex_polar(x, y)
    rng = numpy.random.default_rng(3)
    n = 28
    spikes = numpy.full_like(x, -1.0)
    for k in range(n):
        ang = 2 * numpy.pi * k / n + rng.uniform(-0.05, 0.05)
        ln = rng.uniform(0.08, 0.2)
        p0 = (numpy.cos(ang) * 0.72, numpy.sin(ang) * 0.72)
        p1 = (numpy.cos(ang + 0.08) * (0.72 + ln), numpy.sin(ang + 0.08) * (0.72 + ln))
        spikes = numpy.maximum(spikes, vt.tex_stroke(x, y, numpy.array([p0, p1]), [0.045, 0.0]))
    band = 0.04 - numpy.abs(r - 0.72)
    return vt.tex_edge(numpy.maximum(band, spikes), soft=0.006)

vt.draw_flipbook("HoundJaws", jaws, grid=4, fps=30)
vt.draw_flipbook("HoundHowl", howl, grid=4, fps=24)
vt.draw_texture("HoundPaw", paw, size=512)
vt.draw_texture("HoundRuff", ruff, size=512)
H, W = 512, 128
yy, xx = numpy.mgrid[0:H, 0:W].astype(numpy.float32)
rng = numpy.random.default_rng(4)
ys = numpy.linspace(0, H, 9); xs = W / 2 + rng.uniform(-W * 0.22, W * 0.22, 9); xs[-1] = xs[0]
cx = numpy.interp(yy[:, 0], ys, xs)[:, None]
d1 = numpy.abs(xx - cx - 9); d2 = numpy.abs(xx - cx + 9)
a = numpy.clip(((d1 < 3.5) | (d2 < 3.5)).astype(numpy.float32) + numpy.exp(-((xx - cx) / 16) ** 2) * 0.35, 0, 1)
Image.fromarray((numpy.dstack([numpy.ones_like(a)] * 3 + [a]) * 255).astype(numpy.uint8), "RGBA").save(os.path.join(vt.OUTPUT_DIR, "HoundBolt.png"))
print("done")
