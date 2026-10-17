# Void Seraph (Rift, Legendary) for Hatch or Snatch: HOS-PET-031, built on the pet kit (flier helpers from the Tengu).
# Redone 17 Oct (HOS-PET-REDO, Hunter: "a small pale cat with wings, plainer than the Epics"): a void-black indigo
# coat with a magenta nebula and glowing stars, a pearl chest ruff and muzzle, gold circlet, collar and wing arms,
# and big layered angel wings made of pointed feathers (pearl -> lilac -> violet with glowing magenta tips).
# From the concept card (docs/pets/void_seraph/void_seraph_card.png): a pale lavender-white winged beast with big
# feathered angel wings, a gold circlet and gold collar, gold eyes, wrapped in violet void energy and magenta portals.
# Read through PET_LESSONS (anime / edgy): ivory-lavender fur with fur strokes split by glowing magenta void cracks,
# feathers that darken from white to void-violet with a glowing magenta rim, narrow slanted gold slit eyes with dark
# violet liner, a flat mouth (face decal shell), sharp pointed ears, a long tail ending in a void wisp. It hovers.
# L2 "Twin Halo": a second, lower pair of wings and a gold halo ring. L3 "Six-Winged Void": a third pair of small
# wings at the temples, a black void eye with a magenta rim behind the head, violet crystal crown points,
# magenta-gold eyes and glow.
import math, os, sys
try:
    _d = os.path.dirname(os.path.abspath(__file__))
    while not os.path.exists(os.path.join(_d, 'petkit.py')) and os.path.dirname(_d) != _d:
        _d = os.path.dirname(_d)
    if os.path.exists(os.path.join(_d, 'petkit.py')):
        sys.path.insert(0, _d)
except NameError:
    pass
from petkit import *   # noqa: F401,F403
import numpy as np

NAME = 'Seraph'
SHARP_ANGLE = 40
NORMAL_STRENGTH = 1.8
TS = 1024
ATLAS = Atlas({
    'skin': (0, 0, 1024, 384),      # body loft: u around (0 = back), v tail root -> head top
    'wing': (0, 384, 512, 256),     # main wings
    'wing2': (512, 384, 512, 256),  # L2 / L3 wings
    'tail': (0, 640, 256, 128),
    'ear': (256, 640, 128, 128),
    'muzzle': (384, 640, 128, 128),
    'gold': (512, 640, 256, 128),
    'gem': (768, 640, 128, 128),
    'wisp': (896, 640, 128, 128),
    'limb': (0, 768, 256, 128),
    'void': (256, 768, 256, 128),   # L3 void eye
    'crystal': (512, 768, 256, 128),
    'warm': (768, 768, 256, 128),   # wing arm (gold)
    'ruff': (0, 896, 256, 128),     # pearl chest ruff: v root -> tip
})

GLOW = {1: ('5a1a8a', 'd04aff', 'f8e0ff'), 2: ('5a1a9a', 'e050ff', 'fbe8ff'), 3: ('7a0a6a', 'ff3ad8', 'ffe8fa')}
EYE = {1: ('8a5a04', 'ffcc3a', 'fff6d0'), 2: ('8a5a04', 'ffd84a', 'fffae0'), 3: ('8a0a6a', 'ff5ad8', 'fff0fa')}
FUR = [(0, '080314'), (0.5, '22104a'), (1, '4a2a88')]      # void coat (redo; was ivory-lavender)
PEARL = [(0, 'b8a8e0'), (0.6, 'eae4fa'), (1, 'fcfaff')]


def bones_def():
    b = [
        ('Root', V(0, 0, 0), V(0, 0, 0.2), None),
        ('Body', V(0, 0.08, 0.96), V(0, -0.08, 1.14), 'Root'),
        ('Head', V(0, -0.12, 1.24), V(0, -0.2, 1.56), 'Body'),
        ('Tail1', V(0, 0.4, 0.82), V(0, 0.72, 0.7), 'Body'),
        ('Tail2', V(0, 0.72, 0.7), V(0, 0.98, 0.86), 'Tail1'),
        ('Halo', V(0, 0.06, 1.62), V(0, 0.06, 1.82), 'Body'),
    ]
    for s, x in (('L', 1), ('R', -1)):
        b += [
            ('Wing.' + s, V(x * 0.16, 0.04, 1.12), V(x * 0.9, 0.12, 1.6), 'Body'),
            ('Wing2.' + s, V(x * 0.15, 0.16, 0.92), V(x * 0.7, 0.3, 0.7), 'Body'),
            ('Wing3.' + s, V(x * 0.14, -0.12, 1.5), V(x * 0.45, -0.02, 1.72), 'Head'),
            ('Leg.' + s, V(x * 0.1, -0.06, 0.92), V(x * 0.12, -0.16, 0.66), 'Body'),
            ('Hind.' + s, V(x * 0.14, 0.3, 0.84), V(x * 0.16, 0.24, 0.62), 'Body'),
        ]
    return b


def _cum(centers):
    c = [np.asarray(p, float) for p in centers]
    d = [0.0]
    for a, b in zip(c, c[1:]):
        d.append(d[-1] + float(np.linalg.norm(b - a)))
    return [x / max(d[-1], 1e-9) for x in d]


def tube(mb, region, centers, radii, n, weights, part, start='point', end='point', start_pt=None, end_pt=None,
         side_hint=None, anti=True, th0=-math.pi / 2):
    vv = _cum(centers)

    def profile(k, nn, a, b, i):
        th = th0 + 2 * math.pi * (k + (0.5 if (anti and i % 2) else 0.0)) / nn
        return a * math.cos(th), b * math.sin(th)

    def uvf(i, k, seg, fk):
        return ATLAS.uv(region, k / n, vv[i])
    return loft(mb, centers, radii, n, weights, uvf, part, start=start, end=end, profile=profile,
                start_pt=start_pt, end_pt=end_pt, side_hint=side_hint)


def wing(mb, region, root, pts, w, part, thick=0.04):
    """a flat wing: a fan of triangles from the root to an outline (pts), both faces, planar UV across the region."""
    root = np.asarray(root, float)
    allp = [root] + [np.asarray(p, float) for p in pts]
    xs = [p[0] for p in allp]; zs = [p[2] for p in allp]
    span = max(abs(max(xs) - root[0]), abs(min(xs) - root[0]), 1e-6)
    zmin, zmax = min(zs), max(zs)

    def uv(p):
        a = abs(p[0] - root[0]) / span
        b = (p[2] - zmin) / max(zmax - zmin, 1e-6)
        return ATLAS.uv(region, 0.02 + 0.96 * a, 0.02 + 0.96 * (1 - b))
    n = nrm(np.cross(allp[1] - root, allp[-1] - root))
    top = [mb.vert(p + n * thick * 0.5, w) for p in allp]
    bot = [mb.vert(p - n * thick * 0.5, w) for p in allp]
    c = sum(allp) / len(allp)
    for i in range(1, len(allp) - 1):
        mb.face([top[0], top[i], top[i + 1]], [uv(allp[0]), uv(allp[i]), uv(allp[i + 1])], inside=c - n, part=part)
        mb.face([bot[0], bot[i + 1], bot[i]], [uv(allp[0]), uv(allp[i + 1]), uv(allp[i])], inside=c + n, part=part)
    for i in range(1, len(allp) - 1):
        mb.face([top[i], bot[i], bot[i + 1], top[i + 1]], [uv(allp[i])] * 2 + [uv(allp[i + 1])] * 2, inside=c, part=part)


def ring(mb, region, c, normal, R, r, n_around, n_tube, w, part, arc=1.0, a0=0.0):
    normal = nrm(np.asarray(normal, float))
    a = nrm(np.cross(normal, V(0, 0, 1) if abs(normal[2]) < 0.9 else V(1, 0, 0)))
    b = np.cross(normal, a)
    m = n_around + 1
    cen = [np.asarray(c, float) + (a * math.cos(a0 + 2 * math.pi * arc * i / n_around) + b * math.sin(a0 + 2 * math.pi * arc * i / n_around)) * R
           for i in range(m)]
    rad = [(r * (math.sin(math.pi * i / n_around) * 0.85 + 0.15) if arc < 1 else r,) * 2 for i in range(m)]
    tube(mb, region, cen, rad, n_tube, [w] * m, part, start='point' if arc < 1 else 'open', end='point' if arc < 1 else 'open',
         side_hint=normal, anti=False)
    return a, b


def disc(mb, region, c, normal, R, n, w, part, thick=0.03):
    """a thin closed disc (both faces), radial UV."""
    normal = nrm(np.asarray(normal, float))
    a = nrm(np.cross(normal, V(0, 0, 1)))
    b = np.cross(normal, a)
    c = np.asarray(c, float)
    pts = [c + (a * math.cos(2 * math.pi * i / n) + b * math.sin(2 * math.pi * i / n)) * R for i in range(n)]
    for sgn in (1, -1):
        ci = mb.vert(c + normal * thick * 0.5 * sgn, w)
        ring_ = [mb.vert(p + normal * thick * 0.5 * sgn, w) for p in pts]
        for i in range(n):
            j = (i + 1) % n
            mb.face([ci, ring_[i], ring_[j]], [ATLAS.uv(region, 0.5, 0.5), ATLAS.uv(region, 0.5 + 0.48 * math.cos(2 * math.pi * i / n), 0.5 + 0.48 * math.sin(2 * math.pi * i / n)),
                                               ATLAS.uv(region, 0.5 + 0.48 * math.cos(2 * math.pi * j / n), 0.5 + 0.48 * math.sin(2 * math.pi * j / n))],
                    inside=c - normal * sgn, part=part)


FX, FZ, FZH = 0.31, 1.44, 0.24
HEAD_C = V(0, -0.18, 1.44)


def _vnormals(mb, faces):
    acc = {}
    for fi in faces:
        f = mb.F[fi]
        a, b, c = mb.V[f[0]], mb.V[f[1]], mb.V[f[2]]
        n = np.cross(b - a, c - a)
        for v in f:
            acc[v] = acc.get(v, np.zeros(3)) + n
    return {v: nrm(n) for v, n in acc.items()}


def face_shell(mb, faces, lift=0.008):
    sel = [fi for fi in faces if all(mb.V[v][1] < -0.2 and 1.22 < mb.V[v][2] < 1.64 for v in mb.F[fi])]
    vn = _vnormals(mb, faces)
    remap = {}
    for fi in sel:
        for v in mb.F[fi]:
            if v not in remap:
                remap[v] = mb.vert(mb.V[v] + vn[v] * lift, dict(mb.W[v]))
    face_shell.src = dict(remap)
    for fi in sel:
        f = mb.F[fi]
        uvs = [(0.5 + mb.V[v][0] / (2 * FX), 0.5 + (mb.V[v][2] - FZ) / (2 * FZH)) for v in f]
        mb.face([remap[v] for v in f], uvs, part='faceshell')


def _arm_pt(S, E, Wr, t):
    """a point t of the way along the wing arm, from the wrist (0) via the elbow to the shoulder (1)."""
    if t < 0.5:
        return Wr + (E - Wr) * (t / 0.5)
    return E + (S - E) * ((t - 0.5) / 0.5)


def fwing(mb, x, S, E, Wr, w, part, k=1.0, prim=None, sec=None, cov=None, arm=True, back=0.12):
    """a layered angel wing: a gold arm, long pointed primaries fanned from the wrist, secondaries hanging from the
    arm, a row of shorter pearl-gold coverts over them. Angles in degrees from the outward horizontal (+ = up)."""
    S, E, Wr = np.asarray(S, float), np.asarray(E, float), np.asarray(Wr, float)
    if arm:
        tube(mb, 'warm', [S, E, Wr], [(0.07 * k, 0.07 * k), (0.055 * k, 0.055 * k), (0.04 * k, 0.04 * k)], 6, [w] * 3, part,
             start='point', end='point', start_pt=S - (E - S) * 0.15, end_pt=Wr + nrm(Wr - E) * 0.1 * k, side_hint=V(0, 1, 0))

    def feather(base, ang, ln, wd, u, yoff=0.0):
        a = math.radians(ang)
        d = nrm(V(x * math.cos(a), back, math.sin(a)))
        b0 = base + V(0, yoff, 0)
        side = nrm(np.cross(d, V(0, 1, 0)))
        bipyramid(mb, b0, b0 + d * ln * k, side, V(0, 1, 0), wd * k, 0.035 * k, w, ATLAS.uv('wing', u, 0.04),
                  ATLAS.uv('wing', u, 0.96), part, wide_at=0.34, ridge_at=0.34)
    for i, (ang, ln) in enumerate(prim or ()):
        feather(Wr - nrm(Wr - E) * 0.03, ang, ln, 0.25, 0.08 + 0.08 * (i % 4), yoff=0.012 * i)
    for i, (t, ang, ln) in enumerate(sec or ()):
        feather(_arm_pt(S, E, Wr, t), ang, ln, 0.27, 0.4 + 0.08 * (i % 3), yoff=0.01)
    for i, (t, ang, ln) in enumerate(cov or ()):
        feather(_arm_pt(S, E, Wr, t), ang, ln, 0.2, 0.86, yoff=-0.035)


PRIM = [(84, 0.52), (71, 0.64), (58, 0.76), (45, 0.85), (32, 0.9), (19, 0.9), (6, 0.84), (-7, 0.76), (-20, 0.68)]
SEC = [(0.1, -33, 0.66), (0.22, -40, 0.64), (0.34, -47, 0.6), (0.46, -54, 0.56), (0.58, -61, 0.52), (0.7, -68, 0.46),
       (0.82, -75, 0.4), (0.94, -82, 0.34)]
COV = [(0.06, 30, 0.42), (0.2, -10, 0.38), (0.35, -28, 0.36), (0.5, -40, 0.32), (0.65, -52, 0.28), (0.8, -62, 0.24)]


def _wing_outline(x, tip, root_low, n_feath, lead):
    """leading edge points (lead), then a jagged trailing edge of feather tips from the tip down to root_low."""
    pts = [V(x * p[0], p[1], p[2]) for p in lead]
    tx, ty, tz = tip
    lx, ly, lz = root_low
    for i in range(n_feath + 1):
        t = i / n_feath
        px = tx + (lx - tx) * t
        pz = tz + (lz - tz) * t - 0.1 * math.sin(math.pi * t)
        py = ty + (ly - ty) * t
        if i % 2 == 1:      # notch between feathers
            px -= 0.07 * (1 - 0.5 * t); pz += 0.06
        pts.append(V(x * px, py, pz))
    return pts



def build():
    mb = MB()
    mb.mat = 0
    W_B, W_H = {'Body': 1}, {'Head': 1}
    # one loft: tail root -> hips -> chest -> neck -> round head (a small beast floating upright)
    st = [(V(0, 0.42, 0.8), (0.1, 0.09), {'Body': 0.6, 'Tail1': 0.4}), (V(0, 0.3, 0.86), (0.2, 0.19), W_B),
          (V(0, 0.1, 0.94), (0.26, 0.26), W_B), (V(0, -0.06, 1.08), (0.25, 0.25), W_B),
          (V(0, -0.12, 1.22), (0.15, 0.15), {'Body': 0.5, 'Head': 0.5}),
          (V(0, -0.18, 1.35), (0.28, 0.25), W_H), (V(0, -0.18, 1.5), (0.26, 0.23), W_H), (V(0, -0.14, 1.63), (0.13, 0.13), W_H)]
    n0 = len(mb.F)
    tube(mb, 'skin', [s[0] for s in st], [s[1] for s in st], 18, [s[2] for s in st], 'body', start='point', end='point',
         start_pt=V(0, 0.48, 0.76), end_pt=V(0, -0.1, 1.67), side_hint=V(1, 0, 0), th0=math.pi / 2)
    body_faces = list(range(n0, len(mb.F)))
    # short cat muzzle
    tube(mb, 'muzzle', [V(0, -0.33, 1.35), V(0, -0.4, 1.33), V(0, -0.44, 1.31)], [(0.12, 0.08), (0.09, 0.065), (0.05, 0.04)],
         8, [W_H] * 3, 'muzzle', start='point', end='point', start_pt=V(0, -0.27, 1.36), end_pt=V(0, -0.46, 1.3), side_hint=V(1, 0, 0))
    gb, gt = ATLAS.uv('gold', 0.5, 0.05), ATLAS.uv('gold', 0.5, 0.95)
    for s, x in (('L', 1), ('R', -1)):
        # tall sharp ears
        bipyramid(mb, V(x * 0.1, -0.16, 1.56), V(x * 0.24, -0.08, 1.9), V(0, 1, 0), V(0, -1, 0.1), 0.17, 0.06, W_H,
                  ATLAS.uv('ear', 0.5, 0.9), ATLAS.uv('ear', 0.5, 0.05), 'ear', wide_at=0.32, ridge_at=0.32)
        # big feathered main wings, swept up like the card
        Ww = {'Wing.' + s: 1}
        fwing(mb, x, V(x * 0.16, 0.06, 1.14), V(x * 0.46, 0.1, 1.54), V(x * 0.8, 0.14, 1.9), Ww, 'wing',
              prim=PRIM, sec=SEC, cov=COV)
        # tucked paws
        Wl = {'Leg.' + s: 1}
        tube(mb, 'limb', [V(x * 0.1, -0.06, 0.94), V(x * 0.12, -0.12, 0.78), V(x * 0.12, -0.18, 0.68)],
             [(0.07, 0.07), (0.05, 0.05), (0.055, 0.05)], 6, [Wl] * 3, 'leg', start='point', end='point',
             start_pt=V(x * 0.09, -0.02, 1.0), end_pt=V(x * 0.12, -0.22, 0.64))
        Wk = {'Hind.' + s: 1}
        tube(mb, 'limb', [V(x * 0.14, 0.3, 0.86), V(x * 0.16, 0.26, 0.72), V(x * 0.16, 0.2, 0.64)],
             [(0.09, 0.09), (0.06, 0.06), (0.06, 0.05)], 6, [Wk] * 3, 'leg', start='point', end='point',
             start_pt=V(x * 0.12, 0.3, 0.92), end_pt=V(x * 0.16, 0.16, 0.6))
    # a pearl ruff spilling over the chest and round the neck
    for k in range(9):
        a = math.radians(-110 + 220 * k / 8)
        b0 = V(math.sin(a) * 0.17, -0.14 - math.cos(a) * 0.14, 1.16)
        d = nrm(V(math.sin(a) * 0.9, -math.cos(a) * 0.7, -0.75))
        bipyramid(mb, b0, b0 + d * (0.28 if abs(a) < 0.6 else 0.22), V(math.cos(a), math.sin(a), 0), V(0, 0, 1), 0.15, 0.05,
                  W_B, ATLAS.uv('ruff', 0.5, 0.05), ATLAS.uv('ruff', 0.5, 0.95), 'ruff', wide_at=0.35, ridge_at=0.35)
    # gold circlet round the brow with a violet gem, gold collar with a pendant
    ring(mb, 'gold', V(0, -0.18, 1.55), V(0, 0.35, 1), 0.2, 0.025, 14, 4, W_H, 'gold')
    bipyramid(mb, V(0, -0.38, 1.58), V(0, -0.38, 1.7), V(1, 0, 0), V(0, -1, 0), 0.08, 0.06, W_H,
              ATLAS.uv('gem', 0.5, 0.1), ATLAS.uv('gem', 0.5, 0.9), 'gem')
    for x in (1, -1):
        bipyramid(mb, V(x * 0.08, -0.36, 1.6), V(x * 0.16, -0.32, 1.74), V(0, 1, 0), V(0, -1, 0), 0.05, 0.03, W_H, gb, gt, 'gold', wide_at=0.3)
    ring(mb, 'gold', V(0, -0.12, 1.2), V(0, -0.35, 1), 0.17, 0.03, 12, 4, W_B, 'gold')
    bipyramid(mb, V(0, -0.3, 1.14), V(0, -0.32, 0.98), V(1, 0, 0), V(0, -1, 0), 0.1, 0.05, W_B, gb, gt, 'gold', wide_at=0.4)
    # long tail with a void wisp tuft
    tube(mb, 'tail', [V(0, 0.42, 0.8), V(0, 0.66, 0.72), V(0, 0.86, 0.76), V(0, 0.98, 0.88)], [(0.07, 0.07), (0.06, 0.06), (0.05, 0.05), (0.04, 0.04)],
         6, [{'Body': 0.4, 'Tail1': 0.6}, {'Tail1': 1}, {'Tail2': 1}, {'Tail2': 1}], 'tail', start='point', end='point',
         start_pt=V(0, 0.36, 0.82), end_pt=V(0, 1.02, 0.94))
    for d in (V(0.4, 0.6, 0.6), V(-0.4, 0.6, 0.6), V(0, 0.4, 1), V(0, 1, 0.2)):
        bipyramid(mb, V(0, 0.96, 0.88), V(0, 0.96, 0.88) + nrm(d) * 0.26, V(1, 0, 0) if abs(d[0]) < 0.1 else V(0, 1, 0), V(0, 0, 1),
                  0.13, 0.04, {'Tail2': 1}, ATLAS.uv('wisp', 0.5, 0.05), ATLAS.uv('wisp', 0.5, 0.95), 'tail', wide_at=0.3, ridge_at=0.3, curl=0.15)
    mb.mat = 1
    face_shell(mb, body_faces)
    # ---- L2 "Twin Halo": a lower wing pair, a gold halo ring
    mb.mat = 2
    for s, x in (('L', 1), ('R', -1)):
        fwing(mb, x, V(x * 0.15, 0.18, 0.96), V(x * 0.36, 0.24, 0.94), V(x * 0.58, 0.3, 0.86), {'Wing2.' + s: 1}, 'L2',
              k=0.72, prim=[(-4, 0.62), (-20, 0.72), (-36, 0.74), (-52, 0.66), (-68, 0.54)],
              sec=[(0.3, -74, 0.5), (0.6, -82, 0.42)], cov=[(0.15, -20, 0.34), (0.45, -45, 0.3)], back=0.2)
    ring(mb, 'gold', V(0, 0.06, 1.8), V(0, 0.15, 1), 0.26, 0.022, 16, 4, {'Halo': 1}, 'L2')
    # ---- L3 "Six-Winged Void": temple wings, a void eye behind the head, crystal crown points
    mb.mat = 3
    for s, x in (('L', 1), ('R', -1)):
        fwing(mb, x, V(x * 0.14, -0.1, 1.52), V(x * 0.26, -0.06, 1.62), V(x * 0.38, -0.02, 1.74), {'Wing3.' + s: 1}, 'L3',
              k=0.5, prim=[(78, 0.6), (56, 0.72), (34, 0.74), (12, 0.66)], cov=[(0.2, 20, 0.36)], back=0.3)
        bipyramid(mb, V(x * 0.12, -0.3, 1.66), V(x * 0.2, -0.26, 1.88), V(0, 1, 0), V(0, -1, 0), 0.06, 0.05, W_H,
                  ATLAS.uv('crystal', 0.5, 0.1), ATLAS.uv('crystal', 0.5, 0.95), 'L3', wide_at=0.35)
    bipyramid(mb, V(0, -0.36, 1.68), V(0, -0.34, 1.94), V(1, 0, 0), V(0, -1, 0), 0.07, 0.05, W_H,
              ATLAS.uv('crystal', 0.5, 0.1), ATLAS.uv('crystal', 0.5, 0.95), 'L3', wide_at=0.35)
    disc(mb, 'void', V(0, 0.2, 1.5), V(0, 1, -0.1), 0.34, 16, {'Halo': 1}, 'L3', thick=0.02)
    mb.mat = 0
    return mb


# ----------------------------------------------------------------- painting
def _saw(x):
    f = x - np.floor(x)
    return 1 - np.abs(2 * f - 1)


def _streaks(h, w, cells, seed):
    a = vnoise(max(8, h // 24), 2 * w, cells, seed)
    t = (np.arange(w, dtype=np.float32) / w)[None, :]
    a = a[:, w:] * (1 - t) + a[:, :w] * t
    yi = np.linspace(0, a.shape[0] - 1, h)
    i0 = np.floor(yi).astype(int)
    i1 = np.minimum(i0 + 1, a.shape[0] - 1)
    f = (yi - i0)[:, None]
    return (a[i0] * (1 - f) + a[i1] * f) - 0.5


def _reg(name):
    y0, y1, x0, x1 = ATLAS.px(name)
    h, w = y1 - y0, x1 - x0
    v, u = np.mgrid[0:h, 0:w].astype(np.float32)
    return (y0, y1, x0, x1), v / h, u / w


VOIDC = [(0, '0a0418'), (0.5, '3a1460'), (1, '8a4ad8')]


def paint_atlas(level):
    col = np.zeros((TS, TS, 3), np.float32)
    hgt = np.full((TS, TS), 0.5, np.float32)
    rgh = np.full((TS, TS), 0.6, np.float32)
    glow = np.zeros((TS, TS), np.float32)
    gd, gm, gh = GLOW[level]
    # body: a void-black indigo coat with a magenta nebula and glowing stars, a pearl chest, glowing magenta cracks
    (y0, y1, x0, x1), v, u = _reg('skin')
    h, w = y1 - y0, x1 - x0
    top = np.cos(u * 2 * math.pi)
    c = grad(np.clip(0.45 + 0.4 * top, 0, 1), FUR)
    neb = ss(0.5, 0.85, vnoise(h, w, 9, 63)) * ss(0.25, 0.8, vnoise(h, w, 22, 64))
    c = c * (1 - 0.55 * neb[..., None]) + grad(neb, [(0, '3a1470'), (1, 'b03ad0')]) * (0.55 * neb[..., None])
    star = ss(0.93, 0.965, vnoise(h, w, 260, 65)) * ss(0.2, 0.6, vnoise(h, w, 30, 66))
    c = c * (1 - star[..., None]) + hx('fff4ff') * star[..., None]
    under = ss(-0.35, -0.8, top + 0.15 * _saw(v * 14)) * ss(0.78, 0.6, v) * ss(0.3, 0.45, v)
    c = c * (1 - 0.9 * under[..., None]) + grad(np.clip(1 - np.abs(top + 1) * 2, 0, 1), PEARL) * (0.9 * under[..., None])
    side = np.abs(np.sin(u * 2 * math.pi))
    crack = ss(0.012, 0.0, np.abs(_saw(v * 5 + 0.6 * _saw(u * 3)) - 0.5) - 0.012) * ss(0.55, 0.8, side) * ss(0.12, 0.2, v) * ss(0.62, 0.55, v)
    c = c * (1 - crack[..., None]) + hx(gm) * crack[..., None]
    st = _streaks(h, w, 170, 61)
    col[y0:y1, x0:x1] = c * (1 + 0.18 * st[..., None])
    hgt[y0:y1, x0:x1] = 0.5 + 0.4 * st
    glow[y0:y1, x0:x1] = np.maximum(crack * (0.6 if level == 1 else 1.0), star * 0.9)
    # feather blades (u < 0.75: flight feathers, pearl -> lilac -> violet, glowing magenta tips; u > 0.8: pearl-gold
    # coverts), a dark shaft-side shading so neighbouring feathers separate
    (y0, y1, x0, x1), v, u = _reg('wing')
    st = _streaks(y1 - y0, x1 - x0, 50, 67)
    fl = grad(np.clip(v, 0, 1), [(0, 'fcfaff'), (0.45, 'ece4fc'), (0.66, 'b49ae8'), (0.8, '5a2aa8'), (0.9, gm), (1, gh)])
    fl = fl * (0.85 + 0.3 * _saw(u * 12.5)[..., None] * 0.5)
    cv = grad(np.clip(v, 0, 1), [(0, 'ffe8a0'), (0.3, 'f8f0ff'), (0.85, 'e8dcff'), (1, 'b89ae8')])
    isc = ss(0.75, 0.8, u)
    c = fl * (1 - isc[..., None]) + cv * isc[..., None]
    col[y0:y1, x0:x1] = c * (1 + 0.12 * st[..., None])
    hgt[y0:y1, x0:x1] = 0.5 + 0.3 * st
    rgh[y0:y1, x0:x1] = 0.5
    glow[y0:y1, x0:x1] = ss(0.84, 0.95, v) * (1 - isc) * (0.8 if level == 1 else 1.0)
    (y0, y1, x0, x1), v, u = _reg('ruff')
    st = _streaks(y1 - y0, x1 - x0, 40, 68)
    col[y0:y1, x0:x1] = grad(np.clip(v, 0, 1), [(0, 'd0c4f0'), (0.5, 'fcfaff'), (0.85, 'e8d8ff'), (1, gm)]) * (1 + 0.15 * st[..., None])
    glow[y0:y1, x0:x1] = ss(0.85, 1.0, v) * 0.6
    for reg in ('wing2',):
        (y0, y1, x0, x1), v, u = _reg(reg)
        A, B = u, 1 - v
        nf = 12 if reg == 'wing' else 8
        fl = np.abs(_saw(A * nf * 0.5 + B * 2.2) - 0.5)
        lines = ss(0.04, 0.0, fl - 0.02)
        teeth = 0.6 + 0.1 * _saw(B * 14) - 0.06 * B
        dark = ss(0.0, 0.08, A - teeth)
        base = grad(np.clip(0.45 + 0.6 * (1 - A), 0, 1), FUR)
        tip = grad(np.clip((A - teeth) * 3, 0, 1), [(0, '6a4ab8'), (0.5, '2a0c50'), (1, '0a0418')])
        c = base * (1 - dark[..., None]) + tip * dark[..., None]
        rim = ss(0.03, 0.0, np.abs(A - teeth - 0.01) - 0.012)
        c = c * (1 - rim[..., None]) + hx(gm) * rim[..., None]
        c = c * (1 - 0.35 * lines[..., None])
        cov = ss(0.0, 0.04, 0.22 - A + 0.05 * _saw(B * 18))
        c = c * (1 - 0.15 * cov[..., None])
        col[y0:y1, x0:x1] = c
        hgt[y0:y1, x0:x1] = 0.5 - 0.25 * lines + 0.1 * cov
        rgh[y0:y1, x0:x1] = 0.55
        glow[y0:y1, x0:x1] = np.clip(rim * (0.7 + 0.3 * (level >= 2)) + dark * 0.15 * (level >= 2), 0, 1)
    (y0, y1, x0, x1), v, u = _reg('warm')
    eng = ss(0.02, 0.0, np.abs(_saw(v * 6) - 0.5) - 0.04)
    col[y0:y1, x0:x1] = grad(np.cos(u * 2 * math.pi) * 0.5 + 0.5, [(0, '8a5a08'), (0.55, 'f0b030'), (1, 'fff0a0')]) * (1 - 0.4 * eng[..., None])
    rgh[y0:y1, x0:x1] = 0.25
    (y0, y1, x0, x1), v, u = _reg('tail')
    col[y0:y1, x0:x1] = grad(np.clip(v * 1.2, 0, 1), [(0, '180a34'), (0.6, '3a1878'), (1, '7a2ab8')])
    (y0, y1, x0, x1), v, u = _reg('wisp')
    col[y0:y1, x0:x1] = grad(v, [(0, '3a1460'), (0.5, gm), (1, gh)])
    glow[y0:y1, x0:x1] = 0.4 + 0.5 * v
    (y0, y1, x0, x1), v, u = _reg('ear')
    inner = ss(0.32, 0.42, np.cos(u * 2 * math.pi) * 0.5 + 0.5) * ss(0.95, 0.75, v)
    col[y0:y1, x0:x1] = grad(v, FUR) * (1 - inner[..., None]) + grad(v, [(0, '6a1a9a'), (1, gm)]) * inner[..., None]
    glow[y0:y1, x0:x1] = inner * 0.5
    (y0, y1, x0, x1), v, u = _reg('muzzle')
    col[y0:y1, x0:x1] = grad(v, [(0, 'fcfaff'), (0.8, 'e4dcf6'), (1, '1a0c30')])
    (y0, y1, x0, x1), v, u = _reg('limb')
    paw = ss(0.72, 0.8, v)
    col[y0:y1, x0:x1] = grad(np.clip(0.8 - 0.3 * v, 0, 1), FUR) * (1 - paw[..., None]) + hx('eee8fc') * paw[..., None]
    (y0, y1, x0, x1), v, u = _reg('gold')
    eng = ss(0.02, 0.0, np.abs(_saw(v * 5) - 0.5) - 0.03)
    col[y0:y1, x0:x1] = grad(u, [(0, 'fff0a0'), (0.45, 'f0b030'), (1, '8a5a08')]) * (1 - 0.35 * eng[..., None])
    rgh[y0:y1, x0:x1] = 0.25
    glow[y0:y1, x0:x1] = 0.12
    (y0, y1, x0, x1), v, u = _reg('gem')
    col[y0:y1, x0:x1] = grad(v, [(0, 'ffd0ff'), (0.5, 'b03ae0'), (1, '3a0a60')])
    rgh[y0:y1, x0:x1] = 0.1
    glow[y0:y1, x0:x1] = 0.8
    (y0, y1, x0, x1), v, u = _reg('crystal')
    facet = 0.5 + 0.5 * np.sign(np.sin(u * 2 * math.pi * 3))
    col[y0:y1, x0:x1] = grad(v, [(0, '3a0a60'), (0.6, gm), (1, gh)]) * (0.8 + 0.2 * facet[..., None])
    glow[y0:y1, x0:x1] = 0.4 + 0.5 * v
    (y0, y1, x0, x1), v, u = _reg('void')
    r = np.sqrt((u - 0.5) ** 2 + (v - 0.5) ** 2) / 0.48
    col[y0:y1, x0:x1] = grad(np.clip(r, 0, 1), [(0, '000000'), (0.62, '0a0418'), (0.8, '6a1aa8'), (0.92, gm), (1, gh)])
    glow[y0:y1, x0:x1] = ss(0.7, 0.95, r)
    paint_atlas._glow = np.clip(glow, 0, 1)
    return np.clip(col, 0, 1), hgt, rgh


def emissive_mask(level):
    paint_atlas(level)
    return np.repeat(paint_atlas._glow[..., None], 3, -1)


def _seg(X, Z, a, b, w0, w1):
    ax, az = a; bx, bz = b
    dx, dz = bx - ax, bz - az
    L2 = dx * dx + dz * dz
    t = np.clip(((X - ax) * dx + (Z - az) * dz) / L2, 0, 1)
    d = np.sqrt((X - ax - t * dx) ** 2 + (Z - az - t * dz) ** 2)
    wd = w0 + (w1 - w0) * t
    return ss(wd, wd - 0.003, d)


def _face_layers(level, size):
    x, y = coords(size)
    X, Z = x * FX, FZ + y * FZH
    aX = np.abs(X)
    ix, iz, ox, oz = 0.06, 1.44, 0.18, 1.5
    ex, ez = ox - ix, oz - iz
    L = math.hypot(ex, ez)
    s = ((aX - ix) * ex + (Z - iz) * ez) / (L * L)
    d = (-(aX - ix) * ez + (Z - iz) * ex) / L
    sc = np.clip(s, 0, 1)
    top = 0.028 * np.clip(sc * 3.0, 0, 1) * (1 - sc ** 4) + 0.002
    bot = -0.02 * np.clip(np.sin(math.pi * sc), 0, 1) ** 0.9 - 0.001
    eye = ss(0.003, 0.0, np.maximum(d - top, bot - d)) * (s > 0) * (s < 1)
    cxs, czs = ix + 0.52 * ex, iz + 0.52 * ez
    rr = np.sqrt((aX - cxs) ** 2 + (Z - czs) ** 2)
    _face_layers.rr = rr
    iris = ss(0.04, 0.036, rr)
    slit = ss(0.005 * np.clip(1 - ((Z - czs) / 0.03) ** 2, 0, 1) + 0.0005, 0.0, np.abs(aX - cxs)) * ss(0.03, 0.026, rr)
    brow = np.maximum(_seg(aX, Z, (0.04, 1.49), (0.2, 1.56), 0.011, 0.005), _seg(aX, Z, (0.18, 1.555), (0.25, 1.6), 0.007, 0.001))
    lid = ss(0.006, 0.003, np.abs(d - top - 0.003)) * (s > -0.05) * (s < 1.02)
    # dark violet liner flicks and void tear marks under the eyes
    liner = np.maximum(_seg(aX, Z, (0.17, 1.5), (0.24, 1.53), 0.008, 0.002), _seg(aX, Z, (0.12, 1.42), (0.15, 1.34), 0.009, 0.002))
    mark = _seg(X, Z, (0.0, 1.56), (0.0, 1.6), 0.012, 0.004) * (level >= 2)
    if level >= 3:
        mark = np.maximum(mark, _seg(aX, Z, (0.15, 1.36), (0.18, 1.3), 0.006, 0.002))
    mouth = _seg(X, Z, (-0.045, 1.27), (0.045, 1.27), 0.004, 0.004)
    nose = ss(0.004, 0.0, aX / 0.03 + np.abs(Z - 1.33) / 0.016 - 1)
    return X, Z, eye, iris, slit, brow, lid, liner, mark, mouth, nose


def face_texture(level, size=512):
    X, Z, eye, iris, slit, brow, lid, liner, mark, mouth, nose = _face_layers(level, size)
    rr = _face_layers.rr
    ed, em, eh = EYE[level]
    gd, gm, gh = GLOW[level]
    rgba = np.zeros((size, size, 4), np.float32)
    c = np.zeros((size, size, 3), np.float32) + hx('2a0c48')
    c = c * (1 - liner[..., None]) + hx('3a0a60') * liner[..., None]
    c = c * (1 - mark[..., None]) + hx(gm) * mark[..., None]
    irisc = grad(np.clip(1 - rr / 0.036, 0, 1), [(0, ed), (0.45, em), (1, eh)])
    e = hx('0a0610') * (1 - iris[..., None]) + irisc * iris[..., None]
    e = e * (1 - slit[..., None]) + hx('020104') * slit[..., None]
    c = c * (1 - eye[..., None]) + e * eye[..., None]
    ln = np.maximum.reduce([lid, brow, mouth])
    c = c * (1 - ln[..., None]) + hx('14081e') * ln[..., None]
    c = c * (1 - nose[..., None]) + hx('5a3a7a') * nose[..., None]
    rgba[..., :3] = c
    rgba[..., 3] = np.clip(np.maximum.reduce([eye, ln, liner, mark, nose]), 0, 1)
    return rgba


def face_emissive(level, size=512):
    X, Z, eye, iris, slit, brow, lid, liner, mark, mouth, nose = _face_layers(level, size)
    g = np.clip(np.maximum(iris * eye * (1 - slit), mark * 0.9), 0, 1)
    return np.repeat(g[..., None], 3, -1)


# ----------------------------------------------------------------- animation
def _ease(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def _wings(w, amp, base=0.0):
    f = amp * math.sin(w) + base
    g = 0.8 * amp * math.sin(w - 0.6) + base * 0.5
    h = 0.6 * amp * math.sin(w + 0.6) + base * 0.4
    return {'Wing.L': P(('y', -f)), 'Wing.R': P(('y', f)), 'Wing2.L': P(('y', -g)), 'Wing2.R': P(('y', g)),
            'Wing3.L': P(('y', -h)), 'Wing3.R': P(('y', h))}


def _tailw(w, amp):
    return {'Tail1': P(('z', amp * math.sin(w)), ('x', -6)), 'Tail2': P(('z', amp * 1.4 * math.sin(w - 0.8)))}


def anim_idle():
    """A slow, regal hover: deep wing strokes, the head turning to watch, the tail curling, the halo turning."""
    F = 72
    keys = {}
    for f in range(0, F + 1, 2):
        t = f / F
        w = 2 * math.pi * t
        k = {'Body': P(('x', 3 * math.sin(w)), loc=(0, 0, 0.09 * math.sin(w * 2 - 0.8))),
             'Head': P(('z', 16 * math.sin(w * 0.5)), ('x', -4 * math.sin(w))),
             'Halo': P(('y', 360 * t), loc=(0, 0, 0.03 * math.sin(w))),
             'Leg.L': P(('x', 25 + 5 * math.sin(w * 2))), 'Leg.R': P(('x', 25 + 5 * math.sin(w * 2 + 0.5))),
             'Hind.L': P(('x', -20)), 'Hind.R': P(('x', -20))}
        k.update(_wings(w * 2, 18, 6))
        k.update(_tailw(w, 14))
        keys[f] = k
    keys[F] = dict(keys[0])
    keys[F]['Halo'] = P(('y', 0))
    return {'frames': F, 'loop': True, 'keys': keys}


def _fly(frames, pitch, amp):
    keys = {}
    for f in range(0, frames + 1):
        t = f / frames
        w = 2 * math.pi * t
        k = {'Body': P(('x', pitch + 3 * math.sin(w)), loc=(0, 0, 0.06 * math.sin(w - 1.4))),
             'Head': P(('x', -pitch * 0.7)), 'Halo': P(('x', -pitch * 0.5)),
             'Leg.L': P(('x', 55)), 'Leg.R': P(('x', 55)), 'Hind.L': P(('x', -45)), 'Hind.R': P(('x', -45))}
        k.update(_wings(w, amp, 4))
        k.update(_tailw(w, 8))
        keys[f] = k
    return {'frames': frames, 'loop': True, 'keys': keys}


def anim_walk():
    return _fly(22, 20, 32)


def anim_run():
    return _fly(14, 40, 40)


def anim_hop():
    keys = {}
    for f in range(0, 17, 2):
        t = f / 16
        up = math.sin(math.pi * t)
        k = {'Body': P(('x', -8 * up), loc=(0, 0, 0.3 * up))}
        k.update(_wings(math.pi / 2, 40 * up, 0))
        keys[f] = k
    return {'frames': 16, 'loop': False, 'keys': keys}


def anim_ability():
    """Portal Relocation (~1 s, Runner): folds every wing forward into a closed cocoon, spins inside it (the portal
    opens at ~0.5), then throws all the wings wide in a burst and settles."""
    keys = {}
    F = 24
    for f in range(0, F + 1, 2):
        t = f / F
        wrap = _ease(t / 0.3) * (1 - _ease((t - 0.45) / 0.08))
        spin = _ease((t - 0.15) / 0.35)
        burst = _ease((t - 0.45) / 0.08) * (1 - _ease((t - 0.78) / 0.22))
        k = {'Body': P(('z', -360 * spin), ('x', 10 * wrap - 12 * burst), loc=(0, 0, -0.05 * wrap + 0.16 * burst)),
             'Head': P(('x', 18 * wrap - 16 * burst)), 'Halo': P(('y', 720 * t)),
             'Wing.L': P(('y', 30 * wrap - 60 * burst), ('z', -75 * wrap)), 'Wing.R': P(('y', -30 * wrap + 60 * burst), ('z', 75 * wrap)),
             'Wing2.L': P(('y', 20 * wrap - 45 * burst), ('z', -60 * wrap)), 'Wing2.R': P(('y', -20 * wrap + 45 * burst), ('z', 60 * wrap)),
             'Wing3.L': P(('y', 20 * wrap - 35 * burst), ('z', -40 * wrap)), 'Wing3.R': P(('y', -20 * wrap + 35 * burst), ('z', 40 * wrap)),
             'Leg.L': P(('x', 40 * wrap)), 'Leg.R': P(('x', 40 * wrap))}
        k.update(_tailw(6 * t, 20 * burst))
        keys[f] = k
    keys[F]['Body'] = P(('z', -360))
    return {'frames': F, 'loop': False, 'keys': keys}


def anim_blink():
    """Blink (~0.75 s, Catcher): snaps the wings tight against its body, flickers forward low (the blink at ~0.4),
    then flares to brake."""
    keys = {}
    F = 18
    for f in range(0, F + 1):
        t = f / F
        tuck = _ease(t / 0.3) * (1 - _ease((t - 0.42) / 0.08))
        dart = _ease((t - 0.3) / 0.1) * (1 - _ease((t - 0.6) / 0.3))
        brake = _ease((t - 0.5) / 0.12) * (1 - _ease((t - 0.8) / 0.2))
        k = {'Body': P(('x', 12 * tuck + 30 * dart - 20 * brake), loc=(0, -0.35 * dart, -0.08 * tuck)),
             'Head': P(('x', -10 * dart + 8 * brake)),
             'Wing.L': P(('y', 40 * tuck - 50 * brake), ('z', -30 * tuck)), 'Wing.R': P(('y', -40 * tuck + 50 * brake), ('z', 30 * tuck)),
             'Wing2.L': P(('y', 30 * tuck - 30 * brake)), 'Wing2.R': P(('y', -30 * tuck + 30 * brake)),
             'Wing3.L': P(('y', 30 * tuck)), 'Wing3.R': P(('y', -30 * tuck)),
             'Leg.L': P(('x', 50 * tuck)), 'Leg.R': P(('x', 50 * tuck))}
        k.update(_tailw(4 * t, 10))
        keys[f] = k
    return {'frames': F, 'loop': False, 'keys': keys}


ANIMS = {'Idle': anim_idle, 'Walk': anim_walk, 'Run': anim_run, 'Hop': anim_hop, 'Ability': anim_ability,
         'Blink': anim_blink}
