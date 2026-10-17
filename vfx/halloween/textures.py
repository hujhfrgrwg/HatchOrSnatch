# Halloween pets' own ability textures (HOS-HWN-001 v2), drawn with the roblox-vfx numpy library.
#   Pumpkin Wraith: WraithGrin (a carved jack-o'-lantern face flash: slit eyes, jagged grin), WraithEmberSwirl (4x4: an
#     ember spiral that winds up and breaks into sparks), WraithCinder (a jagged glowing cinder flake).
#   Witch's Cat: CatBubble (a cauldron bubble with a rim highlight), CatHexSigil (a witch's hex circle: double ring,
#     five-point star, crescent and rune ticks), CatSmokePuff (4x4: a round cauldron puff that swells and pops).
#   Mummy: MummyStrip (a frayed bandage strip with wrap lines), MummyWrapSwirl (4x4: bandage strips spiralling in and
#     closing), MummyBandage (a beam strip: linen with diagonal wrap folds and torn edges).
import os, sys
sys.path.insert(0, r"C:\Users\hunte\.claude\skills\roblox-vfx\scripts")
import numpy
import vfxtex as vt
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
vt.OUTPUT_DIR = os.path.join(HERE, "out")
os.makedirs(vt.OUTPUT_DIR, exist_ok=True)
NOISE = vt.tex_noise(256, scale=6, seed=131)
np = numpy


# ---------------------------------------------------------------- Pumpkin Wraith
def grin(size):
    """jack-o'-lantern face: two narrow eye blades slanting down to the nose, a small inverted nose, a wide jagged
    fanged mouth with its corners pulled down. White = the carved light, hotter toward the middle of each cut."""
    x, y = vt.tex_coords(size)
    ax = np.abs(x)

    def tri(p0, p1, p2):
        def side(a, b):
            return (b[0] - a[0]) * (y - a[1]) - (b[1] - a[1]) * (ax - a[0])
        s0, s1, s2 = side(p0, p1), side(p1, p2), side(p2, p0)
        sg = 1 if ((p1[0] - p0[0]) * (p2[1] - p0[1]) - (p1[1] - p0[1]) * (p2[0] - p0[0])) > 0 else -1
        return np.minimum(np.minimum(s0 * sg, s1 * sg), s2 * sg)
    eye = np.maximum(tri((0.08, 0.12), (0.64, 0.44), (0.6, 0.18)), tri((0.08, 0.12), (0.6, 0.18), (0.36, 0.08)))
    nose = tri((0.0, -0.08), (0.09, 0.06), (0.0, 0.06))
    top = -0.2 - 0.2 * ax ** 2
    bot = -0.52 + 0.1 * ax ** 2
    saw = np.abs(((x * 4.5) % 1) - 0.5) * 2          # 0 at a tooth tip .. 1 between
    saw2 = np.abs(((x * 4.5 + 0.5) % 1) - 0.5) * 2
    up = (top - 0.12 * (1 - saw)) - y                  # upper fangs hang down
    lo = y - (bot + 0.1 * (1 - saw2))                  # lower fangs point up
    mouth = np.minimum(np.minimum(up, lo), 0.76 - ax)
    field = np.maximum.reduce([eye * 4, nose * 4, mouth * 2])
    a = vt.tex_edge(field, soft=0.012)
    v = 0.55 + 0.45 * vt.tex_edge(field - 0.06, soft=0.08)
    return np.dstack([v, v, v, a])


def ember_swirl(t, size):
    x, y = vt.tex_coords(size)
    g = vt.tex_ease(t * 1.6)
    f = np.full_like(x, -1.0)
    for k in range(3):
        a0 = k * 2 * np.pi / 3 + t * 2.4
        th = np.linspace(0, 2.6 * g + 0.2, 40)
        r = 0.18 + 0.55 * th / (2.6 + 0.2)
        pts = np.stack([np.cos(a0 + th) * r, np.sin(a0 + th) * r], 1)
        f = np.maximum(f, vt.tex_stroke(x, y, pts, lambda u: (0.13 * u + 0.03) * (1 - 0.5 * t)))
    holes = vt.tex_sample(NOISE, x * 0.6 + 0.3, y * 0.6 - t * 0.5) - t * 1.4 + 0.9
    a = vt.tex_edge(f, soft=0.008) * vt.tex_edge(holes, soft=0.03)
    return a, 0.75 + 0.25 * vt.tex_edge(f - 0.02, soft=0.02)


def cinder(size):
    x, y = vt.tex_coords(size)
    b = vt.tex_blob(x * 1.2, y * 1.8, radius=0.55, lumps=7, roughness=0.8, seed=7)
    a = vt.tex_edge(b, soft=0.01)
    v = 0.6 + 0.4 * vt.tex_edge(b - 0.18, soft=0.15)
    return np.dstack([v, v, v, a])


# ---------------------------------------------------------------- Witch's Cat
def bubble(size):
    x, y = vt.tex_coords(size)
    r = np.hypot(x, y)
    rim = vt.tex_edge(0.07 - np.abs(r - 0.78), soft=0.02)
    fill = vt.tex_edge(0.8 - r, soft=0.02) * 0.28
    hi = vt.tex_edge(0.13 - np.hypot(x + 0.32, y - 0.36), soft=0.05)
    a = np.clip(np.maximum(np.maximum(rim, fill), hi), 0, 1)
    v = np.clip(0.75 + 0.25 * hi, 0, 1)
    return np.dstack([v, v, v, a])


def hex_sigil(size):
    x, y = vt.tex_coords(size)
    r, a = vt.tex_polar(x, y)
    ring = np.maximum(vt.tex_edge(0.025 - np.abs(r - 0.9), soft=0.006), vt.tex_edge(0.014 - np.abs(r - 0.78), soft=0.006))
    ticks = vt.tex_edge(0.05 - np.abs(r - 0.84), soft=0.006) * vt.tex_edge(0.035 - np.abs(((a / (2 * np.pi) * 24) % 1) - 0.5) * 0.25, soft=0.004)
    star = np.full_like(x, -1.0)
    pts = [(np.cos(np.pi / 2 + k * 4 * np.pi / 5) * 0.78, np.sin(np.pi / 2 + k * 4 * np.pi / 5) * 0.78) for k in range(6)]
    for p, q in zip(pts, pts[1:]):
        star = np.maximum(star, vt.tex_stroke(x, y, np.array([p, q]), [0.018, 0.018]))
    moon = vt.tex_edge(0.17 - np.hypot(x, y + 0.02), soft=0.008) * (1 - vt.tex_edge(0.15 - np.hypot(x - 0.07, y + 0.0), soft=0.008))
    al = np.clip(np.maximum.reduce([ring, ticks * 0.9, vt.tex_edge(star, soft=0.006), moon]), 0, 1)
    return np.dstack([np.ones_like(x), np.ones_like(x), np.ones_like(x), al])


def smoke_puff(t, size):
    x, y = vt.tex_coords(size)
    g = vt.tex_ease(t * 2.2)
    b = vt.tex_blob(x, y, radius=0.25 + 0.5 * g, lumps=8, roughness=0.45, seed=21)
    holes = vt.tex_sample(NOISE, x * 0.5 + 0.1, y * 0.5 + t * 0.3) - t * 1.5 + 1.0
    a = vt.tex_edge(b, soft=0.012) * vt.tex_edge(holes, soft=0.03)
    shade = 0.6 + 0.4 * vt.tex_edge(vt.tex_blob(x + 0.12, y - 0.12, radius=0.18 + 0.45 * g, lumps=8, roughness=0.45, seed=21), soft=0.1)
    return a, shade


# ---------------------------------------------------------------- Mummy
def strip(size):
    x, y = vt.tex_coords(size)
    w = 0.22 + 0.03 * np.sin(y * 9)
    edge = np.abs(x) - w + 0.04 * (vt.tex_sample(NOISE, x * 0.3, y * 2.0) - 0.5)
    fray = vt.tex_edge(0.9 - np.abs(y) - 0.08 * (vt.tex_sample(NOISE, x * 3, y * 0.2) - 0.5), soft=0.01)
    a = vt.tex_edge(-edge, soft=0.008) * fray
    lines = np.abs(np.sin((y + x * 0.4) * 22))
    v = np.clip(0.72 + 0.28 * lines - 0.25 * vt.tex_edge(0.04 - np.abs(np.abs(x) - w + 0.03), soft=0.01), 0, 1)
    return np.dstack([v, v, v, a])


def wrap_swirl(t, size):
    x, y = vt.tex_coords(size)
    g = vt.tex_ease(t * 1.5)
    f = np.full_like(x, -1.0)
    for k in range(4):
        a0 = k * np.pi / 2 + t * 3.0
        r0 = 0.85 - 0.45 * g
        th = np.linspace(0, 1.6, 24)
        pts = np.stack([np.cos(a0 + th) * (r0 - 0.1 * th), np.sin(a0 + th) * (r0 - 0.1 * th) * 0.75], 1)
        f = np.maximum(f, vt.tex_stroke(x, y, pts, lambda u: 0.13 * (0.4 + 0.6 * np.sin(np.pi * u))))
    holes = vt.tex_sample(NOISE, x * 0.5, y * 0.5 + t * 0.4) - max(0, t - 0.6) * 3.0 + 0.9
    a = vt.tex_edge(f, soft=0.008) * vt.tex_edge(holes, soft=0.03)
    return a, 0.7 + 0.3 * np.abs(np.sin((x + y) * 30))


vt.draw_texture("WraithGrin", grin, size=512)
vt.draw_flipbook("WraithEmberSwirl", ember_swirl, grid=4, fps=24)
vt.draw_texture("WraithCinder", cinder, size=128)
vt.draw_texture("CatBubble", bubble, size=256)
vt.draw_texture("CatHexSigil", hex_sigil, size=512)
vt.draw_flipbook("CatSmokePuff", smoke_puff, grid=4, fps=24)
vt.draw_texture("MummyStrip", strip, size=256)
vt.draw_flipbook("MummyWrapSwirl", wrap_swirl, grid=4, fps=24)
# bandage beam strip (tiles along the beam)
H, W = 512, 128
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
u = (xx / W - 0.5) * 2
v = yy / H
nz = vt.tex_sample(NOISE, u * 0.5, v * 4)
a = (np.abs(u) < 0.62 + 0.1 * (nz - 0.5)).astype(np.float32)
fold = np.abs(np.sin((v * 8 + u * 0.6) * np.pi))
val = np.clip(0.62 + 0.38 * fold, 0, 1)
Image.fromarray((np.dstack([val, val, val, a]) * 255).astype(np.uint8), "RGBA").save(os.path.join(vt.OUTPUT_DIR, "MummyBandage.png"))
print("done")
