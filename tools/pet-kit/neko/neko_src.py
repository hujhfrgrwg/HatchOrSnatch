# Veil Nekomata (Invisibility, Legendary) for Hatch or Snatch: HOS-PET-028, built on the pet kit. Assembled by
# assemble_pet.py. From the concept card (docs/pets/veil_nekomata/veil_nekomata_card.png): a black-and-white cat yokai
# with two forked tails wreathed in blue ghost fire (onibi), blue flames round its ears, a blue collar with a gold tag,
# cyan eyes.
# Reshaped 17 Oct (HOS-PET-RESHAPE): its own body plan, a sleek slinky cat high on long thin legs with an arched
# back, a longer body and two long tails sweeping high (`_slink`, applied after the build).
# Redone 17 Oct (HOS-PET-REDO, Hunter: longer slimmer body, a real arched back, whip tails with wispy flames, its own
# colour apart from the Witch Cat): a ghost-silver coat with indigo ink tabby stripes, socks and cheek streaks, a
# crimson rope collar, thin S-curled whip tails ending in long curled cyan wisps.
# Read through PET_LESSONS (anime / edgy): near-black plum fur with fur strokes and a white bib and muzzle, tall sharp
# ears with dark-violet insides, narrow slanted glowing cyan slit eyes under a heavy brow, a flat mouth with one small
# fang (face decal shell), two long tails ending in blue onibi. L2 "Spirit Veil": a ghost-fire ruff round the neck,
# two floating onibi, flame tips on the ears, glowing cyan stripes. L3 "Thousand-Year Nekomata": a ring of five onibi
# over its back, a ghost-flame crown between the ears, third flame on each tail, violet-white eyes and glow.
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

NAME = 'Neko'
SHARP_ANGLE = 40
NORMAL_STRENGTH = 2.0
TS = 1024
ATLAS = Atlas({
    'skin': (0, 0, 1024, 384),
    'head': (0, 384, 512, 256),
    'limb': (512, 384, 512, 128),
    'tail': (512, 512, 512, 128),   # v root -> tip
    'ear': (0, 640, 256, 128),
    'claw': (256, 640, 128, 128),
    'collar': (384, 640, 384, 128),
    'gold': (768, 640, 256, 128),
    'fire': (0, 768, 512, 128),     # onibi: v base -> tip
    'ruff': (512, 768, 512, 128),
})

GLOW = {1: ('0a3aa0', '2ab8ff', 'd8f6ff'), 2: ('0a4ab0', '3ad0ff', 'e8fbff'), 3: ('2a2ab8', '7a9cff', 'f4f0ff')}
EYE = {1: ('0a4a8a', '2ad8ff', 'e8fcff'), 2: ('0a5a9a', '4ae8ff', 'f0feff'), 3: ('5a1ab0', 'c080ff', 'faf2ff')}
FUR = [(0, '4a4658'), (0.5, 'a8a6ba'), (1, 'e8e6f2')]   # silver spirit coat (17 Oct redo; was near-black like the Witch Cat)


TAIL_BONES = ('Tail1', 'Tail2', 'Tail3', 'TailB1', 'TailB2', 'TailB3')


def _slink0(p):
    """Long thin legs (everything below the body stretched 1.55x), the body lifted and lengthened, the back arched."""
    x, y, z = float(p[0]), float(p[1]), float(p[2])
    z2 = 1.3 * z if z < 0.7 else z + 0.21
    if z > 0.6:
        z2 += 0.36 * math.exp(-((y - 0.08) / 0.3) ** 2)     # a high, tight arch over the middle of the back
    return V(x, y * 1.45, z2)


def _slink(p, w):
    """_slink0, plus the twin tails stretched 1.2x away from their roots (by skin weight)."""
    q = _slink0(p)
    wt = sum(v for k, v in w.items() if k in TAIL_BONES)
    if wt > 0:
        root = _slink0(V(0.05 if p[0] >= 0 else -0.05, 0.5, 0.76))
        q = root + (q - root) * (1 + 0.3 * wt)
    return q


def bones_def():
    b = [
        ('Root', V(0, 0, 0), V(0, 0, 0.2), None),
        ('Body', V(0, 0.3, 0.7), V(0, -0.08, 0.72), 'Root'),
        ('Chest', V(0, -0.08, 0.72), V(0, -0.34, 0.82), 'Body'),
        ('Head', V(0, -0.38, 0.94), V(0, -0.9, 0.94), 'Chest'),
        ('Orbs', V(0, 0.1, 1.45), V(0, 0.1, 1.65), 'Body'),
    ]
    for s, x in (('L', 1), ('R', -1)):
        t = '' if s == 'L' else 'B'
        b += [
            ('Tail%s1' % t, V(x * 0.06, 0.5, 0.76), V(x * 0.14, 0.8, 0.92), 'Body'),
            ('Tail%s2' % t, V(x * 0.14, 0.8, 0.92), V(x * 0.24, 0.92, 1.18), 'Tail%s1' % t),
            ('Tail%s3' % t, V(x * 0.24, 0.92, 1.18), V(x * 0.24, 0.84, 1.5), 'Tail%s2' % t),
            ('Ear.' + s, V(x * 0.16, -0.48, 1.14), V(x * 0.27, -0.46, 1.44), 'Head'),
            ('FrontUpper.' + s, V(x * 0.17, -0.22, 0.62), V(x * 0.18, -0.26, 0.34), 'Chest'),
            ('FrontLower.' + s, V(x * 0.18, -0.26, 0.34), V(x * 0.19, -0.28, 0.1), 'FrontUpper.' + s),
            ('FrontFoot.' + s, V(x * 0.19, -0.28, 0.1), V(x * 0.19, -0.42, 0.04), 'FrontLower.' + s),
            ('BackUpper.' + s, V(x * 0.19, 0.34, 0.62), V(x * 0.2, 0.26, 0.34), 'Body'),
            ('BackLower.' + s, V(x * 0.2, 0.26, 0.34), V(x * 0.2, 0.34, 0.1), 'BackUpper.' + s),
            ('BackFoot.' + s, V(x * 0.2, 0.34, 0.1), V(x * 0.2, 0.2, 0.04), 'BackLower.' + s),
        ]
    return [(n, _slink(h, {n: 1}), _slink(t, {n: 1}), p) for n, h, t, p in b]


#@helpers
FX, FZ, FZH = 0.36, 0.98, 0.28
SHELL = (-0.6, 0.76, 1.2)
#@shell


def _flame(mb, base, d, ln, w, part, wid=0.12):
    """an onibi flame: a fat bipyramid with a curled tip."""
    bipyramid(mb, base, base + nrm(d) * ln, V(1, 0, 0), V(0, -1, 0), wid, wid * 0.8, w,
              ATLAS.uv('fire', 0.5, 0.05), ATLAS.uv('fire', 0.5, 0.95), part, wide_at=0.22, ridge_at=0.22, curl=0.14)


def _wisp(mb, base, d, ln, w, part, curl=0.25, wid=0.06):
    """a thin, long, curled wisp of ghost fire (wispy, not a block)."""
    d = nrm(d)
    side = nrm(np.cross(d, V(0, 0, 1))) if abs(d[2]) < 0.95 else V(1, 0, 0)
    bipyramid(mb, base, base + d * ln, side, nrm(np.cross(side, d)), wid, wid * 0.45, w,
              ATLAS.uv('fire', 0.5, 0.05), ATLAS.uv('fire', 0.5, 0.95), part, wide_at=0.18, ridge_at=0.18, curl=curl)


def build():
    mb = MB()
    mb.mat = 0
    W_B, W_C, W_H = {'Body': 1}, {'Chest': 1}, {'Head': 1}
    # lean feline body: narrow waist, deep chest
    st = [(V(0, 0.54, 0.74), (0.09, 0.09), {'Body': 0.6, 'Tail1': 0.2, 'TailB1': 0.2}), (V(0, 0.4, 0.72), (0.16, 0.17), W_B),
          (V(0, 0.16, 0.7), (0.13, 0.15), W_B), (V(0, -0.08, 0.72), (0.17, 0.2), {'Body': 0.5, 'Chest': 0.5}),
          (V(0, -0.26, 0.8), (0.17, 0.2), W_C), (V(0, -0.38, 0.9), (0.13, 0.14), {'Chest': 0.5, 'Head': 0.5})]
    tube(mb, 'skin', [s[0] for s in st], [s[1] for s in st], 14, [s[2] for s in st], 'body',
         start='point', end='point', start_pt=V(0, 0.62, 0.76), end_pt=V(0, -0.44, 0.94), side_hint=V(1, 0, 0),
         th0=math.pi / 2)
    n0 = len(mb.F)
    # head: wide sharp cheeks, short muzzle
    hs = [(V(0, -0.38, 0.98), (0.2, 0.2), W_H), (V(0, -0.52, 1.0), (0.3, 0.25), W_H),
          (V(0, -0.66, 0.96), (0.25, 0.21), W_H), (V(0, -0.8, 0.9), (0.13, 0.11), W_H)]
    tube(mb, 'head', [h[0] for h in hs], [h[1] for h in hs], 14, [h[2] for h in hs], 'head', start='point', end='point',
         start_pt=V(0, -0.3, 1.0), end_pt=V(0, -0.88, 0.88), side_hint=V(1, 0, 0), th0=math.pi / 2)
    head_faces = list(range(n0, len(mb.F)))
    # tall sharp ears + cheek fur spikes
    for s, x in (('L', 1), ('R', -1)):
        bipyramid(mb, V(x * 0.14, -0.48, 1.1), V(x * 0.28, -0.44, 1.46), V(0, 1, 0), V(0, -1, 0.1), 0.22, 0.07,
                  {'Ear.' + s: 1}, ATLAS.uv('ear', 0.5, 0.9), ATLAS.uv('ear', 0.5, 0.05), 'ear', wide_at=0.35, ridge_at=0.35)
        for k, (dz, ln) in enumerate(((0.06, 0.16), (-0.04, 0.13))):
            b0 = V(x * 0.26, -0.56, 0.94 + dz)
            bipyramid(mb, b0, b0 + nrm(V(x, 0.35, -0.15 + dz)) * ln, V(0, 0, 1), V(0, -1, 0), 0.07, 0.03, W_H,
                      ATLAS.uv('ruff', 0.5, 0.1), ATLAS.uv('ruff', 0.5, 0.9), 'cheek', wide_at=0.3, ridge_at=0.3)
    # blue collar, gold bell and tag
    cen = [V(0, -0.34, 0.86) + V(math.cos(2 * math.pi * i / 12) * 0.21, 0.04 * math.sin(2 * math.pi * i / 12),
                                 math.sin(2 * math.pi * i / 12) * 0.22) for i in range(13)]
    tube(mb, 'collar', cen, [(0.04, 0.035)] * 13, 5, [{'Chest': 0.5, 'Head': 0.5}] * 13, 'collar', start='open', end='open',
         side_hint=V(0, 1, 0), anti=False)
    tube(mb, 'gold', [V(0, -0.5, 0.7), V(0, -0.53, 0.66), V(0, -0.53, 0.6), V(0, -0.51, 0.56)],
         [(0.025, 0.025), (0.055, 0.055), (0.06, 0.06), (0.025, 0.025)], 8, [W_C] * 4, 'gold', start='point', end='flat',
         side_hint=V(1, 0, 0))
    # legs: long and slim, white socks on the front paws
    for s, x in (('L', 1), ('R', -1)):
        fu, fl, ff = 'FrontUpper.' + s, 'FrontLower.' + s, 'FrontFoot.' + s
        front = [(V(x * 0.15, -0.2, 0.68), (0.11, 0.12), {'Chest': 0.6, fu: 0.4}), (V(x * 0.17, -0.24, 0.44), (0.08, 0.085), {fu: 1}),
                 (V(x * 0.18, -0.26, 0.32), (0.065, 0.065), {fu: 0.5, fl: 0.5}), (V(x * 0.19, -0.28, 0.14), (0.06, 0.06), {fl: 1}),
                 (V(x * 0.19, -0.33, 0.05), (0.075, 0.05), {fl: 0.3, ff: 0.7})]
        tube(mb, 'limb', [f[0] for f in front], [f[1] for f in front], 8, [f[2] for f in front], 'front' + s,
             start='point', end='point', start_pt=V(x * 0.08, -0.18, 0.72), end_pt=V(x * 0.19, -0.42, 0.04))
        bu, bl, bf = 'BackUpper.' + s, 'BackLower.' + s, 'BackFoot.' + s
        back = [(V(x * 0.17, 0.34, 0.66), (0.14, 0.17), {'Body': 0.6, bu: 0.4}), (V(x * 0.19, 0.28, 0.44), (0.1, 0.11), {bu: 1}),
                (V(x * 0.2, 0.26, 0.32), (0.07, 0.07), {bu: 0.5, bl: 0.5}), (V(x * 0.2, 0.32, 0.16), (0.06, 0.06), {bl: 1}),
                (V(x * 0.2, 0.28, 0.05), (0.075, 0.05), {bl: 0.3, bf: 0.7})]
        tube(mb, 'limb', [f[0] for f in back], [f[1] for f in back], 8, [f[2] for f in back], 'back' + s,
             start='point', end='point', start_pt=V(x * 0.08, 0.34, 0.7), end_pt=V(x * 0.2, 0.18, 0.04))
        for foot, bone in ((V(x * 0.19, -0.39, 0.05), ff), (V(x * 0.2, 0.2, 0.05), bf)):
            for k in (-1, 0, 1):
                b0 = foot + V(k * 0.035, 0, 0)
                bipyramid(mb, b0, b0 + nrm(V(k * 0.3, -1, -0.35)) * 0.08, V(1, 0, 0), V(0, 0, 1), 0.028, 0.025, {bone: 1},
                          ATLAS.uv('claw', 0.5, 0.15), ATLAS.uv('claw', 0.5, 0.9), 'claw', wide_at=0.3, ridge_at=0.3)
        # one of the two tails: rises, sweeps out and curls, ends in onibi
        t = '' if s == 'L' else 'B'
        T1, T2, T3 = 'Tail%s1' % t, 'Tail%s2' % t, 'Tail%s3' % t
        # thin whip tail: rises, sweeps out wide, then curls its tip forward in an S
        tp = [V(x * 0.05, 0.5, 0.76), V(x * 0.12, 0.74, 0.84), V(x * 0.22, 0.92, 1.04), V(x * 0.3, 0.98, 1.28),
              V(x * 0.3, 0.9, 1.46), V(x * 0.22, 0.8, 1.54)]
        tube(mb, 'tail', tp, [(0.045, 0.045), (0.04, 0.04), (0.033, 0.033), (0.027, 0.027), (0.02, 0.02), (0.012, 0.012)], 6,
             [{'Body': 0.4, T1: 0.6}, {T1: 1}, {T1: 0.3, T2: 0.7}, {T2: 0.4, T3: 0.6}, {T3: 1}, {T3: 1}], 'tail',
             start='point', end='point', start_pt=V(x * 0.03, 0.44, 0.74), end_pt=V(x * 0.18, 0.76, 1.56))
        # long curled ghost-fire wisps streaming off the tip
        for k, (p, d, ln, cu) in enumerate(((V(x * 0.21, 0.79, 1.54), V(x * 0.05, 0.15, 1), 0.5, 0.32),
                                            (V(x * 0.23, 0.8, 1.53), V(x * 0.35, 0.3, 1), 0.4, -0.34),
                                            (V(x * 0.2, 0.77, 1.53), V(-x * 0.3, 0.25, 1), 0.38, 0.34),
                                            (V(x * 0.22, 0.8, 1.52), V(x * 0.1, 0.6, 0.9), 0.44, -0.3),
                                            (V(x * 0.25, 0.84, 1.5), V(x * 0.55, 0.45, 0.8), 0.3, 0.36),
                                            (V(x * 0.19, 0.76, 1.52), V(-x * 0.1, -0.3, 1), 0.3, -0.32),
                                            (V(x * 0.28, 0.9, 1.44), V(x * 0.5, 0.5, 0.75), 0.24, 0.3))):
            _wisp(mb, p, d, ln, {T3: 1}, 'fire', cu)
    # white fluffy chest ruff (the card's bib)
    for k in range(9):
        a = math.radians(-110 + 220 * k / 8)
        d = nrm(V(math.sin(a), 0.55, math.cos(a) * 0.55 - 0.25))
        base = V(0, -0.3, 0.86) + V(math.sin(a) * 0.17, 0, math.cos(a) * 0.12)
        bipyramid(mb, base, base + d * 0.24, V(0, 0, 1), V(0, -1, 0), 0.12, 0.05, {'Chest': 0.6, 'Head': 0.4},
                  ATLAS.uv('ruff', 0.5, 0.05), ATLAS.uv('ruff', 0.5, 0.95), 'ruff', wide_at=0.3, ridge_at=0.3, curl=0.1)
    for s, x in (('L', 1), ('R', -1)):
        _flame(mb, V(x * 0.25, -0.46, 1.32), V(x * 0.25, 0.1, 1), 0.15, {'Ear.' + s: 1}, 'fire', wid=0.07)
    mb.mat = 1
    face_shell(mb, head_faces)
    # ---- L2 "Spirit Veil": ghost-fire ruff, two floating onibi, flame tips on the ears
    mb.mat = 2
    for s, x in (('L', 1), ('R', -1)):
        _flame(mb, V(x * 0.28, -0.44, 1.42), V(x * 0.2, 0.1, 1), 0.26, {'Ear.' + s: 1}, 'L2', wid=0.11)
        for k in range(3):
            a = math.radians(-60 + 60 * k) * x
            _flame(mb, V(math.sin(a) * 0.2, -0.3, 0.9 + math.cos(a) * 0.08), V(math.sin(a), 0.4, 0.6), 0.2, {'Chest': 0.6, 'Head': 0.4}, 'L2', wid=0.08)
        _flame(mb, V(x * 0.5, 0.0, 1.22), V(0, 0, 1), 0.22, {'Orbs': 1}, 'L2', wid=0.13)
    # ---- L3 "Thousand-Year Nekomata": a ring of onibi, a ghost-flame crown, a second flame on each tail
    mb.mat = 3
    for k in range(5):
        a = 2 * math.pi * k / 5 + 0.3
        c = V(0, 0.15, 1.42) + V(math.cos(a) * 0.4, math.sin(a) * 0.32, 0.05 * math.sin(2 * a))
        _flame(mb, c, V(0, 0, 1), 0.2, {'Orbs': 1}, 'L3', wid=0.11)
    for k, (sx, ln) in enumerate(((0, 0.3), (0.07, 0.22), (-0.07, 0.22))):
        _flame(mb, V(sx, -0.48, 1.16), V(sx * 1.5, 0.05, 1), ln, W_H, 'L3', wid=0.1)
    for s, x in (('L', 1), ('R', -1)):
        T2 = 'Tail2' if s == 'L' else 'TailB2'
        _wisp(mb, V(x * 0.25, 0.95, 1.16), V(x * 0.6, 0.2, 1), 0.3, {T2: 1}, 'L3', 0.3)
        _wisp(mb, V(x * 0.2, 0.88, 1.0), V(x * 0.8, 0.3, 0.5), 0.24, {T2: 1}, 'L3', -0.28)
    # slink it: long thin legs, a lifted, lengthened and arched body, long twin tails
    for i in range(len(mb.V)):
        mb.V[i] = _slink(mb.V[i], mb.W[i])
    mb.mat = 0
    return mb


#@paint_helpers


def paint_atlas(level):
    col = np.zeros((TS, TS, 3), np.float32)
    hgt = np.full((TS, TS), 0.5, np.float32)
    rgh = np.full((TS, TS), 0.6, np.float32)
    glow = np.zeros((TS, TS), np.float32)
    gd, gm, gh = GLOW[level]
    for reg in ('skin', 'head'):
        (y0, y1, x0, x1), v, u = _reg(reg)
        h, w = y1 - y0, x1 - x0
        top = np.cos(u * 2 * math.pi)
        c = grad(np.clip(0.45 + 0.35 * top, 0, 1), FUR)
        if reg == 'skin':
            # white bib on the chest / belly with jagged flame-tooth edges
            bib = ss(-0.25, -0.5, top + 0.15 * _saw(v * 14)) * ss(0.45, 0.6, v)
            c = c * (1 - bib[..., None]) + grad(np.clip(v, 0, 1), [(0, 'b8b4c8'), (1, 'eeeaf6')]) * bib[..., None]
            # ghost-fire stripes along the flanks (glow from L2)
            side = np.abs(np.sin(u * 2 * math.pi))
            stripe = ss(0.02, 0.0, np.abs(_saw(v * 7 + 1.2 * top) - 0.5) - 0.07 - 0.03 * (1 - side)) * ss(-0.2, 0.3, side + 0.6 * top) * ss(0.15, 0.25, v) * ss(0.85, 0.75, v)
            ink = ss(0.025, 0.0, np.abs(_saw(v * 9 + 0.8 * top) - 0.5) - 0.05) * ss(-0.1, 0.5, top + 0.3) * ss(0.12, 0.2, v) * ss(0.9, 0.8, v)
            c = c * (1 - 0.85 * ink[..., None]) + hx('1c1a3a') * (0.85 * ink[..., None])     # indigo ink tabby stripes
            c = c * (1 - stripe[..., None] * 0.9) + hx(gm if level >= 2 else '1c1a3a') * (0.9 * stripe[..., None])
            glow[y0:y1, x0:x1] = stripe * (0.9 if level >= 2 else 0.0)
        st = _streaks(h, w, 170, 81)
        gr = _pgrain(h, w, 82)
        col[y0:y1, x0:x1] = c * (1 + 0.35 * st[..., None] + 0.05 * gr[..., None])
        hgt[y0:y1, x0:x1] = 0.5 + 0.45 * st + 0.1 * gr
    (y0, y1, x0, x1), v, u = _reg('limb')
    st = _streaks(y1 - y0, x1 - x0, 60, 83)
    sock = ss(0.0, 0.03, v - (0.5 + 0.08 * _saw(u * 8)))
    c = grad(np.clip(0.6 - 0.3 * v, 0, 1), FUR) * (1 + 0.3 * st[..., None])
    col[y0:y1, x0:x1] = c * (1 - sock[..., None]) + hx('1c1a3a') * sock[..., None]
    hgt[y0:y1, x0:x1] = 0.5 + 0.4 * st
    # tails: black at the root, ghost-white toward the tip, glowing cyan at the end
    (y0, y1, x0, x1), v, u = _reg('tail')
    st = _streaks(y1 - y0, x1 - x0, 50, 84)
    t = np.clip((v - 0.45 - 0.08 * _saw(u * 9)) * 2.2, 0, 1)
    ring = ss(0.03, 0.0, np.abs(_saw(v * 6) - 0.5) - 0.12) * ss(0.4, 0.3, v)
    base = grad(np.full_like(v, 0.6), FUR) * (1 - ring[..., None]) + hx('1c1a3a') * ring[..., None]
    c = base * (1 - t[..., None]) + grad(t, [(0, '1c1a3a'), (0.45, gd), (0.8, gm), (1, gh)]) * t[..., None]
    col[y0:y1, x0:x1] = c * (1 + 0.3 * st[..., None])
    hgt[y0:y1, x0:x1] = 0.5 + 0.4 * st
    glow[y0:y1, x0:x1] = ss(0.75, 1.0, t) * 0.7
    (y0, y1, x0, x1), v, u = _reg('ear')
    inner = ss(0.32, 0.42, np.cos(u * 2 * math.pi) * 0.5 + 0.5) * ss(0.95, 0.75, v)
    col[y0:y1, x0:x1] = hx('0a0710') * (1 - inner[..., None]) + grad(v, [(0, '4a2a6a'), (1, '1a1030')]) * inner[..., None]
    (y0, y1, x0, x1), v, u = _reg('claw')
    col[y0:y1, x0:x1] = hx('0a0710')
    (y0, y1, x0, x1), v, u = _reg('collar')
    rope = 0.5 + 0.5 * np.cos((u * 3 + v * 8) * 2 * math.pi)
    col[y0:y1, x0:x1] = grad(rope, [(0, '6a0a16'), (1, 'd8283c')])
    glow[y0:y1, x0:x1] = 0.0 * rope
    (y0, y1, x0, x1), v, u = _reg('gold')
    col[y0:y1, x0:x1] = grad(v, [(0, 'fff0a0'), (0.5, 'ffc23a'), (1, 'a8700a')])
    rgh[y0:y1, x0:x1] = 0.28
    (y0, y1, x0, x1), v, u = _reg('fire')
    tongues = 0.5 + 0.5 * np.cos(u * 2 * math.pi * 3 + v * 4)
    col[y0:y1, x0:x1] = grad(np.clip(v + 0.1 * tongues, 0, 1), [(0, 'ffffff'), (0.25, gh), (0.6, gm), (1, gd)])
    glow[y0:y1, x0:x1] = 1.0 - 0.35 * v
    (y0, y1, x0, x1), v, u = _reg('ruff')
    st = _streaks(y1 - y0, x1 - x0, 40, 85)
    col[y0:y1, x0:x1] = grad(v, [(0, 'eceaf6'), (0.6, gh), (1, gm)]) * (1 + 0.2 * st[..., None])
    glow[y0:y1, x0:x1] = ss(0.5, 1.0, v) * (0.8 if level >= 2 else 0.25)
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
    ix, iz, ox, oz = 0.065, 0.985, 0.21, 1.045
    ex, ez = ox - ix, oz - iz
    L = math.hypot(ex, ez)
    s = ((aX - ix) * ex + (Z - iz) * ez) / (L * L)
    d = (-(aX - ix) * ez + (Z - iz) * ex) / L
    sc = np.clip(s, 0, 1)
    top = 0.03 * np.clip(sc * 3.0, 0, 1) * (1 - sc ** 4) + 0.002
    bot = -0.022 * np.clip(np.sin(math.pi * sc), 0, 1) ** 0.9 - 0.001
    eye = ss(0.003, 0.0, np.maximum(d - top, bot - d)) * (s > 0) * (s < 1)
    cxs, czs = ix + 0.52 * ex, iz + 0.52 * ez
    rr = np.sqrt((aX - cxs) ** 2 + (Z - czs) ** 2)
    _face_layers.rr = rr
    iris = ss(0.046, 0.042, rr)
    slit = ss(0.005 * np.clip(1 - ((Z - czs) / 0.034) ** 2, 0, 1) + 0.0005, 0.0, np.abs(aX - cxs)) * ss(0.034, 0.03, rr)
    brow = np.maximum(_seg(aX, Z, (0.04, 1.03), (0.22, 1.1), 0.011, 0.005), _seg(aX, Z, (0.2, 1.095), (0.28, 1.14), 0.007, 0.001))
    lid = ss(0.006, 0.003, np.abs(d - top - 0.003)) * (s > -0.05) * (s < 1.02)
    # white muzzle and a white blaze up between the eyes (the card's tuxedo face)
    muzzle = ss(0.01, 0.0, np.sqrt((aX / 0.17) ** 2 + ((Z - 0.86) / 0.11) ** 2) - 1) * ss(0.0, 0.01, 1 - 0.0 * Z)
    blaze = ss(0.006, 0.0, aX - (0.012 + 0.07 * np.clip((1.02 - Z) / 0.16, 0, 1))) * (Z < 1.08) * (Z > 0.9)
    white = np.clip(np.maximum(muzzle, blaze), 0, 1)
    mark = _seg(aX, Z, (0.24, 0.94), (0.3, 0.88), 0.007, 0.002) * (level >= 2)
    mark = np.maximum(mark, ss(0.004, 0.0, np.abs(np.sqrt(X ** 2 + (Z - 1.13) ** 2) - 0.02) - 0.003))
    if level >= 3:
        mark = np.maximum(mark, _seg(aX, Z, (0.03, 1.12), (0.08, 1.17), 0.006, 0.002))
    _face_layers.ink = np.maximum.reduce([_seg(aX, Z, (0.22, 1.035), (0.34, 1.0), 0.014, 0.003),
                                          _seg(aX, Z, (0.2, 0.96), (0.33, 0.9), 0.012, 0.002),
                                          _seg(aX, Z, (0.06, 1.12), (0.0, 1.2), 0.012, 0.003)])
    mouth = np.maximum(_seg(X, Z, (-0.05, 0.795), (0.05, 0.795), 0.004, 0.004), _seg(X, Z, (0.0, 0.795), (0.0, 0.83), 0.003, 0.003))
    fang = ss(0.08, 0.0, np.abs(X - 0.035) / 0.009 + (0.795 - Z) / 0.026 - 1) * (Z < 0.795) * (Z > 0.765)
    nose = ss(0.004, 0.0, aX / 0.035 + np.abs(Z - 0.845) / 0.018 - 1)
    return X, Z, eye, iris, slit, brow, lid, white, mark, mouth, fang, nose


def face_texture(level, size=512):
    X, Z, eye, iris, slit, brow, lid, white, mark, mouth, fang, nose = _face_layers(level, size)
    rr = _face_layers.rr
    ed, em, eh = EYE[level]
    gd, gm, gh = GLOW[level]
    rgba = np.zeros((size, size, 4), np.float32)
    c = np.zeros((size, size, 3), np.float32) + hx('e6e2f0')
    a = white * 0.97
    # a dark violet rim round the eyes (anime liner)
    rim = ss(0.02, 0.0, np.abs(_face_layers.rr - 0.0) - 0.075) * 0.0
    ink = _face_layers.ink
    c = c * (1 - ink[..., None]) + hx('1c1a3a') * ink[..., None]
    c = c * (1 - mark[..., None]) + hx(gm) * mark[..., None]
    irisc = grad(np.clip(1 - rr / 0.042, 0, 1), [(0, ed), (0.45, em), (1, eh)])
    e = hx('06040c') * (1 - iris[..., None]) + irisc * iris[..., None]
    e = e * (1 - slit[..., None]) + hx('010104') * slit[..., None]
    c = c * (1 - eye[..., None]) + e * eye[..., None]
    ln = np.maximum.reduce([lid, brow, mouth])
    c = c * (1 - ln[..., None]) + hx('040208') * ln[..., None]
    c = c * (1 - fang[..., None]) + hx('f8f6fc') * fang[..., None]
    c = c * (1 - nose[..., None]) + hx('1a1024') * nose[..., None]
    rgba[..., :3] = c
    rgba[..., 3] = np.clip(np.maximum.reduce([a, eye, ln, mark, fang, nose, rim, _face_layers.ink]), 0, 1)
    return rgba


def face_emissive(level, size=512):
    X, Z, eye, iris, slit, brow, lid, white, mark, mouth, fang, nose = _face_layers(level, size)
    g = np.clip(np.maximum(iris * eye * (1 - slit), mark * 0.9), 0, 1)
    return np.repeat(g[..., None], 3, -1)


#@animh
#@gait


def _tails(w, amp, lift=0.0):
    """both tails: out of phase, so they weave like the card's twin flames."""
    return {'Tail1': P(('z', amp * math.sin(w)), ('x', -lift)), 'Tail2': P(('z', amp * 1.2 * math.sin(w - 0.7))),
            'Tail3': P(('z', amp * 1.4 * math.sin(w - 1.4))),
            'TailB1': P(('z', amp * math.sin(w + 2.2)), ('x', -lift)), 'TailB2': P(('z', amp * 1.2 * math.sin(w + 1.5))),
            'TailB3': P(('z', amp * 1.4 * math.sin(w + 0.8)))}


def _with_tails(anim, amp, lift):
    for f, k in anim['keys'].items():
        w = 2 * math.pi * f / anim['frames']
        for b in ('Tail1', 'Tail2', 'Tail3'):
            k.pop(b, None)
        k.update(_tails(w, amp, lift))
        k['Orbs'] = P(('z', 360 * f / anim['frames']))
    return anim


def anim_idle():
    F = 72
    keys = {}
    for f in range(0, F + 1, 3):
        t = f / F
        w = 2 * math.pi * t
        k = {'Body': P(('y', 2 * math.sin(w)), loc=(0, 0, 0.012 * math.sin(2 * w))), 'Chest': P(('x', 2 * math.sin(2 * w))),
             'Head': P(('z', 16 * math.sin(w * 0.5)), ('x', -4 * _pulse(t, 0.4, 0.6))),
             'Ear.L': P(('y', -20 * _pulse(t, 0.55, 0.6))), 'Ear.R': P(('y', 20 * _pulse(t, 0.72, 0.77))),
             'Orbs': P(('z', 360 * t), loc=(0, 0, 0.05 * math.sin(w)))}
        k.update(_tails(w, 16, -4))
        keys[f] = k
    keys[F] = dict(keys[0])
    keys[F]['Orbs'] = P(('z', 0), loc=(0, 0, 0))
    return {'frames': F, 'loop': True, 'keys': keys}


def anim_walk():
    return _with_tails(_gait(24, 26, 34, 0.025, 0, 10), 10, -6)


def anim_run():
    return _with_tails(_gait(14, 44, 54, 0.07, 6, 8), 8, -14)


def anim_hop():
    keys = {}
    for f in range(0, 17, 2):
        t = f / 16
        upv = math.sin(math.pi * t)
        p = {'Body': P(('x', -10 * upv), loc=(0, 0, 0.4 * upv))}
        for s in 'LR':
            p['BackUpper.' + s] = P(('x', 30 * upv))
            p['FrontUpper.' + s] = P(('x', -30 * upv))
        p.update(_tails(math.pi * t, 10, 10 * upv))
        keys[f] = p
    return {'frames': 16, 'loop': False, 'keys': keys}


def anim_ability():
    """Vanish (~1 s, Runner): crouches low, whips both flaming tails forward over its back like a veil (it turns
    invisible at ~0.5), then springs up out of the flames and lands."""
    keys = {}
    F = 24
    for f in range(0, F + 1, 2):
        t = f / F
        crouch = _ease(t / 0.3) * (1 - _ease((t - 0.45) / 0.1))
        veil = _ease((t - 0.2) / 0.25) * (1 - _ease((t - 0.6) / 0.25))
        spring = math.sin(math.pi * min(1, max(0, (t - 0.5) / 0.4)))
        k = {'Body': P(('x', 6 * crouch - 10 * spring), loc=(0, 0, -0.1 * crouch + 0.3 * spring)),
             'Head': P(('x', 16 * crouch - 12 * spring)), 'Orbs': P(('z', 720 * t)),
             'Ear.L': P(('x', 30 * crouch)), 'Ear.R': P(('x', 30 * crouch)),
             'Tail1': P(('x', -70 * veil), ('z', 20 * veil)), 'Tail2': P(('x', -40 * veil)), 'Tail3': P(('x', -30 * veil)),
             'TailB1': P(('x', -70 * veil), ('z', -20 * veil)), 'TailB2': P(('x', -40 * veil)), 'TailB3': P(('x', -30 * veil))}
        for s in 'LR':
            k['FrontUpper.' + s] = P(('x', 25 * crouch - 30 * spring))
            k['FrontLower.' + s] = P(('x', -30 * crouch))
            k['BackUpper.' + s] = P(('x', -25 * crouch + 25 * spring))
            k['BackLower.' + s] = P(('x', 30 * crouch))
        keys[f] = k
    return {'frames': F, 'loop': False, 'keys': keys}


def anim_stalk():
    """Stalk (~0.8 s, Catcher, the Tether cast): sinks into a hunting crouch, tails low and twitching, then lunges a
    forepaw out (the tether flies at ~0.45) and draws back."""
    keys = {}
    F = 20
    for f in range(0, F + 1, 1):
        t = f / F
        sink = _ease(t / 0.35) * (1 - _ease((t - 0.7) / 0.3))
        lunge = _pulse(t, 0.35, 0.75)
        k = {'Body': P(('x', 4 * sink - 6 * lunge), loc=(0, -0.15 * lunge, -0.12 * sink)),
             'Head': P(('x', 10 * sink - 6 * lunge)), 'Ear.L': P(('x', 35 * sink)), 'Ear.R': P(('x', 35 * sink)),
             'FrontUpper.L': P(('x', 20 * sink - 75 * lunge)), 'FrontLower.L': P(('x', -20 * sink + 25 * lunge)),
             'FrontUpper.R': P(('x', 20 * sink)), 'FrontLower.R': P(('x', -20 * sink)),
             'BackUpper.L': P(('x', -20 * sink)), 'BackUpper.R': P(('x', -20 * sink)),
             'BackLower.L': P(('x', 25 * sink)), 'BackLower.R': P(('x', 25 * sink))}
        k.update(_tails(2 * math.pi * t * 2, 6 + 10 * lunge, 25 * sink))
        keys[f] = k
    return {'frames': F, 'loop': False, 'keys': keys}


ANIMS = {'Idle': anim_idle, 'Walk': anim_walk, 'Run': anim_run, 'Hop': anim_hop, 'Ability': anim_ability,
         'Stalk': anim_stalk}
