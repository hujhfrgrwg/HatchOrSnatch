# Ring Imp (Rift, Common) for Hatch or Snatch: HOS-PET-017, built on the pet kit (docs/pets/Pet Pipeline Guide.md).
# Our own imp (NOT Hoopa). Pass 7 (17 Oct): Hunter wants anime / edgy, not a happy little imp. A sly, menacing teal
# imp: deep teal body with near-black accents, narrow slanted glowing slit-pupil eyes painted flush on a face decal
# shell inside a dark mask, angry brows, glowing cheek + forehead runes, a thin one-sided smirk with one fang, long
# swept-back horns with sharp gold tips, long pointed ears, tattered bat wings, clawed hands, a sharp arrow spade tail,
# and the magenta-to-cyan portal ring floating behind its back. L2: brighter runes, glowing claws, ring runes.
# L3: a second ring, sparks, a darker richer palette and magenta eyes.
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

NAME = 'Imp'
SHARP_ANGLE = 40
NORMAL_STRENGTH = 2.0
TS = 1024
ATLAS = Atlas({
    'skin': (0, 0, 1024, 512),      # body + head loft: u around (0 = back seam, 0.5 = front), v bottom -> top
    'limb': (0, 512, 512, 128),     # arms + legs: v shoulder/hip -> hand/foot
    'horn': (512, 512, 256, 128),   # v root -> tip
    'wing': (768, 512, 256, 128),
    'ring': (0, 640, 512, 128),     # the portal ring + bracelets + mini ring
    'tail': (512, 640, 256, 128),
    'gold': (768, 640, 256, 128),   # gold gems / star specks
    'mouth': (0, 768, 256, 128),    # (brows)
    'claw': (256, 768, 128, 128),
    'collar': (384, 768, 256, 128),
    'spade': (640, 768, 256, 128),
    'ear': (896, 768, 128, 128),
})

VIOLET = '1f9e9a'      # (names kept from the first draft; these are the teal body tones now)
VIOLET_HI = '58d8c8'
VIOLET_DK = '0c4a52'
LAV = 'f6e8cc'         # cream face mask + belly
LAV_HI = 'fff6e4'
CYAN = '3fe0ff'
GOLD = 'ffc83a'
GOLD_HI = 'fff2b0'
GOLD_DK = 'c98a10'
MAGENTA = 'ff3fb0'
HORN = '3a3358'


# ---------------------------------------------------------------- skeleton
def bones_def():
    b = [
        ('Root', V(0, 0, 0), V(0, 0, 0.2), None),
        ('Body', V(0, 0, 0.45), V(0, 0, 0.78), 'Root'),
        ('Head', V(0, 0, 0.8), V(0, 0, 1.35), 'Body'),
        ('Ring', V(0, 0.46, 0.98), V(0, 0.46, 1.3), 'Body'),
        ('Tail1', V(0, 0.2, 0.42), V(0, 0.48, 0.3), 'Body'),
        ('Tail2', V(0, 0.48, 0.3), V(0, 0.7, 0.36), 'Tail1'),
        ('Tail3', V(0, 0.7, 0.36), V(0, 0.88, 0.56), 'Tail2'),
    ]
    for s, x in (('L', 1), ('R', -1)):
        b += [
            ('Ear.' + s, V(x * 0.4, 0.04, 1.12), V(x * 0.8, 0.28, 1.28), 'Head'),
            ('Wing.' + s, V(x * 0.12, 0.17, 0.7), V(x * 0.55, 0.42, 0.9), 'Body'),
            ('Horn.' + s, V(x * 0.2, 0.02, 1.38), V(x * 0.5, 0.2, 1.3), 'Head'),
            ('ArmU.' + s, V(x * 0.22, -0.02, 0.68), V(x * 0.38, -0.08, 0.55), 'Body'),
            ('Hand.' + s, V(x * 0.38, -0.08, 0.55), V(x * 0.48, -0.13, 0.4), 'ArmU.' + s),
            ('Leg.' + s, V(x * 0.12, 0.0, 0.42), V(x * 0.15, -0.06, 0.2), 'Body'),
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


def _surface(tris, p, n):
    o = np.asarray(p, float) + np.asarray(n, float) * 1.2
    t = raycast(o, -np.asarray(n, float), tris)
    return None if t is None else o - np.asarray(n, float) * t


def conform_disc(mb, tris, c, n, r, w, segs, part, lift=0.008, uv_fn=None, uvc=None):
    n = nrm(np.asarray(n, float))
    up = nrm(V(0, 0, 1) - n * n[2])
    side = nrm(np.cross(up, n))
    cs = _surface(tris, c, n)
    cs = np.asarray(c, float) if cs is None else cs
    ring = []
    for k in range(segs):
        a = 2 * math.pi * k / segs
        q = cs + (side * math.cos(a) + up * math.sin(a)) * r
        s = _surface(tris, q, n)
        s = q if s is None else s
        ring.append((mb.vert(s + n * lift, w), uv_fn(a) if uv_fn else uvc))
    ci = mb.vert(cs + n * (lift + 0.004), w)
    for k in range(segs):
        k2 = (k + 1) % segs
        mb.face([ring[k][0], ring[k2][0], ci], [ring[k][1], ring[k2][1], uv_fn(None) if uv_fn else uvc],
                inside=cs - n * 0.4, part=part)


def torus(mb, region, c, normal, R, r, n_around, n_tube, w, part):
    """A ring: a loft around a circle (first station repeated to close it)."""
    normal = nrm(np.asarray(normal, float))
    a = nrm(np.cross(normal, V(0, 0, 1) if abs(normal[2]) < 0.9 else V(1, 0, 0)))
    b = np.cross(normal, a)
    cen = [np.asarray(c, float) + (a * math.cos(2 * math.pi * i / n_around) + b * math.sin(2 * math.pi * i / n_around)) * R
           for i in range(n_around + 1)]
    tube(mb, region, cen, [(r, r)] * len(cen), n_tube, [w] * len(cen), part, start='open', end='open',
         side_hint=normal, anti=False)



EYE_C = {1: V(0.17, -0.4, 1.15), -1: V(-0.17, -0.4, 1.15)}   # (kept for older tools; eyes are painted on the shell)
RING_C, RING_N, RING_R = V(0, 0.46, 0.98), V(0, 1, 0), 0.6
FX, FZ, FZH = 0.46, 1.13, 0.33          # face decal shell: model x half-width, z centre, z half-height -> face texture


def _vnormals(mb, faces):
    acc = {}
    for fi in faces:
        f = mb.F[fi]
        a, b, c = mb.V[f[0]], mb.V[f[1]], mb.V[f[2]]
        n = np.cross(b - a, c - a)
        for v in f:
            acc[v] = acc.get(v, np.zeros(3)) + n
    return {v: nrm(n) for v, n in acc.items()}


def face_shell(mb, body_faces, lift=0.009):
    """Guide section 6: a mat-1 decal shell = a copy of the head's front facets, lifted along smoothed normals, with
    the same weights, so the eyes / mask / runes / smirk are painted flush and follow the head in every frame."""
    sel = [fi for fi in body_faces if all(mb.V[v][1] < -0.04 and 0.78 < mb.V[v][2] < 1.46 for v in mb.F[fi])]
    vn = _vnormals(mb, body_faces)
    remap = {}
    for fi in sel:
        for v in mb.F[fi]:
            if v not in remap:
                p = mb.V[v]
                remap[v] = mb.vert(p + vn[v] * lift, dict(mb.W[v]))
    face_shell.src = dict(remap)             # shell vertex -> source vertex (eyes-flush check)
    for fi in sel:
        f = mb.F[fi]
        uvs = [(0.5 + mb.V[v][0] / (2 * FX), 0.5 + (mb.V[v][2] - FZ) / (2 * FZH)) for v in f]
        mb.face([remap[v] for v in f], uvs, part='faceshell')


def build():
    mb = MB()
    mb.mat = 0
    W_B, W_H = {'Body': 1}, {'Head': 1}
    # lean torso + an angular head (wide cheeks, narrow chin, tapering crown): not a round chibi ball
    st = [(0.32, (0.15, 0.13), W_B), (0.44, (0.2, 0.17), W_B), (0.58, (0.23, 0.19), W_B), (0.7, (0.16, 0.14), {'Body': 0.6, 'Head': 0.4}),
          (0.8, (0.2, 0.2), {'Body': 0.2, 'Head': 0.8}), (0.95, (0.4, 0.33), W_H), (1.12, (0.45, 0.37), W_H),
          (1.28, (0.4, 0.34), W_H), (1.41, (0.24, 0.22), W_H)]
    n0 = len(mb.F)
    tube(mb, 'skin', [V(0, 0, z) for z, _, _ in st], [r for _, r, _ in st], 16, [w for _, _, w in st], 'body',
         start='point', end='point', start_pt=V(0, 0.02, 0.24), end_pt=V(0, 0.04, 1.47), side_hint=V(1, 0, 0), th0=math.pi / 2)
    body_faces = list(range(n0, len(mb.F)))
    head_tris = tris_of(mb, {'body'})
    # collar: dark band, gold trim
    tube(mb, 'collar', [V(0, 0, 0.66), V(0, 0, 0.72), V(0, 0, 0.78)], [(0.2, 0.18), (0.215, 0.195), (0.22, 0.2)], 16,
         [W_B, W_B, {'Body': 0.5, 'Head': 0.5}], 'collar', start='flat', end='flat', side_hint=V(1, 0, 0), th0=math.pi / 2)
    # long pointed ears, swept back
    eb, et = ATLAS.uv('ear', 0.3, 0.8), ATLAS.uv('ear', 0.7, 0.1)
    for s, x in (('L', 1), ('R', -1)):
        bipyramid(mb, V(x * 0.38, 0.04, 1.12), V(x * 0.84, 0.3, 1.3), V(0, 0.3, 1), V(0, 1, 0), 0.2, 0.07,
                  {'Ear.' + s: 1}, eb, et, 'ear', wide_at=0.28, ridge_at=0.3)
    # long swept-back horns, near-black base, pointed gold tips (the tip continues along the last segment: no split)
    for s, x in (('L', 1), ('R', -1)):
        path = [V(x * 0.19, -0.02, 1.3), V(x * 0.24, 0.04, 1.5), V(x * 0.29, 0.18, 1.65), V(x * 0.33, 0.38, 1.74),
                V(x * 0.36, 0.58, 1.76)]
        d = nrm(path[-1] - path[-2])
        tube(mb, 'horn', path, [(0.12, 0.11), (0.1, 0.09), (0.075, 0.07), (0.05, 0.045), (0.028, 0.025)],
             8, [{'Horn.' + s: 1}] * len(path), 'horn', start='point', end='point', start_pt=V(x * 0.15, -0.06, 1.24),
             end_pt=path[-1] + d * 0.16, anti=False, side_hint=V(-1, 0, 0))   # -x: no frame flip as it sweeps back
    # brows: dark angular ridges slanting down toward the nose, so it glares out from under them
    bb, bt = ATLAS.uv('mouth', 0.5, 0.2), ATLAS.uv('mouth', 0.5, 0.8)
    for s, x in (('L', 1), ('R', -1)):
        pi_, po_ = V(x * 0.05, 0, 1.2), V(x * 0.31, 0, 1.31)
        qi = _surface(head_tris, pi_ + V(0, -0.6, 0), V(0, -1, 0))
        qo = _surface(head_tris, po_ + V(0, -0.6, 0), V(0, -1, 0))
        qi = V(pi_[0], -0.38, pi_[2]) if qi is None else qi
        qo = V(po_[0], -0.3, po_[2]) if qo is None else qo
        bipyramid(mb, qi + V(0, 0.01, 0), qo + V(0, 0.015, 0), V(0, 0, 1), V(0, -1, 0), 0.05, 0.06, W_H, bb, bt,
                  'brow', wide_at=0.45, ridge_at=0.45)
    # arms with three black claws each
    cb, ct = ATLAS.uv('claw', 0.5, 0.15), ATLAS.uv('claw', 0.5, 0.9)
    for s, x in (('L', 1), ('R', -1)):
        au, h = 'ArmU.' + s, 'Hand.' + s
        arm = [(V(x * 0.15, -0.01, 0.64), (0.085, 0.085), {'Body': 0.5, au: 0.5}), (V(x * 0.29, -0.05, 0.57), (0.075, 0.075), {au: 1}),
               (V(x * 0.38, -0.08, 0.5), (0.068, 0.068), {au: 0.5, h: 0.5}), (V(x * 0.44, -0.11, 0.42), (0.085, 0.08), {h: 1})]
        tube(mb, 'limb', [a[0] for a in arm], [a[1] for a in arm], 8, [a[2] for a in arm], 'arm' + s,
             start='point', end='point', start_pt=V(x * 0.08, 0.0, 0.66), end_pt=V(x * 0.47, -0.13, 0.36))
        for dx, dy in ((-0.045, -0.02), (0.0, -0.05), (0.045, -0.02)):
            b0 = V(x * (0.455 + dx), -0.13 + dy, 0.38)
            bipyramid(mb, b0, b0 + V(x * dx * 0.6, -0.06, -0.12), V(1, 0, 0), V(0, -1, 0), 0.035, 0.03, {h: 1}, cb, ct,
                      'claw', wide_at=0.3, ridge_at=0.3)
        lg = 'Leg.' + s
        leg = [(V(x * 0.09, 0.0, 0.38), (0.09, 0.09), {'Body': 0.5, lg: 0.5}), (V(x * 0.12, -0.02, 0.28), (0.08, 0.08), {lg: 1}),
               (V(x * 0.13, -0.06, 0.2), (0.085, 0.07), {lg: 1})]
        tube(mb, 'limb', [a[0] for a in leg], [a[1] for a in leg], 8, [a[2] for a in leg], 'leg' + s,
             start='point', end='point', start_pt=V(x * 0.05, 0.02, 0.44), end_pt=V(x * 0.14, -0.22, 0.13))
    # tattered bat wings: three pointed blades fanned from the upper back
    wb, wt = ATLAS.uv('wing', 0.5, 0.08), ATLAS.uv('wing', 0.5, 0.92)
    for s, x in (('L', 1), ('R', -1)):
        sh = V(x * 0.12, 0.17, 0.7)
        for tip, wd in ((V(x * 0.6, 0.44, 1.08), 0.17), (V(x * 0.66, 0.48, 0.84), 0.15), (V(x * 0.48, 0.44, 0.62), 0.12)):
            bipyramid(mb, sh, tip, V(0, 0, 1), V(0, 1, 0), wd, 0.03, [{'Body': 1}, {'Wing.' + s: 1}] + [{'Wing.' + s: 1}] * 4,
                      wb, wt, 'wing', wide_at=0.4, ridge_at=0.4)
    # thin tail, sharp arrow spade
    tp = [V(0, 0.16, 0.4), V(0, 0.42, 0.28), V(0, 0.68, 0.34), V(0, 0.86, 0.52)]
    tube(mb, 'tail', tp, [(0.05, 0.05), (0.042, 0.042), (0.036, 0.036), (0.03, 0.03)], 6,
         [{'Body': 0.4, 'Tail1': 0.6}, {'Tail1': 0.5, 'Tail2': 0.5}, {'Tail2': 0.5, 'Tail3': 0.5}, {'Tail3': 1}], 'tail',
         start='point', end='point', start_pt=V(0, 0.08, 0.42), end_pt=V(0, 0.89, 0.57))
    sb, stp = ATLAS.uv('spade', 0.3, 0.8), ATLAS.uv('spade', 0.7, 0.2)
    bipyramid(mb, V(0, 0.84, 0.5), V(0, 0.98, 0.82), V(0, 1, 0), V(0, 1, -0.3), 0.22, 0.04, {'Tail3': 1}, sb, stp,
              'spade', wide_at=0.28, ridge_at=0.28)
    # the portal ring: a halo floating behind its back
    torus(mb, 'ring', RING_C, RING_N, RING_R, 0.06, 22, 6, {'Ring': 1}, 'ring')
    # ---- face decal shell (mat 1): eyes, dark mask, runes and the smirk, all painted flush
    mb.mat = 1
    face_shell(mb, body_faces)
    # ---- level 2 (mat 2): gold bracelets + glowing runes on the halo
    mb.mat = 2
    for s, x in (('L', 1), ('R', -1)):
        torus(mb, 'ring', V(x * 0.42, -0.1, 0.46), V(x * 0.06, -0.03, 0.09), 0.075, 0.02, 10, 4, {'Hand.' + s: 1}, 'L2')
    gb, gt = ATLAS.uv('gold', 0.3, 0.8), ATLAS.uv('gold', 0.7, 0.2)
    for k in range(6):
        a = 2 * math.pi * (k + 0.5) / 6
        p = RING_C + V(math.cos(a), 0, math.sin(a)) * RING_R + V(0, -0.05, 0)
        bipyramid(mb, p, p + V(0, -0.1, 0), V(math.cos(a), 0, math.sin(a)), V(0, 0, 1), 0.08, 0.08, {'Ring': 1}, gb, gt,
                  'L2', wide_at=0.5, ridge_at=0.5)
    # ---- level 3 (mat 3): a second, smaller ring inside the halo + sparks
    mb.mat = 3
    torus(mb, 'ring', RING_C + V(0, 0.04, 0), V(0, 1, 0.3), 0.38, 0.035, 16, 4, {'Ring': 1}, 'L3')
    for p in (V(0.5, 0.3, 1.5), V(-0.56, 0.36, 1.36), V(0.62, 0.4, 0.66), V(-0.5, 0.42, 0.6)):
        bipyramid(mb, p, p + V(0, 0, 0.1), V(1, 0, 0), V(0, -1, 0), 0.07, 0.07, {'Ring': 1}, gb, gt, 'L3',
                  wide_at=0.5, ridge_at=0.5)
    mb.mat = 0
    return mb


# ---------------------------------------------------------------- painting
def _pgrain(h, w, seed):
    """grit made periodic across u (the tube seam), so no line shows at the back."""
    a = grit(h, 2 * w, seed)
    t = (np.arange(w, dtype=np.float32) / w)[None, :]
    return a[:, w:] * (1 - t) + a[:, :w] * t


def _fill(col, rgh, glow, region, colr, r, g=0.0):
    y0, y1, x0, x1 = ATLAS.px(region)
    col[y0:y1, x0:x1] = colr
    rgh[y0:y1, x0:x1] = r
    glow[y0:y1, x0:x1] = g


def _teal(level):
    if level == 3:
        return [(0, '031c22'), (0.5, '0a5a60'), (1, '1f9a94')]
    if level == 2:
        return [(0, '05262a'), (0.5, '0f6e6c'), (1, '2fb3a8')]
    return [(0, '06262a'), (0.5, '0e6664'), (1, '26a29a')]


def paint_atlas(level):
    col = np.zeros((TS, TS, 3), np.float32)
    hgt = np.full((TS, TS), 0.5, np.float32)
    rgh = np.full((TS, TS), 0.5, np.float32)
    glow = np.zeros((TS, TS), np.float32)
    teal = _teal(level)
    # skin: deep teal, top-lit, darker underside and back, light fur grain
    y0, y1, x0, x1 = ATLAS.px('skin')
    h, w = y1 - y0, x1 - x0
    v, u = np.mgrid[0:h, 0:w].astype(np.float32)
    u /= w; v = 1 - v / h
    front = np.cos((u - 0.5) * 2 * math.pi)
    c = grad(np.clip(0.15 + 0.7 * (1 - v) + 0.12 * front, 0, 1), teal)
    # a dark V marking down the chest
    chest = (np.abs(u - 0.5) < (0.035 + 0.25 * np.clip(v - 0.28, 0, 1)) * 0.6) & (v > 0.22) & (v < 0.36)
    c = np.where(chest[..., None], c * 0.45, c)
    gr = _pgrain(h, w, 11)
    col[y0:y1, x0:x1] = c * (1 + 0.1 * gr[..., None])
    rgh[y0:y1, x0:x1] = 0.55
    hgt[y0:y1, x0:x1] = 0.5 + 0.35 * gr
    # limbs: teal, near-black hands / feet
    y0, y1, x0, x1 = ATLAS.px('limb')
    h, w = y1 - y0, x1 - x0
    v = np.mgrid[0:h, 0:w][0].astype(np.float32) / h
    tipm = ss(0.66, 0.8, v)
    gr = _pgrain(h, w, 12)
    c = grad(np.clip(0.75 - 0.35 * v, 0, 1), teal)
    col[y0:y1, x0:x1] = (c * (1 - tipm[..., None]) + hx('0b1416') * tipm[..., None]) * (1 + 0.08 * gr[..., None])
    rgh[y0:y1, x0:x1] = 0.55
    hgt[y0:y1, x0:x1] = 0.5 + 0.3 * gr
    # horns: near-black, faint ridges, a short sharp gold tip
    y0, y1, x0, x1 = ATLAS.px('horn')
    h, w = y1 - y0, x1 - x0
    v = np.mgrid[0:h, 0:w][0].astype(np.float32) / h
    tip = ss(0.72, 0.84, v)
    ridges = 0.5 + 0.5 * np.cos(v * 2 * math.pi * 8)
    base = grad(v, [(0, '090c10'), (0.7, '1c2430')])
    col[y0:y1, x0:x1] = (base * (1 - 0.2 * ridges[..., None]) * (1 - tip[..., None]) +
                         grad(v, [(0.72, GOLD_DK), (0.9, GOLD), (1, GOLD_HI)]) * tip[..., None])
    rgh[y0:y1, x0:x1] = 0.4 - 0.2 * tip
    hgt[y0:y1, x0:x1] = 0.5 + 0.25 * ridges * (1 - tip)
    glow[y0:y1, x0:x1] = 0.5 * ss(0.85, 1.0, v)
    # brows (mouth region): near-black
    _fill(col, rgh, glow, 'mouth', hx('0a1012'), 0.4)
    # claws: black, glowing magenta tips from L2
    y0, y1, x0, x1 = ATLAS.px('claw')
    h, w = y1 - y0, x1 - x0
    v = np.mgrid[0:h, 0:w][0].astype(np.float32) / h
    t = ss(0.55, 0.9, v)
    hot = 1.0 if level >= 2 else 0.0
    col[y0:y1, x0:x1] = hx('0a0d10') * (1 - t[..., None] * hot) + grad(v, [(0, MAGENTA), (1, 'ffd0f0')]) * (t[..., None] * hot)
    rgh[y0:y1, x0:x1] = 0.3
    glow[y0:y1, x0:x1] = t * hot
    # bat wings: near-black membrane, teal edge, magenta tips
    y0, y1, x0, x1 = ATLAS.px('wing')
    h, w = y1 - y0, x1 - x0
    v = np.mgrid[0:h, 0:w][0].astype(np.float32) / h
    col[y0:y1, x0:x1] = grad(v, [(0, '070b0e'), (0.6, '0c2a2e'), (0.85, '13706e'), (1, MAGENTA)])
    rgh[y0:y1, x0:x1] = 0.45
    glow[y0:y1, x0:x1] = ss(0.88, 1.0, v) * (0.6 + 0.4 * (level >= 2))
    # the portal ring: magenta -> violet -> cyan around, white-hot inner face, glowing
    y0, y1, x0, x1 = ATLAS.px('ring')
    h, w = y1 - y0, x1 - x0
    vv, u = np.mgrid[0:h, 0:w].astype(np.float32)
    u /= w; vv /= h
    around = 0.5 - 0.5 * np.cos(vv * 2 * math.pi)
    hue = grad(around, [(0, MAGENTA), (0.5, '9a5cff'), (1, CYAN)])
    core = np.clip(np.cos((u - 0.5) * 2 * math.pi), 0, 1) ** 2
    col[y0:y1, x0:x1] = hue * (1 - 0.6 * core[..., None]) + 0.6 * core[..., None]
    rgh[y0:y1, x0:x1] = 0.15
    glow[y0:y1, x0:x1] = np.clip(0.8 + 0.2 * core + 0.1 * (level - 1), 0, 1)
    # tail, gold, spade (black with a glowing magenta edge), collar, ears
    y0, y1, x0, x1 = ATLAS.px('tail')
    h, w = y1 - y0, x1 - x0
    v = np.mgrid[0:h, 0:w][0].astype(np.float32) / h
    col[y0:y1, x0:x1] = grad(v, teal[::-1] if False else [(0, teal[1][1]), (1, '0b1416')])
    rgh[y0:y1, x0:x1] = 0.5
    _fill(col, rgh, glow, 'gold', hx(GOLD_HI), 0.2, 1.0)
    y0, y1, x0, x1 = ATLAS.px('spade')
    h, w = y1 - y0, x1 - x0
    v = np.mgrid[0:h, 0:w][0].astype(np.float32) / h
    col[y0:y1, x0:x1] = grad(1 - v, [(0, '0a0d10'), (0.55, '3a0a2a'), (1, MAGENTA)])
    rgh[y0:y1, x0:x1] = 0.25
    glow[y0:y1, x0:x1] = ss(0.6, 1.0, 1 - v)
    y0, y1, x0, x1 = ATLAS.px('ear')
    h, w = y1 - y0, x1 - x0
    v = np.mgrid[0:h, 0:w][0].astype(np.float32) / h
    col[y0:y1, x0:x1] = grad(1 - v, [(0, teal[1][1]), (0.75, teal[2][1]), (1, '0b1416')])
    rgh[y0:y1, x0:x1] = 0.5
    y0, y1, x0, x1 = ATLAS.px('collar')
    h, w = y1 - y0, x1 - x0
    v = np.mgrid[0:h, 0:w][0].astype(np.float32) / h
    trim = np.maximum(ss(0.22, 0.12, v), ss(0.78, 0.88, v))
    col[y0:y1, x0:x1] = hx('0a0f12') * (1 - trim[..., None]) + hx(GOLD) * trim[..., None]
    rgh[y0:y1, x0:x1] = 0.35
    glow[y0:y1, x0:x1] = trim * 0.3
    paint_atlas._glow = np.clip(glow, 0, 1)
    return np.clip(col, 0, 1), hgt, rgh


def emissive_mask(level):
    paint_atlas(level)
    g = paint_atlas._glow
    return np.repeat(g[..., None], 3, -1)


# ---------------------------------------------------------------- face decal (eyes, mask, runes, smirk)
def _seg(X, Z, a, b, w0, w1):
    """distance-field stroke from a to b, width tapering w0 -> w1 (model units). Returns coverage 0..1."""
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
    sgn = np.where(X >= 0, 1.0, -1.0)
    # eye frame: inner corner low by the nose, outer corner high (slants down toward the nose)
    ix, iz, ox, oz = 0.05, 1.115, 0.265, 1.17
    ex, ez = ox - ix, oz - iz
    L = math.hypot(ex, ez)
    s = ((aX - ix) * ex + (Z - iz) * ez) / (L * L)                 # 0 inner .. 1 outer
    d = (-(aX - ix) * ez + (Z - iz) * ex) / L                       # + up
    sc = np.clip(s, 0, 1)
    top = 0.044 * np.clip(sc * 3.5, 0, 1) * (1 - sc ** 4) + 0.002
    bot = -0.03 * np.clip(np.sin(math.pi * sc), 0, 1) ** 0.9 - 0.001
    inside = (s > 0) & (s < 1)
    eye = ss(0.003, 0.0, np.maximum(d - top, bot - d)) * inside
    # iris (glowing) + vertical slit pupil
    cxs = ix + 0.45 * ex
    czs = iz + 0.45 * ez - 0.002
    rr = np.sqrt((aX - cxs) ** 2 + (Z - czs) ** 2)
    iris = ss(0.075, 0.07, rr)                      # fills the almond, so the slanted lids shape the glow
    slit = ss(0.008 * np.clip(1 - ((Z - czs) / 0.05) ** 2, 0, 1) + 0.0005, 0.0, np.abs(aX - cxs)) * ss(0.05, 0.046, rr)
    # heavy upper lid line + a sharp flick past the outer corner
    lid = ss(0.007, 0.004, np.abs(d - top - 0.003)) * (s > -0.05) * (s < 1.02)
    flick = _seg(aX, Z, (ox - 0.01, oz + 0.004), (ox + 0.06, oz + 0.035), 0.008, 0.001)
    # dark mask band across both eyes, pointed at the outside
    zc = 1.15 + 0.11 * aX
    hh = 0.07 * np.clip(1 - (aX / 0.4) ** 2, 0, 1) + 0.006
    mask = ss(0.004, 0.0, np.abs(Z - zc) - hh) * (aX < 0.42)
    # runes: two chevron strokes on each cheek + a forehead diamond
    rune = np.maximum.reduce([
        _seg(aX, Z, (0.25, 1.06), (0.32, 1.0), 0.011, 0.003), _seg(aX, Z, (0.25, 1.06), (0.2, 1.0), 0.009, 0.003),
        _seg(aX, Z, (0.3, 0.98), (0.35, 0.93), 0.008, 0.002),
        ss(0.004, 0.0, aX / 0.03 + np.abs(Z - 1.33) / 0.065 - 1) * 1.0,
    ])
    # a thin one-sided smirk + one small fang on the smirk side
    smirk = np.maximum(_seg(X, Z, (-0.07, 0.935), (0.05, 0.93), 0.004, 0.005),
                       _seg(X, Z, (0.05, 0.93), (0.1, 0.952), 0.005, 0.002))
    fx_ = np.abs(X - 0.062) / 0.013 + (0.93 - Z) / 0.032
    fang = ss(0.08, 0.0, fx_ - 1) * (Z < 0.93) * (Z > 0.896)
    return X, Z, eye, iris, slit, lid, flick, mask, rune, smirk, fang


def _rune_col(level):
    return {1: ('22c8f0', 'a8f0ff'), 2: (CYAN, 'e8ffff'), 3: (MAGENTA, 'ffd8f0')}[level]


def face_texture(level, size=512):
    X, Z, eye, iris, slit, lid, flick, mask, rune, smirk, fang = _face_layers(level, size)
    rgba = np.zeros((size, size, 4), np.float32)
    teal = _teal(level)
    c = np.zeros((size, size, 3), np.float32) + hx('0a1a1c')                      # dark mask colour
    rc, rhi = _rune_col(level)
    core = ss(0.6, 1.0, rune) * 0.35
    c = c * (1 - rune[..., None]) + (hx(rc) * (1 - core[..., None]) + hx(rhi) * core[..., None]) * rune[..., None]
    sclera = hx('140a12')
    irisc = grad(np.clip((Z - (1.1)) / 0.07, 0, 1), [(0, 'ff9a1a'), (0.6, GOLD), (1, 'fff2a0')])
    if level == 3:
        irisc = grad(np.clip((Z - 1.11) / 0.05, 0, 1), [(0, 'c0105a'), (0.6, MAGENTA), (1, 'ffc0e8')])
    e = sclera * (1 - iris[..., None]) + irisc * iris[..., None]
    e = e * (1 - slit[..., None]) + hx('050304') * slit[..., None]
    c = c * (1 - eye[..., None]) + e * eye[..., None]
    ln = np.maximum(lid, flick)
    c = c * (1 - ln[..., None]) + hx('030506') * ln[..., None]
    c = c * (1 - smirk[..., None]) + hx('061012') * smirk[..., None]
    c = c * (1 - fang[..., None]) + hx('f4f0e8') * fang[..., None]
    rgba[..., :3] = c
    rgba[..., 3] = np.clip(np.maximum.reduce([mask, eye, ln, rune, smirk, fang]), 0, 1)
    return rgba


def face_emissive(level, size=512):
    X, Z, eye, iris, slit, lid, flick, mask, rune, smirk, fang = _face_layers(level, size)
    g = np.clip(np.maximum(iris * eye * (1 - slit), rune * (0.8 + 0.2 * (level >= 2))), 0, 1)
    return np.repeat(g[..., None], 3, -1)


# ---------------------------------------------------------------- animation (24 fps, in place, it floats)
def _spin(f, frames, turns=1.0):
    return 360.0 * turns * f / frames


def anim_idle():
    keys = {}
    for f in range(0, 49, 6):
        t = f / 48 * 2 * math.pi
        keys[f] = {'Body': P(loc=(0, 0, 0.05 * math.sin(t))),
                   'Head': P(('z', 6 * math.sin(t * 0.5)), ('x', -2 * math.sin(t))),
                   'Ring': P(('y', _spin(f, 48)), loc=(0, 0, 0.04 * math.sin(t + 1.2))),
                   'Wing.L': P(('y', 10 * math.sin(t * 2))), 'Wing.R': P(('y', -10 * math.sin(t * 2))),
                   'Tail1': P(('z', 10 * math.sin(t))), 'Tail2': P(('z', 12 * math.sin(t - 0.6))),
                   'Leg.L': P(('x', -6 * math.sin(t))), 'Leg.R': P(('x', 6 * math.sin(t)))}
    keys[48] = dict(keys[0])
    keys[48]['Ring'] = P(('y', 0), loc=(0, 0, 0.04 * math.sin(1.2)))
    return {'frames': 48, 'loop': True, 'keys': keys}


def _move(frames, lean, swing, flap):
    keys = {}
    for f in range(0, frames + 1, 2):
        t = f / frames * 2 * math.pi
        keys[f] = {'Body': P(('x', lean), loc=(0, 0, 0.04 * math.sin(2 * t))),
                   'Head': P(('x', -lean * 0.6)),
                   'ArmU.L': P(('x', -swing * math.sin(t))), 'ArmU.R': P(('x', swing * math.sin(t))),
                   'Leg.L': P(('x', swing * 0.8 * math.sin(t) + lean * 0.8)), 'Leg.R': P(('x', -swing * 0.8 * math.sin(t) + lean * 0.8)),
                   'Wing.L': P(('y', flap * math.sin(2 * t))), 'Wing.R': P(('y', -flap * math.sin(2 * t))),
                   'Tail1': P(('x', -lean * 0.8), ('z', 10 * math.sin(t))),
                   'Ring': P(('y', _spin(f, frames)), loc=(0, 0, 0.03 * math.sin(t)))}
    keys[frames] = dict(keys[0])
    keys[frames]['Ring'] = P(('y', 0), loc=(0, 0, 0))
    return {'frames': frames, 'loop': True, 'keys': keys}


def anim_walk():
    return _move(24, 10, 18, 14)


def anim_run():
    return _move(16, 22, 26, 24)


def anim_hop():
    keys = {}
    for f in range(0, 17, 2):
        upv = math.sin(math.pi * f / 16)
        keys[f] = {'Body': P(('x', -6 * upv), loc=(0, 0, 0.3 * upv)),
                   'ArmU.L': P(('y', -30 * upv)), 'ArmU.R': P(('y', 30 * upv)),
                   'Wing.L': P(('y', 25 * upv)), 'Wing.R': P(('y', -25 * upv)),
                   'Leg.L': P(('x', 20 * upv)), 'Leg.R': P(('x', 20 * upv))}
    return {'frames': 16, 'loop': False, 'keys': keys}


def anim_ability():
    """It swings the ring in front of itself, spins it, and steps through it (Portal Relocation / Blink)."""
    keys = {}
    F = 24
    for f in range(0, F + 1, 2):
        t = f / F
        bring = smooth(min(1.0, t / 0.3)) * (1 - smooth(max(0.0, (t - 0.8) / 0.2)))
        step = math.sin(math.pi * min(1.0, max(0.0, (t - 0.35) / 0.45)))
        keys[f] = {'Ring': P(('y', 720 * t if bring > 0 else 0), loc=(-0.74 * bring, -0.32 * bring, 0.32 * bring)),
                   'ArmU.L': P(('y', -50 * bring), ('x', -30 * bring)),
                   'ArmU.R': P(('y', 30 * bring)),
                   'Wing.L': P(('y', 30 * step)), 'Wing.R': P(('y', -30 * step)),
                   'Body': P(('x', 18 * step), loc=(0, -0.3 * step, 0.06 * step)),
                   'Head': P(('x', -8 * step))}
    return {'frames': F, 'loop': False, 'keys': keys}


ANIMS = {'Idle': anim_idle, 'Walk': anim_walk, 'Run': anim_run, 'Hop': anim_hop, 'Ability': anim_ability}
