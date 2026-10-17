# Eclipse Tengu ability textures (HOS-PET-027 v2): drawn with numpy + two AllVFX picks.
import os, sys
sys.path.insert(0, r"C:\Users\hunte\.claude\skills\roblox-vfx\scripts")
import numpy
import vfxtex as vt
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
vt.OUTPUT_DIR = os.path.join(HERE, "out")
os.makedirs(vt.OUTPUT_DIR, exist_ok=True)

# A crow feather: tapered lopsided vane with notches torn into it, a thin shaft line in the shadow tone.
def feather(size):
    x, y = vt.tex_coords(size)
    wx, wy = vt.tex_warp(x, y, amount=0.03, scale=3, seed=21)
    spine = vt.tex_curve([(0.02, -0.92), (-0.04, -0.3), (0.0, 0.35), (0.1, 0.9)], 32)
    def width(u):
        return 0.42 * numpy.sin(numpy.clip(u, 0, 1) * numpy.pi) ** 0.6 * (0.7 + 0.3 * u)
    vane = vt.tex_stroke(wx, wy, spine, width)
    notch = numpy.full_like(x, -1.0)
    for (cy, side, ln) in ((0.05, 1, 0.22), (0.38, -1, 0.18), (-0.25, -1, 0.14), (0.6, 1, 0.12)):
        a = (side * 0.5, cy + 0.14); b = (side * (0.42 - ln), cy - 0.02)
        notch = numpy.maximum(notch, vt.tex_stroke(x, y, numpy.array([a, b]), [0.06, 0.0]))
    shape = numpy.minimum(vane, -notch)
    alpha = vt.tex_edge(shape, soft=0.008)
    shaft = vt.tex_edge(vt.tex_stroke(x, y, spine, [0.03, 0.02, 0.008]), soft=0.006)
    value = 1.0 - 0.45 * shaft + 0.0 * x
    return numpy.dstack([value, value, value, numpy.maximum(alpha, shaft * (y < 0.9))])

# Eclipse corona: a thin crisp ring with uneven flame tongues licking outward (a black sun's rim).
RNG = numpy.random.default_rng(5)
TONGUES = [(a + RNG.uniform(-0.12, 0.12), RNG.uniform(0.05, 0.3) ** 1.3 * 1.6, RNG.uniform(0.04, 0.075), RNG.uniform(-1, 1)) for a in numpy.linspace(0, 2 * numpy.pi, 24, endpoint=False)]
def corona(size):
    x, y = vt.tex_coords(size)
    wx, wy = vt.tex_warp(x, y, amount=0.025, scale=5, seed=8)
    r, a = vt.tex_polar(wx, wy)
    R = 0.5
    ringf = 0.05 - numpy.abs(r - R)
    field = ringf
    for ang, ln, w, bend in TONGUES:
        p0 = (numpy.cos(ang) * (R - 0.02), numpy.sin(ang) * (R - 0.02))
        mid = (numpy.cos(ang + bend * 0.15) * (R + ln * 0.55), numpy.sin(ang + bend * 0.15) * (R + ln * 0.55))
        tip = (numpy.cos(ang + bend * 0.3) * (R + ln), numpy.sin(ang + bend * 0.3) * (R + ln))
        field = numpy.maximum(field, vt.tex_stroke(wx, wy, vt.tex_curve([p0, mid, tip], 12), [w, w * 0.75, 0.0]))
    return vt.tex_edge(field, soft=0.006)

# Eclipse disc: a solid lopsided black-sun body (tinted black or crimson by the emitter).
def disc(size):
    x, y = vt.tex_coords(size)
    return vt.tex_edge(vt.tex_blob(x, y, radius=0.62, lumps=7, roughness=0.12, seed=3), soft=0.008)

# Fan gust: a wide crescent of wind swept on by a tengu fan, with two thinner trailing lines, breaking up.
GUST = vt.tex_curve([(-0.8, -0.2), (-0.45, 0.35), (0.1, 0.55), (0.6, 0.35), (0.85, -0.05)], 40)
LINES = [vt.tex_curve([(-0.7, -0.38), (-0.3, 0.1), (0.2, 0.25), (0.7, 0.05)], 30),
         vt.tex_curve([(-0.55, -0.55), (-0.15, -0.2), (0.3, -0.12), (0.65, -0.3)], 30)]
NOISE = vt.tex_noise(256, scale=6, seed=13)
def gust(t, size):
    x, y = vt.tex_coords(size)
    wx, wy = vt.tex_warp(x, y, amount=0.05, scale=3, seed=4, t=t * 0.3)
    def width(u):
        return 0.16 * (1 - u) ** 0.6 * numpy.sin(numpy.clip(u * 4, 0, 1) * numpy.pi / 2) * (1 - 0.6 * t)
    body = vt.tex_stroke(wx, wy, GUST, width, start=numpy.clip((t - 0.4) * 1.5, 0, 1), end=0.12 + 0.88 * vt.tex_ease(t * 3))
    for i, L in enumerate(LINES):
        body = numpy.maximum(body, vt.tex_stroke(wx, wy, L, lambda u: 0.05 * (1 - u) * (1 - t),
                                                 start=numpy.clip((t - 0.3 - 0.1 * i) * 1.6, 0, 1), end=0.1 + 0.9 * vt.tex_ease(t * 2.6)))
    holes = vt.tex_sample(NOISE, x * 0.5 + 0.2, y * 0.5 + t * 0.3) - t * 1.2 + 0.75
    return vt.tex_edge(body, soft=0.006) * vt.tex_edge(holes, soft=0.02)

vt.draw_texture("TenguFeather", feather, size=256)
vt.draw_texture("TenguCorona", corona, size=512)
vt.draw_texture("TenguSunDisc", disc, size=256)
vt.draw_flipbook("TenguGust", gust, grid=4, fps=30)

# AllVFX picks (2_Flipbooks): a cel smoke puff that breaks apart (Smoke/24) and curling wind wisps (Wind/35),
# scaled to the 1024 flipbook sheet.
SRC = os.path.join(HERE, "..", "..", "Assets", "AllVFX", "vfx-texture-pack-2-flipbooks", "2_Flipbooks")
for src, name in (("Smoke/24.png", "TenguSmoke.flipbook.png"), ("Wind/35.png", "TenguWisp.flipbook.png")):
    im = Image.open(os.path.join(SRC, src)).convert("RGBA").resize((1024, 1024), Image.LANCZOS)
    im.save(os.path.join(vt.OUTPUT_DIR, name))
print("done")
