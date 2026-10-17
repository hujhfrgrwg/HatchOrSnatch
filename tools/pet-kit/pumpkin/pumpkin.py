# Pumpkin Wraith rework (Invisibility, Legendary, Halloween) for Hatch or Snatch: HOS-HWN-001 pass 3.
# Hunter, 17 Oct 15:40: "I feel like the jacko wraith would look better as just a pumpkin or something." So the cloak and
# hood are gone: a floating, carved, scorched jack-o'-lantern with an ember glow inside, a thick curled stem with two
# leaves, curling vine tendrils for arms ending in thorn hooks, dangling root tendrils underneath. Same pet id, prefix
# (Wraith_), family, rarity, price and shop slot; same carved face (narrow slit eyes, inverted nose, jagged fanged mouth
# with the corners pulled down), now big on the pumpkin's front.
# L2 "Harvest Reaper": thorned vines wrapping the pumpkin, two big leaf-blade wings, ember wisps orbiting.
# L3 "Hollow King": a crown of black candles with ember flames round the stem, soul flame from the cut lid, a third vine
# arm pair of thorns, white-hot glow.
# Built with `python ../assemble_parts.py` style: this source + pumpkin/_parts.py (helpers lifted from wraith.py).
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

NAME = 'Wraith'   # keeps the installed template prefix (Wraith_) and controller
SHARP_ANGLE = 40
NORMAL_STRENGTH = 2.0
TS = 1024
ATLAS = Atlas({
    'pumpkin': (0, 0, 1024, 384),   # u around (0 back, 0.5 front), v bottom -> top
    'lid': (0, 384, 512, 128),      # the cut lid ring: u around, v
    'stem': (512, 384, 256, 128),
    'vine': (768, 384, 256, 128),   # arm / root tendrils: v root -> tip
    'leaf': (0, 512, 512, 128),     # leaves, leaf wings, thorns: v root -> tip
    'claw': (512, 512, 128, 128),   # thorn hooks
    'fire': (640, 512, 384, 128),   # ember wisps, soul flame, candle flames: v root -> tip
    'candle': (0, 640, 512, 128),   # L3 black wax candles: v bottom -> top
    'crown': (512, 640, 512, 128),  # L3 crown band
})

GLOW = {1: ('ff6a12', 'ffd08a'), 2: ('ff9a1e', 'fff0b0'), 3: ('ffb43c', 'fffbe8')}
CUT = {1: ('ff7a10', 'ffe070'), 2: ('ffa020', 'fff2a0'), 3: ('ffd060', 'ffffff')}

PC = V(0, -0.02, 0.95)      # pumpkin centre
PR, PH = 0.55, 0.42         # pumpkin radius, half-height
S = PR / 0.35               # face scale vs the wraith's head
FX, FZ, FZH = 0.36 * S, PC[2] + 0.02 * S, 0.27 * S   # face decal shell mapping (model space)


def bones_def():
    b = [
        ('Root', V(0, 0, 0), V(0, 0, 0.2), None),
        ('Body', PC + V(0, 0, -0.3), PC + V(0, 0, 0.3), 'Root'),
        ('Stem', PC + V(0, 0.02, PH - 0.04), PC + V(0, 0.06, PH + 0.25), 'Body'),
        ('Tail1', PC + V(0, 0.04, -PH + 0.05), PC + V(0, 0.08, -PH - 0.2), 'Body'),
        ('Tail2', PC + V(0, 0.08, -PH - 0.2), PC + V(0, 0.14, -PH - 0.42), 'Tail1'),
        ('Wisp', PC + V(0, 0, 0.0), PC + V(0, 0, 0.2), 'Body'),
        ('Crown', PC + V(0, 0.02, PH + 0.02), PC + V(0, 0.02, PH + 0.2), 'Body'),
        ('Wings', PC + V(0, 0.4, 0.2), PC + V(0, 0.55, 0.3), 'Body'),
    ]
    for s, x in (('L', 1), ('R', -1)):
        b += [('ArmU.' + s, PC + V(x * 0.5, -0.02, -0.05), PC + V(x * 0.8, -0.14, -0.12), 'Body'),
              ('Hand.' + s, PC + V(x * 0.8, -0.14, -0.12), PC + V(x * 0.95, -0.32, -0.08), 'ArmU.' + s)]
    return b


def _cum(centers):
    c = [np.asarray(p, float) for p in centers]
    d = [0.0]
    for a, b in zip(c, c[1:]):
        d.append(d[-1] + float(np.linalg.norm(b - a)))
    return [x / max(d[-1], 1e-9) for x in d]


def tube(mb, region, centers, radii, n, weights, part, start='point', end='point', start_pt=None, end_pt=None,
         side_hint=None, anti=True, th0=-math.pi / 2, lobes=0, lobe_amp=0.0):
    vv = _cum(centers)

    def profile(k, nn, a, b, i):
        th = th0 + 2 * math.pi * (k + (0.5 if (anti and i % 2) else 0.0)) / nn
        r = 1.0 + (lobe_amp * math.cos(lobes * (th - th0)) if lobes else 0.0)
        return a * r * math.cos(th), b * r * math.sin(th)

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


def _vnormals(mb, faces):
    acc = {}
    for fi in faces:
        f = mb.F[fi]
        a, b, c = mb.V[f[0]], mb.V[f[1]], mb.V[f[2]]
        n = np.cross(b - a, c - a)
        for v in f:
            acc[v] = acc.get(v, np.zeros(3)) + n
    return {v: nrm(n) for v, n in acc.items()}



def face_shell(mb, head_faces, lift=0.01):
    """mat-1 decal shell: the pumpkin's front facets lifted along smoothed normals (the carved face is painted flush)."""
    sel = [fi for fi in head_faces if all(mb.V[v][1] < PC[1] - 0.18 and FZ - FZH - 0.02 < mb.V[v][2] < FZ + FZH + 0.02 and
                                          abs(mb.V[v][0]) < FX + 0.02 for v in mb.F[fi])]
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


def vine(mb, pts, r0, r1, weights, part, region='vine'):
    n = len(pts)
    radii = [((r0 + (r1 - r0) * i / (n - 1)),) * 2 for i in range(n)]
    tube(mb, region, pts, radii, 6, weights, part, start='point', end='point', anti=False)


def build():
    mb = MB()
    mb.mat = 0
    W_B = {'Body': 1}
    n0 = len(mb.F)
    # deep-lobed pumpkin, wider than tall, flattened top with a cut-lid ring
    ps = [(-1.0, 0.25), (-0.86, 0.62), (-0.55, 0.9), (-0.15, 1.0), (0.25, 0.98), (0.58, 0.86), (0.84, 0.6), (0.97, 0.3)]
    tube(mb, 'pumpkin', [PC + V(0, 0, z * PH) for z, _ in ps], [(PR * r, PR * r * 0.92) for _, r in ps], 20, [W_B] * len(ps),
         'body', start='point', end='point', start_pt=PC + V(0, 0, -PH - 0.04), end_pt=PC + V(0, 0, PH * 0.9), side_hint=V(1, 0, 0),
         anti=False, th0=math.pi / 2, lobes=10, lobe_amp=0.09)
    head_faces = list(range(n0, len(mb.F)))
    # cut-lid seam: a thin dark torus just under the top, jagged glow painted on it
    torus(mb, 'lid', PC + V(0, 0, PH * 0.78), V(0, 0, 1), PR * 0.42, 0.02, 14, 4, W_B, 'lid')
    # thick curled stem + two leaves
    vine(mb, [PC + V(0, 0.02, PH * 0.82), PC + V(0.02, 0.04, PH + 0.1), PC + V(0.08, 0.1, PH + 0.2), PC + V(0.18, 0.16, PH + 0.22),
              PC + V(0.24, 0.14, PH + 0.14)], 0.075, 0.025, [{'Stem': 1}] * 5, 'stem', region='stem')
    lb, lt = ATLAS.uv('leaf', 0.3, 0.06), ATLAS.uv('leaf', 0.3, 0.95)
    for x, d in ((1, V(0.36, 0.16, 0.06)), (-1, V(-0.3, 0.2, 0.1))):
        base = PC + V(0.02 * x, 0.06, PH * 0.9)
        bipyramid(mb, base, base + d * 1.5, V(0, 1, 0), V(0, 0, 1), 0.3, 0.04, {'Stem': 1}, lb, lt, 'leaf', wide_at=0.4, ridge_at=0.4, curl=0.15)
    # curling vine tendril arms ending in three thorn hooks
    cb, ct = ATLAS.uv('claw', 0.5, 0.15), ATLAS.uv('claw', 0.5, 0.9)
    for s, x in (('L', 1), ('R', -1)):
        au, h = 'ArmU.' + s, 'Hand.' + s
        pts = [PC + V(x * 0.44, 0.0, -0.02), PC + V(x * 0.62, -0.06, -0.1), PC + V(x * 0.78, -0.14, -0.12),
               PC + V(x * 0.9, -0.24, -0.08), PC + V(x * 0.96, -0.32, 0.0)]
        vine(mb, pts, 0.06, 0.035, [{'Body': 0.5, au: 0.5}, {au: 1}, {au: 0.5, h: 0.5}, {h: 1}, {h: 1}], 'arm' + s)
        for k, (dz, dy) in enumerate(((0.05, -0.06), (-0.03, -0.1), (0.1, 0.02))):
            b0 = PC + V(x * 0.95, -0.31, -0.01)
            bipyramid(mb, b0, b0 + V(x * 0.06, dy - 0.08, dz + 0.04), V(1, 0, 0), V(0, 0, 1), 0.04, 0.035, {h: 1}, cb, ct, 'claw',
                      wide_at=0.3, ridge_at=0.3, curl=0.2)
        # curl tendril off each arm
        vine(mb, [PC + V(x * 0.64, -0.04, -0.06), PC + V(x * 0.7, 0.04, 0.08), PC + V(x * 0.64, 0.08, 0.16), PC + V(x * 0.56, 0.04, 0.14)],
             0.025, 0.012, [{au: 1}] * 4, 'curl' + s)
    # dangling root tendrils underneath (ember tips)
    for k, (dx, dy) in enumerate(((0.0, 0.0), (0.16, 0.08), (-0.16, 0.06))):
        top = PC + V(dx * 0.6, dy * 0.4, -PH * 0.9)
        vine(mb, [top, top + V(dx * 0.3, 0.06, -0.16), top + V(dx * 0.5, 0.14, -0.32), top + V(dx * 0.4, 0.22, -0.44)], 0.04, 0.012,
             [{'Body': 1}, {'Tail1': 1}, {'Tail2': 1}, {'Tail2': 1}], 'root%d' % k)
    mb.mat = 1
    face_shell(mb, head_faces)
    # ---- L2 "Harvest Reaper"
    mb.mat = 2
    # thorned vines creeping from the stem down the sides and back (never over the carved face)
    for k, a in enumerate((0.9, 2.2, math.pi, 4.1, 5.4)):
        d = V(math.cos(a), math.sin(a), 0)
        if d[1] < -0.45:
            continue
        pts = [PC + V(0, 0.02, PH * 0.86) + d * 0.08, PC + d * PR * 0.62 + V(0, 0, PH * 0.82), PC + d * PR * 0.95 + V(0, 0, PH * 0.4),
               PC + d * PR * 1.02 + V(0, 0, -PH * 0.05), PC + d * PR * 0.9 + V(0, 0, -PH * 0.5)]
        vine(mb, pts, 0.035, 0.018, [W_B] * 5, 'L2')
    for k in range(8):
        a = 2 * math.pi * k / 8 + 0.3
        p = PC + V(math.cos(a) * PR * 0.98, math.sin(a) * PR * 0.98 * 0.92 + 0.0, (0.1 if k % 2 else -0.08) * PH)
        if math.sin(a) < -0.4:
            continue
        d = nrm(V(math.cos(a), math.sin(a), 0.2))
        bipyramid(mb, p - d * 0.02, p + d * 0.12, V(0, 0, 1), d, 0.05, 0.04, W_B, lb, lt, 'L2', wide_at=0.3, ridge_at=0.3)
    for x in (1, -1):        # leaf-blade wings off the back
        base = PC + V(x * 0.18, 0.42, 0.18)
        bipyramid(mb, base, base + V(x * 0.62, 0.28, 0.42), V(0, 1, 0.3), V(0, 0, 1), 0.34, 0.05, {'Wings': 1}, lb, lt, 'L2',
                  wide_at=0.38, ridge_at=0.38, curl=0.18)
        bipyramid(mb, base + V(0, 0, -0.1), base + V(x * 0.48, 0.36, 0.06), V(0, 1, 0.3), V(0, 0, 1), 0.22, 0.04, {'Wings': 1}, lb, lt,
                  'L2', wide_at=0.38, ridge_at=0.38, curl=0.12)
    xb, xt = ATLAS.uv('fire', 0.5, 0.05), ATLAS.uv('fire', 0.5, 0.95)
    for x in (1, -1):
        c = PC + V(x * 0.86, 0.02, 0.3)
        bipyramid(mb, c, c + V(x * 0.03, 0.04, 0.26), V(1, 0, 0), V(0, -1, 0), 0.14, 0.14, {'Wisp': 1}, xb, xt, 'L2', wide_at=0.32, ridge_at=0.32)
        bipyramid(mb, c + V(0, 0.02, 0.06), c + V(-x * 0.06, 0.06, 0.2), V(1, 0, 0), V(0, -1, 0), 0.07, 0.07, {'Wisp': 1}, xb, xt, 'L2',
                  wide_at=0.3, ridge_at=0.3)
    # ---- L3 "Hollow King": candle crown round the stem, soul flame from the lid, extra thorn tendrils
    mb.mat = 3
    CC = PC + V(0, 0.02, PH * 0.86)
    tube(mb, 'crown', [CC + V(math.cos(2 * math.pi * i / 16) * PR * 0.5, math.sin(2 * math.pi * i / 16) * PR * 0.46, 0) for i in range(17)],
         [(0.035, 0.02)] * 17, 4, [{'Crown': 1}] * 17, 'L3', start='open', end='open', side_hint=V(0, 0, 1), anti=False)
    kb, kt = ATLAS.uv('candle', 0.5, 0.05), ATLAS.uv('candle', 0.5, 0.95)
    for k, ln in enumerate((0.26, 0.18, 0.22, 0.16, 0.22, 0.18)):
        a = -math.pi / 2 + 2 * math.pi * k / 6
        p = CC + V(math.cos(a) * PR * 0.5, math.sin(a) * PR * 0.46, 0.0)
        tube(mb, 'candle', [p, p + V(0, 0, ln)], [(0.035, 0.035), (0.03, 0.03)], 6, [{'Crown': 1}] * 2, 'L3', start='flat', end='flat', anti=False)
        f0 = p + V(0, 0, ln + 0.005)
        bipyramid(mb, f0, f0 + V(0, 0, 0.11), V(1, 0, 0), V(0, 1, 0), 0.05, 0.05, {'Crown': 1}, xb, xt, 'L3', wide_at=0.35, ridge_at=0.35)
    for base, tip, wd in ((PC + V(0, 0.04, PH * 0.85), PC + V(0, 0.12, PH + 0.5), 0.2), (PC + V(0.06, 0.02, PH * 0.82), PC + V(0.16, 0.06, PH + 0.36), 0.12),
                          (PC + V(-0.06, 0.06, PH * 0.82), PC + V(-0.14, 0.14, PH + 0.34), 0.12)):
        bipyramid(mb, base, tip, V(1, 0, 0), V(0, 1, 0), wd, wd, {'Crown': 1}, xb, xt, 'L3', wide_at=0.3, ridge_at=0.3)
    for s, x in (('L', 1), ('R', -1)):
        vine(mb, [PC + V(x * 0.42, 0.1, 0.18), PC + V(x * 0.66, 0.1, 0.34), PC + V(x * 0.8, 0.02, 0.42), PC + V(x * 0.86, -0.08, 0.36)],
             0.04, 0.015, [{'Body': 1}, {'Wings': 1}, {'Wings': 1}, {'Wings': 1}], 'L3')
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


def _orange(level):
    if level == 3:
        return [(0, '2a0a04'), (0.4, '7a2408'), (0.8, 'c4520e'), (1, 'e07a22')]
    return [(0, '220803'), (0.4, '6a1e06'), (0.8, 'b2440c'), (1, 'd2661a')]


def _reg(name):
    y0, y1, x0, x1 = ATLAS.px(name)
    h, w = y1 - y0, x1 - x0
    v, u = np.mgrid[0:h, 0:w].astype(np.float32)
    return (y0, y1, x0, x1), v / h, u / w



def paint_atlas(level):
    col = np.zeros((TS, TS, 3), np.float32)
    hgt = np.full((TS, TS), 0.5, np.float32)
    rgh = np.full((TS, TS), 0.6, np.float32)
    glow = np.zeros((TS, TS), np.float32)
    gc, ghi = GLOW[level]
    # ---- pumpkin: deep burnt orange lobes, dark grooves, grain, scorched top and bottom, glowing cracks
    (y0, y1, x0, x1), v, u = _reg('pumpkin')
    h, w = y1 - y0, x1 - x0
    ribs = np.abs(_saw(u * 10 + 0.5) - 0.5) * 2
    lobe = 1 - ribs
    st = _streaks(h, w, 140, 47)
    gr = _pgrain(h, w, 23)
    mott = vnoise(h, w, 18, 9) - 0.5
    sh = 0.35 + 0.55 * lobe ** 0.6 + 0.25 * mott - 0.4 * (np.abs(v - 0.5) * 2) ** 2
    c = grad(np.clip(sh, 0, 1), _orange(level)) * (1 + 0.25 * st[..., None] + 0.06 * gr[..., None])
    groove = ss(0.12, 0.0, lobe)
    c = c * (1 - 0.72 * groove[..., None]) + hx('1a0602') * 0.72 * groove[..., None]
    scorch = ss(0.0, 0.25, np.abs(v - 0.5) * 2 - 0.6 + 0.1 * _saw(u * 20))
    c = c * (1 - 0.82 * scorch[..., None]) + hx('0c0503') * 0.82 * scorch[..., None]
    # burnt claw scratches across the back (edgy)
    scratch = ss(0.012, 0.0, np.abs(_saw(u * 3 + v * 1.2) - 0.5) - 0.005) * ss(0.3, 0.42, np.abs(u - 0.5)) * ss(0.25, 0.4, v) * ss(0.8, 0.65, v)
    c = c * (1 - 0.7 * scratch[..., None])
    cr = ss(0.01, 0.0, np.abs(_saw(u * 5 + 2.2 * v + 0.3 * mott) - 0.5) - 0.006) * ss(0.85, 0.95, vnoise(h, w, 30, 3 + level))
    cr *= (0.45, 0.8, 1.0)[level - 1]
    c = c * (1 - cr[..., None]) + hx(gc) * cr[..., None]
    col[y0:y1, x0:x1] = c
    rgh[y0:y1, x0:x1] = 0.45 + 0.2 * scorch - 0.1 * lobe
    hgt[y0:y1, x0:x1] = 0.5 + 0.38 * lobe + 0.2 * st - 0.28 * groove - 0.15 * scratch
    glow[y0:y1, x0:x1] = cr
    # ---- lid seam: dark with a jagged glowing cut line
    (y0, y1, x0, x1), v, u = _reg('lid')
    line = ss(0.03, 0.0, np.abs(np.cos((u * 22) * math.pi) * 0.25 + (v - 0.5)) - 0.1)
    col[y0:y1, x0:x1] = hx('140804') * (1 - line[..., None]) + hx(gc) * line[..., None]
    glow[y0:y1, x0:x1] = line
    # ---- stem: dark twisted green-black, a little rot
    (y0, y1, x0, x1), v, u = _reg('stem')
    col[y0:y1, x0:x1] = grad(v, [(0, '24301a'), (0.6, '121a0c'), (1, '070904')]) * (1 + 0.3 * (0.5 + 0.5 * np.cos(u * 2 * math.pi * 6)))[..., None]
    rgh[y0:y1, x0:x1] = 0.75
    hgt[y0:y1, x0:x1] = 0.5 + 0.3 * np.cos(u * 2 * math.pi * 6)
    # ---- vine tendrils: near-black green, ember sap veins, glowing tip
    (y0, y1, x0, x1), v, u = _reg('vine')
    sap = ss(0.02, 0.0, np.abs(_saw(v * 3 + u) - 0.5) - 0.01) * ss(0.4, 0.5, np.cos((u - 0.5) * 2 * math.pi)) * (0.5 if level == 1 else 1.0)
    tipg = ss(0.85, 0.98, v)
    cc = hx('121a0a') * (0.7 + 0.5 * np.cos((u - 0.5) * 2 * math.pi) ** 2)[..., None]
    g2 = np.clip(sap + tipg, 0, 1)
    col[y0:y1, x0:x1] = cc * (1 - g2[..., None]) + hx(gc) * g2[..., None]
    rgh[y0:y1, x0:x1] = 0.6
    hgt[y0:y1, x0:x1] = 0.5 + 0.3 * np.cos(v * 2 * math.pi * 10)
    glow[y0:y1, x0:x1] = g2 * 0.8
    # ---- leaves / thorns
    (y0, y1, x0, x1), v, u = _reg('leaf')
    mid = ss(0.02, 0.0, np.abs(u - 0.5) - 0.006)
    veins = ss(0.015, 0.0, np.abs(_saw(u * 4 + v * 2) - 0.5) - 0.01)
    tip = ss(0.82, 0.96, v)
    cc = grad(v, [(0, '24301a'), (0.6, '10160a'), (1, '060804')]) * (1 - 0.3 * veins[..., None])
    g2 = np.clip(mid * (0.4 if level == 1 else 0.8) + tip, 0, 1)
    col[y0:y1, x0:x1] = cc * (1 - g2[..., None]) + hx(gc) * g2[..., None]
    rgh[y0:y1, x0:x1] = 0.55
    hgt[y0:y1, x0:x1] = 0.5 + 0.25 * veins
    glow[y0:y1, x0:x1] = g2
    # ---- thorn hooks: black, ember tips
    (y0, y1, x0, x1), v, u = _reg('claw')
    t = ss(0.6, 0.92, v)
    col[y0:y1, x0:x1] = hx('0a0808') * (1 - t[..., None]) + hx(gc) * t[..., None]
    rgh[y0:y1, x0:x1] = 0.3
    glow[y0:y1, x0:x1] = t * (0.6 if level == 1 else 1.0)
    # ---- fire
    (y0, y1, x0, x1), v, u = _reg('fire')
    col[y0:y1, x0:x1] = grad(v, [(0, ghi), (0.45, gc), (1, '2a0804')])
    rgh[y0:y1, x0:x1] = 0.2
    glow[y0:y1, x0:x1] = 1.0 - 0.6 * v
    # ---- L3 black candles with wax drips
    (y0, y1, x0, x1), v, u = _reg('candle')
    drip = ss(0.02, 0.0, v - (0.7 + 0.2 * _saw(u * 7)))
    col[y0:y1, x0:x1] = grad(v, [(0, '0a0808'), (1, '1a1414')]) * (1 + 0.6 * drip[..., None])
    rgh[y0:y1, x0:x1] = 0.35
    # ---- L3 crown band: black iron, glowing inlay
    (y0, y1, x0, x1), v, u = _reg('crown')
    inl = ss(0.02, 0.0, np.abs(v - 0.5) - (0.08 + 0.06 * _saw(u * 24)))
    col[y0:y1, x0:x1] = hx('100a08') * (1 - inl[..., None]) + hx(gc) * inl[..., None]
    rgh[y0:y1, x0:x1] = 0.3
    glow[y0:y1, x0:x1] = inl
    paint_atlas._glow = np.clip(glow, 0, 1)
    return np.clip(col, 0, 1), hgt, rgh


def emissive_mask(level):
    paint_atlas(level)
    return np.repeat(paint_atlas._glow[..., None], 3, -1)


# ---------------------------------------------------------------- face decal (carved eyes, nose, mouth)
def _seg(X, Z, a, b, w0, w1):
    ax, az = a; bx, bz = b
    dx, dz = bx - ax, bz - az
    L2 = dx * dx + dz * dz
    t = np.clip(((X - ax) * dx + (Z - az) * dz) / L2, 0, 1)
    d = np.sqrt((X - ax - t * dx) ** 2 + (Z - az - t * dz) ** 2)
    wd = w0 + (w1 - w0) * t
    return ss(wd, wd - 0.003, d)


def _tri(X, Z, p0, p1, p2):
    """inside of the triangle p0 p1 p2 (soft 0..1)."""
    def side(a, b):
        return (b[0] - a[0]) * (Z - a[1]) - (b[1] - a[1]) * (X - a[0])
    s0, s1, s2 = side(p0, p1), side(p1, p2), side(p2, p0)
    sgn = 1 if ((p1[0] - p0[0]) * (p2[1] - p0[1]) - (p1[1] - p0[1]) * (p2[0] - p0[0])) > 0 else -1
    m = np.minimum(np.minimum(s0 * sgn, s1 * sgn), s2 * sgn)
    return ss(0.0, 0.0006, m)


def _face_layers(level, size):
    x, y = coords(size)
    X, Z = x * 0.36, 1.2 + y * 0.27      # texture space = the wraith face layout; face_shell maps the pumpkin front onto it
    aX = np.abs(X)
    # carved eyes: narrow blades slanting down toward the nose (inner corner low and pointed, outer corner high)
    eye = _tri(aX, Z, (0.045, 1.215), (0.27, 1.32), (0.25, 1.245))
    eye = np.maximum(eye, _tri(aX, Z, (0.045, 1.215), (0.25, 1.245), (0.16, 1.215)))
    # a dark slit "pupil" flame inside each eye (anime slit)
    cx, cz = 0.175, 1.255
    slit = ss(0.008, 0.002, np.abs(aX - cx) - 0.003 * np.clip(1 - ((Z - cz) / 0.04) ** 2, 0, 1)) * ss(0.045, 0.035, np.abs(Z - cz)) * eye
    # heavy carved brow notch above each eye (a dark wedge, not cut through)
    brow = _seg(aX, Z, (0.03, 1.26), (0.29, 1.36), 0.014, 0.004)
    # small inverted nose cut
    nose = _tri(X, Z, (-0.032, 1.2), (0.032, 1.2), (0.0, 1.155))
    # mouth: a wide, nearly flat jagged slash, corners pulled DOWN (menacing), with sharp teeth points
    top = 1.125 - 0.25 * aX ** 2 + 0.012 * _saw(X / 0.07 + 0.5)
    bot = 1.035 - 0.18 * aX ** 2
    span = aX < 0.29
    mouth = ss(0.003, 0.0, np.maximum(Z - top, bot - Z)) * span
    gap = top - bot
    tw = 0.07
    ph = _saw(X / tw + 0.5)
    up_t = (top - Z) < (0.55 * gap * ph) + 0.002            # upper fangs hang down
    lo_t = (Z - bot) < (0.45 * gap * _saw(X / tw)) + 0.002  # lower fangs point up, offset
    teeth = mouth * np.clip(up_t * 1.0 + lo_t * 1.0, 0, 1)
    cut = np.clip(mouth * (1 - teeth), 0, 1)
    # mouth corners: thin cracks running down the cheeks
    crack = np.maximum(_seg(aX, Z, (0.28, top_at(0.28) - 0.03), (0.33, 0.98), 0.008, 0.001),
                       _seg(aX, Z, (0.3, 1.05), (0.36, 1.09), 0.006, 0.001))
    # carved-wall rim (the thickness of the shell round every cut, a lighter flesh colour)
    allcut = np.maximum.reduce([eye, nose, cut])
    marks = np.zeros_like(X)
    if level >= 2:                                   # L2: ember rune scars under the eyes
        marks = np.maximum(_seg(aX, Z, (0.15, 1.19), (0.2, 1.12), 0.008, 0.002), _seg(aX, Z, (0.22, 1.2), (0.26, 1.15), 0.006, 0.002))
    if level >= 3:                                   # L3: a third carved eye mark on the brow
        marks = np.maximum(marks, _tri(X, Z, (-0.04, 1.35), (0.04, 1.35), (0.0, 1.41)))
    return X, Z, eye, slit, brow, nose, cut, teeth, mouth, crack, allcut, marks


def _blur(a, r):
    out = a.copy()
    for _ in range(3):
        acc = np.zeros_like(out)
        for d in range(-r, r + 1):
            acc += np.roll(out, d, 0)
        out = acc / (2 * r + 1)
        acc = np.zeros_like(out)
        for d in range(-r, r + 1):
            acc += np.roll(out, d, 1)
        out = acc / (2 * r + 1)
    return out


def top_at(x):
    return 1.125 - 0.25 * x ** 2


def face_texture(level, size=512):
    X, Z, eye, slit, brow, nose, cut, teeth, mouth, crack, allcut, marks = _face_layers(level, size)
    gc, ghi = CUT[level]
    rgba = np.zeros((size, size, 4), np.float32)
    # carved openings: ember at the cut edge, white-hot toward the middle of each cut (lit from inside)
    hot = _blur(allcut, 6)
    hot = np.clip((hot - 0.45) * 2.2, 0, 1) * allcut
    c = hx(gc) * (1 - hot[..., None]) + hx(ghi) * hot[..., None]
    rim = np.clip(allcut - _blur(allcut, 2) * 0.0, 0, 1) * (1 - _blur(allcut, 2) ** 4)
    c = c * (1 - 0.35 * rim[..., None]) + hx('a83a08') * 0.35 * rim[..., None]
    c = c * (1 - slit[..., None]) + hx('1a0602') * slit[..., None]
    # pumpkin-flesh teeth (lit from below by the glow)
    tcol = grad(np.clip((Z - 1.03) / 0.1, 0, 1), [(0, 'e0802a'), (1, '8a3010')])
    c = c * (1 - teeth[..., None]) + tcol * teeth[..., None]
    # dark brow wedge, cheek cracks and marks
    ln = np.clip(np.maximum(brow, crack), 0, 1)
    c = c * (1 - ln[..., None]) + hx('140602') * ln[..., None]
    c = c * (1 - marks[..., None]) + hx(GLOW[level][0]) * marks[..., None]
    rgba[..., :3] = c
    rgba[..., 3] = np.clip(np.maximum.reduce([allcut, teeth, ln, marks]), 0, 1)
    return rgba


def face_emissive(level, size=512):
    X, Z, eye, slit, brow, nose, cut, teeth, mouth, crack, allcut, marks = _face_layers(level, size)
    g = np.clip(np.maximum.reduce([allcut * (1 - slit), teeth * 0.35, marks * 0.9, crack * 0.25]), 0, 1)
    return np.repeat(g[..., None], 3, -1)


def _ease(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def _pulse(t, a, b):
    if t <= a or t >= b:
        return 0.0
    return math.sin(math.pi * (t - a) / (b - a))



# A menacing floating jack-o'-lantern: a slow heavy bob, a wobble, the vine arms curling, roots trailing.
def anim_idle():
    F = 72
    keys = {}
    for f in range(0, F + 1, 3):
        t = f / F
        w = 2 * math.pi * t
        stare = _pulse(t, 0.35, 0.7)
        flex = _pulse(t, 0.55, 0.8)
        k = {'Body': P(('x', 3 * math.sin(w) + 8 * stare), ('y', 4 * math.sin(w * 0.5)), ('z', 6 * math.sin(w * 0.5 + 0.3) - 10 * stare), loc=(0, 0, 0.08 * math.sin(w))),
             'Stem': P(('x', 8 * math.sin(w + 1)), ('y', 6 * math.sin(w))),
             'ArmU.L': P(('x', -10 + 8 * math.sin(w)), ('z', -12 + 6 * math.sin(w + 0.4)), ('y', -10 * flex)),
             'ArmU.R': P(('x', -10 + 8 * math.sin(w + 0.4)), ('z', 12 - 6 * math.sin(w)), ('y', 10 * flex)),
             'Hand.L': P(('x', -25 - 30 * flex)), 'Hand.R': P(('x', -25 - 30 * flex)),
             'Tail1': P(('x', 10 * math.sin(w)), ('z', 10 * math.sin(w + 0.5))), 'Tail2': P(('x', 14 * math.sin(w - 0.8)), ('z', 14 * math.sin(w - 0.3))),
             'Wisp': P(('z', 360 * t), loc=(0, 0, 0.04 * math.sin(2 * w))),
             'Crown': P(('z', 8 * math.sin(w))), 'Wings': P(('z', 6 * math.sin(w * 2)), ('x', 4 * math.sin(w * 2)))}
        keys[f] = k
    keys[F] = dict(keys[0])
    keys[F]['Wisp'] = P(('z', 0))
    return {'frames': F, 'loop': True, 'keys': keys}


def _fly(frames, pitch, sway):
    keys = {}
    for f in range(0, frames + 1, 2):
        t = f / frames
        w = 2 * math.pi * t
        keys[f] = {'Body': P(('x', pitch + 4 * math.sin(w + 0.6)), ('z', sway * 0.3 * math.sin(w)), loc=(0, 0, 0.06 * math.sin(w - 1.2))),
                   'Stem': P(('x', -pitch * 0.8)),
                   'ArmU.L': P(('x', 40 + 8 * math.sin(w)), ('z', 14)), 'ArmU.R': P(('x', 40 + 8 * math.sin(w + 0.5)), ('z', -14)),
                   'Hand.L': P(('x', 20)), 'Hand.R': P(('x', 20)),
                   'Tail1': P(('x', -pitch * 0.9), ('z', sway * math.sin(w))), 'Tail2': P(('x', -pitch * 0.5), ('z', sway * 1.3 * math.sin(w - 0.9))),
                   'Wisp': P(loc=(0, 0.1, -0.05)), 'Crown': P(('x', -pitch * 0.3)),
                   'Wings': P(('x', -12 + 10 * math.sin(w * 2)), ('z', 8 * math.sin(w * 2)))}
    keys[frames] = dict(keys[0])
    return {'frames': frames, 'loop': True, 'keys': keys}


def anim_walk():
    return _fly(24, 18, 12)


def anim_run():
    return _fly(16, 34, 18)


def anim_hop():
    keys = {}
    F = 16
    for f in range(0, F + 1, 2):
        t = f / F
        crouch = _pulse(t, 0.0, 0.3)
        up = _pulse(t, 0.2, 1.0)
        keys[f] = {'Body': P(('x', 10 * crouch - 12 * up), loc=(0, 0, -0.08 * crouch + 0.32 * up)),
                   'ArmU.L': P(('y', -60 * up)), 'ArmU.R': P(('y', 60 * up)),
                   'Tail1': P(('x', 25 * up)), 'Tail2': P(('x', 20 * up)), 'Stem': P(('x', 20 * up))}
    return {'frames': F, 'loop': False, 'keys': keys}


def anim_ability():
    """Vanish (~1 s, Runner): the vines wrap over the face, the pumpkin spins a full turn and sinks, then flares up with
    the vines flung wide and the carved face blazing (the moment it turns invisible)."""
    keys = {}
    F = 24
    for f in range(0, F + 1, 2):
        t = f / F
        wrap = _ease(t / 0.3) * (1 - _ease((t - 0.55) / 0.1))
        spin = _ease((t - 0.2) / 0.4)
        fling = _ease((t - 0.55) / 0.1) * (1 - _ease((t - 0.8) / 0.2))
        keys[f] = {'Root': P(('z', 360 * spin)),
                   'Body': P(('x', 14 * wrap - 18 * fling), loc=(0, 0, -0.12 * wrap + 0.14 * fling)),
                   'ArmU.L': P(('x', -40 * wrap), ('z', -70 * wrap), ('y', -80 * fling)),
                   'ArmU.R': P(('x', -40 * wrap), ('z', 70 * wrap), ('y', 80 * fling)),
                   'Hand.L': P(('x', -50 * wrap)), 'Hand.R': P(('x', -50 * wrap)),
                   'Stem': P(('x', 25 * fling - 10 * wrap)),
                   'Tail1': P(('z', 30 * math.sin(6 * t))), 'Tail2': P(('z', 40 * math.sin(6 * t - 1))),
                   'Wisp': P(('z', 720 * t)), 'Crown': P(loc=(0, 0, 0.1 * fling)), 'Wings': P(('z', 25 * fling))}
    return {'frames': F, 'loop': False, 'keys': keys}


def anim_tether():
    """Stalk (~0.75 s, Catcher): rears back, lashes the right vine forward like a whip, yanks it back."""
    keys = {}
    F = 18
    for f in range(0, F + 1):
        t = f / F
        rear = _ease(t / 0.3) * (1 - _ease((t - 0.3) / 0.1))
        lunge = _ease((t - 0.3) / 0.1) * (1 - _ease((t - 0.55) / 0.12))
        yank = _ease((t - 0.55) / 0.12) * (1 - _ease((t - 0.8) / 0.2))
        keys[f] = {'Body': P(('x', -14 * rear + 22 * lunge - 16 * yank), ('z', 12 * rear - 8 * lunge),
                             loc=(0, 0.12 * rear - 0.25 * lunge + 0.18 * yank, 0.04 * rear)),
                   'ArmU.R': P(('x', 40 * rear - 95 * lunge - 50 * yank), ('z', -30 * rear + 20 * lunge)),
                   'Hand.R': P(('x', 30 * rear - 30 * lunge + 50 * yank)),
                   'ArmU.L': P(('x', -20 * lunge), ('y', -30 * yank)), 'Hand.L': P(('x', -30 * yank)),
                   'Tail1': P(('x', 20 * lunge - 15 * yank)), 'Tail2': P(('x', 15 * lunge)), 'Stem': P(('x', -15 * lunge)),
                   'Wisp': P(('z', 360 * t))}
    return {'frames': F, 'loop': False, 'keys': keys}


ANIMS = {'Idle': anim_idle, 'Walk': anim_walk, 'Run': anim_run, 'Hop': anim_hop, 'Ability': anim_ability,
         'Stalk': anim_tether}
