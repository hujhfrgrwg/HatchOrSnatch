# Raiju ability textures (HOS-PET-030): a jagged lightning ring, a forked bolt burst, jagged gold mane-fire, a zig-zag
# bolt strip for beams / trails; AllVFX Lightning "lightningstrikeFLIP" for falling strikes.
import os, sys
sys.path.insert(0, r"C:\Users\hunte\.claude\skills\roblox-vfx\scripts")
import numpy
import vfxtex as vt
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
vt.OUTPUT_DIR = os.path.join(HERE, "out")
os.makedirs(vt.OUTPUT_DIR, exist_ok=True)
NOISE = vt.tex_noise(256, scale=6, seed=51)

def zig(p0, p1, n, amp, rng):
    """a jagged polyline from p0 to p1 with n kinks."""
    p0, p1 = numpy.array(p0, float), numpy.array(p1, float)
    d = p1 - p0
    nrm = numpy.array([-d[1], d[0]]) / (numpy.linalg.norm(d) + 1e-9)
    pts = [p0 + d * (i / n) + nrm * (rng.uniform(-amp, amp) if 0 < i < n else 0) for i in range(n + 1)]
    return numpy.array(pts)

# Lightning ring: a circle built from jagged segments, thicker in places, with a few short sparks off it.
def ring(size):
    x, y = vt.tex_coords(size)
    rng = numpy.random.default_rng(3)
    field = numpy.full_like(x, -1.0)
    n = 22
    for i in range(n):
        a0, a1 = 2 * numpy.pi * i / n, 2 * numpy.pi * (i + 1) / n
        r0, r1 = 0.78 + rng.uniform(-0.05, 0.05), 0.78 + rng.uniform(-0.05, 0.05)
        p0 = (numpy.cos(a0) * r0, numpy.sin(a0) * r0); p1 = (numpy.cos(a1) * r1, numpy.sin(a1) * r1)
        w = rng.uniform(0.018, 0.04)
        field = numpy.maximum(field, vt.tex_stroke(x, y, numpy.array([p0, p1]), [w, w]))
        if rng.random() < 0.35:
            out = (numpy.cos(a0) * (r0 + rng.uniform(0.08, 0.18)), numpy.sin(a0) * (r0 + rng.uniform(0.08, 0.18)))
            field = numpy.maximum(field, vt.tex_stroke(x, y, zig(p0, out, 2, 0.03, rng), [w * 0.8, 0.0]))
    return vt.tex_edge(field, soft=0.006)

# Forked bolt burst: uneven jagged bolts thrown out from the centre, each forking once, struck on then broken up.
RNG = numpy.random.default_rng(7)
BOLTS = []
for i in range(7):
    ang = i / 7 * 2 * numpy.pi + RNG.uniform(-0.35, 0.35)
    ln = RNG.uniform(0.5, 0.92)
    main = zig((0, 0), (numpy.cos(ang) * ln, numpy.sin(ang) * ln), 5, 0.07, RNG)
    k = RNG.integers(2, 4)
    turn = ang + RNG.choice([-1, 1]) * RNG.uniform(0.5, 0.9)
    fork = zig(main[k], main[k] + numpy.array([numpy.cos(turn), numpy.sin(turn)]) * RNG.uniform(0.15, 0.3), 3, 0.04, RNG)
    BOLTS.append((main, fork, RNG.uniform(0.03, 0.05)))
def burst(t, size):
    x, y = vt.tex_coords(size)
    field = numpy.full_like(x, -1.0)
    on = vt.tex_ease(t * 4)
    for main, fork, w in BOLTS:
        ww = w * (1 - 0.7 * t)
        field = numpy.maximum(field, vt.tex_stroke(x, y, main, [ww * 1.4, ww, ww * 0.3], start=numpy.clip((t - 0.4) * 1.5, 0, 1), end=0.1 + 0.9 * on))
        field = numpy.maximum(field, vt.tex_stroke(x, y, fork, [ww, 0.0], end=numpy.clip(on * 1.3 - 0.3, 0.05, 1)))
    core = numpy.exp(-(numpy.hypot(x, y) / (0.16 * (1 - t) + 0.01)) ** 2) - 0.5
    holes = vt.tex_sample(NOISE, x * 0.6, y * 0.6 + t * 0.5) - t * 1.2 + 0.85
    return vt.tex_edge(numpy.maximum(field, core), soft=0.006) * vt.tex_edge(holes, soft=0.02)

# Jagged mane-fire: a sawtooth-edged tongue (fire with lightning teeth) licking up, then shredding.
def manefire(t, size):
    x, y = vt.tex_coords(size)
    wx, wy = vt.tex_warp(x, y, amount=0.05, scale=3, seed=2, t=t * 0.6)
    grow = vt.tex_ease(t * 3)
    spine = vt.tex_curve([(0.0, -0.85), (0.12, -0.3), (-0.08, 0.25), (0.06, 0.85)], 30)
    w = lambda u: 0.85 * (1 - u) ** 0.8 * grow * (1 - 0.5 * t)
    body = vt.tex_stroke(wx, wy, spine, w, end=0.15 + 0.85 * grow)
    teeth = 0.12 * numpy.abs(((wy * 5 + 0.3) % 1) - 0.5) * (wx > 0.02)
    holes = vt.tex_sample(NOISE, x * 0.5, y * 0.5 - t * 0.7) - t * 1.3 + 0.85
    alpha = vt.tex_edge(body - teeth, soft=0.007) * vt.tex_edge(holes, soft=0.02)
    value = numpy.clip(0.55 + 0.45 * vt.tex_edge(-(wy + 0.25), soft=0.3), 0, 1)
    return alpha, value

vt.draw_texture("RaijuRing", ring, size=512)
vt.draw_flipbook("RaijuBurst", burst, grid=4, fps=30)
vt.draw_flipbook("RaijuManeFire", manefire, grid=4, fps=24)

# Beam strip: a zig-zag bolt running down the strip with a soft glow (tiles vertically).
H, W = 512, 128
yy, xx = numpy.mgrid[0:H, 0:W].astype(numpy.float32)
rng = numpy.random.default_rng(9)
ys = numpy.linspace(0, H, 13); xs = W / 2 + rng.uniform(-W * 0.32, W * 0.32, 13); xs[-1] = xs[0]
cx = numpy.interp(yy[:, 0], ys, xs)[:, None]
d = numpy.abs(xx - cx)
a = numpy.clip(numpy.maximum((d < 4).astype(numpy.float32), numpy.exp(-(d / 14) ** 2) * 0.55), 0, 1)
Image.fromarray((numpy.dstack([numpy.ones_like(a)] * 3 + [a]) * 255).astype(numpy.uint8), "RGBA").save(os.path.join(vt.OUTPUT_DIR, "RaijuBeam.png"))
SRC = os.path.join(HERE, "..", "..", "Assets", "AllVFX", "vfx-texture-pack-2-flipbooks", "2_Flipbooks", "Lightning", "lightningstrikeFLIP.png")
Image.open(SRC).convert("RGBA").resize((1024, 1024), Image.LANCZOS).save(os.path.join(vt.OUTPUT_DIR, "RaijuStrike.flipbook.png"))
print("done")
