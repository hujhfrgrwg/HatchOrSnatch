"""Bastion Beetle (Guardian Common), v3 to Hunter's model sheet (docs/pets/concepts/bastion_beetle_model_sheet.png).
HOS-PET-013c. A stout armoured scarab: a domed shell of big overlapping ivory armour plates with thick bevelled
bronze rims (a rune on the side plates), a dark body underneath, a helmeted head with a forward-swept curved horn
with cyan crystal set into the horn and forehead, small NARROW glowing cyan eyes under a V brow, big
armour-plated front claws with cyan crystal insets, short dark legs with small armour plates, and a cyan crystal
on the back (L1 small, L2 bigger crystals + brighter eyes, L3 full crystal growth on back and shoulders).
Rigged (rigid skin), animated from code, baked colour texture with a baked sheen; eye glow mask baked for the
SurfaceAppearance emissive.
blender --background --factory-startup --python tools/pets/bastion_beetle.py -- <abs outdir>
"""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bmesh
import petkit as K
import rigkit as R
from mathutils import Vector, Matrix

SLUG, SPECIES, PREFIX = "bastion_beetle", "Bastion Beetle", "Beetle_"
OUT = K.outdir_arg(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "docs", "pets", SLUG))
os.makedirs(OUT, exist_ok=True)
K.reset()

IVORY = K.material("Beetle_Ivory", K.hexrgb(237, 227, 207), rough=0.45)      # #EDE3CF
BRONZE = K.material("Beetle_Bronze", K.hexrgb(176, 122, 58), rough=0.35)     # #B07A3A
BRONZE_DK = K.material("Beetle_BronzeDark", K.hexrgb(118, 78, 34), rough=0.45)
DARK = K.material("Beetle_Dark", K.hexrgb(58, 58, 64), rough=0.6)            # #3A3A40
DARK_LT = K.material("Beetle_DarkLight", K.hexrgb(84, 84, 94), rough=0.55)
CRYSTAL = K.material("Beetle_Crystal", K.hexrgb(63, 200, 255), rough=0.2)    # #3FC8FF
CRYSTAL_LT = K.material("Beetle_CrystalLight", K.hexrgb(155, 230, 255), rough=0.2)  # #9BE6FF
EYE = K.material("Eye_Glow", K.hexrgb(90, 214, 255), rough=0.2)
EYE_HOT = K.material("Eye_GlowHot", K.hexrgb(214, 248, 255), rough=0.2)
SOCKET = K.material("Eye_Socket", K.hexrgb(22, 24, 30), rough=0.5)
# PBR (Hunter 17 Oct, "premium"): bronze rims metallic, ivory satin, crystals glossy; read by rigkit's pbr bake
for _m, _metal in ((BRONZE, 1.0), (BRONZE_DK, 0.85)):
    _m["metal"] = _metal
for _m, _r in ((IVORY, 0.55), (BRONZE, 0.3), (BRONZE_DK, 0.4), (DARK, 0.75), (DARK_LT, 0.6), (CRYSTAL, 0.08), (CRYSTAL_LT, 0.08), (EYE, 0.1), (EYE_HOT, 0.1)):
    next(n for n in _m.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Roughness"].default_value = _r
# painted surface detail baked into the colour / normal maps (HOS-PET-014 texture standard)
for _m, _style in ((IVORY, "filigree"), (BRONZE, "metal"), (BRONZE_DK, "metal"), (CRYSTAL, "crystal"), (CRYSTAL_LT, "crystal"), (DARK, "dark"), (DARK_LT, "dark")):
    R.paint_material(_m, _style)


# ===== plate primitives =====
def _plate_geom(base, nrm, center, ncenter, thick, bevel, inset, bulge):
    """Rim (base -> top ring -> bevel down to the inner ring) and a cushioned face (inner ring -> mid -> centre)."""
    n = len(base)
    area = sum(((base[i] - center).cross(base[(i + 1) % n] - center)).dot(ncenter) for i in range(n))
    if area < 0:  # wind the outline counter-clockwise seen from outside, so every face points outward
        base, nrm = base[::-1], nrm[::-1]
    top = [base[i] + nrm[i] * thick for i in range(n)]
    inner = [base[i].lerp(center, inset) + nrm[i].lerp(ncenter, inset).normalized() * (thick + bevel) for i in range(n)]
    mid = [base[i].lerp(center, 0.55) + nrm[i].lerp(ncenter, 0.55).normalized() * (thick + bevel + bulge * 0.7) for i in range(n)]
    tip = center + ncenter * (thick + bevel + bulge)
    sink = [base[i] - nrm[i] * 0.03 for i in range(n)]

    def rim(bm):
        rings = [[bm.verts.new(v) for v in ring] for ring in (sink, top, inner)]
        for a, b in ((0, 1), (1, 2)):
            for i in range(n):
                j = (i + 1) % n
                bm.faces.new((rings[a][i], rings[a][j], rings[b][j], rings[b][i]))

    def face(bm):
        ri = [bm.verts.new(v) for v in inner]
        rm = [bm.verts.new(v) for v in mid]
        c = bm.verts.new(tip)
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((ri[i], ri[j], rm[j], rm[i]))
            bm.faces.new((rm[i], rm[j], c))
    return rim, face


def _fix_normals(fn):
    def g(bm):
        fn(bm)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return g


def add_plate(b, base, nrm, center, ncenter, bone, rim_mat=BRONZE, face_mat=IVORY, thick=0.07, bevel=0.05, inset=0.24, bulge=0.05):
    rim, face = _plate_geom(base, nrm, center, ncenter, thick, bevel, inset, bulge)
    # the rim/face pieces are open shells, outward winding is fixed per piece from its own vertex order
    b.add(rim, rim_mat, Matrix.Identity(4), bone)
    b.add(face, face_mat, Matrix.Identity(4), bone)


def flat_plate(b, origin, n, v, outline, bone, bend=0.0, scale=1.0, **kw):
    """A plate in the plane (origin, u = v x n, v), outline in (u, v) units, edges bent back by `bend`."""
    o, n, v = Vector(origin), Vector(n).normalized(), Vector(v)
    v = (v - n * v.dot(n)).normalized()
    u = v.cross(n).normalized()
    base, nrm = [], []
    for x, y in outline:
        x, y = x * scale, y * scale
        r2 = x * x + y * y
        base.append(o + u * x + v * y - n * bend * r2)
        nrm.append((n + (u * x + v * y) * bend * 2).normalized())
    add_plate(b, base, nrm, o, n, bone, **kw)
    return o, u, v, n


SHELL_C, SHELL_R = Vector((0, 0.15, 0.5)), Vector((0.98, 1.1, 1.04))


def shell_point(d):
    d = Vector(d).normalized()
    p = SHELL_C + Vector((d.x * SHELL_R.x, d.y * SHELL_R.y, d.z * SHELL_R.z))
    nrm = Vector((d.x / SHELL_R.x, d.y / SHELL_R.y, d.z / SHELL_R.z)).normalized()
    return p, nrm


def shell_plate(b, dirs, cdir, bone, smooth=False, **kw):
    if smooth:  # extra outline points on the dome between corners: rounder, more curved plates
        dirs = [x for i, d in enumerate(dirs) for x in (d, tuple((Vector(d).normalized() + Vector(dirs[(i + 1) % len(dirs)]).normalized()) / 2))]
    pts = [shell_point(d) for d in dirs]
    c, cn = shell_point(cdir)
    add_plate(b, [p for p, _ in pts], [n for _, n in pts], c, cn, bone, **kw)
    return c, cn


def framed(b, mat, center, u, v, n, size, kind="gem", bone="Body", lift=0.0):
    """A gem/crystal set into a plate face: local x = u, y = n (out of the face), z = v."""
    m = Matrix((
        (u.x * size[0], -n.x * size[1], v.x * size[2], center.x + n.x * lift),
        (u.y * size[0], -n.y * size[1], v.y * size[2], center.y + n.y * lift),
        (u.z * size[0], -n.z * size[1], v.z * size[2], center.z + n.z * lift),
        (0, 0, 0, 1)))
    if kind == "gem":
        def g(bm):
            vs = [bm.verts.new(p) for p in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1.4), (0, 0, -1.4))]
            for a, bb, c in ((0, 2, 4), (2, 1, 4), (1, 3, 4), (3, 0, 4), (2, 0, 5), (1, 2, 5), (3, 1, 5), (0, 3, 5)):
                bm.faces.new((vs[a], vs[bb], vs[c]))
        b.add(g, mat, m, bone)


def crystal(b, base, direction, length, radius, bone, mat=CRYSTAL, segs=5, twist=0):
    """A faceted crystal shard: a short prism with a pointed tip."""
    base, d = Vector(base), Vector(direction).normalized()
    q = d.to_track_quat("Z", "Y")
    m = Matrix.Translation(base) @ q.to_matrix().to_4x4() @ Matrix.Rotation(math.radians(twist), 4, "Z")

    def g(bm):
        ring0 = [bm.verts.new((radius * 0.8 * math.cos(2 * math.pi * i / segs), radius * 0.8 * math.sin(2 * math.pi * i / segs), -0.05)) for i in range(segs)]
        ring1 = [bm.verts.new((radius * math.cos(2 * math.pi * i / segs), radius * math.sin(2 * math.pi * i / segs), length * 0.62)) for i in range(segs)]
        tip = bm.verts.new((0, 0, length))
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((ring0[i], ring0[j], ring1[j], ring1[i]))
            bm.faces.new((ring1[i], ring1[j], tip))
    b.add(_fix_normals(g), mat, m, bone)


# ===== skeleton (Blender: front -Y, up +Z) =====
LEGS = [("M", 0.02), ("B", 0.6)]
bones = [
    ("Root", (0, 0, 0), (0, 0, 0.3), None),
    ("Body", (0, 0.1, 0.5), (0, 0.1, 0.9), "Root"),
    ("ShellL", (-0.22, 0.15, 1.3), (-0.22, 0.75, 1.3), "Body"),
    ("ShellR", (0.22, 0.15, 1.3), (0.22, 0.75, 1.3), "Body"),
    ("Head", (0, -0.8, 0.62), (0, -1.3, 0.7), "Body"),
    ("Horn", (0, -1.25, 1.12), (0, -1.45, 1.6), "Head"),
]
for side, sx in (("L", -1), ("R", 1)):
    bones.append((f"ArmU.{side}", (sx * 0.5, -0.62, 0.72), (sx * 0.8, -0.82, 0.62), "Body"))
    bones.append((f"ArmL.{side}", (sx * 0.8, -0.82, 0.62), (sx * 0.9, -0.95, 0.05), f"ArmU.{side}"))
for tag, y in LEGS:
    for side, sx in (("L", -1), ("R", 1)):
        bones.append((f"Leg{tag}U.{side}", (sx * 0.55, y, 0.42), (sx * 0.85, y, 0.3), "Body"))
        bones.append((f"Leg{tag}L.{side}", (sx * 0.85, y, 0.3), (sx * 0.98, y + 0.04, 0.0), f"Leg{tag}U.{side}"))
arm = R.armature(bones)

# ===== L1 body =====
b = R.RigBuilder(PREFIX + "Body")
# dark understructure
b.sphere(DARK, (0, 0.12, 0.44), (0.84, 1.08, 0.32), segs=8, rings=5, bone="Body")


# the shell frame: a bronze half-dome under the plates (the gaps between plates read as bronze straps)
def dome(bm):
    bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=8, radius=1.0)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -0.05], context="VERTS")


b.add(dome, BRONZE_DK, Matrix.Translation(SHELL_C) @ Matrix.Diagonal((*SHELL_R * 0.985, 1)), "Body")
# centre ridge plate, front to back over the top
shell_plate(b, [(0.2, -0.62, 0.72), (0.24, 0.0, 1), (0.2, 0.5, 0.82), (-0.2, 0.5, 0.82), (-0.24, 0.0, 1), (-0.2, -0.62, 0.72)], (0, -0.04, 1), "Body", smooth=True)
RUNES = []
for side, bn in ((1, "ShellR"), (-1, "ShellL")):
    def S(*d):
        return (side * d[0], d[1], d[2])
    # upper side plate
    shell_plate(b, [S(0.42, -0.66, 0.62), S(0.4, -0.05, 0.92), S(0.38, 0.46, 0.76), S(0.76, 0.42, 0.42), S(0.86, -0.08, 0.48), S(0.72, -0.62, 0.38)],
                S(0.68, -0.08, 0.66), bn, smooth=True)
    # big lower side plate (the rune plate)
    c, cn = shell_plate(b, [S(0.84, -0.56, 0.26), S(0.98, -0.06, 0.36), S(0.88, 0.44, 0.3), S(0.86, 0.5, -0.04), S(1, -0.06, -0.08), S(0.84, -0.6, -0.04)],
                        S(1, -0.06, 0.12), bn, smooth=True)
    RUNES.append((c, cn, bn))
    # rear quarter plate
    shell_plate(b, [S(0.3, 0.76, 0.58), S(0.72, 0.48, 0.38), S(0.8, 0.56, 0.0), S(0.36, 0.92, -0.04), S(0.18, 0.98, 0.24)], S(0.48, 0.78, 0.26), bn)
    # front shoulder plate behind the head
    shell_plate(b, [S(0.3, -0.86, 0.4), S(0.62, -0.68, 0.32), S(0.7, -0.66, 0.0), S(0.34, -0.92, -0.02)], S(0.5, -0.8, 0.18), bn)
# rear: the crystal set in a bronze diamond at the back (L1 small)
rc, rcn = shell_plate(b, [(0, 0.78, 0.62), (0.24, 0.96, 0.28), (0, 1, -0.06), (-0.24, 0.96, 0.28)], (0, 1, 0.28), "Body", face_mat=CRYSTAL, inset=0.3, bulge=0.08)
# the rune on each big side plate: a bronze sun cross set into the ivory
for c, cn, bn in RUNES:
    v = (Vector((0, 0, 1)) - cn * cn.z).normalized()
    u = v.cross(cn).normalized()
    framed(b, BRONZE, c, u, v, cn, (0.16, 0.025, 0.05), bone=bn, lift=0.16)
    framed(b, BRONZE, c, u, v, cn, (0.05, 0.025, 0.16), bone=bn, lift=0.16)
# head: dark core, a bronze-rimmed ivory helmet with a V brow, a lower face mask, the horn with its crystal edge
b.sphere(DARK, (0, -1.04, 0.66), (0.42, 0.4, 0.36), segs=8, rings=6, bone="Head")
HELM = [(0, 0.44), (0.36, 0.32), (0.48, 0.04), (0.3, -0.12), (0, -0.3), (-0.3, -0.12), (-0.48, 0.04), (-0.36, 0.32)]
ho, hu, hv, hn = flat_plate(b, (0, -1.27, 0.98), (0, -0.87, 0.5), (0, 0.5, 0.87), HELM, "Head", bend=0.42)
framed(b, CRYSTAL, ho + hv * 0.04, hu, hv, hn, (0.1, 0.06, 0.15), bone="Head", lift=0.15)
MASK = [(0, 0.1), (0.3, 0.16), (0.36, 0.0), (0.18, -0.2), (0, -0.3), (-0.18, -0.2), (-0.36, 0.0), (-0.3, 0.16)]
flat_plate(b, (0, -1.38, 0.5), (0, -0.96, 0.27), (0, 0.27, 0.96), MASK, "Head", bend=0.5)
# the horn: a forward-swept sickle blade (diamond section) with a cyan crystal edge on its concave side
def sweep(b, mat, path, widths, bone, shift=0.0):
    pts = [Vector(p) for p in path]
    side = Vector((1, 0, 0))
    rings = []
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        d = t.cross(side).normalized()
        if d.y < 0:
            d = -d
        wx, wd = widths[i]
        c = p + d * wd * shift
        rings.append([c + side * wx, c + d * wd, c - side * wx, c - d * wd])

    def g(bm):
        vr = [[bm.verts.new(v) for v in ring] for ring in rings[:-1]]
        tip = bm.verts.new(rings[-1][0].lerp(rings[-1][2], 0.5))
        bm.faces.new(vr[0][::-1])
        for i in range(len(vr) - 1):
            for k in range(4):
                j = (k + 1) % 4
                bm.faces.new((vr[i][k], vr[i][j], vr[i + 1][j], vr[i + 1][k]))
        for k in range(4):
            bm.faces.new((vr[-1][k], vr[-1][(k + 1) % 4], tip))
    b.add(_fix_normals(g), mat, Matrix.Identity(4), bone)


HORN = [(0, -1.2, 1.12), (0, -1.42, 1.36), (0, -1.56, 1.64), (0, -1.52, 1.9), (0, -1.36, 2.08)]
sweep(b, BRONZE, HORN, [(0.12, 0.15), (0.1, 0.13), (0.08, 0.11), (0.05, 0.07), (0, 0)], "Horn")
sweep(b, CRYSTAL, HORN[1:], [(0.06, 0.12), (0.05, 0.1), (0.03, 0.07), (0, 0)], "Horn", shift=0.55)
# big armour-plated front claws (shoulder plate + a long claw plate with a crystal inset)
CLAW = [(0, 0.5), (0.24, 0.32), (0.23, -0.16), (0, -0.64), (-0.23, -0.16), (-0.24, 0.32)]
SHOULDER = [(0, 0.2), (0.2, 0.12), (0.2, -0.1), (0, -0.2), (-0.2, -0.1), (-0.2, 0.12)]
for side, sx in (("L", -1), ("R", 1)):
    b.limb(DARK, (sx * 0.5, -0.62, 0.72), (sx * 0.8, -0.84, 0.66), 0.13, 0.11, segs=5, bone=f"ArmU.{side}")
    flat_plate(b, (sx * 0.72, -0.8, 0.96), (sx * 0.6, -0.55, 0.58), (0, 0.4, 1), SHOULDER, f"ArmU.{side}", bend=0.6)
    co, cu, cv, cn = flat_plate(b, (sx * 0.9, -0.96, 0.6), (sx * 0.8, -0.6, 0.0), (0, 0.06, 1), CLAW, f"ArmL.{side}", bend=0.32)
    framed(b, CRYSTAL, co, cu, cv, cn, (0.08, 0.06, 0.14), bone=f"ArmL.{side}", lift=0.14)
    b.cone(DARK_LT, (sx * 0.86, -0.98, 0.03), 0.06, 0.0, 0.16, segs=4, rot=(-60, 0, 0), bone=f"ArmL.{side}")
# short dark legs with small armour plates on the shins
SHIN = [(0, 0.2), (0.1, 0.1), (0.09, -0.08), (0, -0.24), (-0.09, -0.08), (-0.1, 0.1)]
for tag, y in LEGS:
    for side, sx in (("L", -1), ("R", 1)):
        hip, knee, foot = Vector((sx * 0.55, y, 0.42)), Vector((sx * 0.85, y, 0.3)), Vector((sx * 0.98, y + 0.04, 0.0))
        b.limb(DARK, hip, knee, 0.12, 0.1, segs=5, bone=f"Leg{tag}U.{side}")
        b.limb(DARK, knee, foot, 0.1, 0.04, segs=5, bone=f"Leg{tag}L.{side}")
        flat_plate(b, knee.lerp(foot, 0.4) + Vector((sx * 0.06, 0, 0)), (sx * 0.9, -0.2, 0.25), foot - knee, SHIN, f"Leg{tag}L.{side}",
                   bend=0.4, thick=0.04, bevel=0.03, inset=0.28, bulge=0.03)
body = b.finish_rigged(arm)

# ===== face: small narrow glowing cyan eyes in dark sockets under the V brow (same on L1-L3) =====
f = R.RigBuilder(PREFIX + "Face")
for side in (-1, 1):
    x, y, z = side * 0.21, -1.39, 0.74
    f.sphere(SOCKET, (x, y + 0.02, z), (0.15, 0.05, 0.075), segs=8, rings=3, rot=(0, -side * 18, 0), bone="Head")
    f.sphere(EYE, (x, y - 0.025, z), (0.11, 0.035, 0.038), segs=8, rings=3, rot=(0, -side * 18, 0), bone="Head")
    f.sphere(EYE_HOT, (x + side * 0.01, y - 0.05, z + 0.003), (0.05, 0.02, 0.016), segs=6, rings=3, rot=(0, -side * 18, 0), bone="Head")
face = f.finish_rigged(arm)

# ===== L2: a bigger crystal cluster on the back and brighter eye glow =====
l2 = R.RigBuilder(PREFIX + "L2")
crystal(l2, (0, 0.62, 1.12), (0, 0.55, 1), 0.46, 0.16, "Body")
crystal(l2, (0.16, 0.5, 1.18), (0.5, 0.3, 1), 0.3, 0.1, "Body", mat=CRYSTAL_LT)
crystal(l2, (-0.16, 0.5, 1.18), (-0.5, 0.3, 1), 0.3, 0.1, "Body", mat=CRYSTAL_LT)
for side in (-1, 1):
    l2.sphere(EYE_HOT, (side * 0.21, -1.445, 0.744), (0.085, 0.012, 0.02), segs=6, rings=3, rot=(0, -side * 18, 0), bone="Head")
l2_ob = l2.finish_rigged(arm)

# ===== L3: full crystal growth on the back and shoulders =====
l3 = R.RigBuilder(PREFIX + "L3")
crystal(l3, (0, 0.18, 1.38), (0, 0.3, 1), 0.5, 0.15, "Body")
crystal(l3, (0, -0.3, 1.36), (0, -0.1, 1), 0.36, 0.11, "Body", mat=CRYSTAL_LT)
for side, bn in ((-1, "ShellL"), (1, "ShellR")):
    crystal(l3, (side * 0.62, 0.0, 1.12), (side * 0.8, 0.1, 1), 0.42, 0.13, bn)
    crystal(l3, (side * 0.66, 0.4, 0.98), (side * 0.9, 0.5, 0.8), 0.3, 0.1, bn, mat=CRYSTAL_LT)
    crystal(l3, (side * 0.74, -0.86, 1.1), (side * 0.6, -0.2, 1), 0.34, 0.1, f"ArmU.{'L' if side < 0 else 'R'}")
l3_ob = l3.finish_rigged(arm)

forms = {"L1": [body, face], "L2": [body, face, l2_ob], "L3": [body, face, l2_ob, l3_ob]}
tris = {k: sum(K.tri_count(o) for o in v) for k, v in forms.items()}
print("TRIS", {o.name: K.tri_count(o) for o in (body, face, l2_ob, l3_ob)}, "per form", tris)
assert tris["L3"] <= 2000, tris

# ===== animations (24 fps), bone deltas in Blender model axes =====
X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)
LIMBS = [("Arm", "L"), ("Arm", "R"), ("LegM", "L"), ("LegM", "R"), ("LegB", "L"), ("LegB", "R")]
TRIPOD_A = {("Arm", "L"), ("LegM", "R"), ("LegB", "L")}
LIMB_NAMES = [f"{p}{k}.{s}" for p, s in LIMBS for k in "UL"]
ALL = ["Root", "Body", "ShellL", "ShellR", "Head", "Horn"] + LIMB_NAMES


def limbs_pose(ph, swing, lift):
    out = {}
    for p, s in LIMBS:
        side = -1 if s == "L" else 1
        q = ph + (0 if (p, s) in TRIPOD_A else math.pi)
        fwd = math.sin(q) * swing * (0.6 if p == "Arm" else 1.0)
        up = max(0.0, math.cos(q)) * lift * (0.5 if p == "Arm" else 1.0)
        out[f"{p}U.{s}"] = (R.axis_q(Z, -side * fwd) @ R.axis_q(Y, -side * up), Vector())
    return out


def idle(fr):
    ph = fr / 48 * 2 * math.pi
    breath = (1 + math.sin(ph)) / 2
    return {"Body": (R.axis_q(X, 1.0 * math.sin(ph)), Vector((0, 0, 0.02 * math.sin(ph)))),
            "ShellL": (R.axis_q(Y, 1.5 * breath), Vector()),
            "ShellR": (R.axis_q(Y, -1.5 * breath), Vector()),
            "Head": (R.axis_q(Z, 6 * math.sin(ph * 0.5)) @ R.axis_q(X, -2 * math.sin(ph)), Vector()),
            "Horn": (R.axis_q(X, 2 * math.sin(ph + 1)), Vector()),
            "ArmU.L": (R.axis_q(Y, 2 * breath), Vector()),
            "ArmU.R": (R.axis_q(Y, -2 * breath), Vector())}


def walk(fr, n=24, swing=20, lift=16, bob=0.035):
    ph = fr / n * 2 * math.pi
    p = limbs_pose(ph, swing, lift)
    p["Body"] = (R.axis_q(Y, 2.5 * math.sin(ph)) @ R.axis_q(X, 1.2 * math.sin(2 * ph)), Vector((0, 0, bob * abs(math.sin(ph)))))
    p["Head"] = (R.axis_q(Z, -4 * math.sin(ph)), Vector())
    return p


def run(fr):
    return walk(fr, n=16, swing=28, lift=24, bob=0.06)


def hop(fr):
    t = fr / 16
    up = math.sin(math.pi * t)
    p = {"Body": (R.axis_q(X, -8 * up), Vector((0, 0, 0.4 * up)))}
    for pp, s in LIMBS:
        side = -1 if s == "L" else 1
        p[f"{pp}U.{s}"] = (R.axis_q(Y, side * 18 * up), Vector())
    return p


def ability(fr):
    """Rears up, the shell plates flare open, the claws spread and the horn thrusts forward: 0.8 s."""
    t = fr / 20
    rise = math.sin(math.pi * min(1.0, t * 1.6)) if t < 0.62 else max(0.0, 1 - (t - 0.62) / 0.38)
    rise = max(0.0, min(1.0, rise))
    thrust = math.sin(math.pi * min(1.0, max(0.0, t - 0.12) * 2.4)) if t < 0.54 else 0.0
    p = {"Body": (R.axis_q(X, -16 * rise), Vector((0, 0.06 * rise, 0.14 * rise))),
         "ShellL": (R.axis_q(Y, 22 * rise), Vector((0, 0, 0.05 * rise))),
         "ShellR": (R.axis_q(Y, -22 * rise), Vector((0, 0, 0.05 * rise))),
         "Head": (R.axis_q(X, 10 * thrust - 6 * rise), Vector((0, -0.08 * thrust, 0))),
         "Horn": (R.axis_q(X, 28 * thrust), Vector())}
    for s in "LR":
        side = -1 if s == "L" else 1
        p[f"ArmU.{s}"] = (R.axis_q(Z, side * 18 * rise) @ R.axis_q(Y, -side * 22 * rise), Vector())
    return p


ANIMS = {
    "Idle": {"frames": 48, "loop": True, "bones": ALL, "fn": idle, "step": 4},
    "Walk": {"frames": 24, "loop": True, "bones": ALL, "fn": walk, "step": 2},
    "Run": {"frames": 16, "loop": True, "bones": ALL, "fn": run, "step": 2},
    "Hop": {"frames": 16, "loop": False, "bones": ALL, "fn": hop, "step": 2},
    "Ability": {"frames": 20, "loop": False, "bones": ALL, "fn": ability, "step": 2},
}
R.write_anims(os.path.join(OUT, "BeetleAnims.lua"), "Beetle", "tools/pets/bastion_beetle.py", ANIMS)

# ===== texture (sheen on armour and crystal), export, renders =====
meshes = [body, face, l2_ob, l3_ob]
SHEEN = (K.hexrgb(255, 248, 228)[:3],
         {"Beetle_Ivory": 0.3, "Beetle_Bronze": 0.3, "Beetle_BronzeDark": 0.15, "Beetle_Crystal": 0.45, "Beetle_CrystalLight": 0.35},
         (-0.3, -0.45, 0.85))
tex = R.bake_textures(meshes, OUT, size=512, ao_strength=0.6, sheen=SHEEN, ao_distance=0.35, sizes={PREFIX + "Body": 1024},
                       emissive={"Eye_Glow": 1.0, "Eye_GlowHot": 1.0, "Beetle_Crystal": 0.85, "Beetle_CrystalLight": 1.0}, pbr=True)
R.use_baked(meshes, tex)
R.export_fbx(os.path.join(OUT, SLUG + ".fbx"), [arm] + meshes)
import bpy
src = os.path.join(OUT, "src")
os.makedirs(src, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(src, SLUG + ".blend"))

K.setup_render(1024)
for o in (l2_ob, l3_ob):
    o.hide_render = True
K.render_views(1.7, 0.8, OUT, SLUG + "_L1", [("front", 0, 10), ("three_quarter", 38, 18), ("side", 90, 6), ("back", 180, 14)], dist=7.6)
sc = bpy.context.scene
cam = sc.camera
head_at = Vector((0, -1.3, 0.92))
for name, pos in (("head_closeup", Vector((1.0, -3.4, 1.3))), ("head_front", Vector((0.0, -3.6, 1.05)))):
    cam.location = pos
    cam.rotation_euler = (head_at - pos).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(OUT, f"{SLUG}_{name}.png")
    bpy.ops.render.render(write_still=True)
l2_ob.hide_render = False
K.render_views(1.7, 0.85, OUT, SLUG + "_L2", [("three_quarter", 38, 18)], dist=7.6)
l3_ob.hide_render = False
K.render_views(1.7, 0.9, OUT, SLUG + "_L3", [("three_quarter", 38, 18), ("back", 180, 18)], dist=7.6)
R.apply_pose_blender(arm, ability(9))
for o in (l2_ob, l3_ob):
    o.hide_render = True
K.render_views(1.7, 1.0, OUT, SLUG + "_ability_pose", [("three_quarter", 38, 14)], dist=7.8)
print("DONE")
