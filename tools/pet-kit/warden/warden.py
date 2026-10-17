# Crystal Warden (Guardian, Rare) for Hatch or Snatch: HOS-PET-019, built on the pet kit (docs/pets/Pet Pipeline Guide.md).
# From the concept-library card (docs/pets/crystal_warden/crystal_warden_card.png): a stocky armoured indigo beast with
# glowing cyan crystals growing from its back, head and tail, a gold forehead crest and gold muzzle armour, yellow eyes.
# Read through PET_LESSONS (anime / edgy): deep indigo with near-black underside and claws, jagged armour plates,
# narrow slanted glowing slit eyes under a heavy brow (painted flush on a face decal shell), a thin snarl with fangs,
# sharp angular crystals. L2 "Bulwark": crystal pauldrons, a chest gem, brow crystals, more tail crystals, gold trim.
# L3 "Prism Sovereign": a crystal crown, crystal wing-fins, a great spine crystal, violet-white prism crystals.
# Reshaped 17 Oct (HOS-PET-RESHAPE): its own body plan, a low armoured crawler like a pangolin, a very wide flat domed
# shell close to the ground under rows of angled crystal plates, short legs splayed out to the sides, a small low
# wedge head and a long flat armoured tail; its Shield hunkers under the shell and slams it down.
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

NAME = 'Warden'
SHARP_ANGLE = 40
NORMAL_STRENGTH = 2.2
TS = 1024
ATLAS = Atlas({
    'skin': (0, 0, 1024, 384),      # body loft: u around (0 = top seam, 0.5 = belly), v tail end -> neck
    'head': (0, 384, 512, 256),     # head loft: u around, v skull -> snout
    'limb': (512, 384, 512, 128),   # legs: v hip/shoulder -> foot
    'tail': (512, 512, 256, 128),   # v root -> tip
    'jaw': (768, 512, 256, 128),
    'crystal': (0, 640, 256, 128),  # v root -> tip
    'gold': (256, 640, 256, 128),
    'claw': (512, 640, 128, 128),
    'fin': (640, 640, 384, 128),    # L3 crystal wing-fins
    'crystal3': (0, 768, 256, 128), # L2 / L3 crystals (palette per level)
})

CRYSTAL = {1: ('1a7ae8', '5aeeff', 'f4feff'), 2: ('1a86f0', '6af4ff', 'f8ffff'), 3: ('6a34e0', 'c8a8ff', 'fff6ff')}   # redo: brighter
EYE = {1: ('c87a00', 'ffd23a', 'fff6c0'), 2: ('c87a00', 'ffe04a', 'fffbe0'), 3: ('7a3ad0', 'e0c8ff', 'ffffff')}


# ---------------------------------------------------------------- skeleton
def bones_def():
    b = [
        ('Root', V(0, 0, 0), V(0, 0, 0.2), None),
        ('Body', V(0, 0.45, 0.44), V(0, -0.05, 0.48), 'Root'),
        ('Chest', V(0, -0.05, 0.48), V(0, -0.5, 0.46), 'Body'),
        ('Head', V(0, -0.58, 0.52), V(0, -1.18, 0.48), 'Chest'),
        ('Jaw', V(0, -0.76, 0.38), V(0, -1.14, 0.32), 'Head'),
        ('Tail1', V(0, 0.9, 0.4), V(0, 1.25, 0.32), 'Body'),
        ('Tail2', V(0, 1.25, 0.32), V(0, 1.6, 0.28), 'Tail1'),
        ('Tail3', V(0, 1.6, 0.28), V(0, 1.9, 0.3), 'Tail2'),
    ]
    for s, x in (('L', 1), ('R', -1)):
        b += [
            ('FrontUpper.' + s, V(x * 0.48, -0.3, 0.44), V(x * 0.76, -0.37, 0.24), 'Chest'),
            ('FrontLower.' + s, V(x * 0.76, -0.37, 0.24), V(x * 0.8, -0.42, 0.08), 'FrontUpper.' + s),
            ('FrontFoot.' + s, V(x * 0.8, -0.42, 0.08), V(x * 0.82, -0.58, 0.05), 'FrontLower.' + s),
            ('BackUpper.' + s, V(x * 0.5, 0.46, 0.44), V(x * 0.78, 0.4, 0.24), 'Body'),
            ('BackLower.' + s, V(x * 0.78, 0.4, 0.24), V(x * 0.82, 0.44, 0.08), 'BackUpper.' + s),
            ('BackFoot.' + s, V(x * 0.82, 0.44, 0.08), V(x * 0.85, 0.28, 0.05), 'BackLower.' + s),
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


def crystal(mb, region, base, tip, w, width, part, side=None, up=None, wide_at=0.3):
    """A sharp crystal: bipyramid with a fat base buried in the part it grows from."""
    d = nrm(np.asarray(tip, float) - np.asarray(base, float))
    side = side if side is not None else (V(1, 0, 0) if abs(d[0]) < 0.8 else V(0, 1, 0))
    up = up if up is not None else nrm(np.cross(d, side))
    width *= 1.45                      # chunky crystals like the card
    bipyramid(mb, base, tip, side, up, width, width * 0.8, w, ATLAS.uv(region, 0.5, 0.05), ATLAS.uv(region, 0.5, 0.95),
              part, wide_at=wide_at, ridge_at=wide_at)


DFX, DFZ, DFZH = 0.44, 1.0, 0.4   # the face decal is drawn in these units, then mapped onto FX / FZ / FZH
FX, FZ, FZH = 0.33, 0.45, 0.3             # face decal shell: model x half-width, z centre, z half-height -> face texture


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
    sel = [fi for fi in head_faces if all(mb.V[v][1] < -0.78 and 0.15 < mb.V[v][2] < 0.85 for v in mb.F[fi])]
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
    # a low armoured crawler: a very wide, flat domed shell close to the ground
    st = [(V(0, 0.95, 0.38), (0.16, 0.12), {'Body': 0.5, 'Tail1': 0.5}),
          (V(0, 0.75, 0.42), (0.5, 0.28), W_B),
          (V(0, 0.45, 0.46), (0.68, 0.34), W_B),
          (V(0, 0.1, 0.48), (0.72, 0.36), {'Body': 0.6, 'Chest': 0.4}),
          (V(0, -0.24, 0.46), (0.66, 0.33), W_C),
          (V(0, -0.46, 0.44), (0.48, 0.26), W_C),
          (V(0, -0.6, 0.44), (0.3, 0.2), {'Chest': 0.4, 'Head': 0.6})]
    tube(mb, 'skin', [s[0] for s in st], [s[1] for s in st], 14, [s[2] for s in st], 'body',
         start='point', end='point', start_pt=V(0, 1.02, 0.38), end_pt=V(0, -0.68, 0.46), side_hint=V(1, 0, 0),
         th0=math.pi / 2)
    # small low wedge head
    n0 = len(mb.F)
    hs = [(V(0, -0.58, 0.5), (0.24, 0.22), W_H), (V(0, -0.74, 0.52), (0.35, 0.3), W_H),
          (V(0, -0.92, 0.49), (0.33, 0.26), W_H), (V(0, -1.06, 0.44), (0.23, 0.18), W_H),
          (V(0, -1.18, 0.39), (0.15, 0.12), W_H)]
    tube(mb, 'head', [h[0] for h in hs], [h[1] for h in hs], 12, [h[2] for h in hs], 'head',
         start='point', end='point', start_pt=V(0, -0.52, 0.5), end_pt=V(0, -1.26, 0.37), side_hint=V(1, 0, 0),
         th0=math.pi / 2)
    head_faces = list(range(n0, len(mb.F)))
    js = [(V(0, -0.78, 0.36), (0.22, 0.09), W_J), (V(0, -0.94, 0.33), (0.18, 0.07), W_J), (V(0, -1.08, 0.32), (0.11, 0.05), W_J)]
    tube(mb, 'jaw', [j[0] for j in js], [j[1] for j in js], 8, [j[2] for j in js], 'jaw', start='point', end='point',
         start_pt=V(0, -0.7, 0.38), end_pt=V(0, -1.14, 0.32), side_hint=V(1, 0, 0), th0=math.pi / 2)
    # gold armour: a forehead crest plate and a muzzle plate
    gb, gt = ATLAS.uv('gold', 0.4, 0.8), ATLAS.uv('gold', 0.6, 0.2)
    bipyramid(mb, V(0, -0.84, 0.72), V(0, -0.76, 1.0), V(1, 0, 0), V(0, -1, 0.2), 0.27, 0.1, W_H, gb, gt, 'gold',
              wide_at=0.35, ridge_at=0.3)
    bipyramid(mb, V(0, -0.94, 0.76), V(0, -1.3, 0.5), V(1, 0, 0), V(0, -0.4, 1), 0.16, 0.1, W_H, gb, gt, 'gold',
              wide_at=0.72, ridge_at=0.6)
    for x in (1, -1):
        crystal(mb, 'crystal', V(x * 0.15, -0.68, 0.68), V(x * 0.34, -0.46, 1.0), W_H, 0.15, 'horn')
        crystal(mb, 'crystal', V(x * 0.26, -0.62, 0.6), V(x * 0.46, -0.48, 0.72), W_H, 0.1, 'horn')
    # rows of angled crystal plates fanned over the shell, like a pangolin's scales
    for row, (y, w, ln) in enumerate(((-0.36, W_C, 0.3), (-0.06, {'Body': 0.4, 'Chest': 0.6}, 0.36), (0.26, W_B, 0.34),
                                      (0.56, W_B, 0.28), (0.8, W_B, 0.2))):
        for a_deg in ((-62, -31, 0, 31, 62) if row < 4 else (-40, 0, 40)):
            a = math.radians(a_deg + (8 if row % 2 else 0))
            rx, rz, zc = (0.7, 0.35, 0.47) if row < 3 else (0.6, 0.3, 0.44)
            base = V(math.sin(a) * rx * 0.86, y, zc + math.cos(a) * rz * 0.9)
            d = nrm(V(math.sin(a) * 0.75, 0.55, math.cos(a)))
            crystal(mb, 'crystal', base, base + d * ln * (1.0 if a_deg == 0 else 0.8), w, 0.2, 'crystal')
    # short legs splayed out to the sides, three crystal claws per foot
    for s, x in (('L', 1), ('R', -1)):
        fu, fl, ff = 'FrontUpper.' + s, 'FrontLower.' + s, 'FrontFoot.' + s
        front = [(V(x * 0.48, -0.3, 0.44), (0.18, 0.16), {'Chest': 0.6, fu: 0.4}),
                 (V(x * 0.66, -0.34, 0.34), (0.15, 0.14), {fu: 1}),
                 (V(x * 0.76, -0.37, 0.24), (0.13, 0.13), {fu: 0.5, fl: 0.5}),
                 (V(x * 0.8, -0.4, 0.12), (0.12, 0.12), {fl: 1}),
                 (V(x * 0.82, -0.48, 0.06), (0.15, 0.07), {fl: 0.3, ff: 0.7})]
        tube(mb, 'limb', [f[0] for f in front], [f[1] for f in front], 10, [f[2] for f in front], 'front' + s,
             start='point', end='point', start_pt=V(x * 0.36, -0.28, 0.46), end_pt=V(x * 0.83, -0.58, 0.05))
        bu, bl, bf = 'BackUpper.' + s, 'BackLower.' + s, 'BackFoot.' + s
        back = [(V(x * 0.5, 0.46, 0.44), (0.19, 0.17), {'Body': 0.6, bu: 0.4}),
                (V(x * 0.68, 0.42, 0.34), (0.16, 0.15), {bu: 1}),
                (V(x * 0.78, 0.4, 0.24), (0.13, 0.13), {bu: 0.5, bl: 0.5}),
                (V(x * 0.82, 0.42, 0.12), (0.12, 0.12), {bl: 1}),
                (V(x * 0.84, 0.36, 0.06), (0.15, 0.07), {bl: 0.3, bf: 0.7})]
        tube(mb, 'limb', [f[0] for f in back], [f[1] for f in back], 10, [f[2] for f in back], 'back' + s,
             start='point', end='point', start_pt=V(x * 0.38, 0.46, 0.46), end_pt=V(x * 0.86, 0.28, 0.05))
        for foot, bone in ((V(x * 0.82, -0.52, 0.07), ff), (V(x * 0.85, 0.32, 0.07), bf)):
            for k in (-1, 0, 1):
                dirv = nrm(V(k * 0.4 + x * 0.3, -1, -0.15))
                b0 = foot + V(k * 0.06, 0, 0)
                bipyramid(mb, b0, b0 + dirv * 0.14, V(1, 0, 0), V(0, 0, 1), 0.06, 0.05, {bone: 1},
                          ATLAS.uv('claw', 0.5, 0.15), ATLAS.uv('claw', 0.5, 0.9), 'claw', wide_at=0.3, ridge_at=0.3)
    # a long, flat armoured tail held low, crystal plates along it and a crystal cluster at the tip
    tp = [V(0, 0.9, 0.4), V(0, 1.25, 0.32), V(0, 1.6, 0.28), V(0, 1.9, 0.3)]
    tube(mb, 'tail', tp, [(0.2, 0.12), (0.15, 0.09), (0.1, 0.07), (0.05, 0.05)], 8,
         [{'Body': 0.4, 'Tail1': 0.6}, {'Tail1': 0.5, 'Tail2': 0.5}, {'Tail2': 0.5, 'Tail3': 0.5}, {'Tail3': 1}], 'tail',
         start='point', end='point', start_pt=V(0, 0.84, 0.4), end_pt=V(0, 2.0, 0.31))
    for p, tip, w in ((V(0, 1.15, 0.42), V(0, 1.3, 0.62), {'Tail1': 1}), (V(0, 1.45, 0.36), V(0, 1.6, 0.54), {'Tail2': 1})):
        crystal(mb, 'crystal', p, tip, w, 0.13, 'crystal')
    tc = V(0, 1.9, 0.32)
    for tip, wd in ((V(0, 2.1, 0.52), 0.14), (V(0.16, 2.06, 0.42), 0.11), (V(-0.16, 2.06, 0.42), 0.11)):
        crystal(mb, 'crystal', tc, tip, {'Tail3': 1}, wd, 'crystal')
    # ---- face decal shell (mat 1): eyes, brows, snarl, markings
    mb.mat = 1
    face_shell(mb, head_faces)
    # ---- level 2 (mat 2) "Bulwark": crystal pauldrons, chest gem, brow crystals, hip crystals
    mb.mat = 2
    for x in (1, -1):
        crystal(mb, 'crystal3', V(x * 0.56, -0.3, 0.62), V(x * 0.86, -0.36, 0.8), W_C, 0.18, 'L2')
        crystal(mb, 'crystal3', V(x * 0.6, -0.2, 0.56), V(x * 0.92, -0.14, 0.64), W_C, 0.14, 'L2')
        crystal(mb, 'crystal3', V(x * 0.12, -0.94, 0.74), V(x * 0.18, -0.92, 0.9), W_H, 0.08, 'L2')
        crystal(mb, 'crystal3', V(x * 0.6, 0.6, 0.6), V(x * 0.84, 0.72, 0.78), W_B, 0.14, 'L2')
    crystal(mb, 'crystal3', V(0, -0.56, 0.28), V(0, -0.76, 0.24), W_C, 0.16, 'L2', side=V(1, 0, 0), up=V(0, 0, 1))
    # ---- level 3 (mat 3) "Prism Sovereign": crystal crown, wing-fins, a great spine crystal
    mb.mat = 3
    cc = V(0, -0.8, 0.86)
    for k, (dx, ln) in enumerate(((-0.2, 0.18), (-0.1, 0.24), (0.0, 0.32), (0.1, 0.24), (0.2, 0.18))):
        base = cc + V(dx, 0.04 * abs(dx) * 4, -0.02)
        crystal(mb, 'crystal3', base, base + V(dx * 0.4, 0.06, ln), W_H, 0.08, 'L3')
    fb, ft = ATLAS.uv('fin', 0.5, 0.05), ATLAS.uv('fin', 0.5, 0.95)
    for x in (1, -1):
        for tip, wd in ((V(x * 1.15, 0.35, 1.1), 0.28), (V(x * 1.2, 0.55, 0.85), 0.22)):
            bipyramid(mb, V(x * 0.5, -0.1, 0.7), tip, V(0, 1, 0.3), V(0, -0.2, 1), wd, 0.05,
                      [W_C, W_C] + [W_C] * 4, fb, ft, 'L3', wide_at=0.35, ridge_at=0.35)
    crystal(mb, 'crystal3', V(0, -0.04, 0.8), V(0, 0.08, 1.5), W_C, 0.28, 'L3')
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


def _reg(name):
    y0, y1, x0, x1 = ATLAS.px(name)
    h, w = y1 - y0, x1 - x0
    v, u = np.mgrid[0:h, 0:w].astype(np.float32)
    return (y0, y1, x0, x1), v / h, u / w


def _indigo(level):
    if level == 3:
        return [(0, '0a0820'), (0.45, '241a6a'), (1, '5a48c8')]
    if level == 2:
        return [(0, '0c0e2a'), (0.5, '2a3290'), (1, '5c6ae0')]
    return [(0, '0c0a26'), (0.5, '2a2a80'), (1, '5656cc')]


def _plates(u, v, nu, nv, seed=0):
    """jagged armour plates: cell coordinates + a 0..1 distance to the plate seam."""
    gu, gv = u * nu, v * nv + 0.5 * np.floor(u * nu)     # staggered rows
    fu, fv = gu - np.floor(gu), gv - np.floor(gv)
    seam = np.minimum(np.minimum(fu, 1 - fu) * 1.4, np.minimum(fv, 1 - fv))
    return seam, fv


def paint_atlas(level):
    col = np.zeros((TS, TS, 3), np.float32)
    hgt = np.full((TS, TS), 0.5, np.float32)
    rgh = np.full((TS, TS), 0.5, np.float32)
    glow = np.zeros((TS, TS), np.float32)
    ind = _indigo(level)
    cd, cm, ch = CRYSTAL[level]
    # ---- skin + head: indigo, near-black belly, jagged lighter armour plates on the back with dark seams and
    # glowing crystal-vein cracks; u 0 = top seam (back), 0.5 = belly
    for reg, nu, nv in (('skin', 12, 6), ('head', 8, 4)):
        (y0, y1, x0, x1), v, u = _reg(reg)
        h, w = y1 - y0, x1 - x0
        top = np.cos(u * 2 * math.pi)                          # +1 on the back, -1 on the belly
        c = grad(np.clip(0.5 + 0.45 * top, 0, 1), ind)
        belly = ss(-0.05, -0.35, top + 0.08 * _saw(v * 18))
        c = c * (1 - 0.7 * belly[..., None]) + hx('08061a') * (0.7 * belly[..., None])
        seam, fv = _plates(u, v, nu, nv)
        armour = ss(-0.25, 0.05, top - 0.25 * _saw(v * 14))
        plate_lit = grad(np.clip(0.55 + 0.4 * fv, 0, 1), [(0, ind[1][1]), (1, '8a8cf0' if level < 3 else '9a84f0')])
        edge = ss(0.06, 0.02, seam)
        c = c * (1 - armour[..., None]) + (plate_lit * (1 - 0.75 * edge[..., None]) + hx('0a0820') * 0.0) * armour[..., None]
        # crystal veins: thin glowing cracks along a few seams
        vein = ss(0.02, 0.0, seam - 0.006) * armour * (_saw(u * 3 + v * 2) > 0.7)
        c = c * (1 - vein[..., None]) + hx(cm) * vein[..., None]
        gr = _pgrain(h, w, 31)
        col[y0:y1, x0:x1] = c * (1 + 0.07 * gr[..., None])
        rgh[y0:y1, x0:x1] = 0.55 - 0.2 * armour
        hgt[y0:y1, x0:x1] = 0.5 + 0.35 * armour * (1 - edge) - 0.25 * edge * armour + 0.1 * gr
        glow[y0:y1, x0:x1] = vein * (0.7 + 0.3 * (level >= 2))
    # ---- legs: indigo, armour bands, near-black feet
    (y0, y1, x0, x1), v, u = _reg('limb')
    band = ss(0.03, 0.0, np.abs(v - (0.35 + 0.05 * _saw(u * 6))) - 0.05)
    feet = ss(0.0, 0.03, v - (0.78 + 0.06 * _saw(u * 8)))
    c = grad(np.clip(0.75 - 0.4 * v, 0, 1), ind)
    c = c * (1 - band[..., None]) + grad(v, [(0, '7a7ce8'), (1, '4a4cc0')]) * band[..., None]
    col[y0:y1, x0:x1] = c * (1 - feet[..., None]) + hx('0a0818') * feet[..., None]
    rgh[y0:y1, x0:x1] = 0.5
    hgt[y0:y1, x0:x1] = 0.5 + 0.3 * band
    # ---- tail: indigo with armour rings, darker to the tip
    (y0, y1, x0, x1), v, u = _reg('tail')
    ring = 0.5 + 0.5 * np.cos(v * 2 * math.pi * 5)
    col[y0:y1, x0:x1] = grad(np.clip(0.8 - 0.5 * v, 0, 1), ind) * (0.75 + 0.35 * ring[..., None])
    hgt[y0:y1, x0:x1] = 0.5 + 0.3 * ring
    # ---- jaw: near-black with a pale fang row at the top edge
    (y0, y1, x0, x1), v, u = _reg('jaw')
    col[y0:y1, x0:x1] = grad(v, [(0, '1a1640'), (1, '08061a')])
    # ---- crystals: dark root, saturated body, white-hot tip, facet stripes; glowing
    for reg, lv in (('crystal', min(level, 2) if level < 3 else 1), ('crystal3', level)):
        (y0, y1, x0, x1), v, u = _reg(reg)
        d_, m_, h_ = CRYSTAL[lv] if reg == 'crystal3' else CRYSTAL[1 if level == 1 else 2]
        facet = 0.5 + 0.5 * np.cos(u * 2 * math.pi * 3)
        c = grad(v, [(0, d_), (0.22, m_), (0.75, h_), (1, 'ffffff')]) * (0.92 + 0.14 * facet[..., None])
        col[y0:y1, x0:x1] = c
        rgh[y0:y1, x0:x1] = 0.08
        glow[y0:y1, x0:x1] = 0.75 + 0.25 * v
    # ---- gold armour: brushed gold with a dark engraved chevron
    (y0, y1, x0, x1), v, u = _reg('gold')
    eng = ss(0.02, 0.0, np.abs(np.abs(u - 0.5) * 0.8 - (v - 0.3) * 0.5) - 0.02) * (v > 0.3)
    c = grad(v, [(0, 'fff0a0'), (0.5, 'ffc23a'), (1, 'b8780a')])
    col[y0:y1, x0:x1] = c * (1 - 0.6 * eng[..., None])
    rgh[y0:y1, x0:x1] = 0.3
    glow[y0:y1, x0:x1] = 0.12 + 0.2 * (level >= 2)
    # ---- claws: crystal-tipped black
    (y0, y1, x0, x1), v, u = _reg('claw')
    t = ss(0.45, 0.85, v)
    col[y0:y1, x0:x1] = hx('0a0818') * (1 - t[..., None]) + hx(cm) * t[..., None]
    rgh[y0:y1, x0:x1] = 0.2
    glow[y0:y1, x0:x1] = t * (0.6 + 0.4 * (level >= 2))
    # ---- L3 wing-fins: violet prism membrane, glowing veins and edge
    (y0, y1, x0, x1), v, u = _reg('fin')
    veins = ss(0.012, 0.0, np.minimum.reduce([np.abs(u - k) for k in (0.25, 0.5, 0.75)]) - 0.004)
    ed = ss(0.0, 0.03, v - (0.82 + 0.08 * _saw(u * 6)))
    c = grad(v, [(0, '241a6a'), (0.6, 'b48cff'), (1, 'fff2ff')])
    col[y0:y1, x0:x1] = c * (1 - 0.3 * veins[..., None]) * (1 - ed[..., None]) + hx('ffffff') * ed[..., None]
    rgh[y0:y1, x0:x1] = 0.15
    glow[y0:y1, x0:x1] = np.clip(0.35 + 0.4 * v + veins * 0.3, 0, 1)
    paint_atlas._glow = np.clip(glow, 0, 1)
    return np.clip(col, 0, 1), hgt, rgh


def emissive_mask(level):
    paint_atlas(level)
    return np.repeat(paint_atlas._glow[..., None], 3, -1)


# ---------------------------------------------------------------- face decal (eyes, brows, snarl, marks)
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
    ix, iz, ox, oz = 0.08, 1.06, 0.3, 1.13
    ex, ez = ox - ix, oz - iz
    L = math.hypot(ex, ez)
    s = ((aX - ix) * ex + (Z - iz) * ez) / (L * L)
    d = (-(aX - ix) * ez + (Z - iz) * ex) / L
    sc = np.clip(s, 0, 1)
    top = 0.042 * np.clip(sc * 3.0, 0, 1) * (1 - sc ** 4) + 0.002
    bot = -0.03 * np.clip(np.sin(math.pi * sc), 0, 1) ** 0.9 - 0.001
    eye = ss(0.003, 0.0, np.maximum(d - top, bot - d)) * (s > 0) * (s < 1)
    cxs, czs = ix + 0.5 * ex, iz + 0.5 * ez
    rr = np.sqrt((aX - cxs) ** 2 + (Z - czs) ** 2)
    _face_layers.rr = rr
    iris = ss(0.065, 0.06, rr)
    slit = ss(0.007 * np.clip(1 - ((Z - czs) / 0.045) ** 2, 0, 1) + 0.0005, 0.0, np.abs(aX - cxs)) * ss(0.045, 0.041, rr)
    brow = np.maximum(_seg(aX, Z, (0.05, 1.1), (0.33, 1.2), 0.02, 0.008), _seg(aX, Z, (0.31, 1.19), (0.4, 1.25), 0.01, 0.001))
    lid = ss(0.007, 0.004, np.abs(d - top - 0.003)) * (s > -0.05) * (s < 1.02)
    # dark mask band around the eyes (pointed back), and crystal-glow streaks under the eyes
    zc = 1.1 + 0.05 * aX
    hh = 0.075 * np.clip(1 - (aX / 0.42) ** 2, 0, 1) + 0.005
    mask = ss(0.004, 0.0, np.abs(Z - zc) - hh) * (aX < 0.43)
    mark = np.maximum(_seg(aX, Z, (0.24, 1.02), (0.3, 0.93), 0.012, 0.002), _seg(aX, Z, (0.33, 1.04), (0.38, 0.97), 0.008, 0.002))
    if level >= 2:
        mark = np.maximum(mark, _seg(aX, Z, (0.14, 1.26), (0.2, 1.34), 0.008, 0.002))
    if level >= 3:
        mark = np.maximum(mark, _seg(aX, Z, (0.02, 1.3), (0.0, 1.38), 0.012, 0.003))
    # a thin snarl line along the jaw with two fangs
    snarl = _seg(aX, Z, (0.0, 0.84), (0.2, 0.86), 0.007, 0.004)
    fang = np.zeros_like(X)
    for fx_ in (0.12,):
        fang = np.maximum(fang, ss(0.08, 0.0, np.abs(aX - fx_) / 0.016 + (0.85 - Z) / 0.05 - 1) * (Z < 0.85) * (Z > 0.8))
    return X, Z, eye, iris, slit, brow, lid, mask, mark, snarl, fang


def face_texture(level, size=512):
    X, Z, eye, iris, slit, brow, lid, mask, mark, snarl, fang = _face_layers(level, size)
    rr = _face_layers.rr
    ed, em, eh = EYE[level]
    cd, cm, ch = CRYSTAL[level]
    rgba = np.zeros((size, size, 4), np.float32)
    c = np.zeros((size, size, 3), np.float32) + hx('0a0820')
    c = c * (1 - mark[..., None]) + hx(cm) * mark[..., None]
    irisc = grad(np.clip(1 - rr / 0.06, 0, 1), [(0, ed), (0.45, em), (1, eh)])
    e = hx('0e0a14') * (1 - iris[..., None]) + irisc * iris[..., None]
    e = e * (1 - slit[..., None]) + hx('050308') * slit[..., None]
    c = c * (1 - eye[..., None]) + e * eye[..., None]
    ln = np.maximum.reduce([lid, brow, snarl])
    c = c * (1 - ln[..., None]) + hx('050410') * ln[..., None]
    c = c * (1 - fang[..., None]) + hx('eef4ff') * fang[..., None]
    rgba[..., :3] = c
    rgba[..., 3] = np.clip(np.maximum.reduce([mask * 0.85, eye, ln, mark, fang]), 0, 1)
    return rgba


def face_emissive(level, size=512):
    X, Z, eye, iris, slit, brow, lid, mask, mark, snarl, fang = _face_layers(level, size)
    g = np.clip(np.maximum(iris * eye * (1 - slit), mark * 0.9), 0, 1)
    return np.repeat(g[..., None], 3, -1)


# ---------------------------------------------------------------- animation (24 fps, in place, it walks)
# A heavy, watchful guardian: low prowling stance, head sweeping side to side, tail swaying its crystal club.
# Casts: Shield (Runner, the Ability clip) rears up on its hind legs and slams both forepaws down (the dome
# bursts up at the slam); Reach (Catcher) crouches, then lunges its head forward with the jaw thrown open (the
# crystal beam fires from its maw), then yanks back.
def _ease(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def _pulse(t, a, b):
    if t <= a or t >= b:
        return 0.0
    return math.sin(math.pi * (t - a) / (b - a))


def _legs(phase, swing, lift):
    """Diagonal gait: front-left with back-right."""
    pose = {}
    for s, x, off in (('L', 1, 0.0), ('R', -1, math.pi)):
        for pre, ph in (('Front', phase + off), ('Back', phase + off + math.pi)):
            sw = math.sin(ph) * swing
            lf = max(0.0, math.cos(ph)) * lift
            pose[pre + 'Upper.' + s] = P(('x', -sw))
            pose[pre + 'Lower.' + s] = P(('x', lf * (0.8 if pre == 'Front' else -0.8)))
            pose[pre + 'Foot.' + s] = P(('x', sw * 0.4))
    return pose


def _tail(w, amp, lift=0.0):
    return {'Tail1': P(('z', amp * math.sin(w)), ('x', -lift)), 'Tail2': P(('z', amp * 1.2 * math.sin(w - 0.7))),
            'Tail3': P(('z', amp * 1.4 * math.sin(w - 1.4)))}


def anim_idle():
    F = 72
    keys = {}
    for f in range(0, F + 1, 3):
        t = f / F
        w = 2 * math.pi * t
        look = math.sin(w)                                  # slow head sweep side to side
        snort = _pulse(t, 0.55, 0.68)
        k = {'Body': P(loc=(0, 0, 0.02 * math.sin(2 * w))), 'Chest': P(('x', 1.5 * math.sin(2 * w))),
             'Head': P(('z', 16 * look), ('x', 3 - 6 * snort)), 'Jaw': P(('x', 8 * snort))}
        k.update(_tail(w, 10))
        keys[f] = k
    keys[F] = dict(keys[0])
    return {'frames': F, 'loop': True, 'keys': keys}


def anim_walk():
    keys = {}
    for f in range(0, 25, 2):
        t = f / 24 * 2 * math.pi
        p = _legs(t, 24, 30)
        p['Body'] = P(('y', 3 * math.sin(t)), loc=(0, 0, 0.03 * abs(math.sin(t))))
        p['Head'] = P(('z', -4 * math.sin(t)), ('x', 4))
        p.update(_tail(t, 12))
        keys[f] = p
    keys[24] = keys[0]
    return {'frames': 24, 'loop': True, 'keys': keys}


def anim_run():
    """a heavy bound: forelegs reach, hind legs drive, the body rocks."""
    keys = {}
    for f in range(0, 17, 2):
        t = f / 16
        w = 2 * math.pi * t
        up = math.sin(w)
        p = {'Body': P(('x', -6 * up), loc=(0, 0, 0.08 + 0.12 * max(0, up))), 'Head': P(('x', 6 * up + 6)),
             'Chest': P(('x', 4 * up))}
        for s in 'LR':
            o = 0.3 if s == 'L' else 0.0
            p['FrontUpper.' + s] = P(('x', -40 * math.sin(w + o)))
            p['FrontLower.' + s] = P(('x', 30 * max(0, math.cos(w + o))))
            p['BackUpper.' + s] = P(('x', 38 * math.sin(w + o + 0.8)))
            p['BackLower.' + s] = P(('x', -30 * max(0, math.cos(w + o + 0.8))))
        p.update(_tail(w, 8, 12))
        keys[f] = p
    keys[16] = keys[0]
    return {'frames': 16, 'loop': True, 'keys': keys}


def anim_hop():
    keys = {}
    for f in range(0, 17, 2):
        t = f / 16
        upv = math.sin(math.pi * t)
        p = {'Body': P(('x', -8 * upv), loc=(0, 0, 0.25 * upv))}
        for s in 'LR':
            p['BackUpper.' + s] = P(('x', 30 * upv))
            p['FrontUpper.' + s] = P(('x', -25 * upv))
        keys[f] = p
    return {'frames': 16, 'loop': False, 'keys': keys}


def anim_ability():
    """Shield (~1 s): hunkers down under its shell with the head pulled in and the legs tucked, then heaves the whole
    shell up and slams it down (the dome rises at ~0.5), crystals rattling."""
    keys = {}
    F = 24
    for f in range(0, F + 1, 2):
        t = f / F
        tuck = _ease(t / 0.35) * (1 - _ease((t - 0.38) / 0.08))
        heave = math.sin(math.pi * min(1, max(0, (t - 0.38) / 0.14)))
        slam = _ease((t - 0.5) / 0.05) * (1 - _ease((t - 0.7) / 0.3))
        p = {'Body': P(('y', 4 * math.sin(t * 40) * slam), loc=(0, 0.0, -0.1 * tuck + 0.16 * heave - 0.04 * slam)),
             'Chest': P(('x', 4 * tuck)),
             'Head': P(('x', 14 * tuck - 10 * slam), loc=(0, 0.16 * tuck, 0)), 'Jaw': P(('x', 24 * slam))}
        for s_, x in (('L', 1), ('R', -1)):
            p['FrontUpper.' + s_] = P(('y', x * 25 * tuck - x * 10 * slam))
            p['BackUpper.' + s_] = P(('y', -x * 25 * tuck + x * 10 * slam))
        p.update(_tail(6 * t, 10, 15 * tuck))
        keys[f] = p
    return {'frames': F, 'loop': False, 'keys': keys}


def anim_reach():
    """Long Reach (~0.9 s, Catcher): crouches, lunges the head forward with the jaw thrown open (the beam fires),
    then yanks back hard."""
    keys = {}
    F = 22
    for f in range(0, F + 1, 1):
        t = f / F
        crouch = _ease(t / 0.3) * (1 - _ease((t - 0.3) / 0.1))
        lunge = _ease((t - 0.3) / 0.1) * (1 - _ease((t - 0.62) / 0.12))
        yank = _ease((t - 0.62) / 0.12) * (1 - _ease((t - 0.82) / 0.18))
        p = {'Body': P(('x', -4 * crouch - 4 * lunge + 6 * yank), loc=(0, 0.1 * crouch - 0.2 * lunge + 0.15 * yank, 0.0)),
             'Chest': P(('x', 3 * crouch - 6 * lunge)),
             'Head': P(('x', 4 * crouch - 18 * lunge - 10 * yank), loc=(0, -0.15 * lunge, 0)),
             'Jaw': P(('x', 40 * lunge + 15 * yank))}
        for s in 'LR':
            p['FrontUpper.' + s] = P(('x', -6 * crouch - 20 * lunge + 6 * yank))
            p['FrontLower.' + s] = P(('x', 10 * crouch))
            p['BackUpper.' + s] = P(('x', -10 * crouch + 15 * lunge))
            p['BackLower.' + s] = P(('x', 10 * crouch))
        p.update(_tail(6 * t, 6, 15 * lunge))
        keys[f] = p
    return {'frames': F, 'loop': False, 'keys': keys}


ANIMS = {'Idle': anim_idle, 'Walk': anim_walk, 'Run': anim_run, 'Hop': anim_hop, 'Ability': anim_ability,
         'Reach': anim_reach}
