"""HOS-LOBBY-007 (18 Oct 2026, Matthew): meshes for the Halloween spin wheel, matched 1:1 to Matthew's front-view concept
(docs/HOS-LOBBY-007/spin_wheel_frame_concept.webp): "frame needs to look like this ... meshes for mostly everything", then
"more tightly fitted and a bit more skinny like in the concept. Go 1:1". Every size below is measured off that image.

Writes one GLB, every node already in place (units are studs, +Y up, the front faces +Z, the origin on the ground under
the middle of the base). HOS-LOBBY-007_spin_wheel_meshes.lua assembles the import in Studio.
  BaseStone     the 3-stud octagonal base, the stand under the wheel and the two steps below it (bevelled, low-poly)
  BaseBlocks    the stepped blocks either side of the stairs, the blocks stacked at each post's foot, and along the back
  StepGlow      glow strips on the stand's and middle step's risers (neon)
  PostL, PostR  skinny stone posts that lean in to hug the rim (just behind it), rise to a slanted top, and put out one
                short arm with a hook for the lantern
  Cracks        dark crack lines carved into the posts, steps and blocks
  BackFrame     a pillar behind the wheel, a bar over its top and the mount block in front of it that holds the crystal
  Axle          the axle from the pillar to the wheel (hidden behind it)
  Crystal       the pointer: a long faceted crystal with two small side crystals (neon)
  WheelBacking  the dark disc behind the sectors
  WheelRim      the thick bevelled rim; WheelRimInner the thin band inside it
  Sector        ONE sector (the top slot); the Studio script copies it round the wheel 8 times
  Divider       ONE divider (on the top slot's left edge as you face it); copied 8 times (neon)
  Gem           ONE faceted stud on the rim (at 60 degrees); copied round the rim, skipping the top under the pointer
  Hub           the raised hub ring (the kit pumpkin sits in it)

Run: python3 tools/build/HOS-LOBBY-007_spin_wheel_meshes.py docs/HOS-LOBBY-007/SpinWheel.glb
"""
import json
import math
import random
import struct
import sys

import numpy as np
from scipy.spatial import ConvexHull
import shapely
from shapely.geometry import LineString, Polygon

rng = random.Random(1007)

# layout (local studs), measured 1:1 off the concept (1254 px square): the rim's outer radius (380 px) is 7.45 studs,
# so 1 px = 0.0196 studs; x = (px - 627) * k, y = (1145 - py) * k (1145 px is the ground under the base)
K = 7.45 / 380
WHEEL_Y = 10.72  # wheel centre height (598 px)
WHEEL_Z = 0.0  # the wheel's plane; +Z is the front
R_OUT, R_RIM, R_IN, R_HUB = 7.45, 6.3, 5.98, 1.9  # rim outside, rim band inside, inner band inside (sectors' edge), hub
LEDGE_TOP = 3.0  # the base's top, where the pumpkins and candles stand (990 px)
STAND_TOP = 3.2  # the top step the wheel stands over (the rim's bottom is at WHEEL_Y - R_OUT = 3.27)
POST_Z, POST_D = -1.75, 2.0  # the posts stand just behind the wheel
# ---------------------------------------------------------------- primitives
def hull(points):
    """the convex hull of `points` as outward-wound triangles"""
    pts = np.asarray(points, float)
    h = ConvexHull(pts)
    tris = []
    for simplex, eq in zip(h.simplices, h.equations):
        a, b, c = pts[simplex]
        n = np.cross(b - a, c - a)
        tris.append((a, b, c) if np.dot(n, eq[:3]) >= 0 else (a, c, b))
    return tris


def bevel_box(c, size, b, yaw=0.0):
    """a box with chamfered edges, centred at c, turned `yaw` radians about Y"""
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    pts = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                pts += [(sx * (hx - b), sy * (hy - b), sz * hz), (sx * hx, sy * (hy - b), sz * (hz - b)), (sx * (hx - b), sy * hy, sz * (hz - b))]
    cy, sy_ = math.cos(yaw), math.sin(yaw)
    R = np.array([[cy, 0, sy_], [0, 1, 0], [-sy_, 0, cy]])
    pts = [R @ np.array(p) + np.array(c) for p in pts]
    return hull(pts)


def bevel_prism(poly, z0, z1, b):
    """a convex 2D outline (x, y) extruded from z0 to z1 with its front and back edges chamfered by b"""
    P = Polygon(poly)
    inner = P.buffer(-b, join_style="mitre")
    pts = []
    for x, y in list(inner.exterior.coords)[:-1]:
        pts += [(x, y, z0), (x, y, z1)]
    for x, y in poly:
        pts += [(x, y, z0 + b), (x, y, z1 - b)]
    return hull(pts)


def bevel_slab(poly_xz, y0, y1, b):
    """a convex outline in plan (x, z) as a slab from y0 to y1, top and bottom edges chamfered"""
    P = Polygon(poly_xz)
    inner = P.buffer(-b, join_style="mitre")
    pts = []
    for x, z in list(inner.exterior.coords)[:-1]:
        pts += [(x, y0, z), (x, y1, z)]
    for x, z in poly_xz:
        pts += [(x, y0 + b, z), (x, y1 - b, z)]
    return hull(pts)


def octagon(w, d, cut, cx=0.0, cz=0.0):
    hw, hd = w / 2, d / 2
    return [(cx - hw + cut, cz - hd), (cx + hw - cut, cz - hd), (cx + hw, cz - hd + cut), (cx + hw, cz + hd - cut),
            (cx + hw - cut, cz + hd), (cx - hw + cut, cz + hd), (cx - hw, cz + hd - cut), (cx - hw, cz - hd + cut)]


def lathe(profile, segs, centre, phase=0.0):
    """a solid of revolution about the Z axis through `centre`, from a closed (r, z) profile"""
    cx, cy, cz = centre
    tris = []
    n = len(profile)
    for i in range(segs):
        a0 = 2 * math.pi * i / segs + phase
        a1 = 2 * math.pi * (i + 1) / segs + phase
        for k in range(n):
            r0, z0 = profile[k]
            r1, z1 = profile[(k + 1) % n]
            p00 = np.array([cx + r0 * math.cos(a0), cy + r0 * math.sin(a0), cz + z0])
            p01 = np.array([cx + r0 * math.cos(a1), cy + r0 * math.sin(a1), cz + z0])
            p10 = np.array([cx + r1 * math.cos(a0), cy + r1 * math.sin(a0), cz + z1])
            p11 = np.array([cx + r1 * math.cos(a1), cy + r1 * math.sin(a1), cz + z1])
            # outward: the profile runs anticlockwise in (r, z), so its outward normal is (dz, -dr) in (r, z)
            dr, dz = r1 - r0, z1 - z0
            amid = (a0 + a1) / 2
            out = np.array([dz * math.cos(amid), dz * math.sin(amid), -dr])
            for t in ((p00, p01, p11), (p00, p11, p10)):
                a, b_, c = t
                nrm = np.cross(b_ - a, c - a)
                if np.linalg.norm(nrm) < 1e-12:
                    continue
                tris.append(t if np.dot(nrm, out) >= 0 else (a, c, b_))
    return tris


def extrude(poly, z0, z1, transform=None):
    """any simple 2D polygon (x, y) extruded along Z; front faces +Z"""
    P = Polygon(poly)
    if not P.exterior.is_ccw:
        P = Polygon(list(P.exterior.coords)[::-1])
    tris = []
    for t in shapely.constrained_delaunay_triangles(P).geoms:
        (ax, ay), (bx, by), (cx, cy) = list(t.exterior.coords)[:3]
        a, b, c = np.array([ax, ay, z1]), np.array([bx, by, z1]), np.array([cx, cy, z1])
        tris.append((a, b, c) if np.cross(b - a, c - a)[2] > 0 else (a, c, b))
        a, b, c = np.array([ax, ay, z0]), np.array([bx, by, z0]), np.array([cx, cy, z0])
        tris.append((a, b, c) if np.cross(b - a, c - a)[2] < 0 else (a, c, b))
    coords = list(P.exterior.coords)[:-1]
    for i in range(len(coords)):
        (x0, y0), (x1, y1) = coords[i], coords[(i + 1) % len(coords)]
        out = np.array([y1 - y0, -(x1 - x0), 0.0])  # anticlockwise outline: outward is to the right of travel
        q = [np.array([x0, y0, z0]), np.array([x1, y1, z0]), np.array([x1, y1, z1]), np.array([x0, y0, z1])]
        for t in ((q[0], q[1], q[2]), (q[0], q[2], q[3])):
            a, b, c = t
            tris.append(t if np.dot(np.cross(b - a, c - a), out) >= 0 else (a, c, b))
    if transform is not None:
        tris = [tuple(transform(p) for p in t) for t in tris]
    return tris


def mirror_x(tris):
    return [tuple(np.array([-p[0], p[1], p[2]]) for p in (a, c, b)) for a, b, c in tris]


def move(tris, d):
    d = np.array(d, float)
    return [tuple(p + d for p in t) for t in tris]


def cracks_on(poly, z, n, width=0.07, lift=0.02, inset=0.3, to3d=None):
    """`n` short jagged crack lines inside a 2D outline, as thin raised strips at depth z"""
    P = Polygon(poly).buffer(-inset)
    if P.is_empty:
        return []
    minx, miny, maxx, maxy = P.bounds
    tris = []
    for _ in range(n):
        for _try in range(20):
            x, y = rng.uniform(minx, maxx), rng.uniform(miny, maxy)
            if P.contains(shapely.Point(x, y)):
                break
        pts = [(x, y)]
        ang = rng.uniform(0, 2 * math.pi)
        for _seg in range(rng.randint(2, 4)):
            ang += rng.uniform(-0.9, 0.9)
            L = rng.uniform(0.35, 0.8)
            x, y = x + math.cos(ang) * L, y + math.sin(ang) * L
            pts.append((x, y))
        line = LineString(pts).intersection(P)
        if line.is_empty:
            continue
        geoms = getattr(line, "geoms", [line])
        for g in geoms:
            if g.length < 0.2:
                continue
            strip = g.buffer(width / 2, cap_style="flat", join_style="mitre")
            if strip.geom_type != "Polygon":
                continue
            ext = list(strip.exterior.coords)[:-1]
            tris += extrude(ext, z - 0.01, z + lift, to3d)
    return tris


# ---------------------------------------------------------------- base
base, blocks, glow, cracks = [], [], [], []
BASE_Z0, BASE_Z1 = -4.0, 2.2
base += bevel_slab(octagon(23.6, BASE_Z1 - BASE_Z0, 1.5, cz=(BASE_Z0 + BASE_Z1) / 2), 0.0, LEDGE_TOP, 0.2)
# three steps up the middle: the stand under the wheel, then two below it (450-810 px and 365-890 px wide)
STAND_Z1, STEP2_Z1, STEP1_Z1 = 3.6, 4.9, 6.2
base += bevel_box((0, STAND_TOP / 2, (-1.2 + STAND_Z1) / 2), (7.0, STAND_TOP, STAND_Z1 + 1.2), 0.15)
base += bevel_box((0, 2.16 / 2, (STAND_Z1 - 0.2 + STEP2_Z1) / 2), (10.2, 2.16, STEP2_Z1 - STAND_Z1 + 0.2), 0.15)
base += bevel_box((0, 1.08 / 2, (STEP2_Z1 - 0.2 + STEP1_Z1) / 2), (10.2, 1.08, STEP1_Z1 - STEP2_Z1 + 0.2), 0.15)
glow += bevel_box((0, 2.3, STAND_Z1 + 0.02), (6.4, 0.1, 0.06), 0.0)
glow += bevel_box((0, 1.22, STEP2_Z1 + 0.02), (9.4, 0.08, 0.06), 0.0)
for face_z, x0, x1, y0, y1 in ((STAND_Z1, -3.2, 3.2, 2.4, STAND_TOP - 0.2), (STEP2_Z1, -4.8, 4.8, 1.3, 2.0), (STEP1_Z1, -4.8, 4.8, 0.2, 0.9)):
    cracks += cracks_on([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], 0, 3, inset=0.05, to3d=lambda p, fz=face_z: np.array([p[0], p[1], fz + p[2]]))
# the stepped blocks either side of the stairs (front view: inner tall, middle low, outer corner), and the two blocks
# stacked against each post's outer foot
FRONT_BLOCKS = [  # (x0, x1, top, z0, z1)
    (5.1, 7.7, 2.84, 1.9, 4.6),
    (7.7, 9.7, 2.06, 1.9, 4.3),
    (9.7, 11.6, 2.65, 1.2, 3.5),
]
for s_ in (-1, 1):
    for x0, x1, top, z0, z1 in FRONT_BLOCKS:
        cx = s_ * (x0 + x1) / 2
        blocks.extend(bevel_box((cx, top / 2, (z0 + z1) / 2), (x1 - x0 - 0.06, top, z1 - z0), 0.16, yaw=s_ * rng.uniform(-0.04, 0.04)))
        xa, xb = sorted((s_ * (x0 + 0.25), s_ * (x1 - 0.25)))
        cracks.extend(cracks_on([(xa, 0.25), (xb, 0.25), (xb, top - 0.25), (xa, top - 0.25)], 0, 2, inset=0.05,
                                to3d=lambda p, fz=z1: np.array([p[0], p[1], fz + p[2]])))
    blocks.extend(bevel_box((s_ * 9.95, (LEDGE_TOP + 5.88) / 2, POST_Z - 0.2), (1.7, 5.88 - LEDGE_TOP + 0.1, 2.0), 0.14, yaw=s_ * 0.05))
    blocks.extend(bevel_box((s_ * 9.2, (5.78 + 7.45) / 2, POST_Z - 0.3), (1.45, 7.45 - 5.78, 1.8), 0.12, yaw=-s_ * 0.06))
# blocks along the back edge
for i in range(6):
    x = -9.6 + i * 3.84
    h = rng.uniform(0.5, 0.8)
    blocks.extend(bevel_box((x, LEDGE_TOP + h / 2 - 0.05, BASE_Z0 + 0.8), (3.7, h, 1.4), 0.12, yaw=rng.uniform(-0.05, 0.05)))

# ---------------------------------------------------------------- posts (the left one, measured off the concept; the right mirrors it)
# They rise from the ledge leaning in to hug the rim (behind it), then go up nearly straight to a slanted top; one short
# arm branches outward near the top and ends in a hook the lantern hangs from.
POST = [  # convex slabs, bottom to top, each overlapping the one below
    [(-9.75, 3.0), (-7.35, 3.0), (-7.29, 7.35), (-9.64, 7.35)],
    [(-9.64, 7.1), (-7.29, 7.1), (-7.15, 10.68), (-6.9, 12.64), (-9.15, 12.64), (-9.55, 10.68)],
    [(-9.15, 12.4), (-6.9, 12.4), (-6.41, 14.6), (-5.6, 16.2), (-8.0, 16.2), (-8.47, 14.6)],
    [(-8.0, 15.9), (-5.6, 15.9), (-4.74, 17.54), (-6.41, 21.23), (-8.08, 20.5), (-8.1, 18.5)],
]
ARM = [  # (outline, depth)
    ([(-7.4, 15.9), (-7.3, 16.9), (-9.45, 18.15), (-9.75, 17.3)], 1.2),
    ([(-10.65, 18.0), (-9.6, 18.25), (-9.65, 16.75), (-10.55, 16.6)], 1.3),
]
LANTERN_HOOK = (-10.1, 16.6)  # the hook's underside: the lantern hangs from here
post, post_cracks = [], []
for poly in POST:
    post += bevel_prism(poly, POST_Z - POST_D / 2, POST_Z + POST_D / 2, 0.16)
    post_cracks += cracks_on(poly, POST_Z + POST_D / 2, 7, inset=0.22)
for poly, d in ARM:
    post += bevel_prism(poly, POST_Z - d / 2, POST_Z + d / 2, 0.14)
post_L = post
post_R = mirror_x(post_L)
cracks += post_cracks + mirror_x(post_cracks)

# ---------------------------------------------------------------- frame and pointer
frame = []
PILLAR_Z = WHEEL_Z - 1.6  # behind the wheel's backing (-0.75)
BAR_Y0 = WHEEL_Y + R_OUT + 0.08  # the bar over the top clears the rim
MOUNT_Z0, MOUNT_Z1 = WHEEL_Z + 0.55, WHEEL_Z + 1.35  # the mount block in front of the rim's top (the rim turns behind it)
frame += bevel_box((0, (LEDGE_TOP + BAR_Y0 + 0.5) / 2, PILLAR_Z), (2.0, BAR_Y0 + 0.5 - LEDGE_TOP, 1.2), 0.14)
frame += bevel_box((0, BAR_Y0 + 0.25, (PILLAR_Z - 0.6 + MOUNT_Z1) / 2), (2.2, 0.5, MOUNT_Z1 - PILLAR_Z + 0.6), 0.12)
frame += bevel_box((0, (17.54 + 18.42) / 2, (MOUNT_Z0 + MOUNT_Z1) / 2), (5.0, 18.42 - 17.54, MOUNT_Z1 - MOUNT_Z0), 0.14)
for s_ in (-1, 1):  # angled cheeks either side of the crystal on the mount
    frame += bevel_box((s_ * 1.7, 18.6, MOUNT_Z1 - 0.3), (1.0, 0.7, 0.7), 0.1, yaw=s_ * 0.4)
axle = lathe([(0, -0.6), (0.7, -0.6), (0.7, 0.6), (0, 0.6)], 12, (0, WHEEL_Y, PILLAR_Z + 0.6 + 0.3))
def bipyramid(cx, cy, cz, top, bottom, rx, rz, girdle, tilt=0.0):
    pts = [(0, top, 0), (0, -bottom, 0)]
    for i in range(6):
        a = 2 * math.pi * i / 6 + math.pi / 6
        pts.append((rx * math.cos(a), girdle, rz * math.sin(a)))
    c, s = math.cos(tilt), math.sin(tilt)
    return hull([(cx + x * c - y * s, cy + x * s + y * c, cz + z) for x, y, z in pts])
CRYSTAL_Z = MOUNT_Z1 + 0.35
# 92 px top, 180 px girdle (widest, 135 px across), 305 px tip
crystal = bipyramid(0, 18.9, CRYSTAL_Z, 20.64 - 18.9, 18.9 - 16.46, 1.31, 0.5, 0.0)
crystal += bipyramid(-1.2, 19.35, CRYSTAL_Z - 0.15, 0.95, 0.4, 0.34, 0.24, 0.1, tilt=math.radians(35))
crystal += bipyramid(1.2, 19.35, CRYSTAL_Z - 0.15, 0.95, 0.4, 0.34, 0.24, 0.1, tilt=math.radians(-35))

# ---------------------------------------------------------------- wheel (about the axis through (0, WHEEL_Y, WHEEL_Z))
C = (0, WHEEL_Y, WHEEL_Z)
backing = lathe([(0, -0.75), (R_OUT - 0.25, -0.75), (R_OUT - 0.25, -0.3), (0, -0.3)], 32, C, phase=math.pi / 32)
rim = lathe([(R_RIM, -0.6), (R_OUT, -0.6), (R_OUT, 0.3), (R_OUT - 0.2, 0.5), (R_RIM + 0.15, 0.5), (R_RIM, 0.35)], 32, C, phase=math.pi / 32)
rim_inner = lathe([(R_IN - 0.05, -0.35), (R_RIM + 0.02, -0.35), (R_RIM + 0.02, 0.16), (R_IN - 0.05, 0.16)], 32, C, phase=math.pi / 32)
hub = lathe([(0, -0.35), (R_HUB, -0.35), (R_HUB, 0.3), (R_HUB - 0.12, 0.5), (1.5, 0.5), (1.37, 0.18), (0, 0.18)], 24, C)
# one sector, the top slot (67.5 to 112.5 degrees), a hair narrower than 45 so neighbours never share a face
arc = [math.radians(67.5 + 0.15 + (45 - 0.3) * i / 8) for i in range(9)]
sec_r0, sec_r1 = R_HUB - 0.1, R_IN
sec_poly = [(sec_r1 * math.cos(a), sec_r1 * math.sin(a)) for a in arc] + [(sec_r0 * math.cos(a), sec_r0 * math.sin(a)) for a in reversed(arc)]
sector = extrude(sec_poly, -0.32, -0.02, lambda p: np.array([p[0] + C[0], p[1] + C[1], p[2] + C[2]]))
# one divider, on the top slot's left edge (112.5 degrees)
a = math.radians(112.5)
u = np.array([math.cos(a), math.sin(a)])
nrm = np.array([-u[1], u[0]]) * 0.08
div_poly = [tuple(u * (sec_r0 - 0.05) - nrm), tuple(u * (sec_r1 + 0.1) - nrm), tuple(u * (sec_r1 + 0.1) + nrm), tuple(u * (sec_r0 - 0.05) + nrm)]
divider = extrude(div_poly, -0.3, 0.05, lambda p: np.array([p[0] + C[0], p[1] + C[1], p[2] + C[2]]))
# one gem on the rim's face at 60 degrees (345 px out, 55 px across): a bevelled square pyramid, set diamond-wise
GEM_A = math.radians(60)
gr = (R_RIM + R_OUT) / 2
gc = np.array([C[0] + gr * math.cos(GEM_A), C[1] + gr * math.sin(GEM_A), C[2] + 0.5])
gem_pts = []
for i in range(4):
    t = math.pi / 2 * i + GEM_A
    gem_pts.append(gc + np.array([0.55 * math.cos(t), 0.55 * math.sin(t), -0.05]))
    gem_pts.append(gc + np.array([0.42 * math.cos(t), 0.42 * math.sin(t), 0.2]))
gem_pts.append(gc + np.array([0, 0, 0.48]))
gem = hull(gem_pts)

# keep the posts clear of the turning wheel: behind its backing, and their arms outside its silhouette
assert POST_Z + POST_D / 2 < WHEEL_Z - 0.6, "the posts must stand behind the rim"

NODES = [
    ("BaseStone", base, (74, 63, 99)),
    ("BaseBlocks", blocks, (93, 83, 121)),
    ("StepGlow", glow, (180, 92, 255)),
    ("PostL", post_L, (98, 88, 124)),
    ("PostR", post_R, (98, 88, 124)),
    ("Cracks", cracks, (40, 34, 58)),
    ("BackFrame", frame, (40, 36, 62)),
    ("Axle", axle, (58, 48, 54)),
    ("Crystal", crystal, (200, 110, 255)),
    ("WheelBacking", backing, (17, 18, 38)),
    ("WheelRim", rim, (32, 28, 52)),
    ("WheelRimInner", rim_inner, (58, 40, 92)),
    ("Sector", sector, (255, 150, 30)),
    ("Divider", divider, (170, 90, 255)),
    ("Gem", gem, (150, 75, 235)),
    ("Hub", hub, (32, 28, 52)),
]

def write_glb(path, meshes):
    bin_ = bytearray(); views = []; accessors = []; gmeshes = []; nodes = []; materials = []

    def view(data, target):
        while len(bin_) % 4: bin_.append(0)
        off = len(bin_); bin_.extend(data)
        views.append({'buffer': 0, 'byteOffset': off, 'byteLength': len(data), 'target': target})
        return len(views) - 1
    for name, tris, color in meshes:
        pos, nrm, uv = [], [], []
        for a, b, c in tris:
            n = np.cross(b - a, c - a); n = n / max(np.linalg.norm(n), 1e-9)
            for p in (a, b, c):
                pos.append(p); nrm.append(n); uv.append((0.0, 0.0))
        pos = np.array(pos, np.float32); nrm = np.array(nrm, np.float32); uv = np.array(uv, np.float32)
        ind = np.arange(len(pos), dtype=np.uint32)
        acc = {}
        for key, arr, typ in (('POSITION', pos, 'VEC3'), ('NORMAL', nrm, 'VEC3'), ('TEXCOORD_0', uv, 'VEC2')):
            a = {'bufferView': view(arr.tobytes(), 34962), 'componentType': 5126, 'count': len(arr), 'type': typ}
            if key == 'POSITION':
                a['min'] = pos.min(0).tolist(); a['max'] = pos.max(0).tolist()
            accessors.append(a); acc[key] = len(accessors) - 1
        accessors.append({'bufferView': view(ind.tobytes(), 34963), 'componentType': 5125, 'count': len(ind), 'type': 'SCALAR'})
        materials.append({'name': name, 'pbrMetallicRoughness': {'baseColorFactor': [c / 255 for c in color] + [1], 'metallicFactor': 0, 'roughnessFactor': 0.9}})
        gmeshes.append({'name': name, 'primitives': [{'attributes': acc, 'indices': len(accessors) - 1, 'material': len(materials) - 1}]})
        nodes.append({'name': name, 'mesh': len(gmeshes) - 1})
    while len(bin_) % 4: bin_.append(0)
    gltf = {'asset': {'version': '2.0', 'generator': 'HOS-LOBBY-007 spin wheel'}, 'scene': 0,
            'scenes': [{'name': 'SpinWheel', 'nodes': list(range(len(nodes)))}], 'nodes': nodes, 'meshes': gmeshes,
            'materials': materials, 'accessors': accessors, 'bufferViews': views, 'buffers': [{'byteLength': len(bin_)}]}
    j = json.dumps(gltf, separators=(',', ':')).encode()
    while len(j) % 4: j += b' '
    out = struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(j) + 8 + len(bin_)) + struct.pack('<II', len(j), 0x4E4F534A) + j + struct.pack('<II', len(bin_), 0x004E4942) + bytes(bin_)
    open(path, 'wb').write(out)


if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else 'SpinWheel.glb'
    write_glb(out, NODES)
    total = 0
    for name, tris, _ in NODES:
        pts = np.array([p for t in tris for p in t])
        total += len(tris)
        print(f"{name:14s} {len(tris):5d} tris  centre {np.round((pts.min(0) + pts.max(0)) / 2, 3).tolist()}  size {np.round(pts.max(0) - pts.min(0), 3).tolist()}")
    print('total triangles', total)
    print(f'wheel centre (0, {WHEEL_Y:.3f}, {WHEEL_Z:.3f}); lantern hooks (+-{-LANTERN_HOOK[0]:.3f}, {LANTERN_HOOK[1]:.3f}, {POST_Z:.3f}); ledge top {LEDGE_TOP}')
