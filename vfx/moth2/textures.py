# Moonveil Moth own ability textures (HOS-PET-023 v2): a four-wing moth silhouette that flares open and dissolves into
# dust, a glittering wing-dust cloud, a wing eyespot (moon-eye). The crescent sprite from vfx/moth is kept.
import os, sys
sys.path.insert(0, r"C:\Users\hunte\.claude\skills\roblox-vfx\scripts")
import numpy
import vfxtex as vt
HERE = os.path.dirname(os.path.abspath(__file__))
vt.OUTPUT_DIR = os.path.join(HERE, "out")
os.makedirs(vt.OUTPUT_DIR, exist_ok=True)
NOISE = vt.tex_noise(256, scale=8, seed=81)
FINE = vt.tex_noise(256, scale=22, seed=82)

# Moth silhouette: four rounded wing lobes (two big upper, two smaller lower) opening from closed to spread, then
# eaten into dust from the edges.
def mothwings(t, size):
    x, y = vt.tex_coords(size)
    op = vt.tex_ease(t * 3)
    f = numpy.full_like(x, -1.0)
    for side in (-1, 1):
        for (cx, cy, rx, ry, ang) in ((0.42, 0.2, 0.42, 0.3, 0.35), (0.3, -0.3, 0.3, 0.24, -0.4)):
            a = ang * op * side
            px, py = (x - side * cx * op), (y - cy * (0.5 + 0.5 * op))
            qx, qy = px * numpy.cos(a) + py * numpy.sin(a), -px * numpy.sin(a) + py * numpy.cos(a)
            f = numpy.maximum(f, 1 - (numpy.abs(qx / (rx * (0.4 + 0.6 * op))) ** 1.3 + numpy.abs(qy / ry) ** 1.3) ** (1 / 1.3))
    body = 1 - numpy.hypot(x / 0.06, y / 0.4)
    f = numpy.maximum(f, body)
    eat = vt.tex_sample(FINE, x * 0.8 + 0.1, y * 0.8) - numpy.clip(t - 0.4, 0, 1) * 1.6 + 0.7
    edge_eat = numpy.hypot(x, y) * numpy.clip(t - 0.4, 0, 1) * 1.8
    a = vt.tex_edge(f * 0.3, soft=0.01) * vt.tex_edge(eat - edge_eat, soft=0.02)
    spot = numpy.zeros_like(x)
    for side in (-1, 1):
        spot = numpy.maximum(spot, vt.tex_edge(0.07 * op - numpy.hypot(x - side * 0.48 * op, y - 0.22), soft=0.01))
    veins = vt.tex_edge(0.015 - numpy.abs(numpy.sin(numpy.arctan2(y, numpy.abs(x) + 0.05) * 5)) * 0.2, soft=0.02)
    return a, numpy.clip(1 - 0.35 * veins, 0.5, 1)

# Wing dust: a loose glittering cloud of fine specks that drifts and thins (light: soft specks).
def dust(t, size):
    x, y = vt.tex_coords(size)
    r = numpy.hypot(x, y)
    spread = 0.3 + 0.5 * vt.tex_ease(t * 2)
    cloud = numpy.exp(-(r / spread) ** 2) * numpy.clip((0.92 - r) / 0.25, 0, 1)
    specks = numpy.clip((vt.tex_sample(FINE, x * 1.3 + t * 0.2, y * 1.3 - t * 0.3) - 0.62) * 6, 0, 1)
    return numpy.clip(specks * cloud * (1 - t) * 1.6 + 0.12 * cloud * (1 - t), 0, 1)

# Moon eyespot: a precise ring-in-ring eyespot with a crescent highlight (symmetric symbol).
def eyespot(size):
    x, y = vt.tex_coords(size)
    r = numpy.hypot(x, y)
    rings = numpy.maximum(0.06 - numpy.abs(r - 0.78), 0.035 - numpy.abs(r - 0.5))
    pupil = 0.24 - r
    cres = numpy.minimum(0.16 - numpy.hypot(x + 0.06, y - 0.06), numpy.hypot(x + 0.0, y - 0.0) - 0.12)
    return vt.tex_edge(numpy.maximum(numpy.maximum(rings, pupil), -1), soft=0.006) * (1 - 0.7 * vt.tex_edge(cres, soft=0.006))

vt.draw_flipbook("MothWingFlash", mothwings, grid=4, fps=24)
vt.draw_flipbook("MothDust", dust, grid=4, fps=16)
vt.draw_texture("MothEyespot", eyespot, size=512)
print("done")
