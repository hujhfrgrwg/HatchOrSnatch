# Pumpkin Wraith (Invisibility, Legendary, Halloween featured pet) for Hatch or Snatch: HOS-HWN-001, built on the pet kit
# (docs/pets/Pet Pipeline Guide.md, docs/pets/PET_LESSONS.md). Brief (Hunter via the thread, 17 Oct): a floating hooded
# wraith, carved jack-o'-lantern head with ember-orange glowing eyes and a jagged grin cut (menacing, not a smile), a
# tattered dark cloak, no legs. The richest look in the Invisibility family.
# Build: one lofted cloak (flared, tattered hem with burning edges), a thick open hood shell with a swept-back peak framing
# a lobed, scorched pumpkin head, bell sleeves with bony black claws, a tattered mantle and streaming cape blades.
# Face decal shell on the pumpkin front: narrow slanted carved slit eyes (ember core, dark slit), a small inverted nose
# cut, a wide flat jagged mouth with sharp teeth points. L2 "Harvest Reaper": thorned vines wrapped round the sleeves,
# two ember wisps, leaf-blade pauldrons, molten-gold glow. L3 "Hollow King": a floating crown of black thorns with ember
# tips, a reaper's scythe floating behind its back, soul flame from the hood peak, extra cape tatters, white-hot eyes.
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

NAME = 'Wraith'
SHARP_ANGLE = 40
NORMAL_STRENGTH = 2.0
TS = 1024
ATLAS = Atlas({
    'cloak': (0, 0, 1024, 384),     # cloak loft: u around (0 = back seam, 0.5 = front), v hem -> neck
    'hood': (0, 384, 512, 256),     # hood shell: u along the C ring (0..0.5 outer, 0.5..1 inner), v shoulder -> peak
    'pumpkin': (512, 384, 512, 256),  # u around (0 back, 0.5 front), v bottom -> top
    'limb': (0, 640, 384, 128),     # sleeves: v shoulder -> cuff; also the bony hands
    'tatter': (384, 640, 256, 128),  # hem tatters, mantle, cape blades: v root -> tip
    'claw': (640, 640, 128, 128),
    'stem': (768, 640, 256, 128),
    'vine': (0, 768, 256, 128),     # L2 vines
    'leaf': (256, 768, 256, 128),   # L2 pauldron leaf blades, thorns
    'fire': (512, 768, 256, 128),   # L2 ember wisps, L3 soul flame: v root -> tip
    'crown': (768, 768, 256, 128),  # L3 thorn crown band + spikes
    'blade': (0, 896, 512, 128),    # L3 scythe blade
    'haft': (512, 896, 512, 128),   # L3 scythe haft
})

GLOW = {1: ('ff6a12', 'ffd08a'), 2: ('ff9a1e', 'fff0b0'), 3: ('ffb43c', 'fffbe8')}   # ember glow per level
CUT = {1: ('ff7a10', 'ffe070'), 2: ('ffa020', 'fff2a0'), 3: ('ffd060', 'ffffff')}     # carved-cut core per level


# ---------------------------------------------------------------- skeleton
def bones_def():
    b = [
        ('Root', V(0, 0, 0), V(0, 0, 0.2), None),
        ('Body', V(0, 0.02, 0.35), V(0, 0.02, 0.9), 'Root'),
        ('Head', V(0, 0.0, 0.92), V(0, 0.0, 1.5), 'Body'),
        ('Hem', V(0, 0.04, 0.3), V(0, 0.04, 0.05), 'Body'),
        ('Cape1', V(0, 0.3, 0.8), V(0, 0.46, 0.55), 'Body'),
        ('Cape2', V(0, 0.46, 0.55), V(0, 0.62, 0.32), 'Cape1'),
        ('Cape3', V(0, 0.62, 0.32), V(0, 0.82, 0.12), 'Cape2'),
        ('Wisp', V(0, 0.0, 1.0), V(0, 0.0, 1.2), 'Body'),
        ('Crown', V(0, 0.16, 1.68), V(0, 0.16, 1.86), 'Head'),
        ('Scythe', V(0, 0.48, 0.9), V(0, 0.48, 1.1), 'Body'),
    ]
    for s, x in (('L', 1), ('R', -1)):
        b += [
            ('ArmU.' + s, V(x * 0.34, -0.02, 0.8), V(x * 0.52, -0.16, 0.56), 'Body'),
            ('Hand.' + s, V(x * 0.52, -0.16, 0.56), V(x * 0.6, -0.3, 0.44), 'ArmU.' + s),
        ]
    return b


# ---------------------------------------------------------------- helpers (as the Ghost)
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


def hood_shell(mb, centers, radii, gaps, thick, weights, n_arc, part, tip):
    """Thick open hood: each station is a C ring (outer arc round the back, inner arc back again), opening toward the
    front (-y) by `gaps[i]` radians each side of the front. Winding is set from the ring order, then checked once."""
    vv = _cum(centers + [tip])
    C = [np.asarray(c, float) for c in centers]
    rings, ring_uv = [], []
    for i, c in enumerate(C):
        a, b = radii[i]
        g = gaps[i]
        pts, us = [], []
        for k in range(n_arc):                      # outer: front-left edge round the back to the front-right edge
            th = -math.pi / 2 + g + (2 * math.pi - 2 * g) * k / (n_arc - 1)
            pts.append(c + V(a * math.cos(th), b * math.sin(th), 0))
            us.append(0.5 * k / (n_arc - 1))
        for k in range(n_arc):                      # inner: back again
            th = -math.pi / 2 + g + (2 * math.pi - 2 * g) * (n_arc - 1 - k) / (n_arc - 1)
            pts.append(c + V((a - thick) * math.cos(th), (b - thick) * math.sin(th), 0))
            us.append(0.5 + 0.5 * k / (n_arc - 1))
        rings.append([mb.vert(p, weights[i]) for p in pts])
        ring_uv.append(us)
    n = 2 * n_arc
    quads = []
    for i in range(len(C) - 1):
        for k in range(n):
            k2 = (k + 1) % n
            quads.append(([rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]],
                          [ATLAS.uv('hood', ring_uv[i][k], vv[i]), ATLAS.uv('hood', ring_uv[i][k2] if k2 else 1.0, vv[i]),
                           ATLAS.uv('hood', ring_uv[i + 1][k2] if k2 else 1.0, vv[i + 1]), ATLAS.uv('hood', ring_uv[i + 1][k], vv[i + 1])]))
    # winding check on the outer back quad of the first segment: its normal must point +y (away from the head)
    q = quads[n_arc // 2][0]
    P = [mb.V[j] for j in q]
    nn = sum(np.cross(P[j], P[(j + 1) % 4]) for j in range(4))
    flip = nn[1] < 0
    for idx, uv in quads:
        if flip:
            idx, uv = idx[::-1], uv[::-1]
        mb.face(idx[:3], uv[:3], part=part)
        mb.face([idx[0], idx[2], idx[3]], [uv[0], uv[2], uv[3]], part=part)
    ti = mb.vert(np.asarray(tip, float), weights[-1])
    last = rings[-1]
    for k in range(n):
        k2 = (k + 1) % n
        mb.face([last[k], last[k2], ti], [ATLAS.uv('hood', ring_uv[-1][k], vv[-2]), ATLAS.uv('hood', ring_uv[-1][k2], vv[-2]),
                                          ATLAS.uv('hood', ring_uv[-1][k], 1.0)], inside=C[-1], part=part)


FX, FZ, FZH = 0.36, 1.2, 0.27          # face decal shell: model x half-width, z centre, z half-height -> face texture
HEAD_C = V(0, -0.03, 1.18)


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
    """mat-1 decal shell: the pumpkin's front facets lifted along smoothed normals with the same weights (the carved
    eyes, nose and mouth are painted flush and follow the head in every frame)."""
    sel = [fi for fi in head_faces if all(mb.V[v][1] < -0.1 and 0.96 < mb.V[v][2] < 1.4 for v in mb.F[fi])]
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


# cloak loft stations: hem (flared) -> waist -> shoulders -> neck (leans back a touch as it rises)
STATIONS = [
    (V(0, 0.16, 0.1), (0.19, 0.17), {'Hem': 1}),
    (V(0, 0.1, 0.24), (0.25, 0.23), {'Hem': 0.6, 'Body': 0.4}),
    (V(0, 0.06, 0.42), (0.31, 0.28), {'Body': 1}),
    (V(0, 0.03, 0.6), (0.36, 0.31), {'Body': 1}),
    (V(0, 0.02, 0.74), (0.39, 0.33), {'Body': 1}),
    (V(0, 0.02, 0.85), (0.36, 0.31), {'Body': 1}),
    (V(0, 0.02, 0.93), (0.22, 0.2), {'Body': 0.6, 'Head': 0.4}),
]


def build():
    mb = MB()
    mb.mat = 0
    W_B, W_H = {'Body': 1}, {'Head': 1}
    tube(mb, 'cloak', [s[0] for s in STATIONS], [s[1] for s in STATIONS], 16, [s[2] for s in STATIONS], 'body',
         start='point', end='point', start_pt=V(0, 0.12, 0.3), end_pt=V(0, 0.02, 0.98), side_hint=V(1, 0, 0),
         th0=math.pi / 2)
    # pumpkin head: lobed (8 ribs), wider than tall, a little forward of the hood centre
    n0 = len(mb.F)
    hc = HEAD_C
    ps = [(hc + V(0, 0, -0.2), (0.17, 0.16)), (hc + V(0, 0, -0.15), (0.28, 0.26)), (hc + V(0, 0, -0.06), (0.35, 0.3)),
          (hc + V(0, 0, 0.05), (0.35, 0.3)), (hc + V(0, 0, 0.14), (0.28, 0.26)), (hc + V(0, 0, 0.2), (0.16, 0.15))]
    tube(mb, 'pumpkin', [p[0] for p in ps], [p[1] for p in ps], 16, [W_H] * len(ps), 'head', start='point', end='point',
         start_pt=hc + V(0, 0, -0.23), end_pt=hc + V(0, 0, 0.19), side_hint=V(1, 0, 0), anti=False, th0=math.pi / 2,
         lobes=8, lobe_amp=0.07)
    head_faces = list(range(n0, len(mb.F)))
    # a short curled stem poking out under the hood peak
    tube(mb, 'stem', [hc + V(0, 0.02, 0.17), hc + V(0.01, 0.04, 0.26), hc + V(0.05, 0.1, 0.31)],
         [(0.05, 0.05), (0.04, 0.04), (0.028, 0.028)], 6, [W_H] * 3, 'stem', start='open', end='point',
         end_pt=hc + V(0.09, 0.14, 0.32), anti=False)
    # hood: a thick open shell, opening to the front, peak swept up and back
    hood_c = [V(0, 0.02, 0.84), V(0, -0.04, 1.0), V(0, -0.07, 1.18), V(0, -0.08, 1.34), V(0, -0.04, 1.5), V(0, 0.06, 1.62)]
    hood_r = [(0.4, 0.36), (0.44, 0.41), (0.46, 0.43), (0.43, 0.41), (0.33, 0.32), (0.18, 0.17)]
    gaps = [math.radians(a) for a in (68, 62, 52, 34, 16, 8)]
    hood_w = [{'Body': 0.7, 'Head': 0.3}, {'Body': 0.3, 'Head': 0.7}, W_H, W_H, W_H, W_H]
    hood_shell(mb, hood_c, hood_r, gaps, 0.06, hood_w, 7, 'hood', tip=V(0, 0.34, 1.78))
    # tattered mantle over the shoulders: jagged cloth blades hanging out and down
    tb, tt = ATLAS.uv('tatter', 0.5, 0.06), ATLAS.uv('tatter', 0.5, 0.94)
    for k in range(7):
        a = math.radians(-160 + k * 320 / 6 + 90)       # spread round the sides and back, none over the face
        d = V(math.cos(a), math.sin(a), 0)
        if d[1] < -0.5:
            continue
        base = V(0, 0.03, 0.86) + d * 0.3
        tip = V(0, 0.03, 0.62) + d * (0.52 + 0.05 * (k % 2))
        bipyramid(mb, base, tip, V(-d[1], d[0], 0), d, 0.26, 0.05, W_B, tb, tt, 'mantle', wide_at=0.3, ridge_at=0.3)
    # hem tatters: jagged blades of different lengths round the hem (burning edges painted)
    for k in range(10):
        a = 2 * math.pi * (k + 0.5) / 10
        d = V(math.cos(a), math.sin(a), 0)
        ln = (0.14, 0.2, 0.12, 0.22, 0.16)[k % 5]
        base = V(0, 0.13, 0.17) + V(d[0] * 0.22, d[1] * 0.2, 0)
        tip = base + d * (0.06 + ln * 0.3) + V(0, 0.08, -0.12 - ln * 0.4)
        tip[2] = max(tip[2], 0.0)
        bipyramid(mb, base, tip, V(-d[1], d[0], 0), d, 0.2, 0.04, [{'Hem': 1}] * 6, tb, tt, 'tatter', wide_at=0.32, ridge_at=0.32)
    # cape blades streaming from the back
    for base, tip, wd in ((V(0.14, 0.3, 0.78), V(0.24, 0.84, 0.16), 0.26), (V(-0.14, 0.3, 0.78), V(-0.24, 0.84, 0.16), 0.26),
                          (V(0, 0.32, 0.72), V(0, 0.92, 0.26), 0.24)):
        bipyramid(mb, base, tip, V(1, 0, 0), V(0, 1, 0), wd, 0.05, [{'Cape1': 1}, {'Cape3': 1}, {'Cape2': 1}, {'Cape2': 1},
                                                                    {'Cape1': 0.5, 'Cape2': 0.5}, {'Cape1': 0.5, 'Cape2': 0.5}],
                  tb, tt, 'cape', wide_at=0.4, ridge_at=0.4)
    # bell sleeves (flared cuffs, recessed dark opening) with bony hands and long black claws
    cb, ct = ATLAS.uv('claw', 0.5, 0.15), ATLAS.uv('claw', 0.5, 0.9)
    for s, x in (('L', 1), ('R', -1)):
        au, h = 'ArmU.' + s, 'Hand.' + s
        arm = [(V(x * 0.3, 0.0, 0.82), (0.12, 0.12), {'Body': 0.5, au: 0.5}), (V(x * 0.42, -0.08, 0.7), (0.11, 0.11), {au: 1}),
               (V(x * 0.5, -0.14, 0.6), (0.14, 0.13), {au: 1}), (V(x * 0.55, -0.19, 0.52), (0.18, 0.16), {au: 0.6, h: 0.4})]
        tube(mb, 'limb', [a[0] for a in arm], [a[1] for a in arm], 8, [a[2] for a in arm], 'arm' + s,
             start='point', end='point', start_pt=V(x * 0.22, 0.02, 0.86), end_pt=V(x * 0.49, -0.13, 0.6))
        hand = [(V(x * 0.5, -0.15, 0.58), (0.05, 0.045)), (V(x * 0.57, -0.24, 0.48), (0.06, 0.05)), (V(x * 0.6, -0.29, 0.43), (0.055, 0.04))]
        tube(mb, 'limb', [p[0] for p in hand], [p[1] for p in hand], 6, [{h: 1}] * 3, 'hand' + s, start='point', end='point',
             end_pt=V(x * 0.61, -0.31, 0.41))
        for dx, dz in ((-0.04, 0.02), (0.0, -0.01), (0.04, 0.02)):
            b0 = V(x * (0.6 + dx), -0.28, 0.43 + dz)
            bipyramid(mb, b0, b0 + V(x * dx * 1.2, -0.2, -0.14), V(1, 0, 0), V(0, 0, 1), 0.045, 0.04, {h: 1}, cb, ct,
                      'claw', wide_at=0.3, ridge_at=0.3, curl=0.12)
    # ---- face decal shell (mat 1): carved eyes, nose and mouth
    mb.mat = 1
    face_shell(mb, head_faces)
    # ---- level 2 (mat 2) "Harvest Reaper": thorned vines round the sleeves, leaf-blade pauldrons, ember wisps
    mb.mat = 2
    lb, lt = ATLAS.uv('leaf', 0.5, 0.08), ATLAS.uv('leaf', 0.5, 0.94)
    for s, x in (('L', 1), ('R', -1)):
        au, h = 'ArmU.' + s, 'Hand.' + s
        torus(mb, 'vine', V(x * 0.44, -0.09, 0.69), V(x * 0.6, -0.5, -0.6), 0.125, 0.034, 9, 4, {au: 1}, 'L2')
        torus(mb, 'vine', V(x * 0.54, -0.18, 0.54), V(x * 0.4, -0.55, -0.7), 0.18, 0.034, 10, 4, {au: 0.6, h: 0.4}, 'L2')
        for p, d in ((V(x * 0.56, -0.08, 0.7), V(x, 0.2, 0.4)), (V(x * 0.66, -0.2, 0.54), V(x, -0.2, 0.3)),
                     (V(x * 0.44, -0.3, 0.52), V(0, -1, -0.2))):
            bipyramid(mb, p, p + nrm(d) * 0.1, V(0, 0, 1), V(0, -1, 0), 0.05, 0.04, {au: 1}, lb, lt, 'L2', wide_at=0.3, ridge_at=0.3)
        # pauldron: two jagged leaf blades rising off each shoulder
        for k, (tz, ty) in enumerate(((0.98, 0.08), (0.9, 0.2))):
            base = V(x * 0.34, 0.04 + 0.06 * k, 0.86)
            bipyramid(mb, base, V(x * (0.62 - 0.06 * k), ty, tz), V(0, 1, 0), V(0, 0, 1), 0.2, 0.05, W_B, lb, lt, 'L2',
                      wide_at=0.35, ridge_at=0.35, curl=0.15)
    xb, xt = ATLAS.uv('fire', 0.5, 0.05), ATLAS.uv('fire', 0.5, 0.95)
    for x in (1, -1):                               # ember wisps floating off each shoulder (Wisp bone: orbits in idle)
        c = V(x * 0.72, -0.06, 1.18)
        bipyramid(mb, c, c + V(x * 0.03, 0.04, 0.28), V(1, 0, 0), V(0, -1, 0), 0.15, 0.15, {'Wisp': 1}, xb, xt, 'L2',
                  wide_at=0.32, ridge_at=0.32)
        bipyramid(mb, c + V(0, 0.02, 0.06), c + V(-x * 0.07, 0.06, 0.22), V(1, 0, 0), V(0, -1, 0), 0.08, 0.08, {'Wisp': 1},
                  xb, xt, 'L2', wide_at=0.3, ridge_at=0.3)
    # ---- level 3 (mat 3) "Hollow King": thorn crown, floating scythe, soul flame, extra cape tatters
    mb.mat = 3
    CC = V(0, 0.0, 1.6)
    tube(mb, 'crown', [CC + V(math.cos(2 * math.pi * i / 14) * 0.3, math.sin(2 * math.pi * i / 14) * 0.28, 0.0)
                       for i in range(15)], [(0.04, 0.022)] * 15, 4, [{'Crown': 1}] * 15, 'L3', start='open', end='open',
         side_hint=V(0, 0, 1), anti=False)
    yb, yt = ATLAS.uv('crown', 0.5, 0.9), ATLAS.uv('crown', 0.5, 0.06)
    for k, ln in enumerate((0.3, 0.18, 0.24, 0.16, 0.24, 0.18, 0.2)):
        a = -math.pi / 2 + 2 * math.pi * k / 7
        p = CC + V(math.cos(a) * 0.3, math.sin(a) * 0.28, 0.0)
        bipyramid(mb, p - V(0, 0, 0.03), p + V(0, 0, ln) + V(math.cos(a), math.sin(a), 0) * 0.07, V(-math.sin(a), math.cos(a), 0),
                  V(math.cos(a), math.sin(a), 0), 0.08, 0.05, {'Crown': 1}, yb, yt, 'L3', wide_at=0.3, ridge_at=0.3, curl=0.1)
    # soul flame licking up out of the hood peak
    fb, ft = ATLAS.uv('fire', 0.5, 0.05), ATLAS.uv('fire', 0.5, 0.95)
    for base, tip, wd in ((V(0, 0.36, 1.7), V(0, 0.5, 2.02), 0.16), (V(0.04, 0.34, 1.68), V(0.12, 0.44, 1.92), 0.1),
                          (V(-0.04, 0.34, 1.68), V(-0.12, 0.48, 1.9), 0.1)):
        bipyramid(mb, base, tip, V(1, 0, 0), V(0, 1, 0), wd, wd, W_H, fb, ft, 'L3', wide_at=0.3, ridge_at=0.3)
    # the reaper's scythe floating diagonally behind the back (Scythe bone: slow sway)
    sw = {'Scythe': 1}
    h0, h1 = V(0.5, 0.46, 0.12), V(-0.46, 0.46, 1.86)
    tube(mb, 'haft', [h0, (h0 + h1) / 2, h1], [(0.03, 0.03)] * 3, 6, [sw] * 3, 'L3', start='point', end='point',
         start_pt=h0 + nrm(h0 - h1) * 0.06, end_pt=h1 + nrm(h1 - h0) * 0.04, anti=False)
    bb, bt = ATLAS.uv('blade', 0.5, 0.1), ATLAS.uv('blade', 0.5, 0.9)
    hd = nrm(h1 - h0)
    pts = [h1 - hd * 0.04, V(-0.06, 0.48, 2.0), V(0.38, 0.5, 1.94), V(0.7, 0.52, 1.68)]
    for (p, q), wd in zip(zip(pts, pts[1:]), (0.3, 0.24, 0.14)):     # curved blade in three chunky segments
        bipyramid(mb, p, q, V(0, 0, -1) if q[0] > p[0] else V(0, 0, 1), V(0, 1, 0), wd, 0.035, sw, bb, bt, 'L3',
                  wide_at=0.45, ridge_at=0.45)
    for base, tip, wd in ((V(0.2, 0.36, 0.6), V(0.5, 0.86, 0.22), 0.2), (V(-0.2, 0.36, 0.6), V(-0.5, 0.86, 0.22), 0.2)):
        bipyramid(mb, base, tip, V(0, 0, 1), V(0, 1, 0), wd, 0.04, [{'Cape1': 1}, {'Cape3': 1}] + [{'Cape2': 1}] * 4,
                  tb, tt, 'L3', wide_at=0.35, ridge_at=0.35)
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


def _cloth(level):
    if level == 3:                                  # royal: deep plum-black with a wine sheen
        return [(0, '07040a'), (0.5, '24102c'), (1, '4a2450')]
    if level == 2:                                  # moss-tinged charcoal
        return [(0, '06070a'), (0.5, '1a1e1e'), (1, '3a3c38')]
    return [(0, '060509'), (0.5, '1a1622'), (1, '3a3246')]


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
    cl = _cloth(level)
    gc, ghi = GLOW[level]
    # ---- cloak. v: 0 hem .. 1 neck. u: 0 back seam, 0.5 front.
    (y0, y1, x0, x1), v, u = _reg('cloak')
    h, w = y1 - y0, x1 - x0
    front = np.cos((u - 0.5) * 2 * math.pi)
    st = _streaks(h, w, 160, 41)
    gr = _pgrain(h, w, 19)
    folds = 0.5 + 0.5 * np.cos(u * 2 * math.pi * 16)            # vertical cloth folds
    c = grad(np.clip(0.25 + 0.5 * v + 0.1 * front + 0.25 * folds * (1 - v * 0.5), 0, 1), cl)
    c = c * (1 + 0.35 * st[..., None] + 0.08 * gr[..., None])
    # burning hem: charred black band with a jagged ember edge, little embers eating upward
    hemline = 0.12 + 0.07 * _saw(u * 22) + 0.04 * _saw(u * 7 + 0.3)
    char = ss(0.02, -0.02, v - hemline - 0.06)
    c = c * (1 - 0.7 * char[..., None])
    edge = ss(0.022, 0.0, np.abs(v - hemline - 0.06)) * ss(0.0, 0.01, v - 0.02)
    em = vnoise(h, w, 90, 7)
    embers = ss(0.82, 0.9, em) * ss(0.36, 0.1, v)
    # front seam: a chain of small glowing runes down the chest
    rx = np.abs(u - 0.5) * 2 * math.pi * 0.38
    rune = ss(0.012, 0.0, np.abs(_saw(v * 9) - 0.5) * 0.06 + rx * 0.5 - 0.02) * ss(0.45, 0.5, v) * ss(0.92, 0.86, v)
    rune *= 0.0
    # L3: a gold-embroidered trim band above the hem
    trim = ss(0.012, 0.0, np.abs(v - hemline - 0.13) - 0.012) * (1.0 if level == 3 else 0.0)
    c = c * (1 - trim[..., None]) + hx('c08a2a') * trim[..., None] * (0.8 + 0.4 * folds[..., None])
    gl = np.clip(edge + embers * 0.8 + rune, 0, 1)
    c = c * (1 - gl[..., None]) + hx(gc) * gl[..., None]
    col[y0:y1, x0:x1] = c
    rgh[y0:y1, x0:x1] = 0.72 - 0.25 * trim
    hgt[y0:y1, x0:x1] = 0.5 + 0.35 * st + 0.25 * (folds - 0.5) + 0.1 * gr - 0.15 * char
    glow[y0:y1, x0:x1] = gl
    # ---- hood: cloth outside, a near-black hollow inside with an ember underglow near the face
    (y0, y1, x0, x1), v, u = _reg('hood')
    h, w = y1 - y0, x1 - x0
    outer = (u < 0.5).astype(np.float32)
    st = _streaks(h, w, 80, 43)
    fo = 0.5 + 0.5 * np.cos(u * 2 * math.pi * 10)
    c = grad(np.clip(0.3 + 0.45 * (1 - v) * 0.5 + 0.3 * fo, 0, 1), cl) * (1 + 0.3 * st[..., None])
    rim = ss(0.04, 0.0, np.minimum(np.abs(u - 0.0), np.minimum(np.abs(u - 0.5), np.abs(u - 1.0))))   # front edge of the hood
    tear = ss(0.02, 0.0, np.abs(_saw(u * 30) - 0.5) - 0.44) * ss(0.4, 0.2, v) * outer       # frayed lower hood
    c = c * (1 - 0.5 * tear[..., None])
    inner = grad(np.clip(v * 1.2, 0, 1), [(0, '120604'), (0.5, '050306'), (1, '030204')])
    under = ss(0.5, 0.0, v) * (1 - outer) * 0.35
    inner = inner + hx(gc) * under[..., None] * 0.35
    c = c * outer[..., None] + inner * (1 - outer[..., None])
    # L2 / L3: glowing stitch line along the hood rim
    stitch = rim * ss(0.0, 0.2, _saw(v * 40)) * (0.0 if level == 1 else 0.8)
    if level == 3:
        c = c * (1 - 0.8 * rim[..., None]) + hx('b07a24') * 0.8 * rim[..., None]
    c = c * (1 - stitch[..., None]) + hx(gc) * stitch[..., None]
    col[y0:y1, x0:x1] = c
    rgh[y0:y1, x0:x1] = 0.75
    hgt[y0:y1, x0:x1] = 0.5 + 0.3 * st + 0.2 * (fo - 0.5) * outer
    glow[y0:y1, x0:x1] = stitch + under * 0.4
    # ---- pumpkin: deep burnt orange, dark rib grooves, vertical grain, scorched top and bottom
    (y0, y1, x0, x1), v, u = _reg('pumpkin')
    h, w = y1 - y0, x1 - x0
    ribs = np.abs(_saw(u * 8 + 0.5) - 0.5) * 2          # 1 mid-lobe .. 0 in the groove (grooves at k odd/16)
    lobe = 1 - ribs
    st = _streaks(h, w, 120, 47)
    gr = _pgrain(h, w, 23)
    mott = vnoise(h, w, 18, 9) - 0.5
    sh = 0.35 + 0.55 * lobe ** 0.6 + 0.25 * mott - 0.4 * (np.abs(v - 0.5) * 2) ** 2
    c = grad(np.clip(sh, 0, 1), _orange(level)) * (1 + 0.25 * st[..., None] + 0.06 * gr[..., None])
    groove = ss(0.12, 0.0, lobe)
    c = c * (1 - 0.7 * groove[..., None]) + hx('1a0602') * 0.7 * groove[..., None]
    scorch = ss(0.0, 0.25, np.abs(v - 0.5) * 2 - 0.62 + 0.1 * _saw(u * 16))
    c = c * (1 - 0.8 * scorch[..., None]) + hx('0c0503') * 0.8 * scorch[..., None]
    # glowing cracks seeping light from inside (thin, jagged, more at higher levels)
    cr = ss(0.01, 0.0, np.abs(_saw(u * 5 + 2.2 * v + 0.3 * mott) - 0.5) - 0.006) * ss(0.85, 0.95, vnoise(h, w, 30, 3 + level))
    cr *= (0.4, 0.8, 1.0)[level - 1]
    c = c * (1 - cr[..., None]) + hx(gc) * cr[..., None]
    col[y0:y1, x0:x1] = c
    rgh[y0:y1, x0:x1] = 0.45 + 0.2 * scorch - 0.1 * lobe
    hgt[y0:y1, x0:x1] = 0.5 + 0.35 * lobe + 0.2 * st - 0.25 * groove
    glow[y0:y1, x0:x1] = cr
    # ---- sleeves / hands: cloth sleeve, burnt cuff; bony charcoal hands
    (y0, y1, x0, x1), v, u = _reg('limb')
    st = _streaks(y1 - y0, x1 - x0, 60, 52)
    cuff = ss(0.0, 0.03, v - (0.82 + 0.06 * _saw(u * 10)))
    cc = grad(np.clip(0.55 - 0.2 * v + 0.2 * (0.5 + 0.5 * np.cos(u * 2 * math.pi * 6)), 0, 1), cl) * (1 + 0.3 * st[..., None])
    cedge = ss(0.02, 0.0, np.abs(v - (0.82 + 0.06 * _saw(u * 10))))
    cc = cc * (1 - 0.6 * cuff[..., None])
    cc = cc * (1 - cedge[..., None]) + hx(gc) * cedge[..., None] * 0.9
    col[y0:y1, x0:x1] = cc
    rgh[y0:y1, x0:x1] = 0.7
    hgt[y0:y1, x0:x1] = 0.5 + 0.3 * st
    glow[y0:y1, x0:x1] = cedge * 0.8
    # ---- tatters / mantle / cape: cloth blades going to a charred tip with a burning jagged edge
    (y0, y1, x0, x1), v, u = _reg('tatter')
    st = _streaks(y1 - y0, x1 - x0, 50, 55)
    ed = ss(0.0, 0.03, v - (0.74 + 0.1 * _saw(u * 6)))
    eg = ss(0.03, 0.0, np.abs(v - (0.74 + 0.1 * _saw(u * 6))))
    cc = grad(np.clip(0.6 - 0.4 * v, 0, 1), cl) * (1 + 0.35 * st[..., None])
    cc = cc * (1 - 0.8 * ed[..., None])
    cc = cc * (1 - eg[..., None]) + hx(gc) * eg[..., None]
    col[y0:y1, x0:x1] = cc
    rgh[y0:y1, x0:x1] = 0.72
    hgt[y0:y1, x0:x1] = 0.5 + 0.3 * st
    glow[y0:y1, x0:x1] = eg * 0.9
    # ---- claws: black, ember tips
    (y0, y1, x0, x1), v, u = _reg('claw')
    t = ss(0.6, 0.92, v)
    col[y0:y1, x0:x1] = hx('0a0808') * (1 - t[..., None]) + hx(gc) * t[..., None]
    rgh[y0:y1, x0:x1] = 0.3
    glow[y0:y1, x0:x1] = t * (0.6 if level == 1 else 1.0)
    # ---- stem: dark twisted green-black
    (y0, y1, x0, x1), v, u = _reg('stem')
    col[y0:y1, x0:x1] = grad(v, [(0, '1e2410'), (0.7, '0e1208'), (1, '060704')]) * (1 + 0.3 * (0.5 + 0.5 * np.cos(u * 2 * math.pi * 6)))[..., None]
    rgh[y0:y1, x0:x1] = 0.75
    # ---- L2 vines: near-black green with ember sap veins
    (y0, y1, x0, x1), v, u = _reg('vine')
    sap = ss(0.02, 0.0, np.abs(_saw(v * 3 + u) - 0.5) - 0.01) * ss(0.4, 0.5, np.cos((u - 0.5) * 2 * math.pi))
    col[y0:y1, x0:x1] = hx('101808') * (0.7 + 0.5 * np.cos((u - 0.5) * 2 * math.pi) ** 2)[..., None] * (1 - sap[..., None]) + hx(gc) * sap[..., None]
    rgh[y0:y1, x0:x1] = 0.6
    hgt[y0:y1, x0:x1] = 0.5 + 0.3 * np.cos(v * 2 * math.pi * 10)
    glow[y0:y1, x0:x1] = sap * 0.8
    # ---- L2 leaves / thorns: dark green-black blade, glowing midrib and tip
    (y0, y1, x0, x1), v, u = _reg('leaf')
    mid = ss(0.02, 0.0, np.abs(u - 0.5) - 0.006)
    tip = ss(0.8, 0.95, v)
    cc = grad(v, [(0, '1a2410'), (0.6, '0c1008'), (1, '050604')]) * (1 - 0.3 * ss(0.02, 0.0, np.abs(_saw(u * 4 + v * 2) - 0.5) - 0.01))[..., None]
    g2 = np.clip(mid * 0.7 + tip, 0, 1)
    col[y0:y1, x0:x1] = cc * (1 - g2[..., None]) + hx(gc) * g2[..., None]
    rgh[y0:y1, x0:x1] = 0.55
    glow[y0:y1, x0:x1] = g2
    # ---- fire: white-hot root to ember to a dark smoky tip
    (y0, y1, x0, x1), v, u = _reg('fire')
    col[y0:y1, x0:x1] = grad(v, [(0, ghi), (0.45, gc), (1, '2a0804')])
    rgh[y0:y1, x0:x1] = 0.2
    glow[y0:y1, x0:x1] = 1.0 - 0.6 * v
    # ---- L3 crown: black thorn wood with ember tips (spikes use v 0.06 tip .. 0.9 root)
    (y0, y1, x0, x1), v, u = _reg('crown')
    t = ss(0.3, 0.06, v)
    bark = 0.5 + 0.5 * np.cos(v * 2 * math.pi * 9 + u * 3)
    col[y0:y1, x0:x1] = hx('0e0a08') * (0.8 + 0.4 * bark[..., None]) * (1 - t[..., None]) + hx(gc) * t[..., None]
    rgh[y0:y1, x0:x1] = 0.5
    hgt[y0:y1, x0:x1] = 0.5 + 0.3 * bark
    glow[y0:y1, x0:x1] = t
    # ---- L3 scythe blade: blackened steel, the wide edge glows molten (bipyramid sides sample v ~0.58)
    (y0, y1, x0, x1), v, u = _reg('blade')
    edge = ss(0.45, 0.56, v) * ss(0.75, 0.62, v)
    cc = grad(np.clip(v, 0, 1), [(0, '101014'), (0.5, '2e2e38'), (1, '0c0c10')])
    col[y0:y1, x0:x1] = cc * (1 - edge[..., None]) + hx(gc) * edge[..., None]
    rgh[y0:y1, x0:x1] = 0.3
    glow[y0:y1, x0:x1] = edge
    # ---- L3 haft: dark wood wrapped in gold bands
    (y0, y1, x0, x1), v, u = _reg('haft')
    band = ss(0.01, 0.0, np.abs(_saw(v * 7) - 0.5) - 0.46)
    wood = grad(np.clip(0.5 + 0.3 * np.cos(u * 2 * math.pi * 3 + v * 40), 0, 1), [(0, '120a06'), (1, '2e1c10')])
    col[y0:y1, x0:x1] = wood * (1 - band[..., None]) + hx('b4842c') * band[..., None]
    rgh[y0:y1, x0:x1] = 0.6 - 0.3 * band
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
    X, Z = x * FX, FZ + y * FZH
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


# ---------------------------------------------------------------- animation (24 fps, in place, it floats)
# A looming floater: it hangs in the air with a slow, heavy bob, the hem and cape rippling like smoke, the head tilting
# down to stare, claws flexing. It never walks: Walk / Run are flight. Casts: Vanish (Runner): it draws the cloak
# round itself, spins down, then bursts its arms open (the moment it turns invisible). Stalk (Catcher): rears back,
# lunges a claw forward to throw the tether, then yanks back.

def _ease(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def _pulse(t, a, b):
    if t <= a or t >= b:
        return 0.0
    return math.sin(math.pi * (t - a) / (b - a))


def _cape(w, amp, pitch=0.0):
    return {'Cape1': P(('x', -pitch * 0.4 - 4), ('z', amp * math.sin(w))),
            'Cape2': P(('x', -pitch * 0.3), ('z', amp * 1.3 * math.sin(w - 0.9))),
            'Cape3': P(('x', -pitch * 0.2), ('z', amp * 1.6 * math.sin(w - 1.8))),
            'Hem': P(('x', -pitch * 0.25 + 4 * math.sin(w * 2)), ('y', 5 * math.sin(w * 2 + 0.7)))}


def anim_idle():
    """3 s loop: slow heavy bob, cape and hem ripple, the head tilts down to stare, claws flex, wisps orbit."""
    F = 72
    keys = {}
    for f in range(0, F + 1, 3):
        t = f / F
        w = 2 * math.pi * t
        stare = _pulse(t, 0.35, 0.75)
        flex = _pulse(t, 0.55, 0.8)
        k = {'Body': P(('x', 3 + 2 * math.sin(w)), ('z', 4 * math.sin(w * 0.5 + 0.3)), loc=(0, 0, 0.08 * math.sin(w))),
             'Head': P(('x', 4 - 3 * math.sin(w) + 10 * stare), ('y', -8 * stare), ('z', 10 * stare)),
             'ArmU.L': P(('x', -14 + 6 * math.sin(w)), ('z', -16), ('y', -8 * flex)),
             'ArmU.R': P(('x', -14 + 6 * math.sin(w + 0.4)), ('z', 16), ('y', 8 * flex)),
             'Hand.L': P(('x', -18 - 25 * flex)), 'Hand.R': P(('x', -18 - 25 * flex)),
             'Wisp': P(('z', 360 * t), loc=(0, 0, 0.04 * math.sin(2 * w))),
             'Crown': P(('z', 8 * math.sin(w)), loc=(0, 0, 0.03 * math.sin(w + 1.0))),
             'Scythe': P(('y', 5 * math.sin(w)), loc=(0, 0, 0.05 * math.sin(w + 2.0)))}
        k.update(_cape(w, 10))
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
             'Wisp': P(loc=(0, 0.1, -0.05)), 'Crown': P(('x', -pitch * 0.3)), 'Scythe': P(('x', -pitch * 0.4))}
        k.update(_cape(w, sway, pitch * 1.4))
        keys[f] = k
    keys[frames] = dict(keys[0])
    return {'frames': frames, 'loop': True, 'keys': keys}


def anim_walk():
    return _fly(24, 26, 12)


def anim_run():
    return _fly(16, 46, 18)


def anim_hop():
    """a looming rise: sinks into the cloak, surges up with arms flung wide, cape whipping."""
    keys = {}
    F = 16
    for f in range(0, F + 1, 2):
        t = f / F
        crouch = _pulse(t, 0.0, 0.3)
        up = _pulse(t, 0.2, 1.0)
        keys[f] = {'Body': P(('x', 10 * crouch - 10 * up), loc=(0, 0, -0.08 * crouch + 0.32 * up)),
                   'Head': P(('x', 12 * crouch - 8 * up)),
                   'ArmU.L': P(('y', -60 * up), ('x', -20 * crouch)), 'ArmU.R': P(('y', 60 * up), ('x', -20 * crouch)),
                   'Cape1': P(('x', 25 * up)), 'Cape2': P(('x', 20 * up)), 'Cape3': P(('x', 15 * up)),
                   'Hem': P(('x', -12 * up))}
    return {'frames': F, 'loop': False, 'keys': keys}


def anim_ability():
    """Vanish (~1 s, Runner): draws both sleeves across its face, spins a full turn sinking into the cloak, then bursts
    the arms wide and rears up (the moment it turns invisible), and settles."""
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
                   'Cape1': P(('x', 30 * wrap - 20 * fling), ('z', 25 * math.sin(6 * t))),
                   'Cape2': P(('z', 35 * math.sin(6 * t - 1))), 'Cape3': P(('z', 45 * math.sin(6 * t - 2))),
                   'Hem': P(('x', -14 * fling), ('y', 10 * math.sin(8 * t))),
                   'Wisp': P(('z', 720 * t)), 'Crown': P(loc=(0, 0, 0.12 * fling)), 'Scythe': P(('y', 20 * fling))}
    return {'frames': F, 'loop': False, 'keys': keys}


def anim_tether():
    """Stalk (~0.75 s, Catcher): rears back with the right claw cocked, lunges forward thrusting it out (the tether
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
                   'Cape1': P(('x', 20 * lunge - 15 * yank)), 'Cape2': P(('x', 15 * lunge - 10 * yank)),
                   'Cape3': P(('x', 12 * lunge)), 'Hem': P(('x', -10 * lunge)),
                   'Wisp': P(('z', 360 * t))}
    return {'frames': F, 'loop': False, 'keys': keys}


ANIMS = {'Idle': anim_idle, 'Walk': anim_walk, 'Run': anim_run, 'Hop': anim_hop, 'Ability': anim_ability,
         'Stalk': anim_tether}
