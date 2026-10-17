# Mummy (Guardian, Epic, Halloween featured pet) for Hatch or Snatch: HOS-HWN-001, built on the pet kit
# (docs/pets/Pet Pipeline Guide.md, docs/pets/PET_LESSONS.md). Brief (Hunter via the thread, 17 Oct): a bandage-wrapped
# mummy, edgy, one glowing eye through the wraps. Read through the floating-pet rule: it hovers, its lower body unravels
# into trailing bandage strips instead of legs.
# Build: a hunched wrapped torso tapering into a trailing bandage tail, a wrapped skull on a short neck, long reaching arms
# with clawed wrapped hands, loose bandage ends streaming from the wrists, head and back. Atlas: grimy dark linen in
# helical wraps with dark gaps, stains and tears. Face decal shell: wraps across the face with one torn gap and a single
# glowing slit eye under a heavy brow, a faint glow seeping from the covered eye, a dark jagged mouth gap.
# L2 "Tomb Warden": gold scarab amulet, gold arm cuffs, glowing hieroglyph wraps. L3 "Cursed Pharaoh": a striped nemes
# headdress with a gold cobra crest, a gold broad collar, an ankh orbiting behind, crimson eye.
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

NAME = 'Mummy'
SHARP_ANGLE = 40
NORMAL_STRENGTH = 2.2
TS = 1024
ATLAS = Atlas({
    'wrap': (0, 0, 1024, 384),      # body loft: u around (0 back seam), v tail tip -> neck
    'skull': (0, 384, 512, 256),    # head loft: u around, v chin -> crown
    'limb': (512, 384, 512, 256),   # arms / hands: v shoulder -> hand
    'strip': (0, 640, 512, 128),    # loose bandage ends: v root -> tip
    'claw': (512, 640, 128, 128),
    'gold': (640, 640, 384, 128),   # cuffs, amulet, collar, cobra, ankh
    'gem': (0, 768, 256, 128),      # scarab / collar gems
    'nemes': (256, 768, 512, 128),  # L3 headdress stripes: u across, v top -> bottom
})

GLOW = {1: ('2ee6ff', 'd8fbff'), 2: ('38ffd2', 'e4fff6'), 3: ('ff2a3c', 'ffd8dc')}


def bones_def():
    b = [
        ('Root', V(0, 0, 0), V(0, 0, 0.2), None),
        ('Body', V(0, 0.04, 0.5), V(0, 0, 0.9), 'Root'),
        ('Head', V(0, -0.04, 0.94), V(0, -0.04, 1.42), 'Body'),
        ('Wrap1', V(0, 0.12, 0.42), V(0, 0.34, 0.26), 'Body'),
        ('Wrap2', V(0, 0.34, 0.26), V(0, 0.56, 0.2), 'Wrap1'),
        ('Wrap3', V(0, 0.56, 0.2), V(0, 0.86, 0.26), 'Wrap2'),
        ('HeadStrip', V(0.1, 0.16, 1.3), V(0.2, 0.46, 1.2), 'Head'),
        ('BackStrip', V(-0.1, 0.24, 0.8), V(-0.2, 0.56, 0.6), 'Body'),
        ('Ankh', V(0, 0.42, 1.0), V(0, 0.42, 1.2), 'Body'),
    ]
    for s, x in (('L', 1), ('R', -1)):
        b += [
            ('ArmU.' + s, V(x * 0.3, -0.02, 0.84), V(x * 0.4, -0.3, 0.76), 'Body'),
            ('Hand.' + s, V(x * 0.4, -0.3, 0.76), V(x * 0.42, -0.5, 0.72), 'ArmU.' + s),
            ('Strip.' + s, V(x * 0.4, -0.34, 0.72), V(x * 0.44, -0.2, 0.42), 'Hand.' + s),
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


def torus(mb, region, c, normal, R, r, n_around, n_tube, w, part):
    normal = nrm(np.asarray(normal, float))
    a = nrm(np.cross(normal, V(0, 0, 1) if abs(normal[2]) < 0.9 else V(1, 0, 0)))
    b = np.cross(normal, a)
    cen = [np.asarray(c, float) + (a * math.cos(2 * math.pi * i / n_around) + b * math.sin(2 * math.pi * i / n_around)) * R
           for i in range(n_around + 1)]
    tube(mb, region, cen, [(r, r)] * len(cen), n_tube, [w] * len(cen), part, start='open', end='open',
         side_hint=normal, anti=False)


def strip(mb, pts, width, weights, part, twist=0.0):
    """a loose bandage ribbon through `pts`: a flat 4-sided loft that twists along its length, torn point at the end."""
    n = len(pts)
    sides = [V(math.cos(twist * i), 0.3 * math.sin(twist * i), math.sin(twist * i)) for i in range(n)]
    radii = [(width * 0.5 * (1 - 0.35 * i / (n - 1)), 0.026) for i in range(n)]
    ws = list(weights) + [weights[-1]] * (n - len(weights))
    vv = _cum(pts)
    f0 = len(mb.F)
    loft(mb, pts, radii, 4, ws, lambda i, k, seg, fk: ATLAS.uv('strip', k / 4, 0.04 + 0.9 * vv[i]), part,
         start='flat', end='point', end_pt=np.asarray(pts[-1], float) + nrm(np.asarray(pts[-1], float) - np.asarray(pts[-2], float)) * 0.06,
         profile=lambda k, nn, a, b, i: (a * math.cos(math.pi / 4 + k * math.pi / 2) * 1.41, b * math.sin(math.pi / 4 + k * math.pi / 2) * 1.41),
         side_hint=sides)
    # the loft orients faces against the segment centre, which lies in the ribbon's own plane: re-orient each face
    # outward from the nearest point on the centreline so both sides shade
    P = [np.asarray(q, float) for q in pts]
    for fi in range(f0, len(mb.F)):
        f = mb.F[fi]
        c = sum(mb.V[v] for v in f) / len(f)
        nrml = np.cross(mb.V[f[1]] - mb.V[f[0]], mb.V[f[2]] - mb.V[f[0]])
        best, bd = None, 1e9
        for q0, q1 in zip(P, P[1:]):
            d = q1 - q0
            t = min(1.0, max(0.0, float(np.dot(c - q0, d) / np.dot(d, d))))
            q = q0 + d * t
            if np.linalg.norm(c - q) < bd:
                best, bd = q, np.linalg.norm(c - q)
        if np.dot(nrml, c - best) < 0:
            mb.F[fi] = f[::-1]
            mb.UV[fi] = mb.UV[fi][::-1]


FX, FZ, FZH = 0.3, 1.17, 0.24
HZ = 1.17


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
    sel = [fi for fi in head_faces if all(mb.V[v][1] < -0.16 and 0.98 < mb.V[v][2] < 1.38 for v in mb.F[fi])]
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


STATIONS = [
    (V(0, 0.92, 0.3), (0.04, 0.03), {'Wrap3': 1}),
    (V(0, 0.76, 0.22), (0.09, 0.07), {'Wrap3': 1}),
    (V(0, 0.56, 0.2), (0.14, 0.11), {'Wrap2': 0.7, 'Wrap3': 0.3}),
    (V(0, 0.36, 0.25), (0.19, 0.16), {'Wrap1': 0.6, 'Wrap2': 0.4}),
    (V(0, 0.18, 0.36), (0.25, 0.21), {'Wrap1': 0.5, 'Body': 0.5}),
    (V(0, 0.07, 0.52), (0.28, 0.24), {'Body': 1}),
    (V(0, 0.03, 0.68), (0.33, 0.26), {'Body': 1}),
    (V(0, 0.03, 0.82), (0.36, 0.27), {'Body': 1}),
    (V(0, 0.02, 0.92), (0.24, 0.2), {'Body': 0.7, 'Head': 0.3}),
]


def build():
    mb = MB()
    mb.mat = 0
    W_B, W_H = {'Body': 1}, {'Head': 1}
    tube(mb, 'wrap', [s[0] for s in STATIONS], [s[1] for s in STATIONS], 14, [s[2] for s in STATIONS], 'body',
         start='point', end='point', start_pt=V(0, 1.0, 0.36), end_pt=V(0, 0.02, 0.98), side_hint=V(1, 0, 0), th0=math.pi / 2)
    # wrapped skull, slightly forward (hunched), narrow jaw
    n0 = len(mb.F)
    hc = V(0, -0.08, HZ)
    hs = [(hc + V(0, -0.03, -0.24), (0.09, 0.08)), (hc + V(0, -0.02, -0.17), (0.15, 0.15)), (hc + V(0, -0.01, -0.06), (0.21, 0.21)),
          (hc + V(0, -0.01, 0.06), (0.24, 0.23)), (hc + V(0, 0.01, 0.17), (0.21, 0.2)), (hc + V(0, 0.03, 0.26), (0.12, 0.12))]
    tube(mb, 'skull', [h[0] for h in hs], [h[1] for h in hs], 14, [W_H] * len(hs), 'head', start='point', end='point',
         start_pt=hc + V(0, -0.03, -0.28), end_pt=hc + V(0, 0.03, 0.3), side_hint=V(1, 0, 0), anti=False, th0=math.pi / 2)
    head_faces = list(range(n0, len(mb.F)))
    # neck
    tube(mb, 'limb', [V(0, -0.02, 0.88), V(0, -0.05, 1.0)], [(0.12, 0.11), (0.11, 0.1)], 8, [W_B, W_H], 'neck',
         start='open', end='open', anti=False)
    # hunched shoulders: a raised bandage hump on each side
    for x in (1, -1):
        tube(mb, 'wrap', [V(x * 0.16, 0.06, 0.88), V(x * 0.28, 0.02, 0.88), V(x * 0.36, 0.0, 0.82)], [(0.1, 0.1), (0.12, 0.11), (0.1, 0.1)],
             8, [W_B] * 3, 'shoulder', start='point', end='point', anti=False)
    # long reaching arms with clawed wrapped hands
    cb, ct = ATLAS.uv('claw', 0.5, 0.15), ATLAS.uv('claw', 0.5, 0.9)
    for s, x in (('L', 1), ('R', -1)):
        au, h = 'ArmU.' + s, 'Hand.' + s
        arm = [(V(x * 0.3, 0.0, 0.84), (0.095, 0.095), {'Body': 0.5, au: 0.5}), (V(x * 0.36, -0.16, 0.8), (0.085, 0.085), {au: 1}),
               (V(x * 0.4, -0.3, 0.76), (0.075, 0.075), {au: 0.5, h: 0.5}), (V(x * 0.42, -0.42, 0.74), (0.07, 0.065), {h: 1}),
               (V(x * 0.43, -0.5, 0.72), (0.08, 0.05), {h: 1})]
        tube(mb, 'limb', [a[0] for a in arm], [a[1] for a in arm], 8, [a[2] for a in arm], 'arm' + s,
             start='point', end='point', start_pt=V(x * 0.24, 0.02, 0.86), end_pt=V(x * 0.43, -0.55, 0.71))
        for dx in (-0.045, -0.015, 0.015, 0.045):
            b0 = V(x * 0.43 + dx, -0.52, 0.72)
            bipyramid(mb, b0, b0 + V(dx * 0.6, -0.14, -0.08), V(1, 0, 0), V(0, 0, 1), 0.03, 0.03, {h: 1}, cb, ct, 'claw',
                      wide_at=0.3, ridge_at=0.3, curl=0.18)
        # loose bandage end trailing off the wrist
        strip(mb, [V(x * 0.42, -0.38, 0.72), V(x * 0.46, -0.32, 0.58), V(x * 0.48, -0.22, 0.46), V(x * 0.5, -0.12, 0.36)], 0.08,
              [{'Strip.' + s: 1}] * 3, 'strip', twist=0.5)
    # loose ends off the head and back, plus ragged strips peeling off the tail
    strip(mb, [V(0.12, 0.12, 1.3), V(0.2, 0.3, 1.28), V(0.26, 0.48, 1.18), V(0.3, 0.62, 1.04)], 0.09, [{'HeadStrip': 1}] * 3,
          'strip', twist=0.4)
    strip(mb, [V(-0.12, 0.24, 0.8), V(-0.2, 0.42, 0.72), V(-0.26, 0.56, 0.56), V(-0.28, 0.66, 0.4)], 0.1, [{'BackStrip': 1}] * 3,
          'strip', twist=-0.4)
    for x, wb in ((1, 'Wrap2'), (-1, 'Wrap3')):
        strip(mb, [V(x * 0.1, 0.5, 0.22), V(x * 0.22, 0.68, 0.16), V(x * 0.3, 0.84, 0.18)], 0.09, [{wb: 1}] * 2, 'strip', twist=0.6)
    mb.mat = 1
    face_shell(mb, head_faces)
    # ---- L2 "Tomb Warden": gold cuffs, scarab amulet
    mb.mat = 2
    for s, x in (('L', 1), ('R', -1)):
        torus(mb, 'gold', V(x * 0.4, -0.3, 0.76), V(x * 0.15, -1, -0.2), 0.085, 0.022, 10, 4, {'Hand.' + s: 1}, 'L2')
        torus(mb, 'gold', V(x * 0.33, -0.06, 0.83), V(x * 0.3, -1, -0.15), 0.1, 0.02, 10, 4, {'ArmU.' + s: 1}, 'L2')
    # scarab on a cord: gem body + gold wings
    sc = V(0, -0.27, 0.72)
    tube(mb, 'gem', [sc + V(0, 0, 0.06), sc, sc + V(0, 0, -0.06)], [(0.035, 0.02), (0.05, 0.03), (0.03, 0.02)], 8, [W_B] * 3, 'L2',
         start='point', end='point', anti=False)
    gb, gt = ATLAS.uv('gold', 0.3, 0.4), ATLAS.uv('gold', 0.8, 0.6)
    for x in (1, -1):
        bipyramid(mb, sc + V(x * 0.02, 0, 0.02), sc + V(x * 0.15, 0.02, 0.07), V(0, 0, 1), V(0, -1, 0), 0.07, 0.02, W_B, gb, gt, 'L2',
                  wide_at=0.35, ridge_at=0.35)
    torus(mb, 'gold', V(0, -0.08, 0.86), V(0, 0.3, 1), 0.2, 0.008, 12, 3, W_B, 'L2')
    # ---- L3 "Cursed Pharaoh": nemes headdress, cobra crest, broad collar, orbiting ankh
    mb.mat = 3
    nb, nt = ATLAS.uv('nemes', 0.5, 0.05), ATLAS.uv('nemes', 0.5, 0.95)
    # headdress cap (a shell over the crown) + two lappets down the front of the shoulders + a back tail
    cap = [(hc + V(0, 0.0, 0.0), (0.285, 0.265)), (hc + V(0, 0.01, 0.1), (0.27, 0.25)), (hc + V(0, 0.02, 0.19), (0.21, 0.2)),
           (hc + V(0, 0.03, 0.26), (0.11, 0.1))]
    tube(mb, 'nemes', [c[0] for c in cap], [c[1] for c in cap], 14, [W_H] * 4, 'L3', start='open', end='point',
         end_pt=hc + V(0, 0.03, 0.3), side_hint=V(1, 0, 0), anti=False, th0=math.pi / 2)
    for x in (1, -1):
        bipyramid(mb, hc + V(x * 0.25, -0.02, 0.02), V(x * 0.26, -0.14, 0.72), V(0, -1, 0), V(x, 0, 0), 0.2, 0.05,
                  [W_H, W_B, W_H, W_H, W_H, W_H], nb, nt, 'L3', wide_at=0.3, ridge_at=0.3)
    bipyramid(mb, hc + V(0, 0.2, 0.0), V(0, 0.36, 0.7), V(1, 0, 0), V(0, 1, 0), 0.26, 0.05, [W_H, W_B] + [W_H] * 4, nb, nt, 'L3',
              wide_at=0.3, ridge_at=0.3)
    # cobra crest rising off the brow
    cobra = [hc + V(0, -0.24, 0.12), hc + V(0, -0.27, 0.2), hc + V(0, -0.25, 0.28), hc + V(0, -0.29, 0.33)]
    tube(mb, 'gold', cobra, [(0.025, 0.025), (0.03, 0.025), (0.045, 0.02), (0.03, 0.02)], 6, [W_H] * 4, 'L3', start='point', end='point',
         end_pt=hc + V(0, -0.33, 0.33), anti=False)
    # broad collar: a gold ring on the chest with gem studs
    torus(mb, 'gold', V(0, -0.02, 0.86), V(0, 0.15, 1), 0.27, 0.04, 14, 4, W_B, 'L3')
    for k in range(5):
        a = math.radians(-150 + k * 30)
        p = V(0, -0.02, 0.86) + V(math.cos(a) * 0.29, math.sin(a) * 0.29, -0.03)
        bipyramid(mb, p, p + V(0, -0.02, -0.08), V(1, 0, 0), V(0, -1, 0), 0.05, 0.03, W_B, ATLAS.uv('gem', 0.4, 0.4),
                  ATLAS.uv('gem', 0.6, 0.6), 'L3', wide_at=0.4, ridge_at=0.4)
    # ankh orbiting behind (Ankh bone spins it)
    ac = V(0, 0.48, 1.08)
    tube(mb, 'gold', [ac + V(0, 0, -0.04), ac + V(0, 0, -0.32)], [(0.025, 0.025)] * 2, 6, [{'Ankh': 1}] * 2, 'L3', start='flat',
         end='flat', anti=False)
    tube(mb, 'gold', [ac + V(-0.12, 0, -0.1), ac + V(0.12, 0, -0.1)], [(0.022, 0.022)] * 2, 6, [{'Ankh': 1}] * 2, 'L3',
         start='flat', end='flat', anti=False)
    torus(mb, 'gold', ac + V(0, 0, 0.04), V(0, 1, 0), 0.075, 0.022, 10, 4, {'Ankh': 1}, 'L3')
    mb.mat = 0
    return mb


# ---------------------------------------------------------------- painting
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


def _linen(level):
    if level == 3:
        return [(0, '161008'), (0.5, '4a3a26'), (1, '8a7452')]
    if level == 2:
        return [(0, '12100c'), (0.5, '443c30'), (1, '7e7260')]
    return [(0, '100e0b'), (0.5, '3e362c'), (1, '766a58')]


def _wraps(v, u, n, tilt, seed_h, seed_w, level, glyph=False):
    """helical bandage bands: returns colour, height, band-gap mask, glyph glow."""
    h, w = v.shape
    wob = vnoise(h, w, 6, seed_h + 5) - 0.5
    ph = v * n + u * tilt + 0.9 * wob
    band = _saw(ph)                                  # 1 mid band .. 0 at the gap
    jit = vnoise(h, w, 20, seed_h) - 0.5
    gap = ss(0.16, 0.05, band + 0.14 * jit)
    # crossing straps in patches (bands wound the other way over the top)
    ph2 = v * n * 0.55 - u * tilt * 2.2 + 0.7 * wob
    patch = ss(0.5, 0.62, vnoise(h, w, 5, seed_h + 7))
    band2 = _saw(ph2)
    strap = ss(0.3, 0.4, band2) * patch
    gap = gap * (1 - strap) + ss(0.16, 0.05, band2) * patch * ss(0.2, 0.3, band2) * 0.0
    edge2 = ss(0.36, 0.3, band2) * ss(0.24, 0.3, band2) * patch
    band = band * (1 - strap) + band2 * strap
    gap = np.clip(gap + edge2, 0, 1)
    over = ss(0.02, 0.0, np.abs(_saw(ph * 0.5 + 0.25) - 0.5) - 0.48)      # overlapping band edges (raised lip)
    st = _streaks(h, w, 160, seed_w)
    stain = ss(0.55, 0.75, vnoise(h, w, 10, seed_h + 3))
    c = grad(np.clip(0.35 + 0.5 * band + 0.6 * st, 0, 1), _linen(level))
    c = c * (1 - 0.45 * stain[..., None]) + hx('1a120a') * 0.45 * stain[..., None]
    c = c * (1 - 0.85 * gap[..., None]) + hx('080605') * 0.85 * gap[..., None]
    c = c * (1 + 0.25 * over[..., None])
    gl = np.zeros_like(v)
    if glyph:                                        # small glowing hieroglyph dashes along some bands
        cell = _saw(u * 18 + np.floor(ph) * 0.37)
        gl = ss(0.06, 0.0, np.abs(band - 0.6) - 0.05) * ss(0.7, 0.85, cell) * ss(0.55, 0.7, vnoise(h, w, 8, seed_h + 9))
    hgt = 0.5 + 0.35 * band - 0.35 * gap + 0.2 * st + 0.1 * over
    return c, hgt, gap, gl


def paint_atlas(level):
    col = np.zeros((TS, TS, 3), np.float32)
    hgt = np.full((TS, TS), 0.5, np.float32)
    rgh = np.full((TS, TS), 0.8, np.float32)
    glow = np.zeros((TS, TS), np.float32)
    gc, ghi = GLOW[level]
    for reg, n, tilt, s1, s2 in (('wrap', 22, 3.0, 81, 82), ('skull', 12, 2.0, 83, 84), ('limb', 16, 3.0, 85, 86)):
        (y0, y1, x0, x1), v, u = _reg(reg)
        c, hh, gap, gl = _wraps(v, u, n, tilt, s1, s2, level, glyph=(level >= 2 and reg != 'skull'))
        # deep gaps seep a faint curse glow at L1 too (sparse)
        seep = gap * ss(0.88, 0.95, vnoise(y1 - y0, x1 - x0, 14, s1 + 20)) * 0.6
        g = np.clip(gl + seep, 0, 1)
        col[y0:y1, x0:x1] = c * (1 - g[..., None]) + hx(gc) * g[..., None]
        hgt[y0:y1, x0:x1] = hh
        glow[y0:y1, x0:x1] = g
    # ---- loose strips: frayed, darker toward the torn tip
    (y0, y1, x0, x1), v, u = _reg('strip')
    st = _streaks(y1 - y0, x1 - x0, 60, 87)
    fray = ss(0.0, 0.04, v - (0.84 + 0.1 * _saw(u * 9)))
    c = grad(np.clip(0.85 - 0.3 * v + 0.6 * st, 0, 1), _linen(level)) * (1 - 0.6 * fray[..., None])
    col[y0:y1, x0:x1] = c
    hgt[y0:y1, x0:x1] = 0.5 + 0.3 * st
    # ---- claws: black, curse-glow tips from L2
    (y0, y1, x0, x1), v, u = _reg('claw')
    t = ss(0.6, 0.9, v) * (0.0 if level == 1 else 1.0)
    col[y0:y1, x0:x1] = hx('0e0b08') * (1 - t[..., None]) + hx(gc) * t[..., None]
    rgh[y0:y1, x0:x1] = 0.35
    glow[y0:y1, x0:x1] = t
    # ---- gold: tarnished, darker in the grooves
    (y0, y1, x0, x1), v, u = _reg('gold')
    rib = 0.5 + 0.5 * np.cos(u * 2 * math.pi * 6)
    col[y0:y1, x0:x1] = grad(np.clip(0.3 + 0.5 * np.cos((u - 0.5) * 2 * math.pi) ** 2 + 0.2 * rib, 0, 1), [(0, '3a2408'), (0.6, 'a87a28'), (1, 'f0cc6a')])
    rgh[y0:y1, x0:x1] = 0.3
    hgt[y0:y1, x0:x1] = 0.5 + 0.2 * rib
    # ---- gems: deep curse-coloured glass with a glowing core
    (y0, y1, x0, x1), v, u = _reg('gem')
    r = np.sqrt((u - 0.5) ** 2 + (v - 0.5) ** 2) * 2
    col[y0:y1, x0:x1] = grad(np.clip(1 - r, 0, 1), [(0, '04121a' if level < 3 else '1a0408'), (0.6, gc), (1, ghi)])
    rgh[y0:y1, x0:x1] = 0.1
    glow[y0:y1, x0:x1] = np.clip(1 - r, 0, 1) * 0.8
    # ---- nemes: black and gold stripes (horizontal bands down the headdress), a glowing trim line
    (y0, y1, x0, x1), v, u = _reg('nemes')
    stp = ss(0.02, 0.0, np.abs(_saw(v * 9) - 0.5) - 0.25)
    c = hx('0c0a10') * (1 - stp[..., None]) + hx('b88a2c') * stp[..., None] * (0.85 + 0.3 * np.cos((u - 0.5) * 2 * math.pi) ** 2)[..., None]
    col[y0:y1, x0:x1] = c
    rgh[y0:y1, x0:x1] = 0.45 - 0.15 * stp
    hgt[y0:y1, x0:x1] = 0.5 + 0.15 * stp
    paint_atlas._glow = np.clip(glow, 0, 1)
    return np.clip(col, 0, 1), hgt, rgh


def emissive_mask(level):
    paint_atlas(level)
    return np.repeat(paint_atlas._glow[..., None], 3, -1)


# ---------------------------------------------------------------- face decal: wraps over the face, one torn gap, one eye
def _seg(X, Z, a, b, w0, w1):
    ax, az = a; bx, bz = b
    dx, dz = bx - ax, bz - az
    L2 = dx * dx + dz * dz
    t = np.clip(((X - ax) * dx + (Z - az) * dz) / L2, 0, 1)
    d = np.sqrt((X - ax - t * dx) ** 2 + (Z - az - t * dz) ** 2)
    wd = w0 + (w1 - w0) * t
    return ss(wd, wd - 0.003, d)


EYE_X = -0.1     # the open eye: the mummy's right (viewer's left)


def _face_layers(level, size):
    x, y = coords(size)
    X, Z = x * FX, FZ + y * FZH
    # torn gap in the wraps around the open eye: a jagged dark hollow
    gx, gz = EYE_X, 1.2
    jag = 0.012 * _saw(np.arctan2(Z - gz, X - gx) * 5)
    gap = ss(0.004, 0.0, np.sqrt(((X - gx) / 0.11) ** 2 + ((Z - gz) / 0.055) ** 2) - 1 + jag * 6)
    # the eye: a narrow slit slanting down toward the nose (inner corner low), glowing, with a dark slit pupil
    ix, iz, ox, oz = -0.03, 1.185, -0.18, 1.225
    ex, ez = ox - ix, oz - iz
    L = math.hypot(ex, ez)
    s = ((X - ix) * ex + (Z - iz) * ez) / (L * L)
    d = (-(X - ix) * ez + (Z - iz) * ex) / L
    sc = np.clip(s, 0, 1)
    top = 0.024 * np.clip(sc * 3.0, 0, 1) * (1 - sc ** 4) + 0.002
    bot = -0.016 * np.clip(np.sin(math.pi * sc), 0, 1) ** 0.9 - 0.001
    inside = (s > 0) & (s < 1)
    eye = ss(0.003, 0.0, np.maximum(-d - top, bot + d)) * inside
    cxs, czs = ix + 0.55 * ex, iz + 0.55 * ez
    rr = np.sqrt((X - cxs) ** 2 + (Z - czs) ** 2)
    _face_layers.rr = rr
    slit = ss(0.005 * np.clip(1 - ((Z - czs) / 0.03) ** 2, 0, 1) + 0.0005, 0.0, np.abs(X - cxs)) * ss(0.03, 0.025, rr)
    brow = _seg(X, Z, (-0.01, 1.215), (-0.2, 1.27), 0.012, 0.004)
    # the covered eye: wraps over it, a thin line of light seeping through a crack
    seep = _seg(X, Z, (0.04, 1.2), (0.17, 1.235), 0.006, 0.002)
    # face wraps: diagonal bands with dark gaps (drawn on the shell so they overlap the gap edge)
    ph = (Z * 22 + X * 7)
    band_gap = ss(0.14, 0.05, _saw(ph)) * (1 - gap)
    # mouth: a dark jagged gap between wraps
    mouth = ss(0.004, 0.0, np.abs(Z - (1.02 + 0.008 * _saw(X / 0.03))) - 0.012) * ss(0.13, 0.11, np.abs(X))
    marks = np.zeros_like(X)
    if level >= 2:   # glyph mark over the covered eye
        marks = np.maximum(_seg(X, Z, (0.1, 1.28), (0.1, 1.32), 0.006, 0.006), _seg(X, Z, (0.07, 1.3), (0.13, 1.3), 0.005, 0.005))
    if level >= 3:   # a second, smaller glowing crack under the open eye
        marks = np.maximum(marks, _seg(X, Z, (-0.14, 1.16), (-0.18, 1.1), 0.006, 0.001))
    return X, Z, gap, eye, slit, brow, seep, band_gap, mouth, marks


def face_texture(level, size=512):
    X, Z, gap, eye, slit, brow, seep, band_gap, mouth, marks = _face_layers(level, size)
    gc, ghi = GLOW[level]
    rr_ = _face_layers.rr
    rgba = np.zeros((size, size, 4), np.float32)
    c = np.zeros((size, size, 3), np.float32) + hx('050403')
    irisc = grad(np.clip(1 - rr_ / 0.03, 0, 1), [(0, gc), (0.6, ghi), (1, 'ffffff')])
    e = irisc * (1 - slit[..., None]) + hx('020202') * slit[..., None]
    c = c * (1 - eye[..., None]) + e * eye[..., None]
    c = c * (1 - seep[..., None]) + hx(gc) * seep[..., None]
    c = c * (1 - marks[..., None]) + hx(gc) * marks[..., None]
    rgba[..., :3] = c
    a = np.maximum.reduce([gap, eye, brow, seep, band_gap * 0.8, mouth, marks])
    rgba[..., 3] = np.clip(a, 0, 1)
    return rgba


def face_emissive(level, size=512):
    X, Z, gap, eye, slit, brow, seep, band_gap, mouth, marks = _face_layers(level, size)
    halo = gap * (1 - eye) * 0.15
    g = np.clip(np.maximum.reduce([eye * (1 - slit), seep * 0.8, marks * 0.9, halo]), 0, 1)
    return np.repeat(g[..., None], 3, -1)


# ---------------------------------------------------------------- animation (24 fps, it floats)
def _ease(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def _pulse(t, a, b):
    if t <= a or t >= b:
        return 0.0
    return math.sin(math.pi * (t - a) / (b - a))


def _trail(w, amp, pitch=0.0):
    return {'Wrap1': P(('x', -pitch * 0.4), ('z', amp * math.sin(w))),
            'Wrap2': P(('x', -pitch * 0.3), ('z', amp * 1.3 * math.sin(w - 0.9))),
            'Wrap3': P(('x', -pitch * 0.2), ('z', amp * 1.6 * math.sin(w - 1.8))),
            'Strip.L': P(('x', 10 * math.sin(w + 0.5)), ('z', 8 * math.sin(w))), 'Strip.R': P(('x', 10 * math.sin(w + 1.5)), ('z', -8 * math.sin(w))),
            'HeadStrip': P(('z', 12 * math.sin(w + 0.3)), ('x', 6 * math.sin(w * 2))),
            'BackStrip': P(('z', -12 * math.sin(w + 1.0)), ('x', 6 * math.sin(w * 2 + 1)))}


def anim_idle():
    """3 s loop: a slow, heavy bob, arms half-raised and swaying, the head lolls and snaps to stare, strips drift."""
    F = 72
    keys = {}
    for f in range(0, F + 1, 3):
        t = f / F
        w = 2 * math.pi * t
        snap = _pulse(t, 0.4, 0.55)
        k = {'Body': P(('x', 8 + 2 * math.sin(w)), ('y', 3 * math.sin(w * 0.5)), loc=(0, 0, 0.07 * math.sin(w))),
             'Head': P(('x', -4 + 4 * math.sin(w)), ('y', 10 * math.sin(w * 0.5 + 0.4) * (1 - snap)), ('z', -14 * snap)),
             'ArmU.L': P(('x', -8 + 6 * math.sin(w)), ('z', -6)), 'ArmU.R': P(('x', -8 + 6 * math.sin(w + 0.6)), ('z', 6)),
             'Hand.L': P(('x', 10 + 10 * math.sin(w + 1))), 'Hand.R': P(('x', 10 + 10 * math.sin(w + 1.6))),
             'Ankh': P(('z', 360 * t), loc=(0, 0, 0.04 * math.sin(w)))}
        k.update(_trail(w, 12))
        keys[f] = k
    keys[F] = dict(keys[0])
    keys[F]['Ankh'] = P(('z', 0))
    return {'frames': F, 'loop': True, 'keys': keys}


def _fly(frames, pitch, sway):
    keys = {}
    for f in range(0, frames + 1, 2):
        t = f / frames
        w = 2 * math.pi * t
        k = {'Body': P(('x', pitch + 3 * math.sin(w + 0.6)), loc=(0, 0, 0.05 * math.sin(w - 1.2))),
             'Head': P(('x', -pitch * 0.7)),
             'ArmU.L': P(('x', -pitch * 0.5 + 4 * math.sin(w)), ('z', -4)), 'ArmU.R': P(('x', -pitch * 0.5 + 4 * math.sin(w + 0.5)), ('z', 4)),
             'Ankh': P(('x', -pitch * 0.4))}
        k.update(_trail(w, sway, pitch * 1.3))
        keys[f] = k
    keys[frames] = dict(keys[0])
    return {'frames': frames, 'loop': True, 'keys': keys}


def anim_walk():
    return _fly(24, 22, 12)


def anim_run():
    return _fly(16, 40, 18)


def anim_hop():
    keys = {}
    F = 16
    for f in range(0, F + 1, 2):
        t = f / F
        crouch = _pulse(t, 0.0, 0.3)
        up = _pulse(t, 0.2, 1.0)
        keys[f] = {'Body': P(('x', 12 * crouch - 8 * up), loc=(0, 0, -0.08 * crouch + 0.3 * up)),
                   'ArmU.L': P(('x', -40 * up)), 'ArmU.R': P(('x', -40 * up)),
                   'Wrap1': P(('x', 25 * up)), 'Wrap2': P(('x', 20 * up)), 'Wrap3': P(('x', 15 * up))}
    return {'frames': F, 'loop': False, 'keys': keys}


def anim_ability():
    """Shield (~1 s, Runner): crosses both arms over its chest and hunches, then throws them wide as the bandage
    wrap whips round it (the shield goes up here), strips flaring out, and settles."""
    keys = {}
    F = 24
    for f in range(0, F + 1, 2):
        t = f / F
        cross = _ease(t / 0.35) * (1 - _ease((t - 0.45) / 0.1))
        throw = _ease((t - 0.45) / 0.1) * (1 - _ease((t - 0.8) / 0.2))
        keys[f] = {'Body': P(('x', 18 * cross - 12 * throw), loc=(0, 0, -0.06 * cross + 0.1 * throw)),
                   'Head': P(('x', 14 * cross - 20 * throw)),
                   'ArmU.L': P(('z', -70 * cross), ('y', -70 * throw), ('x', -10 * cross)),
                   'ArmU.R': P(('z', 70 * cross), ('y', 70 * throw), ('x', -10 * cross)),
                   'Hand.L': P(('x', -30 * cross)), 'Hand.R': P(('x', -30 * cross)),
                   'Strip.L': P(('y', -60 * throw)), 'Strip.R': P(('y', 60 * throw)),
                   'HeadStrip': P(('z', 50 * throw)), 'BackStrip': P(('z', -50 * throw)),
                   'Wrap1': P(('z', 30 * math.sin(6 * t))), 'Wrap2': P(('z', 40 * math.sin(6 * t - 1))),
                   'Wrap3': P(('z', 50 * math.sin(6 * t - 2))), 'Ankh': P(('z', 540 * t))}
    return {'frames': F, 'loop': False, 'keys': keys}


def anim_lash():
    """Lash (~0.75 s, Catcher): winds the right arm back, whips it forward (the bandage tether lashes out), then hauls
    back hand over hand."""
    keys = {}
    F = 18
    for f in range(0, F + 1):
        t = f / F
        wind = _ease(t / 0.3) * (1 - _ease((t - 0.3) / 0.1))
        whip = _ease((t - 0.3) / 0.08) * (1 - _ease((t - 0.55) / 0.12))
        haul = _ease((t - 0.55) / 0.12) * (1 - _ease((t - 0.82) / 0.18))
        keys[f] = {'Body': P(('x', -10 * wind + 20 * whip - 14 * haul), ('z', 16 * wind - 10 * whip),
                             loc=(0, 0.08 * wind - 0.2 * whip + 0.14 * haul, 0)),
                   'Head': P(('x', -8 * wind + 8 * whip)),
                   'ArmU.R': P(('x', 50 * wind - 80 * whip - 40 * haul), ('z', -40 * wind + 20 * whip)),
                   'Hand.R': P(('x', 30 * wind - 30 * whip + 30 * haul)),
                   'ArmU.L': P(('x', -30 * haul)), 'Hand.L': P(('x', 20 * haul)),
                   'Strip.R': P(('x', -60 * whip + 30 * haul)), 'Strip.L': P(('x', 20 * haul)),
                   'Wrap1': P(('x', 20 * whip)), 'Wrap2': P(('x', 15 * whip)), 'Wrap3': P(('x', 12 * whip))}
    return {'frames': F, 'loop': False, 'keys': keys}


ANIMS = {'Idle': anim_idle, 'Walk': anim_walk, 'Run': anim_run, 'Hop': anim_hop, 'Ability': anim_ability,
         'Lash': anim_lash}
