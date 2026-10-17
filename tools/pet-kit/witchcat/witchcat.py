# Witch's Cat (Decoy, Epic, Halloween featured pet) for Hatch or Snatch: HOS-HWN-001, built on the pet kit
# (docs/pets/Pet Pipeline Guide.md, docs/pets/PET_LESSONS.md). Brief (Hunter via the thread, 17 Oct): a black cat in a
# pointed witch hat floating on a broomstick, narrow green slit eyes. Anime / edgy: sly, never cute.
# Build: a lean crouched black cat riding a broom (it never walks: the broom floats), tall swept ears, a long hooked
# tail, a crooked witch hat with a bent tip and a frayed brim, a twig broom with a bound bristle bundle.
# Face decal shell: narrow slanted green slit eyes under a heavy brow, a dark mask, a thin one-sided smirk with a fang.
# L2 "Hex Familiar": a hat band with a gold buckle and a green rune, a crescent charm off the hat tip, a potion vial
# hanging off the broom, glowing whisker marks. L3 "Coven Queen": a tattered violet cape, two extra tails (forked like
# a nekomata), green hex flame in the bristles, a moon emblem on the hat, gold-green eyes.
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

NAME = 'WitchCat'
SHARP_ANGLE = 40
NORMAL_STRENGTH = 2.0
TS = 1024
ATLAS = Atlas({
    'fur': (0, 0, 1024, 256),       # torso loft: u around (0 = top seam), v rear -> neck
    'head': (0, 256, 512, 256),     # head loft: u around, v back of head -> muzzle
    'hat': (512, 256, 512, 256),    # hat cone: u around, v brim -> tip; brim uses the lower band
    'limb': (0, 512, 512, 128),     # paws, haunches, tail
    'ear': (512, 512, 256, 128),    # v root -> tip
    'haft': (768, 512, 256, 128),   # broom haft: v back -> front
    'bristle': (0, 640, 512, 128),  # v root -> tip
    'band': (512, 640, 256, 128),   # L2 hat band, broom bindings
    'gold': (768, 640, 256, 128),   # buckle, charm
    'glass': (0, 768, 256, 128),    # L2 potion vial
    'cape': (256, 768, 512, 128),   # L3 cape blades
    'fire': (768, 768, 256, 128),   # L3 hex flame
    'claw': (0, 896, 128, 128),
})

GLOW = {1: ('3dff6a', 'd8ffe0'), 2: ('5aff4a', 'eaffd8'), 3: ('9cff3a', 'faffe0')}   # hex green per level


def bones_def():
    b = [
        ('Root', V(0, 0, 0), V(0, 0, 0.2), None),
        ('Broom', V(0, 0.0, 0.36), V(0, -0.3, 0.36), 'Root'),
        ('Bristle', V(0, 0.5, 0.33), V(0, 0.9, 0.3), 'Broom'),
        ('Body', V(0, 0.16, 0.5), V(0, -0.16, 0.84), 'Broom'),
        ('Head', V(0, -0.2, 0.9), V(0, -0.3, 1.12), 'Body'),
        ('Hat', V(0, -0.22, 1.2), V(0, -0.18, 1.45), 'Head'),
        ('HatTip', V(0, -0.14, 1.5), V(0, 0.1, 1.72), 'Hat'),
        ('Tail1', V(0, 0.3, 0.5), V(0, 0.52, 0.58), 'Body'),
        ('Tail2', V(0, 0.52, 0.58), V(0, 0.66, 0.84), 'Tail1'),
        ('Tail3', V(0, 0.66, 0.84), V(0, 0.6, 1.1), 'Tail2'),
        ('Cape', V(0, -0.06, 0.86), V(0, 0.3, 0.6), 'Body'),
        ('Vial', V(0, -0.62, 0.34), V(0, -0.62, 0.2), 'Broom'),
    ]
    for s, x in (('L', 1), ('R', -1)):
        b += [('Ear.' + s, V(x * 0.13, -0.2, 1.14), V(x * 0.22, -0.16, 1.4), 'Head'),
              ('Paw.' + s, V(x * 0.1, -0.12, 0.72), V(x * 0.1, -0.24, 0.42), 'Body')]
    return b


def _cum(centers):
    c = [np.asarray(p, float) for p in centers]
    d = [0.0]
    for a, b in zip(c, c[1:]):
        d.append(d[-1] + float(np.linalg.norm(b - a)))
    return [x / max(d[-1], 1e-9) for x in d]


def tube(mb, region, centers, radii, n, weights, part, start='point', end='point', start_pt=None, end_pt=None,
         side_hint=None, anti=True, th0=-math.pi / 2, v_range=(0.0, 1.0)):
    vv = _cum(centers)

    def profile(k, nn, a, b, i):
        th = th0 + 2 * math.pi * (k + (0.5 if (anti and i % 2) else 0.0)) / nn
        return a * math.cos(th), b * math.sin(th)

    def uvf(i, k, seg, fk):
        return ATLAS.uv(region, k / n, v_range[0] + (v_range[1] - v_range[0]) * vv[i])
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


FX, FZ, FZH = 0.3, 1.0, 0.24
HEAD_Z = 1.0


def _vnormals(mb, faces):
    acc = {}
    for fi in faces:
        f = mb.F[fi]
        a, b, c = mb.V[f[0]], mb.V[f[1]], mb.V[f[2]]
        n = np.cross(b - a, c - a)
        for v in f:
            acc[v] = acc.get(v, np.zeros(3)) + n
    return {v: nrm(n) for v, n in acc.items()}


def face_shell(mb, head_faces, lift=0.008):
    sel = [fi for fi in head_faces if all(mb.V[v][1] < -0.33 for v in mb.F[fi])]
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
    W_B, W_H, W_BR = {'Body': 1}, {'Head': 1}, {'Broom': 1}
    # lean crouched torso: rear on the broom, chest raised
    body = [(V(0, 0.27, 0.5), (0.17, 0.15), W_B), (V(0, 0.15, 0.53), (0.23, 0.21), W_B), (V(0, 0.0, 0.6), (0.21, 0.2), W_B),
            (V(0, -0.11, 0.73), (0.18, 0.17), W_B), (V(0, -0.17, 0.85), (0.14, 0.13), {'Body': 0.6, 'Head': 0.4})]
    tube(mb, 'fur', [b[0] for b in body], [b[1] for b in body], 12, [b[2] for b in body], 'body', start='point',
         end='point', start_pt=V(0, 0.34, 0.5), end_pt=V(0, -0.2, 0.9), side_hint=V(1, 0, 0), th0=math.pi / 2)
    # head: loft from the back of the skull to a short muzzle (faces -y)
    n0 = len(mb.F)
    hz = HEAD_Z
    hs = [(V(0, -0.1, hz + 0.02), (0.13, 0.13)), (V(0, -0.17, hz + 0.02), (0.2, 0.18)), (V(0, -0.26, hz), (0.22, 0.18)),
          (V(0, -0.34, hz - 0.03), (0.16, 0.14)), (V(0, -0.41, hz - 0.06), (0.08, 0.07))]
    hv = _cum([h[0] for h in hs])

    def cheek(k, nn, a, b, i):                      # cheeks flare a little at the widest stations
        th = math.pi / 2 + 2 * math.pi * k / nn
        flare = 1 + 0.12 * max(0.0, abs(math.cos(th)) - 0.3) * (i in (1, 2))
        return a * math.cos(th) * flare, b * math.sin(th)
    loft(mb, [h[0] for h in hs], [h[1] for h in hs], 12, [W_H] * len(hs), lambda i, k, seg, fk: ATLAS.uv('head', k / 12, hv[i]),
         'head', start='point', end='point', start_pt=V(0, -0.06, hz + 0.02), end_pt=V(0, -0.46, hz - 0.08), profile=cheek,
         side_hint=V(1, 0, 0))
    head_faces = list(range(n0, len(mb.F)))
    # tall swept ears (pointed, a little outward and back), rooted inside the skull
    eb, et = ATLAS.uv('ear', 0.5, 0.1), ATLAS.uv('ear', 0.5, 0.94)
    for s, x in (('L', 1), ('R', -1)):
        bipyramid(mb, V(x * 0.13, -0.21, hz + 0.08), V(x * 0.36, -0.16, hz + 0.44), V(0, -1, 0), V(x, 0, 0.3), 0.2, 0.08,
                  {'Ear.' + s: 1}, eb, et, 'ear', wide_at=0.25, ridge_at=0.25)
    # sharp cheek tufts swept back (angular silhouette)
    for x in (1, -1):
        for dz, ln in ((0.0, 0.16), (-0.07, 0.12)):
            bipyramid(mb, V(x * 0.15, -0.27, hz - 0.03 + dz), V(x * (0.3 + ln * 0.3), -0.16, hz - 0.08 + dz * 1.5), V(0, 0, 1), V(0, -1, 0),
                      0.08, 0.04, W_H, ATLAS.uv('limb', 0.0, 0.3), ATLAS.uv('limb', 0.0, 0.7), 'ear', wide_at=0.3, ridge_at=0.3)
    # haunches (tucked hind legs) and front paws gripping the haft
    for x in (1, -1):
        tube(mb, 'limb', [V(x * 0.15, 0.24, 0.5), V(x * 0.19, 0.14, 0.48), V(x * 0.17, 0.0, 0.44)],
             [(0.08, 0.1), (0.1, 0.12), (0.07, 0.07)], 8, [W_B] * 3, 'haunch', start='point', end='point',
             start_pt=V(x * 0.13, 0.3, 0.52), end_pt=V(x * 0.15, -0.06, 0.41), anti=False)
    cb, ct = ATLAS.uv('claw', 0.5, 0.15), ATLAS.uv('claw', 0.5, 0.9)
    for s, x in (('L', 1), ('R', -1)):
        p = 'Paw.' + s
        tube(mb, 'limb', [V(x * 0.1, -0.1, 0.74), V(x * 0.11, -0.18, 0.58), V(x * 0.1, -0.24, 0.44)],
             [(0.06, 0.06), (0.05, 0.05), (0.06, 0.055)], 8, [{'Body': 0.5, p: 0.5}, {p: 1}, {p: 1}], 'paw', start='point',
             end='point', start_pt=V(x * 0.09, -0.06, 0.78), end_pt=V(x * 0.1, -0.28, 0.4), anti=False)
        for dx in (-0.03, 0.0, 0.03):
            b0 = V(x * 0.1 + dx, -0.27, 0.42)
            bipyramid(mb, b0, b0 + V(dx * 0.4, -0.06, -0.07), V(1, 0, 0), V(0, -1, 0), 0.025, 0.022, {p: 1}, cb, ct, 'claw',
                      wide_at=0.3, ridge_at=0.3, curl=0.1)
    # long tail hooking up behind
    tl = [(V(0, 0.3, 0.5), (0.055, 0.055), {'Body': 0.5, 'Tail1': 0.5}), (V(0, 0.46, 0.53), (0.05, 0.05), {'Tail1': 1}),
          (V(0, 0.6, 0.66), (0.048, 0.048), {'Tail2': 1}), (V(0, 0.66, 0.86), (0.045, 0.045), {'Tail2': 0.5, 'Tail3': 0.5}),
          (V(0, 0.62, 1.02), (0.04, 0.04), {'Tail3': 1}), (V(0, 0.54, 1.08), (0.03, 0.03), {'Tail3': 1})]
    tube(mb, 'limb', [t[0] for t in tl], [t[1] for t in tl], 6, [t[2] for t in tl], 'tail', start='point', end='point',
         end_pt=V(0, 0.48, 1.06), anti=False)
    # broom: haft along y with a slight upturn at the front, bound bristle bundle at the back
    hb = [V(0, 0.5, 0.33), V(0, 0.1, 0.36), V(0, -0.35, 0.37), V(0, -0.72, 0.42)]
    tube(mb, 'haft', hb, [(0.035, 0.035)] * 4, 6, [W_BR] * 4, 'haft', start='point', end='point',
         start_pt=V(0, 0.54, 0.33), end_pt=V(0, -0.78, 0.45), anti=False)
    tube(mb, 'bristle', [V(0, 0.46, 0.33), V(0, 0.6, 0.32), V(0, 0.82, 0.3)], [(0.07, 0.07), (0.12, 0.11), (0.18, 0.16)], 8,
         [{'Bristle': 1}] * 3, 'bristle', start='point', end='open', start_pt=V(0, 0.42, 0.33), anti=True)
    bb, bt = ATLAS.uv('bristle', 0.5, 0.2), ATLAS.uv('bristle', 0.5, 0.96)
    for k in range(9):
        a = 2 * math.pi * k / 9
        o = V(math.cos(a) * 0.12, 0, math.sin(a) * 0.11)
        bipyramid(mb, V(0, 0.66, 0.31) + o * 0.8, V(0, 1.0, 0.29) + o * 1.6 + V(0, 0.04 * (k % 3), 0), V(math.cos(a), 0, math.sin(a)),
                  V(-math.sin(a), 0, math.cos(a)), 0.09, 0.03, {'Bristle': 1}, bb, bt, 'bristle', wide_at=0.3, ridge_at=0.3)
    torus(mb, 'band', V(0, 0.48, 0.33), V(0, 1, 0), 0.075, 0.018, 8, 4, {'Bristle': 1}, 'binding')
    # witch hat: frayed brim + crooked cone with a bent tip, perched between the ears
    HC = V(0, -0.2, hz + 0.21)
    tube(mb, 'hat', [HC + V(0, 0, -0.012), HC + V(0, 0, 0.012)], [(0.27, 0.25), (0.27, 0.25)], 14, [{'Hat': 1}] * 2, 'brim',
         start='flat', end='flat', side_hint=V(1, 0, 0), anti=False, v_range=(0.0, 0.08))
    cone = [(HC + V(0, 0, 0.0), (0.17, 0.16), {'Hat': 1}), (HC + V(0, 0.02, 0.16), (0.14, 0.13), {'Hat': 1}),
            (HC + V(0, 0.06, 0.32), (0.1, 0.095), {'Hat': 0.5, 'HatTip': 0.5}), (HC + V(0, 0.14, 0.44), (0.07, 0.065), {'HatTip': 1}),
            (HC + V(0, 0.28, 0.5), (0.045, 0.04), {'HatTip': 1})]
    tube(mb, 'hat', [c[0] for c in cone], [c[1] for c in cone], 10, [c[2] for c in cone], 'cone', start='open', end='point',
         end_pt=HC + V(0, 0.42, 0.46), side_hint=V(1, 0, 0), v_range=(0.12, 1.0))
    # frayed brim: a few jagged points round the rim
    fb, ft = ATLAS.uv('hat', 0.5, 0.02), ATLAS.uv('hat', 0.5, 0.1)
    for k in range(7):
        a = 2 * math.pi * (k + 0.3) / 7
        d = V(math.cos(a), math.sin(a), 0)
        base = HC + V(d[0] * 0.23, d[1] * 0.21, 0)
        bipyramid(mb, base, base + d * 0.09 + V(0, 0, -0.02 - 0.02 * (k % 2)), V(-d[1], d[0], 0), V(0, 0, 1), 0.08, 0.02,
                  {'Hat': 1}, fb, ft, 'brim', wide_at=0.3, ridge_at=0.5)
    mb.mat = 1
    face_shell(mb, head_faces)
    # ---- L2 "Hex Familiar"
    mb.mat = 2
    torus(mb, 'band', HC + V(0, 0, 0.05), V(0, 0, 1), 0.165, 0.025, 12, 4, {'Hat': 1}, 'L2')
    gb, gt = ATLAS.uv('gold', 0.3, 0.3), ATLAS.uv('gold', 0.7, 0.7)
    bipyramid(mb, HC + V(0, -0.16, 0.0), HC + V(0, -0.17, 0.11), V(1, 0, 0), V(0, -1, 0), 0.09, 0.04, {'Hat': 1}, gb, gt, 'L2',
              wide_at=0.5, ridge_at=0.5)
    # crescent charm dangling off the bent tip
    tip = HC + V(0, 0.42, 0.46)
    tube(mb, 'gold', [tip + V(0, 0, -0.02), tip + V(0, 0.0, -0.12)], [(0.008, 0.008)] * 2, 4, [{'HatTip': 1}] * 2, 'L2',
         start='open', end='open', anti=False)
    cr = [tip + V(0.05 * math.cos(a), 0, -0.18 + 0.06 * math.sin(a)) for a in np.linspace(0.6, 2 * math.pi - 0.6, 6)]
    tube(mb, 'gold', cr, [(0.016, 0.016)] * len(cr), 4, [{'HatTip': 1}] * len(cr), 'L2', start='point', end='point', anti=False)
    # potion vial hanging off the broom front
    vb = V(0, -0.62, 0.38)
    tube(mb, 'band', [vb, vb + V(0, 0, -0.1)], [(0.006, 0.006)] * 2, 4, [{'Vial': 1}] * 2, 'L2', start='open', end='open', anti=False)
    tube(mb, 'glass', [vb + V(0, 0, -0.1), vb + V(0, 0, -0.14), vb + V(0, 0, -0.2), vb + V(0, 0, -0.26)],
         [(0.025, 0.025), (0.06, 0.06), (0.07, 0.07), (0.05, 0.05)], 8, [{'Vial': 1}] * 4, 'L2', start='flat', end='point',
         end_pt=vb + V(0, 0, -0.29), anti=False)
    # ---- L3 "Coven Queen"
    mb.mat = 3
    pb, pt = ATLAS.uv('cape', 0.5, 0.06), ATLAS.uv('cape', 0.5, 0.94)
    for base, tp, wd in ((V(0.12, -0.1, 0.86), V(0.4, 0.44, 0.44), 0.4), (V(-0.12, -0.1, 0.86), V(-0.4, 0.44, 0.44), 0.4),
                         (V(0, -0.06, 0.9), V(0, 0.56, 0.62), 0.42)):
        bipyramid(mb, base, tp, V(1, 0, 0), V(0, 0, 1), wd, 0.04, [{'Body': 1}, {'Cape': 1}] + [{'Cape': 0.6, 'Body': 0.4}] * 4,
                  pb, pt, 'L3', wide_at=0.35, ridge_at=0.35)
    # two extra forked tails
    for x in (1, -1):
        tl2 = [V(x * 0.03, 0.3, 0.5), V(x * 0.14, 0.46, 0.56), V(x * 0.24, 0.56, 0.74), V(x * 0.28, 0.52, 0.94), V(x * 0.24, 0.44, 1.0)]
        tube(mb, 'limb', tl2, [(0.045, 0.045), (0.042, 0.042), (0.04, 0.04), (0.034, 0.034), (0.025, 0.025)], 6,
             [{'Tail1': 1}, {'Tail1': 0.5, 'Tail2': 0.5}, {'Tail2': 1}, {'Tail3': 1}, {'Tail3': 1}], 'L3', start='point', end='point',
             end_pt=V(x * 0.2, 0.4, 0.98), anti=False)
    # hex flame streaming out of the bristles
    xb, xt = ATLAS.uv('fire', 0.5, 0.05), ATLAS.uv('fire', 0.5, 0.95)
    for k, (o, ln) in enumerate(((V(0, 0, 0.06), 0.42), (V(0.1, 0, -0.02), 0.32), (V(-0.1, 0, -0.02), 0.32), (V(0, 0, -0.1), 0.26))):
        bp = V(0, 0.86, 0.3) + o
        bipyramid(mb, bp, bp + V(0, ln, 0.1 + 0.04 * k), V(1, 0, 0), V(0, 0, 1), 0.14, 0.12, {'Bristle': 1}, xb, xt, 'L3',
                  wide_at=0.3, ridge_at=0.3)
    # moon emblem on the hat front
    mb_ = [HC + V(0.05 * math.cos(a), -0.15, 0.2 + 0.05 * math.sin(a)) for a in np.linspace(-1.9, 1.9, 6)]
    tube(mb, 'gold', mb_, [(0.014, 0.014)] * len(mb_), 4, [{'Hat': 1}] * len(mb_), 'L3', start='point', end='point', anti=False)
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


def _pgrain(h, w, seed):
    a = grit(h, 2 * w, seed)
    t = (np.arange(w, dtype=np.float32) / w)[None, :]
    return a[:, w:] * (1 - t) + a[:, :w] * t


def _reg(name):
    y0, y1, x0, x1 = ATLAS.px(name)
    h, w = y1 - y0, x1 - x0
    v, u = np.mgrid[0:h, 0:w].astype(np.float32)
    return (y0, y1, x0, x1), v / h, u / w


def _black(level):
    if level == 3:
        return [(0, '06040a'), (0.5, '20163a'), (1, '5a4488')]   # violet sheen
    if level == 2:
        return [(0, '050607'), (0.5, '182224'), (1, '42585a')]   # cool teal sheen
    return [(0, '050507'), (0.5, '1a1822'), (1, '4a4458')]


def _hatc(level):
    if level == 3:
        return [(0, '0a0612'), (0.5, '361a5c'), (1, '6a3aa8')]
    return [(0, '08070c'), (0.5, '1c1828'), (1, '362e48')]


def _fur(h, w, seed, cells=220):
    st = _streaks(h, w, cells, seed)
    gr = _pgrain(h, w, seed + 1)
    return st, gr


def paint_atlas(level):
    col = np.zeros((TS, TS, 3), np.float32)
    hgt = np.full((TS, TS), 0.5, np.float32)
    rgh = np.full((TS, TS), 0.55, np.float32)
    glow = np.zeros((TS, TS), np.float32)
    bk = _black(level)
    gc, ghi = GLOW[level]
    # ---- torso fur: black with blue-violet sheen on top, fur strokes, a jagged pale-grey chest blaze? no: a dark-green
    # rune stripe down the spine (glows at L2+)
    (y0, y1, x0, x1), v, u = _reg('fur')
    h, w = y1 - y0, x1 - x0
    top = np.cos(u * 2 * math.pi)                 # 1 on the spine
    st, gr = _fur(h, w, 61)
    c = grad(np.clip(0.3 + 0.35 * top + 0.15 * v, 0, 1), bk) * (1 + 0.5 * st[..., None] + 0.1 * gr[..., None])
    stripes = ss(0.02, 0.0, np.abs(_saw(v * 7 + 0.4 * _saw(u * 3)) - 0.5) - 0.06) * ss(0.2, 0.6, top)
    c = c * (1 - 0.5 * stripes[..., None])
    spine = ss(0.02, 0.0, np.abs(u - 0.0) * np.abs(u - 1.0) * 4 - 0.02) * ss(0.15, 0.25, v) * ss(0.85, 0.75, v) * (0.0 if level == 1 else 0.7)
    spine *= ss(0.3, 0.6, _saw(v * 10))
    c = c * (1 - spine[..., None]) + hx(gc) * spine[..., None]
    col[y0:y1, x0:x1] = c
    rgh[y0:y1, x0:x1] = 0.5 - 0.1 * top
    hgt[y0:y1, x0:x1] = 0.5 + 0.45 * st + 0.1 * gr - 0.2 * stripes
    glow[y0:y1, x0:x1] = spine
    # ---- head fur: same, darker mask toward the muzzle, flame-tooth edge
    (y0, y1, x0, x1), v, u = _reg('head')
    h, w = y1 - y0, x1 - x0
    top = np.cos(u * 2 * math.pi)
    st, gr = _fur(h, w, 63, 120)
    c = grad(np.clip(0.3 + 0.35 * top + 0.1 * (1 - v), 0, 1), bk) * (1 + 0.45 * st[..., None] + 0.1 * gr[..., None])
    col[y0:y1, x0:x1] = c
    rgh[y0:y1, x0:x1] = 0.5
    hgt[y0:y1, x0:x1] = 0.5 + 0.4 * st
    # ---- hat: dark felt with patches and stitches, a band of darker brim
    (y0, y1, x0, x1), v, u = _reg('hat')
    h, w = y1 - y0, x1 - x0
    st = _streaks(h, w, 40, 65)
    hc = _hatc(level)
    c = grad(np.clip(0.4 + 0.3 * np.cos((u - 0.5) * 2 * math.pi) - 0.2 * v, 0, 1), hc) * (1 + 0.3 * st[..., None])
    patch = ss(0.01, 0.0, np.maximum(np.abs(u - 0.62) - 0.07, np.abs(v - 0.45) - 0.08))
    c = c * (1 - 0.4 * patch[..., None]) + hx('2a1a14') * 0.4 * patch[..., None]
    stitch = ss(0.01, 0.0, np.abs(np.maximum(np.abs(u - 0.62) - 0.07, np.abs(v - 0.45) - 0.08)) - 0.003) * ss(0.4, 0.6, _saw(u * 60 + v * 60))
    c = c * (1 - stitch[..., None]) + hx('8a7a60') * stitch[..., None]
    brim = (v < 0.1).astype(np.float32)
    c = c * (1 - 0.3 * brim[..., None])
    col[y0:y1, x0:x1] = c
    rgh[y0:y1, x0:x1] = 0.8
    hgt[y0:y1, x0:x1] = 0.5 + 0.3 * st + 0.1 * patch
    # ---- limbs / tail: fur
    (y0, y1, x0, x1), v, u = _reg('limb')
    st, gr = _fur(y1 - y0, x1 - x0, 67, 90)
    c = grad(np.clip(0.35 + 0.3 * np.cos(u * 2 * math.pi), 0, 1), bk) * (1 + 0.5 * st[..., None])
    col[y0:y1, x0:x1] = c
    hgt[y0:y1, x0:x1] = 0.5 + 0.4 * st
    # ---- ears: black outside, a dark wine inner with a glowing green rim tip at L2+
    (y0, y1, x0, x1), v, u = _reg('ear')
    inner = ss(0.32, 0.22, np.abs(u - 0.5)) * ss(0.85, 0.7, v)
    tipg = ss(0.86, 0.97, v) * (0.0 if level == 1 else 1.0)
    c = grad(v, bk) * (1 - inner[..., None]) + hx('2a0c18') * inner[..., None]
    col[y0:y1, x0:x1] = c * (1 - tipg[..., None]) + hx(gc) * tipg[..., None]
    glow[y0:y1, x0:x1] = tipg
    # ---- haft: gnarled dark wood
    (y0, y1, x0, x1), v, u = _reg('haft')
    gn = 0.5 + 0.5 * np.cos(u * 2 * math.pi * 3 + v * 30 + 2 * np.sin(v * 9))
    col[y0:y1, x0:x1] = grad(gn, [(0, '140c06'), (1, '3a2414')])
    rgh[y0:y1, x0:x1] = 0.7
    hgt[y0:y1, x0:x1] = 0.5 + 0.4 * gn
    # ---- bristles: straw gone dark and scorched toward the tips, green embers at L2+
    (y0, y1, x0, x1), v, u = _reg('bristle')
    st = _streaks(y1 - y0, x1 - x0, 300, 69)
    sc = ss(0.5, 0.95, v)
    c = grad(np.clip(0.6 + st * 1.2, 0, 1), [(0, '3a2a10'), (1, '6a5228')]) * (1 - 0.8 * sc[..., None])
    emb = ss(0.85, 0.95, vnoise(y1 - y0, x1 - x0, 60, 71)) * sc * (0.0 if level == 1 else 1.0)
    col[y0:y1, x0:x1] = c * (1 - emb[..., None]) + hx(gc) * emb[..., None]
    rgh[y0:y1, x0:x1] = 0.8
    hgt[y0:y1, x0:x1] = 0.5 + 0.6 * st
    glow[y0:y1, x0:x1] = emb
    # ---- band: dark leather with a green rune line
    (y0, y1, x0, x1), v, u = _reg('band')
    rn = ss(0.03, 0.0, np.abs(v - 0.5) - 0.02) * ss(0.3, 0.6, _saw(u * 24))
    col[y0:y1, x0:x1] = hx('1a0e0a') * (1 - rn[..., None]) + hx(gc) * rn[..., None]
    rgh[y0:y1, x0:x1] = 0.5
    glow[y0:y1, x0:x1] = rn
    # ---- gold
    (y0, y1, x0, x1), v, u = _reg('gold')
    col[y0:y1, x0:x1] = grad(np.clip(0.5 + 0.5 * np.cos(u * 2 * math.pi), 0, 1), [(0, '5a3a10'), (1, 'e2b44a')])
    rgh[y0:y1, x0:x1] = 0.25
    # ---- glass vial: green potion glowing
    (y0, y1, x0, x1), v, u = _reg('glass')
    col[y0:y1, x0:x1] = grad(v, [(0, '204a20'), (0.3, gc), (1, ghi)])
    rgh[y0:y1, x0:x1] = 0.1
    glow[y0:y1, x0:x1] = 0.5 + 0.5 * v
    # ---- cape: violet-black with a frayed glowing green edge
    (y0, y1, x0, x1), v, u = _reg('cape')
    st = _streaks(y1 - y0, x1 - x0, 50, 73)
    ed = ss(0.0, 0.03, v - (0.78 + 0.1 * _saw(u * 6)))
    eg = ss(0.03, 0.0, np.abs(v - (0.78 + 0.1 * _saw(u * 6))))
    c = grad(np.clip(0.7 - 0.5 * v, 0, 1), [(0, '07040c'), (0.6, '24123c'), (1, '44266e')]) * (1 + 0.3 * st[..., None])
    c = c * (1 - 0.7 * ed[..., None])
    col[y0:y1, x0:x1] = c * (1 - eg[..., None]) + hx(gc) * eg[..., None]
    rgh[y0:y1, x0:x1] = 0.7
    glow[y0:y1, x0:x1] = eg
    # ---- fire
    (y0, y1, x0, x1), v, u = _reg('fire')
    col[y0:y1, x0:x1] = grad(v, [(0, ghi), (0.45, gc), (1, '06200a')])
    rgh[y0:y1, x0:x1] = 0.2
    glow[y0:y1, x0:x1] = 1.0 - 0.6 * v
    # ---- claws
    (y0, y1, x0, x1), v, u = _reg('claw')
    t = ss(0.6, 0.9, v)
    col[y0:y1, x0:x1] = hx('0c0a0e') * (1 - t[..., None]) + hx('d8d4c8') * t[..., None]
    rgh[y0:y1, x0:x1] = 0.3
    paint_atlas._glow = np.clip(glow, 0, 1)
    return np.clip(col, 0, 1), hgt, rgh


def emissive_mask(level):
    paint_atlas(level)
    return np.repeat(paint_atlas._glow[..., None], 3, -1)


# ---------------------------------------------------------------- face decal
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
    # narrow slanted almond eyes: inner corner low near the nose bridge, outer corner high
    ix, iz, ox, oz = 0.04, 1.0, 0.17, 1.06
    ex, ez = ox - ix, oz - iz
    L = math.hypot(ex, ez)
    s = ((aX - ix) * ex + (Z - iz) * ez) / (L * L)
    d = (-(aX - ix) * ez + (Z - iz) * ex) / L
    sc = np.clip(s, 0, 1)
    top = 0.03 * np.clip(sc * 3.0, 0, 1) * (1 - sc ** 4) + 0.002
    bot = -0.02 * np.clip(np.sin(math.pi * sc), 0, 1) ** 0.9 - 0.001
    inside = (s > 0) & (s < 1)
    eye = ss(0.003, 0.0, np.maximum(d - top, bot - d)) * inside
    cxs, czs = ix + 0.55 * ex, iz + 0.55 * ez
    rr = np.sqrt((aX - cxs) ** 2 + (Z - czs) ** 2)
    iris = ss(0.045, 0.04, rr)
    _face_layers.rr = rr
    slit = ss(0.006 * np.clip(1 - ((Z - czs) / 0.035) ** 2, 0, 1) + 0.0005, 0.0, np.abs(aX - cxs)) * ss(0.035, 0.03, rr)
    brow = np.maximum(_seg(aX, Z, (0.025, 1.035), (0.19, 1.1), 0.012, 0.004), _seg(aX, Z, (0.18, 1.095), (0.23, 1.13), 0.006, 0.001))
    lid = ss(0.006, 0.003, np.abs(d - top - 0.003)) * (s > -0.05) * (s < 1.02)
    # dark mask around the eyes (flame-tooth lower edge)
    mask = ss(0.012, 0.0, np.abs(Z - 1.035) - 0.05) * ss(0.24, 0.2, aX)
    # small dark nose, a thin one-sided smirk (left side up) with a single fang
    nose = ss(0.004, 0.0, aX / 0.026 + (Z - 0.955) / 0.02 - 1) * (Z < 0.955) * (Z > 0.93)
    mouth = np.maximum(_seg(X, Z, (-0.06, 0.9), (0.0, 0.905), 0.006, 0.006), _seg(X, Z, (0.0, 0.905), (0.08, 0.925), 0.006, 0.003))
    philtrum = _seg(X, Z, (0.0, 0.93), (0.0, 0.905), 0.004, 0.004)
    fang = ss(0.003, 0.0, np.abs(X - 0.045) / 0.012 + (0.912 - Z) / 0.03 - 1) * (Z < 0.912) * (Z > 0.88)
    marks = np.zeros_like(X)
    if level >= 2:                               # glowing whisker marks
        marks = np.maximum.reduce([_seg(aX, Z, (0.09, 0.94), (0.24, 0.96), 0.005, 0.001), _seg(aX, Z, (0.09, 0.925), (0.24, 0.915), 0.005, 0.001)])
    if level >= 3:                               # forehead crescent sigil
        r0 = np.sqrt(X ** 2 + (Z - 1.15) ** 2)
        r1 = np.sqrt((X - 0.012) ** 2 + (Z - 1.16) ** 2)
        marks = np.maximum(marks, ss(0.004, 0.0, r0 - 0.035) * ss(0.0, 0.004, r1 - 0.032))
    return X, Z, eye, iris, slit, brow, lid, mask, nose, mouth, philtrum, fang, marks


def face_texture(level, size=512):
    X, Z, eye, iris, slit, brow, lid, mask, nose, mouth, philtrum, fang, marks = _face_layers(level, size)
    gc, ghi = GLOW[level]
    rr_ = _face_layers.rr
    rgba = np.zeros((size, size, 4), np.float32)
    c = np.zeros((size, size, 3), np.float32) + hx('030304')
    eyec = 'e8ff60' if level == 3 else gc
    irisc = grad(np.clip(1 - rr_ / 0.045, 0, 1), [(0, '0a2a10'), (0.35, eyec), (0.8, ghi), (1, 'ffffff')])
    e = hx('061008') * (1 - iris[..., None]) + irisc * iris[..., None]
    e = e * (1 - slit[..., None]) + hx('020302') * slit[..., None]
    c = c * (1 - eye[..., None]) + e * eye[..., None]
    c = c * (1 - fang[..., None]) + hx('e8e4d8') * fang[..., None]
    c = c * (1 - marks[..., None]) + hx(gc) * marks[..., None]
    ln = np.clip(np.maximum.reduce([lid, brow, nose, mouth, philtrum]), 0, 1)
    c = c * (1 - ln[..., None]) + hx('010101') * ln[..., None]
    rgba[..., :3] = c
    rgba[..., 3] = np.clip(np.maximum.reduce([eye, ln, mask * 0.85, fang, marks]), 0, 1)
    return rgba


def face_emissive(level, size=512):
    X, Z, eye, iris, slit, brow, lid, mask, nose, mouth, philtrum, fang, marks = _face_layers(level, size)
    g = np.clip(np.maximum(iris * eye * (1 - slit), marks * 0.9), 0, 1)
    return np.repeat(g[..., None], 3, -1)


# ---------------------------------------------------------------- animation (24 fps; the broom floats)
def _ease(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def _pulse(t, a, b):
    if t <= a or t >= b:
        return 0.0
    return math.sin(math.pi * (t - a) / (b - a))


def _tail(w, amp, pitch=0.0):
    return {'Tail1': P(('x', -pitch * 0.4), ('z', amp * math.sin(w))),
            'Tail2': P(('x', -pitch * 0.3), ('z', amp * 1.2 * math.sin(w - 0.9))),
            'Tail3': P(('x', -pitch * 0.2 + 10 * math.sin(w - 1.4)), ('z', amp * 1.4 * math.sin(w - 1.8)))}


def anim_idle():
    """3 s loop: the broom bobs and rocks, the cat sways, tail hooks and curls, an ear flicks, the hat tip flops."""
    F = 72
    keys = {}
    for f in range(0, F + 1, 3):
        t = f / F
        w = 2 * math.pi * t
        flick = _pulse(t, 0.5, 0.6)
        look = _pulse(t, 0.15, 0.45)
        k = {'Broom': P(('x', 3 * math.sin(w)), ('y', 4 * math.sin(w + 0.8)), loc=(0, 0, 0.07 * math.sin(w))),
             'Bristle': P(('z', 4 * math.sin(w * 2))),
             'Body': P(('x', 2 * math.sin(w + 0.5))),
             'Head': P(('x', -3 * math.sin(w + 0.7)), ('z', 18 * look), ('y', -6 * look)),
             'Ear.L': P(('y', -25 * flick)), 'Ear.R': P(('y', 4 * math.sin(w))),
             'HatTip': P(('x', 8 * math.sin(w + 1.2)), ('z', 6 * math.sin(w))),
             'Paw.L': P(), 'Paw.R': P(), 'Cape': P(('x', 6 * math.sin(w))), 'Vial': P(('x', -10 * math.sin(w + 0.4)))}
        k.update(_tail(w, 14))
        keys[f] = k
    keys[F] = dict(keys[0])
    return {'frames': F, 'loop': True, 'keys': keys}


def _fly(frames, pitch, sway):
    keys = {}
    for f in range(0, frames + 1, 2):
        t = f / frames
        w = 2 * math.pi * t
        keys[f] = {'Broom': P(('x', pitch + 3 * math.sin(w)), ('y', 5 * math.sin(w)), loc=(0, 0, 0.05 * math.sin(w - 1.0))),
                   'Body': P(('x', pitch * 0.3)), 'Head': P(('x', -pitch * 0.9)),
                   'Ear.L': P(('x', 25)), 'Ear.R': P(('x', 25)),
                   'Hat': P(('x', 10)), 'HatTip': P(('x', 18 + 6 * math.sin(w * 2))), 'Bristle': P(('z', 8 * math.sin(w * 2))),
                   'Cape': P(('x', -pitch * 0.8 + 6 * math.sin(w * 2))), 'Vial': P(('x', -pitch - 20))}
        keys[f].update(_tail(w, sway, pitch * 1.3))
    keys[frames] = dict(keys[0])
    return {'frames': frames, 'loop': True, 'keys': keys}


def anim_walk():
    return _fly(24, 12, 10)


def anim_run():
    return _fly(16, 24, 16)


def anim_hop():
    keys = {}
    F = 16
    for f in range(0, F + 1, 2):
        t = f / F
        crouch = _pulse(t, 0.0, 0.3)
        up = _pulse(t, 0.2, 1.0)
        keys[f] = {'Broom': P(('x', -20 * up + 8 * crouch), loc=(0, 0, -0.06 * crouch + 0.3 * up)),
                   'Body': P(('x', 12 * crouch)), 'Head': P(('x', -10 * up)),
                   'HatTip': P(('x', 30 * up)), 'Tail1': P(('x', 20 * up)), 'Tail2': P(('x', 15 * up))}
    return {'frames': F, 'loop': False, 'keys': keys}


def anim_ability():
    """Fake Clone (~1 s, Runner): leans in, barrel-rolls the broom a full turn, tips the hat at the top (the clone
    splits off here), settles with a sly look."""
    keys = {}
    F = 24
    for f in range(0, F + 1, 2):
        t = f / F
        lean = _ease(t / 0.25) * (1 - _ease((t - 0.25) / 0.1))
        roll = _ease((t - 0.2) / 0.45)
        tip = _pulse(t, 0.55, 0.85)
        keys[f] = {'Broom': P(('y', 360 * roll), ('x', 10 * lean - 12 * tip), loc=(0, 0, 0.18 * _pulse(t, 0.2, 0.7))),
                   'Body': P(('x', 14 * lean)), 'Head': P(('x', -8 * tip), ('z', 20 * tip)),
                   'Paw.R': P(('x', -80 * tip), ('z', 20 * tip)), 'Hat': P(('x', -20 * tip), ('y', 15 * tip)),
                   'HatTip': P(('x', 25 * lean + 30 * tip)), 'Bristle': P(('z', 20 * math.sin(8 * t))),
                   'Tail1': P(('z', 30 * math.sin(6 * t))), 'Tail2': P(('z', 40 * math.sin(6 * t - 1))),
                   'Tail3': P(('z', 50 * math.sin(6 * t - 2))), 'Cape': P(('x', -30 * roll * (1 - roll) * 4))}
    return {'frames': F, 'loop': False, 'keys': keys}


def anim_snare():
    """Snare (~0.75 s, Catcher): rears the broom up, then stabs it nose-down to brew the hex circle, hisses."""
    keys = {}
    F = 18
    for f in range(0, F + 1):
        t = f / F
        rear = _ease(t / 0.3) * (1 - _ease((t - 0.3) / 0.1))
        stab = _ease((t - 0.3) / 0.1) * (1 - _ease((t - 0.7) / 0.3))
        keys[f] = {'Broom': P(('x', -35 * rear + 40 * stab), loc=(0, 0, 0.12 * rear - 0.08 * stab)),
                   'Body': P(('x', -10 * rear + 10 * stab)), 'Head': P(('x', 10 * rear - 25 * stab)),
                   'Ear.L': P(('x', 30 * stab), ('y', -20 * stab)), 'Ear.R': P(('x', 30 * stab), ('y', 20 * stab)),
                   'Paw.L': P(('x', -40 * stab)), 'Paw.R': P(('x', -40 * stab)),
                   'HatTip': P(('x', -20 * rear + 30 * stab)), 'Tail1': P(('x', -30 * stab)), 'Tail2': P(('x', -20 * stab)),
                   'Tail3': P(('x', 20 * stab))}
    return {'frames': F, 'loop': False, 'keys': keys}


ANIMS = {'Idle': anim_idle, 'Walk': anim_walk, 'Run': anim_run, 'Hop': anim_hop, 'Ability': anim_ability,
         'Snare': anim_snare}
