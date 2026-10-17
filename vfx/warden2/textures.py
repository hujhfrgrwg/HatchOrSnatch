# Crystal Warden own ability textures (HOS-PET-019 v2): a crystal cluster that grows up and cracks, a faceted
# sapphire shard, the Warden's gold crest sigil, a prism beam strip.
import os, sys
sys.path.insert(0, r"C:\Users\hunte\.claude\skills\roblox-vfx\scripts")
import numpy
import vfxtex as vt
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
vt.OUTPUT_DIR = os.path.join(HERE, "out")
os.makedirs(vt.OUTPUT_DIR, exist_ok=True)
NOISE = vt.tex_noise(256, scale=7, seed=101)

# Crystal cluster: uneven angular spires growing from a base, each with a lit and a shadow facet, then cracking apart.
RNG = numpy.random.default_rng(5)
SP = [(RNG.uniform(-0.55, 0.55), RNG.uniform(0.7, 1.5), RNG.uniform(0.12, 0.22), RNG.uniform(-0.35, 0.35)) for _ in range(6)]
def spires(t, size):
    x, y = vt.tex_coords(size)
    g = vt.tex_ease(t * 3)
    f = numpy.full_like(x, -1.0)
    lit = numpy.zeros_like(x)
    for bx, h, w, lean in SP:
        hh = h * g
        top = (bx + lean * hh, -0.8 + hh)
        # a spire is a triangle-ish polygon: distance to its two edges
        for side in (-1, 1):
            pass
        u = (y + 0.8) / max(hh, 1e-3)
        cx = bx + lean * hh * u
        half = w * (1 - u)
        inside = numpy.minimum(half - numpy.abs(x - cx), numpy.minimum(u, 1 - u) * 0.3)
        f = numpy.maximum(f, inside)
        lit = numpy.maximum(lit, (inside > 0) * (x < cx))
    crack = vt.tex_sample(NOISE, x * 0.7, y * 0.7) - numpy.clip(t - 0.5, 0, 1) * 1.8 + 0.6
    a = vt.tex_edge(f, soft=0.006) * vt.tex_edge(crack, soft=0.02)
    return a, 0.55 + 0.45 * lit

# Faceted shard: a long diamond with a centre ridge (lit / shadow halves).
def shard(size):
    x, y = vt.tex_coords(size)
    f = 0.85 - (numpy.abs(x) / 0.35 + numpy.abs(y) / 0.9)
    a = vt.tex_edge(f * 0.3, soft=0.006)
    v = 0.55 + 0.45 * (x < 0) + 0.0 * y
    return numpy.dstack([v, v, v, a])

# Crest sigil: a precise double hexagon with six crystal chevrons pointing out (symbol).
def crest(size):
    x, y = vt.tex_coords(size)
    r, a = vt.tex_polar(x, y)
    hexr = numpy.cos(numpy.pi / 6) / numpy.cos((a % (numpy.pi / 3)) - numpy.pi / 6)
    f = numpy.maximum(0.03 - numpy.abs(r - 0.62 * hexr), 0.018 - numpy.abs(r - 0.5 * hexr))
    for k in range(6):
        ang = k * numpy.pi / 3
        d = numpy.array([numpy.cos(ang), numpy.sin(ang)])
        n = numpy.array([-d[1], d[0]])
        px, py = x - d[0] * 0.78, y - d[1] * 0.78
        along, across = px * d[0] + py * d[1], px * n[0] + py * n[1]
        chev = numpy.minimum(0.16 - along - numpy.abs(across) * 1.6, along + 0.04 + numpy.abs(across) * 0.0)
        f = numpy.maximum(f, numpy.minimum(chev, 0.1 - numpy.abs(across)))
    return vt.tex_edge(f, soft=0.006)

vt.draw_flipbook("WardenSpires", spires, grid=4, fps=24)
vt.draw_texture("WardenShard", shard, size=256)
vt.draw_texture("WardenCrest", crest, size=512)
H, W = 512, 128
yy, xx = numpy.mgrid[0:H, 0:W].astype(numpy.float32)
u = (xx / W - 0.5) * 2
v = (yy / H * 8) % 1
dia = 0.9 - (numpy.abs(u) / 0.8 + numpy.abs(v - 0.5) / 0.55)
a = numpy.clip(dia * 6, 0, 1)
val = numpy.clip(0.6 + 0.4 * (u < 0), 0, 1)
Image.fromarray((numpy.dstack([val, val, val, a]) * 255).astype(numpy.uint8), "RGBA").save(os.path.join(vt.OUTPUT_DIR, "WardenPrism.png"))
print("done")
