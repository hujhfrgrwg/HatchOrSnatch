"""HOS-EGG-002 back shard (17 Oct): one chunky, faceted eggshell shard with a jagged broken rim, built in code.

Outputs (tools/shard/out/):
  shard.obj               the mesh (one object, UVs into a 1024 atlas; ~400 tris; flat-shade it)
  shard_<rarity>.png      painted 1024 atlas per rarity (common / rare / epic / legendary), matching the HUD shard art
Run: python tools/shard/shard.py   then   blender -b -P tools/shard/shard_blender.py
Units: 1 = 1 stud. The shard lies in the XZ plane facing -Y (its convex outside towards -Y = away from the back),
up is +Z. Scale it in Roblox (back wear ~1.6 studs tall).
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'out')
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(17)

# ------------------------------------------------------------------ geometry
K = 32            # vertices around the broken rim
RINGS = [0.0, 0.3, 0.58, 0.82, 1.0]    # fractions of the outline (0 = centre point)
A, B, C = 0.62, 0.62, 0.86             # egg ellipsoid half-axes (x, y, z): taller than wide
TH = 0.085                             # shell thickness
PHI0 = math.radians(80)                # how far round the egg the shard reaches at outline radius 1
JIT = rng.random(K)
WOB = rng.random((len(RINGS), K))      # the inner rings' facet wobble (shared by both shells so they stay parallel)


def outline(k, jag):
    """Vertex k of the shard's outline in the cap's tangent plane (x across, z up) as (radius, angle): a bowed
    crescent with a few irregular lobes; jag adds the small zigzag of the broken edge (rim only)."""
    t = 2 * math.pi * k / K
    z = math.sin(t)
    x = 0.50 * math.cos(t) + 0.22 * (1 - z * z) - 0.10
    lobe = 1 + 0.12 * math.sin(3 * t + 0.7) + 0.07 * math.sin(5 * t + 2.1)
    r = math.hypot(x, z) * lobe
    if jag:   # big teeth on the broken (concave) side, small ones elsewhere
        big = math.cos(t) > -0.15
        r *= ((1.20 if k % 2 == 0 else 0.84) if big else (1.06 if k % 2 == 0 else 0.95)) * (0.95 + 0.10 * JIT[k])
    return r, math.atan2(z, x)


def surf(phi, th, inner=False):
    """A point on the egg cap: phi from the cap axis (-Y), th around it. inner = the shell's inside."""
    d = np.array([math.sin(phi) * math.cos(th), -math.cos(phi), math.sin(phi) * math.sin(th)])
    p = d * np.array([A, B, C])
    if inner:
        n = d / np.array([A, B, C]) ** 2
        n /= np.linalg.norm(n)
        p = p - n * TH
    return p


verts, uvs, faces = [], [], []   # faces: (vertex ids, uv ids)


def add_v(p, uv):
    verts.append(p)
    uvs.append(uv)
    return len(verts) - 1


# atlas regions (u0, v0, w, h in 0..1, v up): outside, inside, rim
REG = {'out': (0.02, 0.36, 0.62, 0.62), 'in': (0.66, 0.36, 0.32, 0.62), 'rim': (0.02, 0.02, 0.96, 0.30)}


def ruv(reg, a, b):
    u0, v0, w, h = REG[reg]
    return (u0 + a * w, v0 + b * h)


def shell(inner):
    ids = []
    for ri, f in enumerate(RINGS):
        ring = []
        n = 1 if f == 0 else K
        for k in range(n):
            rr, th = outline(k, jag=f >= 1)
            phi = PHI0 * f * rr
            if 0 < f < 1:   # chunky facets: wobble the inner rings (same on both shells, so the thickness holds)
                phi *= 1 + 0.07 * (WOB[ri][k] - 0.5)
            p = surf(phi, th, inner)
            if 0 < f < 1:
                p = p * (1 + 0.035 * (WOB[(ri + 2) % len(RINGS)][k] - 0.5))
            # planar UV from the projection on XZ (the shard's face), normalised to the region
            a = 0.5 + p[0] / (2 * A * 1.25)
            b = 0.5 + p[2] / (2 * C * 1.25)
            ring.append(add_v(p, ruv('in' if inner else 'out', 1 - a if inner else a, b)))
        ids.append(ring)
    for ri in range(len(RINGS) - 1):
        a_, b_ = ids[ri], ids[ri + 1]
        for k in range(K):
            k2 = (k + 1) % K
            if len(a_) == 1:
                tri = (a_[0], b_[k], b_[k2])
                faces.append(tri[::-1] if inner else tri)
            else:
                q = (a_[k], b_[k], b_[k2], a_[k2])
                t1, t2 = (q[0], q[1], q[2]), (q[0], q[2], q[3])
                faces.extend([t1[::-1], t2[::-1]] if inner else [t1, t2])
    return ids[-1]


outer_rim = shell(False)
inner_rim = shell(True)
# rim walls: the broken edge, its own UVs (a strip)
for k in range(K):
    k2 = (k + 1) % K
    u_a, u_b = k / K, (k + 1) / K
    o1 = add_v(verts[outer_rim[k]], ruv('rim', u_a, 1.0))
    o2 = add_v(verts[outer_rim[k2]], ruv('rim', u_b, 1.0))
    i1 = add_v(verts[inner_rim[k]], ruv('rim', u_a, 0.0))
    i2 = add_v(verts[inner_rim[k2]], ruv('rim', u_b, 0.0))
    faces.extend([(o1, i1, i2), (o1, i2, o2)])

V = np.array(verts)
V -= (V.max(0) + V.min(0)) / 2   # centred
with open(os.path.join(OUT, 'shard.obj'), 'w') as f:
    f.write('# HOS back shard (tools/shard/shard.py)\no Shard\n')
    for p in V:
        f.write('v %.5f %.5f %.5f\n' % tuple(p))
    for uv in uvs:
        f.write('vt %.5f %.5f\n' % uv)
    for tri in faces:
        f.write('f ' + ' '.join('%d/%d' % (i + 1, i + 1) for i in tri) + '\n')
print('shard.obj: %d verts, %d tris, size %s' % (len(V), len(faces), np.round(V.max(0) - V.min(0), 3)))

# ------------------------------------------------------------------ atlases (one per rarity)
N = 1024
PAL = {  # outside light -> dark, speckle colour, inside, rim
    'common': ('#f7faf2', '#d9e6cf', '#58d158', '#c9d8bd', '#ffffff'),
    'rare': ('#7fd0ff', '#1f73e0', '#ffffff', '#1a4fa8', '#d8f1ff'),
    'epic': ('#c58cff', '#5a1fb8', '#7ff0ff', '#3a1080', '#efd9ff'),
    'legendary': ('#ffe36a', '#d98a10', '#fff6d0', '#9a5a06', '#fff3c4'),
}


def hx(h):
    h = h.lstrip('#')
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], float)


def region_px(name):
    u0, v0, w, h = REG[name]
    return int(u0 * N), int((1 - v0 - h) * N), int(w * N), int(h * N)


def paint(r):
    lo, hi, spk, inside, rim = PAL[r]
    img = np.zeros((N, N, 3))
    yy, xx = np.mgrid[0:N, 0:N] / N
    # outside: diagonal light -> dark, faceted bands, grit
    x0, y0, w, h = region_px('out')
    t = np.clip(((xx - x0 / N) / (w / N) * 0.45 + (yy - y0 / N) / (h / N) * 0.75), 0, 1)
    bands = np.floor(t * 6) / 6 * 0.35 + t * 0.65   # stepped shading reads as facets
    col = hx(lo)[None, None] * (1 - bands[..., None]) + hx(hi)[None, None] * bands[..., None]
    img[:] = col
    grit = rng.random((N, N)) * 14 - 7
    img += grit[..., None]
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(im)
    # speckles: rotated squares like the icon's chips (outside region dense, inside sparse)
    for name, count, smax in (('out', 70, 46), ('in', 18, 26)):
        rx, ry, rw, rh = region_px(name)
        for _ in range(count):
            cx, cy = rx + rng.random() * rw, ry + rng.random() * rh
            s = 10 + rng.random() * smax
            a = rng.random() * math.pi
            pts = [(cx + s * math.cos(a + q * math.pi / 2) / 1.4, cy + s * math.sin(a + q * math.pi / 2) / 1.4) for q in range(4)]
            c = hx(spk) if name == 'out' else hx(spk) * 0.6 + hx(inside) * 0.4
            d.polygon(pts, fill=tuple(int(v) for v in c))
    # inside: darker, flat
    rx, ry, rw, rh = region_px('in')
    ins = Image.new('RGB', (rw, rh), tuple(int(v) for v in hx(inside)))
    mask = Image.new('L', (rw, rh), 150)
    im.paste(ins, (rx, ry), mask)
    # rim: pale broken edge with a darker inner line
    rx, ry, rw, rh = region_px('rim')
    d.rectangle([rx, ry, rx + rw, ry + rh], fill=tuple(int(v) for v in hx(rim)))
    d.rectangle([rx, ry + int(rh * 0.78), rx + rw, ry + rh], fill=tuple(int(v) for v in hx(inside)))
    im = im.filter(ImageFilter.GaussianBlur(0.6))
    im.save(os.path.join(OUT, 'shard_%s.png' % r))


for r in PAL:
    paint(r)
print('atlases:', ', '.join('shard_%s.png' % r for r in PAL))
