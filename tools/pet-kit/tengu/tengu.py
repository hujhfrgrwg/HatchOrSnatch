# Eclipse Tengu (Decoy, Legendary) for Hatch or Snatch: HOS-PET-027, built on the pet kit.
# From the concept card (docs/pets/eclipse_tengu/eclipse_tengu_card.png): a karasu-tengu crow spirit, plum-black plumage,
# a hooked red beak, tall gold horns, a gold pauldron and chest medallion with a blue gem, huge wings that run from
# black to blazing red at the tips, gold talons. It flies (hover, talons tucked, no walking).
# Read through PET_LESSONS (anime / edgy): near-black plum feathers with scallop strokes and red flame-tooth edges,
# a dark mask with narrow slanted glowing red slit eyes under a heavy brow (face decal shell), sharp swept horns,
# glowing red feather runes. L2 "Crimson Mantle": a second pair of horns, a red flame crest, gold wing claws, long
# red tail plumes, orange glow. L3 "Black Sun Sovereign": a black-sun eclipse halo with a gold corona behind the head,
# a second pair of wings, a gold brow crown, gold-white eyes and glow.
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

NAME = 'Tengu'
SHARP_ANGLE = 40
NORMAL_STRENGTH = 2.0
TS = 1024
ATLAS = Atlas({
    'skin': (0, 0, 1024, 384),      # body loft: u around (0 = back), v tail tip -> head top
    'wing': (0, 384, 512, 256),     # main wings: a = root -> tip, b = low -> high
    'wing2': (512, 384, 512, 256),  # L3 second wings
    'tailf': (0, 640, 256, 128),    # tail feathers
    'crest': (256, 640, 256, 128),  # head crest feathers
    'gold': (512, 640, 256, 128),
    'beak': (768, 640, 256, 128),
    'limb': (0, 768, 256, 128),
    'halo': (256, 768, 256, 128),   # L3 black sun
    'gem': (512, 768, 256, 128),
    'warm': (768, 768, 256, 128),   # wing arm (leading edge)
    'plume': (0, 896, 512, 128),    # L2 red tail plumes / flame crest
})

GLOW = {1: ('6a0a14', 'ff2a2a', 'ffc0a0'), 2: ('8a1a08', 'ff6a1a', 'ffe0a0'), 3: ('9a5a08', 'ffc23a', 'fff6d8')}
EYE = {1: ('6a0408', 'ff2a1a', 'ffd0a0'), 2: ('7a2004', 'ff7a1a', 'ffe8b0'), 3: ('8a5a04', 'ffd040', 'fffbe8')}


def bones_def():
    b = [
        ('Root', V(0, 0, 0), V(0, 0, 0.2), None),
        ('Body', V(0, 0.06, 0.96), V(0, -0.08, 1.16), 'Root'),
        ('Tail', V(0, 0.3, 0.8), V(0, 0.6, 0.62), 'Body'),
        ('Head', V(0, -0.12, 1.2), V(0, -0.18, 1.5), 'Body'),
        ('Halo', V(0, 0.12, 1.5), V(0, 0.12, 1.7), 'Body'),
    ]
    for s, x in (('L', 1), ('R', -1)):
        b += [
            ('Wing.' + s, V(x * 0.18, 0.06, 1.1), V(x * 0.9, 0.14, 1.5), 'Body'),
            ('Wing2.' + s, V(x * 0.16, 0.16, 0.92), V(x * 0.6, 0.3, 0.72), 'Body'),
            ('Leg.' + s, V(x * 0.1, 0.04, 0.82), V(x * 0.12, -0.06, 0.56), 'Body'),
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


FX, FZ, FZH = 0.27, 1.42, 0.24
HEAD_C = V(0, -0.15, 1.42)


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
    sel = [fi for fi in faces if all(mb.V[v][1] < -0.19 and 1.22 < mb.V[v][2] < 1.64 for v in mb.F[fi])]
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
    W_B, W_H, W_T = {'Body': 1}, {'Head': 1}, {'Tail': 1}
    # one loft: tail root -> puffed chest -> neck -> head top (pitched forward like a perched crow)
    st = [(V(0, 0.46, 0.72), (0.09, 0.07), W_T), (V(0, 0.3, 0.8), (0.19, 0.17), {'Tail': 0.4, 'Body': 0.6}),
          (V(0, 0.1, 0.92), (0.24, 0.24), W_B), (V(0, -0.04, 1.06), (0.25, 0.25), W_B),
          (V(0, -0.1, 1.2), (0.18, 0.18), {'Body': 0.5, 'Head': 0.5}),
          (V(0, -0.15, 1.33), (0.24, 0.22), W_H), (V(0, -0.15, 1.47), (0.23, 0.21), W_H), (V(0, -0.11, 1.6), (0.13, 0.13), W_H)]
    n0 = len(mb.F)
    tube(mb, 'skin', [s[0] for s in st], [s[1] for s in st], 18, [s[2] for s in st], 'body', start='point', end='point',
         start_pt=V(0, 0.54, 0.66), end_pt=V(0, -0.08, 1.65), side_hint=V(1, 0, 0), th0=math.pi / 2)
    body_faces = list(range(n0, len(mb.F)))
    # hooked red beak
    tube(mb, 'beak', [V(0, -0.3, 1.39), V(0, -0.43, 1.37), V(0, -0.52, 1.32)], [(0.095, 0.085), (0.065, 0.06), (0.035, 0.035)],
         8, [W_H] * 3, 'beak', start='point', end='point', start_pt=V(0, -0.24, 1.4), end_pt=V(0, -0.57, 1.22), side_hint=V(1, 0, 0))
    # head crest: swept black feather spikes with red tips
    cb, ct = ATLAS.uv('crest', 0.5, 0.05), ATLAS.uv('crest', 0.5, 0.95)
    for k, (sx, el, ln) in enumerate(((0, 30, 0.34), (0.07, 18, 0.3), (-0.07, 18, 0.3), (0.12, 4, 0.24), (-0.12, 4, 0.24))):
        base = V(sx, 0.0, 1.5)
        d = nrm(V(sx * 1.6, 1.0, math.tan(math.radians(el))))
        bipyramid(mb, base, base + d * ln, V(1, 0, 0), V(0, 0, 1), 0.1, 0.05, W_H, cb, ct, 'crest', wide_at=0.3, ridge_at=0.3, curl=0.12)
    # tail fan
    tb, tt = ATLAS.uv('tailf', 0.5, 0.05), ATLAS.uv('tailf', 0.5, 0.95)
    for k in range(5):
        a = math.radians(-36 + 18 * k)
        d = nrm(V(math.sin(a) * 0.8, 1.0, -0.55))
        base = V(math.sin(a) * 0.05, 0.44, 0.72)
        bipyramid(mb, base, base + d * (0.5 - 0.06 * abs(k - 2)), V(1, 0, 0), V(0, 0, 1), 0.15, 0.04, W_T, tb, tt, 'tail',
                  wide_at=0.55, ridge_at=0.5)
    gb, gt = ATLAS.uv('gold', 0.5, 0.05), ATLAS.uv('gold', 0.5, 0.95)
    for s, x in (('L', 1), ('R', -1)):
        Ww = {'Wing.' + s: 1}
        # big wing: chunky leading-edge arm + feathered membrane
        lead = [(0.36, 0.06, 1.32), (0.62, 0.1, 1.56), (0.82, 0.13, 1.7)]
        pts = _wing_outline(x, (1.0, 0.17, 1.72), (0.3, 0.2, 0.84), 11, lead)
        wing(mb, 'wing', V(x * 0.18, 0.08, 1.1), pts, Ww, 'wing')
        tube(mb, 'warm', [V(x * 0.16, 0.06, 1.12), V(x * 0.38, 0.06, 1.34), V(x * 0.64, 0.1, 1.57), V(x * 0.84, 0.13, 1.71)],
             [(0.07, 0.07), (0.06, 0.06), (0.045, 0.045), (0.03, 0.03)], 6, [Ww] * 4, 'warm', start='point', end='point',
             start_pt=V(x * 0.1, 0.06, 1.06), end_pt=V(x * 1.02, 0.17, 1.76), side_hint=V(0, 1, 0))
        # tucked legs with gold talons
        Wl = {'Leg.' + s: 1}
        tube(mb, 'limb', [V(x * 0.1, 0.04, 0.84), V(x * 0.12, -0.02, 0.72), V(x * 0.12, -0.06, 0.64)],
             [(0.075, 0.075), (0.05, 0.05), (0.042, 0.042)], 6, [Wl] * 3, 'leg', start='point', end='point',
             start_pt=V(x * 0.1, 0.06, 0.9), end_pt=V(x * 0.12, -0.08, 0.6))
        for ca in (-25, 0, 25):
            d = nrm(V(math.sin(math.radians(ca)) * 0.6, -1.0, -0.6))
            base = V(x * 0.12, -0.06, 0.63)
            bipyramid(mb, base, base + d * 0.17, V(1, 0, 0), V(0, 0, 1), 0.055, 0.045, Wl, gb, gt, 'claw', wide_at=0.25, ridge_at=0.25, curl=-0.25)
        # tall gold horns, swept back
        tube(mb, 'gold', [V(x * 0.09, -0.16, 1.56), V(x * 0.13, -0.12, 1.72), V(x * 0.17, -0.02, 1.86), V(x * 0.19, 0.1, 1.94)],
             [(0.055, 0.055), (0.045, 0.045), (0.035, 0.035), (0.02, 0.02)], 6, [W_H] * 4, 'horn', start='point', end='point',
             start_pt=V(x * 0.08, -0.16, 1.5), end_pt=V(x * 0.2, 0.18, 1.98), side_hint=V(-1, 0, 0))
        # gold pauldron: two layered plates
        bipyramid(mb, V(x * 0.1, -0.04, 1.2), V(x * 0.42, 0.0, 1.1), V(0, 1, 0), V(x, 0, 1), 0.38, 0.16, W_B, gb, gt, 'gold',
                  wide_at=0.45, ridge_at=0.45)
        bipyramid(mb, V(x * 0.14, -0.02, 1.08), V(x * 0.44, 0.04, 0.96), V(0, 1, 0), V(x, 0, 1), 0.3, 0.12, W_B, gb, gt, 'gold',
                  wide_at=0.45, ridge_at=0.45)
        bipyramid(mb, V(x * 0.26, -0.02, 1.2), V(x * 0.34, 0.0, 1.36), V(0, 1, 0), V(x, 0, 1), 0.08, 0.06, W_B, gb, gt, 'gold',
                  wide_at=0.3, ridge_at=0.3)
    # chest medallion: gold ring and blue gem
    ring(mb, 'gold', V(0, -0.3, 1.02), V(0, -1, 0.35), 0.08, 0.02, 10, 4, W_B, 'gold')
    gm0, gm1 = ATLAS.uv('gem', 0.5, 0.1), ATLAS.uv('gem', 0.5, 0.9)
    bipyramid(mb, V(0, -0.26, 1.06), V(0, -0.26, 0.94), V(1, 0, 0), V(0, -1, 0), 0.1, 0.08, W_B, gm0, gm1, 'gem')
    mb.mat = 1
    face_shell(mb, body_faces)
    # ---- L2 "Crimson Mantle": front horns, flame crest, gold wing claws, long red tail plumes
    mb.mat = 2
    pb, pt = ATLAS.uv('plume', 0.5, 0.05), ATLAS.uv('plume', 0.5, 0.95)
    for s, x in (('L', 1), ('R', -1)):
        tube(mb, 'gold', [V(x * 0.12, -0.24, 1.5), V(x * 0.2, -0.24, 1.6), V(x * 0.27, -0.18, 1.68)], [(0.035, 0.035), (0.028, 0.028), (0.018, 0.018)],
             5, [W_H] * 3, 'L2', start='point', end='point', start_pt=V(x * 0.1, -0.22, 1.46), end_pt=V(x * 0.3, -0.12, 1.72), side_hint=V(0, 1, 0))
        Ww = {'Wing.' + s: 1}
        bipyramid(mb, V(x * 0.62, 0.1, 1.57), V(x * 0.66, -0.08, 1.66), V(1, 0, 0), V(0, 0, 1), 0.06, 0.05, Ww, gb, gt, 'L2', wide_at=0.25, curl=-0.3)
        bipyramid(mb, V(x * 0.84, 0.13, 1.71), V(x * 0.9, -0.04, 1.8), V(1, 0, 0), V(0, 0, 1), 0.05, 0.04, Ww, gb, gt, 'L2', wide_at=0.25, curl=-0.3)
        bipyramid(mb, V(x * 0.05, 0.42, 0.72), V(x * 0.22, 0.98, 0.42), V(1, 0, 0), V(0, 0, 1), 0.12, 0.03, W_T, pb, pt, 'L2', wide_at=0.6, ridge_at=0.55, curl=0.1)
    for k, sx in enumerate((-0.05, 0.05, 0.0)):
        base = V(sx, -0.06, 1.56)
        d = nrm(V(sx * 2, 0.7, 1.0 - 0.2 * k))
        bipyramid(mb, base, base + d * 0.3, V(1, 0, 0), V(0, 1, 0), 0.1, 0.04, W_H, pb, pt, 'L2', wide_at=0.35, ridge_at=0.35, curl=0.15)
    # ---- L3 "Black Sun Sovereign": eclipse halo + corona, second wings, brow crown
    mb.mat = 3
    Wh = {'Halo': 1}
    hc, hn = V(0, 0.16, 1.56), V(0, 1, -0.15)
    disc(mb, 'halo', hc, hn, 0.3, 14, Wh, 'L3', thick=0.02)
    a_, b_ = ring(mb, 'gold', hc + nrm(hn) * 0.012, hn, 0.32, 0.025, 16, 4, Wh, 'L3')
    for k in range(10):
        th = 2 * math.pi * k / 10
        dr = a_ * math.cos(th) + b_ * math.sin(th)
        bipyramid(mb, hc + dr * 0.32, hc + dr * (0.5 if k % 2 == 0 else 0.42), hn, V(0, 0, 1), 0.07, 0.03, Wh, gb, gt, 'L3', wide_at=0.2, ridge_at=0.2)
    for s, x in (('L', 1), ('R', -1)):
        pts = _wing_outline(x, (0.66, 0.34, 0.86), (0.2, 0.24, 0.74), 7, [(0.34, 0.24, 0.98), (0.52, 0.3, 0.98)])
        wing(mb, 'wing2', V(x * 0.15, 0.18, 0.92), pts, {'Wing2.' + s: 1}, 'L3', thick=0.03)
        bipyramid(mb, V(x * 0.06, -0.3, 1.58), V(x * 0.2, -0.26, 1.64), V(0, 0, 1), V(0, -1, 0), 0.05, 0.03, W_H, gb, gt, 'L3', wide_at=0.5)
    bipyramid(mb, V(0, -0.33, 1.52), V(0, -0.36, 1.68), V(1, 0, 0), V(0, -1, 0), 0.07, 0.04, W_H, gb, gt, 'L3', wide_at=0.4)
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


def _scallops(u, v, nu, nv):
    """overlapping feather scallops: 1 on each feather's rounded edge, plus a per-feather shade."""
    rv = v * nv
    row = np.floor(rv)
    cu = u * nu + 0.5 * (row % 2)
    fu = cu - np.floor(cu) - 0.5
    fv = rv - row
    edge = ss(0.0, 0.12, np.abs(fv - (0.85 - 1.2 * fu ** 2)) - 0.02)
    shade = fv
    return 1 - edge, shade


FEATHER = [(0, '0c0812'), (0.5, '24183a'), (1, '43305e')]


def paint_atlas(level):
    col = np.zeros((TS, TS, 3), np.float32)
    hgt = np.full((TS, TS), 0.5, np.float32)
    rgh = np.full((TS, TS), 0.6, np.float32)
    glow = np.zeros((TS, TS), np.float32)
    gd, gm, gh = GLOW[level]
    red = {1: 'c81a1a', 2: 'e0401a', 3: 'e8501a'}[level]
    # body: plum-black scalloped plumage, darker back, red flame-tooth feathers along the flanks, glowing chest runes
    (y0, y1, x0, x1), v, u = _reg('skin')
    h, w = y1 - y0, x1 - x0
    top = np.cos(u * 2 * math.pi)
    sc, shade = _scallops(u, v, 18, 22)
    c = grad(np.clip(0.55 - 0.3 * top + 0.25 * shade, 0, 1), FEATHER)
    c = c * (0.65 + 0.35 * sc[..., None])
    side = np.abs(np.sin(u * 2 * math.pi))
    flame = ss(0.0, 0.03, side - 0.86 - 0.08 * _saw(v * 26)) * ss(0.25, 0.35, v) * ss(0.8, 0.7, v)
    c = c * (1 - flame[..., None]) + hx(red) * (0.9 * flame[..., None]) * (0.7 + 0.3 * shade[..., None])
    chest = ss(-0.6, -0.85, top) * ss(0.42, 0.48, v) * ss(0.7, 0.62, v)
    runes = chest * ss(0.012, 0.0, np.abs(_saw(u * 9 + 0.5 * v * 10) - 0.5) - 0.02) * (np.abs(_saw(v * 6)) > 0.35)
    rune_on = 0.6 if level == 1 else 1.0
    c = c * (1 - runes[..., None]) + hx(gm) * runes[..., None]
    st = _streaks(h, w, 160, 31)
    col[y0:y1, x0:x1] = c * (1 + 0.2 * st[..., None])
    hgt[y0:y1, x0:x1] = 0.5 + 0.3 * sc + 0.15 * st
    rgh[y0:y1, x0:x1] = 0.7
    glow[y0:y1, x0:x1] = np.clip(runes * rune_on + flame * 0.15 * (level >= 2), 0, 1)
    # wings: black at the root, blazing red-orange at the tips, feather lines and flame-tooth bands
    for reg in ('wing', 'wing2'):
        (y0, y1, x0, x1), v, u = _reg(reg)
        A, B = u, 1 - v
        nf = 12 if reg == 'wing' else 8
        fl = np.abs(_saw(A * nf * 0.5 + B * 2.2) - 0.5)
        lines = ss(0.04, 0.0, fl - 0.02)
        teeth = 0.55 + 0.12 * _saw(B * 14) - 0.08 * B
        hot = ss(0.0, 0.05, A - teeth)
        tipc = grad(np.clip((A - teeth) * 3, 0, 1), [(0, red), (0.6, gm), (1, gh)])
        base = grad(np.clip(A * 1.4, 0, 1), FEATHER)
        c = base * (1 - hot[..., None]) + tipc * hot[..., None]
        band = ss(0.0, 0.03, A - 0.32 - 0.08 * _saw(B * 10)) * ss(0.03, 0.0, A - 0.38 - 0.08 * _saw(B * 10))
        c = c * (1 - 0.8 * band[..., None]) + hx(red) * (0.8 * band[..., None])
        c = c * (1 - 0.45 * lines[..., None])
        cov = ss(0.0, 0.04, 0.22 - A + 0.05 * _saw(B * 18))   # covert scallops near the root
        c = c * (1 - 0.3 * cov[..., None])
        col[y0:y1, x0:x1] = c
        hgt[y0:y1, x0:x1] = 0.5 - 0.25 * lines + 0.1 * cov
        rgh[y0:y1, x0:x1] = 0.55
        glow[y0:y1, x0:x1] = np.clip(hot * (0.35 + 0.25 * (level - 1)) * ss(0.0, 0.25, A - teeth) * 2 + band * 0.3 * (level >= 2), 0, 1)
    for reg in ('tailf', 'crest'):
        (y0, y1, x0, x1), v, u = _reg(reg)
        hot = ss(0.62, 0.8, v + 0.05 * _saw(u * 7))
        c = grad(np.clip(v * 1.3, 0, 1), FEATHER) * (1 - hot[..., None]) + grad(np.clip((v - 0.6) * 2.5, 0, 1), [(0, red), (1, gm)]) * hot[..., None]
        vane = ss(0.03, 0.0, np.abs(u - 0.5) - 0.01)
        col[y0:y1, x0:x1] = c * (1 - 0.4 * vane[..., None])
        glow[y0:y1, x0:x1] = hot * 0.4
    (y0, y1, x0, x1), v, u = _reg('plume')
    col[y0:y1, x0:x1] = grad(v, [(0, '3a0810'), (0.5, red), (1, gh)])
    glow[y0:y1, x0:x1] = 0.3 + 0.6 * v
    (y0, y1, x0, x1), v, u = _reg('gold')
    eng = ss(0.02, 0.0, np.abs(_saw(v * 5) - 0.5) - 0.03)
    col[y0:y1, x0:x1] = grad(u, [(0, 'fff0a0'), (0.45, 'f0b030'), (1, '8a5a08')]) * (1 - 0.35 * eng[..., None])
    hgt[y0:y1, x0:x1] = 0.5 - 0.3 * eng
    rgh[y0:y1, x0:x1] = 0.28
    glow[y0:y1, x0:x1] = 0.12
    (y0, y1, x0, x1), v, u = _reg('beak')
    c = grad(v, [(0, 'a01414'), (0.6, 'd8261c'), (1, '3a0606')])
    c = c * (0.85 + 0.15 * np.cos(u * 2 * math.pi)[..., None])
    col[y0:y1, x0:x1] = c
    rgh[y0:y1, x0:x1] = 0.35
    (y0, y1, x0, x1), v, u = _reg('limb')
    sc2 = ss(0.02, 0.0, np.abs(_saw(v * 9) - 0.5) - 0.06)
    col[y0:y1, x0:x1] = grad(v, [(0, '2a2030'), (1, '141018')]) * (1 - 0.4 * sc2[..., None])
    hgt[y0:y1, x0:x1] = 0.5 - 0.3 * sc2
    (y0, y1, x0, x1), v, u = _reg('warm')
    sc, shade = _scallops(u, v, 6, 10)
    col[y0:y1, x0:x1] = grad(np.clip(0.3 + 0.4 * shade, 0, 1), FEATHER) * (0.7 + 0.3 * sc[..., None])
    hgt[y0:y1, x0:x1] = 0.5 + 0.3 * sc
    (y0, y1, x0, x1), v, u = _reg('gem')
    col[y0:y1, x0:x1] = grad(v, [(0, '0a2a8a'), (0.5, '3a8aff'), (1, 'd0eaff')]) if level < 3 else grad(v, [(0, '8a0a14'), (0.5, 'ff3a2a'), (1, 'ffe0c0')])
    rgh[y0:y1, x0:x1] = 0.15
    glow[y0:y1, x0:x1] = 0.7
    (y0, y1, x0, x1), v, u = _reg('halo')
    r = np.sqrt((u - 0.5) ** 2 + (v - 0.5) ** 2) / 0.48
    c = grad(np.clip(r, 0, 1), [(0, '040206'), (0.8, '0c0610'), (0.92, gm), (1, gh)])
    col[y0:y1, x0:x1] = c
    glow[y0:y1, x0:x1] = ss(0.82, 0.97, r)
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
    ix, iz, ox, oz = 0.06, 1.455, 0.18, 1.515
    ex, ez = ox - ix, oz - iz
    L = math.hypot(ex, ez)
    s = ((aX - ix) * ex + (Z - iz) * ez) / (L * L)
    d = (-(aX - ix) * ez + (Z - iz) * ex) / L
    sc = np.clip(s, 0, 1)
    top = 0.026 * np.clip(sc * 3.0, 0, 1) * (1 - sc ** 4) + 0.002
    bot = -0.02 * np.clip(np.sin(math.pi * sc), 0, 1) ** 0.9 - 0.001
    eye = ss(0.003, 0.0, np.maximum(d - top, bot - d)) * (s > 0) * (s < 1)
    cxs, czs = ix + 0.55 * ex, iz + 0.55 * ez
    rr = np.sqrt((aX - cxs) ** 2 + (Z - czs) ** 2)
    _face_layers.rr = rr
    iris = ss(0.04, 0.036, rr)
    slit = ss(0.005 * np.clip(1 - ((Z - czs) / 0.03) ** 2, 0, 1) + 0.0005, 0.0, np.abs(aX - cxs)) * ss(0.03, 0.026, rr)
    # heavy angry brow sweeping up to the horns
    brow = np.maximum(_seg(aX, Z, (0.03, 1.47), (0.2, 1.555), 0.013, 0.006), _seg(aX, Z, (0.18, 1.55), (0.25, 1.61), 0.008, 0.001))
    lid = ss(0.006, 0.003, np.abs(d - top - 0.003)) * (s > -0.05) * (s < 1.02)
    # dark tengu mask band across the eyes
    zc = 1.49 + 0.06 * aX
    hh = 0.055 * np.clip(1 - (aX / 0.25) ** 2, 0, 1) + 0.004
    mask = ss(0.004, 0.0, np.abs(Z - zc) - hh) * (aX < 0.26)
    # red war-paint marks under the eyes and a forehead rune
    mark = np.maximum(_seg(aX, Z, (0.12, 1.43), (0.17, 1.37), 0.008, 0.002), _seg(aX, Z, (0.16, 1.44), (0.21, 1.4), 0.006, 0.0015))
    mark = np.maximum(mark, _seg(X, Z, (0.0, 1.56), (0.0, 1.61), 0.008, 0.002))
    if level >= 2:
        mark = np.maximum(mark, _seg(aX, Z, (0.02, 1.58), (0.06, 1.62), 0.006, 0.002))
    if level >= 3:
        mark = np.maximum(mark, ss(0.004, 0.0, np.abs(np.sqrt(X ** 2 + (Z - 1.6) ** 2) - 0.025) - 0.003))
    return X, Z, eye, iris, slit, brow, lid, mask, mark


def face_texture(level, size=512):
    X, Z, eye, iris, slit, brow, lid, mask, mark = _face_layers(level, size)
    rr = _face_layers.rr
    ed, em, eh = EYE[level]
    gd, gm, gh = GLOW[level]
    rgba = np.zeros((size, size, 4), np.float32)
    c = np.zeros((size, size, 3), np.float32) + hx('08040c')
    c = c * (1 - mark[..., None]) + hx(gm) * mark[..., None]
    irisc = grad(np.clip(1 - rr / 0.036, 0, 1), [(0, ed), (0.45, em), (1, eh)])
    e = hx('0a0408') * (1 - iris[..., None]) + irisc * iris[..., None]
    e = e * (1 - slit[..., None]) + hx('020102') * slit[..., None]
    c = c * (1 - eye[..., None]) + e * eye[..., None]
    ln = np.maximum.reduce([lid, brow])
    c = c * (1 - ln[..., None]) + hx('020104') * ln[..., None]
    rgba[..., :3] = c
    rgba[..., 3] = np.clip(np.maximum.reduce([mask * 0.9, eye, ln, mark]), 0, 1)
    return rgba


def face_emissive(level, size=512):
    X, Z, eye, iris, slit, brow, lid, mask, mark = _face_layers(level, size)
    g = np.clip(np.maximum(iris * eye * (1 - slit), mark * 0.9), 0, 1)
    return np.repeat(g[..., None], 3, -1)


# ----------------------------------------------------------------- animation
def _ease(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def _wings(w, amp, base=0.0, amp2=None):
    """Wing ('y', -L / +R) raises the wings (as the Moth / Imp)."""
    f = amp * math.sin(w) + base
    a2 = 0.8 * amp if amp2 is None else amp2
    g = a2 * math.sin(w - 0.5) + base * 0.5
    return {'Wing.L': P(('y', -f)), 'Wing.R': P(('y', f)), 'Wing2.L': P(('y', -g)), 'Wing2.R': P(('y', g))}


def _legs(a):
    return {'Leg.L': P(('x', a)), 'Leg.R': P(('x', a))}


def anim_idle():
    F = 72
    keys = {}
    for f in range(0, F + 1, 2):
        t = f / F
        w = 2 * math.pi * t
        k = {'Body': P(('x', 6 + 2 * math.sin(w)), loc=(0, 0, 0.08 * math.sin(w * 2 - 1.0))),
             'Head': P(('x', -4 * math.sin(w)), ('z', 14 * math.sin(w) * (abs(math.sin(w)) > 0.5))),
             'Tail': P(('x', 5 * math.sin(w * 2)), ('z', 4 * math.sin(w))),
             'Halo': P(('y', 360 * t))}
        k.update(_wings(w * 2, 20, 4))
        k.update(_legs(20 + 4 * math.sin(w * 2)))
        keys[f] = k
    keys[F] = dict(keys[0])
    keys[F]['Halo'] = P(('y', 0))
    return {'frames': F, 'loop': True, 'keys': keys}


def _fly(frames, pitch, amp):
    keys = {}
    for f in range(0, frames + 1):
        t = f / frames
        w = 2 * math.pi * t
        k = {'Body': P(('x', pitch + 4 * math.sin(w)), loc=(0, 0, 0.07 * math.sin(w - 1.4))),
             'Head': P(('x', -pitch * 0.75)), 'Tail': P(('x', -pitch * 0.4 + 5 * math.sin(w + 1))),
             'Halo': P(('x', -pitch * 0.5))}
        k.update(_wings(w, amp, 6))
        k.update(_legs(55))
        keys[f] = k
    return {'frames': frames, 'loop': True, 'keys': keys}


def anim_walk():
    return _fly(20, 22, 34)


def anim_run():
    return _fly(14, 42, 42)


def anim_hop():
    keys = {}
    for f in range(0, 17, 2):
        t = f / 16
        up = math.sin(math.pi * t)
        k = {'Body': P(('x', -10 * up), loc=(0, 0, 0.3 * up)), 'Tail': P(('x', 12 * up))}
        k.update(_wings(math.pi / 2, 45 * up, 0))
        k.update(_legs(20 - 15 * up))
        keys[f] = k
    return {'frames': 16, 'loop': False, 'keys': keys}


def anim_ability():
    """Fake Clone (~1 s, Runner): wraps its wings round itself, spins a full turn (the clone splits off at ~0.45),
    then flares the wings wide with its head thrown back and settles."""
    keys = {}
    F = 24
    for f in range(0, F + 1, 2):
        t = f / F
        wrap = _ease(t / 0.3) * (1 - _ease((t - 0.4) / 0.1))
        spin = _ease((t - 0.15) / 0.3)
        flare = _ease((t - 0.42) / 0.1) * (1 - _ease((t - 0.78) / 0.22))
        k = {'Body': P(('z', 360 * spin), ('x', 12 * wrap - 14 * flare), loc=(0, 0, -0.06 * wrap + 0.18 * flare)),
             'Head': P(('x', 16 * wrap - 22 * flare)), 'Tail': P(('x', 18 * flare)),
             'Wing.L': P(('y', 30 * wrap - 55 * flare), ('z', -70 * wrap)), 'Wing.R': P(('y', -30 * wrap + 55 * flare), ('z', 70 * wrap)),
             'Wing2.L': P(('y', 20 * wrap - 40 * flare), ('z', -50 * wrap)), 'Wing2.R': P(('y', -20 * wrap + 40 * flare), ('z', 50 * wrap)),
             'Halo': P(('y', 540 * t))}
        k.update(_legs(30 * wrap + 10))
        keys[f] = k
    keys[F]['Body'] = P(('z', 360))
    return {'frames': F, 'loop': False, 'keys': keys}


def anim_snare():
    """Snare (~0.8 s, Catcher): rears up with wings high, then dives and stamps both talons forward-down (the seal
    lands at ~0.45), wings swept back, and recovers."""
    keys = {}
    F = 20
    for f in range(0, F + 1):
        t = f / F
        rear = _ease(t / 0.3) * (1 - _ease((t - 0.32) / 0.1))
        dive = _ease((t - 0.32) / 0.12) * (1 - _ease((t - 0.65) / 0.35))
        k = {'Body': P(('x', -22 * rear + 38 * dive), loc=(0, -0.25 * dive, 0.15 * rear - 0.12 * dive)),
             'Head': P(('x', 12 * rear - 20 * dive)), 'Tail': P(('x', 20 * rear - 15 * dive)),
             'Wing.L': P(('y', -60 * rear + 10 * dive), ('z', -50 * dive)), 'Wing.R': P(('y', 60 * rear - 10 * dive), ('z', 50 * dive)),
             'Wing2.L': P(('y', -40 * rear), ('z', -40 * dive)), 'Wing2.R': P(('y', 40 * rear), ('z', 40 * dive))}
        k.update(_legs(20 + 10 * rear - 75 * dive))
        keys[f] = k
    return {'frames': F, 'loop': False, 'keys': keys}


ANIMS = {'Idle': anim_idle, 'Walk': anim_walk, 'Run': anim_run, 'Hop': anim_hop, 'Ability': anim_ability,
         'Snare': anim_snare}
