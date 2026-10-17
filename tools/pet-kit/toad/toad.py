# Thunder Toad (Tempest, Common) for Hatch or Snatch: HOS-PET-016, remade 17 Oct (HOS-PET-REDO, Hunter: "thunder
# toad needs to either be remade or removed" -> "Both": remake). Shape from Hunter's Tempest card
# (docs/pets/concepts/thunder_toad_hunter_reference_2.png): a squat, wide toad with a cream throat and belly, back
# spikes, a bolt crest and glowing toe pads. Read through PET_LESSONS (anime / edgy, not cute) and given its own palette
# (the card's cobalt / yellow belongs to the Riot Hound now): a deep bottle-green storm toad mottled near-black, electric
# lime lightning markings, spines and toe pads that glow, raised eye turrets over narrow slanted lime slit eyes, a sly
# flat mouth with one fang, glowing storm glands behind the eyes. Big folded frog hind legs, splayed front legs.
# L2 "Storm Croaker": shoulder bolt spikes, a taller crest, lightning cheek bolts, glowing gland rows on the back.
# L3 "Thunder King": a crown of lightning bolts, bigger back spines, bolt bracers, white-hot lime glow and eyes.
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

NAME = 'Toad'
SHARP_ANGLE = 40
NORMAL_STRENGTH = 2.2
TS = 1024
ATLAS = Atlas({
    'skin': (0, 0, 1024, 384),      # body + head loft: u around (0 = top seam, 0.5 = belly), v rear -> snout
    'jaw': (0, 384, 512, 256),      # jaw / throat sac: u around, v back -> front
    'limb': (512, 384, 512, 128),   # legs: v hip / shoulder -> foot
    'foot': (512, 512, 512, 128),   # toe pads
    'bolt': (0, 640, 256, 128),     # lightning spines: v root -> tip
    'node': (256, 640, 256, 128),   # storm glands, eye turrets
    'wart': (512, 640, 128, 128),
    'claw': (640, 640, 128, 128),
    'bolt3': (768, 640, 256, 128),  # L2 / L3 bolts (palette per level)
})

BOLT = {1: ('5a9a00', 'c8ff3a', 'f4ffd0'), 2: ('6aae00', 'd8ff50', 'f8ffe0'), 3: ('8ad000', 'eeff90', 'ffffff')}
EYE = {1: ('6a9a00', 'd0ff40', 'f8ffd8'), 2: ('7aae00', 'e0ff60', 'fcffe8'), 3: ('a0d020', 'f6ffb0', 'ffffff')}


# ---------------------------------------------------------------- skeleton
def bones_def():
    b = [
        ('Root', V(0, 0, 0), V(0, 0, 0.2), None),
        ('Body', V(0, 0.4, 0.34), V(0, -0.12, 0.42), 'Root'),
        ('Head', V(0, -0.14, 0.46), V(0, -0.72, 0.44), 'Body'),
        ('Jaw', V(0, -0.18, 0.3), V(0, -0.66, 0.28), 'Head'),
        ('Throat', V(0, -0.32, 0.22), V(0, -0.46, 0.12), 'Jaw'),
    ]
    for s, x in (('L', 1), ('R', -1)):
        b += [
            ('ArmU.' + s, V(x * 0.3, -0.3, 0.32), V(x * 0.42, -0.42, 0.14), 'Body'),
            ('ArmL.' + s, V(x * 0.42, -0.42, 0.14), V(x * 0.46, -0.52, 0.03), 'ArmU.' + s),
            ('LegU.' + s, V(x * 0.3, 0.32, 0.32), V(x * 0.58, 0.06, 0.22), 'Body'),
            ('LegL.' + s, V(x * 0.58, 0.06, 0.22), V(x * 0.54, 0.4, 0.08), 'LegU.' + s),
            ('Foot.' + s, V(x * 0.54, 0.4, 0.08), V(x * 0.6, 0.08, 0.03), 'LegL.' + s),
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


def spike(mb, region, base, tip, w, width, part, side=None, up=None, wide_at=0.3, flat=0.45, curl=0.0):
    """A flattened blade (spine / bolt / claw), root buried in the part it grows from."""
    d = nrm(np.asarray(tip, float) - np.asarray(base, float))
    side = side if side is not None else (V(1, 0, 0) if abs(d[0]) < 0.8 else V(0, 1, 0))
    up = up if up is not None else nrm(np.cross(d, side))
    bipyramid(mb, base, tip, side, up, width, width * flat, w, ATLAS.uv(region, 0.5, 0.05), ATLAS.uv(region, 0.5, 0.95),
              part, wide_at=wide_at, ridge_at=wide_at, curl=curl)


def bolt(mb, region, base, mid, tip, w, width, part, side=None):
    """A zig-zag lightning bolt: two kinked blades."""
    spike(mb, region, base, mid, w, width, part, side=side, wide_at=0.5, flat=0.35)
    spike(mb, region, mid - (mid - base) * 0.25, tip, w, width * 0.8, part, side=side, wide_at=0.3, flat=0.35)


def lump(mb, region, c, r, w, part, n=8, squash=0.7):
    """A small domed lump (wart / gland / eye turret): a short closed tube."""
    c = np.asarray(c, float)
    tube(mb, region, [c - V(0, 0, r * squash * 0.6), c, c + V(0, 0, r * squash * 0.5)],
         [(r * 0.8, r * 0.8), (r, r), (r * 0.55, r * 0.55)], n, [w] * 3, part, start='point', end='point',
         start_pt=c - V(0, 0, r * squash), end_pt=c + V(0, 0, r * squash), side_hint=V(0, 1, 0))


def dome(mb, region, c, r, w, part, normal=V(0, 0, 1)):
    """a cheap wart / pad: an 8-tri bipyramid rising out of the surface along normal."""
    n = nrm(np.asarray(normal, float))
    side = nrm(np.cross(n, V(0, 1, 0))) if abs(n[1]) < 0.9 else V(1, 0, 0)
    c = np.asarray(c, float)
    bipyramid(mb, c - n * r * 0.5, c + n * r * 0.8, side, np.cross(n, side), r * 2.0, r * 1.8, w,
              ATLAS.uv(region, 0.5, 0.1), ATLAS.uv(region, 0.5, 0.9), part, wide_at=0.45, ridge_at=0.45)


FX, FZ, FZH = 0.46, 0.5, 0.26
SHELL = (-0.5, 0.33, 0.76)            # face shell: head faces with y < SHELL[0] and SHELL[1] < z < SHELL[2]


def _vnormals(mb, faces):
    acc = {}
    for fi in faces:
        f = mb.F[fi]
        a, b, c = mb.V[f[0]], mb.V[f[1]], mb.V[f[2]]
        n = np.cross(b - a, c - a)
        for v in f:
            acc[v] = acc.get(v, np.zeros(3)) + n
    return {v: nrm(n) for v, n in acc.items()}


def face_shell(mb, head_faces, lift=0.009):
    sel = [fi for fi in head_faces if all(mb.V[v][1] < SHELL[0] and SHELL[1] < mb.V[v][2] < SHELL[2] for v in mb.F[fi])]
    vn = _vnormals(mb, head_faces)
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
    W_B, W_H, W_J, W_T = {'Body': 1}, {'Head': 1}, {'Jaw': 1}, {'Throat': 1}
    # one squat loft: a round rump, a broad body, a wide flat head (no neck), a blunt snout
    st = [(V(0, 0.46, 0.33), (0.36, 0.26), W_B),
          (V(0, 0.26, 0.37), (0.46, 0.32), W_B),
          (V(0, 0.02, 0.4), (0.48, 0.33), {'Body': 0.6, 'Head': 0.4}),
          (V(0, -0.2, 0.45), (0.46, 0.31), {'Body': 0.2, 'Head': 0.8}),
          (V(0, -0.4, 0.46), (0.42, 0.27), W_H),
          (V(0, -0.56, 0.43), (0.34, 0.2), W_H),
          (V(0, -0.66, 0.4), (0.22, 0.12), W_H)]
    n0 = len(mb.F)
    tube(mb, 'skin', [s[0] for s in st], [s[1] for s in st], 16, [s[2] for s in st], 'body',
         start='point', end='point', start_pt=V(0, 0.58, 0.31), end_pt=V(0, -0.72, 0.38), side_hint=V(1, 0, 0),
         th0=math.pi / 2)
    head_faces = list(range(n0, len(mb.F)))
    # jaw and the cream throat sac hanging under the head
    js = [(V(0, -0.12, 0.24), (0.36, 0.12), {'Jaw': 0.5, 'Body': 0.5}), (V(0, -0.32, 0.22), (0.38, 0.15), W_T),
          (V(0, -0.5, 0.26), (0.3, 0.1), W_J), (V(0, -0.62, 0.3), (0.18, 0.06), W_J)]
    tube(mb, 'jaw', [j[0] for j in js], [j[1] for j in js], 12, [j[2] for j in js], 'jaw', start='point', end='point',
         start_pt=V(0, 0.0, 0.26), end_pt=V(0, -0.68, 0.32), side_hint=V(1, 0, 0), th0=math.pi / 2)
    for s, x in (('L', 1), ('R', -1)):
        # raised eye turrets and glowing storm glands behind them
        lump(mb, 'node', V(x * 0.21, -0.42, 0.66), 0.11, W_H, 'eyeb', n=10, squash=0.75)
        lump(mb, 'node', V(x * 0.3, -0.18, 0.66), 0.1, W_H, 'gland', n=6, squash=0.6)
        # splayed front legs, three claws and glowing pads
        au, al = 'ArmU.' + s, 'ArmL.' + s
        arm = [(V(x * 0.28, -0.3, 0.34), (0.13, 0.13), {'Body': 0.5, au: 0.5}), (V(x * 0.38, -0.38, 0.22), (0.1, 0.1), {au: 1}),
               (V(x * 0.42, -0.43, 0.13), (0.08, 0.08), {au: 0.5, al: 0.5}), (V(x * 0.45, -0.5, 0.05), (0.11, 0.055), {al: 1})]
        tube(mb, 'limb', [a[0] for a in arm], [a[1] for a in arm], 8, [a[2] for a in arm], 'arm' + s, start='point',
             end='point', start_pt=V(x * 0.2, -0.26, 0.38), end_pt=V(x * 0.46, -0.56, 0.03))
        for k in (-1, 0, 1):
            d = nrm(V(x * 0.25 + k * 0.45, -1, -0.2))
            b0 = V(x * 0.46, -0.5, 0.035) + V(k * 0.05, 0, 0)
            dome(mb, 'foot', b0 + d * 0.07, 0.035, {al: 1}, 'pad')
            spike(mb, 'claw', b0, b0 + d * 0.15, {al: 1}, 0.035, 'claw', side=V(1, 0, 0), up=V(0, 0, 1))
        # big folded frog hind legs: thigh out and forward, shin folded back, long foot forward
        lu, ll, lf = 'LegU.' + s, 'LegL.' + s, 'Foot.' + s
        leg = [(V(x * 0.3, 0.32, 0.34), (0.2, 0.18), {'Body': 0.5, lu: 0.5}), (V(x * 0.46, 0.18, 0.29), (0.17, 0.15), {lu: 1}),
               (V(x * 0.58, 0.06, 0.22), (0.11, 0.11), {lu: 0.5, ll: 0.5}), (V(x * 0.57, 0.24, 0.15), (0.09, 0.09), {ll: 1}),
               (V(x * 0.54, 0.4, 0.08), (0.07, 0.07), {ll: 0.5, lf: 0.5})]
        tube(mb, 'limb', [a[0] for a in leg], [a[1] for a in leg], 8, [a[2] for a in leg], 'leg' + s, start='point',
             end='point', start_pt=V(x * 0.2, 0.36, 0.38), end_pt=V(x * 0.54, 0.46, 0.06))
        tube(mb, 'limb', [V(x * 0.54, 0.4, 0.06), V(x * 0.57, 0.26, 0.04), V(x * 0.6, 0.12, 0.03)],
             [(0.07, 0.04), (0.08, 0.035), (0.09, 0.03)], 8, [{lf: 1}] * 3, 'foot' + s, start='point', end='point',
             start_pt=V(x * 0.54, 0.46, 0.06), end_pt=V(x * 0.61, 0.06, 0.03))
        for k in (-1, 0, 1):
            d = nrm(V(x * 0.2 + k * 0.5, -1, -0.1))
            b0 = V(x * 0.6, 0.1, 0.03)
            dome(mb, 'foot', b0 + d * 0.09, 0.04, {lf: 1}, 'pad')
            spike(mb, 'claw', b0, b0 + d * 0.18, {lf: 1}, 0.04, 'claw', side=V(1, 0, 0), up=V(0, 0, 1))
    # warts over the back and head (near-black, a few glowing)
    rng = np.random.default_rng(16)
    for k in range(16):
        y = 0.45 - 0.75 * rng.random()
        a = math.radians(-70 + 140 * rng.random())
        rx = 0.44 if y > -0.1 else 0.4
        p = V(math.sin(a) * rx * 0.86, y, 0.38 + math.cos(a) * 0.3 * 0.9)
        dome(mb, 'wart', p, 0.035 + 0.02 * rng.random(), W_B if y > -0.05 else W_H, 'wart', normal=V(math.sin(a), 0, math.cos(a)))
    # lightning spines down the back and a swept bolt crest behind the head
    for (y, h, w) in ((-0.06, 0.24, 0.13), (0.12, 0.22, 0.12), (0.28, 0.18, 0.11), (0.42, 0.13, 0.09)):
        zt = 0.4 + 0.32
        bolt(mb, 'bolt', V(0, y, zt - 0.06), V(0, y + 0.08, zt + h * 0.6), V(0, y + 0.16, zt + h * 1.15), W_B, w * 1.4,
             'bolt', side=V(0, 1, 0))
    bolt(mb, 'bolt', V(0, -0.22, 0.72), V(0, -0.12, 0.92), V(0, 0.02, 1.02), W_H, 0.2, 'bolt', side=V(0, 1, 0))
    for x in (1, -1):
        spike(mb, 'bolt', V(x * 0.1, -0.24, 0.72), V(x * 0.22, -0.1, 0.88), W_H, 0.12, 'bolt')
    # ---- face decal shell (mat 1)
    mb.mat = 1
    face_shell(mb, head_faces)
    # ---- level 2 (mat 2) "Storm Croaker": shoulder bolt spikes, taller crest, lightning cheek bolts, gland rows
    mb.mat = 2
    for x in (1, -1):
        bolt(mb, 'bolt3', V(x * 0.34, -0.22, 0.58), V(x * 0.48, -0.16, 0.74), V(x * 0.56, -0.06, 0.9), W_B, 0.12, 'L2')
        bolt(mb, 'bolt3', V(x * 0.4, -0.46, 0.4), V(x * 0.56, -0.42, 0.44), V(x * 0.64, -0.36, 0.36), W_H, 0.09, 'L2')
        for y in (0.04, 0.22, 0.38):
            dome(mb, 'node', V(x * 0.2, y, 0.68 - 0.08 * y), 0.05, W_B, 'L2', normal=V(x * 0.4, 0, 1))
    bolt(mb, 'bolt3', V(0, -0.18, 0.86), V(0, -0.08, 1.08), V(0, 0.06, 1.2), W_H, 0.16, 'L2', side=V(0, 1, 0))
    # ---- level 3 (mat 3) "Thunder King": a crown of lightning, bigger back spines, bolt bracers
    mb.mat = 3
    for k in range(5):
        a = math.radians(-60 + 30 * k)
        b0 = V(math.sin(a) * 0.16, -0.36, 0.68 + math.cos(a) * 0.03)
        d = V(math.sin(a) * 0.5, 0.1, 1)
        bolt(mb, 'bolt3', b0, b0 + nrm(d) * 0.14 + V(0.03, 0, 0), b0 + nrm(d) * 0.3, W_H, 0.08, 'L3', side=V(0, 1, 0))
    for (y, h, w) in ((0.03, 0.34, 0.15), (0.2, 0.3, 0.14), (0.35, 0.24, 0.12)):
        for x in (0.14, -0.14):
            bolt(mb, 'bolt3', V(x, y, 0.66), V(x * 1.4, y + 0.08, 0.66 + h * 0.6), V(x * 1.8, y + 0.16, 0.66 + h * 1.1),
                 W_B, w, 'L3', side=V(0, 1, 0))
    for s, x in (('L', 1), ('R', -1)):
        c = V(x * 0.42, -0.43, 0.13)
        ring = [c + V(math.cos(2 * math.pi * i / 8) * 0.095, math.sin(2 * math.pi * i / 8) * 0.095, 0) for i in range(9)]
        tube(mb, 'bolt3', ring, [(0.025, 0.035)] * 9, 4, [{'ArmL.' + s: 1}] * 9, 'L3', start='open', end='open',
             side_hint=V(0, 0, 1), anti=False)
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


def _reg(name):
    y0, y1, x0, x1 = ATLAS.px(name)
    h, w = y1 - y0, x1 - x0
    v, u = np.mgrid[0:h, 0:w].astype(np.float32)
    return (y0, y1, x0, x1), v / h, u / w


def _green(level):
    if level == 3:
        return [(0, '06120a'), (0.5, '17442a'), (1, '3a8a50')]
    return [(0, '081a0e'), (0.5, '1e5a34'), (1, '4aa060')]


BELLY = [(0, 'cfc488'), (0.6, 'eee4b0'), (1, 'f8f2d0')]


def paint_atlas(level):
    col = np.zeros((TS, TS, 3), np.float32)
    hgt = np.full((TS, TS), 0.5, np.float32)
    rgh = np.full((TS, TS), 0.5, np.float32)
    glow = np.zeros((TS, TS), np.float32)
    gr_ = _green(level)
    bd, bm, bh = BOLT[level]
    # ---- skin: deep green, near-black mottling over the back, a cream belly with a jagged edge, glowing lime
    # lightning-crack markings down the flanks, bumpy grain
    (y0, y1, x0, x1), v, u = _reg('skin')
    h, w = y1 - y0, x1 - x0
    top = np.cos(u * 2 * math.pi)
    c = grad(np.clip(0.5 + 0.4 * top, 0, 1), gr_)
    mott = ss(0.55, 0.7, vnoise(h, w, 34, 161)) * ss(-0.3, 0.3, top)
    c = c * (1 - 0.75 * mott[..., None]) + hx('040a06') * (0.75 * mott[..., None])
    belly = ss(-0.35, -0.6, top + 0.1 * _saw(v * 18 + u * 4)) * ss(0.05, 0.12, v)
    c = c * (1 - belly[..., None]) + grad(np.clip(v, 0, 1), BELLY) * belly[..., None]
    zz = 0.2 + 0.05 * _saw(v * 7 + 0.3)
    crack = ss(0.016, 0.0, np.abs(np.abs(u - 0.5) - zz) - 0.008) * ss(0.12, 0.22, v) * ss(0.78, 0.68, v)
    zz2 = 0.04 + 0.03 * _saw(v * 9)
    crack2 = ss(0.012, 0.0, np.abs(np.minimum(u, 1 - u) - zz2) - 0.006) * ss(0.2, 0.3, v) * ss(0.6, 0.5, v)
    cr = np.clip(crack + crack2, 0, 1)
    c = c * (1 - cr[..., None]) + hx(bm) * cr[..., None]
    st = _streaks(h, w, 120, 162)
    gr = _pgrain(h, w, 163)
    col[y0:y1, x0:x1] = c * (1 + 0.18 * st[..., None] + 0.08 * gr[..., None])
    hgt[y0:y1, x0:x1] = 0.5 + 0.25 * st + 0.25 * gr
    rgh[y0:y1, x0:x1] = 0.32 + 0.25 * belly          # wet, glossy skin; matte belly
    glow[y0:y1, x0:x1] = cr * (0.8 if level == 1 else 1.0)
    # ---- jaw / throat: cream sac with fine throat folds, green sides
    (y0, y1, x0, x1), v, u = _reg('jaw')
    h, w = y1 - y0, x1 - x0
    top = np.cos(u * 2 * math.pi)
    folds = 0.5 + 0.5 * np.cos(v * 2 * math.pi * 9)
    sac = ss(0.3, -0.1, top)
    c = grad(np.clip(0.4 + 0.5 * top, 0, 1), gr_) * (1 - sac[..., None]) + grad(np.clip(0.6 + 0.3 * folds, 0, 1), BELLY) * sac[..., None]
    lip = ss(0.75, 0.9, top)
    c = c * (1 - lip[..., None]) + hx('050806') * lip[..., None]
    col[y0:y1, x0:x1] = c
    hgt[y0:y1, x0:x1] = 0.5 - 0.2 * folds * sac
    rgh[y0:y1, x0:x1] = 0.55
    # ---- legs: green with bands, dark undersides, lime zig-zag stripe
    (y0, y1, x0, x1), v, u = _reg('limb')
    h, w = y1 - y0, x1 - x0
    top = np.cos(u * 2 * math.pi)
    c = grad(np.clip(0.55 + 0.35 * top, 0, 1), gr_)
    band = ss(0.03, 0.0, np.abs(_saw(v * 4) - 0.5) - 0.38) * ss(0.0, 0.4, top)
    c = c * (1 - 0.8 * band[..., None]) + hx('040a06') * (0.8 * band[..., None])
    zig = ss(0.02, 0.0, np.abs(u - (0.25 + 0.04 * _saw(v * 10))) - 0.01) * ss(0.1, 0.2, v) * ss(0.9, 0.8, v)
    c = c * (1 - zig[..., None]) + hx(bm) * zig[..., None]
    st = _streaks(h, w, 60, 164)
    col[y0:y1, x0:x1] = c * (1 + 0.2 * st[..., None])
    hgt[y0:y1, x0:x1] = 0.5 + 0.3 * st
    rgh[y0:y1, x0:x1] = 0.35
    glow[y0:y1, x0:x1] = zig * 0.8
    # ---- toe pads: glowing lime
    (y0, y1, x0, x1), v, u = _reg('foot')
    col[y0:y1, x0:x1] = grad(np.clip(v, 0, 1), [(0, bd), (0.5, bm), (1, bh)])
    rgh[y0:y1, x0:x1] = 0.3
    glow[y0:y1, x0:x1] = 0.6 + 0.4 * v
    # ---- lightning spines: deep lime root, white-hot tip, glowing
    for reg, lv in (('bolt', 1 if level < 3 else 2), ('bolt3', level)):
        (y0, y1, x0, x1), v, u = _reg(reg)
        d_, m_, h_ = BOLT[lv]
        col[y0:y1, x0:x1] = grad(v, [(0, '0a1a08'), (0.18, d_), (0.5, m_), (0.88, h_), (1, 'ffffff')])
        rgh[y0:y1, x0:x1] = 0.2
        glow[y0:y1, x0:x1] = ss(0.15, 0.4, v) * (0.55 + 0.45 * v)
    # ---- storm glands / eye turrets: green domes with a glowing lime core ring
    (y0, y1, x0, x1), v, u = _reg('node')
    core = ss(0.35, 0.5, v) * ss(0.95, 0.8, v)
    c = grad(np.clip(v, 0, 1), gr_)
    ringc = ss(0.03, 0.0, np.abs(v - 0.62) - 0.04)
    c = c * (1 - ringc[..., None]) + hx(bm) * ringc[..., None]
    col[y0:y1, x0:x1] = c
    glow[y0:y1, x0:x1] = ringc
    # ---- warts: near-black with a faint green rim
    (y0, y1, x0, x1), v, u = _reg('wart')
    col[y0:y1, x0:x1] = grad(np.clip(v, 0, 1), [(0, '1e5a34'), (0.5, '0a1a0e'), (1, '040806')])
    hgt[y0:y1, x0:x1] = 0.5 + 0.4 * ss(0.2, 0.7, v)
    # ---- claws: black, lime tips at L2+
    (y0, y1, x0, x1), v, u = _reg('claw')
    t = ss(0.55, 0.9, v) * (1.0 if level >= 2 else 0.0)
    col[y0:y1, x0:x1] = hx('060806') * (1 - t[..., None]) + hx(bm) * t[..., None]
    glow[y0:y1, x0:x1] = t
    paint_atlas._glow = np.clip(glow, 0, 1)
    return np.clip(col, 0, 1), hgt, rgh


def emissive_mask(level):
    paint_atlas(level)
    return np.repeat(paint_atlas._glow[..., None], 3, -1)


# ---------------------------------------------------------------- face decal (drawn in world units: X across, Z up)
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
    # narrow eyes slanting down toward the nose, under the turrets
    ix, iz, ox, oz = 0.08, 0.49, 0.3, 0.555
    ex, ez = ox - ix, oz - iz
    L = math.hypot(ex, ez)
    s = ((aX - ix) * ex + (Z - iz) * ez) / (L * L)
    d = (-(aX - ix) * ez + (Z - iz) * ex) / L
    sc = np.clip(s, 0, 1)
    top = 0.042 * np.clip(sc * 3.0, 0, 1) * (1 - sc ** 4) + 0.002
    bot = -0.028 * np.clip(np.sin(math.pi * sc), 0, 1) ** 0.9 - 0.001
    eye = ss(0.003, 0.0, np.maximum(d - top, bot - d)) * (s > 0) * (s < 1)
    cxs, czs = ix + 0.5 * ex, iz + 0.5 * ez
    rr = np.sqrt((aX - cxs) ** 2 + (Z - czs) ** 2)
    _face_layers.rr = rr
    iris = ss(0.06, 0.055, rr)
    slit = ss(0.006 * np.clip(1 - ((Z - czs) / 0.035) ** 2, 0, 1) + 0.0005, 0.0, np.abs(aX - cxs)) * ss(0.036, 0.032, rr)
    brow = np.maximum(_seg(aX, Z, (0.05, 0.545), (0.31, 0.63), 0.018, 0.006), _seg(aX, Z, (0.29, 0.625), (0.38, 0.665), 0.01, 0.002))
    lid = ss(0.006, 0.003, np.abs(d - top - 0.003)) * (s > -0.05) * (s < 1.02)
    # a dark storm mask band through the eyes
    zc = 0.515 + 0.07 * aX
    hh = 0.038 * np.clip(1 - (aX / 0.4) ** 2, 0, 1) + 0.004
    mask = ss(0.004, 0.0, np.abs(Z - zc) - hh) * (aX < 0.4)
    # lime lightning marks under the eyes (L2 adds a forehead bolt, L3 cheek forks)
    mark = np.maximum(_seg(aX, Z, (0.24, 0.47), (0.3, 0.41), 0.011, 0.003), _seg(aX, Z, (0.3, 0.41), (0.27, 0.37), 0.009, 0.002))
    if level >= 2:
        mark = np.maximum(mark, np.maximum(_seg(aX, Z, (0.0, 0.7), (0.035, 0.76), 0.012, 0.004), _seg(aX, Z, (0.035, 0.76), (0.0, 0.8), 0.01, 0.003)))
    if level >= 3:
        mark = np.maximum(mark, _seg(aX, Z, (0.35, 0.47), (0.41, 0.4), 0.008, 0.002))
    # a wide, sly flat mouth along the jaw seam (one-sided smirk) and one small fang; two nostril slits
    mouth = np.maximum(_seg(X, Z, (-0.34, 0.36), (0.25, 0.355), 0.006, 0.006), _seg(X, Z, (0.25, 0.355), (0.36, 0.385), 0.006, 0.002))
    fang = ss(0.08, 0.0, np.abs(X - 0.17) / 0.014 + (0.355 - Z) / 0.04 - 1) * (Z < 0.355) * (Z > 0.31)
    nose = np.maximum(_seg(X, Z, (0.035, 0.43), (0.055, 0.42), 0.006, 0.003), _seg(X, Z, (-0.035, 0.43), (-0.055, 0.42), 0.006, 0.003))
    return X, Z, eye, iris, slit, brow, lid, mask, mark, mouth, fang, nose


def face_texture(level, size=512):
    X, Z, eye, iris, slit, brow, lid, mask, mark, mouth, fang, nose = _face_layers(level, size)
    rr = _face_layers.rr
    ed, em, eh = EYE[level]
    bd, bm, bh = BOLT[level]
    rgba = np.zeros((size, size, 4), np.float32)
    c = np.zeros((size, size, 3), np.float32) + hx('030805')
    c = c * (1 - mark[..., None]) + hx(bm) * mark[..., None]
    irisc = grad(np.clip(1 - rr / 0.046, 0, 1), [(0, ed), (0.45, em), (1, eh)])
    e = hx('060a06') * (1 - iris[..., None]) + irisc * iris[..., None]
    e = e * (1 - slit[..., None]) + hx('010201') * slit[..., None]
    c = c * (1 - eye[..., None]) + e * eye[..., None]
    ln = np.maximum.reduce([lid, brow, mouth, nose])
    c = c * (1 - ln[..., None]) + hx('020402') * ln[..., None]
    c = c * (1 - fang[..., None]) + hx('f4f6ea') * fang[..., None]
    rgba[..., :3] = c
    rgba[..., 3] = np.clip(np.maximum.reduce([mask * 0.7, eye, ln, mark, fang]), 0, 1)
    return rgba


def face_emissive(level, size=512):
    X, Z, eye, iris, slit, brow, lid, mask, mark, mouth, fang, nose = _face_layers(level, size)
    g = np.clip(np.maximum(iris * eye * (1 - slit), mark * 0.9), 0, 1)
    return np.repeat(g[..., None], 3, -1)


# ---------------------------------------------------------------- animation (24 fps, in place)
# A coiled storm toad: slow breathing, a throat pulse, a crackling shudder, a tongue-flick snap. Walks in a heavy crawl,
# runs in springing hops. Ability (both roles' summon): rears back and balloons its throat in a croak, then slams down.
def _ease(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def _pulse(t, a, b):
    if t <= a or t >= b:
        return 0.0
    return math.sin(math.pi * (t - a) / (b - a))


def _legs(sw_f, sw_b, fold):
    """front arms swing by sw_f (per side), hind legs fold by fold (0 = tucked, 1 = kicked out)."""
    p = {}
    for s, sg in (('L', 1), ('R', -1)):
        p['ArmU.' + s] = P(('x', -sw_f[s]))
        p['ArmL.' + s] = P(('x', sw_f[s] * 0.6))
        k = fold[s]
        p['LegU.' + s] = P(('x', 40 * k), ('z', sg * 12 * k))
        p['LegL.' + s] = P(('x', -70 * k))
        p['Foot.' + s] = P(('x', 35 * k))
    return p


def anim_idle():
    F = 72
    keys = {}
    for f in range(0, F + 1, 3):
        t = f / F
        w = 2 * math.pi * t
        puff = _pulse(t, 0.15, 0.32) + 0.6 * _pulse(t, 0.6, 0.72)
        shud = _pulse(t, 0.42, 0.52) * math.sin(w * 24)
        k = {'Body': P(('x', 1.5 * math.sin(w)), ('y', 3 * shud), loc=(0, 0, 0.015 * math.sin(2 * w))),
             'Head': P(('z', 8 * math.sin(w * 0.5)), ('x', -3 * puff + 4 * shud)),
             'Jaw': P(('x', 4 * _pulse(t, 0.8, 0.88))), 'Throat': P(loc=(0, -0.03 * puff, -0.07 * puff))}
        k.update(_legs({'L': 3 * math.sin(w), 'R': -3 * math.sin(w)}, None, {'L': 0.0, 'R': 0.0}))
        keys[f] = k
    keys[F] = dict(keys[0])
    return {'frames': F, 'loop': True, 'keys': keys}


def _crawl(frames, swing, hop, pitch):
    """hop 0: a heavy crawl (front arms alternate, hind legs push in turn); hop 1: springing bounds."""
    keys = {}
    for f in range(0, frames + 1, 2):
        t = f / frames
        w = 2 * math.pi * t
        air = max(0.0, math.sin(w)) * hop
        k = {'Body': P(('x', pitch - 12 * air + 4 * math.sin(2 * w) * (1 - hop)),
                       loc=(0, 0, 0.03 * abs(math.sin(w)) * (1 - hop) + 0.32 * air)),
             'Head': P(('x', -pitch * 0.5 + 6 * air)), 'Throat': P(loc=(0, 0, -0.02 * abs(math.sin(2 * w))))}
        if hop:
            kick = max(0.0, math.sin(w + 0.4))
            k.update(_legs({'L': -swing * air + 10, 'R': -swing * air + 10}, None, {'L': kick, 'R': kick}))
        else:
            k.update(_legs({'L': swing * math.sin(w), 'R': -swing * math.sin(w)}, None,
                           {'L': 0.5 * max(0.0, math.sin(w + math.pi)), 'R': 0.5 * max(0.0, math.sin(w))}))
        keys[f] = k
    keys[frames] = dict(keys[0])
    return {'frames': frames, 'loop': True, 'keys': keys}


def anim_walk():
    return _crawl(24, 26, 0, 2)


def anim_run():
    return _crawl(14, 30, 1, 4)


def anim_hop():
    keys = {}
    for f in range(0, 17, 2):
        t = f / 16
        upv = math.sin(math.pi * t)
        k = {'Body': P(('x', -12 * upv), loc=(0, 0, 0.4 * upv))}
        k.update(_legs({'L': -30 * upv, 'R': -30 * upv}, None, {'L': upv, 'R': upv}))
        keys[f] = k
    return {'frames': 16, 'loop': False, 'keys': keys}


def anim_ability():
    """The croak (~1 s): sinks, rears back with the jaw open and the throat sac ballooning (the flash at ~0.45),
    then slams both front feet down."""
    keys = {}
    F = 24
    for f in range(0, F + 1, 2):
        t = f / F
        sink = _ease(t / 0.2) * (1 - _ease((t - 0.2) / 0.1))
        rear = _ease((t - 0.2) / 0.2) * (1 - _ease((t - 0.6) / 0.12))
        slam = _ease((t - 0.6) / 0.08) * (1 - _ease((t - 0.8) / 0.2))
        k = {'Body': P(('x', -18 * rear + 6 * slam), loc=(0, 0.04 * rear, -0.05 * sink + 0.1 * rear - 0.04 * slam)),
             'Head': P(('x', -14 * rear + 8 * slam)), 'Jaw': P(('x', 30 * rear)),
             'Throat': P(loc=(0, -0.06 * rear, -0.12 * rear))}
        k.update(_legs({'L': -30 * rear + 25 * slam, 'R': -30 * rear + 25 * slam}, None,
                       {'L': 0.3 * sink, 'R': 0.3 * sink}))
        keys[f] = k
    return {'frames': F, 'loop': False, 'keys': keys}


ANIMS = {'Idle': anim_idle, 'Walk': anim_walk, 'Run': anim_run, 'Hop': anim_hop, 'Ability': anim_ability}
