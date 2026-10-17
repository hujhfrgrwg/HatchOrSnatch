# Aegis Kirin (Guardian, Legendary) for Hatch or Snatch: HOS-PET-029, built on the pet kit. Assembled by assemble_pet.py.
# Reshaped 17 Oct (HOS-PET-RESHAPE): its own body plan, a tall slender deer high on long legs with backward hocks, a
# long neck carried almost upright (the Chest bone runs up it) and a small head held high under tall antlers.
# From the concept card (docs/pets/aegis_kirin/aegis_kirin_card.png): a white qilin with branching gold antlers, a gold
# flame mane and flame tail, blue scale markings on its back, blue hooves and green-teal eyes.
# Read through PET_LESSONS (anime / edgy): pale ivory fur with fur strokes and jagged blue scale plates, a lean
# deer-dragon head, narrow slanted glowing teal slit eyes under a heavy brow, a flat mouth with one small fang (face
# decal shell), sharp gold flame blades for mane and tail, dark-blue hooves. L2 "Aegis Warden": a gold chest aegis
# with a blue gem, gold shoulder guards, glowing scale plates. L3 "Celestial Aegis": a floating gold halo ring of
# blue crystal shards behind the head, crystal antler tips, flame anklets, white-cyan glow and eyes.
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

NAME = 'Kirin'
SHARP_ANGLE = 40
NORMAL_STRENGTH = 2.0
TS = 1024
ATLAS = Atlas({
    'skin': (0, 0, 1024, 384),
    'head': (0, 384, 512, 256),
    'limb': (512, 384, 512, 128),
    'tail': (512, 512, 512, 128),
    'flame': (0, 640, 256, 128),    # gold flame blades: v root -> tip
    'antler': (256, 640, 128, 128),
    'hoof': (384, 640, 128, 128),
    'gold': (512, 640, 256, 128),
    'gem': (768, 640, 128, 128),
    'ear': (896, 640, 128, 128),
    'crystal': (0, 768, 256, 128),
    'jaw': (256, 768, 256, 128),
})

GLOW = {1: ('a86a00', 'ffd23a', 'fff6c8'), 2: ('a87000', 'ffe04a', 'fffbe0'), 3: ('2a8ac8', '8ae8ff', 'f4fdff')}
EYE = {1: ('0a6a5a', '3ae8c0', 'e8fff8'), 2: ('0a6a6a', '4af0d8', 'f0fffc'), 3: ('1a6ab8', '8ae0ff', 'f8feff')}
FUR = [(0, 'a8acc0'), (0.5, 'dcdde8'), (1, 'f8f8fc')]
BLUE = [(0, '0a2a6a'), (0.5, '2a6ad0'), (1, '7ab8ff')]


def bones_def():
    b = [
        ('Root', V(0, 0, 0), V(0, 0, 0.2), None),
        ('Body', V(0, 0.4, 1.32), V(0, -0.1, 1.36), 'Root'),
        ('Chest', V(0, -0.1, 1.36), V(0, -0.5, 2.1), 'Body'),
        ('Head', V(0, -0.56, 2.24), V(0, -1.02, 2.12), 'Chest'),
        ('Jaw', V(0, -0.72, 2.12), V(0, -1.0, 2.06), 'Head'),
        ('Tail1', V(0, 0.52, 1.42), V(0, 0.7, 1.5), 'Body'),
        ('Tail2', V(0, 0.7, 1.5), V(0, 0.84, 1.62), 'Tail1'),
        ('Tail3', V(0, 0.84, 1.62), V(0, 0.92, 1.8), 'Tail2'),
        ('Halo', V(0, -0.36, 2.5), V(0, -0.36, 2.7), 'Chest'),
    ]
    for s, x in (('L', 1), ('R', -1)):
        b += [
            ('Ear.' + s, V(x * 0.12, -0.6, 2.36), V(x * 0.3, -0.52, 2.44), 'Head'),
            ('FrontUpper.' + s, V(x * 0.15, -0.2, 1.26), V(x * 0.16, -0.22, 0.7), 'Chest'),
            ('FrontLower.' + s, V(x * 0.16, -0.22, 0.7), V(x * 0.16, -0.24, 0.18), 'FrontUpper.' + s),
            ('FrontFoot.' + s, V(x * 0.16, -0.24, 0.18), V(x * 0.16, -0.28, 0.04), 'FrontLower.' + s),
            ('BackUpper.' + s, V(x * 0.16, 0.38, 1.26), V(x * 0.17, 0.44, 0.68), 'Body'),
            ('BackLower.' + s, V(x * 0.17, 0.44, 0.68), V(x * 0.17, 0.4, 0.16), 'BackUpper.' + s),
            ('BackFoot.' + s, V(x * 0.17, 0.4, 0.16), V(x * 0.17, 0.34, 0.04), 'BackLower.' + s),
        ]
    return b


#@helpers
FX, FZ, FZH = 0.27, 2.28, 0.225
SHELL = (-0.62, 2.06, 2.5)
DFX, DFZ, DFZH = 0.36, 1.38, 0.3    # the face decal is drawn in these units, then mapped onto FX / FZ / FZH
#@shell


def _blade(mb, base, d, ln, w, wid=0.12, part='flame', region='flame'):
    bipyramid(mb, base, base + nrm(d) * ln, V(1, 0, 0) if abs(nrm(d)[0]) < 0.6 else V(0, 1, 0), V(0, -1, 0), wid, wid * 0.4, w,
              ATLAS.uv(region, 0.5, 0.05), ATLAS.uv(region, 0.5, 0.95), part, wide_at=0.28, ridge_at=0.28, curl=0.15)


def build():
    mb = MB()
    mb.mat = 0
    W_B, W_C, W_H, W_J = {'Body': 1}, {'Chest': 1}, {'Head': 1}, {'Jaw': 1}
    # tall slender deer: a short deep body high on long legs, and a long neck rising almost straight up to a high head
    st = [(V(0, 0.58, 1.38), (0.12, 0.12), {'Body': 0.5, 'Tail1': 0.5}), (V(0, 0.44, 1.34), (0.22, 0.24), W_B),
          (V(0, 0.18, 1.32), (0.21, 0.25), W_B), (V(0, -0.08, 1.36), (0.22, 0.27), {'Body': 0.5, 'Chest': 0.5}),
          (V(0, -0.26, 1.5), (0.18, 0.21), W_C), (V(0, -0.38, 1.74), (0.13, 0.14), W_C),
          (V(0, -0.47, 1.98), (0.11, 0.12), W_C), (V(0, -0.53, 2.18), (0.12, 0.13), {'Chest': 0.5, 'Head': 0.5})]
    tube(mb, 'skin', [s[0] for s in st], [s[1] for s in st], 14, [s[2] for s in st], 'body',
         start='point', end='point', start_pt=V(0, 0.66, 1.4), end_pt=V(0, -0.55, 2.28), side_hint=V(1, 0, 0), th0=math.pi / 2)
    n0 = len(mb.F)
    # small, fine deer-dragon head held high
    hs = [(V(0, -0.52, 2.3), (0.15, 0.15), W_H), (V(0, -0.64, 2.32), (0.2, 0.18), W_H),
          (V(0, -0.78, 2.27), (0.16, 0.14), W_H), (V(0, -0.9, 2.21), (0.11, 0.1), W_H), (V(0, -0.98, 2.18), (0.075, 0.07), W_H)]
    tube(mb, 'head', [h[0] for h in hs], [h[1] for h in hs], 12, [h[2] for h in hs], 'head', start='point', end='point',
         start_pt=V(0, -0.46, 2.32), end_pt=V(0, -1.03, 2.17), side_hint=V(1, 0, 0), th0=math.pi / 2)
    head_faces = list(range(n0, len(mb.F)))
    js = [(V(0, -0.7, 2.17), (0.12, 0.045), W_J), (V(0, -0.84, 2.14), (0.09, 0.04), W_J), (V(0, -0.94, 2.13), (0.05, 0.03), W_J)]
    tube(mb, 'jaw', [j[0] for j in js], [j[1] for j in js], 8, [j[2] for j in js], 'jaw', start='point', end='point',
         start_pt=V(0, -0.62, 2.19), end_pt=V(0, -0.98, 2.13), side_hint=V(1, 0, 0), th0=math.pi / 2)
    for s, x in (('L', 1), ('R', -1)):
        # swept ears
        bipyramid(mb, V(x * 0.12, -0.6, 2.36), V(x * 0.33, -0.52, 2.46), V(0, 1, 0), V(0, -1, 0.3), 0.1, 0.04,
                  {'Ear.' + s: 1}, ATLAS.uv('ear', 0.5, 0.9), ATLAS.uv('ear', 0.5, 0.1), 'ear', wide_at=0.4, ridge_at=0.4)
        # tall branching gold antlers: a swept beam with forward tines
        path = [V(x * 0.07, -0.66, 2.42), V(x * 0.12, -0.6, 2.62), V(x * 0.19, -0.5, 2.8), V(x * 0.24, -0.38, 2.92)]
        tube(mb, 'antler', path, [(0.04, 0.04), (0.035, 0.035), (0.027, 0.027), (0.018, 0.018)], 6, [W_H] * 4, 'antler',
             start='point', end='point', start_pt=V(x * 0.06, -0.66, 2.37), end_pt=V(x * 0.26, -0.33, 2.98), side_hint=V(-1, 0, 0))
        for (p0, d, ln) in ((V(x * 0.12, -0.6, 2.64), V(x * 0.3, -0.7, 0.7), 0.18), (V(x * 0.18, -0.52, 2.78), V(x * 0.4, -0.5, 0.8), 0.16),
                            (V(x * 0.1, -0.64, 2.52), V(x * 0.8, -0.2, 0.3), 0.12)):
            bipyramid(mb, p0, p0 + nrm(d) * ln, V(0, 0, 1), V(0, -1, 0), 0.045, 0.035, W_H,
                      ATLAS.uv('antler', 0.5, 0.1), ATLAS.uv('antler', 0.5, 0.95), 'antler', wide_at=0.3, ridge_at=0.3)
    # gold flame mane: blades streaming back off the crest of the long neck
    for k in range(8):
        t = k / 7
        base = V(0, -0.5 + 0.42 * t, 2.34 - 0.78 * t)
        for sx in ((-1, 1) if k % 2 else (0,)):
            _blade(mb, base + V(sx * 0.05, 0, 0), V(sx * 0.6, 1.0, 0.3 - 0.2 * t), 0.4 - 0.1 * t, W_H if t < 0.12 else W_C, wid=0.2)
    _blade(mb, V(0, -0.66, 2.42), V(0, -0.5, 0.8), 0.22, W_H, wid=0.14)
    for x in (1, -1):
        for k, (dz, ln) in enumerate(((0.08, 0.26), (-0.06, 0.2))):
            _blade(mb, V(x * 0.17, -0.14, 1.42 + dz), V(x * 0.8, 0.7, 0.3 + dz), ln, W_C, wid=0.14)
    # long slender legs: straight forelegs, hind legs with a backward hock, gold flame fetlock tufts, blue hooves
    for s, x in (('L', 1), ('R', -1)):
        fu, fl, ff = 'FrontUpper.' + s, 'FrontLower.' + s, 'FrontFoot.' + s
        front = [(V(x * 0.14, -0.2, 1.3), (0.11, 0.13), {'Chest': 0.6, fu: 0.4}), (V(x * 0.15, -0.21, 1.0), (0.075, 0.085), {fu: 1}),
                 (V(x * 0.16, -0.22, 0.72), (0.055, 0.06), {fu: 0.5, fl: 0.5}), (V(x * 0.16, -0.23, 0.4), (0.045, 0.045), {fl: 1}),
                 (V(x * 0.16, -0.24, 0.16), (0.05, 0.05), {fl: 0.5, ff: 0.5})]
        tube(mb, 'limb', [f[0] for f in front], [f[1] for f in front], 8, [f[2] for f in front], 'front' + s,
             start='point', end='open', start_pt=V(x * 0.08, -0.18, 1.36))
        bu, bl, bf = 'BackUpper.' + s, 'BackLower.' + s, 'BackFoot.' + s
        back = [(V(x * 0.15, 0.4, 1.28), (0.13, 0.17), {'Body': 0.6, bu: 0.4}), (V(x * 0.16, 0.34, 1.0), (0.1, 0.11), {bu: 1}),
                (V(x * 0.17, 0.44, 0.68), (0.055, 0.06), {bu: 0.5, bl: 0.5}), (V(x * 0.17, 0.42, 0.4), (0.045, 0.045), {bl: 1}),
                (V(x * 0.17, 0.4, 0.16), (0.05, 0.05), {bl: 0.5, bf: 0.5})]
        tube(mb, 'limb', [f[0] for f in back], [f[1] for f in back], 8, [f[2] for f in back], 'back' + s,
             start='point', end='open', start_pt=V(x * 0.08, 0.4, 1.34))
        for foot, bone in ((V(x * 0.16, -0.25, 0.0), ff), (V(x * 0.17, 0.39, 0.0), bf)):
            tube(mb, 'hoof', [foot + V(0, 0, 0.12), foot + V(0, -0.02, 0.05), foot + V(0, -0.03, 0.01)],
                 [(0.055, 0.055), (0.07, 0.07), (0.075, 0.065)], 8, [{bone: 1}] * 3, 'hoof', start='open', end='flat', side_hint=V(1, 0, 0))
            for k2 in (-1, 1):
                _blade(mb, foot + V(x * 0.03 * k2, 0.02, 0.16), V(k2 * 0.5 * x, 0.6, 0.6), 0.12, {bone: 1}, wid=0.06)
    # short flame tail, carried high
    tp = [V(0, 0.56, 1.42), V(0, 0.7, 1.5), V(0, 0.82, 1.62), V(0, 0.88, 1.78)]
    tube(mb, 'tail', tp, [(0.06, 0.06), (0.07, 0.07), (0.07, 0.07), (0.05, 0.05)], 8,
         [{'Body': 0.4, 'Tail1': 0.6}, {'Tail1': 1}, {'Tail2': 1}, {'Tail3': 1}], 'tail', start='point', end='point',
         start_pt=V(0, 0.52, 1.4), end_pt=V(0, 0.9, 1.84))
    for k, d in enumerate((V(0.6, 0.6, 0.3), V(-0.6, 0.6, 0.3), V(0, 0.9, 0.5), V(0.35, 0.4, 1), V(-0.35, 0.4, 1), V(0, 1, -0.2), V(0, 0.3, 1))):
        _blade(mb, V(0, 0.8, 1.62) + V(0, 0.02 * k, 0.03 * k), d, 0.42 if k < 3 else 0.34, {'Tail3': 1} if k > 1 else {'Tail2': 1}, wid=0.2)
    mb.mat = 1
    face_shell(mb, head_faces)
    # ---- L2 "Aegis Warden": chest aegis with a blue gem, gold shoulder guards
    mb.mat = 2
    bipyramid(mb, V(0, -0.36, 1.64), V(0, -0.4, 1.22), V(1, 0, 0), V(0, -1, 0), 0.3, 0.09, W_C,
              ATLAS.uv('gold', 0.4, 0.8), ATLAS.uv('gold', 0.6, 0.2), 'L2', wide_at=0.45, ridge_at=0.45)
    bipyramid(mb, V(0, -0.46, 1.48), V(0, -0.46, 1.37), V(1, 0, 0), V(0, -1, 0), 0.1, 0.09, W_C,
              ATLAS.uv('gem', 0.5, 0.1), ATLAS.uv('gem', 0.5, 0.9), 'L2')
    for x in (1, -1):
        bipyramid(mb, V(x * 0.13, -0.16, 1.52), V(x * 0.34, -0.12, 1.36), V(0, 1, 0), V(x, 0, 1), 0.26, 0.09, W_C,
                  ATLAS.uv('gold', 0.4, 0.8), ATLAS.uv('gold', 0.6, 0.2), 'L2', wide_at=0.45, ridge_at=0.45)
        bipyramid(mb, V(x * 0.26, -0.14, 1.48), V(x * 0.34, -0.1, 1.68), V(0, 1, 0), V(x, 0, 1), 0.06, 0.045, W_C,
                  ATLAS.uv('gold', 0.4, 0.8), ATLAS.uv('gold', 0.6, 0.2), 'L2', wide_at=0.3, ridge_at=0.3)
    # ---- L3 "Celestial Aegis": a halo ring of blue crystal shards behind the head, crystal antler tips, flame anklets
    mb.mat = 3
    hc = V(0, -0.36, 2.5)
    cen = [hc + V(math.cos(2 * math.pi * i / 16) * 0.38, 0, math.sin(2 * math.pi * i / 16) * 0.38) for i in range(17)]
    tube(mb, 'gold', cen, [(0.022, 0.022)] * 17, 4, [{'Halo': 1}] * 17, 'L3', start='open', end='open', side_hint=V(0, 1, 0), anti=False)
    for k in range(6):
        a = 2 * math.pi * k / 6 + math.pi / 6
        p = hc + V(math.cos(a) * 0.38, 0, math.sin(a) * 0.38)
        bipyramid(mb, p - V(math.cos(a), 0, math.sin(a)) * 0.05, p + V(math.cos(a), 0, math.sin(a)) * 0.18, V(0, 1, 0), V(0, -1, 0),
                  0.09, 0.055, {'Halo': 1}, ATLAS.uv('crystal', 0.5, 0.1), ATLAS.uv('crystal', 0.5, 0.95), 'L3', wide_at=0.35, ridge_at=0.35)
    for x in (1, -1):
        p0 = V(x * 0.24, -0.38, 2.9)
        bipyramid(mb, p0 - V(0, 0, 0.04), p0 + V(x * 0.05, 0.07, 0.18), V(1, 0, 0), V(0, -1, 0), 0.07, 0.05, W_H,
                  ATLAS.uv('crystal', 0.5, 0.1), ATLAS.uv('crystal', 0.5, 0.95), 'L3', wide_at=0.35, ridge_at=0.35)
        for bone, foot in (('FrontLower.' + ('L' if x > 0 else 'R'), V(x * 0.16, -0.23, 0.42)), ('BackLower.' + ('L' if x > 0 else 'R'), V(x * 0.17, 0.42, 0.42))):
            _blade(mb, foot, V(x, 0.4, 0.5), 0.16, {bone: 1}, wid=0.07, part='L3', region='crystal')
    mb.mat = 0
    return mb


#@paint_helpers


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
        if reg == 'skin':
            # jagged blue scale plates along the back and down the flanks
            row = np.floor(v * 10)
            cu = u * 13 + 0.5 * (row % 2)
            fu, fv = cu - np.floor(cu) - 0.5, v * 10 - row
            scale = ss(0.0, 0.06, 0.85 - fv - 1.6 * fu ** 2)
            zone = ss(0.0, 0.2, top - 0.35 + 0.2 * _saw(v * 7)) * ss(0.12, 0.22, v) * ss(0.85, 0.75, v)
            plate = scale * zone
            c = c * (1 - plate[..., None]) + grad(np.clip(fv, 0, 1), BLUE) * plate[..., None]
            edge = zone * ss(0.03, 0.0, np.abs(0.85 - fv - 1.6 * fu ** 2) - 0.02)
            c = c * (1 - 0.6 * edge[..., None]) + hx('0a1a4a') * (0.6 * edge[..., None])
            glow[y0:y1, x0:x1] = plate * (0.08 + 0.3 * (level >= 2)) * fv
            hgt[y0:y1, x0:x1] = 0.5 + 0.3 * plate
        st = _streaks(h, w, 170, 91)
        col[y0:y1, x0:x1] = c * (1 + 0.15 * st[..., None])
        if reg != 'skin':
            hgt[y0:y1, x0:x1] = 0.5 + 0.4 * st
    (y0, y1, x0, x1), v, u = _reg('limb')
    st = _streaks(y1 - y0, x1 - x0, 60, 92)
    sock = ss(0.0, 0.04, v - (0.72 + 0.05 * _saw(u * 8)))
    c = grad(np.clip(0.8 - 0.2 * v, 0, 1), FUR) * (1 + 0.15 * st[..., None])
    col[y0:y1, x0:x1] = c * (1 - sock[..., None]) + grad(np.clip(v, 0, 1), BLUE) * sock[..., None]
    hgt[y0:y1, x0:x1] = 0.5 + 0.4 * st
    (y0, y1, x0, x1), v, u = _reg('flame')
    tongue = 0.5 + 0.5 * np.cos(u * 2 * math.pi * 2 + v * 5)
    col[y0:y1, x0:x1] = grad(np.clip(v + 0.1 * tongue, 0, 1), [(0, 'fff6c8'), (0.35, 'ffd23a'), (0.8, 'f09a10'), (1, 'b85a00')])
    glow[y0:y1, x0:x1] = (0.55 - 0.35 * v) * (1 + 0.4 * (level >= 2))
    (y0, y1, x0, x1), v, u = _reg('antler')
    ridges = 0.5 + 0.5 * np.cos(v * 2 * math.pi * 7)
    col[y0:y1, x0:x1] = grad(v, [(0, '8a5a08'), (0.5, 'f0b030'), (1, 'fff0a0')]) * (0.85 + 0.15 * ridges[..., None])
    rgh[y0:y1, x0:x1] = 0.3
    glow[y0:y1, x0:x1] = 0.15 + 0.5 * ss(0.8, 1.0, v)
    (y0, y1, x0, x1), v, u = _reg('hoof')
    col[y0:y1, x0:x1] = grad(v, [(0, '2a5ab8'), (1, '0a1a4a')])
    rgh[y0:y1, x0:x1] = 0.3
    (y0, y1, x0, x1), v, u = _reg('gold')
    eng = ss(0.02, 0.0, np.abs(_saw(v * 5) - 0.5) - 0.03)
    col[y0:y1, x0:x1] = grad(u, [(0, 'fff0a0'), (0.45, 'f0b030'), (1, '8a5a08')]) * (1 - 0.35 * eng[..., None])
    rgh[y0:y1, x0:x1] = 0.25
    glow[y0:y1, x0:x1] = 0.12
    (y0, y1, x0, x1), v, u = _reg('gem')
    col[y0:y1, x0:x1] = grad(v, [(0, 'd0f0ff'), (0.5, '3a8aff'), (1, '0a2a8a')])
    rgh[y0:y1, x0:x1] = 0.1
    glow[y0:y1, x0:x1] = 0.8
    (y0, y1, x0, x1), v, u = _reg('ear')
    inner = ss(0.32, 0.42, np.cos(u * 2 * math.pi) * 0.5 + 0.5)
    col[y0:y1, x0:x1] = grad(v, FUR) * (1 - inner[..., None]) + grad(v, BLUE) * inner[..., None]
    (y0, y1, x0, x1), v, u = _reg('crystal')
    facet = 0.5 + 0.5 * np.sign(np.sin(u * 2 * math.pi * 3))
    col[y0:y1, x0:x1] = grad(v, [(0, '1a4ab8'), (0.6, gm), (1, gh)]) * (0.8 + 0.2 * facet[..., None])
    rgh[y0:y1, x0:x1] = 0.12
    glow[y0:y1, x0:x1] = 0.4 + 0.5 * v
    (y0, y1, x0, x1), v, u = _reg('jaw')
    col[y0:y1, x0:x1] = grad(v, [(0, 'e0e0ea'), (0.6, 'c8c8d8'), (1, '1a1a2a')])
    paint_atlas._glow = np.clip(glow, 0, 1)
    return np.clip(col, 0, 1), hgt, rgh


def emissive_mask(level):
    paint_atlas(level)
    return np.repeat(paint_atlas._glow[..., None], 3, -1)


#@seg


def _face_layers(level, size):
    x, y = coords(size)
    X, Z = x * DFX, DFZ + y * DFZH
    aX = np.abs(X)
    ix, iz, ox, oz = 0.07, 1.43, 0.2, 1.5
    ex, ez = ox - ix, oz - iz
    L = math.hypot(ex, ez)
    s = ((aX - ix) * ex + (Z - iz) * ez) / (L * L)
    d = (-(aX - ix) * ez + (Z - iz) * ex) / L
    sc = np.clip(s, 0, 1)
    top = 0.03 * np.clip(sc * 3.0, 0, 1) * (1 - sc ** 4) + 0.002
    bot = -0.022 * np.clip(np.sin(math.pi * sc), 0, 1) ** 0.9 - 0.001
    eye = ss(0.003, 0.0, np.maximum(d - top, bot - d)) * (s > 0) * (s < 1)
    cxs, czs = ix + 0.5 * ex, iz + 0.5 * ez
    rr = np.sqrt((aX - cxs) ** 2 + (Z - czs) ** 2)
    _face_layers.rr = rr
    iris = ss(0.044, 0.04, rr)
    slit = ss(0.005 * np.clip(1 - ((Z - czs) / 0.032) ** 2, 0, 1) + 0.0005, 0.0, np.abs(aX - cxs)) * ss(0.032, 0.028, rr)
    brow = np.maximum(_seg(aX, Z, (0.04, 1.47), (0.22, 1.55), 0.012, 0.005), _seg(aX, Z, (0.2, 1.545), (0.27, 1.6), 0.008, 0.001))
    lid = ss(0.006, 0.003, np.abs(d - top - 0.003)) * (s > -0.05) * (s < 1.02)
    # blue forehead flame marking and cheek stripes (the card's blue face markings)
    mark = np.maximum(_seg(X, Z, (0.0, 1.52), (0.0, 1.64), 0.03, 0.004), _seg(aX, Z, (0.03, 1.55), (0.07, 1.63), 0.014, 0.002))
    mark = np.maximum(mark, _seg(aX, Z, (0.17, 1.38), (0.24, 1.32), 0.01, 0.002))
    if level >= 3:
        mark = np.maximum(mark, _seg(aX, Z, (0.1, 1.6), (0.16, 1.66), 0.008, 0.002))
    mouth = _seg(aX, Z, (0.0, 1.235), (0.12, 1.25), 0.004, 0.003)
    fang = ss(0.08, 0.0, np.abs(X - 0.07) / 0.009 + (1.24 - Z) / 0.028 - 1) * (Z < 1.24) * (Z > 1.21)
    nose = np.maximum(ss(0.004, 0.0, np.abs(aX - 0.035) / 0.016 + np.abs(Z - 1.31) / 0.012 - 1), 0)
    return X, Z, eye, iris, slit, brow, lid, mark, mouth, fang, nose


def face_texture(level, size=512):
    X, Z, eye, iris, slit, brow, lid, mark, mouth, fang, nose = _face_layers(level, size)
    rr = _face_layers.rr
    ed, em, eh = EYE[level]
    rgba = np.zeros((size, size, 4), np.float32)
    c = np.zeros((size, size, 3), np.float32) + hx('2a6ad0')
    irisc = grad(np.clip(1 - rr / 0.04, 0, 1), [(0, ed), (0.45, em), (1, eh)])
    e = hx('06100e') * (1 - iris[..., None]) + irisc * iris[..., None]
    e = e * (1 - slit[..., None]) + hx('020404') * slit[..., None]
    c = c * (1 - eye[..., None]) + e * eye[..., None]
    ln = np.maximum.reduce([lid, mouth])
    c = c * (1 - brow[..., None]) + hx('8a5a10') * brow[..., None]
    c = c * (1 - ln[..., None]) + hx('0a0c18') * ln[..., None]
    c = c * (1 - fang[..., None]) + hx('f8f6f0') * fang[..., None]
    c = c * (1 - nose[..., None]) + hx('1a1a2a') * nose[..., None]
    rgba[..., :3] = c
    rgba[..., 3] = np.clip(np.maximum.reduce([eye, brow, ln, mark, fang, nose]), 0, 1)
    return rgba


def face_emissive(level, size=512):
    X, Z, eye, iris, slit, brow, lid, mark, mouth, fang, nose = _face_layers(level, size)
    g = np.clip(np.maximum(iris * eye * (1 - slit), mark * (0.3 + 0.4 * (level >= 2))), 0, 1)
    return np.repeat(g[..., None], 3, -1)


#@animh
#@gait


def anim_idle():
    F = 72
    keys = {}
    for f in range(0, F + 1, 3):
        t = f / F
        w = 2 * math.pi * t
        toss = _pulse(t, 0.55, 0.75)
        k = {'Body': P(loc=(0, 0, 0.012 * math.sin(2 * w))), 'Chest': P(('x', 2 * math.sin(2 * w)), ('z', 5 * math.sin(w))),
             'Head': P(('z', 10 * math.sin(w * 0.5)), ('x', -12 * toss)), 'Jaw': P(('x', 4 * toss)),
             'Halo': P(('y', 360 * t)),
             'Ear.L': P(('x', -15 * _pulse(t, 0.2, 0.28))), 'Ear.R': P(('x', -15 * _pulse(t, 0.3, 0.38)))}
        for s in 'LR':
            k['FrontUpper.' + s] = P(('x', -14 * _pulse(t, 0.1, 0.25) * (s == 'L')))
            k['FrontLower.' + s] = P(('x', 26 * _pulse(t, 0.1, 0.25) * (s == 'L')))
        k.update(_tail(w, 12, -4))
        keys[f] = k
    keys[F] = dict(keys[0])
    keys[F]['Halo'] = P(('y', 0))
    return {'frames': F, 'loop': True, 'keys': keys}


def anim_walk():
    return _gait(24, 22, 36, 0.03, 0, 8)


def anim_run():
    return _gait(14, 42, 56, 0.09, 6, 6)


def anim_hop():
    keys = {}
    for f in range(0, 17, 2):
        t = f / 16
        upv = math.sin(math.pi * t)
        p = {'Body': P(('x', -10 * upv), loc=(0, 0, 0.45 * upv))}
        for s in 'LR':
            p['BackUpper.' + s] = P(('x', 30 * upv))
            p['FrontUpper.' + s] = P(('x', -40 * upv))
            p['FrontLower.' + s] = P(('x', 50 * upv))
        keys[f] = p
    return {'frames': 16, 'loop': False, 'keys': keys}


def anim_ability():
    """Shield (~1 s, Runner): rears high on its hind legs with the antlers thrown back, then stamps both hooves down
    (the aegis dome rises at ~0.5) and lowers its head to brace."""
    keys = {}
    F = 24
    for f in range(0, F + 1, 2):
        t = f / F
        rear = _ease(t / 0.4) * (1 - _ease((t - 0.42) / 0.1))
        slam = _ease((t - 0.42) / 0.1) * (1 - _ease((t - 0.75) / 0.25))
        p = {'Body': P(('x', -34 * rear + 3 * slam), loc=(0, 0, 0.06 * rear)), 'Chest': P(('x', -6 * rear + 10 * slam)),
             'Head': P(('x', -18 * rear + 16 * slam)), 'Jaw': P(('x', 14 * rear)), 'Halo': P(('y', 540 * t))}
        for s, x in (('L', 1), ('R', -1)):
            p['FrontUpper.' + s] = P(('x', -60 * rear - 8 * slam), ('y', -x * 8 * slam))
            p['FrontLower.' + s] = P(('x', 60 * rear))
            p['BackUpper.' + s] = P(('x', 34 * rear))
            p['BackLower.' + s] = P(('x', -20 * rear))
        p.update(_tail(6 * t, 12, -25 * rear))
        keys[f] = p
    return {'frames': F, 'loop': False, 'keys': keys}


def anim_reach():
    """Long Reach (~0.9 s, Catcher): plants, drops its head and levels the antlers like a lance, then thrusts forward
    (the beam fires from the antlers at ~0.42) and pulls back."""
    keys = {}
    F = 22
    for f in range(0, F + 1, 1):
        t = f / F
        crouch = _ease(t / 0.3) * (1 - _ease((t - 0.32) / 0.1))
        thrust = _ease((t - 0.32) / 0.1) * (1 - _ease((t - 0.7) / 0.3))
        p = {'Body': P(('x', 4 * crouch - 3 * thrust), loc=(0, 0.1 * crouch - 0.16 * thrust, -0.05 * crouch)),
             'Chest': P(('x', 22 * crouch + 30 * thrust)), 'Head': P(('x', 12 * crouch + 14 * thrust), loc=(0, -0.08 * thrust, 0)),
             'Jaw': P(('x', 8 * thrust))}
        for s in 'LR':
            p['FrontUpper.' + s] = P(('x', 10 * crouch - 18 * thrust))
            p['BackUpper.' + s] = P(('x', -10 * crouch + 14 * thrust))
        p.update(_tail(6 * t, 8, 18 * thrust))
        keys[f] = p
    return {'frames': F, 'loop': False, 'keys': keys}


ANIMS = {'Idle': anim_idle, 'Walk': anim_walk, 'Run': anim_run, 'Hop': anim_hop, 'Ability': anim_ability,
         'Reach': anim_reach}
