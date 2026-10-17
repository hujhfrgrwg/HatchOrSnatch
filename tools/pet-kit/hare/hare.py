# Compass Hare (Rift, Rare) for Hatch or Snatch: HOS-PET-021, built on the pet kit (docs/pets/Pet Pipeline Guide.md).
# From the concept-library card (docs/pets/compass_hare/compass_hare_card.png): a white hare with very long blue-tipped
# ears, a big gold compass strapped to its flank, a blue scarf with a gem, a gold circlet and blue eyes, in a blue
# rift glow. Read through PET_LESSONS (anime / edgy): cold white fur with slate-grey jagged markings and fur strokes,
# deep-blue inner ears (no pink), narrow slanted glowing cyan slit eyes in a dark mask, a sly flat mouth (face decal
# shell). L2 "Wayfinder": a compass-needle crest, a glowing rune ring round the compass, a longer scarf tail.
# L3 "Star Navigator": gold astrolabe rings behind its back, star gems on the ears, violet-magenta runes and eyes.
# Reshaped 17 Oct (HOS-PET-RESHAPE): its own body plan, an upright hare sitting up on big haunches with long flat
# hind feet, the upper body tilted back 50 degrees (TILT, about PIVOT) so the head and very long ears stand high and
# the small forelegs are held up in front of the chest; it moves in hops.
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

NAME = 'Hare'
SHARP_ANGLE = 40
NORMAL_STRENGTH = 2.0
TS = 1024
ATLAS = Atlas({
    'skin': (0, 0, 1024, 384),      # body loft: u around (0 = top seam, 0.5 = belly), v tail end -> neck
    'head': (0, 384, 512, 256),     # head loft: u around, v skull -> nose
    'limb': (512, 384, 512, 128),   # legs: v hip / shoulder -> paw
    'ear': (512, 512, 256, 128),    # long ears: v root -> tip (front face = inner)
    'tail': (768, 512, 256, 128),
    'gold': (0, 640, 256, 128),     # compass rim, circlet, strap buckle, astrolabe
    'dial': (256, 640, 256, 256),   # compass face (planar, painted)
    'scarf': (512, 640, 256, 128),
    'gem': (768, 640, 128, 128),
    'claw': (896, 640, 128, 128),
    'strap': (0, 768, 256, 128),
    'rune': (512, 768, 256, 128),   # L2 / L3 glowing rune ring
})

GLOW = {1: ('1a6ad8', '5fd0ff', 'e6faff'), 2: ('1a6ad8', '6fe0ff', 'f0fdff'), 3: ('7a1ab8', 'd06aff', 'fff0ff')}
EYE = {1: ('0a5ab0', '4fd8ff', 'e8fbff'), 2: ('0a5ab0', '6fe6ff', 'f2feff'), 3: ('8a1ac0', 'e070ff', 'fff2ff')}


# ---------------------------------------------------------------- skeleton
TILT, PIVOT = math.radians(50), (0.0, 0.3, 0.45)


def _tilt(p):
    """Sit the upper body up: rotate about the hips so the front rises and the top leans back."""
    y, z = p[1] - PIVOT[1], p[2] - PIVOT[2]
    c, sn = math.cos(TILT), math.sin(TILT)
    return V(p[0], PIVOT[1] + y * c + z * sn, PIVOT[2] - y * sn + z * c)


def _rot(p, piv, ang, scale=1.0):
    """rotate about the x-axis line through piv (positive raises the front), optionally scaling toward piv."""
    y, z = p[1] - piv[1], p[2] - piv[2]
    c, sn = math.cos(ang), math.sin(ang)
    return V(p[0], piv[1] + (y * c + z * sn) * scale, piv[2] + (-y * sn + z * c) * scale)


NECK, SHOULDER = V(0, -0.36, 0.9), V(0, -0.24, 0.66)
HEAD_BONES = ('Head', 'Ear.L', 'Ear.R', 'EarTip.L', 'EarTip.R')
FORE_BONES = ('FrontUpper.L', 'FrontUpper.R', 'FrontLower.L', 'FrontLower.R')
HEAD_FIX, FORE_FIX = math.radians(-40), math.radians(-45)


def _settle(p, w):
    """After the sit-up tilt: bring the head level again and let the forelegs hang, by skin weight."""
    wh = sum(v for k, v in w.items() if k in HEAD_BONES)
    wf = sum(v for k, v in w.items() if k in FORE_BONES)
    if wh > 0:
        p = _rot(p, _tilt(NECK), HEAD_FIX * wh)
    if wf > 0:
        p = _rot(p, _tilt(SHOULDER), FORE_FIX * wf, 1 - 0.25 * wf)
    return p


def bones_def():
    b = [
        ('Root', V(0, 0, 0), V(0, 0, 0.2), None),
        ('Body', V(0, 0.3, 0.62), V(0, -0.1, 0.7), 'Root'),
        ('Chest', V(0, -0.1, 0.7), V(0, -0.36, 0.84), 'Body'),
        ('Head', V(0, -0.4, 0.96), V(0, -0.86, 1.0), 'Chest'),
        ('Compass', V(0.34, 0.12, 0.72), V(0.5, 0.12, 0.72), 'Body'),
        ('Tail', V(0, 0.58, 0.72), V(0, 0.72, 0.82), 'Body'),
        ('Astro', V(0, 0.24, 1.12), V(0, 0.24, 1.4), 'Body'),
    ]
    for s, x in (('L', 1), ('R', -1)):
        b += [
            ('Ear.' + s, V(x * 0.1, -0.5, 1.18), V(x * 0.16, -0.36, 1.62), 'Head'),
            ('EarTip.' + s, V(x * 0.16, -0.36, 1.62), V(x * 0.2, -0.28, 2.0), 'Ear.' + s),
            ('FrontUpper.' + s, V(x * 0.15, -0.26, 0.62), V(x * 0.16, -0.3, 0.32), 'Chest'),
            ('FrontLower.' + s, V(x * 0.16, -0.3, 0.32), V(x * 0.16, -0.36, 0.06), 'FrontUpper.' + s),
        ]
    b = [(n, _tilt(h), _tilt(t), p) for n, h, t, p in b]
    b = [(n, _settle(h, {n: 1}), _settle(t, {n: 1}), p) for n, h, t, p in b]
    for s, x in (('L', 1), ('R', -1)):
        b += [
            ('BackUpper.' + s, V(x * 0.24, 0.34, 0.5), V(x * 0.28, 0.16, 0.22), 'Body'),
            ('BackLower.' + s, V(x * 0.28, 0.16, 0.22), V(x * 0.28, 0.38, 0.08), 'BackUpper.' + s),
            ('BackFoot.' + s, V(x * 0.28, 0.38, 0.08), V(x * 0.28, -0.14, 0.04), 'BackLower.' + s),
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


def ring(mb, region, c, normal, R, r, n_around, n_tube, w, part, ry=None):
    normal = nrm(np.asarray(normal, float))
    a = nrm(np.cross(normal, V(0, 0, 1) if abs(normal[2]) < 0.9 else V(1, 0, 0)))
    b = np.cross(normal, a)
    ry = R if ry is None else ry
    cen = [np.asarray(c, float) + a * math.cos(2 * math.pi * i / n_around) * R + b * math.sin(2 * math.pi * i / n_around) * ry
           for i in range(n_around + 1)]
    tube(mb, region, cen, [(r, r)] * len(cen), n_tube, [w] * len(cen), part, start='open', end='open',
         side_hint=normal, anti=False)


def disc(mb, region, c, normal, R, segs, w, part, thick=0.02):
    """a flat round face (the compass dial), UV-mapped planar onto `region`."""
    normal = nrm(np.asarray(normal, float))
    a = nrm(np.cross(normal, V(0, 0, 1) if abs(normal[2]) < 0.9 else V(1, 0, 0)))
    b = np.cross(normal, a)
    c = np.asarray(c, float)
    ci = mb.vert(c + normal * thick, w)
    rim = [mb.vert(c + (a * math.cos(2 * math.pi * k / segs) + b * math.sin(2 * math.pi * k / segs)) * R, w)
           for k in range(segs)]
    uvc = ATLAS.uv(region, 0.5, 0.5)
    for k in range(segs):
        k2 = (k + 1) % segs
        u1 = ATLAS.uv(region, 0.5 + 0.48 * math.cos(2 * math.pi * k / segs), 0.5 - 0.48 * math.sin(2 * math.pi * k / segs))
        u2 = ATLAS.uv(region, 0.5 + 0.48 * math.cos(2 * math.pi * k2 / segs), 0.5 - 0.48 * math.sin(2 * math.pi * k2 / segs))
        mb.face([rim[k], rim[k2], ci], [u1, u2, uvc], inside=c - normal, part=part)


FX, FZ, FZH = 0.3, 1.0, 0.28


def _vnormals(mb, faces):
    acc = {}
    for fi in faces:
        f = mb.F[fi]
        a, b, c = mb.V[f[0]], mb.V[f[1]], mb.V[f[2]]
        n = np.cross(b - a, c - a)
        for v in f:
            acc[v] = acc.get(v, np.zeros(3)) + n
    return {v: nrm(n) for v, n in acc.items()}


def face_shell(mb, head_faces, lift=0.008):
    sel = [fi for fi in head_faces if all(mb.V[v][1] < -0.6 and 0.74 < mb.V[v][2] < 1.26 for v in mb.F[fi])]
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
    W_B, W_C, W_H = {'Body': 1}, {'Chest': 1}, {'Head': 1}
    # compact body, big round haunches, raised chest
    st = [(V(0, 0.58, 0.66), (0.16, 0.16), W_B), (V(0, 0.44, 0.64), (0.33, 0.33), W_B),
          (V(0, 0.2, 0.64), (0.34, 0.33), W_B), (V(0, -0.04, 0.68), (0.28, 0.3), {'Body': 0.5, 'Chest': 0.5}),
          (V(0, -0.24, 0.76), (0.25, 0.28), W_C), (V(0, -0.36, 0.88), (0.19, 0.21), {'Chest': 0.5, 'Head': 0.5})]
    tube(mb, 'skin', [s[0] for s in st], [s[1] for s in st], 14, [s[2] for s in st], 'body',
         start='point', end='point', start_pt=V(0, 0.66, 0.68), end_pt=V(0, -0.42, 0.96), side_hint=V(1, 0, 0),
         th0=math.pi / 2)
    # head: rounded skull, short blunt muzzle
    n0 = len(mb.F)
    hs = [(V(0, -0.36, 1.0), (0.17, 0.17), W_H), (V(0, -0.5, 1.02), (0.24, 0.22), W_H),
          (V(0, -0.66, 0.98), (0.21, 0.19), W_H), (V(0, -0.8, 0.92), (0.13, 0.12), W_H)]
    tube(mb, 'head', [h[0] for h in hs], [h[1] for h in hs], 12, [h[2] for h in hs], 'head',
         start='point', end='point', start_pt=V(0, -0.3, 1.0), end_pt=V(0, -0.88, 0.9), side_hint=V(1, 0, 0),
         th0=math.pi / 2)
    head_faces = list(range(n0, len(mb.F)))
    # very long ears, swept up and back, flattened (inner face forward)
    for s, x in (('L', 1), ('R', -1)):
        e, t = 'Ear.' + s, 'EarTip.' + s
        path = [V(x * 0.1, -0.46, 1.14), V(x * 0.14, -0.4, 1.42), V(x * 0.16, -0.36, 1.66), V(x * 0.19, -0.3, 1.88),
                V(x * 0.2, -0.26, 2.02)]
        tube(mb, 'ear', path, [(0.07, 0.04), (0.11, 0.05), (0.11, 0.05), (0.08, 0.04), (0.04, 0.025)], 8,
             [{e: 1}, {e: 1}, {e: 0.5, t: 0.5}, {t: 1}, {t: 1}], 'ear', start='point', end='point',
             start_pt=V(x * 0.08, -0.48, 1.06), end_pt=V(x * 0.21, -0.22, 2.1), side_hint=V(1, 0, 0), anti=False)
    # gold circlet across the brow with a point
    ring(mb, 'gold', V(0, -0.46, 1.08), V(0, 0.15, 1), 0.22, 0.022, 14, 4, W_H, 'gold', ry=0.25)
    bipyramid(mb, V(0, -0.66, 1.12), V(0, -0.66, 1.32), V(1, 0, 0), V(0, -1, 0), 0.1, 0.06, W_H,
              ATLAS.uv('gold', 0.4, 0.8), ATLAS.uv('gold', 0.6, 0.2), 'gold', wide_at=0.4, ridge_at=0.4)
    # blue scarf round the neck, a knot tail and a gem
    ring(mb, 'scarf', V(0, -0.32, 0.86), V(0, 0.55, -0.85), 0.2, 0.06, 12, 5, {'Chest': 0.5, 'Head': 0.5}, 'scarf', ry=0.22)
    bipyramid(mb, V(0.08, -0.46, 0.74), V(0.2, -0.5, 0.5), V(1, 0, 0), V(0, -1, 0), 0.14, 0.04, W_C,
              ATLAS.uv('scarf', 0.5, 0.1), ATLAS.uv('scarf', 0.5, 0.9), 'scarf', wide_at=0.4, ridge_at=0.4)
    bipyramid(mb, V(0, -0.5, 0.72), V(0, -0.58, 0.72), V(1, 0, 0), V(0, 0, 1), 0.09, 0.11, W_C,
              ATLAS.uv('gem', 0.5, 0.2), ATLAS.uv('gem', 0.5, 0.8), 'gem', wide_at=0.5, ridge_at=0.5)
    # the compass on the left flank: gold rim, painted dial, crown knob, and a strap round the body
    cc, cn = V(0.37, 0.18, 0.72), V(1, 0.1, 0.12)
    disc(mb, 'dial', cc, cn, 0.21, 16, {'Compass': 1}, 'dial')
    ring(mb, 'gold', cc, cn, 0.22, 0.045, 16, 5, {'Compass': 1}, 'gold')
    bipyramid(mb, cc + V(-0.02, -0.02, 0.2), cc + V(-0.02, -0.04, 0.34), V(1, 0, 0), V(0, -1, 0), 0.08, 0.08,
              {'Compass': 1}, ATLAS.uv('gold', 0.4, 0.8), ATLAS.uv('gold', 0.6, 0.2), 'gold', wide_at=0.5, ridge_at=0.5)
    ring(mb, 'strap', V(0, 0.2, 0.66), V(0, 1, 0.05), 0.355, 0.03, 14, 4, W_B, 'strap', ry=0.345)
    # legs: short front legs, long powerful hind legs with long feet
    for s, x in (('L', 1), ('R', -1)):
        fu, fl = 'FrontUpper.' + s, 'FrontLower.' + s
        front = [(V(x * 0.13, -0.24, 0.66), (0.09, 0.1), {'Chest': 0.6, fu: 0.4}), (V(x * 0.15, -0.28, 0.42), (0.065, 0.07), {fu: 1}),
                 (V(x * 0.16, -0.3, 0.3), (0.055, 0.055), {fu: 0.5, fl: 0.5}), (V(x * 0.16, -0.34, 0.12), (0.05, 0.05), {fl: 1}),
                 (V(x * 0.16, -0.39, 0.05), (0.065, 0.04), {fl: 1})]
        tube(mb, 'limb', [f[0] for f in front], [f[1] for f in front], 8, [f[2] for f in front], 'front' + s,
             start='point', end='point', start_pt=V(x * 0.06, -0.22, 0.7), end_pt=V(x * 0.16, -0.46, 0.04))
        for foot, bone in ((V(x * 0.16, -0.42, 0.05), fl),):
            for k in (-1, 0, 1):
                b0 = foot + V(k * 0.035, 0, 0)
                bipyramid(mb, b0, b0 + nrm(V(k * 0.3, -1, -0.3)) * 0.08, V(1, 0, 0), V(0, 0, 1), 0.03, 0.025, {bone: 1},
                          ATLAS.uv('claw', 0.5, 0.15), ATLAS.uv('claw', 0.5, 0.9), 'claw', wide_at=0.3, ridge_at=0.3)
    # fluffy tail: a tufted pom of three blades
    tube(mb, 'tail', [V(0, 0.56, 0.72), V(0, 0.66, 0.78), V(0, 0.74, 0.84)], [(0.1, 0.1), (0.13, 0.13), (0.08, 0.08)], 8,
         [{'Tail': 1}] * 3, 'tail', start='point', end='point', start_pt=V(0, 0.5, 0.7), end_pt=V(0, 0.8, 0.88))
    # ---- face decal shell (mat 1)
    mb.mat = 1
    face_shell(mb, head_faces)
    # ---- level 2 (mat 2) "Wayfinder": compass-needle crest, rune ring round the compass, longer scarf tail
    mb.mat = 2
    bipyramid(mb, V(0, -0.5, 1.2), V(0, -0.44, 1.5), V(1, 0, 0), V(0, -1, 0), 0.07, 0.05, W_H,
              ATLAS.uv('gold', 0.4, 0.8), ATLAS.uv('gold', 0.6, 0.2), 'L2', wide_at=0.3, ridge_at=0.3)
    bipyramid(mb, V(0, -0.5, 1.2), V(0, -0.58, 1.05), V(1, 0, 0), V(0, -1, 0), 0.06, 0.05, W_H,
              ATLAS.uv('rune', 0.5, 0.5), ATLAS.uv('rune', 0.5, 0.5), 'L2', wide_at=0.3, ridge_at=0.3)
    ring(mb, 'rune', cc + V(0.02, 0.0, 0.0), cn, 0.3, 0.018, 18, 4, {'Compass': 1}, 'L2')
    bipyramid(mb, V(-0.08, -0.44, 0.76), V(-0.28, -0.26, 0.5), V(1, 0, 0), V(0, -1, 0), 0.12, 0.035, W_C,
              ATLAS.uv('scarf', 0.5, 0.1), ATLAS.uv('scarf', 0.5, 0.9), 'L2', wide_at=0.4, ridge_at=0.4)
    # ---- level 3 (mat 3) "Star Navigator": astrolabe rings behind the back, star gems on the ears
    mb.mat = 3
    ac = V(0, 0.3, 1.2)
    ring(mb, 'gold', ac, V(0, 1, 0), 0.36, 0.025, 14, 3, {'Astro': 1}, 'L3')
    ring(mb, 'rune', ac, V(0.7, 0.3, 0.6), 0.28, 0.02, 12, 3, {'Astro': 1}, 'L3')
    ring(mb, 'rune', ac, V(-0.7, 0.3, 0.6), 0.28, 0.02, 12, 3, {'Astro': 1}, 'L3')
    for s, x in (('L', 1), ('R', -1)):
        p = V(x * 0.17, -0.36, 1.7)
        bipyramid(mb, p - V(0, 0.02, 0.06), p + V(0, -0.02, 0.12), V(1, 0, 0), V(0, -1, 0), 0.09, 0.09,
                  {'EarTip.' + s: 1}, ATLAS.uv('gem', 0.5, 0.2), ATLAS.uv('gem', 0.5, 0.8), 'L3', wide_at=0.5, ridge_at=0.5)
    # sit it up: tilt everything built so far about the hips
    for i in range(len(mb.V)):
        mb.V[i] = _settle(_tilt(mb.V[i]), mb.W[i])
    # big haunches on the ground with long flat hind feet
    mb.mat = 0
    for s, x in (('L', 1), ('R', -1)):
        bu, bl, bf = 'BackUpper.' + s, 'BackLower.' + s, 'BackFoot.' + s
        back = [(V(x * 0.2, 0.36, 0.52), (0.2, 0.24), {'Body': 0.6, bu: 0.4}), (V(x * 0.26, 0.24, 0.36), (0.19, 0.2), {bu: 1}),
                (V(x * 0.28, 0.18, 0.22), (0.12, 0.12), {bu: 0.5, bl: 0.5}), (V(x * 0.28, 0.34, 0.11), (0.08, 0.08), {bl: 1}),
                (V(x * 0.28, 0.36, 0.06), (0.08, 0.05), {bl: 0.3, bf: 0.7}), (V(x * 0.28, 0.1, 0.05), (0.085, 0.045), {bf: 1}),
                (V(x * 0.28, -0.1, 0.04), (0.075, 0.04), {bf: 1})]
        tube(mb, 'limb', [f[0] for f in back], [f[1] for f in back], 8, [f[2] for f in back], 'back' + s,
             start='point', end='point', start_pt=V(x * 0.1, 0.38, 0.58), end_pt=V(x * 0.28, -0.18, 0.04))
        foot = V(x * 0.28, -0.16, 0.05)
        for k in (-1, 0, 1):
            b0 = foot + V(k * 0.035, 0, 0)
            bipyramid(mb, b0, b0 + nrm(V(k * 0.3, -1, -0.3)) * 0.08, V(1, 0, 0), V(0, 0, 1), 0.03, 0.025, {bf: 1},
                      ATLAS.uv('claw', 0.5, 0.15), ATLAS.uv('claw', 0.5, 0.9), 'claw', wide_at=0.3, ridge_at=0.3)
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


WHITE = [(0, '8a92a8'), (0.5, 'd8dee8'), (1, 'f6f8fc')]
SLATE = '3a4258'


def paint_atlas(level):
    col = np.zeros((TS, TS, 3), np.float32)
    hgt = np.full((TS, TS), 0.5, np.float32)
    rgh = np.full((TS, TS), 0.6, np.float32)
    glow = np.zeros((TS, TS), np.float32)
    gd, gm, gh = GLOW[level]
    # ---- fur: cold white, fur strokes, slate jagged saddle on the back, slate stripes, glowing rift marks
    for reg in ('skin', 'head'):
        (y0, y1, x0, x1), v, u = _reg(reg)
        h, w = y1 - y0, x1 - x0
        top = np.cos(u * 2 * math.pi)
        c = grad(np.clip(0.55 + 0.35 * top, 0, 1), WHITE)
        saddle = ss(0.5, 0.62, top + 0.12 * _saw(v * 14 + u * 4)) * (ss(0.15, 0.3, v) if reg == 'skin' else ss(0.0, 0.2, 1 - v))
        c = c * (1 - 0.75 * saddle[..., None]) + hx(SLATE) * (0.75 * saddle[..., None])
        stripe = ss(0.03, 0.01, np.abs(_saw(v * 6 + 0.25) - 0.5) - 0.0) * ss(0.2, 0.0, np.abs(np.abs(u - 0.5) - 0.3)) * (reg == 'skin')
        c = c * (1 - 0.6 * stripe[..., None]) + hx(SLATE) * (0.6 * stripe[..., None])
        mark = ss(0.012, 0.0, np.abs(np.abs(u - 0.5) - (0.22 + 0.04 * _saw(v * 10))) - 0.004) * ss(0.25, 0.35, v) * ss(0.75, 0.65, v)
        mark = mark * (reg == 'skin') * (level >= 1)
        c = c * (1 - mark[..., None]) + hx(gm) * mark[..., None]
        st = _streaks(h, w, 170, 51)
        gr = _pgrain(h, w, 52)
        col[y0:y1, x0:x1] = c * (1 + 0.22 * st[..., None] + 0.05 * gr[..., None])
        hgt[y0:y1, x0:x1] = 0.5 + 0.45 * st + 0.1 * gr
        glow[y0:y1, x0:x1] = mark * (0.7 + 0.3 * (level >= 2))
    # ---- legs: white with slate jagged socks
    (y0, y1, x0, x1), v, u = _reg('limb')
    st = _streaks(y1 - y0, x1 - x0, 60, 53)
    sock = ss(0.0, 0.03, v - (0.7 + 0.08 * _saw(u * 8)))
    c = grad(np.clip(0.8 - 0.3 * v, 0, 1), WHITE) * (1 + 0.2 * st[..., None])
    col[y0:y1, x0:x1] = c * (1 - sock[..., None]) + hx('2a3044') * sock[..., None]
    hgt[y0:y1, x0:x1] = 0.5 + 0.4 * st
    # ---- ears: white back, deep-blue inner (front half of u), glowing blue jagged tips
    (y0, y1, x0, x1), v, u = _reg('ear')
    inner = ss(0.3, 0.38, np.cos(u * 2 * math.pi) * 0.5 + 0.5)   # ears use th0 = -pi/2: u 0 faces front
    tip = ss(0.0, 0.03, v - (0.72 + 0.08 * _saw(u * 6)))
    st = _streaks(y1 - y0, x1 - x0, 40, 54)
    c = grad(np.clip(0.7 + 0.2 * v, 0, 1), WHITE) * (1 + 0.15 * st[..., None])
    c = c * (1 - inner[..., None]) + grad(v, [(0, '0a1640'), (1, '1a3c90')]) * inner[..., None]
    col[y0:y1, x0:x1] = c * (1 - tip[..., None]) + grad(v, [(0.7, gd), (1, gm)]) * tip[..., None]
    glow[y0:y1, x0:x1] = tip * 0.8
    # ---- tail: white fluff
    (y0, y1, x0, x1), v, u = _reg('tail')
    st = _streaks(y1 - y0, x1 - x0, 40, 55)
    col[y0:y1, x0:x1] = grad(np.full_like(v, 0.9), WHITE) * (1 + 0.25 * st[..., None])
    # ---- gold
    (y0, y1, x0, x1), v, u = _reg('gold')
    ridges = 0.5 + 0.5 * np.cos(u * 2 * math.pi * 10)
    col[y0:y1, x0:x1] = grad(v, [(0, 'fff0a0'), (0.5, 'ffc23a'), (1, 'a8700a')]) * (0.85 + 0.2 * ridges[..., None])
    rgh[y0:y1, x0:x1] = 0.28
    glow[y0:y1, x0:x1] = 0.1
    # ---- compass dial: dark-blue glass, gold ticks, a glowing rift needle (L3 violet)
    (y0, y1, x0, x1), v, u = _reg('dial')
    X, Y = (u - 0.5) * 2, (v - 0.5) * 2
    R = np.sqrt(X ** 2 + Y ** 2)
    A = np.arctan2(Y, X)
    c = grad(np.clip(R, 0, 1), [(0, '1a3c8a'), (0.8, '0a1640'), (1, '060a20')])
    ticks = ss(0.02, 0.0, np.abs(_saw(A / (2 * math.pi) * 16) - 0) - 0.08) * ss(0.78, 0.82, R) * ss(0.95, 0.9, R)
    c = c * (1 - ticks[..., None]) + hx('ffd23a') * ticks[..., None]
    ang = math.radians(35)
    along = X * math.cos(ang) + Y * math.sin(ang)
    across = -X * math.sin(ang) + Y * math.cos(ang)
    needle = ss(0.02, 0.0, np.abs(across) - 0.07 * np.clip(1 - np.abs(along) / 0.75, 0, 1)) * (np.abs(along) < 0.75)
    north = needle * (along > 0)
    c = c * (1 - needle[..., None]) + (hx(gm) * north[..., None] + hx('d8dee8') * (needle - north)[..., None])
    rune = ss(0.015, 0.0, np.abs(R - 0.6) - 0.01) * (_saw(A / (2 * math.pi) * 24) > 0.4)
    c = c * (1 - rune[..., None]) + hx(gm) * rune[..., None]
    col[y0:y1, x0:x1] = c
    rgh[y0:y1, x0:x1] = 0.08
    glow[y0:y1, x0:x1] = np.clip(north + rune * 0.8 + ticks * 0.3, 0, 1)
    # ---- scarf: deep blue cloth, gold hem stripe
    (y0, y1, x0, x1), v, u = _reg('scarf')
    folds = 0.5 + 0.5 * np.cos(u * 2 * math.pi * 3)
    hem = ss(0.04, 0.0, np.abs(v - 0.85) - 0.03)
    c = grad(v, [(0, '1a3c9a'), (1, '0a1a58')]) * (0.8 + 0.25 * folds[..., None])
    col[y0:y1, x0:x1] = c * (1 - hem[..., None]) + hx('ffc23a') * hem[..., None]
    hgt[y0:y1, x0:x1] = 0.5 + 0.3 * folds
    # ---- gem, claws, strap, rune ring
    (y0, y1, x0, x1), v, u = _reg('gem')
    col[y0:y1, x0:x1] = grad(v, [(0, gh), (0.5, gm), (1, gd)])
    rgh[y0:y1, x0:x1] = 0.08
    glow[y0:y1, x0:x1] = 0.8
    (y0, y1, x0, x1), v, u = _reg('claw')
    t = ss(0.5, 0.9, v) * (1.0 if level >= 2 else 0.0)
    col[y0:y1, x0:x1] = hx('1a1e2a') * (1 - t[..., None]) + hx(gm) * t[..., None]
    glow[y0:y1, x0:x1] = t
    (y0, y1, x0, x1), v, u = _reg('strap')
    col[y0:y1, x0:x1] = grad(v, [(0, '2a1e14'), (1, '4a3424')]) * (0.9 + 0.1 * np.cos(u * 2 * math.pi * 30)[..., None])
    (y0, y1, x0, x1), v, u = _reg('rune')
    glyph = (_saw(u * 30) > 0.5) * 1.0
    col[y0:y1, x0:x1] = hx(gm) * (0.7 + 0.3 * glyph[..., None])
    rgh[y0:y1, x0:x1] = 0.2
    glow[y0:y1, x0:x1] = 0.6 + 0.4 * glyph
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
    ix, iz, ox, oz = 0.05, 1.0, 0.18, 1.06
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
    iris = ss(0.045, 0.041, rr)
    slit = ss(0.005 * np.clip(1 - ((Z - czs) / 0.032) ** 2, 0, 1) + 0.0005, 0.0, np.abs(aX - cxs)) * ss(0.032, 0.028, rr)
    brow = np.maximum(_seg(aX, Z, (0.03, 1.04), (0.19, 1.11), 0.011, 0.005), _seg(aX, Z, (0.17, 1.1), (0.24, 1.15), 0.007, 0.001))
    lid = ss(0.006, 0.003, np.abs(d - top - 0.003)) * (s > -0.05) * (s < 1.02)
    zc = 1.03 + 0.05 * aX
    hh = 0.05 * np.clip(1 - (aX / 0.25) ** 2, 0, 1) + 0.004
    mask = ss(0.004, 0.0, np.abs(Z - zc) - hh) * (aX < 0.26)
    mark = _seg(aX, Z, (0.14, 0.96), (0.18, 0.9), 0.008, 0.002)
    if level >= 2:
        mark = np.maximum(mark, ss(0.004, 0.0, aX / 0.015 + np.abs(Z - 1.16) / 0.03 - 1))
    if level >= 3:
        mark = np.maximum(mark, _seg(aX, Z, (0.2, 0.98), (0.25, 0.93), 0.006, 0.002))
    mouth = np.maximum(_seg(X, Z, (-0.05, 0.82), (0.04, 0.825), 0.004, 0.004), _seg(X, Z, (0.04, 0.825), (0.075, 0.84), 0.004, 0.002))
    nose = ss(0.004, 0.0, aX / 0.03 + np.abs(Z - 0.875) / 0.016 - 1)
    return X, Z, eye, iris, slit, brow, lid, mask, mark, mouth, nose


def face_texture(level, size=512):
    X, Z, eye, iris, slit, brow, lid, mask, mark, mouth, nose = _face_layers(level, size)
    rr = _face_layers.rr
    ed, em, eh = EYE[level]
    gd, gm, gh = GLOW[level]
    rgba = np.zeros((size, size, 4), np.float32)
    c = np.zeros((size, size, 3), np.float32) + hx('1a2034')
    c = c * (1 - mark[..., None]) + hx(gm) * mark[..., None]
    irisc = grad(np.clip(1 - rr / 0.041, 0, 1), [(0, ed), (0.45, em), (1, eh)])
    e = hx('0a0c14') * (1 - iris[..., None]) + irisc * iris[..., None]
    e = e * (1 - slit[..., None]) + hx('020308') * slit[..., None]
    c = c * (1 - eye[..., None]) + e * eye[..., None]
    ln = np.maximum.reduce([lid, brow, mouth])
    c = c * (1 - ln[..., None]) + hx('0a0e1a') * ln[..., None]
    c = c * (1 - nose[..., None]) + hx('2a3044') * nose[..., None]
    rgba[..., :3] = c
    rgba[..., 3] = np.clip(np.maximum.reduce([mask * 0.8, eye, ln, mark, nose]), 0, 1)
    return rgba


def face_emissive(level, size=512):
    X, Z, eye, iris, slit, brow, lid, mask, mark, mouth, nose = _face_layers(level, size)
    g = np.clip(np.maximum(iris * eye * (1 - slit), mark * 0.9), 0, 1)
    return np.repeat(g[..., None], 3, -1)


# ---------------------------------------------------------------- animation (24 fps, in place, it hops)
# A watchful, sly hare: ears swivel independently, the nose twitches, a hind-foot thump, the compass needle ticks.
# It moves in hops: Walk = small hops, Run = long bounds. Casts: Portal (Runner, the Ability clip) rears up on its
# hind legs, flips the compass up and the portal opens; Blink (Catcher) crouches, then flings itself forward in a
# vanishing leap and lands.
def _ease(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def _pulse(t, a, b):
    if t <= a or t >= b:
        return 0.0
    return math.sin(math.pi * (t - a) / (b - a))


def anim_idle():
    F = 72
    keys = {}
    for f in range(0, F + 1, 3):
        t = f / F
        w = 2 * math.pi * t
        thump = _pulse(t, 0.62, 0.7)
        k = {'Body': P(loc=(0, 0, 0.01 * math.sin(2 * w))), 'Chest': P(('x', 2 * math.sin(2 * w))),
             'Head': P(('z', 14 * math.sin(w * 0.5)), ('x', -4 * _pulse(t, 0.3, 0.4))),
             'Ear.L': P(('x', 10 * math.sin(w + 0.5)), ('y', -8 * _pulse(t, 0.15, 0.3))),
             'Ear.R': P(('x', 10 * math.sin(w + 1.6)), ('y', 8 * _pulse(t, 0.45, 0.6))),
             'EarTip.L': P(('x', 12 * math.sin(w + 1.0))), 'EarTip.R': P(('x', 12 * math.sin(w + 2.1))),
             'BackFoot.L': P(('x', -25 * thump)), 'BackLower.L': P(('x', 15 * thump)),
             'Tail': P(('x', -10 * _pulse(t, 0.62, 0.72))), 'Compass': P(('x', 4 * math.sin(w))),
             'Astro': P(('z', 360 * t), loc=(0, 0, 0.03 * math.sin(w)))}
        keys[f] = k
    keys[F] = dict(keys[0])
    keys[F]['Astro'] = P(('z', 0), loc=(0, 0, 0))
    return {'frames': F, 'loop': True, 'keys': keys}


def _hop(frames, height, stretch):
    keys = {}
    for f in range(0, frames + 1, 1):
        t = f / frames
        air = math.sin(math.pi * t)
        push = _pulse(t, 0.0, 0.35)
        land = _pulse(t, 0.7, 1.0)
        k = {'Body': P(('x', -10 * push + 8 * land), loc=(0, 0, height * air)),
             'Head': P(('x', 6 * push - 4 * land)),
             'Ear.L': P(('x', 25 * air)), 'Ear.R': P(('x', 25 * air)),
             'EarTip.L': P(('x', 15 * air)), 'EarTip.R': P(('x', 15 * air)), 'Tail': P(('x', -12 * air))}
        for s in 'LR':
            k['BackUpper.' + s] = P(('x', stretch * push - 20 * land))
            k['BackLower.' + s] = P(('x', -stretch * 0.6 * push))
            k['BackFoot.' + s] = P(('x', stretch * 0.6 * air))
            k['FrontUpper.' + s] = P(('x', -stretch * 0.8 * air + 10 * land))
            k['FrontLower.' + s] = P(('x', 20 * air))
        keys[f] = k
    return {'frames': frames, 'loop': True, 'keys': keys}


def anim_walk():
    return _hop(16, 0.14, 30)


def anim_run():
    return _hop(12, 0.32, 50)


def anim_hop():
    a = _hop(16, 0.45, 45)
    a['loop'] = False
    return a


def anim_ability():
    """Portal (~1 s): rears up on its hind legs, forepaws high, flips the compass up and spins the needle (the
    portal opens at ~0.5), then drops back down."""
    keys = {}
    F = 24
    for f in range(0, F + 1, 2):
        t = f / F
        up = _ease(t / 0.35) * (1 - _ease((t - 0.75) / 0.25))
        flip = _ease((t - 0.3) / 0.2) * (1 - _ease((t - 0.8) / 0.2))
        k = {'Body': P(('x', -42 * up), loc=(0, 0.06 * up, 0.05 * up)), 'Chest': P(('x', -12 * up)),
             'Head': P(('x', 30 * up)), 'Compass': P(('y', -70 * flip), ('x', 720 * t * flip)),
             'Ear.L': P(('y', -20 * flip)), 'Ear.R': P(('y', 20 * flip)), 'Astro': P(('z', 540 * t))}
        for s, x in (('L', 1), ('R', -1)):
            k['FrontUpper.' + s] = P(('x', -50 * up), ('y', -x * 15 * flip))
            k['FrontLower.' + s] = P(('x', 40 * up))
            k['BackUpper.' + s] = P(('x', 38 * up))
            k['BackLower.' + s] = P(('x', -10 * up))
            k['BackFoot.' + s] = P(('x', -20 * up))
        keys[f] = k
    return {'frames': F, 'loop': False, 'keys': keys}


def anim_blink():
    """Blink (~0.75 s, Catcher): crouches low, ears flat, then flings itself forward in a long leap (it blinks at
    the top) and lands."""
    keys = {}
    F = 18
    for f in range(0, F + 1, 1):
        t = f / F
        crouch = _ease(t / 0.3) * (1 - _ease((t - 0.3) / 0.08))
        leap = _pulse(t, 0.32, 0.85)
        land = _pulse(t, 0.8, 1.0)
        k = {'Body': P(('x', 2 * crouch - 12 * leap + 4 * land), loc=(0, -0.3 * leap, 0.3 * leap)),
             'Head': P(('x', 10 * crouch + 8 * leap)),
             'Ear.L': P(('x', 50 * crouch + 40 * leap)), 'Ear.R': P(('x', 50 * crouch + 40 * leap)),
             'EarTip.L': P(('x', 20 * leap)), 'EarTip.R': P(('x', 20 * leap)), 'Tail': P(('x', -15 * leap))}
        for s in 'LR':
            k['BackUpper.' + s] = P(('x', -10 * crouch + 55 * leap))
            k['BackLower.' + s] = P(('x', 15 * crouch - 30 * leap))
            k['BackFoot.' + s] = P(('x', 40 * leap))
            k['FrontUpper.' + s] = P(('x', -6 * crouch - 55 * leap + 4 * land))
        keys[f] = k
    return {'frames': F, 'loop': False, 'keys': keys}


ANIMS = {'Idle': anim_idle, 'Walk': anim_walk, 'Run': anim_run, 'Hop': anim_hop, 'Ability': anim_ability,
         'Blink': anim_blink}
