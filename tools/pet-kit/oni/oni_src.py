# Drum Oni (Tempest, Epic) for Hatch or Snatch: HOS-PET-025, built on the pet kit. Assembled by assemble_pet.py.
# From the concept-library card (docs/pets/drum_oni/drum_oni_card.png): a crouching teal oni with a wild red mane and
# red horns, a purple vest, red legs, and gold-rimmed taiko drums floating round its back; a fanged grin, red eyes.
# Read through PET_LESSONS (anime / edgy): deep teal skin with darker markings and fur strokes on the mane, near-black
# claws, narrow slanted glowing red slit eyes, a fanged snarl (face decal shell), jagged red mane. L2 "War Drummer":
# a fourth drum, gold arm bands, rope belt with tassels. L3 "Thunder Oni": a ring of lightning-bolt flags behind the
# drums, gold horn tips, flaming hair tips, gold-white eyes.
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

NAME = 'Oni'
SHARP_ANGLE = 40
NORMAL_STRENGTH = 2.0
TS = 1024
ATLAS = Atlas({
    'skin': (0, 0, 1024, 384),      # torso loft: u around, v hips -> neck
    'head': (0, 384, 512, 256),
    'limb': (512, 384, 512, 128),   # arms (teal)
    'leg': (512, 512, 512, 128),    # legs (red)
    'mane': (0, 640, 256, 128),
    'horn': (256, 640, 128, 128),
    'claw': (384, 640, 128, 128),
    'drum': (512, 640, 256, 128),   # drum body: u around, v rim -> rim
    'skinh': (768, 640, 256, 256),  # drum head (planar)
    'gold': (0, 768, 256, 128),
    'vest': (256, 768, 256, 128),
    'flag': (512, 768, 256, 128),
    'jaw': (0, 896, 256, 128),
})

GLOW = {1: ('b02a00', 'ff6a1a', 'ffe0b0'), 2: ('b02a00', 'ff8a2a', 'fff0c8'), 3: ('c88a00', 'ffd23a', 'fffbe0')}
EYE = {1: ('8a0a0a', 'ff3a2a', 'ffd8c8'), 2: ('8a0a0a', 'ff5a3a', 'ffe8d8'), 3: ('b07a00', 'ffd23a', 'fffbe8')}
TEAL = [(0, '0a2a30'), (0.5, '1a8a8a'), (1, '5ad0c8')]
RED = [(0, '4a0606'), (0.5, 'b81a1a'), (1, 'ff5a3a')]


def bones_def():
    b = [
        ('Root', V(0, 0, 0), V(0, 0, 0.2), None),
        ('Hips', V(0, 0.1, 0.62), V(0, 0.0, 0.8), 'Root'),
        ('Torso', V(0, 0.0, 0.8), V(0, -0.2, 1.2), 'Hips'),
        ('Head', V(0, -0.24, 1.24), V(0, -0.4, 1.7), 'Torso'),
        ('Jaw', V(0, -0.34, 1.32), V(0, -0.6, 1.28), 'Head'),
        ('Drums', V(0, 0.36, 1.1), V(0, 0.36, 1.4), 'Torso'),
    ]
    for s, x in (('L', 1), ('R', -1)):
        b += [
            ('ArmU.' + s, V(x * 0.34, -0.12, 1.12), V(x * 0.52, -0.22, 0.8), 'Torso'),
            ('ArmL.' + s, V(x * 0.52, -0.22, 0.8), V(x * 0.56, -0.34, 0.46), 'ArmU.' + s),
            ('Hand.' + s, V(x * 0.56, -0.34, 0.46), V(x * 0.58, -0.42, 0.26), 'ArmL.' + s),
            ('LegU.' + s, V(x * 0.18, 0.1, 0.6), V(x * 0.26, 0.0, 0.32), 'Hips'),
            ('LegL.' + s, V(x * 0.26, 0.0, 0.32), V(x * 0.28, 0.06, 0.06), 'LegU.' + s),
        ]
    return b


#@helpers
FX, FZ, FZH = 0.36, 1.46, 0.3
SHELL = (-0.36, 1.2, 1.78)
#@shell


def drum(mb, c, axis, R, depth, w, part):
    axis = nrm(np.asarray(axis, float))
    c = np.asarray(c, float)
    tube(mb, 'drum', [c - axis * depth / 2, c - axis * depth * 0.4, c + axis * depth * 0.4, c + axis * depth / 2],
         [(R * 0.92, R * 0.92), (R, R), (R, R), (R * 0.92, R * 0.92)], 10, [w] * 4, part, start='open', end='open',
         side_hint=nrm(np.cross(axis, V(0, 0, 1)) if abs(axis[2]) < 0.9 else V(1, 0, 0)), anti=False)
    for sgn in (1, -1):
        cc = c + axis * sgn * depth / 2
        a = nrm(np.cross(axis, V(0, 0, 1) if abs(axis[2]) < 0.9 else V(1, 0, 0)))
        b = np.cross(axis, a)
        rim = [mb.vert(cc + (a * math.cos(2 * math.pi * k / 10) + b * math.sin(2 * math.pi * k / 10)) * R * 0.92, w) for k in range(10)]
        ci = mb.vert(cc + axis * sgn * 0.01, w)
        for k in range(10):
            k2 = (k + 1) % 10
            uv = lambda kk: ATLAS.uv('skinh', 0.5 + 0.46 * math.cos(2 * math.pi * kk / 10), 0.5 + 0.46 * math.sin(2 * math.pi * kk / 10))
            mb.face([rim[k], rim[k2], ci], [uv(k), uv(k2), ATLAS.uv('skinh', 0.5, 0.5)], inside=c, part=part)
        ring_c = [cc + (a * math.cos(2 * math.pi * k / 8) + b * math.sin(2 * math.pi * k / 8)) * R for k in range(9)]
        tube(mb, 'gold', ring_c, [(0.03, 0.03)] * 9, 3, [w] * 9, part, start='open', end='open', side_hint=axis, anti=False)


def build():
    mb = MB()
    mb.mat = 0
    W_Hp, W_T, W_H, W_J = {'Hips': 1}, {'Torso': 1}, {'Head': 1}, {'Jaw': 1}
    # hunched torso: broad shoulders, leaning forward
    st = [(V(0, 0.1, 0.52), (0.26, 0.22), W_Hp), (V(0, 0.06, 0.66), (0.3, 0.26), W_Hp),
          (V(0, 0.0, 0.84), (0.33, 0.27), {'Hips': 0.4, 'Torso': 0.6}), (V(0, -0.08, 1.02), (0.4, 0.3), W_T),
          (V(0, -0.16, 1.16), (0.36, 0.27), W_T), (V(0, -0.22, 1.24), (0.18, 0.16), {'Torso': 0.5, 'Head': 0.5})]
    tube(mb, 'skin', [s[0] for s in st], [s[1] for s in st], 14, [s[2] for s in st], 'body', start='point', end='point',
         start_pt=V(0, 0.12, 0.46), end_pt=V(0, -0.24, 1.3), side_hint=V(1, 0, 0), th0=math.pi / 2)
    n0 = len(mb.F)
    hs = [(V(0, -0.22, 1.32), (0.2, 0.2), W_H), (V(0, -0.3, 1.46), (0.27, 0.26), W_H), (V(0, -0.34, 1.62), (0.25, 0.23), W_H),
          (V(0, -0.32, 1.74), (0.15, 0.14), W_H)]
    tube(mb, 'head', [h[0] for h in hs], [h[1] for h in hs], 12, [h[2] for h in hs], 'head', start='point', end='point',
         start_pt=V(0, -0.2, 1.26), end_pt=V(0, -0.3, 1.8), side_hint=V(1, 0, 0), th0=math.pi / 2)
    head_faces = list(range(n0, len(mb.F)))
    js = [(V(0, -0.34, 1.34), (0.2, 0.06), W_J), (V(0, -0.48, 1.32), (0.14, 0.05), W_J)]
    tube(mb, 'jaw', [j[0] for j in js], [j[1] for j in js], 8, [j[2] for j in js], 'jaw', start='point', end='point',
         start_pt=V(0, -0.26, 1.36), end_pt=V(0, -0.54, 1.32), side_hint=V(1, 0, 0), th0=math.pi / 2)
    # red horns curving up and out, pointed ears
    for s, x in (('L', 1), ('R', -1)):
        path = [V(x * 0.12, -0.32, 1.72), V(x * 0.2, -0.34, 1.9), V(x * 0.3, -0.3, 2.04), V(x * 0.34, -0.22, 2.14)]
        d = nrm(path[-1] - path[-2])
        tube(mb, 'horn', path, [(0.07, 0.065), (0.055, 0.05), (0.035, 0.03), (0.018, 0.016)], 6, [W_H] * 4, 'horn',
             start='point', end='point', start_pt=V(x * 0.1, -0.32, 1.64), end_pt=path[-1] + d * 0.1, anti=False, side_hint=V(0, 1, 0))
        bipyramid(mb, V(x * 0.24, -0.3, 1.52), V(x * 0.44, -0.26, 1.62), V(0, 0, 1), V(0, -1, 0), 0.12, 0.04, W_H,
                  ATLAS.uv('limb', 0.5, 0.5), ATLAS.uv('limb', 0.5, 0.5), 'ear', wide_at=0.35, ridge_at=0.35)
    # wild red mane: spikes swept back from the crown and down the neck
    for k in range(11):
        a = math.radians(-110 + 220 * k / 10)
        base = V(math.sin(a) * 0.2, -0.18, 1.56 + math.cos(a) * 0.14)
        d = nrm(V(math.sin(a) * 0.7, 0.8, math.cos(a) * 0.6))
        bipyramid(mb, base, base + d * (0.36 + 0.08 * (k % 2)), V(0, 0, 1) if abs(math.sin(a)) > 0.5 else V(1, 0, 0), V(0, 1, 0),
                  0.16, 0.06, W_H, ATLAS.uv('mane', 0.5, 0.1), ATLAS.uv('mane', 0.5, 0.95), 'mane', wide_at=0.3, ridge_at=0.3)
    # (the chest / back vest plates were removed 17 Oct: Hunter, "remove the weird triangle on drum onis chest")
    # redo 17 Oct (Hunter: "chest is plain teal now"): a thick twisted shimenawa rope sash from the left shoulder across
    # the chest to the right hip, half-buried in the torso so it never z-fights, a knot and two tassels at the hip
    sash = [V(0.3, -0.05, 1.24), V(0.26, -0.36, 1.18), V(0.14, -0.38, 1.02), V(-0.06, -0.29, 0.84), V(-0.22, -0.14, 0.68),
            V(-0.31, 0.0, 0.6), V(-0.3, 0.16, 0.6)]
    tube(mb, 'vest', sash, [(0.055, 0.055)] * 7, 6,
         [W_T, W_T, W_T, {'Hips': 0.4, 'Torso': 0.6}, W_Hp, W_Hp, W_Hp], 'sash', start='point', end='point',
         start_pt=V(0.3, 0.04, 1.24), end_pt=V(-0.28, 0.22, 0.6), side_hint=V(0, 1, 0), anti=False)
    for dx, ln in ((0.0, 0.26), (0.06, 0.22)):
        b0 = V(-0.33 + dx, -0.06, 0.58)
        bipyramid(mb, b0, b0 + V(-0.02 + dx, -0.04, -ln), V(1, 0, 0), V(0, -1, 0), 0.07, 0.05, W_Hp,
                  ATLAS.uv('vest', 0.5, 0.1), ATLAS.uv('vest', 0.5, 0.9), 'sash', wide_at=0.25, ridge_at=0.25)
    # long arms with big fists and claws; short bowed red legs
    for s, x in (('L', 1), ('R', -1)):
        au, al, h = 'ArmU.' + s, 'ArmL.' + s, 'Hand.' + s
        arm = [(V(x * 0.28, -0.1, 1.12), (0.13, 0.13), {'Torso': 0.5, au: 0.5}), (V(x * 0.44, -0.18, 0.96), (0.13, 0.13), {au: 1}),
               (V(x * 0.52, -0.22, 0.8), (0.11, 0.11), {au: 0.5, al: 0.5}), (V(x * 0.55, -0.3, 0.6), (0.1, 0.1), {al: 1}),
               (V(x * 0.56, -0.34, 0.46), (0.11, 0.11), {al: 0.5, h: 0.5}), (V(x * 0.57, -0.38, 0.34), (0.15, 0.14), {h: 1})]
        tube(mb, 'limb', [a[0] for a in arm], [a[1] for a in arm], 8, [a[2] for a in arm], 'arm' + s, start='point', end='point',
             start_pt=V(x * 0.18, -0.08, 1.14), end_pt=V(x * 0.58, -0.42, 0.22))
        for dx in (-0.05, 0.0, 0.05):
            b0 = V(x * (0.57 + dx), -0.44, 0.3)
            bipyramid(mb, b0, b0 + V(x * dx, -0.12, -0.08), V(1, 0, 0), V(0, 0, 1), 0.045, 0.04, {h: 1},
                      ATLAS.uv('claw', 0.5, 0.15), ATLAS.uv('claw', 0.5, 0.9), 'claw', wide_at=0.3, ridge_at=0.3)
        lu, ll = 'LegU.' + s, 'LegL.' + s
        leg = [(V(x * 0.16, 0.1, 0.62), (0.15, 0.15), {'Hips': 0.5, lu: 0.5}), (V(x * 0.24, 0.04, 0.42), (0.14, 0.14), {lu: 1}),
               (V(x * 0.26, 0.0, 0.32), (0.12, 0.12), {lu: 0.5, ll: 0.5}), (V(x * 0.27, 0.02, 0.14), (0.11, 0.11), {ll: 1}),
               (V(x * 0.28, -0.04, 0.05), (0.13, 0.07), {ll: 1})]
        tube(mb, 'leg', [a[0] for a in leg], [a[1] for a in leg], 8, [a[2] for a in leg], 'leg' + s, start='point', end='point',
             start_pt=V(x * 0.06, 0.1, 0.66), end_pt=V(x * 0.28, -0.16, 0.04))
    # the drums: three taiko drums on a ring behind the back
    for k, (dx, dz) in enumerate(((0.0, 1.38), (0.42, 1.1), (-0.42, 1.1))):
        drum(mb, V(dx, 0.42, dz), V(dx * 0.6, 1, 0.1), 0.2, 0.22, {'Drums': 1}, 'drum')
    mb.mat = 1
    face_shell(mb, head_faces)
    # ---- L2 "War Drummer": a fourth drum, gold arm bands, rope belt with tassels
    mb.mat = 2
    drum(mb, V(0, 0.46, 0.84), V(0, 1, 0), 0.16, 0.18, {'Drums': 1}, 'L2')
    for s, x in (('L', 1), ('R', -1)):
        c = V(x * 0.555, -0.31, 0.58)
        ring_c = [c + V(math.cos(2 * math.pi * i / 8) * 0.12, math.sin(2 * math.pi * i / 8) * 0.12, 0) for i in range(9)]
        tube(mb, 'gold', ring_c, [(0.03, 0.045)] * 9, 4, [{'ArmL.' + s: 1}] * 9, 'L2', start='open', end='open', side_hint=V(0, 0, 1), anti=False)
    belt = [V(0, 0.08, 0.66) + V(math.cos(2 * math.pi * i / 12) * 0.31, math.sin(2 * math.pi * i / 12) * 0.27, 0) for i in range(13)]
    tube(mb, 'gold', belt, [(0.035, 0.035)] * 13, 4, [W_Hp] * 13, 'L2', start='open', end='open', side_hint=V(0, 0, 1), anti=False)
    for x in (1, -1):
        bipyramid(mb, V(x * 0.12, -0.2, 0.64), V(x * 0.14, -0.24, 0.36), V(1, 0, 0), V(0, -1, 0), 0.08, 0.03, W_Hp,
                  ATLAS.uv('mane', 0.5, 0.1), ATLAS.uv('mane', 0.5, 0.95), 'L2', wide_at=0.3, ridge_at=0.3)
    # ---- L3 "Thunder Oni": lightning-bolt flags fanned behind the drums, gold horn tips
    mb.mat = 3
    for k in range(5):
        a = math.radians(-60 + 30 * k)
        base = V(0, 0.5, 1.1) + V(math.sin(a) * 0.2, 0, math.cos(a) * 0.1)
        tip = base + V(math.sin(a) * 0.5, 0.12, math.cos(a) * 0.6)
        mid = base + (tip - base) * 0.5 + V(math.cos(a) * 0.08, 0, -math.sin(a) * 0.08)
        bipyramid(mb, base, mid, V(0, 1, 0), V(math.cos(a), 0, -math.sin(a)), 0.16, 0.03, {'Drums': 1},
                  ATLAS.uv('flag', 0.5, 0.05), ATLAS.uv('flag', 0.5, 0.95), 'L3', wide_at=0.5, ridge_at=0.5)
        bipyramid(mb, mid - (mid - base) * 0.2, tip, V(0, 1, 0), V(math.cos(a), 0, -math.sin(a)), 0.13, 0.03, {'Drums': 1},
                  ATLAS.uv('flag', 0.5, 0.05), ATLAS.uv('flag', 0.5, 0.95), 'L3', wide_at=0.3, ridge_at=0.3)
    for s, x in (('L', 1), ('R', -1)):
        p = V(x * 0.34, -0.22, 2.14)
        bipyramid(mb, p - V(x * 0.03, 0.06, 0.06), p + V(x * 0.03, 0.06, 0.12), V(1, 0, 0), V(0, -1, 0), 0.06, 0.06, W_H,
                  ATLAS.uv('gold', 0.4, 0.8), ATLAS.uv('gold', 0.6, 0.2), 'L3', wide_at=0.35, ridge_at=0.35)
    mb.mat = 0
    return mb


#@paint_helpers


def paint_atlas(level):
    col = np.zeros((TS, TS, 3), np.float32)
    hgt = np.full((TS, TS), 0.5, np.float32)
    rgh = np.full((TS, TS), 0.6, np.float32)
    glow = np.zeros((TS, TS), np.float32)
    gd, gm, gh = GLOW[level]
    for reg in ('skin', 'head', 'limb'):
        (y0, y1, x0, x1), v, u = _reg(reg)
        h, w = y1 - y0, x1 - x0
        top = np.cos(u * 2 * math.pi)
        c = grad(np.clip(0.5 + 0.35 * top, 0, 1), TEAL)
        stripes = ss(0.03, 0.0, np.abs(_saw(v * 5 + u * 2) - 0.5) - 0.06) * ss(0.0, 0.4, top) * (reg != 'head')
        c = c * (1 - 0.6 * stripes[..., None]) + hx('06181c') * (0.6 * stripes[..., None])
        if reg == 'skin':   # redo: dark wavy tiger stripes across the chest and belly (the front was plain teal)
            front = ss(0.1, -0.3, top)
            tig = ss(0.03, 0.0, np.abs(_saw(v * 7 + 0.12 * np.sin(u * 2 * math.pi * 6)) - 0.5) - 0.07 - 0.06 * np.abs(u - 0.5))
            tig = tig * front * ss(0.15, 0.3, v) * ss(0.95, 0.85, v)
            c = c * (1 - 0.8 * tig[..., None]) + hx('041014') * (0.8 * tig[..., None])
            stripes = np.maximum(stripes, tig)
        gr = _pgrain(h, w, 91)
        col[y0:y1, x0:x1] = c * (1 + 0.06 * gr[..., None])
        hgt[y0:y1, x0:x1] = 0.5 + 0.15 * gr - 0.2 * stripes
        if reg == 'limb':
            fist = ss(0.75, 0.8, v)
            col[y0:y1, x0:x1] = col[y0:y1, x0:x1] * (1 - 0.3 * fist[..., None])
    (y0, y1, x0, x1), v, u = _reg('leg')
    st = _streaks(y1 - y0, x1 - x0, 40, 92)
    col[y0:y1, x0:x1] = grad(np.clip(0.75 - 0.4 * v, 0, 1), RED) * (1 + 0.1 * st[..., None])
    (y0, y1, x0, x1), v, u = _reg('mane')
    st = _streaks(y1 - y0, x1 - x0, 50, 93)
    tip = ss(0.0, 0.04, v - (0.8 + 0.08 * _saw(u * 6)))
    c = grad(np.clip(0.3 + 0.7 * v, 0, 1), RED) * (1 + 0.3 * st[..., None])
    col[y0:y1, x0:x1] = c * (1 - tip[..., None]) + hx(gm if level == 3 else '2a0404') * tip[..., None]
    hgt[y0:y1, x0:x1] = 0.5 + 0.45 * st
    glow[y0:y1, x0:x1] = tip * (level == 3)
    (y0, y1, x0, x1), v, u = _reg('horn')
    col[y0:y1, x0:x1] = grad(v, [(0, '4a0606'), (0.7, 'd8281a'), (1, gh)])
    glow[y0:y1, x0:x1] = ss(0.85, 1.0, v)
    (y0, y1, x0, x1), v, u = _reg('claw')
    col[y0:y1, x0:x1] = hx('0a0606')
    (y0, y1, x0, x1), v, u = _reg('drum')
    studs = ss(0.25, 0.0, np.abs(_saw(u * 16) - 0.5) * 2 + np.abs(v - 0.14) * 18 - 0.8)
    studs = np.maximum(studs, ss(0.25, 0.0, np.abs(_saw(u * 16) - 0.5) * 2 + np.abs(v - 0.86) * 18 - 0.8))
    c = grad(np.clip(0.5 + 0.4 * np.cos(u * 2 * math.pi), 0, 1), [(0, '4a0a0a'), (1, 'a8201a')])
    col[y0:y1, x0:x1] = c * (1 - studs[..., None]) + hx('ffd23a') * studs[..., None]
    rgh[y0:y1, x0:x1] = 0.4
    (y0, y1, x0, x1), v, u = _reg('skinh')
    X, Y = (u - 0.5) * 2, (v - 0.5) * 2
    R = np.sqrt(X ** 2 + Y ** 2)
    A = np.arctan2(Y, X)
    tomoe = ss(0.04, 0.0, np.abs(R - 0.35 - 0.12 * np.sin(A * 3)) - 0.06) * (R < 0.7)
    c = grad(np.clip(R, 0, 1), [(0, 'f4ead0'), (1, 'c8b890')])
    col[y0:y1, x0:x1] = c * (1 - tomoe[..., None]) + hx(gm) * tomoe[..., None]
    glow[y0:y1, x0:x1] = tomoe * (0.6 + 0.4 * (level >= 2))
    (y0, y1, x0, x1), v, u = _reg('gold')
    col[y0:y1, x0:x1] = grad(u, [(0, 'fff0a0'), (0.5, 'ffc23a'), (1, '8a5a0a')])
    rgh[y0:y1, x0:x1] = 0.25
    (y0, y1, x0, x1), v, u = _reg('vest')
    # twisted straw shimenawa rope with red twist lines (the redo sash)
    tw = _saw(u * 3 + v * 14)
    c = grad(tw, [(0, '8a6a2a'), (0.5, 'f0d890'), (1, 'fff4c8')])
    red = ss(0.06, 0.0, np.abs(_saw(u * 3 + v * 14 + 0.5) - 0.5) - 0.05)
    col[y0:y1, x0:x1] = c * (1 - red[..., None]) + hx('c0141a') * red[..., None]
    hgt[y0:y1, x0:x1] = 0.3 + 0.5 * tw
    rgh[y0:y1, x0:x1] = 0.7
    (y0, y1, x0, x1), v, u = _reg('flag')
    col[y0:y1, x0:x1] = grad(v, [(0, gh), (0.5, gm), (1, gd)])
    glow[y0:y1, x0:x1] = 1.0 - 0.4 * v
    (y0, y1, x0, x1), v, u = _reg('jaw')
    col[y0:y1, x0:x1] = grad(v, [(0, '1a6a6a'), (1, '0a2a2a')])
    paint_atlas._glow = np.clip(glow, 0, 1)
    return np.clip(col, 0, 1), hgt, rgh


def emissive_mask(level):
    paint_atlas(level)
    return np.repeat(paint_atlas._glow[..., None], 3, -1)


#@seg


def _face_layers(level, size):
    x, y = coords(size)
    X, Z = x * FX, FZ + y * FZH
    aX = np.abs(X)
    ix, iz, ox, oz = 0.05, 1.5, 0.2, 1.57
    ex, ez = ox - ix, oz - iz
    L = math.hypot(ex, ez)
    s = ((aX - ix) * ex + (Z - iz) * ez) / (L * L)
    d = (-(aX - ix) * ez + (Z - iz) * ex) / L
    sc = np.clip(s, 0, 1)
    top = 0.032 * np.clip(sc * 3.0, 0, 1) * (1 - sc ** 4) + 0.002
    bot = -0.024 * np.clip(np.sin(math.pi * sc), 0, 1) ** 0.9 - 0.001
    eye = ss(0.003, 0.0, np.maximum(d - top, bot - d)) * (s > 0) * (s < 1)
    cxs, czs = ix + 0.5 * ex, iz + 0.5 * ez
    rr = np.sqrt((aX - cxs) ** 2 + (Z - czs) ** 2)
    _face_layers.rr = rr
    iris = ss(0.048, 0.044, rr)
    slit = ss(0.006 * np.clip(1 - ((Z - czs) / 0.034) ** 2, 0, 1) + 0.0005, 0.0, np.abs(aX - cxs)) * ss(0.034, 0.03, rr)
    brow = np.maximum(_seg(aX, Z, (0.03, 1.55), (0.22, 1.63), 0.016, 0.006), _seg(aX, Z, (0.2, 1.62), (0.28, 1.68), 0.009, 0.001))
    lid = ss(0.006, 0.003, np.abs(d - top - 0.003)) * (s > -0.05) * (s < 1.02)
    mark = np.maximum(_seg(aX, Z, (0.18, 1.46), (0.22, 1.38), 0.01, 0.002), _seg(aX, Z, (0.0, 1.66), (0.0, 1.72), 0.012, 0.004))
    if level >= 3:
        mark = np.maximum(mark, _seg(aX, Z, (0.24, 1.46), (0.28, 1.4), 0.008, 0.002))
    # a wide fanged snarl
    zc = 1.36 + 0.4 * aX ** 2
    mouth = ss(0.004, 0.0, np.abs(Z - zc) - 0.018) * (aX < 0.2)
    ph = _saw(X / 0.04 + 0.5)
    teeth = mouth * ((zc + 0.018 - Z) < 0.03 * ph + 0.004)
    fang = ss(0.08, 0.0, np.abs(aX - 0.12) / 0.014 + (1.36 + 0.4 * 0.0144 - Z) / 0.05 - 1) * (Z < 1.37) * (Z > 1.31)
    return X, Z, eye, iris, slit, brow, lid, mark, mouth, teeth, fang


def face_texture(level, size=512):
    X, Z, eye, iris, slit, brow, lid, mark, mouth, teeth, fang = _face_layers(level, size)
    rr = _face_layers.rr
    ed, em, eh = EYE[level]
    gd, gm, gh = GLOW[level]
    rgba = np.zeros((size, size, 4), np.float32)
    c = np.zeros((size, size, 3), np.float32) + hx('06181c')
    c = c * (1 - mark[..., None]) + hx(gm) * mark[..., None]
    irisc = grad(np.clip(1 - rr / 0.044, 0, 1), [(0, ed), (0.45, em), (1, eh)])
    e = hx('140606') * (1 - iris[..., None]) + irisc * iris[..., None]
    e = e * (1 - slit[..., None]) + hx('040202') * slit[..., None]
    c = c * (1 - eye[..., None]) + e * eye[..., None]
    c = c * (1 - brow[..., None]) + hx('6a0a0a') * brow[..., None]
    c = c * (1 - mouth[..., None]) + hx('1a0404') * mouth[..., None]
    c = c * (1 - teeth[..., None]) + hx('f4f0e6') * teeth[..., None]
    c = c * (1 - fang[..., None]) + hx('f4f0e6') * fang[..., None]
    c = c * (1 - lid[..., None]) + hx('020606') * lid[..., None]
    rgba[..., :3] = c
    rgba[..., 3] = np.clip(np.maximum.reduce([eye, brow, lid, mark, mouth, fang]), 0, 1)
    return rgba


def face_emissive(level, size=512):
    X, Z, eye, iris, slit, brow, lid, mark, mouth, teeth, fang = _face_layers(level, size)
    g = np.clip(np.maximum(iris * eye * (1 - slit), mark * 0.9), 0, 1)
    return np.repeat(g[..., None], 3, -1)


#@animh


def anim_idle():
    F = 72
    keys = {}
    for f in range(0, F + 1, 3):
        t = f / F
        w = 2 * math.pi * t
        drum = _pulse(t, 0.55, 0.7)
        k = {'Hips': P(loc=(0, 0, 0.015 * math.sin(2 * w))), 'Torso': P(('x', 8 + 2 * math.sin(2 * w))),
             'Head': P(('z', 12 * math.sin(w * 0.5)), ('x', -8)), 'Jaw': P(('x', 10 * _pulse(t, 0.3, 0.42))),
             'Drums': P(('y', 30 * math.sin(w))),
             'ArmU.L': P(('x', -10 + 6 * math.sin(w)), ('y', -10)), 'ArmU.R': P(('x', -10 - 40 * drum), ('y', 10 + 30 * drum)),
             'ArmL.R': P(('x', -40 * drum)), 'LegU.L': P(('x', -10)), 'LegU.R': P(('x', -10)), 'LegL.L': P(('x', 14)), 'LegL.R': P(('x', 14))}
        keys[f] = k
    keys[F] = dict(keys[0])
    return {'frames': F, 'loop': True, 'keys': keys}


def _walk(frames, swing, bounce, lean):
    keys = {}
    for f in range(0, frames + 1, 2):
        t = f / frames
        w = 2 * math.pi * t
        k = {'Hips': P(('z', 6 * math.sin(w)), loc=(0, 0, bounce * abs(math.sin(w)))), 'Torso': P(('x', lean), ('z', -8 * math.sin(w))),
             'Head': P(('x', -lean * 0.6)), 'Drums': P(('y', 10 * math.sin(w)))}
        for s, off in (('L', 0.0), ('R', math.pi)):
            ph = w + off
            k['LegU.' + s] = P(('x', -swing * math.sin(ph) - 6))
            k['LegL.' + s] = P(('x', swing * 0.8 * max(0, math.cos(ph)) + 8))
            k['ArmU.' + s] = P(('x', swing * 0.9 * math.sin(ph) - 6), ('y', (-1 if s == 'L' else 1) * 8))
            k['ArmL.' + s] = P(('x', -20 - 10 * max(0, math.sin(ph))))
        keys[f] = k
    keys[frames] = dict(keys[0])
    return {'frames': frames, 'loop': True, 'keys': keys}


def anim_walk():
    return _walk(24, 26, 0.04, 14)


def anim_run():
    return _walk(14, 44, 0.1, 26)


def anim_hop():
    keys = {}
    for f in range(0, 17, 2):
        t = f / 16
        up = math.sin(math.pi * t)
        keys[f] = {'Hips': P(loc=(0, 0, 0.4 * up)), 'ArmU.L': P(('y', -50 * up)), 'ArmU.R': P(('y', 50 * up)),
                   'LegU.L': P(('x', -20 * up)), 'LegU.R': P(('x', -20 * up)), 'LegL.L': P(('x', 30 * up)), 'LegL.R': P(('x', 30 * up))}
    return {'frames': 16, 'loop': False, 'keys': keys}


def anim_ability():
    """Knockback (~1 s, Runner): raises both fists high, roars, then pounds the ground with both (the shockwave at ~0.5)."""
    keys = {}
    F = 24
    for f in range(0, F + 1, 2):
        t = f / F
        up = _ease(t / 0.4) * (1 - _ease((t - 0.42) / 0.08))
        slam = _ease((t - 0.42) / 0.08) * (1 - _ease((t - 0.75) / 0.25))
        k = {'Hips': P(loc=(0, 0, 0.06 * up - 0.06 * slam)), 'Torso': P(('x', -14 * up + 30 * slam)),
             'Head': P(('x', -14 * up + 4 * slam)), 'Jaw': P(('x', 30 * up + 20 * slam)), 'Drums': P(('x', 15 * slam), ('y', 90 * t)),
             'ArmU.L': P(('x', -140 * up - 40 * slam), ('y', -10)), 'ArmU.R': P(('x', -140 * up - 40 * slam), ('y', 10)),
             'ArmL.L': P(('x', -20 * up)), 'ArmL.R': P(('x', -20 * up)),
             'LegU.L': P(('x', -20 * slam)), 'LegU.R': P(('x', -20 * slam)), 'LegL.L': P(('x', 30 * slam)), 'LegL.R': P(('x', 30 * slam))}
        keys[f] = k
    return {'frames': F, 'loop': False, 'keys': keys}


def anim_drum():
    """Storm Ball (~0.9 s, Catcher): beats the drum behind its shoulder twice, then thrusts a palm forward (the ball)."""
    keys = {}
    F = 22
    for f in range(0, F + 1, 1):
        t = f / F
        beat = _pulse(t, 0.0, 0.18) + _pulse(t, 0.18, 0.36)
        thrust = _ease((t - 0.4) / 0.1) * (1 - _ease((t - 0.75) / 0.25))
        k = {'Torso': P(('x', 8 - 6 * beat + 14 * thrust), ('z', -15 * beat)), 'Head': P(('x', -6 * thrust)),
             'Jaw': P(('x', 25 * thrust)), 'Drums': P(('y', 40 * beat)),
             'ArmU.R': P(('x', -110 * beat - 80 * thrust), ('y', 30 * beat)), 'ArmL.R': P(('x', -60 * beat + 10 * thrust)),
             'ArmU.L': P(('x', -20 + 10 * beat), ('y', -10)), 'LegU.L': P(('x', -10)), 'LegU.R': P(('x', -10 + 10 * thrust))}
        keys[f] = k
    return {'frames': F, 'loop': False, 'keys': keys}


ANIMS = {'Idle': anim_idle, 'Walk': anim_walk, 'Run': anim_run, 'Hop': anim_hop, 'Ability': anim_ability,
         'Drum': anim_drum}
