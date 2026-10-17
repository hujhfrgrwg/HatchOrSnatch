# Astral Djinn own ability textures (HOS-PET-026 v2): an eight-point star seal (khatam) with a scalloped rim, a genie
# smoke coil that curls up out of a lamp spout and frays, a constellation of linked stars, a four-point twinkle.
import os, sys
sys.path.insert(0, r"C:\Users\hunte\.claude\skills\roblox-vfx\scripts")
import numpy
import vfxtex as vt
HERE = os.path.dirname(os.path.abspath(__file__))
vt.OUTPUT_DIR = os.path.join(HERE, "out")
os.makedirs(vt.OUTPUT_DIR, exist_ok=True)
NOISE = vt.tex_noise(256, scale=5, seed=262)

def square(x, y, ang, s):
    c, si = numpy.cos(ang), numpy.sin(ang)
    u, v = x * c + y * si, -x * si + y * c
    return s - numpy.maximum(numpy.abs(u), numpy.abs(v))

# Khatam seal: two overlapping squares drawn as outlines (an eight-point star), a small inner star, a scalloped
# outer rim of 16 arcs (symbol). Lines lit, crossing points brighter.
def seal(size):
    x, y = vt.tex_coords(size)
    r, a = vt.tex_polar(x, y)
    s1, s2 = square(x, y, 0, 0.6), square(x, y, numpy.pi / 4, 0.6)
    star = numpy.maximum(s1, s2)
    outline = 0.03 - numpy.abs(star)
    inner = 0.022 - numpy.abs(numpy.maximum(square(x, y, 0, 0.25), square(x, y, numpy.pi / 4, 0.25)))
    scal = 0.025 - numpy.abs(r - (0.86 + 0.05 * numpy.abs(numpy.cos(a * 8))))
    f = numpy.maximum.reduce([outline, inner, scal])
    al = vt.tex_edge(f, soft=0.006)
    v = 0.7 + 0.3 * ((numpy.abs(s1) < 0.03) & (numpy.abs(s2) < 0.03))
    return numpy.dstack([v, v, v, al])

# Genie smoke: a thick plume rises from the bottom, curls over into a hook at the top and frays away with holes.
SPINE = vt.tex_curve([(0.0, -0.85), (0.2, -0.45), (-0.15, 0.0), (0.05, 0.4), (0.4, 0.55), (0.55, 0.3), (0.4, 0.15)], 48)
def smoke(t, size):
    x, y = vt.tex_coords(size)
    wx, wy = vt.tex_warp(x, y, amount=0.07, scale=3, seed=9, t=t)
    grow = vt.tex_ease(t * 2.4)
    f = vt.tex_stroke(wx, wy, SPINE, lambda u: (0.17 + 0.2 * u) * (1 + 0.35 * t), end=0.15 + 0.85 * grow)
    holes = vt.tex_sample(NOISE, x * 0.7, y * 0.7 - t * 0.6) - t * 1.4 + 0.95
    al = vt.tex_edge(f, soft=0.06) * vt.tex_edge(holes, soft=0.05)
    shade = numpy.clip(0.55 + 0.45 * vt.tex_edge(wx - 0.1, soft=0.4), 0, 1)
    return al, shade

# Constellation: seven stars of two sizes linked by thin lines (symbol).
STARS = [(-0.75, -0.35, 1), (-0.4, -0.05, 0), (-0.05, -0.25, 1), (0.25, 0.1, 0), (0.6, -0.05, 1), (0.3, 0.55, 0), (-0.2, 0.6, 0)]
LINKS = [(0, 1), (1, 2), (2, 3), (3, 4), (3, 5), (5, 6), (6, 1)]
def const(size):
    x, y = vt.tex_coords(size)
    f = numpy.full_like(x, -1.0)
    for i, j in LINKS:
        a, b = STARS[i], STARS[j]
        f = numpy.maximum(f, vt.tex_stroke(x, y, numpy.array([a[:2], b[:2]]), [0.012, 0.012]) - 0.0)
    lines = vt.tex_edge(f, soft=0.006) * 0.55
    pts = numpy.zeros_like(x)
    for sx, sy, big in STARS:
        dx, dy = numpy.abs(x - sx), numpy.abs(y - sy)
        R = 0.09 if big else 0.06
        spark = numpy.clip(1 - (numpy.sqrt(dx) + numpy.sqrt(dy)) / numpy.sqrt(R), 0, 1)
        pts = numpy.maximum(pts, spark ** 0.7)
    al = numpy.maximum(lines, pts)
    return al

# Twinkle: a four-point star with long thin arms (pinched curves, not a cross of bars).
def twinkle(size):
    x, y = vt.tex_coords(size)
    dx, dy = numpy.abs(x), numpy.abs(y)
    star = numpy.clip(1 - (numpy.sqrt(dx) + numpy.sqrt(dy)) / numpy.sqrt(0.95), 0, 1)
    core = numpy.clip(1 - numpy.hypot(x, y) / 0.18, 0, 1)
    return numpy.clip(star ** 0.8 + core * 0.5, 0, 1)

vt.draw_texture("DjinnSeal", seal, size=512)
vt.draw_flipbook("DjinnSmoke", smoke, grid=4, fps=24)
vt.draw_texture("DjinnConst", const, size=512)
vt.draw_texture("DjinnTwinkle", twinkle, size=256)
print("done")
