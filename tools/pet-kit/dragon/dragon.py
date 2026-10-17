# Bone Dragon (Tempest, Legendary, Halloween) for Hatch or Snatch: HOS-HWN-001. Hunter, 17 Oct 15:40: "maybe we make a
# bone dragon pet too that can cycle into the featured menu this halloween" (picked "Both" 15:46).
# A flying skeletal drake (it never walks): a long horned skull with a separate hinged jaw and fangs, sockets burning with
# narrow green soul-fire slits, a vertebra neck, an open ribcage with a soul-fire heart flickering inside, a spine of
# dorsal spikes, tucked bony hind legs, bone wings (arm + three finger bones) carrying a torn dark-violet membrane, and a
# vertebra tail ending in a bone blade. Edgy, not cute: aged ivory with dark cracks, near-black membrane, sharp spikes.
# L2 "Grave Wyrm": longer swept horns, glowing rune cracks down the bones, a second row of dorsal spikes, violet fire.
# L3 "Lich Drake": a crown of black horns, soul flame streaming off the tail blade and the skull, an extra torn membrane
# panel, orbiting bone shards, white-green fire.
# Built by assembling this source with dragon/_parts.py (helpers lifted from wraith.py).
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

NAME = 'Dragon'
SHARP_ANGLE = 40
NORMAL_STRENGTH = 2.2
TS = 1024
ATLAS = Atlas({
    'skull': (0, 0, 512, 256),      # skull loft: u around, v back -> snout
    'bone': (512, 0, 512, 256),     # spine, ribs, limbs, wing bones, tail: u around, v along
    'membrane': (0, 256, 1024, 256),  # wing membrane: u across span, v root -> trailing edge
    'tooth': (0, 512, 256, 128),    # teeth, claws, spikes, horns: v root -> tip
    'fire': (256, 512, 384, 128),   # soul fire: v root -> tip
    'horn': (640, 512, 384, 128),   # horns (darker): v root -> tip
    'shard': (0, 640, 512, 128),    # L3 orbit shards
})

GLOW = {1: ('46ff8a', 'd8ffe6'), 2: ('b05aff', 'f0e0ff'), 3: ('8affc4', 'f4fff8')}   # soul fire per level


def bones_def():
    b = [
        ('Root', V(0, 0, 0), V(0, 0, 0.2), None),
        ('Body', V(0, 0.35, 0.95), V(0, -0.1, 1.02), 'Root'),
        ('Neck1', V(0, -0.15, 1.08), V(0, -0.32, 1.3), 'Body'),
        ('Neck2', V(0, -0.32, 1.3), V(0, -0.45, 1.5), 'Neck1'),
        ('Head', V(0, -0.47, 1.56), V(0, -0.95, 1.5), 'Neck2'),
        ('Jaw', V(0, -0.52, 1.47), V(0, -0.95, 1.38), 'Head'),
        ('Tail1', V(0, 0.45, 0.92), V(0, 0.72, 0.88), 'Body'),
        ('Tail2', V(0, 0.72, 0.88), V(0, 1.0, 0.82), 'Tail1'),
        ('Tail3', V(0, 1.0, 0.82), V(0, 1.28, 0.78), 'Tail2'),
        ('Tail4', V(0, 1.28, 0.78), V(0, 1.55, 0.76), 'Tail3'),
        ('Core', V(0, 0.08, 0.96), V(0, 0.08, 1.12), 'Body'),
        ('Crown', V(0, -0.52, 1.72), V(0, -0.52, 1.9), 'Head'),
        ('Shards', V(0, 0.1, 1.0), V(0, 0.1, 1.2), 'Body'),
    ]
    for s, x in (('L', 1), ('R', -1)):
        b += [('WingU.' + s, V(x * 0.14, -0.02, 1.12), V(x * 0.68, 0.06, 1.36), 'Body'),
              ('WingF.' + s, V(x * 0.68, 0.06, 1.36), V(x * 1.12, 0.24, 1.18), 'WingU.' + s),
              ('Leg.' + s, V(x * 0.14, 0.42, 0.88), V(x * 0.2, 0.3, 0.62), 'Body')]
    return b


def _cum(centers):
    c = [np.asarray(p, float) for p in centers]
    d = [0.0]
    for a, b in zip(c, c[1:]):
        d.append(d[-1] + float(np.linalg.norm(b - a)))
    return [x / max(d[-1], 1e-9) for x in d]


def tube(mb, region, centers, radii, n, weights, part, start='point', end='point', start_pt=None, end_pt=None,
         side_hint=None, anti=True, th0=-math.pi / 2, lobes=0, lobe_amp=0.0):
    vv = _cum(centers)

    def profile(k, nn, a, b, i):
        th = th0 + 2 * math.pi * (k + (0.5 if (anti and i % 2) else 0.0)) / nn
        r = 1.0 + (lobe_amp * math.cos(lobes * (th - th0)) if lobes else 0.0)
        return a * r * math.cos(th), b * r * math.sin(th)

    def uvf(i, k, seg, fk):
        return ATLAS.uv(region, k / n, vv[i])
    return loft(mb, centers, radii, n, weights, uvf, part, start=start, end=end, profile=profile,
                start_pt=start_pt, end_pt=end_pt, side_hint=side_hint)


def torus(mb, region, c, normal, R, r, n_around, n_tube, w, part):
    normal = nrm(np.asarray(normal, float))
    a = nrm(np.cross(normal, V(0, 0, 1) if abs(normal[2]) < 0.9 else V(1, 0, 0)))
    b = np.cross(normal, a)
    cen = [np.asarray(c, float) + (a * math.cos(2 * math.pi * i / n_around) + b * math.sin(2 * math.pi * i / n_around)) * R
           for i in range(n_around + 1)]
    tube(mb, region, cen, [(r, r)] * len(cen), n_tube, [w] * len(cen), part, start='open', end='open',
         side_hint=normal, anti=False)


def _vnormals(mb, faces):
    acc = {}
    for fi in faces:
        f = mb.F[fi]
        a, b, c = mb.V[f[0]], mb.V[f[1]], mb.V[f[2]]
        n = np.cross(b - a, c - a)
        for v in f:
            acc[v] = acc.get(v, np.zeros(3)) + n
    return {v: nrm(n) for v, n in acc.items()}



FX, FZ, FZH = 0.24, 0.0, 0.2     # face decal shell: skull upper-front, projected (x, b) -> texture
SK = V(0, -0.62, 1.6)            # projection centre on the skull
EB = nrm(V(0, 0.6, 0.8))         # projection "up" axis in the texture (toward the back of the cranium)


def _fb(p):
    d = np.asarray(p, float) - SK
    return float(d[0]), float(np.dot(d, EB))


def face_shell(mb, head_faces, lift=0.008):
    sel = []
    for fi in head_faces:
        ok = True
        for v in mb.F[fi]:
            x, b = _fb(mb.V[v])
            p = mb.V[v]
            if not (abs(x) < FX and abs(b - FZ) < FZH and p[2] > 1.52 and p[1] < -0.5):
                ok = False
                break
        if ok:
            sel.append(fi)
    vn = _vnormals(mb, head_faces)
    remap = {}
    for fi in sel:
        for v in mb.F[fi]:
            if v not in remap:
                remap[v] = mb.vert(mb.V[v] + vn[v] * lift, dict(mb.W[v]))
    face_shell.src = dict(remap)
    for fi in sel:
        f = mb.F[fi]
        uvs = []
        for v in f:
            x, b = _fb(mb.V[v])
            uvs.append((0.5 + x / (2 * FX), 0.5 + (b - FZ) / (2 * FZH)))
        mb.face([remap[v] for v in f], uvs, part='faceshell')


def bone_tube(mb, pts, r0, r1, weights, part, n=6, region='bone'):
    k = len(pts)
    tube(mb, region, pts, [((r0 + (r1 - r0) * i / (k - 1)),) * 2 for i in range(k)], n, weights, part, start='point', end='point', anti=False)


def panel(mb, pts, w, part, region='membrane'):
    """a thin double-sided membrane polygon (fan from pts[0]); uv from the polygon's own bounds."""
    P = [np.asarray(p, float) for p in pts]
    lo, hi = np.min(P, 0), np.max(P, 0)
    span = np.maximum(hi - lo, 1e-6)
    ids = [mb.vert(p, w[i] if isinstance(w, list) else w) for i, p in enumerate(P)]
    uvs = [ATLAS.uv(region, (p[0] - lo[0]) / span[0], (p[1] - lo[1]) / span[1]) for p in P]
    for i in range(1, len(P) - 1):
        mb.face([ids[0], ids[i], ids[i + 1]], [uvs[0], uvs[i], uvs[i + 1]], part=part)
        mb.face([ids[0], ids[i + 1], ids[i]], [uvs[0], uvs[i + 1], uvs[i]], part=part)


def build():
    mb = MB()
    mb.mat = 0
    W_B, W_H = {'Body': 1}, {'Head': 1}
    tb, tt = ATLAS.uv('tooth', 0.3, 0.1), ATLAS.uv('tooth', 0.3, 0.92)
    hb, ht = ATLAS.uv('horn', 0.3, 0.1), ATLAS.uv('horn', 0.3, 0.92)
    # ---- skull (cranium + snout), facing -y
    n0 = len(mb.F)
    sk = [(V(0, -0.46, 1.6), (0.13, 0.12)), (V(0, -0.53, 1.62), (0.19, 0.17)), (V(0, -0.62, 1.6), (0.18, 0.15)),
          (V(0, -0.72, 1.55), (0.12, 0.1)), (V(0, -0.84, 1.51), (0.09, 0.075)), (V(0, -0.96, 1.48), (0.065, 0.055))]
    tube(mb, 'skull', [s[0] for s in sk], [s[1] for s in sk], 10, [W_H] * len(sk), 'skull', start='point', end='point',
         start_pt=V(0, -0.42, 1.6), end_pt=V(0, -1.02, 1.46), side_hint=V(1, 0, 0), anti=False, th0=math.pi / 2)
    head_faces = list(range(n0, len(mb.F)))
    # brow ridges (sharp, over the sockets) and cheek spikes
    for x in (1, -1):
        bipyramid(mb, V(x * 0.08, -0.6, 1.7), V(x * 0.2, -0.5, 1.75), V(0, -1, 0), V(0, 0, 1), 0.1, 0.05, W_H, tb, tt, 'skull', wide_at=0.3, ridge_at=0.3)
        bipyramid(mb, V(x * 0.15, -0.52, 1.52), V(x * 0.32, -0.42, 1.46), V(0, 0, 1), V(x, 0, 0), 0.08, 0.04, W_H, tb, tt, 'skull', wide_at=0.3, ridge_at=0.3)
    # swept horns
    for x in (1, -1):
        hp = [V(x * 0.1, -0.5, 1.72), V(x * 0.17, -0.4, 1.82), V(x * 0.24, -0.26, 1.9), V(x * 0.27, -0.12, 1.92)]
        tube(mb, 'horn', hp, [(0.05, 0.05), (0.04, 0.04), (0.028, 0.028), (0.015, 0.015)], 6, [W_H] * 4, 'horn', start='point', end='point',
             end_pt=V(x * 0.28, -0.04, 1.9), anti=False, side_hint=V(-1, 0, 0))
    # lower jaw (hinged) + fangs on both jaws
    bone_tube(mb, [V(0, -0.5, 1.48), V(0, -0.66, 1.44), V(0, -0.82, 1.4), V(0, -0.95, 1.38)], 0.09, 0.045, [{'Jaw': 1}] * 4, 'jaw', n=8, region='skull')
    for k, y in enumerate((-0.66, -0.76, -0.86, -0.94)):
        for x in (1, -1):
            bipyramid(mb, V(x * 0.06 * (1 - 0.3 * k / 3), y, 1.5 - 0.02 * k), V(x * 0.06 * (1 - 0.3 * k / 3), y - 0.015, 1.42 - 0.02 * k), V(0, 1, 0),
                      V(x, 0, 0), 0.025, 0.02, W_H, tb, tt, 'tooth', wide_at=0.3, ridge_at=0.3)
            bipyramid(mb, V(x * 0.05 * (1 - 0.3 * k / 3), y + 0.03, 1.42 - 0.02 * k), V(x * 0.05 * (1 - 0.3 * k / 3), y + 0.02, 1.48 - 0.02 * k),
                      V(0, 1, 0), V(x, 0, 0), 0.02, 0.018, {'Jaw': 1}, tb, tt, 'tooth', wide_at=0.3, ridge_at=0.3)
    # ---- neck vertebrae + spine + tail (one bone tube) with dorsal spikes
    spine = [(V(0, -0.47, 1.52), {'Neck2': 1}), (V(0, -0.36, 1.36), {'Neck2': 1}), (V(0, -0.26, 1.2), {'Neck1': 1}), (V(0, -0.12, 1.07), {'Neck1': 0.5, 'Body': 0.5}),
             (V(0, 0.1, 1.04), W_B), (V(0, 0.32, 0.98), W_B), (V(0, 0.48, 0.92), {'Body': 0.5, 'Tail1': 0.5}), (V(0, 0.72, 0.88), {'Tail1': 1}),
             (V(0, 1.0, 0.82), {'Tail2': 1}), (V(0, 1.28, 0.78), {'Tail3': 1}), (V(0, 1.5, 0.76), {'Tail4': 1})]
    rad = [0.06, 0.065, 0.07, 0.075, 0.08, 0.08, 0.075, 0.06, 0.045, 0.032, 0.02]
    tube(mb, 'bone', [s[0] for s in spine], [(r, r) for r in rad], 6, [s[1] for s in spine], 'spine', start='point', end='point', anti=False)
    for i in range(1, len(spine) - 1):
        p, w = spine[i]
        ln = 0.14 if 3 <= i <= 6 else 0.09
        bipyramid(mb, p + V(0, 0, rad[i] * 0.6), p + V(0, 0.05, rad[i] + ln), V(0, 1, 0), V(1, 0, 0), 0.07, 0.03, w, tb, tt, 'spike', wide_at=0.3, ridge_at=0.3)
    # tail blade
    bipyramid(mb, V(0, 1.46, 0.76), V(0, 1.78, 0.8), V(0, 0, 1), V(1, 0, 0), 0.22, 0.04, {'Tail4': 1}, tb, tt, 'blade', wide_at=0.35, ridge_at=0.35)
    # ---- ribcage: five pairs of curved ribs, open at the belly
    for k, y in enumerate((-0.06, 0.04, 0.14, 0.24, 0.33)):
        rr = 0.24 - 0.025 * abs(k - 1.5)
        for x in (1, -1):
            z0 = 1.04 - 0.02 * k
            pts = [V(x * 0.05, y, z0), V(x * rr * 0.9, y + 0.01, z0 - 0.05), V(x * rr, y + 0.02, z0 - 0.17), V(x * rr * 0.75, y + 0.03, z0 - 0.3),
                   V(x * rr * 0.35, y + 0.03, z0 - 0.36)]
            bone_tube(mb, pts, 0.026, 0.014, [W_B] * 5, 'rib', n=4)
    # soul-fire heart inside the ribs (glows)
    fb, ft = ATLAS.uv('fire', 0.5, 0.05), ATLAS.uv('fire', 0.5, 0.95)
    for base, tip, wd in ((V(0, 0.12, 0.8), V(0, 0.1, 1.08), 0.16), (V(0.05, 0.1, 0.84), V(0.08, 0.06, 1.0), 0.1), (V(-0.05, 0.16, 0.84), V(-0.08, 0.18, 1.0), 0.1)):
        bipyramid(mb, base, tip, V(1, 0, 0), V(0, 1, 0), wd, wd, {'Core': 1}, fb, ft, 'core', wide_at=0.35, ridge_at=0.35)
    # ---- tucked hind legs with claws
    for s, x in (('L', 1), ('R', -1)):
        lg = 'Leg.' + s
        bone_tube(mb, [V(x * 0.1, 0.4, 0.9), V(x * 0.2, 0.36, 0.76), V(x * 0.18, 0.46, 0.66), V(x * 0.2, 0.36, 0.6)], 0.05, 0.03,
                  [W_B, {lg: 1}, {lg: 1}, {lg: 1}], 'leg' + s)
        for dx in (-0.03, 0.0, 0.03):
            b0 = V(x * 0.2 + dx, 0.35, 0.6)
            bipyramid(mb, b0, b0 + V(dx * 0.5, -0.08, -0.05), V(1, 0, 0), V(0, 0, 1), 0.025, 0.022, {lg: 1}, tb, tt, 'claw', wide_at=0.3, ridge_at=0.3, curl=0.2)
    # ---- wings: arm bone, forearm, three finger bones and a torn membrane between them
    for s, x in (('L', 1), ('R', -1)):
        wu, wf = 'WingU.' + s, 'WingF.' + s
        sh, el, wr = V(x * 0.1, -0.02, 1.1), V(x * 0.68, 0.06, 1.36), V(x * 1.12, 0.24, 1.18)
        bone_tube(mb, [sh, (sh + el) / 2 + V(0, 0, 0.04), el], 0.045, 0.035, [W_B, {wu: 1}, {wu: 1}], 'wingU' + s)
        bone_tube(mb, [el, (el + wr) / 2, wr], 0.035, 0.03, [{wu: 1}, {wf: 1}, {wf: 1}], 'wingF' + s)
        bipyramid(mb, wr, wr + V(x * 0.1, -0.12, 0.12), V(0, 0, 1), V(x, 0, 0), 0.05, 0.04, {wf: 1}, tb, tt, 'claw', wide_at=0.3, ridge_at=0.3, curl=0.2)
        tips = [V(x * 1.62, 0.36, 0.86), V(x * 1.4, 0.72, 0.78), V(x * 1.0, 0.86, 0.86)]
        for t_ in tips:
            bone_tube(mb, [wr, (wr + t_) / 2, t_], 0.026, 0.012, [{wf: 1}] * 3, 'finger' + s, n=4)
        # membrane: shoulder -> elbow -> wrist -> finger tips, torn trailing edge (notches between fingers), back to the body
        def notch(a, b, f, depth):
            m = a + (b - a) * f
            return m + V(0, -depth * 0.3, depth) * 0.0 + nrm((sh + el) / 2 - m) * depth
        memb = [sh, el, wr, tips[0], notch(tips[0], tips[1], 0.5, 0.16), tips[1], notch(tips[1], tips[2], 0.45, 0.18), tips[2],
                notch(tips[2], V(x * 0.3, 0.5, 0.9), 0.5, 0.12), V(x * 0.3, 0.5, 0.92), V(x * 0.12, 0.3, 0.98)]
        wts = [W_B, {wu: 1}, {wf: 1}, {wf: 1}, {wf: 1}, {wf: 1}, {wf: 1}, {wf: 1}, {wf: 0.5, 'Body': 0.5}, W_B, W_B]
        panel(mb, memb, wts, 'membrane')
    mb.mat = 1
    face_shell(mb, head_faces)
    # ---- L2 "Grave Wyrm": longer horns, second spike row, bone chain bracelets
    mb.mat = 2
    for x in (1, -1):
        hp = [V(x * 0.15, -0.45, 1.78), V(x * 0.24, -0.32, 1.95), V(x * 0.32, -0.12, 2.05), V(x * 0.36, 0.06, 2.02)]
        tube(mb, 'horn', hp, [(0.04, 0.04), (0.032, 0.032), (0.022, 0.022), (0.012, 0.012)], 6, [W_H] * 4, 'L2', start='point', end='point',
             end_pt=V(x * 0.37, 0.14, 1.98), anti=False, side_hint=V(-1, 0, 0))
    for i in range(2, len(spine) - 2):
        p, w = spine[i]
        for x in (1, -1):
            bipyramid(mb, p + V(x * rad[i] * 0.5, 0, rad[i] * 0.4), p + V(x * 0.1, 0.04, rad[i] + 0.06), V(0, 1, 0), V(x, 0, 1), 0.05, 0.025, w,
                      tb, tt, 'L2', wide_at=0.3, ridge_at=0.3)
    for x in (1, -1):    # floating soul wisps off the shoulders
        c = V(x * 0.3, -0.1, 1.3)
        bipyramid(mb, c, c + V(0, 0.04, 0.22), V(1, 0, 0), V(0, -1, 0), 0.1, 0.1, {'Core': 1}, fb, ft, 'L2', wide_at=0.32, ridge_at=0.32)
    # ---- L3 "Lich Drake": crown of black horns, soul flames off skull + tail blade, extra membrane panel, orbit shards
    mb.mat = 3
    for k, (ang, ln) in enumerate(((-0.6, 0.18), (-0.3, 0.24), (0.0, 0.28), (0.3, 0.24), (0.6, 0.18))):
        base = V(math.sin(ang) * 0.12, -0.56 + abs(ang) * 0.05, 1.72)
        bipyramid(mb, base, base + V(math.sin(ang) * 0.08, 0.06, ln), V(1, 0, 0), V(0, 1, 0), 0.06, 0.04, {'Crown': 1}, hb, ht, 'L3', wide_at=0.3, ridge_at=0.3)
    for base, tip, wd, w in ((V(0, -0.5, 1.74), V(0, -0.3, 2.0), 0.14, W_H), (V(0, 1.7, 0.8), V(0, 2.0, 0.92), 0.16, {'Tail4': 1}),
                             (V(0.04, 1.66, 0.78), V(0.1, 1.9, 0.7), 0.1, {'Tail4': 1})):
        bipyramid(mb, base, tip, V(1, 0, 0), V(0, 0, 1), wd, wd, w, fb, ft, 'L3', wide_at=0.3, ridge_at=0.3)
    sb, st_ = ATLAS.uv('shard', 0.5, 0.1), ATLAS.uv('shard', 0.5, 0.9)
    for k in range(5):
        a = 2 * math.pi * k / 5
        c = V(math.cos(a) * 0.62, 0.1 + math.sin(a) * 0.5, 1.15 + 0.08 * math.sin(3 * a))
        bipyramid(mb, c, c + V(0.03, 0.02, 0.16), V(1, 0, 0), V(0, 1, 0), 0.06, 0.05, {'Shards': 1}, sb, st_, 'L3', wide_at=0.4, ridge_at=0.4)
    mb.mat = 0
    return mb


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


def _orange(level):
    if level == 3:
        return [(0, '2a0a04'), (0.4, '7a2408'), (0.8, 'c4520e'), (1, 'e07a22')]
    return [(0, '220803'), (0.4, '6a1e06'), (0.8, 'b2440c'), (1, 'd2661a')]


def _reg(name):
    y0, y1, x0, x1 = ATLAS.px(name)
    h, w = y1 - y0, x1 - x0
    v, u = np.mgrid[0:h, 0:w].astype(np.float32)
    return (y0, y1, x0, x1), v / h, u / w



def paint_atlas(level):
    col = np.zeros((TS, TS, 3), np.float32)
    hgt = np.full((TS, TS), 0.5, np.float32)
    rgh = np.full((TS, TS), 0.6, np.float32)
    glow = np.zeros((TS, TS), np.float32)
    gc, ghi = GLOW[level]
    ivory = [(0, '4a4436'), (0.45, '968c74'), (0.8, 'c8bea4'), (1, 'eae2ca')] if level < 3 else [(0, '3e3c46'), (0.45, '8a8696'), (0.8, 'bebaca'), (1, 'e6e2f0')]
    for reg, seed in (('skull', 61), ('bone', 63)):
        (y0, y1, x0, x1), v, u = _reg(reg)
        h, w = y1 - y0, x1 - x0
        top = np.cos(u * 2 * math.pi)
        st = _streaks(h, w, 120, seed)
        gr = _pgrain(h, w, seed + 1)
        c = grad(np.clip(0.35 + 0.35 * top + 0.4 * st, 0, 1), ivory) * (1 + 0.08 * gr[..., None])
        # dark cracks and age stains
        crack = ss(0.01, 0.0, np.abs(_saw(u * 6 + v * 3.3 + 0.2 * st) - 0.5) - 0.006) * ss(0.8, 0.9, vnoise(h, w, 22, seed + 5))
        stain = ss(0.55, 0.75, vnoise(h, w, 9, seed + 7))
        c = c * (1 - 0.25 * stain[..., None]) + hx('3a2c1a') * 0.25 * stain[..., None]
        c = c * (1 - 0.8 * crack[..., None]) + hx('0e0a08') * 0.8 * crack[..., None]
        # L2+: rune cracks glow
        rune = crack * (0.0 if level == 1 else 0.9)
        c = c * (1 - rune[..., None]) + hx(gc) * rune[..., None]
        # bone joint rings along v
        joints = ss(0.03, 0.0, np.abs(_saw(v * (6 if reg == 'bone' else 2)) - 1.0) - 0.0) * (1.0 if reg == 'bone' else 0.0)
        c = c * (1 - 0.3 * joints[..., None])
        col[y0:y1, x0:x1] = c
        rgh[y0:y1, x0:x1] = 0.55 + 0.15 * stain
        hgt[y0:y1, x0:x1] = 0.5 + 0.3 * st + 0.08 * gr - 0.35 * crack - 0.2 * joints
        glow[y0:y1, x0:x1] = rune
    # ---- membrane: near-black violet, veins, burnt torn edges glowing faintly
    (y0, y1, x0, x1), v, u = _reg('membrane')
    h, w = y1 - y0, x1 - x0
    st = _streaks(h, w, 80, 71)
    veins = ss(0.012, 0.0, np.abs(_saw(u * 5 + v * 0.6) - 0.5) - 0.006)
    holes = ss(0.8, 0.88, vnoise(h, w, 14, 73)) * ss(0.78, 0.92, v)
    memc = [(0, '0a0610'), (0.6, '1e1230'), (1, '34204e')] if level < 3 else [(0, '060c0a'), (0.6, '12261e'), (1, '204836')]
    c = grad(np.clip(0.4 + 0.5 * st + 0.2 * (1 - v), 0, 1), memc) * (1 - 0.4 * veins[..., None])
    burn = ss(0.02, 0.0, np.abs(holes - 0.5) - 0.45) * 0 + holes
    c = c * (1 - burn[..., None]) + hx(gc) * burn[..., None] * 0.7
    col[y0:y1, x0:x1] = c
    rgh[y0:y1, x0:x1] = 0.7
    hgt[y0:y1, x0:x1] = 0.5 + 0.2 * st + 0.2 * veins
    glow[y0:y1, x0:x1] = burn * 0.6
    # ---- teeth / claws / spikes: ivory to a dark tip, glowing tips from L2
    (y0, y1, x0, x1), v, u = _reg('tooth')
    t = ss(0.55, 0.95, v)
    tipg = ss(0.85, 0.97, v) * (0.0 if level == 1 else 1.0)
    c = grad(v, [(0, 'cfc6ae'), (0.6, '8a8070'), (1, '1a1612')])
    col[y0:y1, x0:x1] = c * (1 - tipg[..., None]) + hx(gc) * tipg[..., None]
    rgh[y0:y1, x0:x1] = 0.35
    glow[y0:y1, x0:x1] = tipg
    # ---- horns: near-black ridged, ember-green tip
    (y0, y1, x0, x1), v, u = _reg('horn')
    ridges = 0.5 + 0.5 * np.cos(v * 2 * math.pi * 8)
    tipg = ss(0.88, 0.98, v)
    c = grad(v, [(0, '3a342c'), (0.5, '16120e'), (1, '060504')]) * (1 - 0.2 * ridges[..., None])
    col[y0:y1, x0:x1] = c * (1 - tipg[..., None]) + hx(gc) * tipg[..., None]
    hgt[y0:y1, x0:x1] = 0.5 + 0.25 * ridges
    glow[y0:y1, x0:x1] = tipg
    # ---- soul fire
    (y0, y1, x0, x1), v, u = _reg('fire')
    col[y0:y1, x0:x1] = grad(v, [(0, ghi), (0.45, gc), (1, '04140a' if level != 2 else '140420')])
    rgh[y0:y1, x0:x1] = 0.2
    glow[y0:y1, x0:x1] = 1.0 - 0.5 * v
    # ---- L3 shards: pale bone with a glowing core line
    (y0, y1, x0, x1), v, u = _reg('shard')
    core = ss(0.05, 0.0, np.abs(u - 0.5) - 0.02)
    col[y0:y1, x0:x1] = hx('d2cede') * (1 - core[..., None]) + hx(gc) * core[..., None]
    glow[y0:y1, x0:x1] = core
    paint_atlas._glow = np.clip(glow, 0, 1)
    return np.clip(col, 0, 1), hgt, rgh


def emissive_mask(level):
    paint_atlas(level)
    return np.repeat(paint_atlas._glow[..., None], 3, -1)


# ---------------------------------------------------------------- face decal: deep eye sockets with soul-fire slits
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
    X, B = x * FX, FZ + y * FZH
    aX = np.abs(X)
    # socket: an angular dark hollow slanting down toward the snout (inner corner forward/low)
    sock = ss(0.006, 0.0, np.maximum(np.abs(aX - 0.11) / 0.075 + np.abs(B - 0.02 - 0.35 * (aX - 0.11)) / 0.05 - 1, -1))
    # the soul-fire slit inside it: a narrow glowing blade, plus a slit pupil
    slit = ss(0.004, 0.0, np.abs(B - 0.02 - 0.35 * (aX - 0.11)) - 0.0055 * np.clip(1 - ((aX - 0.11) / 0.06) ** 2, 0, 1)) * (aX > 0.05) * (aX < 0.17)
    pupil = ss(0.003, 0.0, np.abs(aX - 0.11) - 0.0025) * slit
    brow = _seg(aX, B, (0.03, 0.06), (0.2, 0.1), 0.012, 0.004)
    nostril = ss(0.004, 0.0, np.hypot((aX - 0.03) / 0.018, (B + 0.15) / 0.012) - 1)
    marks = np.zeros_like(X)
    if level >= 2:     # rune scars over the brow
        marks = np.maximum(_seg(aX, B, (0.04, 0.12), (0.08, 0.17), 0.006, 0.002), _seg(aX, B, (0.12, 0.13), (0.16, 0.17), 0.005, 0.001))
    if level >= 3:     # a third socket mark on the forehead
        marks = np.maximum(marks, ss(0.004, 0.0, aX / 0.02 + np.abs(B - 0.15) / 0.035 - 1))
    return X, B, sock, slit, pupil, brow, nostril, marks


def face_texture(level, size=512):
    X, B, sock, slit, pupil, brow, nostril, marks = _face_layers(level, size)
    gc, ghi = GLOW[level]
    rgba = np.zeros((size, size, 4), np.float32)
    c = np.zeros((size, size, 3), np.float32) + hx('060504')
    fire = grad(np.clip(1 - np.abs(np.abs(X) - 0.11) / 0.06, 0, 1), [(0, gc), (0.7, gc), (1, ghi)])
    c = c * (1 - slit[..., None]) + fire * slit[..., None]
    c = c * (1 - pupil[..., None]) + hx('020302') * pupil[..., None]
    c = c * (1 - marks[..., None]) + hx(gc) * marks[..., None]
    rgba[..., :3] = c
    rgba[..., 3] = np.clip(np.maximum.reduce([sock, slit, brow * 0.9, nostril, marks]), 0, 1)
    return rgba


def face_emissive(level, size=512):
    X, B, sock, slit, pupil, brow, nostril, marks = _face_layers(level, size)
    g = np.clip(np.maximum.reduce([slit * (1 - pupil), marks * 0.9, sock * 0.12]), 0, 1)
    return np.repeat(g[..., None], 3, -1)


def _ease(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def _pulse(t, a, b):
    if t <= a or t >= b:
        return 0.0
    return math.sin(math.pi * (t - a) / (b - a))



# A gliding bone drake: slow heavy wing beats, the tail whipping, the skull turning to stare, the jaw clicking.
def _wings(w, amp, base=0.0):
    a = amp * math.sin(w)
    return {'WingU.L': P(('y', base - a)), 'WingU.R': P(('y', -base + a)),
            'WingF.L': P(('y', -0.6 * a + 10)), 'WingF.R': P(('y', 0.6 * a - 10))}


def _tail(w, amp, pitch=0.0):
    return {'Tail1': P(('x', -pitch * 0.3), ('z', amp * math.sin(w))), 'Tail2': P(('x', -pitch * 0.2), ('z', amp * 1.2 * math.sin(w - 0.8))),
            'Tail3': P(('z', amp * 1.4 * math.sin(w - 1.6))), 'Tail4': P(('z', amp * 1.6 * math.sin(w - 2.4)))}


def anim_idle():
    F = 72
    keys = {}
    for f in range(0, F + 1, 3):
        t = f / F
        w = 2 * math.pi * t
        look = _pulse(t, 0.25, 0.6)
        click = _pulse(t, 0.7, 0.8)
        k = {'Body': P(('x', 3 * math.sin(w * 2)), loc=(0, 0, 0.08 * math.sin(w * 2))),
             'Neck1': P(('x', -4 * math.sin(w * 2 + 0.5)), ('z', 10 * look)), 'Neck2': P(('z', 10 * look)),
             'Head': P(('x', 5 * math.sin(w * 2 + 1.0)), ('z', 8 * look), ('y', -6 * look)),
             'Jaw': P(('x', 18 * click)), 'Core': P(('z', 360 * t), loc=(0, 0, 0.02 * math.sin(4 * w))),
             'Leg.L': P(('x', 6 * math.sin(w))), 'Leg.R': P(('x', 6 * math.sin(w + 0.5))),
             'Crown': P(), 'Shards': P(('z', 360 * t))}
        k.update(_wings(w * 2, 28, 12))
        k.update(_tail(w, 10))
        keys[f] = k
    keys[F] = dict(keys[0])
    keys[F]['Core'] = P(('z', 0)); keys[F]['Shards'] = P(('z', 0))
    return {'frames': F, 'loop': True, 'keys': keys}


def _fly(frames, pitch, beat, sway):
    keys = {}
    for f in range(0, frames + 1, 2):
        t = f / frames
        w = 2 * math.pi * t
        k = {'Body': P(('x', pitch + 4 * math.sin(w)), loc=(0, 0, 0.08 * math.sin(w - 1.0))),
             'Neck1': P(('x', -pitch * 0.4)), 'Neck2': P(('x', -pitch * 0.3)), 'Head': P(('x', -pitch * 0.2)),
             'Leg.L': P(('x', -30)), 'Leg.R': P(('x', -30)), 'Shards': P(('z', 360 * t))}
        k.update(_wings(w, beat, 6))
        k.update(_tail(w, sway, pitch * 1.2))
        keys[f] = k
    keys[frames] = dict(keys[0])
    keys[frames]['Shards'] = P(('z', 0))
    return {'frames': frames, 'loop': True, 'keys': keys}


def anim_walk():
    return _fly(24, 12, 38, 10)


def anim_run():
    return _fly(16, 24, 46, 16)


def anim_hop():
    keys = {}
    F = 16
    for f in range(0, F + 1, 2):
        t = f / F
        crouch = _pulse(t, 0.0, 0.3)
        up = _pulse(t, 0.2, 1.0)
        k = {'Body': P(('x', 10 * crouch - 12 * up), loc=(0, 0, -0.08 * crouch + 0.32 * up)), 'Head': P(('x', -10 * up))}
        k.update(_wings(0, 0, -40 * up + 20 * crouch))
        k.update(_tail(0, 0, 25 * up))
        keys[f] = k
    return {'frames': F, 'loop': False, 'keys': keys}


def anim_ability():
    """Knockback (~1 s, Runner): rears up with the wings thrown high, then slams down and forward in a huge wing beat with
    the jaw wide (the pulse fires at the slam), and settles."""
    keys = {}
    F = 24
    for f in range(0, F + 1, 2):
        t = f / F
        rear = _ease(t / 0.4) * (1 - _ease((t - 0.4) / 0.08))
        slam = _ease((t - 0.4) / 0.08) * (1 - _ease((t - 0.75) / 0.25))
        k = {'Body': P(('x', -28 * rear + 20 * slam), loc=(0, 0.06 * rear - 0.1 * slam, 0.14 * rear - 0.1 * slam)),
             'Neck1': P(('x', -14 * rear + 18 * slam)), 'Neck2': P(('x', -10 * rear + 12 * slam)), 'Head': P(('x', -10 * rear + 6 * slam)),
             'Jaw': P(('x', 10 * rear + 40 * slam)), 'Leg.L': P(('x', 30 * rear)), 'Leg.R': P(('x', 30 * rear)),
             'Core': P(loc=(0, 0, 0.04 * slam)), 'Shards': P(('z', 540 * t))}
        k.update(_wings(0, 0, 55 * rear - 50 * slam))
        k.update(_tail(6 * t, 20, -20 * rear + 15 * slam))
        keys[f] = k
    return {'frames': F, 'loop': False, 'keys': keys}


def anim_breath():
    """Breath (~0.75 s, Catcher: Storm Ball): draws the head back with the jaw open and the core flaring, then thrusts the
    skull forward and spits the soul-fire ball, wings braced."""
    keys = {}
    F = 18
    for f in range(0, F + 1):
        t = f / F
        draw = _ease(t / 0.35) * (1 - _ease((t - 0.35) / 0.08))
        spit = _ease((t - 0.35) / 0.08) * (1 - _ease((t - 0.7) / 0.3))
        k = {'Body': P(('x', -8 * draw + 10 * spit), loc=(0, 0.06 * draw - 0.12 * spit, 0)),
             'Neck1': P(('x', -20 * draw + 22 * spit)), 'Neck2': P(('x', -14 * draw + 16 * spit)), 'Head': P(('x', -10 * draw + 8 * spit)),
             'Jaw': P(('x', 25 * draw + 35 * spit)), 'Core': P(loc=(0, 0, 0.05 * draw))}
        k.update(_wings(0, 0, 20 * draw - 10 * spit))
        k.update(_tail(4 * t, 16))
        keys[f] = k
    return {'frames': F, 'loop': False, 'keys': keys}


ANIMS = {'Idle': anim_idle, 'Walk': anim_walk, 'Run': anim_run, 'Hop': anim_hop, 'Ability': anim_ability,
         'Breath': anim_breath}
