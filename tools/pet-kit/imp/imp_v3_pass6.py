# Ring Imp (Rift, Common) for Hatch or Snatch: HOS-PET-017, built on the pet kit (docs/pets/Pet Pipeline Guide.md).
# Our own imp (NOT Hoopa: no rings on the horns, no floppy ringed ears, no pink/purple Hoopa layout, no Hoopa face):
# a chunky chibi floating imp (Hunter picked TEAL, 17 Oct): teal body, cream face mask and belly, short swept-back
# dark horns with gold tips (no rings), pointed ears, a thin tail with a spade tip, a dark collar with gold trim, big
# confident gold eyes and a sly one-fang grin. Its signature: one glowing magenta-to-cyan portal ring floating
# behind its back like a halo. L2: glowing runes on the ring + gold bracelets. L3: a second smaller ring + sparkles.
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

NAME = 'Imp'
SHARP_ANGLE = 75
NORMAL_STRENGTH = 2.0
TS = 1024
ATLAS = Atlas({
    'skin': (0, 0, 1024, 512),      # body + head loft: u around (0 = back seam, 0.5 = front), v bottom -> top
    'limb': (0, 512, 512, 128),     # arms + legs: v shoulder/hip -> hand/foot
    'horn': (512, 512, 256, 128),   # v root -> tip
    'wing': (768, 512, 256, 128),
    'ring': (0, 640, 512, 128),     # the portal ring + bracelets + mini ring
    'tail': (512, 640, 256, 128),
    'gold': (768, 640, 256, 128),   # gold gems / star specks
    'mouth': (0, 768, 256, 128),
    'fang': (256, 768, 128, 128),
    'collar': (384, 768, 256, 128),
    'spade': (640, 768, 256, 128),
    'ear': (896, 768, 128, 128),
})

VIOLET = '1f9e9a'      # (names kept from the first draft; these are the teal body tones now)
VIOLET_HI = '58d8c8'
VIOLET_DK = '0c4a52'
LAV = 'f6e8cc'         # cream face mask + belly
LAV_HI = 'fff6e4'
CYAN = '3fe0ff'
GOLD = 'ffc83a'
GOLD_HI = 'fff2b0'
GOLD_DK = 'c98a10'
MAGENTA = 'ff3fb0'
HORN = '3a3358'


# ---------------------------------------------------------------- skeleton
def bones_def():
    b = [
        ('Root', V(0, 0, 0), V(0, 0, 0.2), None),
        ('Body', V(0, 0, 0.45), V(0, 0, 0.78), 'Root'),
        ('Head', V(0, 0, 0.8), V(0, 0, 1.35), 'Body'),
        ('Ring', V(0, 0.46, 0.98), V(0, 0.46, 1.3), 'Body'),
        ('Tail1', V(0, 0.2, 0.42), V(0, 0.48, 0.3), 'Body'),
        ('Tail2', V(0, 0.48, 0.3), V(0, 0.68, 0.42), 'Tail1'),
        ('Tail3', V(0, 0.68, 0.42), V(0, 0.76, 0.6), 'Tail2'),
    ]
    for s, x in (('L', 1), ('R', -1)):
        b += [
            ('Ear.' + s, V(x * 0.42, 0.0, 1.12), V(x * 0.78, 0.06, 1.28), 'Head'),
            ('Horn.' + s, V(x * 0.2, 0.02, 1.38), V(x * 0.5, 0.2, 1.3), 'Head'),
            ('ArmU.' + s, V(x * 0.22, -0.02, 0.68), V(x * 0.38, -0.08, 0.55), 'Body'),
            ('Hand.' + s, V(x * 0.38, -0.08, 0.55), V(x * 0.48, -0.13, 0.4), 'ArmU.' + s),
            ('Leg.' + s, V(x * 0.12, 0.0, 0.42), V(x * 0.15, -0.06, 0.2), 'Body'),
        ]
    return b


# ---------------------------------------------------------------- helpers
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


def _surface(tris, p, n):
    o = np.asarray(p, float) + np.asarray(n, float) * 1.2
    t = raycast(o, -np.asarray(n, float), tris)
    return None if t is None else o - np.asarray(n, float) * t


def conform_disc(mb, tris, c, n, r, w, segs, part, lift=0.008, uv_fn=None, uvc=None):
    n = nrm(np.asarray(n, float))
    up = nrm(V(0, 0, 1) - n * n[2])
    side = nrm(np.cross(up, n))
    cs = _surface(tris, c, n)
    cs = np.asarray(c, float) if cs is None else cs
    ring = []
    for k in range(segs):
        a = 2 * math.pi * k / segs
        q = cs + (side * math.cos(a) + up * math.sin(a)) * r
        s = _surface(tris, q, n)
        s = q if s is None else s
        ring.append((mb.vert(s + n * lift, w), uv_fn(a) if uv_fn else uvc))
    ci = mb.vert(cs + n * (lift + 0.004), w)
    for k in range(segs):
        k2 = (k + 1) % segs
        mb.face([ring[k][0], ring[k2][0], ci], [ring[k][1], ring[k2][1], uv_fn(None) if uv_fn else uvc],
                inside=cs - n * 0.4, part=part)


def torus(mb, region, c, normal, R, r, n_around, n_tube, w, part):
    """A ring: a loft around a circle (first station repeated to close it)."""
    normal = nrm(np.asarray(normal, float))
    a = nrm(np.cross(normal, V(0, 0, 1) if abs(normal[2]) < 0.9 else V(1, 0, 0)))
    b = np.cross(normal, a)
    cen = [np.asarray(c, float) + (a * math.cos(2 * math.pi * i / n_around) + b * math.sin(2 * math.pi * i / n_around)) * R
           for i in range(n_around + 1)]
    tube(mb, region, cen, [(r, r)] * len(cen), n_tube, [w] * len(cen), part, start='open', end='open',
         side_hint=normal, anti=False)


# ---------------------------------------------------------------- build
EYE_C = {1: V(0.19, -0.47, 1.13), -1: V(-0.19, -0.47, 1.13)}
RING_C, RING_N, RING_R = V(0, 0.46, 0.98), V(0, 1, 0), 0.6


def build():
    mb = MB()
    mb.mat = 0
    W_B, W_H = {'Body': 1}, {'Head': 1}
    # one connected body + head loft, bottom -> top (chibi: small pear body, big round head)
    st = [(0.34, (0.2, 0.18), W_B), (0.46, (0.3, 0.27), W_B), (0.6, (0.31, 0.27), W_B), (0.72, (0.24, 0.21), {'Body': 0.6, 'Head': 0.4}),
          (0.82, (0.36, 0.33), {'Body': 0.2, 'Head': 0.8}), (0.97, (0.5, 0.45), W_H), (1.13, (0.53, 0.47), W_H),
          (1.29, (0.46, 0.41), W_H), (1.42, (0.28, 0.25), W_H)]
    tube(mb, 'skin', [V(0, 0, z) for z, _, _ in st], [r for _, r, _ in st], 16, [w for _, _, w in st], 'body',
         start='point', end='point', start_pt=V(0, 0, 0.28), end_pt=V(0, 0, 1.49), side_hint=V(1, 0, 0), th0=math.pi / 2)
    head_tris = tris_of(mb, {'body'})
    # collar: dark band with gold trim around the neck
    tube(mb, 'collar', [V(0, 0, 0.68), V(0, 0, 0.74), V(0, 0, 0.79)], [(0.28, 0.25), (0.3, 0.27), (0.31, 0.28)], 16,
         [W_B, W_B, {'Body': 0.5, 'Head': 0.5}], 'collar', start='flat', end='flat', side_hint=V(1, 0, 0),
         th0=math.pi / 2)
    # pointed elf ears (flat leaf shapes, rigid)
    eb, et = ATLAS.uv('ear', 0.3, 0.8), ATLAS.uv('ear', 0.7, 0.1)
    for s, x in (('L', 1), ('R', -1)):
        bipyramid(mb, V(x * 0.38, 0.0, 1.1), V(x * 0.76, 0.08, 1.3), V(0, 1, 0), V(0, -0.3, 1), 0.3, 0.1,
                  {'Ear.' + s: 1}, eb, et, 'ear', wide_at=0.32, ridge_at=0.3)
    # curled ram horns, dark with gold tips
    for s, x in (('L', 1), ('R', -1)):
        path = [V(x * 0.2, -0.04, 1.33), V(x * 0.26, 0.0, 1.55), V(x * 0.31, 0.08, 1.72), V(x * 0.35, 0.2, 1.84),
                V(x * 0.37, 0.34, 1.9)]
        tube(mb, 'horn', path, [(0.14, 0.13), (0.12, 0.11), (0.09, 0.085), (0.06, 0.055), (0.035, 0.03)],
             8, [{'Horn.' + s: 1}] * len(path), 'horn', start='point', end='point', start_pt=V(x * 0.16, -0.1, 1.27),
             end_pt=V(x * 0.38, 0.46, 1.92), anti=False)
    # arms (short, chunky) with round hands
    for s, x in (('L', 1), ('R', -1)):
        au, h = 'ArmU.' + s, 'Hand.' + s
        arm = [(V(x * 0.18, -0.01, 0.68), (0.1, 0.1), {'Body': 0.5, au: 0.5}), (V(x * 0.32, -0.06, 0.6), (0.095, 0.095), {au: 1}),
               (V(x * 0.4, -0.09, 0.52), (0.085, 0.085), {au: 0.5, h: 0.5}), (V(x * 0.46, -0.12, 0.43), (0.1, 0.1), {h: 1})]
        tube(mb, 'limb', [a[0] for a in arm], [a[1] for a in arm], 8, [a[2] for a in arm], 'arm' + s,
             start='point', end='point', start_pt=V(x * 0.1, 0.0, 0.7), end_pt=V(x * 0.5, -0.14, 0.34))
        lg = 'Leg.' + s
        leg = [(V(x * 0.1, 0.0, 0.42), (0.11, 0.11), {'Body': 0.5, lg: 0.5}), (V(x * 0.14, -0.03, 0.3), (0.1, 0.1), {lg: 1}),
               (V(x * 0.15, -0.08, 0.21), (0.11, 0.09), {lg: 1})]
        tube(mb, 'limb', [a[0] for a in leg], [a[1] for a in leg], 8, [a[2] for a in leg], 'leg' + s,
             start='point', end='point', start_pt=V(x * 0.06, 0.02, 0.48), end_pt=V(x * 0.16, -0.2, 0.16))
    # thin tail with a spade tip
    tp = [V(0, 0.2, 0.42), V(0, 0.42, 0.3), V(0, 0.62, 0.36), V(0, 0.74, 0.52)]
    tube(mb, 'tail', tp, [(0.055, 0.055), (0.045, 0.045), (0.04, 0.04), (0.035, 0.035)], 6,
         [{'Body': 0.4, 'Tail1': 0.6}, {'Tail1': 0.5, 'Tail2': 0.5}, {'Tail2': 0.5, 'Tail3': 0.5}, {'Tail3': 1}], 'tail',
         start='point', end='point', start_pt=V(0, 0.1, 0.44), end_pt=V(0, 0.77, 0.58))
    sb, stp = ATLAS.uv('spade', 0.3, 0.8), ATLAS.uv('spade', 0.7, 0.2)
    bipyramid(mb, V(0, 0.74, 0.52), V(0, 0.84, 0.78), V(0, 1, 0), V(0, 1, -0.3), 0.22, 0.05, {'Tail3': 1}, sb, stp,
              'spade', wide_at=0.35, ridge_at=0.3)
    # the sly grin (conforms to the face) + one fang
    pts = []
    for i in range(9):
        t = -1 + 2 * i / 8
        p = V(t * 0.18, -0.5, 0.9 + 0.04 * t + 0.05 * t * t)
        n = nrm(V(t * 0.4, -1, 0.0))
        s_ = _surface(head_tris, p, n)
        pts.append((s_ if s_ is not None else p) + n * 0.01)
    tube(mb, 'mouth', pts, [(0.016, 0.011)] * len(pts), 4, [W_H] * len(pts), 'mouth', start='flat', end='flat',
         side_hint=V(0, 0, 1), anti=False)
    fb, ft = ATLAS.uv('fang', 0.5, 0.8), ATLAS.uv('fang', 0.5, 0.2)
    fp = pts[3] + V(0, -0.005, -0.004)
    bipyramid(mb, fp, fp + V(0, -0.02, -0.07), V(1, 0, 0), V(0, -1, 0), 0.04, 0.02, W_H, fb, ft, 'fang')
    # the portal ring: a halo floating behind its back
    torus(mb, 'ring', RING_C, RING_N, RING_R, 0.06, 22, 6, {'Ring': 1}, 'ring')
    # ---- face decal (mat 1): big confident eyes
    mb.mat = 1
    for x in (1, -1):
        n = nrm(V(x * 0.36, -1.0, 0.08))

        def uvf(a, x=x):
            if a is None:
                return (0.5, 0.5)
            return (0.5 + 0.48 * math.cos(a) * (1 if x > 0 else -1), 0.5 + 0.48 * math.sin(a))
        conform_disc(mb, head_tris, EYE_C[x], n, 0.135, W_H, 16, 'eye', lift=0.025, uv_fn=uvf)
    # ---- level 2 (mat 2): gold bracelets on the wrists
    mb.mat = 2
    for s, x in (('L', 1), ('R', -1)):
        torus(mb, 'ring', V(x * 0.43, -0.105, 0.48), V(x * 0.06, -0.03, 0.09), 0.085, 0.022, 10, 4, {'Hand.' + s: 1}, 'L2')
    gb, gt = ATLAS.uv('gold', 0.3, 0.8), ATLAS.uv('gold', 0.7, 0.2)
    for k in range(6):                                   # glowing runes around the halo
        a = 2 * math.pi * (k + 0.5) / 6
        p = RING_C + V(math.cos(a), 0, math.sin(a)) * RING_R + V(0, -0.05, 0)
        bipyramid(mb, p, p + V(0, -0.1, 0), V(math.cos(a), 0, math.sin(a)), V(0, 0, 1), 0.08, 0.08, {'Ring': 1}, gb, gt,
                  'L2', wide_at=0.5, ridge_at=0.5)
    # ---- level 3 (mat 3): a second, smaller ring inside the halo + sparkles
    mb.mat = 3
    torus(mb, 'ring', RING_C + V(0, 0.04, 0), V(0, 1, 0.3), 0.38, 0.035, 16, 4, {'Ring': 1}, 'L3')
    for p in (V(0.5, 0.3, 1.5), V(-0.56, 0.36, 1.36), V(0.62, 0.4, 0.66), V(-0.5, 0.42, 0.6)):
        bipyramid(mb, p, p + V(0, 0, 0.1), V(1, 0, 0), V(0, -1, 0), 0.07, 0.07, {'Ring': 1}, gb, gt, 'L3',
                  wide_at=0.5, ridge_at=0.5)
    mb.mat = 0
    return mb


# ---------------------------------------------------------------- painting (clean blocks, one soft gradient each)
def _ellipse(h, w, cx, cy, rx, ry, soft=2.0):
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.sqrt(((xs - cx) / rx) ** 2 + ((ys - cy) / ry) ** 2)
    return np.clip((1 - d) * min(rx, ry) / soft + 0.5, 0, 1)


def _pgrain(h, w, seed):
    """grit made periodic across u (the tube seam), so no line shows at the back."""
    a = grit(h, 2 * w, seed)
    t = (np.arange(w, dtype=np.float32) / w)[None, :]
    return a[:, w:] * (1 - t) + a[:, :w] * t


def _fill(col, rgh, glow, region, colr, r, g=0.0):
    y0, y1, x0, x1 = ATLAS.px(region)
    col[y0:y1, x0:x1] = colr
    rgh[y0:y1, x0:x1] = r
    glow[y0:y1, x0:x1] = g


def paint_atlas(level):
    col = np.zeros((TS, TS, 3), np.float32)
    hgt = np.zeros((TS, TS), np.float32)
    rgh = np.full((TS, TS), 0.3, np.float32)
    glow = np.zeros((TS, TS), np.float32)
    rich = {1: 0.0, 2: 0.35, 3: 0.75}[level]
    vio = [(0, VIOLET_DK), (0.55, VIOLET), (1, VIOLET_HI)]
    if level == 3:
        vio = [(0, '0a4058'), (0.55, '1aa6b0'), (1, '6ef0e0')]
    # skin: violet, top-lit (v = bottom -> top), lavender face mask + belly on the front (u = 0.5)
    y0, y1, x0, x1 = ATLAS.px('skin')
    h, w = y1 - y0, x1 - x0
    v, u = np.mgrid[0:h, 0:w].astype(np.float32)
    u /= w; v = 1 - v / h        # image row 0 = top of the region = v 0 of the uv ... keep a bottom->top value
    front = np.cos((u - 0.5) * 2 * math.pi)        # +1 front, -1 back
    c = grad(np.clip(0.25 + 0.6 * (1 - v) + 0.15 * front, 0, 1), vio)
    face = _ellipse(h, w, 0.5 * w, 0.585 * h, 0.155 * w, 0.13 * h)   # muzzle under the eyes (row / h = height along the loft)
    belly = _ellipse(h, w, 0.5 * w, 0.2 * h, 0.12 * w, 0.12 * h)
    lav = grad(np.clip(0.35 + 0.65 * v, 0, 1), [(0, 'e8cfa2'), (0.5, LAV), (1, LAV_HI)])   # warm cream, never grey
    m = np.maximum(face, belly)
    edge = np.clip(1 - np.abs(m - 0.12) * 8, 0, 1) * (m < 0.5)          # a soft darker line where cream meets teal
    lav = lav * (1 - face[..., None]) + hx(LAV_HI) * face[..., None]
    c = c * (1 - m[..., None]) + lav * m[..., None]
    c = c * (1 - 0.12 * edge[..., None])
    gr = _pgrain(h, w, 11)
    c = c * (1 + 0.09 * gr[..., None])                      # light fur grain
    col[y0:y1, x0:x1] = c
    rgh[y0:y1, x0:x1] = 0.55 - 0.1 * m
    hgt[y0:y1, x0:x1] = 0.5 + 0.35 * gr - 0.25 * edge
    # limbs: violet, lavender hands / feet at the far end
    y0, y1, x0, x1 = ATLAS.px('limb')
    h, w = y1 - y0, x1 - x0
    v, u = np.mgrid[0:h, 0:w].astype(np.float32)
    v /= h
    tipm = ss(0.68, 0.78, v)
    c = grad(np.clip(0.7 - 0.3 * v, 0, 1), vio)
    gr = _pgrain(h, w, 12)
    col[y0:y1, x0:x1] = (c * (1 - tipm[..., None]) + hx(LAV) * tipm[..., None]) * (1 + 0.08 * gr[..., None])
    rgh[y0:y1, x0:x1] = 0.55
    hgt[y0:y1, x0:x1] = 0.5 + 0.3 * gr
    # horns: dark, gold tips that glow
    y0, y1, x0, x1 = ATLAS.px('horn')
    h, w = y1 - y0, x1 - x0
    v = np.mgrid[0:h, 0:w][0].astype(np.float32) / h
    tip = ss(0.5, 0.62, v)
    base = grad(v, [(0, '231e38'), (0.5, HORN)])
    ridges = 0.5 + 0.5 * np.cos(v * 2 * math.pi * 7)
    col[y0:y1, x0:x1] = (base * (1 - 0.15 * ridges[..., None]) * (1 - tip[..., None]) +
                         grad(v, [(0.5, GOLD_DK), (0.8, GOLD), (1, GOLD_HI)]) * tip[..., None])
    rgh[y0:y1, x0:x1] = 0.4 - 0.2 * tip
    hgt[y0:y1, x0:x1] = 0.5 + 0.25 * ridges * (1 - tip)
    glow[y0:y1, x0:x1] = tip * ss(0.7, 1.0, v)
    # wings: dark violet frame, magenta-violet membrane
    y0, y1, x0, x1 = ATLAS.px('wing')
    h, w = y1 - y0, x1 - x0
    v = np.mgrid[0:h, 0:w][0].astype(np.float32) / h
    col[y0:y1, x0:x1] = grad(v, [(0, VIOLET_DK), (0.6, '7a3ac8'), (1, 'c060e0')])
    rgh[y0:y1, x0:x1] = 0.35
    # the portal ring + bracelets + mini ring: gold, white-hot core, glowing (magenta edge at L2+)
    y0, y1, x0, x1 = ATLAS.px('ring')
    h, w = y1 - y0, x1 - x0
    vv, u = np.mgrid[0:h, 0:w].astype(np.float32)
    u /= w; vv /= h                                         # u around the tube, v around the ring
    around = 0.5 - 0.5 * np.cos(vv * 2 * math.pi)          # 0 -> 1 -> 0 around the ring: magenta -> cyan -> magenta
    hue = grad(around, [(0, MAGENTA), (0.5, '9a5cff'), (1, CYAN)])
    core = np.clip(np.cos((u - 0.5) * 2 * math.pi), 0, 1) ** 2   # the tube's inner face runs white-hot
    col[y0:y1, x0:x1] = hue * (1 - 0.6 * core[..., None]) + 0.6 * core[..., None]
    rgh[y0:y1, x0:x1] = 0.15
    glow[y0:y1, x0:x1] = np.clip(0.8 + 0.2 * core + 0.1 * rich, 0, 1)
    # tail
    _fill(col, rgh, glow, 'tail', hx(VIOLET), 0.3)
    # gold specks, spade (magenta glow), mouth, fang, ears, collar
    _fill(col, rgh, glow, 'gold', hx(GOLD_HI), 0.2, 1.0)
    y0, y1, x0, x1 = ATLAS.px('spade')
    h, w = y1 - y0, x1 - x0
    v = np.mgrid[0:h, 0:w][0].astype(np.float32) / h
    col[y0:y1, x0:x1] = grad(1 - v, [(0, 'b02080'), (0.6, MAGENTA), (1, 'ffc0e8')])
    rgh[y0:y1, x0:x1] = 0.2
    glow[y0:y1, x0:x1] = 0.6 + 0.4 * (1 - v)
    _fill(col, rgh, glow, 'mouth', hx('2a1030'), 0.4)
    _fill(col, rgh, glow, 'fang', hx('fffaf0'), 0.2)
    y0, y1, x0, x1 = ATLAS.px('ear')
    h, w = y1 - y0, x1 - x0
    v = np.mgrid[0:h, 0:w][0].astype(np.float32) / h
    col[y0:y1, x0:x1] = grad(1 - v, [(0, VIOLET), (0.7, VIOLET_HI), (1, 'c8a8ff')])
    rgh[y0:y1, x0:x1] = 0.3
    y0, y1, x0, x1 = ATLAS.px('collar')
    h, w = y1 - y0, x1 - x0
    v = np.mgrid[0:h, 0:w][0].astype(np.float32) / h
    trim = np.maximum(ss(0.22, 0.12, v), ss(0.78, 0.88, v))
    col[y0:y1, x0:x1] = hx('1e1636') * (1 - trim[..., None]) + hx(GOLD) * trim[..., None]
    rgh[y0:y1, x0:x1] = 0.3
    glow[y0:y1, x0:x1] = trim * 0.4
    paint_atlas._glow = np.clip(glow, 0, 1)
    return np.clip(col, 0, 1), hgt, rgh


def emissive_mask(level):
    paint_atlas(level)
    g = paint_atlas._glow
    return np.repeat(g[..., None], 3, -1)


LID_Y, LID_SLANT = 0.72, 0.9


def face_texture(level, size=512):
    """Big confident gold eyes: bright gold iris fading to amber at the rim, large dark pupil looking ahead, a big
    highlight upper-outer + a small one, a thin dark outline, and a short lid wedge at the top inner corner (sly)."""
    x, y = coords(size)
    r = np.sqrt(x * x + y * y)
    rgba = np.zeros((size, size, 4), np.float32)
    iris = grad(np.clip(r / 0.92, 0, 1), [(0, 'fff0a0'), (0.5, GOLD), (0.85, 'f0a020'), (1, 'c87010')])
    if level >= 2:
        iris = grad(np.clip(r / 0.92, 0, 1), [(0, 'fff6c0'), (0.5, 'ffd040'), (0.85, 'ff8a40'), (1, 'd04a80')])
    c = iris
    pupil = ss(0.5, 0.47, np.sqrt((x * 1.05) ** 2 + y ** 2))
    c = c * (1 - pupil[..., None]) + hx('120a1e') * pupil[..., None]
    for hx_, hy_, hr in ((0.2, 0.22, 0.17), (-0.17, -0.2, 0.07)):
        hl = ss(hr, hr * 0.75, np.sqrt((x - hx_) ** 2 + (y - hy_) ** 2))
        c = c * (1 - hl[..., None]) + hl[..., None]
    lid = ss(-0.02, 0.03, y - (LID_Y + LID_SLANT * x))
    c = c * (1 - lid[..., None]) + grad(np.clip(0.5 + y * 0.5, 0, 1), [(0, VIOLET_DK), (1, VIOLET)]) * lid[..., None]
    rim = ss(0.93, 0.955, r)
    c = c * (1 - rim[..., None]) + hx('0a1a22') * rim[..., None]
    rgba[..., :3] = c
    rgba[..., 3] = ss(1.0, 0.97, r)
    return rgba


# ---------------------------------------------------------------- animation (24 fps, in place, it floats)
def _spin(f, frames, turns=1.0):
    return 360.0 * turns * f / frames


def anim_idle():
    keys = {}
    for f in range(0, 49, 6):
        t = f / 48 * 2 * math.pi
        keys[f] = {'Body': P(loc=(0, 0, 0.05 * math.sin(t))),
                   'Head': P(('z', 6 * math.sin(t * 0.5)), ('x', -2 * math.sin(t))),
                   'Ring': P(('y', _spin(f, 48)), loc=(0, 0, 0.04 * math.sin(t + 1.2))),
                   'Tail1': P(('z', 10 * math.sin(t))), 'Tail2': P(('z', 12 * math.sin(t - 0.6))),
                   'Leg.L': P(('x', -6 * math.sin(t))), 'Leg.R': P(('x', 6 * math.sin(t)))}
    keys[48] = dict(keys[0])
    keys[48]['Ring'] = P(('y', 0), loc=(0, 0, 0.04 * math.sin(1.2)))
    return {'frames': 48, 'loop': True, 'keys': keys}


def _move(frames, lean, swing, flap):
    keys = {}
    for f in range(0, frames + 1, 2):
        t = f / frames * 2 * math.pi
        keys[f] = {'Body': P(('x', lean), loc=(0, 0, 0.04 * math.sin(2 * t))),
                   'Head': P(('x', -lean * 0.6)),
                   'ArmU.L': P(('x', -swing * math.sin(t))), 'ArmU.R': P(('x', swing * math.sin(t))),
                   'Leg.L': P(('x', swing * 0.8 * math.sin(t) + lean * 0.8)), 'Leg.R': P(('x', -swing * 0.8 * math.sin(t) + lean * 0.8)),
                   'Tail1': P(('x', -lean * 0.8), ('z', 10 * math.sin(t))),
                   'Ring': P(('y', _spin(f, frames)), loc=(0, 0, 0.03 * math.sin(t)))}
    keys[frames] = dict(keys[0])
    keys[frames]['Ring'] = P(('y', 0), loc=(0, 0, 0))
    return {'frames': frames, 'loop': True, 'keys': keys}


def anim_walk():
    return _move(24, 10, 18, 18)


def anim_run():
    return _move(16, 22, 26, 30)


def anim_hop():
    keys = {}
    for f in range(0, 17, 2):
        upv = math.sin(math.pi * f / 16)
        keys[f] = {'Body': P(('x', -6 * upv), loc=(0, 0, 0.3 * upv)),
                   'ArmU.L': P(('y', -30 * upv)), 'ArmU.R': P(('y', 30 * upv)),
                   'Leg.L': P(('x', 20 * upv)), 'Leg.R': P(('x', 20 * upv))}
    return {'frames': 16, 'loop': False, 'keys': keys}


def anim_ability():
    """It swings the ring in front of itself, spins it, and steps through it (Portal Relocation / Blink)."""
    keys = {}
    F = 24
    for f in range(0, F + 1, 2):
        t = f / F
        bring = smooth(min(1.0, t / 0.3)) * (1 - smooth(max(0.0, (t - 0.8) / 0.2)))     # ring swings to the front
        step = math.sin(math.pi * min(1.0, max(0.0, (t - 0.35) / 0.45)))                 # leans in and through
        keys[f] = {'Ring': P(('y', 720 * t * bring / max(bring, 1e-3) if bring > 0 else 0),
                             loc=(-0.74 * bring, -0.32 * bring, 0.32 * bring)),
                   'ArmU.L': P(('y', -50 * bring), ('x', -30 * bring)),
                   'ArmU.R': P(('y', 30 * bring)),
                   'Body': P(('x', 18 * step), loc=(0, -0.3 * step, 0.06 * step)),
                   'Head': P(('x', -8 * step))}
    return {'frames': F, 'loop': False, 'keys': keys}


ANIMS = {'Idle': anim_idle, 'Walk': anim_walk, 'Run': anim_run, 'Hop': anim_hop, 'Ability': anim_ability}
