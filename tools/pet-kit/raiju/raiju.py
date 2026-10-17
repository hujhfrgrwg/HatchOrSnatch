# Raiju (Tempest, Legendary) for Hatch or Snatch: HOS-PET-030, reshaped 17 Oct (HOS-PET-RESHAPE), redone 17 Oct
# (HOS-PET-REDO, Hunter: "small and thin, still blue/gold like the Riot Hound"): a deep barrel chest, a big wedge head,
# a three-ring lightning lion's mane, thicker legs; crimson coat with a black storm saddle and socks, white-hot yellow
# lightning, a tail burning to white at the tip. L3 lightning goes violet-white.
# From the concept card (docs/pets/raiju/raiju_card.png): a thunder beast with a huge gold lightning-flame mane, gold
# zig-zag stripes, white paws and chest, a blue flame tail and gold eyes.
# Body plan (its own, no longer the Hound's): a long, low lightning weasel on short legs, a slim tapering head, a very
# long flame tail that sweeps up behind it; it runs in a bounding lope. Bright electric cobalt with a big white
# underside (not the Hound's navy), glowing gold zig-zag stripes, a gold lightning mane round the neck, gold spine
# bolts, narrow gold slit eyes, a snarl with one fang (face decal shell). L2 "Storm Herald": a gold chest plate with a
# lightning crest, bolt pauldrons. L3 "Thunder God": a half-halo of lightning bolts over the neck, a bolt crown, tail
# bolt blades, gold leg bracers, white-cyan eyes and glow.
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

NAME = 'Raiju'
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

BOLT = {1: ('d08a00', 'ffdc40', 'fff8d0'), 2: ('e0a010', 'ffe866', 'fffbe8'), 3: ('6a2ad8', 'c8a8ff', 'ffffff')}
EYE = {1: ('c87a00', 'ffdc40', 'fff8d0'), 2: ('d08a00', 'ffe866', 'fffbe8'), 3: ('6a2ad8', 'd8c0ff', 'ffffff')}


# ---------------------------------------------------------------- skeleton
def bones_def():
    b = [
        ('Root', V(0, 0, 0), V(0, 0, 0.2), None),
        ('Body', V(0, 0.6, 0.6), V(0, -0.05, 0.64), 'Root'),
        ('Chest', V(0, -0.05, 0.64), V(0, -0.62, 0.74), 'Body'),
        ('Neck', V(0, -0.64, 0.78), V(0, -0.88, 0.98), 'Chest'),
        ('Head', V(0, -0.88, 1.0), V(0, -1.56, 0.92), 'Neck'),
        ('Jaw', V(0, -1.06, 0.88), V(0, -1.5, 0.82), 'Head'),
        ('Tail1', V(0, 1.0, 0.62), V(0, 1.38, 0.74), 'Body'),
        ('Tail2', V(0, 1.38, 0.74), V(0, 1.74, 1.02), 'Tail1'),
        ('Tail3', V(0, 1.74, 1.02), V(0, 1.9, 1.52), 'Tail2'),
    ]
    for s, x in (('L', 1), ('R', -1)):
        b += [
            ('Ear.' + s, V(x * 0.15, -0.94, 1.18), V(x * 0.27, -0.82, 1.48), 'Head'),
            ('FrontUpper.' + s, V(x * 0.21, -0.5, 0.58), V(x * 0.23, -0.55, 0.3), 'Chest'),
            ('FrontLower.' + s, V(x * 0.23, -0.55, 0.3), V(x * 0.24, -0.57, 0.09), 'FrontUpper.' + s),
            ('FrontFoot.' + s, V(x * 0.24, -0.57, 0.09), V(x * 0.24, -0.72, 0.03), 'FrontLower.' + s),
            ('BackUpper.' + s, V(x * 0.21, 0.64, 0.56), V(x * 0.24, 0.53, 0.29), 'Body'),
            ('BackLower.' + s, V(x * 0.24, 0.53, 0.29), V(x * 0.24, 0.63, 0.09), 'BackUpper.' + s),
            ('BackFoot.' + s, V(x * 0.24, 0.63, 0.09), V(x * 0.24, 0.5, 0.03), 'BackLower.' + s),
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


FX, FZ, FZH = 0.34, 1.01, 0.31
SHELL = (-1.0, 0.8, 1.26)            # face shell: faces with y < SHELL[0] and SHELL[1] < z < SHELL[2]
DFX, DFZ, DFZH = 0.36, 1.32, 0.34    # the face decal is drawn in these units, then mapped onto FX / FZ / FZH


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
    # long thunder beast: lean hips, a deep barrel chest, a thick neck rising to a big head (redo 17 Oct: bigger)
    st = [(V(0, 1.06, 0.62), (0.11, 0.11), {'Body': 0.5, 'Tail1': 0.5}),
          (V(0, 0.88, 0.6), (0.23, 0.25), W_B),
          (V(0, 0.52, 0.6), (0.26, 0.28), W_B),
          (V(0, 0.14, 0.63), (0.28, 0.31), {'Body': 0.5, 'Chest': 0.5}),
          (V(0, -0.26, 0.68), (0.35, 0.38), W_C),
          (V(0, -0.56, 0.76), (0.31, 0.34), {'Chest': 0.6, 'Neck': 0.4}),
          (V(0, -0.78, 0.92), (0.22, 0.24), {'Neck': 0.6, 'Head': 0.4})]
    tube(mb, 'skin', [s[0] for s in st], [s[1] for s in st], 14, [s[2] for s in st], 'body',
         start='point', end='point', start_pt=V(0, 1.12, 0.62), end_pt=V(0, -0.9, 1.0), side_hint=V(1, 0, 0),
         th0=math.pi / 2)
    # big wedge head: a wide brow, a long strong muzzle
    n0 = len(mb.F)
    hs = [(V(0, -0.86, 1.02), (0.22, 0.22), W_H), (V(0, -1.0, 1.06), (0.31, 0.275), W_H),
          (V(0, -1.18, 1.01), (0.275, 0.23), W_H), (V(0, -1.35, 0.93), (0.175, 0.15), W_H),
          (V(0, -1.48, 0.89), (0.1, 0.09), W_H)]
    tube(mb, 'head', [h[0] for h in hs], [h[1] for h in hs], 12, [h[2] for h in hs], 'head',
         start='point', end='point', start_pt=V(0, -0.8, 1.04), end_pt=V(0, -1.56, 0.87), side_hint=V(1, 0, 0),
         th0=math.pi / 2)
    head_faces = list(range(n0, len(mb.F)))
    js = [(V(0, -1.08, 0.87), (0.15, 0.07), W_J), (V(0, -1.28, 0.83), (0.11, 0.05), W_J), (V(0, -1.43, 0.82), (0.07, 0.04), W_J)]
    tube(mb, 'jaw', [j[0] for j in js], [j[1] for j in js], 8, [j[2] for j in js], 'jaw', start='point', end='point',
         start_pt=V(0, -0.98, 0.9), end_pt=V(0, -1.5, 0.82), side_hint=V(1, 0, 0), th0=math.pi / 2)
    # tall swept-back pointed ears
    for s, x in (('L', 1), ('R', -1)):
        bipyramid(mb, V(x * 0.14, -0.94, 1.14), V(x * 0.3, -0.78, 1.52), V(0, 1, 0), V(0, -1, 0.1), 0.17, 0.06,
                  {'Ear.' + s: 1}, ATLAS.uv('ear', 0.5, 0.9), ATLAS.uv('ear', 0.5, 0.1), 'ear', wide_at=0.3, ridge_at=0.3)
    # a huge lion's mane of lightning: three rings of jagged blades and bolts flaring out round the head and neck
    rings = ((-0.86, 1.02, 0.24, 0.24, 0.44, 13, 0.22, -160, 160, {'Head': 1}),
             (-0.68, 0.92, 0.32, 0.32, 0.56, 14, 0.25, -165, 165, {'Neck': 0.5, 'Chest': 0.5}),
             (-0.46, 0.84, 0.36, 0.36, 0.42, 9, 0.24, -105, 105, W_C))
    for ri, (cy, cz, rx, rz, ln, n, wd, a0, a1, ww) in enumerate(rings):
        for k in range(n):
            a = math.radians(a0 + (a1 - a0) * k / (n - 1))
            under = max(0.0, -math.cos(a))                 # blades under the chin are shorter
            l2 = ln * (1 - 0.45 * under) * (1.0 + 0.12 * ((k + ri) % 2))
            dirv = nrm(V(math.sin(a) * 1.0, 0.55 + 0.1 * ri, math.cos(a) * 1.0 + 0.25))
            base = V(math.sin(a) * rx * 0.75, cy, cz + math.cos(a) * rz * 0.75)
            if k % 3 == 1:
                bolt(mb, 'bolt', base, base + dirv * l2 * 0.55 + V(0, 0, 0.05), base + dirv * l2 * 1.15, ww, wd, 'mane')
            else:
                spike(mb, 'bolt', base, base + dirv * l2, ww, wd, 'mane')
    for x in (1, -1):                                   # big lightning cheek tufts
        spike(mb, 'bolt', V(x * 0.18, -1.08, 0.96), V(x * 0.46, -0.96, 0.88), W_H, 0.16, 'bolt')
        spike(mb, 'bolt', V(x * 0.16, -1.1, 0.9), V(x * 0.4, -1.0, 0.76), W_H, 0.12, 'bolt')
    # a white-hot ruff spilling down the chest
    for (x, z, l) in ((0.0, 0.5, 0.3), (0.12, 0.54, 0.26), (-0.12, 0.54, 0.26), (0.06, 0.42, 0.24), (-0.06, 0.42, 0.24)):
        b0 = V(x, -0.62, z + 0.08)
        spike(mb, 'fur', b0, b0 + nrm(V(x * 1.5, -0.6, -1)) * l, W_C, 0.16, 'fur')
    # a row of lightning bolts along the whole spine
    for (y, z, h, w) in ((-0.36, 0.98, 0.32, 0.16), (-0.04, 0.9, 0.34, 0.16), (0.28, 0.86, 0.3, 0.15),
                         (0.58, 0.84, 0.24, 0.12), (0.84, 0.8, 0.18, 0.1)):
        wgt = W_C if y < -0.05 else W_B
        bolt(mb, 'bolt', V(0, y, z - 0.05), V(0, y + 0.16, z + h * 0.6), V(0, y + 0.05, z + h * 1.25), wgt, w * 1.5, 'bolt',
             side=V(0, 1, 0))
    # strong legs, black jagged socks, gold claws at L2
    for s, x in (('L', 1), ('R', -1)):
        fu, fl, ff = 'FrontUpper.' + s, 'FrontLower.' + s, 'FrontFoot.' + s
        front = [(V(x * 0.2, -0.5, 0.62), (0.16, 0.18), {'Chest': 0.6, fu: 0.4}),
                 (V(x * 0.22, -0.54, 0.42), (0.14, 0.14), {fu: 1}),
                 (V(x * 0.23, -0.55, 0.29), (0.1, 0.1), {fu: 0.5, fl: 0.5}),
                 (V(x * 0.24, -0.57, 0.15), (0.085, 0.085), {fl: 1}),
                 (V(x * 0.24, -0.61, 0.05), (0.105, 0.06), {fl: 0.3, ff: 0.7})]
        tube(mb, 'limb', [f[0] for f in front], [f[1] for f in front], 8, [f[2] for f in front], 'front' + s,
             start='point', end='point', start_pt=V(x * 0.1, -0.48, 0.7), end_pt=V(x * 0.24, -0.73, 0.03))
        bu, bl, bf = 'BackUpper.' + s, 'BackLower.' + s, 'BackFoot.' + s
        back = [(V(x * 0.2, 0.62, 0.6), (0.18, 0.2), {'Body': 0.6, bu: 0.4}),
                (V(x * 0.23, 0.58, 0.4), (0.15, 0.15), {bu: 1}),
                (V(x * 0.24, 0.53, 0.28), (0.11, 0.11), {bu: 0.5, bl: 0.5}),
                (V(x * 0.24, 0.62, 0.15), (0.085, 0.085), {bl: 1}),
                (V(x * 0.24, 0.62, 0.07), (0.085, 0.065), {bl: 0.4, bf: 0.6}),
                (V(x * 0.24, 0.54, 0.04), (0.1, 0.06), {bf: 1})]
        tube(mb, 'limb', [f[0] for f in back], [f[1] for f in back], 8, [f[2] for f in back], 'back' + s,
             start='point', end='point', start_pt=V(x * 0.1, 0.62, 0.66), end_pt=V(x * 0.24, 0.46, 0.03))
        for foot, bone in ((V(x * 0.24, -0.66, 0.04), ff), (V(x * 0.24, 0.5, 0.04), bf)):
            for k in (-1, 0, 1):
                b0 = foot + V(k * 0.045, 0, 0)
                bipyramid(mb, b0, b0 + nrm(V(k * 0.3, -1, -0.3)) * 0.11, V(1, 0, 0), V(0, 0, 1), 0.04, 0.035, {bone: 1},
                          ATLAS.uv('claw', 0.5, 0.15), ATLAS.uv('claw', 0.5, 0.9), 'claw', wide_at=0.3, ridge_at=0.3)
        # lightning elbow spurs
        spike(mb, 'bolt', V(x * 0.27, -0.46, 0.4), V(x * 0.36, -0.3, 0.46), {fu: 1}, 0.09, 'bolt')
    # long thunder-flame tail: sweeps back, then curls up high in an S, flame tufts along both sides
    tp = [V(0, 1.02, 0.62), V(0, 1.38, 0.68), V(0, 1.7, 0.86), V(0, 1.92, 1.12), V(0, 1.99, 1.46), V(0, 1.88, 1.76)]
    tube(mb, 'tail', tp, [(0.11, 0.11), (0.2, 0.2), (0.25, 0.25), (0.25, 0.25), (0.19, 0.19), (0.09, 0.09)], 10,
         [{'Body': 0.4, 'Tail1': 0.6}, {'Tail1': 1}, {'Tail1': 0.4, 'Tail2': 0.6}, {'Tail2': 0.6, 'Tail3': 0.4},
          {'Tail3': 1}, {'Tail3': 1}], 'tail', start='point', end='point', start_pt=V(0, 0.96, 0.61),
         end_pt=V(0, 1.78, 1.96))
    for p, d, w in ((V(0, 1.38, 0.7), V(0.8, 0.5, 0.3), {'Tail1': 1}), (V(0, 1.38, 0.7), V(-0.8, 0.5, 0.3), {'Tail1': 1}),
                    (V(0, 1.7, 0.88), V(0.8, 0.4, 0.4), {'Tail2': 1}), (V(0, 1.7, 0.88), V(-0.8, 0.4, 0.4), {'Tail2': 1}),
                    (V(0, 1.93, 1.16), V(0.75, 0.5, 0.5), {'Tail3': 1}), (V(0, 1.93, 1.16), V(-0.75, 0.5, 0.5), {'Tail3': 1}),
                    (V(0, 1.97, 1.5), V(0.6, 0.6, 0.6), {'Tail3': 1}), (V(0, 1.97, 1.5), V(-0.6, 0.6, 0.6), {'Tail3': 1}),
                    (V(0, 1.86, 1.8), V(0, -0.2, 1), {'Tail3': 1})):
        spike(mb, 'fur', p, p + nrm(d) * 0.48, w, 0.27, 'fur')
    # ---- face decal shell (mat 1)
    mb.mat = 1
    face_shell(mb, head_faces)
    # ---- level 2 (mat 2) "Storm Herald": gold chest plate with a lightning crest, bolt pauldrons, fuller ruff
    mb.mat = 2
    bipyramid(mb, V(0, -0.78, 0.8), V(0, -0.84, 0.42), V(1, 0, 0), V(0, -1, 0), 0.4, 0.11, W_C,
              ATLAS.uv('metal', 0.4, 0.8), ATLAS.uv('metal', 0.6, 0.2), 'L2', wide_at=0.45, ridge_at=0.45)
    bolt(mb, 'bolt3', V(0, -0.88, 0.74), V(0.06, -0.9, 0.62), V(-0.02, -0.9, 0.52), W_C, 0.1, 'L2', side=V(1, 0, 0))
    for x in (1, -1):
        bolt(mb, 'bolt3', V(x * 0.24, -0.4, 0.86), V(x * 0.4, -0.34, 1.02), V(x * 0.46, -0.26, 1.2), W_C, 0.15, 'L2')
        spike(mb, 'fur', V(x * 0.2, -0.7, 0.84), V(x * 0.56, -0.6, 0.94), {'Neck': 1}, 0.16, 'L2')
    # ---- level 3 (mat 3) "Thunder God": bolt crown, tail bolt blades, a half-halo of bolts, gold leg bracers
    mb.mat = 3
    for dx, h in ((-0.12, 0.24), (0.0, 0.34), (0.12, 0.24)):
        b0 = V(dx, -1.0, 1.2)
        bolt(mb, 'bolt3', b0, b0 + V(dx * 0.4, 0.04, h * 0.55), b0 + V(dx * 0.6, 0.0, h), W_H, 0.09, 'L3', side=V(0, 1, 0))
    for x in (1, -1):
        bolt(mb, 'bolt3', V(0, 1.97, 1.3), V(x * 0.34, 2.1, 1.4), V(x * 0.5, 2.18, 1.64), {'Tail3': 1}, 0.14, 'L3')
    for k in range(9):
        a = math.radians(-100 + 200 * k / 8)
        d = V(math.sin(a), 0.3, math.cos(a))
        c0 = V(0, -0.6, 1.0) + d * 0.5
        bolt(mb, 'bolt3', c0, c0 + d * 0.2 + V(0, 0, 0.03), c0 + d * 0.42, {'Neck': 1}, 0.11, 'L3', side=V(0, 1, 0))
    for s, x in (('L', 1), ('R', -1)):
        for c, bone in ((V(x * 0.24, -0.57, 0.15), 'FrontLower.' + s), (V(x * 0.24, 0.62, 0.15), 'BackLower.' + s)):
            ring = [c + V(math.cos(2 * math.pi * i / 8) * 0.105, math.sin(2 * math.pi * i / 8) * 0.105, 0) for i in range(9)]
            tube(mb, 'metal', ring, [(0.03, 0.045)] * 9, 4, [{bone: 1}] * 9, 'L3', start='open', end='open',
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
    # redo 17 Oct: crimson thunder beast (was cobalt, too close to the Riot Hound)
    if level == 3:
        return [(0, '3a0420'), (0.5, '960e3c'), (1, 'f0507a')]
    return [(0, '4a0610'), (0.5, 'b0142a'), (1, 'ff6a52')]


BLUE = [(0, '3a0410'), (0.5, 'a8142a'), (1, 'ff7a4a')]


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
        under = ss(0.15, -0.2, top + 0.1 * _saw(v * 16))
        c = c * (1 - 0.85 * under[..., None]) + grad(np.clip(v, 0, 1), [(0, 'e0c8aa'), (1, 'fff2e0')]) * (0.85 * under[..., None])
        back = ss(0.3, 0.55, top + 0.12 * _saw(v * 20 + u * 3))
        dk = 0.82 if reg == 'skin' else 0.3
        c = c * (1 - dk * back[..., None]) + hx('120406') * (dk * back[..., None])   # black storm saddle (body only)
        st = _streaks(h, w, 160, 41 if reg == 'skin' else 42)
        gr = _pgrain(h, w, 43)
        c = c * (1 + 0.35 * st[..., None] + 0.05 * gr[..., None])
        # zig-zag lightning cracks along the flanks (gold, glowing)
        zz = 0.18 + 0.05 * _saw(v * 9 * scale + 0.3)
        crack = ss(0.016, 0.0, np.abs(np.abs(u - 0.5) - zz) - 0.007) * ss(0.1, 0.25, v) * ss(0.95, 0.8, v)
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
    col[y0:y1, x0:x1] = c * (1 - sock[..., None]) + hx('0e0608') * sock[..., None]
    hgt[y0:y1, x0:x1] = 0.5 + 0.4 * st
    # ---- tail + fur tufts: blue, fur strokes, darker roots, jagged near-black tips
    for reg in ('tail', 'fur'):
        (y0, y1, x0, x1), v, u = _reg(reg)
        st = _streaks(y1 - y0, x1 - x0, 50, 45)
        tip = ss(0.0, 0.03, v - (0.82 + 0.08 * _saw(u * 6))) * 0.0
        c = grad(np.clip(0.25 + 0.75 * v, 0, 1), [(0, '6a0818'), (0.45, 'e0302a'), (0.75, bm), (1, 'fffbe8')]) * (1 + 0.25 * st[..., None])
        glow[y0:y1, x0:x1] = ss(0.3, 1.0, v) * (0.5 if reg == 'fur' else 0.15)
        if reg == 'tail':
            c = grad(np.clip(0.3 + 0.6 * np.cos((u - 0.5) * math.pi) ** 2, 0, 1), _navy(level)) * (1 + 0.35 * st[..., None])
            flame = ss(0.55, 0.9, v + 0.06 * _saw(u * 7))           # the tail burns to white-hot lightning at the tip
            c = c * (1 - flame[..., None]) + grad(np.clip((v - 0.55) / 0.45, 0, 1), [(0, bm), (1, 'fffbe8')]) * flame[..., None]
            glow[y0:y1, x0:x1] = flame * 0.8
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
    col[y0:y1, x0:x1] = grad(1 - v, nv) * (1 - tip[..., None]) + hx('0e0608') * tip[..., None]
    # ---- claws, jaw
    (y0, y1, x0, x1), v, u = _reg('claw')
    t = ss(0.5, 0.9, v) * (1.0 if level >= 2 else 0.0)
    col[y0:y1, x0:x1] = hx('06060a') * (1 - t[..., None]) + hx(bm) * t[..., None]
    glow[y0:y1, x0:x1] = t
    (y0, y1, x0, x1), v, u = _reg('jaw')
    col[y0:y1, x0:x1] = grad(v, [(0, '2a0a10'), (1, '080204')])
    # ---- metal: dark gunmetal with gold rivets / trim
    (y0, y1, x0, x1), v, u = _reg('metal')
    trim = np.maximum(ss(0.2, 0.1, v), ss(0.8, 0.9, v))
    col[y0:y1, x0:x1] = grad(u, [(0, 'fff0a0'), (0.45, 'f0b030'), (1, '8a5a08')]) * (1 - trim[..., None]) + hx('1a0a0c') * trim[..., None]
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
    X, Z = x * DFX, DFZ + y * DFZH
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
    """A crackling storm beast: heavy breathing, mane shudder (a static shake), a forepaw scrape, a tail lash."""
    F = 72
    keys = {}
    for f in range(0, F + 1, 3):
        t = f / F
        w = 2 * math.pi * t
        shudder = _pulse(t, 0.3, 0.42) * math.sin(w * 22)
        scrape = _pulse(t, 0.62, 0.82)
        k = {'Body': P(('x', 1.5 * math.sin(w)), loc=(0, 0, 0.02 * math.sin(2 * w))),
             'Chest': P(('x', 3 * math.sin(2 * w)), ('y', 5 * shudder)),
             'Neck': P(('x', -6 + 4 * math.sin(w) + 8 * scrape), ('z', 8 * math.sin(w * 0.5))),
             'Head': P(('y', 7 * shudder), ('x', 6 * scrape)), 'Jaw': P(('x', 6 * _pulse(t, 0.84, 0.95))),
             'Ear.L': P(('x', -20 * _pulse(t, 0.1, 0.16))), 'Ear.R': P(('x', -20 * _pulse(t, 0.5, 0.56))),
             'FrontUpper.R': P(('x', -25 * scrape)), 'FrontLower.R': P(('x', 35 * scrape)), 'FrontFoot.R': P(('x', -15 * scrape))}
        k.update(_tail(w * 2, 18, -10))
        keys[f] = k
    keys[F] = dict(keys[0])
    return {'frames': F, 'loop': True, 'keys': keys}


def _gait(frames, swing, lift, bounce, pitch, tail, bound=0.0):
    """bound 0: a walking diagonal gait. bound 1: a weasel's bounding lope (front pair, then back pair, the spine
    flexing and arching between them)."""
    keys = {}
    for f in range(0, frames + 1, 2):
        t = f / frames
        w = 2 * math.pi * t
        arch = bound * math.sin(w)
        p = {'Body': P(('x', pitch + 3 * math.sin(2 * w) + 10 * arch), loc=(0, 0, bounce * abs(math.sin(w)))),
             'Chest': P(('x', -14 * arch)),
             'Neck': P(('x', -pitch * 0.6 + 3 * math.sin(2 * w) + 6 * arch)), 'Head': P(('x', -pitch * 0.3 - 4 * arch)),
             'Ear.L': P(('x', 15)), 'Ear.R': P(('x', 15))}
        for s, off in (('L', 0.0), ('R', math.pi * (1 - 0.9 * bound))):
            for pre, ph in (('Front', w + off), ('Back', w + off + math.pi * (0.9 + 0.1 * bound))):
                sw = math.sin(ph) * swing
                lf = max(0.0, math.cos(ph)) * lift
                p[pre + 'Upper.' + s] = P(('x', -sw))
                p[pre + 'Lower.' + s] = P(('x', lf * (0.9 if pre == 'Front' else -0.9)))
                p[pre + 'Foot.' + s] = P(('x', sw * 0.4))
        p.update(_tail(w, tail, -12 - 10 * arch))
        keys[f] = p
    keys[frames] = dict(keys[0])
    return {'frames': frames, 'loop': True, 'keys': keys}


def anim_walk():
    return _gait(22, 24, 34, 0.02, 2, 14)


def anim_run():
    return _gait(14, 40, 50, 0.16, 4, 10, bound=1.0)


def anim_hop():
    keys = {}
    for f in range(0, 17, 2):
        t = f / 16
        upv = math.sin(math.pi * t)
        p = {'Body': P(('x', -10 * upv), loc=(0, 0, 0.32 * upv))}
        for s in 'LR':
            p['BackUpper.' + s] = P(('x', 35 * upv))
            p['FrontUpper.' + s] = P(('x', -35 * upv))
        keys[f] = p
    return {'frames': 16, 'loop': False, 'keys': keys}


def anim_ability():
    """Thunderclap Knockback (~1 s, Runner): sinks low, springs straight up with its back arched and the mane flared,
    then crashes down on all four paws (the shockwave at ~0.5) and snarls."""
    keys = {}
    F = 24
    for f in range(0, F + 1, 2):
        t = f / F
        sink = _ease(t / 0.22) * (1 - _ease((t - 0.22) / 0.08))
        air = math.sin(math.pi * min(1, max(0, (t - 0.25) / 0.25)))
        land = _ease((t - 0.48) / 0.06) * (1 - _ease((t - 0.7) / 0.3))
        p = {'Body': P(('x', -6 * air + 4 * land), loc=(0, 0, -0.08 * sink + 0.4 * air - 0.08 * land)),
             'Chest': P(('x', -10 * air + 6 * land)), 'Neck': P(('x', -20 * air + 14 * land)),
             'Head': P(('x', -10 * air + 10 * land)), 'Jaw': P(('x', 26 * land))}
        for s_ in 'LR':
            p['FrontUpper.' + s_] = P(('x', 20 * sink - 40 * air + 18 * land))
            p['FrontLower.' + s_] = P(('x', -30 * sink + 50 * air - 20 * land))
            p['BackUpper.' + s_] = P(('x', -25 * sink + 35 * air - 10 * land))
            p['BackLower.' + s_] = P(('x', 35 * sink - 40 * air + 15 * land))
        p.update(_tail(6 * t, 14, -30 * air))
        keys[f] = p
    return {'frames': F, 'loop': False, 'keys': keys}


def anim_roar():
    """Storm Ball (~0.9 s, Catcher): lowers its head and gathers, then lunges forward roaring with the jaw wide (the
    ball fires from its maw at ~0.42) and rocks back."""
    keys = {}
    F = 22
    for f in range(0, F + 1):
        t = f / F
        gather = _ease(t / 0.32) * (1 - _ease((t - 0.34) / 0.08))
        roar = _ease((t - 0.34) / 0.08) * (1 - _ease((t - 0.72) / 0.28))
        p = {'Body': P(('x', 4 * gather - 4 * roar), loc=(0, 0.1 * gather - 0.18 * roar, -0.06 * gather)),
             'Chest': P(('x', 6 * gather)), 'Neck': P(('x', 18 * gather - 12 * roar)),
             'Head': P(('x', 10 * gather - 14 * roar)), 'Jaw': P(('x', 45 * roar)),
             'Ear.L': P(('x', 30 * gather)), 'Ear.R': P(('x', 30 * gather))}
        for s_ in 'LR':
            p['FrontUpper.' + s_] = P(('x', 12 * gather - 22 * roar))
            p['BackUpper.' + s_] = P(('x', -14 * gather + 14 * roar))
        p.update(_tail(4 * t, 10, 20 * roar))
        keys[f] = p
    return {'frames': F, 'loop': False, 'keys': keys}


ANIMS = {'Idle': anim_idle, 'Walk': anim_walk, 'Run': anim_run, 'Hop': anim_hop, 'Ability': anim_ability,
         'Roar': anim_roar}
