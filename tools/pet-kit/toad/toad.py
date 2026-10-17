# Thunder Toad (Tempest, Common) for Hatch or Snatch: HOS-PET-016 rebuild on the pet kit (docs/pets/Pet Pipeline Guide.md).
# Reference: Hunter's Tempest card (docs/pets/concepts/thunder_toad_hunter_reference_2.png) first, then his model sheet.
# A long, low, crouched cobalt toad: broad head, big round yellow eyes under heavy brows, wide smile, cream throat and
# belly, star-burst lightning bolts on the back and limbs, yellow spikes down the spine and a crest at the back of the
# head, yellow cheek dots, chunky yellow toes. Glossy vinyl-toy finish; bolts, spikes, crest and toes glow.
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

NAME = 'Toad'
SHARP_ANGLE = 80
NORMAL_STRENGTH = 2.5
TS = 1024
ATLAS = Atlas({
    'skin': (0, 0, 1024, 448),       # body + head loft: u around (0 = belly seam, 0.5 = spine), v rear -> snout
    'jaw': (0, 448, 512, 192),       # cream lower jaw / throat
    'limb': (512, 448, 512, 192),    # all four legs: u around (0.25 / 0.75 = outer / inner side), v hip -> foot
    'brow': (0, 640, 256, 128),      # eye sockets + brows
    'yellow': (256, 640, 256, 128),  # spikes, crest, toes, gems (solid glowing yellow)
    'tail': (512, 640, 128, 128),
    'mouth': (640, 640, 128, 128),   # grin line + mouth inside
    'pad': (768, 640, 256, 128),     # toe pads
})

# palette (sheet + card)
BLUE = '2468ee'
BLUE_HI = '5aa0ff'
BLUE_DK = '1636a8'
NAVY = '1c2348'
CREAM = 'f7e7b0'
CREAM_HI = 'fff6d2'
YEL = 'ffd93b'
YEL_HI = 'fff7c0'
YEL_DK = 'f0a810'

# ---------------------------------------------------------------- skeleton
def bones_def():
    b = [
        ('Root', V(0, 0, 0), V(0, 0, 0.2), None),
        ('Body', V(0, 0.4, 0.58), V(0, -0.1, 0.66), 'Root'),
        ('Chest', V(0, -0.1, 0.66), V(0, -0.55, 0.86), 'Body'),
        ('Head', V(0, -0.55, 0.9), V(0, -1.15, 1.1), 'Chest'),
        ('Jaw', V(0, -0.6, 0.6), V(0, -1.12, 0.7), 'Chest'),      # throat / belly sac (puffs on the croak)
        ('Tail', V(0, 0.82, 0.5), V(0, 1.08, 0.42), 'Body'),
    ]
    for s, x in (('L', 1), ('R', -1)):
        b += [
            ('FrontUpper.' + s, V(x * 0.42, -0.5, 0.64), V(x * 0.7, -0.66, 0.4), 'Chest'),
            ('FrontLower.' + s, V(x * 0.7, -0.66, 0.4), V(x * 0.76, -0.78, 0.14), 'FrontUpper.' + s),
            ('FrontFoot.' + s, V(x * 0.76, -0.78, 0.14), V(x * 0.8, -1.0, 0.06), 'FrontLower.' + s),
            ('BackUpper.' + s, V(x * 0.45, 0.4, 0.58), V(x * 0.96, 0.34, 0.42), 'Body'),
            ('BackLower.' + s, V(x * 0.96, 0.34, 0.42), V(x * 1.02, 0.1, 0.14), 'BackUpper.' + s),
            ('BackFoot.' + s, V(x * 1.02, 0.1, 0.14), V(x * 1.06, -0.14, 0.06), 'BackLower.' + s),
        ]
    return b


# ---------------------------------------------------------------- mesh helpers
def _cum(centers):
    c = [np.asarray(p, float) for p in centers]
    d = [0.0]
    for a, b in zip(c, c[1:]):
        d.append(d[-1] + float(np.linalg.norm(b - a)))
    return [x / max(d[-1], 1e-9) for x in d]


def tube(mb, region, centers, radii, n, weights, part, start='point', end='point', start_pt=None, end_pt=None,
         side_hint=None, anti=True, u_off=0.0):
    """Anti-prism loft (alternate rings turned half a step), bottom of the ring at k = 0 so the UV seam is on the
    underside; u = k / n (+u_off), v = arc length along the stations."""
    vv = _cum(centers)

    def profile(k, nn, a, b, i):
        th = -math.pi / 2 + 2 * math.pi * (k + (0.5 if (anti and i % 2) else 0.0)) / nn
        return a * math.cos(th), b * math.sin(th)

    def uvf(i, k, seg, fk):
        return ATLAS.uv(region, k / n + u_off, vv[i])
    return loft(mb, centers, radii, n, weights, uvf, part, start=start, end=end, profile=profile,
                start_pt=start_pt, end_pt=end_pt, side_hint=side_hint)


def solid(mb, region, a, b):
    return ATLAS.uv(region, a, b)


def _surface(tris, p, n):
    """Project p onto the surface along -n (ray from outside)."""
    o = np.asarray(p, float) + np.asarray(n, float) * 1.2
    t = raycast(o, -np.asarray(n, float), tris)
    return None if t is None else o - np.asarray(n, float) * t


def conform_disc(mb, tris, c, n, r, w, segs, uvc, part, lift=0.008, uv_fn=None, inside=None):
    """A decal disc that hugs the surface: ring verts projected onto the surface along n and lifted."""
    n = nrm(np.asarray(n, float))
    up = nrm(V(0, 0, 1) - n * n[2]) if abs(n[2]) < 0.95 else nrm(V(0, -1, 0) - n * n[1])
    side = nrm(np.cross(up, n))
    cs = _surface(tris, c, n)
    cs = c if cs is None else cs
    ring = []
    for k in range(segs):
        a = 2 * math.pi * k / segs
        q = cs + (side * math.cos(a) + up * math.sin(a)) * r
        s = _surface(tris, q, n)
        s = q if s is None else s
        ring.append((mb.vert(s + n * lift, w), uv_fn(a) if uv_fn else uvc))
    ci = mb.vert(cs + n * (lift + 0.004), w)
    ins = cs - n * 0.4 if inside is None else inside
    for k in range(segs):
        k2 = (k + 1) % segs
        mb.face([ring[k][0], ring[k2][0], ci], [ring[k][1], ring[k2][1], uv_fn(None) if uv_fn else uvc], inside=ins, part=part)
    return side, up


# ---------------------------------------------------------------- build
EYE_C = {1: V(0.28, -1.22, 1.32), -1: V(-0.28, -1.22, 1.32)}


def build():
    mb = MB()
    mb.mat = 0
    W_B, W_C, W_H = {'Body': 1}, {'Chest': 1}, {'Head': 1}
    # one connected body + neck + head loft: long low body rising to a tall, rounded, raised head
    st = [
        (V(0, 0.98, 0.5), (0.3, 0.24), W_B),
        (V(0, 0.76, 0.56), (0.6, 0.4), W_B),
        (V(0, 0.46, 0.62), (0.76, 0.48), W_B),
        (V(0, 0.12, 0.66), (0.74, 0.48), {'Body': 0.6, 'Chest': 0.4}),
        (V(0, -0.2, 0.74), (0.68, 0.48), W_C),
        (V(0, -0.5, 0.9), (0.62, 0.5), {'Chest': 0.4, 'Head': 0.6}),
        (V(0, -0.78, 1.06), (0.66, 0.56), W_H),
        (V(0, -1.02, 1.12), (0.62, 0.52), W_H),
        (V(0, -1.2, 1.08), (0.48, 0.4), W_H),
    ]
    tube(mb, 'skin', [s[0] for s in st], [s[1] for s in st], 14, [s[2] for s in st], 'body',
         start='point', end='point', start_pt=V(0, 1.06, 0.48), end_pt=V(0, -1.32, 1.04))
    # raised eye bumps on the front-top of the head (the eye decals sit flat on their fronts)
    for x in (1, -1):
        n = nrm(V(x * 0.28, -1.0, 0.18))
        c = EYE_C[x]
        tube(mb, 'brow', [c - n * 0.3, c - n * 0.14, c - n * 0.02], [(0.24, 0.24), (0.31, 0.3), (0.29, 0.28)], 12,
             [W_H] * 3, 'eyebump', start='point', end='point', start_pt=c - n * 0.34, end_pt=c + n * 0.03,
             side_hint=V(0, 0, 1))
    head_tris = tris_of(mb, {'body', 'eyebump'})
    # cream throat + belly: a big rounded bulge from the chin, down the chest, under the body
    bel = [(V(0, -1.1, 0.86), (0.5, 0.24), {'Head': 0.6, 'Jaw': 0.4}),
           (V(0, -0.98, 0.74), (0.56, 0.36), {'Jaw': 1}),
           (V(0, -0.72, 0.56), (0.6, 0.42), {'Jaw': 0.7, 'Chest': 0.3}),
           (V(0, -0.36, 0.44), (0.62, 0.38), {'Chest': 0.7, 'Jaw': 0.3}),
           (V(0, 0.04, 0.4), (0.6, 0.32), {'Chest': 0.4, 'Body': 0.6}),
           (V(0, 0.42, 0.42), (0.5, 0.26), W_B)]
    tube(mb, 'jaw', [b[0] for b in bel], [b[1] for b in bel], 12, [b[2] for b in bel], 'belly',
         start='point', end='point', start_pt=V(0, -1.08, 0.98), end_pt=V(0, 0.62, 0.46), side_hint=V(1, 0, 0))
    # legs: front straighter and planted (chest lifted), back splayed wide; buried in the body
    for s, x in (('L', 1), ('R', -1)):
        fu, fl, ff = 'FrontUpper.' + s, 'FrontLower.' + s, 'FrontFoot.' + s
        front = [(V(x * 0.36, -0.48, 0.7), (0.24, 0.26), {'Chest': 0.6, fu: 0.4}),
                 (V(x * 0.58, -0.6, 0.54), (0.24, 0.24), {fu: 1}),
                 (V(x * 0.7, -0.67, 0.38), (0.22, 0.22), {fu: 0.5, fl: 0.5}),
                 (V(x * 0.74, -0.74, 0.24), (0.2, 0.2), {fl: 1}),
                 (V(x * 0.77, -0.82, 0.14), (0.21, 0.16), {fl: 0.4, ff: 0.6}),
                 (V(x * 0.79, -0.94, 0.11), (0.24, 0.1), {ff: 1})]
        tube(mb, 'limb', [f[0] for f in front], [f[1] for f in front], 10, [f[2] for f in front], 'front' + s,
             start='point', end='point', end_pt=V(x * 0.8, -1.02, 0.1), start_pt=V(x * 0.18, -0.44, 0.74))
        bu, bl, bf = 'BackUpper.' + s, 'BackLower.' + s, 'BackFoot.' + s
        back = [(V(x * 0.42, 0.4, 0.6), (0.34, 0.36), {'Body': 0.6, bu: 0.4}),
                (V(x * 0.76, 0.38, 0.54), (0.36, 0.34), {bu: 1}),
                (V(x * 0.96, 0.32, 0.4), (0.3, 0.28), {bu: 0.5, bl: 0.5}),
                (V(x * 1.0, 0.18, 0.24), (0.21, 0.2), {bl: 1}),
                (V(x * 1.03, 0.04, 0.15), (0.21, 0.15), {bl: 0.4, bf: 0.6}),
                (V(x * 1.05, -0.1, 0.11), (0.24, 0.1), {bf: 1})]
        tube(mb, 'limb', [f[0] for f in back], [f[1] for f in back], 10, [f[2] for f in back], 'back' + s,
             start='point', end='point', end_pt=V(x * 1.06, -0.18, 0.1), start_pt=V(x * 0.2, 0.42, 0.62))
        # three chunky rounded yellow toe-claws per foot
        for foot, bone in ((V(x * 0.8, -0.98, 0.1), ff), (V(x * 1.06, -0.16, 0.1), bf)):
            for k in (-1, 0, 1):
                ang = math.radians(k * 34 + x * 10)
                dirv = nrm(V(x * 0.0 + math.sin(ang), -math.cos(ang), -0.05))
                base = foot + dirv * 0.03
                tip = base + dirv * 0.2
                tube(mb, 'pad', [base, base + dirv * 0.09, tip], [(0.105, 0.09), (0.11, 0.09), (0.085, 0.07)],
                     8, [{bone: 1}] * 3, 'pad', start='point', end='point', start_pt=base - dirv * 0.08,
                     end_pt=tip + dirv * 0.07, side_hint=V(0, 0, 1))
    # short tail nub
    tube(mb, 'tail', [V(0, 0.86, 0.5), V(0, 1.0, 0.46), V(0, 1.12, 0.4)], [(0.16, 0.13), (0.12, 0.1), (0.07, 0.06)],
         8, [{'Body': 0.5, 'Tail': 0.5}, {'Tail': 1}, {'Tail': 1}], 'tail', start='point', end='point',
         start_pt=V(0, 0.74, 0.52), end_pt=V(0, 1.2, 0.36))
    # the heavy brows are painted into the eye decal (a lid slanting down toward the nose)
    # the wide smile: a thin dark line conforming to the head where blue meets cream, curving up at the corners
    pts = []
    for i in range(9):
        t = -1 + 2 * i / 8
        p = V(t * 0.44, -1.2, 0.97 + 0.12 * t * t)
        n = nrm(V(t * 0.7, -1, 0.1))
        s_ = _surface(head_tris, p, n)
        pts.append((s_ if s_ is not None else p) + n * 0.012)
    tube(mb, 'mouth', pts, [(0.016, 0.01)] * len(pts), 4, [W_H] * len(pts), 'smile', start='flat', end='flat',
         side_hint=V(0, 0, 1), anti=False)
    # yellow cheek dots near each mouth corner
    for x in (1, -1):
        conform_disc(mb, head_tris, V(x * 0.42, -1.16, 1.06), nrm(V(x * 0.55, -0.8, 0.1)), 0.075, W_H, 8,
                     solid(mb, 'yellow', 0.5, 0.2), 'cheek')
    # spikes down the spine (chunky gems, rigid weights) + one big swept-back bolt horn as the head crest
    yb, yt = solid(mb, 'yellow', 0.3, 0.7), solid(mb, 'yellow', 0.6, 0.2)
    for (by, bz, ty, tz, wdt, ht, bone) in ((-0.2, 1.14, -0.04, 1.42, 0.3, 0.13, 'Chest'),
                                            (0.16, 1.06, 0.34, 1.32, 0.3, 0.13, 'Body'),
                                            (0.48, 1.0, 0.66, 1.2, 0.24, 0.11, 'Body'),
                                            (0.76, 0.86, 0.9, 1.02, 0.18, 0.09, 'Body')):
        bipyramid(mb, V(0, by, bz), V(0, ty, tz), V(1, 0, 0), V(0, 1, 0), wdt, ht, {bone: 1}, yb, yt, 'spike',
                  wide_at=0.35, ridge_at=0.3)
    # crest: a zig-zag bolt horn (two stacked gems, kinked) swept back from the top of the head
    bipyramid(mb, V(0, -0.72, 1.5), V(0, -0.5, 1.86), V(1, 0, 0), V(0, 1, 0), 0.36, 0.14, W_H, yb, yt, 'crest',
              wide_at=0.4, ridge_at=0.35)
    bipyramid(mb, V(0, -0.6, 1.72), V(0, -0.24, 1.98), V(1, 0, 0), V(0, 1, 0), 0.3, 0.12, W_H, yb, yt, 'crest',
              wide_at=0.3, ridge_at=0.3)
    # ---- face decal (mat 1): BIG round eyes set high on the front of the head, facing forward
    mb.mat = 1
    for x in (1, -1):
        n = nrm(V(x * 0.28, -1.0, 0.18))

        def uvf(a, x=x):
            if a is None:
                return (0.5, 0.5)
            return (0.5 + 0.48 * math.cos(a) * (1 if x > 0 else -1), 0.5 + 0.48 * math.sin(a))
        conform_disc(mb, head_tris, EYE_C[x], n, 0.25, W_H, 16, None, 'eye', lift=0.01, uv_fn=uvf)
    # ---- level 2 extras (mat 2): haunch spikes + a third crest kink
    mb.mat = 2
    for x in (1, -1):
        bipyramid(mb, V(x * 0.62, 0.46, 0.94), V(x * 0.84, 0.52, 1.16), V(0, 1, 0), V(x, 0, 1), 0.2, 0.1, W_B,
                  yb, yt, 'L2', wide_at=0.35, ridge_at=0.3)
    # ---- level 3 extras (mat 3): shoulder spikes + a star gem at the crest base
    mb.mat = 3
    for x in (1, -1):
        bipyramid(mb, V(x * 0.52, -0.3, 1.0), V(x * 0.74, -0.24, 1.24), V(0, 1, 0), V(x, 0, 1), 0.2, 0.1, W_C,
                  yb, yt, 'L3', wide_at=0.35, ridge_at=0.3)
    bipyramid(mb, V(0, -0.86, 1.52), V(0, -0.86, 1.74), V(1, 0, 0), V(0, -1, 0), 0.2, 0.2, W_H, yb, yt, 'L3',
              wide_at=0.5, ridge_at=0.5)
    mb.mat = 0
    return mb


# ---------------------------------------------------------------- painting
def _bolt_mask(h, w, cx, cy, sx, sy, rot=0.0):
    """A lightning-bolt polygon (pixel coords, cy down), filled in numpy (even-odd rule), 4x supersampled edge.
    Pure numpy: the module runs inside Blender, which has no PIL (pet-kit section 4)."""
    pts = [(-0.12, -0.66), (0.4, -0.66), (0.16, -0.16), (0.52, -0.18), (-0.24, 0.7), (-0.04, 0.16), (-0.46, 0.18)]
    c, s_ = math.cos(rot), math.sin(rot)
    poly = np.array([(cx + (x * c - y * s_) * sx, cy + (x * s_ + y * c) * sy) for x, y in pts], np.float32)
    x0, x1 = int(max(0, poly[:, 0].min() - 2)), int(min(w, poly[:, 0].max() + 3))
    y0, y1 = int(max(0, poly[:, 1].min() - 2)), int(min(h, poly[:, 1].max() + 3))
    out = np.zeros((h, w), np.float32)
    if x1 <= x0 or y1 <= y0:
        return out
    acc = np.zeros((y1 - y0, x1 - x0), np.float32)
    for oy in (0.125, 0.375, 0.625, 0.875):
        for ox in (0.125, 0.375, 0.625, 0.875):
            ys, xs = np.mgrid[y0:y1, x0:x1].astype(np.float32)
            xs += ox; ys += oy
            inside = np.zeros(xs.shape, bool)
            n = len(poly)
            for i in range(n):
                xa, ya = poly[i]; xb, yb = poly[(i + 1) % n]
                cond = ((ya > ys) != (yb > ys))
                xint = (xb - xa) * (ys - ya) / ((yb - ya) if yb != ya else 1e-9) + xa
                inside ^= cond & (xs < xint)
            acc += inside
    out[y0:y1, x0:x1] = acc / 16.0
    return out


def _disc(h, w, cx, cy, r, soft=1.5):
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.sqrt((xs - cx) ** 2 + (ys - cy) ** 2)
    return np.clip((r - d) / soft + 0.5, 0, 1)


def _regions():
    return {k: ATLAS.px(k) for k in ATLAS.R}


def paint_atlas(level):
    col = np.zeros((TS, TS, 3), np.float32)
    hgt = np.zeros((TS, TS), np.float32)
    rgh = np.full((TS, TS), 0.3, np.float32)
    glow = np.zeros((TS, TS), np.float32)
    sat = {1: 1.0, 2: 1.08, 3: 1.16}[level]
    R = _regions()
    # --- skin: cobalt, glossy, top-lit; cream belly; navy undersides; bolts + warts + cheek dots
    y0, y1, x0, x1 = R['skin']
    h, w = y1 - y0, x1 - x0
    v, u = np.mgrid[0:h, 0:w].astype(np.float32)
    u /= w; v /= h
    up = np.cos((u - 0.5) * 2 * math.pi)            # +1 spine, -1 belly
    blue = grad((up + 1) / 2, [(0.0, NAVY), (0.35, BLUE_DK), (0.65, BLUE), (1.0, BLUE_HI)])
    belly = ss(-0.2, -0.55, up) * ss(0.66, 0.8, v)     # under the head: cream, blending into the throat mesh
    c = blue * (1 - belly[..., None]) + grad(np.clip((up + 1) * 1.3, 0, 1), [(0, 'eadbb0'), (1, CREAM)]) * belly[..., None]
    marks = np.zeros((h, w), np.float32)
    # big star-burst bolts: down the back, on each flank, and on the top of the head
    marks = np.maximum(marks, _bolt_mask(h, w, 0.5 * w, 0.36 * h, 0.22 * w, 0.5 * h, 0.1))
    marks = np.maximum(marks, _bolt_mask(h, w, 0.28 * w, 0.42 * h, 0.12 * w, 0.32 * h, -0.3))
    marks = np.maximum(marks, _bolt_mask(h, w, 0.72 * w, 0.42 * h, 0.12 * w, 0.32 * h, 0.3))
    if level >= 2:
        marks = np.maximum(marks, _bolt_mask(h, w, 0.5 * w, 0.08 * h, 0.12 * w, 0.14 * h, -0.1))
    # warts on the back and flanks, cheek dots near the snout
    rng = np.random.default_rng(11)
    spots = np.zeros((h, w), np.float32)
    for uu, vv, rr in ((0.42, 0.12, 0.012), (0.58, 0.14, 0.011), (0.36, 0.7, 0.01), (0.64, 0.7, 0.01),
                       (0.24, 0.2, 0.011), (0.76, 0.2, 0.011)):
        spots = np.maximum(spots, _disc(h, w, uu * w, vv * h, rr * w))

    marks = np.maximum(marks, spots)
    ycol = grad(np.clip(marks, 0, 1), [(0, YEL_DK), (0.5, YEL), (0.97, YEL), (1.0, 'ffe866')])
    c = c * (1 - marks[..., None]) + ycol * marks[..., None]
    col[y0:y1, x0:x1] = c
    hgt[y0:y1, x0:x1] = marks * 0.25 + spots * 0.25
    rgh[y0:y1, x0:x1] = 0.25 * (1 - belly) + 0.4 * belly
    glow[y0:y1, x0:x1] = np.clip(marks * 1.2, 0, 1)
    # --- jaw: cream, a soft lower shade
    y0, y1, x0, x1 = R['jaw']
    h, w = y1 - y0, x1 - x0
    v, u = np.mgrid[0:h, 0:w].astype(np.float32)
    u /= w
    up = np.cos((u - 0.5) * 2 * math.pi)
    col[y0:y1, x0:x1] = grad((up + 1) / 2, [(0, 'e6cf92'), (0.55, CREAM), (1, 'fbeec4')])
    rgh[y0:y1, x0:x1] = 0.4
    # --- legs: blue with a bolt on the outer side, darker toward the feet
    y0, y1, x0, x1 = R['limb']
    h, w = y1 - y0, x1 - x0
    v, u = np.mgrid[0:h, 0:w].astype(np.float32)
    u /= w; v /= h
    up = np.cos((u - 0.5) * 2 * math.pi)
    lc = grad((up + 1) / 2 * (1 - 0.35 * v), [(0, NAVY), (0.4, BLUE_DK), (0.75, BLUE), (1, BLUE_HI)])
    lm = np.maximum(_bolt_mask(h, w, 0.25 * w, 0.4 * h, 0.13 * w, 0.52 * h, 0.1),
                    _bolt_mask(h, w, 0.75 * w, 0.4 * h, 0.13 * w, 0.52 * h, -0.1))
    lc = lc * (1 - lm[..., None]) + grad(lm, [(0, YEL_DK), (0.5, YEL), (1, YEL)]) * lm[..., None]
    col[y0:y1, x0:x1] = lc
    hgt[y0:y1, x0:x1] = lm * 0.3
    rgh[y0:y1, x0:x1] = 0.25
    glow[y0:y1, x0:x1] = lm
    # --- brows / sockets: blue, glossy, darker inside
    y0, y1, x0, x1 = R['brow']
    h, w = y1 - y0, x1 - x0
    v, u = np.mgrid[0:h, 0:w].astype(np.float32)
    u /= w; v /= h
    up = np.cos((u - 0.5) * 2 * math.pi)
    col[y0:y1, x0:x1] = grad((up + 1) / 2, [(0, BLUE_DK), (0.6, BLUE), (1, BLUE_HI)]) * (1 - 0.3 * v[..., None])
    rgh[y0:y1, x0:x1] = 0.2
    # --- yellow (spikes, crest): white-hot core falling off to yellow
    y0, y1, x0, x1 = R['yellow']
    h, w = y1 - y0, x1 - x0
    v, u = np.mgrid[0:h, 0:w].astype(np.float32)
    t = 1 - v / h
    col[y0:y1, x0:x1] = grad(t, [(0, YEL_DK), (0.45, YEL), (0.9, 'ffe866'), (1, YEL_HI)])
    rgh[y0:y1, x0:x1] = 0.18
    glow[y0:y1, x0:x1] = 0.6 + 0.4 * t
    # --- toe pads: yellow domes, glowing tips
    y0, y1, x0, x1 = R['pad']
    h, w = y1 - y0, x1 - x0
    v, u = np.mgrid[0:h, 0:w].astype(np.float32)
    v /= h
    col[y0:y1, x0:x1] = grad(v, [(0, YEL_DK), (0.45, YEL), (1, 'ffe866')])
    rgh[y0:y1, x0:x1] = 0.2
    glow[y0:y1, x0:x1] = 0.55 + 0.45 * v
    # --- tail
    y0, y1, x0, x1 = R['tail']
    col[y0:y1, x0:x1] = hx(BLUE)
    # --- mouth: dark navy-red
    y0, y1, x0, x1 = R['mouth']
    col[y0:y1, x0:x1] = hx('16308a')
    rgh[y0:y1, x0:x1] = 0.4
    # level saturation / brightness step
    if sat != 1.0:
        g = col.mean(-1, keepdims=True)
        col = np.clip(g + (col - g) * sat, 0, 1) * (1 + (sat - 1) * 0.5)
    paint_atlas._glow = np.clip(glow, 0, 1)
    return np.clip(col, 0, 1), hgt, rgh


def emissive_mask(level):
    paint_atlas(level)
    g = paint_atlas._glow
    return np.repeat(g[..., None], 3, -1)


LID_Y, LID_SLANT = 0.62, 0.95


def face_texture(level, size=512):
    """mat 1: one round eye (mirrored for the right eye): bright yellow iris fading to amber only at the rim, a
    large centred pupil looking straight ahead, a big highlight at the upper outer edge + a small one, and a short
    blue lid wedge clipping only the top INNER corner (the card's slight frown toward the nose; nose = -x)."""
    x, y = coords(size)
    r = np.sqrt(x * x + y * y)
    rgba = np.zeros((size, size, 4), np.float32)
    iris = grad(np.clip(r / 0.92, 0, 1), [(0, 'ffe45a'), (0.55, YEL), (0.85, 'f2b52a'), (1, 'd98a12')])
    c = iris
    pupil = ss(0.5, 0.47, r)
    c = c * (1 - pupil[..., None]) + hx('0d0d16') * pupil[..., None]
    for hx_, hy_, hr in ((0.2, 0.22, 0.17), (-0.17, -0.2, 0.07)):
        hl = ss(hr, hr * 0.75, np.sqrt((x - hx_) ** 2 + (y - hy_) ** 2))
        c = c * (1 - hl[..., None]) + hl[..., None]
    lid = ss(-0.02, 0.03, y - (LID_Y + LID_SLANT * x))
    c = c * (1 - lid[..., None]) + grad(np.clip(0.5 + y * 0.5, 0, 1), [(0, '1e55d8'), (1, '3a7af0')]) * lid[..., None]
    rim = ss(0.9, 0.93, r)
    c = c * (1 - rim[..., None]) + hx('0f1a40') * rim[..., None]
    rgba[..., :3] = c
    rgba[..., 3] = ss(1.0, 0.97, r)
    return rgba


# ---------------------------------------------------------------- animation (24 fps, in place)
def _legs(phase, swing, lift):
    """Diagonal gait: front-left with back-right."""
    pose = {}
    for s, x, off in (('L', 1, 0.0), ('R', -1, math.pi)):
        pf = phase + off
        pb = phase + off + math.pi
        for pre, ph in (('Front', pf), ('Back', pb)):
            sw = math.sin(ph) * swing
            lf = max(0.0, math.cos(ph)) * lift
            pose[pre + 'Upper.' + s] = P(('x', -sw), ('y', -x * lf * 0.5))
            pose[pre + 'Lower.' + s] = P(('x', lf * 0.6))
            pose[pre + 'Foot.' + s] = P(('x', sw * 0.5))
    return pose


def anim_idle():
    keys = {}
    for f in range(0, 49, 6):
        t = f / 48 * 2 * math.pi
        keys[f] = {'Body': P(loc=(0, 0, 0.015 * math.sin(t))),
                   'Chest': P(('x', 1.5 * math.sin(t))),
                   'Head': P(('z', 5 * math.sin(t * 0.5)), ('x', -2 * math.sin(t))),
                   'Jaw': P(loc=(0, -0.02 * max(0, math.sin(t * 2)), -0.01 * max(0, math.sin(t * 2)))),
                   'Tail': P(('z', 8 * math.sin(t)))}
    keys[48] = keys[0]
    return {'frames': 48, 'loop': True, 'keys': keys}


def anim_walk():
    keys = {}
    for f in range(0, 25, 2):
        t = f / 24 * 2 * math.pi
        p = _legs(t, 22, 22)
        p['Body'] = P(('y', 3 * math.sin(t)), loc=(0, 0, 0.03 * abs(math.sin(t))))
        p['Head'] = P(('z', -4 * math.sin(t)))
        p['Tail'] = P(('z', 10 * math.sin(t)))
        keys[f] = p
    keys[24] = keys[0]
    return {'frames': 24, 'loop': True, 'keys': keys}


def anim_run():
    """A bounding hop-run: back legs push together, the body arcs."""
    keys = {}
    for f in range(0, 17, 2):
        t = f / 16
        upv = math.sin(math.pi * t)
        p = {'Body': P(('x', -8 * upv + 4), loc=(0, 0, 0.28 * upv)), 'Head': P(('x', 5 * upv))}
        for s in 'LR':
            p['BackUpper.' + s] = P(('x', 30 * upv))
            p['BackLower.' + s] = P(('x', -20 * upv))
            p['FrontUpper.' + s] = P(('x', -14 * upv))
        keys[f] = p
    keys[16] = keys[0]
    return {'frames': 16, 'loop': True, 'keys': keys}


def anim_hop():
    keys = {}
    for f in range(0, 17, 2):
        t = f / 16
        upv = math.sin(math.pi * t)
        p = {'Body': P(('x', -10 * upv), loc=(0, 0, 0.45 * upv))}
        for s in 'LR':
            p['BackUpper.' + s] = P(('x', 35 * upv))
            p['FrontUpper.' + s] = P(('x', -18 * upv))
        keys[f] = p
    return {'frames': 16, 'loop': False, 'keys': keys}


def anim_ability():
    """The croak: rears back, head up, the jaw drops open, front legs brace wide (Shockwave / Electric Ball)."""
    keys = {}
    for f in range(0, 21, 2):
        t = f / 20
        rise = math.sin(math.pi * min(1.0, t * 1.4)) if t < 0.7 else max(0.0, 1 - (t - 0.7) / 0.3)
        rise = max(0.0, min(1.0, rise))
        p = {'Body': P(('x', -10 * rise), loc=(0, 0, 0.06 * rise)),
             'Head': P(('x', -14 * rise)),
             'Jaw': P(loc=(0, -0.1 * rise, -0.06 * rise))}
        for s, x in (('L', 1), ('R', -1)):
            p['FrontUpper.' + s] = P(('y', -x * 14 * rise), ('x', -10 * rise))
        keys[f] = p
    return {'frames': 20, 'loop': False, 'keys': keys}


ANIMS = {'Idle': anim_idle, 'Walk': anim_walk, 'Run': anim_run, 'Hop': anim_hop, 'Ability': anim_ability}
