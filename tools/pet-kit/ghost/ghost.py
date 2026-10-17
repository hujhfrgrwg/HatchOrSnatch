# Grin Ghost (Invisibility, Rare) for Hatch or Snatch: HOS-PET-018, built on the pet kit (docs/pets/Pet Pipeline Guide.md).
# From the concept-library card (docs/pets/grin_ghost/grin_ghost_card.png): a floating violet ghost with tall crescent
# horn-ears, small cheek fins, stubby clawed arms, a wispy tail instead of legs and a huge toothy grin. Read through
# PET_LESSONS (anime / edgy): dusky violet, near-black wisp tail with glowing flame-tooth edges, narrow slanted glowing
# eyes under an angry brow, a wide shark-toothed grin (menacing, not cheerful), spiky back, painted flush on a face
# decal shell. L2 "Haunt": shackles with broken chains, two ghost-fire wisps, brow spikes, teal-green ghost fire.
# L3 "Phantom King": a floating jagged crown, extra tail tatters and back spikes, crimson eyes and glow.
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

NAME = 'Ghost'
SHARP_ANGLE = 40
NORMAL_STRENGTH = 2.0
TS = 1024
ATLAS = Atlas({
    'skin': (0, 0, 1024, 512),      # body loft: u around (0 = back seam, 0.5 = front), v tail tip -> crown
    'limb': (0, 512, 512, 128),     # arms: v shoulder -> hand
    'horn': (512, 512, 256, 128),   # v root -> tip
    'fin': (768, 512, 256, 128),    # cheek fins, back spikes: v root -> tip
    'wisp': (0, 640, 512, 128),     # tail tatters: v root -> tip
    'chain': (512, 640, 256, 128),  # L2 shackles + chain links
    'fire': (768, 640, 256, 128),   # L2 ghost-fire wisps: v root -> tip
    'claw': (0, 768, 128, 128),
    'crown': (128, 768, 384, 128),  # L3 crown band
    'crystal': (512, 768, 256, 128),  # L3 crown spikes
    'spike': (768, 768, 256, 128),  # L2 brow spikes, L3 back spikes
})

GLOW = {1: ('a35cff', 'f0dcff'), 2: ('3dffc8', 'e4fff6'), 3: ('ff2a4a', 'ffd6dc')}   # accent glow per level


# ---------------------------------------------------------------- skeleton
def bones_def():
    b = [
        ('Root', V(0, 0, 0), V(0, 0, 0.2), None),
        ('Body', V(0, 0.02, 0.5), V(0, 0, 0.82), 'Root'),
        ('Head', V(0, 0, 0.82), V(0, 0, 1.5), 'Body'),
        ('Tail1', V(0, 0.16, 0.38), V(0, 0.4, 0.26), 'Body'),
        ('Tail2', V(0, 0.4, 0.26), V(0, 0.62, 0.25), 'Tail1'),
        ('Tail3', V(0, 0.62, 0.25), V(0, 0.92, 0.4), 'Tail2'),
        ('Wisp', V(0, 0.1, 1.0), V(0, 0.1, 1.2), 'Body'),
        ('Crown', V(0, 0.04, 1.62), V(0, 0.04, 1.8), 'Head'),
    ]
    for s, x in (('L', 1), ('R', -1)):
        b += [
            ('Horn.' + s, V(x * 0.3, 0.04, 1.3), V(x * 0.55, 0.12, 1.85), 'Head'),
            ('ArmU.' + s, V(x * 0.4, -0.04, 0.74), V(x * 0.58, -0.14, 0.62), 'Body'),
            ('Hand.' + s, V(x * 0.58, -0.14, 0.62), V(x * 0.68, -0.24, 0.5), 'ArmU.' + s),
        ]
    return b


# ---------------------------------------------------------------- helpers (as the Imp)
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


def torus(mb, region, c, normal, R, r, n_around, n_tube, w, part):
    normal = nrm(np.asarray(normal, float))
    a = nrm(np.cross(normal, V(0, 0, 1) if abs(normal[2]) < 0.9 else V(1, 0, 0)))
    b = np.cross(normal, a)
    cen = [np.asarray(c, float) + (a * math.cos(2 * math.pi * i / n_around) + b * math.sin(2 * math.pi * i / n_around)) * R
           for i in range(n_around + 1)]
    tube(mb, region, cen, [(r, r)] * len(cen), n_tube, [w] * len(cen), part, start='open', end='open',
         side_hint=normal, anti=False)


FX, FZ, FZH = 0.54, 1.06, 0.44          # face decal shell: model x half-width, z centre, z half-height -> face texture


def _vnormals(mb, faces):
    acc = {}
    for fi in faces:
        f = mb.F[fi]
        a, b, c = mb.V[f[0]], mb.V[f[1]], mb.V[f[2]]
        n = np.cross(b - a, c - a)
        for v in f:
            acc[v] = acc.get(v, np.zeros(3)) + n
    return {v: nrm(n) for v, n in acc.items()}


def face_shell(mb, body_faces, lift=0.009):
    """mat-1 decal shell: the head's front facets lifted along smoothed normals with the same weights (eyes, brows,
    grin and marks are painted flush and follow the head in every frame)."""
    sel = [fi for fi in body_faces if all(mb.V[v][1] < -0.06 and 0.64 < mb.V[v][2] < 1.48 for v in mb.F[fi])]
    vn = _vnormals(mb, body_faces)
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


# body loft stations: tail tip (behind, low) -> under the body -> up through the head to the crown
STATIONS = [
    (V(0, 0.96, 0.52), (0.04, 0.04), {'Tail3': 1}),
    (V(0, 0.82, 0.34), (0.1, 0.08), {'Tail3': 1}),
    (V(0, 0.6, 0.24), (0.16, 0.13), {'Tail2': 0.7, 'Tail3': 0.3}),
    (V(0, 0.38, 0.26), (0.2, 0.17), {'Tail1': 0.6, 'Tail2': 0.4}),
    (V(0, 0.18, 0.35), (0.29, 0.25), {'Tail1': 0.5, 'Body': 0.5}),
    (V(0, 0.05, 0.49), (0.39, 0.34), {'Body': 1}),
    (V(0, 0.0, 0.65), (0.47, 0.41), {'Body': 1}),
    (V(0, 0.0, 0.83), (0.52, 0.45), {'Body': 0.5, 'Head': 0.5}),
    (V(0, 0.0, 1.0), (0.53, 0.46), {'Head': 1}),
    (V(0, 0.0, 1.16), (0.5, 0.44), {'Head': 1}),
    (V(0, 0.02, 1.3), (0.42, 0.38), {'Head': 1}),
    (V(0, 0.04, 1.41), (0.28, 0.26), {'Head': 1}),
]


def build():
    mb = MB()
    mb.mat = 0
    W_B, W_H = {'Body': 1}, {'Head': 1}
    n0 = len(mb.F)
    tube(mb, 'skin', [s[0] for s in STATIONS], [s[1] for s in STATIONS], 18, [s[2] for s in STATIONS], 'body',
         start='point', end='point', start_pt=V(0, 1.02, 0.64), end_pt=V(0, 0.05, 1.47), side_hint=V(1, 0, 0),
         th0=math.pi / 2)
    body_faces = list(range(n0, len(mb.F)))
    # tall crescent horn-ears: rise up and out, then hook back in at the tip (flattened, wide in the face plane)
    for s, x in (('L', 1), ('R', -1)):
        path = [V(x * 0.28, 0.04, 1.28), V(x * 0.42, 0.06, 1.46), V(x * 0.54, 0.1, 1.64), V(x * 0.58, 0.15, 1.82),
                V(x * 0.52, 0.2, 1.96)]
        d = nrm(path[-1] - path[-2])
        tube(mb, 'horn', path, [(0.09, 0.17), (0.08, 0.15), (0.065, 0.11), (0.045, 0.07), (0.025, 0.035)],
             8, [{'Horn.' + s: 1}] * len(path), 'horn', start='point', end='point', start_pt=V(x * 0.22, 0.03, 1.22),
             end_pt=path[-1] + d * 0.14 + V(-x * 0.03, 0, 0), anti=False, side_hint=V(0, 1, 0))
    # cheek fins (sharp, swept back and up) and a spiky back ridge: the angular silhouette
    fb, ft = ATLAS.uv('fin', 0.5, 0.1), ATLAS.uv('fin', 0.5, 0.92)
    for s, x in (('L', 1), ('R', -1)):
        bipyramid(mb, V(x * 0.44, 0.02, 0.98), V(x * 0.78, 0.12, 1.12), V(0, 0, 1), V(0, -1, 0), 0.2, 0.06, W_H, fb, ft,
                  'fin', wide_at=0.3, ridge_at=0.3)
        bipyramid(mb, V(x * 0.44, 0.06, 0.82), V(x * 0.7, 0.2, 0.86), V(0, 0, 1), V(0, -1, 0), 0.13, 0.05,
                  {'Body': 0.5, 'Head': 0.5}, fb, ft, 'fin', wide_at=0.3, ridge_at=0.3)
    for base, tip, wd, w in ((V(0, 0.36, 1.24), V(0, 0.66, 1.36), 0.2, W_H), (V(0.17, 0.38, 1.04), V(0.3, 0.72, 1.08), 0.17, W_H),
                             (V(-0.17, 0.38, 1.04), V(-0.3, 0.72, 1.08), 0.17, W_H), (V(0, 0.4, 0.86), V(0, 0.74, 0.86), 0.17, W_B)):
        bipyramid(mb, base, tip, V(1, 0, 0) if base[0] == 0 else V(0, 0, 1), V(0, 0, 1) if base[0] == 0 else V(0, 1, 0),
                  wd, 0.07, w, fb, ft, 'fin', wide_at=0.3, ridge_at=0.3)
    # stubby arms with three black claws each
    cb, ct = ATLAS.uv('claw', 0.5, 0.15), ATLAS.uv('claw', 0.5, 0.9)
    for s, x in (('L', 1), ('R', -1)):
        au, h = 'ArmU.' + s, 'Hand.' + s
        arm = [(V(x * 0.36, -0.04, 0.76), (0.11, 0.11), {'Body': 0.5, au: 0.5}), (V(x * 0.5, -0.1, 0.68), (0.095, 0.095), {au: 1}),
               (V(x * 0.58, -0.14, 0.62), (0.085, 0.085), {au: 0.5, h: 0.5}), (V(x * 0.65, -0.2, 0.54), (0.1, 0.09), {h: 1})]
        tube(mb, 'limb', [a[0] for a in arm], [a[1] for a in arm], 8, [a[2] for a in arm], 'arm' + s,
             start='point', end='point', start_pt=V(x * 0.28, -0.02, 0.8), end_pt=V(x * 0.69, -0.24, 0.47))
        for dx, dz in ((-0.05, 0.02), (0.0, -0.02), (0.05, 0.02)):
            b0 = V(x * (0.655 + dx), -0.2, 0.53 + dz)                  # root buried inside the hand
            bipyramid(mb, b0, b0 + V(x * dx * 0.8, -0.16, -0.1), V(1, 0, 0), V(0, 0, 1), 0.05, 0.045, {h: 1}, cb, ct,
                      'claw', wide_at=0.32, ridge_at=0.32)
    # wispy tail tatters: flame blades streaming off the tail end
    wb, wt = ATLAS.uv('wisp', 0.5, 0.06), ATLAS.uv('wisp', 0.5, 0.94)
    for base, tip, wd, w in ((V(0.04, 0.6, 0.25), V(0.26, 0.92, 0.18), 0.14, {'Tail2': 0.5, 'Tail3': 0.5}),
                             (V(-0.04, 0.6, 0.25), V(-0.26, 0.92, 0.18), 0.14, {'Tail2': 0.5, 'Tail3': 0.5}),
                             (V(0.0, 0.42, 0.3), V(0.0, 0.7, 0.55), 0.14, {'Tail1': 0.5, 'Tail2': 0.5})):
        bipyramid(mb, base, tip, V(0, 0, 1) if base[0] else V(1, 0, 0), V(0, 0, 1) if not base[0] else V(1, 0, 0), wd, 0.035,
                  [w, {'Tail3': 1}] + [w] * 4, wb, wt, 'wisp', wide_at=0.35, ridge_at=0.35)
    # ---- face decal shell (mat 1): eyes, brows, grin, tear marks, forehead sigil
    mb.mat = 1
    face_shell(mb, body_faces)
    # ---- level 2 (mat 2) "Haunt": wrist shackles + broken chains, two ghost-fire wisps, brow spikes
    mb.mat = 2
    for s, x in (('L', 1), ('R', -1)):
        h = 'Hand.' + s
        torus(mb, 'chain', V(x * 0.6, -0.16, 0.6), V(x * 0.07, -0.06, -0.08), 0.1, 0.03, 10, 4, {h: 1}, 'L2')
        torus(mb, 'chain', V(x * 0.6, -0.12, 0.47), V(1, 0, 0), 0.05, 0.016, 8, 4, {h: 1}, 'L2')
        torus(mb, 'chain', V(x * 0.6, -0.12, 0.39), V(0, 1, 0), 0.05, 0.016, 8, 4, {h: 1}, 'L2')
    xb, xt = ATLAS.uv('fire', 0.5, 0.05), ATLAS.uv('fire', 0.5, 0.95)
    for x in (1, -1):                               # ghost fire floating off each shoulder (Wisp bone: orbits in idle)
        c = V(x * 0.74, -0.04, 1.22)
        bipyramid(mb, c, c + V(x * 0.03, 0.04, 0.3), V(1, 0, 0), V(0, -1, 0), 0.16, 0.16, {'Wisp': 1}, xb, xt, 'L2',
                  wide_at=0.32, ridge_at=0.32)
        bipyramid(mb, c + V(0, 0.02, 0.06), c + V(-x * 0.07, 0.06, 0.24), V(1, 0, 0), V(0, -1, 0), 0.08, 0.08, {'Wisp': 1},
                  xb, xt, 'L2', wide_at=0.3, ridge_at=0.3)
    sb, st = ATLAS.uv('spike', 0.5, 0.1), ATLAS.uv('spike', 0.5, 0.95)
    for x in (1, -1):                               # spikes over the brow, inside the horns
        bipyramid(mb, V(x * 0.14, -0.06, 1.36), V(x * 0.2, -0.04, 1.58), V(1, 0, 0), V(0, -1, 0), 0.09, 0.06, W_H, sb, st,
                  'L2', wide_at=0.3, ridge_at=0.3)
    # ---- level 3 (mat 3) "Phantom King": a floating jagged crown, bigger tail tatters, more back spikes
    mb.mat = 3
    CC = V(0, 0.04, 1.66)
    tube(mb, 'crown', [CC + V(math.cos(2 * math.pi * i / 14) * 0.26, math.sin(2 * math.pi * i / 14) * 0.24, 0)
                       for i in range(15)], [(0.05, 0.022)] * 15, 4, [{'Crown': 1}] * 15, 'L3', start='open', end='open',
         side_hint=V(0, 0, 1), anti=False)
    yb, yt = ATLAS.uv('crystal', 0.5, 0.9), ATLAS.uv('crystal', 0.5, 0.08)
    for k, ln in enumerate((0.34, 0.2, 0.26, 0.2, 0.26, 0.2, 0.24)):
        a = -math.pi / 2 + 2 * math.pi * k / 7
        p = CC + V(math.cos(a) * 0.26, math.sin(a) * 0.24, 0.0)
        bipyramid(mb, p - V(0, 0, 0.03), p + V(0, 0, ln) + V(math.cos(a), math.sin(a), 0) * 0.04, V(-math.sin(a), math.cos(a), 0),
                  V(math.cos(a), math.sin(a), 0), 0.1, 0.06, {'Crown': 1}, yb, yt, 'L3', wide_at=0.3, ridge_at=0.3)
    for base, tip, wd, w in ((V(0.06, 0.66, 0.26), V(0.42, 1.04, 0.34), 0.16, {'Tail3': 1}),
                             (V(-0.06, 0.66, 0.26), V(-0.42, 1.04, 0.34), 0.16, {'Tail3': 1}),
                             (V(0.0, 0.7, 0.28), V(0.0, 1.12, 0.12), 0.15, {'Tail3': 1})):
        bipyramid(mb, base, tip, V(0, 0, 1) if base[0] else V(1, 0, 0), V(0, 0, 1) if not base[0] else V(1, 0, 0), wd, 0.035,
                  w, wb, wt, 'L3', wide_at=0.35, ridge_at=0.35)
    for base, tip, w in ((V(0.3, 0.3, 1.2), V(0.46, 0.6, 1.3), W_H), (V(-0.3, 0.3, 1.2), V(-0.46, 0.6, 1.3), W_H),
                         (V(0.2, 0.36, 0.66), V(0.34, 0.66, 0.6), W_B), (V(-0.2, 0.36, 0.66), V(-0.34, 0.66, 0.6), W_B)):
        bipyramid(mb, base, tip, V(0, 0, 1), V(0, 1, 0), 0.13, 0.06, w, sb, st, 'L3', wide_at=0.3, ridge_at=0.3)
    mb.mat = 0
    return mb


# ---------------------------------------------------------------- painting
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


def _violet(level):
    if level == 3:                                  # deeper indigo, near-black shadows
        return [(0, '0a0614'), (0.45, '2c1a58'), (1, '6c52b4')]
    if level == 2:                                  # brighter, a cooler blue-violet
        return [(0, '120c26'), (0.5, '4a3a96'), (1, '9a8ce4')]
    return [(0, '120a20'), (0.5, '45307c'), (1, '9a82d6')]


def _reg(name):
    y0, y1, x0, x1 = ATLAS.px(name)
    h, w = y1 - y0, x1 - x0
    v, u = np.mgrid[0:h, 0:w].astype(np.float32)
    return (y0, y1, x0, x1), v / h, u / w


def paint_atlas(level):
    col = np.zeros((TS, TS, 3), np.float32)
    hgt = np.full((TS, TS), 0.5, np.float32)
    rgh = np.full((TS, TS), 0.5, np.float32)
    glow = np.zeros((TS, TS), np.float32)
    vio = _violet(level)
    gc, ghi = GLOW[level]
    # ---- skin. v: 0 tail tip .. 1 crown. u: 0 back seam, 0.5 front.
    (y0, y1, x0, x1), v, u = _reg('skin')
    h, w = y1 - y0, x1 - x0
    front = np.cos((u - 0.5) * 2 * math.pi)
    c = grad(np.clip(0.2 + 0.85 * v + 0.12 * front - 0.25, 0, 1), vio)
    # the wisp: the tail darkens to near-black toward its tip, with a jagged flame-tooth edge
    tailm = ss(0.02, -0.02, v - (0.36 + 0.06 * _saw(u * 10)))
    c = c * (1 - 0.82 * tailm[..., None]) + hx('06040c') * (0.82 * tailm[..., None])
    edge = ss(0.03, 0.0, np.abs(v - (0.36 + 0.06 * _saw(u * 10)))) * 1.0
    # darker back with a jagged edge toward the front
    back = ss(0.02, -0.02, front - (-0.3 + 0.32 * _saw(v * 16)))
    c = c * (1 - 0.4 * back[..., None] * (1 - tailm[..., None]))
    # paler front of the face / belly with jagged edges (ectoplasm sheen)
    pale = ss(-0.02, 0.02, front - (0.5 + 0.2 * _saw(v * 20))) * ss(0.4, 0.48, v) * ss(0.95, 0.85, v)
    c = c * (1 - 0.45 * pale[..., None]) + grad(np.clip(v, 0, 1), [(0, vio[1][1]), (1, vio[2][1])]) * 1.2 * (0.45 * pale[..., None])
    # near-black slash markings over the back and crown (spectral tears)
    slash = ss(0.035, 0.015, np.abs(_saw(u * 7 + v * 2.0) - 0.5) * (1 - 0.6 * _saw(v * 3))) * back * ss(0.45, 0.55, v)
    c = c * (1 - 0.6 * slash[..., None])
    # swirling ectoplasm strokes (flowing streaks along the body) + grain
    st = _streaks(h, w, 140, 31)
    gr = _pgrain(h, w, 17)
    swirl = ss(0.02, 0.0, np.abs(_saw(u * 5 - v * 3.5) - 0.5) - 0.012) * ss(0.4, 0.55, v) * (1 - back)
    under = ss(0.02, 0.0, np.abs(_saw(u * 5 - v * 3.5 + 0.03) - 0.5) - 0.012) * ss(0.4, 0.55, v) * (1 - back)
    c = c * (1 + 0.25 * st[..., None] + 0.06 * gr[..., None]) * (1 - 0.3 * under[..., None]) + 0.22 * swirl[..., None] * hx(vio[2][1])
    # glowing wisp-edge flames at the tail boundary + small glowing veins up the tail
    vein = ss(0.008, 0.0, np.abs(_saw(u * 6 + v * 1.0) - 0.5) - 0.004) * tailm * ss(0.05, 0.2, v)
    gl = np.clip(edge * 0.9 + vein * (0.5 + 0.3 * (level >= 2)), 0, 1)
    c = c * (1 - gl[..., None]) + hx(gc) * gl[..., None]
    col[y0:y1, x0:x1] = c
    rgh[y0:y1, x0:x1] = 0.5 - 0.15 * pale
    hgt[y0:y1, x0:x1] = 0.5 + 0.4 * st + 0.15 * gr - 0.2 * slash
    glow[y0:y1, x0:x1] = gl
    # ---- arms: violet, jagged near-black hands
    (y0, y1, x0, x1), v, u = _reg('limb')
    tipm = ss(0.015, -0.015, (0.62 + 0.08 * _saw(u * 8)) - v)
    st = _streaks(y1 - y0, x1 - x0, 60, 32)
    cc = grad(np.clip(0.8 - 0.3 * v, 0, 1), vio)
    dark = grad(v, [(0.6, '120c1c'), (1, '050308')])
    col[y0:y1, x0:x1] = (cc * (1 - tipm[..., None]) + dark * tipm[..., None]) * (1 + 0.14 * st[..., None])
    rgh[y0:y1, x0:x1] = 0.5 - 0.1 * tipm
    hgt[y0:y1, x0:x1] = 0.5 + 0.35 * st + 0.2 * tipm
    # ---- horns: violet at the root, jagged near-black upper half, a glowing edge line at the tip
    (y0, y1, x0, x1), v, u = _reg('horn')
    dk = ss(0.0, 0.03, v - (0.45 + 0.08 * _saw(u * 6)))
    tipg = ss(0.86, 0.98, v)
    ridges = 0.5 + 0.5 * np.cos(v * 2 * math.pi * 7)
    base = grad(np.clip(0.9 - 0.4 * v, 0, 1), vio)
    cc = base * (1 - dk[..., None]) + grad(v, [(0.4, '1a1028'), (1, '07040c')]) * (1 - 0.15 * ridges[..., None]) * dk[..., None]
    col[y0:y1, x0:x1] = cc * (1 - tipg[..., None]) + hx(gc) * tipg[..., None]
    rgh[y0:y1, x0:x1] = 0.45
    hgt[y0:y1, x0:x1] = 0.5 + 0.2 * ridges * dk
    glow[y0:y1, x0:x1] = tipg
    # ---- fins / back spikes: violet root, near-black tip
    (y0, y1, x0, x1), v, u = _reg('fin')
    t = ss(0.0, 0.03, v - (0.5 + 0.1 * _saw(u * 5)))
    col[y0:y1, x0:x1] = grad(np.clip(0.75 - 0.3 * v, 0, 1), vio) * (1 - t[..., None]) + hx('0a0612') * t[..., None]
    rgh[y0:y1, x0:x1] = 0.45
    # ---- tail tatters: near-black membranes, glowing jagged edge
    (y0, y1, x0, x1), v, u = _reg('wisp')
    ed = ss(0.0, 0.03, v - (0.7 + 0.12 * _saw(u * 5)))
    veins = ss(0.012, 0.0, np.minimum.reduce([np.abs(u - k) for k in (0.25, 0.5, 0.75)]) - 0.004 * (1 - v))
    cc = grad(v, [(0, '1c1232'), (0.6, '0a0614'), (1, '06040c')]) * (1 - 0.4 * veins[..., None])
    col[y0:y1, x0:x1] = cc * (1 - ed[..., None]) + hx(gc) * ed[..., None]
    rgh[y0:y1, x0:x1] = 0.45
    hgt[y0:y1, x0:x1] = 0.5 + 0.3 * veins
    glow[y0:y1, x0:x1] = ed * 0.85
    # ---- claws: black, glowing tips from L2
    (y0, y1, x0, x1), v, u = _reg('claw')
    t = ss(0.55, 0.9, v) * (1.0 if level >= 2 else 0.0)
    col[y0:y1, x0:x1] = hx('0a0810') * (1 - t[..., None]) + hx(gc) * t[..., None]
    rgh[y0:y1, x0:x1] = 0.3
    glow[y0:y1, x0:x1] = t
    # ---- L2 shackles + chain: dark iron with a faint glow in the links' inner face
    (y0, y1, x0, x1), v, u = _reg('chain')
    core = np.clip(np.cos((u - 0.5) * 2 * math.pi), 0, 1) ** 3
    col[y0:y1, x0:x1] = hx('2a2836') * (0.8 + 0.4 * core[..., None])
    rgh[y0:y1, x0:x1] = 0.3
    hgt[y0:y1, x0:x1] = 0.5 + 0.2 * np.cos(v * 2 * math.pi * 6)
    # ---- L2 ghost fire: white-hot core to the level glow, glowing
    (y0, y1, x0, x1), v, u = _reg('fire')
    col[y0:y1, x0:x1] = grad(v, [(0, ghi), (0.45, gc), (1, '0a1a20' if level == 2 else '200614')])
    rgh[y0:y1, x0:x1] = 0.2
    glow[y0:y1, x0:x1] = 1.0 - 0.6 * v
    # ---- L3 crown band: black iron with a glowing jagged inlay
    (y0, y1, x0, x1), v, u = _reg('crown')
    inl = ss(0.02, 0.0, np.abs(v - 0.5) - (0.08 + 0.06 * _saw(u * 24)))
    col[y0:y1, x0:x1] = hx('100a18') * (1 - inl[..., None]) + hx(gc) * inl[..., None]
    rgh[y0:y1, x0:x1] = 0.25
    glow[y0:y1, x0:x1] = inl
    # ---- L3 crown spikes: crystal, white-hot core
    (y0, y1, x0, x1), v, u = _reg('crystal')
    col[y0:y1, x0:x1] = grad(v, [(0, ghi), (0.45, gc), (1, '300818')])
    rgh[y0:y1, x0:x1] = 0.12
    glow[y0:y1, x0:x1] = 0.55 + 0.45 * (1 - v)
    # ---- spikes (L2 brow, L3 back): near-black to a glowing tip
    (y0, y1, x0, x1), v, u = _reg('spike')
    t = ss(0.0, 0.03, v - (0.72 + 0.08 * _saw(u * 6)))
    col[y0:y1, x0:x1] = hx('0c0814') * (1 - t[..., None]) + hx(gc) * t[..., None]
    rgh[y0:y1, x0:x1] = 0.35
    glow[y0:y1, x0:x1] = t
    paint_atlas._glow = np.clip(glow, 0, 1)
    return np.clip(col, 0, 1), hgt, rgh


def emissive_mask(level):
    paint_atlas(level)
    return np.repeat(paint_atlas._glow[..., None], 3, -1)


# ---------------------------------------------------------------- face decal (eyes, brows, grin, marks)
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
    # eyes: narrow almonds slanting down toward the nose (inner corner low, outer corner high)
    ix, iz, ox, oz = 0.06, 1.1, 0.29, 1.17
    ex, ez = ox - ix, oz - iz
    L = math.hypot(ex, ez)
    s = ((aX - ix) * ex + (Z - iz) * ez) / (L * L)
    d = (-(aX - ix) * ez + (Z - iz) * ex) / L
    sc = np.clip(s, 0, 1)
    top = 0.05 * np.clip(sc * 3.0, 0, 1) * (1 - sc ** 4) + 0.002
    bot = -0.034 * np.clip(np.sin(math.pi * sc), 0, 1) ** 0.9 - 0.001
    inside = (s > 0) & (s < 1)
    eye = ss(0.003, 0.0, np.maximum(d - top, bot - d)) * inside
    cxs, czs = ix + 0.5 * ex, iz + 0.5 * ez
    rr = np.sqrt((aX - cxs) ** 2 + (Z - czs) ** 2)
    iris = ss(0.07, 0.065, rr)
    _face_layers.rr = rr
    slit = ss(0.008 * np.clip(1 - ((Z - czs) / 0.05) ** 2, 0, 1) + 0.0005, 0.0, np.abs(aX - cxs)) * ss(0.05, 0.046, rr)
    # heavy angry brow: a thick dark wedge over the eye, low at the nose, plus a sharp flick past the outer corner
    brow = np.maximum(_seg(aX, Z, (0.04, 1.14), (0.32, 1.25), 0.016, 0.006),
                      _seg(aX, Z, (0.3, 1.24), (0.38, 1.3), 0.008, 0.001))
    lid = ss(0.007, 0.004, np.abs(d - top - 0.003)) * (s > -0.05) * (s < 1.02)
    # dark tear streaks running down from the outer corners (edgy, spectral)
    tear = np.maximum(_seg(aX, Z, (0.25, 1.08), (0.27, 0.98), 0.012, 0.002), _seg(aX, Z, (0.2, 1.07), (0.21, 1.01), 0.007, 0.001))
    # forehead sigil: a crescent + a diamond (glows)
    r0 = np.sqrt(X ** 2 + (Z - 1.36) ** 2)
    r1 = np.sqrt(X ** 2 + (Z - 1.385) ** 2)
    sig = ss(0.004, 0.0, r0 - 0.06) * ss(0.0, 0.004, r1 - 0.056)
    sig = np.maximum(sig, ss(0.004, 0.0, aX / 0.022 + np.abs(Z - 1.3) / 0.04 - 1))
    if level >= 2:                                   # L2: cheek chevrons
        sig = np.maximum(sig, np.maximum(_seg(aX, Z, (0.34, 1.06), (0.42, 1.0), 0.01, 0.003), _seg(aX, Z, (0.36, 0.98), (0.43, 0.93), 0.008, 0.002)))
    if level >= 3:                                   # L3: brow crown marks
        sig = np.maximum(sig, np.maximum(_seg(aX, Z, (0.08, 1.28), (0.14, 1.38), 0.007, 0.002), _seg(aX, Z, (0.2, 1.3), (0.26, 1.37), 0.006, 0.002)))
    # the grin: a wide crescent, corners hooked up high under the cheeks; shark teeth along both lips
    zc_top = 0.9 + 0.48 * aX ** 2 + 0.55 * aX ** 4
    zc_bot = 0.76 + 0.95 * aX ** 2 + 0.7 * aX ** 4
    span = aX < 0.4
    mouth = ss(0.004, 0.0, np.maximum(Z - zc_top, zc_bot - Z)) * span * ss(0.41, 0.39, aX)
    gap = zc_top - zc_bot
    tw = 0.046                                       # tooth width
    ph = _saw(X / tw + 0.5)                          # 1 at tooth centre .. 0 between teeth
    up_t = (zc_top - Z) < (0.6 * gap * ph) + 0.004   # upper teeth hang down from the top lip
    lo_t = (Z - zc_bot) < (0.5 * gap * _saw(X / tw)) + 0.004
    teeth = mouth * np.clip(up_t * 1.0 + lo_t * 1.0, 0, 1)
    lip = ss(0.008, 0.004, np.minimum(np.abs(Z - zc_top), np.abs(Z - zc_bot))) * span * ss(0.42, 0.4, aX)
    corner = _seg(aX, Z, (0.38, zc_top_at(0.38)), (0.45, zc_top_at(0.38) + 0.05), 0.007, 0.001)
    return X, Z, eye, iris, slit, brow, lid, tear, sig, mouth, teeth, np.maximum(lip, corner)


def zc_top_at(x):
    return 0.9 + 0.48 * x ** 2 + 0.55 * x ** 4


def face_texture(level, size=512):
    X, Z, eye, iris, slit, brow, lid, tear, sig, mouth, teeth, lip = _face_layers(level, size)
    gc, ghi = GLOW[level]
    rr_ = _face_layers.rr
    rgba = np.zeros((size, size, 4), np.float32)
    c = np.zeros((size, size, 3), np.float32) + hx('0a0612')
    core = ss(0.6, 1.0, sig) * 0.35
    c = c * (1 - sig[..., None]) + (hx(gc) * (1 - core[..., None]) + hx(ghi) * core[..., None]) * sig[..., None]
    # mouth: a deep void with a faint glow at the back of the throat, ivory teeth
    mz = np.clip((Z - 0.78) / 0.12, 0, 1)
    inner = grad(mz, [(0, '05030a'), (0.5, '1a0830'), (1, '05030a')]) + hx(gc) * 0.25 * np.exp(-((X / 0.12) ** 2 + ((Z - 0.84) / 0.04) ** 2))[..., None]
    c = c * (1 - mouth[..., None]) + inner * mouth[..., None]
    tcol = grad(np.clip((Z - 0.8) / 0.2, 0, 1), [(0, 'cfc6e0'), (1, 'f6f2ff')])
    c = c * (1 - teeth[..., None]) + tcol * teeth[..., None]
    c = c * (1 - lip[..., None]) + hx('06040a') * lip[..., None]
    irisc = grad(np.clip(1 - rr_ / 0.065, 0, 1), [(0, '2a0a40' if level < 3 else '400810'), (0.35, gc), (0.8, ghi), (1, 'ffffff')])
    e = hx('0c0614') * (1 - iris[..., None]) + irisc * iris[..., None]
    e = e * (1 - slit[..., None]) + hx('040206') * slit[..., None]
    c = c * (1 - eye[..., None]) + e * eye[..., None]
    ln = np.maximum(lid, np.maximum(brow, tear))
    c = c * (1 - ln[..., None]) + hx('06040a') * ln[..., None]
    rgba[..., :3] = c
    rgba[..., 3] = np.clip(np.maximum.reduce([eye, ln, sig, mouth, lip]), 0, 1)
    return rgba


def face_emissive(level, size=512):
    X, Z, eye, iris, slit, brow, lid, tear, sig, mouth, teeth, lip = _face_layers(level, size)
    throat = mouth * (1 - teeth) * 0.35 * np.exp(-((X / 0.12) ** 2 + ((Z - 0.84) / 0.04) ** 2))
    g = np.clip(np.maximum.reduce([iris * eye * (1 - slit), sig * 0.9, throat, teeth * mouth * 0.25]), 0, 1)
    return np.repeat(g[..., None], 3, -1)


# ---------------------------------------------------------------- animation (24 fps, in place, it floats)
# A sly, menacing floater: it hangs in the air with a slow bob, the tail rippling like smoke, head cocked, claws
# flexing. It never walks: Walk / Run are flight (body pitched into the flight line, tail streaming). Casts: Vanish
# (Runner): it wraps its arms over its face, spins and flings open with the grin; Tether (Catcher): it rears back,
# lunges a claw forward to throw the tether, then yanks back.
# Signs (as the Imp, checked in out/anims.png): ('x', +) pitches a bone forward / down; ArmU ('y', -L / +R) raises
# the arms out to the sides; ArmU ('z', -L / +R) swings them in front of the chest.

def _ease(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def _pulse(t, a, b):
    if t <= a or t >= b:
        return 0.0
    return math.sin(math.pi * (t - a) / (b - a))


def _tail_wave(w, amp, pitch=0.0):
    return {'Tail1': P(('x', -pitch * 0.4), ('z', amp * math.sin(w))),
            'Tail2': P(('x', -pitch * 0.3), ('z', amp * 1.3 * math.sin(w - 0.9))),
            'Tail3': P(('x', -pitch * 0.2), ('z', amp * 1.6 * math.sin(w - 1.8)))}


def anim_idle():
    """3 s loop: slow bob, tail ripples like smoke, a sly head cock, claws flex, the ghost fire orbits."""
    F = 72
    keys = {}
    for f in range(0, F + 1, 3):
        t = f / F
        w = 2 * math.pi * t
        cock = _pulse(t, 0.3, 0.7)
        flex = _pulse(t, 0.6, 0.8)
        k = {'Body': P(('x', 4 + 2 * math.sin(w)), ('z', 4 * math.sin(w * 0.5 + 0.3)), loc=(0, 0, 0.08 * math.sin(w))),
             'Head': P(('x', 6 - 3 * math.sin(w)), ('y', 10 * cock), ('z', -12 * cock)),
             'Horn.L': P(('y', -4 * math.sin(w + 0.5))), 'Horn.R': P(('y', 4 * math.sin(w + 0.5))),
             'ArmU.L': P(('x', -18 + 6 * math.sin(w)), ('z', -20), ('y', -8 * flex)),
             'ArmU.R': P(('x', -18 + 6 * math.sin(w + 0.4)), ('z', 20), ('y', 8 * flex)),
             'Hand.L': P(('x', -20 - 25 * flex)), 'Hand.R': P(('x', -20 - 25 * flex)),
             'Wisp': P(('z', 360 * t), loc=(0, 0, 0.04 * math.sin(2 * w))),
             'Crown': P(('z', 8 * math.sin(w)), loc=(0, 0, 0.03 * math.sin(w + 1.0)))}
        k.update(_tail_wave(w, 14))
        keys[f] = k
    keys[F] = dict(keys[0])
    keys[F]['Wisp'] = P(('z', 0), loc=(0, 0, 0))
    return {'frames': F, 'loop': True, 'keys': keys}


def _fly(frames, pitch, sway):
    keys = {}
    for f in range(0, frames + 1, 2):
        t = f / frames
        w = 2 * math.pi * t
        k = {'Body': P(('x', pitch + 3 * math.sin(w + 0.6)), loc=(0, 0, 0.06 * math.sin(w - 1.2))),
             'Head': P(('x', -pitch * 0.7 + 2 * math.sin(w + 1.0))),
             'ArmU.L': P(('x', 40 + 6 * math.sin(w)), ('z', 14)), 'ArmU.R': P(('x', 40 + 6 * math.sin(w + 0.5)), ('z', -14)),
             'Hand.L': P(('x', 20)), 'Hand.R': P(('x', 20)),
             'Horn.L': P(('x', 10)), 'Horn.R': P(('x', 10)),
             'Wisp': P(loc=(0, 0.1, -0.05)), 'Crown': P(('x', -pitch * 0.3))}
        k.update(_tail_wave(w, sway, pitch))
        keys[f] = k
    keys[frames] = dict(keys[0])
    return {'frames': frames, 'loop': True, 'keys': keys}


def anim_walk():
    return _fly(24, 30, 16)


def anim_run():
    return _fly(16, 52, 22)


def anim_hop():
    """a spooky lunge up: squashes down, shoots up with arms flung wide, tail whipping."""
    keys = {}
    F = 16
    for f in range(0, F + 1, 2):
        t = f / F
        crouch = _pulse(t, 0.0, 0.3)
        up = _pulse(t, 0.2, 1.0)
        keys[f] = {'Body': P(('x', 10 * crouch - 10 * up), loc=(0, 0, -0.08 * crouch + 0.32 * up)),
                   'Head': P(('x', 12 * crouch - 8 * up)),
                   'ArmU.L': P(('y', -60 * up), ('x', -20 * crouch)), 'ArmU.R': P(('y', 60 * up), ('x', -20 * crouch)),
                   'Tail1': P(('x', 25 * up)), 'Tail2': P(('x', 20 * up)), 'Tail3': P(('x', 15 * up))}
    return {'frames': F, 'loop': False, 'keys': keys}


def anim_ability():
    """Vanish (~1 s, Runner): hunches and wraps both arms over its face, spins a full turn sinking into itself,
    then flings arms wide and rears up with the grin (the moment it turns invisible), and settles."""
    keys = {}
    F = 24
    for f in range(0, F + 1, 2):
        t = f / F
        wrap = _ease(t / 0.3) * (1 - _ease((t - 0.55) / 0.1))
        spin = _ease((t - 0.2) / 0.4)
        fling = _ease((t - 0.55) / 0.1) * (1 - _ease((t - 0.8) / 0.2))
        keys[f] = {'Root': P(('z', 360 * spin)),
                   'Body': P(('x', 14 * wrap - 16 * fling), loc=(0, 0, -0.1 * wrap + 0.12 * fling)),
                   'Head': P(('x', 18 * wrap - 14 * fling)),
                   'ArmU.L': P(('x', -50 * wrap), ('z', -70 * wrap), ('y', -85 * fling)),
                   'ArmU.R': P(('x', -50 * wrap), ('z', 70 * wrap), ('y', 85 * fling)),
                   'Hand.L': P(('x', -40 * wrap), ('z', -30 * wrap)), 'Hand.R': P(('x', -40 * wrap), ('z', 30 * wrap)),
                   'Horn.L': P(('y', 12 * wrap - 14 * fling)), 'Horn.R': P(('y', -12 * wrap + 14 * fling)),
                   'Tail1': P(('x', 30 * wrap - 20 * fling), ('z', 25 * math.sin(6 * t))),
                   'Tail2': P(('z', 35 * math.sin(6 * t - 1))), 'Tail3': P(('z', 45 * math.sin(6 * t - 2))),
                   'Wisp': P(('z', 720 * t)), 'Crown': P(loc=(0, 0, 0.12 * fling))}
    return {'frames': F, 'loop': False, 'keys': keys}


def anim_tether():
    """Tether (~0.75 s, Catcher): rears back with the right claw cocked, lunges forward thrusting it out (the tether
    fires), then yanks back with a hard pull."""
    keys = {}
    F = 18
    for f in range(0, F + 1, 1):
        t = f / F
        rear = _ease(t / 0.3) * (1 - _ease((t - 0.3) / 0.1))
        lunge = _ease((t - 0.3) / 0.1) * (1 - _ease((t - 0.55) / 0.12))
        yank = _ease((t - 0.55) / 0.12) * (1 - _ease((t - 0.8) / 0.2))
        keys[f] = {'Body': P(('x', -14 * rear + 22 * lunge - 18 * yank), ('z', 12 * rear - 8 * lunge),
                             loc=(0, 0.12 * rear - 0.25 * lunge + 0.18 * yank, 0.04 * rear)),
                   'Head': P(('x', -10 * rear + 6 * lunge - 6 * yank)),
                   'ArmU.R': P(('x', 40 * rear - 95 * lunge - 50 * yank), ('z', -30 * rear + 20 * lunge)),
                   'Hand.R': P(('x', 30 * rear - 20 * lunge + 40 * yank)),
                   'ArmU.L': P(('x', -20 * lunge), ('y', -30 * yank)), 'Hand.L': P(('x', -30 * yank)),
                   'Tail1': P(('x', 20 * lunge - 15 * yank)), 'Tail2': P(('x', 15 * lunge - 10 * yank)),
                   'Tail3': P(('x', 12 * lunge)),
                   'Wisp': P(('z', 360 * t))}
    return {'frames': F, 'loop': False, 'keys': keys}


ANIMS = {'Idle': anim_idle, 'Walk': anim_walk, 'Run': anim_run, 'Hop': anim_hop, 'Ability': anim_ability,
         'Stalk': anim_tether}
