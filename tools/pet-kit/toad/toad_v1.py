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
SHARP_ANGLE = 55
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
        ('Body', V(0, 0.35, 0.52), V(0, -0.15, 0.56), 'Root'),
        ('Chest', V(0, -0.15, 0.56), V(0, -0.5, 0.62), 'Body'),
        ('Head', V(0, -0.5, 0.66), V(0, -1.1, 0.72), 'Chest'),
        ('Jaw', V(0, -0.55, 0.5), V(0, -1.1, 0.46), 'Head'),
        ('Tail', V(0, 0.78, 0.46), V(0, 1.05, 0.38), 'Body'),
    ]
    for s, x in (('L', 1), ('R', -1)):
        b += [
            ('FrontUpper.' + s, V(x * 0.38, -0.42, 0.5), V(x * 0.78, -0.56, 0.36), 'Chest'),
            ('FrontLower.' + s, V(x * 0.78, -0.56, 0.36), V(x * 0.84, -0.74, 0.1), 'FrontUpper.' + s),
            ('FrontFoot.' + s, V(x * 0.84, -0.74, 0.1), V(x * 0.88, -0.98, 0.04), 'FrontLower.' + s),
            ('BackUpper.' + s, V(x * 0.42, 0.36, 0.5), V(x * 0.9, 0.26, 0.4), 'Body'),
            ('BackLower.' + s, V(x * 0.9, 0.26, 0.4), V(x * 0.96, 0.02, 0.1), 'BackUpper.' + s),
            ('BackFoot.' + s, V(x * 0.96, 0.02, 0.1), V(x * 1.0, -0.22, 0.04), 'BackLower.' + s),
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


# ---------------------------------------------------------------- build
def build():
    mb = MB()
    mb.mat = 0
    # one connected body + head loft (rear -> snout): long, low, crouched; broad head
    W_B, W_C, W_H = {'Body': 1}, {'Chest': 1}, {'Head': 1}
    stations = [
        (V(0, 0.92, 0.46), (0.3, 0.22), W_B),
        (V(0, 0.7, 0.52), (0.62, 0.38), W_B),
        (V(0, 0.4, 0.56), (0.78, 0.46), W_B),
        (V(0, 0.08, 0.58), (0.76, 0.47), {'Body': 0.6, 'Chest': 0.4}),
        (V(0, -0.24, 0.6), (0.72, 0.47), W_C),
        (V(0, -0.5, 0.66), (0.74, 0.48), {'Chest': 0.4, 'Head': 0.6}),
        (V(0, -0.74, 0.72), (0.8, 0.5), W_H),
        (V(0, -0.98, 0.72), (0.74, 0.45), W_H),
        (V(0, -1.16, 0.68), (0.56, 0.34), W_H),
    ]
    tube(mb, 'skin', [s[0] for s in stations], [s[1] for s in stations], 14, [s[2] for s in stations], 'body',
         start='point', end='point', start_pt=V(0, 1.0, 0.44), end_pt=V(0, -1.27, 0.64))
    # cream lower jaw / throat, buried into the head; it drops open on the croak
    jaw = [(V(0, -0.42, 0.46), (0.5, 0.24)), (V(0, -0.7, 0.44), (0.66, 0.3)), (V(0, -0.98, 0.48), (0.6, 0.26)),
           (V(0, -1.16, 0.54), (0.4, 0.17))]
    jw = [{'Chest': 0.5, 'Jaw': 0.5}, {'Jaw': 1}, {'Jaw': 1}, {'Jaw': 1}]
    tube(mb, 'jaw', [j[0] for j in jaw], [j[1] for j in jaw], 12, jw, 'jaw', start='point', end='point',
         start_pt=V(0, -0.3, 0.46), end_pt=V(0, -1.25, 0.57))
    # the wide smile: a thin dark band along the jaw line, curving up at the corners
    pts = []
    for i in range(9):
        t = -1 + 2 * i / 8
        x = t * 0.6
        pts.append(V(x, -1.06 + 0.42 * t * t, 0.6 + 0.09 * t * t))
    tube(mb, 'mouth', pts, [(0.018, 0.018)] * len(pts), 4, [W_H] * len(pts), 'smile', start='flat', end='flat',
         side_hint=V(0, 0, 1), anti=False)
    # eye sockets with heavy brows (blue), on the upper sides of the head
    for s, x in (('L', 1), ('R', -1)):
        c0 = V(x * 0.3, -0.84, 1.0)
        d = nrm(V(x * 0.62, -0.6, 0.5))
        tube(mb, 'brow', [c0, c0 + d * 0.12, c0 + d * 0.2], [(0.24, 0.24), (0.27, 0.26), (0.25, 0.24)], 12,
             [W_H] * 3, 'socket' + s, start='point', end='open', side_hint=V(0, 0, 1))
    # legs: buried in the body, chunky, elbows/knees out
    for s, x in (('L', 1), ('R', -1)):
        fu, fl, ff = 'FrontUpper.' + s, 'FrontLower.' + s, 'FrontFoot.' + s
        front = [(V(x * 0.36, -0.42, 0.52), (0.2, 0.22), {'Chest': 0.6, fu: 0.4}),
                 (V(x * 0.62, -0.5, 0.44), (0.22, 0.22), {fu: 1}),
                 (V(x * 0.78, -0.56, 0.34), (0.2, 0.2), {fu: 0.5, fl: 0.5}),
                 (V(x * 0.82, -0.66, 0.18), (0.17, 0.17), {fl: 1}),
                 (V(x * 0.85, -0.78, 0.08), (0.17, 0.12), {fl: 0.4, ff: 0.6}),
                 (V(x * 0.87, -0.92, 0.06), (0.2, 0.08), {ff: 1})]
        tube(mb, 'limb', [f[0] for f in front], [f[1] for f in front], 10, [f[2] for f in front], 'front' + s,
             start='point', end='point', end_pt=V(x * 0.88, -1.0, 0.05), start_pt=V(x * 0.2, -0.4, 0.55))
        bu, bl, bf = 'BackUpper.' + s, 'BackLower.' + s, 'BackFoot.' + s
        back = [(V(x * 0.4, 0.36, 0.54), (0.3, 0.32), {'Body': 0.6, bu: 0.4}),
                (V(x * 0.72, 0.32, 0.48), (0.32, 0.3), {bu: 1}),
                (V(x * 0.9, 0.24, 0.36), (0.26, 0.24), {bu: 0.5, bl: 0.5}),
                (V(x * 0.95, 0.1, 0.18), (0.18, 0.17), {bl: 1}),
                (V(x * 0.98, -0.04, 0.08), (0.17, 0.12), {bl: 0.4, bf: 0.6}),
                (V(x * 1.0, -0.18, 0.06), (0.2, 0.08), {bf: 1})]
        tube(mb, 'limb', [f[0] for f in back], [f[1] for f in back], 10, [f[2] for f in back], 'back' + s,
             start='point', end='point', end_pt=V(x * 1.01, -0.26, 0.05), start_pt=V(x * 0.22, 0.38, 0.56))
        # chunky yellow toe pads (3 front, 3 back), buried in the foot
        for foot, bone, fwd in ((V(x * 0.87, -0.96, 0.06), ff, -0.96), (V(x * 1.0, -0.22, 0.06), bf, -0.22)):
            for k in (-1, 0, 1):
                ang = math.radians(k * 32)
                dirv = nrm(V(x * math.sin(ang) * 0.9 + x * 0.25, -math.cos(ang), 0))
                base = foot + dirv * 0.05 + V(0, 0, 0.0)
                tip = base + dirv * 0.16
                tube(mb, 'pad', [base, base + dirv * 0.07, tip], [(0.075, 0.065), (0.085, 0.07), (0.065, 0.055)],
                     6, [{bone: 1}] * 3, 'pad', start='point', end='point', start_pt=base - dirv * 0.06,
                     end_pt=tip + dirv * 0.05 + V(0, 0, -0.01), side_hint=V(0, 0, 1))
    # short tail nub
    tube(mb, 'tail', [V(0, 0.82, 0.46), V(0, 0.98, 0.42), V(0, 1.1, 0.36)], [(0.16, 0.13), (0.12, 0.1), (0.07, 0.06)],
         8, [{'Body': 0.5, 'Tail': 0.5}, {'Tail': 1}, {'Tail': 1}], 'tail', start='point', end='point',
         start_pt=V(0, 0.7, 0.48), end_pt=V(0, 1.18, 0.32))
    # spikes down the spine and the crest at the back of the head (chunky gems, rigid weights)
    yb, yt = solid(mb, 'yellow', 0.3, 0.7), solid(mb, 'yellow', 0.6, 0.2)
    for (by, bz, ty, tz, wdt, ht, bone) in ((-0.5, 1.08, -0.38, 1.46, 0.34, 0.16, 'Head'),
                                            (-0.24, 1.02, -0.12, 1.3, 0.26, 0.13, 'Chest'),
                                            (0.06, 0.99, 0.18, 1.24, 0.24, 0.12, 'Body'),
                                            (0.36, 0.96, 0.48, 1.18, 0.22, 0.11, 'Body'),
                                            (0.64, 0.84, 0.76, 1.02, 0.18, 0.1, 'Body')):
        bipyramid(mb, V(0, by, bz), V(0, ty, tz), V(1, 0, 0), V(0, 1, 0), wdt, ht, {bone: 1}, yb, yt, 'spike',
                  wide_at=0.35, ridge_at=0.3)
    # crest side fins at the back of the head
    for x in (1, -1):
        bipyramid(mb, V(x * 0.2, -0.56, 1.06), V(x * 0.38, -0.42, 1.34), V(1, 0, 0), V(0, 1, 0), 0.2, 0.1,
                  {'Head': 1}, yb, yt, 'spike', wide_at=0.35, ridge_at=0.3)
    # ---- face decal (mat 1): flush round eyes, a disc just in front of each socket
    mb.mat = 1
    for s, x in (('L', 1), ('R', -1)):
        c0 = V(x * 0.3, -0.84, 1.0)
        d = nrm(V(x * 0.62, -0.6, 0.5))
        c = c0 + d * 0.205
        up = nrm(V(0, 0, 1) - d * d[2])
        side = nrm(np.cross(up, d))
        if x < 0:
            side = -side
        ring = []
        n = 14
        for k in range(n):
            a = 2 * math.pi * k / n
            p = c + (side * math.cos(a) + up * math.sin(a)) * 0.215
            ring.append((mb.vert(p, W_H), (0.5 + 0.48 * math.cos(a), 0.5 + 0.48 * math.sin(a))))
        ci = mb.vert(c + d * 0.012, W_H)
        for k in range(n):
            k2 = (k + 1) % n
            mb.face([ring[k][0], ring[k2][0], ci], [ring[k][1], ring[k2][1], (0.5, 0.5)], inside=c - d * 0.3, part='eye')
    # ---- level 2 extras (mat 2): taller crest + spike on each haunch
    mb.mat = 2
    bipyramid(mb, V(0, -0.62, 1.04), V(0, -0.58, 1.5), V(1, 0, 0), V(0, 1, 0), 0.2, 0.1, {'Head': 1}, yb, yt, 'L2',
              wide_at=0.35, ridge_at=0.3)
    for x in (1, -1):
        bipyramid(mb, V(x * 0.62, 0.42, 0.86), V(x * 0.84, 0.48, 1.1), V(0, 1, 0), V(x, 0, 1), 0.2, 0.1, {'Body': 1},
                  yb, yt, 'L2', wide_at=0.35, ridge_at=0.3)
    # ---- level 3 extras (mat 3): a glowing star gem on the crest and shoulder spikes
    mb.mat = 3
    bipyramid(mb, V(0, -0.42, 1.32), V(0, -0.3, 1.64), V(1, 0, 0), V(0, 1, 0), 0.22, 0.14, {'Head': 1}, yb, yt, 'L3',
              wide_at=0.4, ridge_at=0.35)
    for x in (1, -1):
        bipyramid(mb, V(x * 0.56, -0.3, 0.92), V(x * 0.78, -0.24, 1.18), V(0, 1, 0), V(x, 0, 1), 0.2, 0.1,
                  {'Chest': 1}, yb, yt, 'L3', wide_at=0.35, ridge_at=0.3)
    mb.mat = 0
    return mb


# ---------------------------------------------------------------- painting
def _bolt_mask(h, w, cx, cy, sx, sy, rot=0.0):
    """A star-burst lightning bolt polygon (pixel coords, cy down), filled with PIL, soft edge."""
    from PIL import Image, ImageDraw, ImageFilter
    pts = [(-0.18, -0.55), (0.2, -0.55), (0.04, -0.1), (0.36, -0.12), (-0.12, 0.6), (0.0, 0.12), (-0.32, 0.14)]
    c, s = math.cos(rot), math.sin(rot)
    poly = [(cx + (x * c - y * s) * sx, cy + (x * s + y * c) * sy) for x, y in pts]
    im = Image.new('L', (w, h), 0)
    ImageDraw.Draw(im).polygon(poly, fill=255)
    im = im.filter(ImageFilter.GaussianBlur(1.2))
    return np.asarray(im, np.float32) / 255


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
    belly = ss(-0.42, -0.62, up)                      # cream on the underside
    belly = np.maximum(belly, ss(0.84, 0.95, v) * ss(-0.05, -0.35, up))   # throat runs up the front
    c = blue * (1 - belly[..., None]) + grad(np.clip((up + 1) * 1.3, 0, 1), [(0, 'eadbb0'), (1, CREAM)]) * belly[..., None]
    c += grit(h, w, 3)[..., None] * 0.05
    marks = np.zeros((h, w), np.float32)
    # big star-burst bolts: down the back, on each flank, and on the top of the head
    marks = np.maximum(marks, _bolt_mask(h, w, 0.5 * w, 0.42 * h, 0.17 * w, 0.42 * h, 0.15))
    marks = np.maximum(marks, _bolt_mask(h, w, 0.29 * w, 0.48 * h, 0.1 * w, 0.32 * h, -0.2))
    marks = np.maximum(marks, _bolt_mask(h, w, 0.71 * w, 0.48 * h, 0.1 * w, 0.32 * h, 0.2))
    if level >= 2:
        marks = np.maximum(marks, _bolt_mask(h, w, 0.5 * w, 0.14 * h, 0.1 * w, 0.22 * h, -0.1))
    # warts on the back and flanks, cheek dots near the snout
    rng = np.random.default_rng(11)
    spots = np.zeros((h, w), np.float32)
    for _ in range(16):
        uu = rng.uniform(0.3, 0.7); vv = rng.uniform(0.1, 0.7)
        if abs(uu - 0.5) < 0.09 and 0.2 < vv < 0.65:
            continue
        spots = np.maximum(spots, _disc(h, w, uu * w, vv * h, rng.uniform(0.008, 0.013) * w))
    for uu in (0.33, 0.67):
        spots = np.maximum(spots, _disc(h, w, uu * w, 0.9 * h, 0.017 * w))
    marks = np.maximum(marks, spots)
    ycol = grad(np.clip(marks * 1.2, 0, 1), [(0, YEL_DK), (0.6, YEL), (1.0, YEL_HI)])
    c = c * (1 - marks[..., None]) + ycol * marks[..., None]
    col[y0:y1, x0:x1] = c
    hgt[y0:y1, x0:x1] = marks * 0.35 + spots * 0.3 + grit(h, w, 4) * 0.03
    rgh[y0:y1, x0:x1] = 0.22 * (1 - belly) + 0.5 * belly
    glow[y0:y1, x0:x1] = np.clip(marks * 1.2, 0, 1)
    # --- jaw: cream, a soft lower shade
    y0, y1, x0, x1 = R['jaw']
    h, w = y1 - y0, x1 - x0
    v, u = np.mgrid[0:h, 0:w].astype(np.float32)
    u /= w
    up = np.cos((u - 0.5) * 2 * math.pi)
    col[y0:y1, x0:x1] = grad((up + 1) / 2, [(0, 'e3cf98'), (0.6, CREAM), (1, CREAM_HI)]) + grit(h, w, 5)[..., None] * 0.03
    rgh[y0:y1, x0:x1] = 0.45
    # --- legs: blue with a bolt on the outer side, darker toward the feet
    y0, y1, x0, x1 = R['limb']
    h, w = y1 - y0, x1 - x0
    v, u = np.mgrid[0:h, 0:w].astype(np.float32)
    u /= w; v /= h
    up = np.cos((u - 0.5) * 2 * math.pi)
    lc = grad((up + 1) / 2 * (1 - 0.35 * v), [(0, NAVY), (0.4, BLUE_DK), (0.75, BLUE), (1, BLUE_HI)])
    lm = np.maximum(_bolt_mask(h, w, 0.25 * w, 0.42 * h, 0.09 * w, 0.42 * h, 0.1),
                    _bolt_mask(h, w, 0.75 * w, 0.42 * h, 0.09 * w, 0.42 * h, -0.1))
    lc = lc * (1 - lm[..., None]) + grad(lm, [(0, YEL_DK), (0.6, YEL), (1, YEL_HI)]) * lm[..., None]
    col[y0:y1, x0:x1] = lc + grit(h, w, 6)[..., None] * 0.04
    hgt[y0:y1, x0:x1] = lm * 0.3
    rgh[y0:y1, x0:x1] = 0.24
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
    col[y0:y1, x0:x1] = grad(t, [(0, YEL_DK), (0.5, YEL), (1, YEL_HI)])
    rgh[y0:y1, x0:x1] = 0.18
    glow[y0:y1, x0:x1] = 0.6 + 0.4 * t
    # --- toe pads: yellow domes, glowing tips
    y0, y1, x0, x1 = R['pad']
    h, w = y1 - y0, x1 - x0
    v, u = np.mgrid[0:h, 0:w].astype(np.float32)
    v /= h
    col[y0:y1, x0:x1] = grad(v, [(0, YEL_DK), (0.5, YEL), (1, YEL_HI)])
    rgh[y0:y1, x0:x1] = 0.2
    glow[y0:y1, x0:x1] = 0.5 + 0.5 * v
    # --- tail
    y0, y1, x0, x1 = R['tail']
    col[y0:y1, x0:x1] = hx(BLUE)
    # --- mouth: dark navy-red
    y0, y1, x0, x1 = R['mouth']
    col[y0:y1, x0:x1] = hx('2a1a3a')
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


def face_texture(level, size=512):
    """mat 1: one round eye (used by both discs): glossy yellow iris, dark rim, big round pupil, two highlights."""
    x, y = coords(size)
    r = np.sqrt(x * x + y * y)
    rgba = np.zeros((size, size, 4), np.float32)
    iris = grad(np.clip(0.5 + y * 0.5, 0, 1), [(0, 'e09a12'), (0.6, 'ffcf2a'), (1, 'ffe873')])
    iris = iris * (1 - 0.25 * ss(0.7, 1.0, r))[..., None]
    rim = ss(0.86, 0.93, r)
    c = iris * (1 - rim[..., None]) + hx('15204a') * rim[..., None]
    py = y + 0.02
    pupil = ss(0.47, 0.44, np.sqrt((x * 0.95) ** 2 + py ** 2))
    c = c * (1 - pupil[..., None]) + hx('0d0d16') * pupil[..., None]
    for hx_, hy_, hr in ((-0.2, 0.26, 0.17), (0.2, -0.22, 0.07)):
        hl = ss(hr, hr * 0.75, np.sqrt((x - hx_) ** 2 + (y - hy_) ** 2))
        c = c * (1 - hl[..., None]) + hl[..., None]
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
                   'Jaw': P(loc=(0, 0, -0.012 * max(0, math.sin(t * 2)))),
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
            p['FrontUpper.' + s] = P(('x', -25 * upv))
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
            p['FrontUpper.' + s] = P(('x', -30 * upv))
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
             'Jaw': P(('x', 22 * rise), loc=(0, 0, -0.04 * rise))}
        for s, x in (('L', 1), ('R', -1)):
            p['FrontUpper.' + s] = P(('y', -x * 14 * rise), ('x', -10 * rise))
        keys[f] = p
    return {'frames': 20, 'loop': False, 'keys': keys}


ANIMS = {'Idle': anim_idle, 'Walk': anim_walk, 'Run': anim_run, 'Hop': anim_hop, 'Ability': anim_ability}
