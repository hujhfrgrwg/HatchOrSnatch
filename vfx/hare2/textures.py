# Compass Hare own ability textures (HOS-PET-021 v2): a compass rose, a compass needle, a globe-grid ring, a dashed
# map route that draws on and fades.
import os, sys
sys.path.insert(0, r"C:\Users\hunte\.claude\skills\roblox-vfx\scripts")
import numpy
import vfxtex as vt
HERE = os.path.dirname(os.path.abspath(__file__))
vt.OUTPUT_DIR = os.path.join(HERE, "out")
os.makedirs(vt.OUTPUT_DIR, exist_ok=True)

# Compass rose: four long and four short points with a lit and a shadow half on each point, inside a ring (symbol).
def rose(size):
    x, y = vt.tex_coords(size)
    r, a = vt.tex_polar(x, y)
    f = numpy.full_like(x, -1.0)
    lit = numpy.zeros_like(x)
    for k in range(8):
        ang = k * numpy.pi / 4
        L = 0.92 if k % 2 == 0 else 0.55
        W = 0.16 if k % 2 == 0 else 0.11
        d = numpy.array([numpy.cos(ang), numpy.sin(ang)]); n = numpy.array([-d[1], d[0]])
        along, across = x * d[0] + y * d[1], x * n[0] + y * n[1]
        pt = numpy.minimum(W * (1 - along / L) - numpy.abs(across), along + 0.02)
        f = numpy.maximum(f, pt)
        lit = numpy.maximum(lit, (pt > 0) * (across > 0))
    ring = 0.02 - numpy.abs(r - 0.7)
    a_ = vt.tex_edge(numpy.maximum(f, ring), soft=0.006)
    v = 0.55 + 0.45 * lit + 0.45 * (ring > 0)
    return numpy.dstack([numpy.clip(v, 0, 1)] * 3 + [a_])

# Needle: a slim diamond, one half lit (tinted red by the emitter's colour sequence over its life is not possible, so
# the two halves are two tones).
def needle(size):
    x, y = vt.tex_coords(size)
    f = 0.9 - (numpy.abs(x) / 0.12 + numpy.abs(y) / 0.95)
    hub = 0.08 - numpy.hypot(x, y)
    a = vt.tex_edge(numpy.maximum(f * 0.3, hub), soft=0.006)
    v = numpy.where(y > 0, 1.0, 0.5)
    return numpy.dstack([v, v, v, a])

# Globe grid: an outer ring, two latitude ellipses and three meridian arcs (symbol).
def globe(size):
    x, y = vt.tex_coords(size)
    r = numpy.hypot(x, y)
    f = 0.03 - numpy.abs(r - 0.85)
    for ry in (0.35, 0.65):
        f = numpy.maximum(f, numpy.minimum(0.015 - numpy.abs(numpy.hypot(x / 0.85, (y - 0.0) / 0.85) * 0 + numpy.abs(y) - ry * 0.85 * numpy.sqrt(numpy.clip(1 - (x / 0.85) ** 2, 0, 1)) * 0 - ry * 0.85), 0.85 - r))
    for rx in (0.0, 0.45, 0.8):
        f = numpy.maximum(f, numpy.minimum(0.015 - numpy.abs(numpy.hypot(x / max(rx * 0.85, 1e-3), y / 0.85) - 1) * (rx * 0.85 if rx > 0 else 1) if rx > 0 else 0.015 - numpy.abs(x), 0.85 - r))
    return vt.tex_edge(f, soft=0.006)

# Map route: a dashed curving path that draws on from the tail and fades from the start, ending in an X.
ROUTE = vt.tex_curve([(-0.85, -0.6), (-0.4, -0.1), (0.1, -0.35), (0.45, 0.15), (0.75, 0.55)], 60)
def route(t, size):
    x, y = vt.tex_coords(size)
    end = vt.tex_ease(t * 2.5)
    start = numpy.clip((t - 0.5) * 2, 0, 1)
    path = vt.tex_stroke(x, y, ROUTE, [0.055] * 5, start=start, end=end)
    seg = numpy.linspace(0, 1, 61)
    # dash mask from the curve parameter: approximate with the distance along x
    dash = numpy.sin((x * 1.0 + y * 0.6) * 22) > -0.2
    xm = numpy.maximum(vt.tex_stroke(x, y, numpy.array([(0.62, 0.42), (0.88, 0.68)]), [0.04, 0.04]),
                       vt.tex_stroke(x, y, numpy.array([(0.62, 0.68), (0.88, 0.42)]), [0.04, 0.04])) if end > 0.95 else numpy.full_like(x, -1.0)
    return numpy.maximum(vt.tex_edge(path, soft=0.006) * dash, vt.tex_edge(xm, soft=0.006))

vt.draw_texture("HareRose", rose, size=512)
vt.draw_texture("HareNeedle", needle, size=256)
vt.draw_texture("HareGlobe", globe, size=512)
vt.draw_flipbook("HareRoute", route, grid=4, fps=24)
print("done")
