# Astral Djinn (Rift, Epic) for Hatch or Snatch: HOS-PET-026, built on the pet kit. Assembled by assemble_pet.py.
# From the concept-library card (docs/pets/astral_djinn/astral_djinn_card.png): a stocky blue genie with gold horns,
# gold armour and ornaments, red eyes and a fanged scowl, with a gold-rimmed galaxy portal disc behind it.
# A djinn floats: no legs, its body tapers into a smoke tail. Read through PET_LESSONS (anime / edgy): deep royal-blue
# skin with darker star-speckled markings, narrow slanted glowing red slit eyes under a heavy brow, a scowl with fangs
# (face decal shell), gold armour with engraved lines. L2 "Star Keeper": gold shoulder guards with gems, a second inner
# portal ring, gold tail bands. L3 "Cosmic Sultan": a crown of gold spikes with a star gem, orbiting star gems, violet
# galaxy glow and violet eyes.
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

NAME = 'Djinn'
SHARP_ANGLE = 40
NORMAL_STRENGTH = 2.0
TS = 1024
ATLAS = Atlas({
    'skin': (0, 0, 1024, 384),      # body loft: u around, v tail tip -> crown
    'limb': (0, 384, 512, 128),
    'horn': (512, 384, 256, 128),
    'gold': (768, 384, 256, 128),
    'galaxy': (0, 512, 256, 256),   # portal disc face (planar)
    'gem': (256, 512, 128, 128),
    'claw': (384, 512, 128, 128),
    'smoke': (512, 512, 512, 128),  # tail wisps
    'cloth': (0, 768, 512, 128),    # sash
    'star': (512, 640, 256, 128),
})

GLOW = {1: ('1a3ab8', '5a8aff', 'e6f0ff'), 2: ('1a3ab8', '7aa8ff', 'f0f6ff'), 3: ('6a1ab8', 'c06aff', 'fff0ff')}
EYE = {1: ('8a0a0a', 'ff3a3a', 'ffd8d8'), 2: ('8a0a0a', 'ff5a4a', 'ffe8e0'), 3: ('7a1ac0', 'd070ff', 'fff0ff')}
BLUE = [(0, '06103a'), (0.5, '1a4ac0'), (1, '5a9aff')]


def bones_def():
    b = [
        ('Root', V(0, 0, 0), V(0, 0, 0.2), None),
        ('Body', V(0, 0.04, 0.6), V(0, 0, 0.96), 'Root'),
        ('Head', V(0, -0.02, 1.0), V(0, -0.1, 1.5), 'Body'),
        ('Jaw', V(0, -0.2, 1.08), V(0, -0.46, 1.06), 'Head'),
        ('Tail1', V(0, 0.12, 0.5), V(0, 0.34, 0.36), 'Body'),
        ('Tail2', V(0, 0.34, 0.36), V(0, 0.56, 0.34), 'Tail1'),
        ('Tail3', V(0, 0.56, 0.34), V(0, 0.76, 0.48), 'Tail2'),
        ('Disc', V(0, 0.44, 1.0), V(0, 0.44, 1.3), 'Body'),
        ('Stars', V(0, 0.0, 1.6), V(0, 0.0, 1.8), 'Body'),
    ]
    for s, x in (('L', 1), ('R', -1)):
        b += [
            ('ArmU.' + s, V(x * 0.34, -0.04, 0.92), V(x * 0.52, -0.12, 0.72), 'Body'),
            ('ArmL.' + s, V(x * 0.52, -0.12, 0.72), V(x * 0.56, -0.26, 0.56), 'ArmU.' + s),
            ('Hand.' + s, V(x * 0.56, -0.26, 0.56), V(x * 0.58, -0.36, 0.46), 'ArmL.' + s),
        ]
    return b


#@helpers
FX, FZ, FZH = 0.36, 1.18, 0.3
SHELL = (-0.2, 0.92, 1.46)
#@shell


def disc(mb, region, c, normal, R, segs, w, part):
    normal = nrm(np.asarray(normal, float))
    a = nrm(np.cross(normal, V(0, 0, 1) if abs(normal[2]) < 0.9 else V(1, 0, 0)))
    b = np.cross(normal, a)
    c = np.asarray(c, float)
    for sgn in (1, -1):
        ci = mb.vert(c + normal * 0.01 * sgn, w)
        rim = [mb.vert(c + (a * math.cos(2 * math.pi * k / segs) + b * math.sin(2 * math.pi * k / segs)) * R + normal * 0.005 * sgn, w)
               for k in range(segs)]
        for k in range(segs):
            k2 = (k + 1) % segs
            uv = lambda kk: ATLAS.uv(region, 0.5 + 0.48 * math.cos(2 * math.pi * kk / segs), 0.5 + 0.48 * math.sin(2 * math.pi * kk / segs))
            mb.face([rim[k], rim[k2], ci], [uv(k), uv(k2), ATLAS.uv(region, 0.5, 0.5)], inside=c - normal * sgn, part=part)


def ring(mb, region, c, normal, R, r, n_around, n_tube, w, part):
    normal = nrm(np.asarray(normal, float))
    a = nrm(np.cross(normal, V(0, 0, 1) if abs(normal[2]) < 0.9 else V(1, 0, 0)))
    b = np.cross(normal, a)
    cen = [np.asarray(c, float) + (a * math.cos(2 * math.pi * i / n_around) + b * math.sin(2 * math.pi * i / n_around)) * R for i in range(n_around + 1)]
    tube(mb, region, cen, [(r, r)] * len(cen), n_tube, [w] * len(cen), part, start='open', end='open', side_hint=normal, anti=False)


def build():
    mb = MB()
    mb.mat = 0
    W_B, W_H, W_J = {'Body': 1}, {'Head': 1}, {'Jaw': 1}
    st = [(V(0, 0.78, 0.5), (0.03, 0.03), {'Tail3': 1}), (V(0, 0.62, 0.36), (0.08, 0.07), {'Tail3': 1}),
          (V(0, 0.44, 0.3), (0.14, 0.12), {'Tail2': 0.7, 'Tail3': 0.3}), (V(0, 0.24, 0.36), (0.22, 0.19), {'Tail1': 0.6, 'Tail2': 0.4}),
          (V(0, 0.08, 0.52), (0.32, 0.28), {'Tail1': 0.4, 'Body': 0.6}), (V(0, 0.0, 0.72), (0.4, 0.32), W_B),
          (V(0, -0.02, 0.9), (0.42, 0.32), W_B), (V(0, -0.04, 1.02), (0.24, 0.22), {'Body': 0.5, 'Head': 0.5}),
          (V(0, -0.06, 1.12), (0.28, 0.27), W_H), (V(0, -0.08, 1.26), (0.3, 0.28), W_H), (V(0, -0.06, 1.4), (0.24, 0.22), W_H),
          (V(0, -0.04, 1.5), (0.13, 0.12), W_H)]
    n0 = len(mb.F)
    tube(mb, 'skin', [s[0] for s in st], [s[1] for s in st], 16, [s[2] for s in st], 'body', start='point', end='point',
         start_pt=V(0, 0.84, 0.58), end_pt=V(0, -0.04, 1.56), side_hint=V(1, 0, 0), th0=math.pi / 2)
    body_faces = list(range(n0, len(mb.F)))
    # (17 Oct, z-fighting fix: the jaw sits 0.08 higher so it clears the collar ring)
    js = [(V(0, -0.22, 1.16), (0.18, 0.06), W_J), (V(0, -0.34, 1.14), (0.12, 0.05), W_J)]
    tube(mb, 'skin', [j[0] for j in js], [j[1] for j in js], 8, [j[2] for j in js], 'jaw', start='point', end='point',
         start_pt=V(0, -0.14, 1.18), end_pt=V(0, -0.4, 1.14), side_hint=V(1, 0, 0), th0=math.pi / 2)
    # gold horns sweeping up and out, pointed ears
    for s, x in (('L', 1), ('R', -1)):
        path = [V(x * 0.14, -0.06, 1.44), V(x * 0.24, -0.04, 1.6), V(x * 0.34, 0.0, 1.72), V(x * 0.38, 0.06, 1.84)]
        d = nrm(path[-1] - path[-2])
        tube(mb, 'horn', path, [(0.08, 0.07), (0.065, 0.06), (0.045, 0.04), (0.025, 0.022)], 6, [W_H] * 4, 'horn',
             start='point', end='point', start_pt=V(x * 0.1, -0.06, 1.36), end_pt=path[-1] + d * 0.12, anti=False, side_hint=V(0, 1, 0))
        bipyramid(mb, V(x * 0.26, -0.04, 1.28), V(x * 0.48, 0.02, 1.36), V(0, 0, 1), V(0, -1, 0), 0.14, 0.05, W_H,
                  ATLAS.uv('limb', 0.5, 0.3), ATLAS.uv('limb', 0.5, 0.3), 'ear', wide_at=0.35, ridge_at=0.35)
    # gold collar plate and a forehead gem
    # (z-fighting fix: level ring, inner edge 0.03 clear of the neck)
    ring(mb, 'gold', V(0, -0.04, 1.02), V(0, 0, 1), 0.32, 0.05, 14, 5, {'Body': 0.5, 'Head': 0.5}, 'gold')
    bipyramid(mb, V(0, -0.3, 1.32), V(0, -0.36, 1.32), V(1, 0, 0), V(0, 0, 1), 0.1, 0.12, W_H,
              ATLAS.uv('gem', 0.5, 0.2), ATLAS.uv('gem', 0.5, 0.8), 'gem', wide_at=0.5, ridge_at=0.5)
    # a red sash diagonally across the chest
    sash = [V(0.34, -0.1, 1.0), V(0.18, -0.37, 0.86), V(-0.1, -0.37, 0.68), V(-0.34, -0.16, 0.52)]   # clear of the chest
    tube(mb, 'cloth', sash, [(0.06, 0.025)] * 4, 4, [W_B] * 4, 'sash', start='flat', end='flat', side_hint=V(0, -1, 0), anti=False)
    # big arms with gold bracers and claws
    for s, x in (('L', 1), ('R', -1)):
        au, al, h = 'ArmU.' + s, 'ArmL.' + s, 'Hand.' + s
        arm = [(V(x * 0.3, -0.04, 0.94), (0.14, 0.14), {'Body': 0.5, au: 0.5}), (V(x * 0.44, -0.08, 0.82), (0.13, 0.13), {au: 1}),
               (V(x * 0.52, -0.12, 0.72), (0.11, 0.11), {au: 0.5, al: 0.5}), (V(x * 0.55, -0.2, 0.62), (0.1, 0.1), {al: 1}),
               (V(x * 0.57, -0.28, 0.54), (0.12, 0.12), {al: 0.4, h: 0.6})]
        tube(mb, 'limb', [a[0] for a in arm], [a[1] for a in arm], 8, [a[2] for a in arm], 'arm' + s, start='point', end='point',
             start_pt=V(x * 0.2, -0.02, 0.96), end_pt=V(x * 0.59, -0.36, 0.48))
        c = V(x * 0.55, -0.2, 0.62)
        ring(mb, 'gold', c, nrm(V(x * 0.15, -0.5, -0.5)), 0.15, 0.035, 8, 4, {al: 1}, 'gold')   # clear of the forearm
        for dx in (-0.04, 0.0, 0.04):
            b0 = V(x * (0.58 + dx), -0.34, 0.5)
            bipyramid(mb, b0, b0 + V(x * dx, -0.1, -0.08), V(1, 0, 0), V(0, 0, 1), 0.04, 0.035, {h: 1},
                      ATLAS.uv('claw', 0.5, 0.15), ATLAS.uv('claw', 0.5, 0.9), 'claw', wide_at=0.3, ridge_at=0.3)
    # smoke wisps off the tail
    for base, tip in ((V(0.04, 0.5, 0.3), V(0.24, 0.8, 0.2)), (V(-0.04, 0.5, 0.3), V(-0.24, 0.8, 0.2))):
        bipyramid(mb, base, tip, V(0, 0, 1), V(1, 0, 0), 0.13, 0.03, {'Tail3': 1}, ATLAS.uv('smoke', 0.5, 0.05),
                  ATLAS.uv('smoke', 0.5, 0.95), 'smoke', wide_at=0.35, ridge_at=0.35)
    # the galaxy portal disc on its back, gold rim
    dc = V(0, 0.44, 1.02)
    disc(mb, 'galaxy', dc, V(0, 1, 0.1), 0.42, 16, {'Disc': 1}, 'disc')
    ring(mb, 'gold', dc, V(0, 1, 0.1), 0.44, 0.05, 16, 4, {'Disc': 1}, 'disc')
    mb.mat = 1
    face_shell(mb, body_faces)
    # ---- L2 "Star Keeper": gold shoulder guards with gems, an inner portal ring, gold tail bands
    mb.mat = 2
    for s, x in (('L', 1), ('R', -1)):
        bipyramid(mb, V(x * 0.3, 0.0, 1.0), V(x * 0.58, 0.04, 1.04), V(0, 1, 0), V(0, 0, 1), 0.26, 0.1, {'ArmU.' + s: 0.5, 'Body': 0.5},
                  ATLAS.uv('gold', 0.4, 0.8), ATLAS.uv('gold', 0.6, 0.2), 'L2', wide_at=0.3, ridge_at=0.3)
        bipyramid(mb, V(x * 0.42, -0.08, 1.06), V(x * 0.44, -0.14, 1.06), V(1, 0, 0), V(0, 0, 1), 0.07, 0.08, {'ArmU.' + s: 1},
                  ATLAS.uv('gem', 0.5, 0.2), ATLAS.uv('gem', 0.5, 0.8), 'L2', wide_at=0.5, ridge_at=0.5)
    ring(mb, 'star', dc + V(0, -0.05, 0), V(0, 1, 0.1), 0.3, 0.025, 14, 4, {'Disc': 1}, 'L2')   # in front of the disc face
    for c, w in ((V(0, 0.24, 0.36), {'Tail1': 0.6, 'Tail2': 0.4}), (V(0, 0.44, 0.3), {'Tail2': 1})):
        ring(mb, 'gold', c, nrm(V(0, 1, -0.3)), 0.25 if c[1] < 0.3 else 0.18, 0.025, 10, 3, w, 'L2')   # clear of the tail
    # ---- L3 "Cosmic Sultan": a crown of gold spikes with a star gem, orbiting star gems
    mb.mat = 3
    for k in range(5):
        a = math.radians(-60 + 30 * k)
        base = V(math.sin(a) * 0.18, -0.06 + 0.06 * abs(math.sin(a)), 1.46)
        bipyramid(mb, base, base + V(math.sin(a) * 0.08, 0.02, 0.22 + 0.08 * (k == 2)), V(1, 0, 0), V(0, -1, 0), 0.08, 0.05, W_H,
                  ATLAS.uv('gold', 0.4, 0.8), ATLAS.uv('gold', 0.6, 0.2), 'L3', wide_at=0.3, ridge_at=0.3)
    bipyramid(mb, V(0, -0.18, 1.6), V(0, -0.22, 1.6), V(1, 0, 0), V(0, 0, 1), 0.1, 0.12, W_H,
              ATLAS.uv('gem', 0.5, 0.2), ATLAS.uv('gem', 0.5, 0.8), 'L3', wide_at=0.5, ridge_at=0.5)
    for k in range(4):
        a = 2 * math.pi * k / 4
        c = V(math.cos(a) * 0.5, math.sin(a) * 0.5, 1.62)
        bipyramid(mb, c - V(0, 0, 0.08), c + V(0, 0, 0.08), V(1, 0, 0), V(0, 1, 0), 0.1, 0.1, {'Stars': 1},
                  ATLAS.uv('star', 0.5, 0.2), ATLAS.uv('star', 0.5, 0.8), 'L3', wide_at=0.5, ridge_at=0.5)
    mb.mat = 0
    return mb


#@paint_helpers


def paint_atlas(level):
    col = np.zeros((TS, TS, 3), np.float32)
    hgt = np.full((TS, TS), 0.5, np.float32)
    rgh = np.full((TS, TS), 0.55, np.float32)
    glow = np.zeros((TS, TS), np.float32)
    gd, gm, gh = GLOW[level]
    blue = BLUE if level < 3 else [(0, '0a0630'), (0.5, '2a2aa8'), (1, '6a7aff')]
    for reg in ('skin', 'limb'):
        (y0, y1, x0, x1), v, u = _reg(reg)
        h, w = y1 - y0, x1 - x0
        top = np.cos(u * 2 * math.pi)
        c = grad(np.clip(0.5 + 0.35 * top, 0, 1), blue)
        # redo 17 Oct (Hunter: "more detail and contrast, less plain navy"): a pale cyan-lilac belly against a deep
        # indigo back with a violet nebula, bigger stars, glowing gold rune bands and chest constellation lines
        belly = ss(-0.62, -0.82, top + 0.08 * _saw(v * 12)) * (1.0 if reg == 'skin' else 0.0) * ss(0.12, 0.25, v) * ss(0.8, 0.68, v)
        c = c * (1 - 0.85 * belly[..., None]) + grad(np.clip(v, 0, 1), [(0, '4a8ae8'), (0.6, '9ac4ff'), (1, 'd0e0ff')]) * (0.85 * belly[..., None])
        back = ss(0.35, 0.65, top + 0.12 * _saw(v * 14 + u * 3))
        c = c * (1 - 0.75 * back[..., None]) + hx('0a0a3a') * (0.75 * back[..., None])
        neb = ss(0.55, 0.85, vnoise(h, w, 10, 107)) * back
        c = c * (1 - 0.6 * neb[..., None]) + grad(neb, [(0, '3a1a8a'), (1, 'b04ae0')]) * (0.6 * neb[..., None])
        rune = ss(0.455, 0.47, np.abs(_saw(v * 4) - 0.5)) * (0.4 + 0.6 * ss(0.2, 0.5, np.abs(np.sin(u * 2 * math.pi * 6))))
        rune = rune * (1.0 if reg == 'limb' else 0.0)
        c = c * (1 - rune[..., None]) + hx('ffc84a') * rune[..., None]
        glow[y0:y1, x0:x1] = rune * 0.8
        if reg == 'skin':
            cx = np.abs(u - 0.5)
            con = np.zeros_like(u)
            pts = [(0.04, 0.62), (0.1, 0.7), (0.07, 0.8), (0.14, 0.86), (0.02, 0.9)]
            for (pa, va), (pb, vb) in zip(pts, pts[1:]):
                L2 = (pb - pa) ** 2 + (vb - va) ** 2
                t = np.clip(((cx - pa) * (pb - pa) + (v - va) * (vb - va)) / L2, 0, 1)
                d = np.sqrt((cx - pa - t * (pb - pa)) ** 2 + (v - va - t * (vb - va)) ** 2)
                con = np.maximum(con, ss(0.004, 0.0015, d))
            for pa, va in pts:
                con = np.maximum(con, ss(0.012, 0.007, np.sqrt((cx - pa) ** 2 + ((v - va) * 0.4) ** 2)))
            con = con * belly
            c = c * (1 - con[..., None]) + hx('ffe08a') * con[..., None]
            glow[y0:y1, x0:x1] = np.maximum(glow[y0:y1, x0:x1], con)
        if reg == 'skin':
            tail = ss(0.02, -0.02, v - (0.3 + 0.05 * _saw(u * 10)))
            c = c * (1 - 0.6 * tail[..., None]) + hx('0a0830') * (0.6 * tail[..., None])
            edge = ss(0.03, 0.0, np.abs(v - (0.3 + 0.05 * _saw(u * 10))))
            c = c * (1 - edge[..., None]) + hx(gm) * edge[..., None]
            glow[y0:y1, x0:x1] = edge
        stars = ss(0.93, 0.965, vnoise(h, w, 240, 101)) * back
        c = c * (1 - stars[..., None]) + hx('e6f0ff') * stars[..., None]
        st = _streaks(h, w, 140, 102)
        col[y0:y1, x0:x1] = c * (1 + 0.12 * st[..., None])
        hgt[y0:y1, x0:x1] = 0.5 + 0.25 * st
        glow[y0:y1, x0:x1] = np.maximum(glow[y0:y1, x0:x1], stars * 0.8)
    (y0, y1, x0, x1), v, u = _reg('horn')
    ridges = 0.5 + 0.5 * np.cos(v * 2 * math.pi * 6)
    col[y0:y1, x0:x1] = grad(v, [(0, 'a8700a'), (0.6, 'ffc23a'), (1, 'fff0a0')]) * (0.85 + 0.15 * ridges[..., None])
    rgh[y0:y1, x0:x1] = 0.25
    (y0, y1, x0, x1), v, u = _reg('gold')
    eng = ss(0.02, 0.0, np.abs(_saw(u * 8) - 0.5) - 0.02) * ss(0.3, 0.4, v) * ss(0.7, 0.6, v)
    col[y0:y1, x0:x1] = grad(v, [(0, 'fff0a0'), (0.5, 'ffc23a'), (1, '8a5a0a')]) * (1 - 0.5 * eng[..., None])
    rgh[y0:y1, x0:x1] = 0.25
    glow[y0:y1, x0:x1] = 0.1
    # galaxy disc: a violet-blue spiral with stars and a dark eye
    (y0, y1, x0, x1), v, u = _reg('galaxy')
    X, Y = (u - 0.5) * 2, (v - 0.5) * 2
    R = np.sqrt(X ** 2 + Y ** 2)
    A = np.arctan2(Y, X)
    spiral = 0.5 + 0.5 * np.cos(A * 2 - R * 9)
    c = grad(np.clip(spiral * (1 - R) + 0.1, 0, 1), [(0, '06061a'), (0.5, gd), (0.85, gm), (1, gh)])
    eye = ss(0.18, 0.12, R)
    c = c * (1 - eye[..., None]) + hx('020208') * eye[..., None]
    starmask = (grit(y1 - y0, x1 - x0, 103) > 0.98) * 1.0
    c = c * (1 - starmask[..., None]) + hx('ffffff') * starmask[..., None]
    col[y0:y1, x0:x1] = c
    glow[y0:y1, x0:x1] = np.clip(spiral * (1 - R) * 0.8 + starmask, 0, 1) * (R < 1)
    for reg, cols in (('gem', [(0, gh), (0.5, gm), (1, gd)]), ('star', [(0, 'ffffff'), (0.5, gh), (1, gm)])):
        (y0, y1, x0, x1), v, u = _reg(reg)
        col[y0:y1, x0:x1] = grad(v, cols)
        rgh[y0:y1, x0:x1] = 0.08
        glow[y0:y1, x0:x1] = 0.8
    (y0, y1, x0, x1), v, u = _reg('claw')
    col[y0:y1, x0:x1] = hx('0a0a1a')
    (y0, y1, x0, x1), v, u = _reg('smoke')
    col[y0:y1, x0:x1] = grad(v, [(0, '1a2a8a'), (0.7, '0a0830'), (1, gm)])
    glow[y0:y1, x0:x1] = ss(0.8, 1.0, v)
    (y0, y1, x0, x1), v, u = _reg('cloth')
    col[y0:y1, x0:x1] = grad(u, [(0, '8a0a1a'), (0.5, 'c81e2a'), (1, '8a0a1a')])
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
    ix, iz, ox, oz = 0.05, 1.2, 0.2, 1.27
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
    brow = np.maximum(_seg(aX, Z, (0.03, 1.25), (0.22, 1.33), 0.016, 0.006), _seg(aX, Z, (0.2, 1.32), (0.28, 1.38), 0.009, 0.001))
    lid = ss(0.006, 0.003, np.abs(d - top - 0.003)) * (s > -0.05) * (s < 1.02)
    mark = np.maximum(_seg(aX, Z, (0.18, 1.16), (0.24, 1.1), 0.01, 0.002), _seg(aX, Z, (0.24, 1.12), (0.3, 1.06), 0.008, 0.002))
    if level >= 3:
        mark = np.maximum(mark, _seg(aX, Z, (0.06, 1.36), (0.12, 1.42), 0.007, 0.002))
    scowl = np.maximum(_seg(aX, Z, (0.0, 1.06), (0.12, 1.04), 0.006, 0.005), _seg(aX, Z, (0.12, 1.04), (0.17, 1.02), 0.005, 0.002))
    fang = ss(0.08, 0.0, np.abs(aX - 0.08) / 0.012 + (1.048 - Z) / 0.04 - 1) * (Z < 1.048) * (Z > 1.01)
    return X, Z, eye, iris, slit, brow, lid, mark, scowl, fang


def face_texture(level, size=512):
    X, Z, eye, iris, slit, brow, lid, mark, scowl, fang = _face_layers(level, size)
    rr = _face_layers.rr
    ed, em, eh = EYE[level]
    gd, gm, gh = GLOW[level]
    rgba = np.zeros((size, size, 4), np.float32)
    c = np.zeros((size, size, 3), np.float32) + hx('060a28')
    c = c * (1 - mark[..., None]) + hx('ffc23a') * mark[..., None]
    irisc = grad(np.clip(1 - rr / 0.044, 0, 1), [(0, ed), (0.45, em), (1, eh)])
    e = hx('140606') * (1 - iris[..., None]) + irisc * iris[..., None]
    e = e * (1 - slit[..., None]) + hx('040202') * slit[..., None]
    c = c * (1 - eye[..., None]) + e * eye[..., None]
    ln = np.maximum.reduce([lid, brow, scowl])
    c = c * (1 - ln[..., None]) + hx('020414') * ln[..., None]
    c = c * (1 - fang[..., None]) + hx('f4f2ea') * fang[..., None]
    rgba[..., :3] = c
    rgba[..., 3] = np.clip(np.maximum.reduce([eye, ln, mark, fang]), 0, 1)
    return rgba


def face_emissive(level, size=512):
    X, Z, eye, iris, slit, brow, lid, mark, scowl, fang = _face_layers(level, size)
    g = np.clip(np.maximum(iris * eye * (1 - slit), mark * 0.6), 0, 1)
    return np.repeat(g[..., None], 3, -1)


#@animh


def anim_idle():
    F = 72
    keys = {}
    for f in range(0, F + 1, 3):
        t = f / F
        w = 2 * math.pi * t
        k = {'Body': P(('x', 4 + 2 * math.sin(w)), loc=(0, 0, 0.07 * math.sin(w))),
             'Head': P(('z', 12 * math.sin(w * 0.5)), ('x', -4 * math.sin(w))), 'Jaw': P(('x', 8 * _pulse(t, 0.4, 0.5))),
             'ArmU.L': P(('x', -20 + 6 * math.sin(w)), ('z', -30)), 'ArmU.R': P(('x', -20 + 6 * math.sin(w + 0.4)), ('z', 30)),
             'ArmL.L': P(('x', -40), ('z', -30)), 'ArmL.R': P(('x', -40), ('z', 30)),
             'Disc': P(('y', 360 * t)), 'Stars': P(('z', 360 * t), loc=(0, 0, 0.04 * math.sin(2 * w)))}
        k.update(_tail(w, 16, 0))
        keys[f] = k
    keys[F] = dict(keys[0])
    keys[F]['Disc'] = P(('y', 0))
    keys[F]['Stars'] = P(('z', 0))
    return {'frames': F, 'loop': True, 'keys': keys}


def _fly(frames, pitch):
    keys = {}
    for f in range(0, frames + 1, 2):
        t = f / frames
        w = 2 * math.pi * t
        k = {'Body': P(('x', pitch + 3 * math.sin(w)), loc=(0, 0, 0.06 * math.sin(w - 1.2))), 'Head': P(('x', -pitch * 0.7)),
             'ArmU.L': P(('x', 40), ('z', 14)), 'ArmU.R': P(('x', 40), ('z', -14)), 'Disc': P(('x', -pitch * 0.5)),
             'Tail1': P(('x', -pitch * 0.4), ('z', 10 * math.sin(w))), 'Tail2': P(('z', 14 * math.sin(w - 0.9))),
             'Tail3': P(('z', 18 * math.sin(w - 1.8)))}
        keys[f] = k
    keys[frames] = dict(keys[0])
    return {'frames': frames, 'loop': True, 'keys': keys}


def anim_walk():
    return _fly(24, 25)


def anim_run():
    return _fly(16, 45)


def anim_hop():
    keys = {}
    for f in range(0, 17, 2):
        t = f / 16
        up = math.sin(math.pi * t)
        keys[f] = {'Body': P(('x', -8 * up), loc=(0, 0, 0.3 * up)), 'ArmU.L': P(('y', -50 * up)), 'ArmU.R': P(('y', 50 * up))}
    return {'frames': 16, 'loop': False, 'keys': keys}


def anim_ability():
    """Portal (~1 s, Runner): pulls the galaxy disc over its head, flings it open in front with both arms (the portal at
    ~0.5) and spins it, then dives through."""
    keys = {}
    F = 24
    for f in range(0, F + 1, 2):
        t = f / F
        lift = _ease(t / 0.3) * (1 - _ease((t - 0.3) / 0.15))
        throw = _ease((t - 0.3) / 0.15) * (1 - _ease((t - 0.85) / 0.15))
        dive = _pulse(t, 0.5, 0.95)
        keys[f] = {'Disc': P(('y', 720 * t * throw), ('x', 90 * lift), loc=(0, -0.44 * lift - 1.1 * throw, 0.7 * lift)),
                   'ArmU.L': P(('y', -70 * lift - 20 * throw), ('x', -60 * throw)), 'ArmU.R': P(('y', 70 * lift + 20 * throw), ('x', -60 * throw)),
                   'Body': P(('x', -10 * lift + 40 * dive), loc=(0, -0.5 * dive, 0.05 * lift)), 'Head': P(('x', -10 * lift + 10 * dive)),
                   'Tail1': P(('x', 25 * dive)), 'Tail2': P(('x', 20 * dive)), 'Stars': P(('z', 720 * t))}
    return {'frames': F, 'loop': False, 'keys': keys}


def anim_blink():
    """Blink (~0.7 s, Catcher): crosses its arms, then snaps them wide in a flash and leans forward."""
    keys = {}
    F = 16
    for f in range(0, F + 1, 1):
        t = f / F
        cross = _ease(t / 0.35) * (1 - _ease((t - 0.35) / 0.08))
        flare = _ease((t - 0.35) / 0.08) * (1 - _ease((t - 0.55) / 0.45))
        keys[f] = {'Body': P(('x', 12 * cross - 8 * flare), loc=(0, 0, -0.05 * cross + 0.08 * flare)), 'Head': P(('x', 12 * cross - 10 * flare)),
                   'ArmU.L': P(('z', -60 * cross), ('y', -80 * flare)), 'ArmU.R': P(('z', 60 * cross), ('y', 80 * flare)),
                   'ArmL.L': P(('x', -50 * cross)), 'ArmL.R': P(('x', -50 * cross)), 'Jaw': P(('x', 25 * flare)),
                   'Disc': P(('y', 540 * t)), 'Tail1': P(('x', 25 * flare))}
    return {'frames': F, 'loop': False, 'keys': keys}


ANIMS = {'Idle': anim_idle, 'Walk': anim_walk, 'Run': anim_run, 'Hop': anim_hop, 'Ability': anim_ability,
         'Blink': anim_blink}
