# Void Seraph ability textures (HOS-PET-031): a void accretion ring, an angel feather, a precise halo, a wing pair that
# spreads and sheds; AllVFX Swirls "ripplevideo2" (a black hole with a bright rim) for the portal's core.
import os, sys
sys.path.insert(0, r"C:\Users\hunte\.claude\skills\roblox-vfx\scripts")
import numpy
import vfxtex as vt
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
vt.OUTPUT_DIR = os.path.join(HERE, "out")
os.makedirs(vt.OUTPUT_DIR, exist_ok=True)
NOISE = vt.tex_noise(256, scale=6, seed=61)

# Accretion ring: four uneven spiral arms whirling into a hollow centre (the void), tapered, crisp.
def accretion(size):
    x, y = vt.tex_coords(size)
    rng = numpy.random.default_rng(12)
    field = numpy.full_like(x, -1.0)
    for k in range(4):
        a0 = k * numpy.pi / 2 + rng.uniform(-0.3, 0.3)
        th = numpy.linspace(0, rng.uniform(2.2, 3.2), 40)
        r = 0.88 - 0.5 * th / th[-1]
        pts = numpy.stack([numpy.cos(a0 + th) * r, numpy.sin(a0 + th) * r], 1)
        field = numpy.maximum(field, vt.tex_stroke(x, y, pts, lambda u: 0.09 * (1 - u) ** 0.6 + 0.01))
    hole = 0.3 - numpy.hypot(x, y)
    return vt.tex_edge(numpy.minimum(field, -hole), soft=0.007)

# Angel feather: a broad soft-ended vane, slightly curved, with barb lines in the shadow tone.
def feather(size):
    x, y = vt.tex_coords(size)
    spine = vt.tex_curve([(0.05, -0.9), (0.0, -0.2), (-0.1, 0.45), (-0.25, 0.9)], 32)
    vane = vt.tex_stroke(x, y, spine, lambda u: 0.48 * numpy.sin(numpy.clip(u * 1.05, 0, 1) * numpy.pi) ** 0.5 * (0.6 + 0.4 * u))
    alpha = vt.tex_edge(vane, soft=0.008)
    barbs = numpy.abs(numpy.sin((y * 9 - numpy.abs(x) * 6) * numpy.pi))
    shaft = vt.tex_edge(vt.tex_stroke(x, y, spine, [0.03, 0.02, 0.006]), soft=0.006)
    v = numpy.clip(0.75 + 0.25 * barbs - 0.4 * shaft, 0.4, 1)
    return numpy.dstack([v, v, v, alpha])

# Halo: two precise concentric rings and eight small diamond studs (a symbol, symmetric).
def halo(size):
    x, y = vt.tex_coords(size)
    r, a = vt.tex_polar(x, y)
    rings = numpy.maximum(0.03 - numpy.abs(r - 0.82), 0.012 - numpy.abs(r - 0.7))
    studs = numpy.full_like(x, -1.0)
    for k in range(8):
        ang = k * numpy.pi / 4
        cx, cy = numpy.cos(ang) * 0.76, numpy.sin(ang) * 0.76
        studs = numpy.maximum(studs, 0.07 - (numpy.abs(x - cx) + numpy.abs(y - cy)))
    return vt.tex_edge(numpy.maximum(rings, studs), soft=0.006)

# Wing pair: two feathered wings unfolding from the centre to full spread, then shedding into loose feathers.
def wingpair(t, size):
    x, y = vt.tex_coords(size)
    spread = vt.tex_ease(t * 2.5)
    field = numpy.full_like(x, -1.0)
    for side in (-1, 1):
        for j in range(6):
            ang = numpy.radians(10 + 22 * j) * spread + numpy.radians(80) * (1 - spread)
            ln = (0.55 + 0.32 * numpy.sin(j / 5 * numpy.pi)) * (0.4 + 0.6 * spread)
            root = (side * 0.06, -0.05)
            tip = (side * numpy.sin(ang) * ln * 1.1, -0.05 + numpy.cos(ang) * ln * 0.75)
            field = numpy.maximum(field, vt.tex_stroke(x, y, numpy.array([root, ((root[0] + tip[0]) / 2, (root[1] + tip[1]) / 2 + 0.05), tip]),
                                                       [0.03, 0.08 * (1 - 0.4 * t), 0.0]))
    holes = vt.tex_sample(NOISE, x * 0.55 + 0.2, y * 0.55 + t * 0.4) - t * 1.4 + 0.95
    return vt.tex_edge(field, soft=0.007) * vt.tex_edge(holes, soft=0.02)

vt.draw_texture("SeraphAccretion", accretion, size=512)
vt.draw_texture("SeraphFeather", feather, size=256)
vt.draw_texture("SeraphHalo", halo, size=512)
vt.draw_flipbook("SeraphWings", wingpair, grid=4, fps=24)
SRC = os.path.join(HERE, "..", "..", "Assets", "AllVFX", "vfx-texture-pack-2-flipbooks", "2_Flipbooks", "Swirls", "2023-06-20_22-43-37 ripplevideo2.png")
Image.open(SRC).convert("RGBA").resize((1024, 1024), Image.LANCZOS).save(os.path.join(vt.OUTPUT_DIR, "SeraphVoid.flipbook.png"))
print("done")
