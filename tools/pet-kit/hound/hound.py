# Riot Hound (Tempest, Rare) for Hatch or Snatch: HOS-PET-020, built on the pet kit (docs/pets/Pet Pipeline Guide.md).
# From the concept-library card (docs/pets/riot_hound/riot_hound_card.png): a lean navy-black wolf with a spiky blue
# ruff and a bushy blue tail, tall pointed ears, a snarling muzzle and yellow eyes, wreathed in gold lightning.
# Read through PET_LESSONS (anime / edgy): near-black navy coat with fur strokes and jagged blue markings, gold
# lightning-bolt fur along the spine, narrow slanted glowing slit eyes in a dark mask, a snarl with fangs (face decal
# shell). L2 "Stormcaller": a spiked riot collar, bolt pauldrons, a fuller ruff. L3 "Thunder Alpha": a lightning
# crown, bolt blades on the tail, gold leg bracers, electric white-cyan eyes.
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

NAME = 'Hound'
SHARP_ANGLE = 40
NORMAL_STRENGTH = 2.2
TS = 1024
ATLAS = Atlas({
    'skin': (0, 0, 1024, 384),      # body loft: u around (0 = top seam, 0.5 = belly), v tail end -> neck
    'head': (0, 384, 512, 256),     # head loft: u around, v skull -> snout
    'limb': (512, 384, 512, 128),   # legs: v hip / shoulder -> paw
    'tail': (512, 512, 512, 128),   # bushy tail: v root -> tip
    'fur': (0, 640, 256, 128),      # blue ruff / tail tufts: v root -> tip
    'bolt': (256, 640, 256, 128),   # gold lightning fur: v root -> tip
    'ear': (512, 640, 128, 128),
    'claw': (640, 640, 128, 128),
    'jaw': (768, 640, 256, 128),
    'metal': (0, 768, 256, 128),    # L2 collar, L3 bracers
    'bolt3': (256, 768, 256, 128),  # L2 / L3 bolts (palette per level)
})

BOLT = {1: ('b8780a', 'ffd23a', 'fff6c0'), 2: ('c88a10', 'ffe04a', 'fffbe0'), 3: ('1a6ad8', '7fe8ff', 'ffffff')}
EYE = {1: ('c87a00', 'ffd23a', 'fff6c0'), 2: ('c87a00', 'ffe04a', 'fffbe0'), 3: ('1a7ad8', '9ff0ff', 'ffffff')}


# ---------------------------------------------------------------- skeleton
def bones_def():
    b = [
        ('Root', V(0, 0, 0), V(0, 0, 0.2), None),
        ('Body', V(0, 0.45, 0.98), V(0, -0.05, 1.0), 'Root'),
        ('Chest', V(0, -0.05, 1.0), V(0, -0.45, 1.1), 'Body'),
        ('Neck', V(0, -0.45, 1.12), V(0, -0.62, 1.32), 'Chest'),
        ('Head', V(0, -0.62, 1.34), V(0, -1.3, 1.24), 'Neck'),
        ('Jaw', V(0, -0.8, 1.16), V(0, -1.28, 1.08), 'Head'),
        ('Tail1', V(0, 0.62, 1.04), V(0, 0.9, 1.22), 'Body'),
        ('Tail2', V(0, 0.9, 1.22), V(0, 1.14, 1.5), 'Tail1'),
        ('Tail3', V(0, 1.14, 1.5), V(0, 1.24, 1.82), 'Tail2'),
    ]
    for s, x in (('L', 1), ('R', -1)):
        b += [
            ('Ear.' + s, V(x * 0.16, -0.68, 1.56), V(x * 0.24, -0.6, 1.94), 'Head'),
            ('FrontUpper.' + s, V(x * 0.2, -0.36, 0.92), V(x * 0.22, -0.4, 0.5), 'Chest'),
            ('FrontLower.' + s, V(x * 0.22, -0.4, 0.5), V(x * 0.23, -0.42, 0.14), 'FrontUpper.' + s),
            ('FrontFoot.' + s, V(x * 0.23, -0.42, 0.14), V(x * 0.23, -0.6, 0.05), 'FrontLower.' + s),
            ('BackUpper.' + s, V(x * 0.22, 0.46, 0.94), V(x * 0.25, 0.32, 0.56), 'Body'),
            ('BackLower.' + s, V(x * 0.25, 0.32, 0.56), V(x * 0.25, 0.48, 0.16), 'BackUpper.' + s),
            ('BackFoot.' + s, V(x * 0.25, 0.48, 0.16), V(x * 0.25, 0.3, 0.05), 'BackLower.' + s),
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


def spike(mb, region, base, tip, w, width, part, side=None, up=None, wide_at=0.3, flat=0.45):
    """A flattened blade (fur tuft / lightning bolt), root buried in the part it grows from."""
    d = nrm(np.asarray(tip, float) - np.asarray(base, float))
    side = side if side is not None else (V(1, 0, 0) if abs(d[0]) < 0.8 else V(0, 1, 0))
    up = up if up is not None else nrm(np.cross(d, side))
    bipyramid(mb, base, tip, side, up, width, width * flat, w, ATLAS.uv(region, 0.5, 0.05), ATLAS.uv(region, 0.5, 0.95),
              part, wide_at=wide_at, ridge_at=wide_at)


def bolt(mb, region, base, mid, tip, w, width, part, side=None):
    """A zig-zag lightning bolt: two kinked blades."""
    spike(mb, region, base, mid, w, width, part, side=side, wide_at=0.5, flat=0.35)
    spike(mb, region, mid - (mid - base) * 0.25, tip, w, width * 0.8, part, side=side, wide_at=0.3, flat=0.35)


FX, FZ, FZH = 0.36, 1.32, 0.34
SHELL = (-0.84, 0.98, 1.66)          # face shell: faces with y < SHELL[0] and SHELL[1] < z < SHELL[2]


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
    W_B, W_C, W_N, W_H, W_J = {'Body': 1}, {'Chest': 1}, {'Neck': 1}, {'Head': 1}, {'Jaw': 1}
    # lean body: deep chest, tucked waist, neck rising to the head
    st = [(V(0, 0.68, 1.02), (0.14, 0.13), {'Body': 0.5, 'Tail1': 0.5}),
          (V(0, 0.52, 1.0), (0.27, 0.27), W_B),
          (V(0, 0.25, 0.98), (0.27, 0.27), W_B),
          (V(0, -0.02, 1.0), (0.29, 0.32), {'Body': 0.5, 'Chest': 0.5}),
          (V(0, -0.3, 1.04), (0.31, 0.37), W_C),
          (V(0, -0.48, 1.14), (0.25, 0.3), {'Chest': 0.5, 'Neck': 0.5}),
          (V(0, -0.6, 1.3), (0.2, 0.22), {'Neck': 0.6, 'Head': 0.4})]
    tube(mb, 'skin', [s[0] for s in st], [s[1] for s in st], 14, [s[2] for s in st], 'body',
         start='point', end='point', start_pt=V(0, 0.76, 1.04), end_pt=V(0, -0.66, 1.38), side_hint=V(1, 0, 0),
         th0=math.pi / 2)
    # wolf head: broad skull, long tapering muzzle
    n0 = len(mb.F)
    hs = [(V(0, -0.58, 1.38), (0.2, 0.2), W_H), (V(0, -0.72, 1.4), (0.27, 0.25), W_H),
          (V(0, -0.9, 1.36), (0.24, 0.21), W_H), (V(0, -1.08, 1.28), (0.15, 0.14), W_H),
          (V(0, -1.24, 1.24), (0.1, 0.1), W_H)]
    tube(mb, 'head', [h[0] for h in hs], [h[1] for h in hs], 12, [h[2] for h in hs], 'head',
         start='point', end='point', start_pt=V(0, -0.52, 1.4), end_pt=V(0, -1.34, 1.22), side_hint=V(1, 0, 0),
         th0=math.pi / 2)
    head_faces = list(range(n0, len(mb.F)))
    js = [(V(0, -0.8, 1.18), (0.16, 0.07), W_J), (V(0, -1.02, 1.14), (0.12, 0.06), W_J), (V(0, -1.22, 1.12), (0.07, 0.04), W_J)]
    tube(mb, 'jaw', [j[0] for j in js], [j[1] for j in js], 8, [j[2] for j in js], 'jaw', start='point', end='point',
         start_pt=V(0, -0.72, 1.2), end_pt=V(0, -1.28, 1.12), side_hint=V(1, 0, 0), th0=math.pi / 2)
    # tall pointed ears (dark, pink-free: edgy), swept slightly back
    for s, x in (('L', 1), ('R', -1)):
        bipyramid(mb, V(x * 0.15, -0.66, 1.5), V(x * 0.26, -0.56, 1.96), V(0, 1, 0), V(0, -1, 0.1), 0.18, 0.07,
                  {'Ear.' + s: 1}, ATLAS.uv('ear', 0.5, 0.9), ATLAS.uv('ear', 0.5, 0.1), 'ear', wide_at=0.3, ridge_at=0.3)
    # spiky blue ruff around the neck and shoulders
    for k in range(9):
        a = math.radians(-100 + 200 * k / 8)
        dirv = nrm(V(math.sin(a) * 0.9, 0.35, math.cos(a) * 0.9 + 0.2))
        base = V(0, -0.42, 1.14) + V(math.sin(a) * 0.18, 0.0, math.cos(a) * 0.2)
        spike(mb, 'fur', base, base + dirv * (0.46 + 0.1 * (k % 2)), {'Neck': 0.5, 'Chest': 0.5}, 0.22, 'fur')
    for x in (1, -1):                                   # cheek tufts
        spike(mb, 'fur', V(x * 0.18, -0.74, 1.3), V(x * 0.4, -0.62, 1.22), W_H, 0.12, 'fur')
    # gold lightning-bolt fur along the spine
    for (y, z, h, w) in ((-0.3, 1.36, 0.42, 0.2), (-0.02, 1.28, 0.36, 0.18), (0.26, 1.22, 0.32, 0.16), (0.5, 1.2, 0.26, 0.13)):
        wgt = W_C if y < -0.1 else W_B
        bolt(mb, 'bolt', V(0, y, z - 0.04), V(0, y + 0.2, z + h * 0.6), V(0, y + 0.06, z + h * 1.25), wgt, w * 1.5, 'bolt',
             side=V(0, 1, 0))
    # legs: long, lean, digitigrade back legs, near-black paws with claws
    for s, x in (('L', 1), ('R', -1)):
        fu, fl, ff = 'FrontUpper.' + s, 'FrontLower.' + s, 'FrontFoot.' + s
        front = [(V(x * 0.18, -0.34, 0.98), (0.16, 0.19), {'Chest': 0.6, fu: 0.4}),
                 (V(x * 0.21, -0.38, 0.7), (0.13, 0.14), {fu: 1}),
                 (V(x * 0.22, -0.4, 0.5), (0.1, 0.1), {fu: 0.5, fl: 0.5}),
                 (V(x * 0.23, -0.42, 0.24), (0.085, 0.085), {fl: 1}),
                 (V(x * 0.23, -0.47, 0.08), (0.1, 0.06), {fl: 0.3, ff: 0.7})]
        tube(mb, 'limb', [f[0] for f in front], [f[1] for f in front], 8, [f[2] for f in front], 'front' + s,
             start='point', end='point', start_pt=V(x * 0.1, -0.32, 1.04), end_pt=V(x * 0.23, -0.6, 0.05))
        bu, bl, bf = 'BackUpper.' + s, 'BackLower.' + s, 'BackFoot.' + s
        back = [(V(x * 0.2, 0.46, 0.98), (0.19, 0.23), {'Body': 0.6, bu: 0.4}),
                (V(x * 0.24, 0.38, 0.72), (0.17, 0.17), {bu: 1}),
                (V(x * 0.25, 0.32, 0.56), (0.11, 0.11), {bu: 0.5, bl: 0.5}),
                (V(x * 0.25, 0.42, 0.3), (0.085, 0.085), {bl: 1}),
                (V(x * 0.25, 0.44, 0.1), (0.085, 0.07), {bl: 0.4, bf: 0.6}),
                (V(x * 0.25, 0.36, 0.07), (0.1, 0.06), {bf: 1})]
        tube(mb, 'limb', [f[0] for f in back], [f[1] for f in back], 8, [f[2] for f in back], 'back' + s,
             start='point', end='point', start_pt=V(x * 0.1, 0.46, 1.04), end_pt=V(x * 0.25, 0.26, 0.05))
        for foot, bone in ((V(x * 0.23, -0.52, 0.07), ff), (V(x * 0.25, 0.3, 0.07), bf)):
            for k in (-1, 0, 1):
                b0 = foot + V(k * 0.045, 0, 0)
                bipyramid(mb, b0, b0 + nrm(V(k * 0.3, -1, -0.3)) * 0.11, V(1, 0, 0), V(0, 0, 1), 0.04, 0.035, {bone: 1},
                          ATLAS.uv('claw', 0.5, 0.15), ATLAS.uv('claw', 0.5, 0.9), 'claw', wide_at=0.3, ridge_at=0.3)
    # big bushy tail: a thick curving tube plus blue tufts
    tp = [V(0, 0.64, 1.04), V(0, 0.88, 1.2), V(0, 1.1, 1.46), V(0, 1.22, 1.76)]
    tube(mb, 'tail', tp, [(0.1, 0.1), (0.2, 0.2), (0.22, 0.22), (0.12, 0.12)], 10,
         [{'Body': 0.4, 'Tail1': 0.6}, {'Tail1': 0.5, 'Tail2': 0.5}, {'Tail2': 0.5, 'Tail3': 0.5}, {'Tail3': 1}], 'tail',
         start='point', end='point', start_pt=V(0, 0.58, 1.02), end_pt=V(0, 1.26, 1.98))
    for p, d, w in ((V(0, 1.0, 1.32), V(0.8, 0.5, 0.3), {'Tail2': 1}), (V(0, 1.0, 1.32), V(-0.8, 0.5, 0.3), {'Tail2': 1}),
                    (V(0, 1.18, 1.62), V(0.7, 0.6, 0.6), {'Tail3': 1}), (V(0, 1.18, 1.62), V(-0.7, 0.6, 0.6), {'Tail3': 1}),
                    (V(0, 1.22, 1.8), V(0, 0.4, 1), {'Tail3': 1})):
        spike(mb, 'fur', p, p + nrm(d) * 0.34, w, 0.18, 'fur')
    # ---- face decal shell (mat 1)
    mb.mat = 1
    face_shell(mb, head_faces)
    # ---- level 2 (mat 2) "Stormcaller": spiked riot collar, bolt pauldrons, fuller ruff
    mb.mat = 2
    cen = [V(0, -0.47, 1.17) + V(math.cos(2 * math.pi * i / 12) * 0.27, 0, math.sin(2 * math.pi * i / 12) * 0.3 + 0.0)
           for i in range(13)]
    cen = [V(c[0], c[1] + 0.06 * math.sin(math.atan2(c[2] - 1.17, c[0])), c[2]) for c in cen]
    tube(mb, 'metal', cen, [(0.05, 0.04)] * 13, 4, [{'Neck': 0.5, 'Chest': 0.5}] * 13, 'L2', start='open', end='open',
         side_hint=V(0, 1, 0), anti=False)
    for k in range(6):
        a = 2 * math.pi * (k + 0.5) / 6
        c = V(0, -0.47, 1.17) + V(math.cos(a) * 0.3, 0, math.sin(a) * 0.33)
        spike(mb, 'metal', c, c + V(math.cos(a), -0.1, math.sin(a)) * 0.13, {'Neck': 0.5, 'Chest': 0.5}, 0.07, 'L2',
              flat=0.9, wide_at=0.25)
    for x in (1, -1):
        bolt(mb, 'bolt3', V(x * 0.24, -0.3, 1.18), V(x * 0.4, -0.26, 1.36), V(x * 0.44, -0.18, 1.56), W_C, 0.15, 'L2')
        spike(mb, 'fur', V(x * 0.2, -0.46, 1.2), V(x * 0.56, -0.36, 1.32), {'Neck': 1}, 0.16, 'L2')
    # ---- level 3 (mat 3) "Thunder Alpha": lightning crown, tail bolt blades, gold leg bracers
    mb.mat = 3
    for dx, h in ((-0.12, 0.26), (0.0, 0.36), (0.12, 0.26)):
        b0 = V(dx, -0.72, 1.6)
        bolt(mb, 'bolt3', b0, b0 + V(dx * 0.4, 0.04, h * 0.55), b0 + V(dx * 0.6, 0.0, h), W_H, 0.09, 'L3', side=V(0, 1, 0))
    for x in (1, -1):
        bolt(mb, 'bolt3', V(0, 1.12, 1.5), V(x * 0.34, 1.26, 1.6), V(x * 0.5, 1.34, 1.86), {'Tail3': 1}, 0.14, 'L3')
    for s, x in (('L', 1), ('R', -1)):
        for c, bone in ((V(x * 0.23, -0.42, 0.24), 'FrontLower.' + s), (V(x * 0.25, 0.42, 0.3), 'BackLower.' + s)):
            ring = [c + V(math.cos(2 * math.pi * i / 8) * 0.11, math.sin(2 * math.pi * i / 8) * 0.11, 0) for i in range(9)]
            tube(mb, 'metal', ring, [(0.03, 0.05)] * 9, 4, [{bone: 1}] * 9, 'L3', start='open', end='open',
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


def _navy(level):
    if level == 3:
        return [(0, '05060e'), (0.5, '141c3c'), (1, '2e3a78')]
    if level == 2:
        return [(0, '070a18'), (0.5, '1a2450'), (1, '34428a')]
    return [(0, '06081a'), (0.5, '161e44'), (1, '2e3a7c')]


BLUE = [(0, '0e1c58'), (0.5, '2f5fd8'), (1, '8ab8ff')]


def paint_atlas(level):
    col = np.zeros((TS, TS, 3), np.float32)
    hgt = np.full((TS, TS), 0.5, np.float32)
    rgh = np.full((TS, TS), 0.55, np.float32)
    glow = np.zeros((TS, TS), np.float32)
    nv = _navy(level)
    bd, bm, bh = BOLT[level]
    # ---- coat (body + head): navy-black, fur strokes, darker back with a jagged edge, paler blue-grey chest blaze,
    # gold lightning-crack markings that glow
    for reg, scale in (('skin', 1.0), ('head', 0.7)):
        (y0, y1, x0, x1), v, u = _reg(reg)
        h, w = y1 - y0, x1 - x0
        top = np.cos(u * 2 * math.pi)
        c = grad(np.clip(0.55 + 0.35 * top, 0, 1), nv)
        under = ss(-0.1, -0.4, top + 0.1 * _saw(v * 16))
        c = c * (1 - 0.5 * under[..., None]) + grad(np.clip(v, 0, 1), [(0, '1c2448'), (1, '40507e')]) * (0.5 * under[..., None])
        back = ss(0.3, 0.55, top + 0.12 * _saw(v * 20 + u * 3))
        c = c * (1 - 0.45 * back[..., None])
        st = _streaks(h, w, 160, 41 if reg == 'skin' else 42)
        gr = _pgrain(h, w, 43)
        c = c * (1 + 0.35 * st[..., None] + 0.05 * gr[..., None])
        # zig-zag lightning cracks along the flanks (gold, glowing)
        zz = 0.18 + 0.05 * _saw(v * 9 * scale + 0.3)
        crack = ss(0.012, 0.0, np.abs(np.abs(u - 0.5) - zz) - 0.004) * ss(0.1, 0.25, v) * ss(0.95, 0.8, v)
        crack = crack * (reg == 'skin')
        c = c * (1 - crack[..., None]) + hx(bm) * crack[..., None]
        col[y0:y1, x0:x1] = c
        hgt[y0:y1, x0:x1] = 0.5 + 0.45 * st + 0.1 * gr
        glow[y0:y1, x0:x1] = crack
    # ---- legs: navy with fur strokes, near-black jagged socks and paws
    (y0, y1, x0, x1), v, u = _reg('limb')
    st = _streaks(y1 - y0, x1 - x0, 60, 44)
    sock = ss(0.0, 0.03, v - (0.6 + 0.08 * _saw(u * 8)))
    c = grad(np.clip(0.75 - 0.35 * v, 0, 1), nv) * (1 + 0.3 * st[..., None])
    col[y0:y1, x0:x1] = c * (1 - sock[..., None]) + hx('04050c') * sock[..., None]
    hgt[y0:y1, x0:x1] = 0.5 + 0.4 * st
    # ---- tail + fur tufts: blue, fur strokes, darker roots, jagged near-black tips
    for reg in ('tail', 'fur'):
        (y0, y1, x0, x1), v, u = _reg(reg)
        st = _streaks(y1 - y0, x1 - x0, 50, 45)
        tip = ss(0.0, 0.03, v - (0.82 + 0.08 * _saw(u * 6)))
        c = grad(np.clip(0.25 + 0.75 * v, 0, 1), BLUE) * (1 + 0.35 * st[..., None])
        if reg == 'tail':
            c = grad(np.clip(0.3 + 0.6 * np.cos((u - 0.5) * math.pi) ** 2, 0, 1), BLUE) * (1 + 0.35 * st[..., None])
            tip = tip * 0.0
        col[y0:y1, x0:x1] = c * (1 - tip[..., None]) + hx('06081a') * tip[..., None]
        hgt[y0:y1, x0:x1] = 0.5 + 0.45 * st
    # ---- gold lightning fur: deep gold root, white-hot tip, glowing
    for reg, lv in (('bolt', 1 if level < 3 else 2), ('bolt3', level)):
        (y0, y1, x0, x1), v, u = _reg(reg)
        d_, m_, h_ = BOLT[lv] if reg == 'bolt3' else BOLT[1]
        col[y0:y1, x0:x1] = grad(v, [(0, d_), (0.4, m_), (0.85, h_), (1, 'ffffff')])
        rgh[y0:y1, x0:x1] = 0.2
        glow[y0:y1, x0:x1] = 0.5 + 0.5 * v
    # ---- ears: navy, inner near-black, jagged blue tip
    (y0, y1, x0, x1), v, u = _reg('ear')
    tip = ss(0.0, 0.03, (1 - v) - (0.75 + 0.08 * _saw(u * 5)))
    col[y0:y1, x0:x1] = grad(1 - v, nv) * (1 - tip[..., None]) + hx('2f5fd8') * tip[..., None]
    # ---- claws, jaw
    (y0, y1, x0, x1), v, u = _reg('claw')
    t = ss(0.5, 0.9, v) * (1.0 if level >= 2 else 0.0)
    col[y0:y1, x0:x1] = hx('06060a') * (1 - t[..., None]) + hx(bm) * t[..., None]
    glow[y0:y1, x0:x1] = t
    (y0, y1, x0, x1), v, u = _reg('jaw')
    col[y0:y1, x0:x1] = grad(v, [(0, '1a1e3a'), (1, '05060e')])
    # ---- metal: dark gunmetal with gold rivets / trim
    (y0, y1, x0, x1), v, u = _reg('metal')
    trim = np.maximum(ss(0.2, 0.1, v), ss(0.8, 0.9, v))
    col[y0:y1, x0:x1] = hx('20242e') * (1 - trim[..., None]) + hx('ffc23a') * trim[..., None]
    rgh[y0:y1, x0:x1] = 0.3
    glow[y0:y1, x0:x1] = trim * 0.25
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
    ix, iz, ox, oz = 0.06, 1.38, 0.2, 1.45
    ex, ez = ox - ix, oz - iz
    L = math.hypot(ex, ez)
    s = ((aX - ix) * ex + (Z - iz) * ez) / (L * L)
    d = (-(aX - ix) * ez + (Z - iz) * ex) / L
    sc = np.clip(s, 0, 1)
    top = 0.032 * np.clip(sc * 3.0, 0, 1) * (1 - sc ** 4) + 0.002
    bot = -0.022 * np.clip(np.sin(math.pi * sc), 0, 1) ** 0.9 - 0.001
    eye = ss(0.003, 0.0, np.maximum(d - top, bot - d)) * (s > 0) * (s < 1)
    cxs, czs = ix + 0.5 * ex, iz + 0.5 * ez
    rr = np.sqrt((aX - cxs) ** 2 + (Z - czs) ** 2)
    _face_layers.rr = rr
    iris = ss(0.048, 0.044, rr)
    slit = ss(0.006 * np.clip(1 - ((Z - czs) / 0.035) ** 2, 0, 1) + 0.0005, 0.0, np.abs(aX - cxs)) * ss(0.034, 0.03, rr)
    brow = np.maximum(_seg(aX, Z, (0.03, 1.42), (0.22, 1.51), 0.014, 0.006), _seg(aX, Z, (0.2, 1.5), (0.27, 1.56), 0.008, 0.001))
    lid = ss(0.006, 0.003, np.abs(d - top - 0.003)) * (s > -0.05) * (s < 1.02)
    zc = 1.42 + 0.06 * aX
    hh = 0.06 * np.clip(1 - (aX / 0.3) ** 2, 0, 1) + 0.004
    mask = ss(0.004, 0.0, np.abs(Z - zc) - hh) * (aX < 0.31)
    mark = np.maximum(_seg(aX, Z, (0.16, 1.34), (0.21, 1.27), 0.01, 0.002), _seg(aX, Z, (0.21, 1.27), (0.18, 1.22), 0.008, 0.002))
    if level >= 2:
        mark = np.maximum(mark, _seg(aX, Z, (0.0, 1.5), (0.03, 1.58), 0.01, 0.003))
    if level >= 3:
        mark = np.maximum(mark, _seg(aX, Z, (0.08, 1.52), (0.13, 1.6), 0.007, 0.002))
    snarl = _seg(aX, Z, (0.0, 1.17), (0.13, 1.2), 0.006, 0.004)
    fang = ss(0.08, 0.0, np.abs(aX - 0.08) / 0.013 + (1.185 - Z) / 0.045 - 1) * (Z < 1.185) * (Z > 1.14)
    return X, Z, eye, iris, slit, brow, lid, mask, mark, snarl, fang


def face_texture(level, size=512):
    X, Z, eye, iris, slit, brow, lid, mask, mark, snarl, fang = _face_layers(level, size)
    rr = _face_layers.rr
    ed, em, eh = EYE[level]
    bd, bm, bh = BOLT[level]
    rgba = np.zeros((size, size, 4), np.float32)
    c = np.zeros((size, size, 3), np.float32) + hx('04050c')
    c = c * (1 - mark[..., None]) + hx(bm) * mark[..., None]
    irisc = grad(np.clip(1 - rr / 0.044, 0, 1), [(0, ed), (0.45, em), (1, eh)])
    e = hx('0a0a10') * (1 - iris[..., None]) + irisc * iris[..., None]
    e = e * (1 - slit[..., None]) + hx('020204') * slit[..., None]
    c = c * (1 - eye[..., None]) + e * eye[..., None]
    ln = np.maximum.reduce([lid, brow, snarl])
    c = c * (1 - ln[..., None]) + hx('020308') * ln[..., None]
    c = c * (1 - fang[..., None]) + hx('f2f4ff') * fang[..., None]
    rgba[..., :3] = c
    rgba[..., 3] = np.clip(np.maximum.reduce([mask * 0.85, eye, ln, mark, fang]), 0, 1)
    return rgba


def face_emissive(level, size=512):
    X, Z, eye, iris, slit, brow, lid, mask, mark, snarl, fang = _face_layers(level, size)
    g = np.clip(np.maximum(iris * eye * (1 - slit), mark * 0.9), 0, 1)
    return np.repeat(g[..., None], 3, -1)


# ---------------------------------------------------------------- animation (24 fps, in place, it runs)
# A restless storm wolf: weight shifting, ears flicking, tail swishing, a crackling shake of the ruff. Casts:
# Knockback (Runner, the Ability clip) plants, rears its head and slams a shockwave down with both forepaws; Storm Ball
# (Catcher, the Howl clip) crouches, then throws its head up in a howl (the ball fires from its maw).
def _ease(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def _pulse(t, a, b):
    if t <= a or t >= b:
        return 0.0
    return math.sin(math.pi * (t - a) / (b - a))


def _tail(w, amp, lift=0.0):
    return {'Tail1': P(('z', amp * math.sin(w)), ('x', -lift)), 'Tail2': P(('z', amp * 1.2 * math.sin(w - 0.7))),
            'Tail3': P(('z', amp * 1.4 * math.sin(w - 1.4)))}


def anim_idle():
    F = 72
    keys = {}
    for f in range(0, F + 1, 3):
        t = f / F
        w = 2 * math.pi * t
        shake = _pulse(t, 0.6, 0.72) * math.sin(w * 18)
        k = {'Body': P(('y', 2 * math.sin(w)), loc=(0, 0, 0.012 * math.sin(2 * w))),
             'Chest': P(('x', 1.5 * math.sin(2 * w)), ('y', 4 * shake)),
             'Neck': P(('x', -4 + 3 * math.sin(w)), ('z', 10 * math.sin(w * 0.5))),
             'Head': P(('z', 8 * math.sin(w + 1)), ('y', 6 * shake)), 'Jaw': P(('x', 4 * _pulse(t, 0.3, 0.4))),
             'Ear.L': P(('x', -20 * _pulse(t, 0.2, 0.26))), 'Ear.R': P(('x', -20 * _pulse(t, 0.42, 0.48)))}
        k.update(_tail(w, 16, -8))
        keys[f] = k
    keys[F] = dict(keys[0])
    return {'frames': F, 'loop': True, 'keys': keys}


def _gait(frames, swing, lift, bounce, pitch, tail):
    keys = {}
    for f in range(0, frames + 1, 2):
        t = f / frames
        w = 2 * math.pi * t
        p = {'Body': P(('x', pitch + 3 * math.sin(2 * w)), loc=(0, 0, bounce * abs(math.sin(w)))),
             'Neck': P(('x', -pitch * 0.6 + 3 * math.sin(2 * w))), 'Head': P(('x', -pitch * 0.3)),
             'Ear.L': P(('x', 15)), 'Ear.R': P(('x', 15))}
        for s, off in (('L', 0.0), ('R', math.pi)):
            for pre, ph in (('Front', w + off), ('Back', w + off + math.pi * 0.9)):
                sw = math.sin(ph) * swing
                lf = max(0.0, math.cos(ph)) * lift
                p[pre + 'Upper.' + s] = P(('x', -sw))
                p[pre + 'Lower.' + s] = P(('x', lf * (0.9 if pre == 'Front' else -0.9)))
                p[pre + 'Foot.' + s] = P(('x', sw * 0.4))
        p.update(_tail(w, tail, -12))
        keys[f] = p
    keys[frames] = dict(keys[0])
    return {'frames': frames, 'loop': True, 'keys': keys}


def anim_walk():
    return _gait(24, 26, 34, 0.03, 0, 10)


def anim_run():
    """a gallop: legs reach long, the body stretches into the stride."""
    keys = {}
    F = 14
    for f in range(0, F + 1, 1):
        t = f / F
        w = 2 * math.pi * t
        p = {'Body': P(('x', 8 * math.sin(w)), loc=(0, 0, 0.06 + 0.1 * max(0, math.sin(w)))),
             'Chest': P(('x', -6 * math.sin(w))), 'Neck': P(('x', 10 - 6 * math.sin(w))), 'Head': P(('x', -4)),
             'Ear.L': P(('x', 30)), 'Ear.R': P(('x', 30))}
        for s, o in (('L', 0.25), ('R', 0.0)):
            p['FrontUpper.' + s] = P(('x', -50 * math.sin(w + o)))
            p['FrontLower.' + s] = P(('x', 40 * max(0, math.cos(w + o))))
            p['BackUpper.' + s] = P(('x', 46 * math.sin(w + o + 0.9)))
            p['BackLower.' + s] = P(('x', -38 * max(0, math.cos(w + o + 0.9))))
        p.update(_tail(w, 6, -20))
        keys[f] = p
    return {'frames': F, 'loop': True, 'keys': keys}


def anim_hop():
    keys = {}
    for f in range(0, 17, 2):
        t = f / 16
        upv = math.sin(math.pi * t)
        p = {'Body': P(('x', -10 * upv), loc=(0, 0, 0.45 * upv))}
        for s in 'LR':
            p['BackUpper.' + s] = P(('x', 35 * upv))
            p['FrontUpper.' + s] = P(('x', -35 * upv))
        keys[f] = p
    return {'frames': 16, 'loop': False, 'keys': keys}


def anim_ability():
    """Knockback (~1 s): rears its head with a snarl, forepaws lift, then slams them down with the head driving
    forward (the shockwave at ~0.5)."""
    keys = {}
    F = 24
    for f in range(0, F + 1, 2):
        t = f / F
        rear = _ease(t / 0.4) * (1 - _ease((t - 0.42) / 0.1))
        slam = _ease((t - 0.42) / 0.1) * (1 - _ease((t - 0.72) / 0.28))
        p = {'Body': P(('x', -24 * rear + 4 * slam), loc=(0, 0, 0.03 * rear)),
             'Neck': P(('x', -18 * rear + 14 * slam)), 'Head': P(('x', -10 * rear + 8 * slam)),
             'Jaw': P(('x', 22 * rear + 28 * slam)), 'Ear.L': P(('x', 25 * slam)), 'Ear.R': P(('x', 25 * slam))}
        for s, x in (('L', 1), ('R', -1)):
            p['FrontUpper.' + s] = P(('x', -45 * rear - 10 * slam), ('y', -x * 10 * slam))
            p['FrontLower.' + s] = P(('x', 60 * rear))
            p['BackUpper.' + s] = P(('x', 20 * rear))
            p['BackLower.' + s] = P(('x', -14 * rear))
        p.update(_tail(6 * t, 10, -25 * rear))
        keys[f] = p
    return {'frames': F, 'loop': False, 'keys': keys}


def anim_howl():
    """Storm Ball (~0.9 s, Catcher): crouches low, then throws its head up in a howl with the jaw wide (the ball
    fires), and settles."""
    keys = {}
    F = 22
    for f in range(0, F + 1, 1):
        t = f / F
        crouch = _ease(t / 0.3) * (1 - _ease((t - 0.3) / 0.1))
        howl = _ease((t - 0.3) / 0.12) * (1 - _ease((t - 0.75) / 0.25))
        p = {'Body': P(('x', -3 * crouch - 10 * howl), loc=(0, 0, -0.03 * crouch)),
             'Neck': P(('x', 14 * crouch - 34 * howl)), 'Head': P(('x', 8 * crouch - 18 * howl)),
             'Jaw': P(('x', 40 * howl)), 'Ear.L': P(('x', 25 * crouch - 15 * howl)), 'Ear.R': P(('x', 25 * crouch - 15 * howl))}
        for s in 'LR':
            p['FrontUpper.' + s] = P(('x', -8 * crouch - 12 * howl))
            p['BackUpper.' + s] = P(('x', -6 * crouch + 8 * howl))
            p['BackLower.' + s] = P(('x', 10 * crouch))
        p.update(_tail(6 * t, 8, 20 * howl))
        keys[f] = p
    return {'frames': F, 'loop': False, 'keys': keys}


ANIMS = {'Idle': anim_idle, 'Walk': anim_walk, 'Run': anim_run, 'Hop': anim_hop, 'Ability': anim_ability,
         'Howl': anim_howl}
