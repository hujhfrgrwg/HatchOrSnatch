# Moonveil Moth (Invisibility, Epic) for Hatch or Snatch: HOS-PET-023, built on the pet kit.
# From the concept-library card (docs/pets/moonveil_moth/moonveil_moth_card.png): a fluffy pale moth spirit with four
# (redo 17 Oct: pointed sickle forewings over tailed hindwings) big lilac wings patterned with moon-eyes, a gold crescent moon on its head, feathered antennae and blue eyes; it floats.
# Read through PET_LESSONS (anime / edgy): pale lavender fur with fur strokes and a dark violet mask, narrow slanted
# glowing slit eyes, a flat mouth (face decal shell), deep-violet veined wings with glowing moon-eye spots and jagged
# dark edges. L2 "Eclipse": a second crescent, glowing wing veins, a fluffier mane. L3 "Moon Sovereign": a full moon
# halo ring, long tail streamers on the hind wings, silver-white glow, violet-magenta eyes.
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

NAME = 'Moth'
SHARP_ANGLE = 40
NORMAL_STRENGTH = 1.8
TS = 1024
ATLAS = Atlas({
    'skin': (0, 0, 1024, 384),      # body loft: u around, v abdomen tip -> head top
    'wing': (0, 384, 512, 256),     # fore wings: u across, v root -> tip
    'wing2': (512, 384, 512, 256),  # hind wings
    'fluff': (0, 640, 256, 128),    # mane tufts
    'gold': (256, 640, 256, 128),
    'ant': (512, 640, 256, 128),    # antennae
    'limb': (768, 640, 256, 128),
    'stream': (0, 768, 512, 128),   # L3 tail streamers
    'halo': (512, 768, 512, 128),
})

GLOW = {1: ('5a2ab8', 'b48cff', 'f2eaff'), 2: ('5a2ab8', 'c8a0ff', 'faf4ff'), 3: ('8a1ab0', 'e870ff', 'fff2ff')}
EYE = {1: ('1a4ab8', '6ab8ff', 'eaf6ff'), 2: ('1a4ab8', '8ad0ff', 'f2fbff'), 3: ('8a1ac0', 'e070ff', 'fff2ff')}


def bones_def():
    b = [
        ('Root', V(0, 0, 0), V(0, 0, 0.2), None),
        ('Body', V(0, 0.1, 0.9), V(0, -0.1, 1.1), 'Root'),
        ('Abdomen', V(0, 0.18, 0.86), V(0, 0.5, 0.6), 'Body'),
        ('Head', V(0, -0.12, 1.12), V(0, -0.3, 1.5), 'Body'),
        ('Halo', V(0, 0.15, 1.5), V(0, 0.15, 1.7), 'Body'),
    ]
    for s, x in (('L', 1), ('R', -1)):
        b += [
            ('Wing.' + s, V(x * 0.14, 0.08, 1.04), V(x * 0.9, 0.2, 1.5), 'Body'),
            ('Wing2.' + s, V(x * 0.14, 0.16, 0.92), V(x * 0.7, 0.36, 0.62), 'Body'),
            ('Ant.' + s, V(x * 0.08, -0.26, 1.42), V(x * 0.24, -0.34, 1.78), 'Head'),
            ('Arm.' + s, V(x * 0.12, -0.12, 0.88), V(x * 0.16, -0.22, 0.66), 'Body'),
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


def wing(mb, region, root, pts, w, part, thick=0.03):
    """a flat wing: a fan of triangles from the root to an outline (pts), both faces, planar UV across the region."""
    root = np.asarray(root, float)
    allp = [root] + [np.asarray(p, float) for p in pts]
    xs = [p[0] for p in allp]; zs = [p[2] for p in allp]; ys = [p[1] for p in allp]
    span = max(abs(max(xs) - root[0]), abs(min(xs) - root[0]), 1e-6)
    zmin, zmax = min(zs), max(zs)
    def uv(p):
        a = abs(p[0] - root[0]) / span
        b = (p[2] - zmin) / max(zmax - zmin, 1e-6)
        return ATLAS.uv(region, 0.02 + 0.96 * b, 0.02 + 0.96 * a)
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


FX, FZ, FZH = 0.26, 1.24, 0.24


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
    sel = [fi for fi in faces if all(mb.V[v][1] < -0.17 and 1.04 < mb.V[v][2] < 1.48 for v in mb.F[fi])]
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


def build():
    mb = MB()
    mb.mat = 0
    W_B, W_H, W_A = {'Body': 1}, {'Head': 1}, {'Abdomen': 1}
    # one loft: abdomen tip (behind, low) -> thorax -> round head
    st = [(V(0, 0.52, 0.58), (0.06, 0.06), W_A), (V(0, 0.4, 0.7), (0.15, 0.15), W_A), (V(0, 0.24, 0.84), (0.2, 0.2), {'Abdomen': 0.5, 'Body': 0.5}),
          (V(0, 0.06, 0.98), (0.22, 0.22), W_B), (V(0, -0.08, 1.12), (0.2, 0.2), {'Body': 0.5, 'Head': 0.5}),
          (V(0, -0.14, 1.24), (0.24, 0.23), W_H), (V(0, -0.14, 1.38), (0.23, 0.22), W_H), (V(0, -0.12, 1.5), (0.14, 0.14), W_H)]
    n0 = len(mb.F)
    tube(mb, 'skin', [s[0] for s in st], [s[1] for s in st], 18, [s[2] for s in st], 'body', start='point', end='point',
         start_pt=V(0, 0.58, 0.5), end_pt=V(0, -0.1, 1.56), side_hint=V(1, 0, 0), th0=math.pi / 2)
    body_faces = list(range(n0, len(mb.F)))
    # fluffy mane round the neck
    fb, ft = ATLAS.uv('fluff', 0.5, 0.1), ATLAS.uv('fluff', 0.5, 0.95)
    for k in range(10):
        a = math.radians(-120 + 240 * k / 9)
        d = nrm(V(math.sin(a), -0.5 + 0.3 * math.cos(a), math.cos(a) * 0.5 - 0.3))
        base = V(0, -0.04, 1.08) + V(math.sin(a) * 0.16, 0, math.cos(a) * 0.1)
        bipyramid(mb, base, base + d * 0.24, V(0, 0, 1), V(0, -1, 0), 0.13, 0.06, W_B, fb, ft, 'fluff', wide_at=0.3, ridge_at=0.3)
    # four big wings
    for s, x in (('L', 1), ('R', -1)):
        def lobe(cx, cz, rx, rz, y0, y1, a0, a1, n):
            pts = []
            for i in range(n + 1):
                th = math.radians(a0 + (a1 - a0) * i / n)
                px = cx + rx * math.cos(th)
                pts.append(V(x * px, y0 + (y1 - y0) * (px / (cx + rx)), cz + rz * math.sin(th)))
            return pts
        # (17 Oct redo: real moth wing outlines instead of round lobes) a pointed forewing with a scalloped outer
        # margin, and a tapered hindwing with a short tail
        def outline(pts, y0, y1):
            mx = max(p[0] for p in pts)
            return [V(x * px, y0 + (y1 - y0) * (px / mx), pz) for px, pz in pts]
        # (HOS-PET-REDO, Hunter: "flat round disc wings read like paddles") a long sickle forewing with a hooked
        # pointed apex and a scalloped outer margin, layered over a separate pointed hindwing with a luna-moth tail
        fore = [(0.35, 1.3), (0.65, 1.6), (0.95, 1.88), (1.2, 2.05), (1.34, 2.09), (1.18, 1.9), (1.15, 1.75), (1.04, 1.63),
                (1.01, 1.47), (0.89, 1.35), (0.84, 1.19), (0.62, 1.08), (0.4, 1.02), (0.22, 1.0)]
        hind = [(0.25, 1.0), (0.5, 1.0), (0.74, 0.94), (0.92, 0.84), (1.0, 0.72), (0.86, 0.66), (0.84, 0.54), (0.7, 0.46),
                (0.6, 0.36), (0.48, 0.42), (0.36, 0.48), (0.24, 0.62), (0.16, 0.78)]
        wing(mb, 'wing', V(x * 0.12, 0.08, 1.04), outline(fore, 0.06, 0.2), {'Wing.' + s: 1}, 'wing')
        wing(mb, 'wing2', V(x * 0.12, 0.18, 0.94), outline(hind, 0.22, 0.36), {'Wing2.' + s: 1}, 'wing2')
        wing(mb, 'stream', V(x * 0.6, 0.36, 0.45), [V(x * 0.7, 0.37, 0.43), V(x * 0.98, 0.6, 0.18), V(x * 1.08, 0.68, 0.06),
                                                     V(x * 0.92, 0.6, 0.14), V(x * 0.6, 0.4, 0.36)], {'Wing2.' + s: 1}, 'stream')
        # feathered antennae: a stalk with two blades
        ab, at = ATLAS.uv('ant', 0.5, 0.1), ATLAS.uv('ant', 0.5, 0.95)
        bipyramid(mb, V(x * 0.06, -0.24, 1.42), V(x * 0.26, -0.36, 1.8), V(0, 1, 0), V(0, -1, 0), 0.12, 0.03,
                  {'Ant.' + s: 1}, ab, at, 'ant', wide_at=0.55, ridge_at=0.55)
        # little dangling forelegs
        tube(mb, 'limb', [V(x * 0.1, -0.1, 0.92), V(x * 0.14, -0.18, 0.76), V(x * 0.16, -0.22, 0.64)], [(0.04, 0.04), (0.035, 0.035), (0.03, 0.03)],
             6, [{'Arm.' + s: 1}] * 3, 'arm', start='point', end='point', start_pt=V(x * 0.06, -0.06, 0.96), end_pt=V(x * 0.17, -0.24, 0.58))
    # the gold crescent moon on the head
    ring(mb, 'gold', V(0, -0.06, 1.66), V(0, 1, 0), 0.16, 0.05, 12, 6, W_H, 'gold', arc=0.62, a0=math.radians(-20))
    mb.mat = 1
    face_shell(mb, body_faces)
    # ---- L2 "Eclipse": a second smaller crescent, a fuller mane
    mb.mat = 2
    ring(mb, 'gold', V(0, -0.02, 1.74), V(0, 1, 0), 0.24, 0.03, 12, 5, W_H, 'L2', arc=0.5, a0=math.radians(200))
    for k in range(6):
        a = math.radians(-100 + 200 * k / 5)
        d = nrm(V(math.sin(a), 0.4, math.cos(a) * 0.4 + 0.2))
        base = V(0, 0.02, 1.12) + V(math.sin(a) * 0.15, 0, math.cos(a) * 0.08)
        bipyramid(mb, base, base + d * 0.26, V(0, 0, 1), V(0, -1, 0), 0.12, 0.05, W_B, fb, ft, 'L2', wide_at=0.3, ridge_at=0.3)
    # ---- L3 "Moon Sovereign": full moon halo, hind-wing streamers
    mb.mat = 3
    ring(mb, 'halo', V(0, 0.2, 1.52), V(0, 1, 0.25), 0.42, 0.025, 16, 4, {'Halo': 1}, 'L3')
    for s, x in (('L', 1), ('R', -1)):
        wing(mb, 'stream', V(x * 0.62, 0.38, 0.4), [V(x * 0.7, 0.4, 0.38), V(x * 1.12, 0.8, 0.0), V(x * 1.26, 0.92, -0.12),
                                                    V(x * 1.06, 0.8, -0.02), V(x * 0.62, 0.42, 0.3)], {'Wing2.' + s: 1}, 'L3')
    mb.mat = 0
    return mb


def _saw(x):
    f = x - np.floor(x)
    return 1 - np.abs(2 * f - 1)


def _pgrain(h, w, seed):
    a = grit(h, 2 * w, seed)
    t = (np.arange(w, dtype=np.float32) / w)[None, :]
    return a[:, w:] * (1 - t) + a[:, :w] * t


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


FUR = [(0, '6a5a9a'), (0.5, 'c8bce8'), (1, 'f4f0ff')]


def paint_atlas(level):
    col = np.zeros((TS, TS, 3), np.float32)
    hgt = np.full((TS, TS), 0.5, np.float32)
    rgh = np.full((TS, TS), 0.6, np.float32)
    glow = np.zeros((TS, TS), np.float32)
    gd, gm, gh = GLOW[level]
    (y0, y1, x0, x1), v, u = _reg('skin')
    h, w = y1 - y0, x1 - x0
    top = np.cos(u * 2 * math.pi)
    c = grad(np.clip(0.5 + 0.3 * top + 0.2 * v, 0, 1), FUR)
    bands = ss(0.03, 0.0, np.abs(_saw(v * 7) - 0.5) - 0.12) * ss(0.45, 0.3, v)     # dark abdomen bands
    c = c * (1 - 0.65 * bands[..., None]) + hx('2a1a4a') * (0.65 * bands[..., None])
    back = ss(0.5, 0.7, top + 0.1 * _saw(v * 16 + u * 4)) * ss(0.35, 0.5, v)
    c = c * (1 - 0.5 * back[..., None]) + hx('4a3a7a') * (0.5 * back[..., None])
    st = _streaks(h, w, 180, 71)
    col[y0:y1, x0:x1] = c * (1 + 0.25 * st[..., None])
    hgt[y0:y1, x0:x1] = 0.5 + 0.45 * st
    # wings: deep violet membrane, veins, glowing moon-eye spots, jagged dark edge
    for reg, eyes in (('wing', ((0.6, 0.58, 0.075),)), ('wing2', ((0.55, 0.62, 0.07),))):
        (y0, y1, x0, x1), v, u = _reg(reg)
        A, B = v, u                                  # A across the span (root -> tip), B low -> high
        base = grad(np.clip(0.3 + 0.6 * A, 0, 1), [(0, '2a1a5a'), (0.6, '7a5ac8'), (1, 'c8b0ff')])
        ang = np.arctan2(B - 0.5, A + 0.02)
        veins = ss(0.02, 0.0, np.abs(_saw(ang / math.pi * 4 + 0.5) - 0.5) * (A + 0.1) - 0.004) * ss(0.05, 0.15, A)
        c = base * (1 - 0.5 * veins[..., None])
        spot = np.zeros_like(A)
        ring_ = np.zeros_like(A)
        for (ca, cb, r) in eyes:
            d = np.sqrt((A - ca) ** 2 + (B - cb) ** 2)
            spot = np.maximum(spot, ss(r * 0.55, r * 0.45, d))
            ring_ = np.maximum(ring_, ss(0.015, 0.0, np.abs(d - r) - 0.01))
        crescent = spot * ss(0.0, 0.02, np.sqrt((A - eyes[0][0] - 0.03) ** 2 + (B - eyes[0][1] - 0.03) ** 2) - eyes[0][2] * 0.4)
        c = c * (1 - ring_[..., None]) + hx('1a0a3a') * ring_[..., None]
        c = c * (1 - crescent[..., None]) + hx(gh) * crescent[..., None]
        band = ss(0.025, 0.0, np.abs(A - (0.78 + 0.05 * _saw(B * 7))) - 0.02) + ss(0.02, 0.0, np.abs(A - (0.35 + 0.04 * _saw(B * 5))) - 0.012)
        c = c * (1 - 0.7 * np.clip(band, 0, 1)[..., None]) + hx('e8dcff') * (0.7 * np.clip(band, 0, 1)[..., None])
        edge = ss(0.0, 0.04, A - (0.9 + 0.05 * _saw(B * 9)))
        c = c * (1 - edge[..., None]) + hx('140a2a') * edge[..., None]
        col[y0:y1, x0:x1] = c
        rgh[y0:y1, x0:x1] = 0.35
        glow[y0:y1, x0:x1] = np.clip(crescent + veins * 0.5 * (level >= 2) + 0.15 * A * (level >= 2), 0, 1)
    (y0, y1, x0, x1), v, u = _reg('fluff')
    st = _streaks(y1 - y0, x1 - x0, 40, 72)
    col[y0:y1, x0:x1] = grad(np.clip(0.6 + 0.4 * v, 0, 1), FUR) * (1 + 0.25 * st[..., None])
    hgt[y0:y1, x0:x1] = 0.5 + 0.4 * st
    (y0, y1, x0, x1), v, u = _reg('gold')
    col[y0:y1, x0:x1] = grad(u, [(0, 'fff0a0'), (0.5, 'ffc23a'), (1, 'a8700a')])
    rgh[y0:y1, x0:x1] = 0.25
    glow[y0:y1, x0:x1] = 0.3
    (y0, y1, x0, x1), v, u = _reg('ant')
    barbs = 0.5 + 0.5 * np.cos(v * 2 * math.pi * 12)
    col[y0:y1, x0:x1] = grad(v, [(0, '3a2a6a'), (1, 'c8b8f0')]) * (0.75 + 0.3 * barbs[..., None])
    (y0, y1, x0, x1), v, u = _reg('limb')
    col[y0:y1, x0:x1] = grad(v, [(0, '6a5a9a'), (1, '1a1030')])
    (y0, y1, x0, x1), v, u = _reg('stream')
    col[y0:y1, x0:x1] = grad(u, [(0, '2a1a5a'), (0.5, '7a5ac8'), (0.85, gm), (1, gh)])
    glow[y0:y1, x0:x1] = ss(0.6, 1.0, u) * 0.8
    (y0, y1, x0, x1), v, u = _reg('halo')
    col[y0:y1, x0:x1] = grad(u, [(0, 'e8e0ff'), (0.5, 'ffffff'), (1, 'e8e0ff')])
    glow[y0:y1, x0:x1] = 0.9
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
    ix, iz, ox, oz = 0.05, 1.26, 0.17, 1.32
    ex, ez = ox - ix, oz - iz
    L = math.hypot(ex, ez)
    s = ((aX - ix) * ex + (Z - iz) * ez) / (L * L)
    d = (-(aX - ix) * ez + (Z - iz) * ex) / L
    sc = np.clip(s, 0, 1)
    top = 0.03 * np.clip(sc * 3.0, 0, 1) * (1 - sc ** 4) + 0.002
    bot = -0.022 * np.clip(np.sin(math.pi * sc), 0, 1) ** 0.9 - 0.001
    eye = ss(0.003, 0.0, np.maximum(d - top, bot - d)) * (s > 0) * (s < 1)
    cxs, czs = ix + 0.5 * ex, iz + 0.5 * ez
    rr = np.sqrt((aX - cxs) ** 2 + (Z - czs) ** 2)
    _face_layers.rr = rr
    iris = ss(0.044, 0.04, rr)
    slit = ss(0.005 * np.clip(1 - ((Z - czs) / 0.032) ** 2, 0, 1) + 0.0005, 0.0, np.abs(aX - cxs)) * ss(0.032, 0.028, rr)
    brow = np.maximum(_seg(aX, Z, (0.03, 1.3), (0.18, 1.37), 0.01, 0.005), _seg(aX, Z, (0.16, 1.36), (0.22, 1.41), 0.007, 0.001))
    lid = ss(0.006, 0.003, np.abs(d - top - 0.003)) * (s > -0.05) * (s < 1.02)
    zc = 1.29 + 0.05 * aX
    hh = 0.05 * np.clip(1 - (aX / 0.23) ** 2, 0, 1) + 0.004
    mask = ss(0.004, 0.0, np.abs(Z - zc) - hh) * (aX < 0.24)
    mark = ss(0.004, 0.0, np.sqrt(X ** 2 + (Z - 1.42) ** 2) - 0.02) * ss(0.0, 0.004, np.sqrt((X - 0.01) ** 2 + (Z - 1.425) ** 2) - 0.017)
    if level >= 2:
        mark = np.maximum(mark, _seg(aX, Z, (0.14, 1.22), (0.17, 1.17), 0.007, 0.002))
    if level >= 3:
        mark = np.maximum(mark, _seg(aX, Z, (0.06, 1.42), (0.1, 1.47), 0.006, 0.002))
    mouth = _seg(X, Z, (-0.04, 1.12), (0.04, 1.12), 0.004, 0.004)
    return X, Z, eye, iris, slit, brow, lid, mask, mark, mouth


def face_texture(level, size=512):
    X, Z, eye, iris, slit, brow, lid, mask, mark, mouth = _face_layers(level, size)
    rr = _face_layers.rr
    ed, em, eh = EYE[level]
    gd, gm, gh = GLOW[level]
    rgba = np.zeros((size, size, 4), np.float32)
    c = np.zeros((size, size, 3), np.float32) + hx('1e143a')
    c = c * (1 - mark[..., None]) + hx(gm) * mark[..., None]
    irisc = grad(np.clip(1 - rr / 0.04, 0, 1), [(0, ed), (0.45, em), (1, eh)])
    e = hx('0a0814') * (1 - iris[..., None]) + irisc * iris[..., None]
    e = e * (1 - slit[..., None]) + hx('020208') * slit[..., None]
    c = c * (1 - eye[..., None]) + e * eye[..., None]
    ln = np.maximum.reduce([lid, brow, mouth])
    c = c * (1 - ln[..., None]) + hx('0a0618') * ln[..., None]
    rgba[..., :3] = c
    rgba[..., 3] = np.clip(np.maximum.reduce([mask * 0.85, eye, ln, mark]), 0, 1)
    return rgba


def face_emissive(level, size=512):
    X, Z, eye, iris, slit, brow, lid, mask, mark, mouth = _face_layers(level, size)
    g = np.clip(np.maximum(iris * eye * (1 - slit), mark * 0.9), 0, 1)
    return np.repeat(g[..., None], 3, -1)


def _ease(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def _pulse(t, a, b):
    if t <= a or t >= b:
        return 0.0
    return math.sin(math.pi * (t - a) / (b - a))


def _wings(w, amp, base=0.0):
    """Wing ('y', -L / +R) opens the wings up (as the Imp)."""
    f = amp * math.sin(w) + base
    return {'Wing.L': P(('y', -f)), 'Wing.R': P(('y', f)),
            'Wing2.L': P(('y', -0.8 * amp * math.sin(w - 0.4) - base * 0.6)), 'Wing2.R': P(('y', 0.8 * amp * math.sin(w - 0.4) + base * 0.6))}


def anim_idle():
    F = 72
    keys = {}
    for f in range(0, F + 1, 2):
        t = f / F
        w = 2 * math.pi * t
        k = {'Body': P(('x', 4 + 2 * math.sin(w)), loc=(0, 0, 0.07 * math.sin(w))),
             'Head': P(('x', -3 * math.sin(w)), ('z', 10 * math.sin(w * 0.5))), 'Abdomen': P(('x', 6 * math.sin(w + 1))),
             'Ant.L': P(('x', -8 * math.sin(w * 2))), 'Ant.R': P(('x', -8 * math.sin(w * 2 + 0.5))),
             'Arm.L': P(('x', 10 * math.sin(w))), 'Arm.R': P(('x', 10 * math.sin(w + 0.6))),
             'Halo': P(('z', 360 * t), loc=(0, 0, 0.03 * math.sin(w)))}
        k.update(_wings(w * 3, 22, 8))
        keys[f] = k
    keys[F] = dict(keys[0])
    keys[F]['Halo'] = P(('z', 0), loc=(0, 0, 0))
    return {'frames': F, 'loop': True, 'keys': keys}


def _fly(frames, pitch, amp):
    keys = {}
    for f in range(0, frames + 1, 1):
        t = f / frames
        w = 2 * math.pi * t
        k = {'Body': P(('x', pitch + 3 * math.sin(w)), loc=(0, 0, 0.06 * math.sin(w - 1.2))),
             'Head': P(('x', -pitch * 0.7)), 'Abdomen': P(('x', -pitch * 0.5 + 4 * math.sin(w))),
             'Ant.L': P(('x', 25)), 'Ant.R': P(('x', 25)), 'Arm.L': P(('x', 30)), 'Arm.R': P(('x', 30)),
             'Halo': P(('x', -pitch * 0.4))}
        k.update(_wings(w, amp, 10))
        keys[f] = k
    return {'frames': frames, 'loop': True, 'keys': keys}


def anim_walk():
    return _fly(20, 25, 32)


def anim_run():
    return _fly(14, 45, 40)


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
    """Vanish (~1 s, Runner): folds all four wings round itself like a cocoon, then flings them wide in a flash of
    moon dust (it turns invisible at ~0.5) and settles."""
    keys = {}
    F = 24
    for f in range(0, F + 1, 2):
        t = f / F
        fold = _ease(t / 0.35) * (1 - _ease((t - 0.45) / 0.1))
        open_ = _ease((t - 0.45) / 0.1) * (1 - _ease((t - 0.8) / 0.2))
        k = {'Body': P(('x', 10 * fold - 12 * open_), loc=(0, 0, -0.05 * fold + 0.12 * open_)),
             'Head': P(('x', 14 * fold - 10 * open_)), 'Abdomen': P(('x', 20 * fold)),
             'Wing.L': P(('y', 70 * fold - 50 * open_), ('z', -40 * fold)), 'Wing.R': P(('y', -70 * fold + 50 * open_), ('z', 40 * fold)),
             'Wing2.L': P(('y', 60 * fold - 40 * open_), ('z', -30 * fold)), 'Wing2.R': P(('y', -60 * fold + 40 * open_), ('z', 30 * fold)),
             'Ant.L': P(('x', 20 * fold - 15 * open_)), 'Ant.R': P(('x', 20 * fold - 15 * open_)), 'Halo': P(('z', 720 * t))}
        keys[f] = k
    return {'frames': F, 'loop': False, 'keys': keys}


def anim_stalk():
    """Stalk (~0.75 s, Catcher): wings sweep back flat, it dips and darts forward low, then rises."""
    keys = {}
    F = 18
    for f in range(0, F + 1, 1):
        t = f / F
        dip = _ease(t / 0.3) * (1 - _ease((t - 0.3) / 0.1))
        dart = _ease((t - 0.3) / 0.1) * (1 - _ease((t - 0.65) / 0.35))
        k = {'Body': P(('x', 14 * dip + 30 * dart), loc=(0, -0.3 * dart, -0.08 * dip)),
             'Head': P(('x', -10 * dart)), 'Ant.L': P(('x', 35 * dart)), 'Ant.R': P(('x', 35 * dart)),
             'Wing.L': P(('y', 20 * dip), ('z', -45 * dart)), 'Wing.R': P(('y', -20 * dip), ('z', 45 * dart)),
             'Wing2.L': P(('z', -40 * dart)), 'Wing2.R': P(('z', 40 * dart))}
        keys[f] = k
    return {'frames': F, 'loop': False, 'keys': keys}


ANIMS = {'Idle': anim_idle, 'Walk': anim_walk, 'Run': anim_run, 'Hop': anim_hop, 'Ability': anim_ability,
         'Stalk': anim_stalk}
