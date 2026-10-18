"""HOS-LOBBY-007 (18 Oct 2026, Matthew): meshes for the Halloween spin wheel, after Matthew's front-view concept
(docs/HOS-LOBBY-007/spin_wheel_frame_concept.webp): "frame needs to look like this ... it needs to be meshes for mostly
everything".

Writes one GLB, every node already in place (units are studs, +Y up, the front faces +Z, the origin on the ground under
the middle of the base). HOS-LOBBY-007_spin_wheel_meshes.lua assembles the import in Studio.
  BaseStone     stepped octagonal plinth, the wheel's tier, two front steps, the cradle under the wheel, stone stacks
                under the posts (bevelled, low-poly)
  BaseBlocks    chunky bevelled blocks round the plinth's sides and back (a second stone tone)
  StepGlow      glow strips on the step and tier risers (neon)
  PostL, PostR  angular stone posts: four bevelled slabs stacked and leaning outward, with a hooked arm for the lantern
  Cracks        dark crack lines carved into the posts' and blocks' faces
  BackFrame     a pillar behind the wheel with a bar over the top that holds the pointer
  Axle          the axle from the pillar to the wheel (hidden behind it)
  Crystal       the pointer: a long faceted crystal with two small side crystals (neon)
  WheelBacking  the dark disc behind the sectors
  WheelRim      the thick bevelled rim; WheelRimInner a thin band inside it
  Sector        ONE sector (the top slot); the Studio script copies it round the wheel 8 times
  Divider       ONE divider (on the top slot's left edge as you face it); copied 8 times (neon)
  Gem           ONE faceted stud on the rim (at 60 degrees); copied round the rim, skipping the top under the pointer
  Hub           the raised hub ring; HubGlow a thin ring round it (neon)

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

# layout (local studs)
PLINTH_H, TIER_H = 0.9, 0.7
TIER_TOP = PLINTH_H + TIER_H
TIER_Z, TIER_D = -1.5, 8.0
WHEEL_Y = TIER_TOP + 0.9 + 7.45  # wheel centre height
WHEEL_Z = -1.2
POST_X, POST_Z = 10.0, -1.5
POST_Y = PLINTH_H + 1.5  # the posts stand on two stacked blocks


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
base += bevel_slab(octagon(26, 14, 2.6), 0.0, PLINTH_H, 0.15)
base += bevel_slab(octagon(19, TIER_D, 1.6, cz=TIER_Z), PLINTH_H - 0.05, TIER_TOP, 0.12)
tier_front = TIER_Z + TIER_D / 2
# step from the ground onto the plinth, and from the plinth onto the tier
base += bevel_box((0, 0.42 / 2, 7.0 + 0.55), (10, 0.42, 1.3), 0.08)
base += bevel_box((0, PLINTH_H + 0.36 / 2, tier_front + 0.55), (9, 0.36, 1.5), 0.08)
glow += bevel_box((0, 0.21, 7.0 + 1.2 + 0.03), (8.8, 0.07, 0.06), 0.0)
glow += bevel_box((0, PLINTH_H + 0.18, tier_front + 1.3 + 0.03), (7.8, 0.07, 0.06), 0.0)
glow += bevel_box((0, PLINTH_H + 0.36 + (TIER_H - 0.36) / 2, tier_front + 0.03), (15.0, 0.07, 0.06), 0.0)
# cradle under the wheel
cradle_top = WHEEL_Y - 7.45 - 0.03  # just under the rim, so the wheel can turn
base += bevel_box((0, (TIER_TOP + cradle_top) / 2, WHEEL_Z - 0.1), (6.5, cradle_top - TIER_TOP + 0.1, 2.0), 0.12)
# stone stacks under the posts
for s in (-1, 1):
    base += bevel_box((s * POST_X, PLINTH_H + 0.5, POST_Z), (4.4, 1.0, 4.0), 0.15, yaw=s * 0.05)
    base += bevel_box((s * POST_X, PLINTH_H + 1.0 + 0.25, POST_Z), (3.8, 0.55, 3.5), 0.12, yaw=-s * 0.08)
# chunky blocks round the sides and back of the plinth, two rows high near the posts
def block_row(x0, z0, x1, z1, rows=1):
    L = math.hypot(x1 - x0, z1 - z0)
    n = max(1, round(L / 2.6))
    yaw = -math.atan2(z1 - z0, x1 - x0)
    for i in range(n):
        t = (i + 0.5) / n
        x, z = x0 + (x1 - x0) * t, z0 + (z1 - z0) * t
        for r in range(rows):
            h = rng.uniform(0.7, 1.0) if r == 0 else rng.uniform(0.5, 0.7)
            y = PLINTH_H + h / 2 + (0.85 * r)
            size = (L / n - 0.08 - r * 0.4, h, rng.uniform(1.4, 1.9) - r * 0.3)
            blocks.extend(bevel_box((x, y, z), size, 0.12, yaw + rng.uniform(-0.08, 0.08)))
# chunky ledges either side of the steps (the pumpkins and candles sit on these), cracked on the front
LEDGE_X0, LEDGE_X1, LEDGE_Z0, LEDGE_Z1, LEDGE_H = 4.85, 10.65, 2.6, 6.6, 1.1
LEDGE_TOP = PLINTH_H + LEDGE_H
for s in (-1, 1):
    blocks.extend(bevel_box((s * (LEDGE_X0 + LEDGE_X1) / 2, PLINTH_H + LEDGE_H / 2, (LEDGE_Z0 + LEDGE_Z1) / 2), (LEDGE_X1 - LEDGE_X0, LEDGE_H, LEDGE_Z1 - LEDGE_Z0), 0.15))
    x0, x1 = sorted((s * (LEDGE_X0 + 0.2), s * (LEDGE_X1 - 0.2)))
    cracks.extend(cracks_on([(x0, PLINTH_H + 0.17), (x1, PLINTH_H + 0.17), (x1, LEDGE_TOP - 0.17), (x0, LEDGE_TOP - 0.17)], 0, 3, inset=0.05,
                            to3d=lambda p: np.array([p[0], p[1], LEDGE_Z1 + p[2]])))
block_row(-9.6, -6.1, 9.6, -6.1, rows=2)  # the back, clear of the octagon's cut corners
block_row(-12.1, 0.9, -12.1, 3.7)  # the sides, in front of the post stacks
block_row(12.1, 0.9, 12.1, 3.7)
# cracks on the plinth's front face
cracks += cracks_on([(-10.4, 0.1), (10.4, 0.1), (10.4, PLINTH_H - 0.1), (-10.4, PLINTH_H - 0.1)], 0, 6, inset=0.05,
                    to3d=lambda p: np.array([p[0], p[1], 7.0 + p[2]]))

# ---------------------------------------------------------------- posts (left, built at x < 0, then mirrored)
CHUNKS = [  # (outline (x outward-negative, y), depth); x = 0 is the post's centre line
    ([(-1.9, 0.0), (1.8, 0.0), (1.9, 5.6), (-1.7, 5.8)], 2.8),
    ([(-1.7, 5.4), (1.9, 5.2), (1.5, 10.6), (-1.9, 10.9)], 2.6),
    ([(-1.9, 10.5), (1.5, 10.2), (0.2, 14.6), (-3.0, 14.6)], 2.4),
    ([(-3.0, 14.2), (0.2, 14.3), (-1.0, 17.3), (-3.7, 16.5)], 2.2),
]
ARM = [  # the hooked arm out to the lantern
    ([(-1.5, 8.4), (-1.3, 9.9), (-3.6, 11.9), (-4.1, 10.7)], 1.5),
    ([(-4.3, 10.6), (-3.5, 12.1), (-5.7, 12.2), (-5.9, 11.1)], 1.4),
    ([(-5.95, 11.25), (-5.3, 11.3), (-5.25, 10.35), (-5.9, 10.3)], 1.3),
]
LANTERN_HOOK = (-5.6, 10.3)  # the arm's tip (post-local x, y): the lantern hangs from here
post, post_cracks = [], []
for poly, d in CHUNKS + ARM:
    post += bevel_prism(poly, -d / 2, d / 2, 0.16)
for poly, d in CHUNKS:  # cracks on each slab's front face
    post_cracks += cracks_on(poly, d / 2, 4)
post_L = move(post, (-POST_X, POST_Y, POST_Z))
post_R = mirror_x(post_L)
cl = move(post_cracks, (-POST_X, POST_Y, POST_Z))
cracks += cl + mirror_x(cl)

# ---------------------------------------------------------------- frame and pointer
frame = []
PILLAR_Z = WHEEL_Z - 1.75
BAR_Y = WHEEL_Y + 7.45 + 0.95
CRYSTAL_Z = WHEEL_Z + 1.45  # in front of the rim and its gems, so the wheel turns behind it
MOUNT_FRONT = CRYSTAL_Z - 0.35  # the bar stops behind the crystal, which sits against its front
frame += bevel_box((0, (TIER_TOP + BAR_Y) / 2, PILLAR_Z), (2.6, BAR_Y - TIER_TOP, 1.5), 0.15)
frame += bevel_box((0, BAR_Y + 0.15, (PILLAR_Z - 0.75 + MOUNT_FRONT) / 2), (2.4, 0.9, MOUNT_FRONT - PILLAR_Z + 0.75), 0.15)
frame += bevel_box((0, BAR_Y + 0.8, (PILLAR_Z - 0.75 + MOUNT_FRONT) / 2 + 0.2), (3.4, 0.45, MOUNT_FRONT - PILLAR_Z + 0.3), 0.12)  # the mount's cap
for s in (-1, 1):  # angled wings either side of the mount, behind the crystal
    frame += bevel_box((s * 1.55, BAR_Y + 0.2, MOUNT_FRONT - 0.45), (1.1, 0.7, 0.9), 0.1, yaw=s * 0.35)
axle = lathe([(0, -0.9), (0.75, -0.9), (0.75, 0.9), (0, 0.9)], 12, (0, WHEEL_Y, PILLAR_Z + 0.75 + 0.6))
def bipyramid(cx, cy, cz, top, bottom, rx, rz, girdle, tilt=0.0):
    pts = [(0, top, 0), (0, -bottom, 0)]
    for i in range(6):
        a = 2 * math.pi * i / 6 + math.pi / 6
        pts.append((rx * math.cos(a), girdle, rz * math.sin(a)))
    c, s = math.cos(tilt), math.sin(tilt)
    out = []
    for x, y, z in pts:
        out.append((cx + x * c - y * s, cy + x * s + y * c, cz + z))
    return hull(out)
crystal_y = WHEEL_Y + 6.7 + 2.3  # its point reaches down over the rim
crystal = bipyramid(0, crystal_y, CRYSTAL_Z, 2.0, 2.3, 1.0, 0.45, 0.35)
crystal += bipyramid(-1.15, crystal_y + 0.5, CRYSTAL_Z - 0.1, 0.95, 0.45, 0.36, 0.25, 0.1, tilt=math.radians(40))
crystal += bipyramid(1.15, crystal_y + 0.5, CRYSTAL_Z - 0.1, 0.95, 0.45, 0.36, 0.25, 0.1, tilt=math.radians(-40))

# ---------------------------------------------------------------- wheel (all about the axis through (0, WHEEL_Y, WHEEL_Z))
C = (0, WHEEL_Y, WHEEL_Z)
R_IN, R_OUT = 6.05, 7.45
backing = lathe([(0, -0.75), (7.2, -0.75), (7.2, -0.3), (0, -0.3)], 32, C, phase=math.pi / 32)
rim = lathe([(R_IN, -0.6), (R_OUT, -0.6), (R_OUT, 0.3), (R_OUT - 0.2, 0.5), (R_IN + 0.15, 0.5), (R_IN, 0.35)], 32, C, phase=math.pi / 32)
rim_inner = lathe([(R_IN - 0.3, -0.35), (R_IN + 0.02, -0.35), (R_IN + 0.02, 0.18), (R_IN - 0.3, 0.18)], 32, C, phase=math.pi / 32)
hub = lathe([(0, -0.35), (2.45, -0.35), (2.45, 0.3), (2.3, 0.5), (1.85, 0.5), (1.7, 0.18), (0, 0.18)], 24, C)
hub_glow = lathe([(2.42, -0.25), (2.62, -0.25), (2.62, 0.15), (2.42, 0.15)], 24, C)
# one sector, the top slot (67.5 to 112.5 degrees), a hair narrower than 45 so neighbours never share a face
arc = [math.radians(67.5 + 0.15 + (45 - 0.3) * i / 8) for i in range(9)]
sec_r0, sec_r1 = 2.35, R_IN - 0.25
sec_poly = [(sec_r1 * math.cos(a), sec_r1 * math.sin(a)) for a in arc] + [(sec_r0 * math.cos(a), sec_r0 * math.sin(a)) for a in reversed(arc)]
sector = extrude(sec_poly, -0.32, -0.02, lambda p: np.array([p[0] + C[0], p[1] + C[1], p[2] + C[2]]))
# one divider, on the top slot's left edge (112.5 degrees)
a = math.radians(112.5)
u = np.array([math.cos(a), math.sin(a)])
nrm = np.array([-u[1], u[0]]) * 0.09
div_poly = [tuple(u * (sec_r0 - 0.1) - nrm), tuple(u * (sec_r1 + 0.2) - nrm), tuple(u * (sec_r1 + 0.2) + nrm), tuple(u * (sec_r0 - 0.1) + nrm)]
divider = extrude(div_poly, -0.3, 0.06, lambda p: np.array([p[0] + C[0], p[1] + C[1], p[2] + C[2]]))
# one gem on the rim's face at 60 degrees: a bevelled square pyramid, set diamond-wise
GEM_A = math.radians(60)
gr = (R_IN + R_OUT) / 2
gc = np.array([C[0] + gr * math.cos(GEM_A), C[1] + gr * math.sin(GEM_A), C[2] + 0.5])
gem_pts = []
for i in range(4):
    t = math.pi / 4 * (2 * i) + GEM_A  # corners pointing along and across the radius
    gem_pts.append(gc + np.array([0.5 * math.cos(t), 0.5 * math.sin(t), -0.05]))
    gem_pts.append(gc + np.array([0.38 * math.cos(t), 0.38 * math.sin(t), 0.2]))
gem_pts.append(gc + np.array([0, 0, 0.48]))
gem = hull(gem_pts)

NODES = [
    ("BaseStone", base, (74, 63, 99)),
    ("BaseBlocks", blocks, (93, 83, 121)),
    ("StepGlow", glow, (180, 92, 255)),
    ("PostL", post_L, (98, 88, 124)),
    ("PostR", post_R, (98, 88, 124)),
    ("Cracks", cracks, (40, 34, 58)),
    ("BackFrame", frame, (68, 60, 94)),
    ("Axle", axle, (58, 48, 54)),
    ("Crystal", crystal, (200, 110, 255)),
    ("WheelBacking", backing, (17, 18, 38)),
    ("WheelRim", rim, (32, 28, 52)),
    ("WheelRimInner", rim_inner, (58, 40, 92)),
    ("Sector", sector, (255, 150, 30)),
    ("Divider", divider, (170, 90, 255)),
    ("Gem", gem, (150, 75, 235)),
    ("Hub", hub, (32, 28, 52)),
    ("HubGlow", hub_glow, (180, 92, 255)),
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
    print(f'ledge top {LEDGE_TOP:.3f} (pumpkins and candles stand here), plinth top {PLINTH_H}')
    print(f'wheel centre (0, {WHEEL_Y:.3f}, {WHEEL_Z:.3f}); lantern hooks (+-{POST_X - LANTERN_HOOK[0]:.3f}, {POST_Y + LANTERN_HOOK[1]:.3f}, {POST_Z:.3f})')
