# Shrine Lion (Guardian, Epic) for Hatch or Snatch: HOS-PET-024, built on the pet kit. Assembled by assemble_pet.py.
# From the concept-library card (docs/pets/shrine_lion/shrine_lion_card.png): a white shrine guardian lion (komainu)
# with a red curly mane and tail tuft, red horns, gold bells on a green rope collar and a fierce yellow-eyed snarl.
# Read through PET_LESSONS (anime / edgy): white fur with fur strokes and red swirl markings, near-black lips and claws,
# narrow slanted glowing gold slit eyes under a heavy red brow, a snarl with fangs (face decal shell). L2 "Temple
# Guard": gold chest armour, more bells, red tassels. L3 "Divine Guardian": a flame mane of gold-red blades, a jade
# forehead gem, a flame tail, gold-white glow.
# Reshaped 17 Oct (HOS-PET-RESHAPE): its own body plan, a heavy komainu with a huge square head inside an enormous
# three-ring mane, a broad barrel chest, short thick legs and big paws; its idle sits upright on guard like a statue.
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

NAME = 'Lion'
SHARP_ANGLE = 40
NORMAL_STRENGTH = 2.0
TS = 1024
ATLAS = Atlas({
    'skin': (0, 0, 1024, 384),
    'head': (0, 384, 512, 256),
    'limb': (512, 384, 512, 128),
    'tail': (512, 512, 512, 128),
    'mane': (0, 640, 256, 128),     # red curly tufts: v root -> tip
    'horn': (256, 640, 128, 128),
    'claw': (384, 640, 128, 128),
    'rope': (512, 640, 256, 128),
    'gold': (768, 640, 256, 128),
    'jaw': (0, 768, 256, 128),
    'flame': (256, 768, 256, 128),
    'jade': (512, 768, 128, 128),
})

GLOW = {1: ('b06a00', 'ffd23a', 'fff6c0'), 2: ('b06a00', 'ffe04a', 'fffbe0'), 3: ('c84a00', 'ffb02a', 'fffbe8')}
EYE = {1: ('b06a00', 'ffd23a', 'fff6c0'), 2: ('b06a00', 'ffe04a', 'fffbe0'), 3: ('2a8a5a', '6affb0', 'f0fff6')}
FUR = [(0, '8a8a9a'), (0.5, 'e4e2ea'), (1, 'fcfbff')]
RED = [(0, '5a0a0a'), (0.5, 'c81e1e'), (1, 'ff6a4a')]


def bones_def():
    b = [
        ('Root', V(0, 0, 0), V(0, 0, 0.2), None),
        ('Body', V(0, 0.3, 0.62), V(0, -0.08, 0.66), 'Root'),
        ('Chest', V(0, -0.08, 0.66), V(0, -0.36, 0.84), 'Body'),
        ('Head', V(0, -0.42, 1.0), V(0, -1.08, 0.98), 'Chest'),
        ('Jaw', V(0, -0.7, 0.84), V(0, -1.1, 0.78), 'Head'),
        ('Tail1', V(0, 0.5, 0.7), V(0, 0.66, 0.96), 'Body'),
        ('Tail2', V(0, 0.66, 0.96), V(0, 0.62, 1.26), 'Tail1'),
        ('Tail3', V(0, 0.62, 1.26), V(0, 0.44, 1.36), 'Tail2'),
        ('Bells', V(0, -0.42, 0.66), V(0, -0.6, 0.5), 'Chest'),
    ]
    for s, x in (('L', 1), ('R', -1)):
        b += [
            ('Ear.' + s, V(x * 0.34, -0.56, 1.2), V(x * 0.46, -0.5, 1.4), 'Head'),
            ('FrontUpper.' + s, V(x * 0.3, -0.26, 0.56), V(x * 0.31, -0.3, 0.3), 'Chest'),
            ('FrontLower.' + s, V(x * 0.31, -0.3, 0.3), V(x * 0.32, -0.32, 0.1), 'FrontUpper.' + s),
            ('FrontFoot.' + s, V(x * 0.32, -0.32, 0.1), V(x * 0.32, -0.48, 0.05), 'FrontLower.' + s),
            ('BackUpper.' + s, V(x * 0.3, 0.34, 0.56), V(x * 0.32, 0.26, 0.3), 'Body'),
            ('BackLower.' + s, V(x * 0.32, 0.26, 0.3), V(x * 0.32, 0.34, 0.1), 'BackUpper.' + s),
            ('BackFoot.' + s, V(x * 0.32, 0.34, 0.1), V(x * 0.32, 0.2, 0.05), 'BackLower.' + s),
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

FX, FZ, FZH = 0.55, 0.96, 0.45
SHELL = (-0.86, 0.51, 1.41)
DFX, DFZ, DFZH = 0.44, 1.14, 0.36    # the face decal is drawn in these units, then mapped onto FX / FZ / FZH
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
    W_B, W_C, W_H, W_J = {'Body': 1}, {'Chest': 1}, {'Head': 1}, {'Jaw': 1}
    # heavy komainu: a short, broad barrel with a huge chest, low on short thick legs
    st = [(V(0, 0.56, 0.7), (0.18, 0.17), {'Body': 0.5, 'Tail1': 0.5}), (V(0, 0.44, 0.66), (0.38, 0.36), W_B),
          (V(0, 0.18, 0.64), (0.42, 0.4), W_B), (V(0, -0.1, 0.68), (0.48, 0.46), {'Body': 0.5, 'Chest': 0.5}),
          (V(0, -0.3, 0.8), (0.46, 0.48), W_C), (V(0, -0.44, 0.94), (0.32, 0.34), {'Chest': 0.5, 'Head': 0.5})]
    tube(mb, 'skin', [s[0] for s in st], [s[1] for s in st], 14, [s[2] for s in st], 'body',
         start='point', end='point', start_pt=V(0, 0.62, 0.72), end_pt=V(0, -0.5, 1.02), side_hint=V(1, 0, 0), th0=math.pi / 2)
    n0 = len(mb.F)
    # a huge square guardian head
    hs = [(V(0, -0.44, 1.0), (0.34, 0.34), W_H), (V(0, -0.66, 1.04), (0.54, 0.45), W_H),
          (V(0, -0.88, 0.98), (0.48, 0.38), W_H), (V(0, -1.05, 0.9), (0.32, 0.25), W_H), (V(0, -1.16, 0.85), (0.2, 0.16), W_H)]
    tube(mb, 'head', [h[0] for h in hs], [h[1] for h in hs], 12, [h[2] for h in hs], 'head', start='point', end='point',
         start_pt=V(0, -0.34, 1.02), end_pt=V(0, -1.24, 0.83), side_hint=V(1, 0, 0), th0=math.pi / 2)
    head_faces = list(range(n0, len(mb.F)))
    js = [(V(0, -0.74, 0.76), (0.32, 0.1), W_J), (V(0, -0.96, 0.72), (0.25, 0.09), W_J), (V(0, -1.12, 0.7), (0.15, 0.06), W_J)]
    tube(mb, 'jaw', [j[0] for j in js], [j[1] for j in js], 8, [j[2] for j in js], 'jaw', start='point', end='point',
         start_pt=V(0, -0.62, 0.78), end_pt=V(0, -1.2, 0.7), side_hint=V(1, 0, 0), th0=math.pi / 2)
    # small ears and red swept horns
    for s, x in (('L', 1), ('R', -1)):
        bipyramid(mb, V(x * 0.33, -0.56, 1.18), V(x * 0.5, -0.5, 1.4), V(0, 1, 0), V(0, -1, 0.1), 0.2, 0.07,
                  {'Ear.' + s: 1}, ATLAS.uv('mane', 0.5, 0.9), ATLAS.uv('mane', 0.5, 0.1), 'ear', wide_at=0.4, ridge_at=0.4)
        path = [V(x * 0.17, -0.72, 1.32), V(x * 0.25, -0.62, 1.56), V(x * 0.3, -0.44, 1.72), V(x * 0.32, -0.26, 1.76)]
        d = nrm(path[-1] - path[-2])
        tube(mb, 'horn', path, [(0.085, 0.07), (0.065, 0.06), (0.042, 0.036), (0.024, 0.024)], 6, [W_H] * 4, 'horn',
             start='point', end='point', start_pt=V(x * 0.15, -0.74, 1.22), end_pt=path[-1] + d * 0.14, anti=False,
             side_hint=V(-1, 0, 0))
    # an enormous red curly mane: three rings of tufts round the head, neck and chest
    for ring_, (cy, cz, rx, rz, ln, n) in enumerate(((-0.5, 1.04, 0.46, 0.42, 0.42, 14), (-0.32, 0.9, 0.5, 0.48, 0.38, 12),
                                                     (-0.16, 0.76, 0.5, 0.48, 0.3, 10))):
        for k in range(n):
            a = math.radians(-150 + 300 * k / (n - 1))
            d = nrm(V(math.sin(a), 0.6, math.cos(a)))
            base = V(math.sin(a) * rx * 0.75, cy, cz + math.cos(a) * rz * 0.75)
            bipyramid(mb, base, base + d * ln, V(0, 0, 1) if abs(math.sin(a)) > 0.5 else V(1, 0, 0), V(0, -1, 0),
                      0.21, 0.09, {'Head': 0.6, 'Chest': 0.4} if ring_ == 0 else W_C,
                      ATLAS.uv('mane', 0.5, 0.1), ATLAS.uv('mane', 0.5, 0.95), 'mane', wide_at=0.35, ridge_at=0.35)
    # green rope collar with gold bells
    cen = [V(0, -0.4, 0.8) + V(math.cos(2 * math.pi * i / 14) * 0.44, 0.07 * math.sin(2 * math.pi * i / 14), math.sin(2 * math.pi * i / 14) * 0.46)
           for i in range(15)]
    tube(mb, 'rope', cen, [(0.065, 0.065)] * 15, 6, [W_C] * 15, 'rope', start='open', end='open', side_hint=V(0, 1, 0), anti=False)
    for bx in (-0.26, 0.0, 0.26):
        c = V(bx, -0.72, 0.5 + 0.06 * abs(bx) * 4)
        tube(mb, 'gold', [c + V(0, 0, 0.12), c + V(0, 0, 0.07), c, c - V(0, 0, 0.07)], [(0.036, 0.036), (0.11, 0.11), (0.13, 0.13), (0.1, 0.1)],
             8, [{'Bells': 1}] * 4, 'bell', start='point', end='point', start_pt=c + V(0, 0, 0.15), end_pt=c - V(0, 0, 0.12),
             side_hint=V(1, 0, 0))
    # short, thick legs with big red-tufted paws and dark claws
    for s, x in (('L', 1), ('R', -1)):
        fu, fl, ff = 'FrontUpper.' + s, 'FrontLower.' + s, 'FrontFoot.' + s
        front = [(V(x * 0.3, -0.24, 0.62), (0.2, 0.21), {'Chest': 0.6, fu: 0.4}), (V(x * 0.31, -0.28, 0.42), (0.16, 0.16), {fu: 1}),
                 (V(x * 0.31, -0.3, 0.3), (0.14, 0.14), {fu: 0.5, fl: 0.5}), (V(x * 0.32, -0.32, 0.16), (0.14, 0.14), {fl: 1}),
                 (V(x * 0.32, -0.38, 0.07), (0.17, 0.08), {fl: 0.3, ff: 0.7})]
        tube(mb, 'limb', [f[0] for f in front], [f[1] for f in front], 8, [f[2] for f in front], 'front' + s,
             start='point', end='point', start_pt=V(x * 0.16, -0.22, 0.68), end_pt=V(x * 0.32, -0.54, 0.05))
        bu, bl, bf = 'BackUpper.' + s, 'BackLower.' + s, 'BackFoot.' + s
        back = [(V(x * 0.3, 0.34, 0.62), (0.22, 0.26), {'Body': 0.6, bu: 0.4}), (V(x * 0.32, 0.28, 0.42), (0.18, 0.18), {bu: 1}),
                (V(x * 0.32, 0.26, 0.3), (0.15, 0.15), {bu: 0.5, bl: 0.5}), (V(x * 0.32, 0.32, 0.16), (0.14, 0.14), {bl: 1}),
                (V(x * 0.32, 0.28, 0.07), (0.17, 0.08), {bl: 0.3, bf: 0.7})]
        tube(mb, 'limb', [f[0] for f in back], [f[1] for f in back], 8, [f[2] for f in back], 'back' + s,
             start='point', end='point', start_pt=V(x * 0.16, 0.34, 0.68), end_pt=V(x * 0.32, 0.14, 0.05))
        for foot, bone in ((V(x * 0.32, -0.5, 0.06), ff), (V(x * 0.32, 0.16, 0.06), bf)):
            for k in (-1, 0, 1):
                b0 = foot + V(k * 0.07, 0, 0)
                bipyramid(mb, b0, b0 + nrm(V(k * 0.3, -1, -0.3)) * 0.12, V(1, 0, 0), V(0, 0, 1), 0.05, 0.045, {bone: 1},
                          ATLAS.uv('claw', 0.5, 0.15), ATLAS.uv('claw', 0.5, 0.9), 'claw', wide_at=0.3, ridge_at=0.3)
        spike_base = V(x * 0.36, -0.32, 0.24)
        bipyramid(mb, spike_base, spike_base + V(x * 0.16, 0.06, 0.06), V(0, 0, 1), V(0, -1, 0), 0.12, 0.06, {fl: 1},
                  ATLAS.uv('mane', 0.5, 0.1), ATLAS.uv('mane', 0.5, 0.95), 'mane', wide_at=0.3, ridge_at=0.3)
    # tail curled up over the back with a big red tuft
    tp = [V(0, 0.52, 0.7), V(0, 0.7, 0.92), V(0, 0.68, 1.2), V(0, 0.5, 1.32)]
    tube(mb, 'tail', tp, [(0.12, 0.12), (0.13, 0.13), (0.12, 0.12), (0.1, 0.1)], 8,
         [{'Body': 0.4, 'Tail1': 0.6}, {'Tail1': 1}, {'Tail2': 1}, {'Tail3': 1}], 'tail', start='point', end='point',
         start_pt=V(0, 0.46, 0.68), end_pt=V(0, 0.42, 1.34))
    for d in (V(0.6, -0.4, 0.5), V(-0.6, -0.4, 0.5), V(0, -0.6, 0.6), V(0, -0.2, 1), V(0.7, 0.2, 0.6), V(-0.7, 0.2, 0.6)):
        bipyramid(mb, V(0, 0.48, 1.32), V(0, 0.48, 1.32) + nrm(d) * 0.34, V(1, 0, 0) if abs(d[0]) < 0.1 else V(0, 0, 1), V(0, -1, 0),
                  0.19, 0.08, {'Tail3': 1}, ATLAS.uv('mane', 0.5, 0.1), ATLAS.uv('mane', 0.5, 0.95), 'mane', wide_at=0.35, ridge_at=0.35)
    mb.mat = 1
    face_shell(mb, head_faces)
    # ---- L2 "Temple Guard": gold chest plate, two more bells, red tassels on the collar
    mb.mat = 2
    bipyramid(mb, V(0, -0.62, 0.82), V(0, -0.68, 0.42), V(1, 0, 0), V(0, -1, 0), 0.5, 0.12, W_C,
              ATLAS.uv('gold', 0.4, 0.8), ATLAS.uv('gold', 0.6, 0.2), 'L2', wide_at=0.4, ridge_at=0.4)
    for x in (1, -1):
        c = V(x * 0.44, -0.5, 0.62)
        tube(mb, 'gold', [c + V(0, 0, 0.12), c + V(0, 0, 0.06), c, c - V(0, 0, 0.06)], [(0.03, 0.03), (0.1, 0.1), (0.12, 0.12), (0.085, 0.085)],
             8, [{'Bells': 1}] * 4, 'L2', start='point', end='point', start_pt=c + V(0, 0, 0.14), end_pt=c - V(0, 0, 0.11),
             side_hint=V(1, 0, 0))
        bipyramid(mb, V(x * 0.36, -0.42, 0.72), V(x * 0.4, -0.48, 0.38), V(1, 0, 0), V(0, -1, 0), 0.1, 0.05, W_C,
                  ATLAS.uv('mane', 0.5, 0.1), ATLAS.uv('mane', 0.5, 0.95), 'L2', wide_at=0.3, ridge_at=0.3)
    # ---- L3 "Divine Guardian": a flame mane crown, a jade forehead gem, a flame tail
    mb.mat = 3
    for k in range(7):
        a = math.radians(-75 + 150 * k / 6)
        base = V(math.sin(a) * 0.38, -0.5, 1.22 + math.cos(a) * 0.24)
        tip = base + nrm(V(math.sin(a) * 0.7, 0.5, math.cos(a) + 0.3)) * (0.5 if k == 3 else 0.4)
        bipyramid(mb, base, tip, V(1, 0, 0) if abs(math.sin(a)) < 0.5 else V(0, 0, 1), V(0, -1, 0), 0.17, 0.06, W_H,
                  ATLAS.uv('flame', 0.5, 0.05), ATLAS.uv('flame', 0.5, 0.95), 'L3', wide_at=0.3, ridge_at=0.3)
    bipyramid(mb, V(0, -0.98, 1.18), V(0, -1.05, 1.18), V(1, 0, 0), V(0, 0, 1), 0.14, 0.16, W_H,
              ATLAS.uv('jade', 0.5, 0.2), ATLAS.uv('jade', 0.5, 0.8), 'L3', wide_at=0.5, ridge_at=0.5)
    for d in (V(0.4, 0.2, 0.9), V(-0.4, 0.2, 0.9), V(0, 0.5, 0.9)):
        bipyramid(mb, V(0, 0.5, 1.34), V(0, 0.5, 1.34) + nrm(d) * 0.42, V(1, 0, 0) if abs(d[0]) < 0.1 else V(0, 1, 0), V(0, -1, 0),
                  0.15, 0.06, {'Tail3': 1}, ATLAS.uv('flame', 0.5, 0.05), ATLAS.uv('flame', 0.5, 0.95), 'L3', wide_at=0.3, ridge_at=0.3)
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



def paint_atlas(level):
    col = np.zeros((TS, TS, 3), np.float32)
    hgt = np.full((TS, TS), 0.5, np.float32)
    rgh = np.full((TS, TS), 0.6, np.float32)
    glow = np.zeros((TS, TS), np.float32)
    gd, gm, gh = GLOW[level]
    for reg in ('skin', 'head', 'tail'):
        (y0, y1, x0, x1), v, u = _reg(reg)
        h, w = y1 - y0, x1 - x0
        top = np.cos(u * 2 * math.pi)
        c = grad(np.clip(0.55 + 0.35 * top, 0, 1), FUR)
        # red swirl markings: curling bands on the flanks / haunches
        sw = ss(0.03, 0.0, np.abs(_saw(u * 3 + np.sin(v * 9) * 0.25) - 0.5) - 0.05) * ss(-0.2, 0.3, top) * (reg == 'skin')
        sw = sw * ss(0.15, 0.25, v) * ss(0.85, 0.75, v)
        c = c * (1 - sw[..., None]) + grad(np.clip(v, 0, 1), RED) * sw[..., None]
        st = _streaks(h, w, 170, 81)
        col[y0:y1, x0:x1] = c * (1 + 0.2 * st[..., None])
        hgt[y0:y1, x0:x1] = 0.5 + 0.4 * st
        glow[y0:y1, x0:x1] = sw * 0.2 * (level >= 2)
    (y0, y1, x0, x1), v, u = _reg('limb')
    st = _streaks(y1 - y0, x1 - x0, 60, 82)
    col[y0:y1, x0:x1] = grad(np.clip(0.8 - 0.25 * v, 0, 1), FUR) * (1 + 0.2 * st[..., None])
    hgt[y0:y1, x0:x1] = 0.5 + 0.4 * st
    (y0, y1, x0, x1), v, u = _reg('mane')
    st = _streaks(y1 - y0, x1 - x0, 50, 83)
    curl = 0.5 + 0.5 * np.cos(u * 2 * math.pi * 3 + v * 6)
    col[y0:y1, x0:x1] = grad(np.clip(0.3 + 0.7 * v, 0, 1), RED) * (0.8 + 0.25 * curl[..., None]) * (1 + 0.2 * st[..., None])
    hgt[y0:y1, x0:x1] = 0.5 + 0.4 * st
    (y0, y1, x0, x1), v, u = _reg('horn')
    ridges = 0.5 + 0.5 * np.cos(v * 2 * math.pi * 6)
    col[y0:y1, x0:x1] = grad(v, [(0, '6a0a0a'), (0.7, 'd8282a'), (1, gh)]) * (0.85 + 0.15 * ridges[..., None])
    glow[y0:y1, x0:x1] = ss(0.85, 1.0, v)
    (y0, y1, x0, x1), v, u = _reg('claw')
    col[y0:y1, x0:x1] = hx('120a0a')
    (y0, y1, x0, x1), v, u = _reg('rope')
    twist = 0.5 + 0.5 * np.cos((u * 3 + v * 10) * 2 * math.pi)
    col[y0:y1, x0:x1] = grad(twist, [(0, '0a3a2a'), (1, '2a8a5a')])
    hgt[y0:y1, x0:x1] = 0.5 + 0.4 * twist
    (y0, y1, x0, x1), v, u = _reg('gold')
    col[y0:y1, x0:x1] = grad(v, [(0, 'fff0a0'), (0.5, 'ffc23a'), (1, '8a5a0a')])
    rgh[y0:y1, x0:x1] = 0.25
    glow[y0:y1, x0:x1] = 0.15 + 0.15 * (level >= 2)
    (y0, y1, x0, x1), v, u = _reg('jaw')
    col[y0:y1, x0:x1] = grad(v, [(0, 'e4e2ea'), (0.5, '3a0a0a'), (1, '120606')])
    (y0, y1, x0, x1), v, u = _reg('flame')
    col[y0:y1, x0:x1] = grad(v, [(0, gh), (0.4, gm), (1, 'c81e1e')])
    glow[y0:y1, x0:x1] = 1.0 - 0.5 * v
    (y0, y1, x0, x1), v, u = _reg('jade')
    col[y0:y1, x0:x1] = grad(v, [(0, 'c0ffe0'), (0.5, '2ac87a'), (1, '0a5a3a')])
    rgh[y0:y1, x0:x1] = 0.1
    glow[y0:y1, x0:x1] = 0.8
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
    X, Z = x * DFX, DFZ + y * DFZH
    aX = np.abs(X)
    ix, iz, ox, oz = 0.08, 1.18, 0.27, 1.26
    ex, ez = ox - ix, oz - iz
    L = math.hypot(ex, ez)
    s = ((aX - ix) * ex + (Z - iz) * ez) / (L * L)
    d = (-(aX - ix) * ez + (Z - iz) * ex) / L
    sc = np.clip(s, 0, 1)
    top = 0.038 * np.clip(sc * 3.0, 0, 1) * (1 - sc ** 4) + 0.002
    bot = -0.028 * np.clip(np.sin(math.pi * sc), 0, 1) ** 0.9 - 0.001
    eye = ss(0.003, 0.0, np.maximum(d - top, bot - d)) * (s > 0) * (s < 1)
    cxs, czs = ix + 0.5 * ex, iz + 0.5 * ez
    rr = np.sqrt((aX - cxs) ** 2 + (Z - czs) ** 2)
    _face_layers.rr = rr
    iris = ss(0.056, 0.052, rr)
    slit = ss(0.007 * np.clip(1 - ((Z - czs) / 0.04) ** 2, 0, 1) + 0.0005, 0.0, np.abs(aX - cxs)) * ss(0.04, 0.036, rr)
    brow = np.maximum(_seg(aX, Z, (0.05, 1.22), (0.3, 1.33), 0.02, 0.008), _seg(aX, Z, (0.28, 1.32), (0.36, 1.38), 0.01, 0.001))
    lid = ss(0.007, 0.004, np.abs(d - top - 0.003)) * (s > -0.05) * (s < 1.02)
    mark = np.maximum(_seg(aX, Z, (0.2, 1.12), (0.26, 1.04), 0.012, 0.003), _seg(aX, Z, (0.3, 1.14), (0.36, 1.08), 0.009, 0.002))
    if level >= 2:
        mark = np.maximum(mark, _seg(aX, Z, (0.0, 1.34), (0.0, 1.42), 0.014, 0.004))
    snarl = np.maximum(_seg(aX, Z, (0.0, 0.98), (0.2, 1.02), 0.008, 0.006), _seg(aX, Z, (0.2, 1.02), (0.26, 1.08), 0.006, 0.002))
    fang = ss(0.08, 0.0, np.abs(aX - 0.1) / 0.016 + (0.99 - Z) / 0.06 - 1) * (Z < 0.99) * (Z > 0.93)
    nose = ss(0.004, 0.0, aX / 0.06 + np.abs(Z - 1.06) / 0.03 - 1)
    return X, Z, eye, iris, slit, brow, lid, mark, snarl, fang, nose


def face_texture(level, size=512):
    X, Z, eye, iris, slit, brow, lid, mark, snarl, fang, nose = _face_layers(level, size)
    rr = _face_layers.rr
    ed, em, eh = EYE[level]
    rgba = np.zeros((size, size, 4), np.float32)
    c = np.zeros((size, size, 3), np.float32) + hx('8a0a0a')
    irisc = grad(np.clip(1 - rr / 0.052, 0, 1), [(0, ed), (0.45, em), (1, eh)])
    e = hx('140808') * (1 - iris[..., None]) + irisc * iris[..., None]
    e = e * (1 - slit[..., None]) + hx('040202') * slit[..., None]
    c = c * (1 - eye[..., None]) + e * eye[..., None]
    c = c * (1 - brow[..., None]) + hx('a01414') * brow[..., None]
    ln = np.maximum(lid, snarl)
    c = c * (1 - ln[..., None]) + hx('0a0404') * ln[..., None]
    c = c * (1 - fang[..., None]) + hx('f8f6f0') * fang[..., None]
    c = c * (1 - nose[..., None]) + hx('1a0808') * nose[..., None]
    rgba[..., :3] = c
    rgba[..., 3] = np.clip(np.maximum.reduce([eye, brow, ln, mark, fang, nose]), 0, 1)
    return rgba


def face_emissive(level, size=512):
    X, Z, eye, iris, slit, brow, lid, mark, snarl, fang, nose = _face_layers(level, size)
    g = np.clip(iris * eye * (1 - slit), 0, 1)
    return np.repeat(g[..., None], 3, -1)


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



def _sit(k):
    """The komainu's seated guard pose, k = 0 (standing) .. 1 (seated): haunches down, chest up, forelegs straight."""
    p = {'Body': P(('x', -30 * k), loc=(0, 0.06 * k, -0.1 * k)), 'Chest': P(('x', 6 * k))}
    for s_ in 'LR':
        p['FrontUpper.' + s_] = P(('x', 24 * k))
        p['BackUpper.' + s_] = P(('x', 70 * k))
        p['BackLower.' + s_] = P(('x', -95 * k))
        p['BackFoot.' + s_] = P(('x', 45 * k))
    return p


def anim_idle():
    """Sits upright on guard like a shrine statue: slow breathing, the head turns to scan, a low growl, bells swing."""
    F = 96
    keys = {}
    for f in range(0, F + 1, 3):
        t = f / F
        w = 2 * math.pi * t
        growl = _pulse(t, 0.55, 0.72)
        k = _sit(1.0)
        k['Body'] = P(('x', -30 + 1.5 * math.sin(2 * w)), loc=(0, 0.06, -0.1 + 0.01 * math.sin(2 * w)))
        k.update({'Head': P(('z', 22 * math.sin(w)), ('x', 4 - 6 * growl)), 'Jaw': P(('x', 16 * growl)),
                  'Bells': P(('x', 30 + 6 * math.sin(2 * w)), ('y', 5 * math.sin(w))),
                  'Ear.L': P(('x', -15 * _pulse(t, 0.2, 0.28))), 'Ear.R': P(('x', -15 * _pulse(t, 0.3, 0.38)))})
        k.update(_tail(w, 8, 10))
        keys[f] = k
    keys[F] = dict(keys[0])
    return {'frames': F, 'loop': True, 'keys': keys}


def anim_walk():
    return _gait(22, 22, 30, 0.04, 0, 8)


def anim_run():
    return _gait(13, 36, 44, 0.1, 5, 6)


def anim_hop():
    keys = {}
    for f in range(0, 17, 2):
        t = f / 16
        upv = math.sin(math.pi * t)
        p = {'Body': P(('x', -10 * upv), loc=(0, 0, 0.3 * upv))}
        for s in 'LR':
            p['BackUpper.' + s] = P(('x', 30 * upv))
            p['FrontUpper.' + s] = P(('x', -30 * upv))
        keys[f] = p
    return {'frames': 16, 'loop': False, 'keys': keys}


def anim_ability():
    """Shield (~1 s, Runner): rears up roaring, bells swinging, then stamps both forepaws down (the dome at ~0.5)."""
    keys = {}
    F = 24
    for f in range(0, F + 1, 2):
        t = f / F
        rear = _ease(t / 0.4) * (1 - _ease((t - 0.42) / 0.1))
        slam = _ease((t - 0.42) / 0.1) * (1 - _ease((t - 0.72) / 0.28))
        p = {'Body': P(('x', -32 * rear + 2 * slam), loc=(0, 0, 0.04 * rear)), 'Chest': P(('x', -8 * rear)),
             'Head': P(('x', -12 * rear + 10 * slam)), 'Jaw': P(('x', 30 * rear + 20 * slam)),
             'Bells': P(('x', -30 * rear + 25 * slam))}
        for s, x in (('L', 1), ('R', -1)):
            p['FrontUpper.' + s] = P(('x', -55 * rear - 6 * slam), ('y', -x * 12 * slam))
            p['FrontLower.' + s] = P(('x', 45 * rear))
            p['BackUpper.' + s] = P(('x', 30 * rear))
            p['BackLower.' + s] = P(('x', -16 * rear))
        p.update(_tail(6 * t, 10, -20 * rear))
        keys[f] = p
    return {'frames': F, 'loop': False, 'keys': keys}


def anim_roar():
    """Long Reach (~0.9 s, Catcher): plants, lowers its head, then roars forward with the jaw wide (the beam fires)."""
    keys = {}
    F = 22
    for f in range(0, F + 1, 1):
        t = f / F
        crouch = _ease(t / 0.3) * (1 - _ease((t - 0.3) / 0.1))
        roar = _ease((t - 0.3) / 0.1) * (1 - _ease((t - 0.7) / 0.3))
        p = {'Body': P(('x', -3 * crouch - 4 * roar), loc=(0, 0.08 * crouch - 0.12 * roar, 0)),
             'Chest': P(('x', 4 * crouch - 6 * roar)), 'Head': P(('x', 6 * crouch - 16 * roar), loc=(0, -0.1 * roar, 0)),
             'Jaw': P(('x', 40 * roar)), 'Bells': P(('x', 20 * roar))}
        for s in 'LR':
            p['FrontUpper.' + s] = P(('x', -6 * crouch - 15 * roar))
            p['BackUpper.' + s] = P(('x', -6 * crouch + 12 * roar))
        p.update(_tail(6 * t, 8, 15 * roar))
        keys[f] = p
    return {'frames': F, 'loop': False, 'keys': keys}


ANIMS = {'Idle': anim_idle, 'Walk': anim_walk, 'Run': anim_run, 'Hop': anim_hop, 'Ability': anim_ability,
         'Roar': anim_roar}
