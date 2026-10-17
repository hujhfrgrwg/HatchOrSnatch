# Scroll Tanuki (Decoy, Epic) for Hatch or Snatch: HOS-PET-022, built on the pet kit. Assembled by assemble_pet.py.
# From the concept-library card (docs/pets/scroll_tanuki/scroll_tanuki_card.png): a brown tanuki with a dark eye mask,
# a ringed bushy tail, teal scrolls strapped across its back, a teal scarf and a leaf on its head.
# Read through PET_LESSONS (anime / edgy): deep umber fur with fur strokes, a near-black bandit mask, narrow slanted
# amber slit eyes, a sly one-sided smirk with a fang (face decal shell), tattered scarf, glowing orange kanji on the
# scrolls. L2 "Trickster": a straw kasa hat, a third scroll and hanging ofuda tags. L3 "Shapeshift Master": a ring of
# floating leaves, spirit flames on the scroll ends, a gold bell, red-orange glow.
# Reshaped 17 Oct (HOS-PET-RESHAPE): its own body plan, standing upright on its hind legs like a tanuki statue, a
# squat pear body with a huge round belly, stubby legs, short arms resting on the belly; it drums its belly in idle
# and waddles upright.
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

NAME = 'Tanuki'
SHARP_ANGLE = 40
NORMAL_STRENGTH = 2.0
TS = 1024
ATLAS = Atlas({
    'skin': (0, 0, 1024, 384),
    'head': (0, 384, 512, 256),
    'limb': (512, 384, 512, 128),
    'tail': (512, 512, 512, 128),   # v root -> tip, ringed
    'scroll': (0, 640, 512, 128),   # u around, v end -> end
    'ear': (512, 640, 128, 128),
    'claw': (640, 640, 128, 128),
    'leaf': (768, 640, 256, 128),
    'scarf': (0, 768, 256, 128),
    'straw': (256, 768, 256, 128),
    'fire': (512, 768, 256, 128),
    'gold': (768, 768, 256, 128),
    'paper': (0, 896, 256, 128),
})

GLOW = {1: ('a04a00', 'ff8a1a', 'ffe2b0'), 2: ('a04a00', 'ffa02a', 'fff0c8'), 3: ('a01a10', 'ff4a2a', 'ffd8c0')}
EYE = {1: ('a05a00', 'ffb02a', 'fff0c0'), 2: ('a05a00', 'ffc040', 'fff6d8'), 3: ('a01a10', 'ff5a3a', 'ffe0d8')}
FUR = [(0, '24140a'), (0.5, '7a4a26'), (1, 'c08a56')]   # redo 17 Oct: a step lighter


def bones_def():
    b = [
        ('Root', V(0, 0, 0), V(0, 0, 0.2), None),
        ('Body', V(0, 0.04, 0.32), V(0, 0.0, 0.7), 'Root'),
        ('Chest', V(0, 0.0, 0.7), V(0, 0.0, 0.98), 'Body'),
        ('Head', V(0, 0.02, 1.1), V(0, -0.5, 1.08), 'Chest'),
        ('Tail1', V(0, 0.3, 0.3), V(0, 0.62, 0.22), 'Body'),
        ('Tail2', V(0, 0.62, 0.22), V(0, 0.88, 0.38), 'Tail1'),
        ('Tail3', V(0, 0.88, 0.38), V(0, 0.96, 0.7), 'Tail2'),
        ('Leaves', V(0, 0.0, 1.82), V(0, 0.0, 2.02), 'Body'),
    ]
    for s, x in (('L', 1), ('R', -1)):
        b += [
            ('Ear.' + s, V(x * 0.2, -0.06, 1.32), V(x * 0.28, -0.02, 1.5), 'Head'),
            ('FrontUpper.' + s, V(x * 0.28, -0.02, 0.88), V(x * 0.38, -0.14, 0.6), 'Chest'),
            ('FrontLower.' + s, V(x * 0.38, -0.14, 0.6), V(x * 0.27, -0.33, 0.5), 'FrontUpper.' + s),
            ('FrontFoot.' + s, V(x * 0.27, -0.33, 0.5), V(x * 0.23, -0.4, 0.48), 'FrontLower.' + s),
            ('BackUpper.' + s, V(x * 0.2, 0.06, 0.34), V(x * 0.22, -0.01, 0.12), 'Body'),
            ('BackLower.' + s, V(x * 0.22, -0.01, 0.12), V(x * 0.22, -0.04, 0.05), 'BackUpper.' + s),
            ('BackFoot.' + s, V(x * 0.22, -0.04, 0.05), V(x * 0.22, -0.2, 0.03), 'BackLower.' + s),
        ]
    return b


#@helpers
FX, FZ, FZH = 0.38, 1.1, 0.3
SHELL = (-0.18, 0.86, 1.38)
DFX, DFZ, DFZH = 0.38, 0.92, 0.3    # the face decal is drawn in these units, then mapped onto FX / FZ / FZH
#@shell


def build():
    mb = MB()
    mb.mat = 0
    W_B, W_C, W_H = {'Body': 1}, {'Chest': 1}, {'Head': 1}
    # stands upright like a tanuki statue: a squat pear body with a huge round belly, stubby legs, short arms on the belly
    st = [(V(0, 0.04, 0.24), (0.3, 0.28), W_B), (V(0, -0.04, 0.42), (0.44, 0.43), W_B),
          (V(0, -0.03, 0.6), (0.42, 0.4), {'Body': 0.5, 'Chest': 0.5}), (V(0, 0.0, 0.8), (0.32, 0.3), W_C),
          (V(0, 0.02, 0.96), (0.22, 0.21), {'Chest': 0.6, 'Head': 0.4})]
    tube(mb, 'skin', [s[0] for s in st], [s[1] for s in st], 14, [s[2] for s in st], 'body',
         start='point', end='point', start_pt=V(0, 0.04, 0.14), end_pt=V(0, 0.02, 1.04), side_hint=V(1, 0, 0),
         th0=math.pi / 2)
    n0 = len(mb.F)
    hs = [(V(0, 0.08, 1.14), (0.24, 0.23), W_H), (V(0, -0.08, 1.16), (0.33, 0.3), W_H),
          (V(0, -0.26, 1.11), (0.28, 0.24), W_H), (V(0, -0.42, 1.04), (0.14, 0.12), W_H)]
    tube(mb, 'head', [h[0] for h in hs], [h[1] for h in hs], 12, [h[2] for h in hs], 'head', start='point', end='point',
         start_pt=V(0, 0.16, 1.15), end_pt=V(0, -0.52, 1.02), side_hint=V(1, 0, 0), th0=math.pi / 2)
    head_faces = list(range(n0, len(mb.F)))
    # round-tipped ears with dark backs
    for s, x in (('L', 1), ('R', -1)):
        bipyramid(mb, V(x * 0.18, -0.04, 1.28), V(x * 0.3, 0.02, 1.54), V(0, 1, 0), V(0, -1, 0.1), 0.2, 0.08,
                  {'Ear.' + s: 1}, ATLAS.uv('ear', 0.5, 0.9), ATLAS.uv('ear', 0.5, 0.1), 'ear', wide_at=0.45, ridge_at=0.45)
    # a leaf on the head
    bipyramid(mb, V(0.04, 0.0, 1.34), V(0.2, 0.08, 1.64), V(1, 0, 0), V(0, -1, 0.3), 0.2, 0.03, W_H,
              ATLAS.uv('leaf', 0.5, 0.05), ATLAS.uv('leaf', 0.5, 0.95), 'leaf', wide_at=0.45, ridge_at=0.45)
    # tattered teal scarf round the neck, two tails hanging over the belly
    cen = [V(0, 0.0, 0.98) + V(math.cos(2 * math.pi * i / 12) * 0.27, math.sin(2 * math.pi * i / 12) * 0.26, 0) for i in range(13)]
    tube(mb, 'scarf', cen, [(0.06, 0.05)] * 13, 5, [{'Chest': 0.5, 'Head': 0.5}] * 13, 'scarf', start='open', end='open',
         side_hint=V(0, 0, 1), anti=False)
    for x, tip in ((1, V(0.26, -0.34, 0.64)), (-1, V(-0.1, -0.4, 0.68))):
        bipyramid(mb, V(x * 0.12, -0.22, 0.94), tip, V(1, 0, 0), V(0, -1, 0), 0.13, 0.03, W_C,
                  ATLAS.uv('scarf', 0.5, 0.1), ATLAS.uv('scarf', 0.5, 0.9), 'scarf', wide_at=0.4, ridge_at=0.4)
    # two scrolls strapped across the back on a slanting sash
    for (y, z, r) in ((0.36, 0.82, 0.11), (0.4, 0.58, 0.1)):
        tube(mb, 'scroll', [V(-0.42, y, z), V(-0.36, y, z), V(0.36, y, z), V(0.42, y, z)], [(r * 0.8, r * 0.8), (r, r), (r, r), (r * 0.8, r * 0.8)],
             8, [W_B if z < 0.7 else W_C] * 4, 'scroll', start='flat', end='flat', side_hint=V(0, 0, 1), anti=False)
    cen = [V(0, -0.02, 0.66) + V(math.cos(2 * math.pi * i / 12) * 0.44, math.sin(2 * math.pi * i / 12) * 0.43,
                                 0.16 * math.cos(2 * math.pi * i / 12)) for i in range(13)]
    tube(mb, 'scarf', cen, [(0.03, 0.025)] * 13, 4, [W_B] * 13, 'strap', start='open', end='open', side_hint=V(0, 0, 1), anti=False)
    for s, x in (('L', 1), ('R', -1)):
        # short arms resting on the belly
        fu, fl, ff = 'FrontUpper.' + s, 'FrontLower.' + s, 'FrontFoot.' + s
        arm = [(V(x * 0.28, -0.02, 0.88), (0.11, 0.12), {'Chest': 0.6, fu: 0.4}), (V(x * 0.36, -0.08, 0.72), (0.09, 0.09), {fu: 1}),
               (V(x * 0.38, -0.14, 0.6), (0.08, 0.08), {fu: 0.5, fl: 0.5}), (V(x * 0.32, -0.26, 0.52), (0.075, 0.075), {fl: 1}),
               (V(x * 0.26, -0.34, 0.5), (0.08, 0.06), {fl: 0.3, ff: 0.7})]
        tube(mb, 'limb', [f[0] for f in arm], [f[1] for f in arm], 8, [f[2] for f in arm], 'front' + s,
             start='point', end='point', start_pt=V(x * 0.18, 0.0, 0.92), end_pt=V(x * 0.22, -0.4, 0.48))
        # stubby legs, flat feet
        bu, bl, bf = 'BackUpper.' + s, 'BackLower.' + s, 'BackFoot.' + s
        leg = [(V(x * 0.2, 0.06, 0.34), (0.16, 0.17), {'Body': 0.6, bu: 0.4}), (V(x * 0.22, 0.0, 0.2), (0.13, 0.13), {bu: 1}),
               (V(x * 0.22, -0.01, 0.12), (0.11, 0.11), {bu: 0.5, bl: 0.5}), (V(x * 0.22, -0.02, 0.06), (0.11, 0.07), {bl: 1}),
               (V(x * 0.22, -0.12, 0.04), (0.12, 0.05), {bf: 1})]
        tube(mb, 'limb', [f[0] for f in leg], [f[1] for f in leg], 8, [f[2] for f in leg], 'back' + s,
             start='point', end='point', start_pt=V(x * 0.1, 0.06, 0.36), end_pt=V(x * 0.22, -0.22, 0.03))
        for foot, bone, dirv in ((V(x * 0.24, -0.36, 0.5), ff, V(0, -1, -0.6)), (V(x * 0.22, -0.18, 0.04), bf, V(0, -1, -0.3))):
            for k in (-1, 0, 1):
                b0 = foot + V(k * 0.045, 0, 0)
                bipyramid(mb, b0, b0 + nrm(dirv + V(k * 0.3, 0, 0)) * 0.08, V(1, 0, 0), V(0, 0, 1), 0.035, 0.03, {bone: 1},
                          ATLAS.uv('claw', 0.5, 0.15), ATLAS.uv('claw', 0.5, 0.9), 'claw', wide_at=0.3, ridge_at=0.3)
    # big ringed bushy tail resting on the ground behind, curling up
    tp = [V(0, 0.3, 0.3), V(0, 0.56, 0.22), V(0, 0.8, 0.3), V(0, 0.94, 0.52), V(0, 0.96, 0.74)]
    tube(mb, 'tail', tp, [(0.12, 0.12), (0.22, 0.22), (0.25, 0.25), (0.2, 0.2), (0.1, 0.1)], 10,
         [{'Body': 0.4, 'Tail1': 0.6}, {'Tail1': 1}, {'Tail2': 1}, {'Tail3': 1}, {'Tail3': 1}], 'tail',
         start='point', end='point', start_pt=V(0, 0.24, 0.32), end_pt=V(0, 0.95, 0.82))
    mb.mat = 1
    face_shell(mb, head_faces)
    # ---- L2 "Trickster": a straw kasa hat, a third scroll, hanging ofuda tags
    mb.mat = 2
    hc = V(0, -0.06, 1.38)
    tube(mb, 'straw', [hc + V(0, 0, 0.0), hc + V(0, 0, 0.06), hc + V(0, 0.0, 0.2)], [(0.5, 0.5), (0.36, 0.36), (0.04, 0.04)], 12,
         [W_H] * 3, 'L2', start='flat', end='point', end_pt=hc + V(0, 0, 0.26), side_hint=V(1, 0, 0), anti=False)
    tube(mb, 'scroll', [V(-0.34, 0.3, 1.0), V(-0.3, 0.3, 1.0), V(0.3, 0.3, 1.0), V(0.34, 0.3, 1.0)],
         [(0.07, 0.07), (0.085, 0.085), (0.085, 0.085), (0.07, 0.07)], 8, [W_C] * 4, 'L2', start='flat', end='flat',
         side_hint=V(0, 0, 1), anti=False)
    for x in (1, -1):
        p = V(x * 0.45, 0.0, 0.74)
        bipyramid(mb, p, p + V(x * 0.03, 0.02, -0.26), V(0, 1, 0), V(x, 0, 0), 0.1, 0.012, W_B,
                  ATLAS.uv('paper', 0.5, 0.05), ATLAS.uv('paper', 0.5, 0.95), 'L2', wide_at=0.5, ridge_at=0.5)
    # ---- L3 "Shapeshift Master": floating leaf ring, spirit flames on the scroll ends, a gold bell
    mb.mat = 3
    for k in range(5):
        a = 2 * math.pi * k / 5
        c = V(0, 0.0, 1.86) + V(math.cos(a) * 0.36, math.sin(a) * 0.36, 0.06 * math.sin(2 * a))
        d = V(-math.sin(a), math.cos(a), 0.2)
        bipyramid(mb, c - d * 0.1, c + d * 0.12, V(0, 0, 1), V(math.cos(a), math.sin(a), 0), 0.12, 0.02, {'Leaves': 1},
                  ATLAS.uv('leaf', 0.5, 0.05), ATLAS.uv('leaf', 0.5, 0.95), 'L3', wide_at=0.45, ridge_at=0.45)
    for x in (1, -1):
        for (y, z) in ((0.36, 0.82), (0.4, 0.58)):
            p = V(x * 0.42, y, z)
            bipyramid(mb, p - V(0, 0, 0.04), p + V(x * 0.06, 0.02, 0.28), V(1, 0, 0), V(0, 1, 0), 0.12, 0.1, W_B if z < 0.7 else W_C,
                      ATLAS.uv('fire', 0.5, 0.05), ATLAS.uv('fire', 0.5, 0.95), 'L3', wide_at=0.3, ridge_at=0.3)
    tube(mb, 'gold', [V(0, -0.28, 0.96), V(0, -0.31, 0.9), V(0, -0.31, 0.82), V(0, -0.29, 0.78)],
         [(0.03, 0.03), (0.07, 0.07), (0.08, 0.08), (0.03, 0.03)], 8, [W_C] * 4, 'L3', start='point', end='flat',
         side_hint=V(1, 0, 0))
    mb.mat = 0
    return mb


#@paint_helpers


def paint_atlas(level):
    col = np.zeros((TS, TS, 3), np.float32)
    hgt = np.full((TS, TS), 0.5, np.float32)
    rgh = np.full((TS, TS), 0.6, np.float32)
    glow = np.zeros((TS, TS), np.float32)
    gd, gm, gh = GLOW[level]
    fur = FUR if level < 3 else [(0, '1a0c08'), (0.5, '6a321e'), (1, 'b06a44')]
    for reg in ('skin', 'head'):
        (y0, y1, x0, x1), v, u = _reg(reg)
        h, w = y1 - y0, x1 - x0
        top = np.cos(u * 2 * math.pi)
        c = grad(np.clip(0.55 + 0.35 * top, 0, 1), fur)
        belly = ss(-0.05, -0.35, top + 0.12 * _saw(v * 16))
        c = c * (1 - 0.92 * belly[..., None]) + grad(np.clip(v, 0, 1), [(0, 'dcc296'), (1, 'f8ecd0')]) * (0.92 * belly[..., None])
        back = ss(0.45, 0.65, top + 0.12 * _saw(v * 18 + u * 3))
        c = c * (1 - 0.5 * back[..., None])
        st = _streaks(h, w, 170, 61)
        gr = _pgrain(h, w, 62)
        col[y0:y1, x0:x1] = c * (1 + 0.3 * st[..., None] + 0.05 * gr[..., None])
        hgt[y0:y1, x0:x1] = 0.5 + 0.45 * st + 0.1 * gr
    (y0, y1, x0, x1), v, u = _reg('limb')
    st = _streaks(y1 - y0, x1 - x0, 60, 63)
    sock = ss(0.0, 0.03, v - (0.35 + 0.08 * _saw(u * 8)))
    c = grad(np.clip(0.7 - 0.3 * v, 0, 1), fur) * (1 + 0.25 * st[..., None])
    col[y0:y1, x0:x1] = c * (1 - sock[..., None]) + hx('120a06') * sock[..., None]
    hgt[y0:y1, x0:x1] = 0.5 + 0.4 * st
    (y0, y1, x0, x1), v, u = _reg('tail')
    st = _streaks(y1 - y0, x1 - x0, 50, 64)
    rings = ss(0.02, -0.02, np.cos(v * 2 * math.pi * 3.5 + 0.3 * _saw(u * 8)))
    c = grad(np.full_like(v, 0.75), fur) * (1 - 0.8 * rings[..., None]) + hx('120a06') * (0.8 * rings[..., None])
    col[y0:y1, x0:x1] = c * (1 + 0.3 * st[..., None])
    hgt[y0:y1, x0:x1] = 0.5 + 0.4 * st
    (y0, y1, x0, x1), v, u = _reg('ear')
    inner = ss(0.3, 0.38, np.cos(u * 2 * math.pi) * 0.5 + 0.5)
    col[y0:y1, x0:x1] = hx('120a06') * (1 - inner[..., None]) + hx('3a2214') * inner[..., None]
    (y0, y1, x0, x1), v, u = _reg('claw')
    col[y0:y1, x0:x1] = hx('0a0604')
    (y0, y1, x0, x1), v, u = _reg('leaf')
    vein = ss(0.03, 0.0, np.abs(u - 0.5) - 0.01)
    c = grad(v, [(0, '1a5a2a'), (1, '4aa04a')]) if level < 3 else grad(v, [(0, '8a2a0a'), (1, 'ff8a2a')])
    col[y0:y1, x0:x1] = c * (1 - 0.4 * vein[..., None])
    glow[y0:y1, x0:x1] = 0.4 * (level == 3)
    (y0, y1, x0, x1), v, u = _reg('scarf')
    tat = ss(0.0, 0.04, v - (0.8 + 0.12 * _saw(u * 7)))
    c = grad(v, [(0, '0a6a6a'), (1, '063c44')]) * (0.85 + 0.2 * np.cos(u * 2 * math.pi * 3)[..., None])
    col[y0:y1, x0:x1] = c * (1 - tat[..., None]) + hx('041c20') * tat[..., None]
    # scrolls: teal paper body with glowing orange kanji strokes, dark wooden rollers at the ends
    (y0, y1, x0, x1), v, u = _reg('scroll')
    ends = np.maximum(ss(0.12, 0.08, v), ss(0.88, 0.92, v))
    kan = ((_saw(u * 6) > 0.75) & (_saw(v * 9) > 0.35)) | ((_saw(v * 9 + 0.5) > 0.85) & (_saw(u * 6 + 0.5) > 0.4))
    kan = kan * ss(0.15, 0.2, v) * ss(0.85, 0.8, v)
    c = grad(u, [(0, '22c4b4'), (0.5, '7af4e4'), (1, '22c4b4')])          # redo: bright teal, not muddy
    band = np.maximum(ss(0.02, 0.0, np.abs(v - 0.16) - 0.015), ss(0.02, 0.0, np.abs(v - 0.84) - 0.015))
    c = c * (1 - band[..., None]) + hx('ffcc40') * band[..., None]
    c = c * (1 - kan[..., None]) + hx(gm) * kan[..., None]
    col[y0:y1, x0:x1] = c * (1 - ends[..., None]) + grad(u, [(0, 'a87010'), (0.5, 'ffd860'), (1, 'a87010')]) * ends[..., None]
    rgh[y0:y1, x0:x1] = 0.35
    glow[y0:y1, x0:x1] = kan * (0.8 + 0.2 * (level >= 2))
    (y0, y1, x0, x1), v, u = _reg('straw')
    weave = 0.5 + 0.5 * np.cos(v * 2 * math.pi * 14) * np.cos(u * 2 * math.pi * 20)
    col[y0:y1, x0:x1] = grad(v, [(0, 'c8a050'), (1, '7a5a24')]) * (0.85 + 0.2 * weave[..., None])
    (y0, y1, x0, x1), v, u = _reg('paper')
    sig = (_saw(v * 6) > 0.7) * ss(0.4, 0.3, np.abs(u - 0.5))
    col[y0:y1, x0:x1] = hx('f0e6c8') * (1 - sig[..., None]) + hx('c81a1a') * sig[..., None]
    (y0, y1, x0, x1), v, u = _reg('fire')
    col[y0:y1, x0:x1] = grad(v, [(0, gh), (0.4, gm), (1, gd)])
    glow[y0:y1, x0:x1] = 1.0 - 0.5 * v
    (y0, y1, x0, x1), v, u = _reg('gold')
    col[y0:y1, x0:x1] = grad(v, [(0, 'fff0a0'), (0.5, 'ffc23a'), (1, 'a8700a')])
    rgh[y0:y1, x0:x1] = 0.28
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
    ix, iz, ox, oz = 0.07, 0.96, 0.22, 1.02
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
    brow = np.maximum(_seg(aX, Z, (0.04, 1.0), (0.24, 1.08), 0.012, 0.005), _seg(aX, Z, (0.22, 1.07), (0.3, 1.12), 0.008, 0.001))
    lid = ss(0.006, 0.003, np.abs(d - top - 0.003)) * (s > -0.05) * (s < 1.02)
    # the tanuki bandit mask: a wide dark band through the eyes, drooping down the cheeks
    zc = 0.97 - 0.12 * np.clip(aX - 0.12, 0, None)
    hh = 0.07 + 0.04 * np.clip(aX - 0.1, 0, 0.2) / 0.2
    mask = ss(0.006, 0.0, np.abs(Z - zc) - hh) * (aX > 0.02) * (aX < 0.36)
    mark = _seg(aX, Z, (0.0, 1.14), (0.0, 1.2), 0.012, 0.004) * (level >= 2)
    if level >= 3:
        mark = np.maximum(mark, _seg(aX, Z, (0.26, 0.88), (0.31, 0.82), 0.008, 0.002))
    smirk = np.maximum(_seg(X, Z, (-0.06, 0.78), (0.05, 0.775), 0.004, 0.004), _seg(X, Z, (0.05, 0.775), (0.09, 0.795), 0.004, 0.002))
    fang = ss(0.08, 0.0, np.abs(X - 0.065) / 0.011 + (0.775 - Z) / 0.03 - 1) * (Z < 0.775) * (Z > 0.74)
    nose = ss(0.004, 0.0, aX / 0.04 + np.abs(Z - 0.83) / 0.022 - 1)
    return X, Z, eye, iris, slit, brow, lid, mask, mark, smirk, fang, nose


def face_texture(level, size=512):
    X, Z, eye, iris, slit, brow, lid, mask, mark, smirk, fang, nose = _face_layers(level, size)
    rr = _face_layers.rr
    ed, em, eh = EYE[level]
    gd, gm, gh = GLOW[level]
    rgba = np.zeros((size, size, 4), np.float32)
    c = np.zeros((size, size, 3), np.float32) + hx('0e0806')
    # cream muzzle and pale brow patches (redo: a lighter face), the dark mask over them
    cream = ss(0.01, 0.0, np.sqrt((X / 0.19) ** 2 + ((Z - 0.8) / 0.11) ** 2) - 1)
    c = c * (1 - cream[..., None]) + hx('f2e4c4') * cream[..., None]
    c = c * (1 - mask[..., None]) + hx('0e0806') * mask[..., None]
    _face_layers.cream = cream
    c = c * (1 - mark[..., None]) + hx(gm) * mark[..., None]
    irisc = grad(np.clip(1 - rr / 0.044, 0, 1), [(0, ed), (0.45, em), (1, eh)])
    e = hx('0a0806') * (1 - iris[..., None]) + irisc * iris[..., None]
    e = e * (1 - slit[..., None]) + hx('020100') * slit[..., None]
    c = c * (1 - eye[..., None]) + e * eye[..., None]
    ln = np.maximum.reduce([lid, brow, smirk])
    c = c * (1 - ln[..., None]) + hx('050302') * ln[..., None]
    c = c * (1 - fang[..., None]) + hx('f4efe6') * fang[..., None]
    c = c * (1 - nose[..., None]) + hx('080504') * nose[..., None]
    rgba[..., :3] = c
    rgba[..., 3] = np.clip(np.maximum.reduce([mask * 0.95, _face_layers.cream * 0.97, eye, ln, mark, fang, nose]), 0, 1)
    return rgba


def face_emissive(level, size=512):
    X, Z, eye, iris, slit, brow, lid, mask, mark, smirk, fang, nose = _face_layers(level, size)
    g = np.clip(np.maximum(iris * eye * (1 - slit), mark * 0.9), 0, 1)
    return np.repeat(g[..., None], 3, -1)


#@animh
#@gait


def anim_idle():
    """Stands on its hind legs drumming its belly (the tanuki's belly drum): alternate paw pats, a smug head tilt, the
    tail swishing on the ground, the leaf ring turning."""
    F = 72
    keys = {}
    for f in range(0, F + 1, 3):
        t = f / F
        w = 2 * math.pi * t
        patL = _pulse((t * 4) % 1, 0.0, 0.3)
        patR = _pulse((t * 4 + 0.5) % 1, 0.0, 0.3)
        drum = _pulse(t, 0.1, 0.6)
        k = {'Body': P(('z', 3 * math.sin(w)), loc=(0, 0, 0.015 * math.sin(4 * w))), 'Chest': P(('x', 2 * math.sin(2 * w))),
             'Head': P(('z', 12 * math.sin(w * 0.5)), ('y', 8 * math.sin(w))),
             'FrontUpper.L': P(('x', -25 * patL * drum)), 'FrontLower.L': P(('x', -20 * patL * drum)),
             'FrontUpper.R': P(('x', -25 * patR * drum)), 'FrontLower.R': P(('x', -20 * patR * drum)),
             'Ear.L': P(('x', -18 * _pulse(t, 0.65, 0.72))), 'Ear.R': P(('x', -18 * _pulse(t, 0.8, 0.87))),
             'Leaves': P(('z', 360 * t), loc=(0, 0, 0.04 * math.sin(w)))}
        k.update(_tail(w, 14, 0))
        keys[f] = k
    keys[F] = dict(keys[0])
    keys[F]['Leaves'] = P(('z', 0), loc=(0, 0, 0))
    return {'frames': F, 'loop': True, 'keys': keys}


def _waddle(frames, swing, sway, bounce, lean, arms):
    """Upright waddle on stubby legs: the body rocks side to side over each step, arms swing against the legs."""
    keys = {}
    for f in range(0, frames + 1, 2):
        t = f / frames
        w = 2 * math.pi * t
        p = {'Body': P(('x', lean), ('z', sway * math.sin(w)), loc=(0, 0, bounce * abs(math.sin(w)))),
             'Head': P(('z', -sway * 0.6 * math.sin(w)))}
        for s, off in (('L', 0.0), ('R', math.pi)):
            sw = math.sin(w + off) * swing
            p['BackUpper.' + s] = P(('x', -sw))
            p['BackLower.' + s] = P(('x', max(0.0, math.cos(w + off)) * swing * 0.8))
            p['FrontUpper.' + s] = P(('x', sw * arms))
        p.update(_tail(w, 10, 0))
        keys[f] = p
    keys[frames] = dict(keys[0])
    return {'frames': frames, 'loop': True, 'keys': keys}


def anim_walk():
    return _waddle(22, 28, 7, 0.03, 4, 0.8)


def anim_run():
    return _waddle(12, 44, 10, 0.08, 12, 1.2)


def anim_hop():
    keys = {}
    for f in range(0, 17, 2):
        t = f / 16
        upv = math.sin(math.pi * t)
        p = {'Body': P(loc=(0, 0, 0.32 * upv))}
        for s in 'LR':
            p['BackUpper.' + s] = P(('x', -40 * upv))
            p['BackLower.' + s] = P(('x', 60 * upv))
            p['FrontUpper.' + s] = P(('x', -50 * upv))
        keys[f] = p
    return {'frames': 16, 'loop': False, 'keys': keys}


def anim_ability():
    """Fake Clone (~1 s): throws both paws up to slap the leaf on its head, spins a full turn in a puff (the copy splits
    off at ~0.5), lands with a sly crouch."""
    keys = {}
    F = 24
    for f in range(0, F + 1, 2):
        t = f / F
        up = _ease(t / 0.3) * (1 - _ease((t - 0.7) / 0.3))
        spin = _ease((t - 0.25) / 0.45)
        k = {'Root': P(('z', 360 * spin)), 'Body': P(loc=(0, 0, 0.2 * math.sin(math.pi * min(1, max(0, (t - 0.25) / 0.45))))),
             'Head': P(('x', -10 * up)), 'Leaves': P(('z', 720 * t))}
        for s, x in (('L', 1), ('R', -1)):
            k['FrontUpper.' + s] = P(('x', -130 * up), ('y', -x * 10 * up))
            k['FrontLower.' + s] = P(('x', -30 * up))
            k['BackUpper.' + s] = P(('x', -20 * up))
            k['BackLower.' + s] = P(('x', 30 * up))
        k.update(_tail(6 * t, 20, 0))
        keys[f] = k
    return {'frames': F, 'loop': False, 'keys': keys}


def anim_snare():
    """Snare (~0.9 s, Catcher): leans back winding up a paw, then lunges forward slamming it down (the snare seal
    lands at ~0.45), and holds a sly crouch."""
    keys = {}
    F = 22
    for f in range(0, F + 1, 1):
        t = f / F
        rear = _ease(t / 0.35) * (1 - _ease((t - 0.35) / 0.1))
        slam = _ease((t - 0.35) / 0.1) * (1 - _ease((t - 0.75) / 0.25))
        k = {'Body': P(('x', -12 * rear + 22 * slam), loc=(0, 0, -0.04 * slam)),
             'Head': P(('x', 10 * rear - 14 * slam)),
             'FrontUpper.L': P(('x', -140 * rear - 40 * slam)), 'FrontLower.L': P(('x', -20 * rear)),
             'FrontUpper.R': P(('x', -20 * rear)), 'Ear.L': P(('x', 20 * slam)), 'Ear.R': P(('x', 20 * slam)),
             'BackUpper.L': P(('x', -20 * slam)), 'BackLower.L': P(('x', 30 * slam))}
        k.update(_tail(6 * t, 10, 0))
        keys[f] = k
    return {'frames': F, 'loop': False, 'keys': keys}


ANIMS = {'Idle': anim_idle, 'Walk': anim_walk, 'Run': anim_run, 'Hop': anim_hop, 'Ability': anim_ability,
         'Snare': anim_snare}
