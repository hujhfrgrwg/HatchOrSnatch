"""Thunder Toad (Tempest Common), to Hunter's concept library sheet (docs/pets/concepts). HOS-PET-014.
Concept: a round blue toad, heavy angry brows over big yellow eyes, a big cream throat sac and belly, yellow
lightning markings and back spikes, stubby legs with yellow toes. Rigged (rigid skin), animated from code
(Idle, Walk, Run, Hop, Ability = a big croak), baked colour texture.
blender --background --factory-startup --python tools/pets/thunder_toad.py -- <abs outdir>
"""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import petkit as K
import rigkit as R
from mathutils import Vector

SLUG, SPECIES, PREFIX = "thunder_toad", "Thunder Toad", "Toad_"
OUT = K.outdir_arg(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "docs", "pets", SLUG))
os.makedirs(OUT, exist_ok=True)
K.reset()

BLUE = K.material("Toad_Blue", K.hexrgb(30, 79, 216), rough=0.18)         # #1E4FD8 cobalt, glossy vinyl
BLUE_DK = K.material("Toad_BlueDark", K.hexrgb(28, 35, 72), rough=0.4)      # #1C2348 navy (grin line, underside)
CREAM = K.material("Toad_Cream", K.hexrgb(252, 238, 186), rough=0.7)
GRIN = K.material("Toad_Grin", K.hexrgb(36, 50, 118), rough=0.5)        # #F7E7B0 soft
YELLOW = K.material("Toad_Yellow", K.hexrgb(255, 217, 59), rough=0.22)      # #FFD93B lightning
YELLOW_DK = K.material("Toad_YellowDark", K.hexrgb(232, 170, 20), rough=0.3)
MOUTH = K.material("Toad_Mouth", K.hexrgb(120, 30, 40), rough=0.6)
TONGUE = K.material("Toad_Tongue", K.hexrgb(240, 112, 72), rough=0.5)
IRIS = K.material("Eye_Iris", K.hexrgb(255, 210, 30), rough=0.05)
BLACK = K.material("Eye_Black", K.hexrgb(14, 14, 22), rough=0.05)
WHITE = K.material("Eye_White", K.hexrgb(255, 255, 255), rough=0.05)
# texture standard (HOS-PET-014): painted detail + PBR maps; the lightning markings, crest, warts and toe pads glow
for _m, _style, _k in ((BLUE, "skin", 0.7), (BLUE_DK, "dark", 0.7), (CREAM, "skin", 0.25), (YELLOW, "skin", 0.5), (YELLOW_DK, "skin", 0.5)):
    R.paint_material(_m, _style, strength=_k)

# ===== skeleton (Blender: front -Y, up +Z) =====
bones = [
    ("Root", (0, 0, 0), (0, 0, 0.3), None),
    ("Body", (0, 0.15, 0.55), (0, 0.15, 0.95), "Root"),
    ("Head", (0, -0.35, 0.8), (0, -0.85, 0.95), "Body"),
    ("Throat", (0, -0.6, 0.58), (0, -0.98, 0.58), "Head"),
    ("Mouth", (0, -0.85, 0.98), (0, -1.1, 0.98), "Head"),
    ("Tail", (0, 0.92, 0.7), (0, 1.25, 1.2), "Body"),
]
for side, sx in (("L", -1), ("R", 1)):
    bones += [
        (f"ArmU.{side}", (sx * 0.5, -0.58, 0.46), (sx * 0.72, -0.76, 0.26), "Body"),
        (f"ArmL.{side}", (sx * 0.72, -0.76, 0.26), (sx * 0.8, -0.92, 0.04), f"ArmU.{side}"),
        (f"LegU.{side}", (sx * 0.6, 0.4, 0.42), (sx * 0.86, 0.3, 0.26), "Body"),
        (f"LegL.{side}", (sx * 0.86, 0.3, 0.26), (sx * 0.94, -0.02, 0.04), f"LegU.{side}"),
    ]
arm = R.armature(bones)

import bmesh
from mathutils import Matrix as _M


def on_ellipsoid(c, r, d):
    d = Vector(d).normalized()
    p = Vector(c) + Vector((d.x * r[0], d.y * r[1], d.z * r[2]))
    n = Vector((d.x / r[0], d.y / r[1], d.z / r[2])).normalized()
    return p, n


def decal_bolt(builder, mat, p, n, size, spin, bone, thick=0.07, sink=0.045, both=False):
    """A bold flat lightning-bolt marking lying on the skin at p (normal n), long axis turned by `spin` degrees."""
    up = Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((0, 1, 0))
    v = (up - n * up.dot(n)).normalized()
    u = v.cross(n).normalized()
    a = math.radians(spin)
    u, v = u * math.cos(a) + v * math.sin(a), v * math.cos(a) - u * math.sin(a)
    pts = [(-0.2, -0.5), (0.14, -0.5), (0.04, -0.06), (0.34, -0.08), (-0.06, 0.56), (0.03, 0.12), (-0.3, 0.14)]

    def g(bm):
        vs = [bm.verts.new(p - n * sink + (u * x + v * y) * size) for x, y in pts]
        f = bm.faces.new(vs)
        if f.normal.dot(n) < 0:
            f.normal_flip()
        ext = bmesh.ops.extrude_face_region(bm, geom=[f])
        bmesh.ops.translate(bm, verts=[e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)], vec=n * thick)
        if not both:  # a marking: its base is buried in the skin
            bmesh.ops.delete(bm, geom=[f], context="FACES")
        bmesh.ops.triangulate(bm, faces=bm.faces[:], ngon_method="EAR_CLIP")
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    builder.add(g, mat, _M.Identity(4), bone)


def tube(builder, mat, pts, r, bone, segs=4):
    """A thin tube through points (the grin line)."""
    pts = [Vector(p) for p in pts]

    def g(bm):
        rings = []
        for i, p in enumerate(pts):
            t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
            a = t.cross(Vector((0, 1, 0))).normalized()
            b2 = t.cross(a).normalized()
            rings.append([bm.verts.new(p + (a * math.cos(2 * math.pi * k / segs) + b2 * math.sin(2 * math.pi * k / segs)) * r) for k in range(segs)])
        for i in range(len(rings) - 1):
            for k in range(segs):
                j = (k + 1) % segs
                bm.faces.new((rings[i][k], rings[i][j], rings[i + 1][j], rings[i + 1][k]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    builder.add(g, mat, _M.Identity(4), bone)


# ===== L1 body (Hunter's model sheet: glossy rounded vinyl-toy cobalt toad, cream belly/throat, bold yellow lightning) =====
BODY_C, BODY_R = (0, 0.12, 0.62), (0.98, 0.95, 0.66)
HEAD_C, HEAD_R = (0, -0.5, 1.0), (0.9, 0.64, 0.56)
b = R.RigBuilder(PREFIX + "Body")
b.sphere(BLUE, BODY_C, BODY_R, segs=12, rings=8, bone="Body")
b.sphere(CREAM, (0, -0.35, 0.44), (0.8, 0.74, 0.38), segs=10, rings=5, bone="Body")
b.sphere(BLUE, HEAD_C, HEAD_R, segs=12, rings=8, bone="Head")
for side in (-1, 1):
    b.sphere(BLUE, (side * 0.44, -0.72, 1.42), (0.33, 0.32, 0.31), segs=6, rings=5, bone="Head")  # eye bumps on top of the head
    b.sphere(BLUE, (side * 0.43, -0.95, 1.67), (0.35, 0.17, 0.12), segs=8, rings=4, rot=(18, side * -20, 0), bone="Head")  # heavy brow blended into the eye bump, low toward the centre
# the cream throat sac, its top tucked under the grin line (pumps on its own bone)
b.sphere(CREAM, (0, -0.95, 0.6), (0.68, 0.42, 0.38), segs=10, rings=6, bone="Throat")
# a wide friendly grin across the face, curving up at the corners
grin = []
for i in range(9):
    x = -0.56 + 1.12 * i / 8
    z = 1.0 + 0.11 * (x / 0.56) ** 2
    dz = (z - HEAD_C[2]) / HEAD_R[2]
    k = max(0.0, 1 - (x / HEAD_R[0]) ** 2 - dz ** 2)
    grin.append((x, HEAD_C[1] - HEAD_R[1] * math.sqrt(k) + 0.012, z))
tube(b, GRIN, grin, 0.016, "Head", segs=3)
# the open mouth (hidden inside the head at rest; slides out on the croak)
b.sphere(MOUTH, (0, -0.95, 0.98), (0.42, 0.08, 0.13), segs=6, rings=3, bone="Mouth")
b.sphere(TONGUE, (0, -0.99, 0.93), (0.24, 0.06, 0.06), segs=5, rings=2, bone="Mouth")
# spiky yellow crest behind the head
# one big yellow lightning-shaped crest standing up behind the head (as on the sheet)
# bold lightning bolts: a big one down the back, one on each flank, thigh and foreleg
p, n = on_ellipsoid(BODY_C, BODY_R, (0, 0.8, 0.62));        decal_bolt(b, YELLOW, p, n, 0.95, 0, "Body")
decal_bolt(b, YELLOW, Vector((0, -0.3, 1.78)), Vector((1, 0, 0)), 0.78, -12, "Head", thick=0.12, sink=0.06, both=True)  # the crest
for side, sx in (("L", -1), ("R", 1)):
    p, n = on_ellipsoid(BODY_C, BODY_R, (sx, 0.1, 0.3)); decal_bolt(b, YELLOW, p, n, 0.58, sx * 10, "Body")
    p, n = on_ellipsoid((sx * 0.84, 0.38, 0.38), (0.4, 0.52, 0.36), (sx, 0.05, 0.4)); decal_bolt(b, YELLOW, p, n, 0.36, 0, f"LegU.{side}", sink=0.06)
    p = Vector((sx * 0.83, -0.86, 0.26)); n = Vector((sx * 0.75, -0.66, 0.0)).normalized()
    decal_bolt(b, YELLOW, p, n, 0.3, 0, f"ArmL.{side}", sink=0.07)
# round yellow warts over the head and back
for d in ((0.5, 0.55, 0.65), (-0.55, 0.5, 0.6), (0.25, 0.1, 0.95), (-0.3, -0.05, 0.92), (0.8, 0.45, 0.25), (-0.8, 0.42, 0.28)):
    p, n = on_ellipsoid(BODY_C, BODY_R, d)
    b.sphere(YELLOW, tuple(p), (0.075, 0.075, 0.06), segs=4, rings=3, bone="Body")
# chunky rounded limbs, round yellow toe-pad domes
for side, sx in (("L", -1), ("R", 1)):
    b.sphere(BLUE, (sx * 0.62, -0.66, 0.38), (0.24, 0.24, 0.26), segs=7, rings=4, bone=f"ArmU.{side}")
    b.limb(BLUE, (sx * 0.72, -0.76, 0.26), (sx * 0.8, -0.92, 0.07), 0.2, 0.17, segs=8, bone=f"ArmL.{side}")
    b.sphere(BLUE, (sx * 0.84, 0.38, 0.38), (0.4, 0.52, 0.36), segs=8, rings=5, bone=f"LegU.{side}")
    b.limb(BLUE, (sx * 0.86, 0.3, 0.26), (sx * 0.94, -0.02, 0.07), 0.18, 0.16, segs=8, bone=f"LegL.{side}")
    for foot, bn, n_pads in (((sx * 0.8, -0.98, 0.06), f"ArmL.{side}", 3), ((sx * 0.95, -0.1, 0.06), f"LegL.{side}", 2)):
        for k in ((-1, 0, 1) if n_pads == 3 else (-0.55, 0.55)):
            b.sphere(YELLOW, (foot[0] + k * 0.13, foot[1] - 0.08 + abs(k) * 0.05, foot[2]), (0.095, 0.1, 0.075), segs=8, rings=3, bone=bn)
body = b.finish_rigged(arm, smooth_angle=62)

# ===== face: big round glossy yellow eyes; the round dark pupils and the large + small highlights are PAINTED
# into the eye texture (perfect circles at any mesh resolution, like the Kitsune's painted face) =====
EYE_X, EYE_Y, EYE_Z, EYE_S = 0.44, -0.93, 1.44, 0.29


def paint_eye(mat):
    nt = mat.node_tree
    N, L = nt.nodes, nt.links
    bsdf = next(n for n in N if n.type == "BSDF_PRINCIPLED")
    tc = N.new("ShaderNodeTexCoord")
    sep = N.new("ShaderNodeSeparateXYZ")
    L.new(tc.outputs["Object"], sep.inputs["Vector"])
    ax = N.new("ShaderNodeMath"); ax.operation = "ABSOLUTE"
    L.new(sep.outputs["X"], ax.inputs[0])

    def disc(cx, cz, r, soft=0.008):
        """1 inside the circle (|x|, z) around (cx, cz) radius r on the eye's front, else 0."""
        dx = N.new("ShaderNodeMath"); dx.operation = "SUBTRACT"; L.new(ax.outputs[0], dx.inputs[0]); dx.inputs[1].default_value = cx
        dz = N.new("ShaderNodeMath"); dz.operation = "SUBTRACT"; L.new(sep.outputs["Z"], dz.inputs[0]); dz.inputs[1].default_value = cz
        c = N.new("ShaderNodeCombineXYZ"); L.new(dx.outputs[0], c.inputs["X"]); L.new(dz.outputs[0], c.inputs["Y"])
        ln = N.new("ShaderNodeVectorMath"); ln.operation = "LENGTH"; L.new(c.outputs[0], ln.inputs[0])
        m = N.new("ShaderNodeMapRange"); m.inputs["From Min"].default_value = r - soft; m.inputs["From Max"].default_value = r + soft
        m.inputs["To Min"].default_value, m.inputs["To Max"].default_value = 1.0, 0.0
        L.new(ln.outputs["Value"], m.inputs["Value"])
        front = N.new("ShaderNodeMath"); front.operation = "LESS_THAN"; L.new(sep.outputs["Y"], front.inputs[0]); front.inputs[1].default_value = EYE_Y - 0.06
        both = N.new("ShaderNodeMath"); both.operation = "MULTIPLY"; L.new(m.outputs["Result"], both.inputs[0]); L.new(front.outputs[0], both.inputs[1])
        return both.outputs[0]

    def mix(a, color, fac):
        mm = N.new("ShaderNodeMix"); mm.data_type = "RGBA"
        L.new(fac, mm.inputs["Factor"])
        if isinstance(a, tuple):
            mm.inputs[6].default_value = tuple(a)[:4]
        else:
            L.new(a, mm.inputs[6])
        mm.inputs[7].default_value = tuple(color)[:4]
        return mm.outputs[2]
    cx, cz = EYE_X - 0.02, EYE_Z - 0.01
    col = mix(tuple(bsdf.inputs["Base Color"].default_value), K.hexrgb(205, 130, 10), disc(cx, cz, EYE_S * 0.86, 0.06))  # warm rim
    col = mix(col, tuple(bsdf.inputs["Base Color"].default_value), disc(cx, cz, EYE_S * 0.66, 0.05))
    col = mix(col, K.hexrgb(14, 14, 22), disc(cx, cz, EYE_S * 0.5))                         # big round pupil
    col = mix(col, K.hexrgb(255, 255, 255), disc(EYE_X + 0.04, EYE_Z + 0.08, EYE_S * 0.17))   # large highlight
    col = mix(col, K.hexrgb(255, 255, 255), disc(EYE_X - 0.07, EYE_Z - 0.08, EYE_S * 0.07))   # small highlight
    L.new(col, bsdf.inputs["Base Color"])


paint_eye(IRIS)
f = R.RigBuilder(PREFIX + "Face")
for side in (-1, 1):
    f.sphere(IRIS, (side * EYE_X, EYE_Y, EYE_Z), (EYE_S, EYE_S * 0.62, EYE_S), segs=12, rings=7, bone="Head")
face = f.finish_rigged(arm, smooth_angle=89)

# ===== L2: a taller crest spike =====
l2 = R.RigBuilder(PREFIX + "L2")
l2.cone(YELLOW, (0, -0.48, 1.55), 0.1, 0.0, 0.46, segs=4, rot=(-22, 0, 0), bone="Head")
l2_ob = l2.finish_rigged(arm)

# ===== L3: crackling gold spikes down the back and a crest gem (plus a lightning aura in Studio) =====
l3 = R.RigBuilder(PREFIX + "L3")
for y in (0.18,):
    l3.cone(YELLOW_DK, (0, y, 1.3 - 0.14 * y), 0.09, 0.0, 0.3, segs=4, rot=(25, 0, 0), bone="Body")
l3.gem(YELLOW, (0, -0.5, 2.0), 0.06, bone="Head")
l3_ob = l3.finish_rigged(arm)

forms = {"L1": [body, face], "L2": [body, face, l2_ob], "L3": [body, face, l2_ob, l3_ob]}
tris = {k: sum(K.tri_count(o) for o in v) for k, v in forms.items()}
print("TRIS", {o.name: K.tri_count(o) for o in (body, face, l2_ob, l3_ob)}, "per form", tris)
assert tris["L3"] <= 2000, tris

# ===== animations (24 fps) =====
X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)
ALL = ["Root", "Body", "Head", "Throat", "Mouth", "Tail"] + [f"{p}.{s}" for s in "LR" for p in ("ArmU", "ArmL", "LegU", "LegL")]


def idle(fr):
    ph = fr / 48 * 2 * math.pi
    puff = max(0.0, math.sin(ph * 2))  # the throat sac pumps twice a loop
    return {"Body": (R.axis_q(X, 1.5 * math.sin(ph)), Vector((0, 0, 0.02 * math.sin(ph)))),
            "Head": (R.axis_q(Z, 5 * math.sin(ph * 0.5)), Vector()),
            "Throat": (R.axis_q(X, 0), Vector((0, -0.07 * puff, -0.02 * puff))),
            "Tail": (R.axis_q(Z, 10 * math.sin(ph)) @ R.axis_q(X, 4 * math.sin(ph * 2)), Vector())}


def walk(fr, n=24, swing=24, bob=0.05):
    ph = fr / n * 2 * math.pi
    p = {"Body": (R.axis_q(Y, 4 * math.sin(ph)), Vector((0, 0, bob * abs(math.sin(ph))))),
         "Head": (R.axis_q(Z, -4 * math.sin(ph)), Vector()),
         "Tail": (R.axis_q(Z, 12 * math.sin(ph)), Vector())}
    for s, sg in (("L", -1), ("R", 1)):
        a = math.sin(ph + (0 if s == "L" else math.pi))
        p[f"ArmU.{s}"] = (R.axis_q(X, swing * a), Vector())
        p[f"LegU.{s}"] = (R.axis_q(X, -swing * 0.8 * a), Vector())
    return p


def run(fr):
    """Hop-run: both back legs push together, body arcs forward."""
    t = fr / 16
    up = math.sin(math.pi * t)
    p = {"Body": (R.axis_q(X, -12 * up + 6), Vector((0, 0, 0.32 * up)))}
    for s in "LR":
        p[f"LegU.{s}"] = (R.axis_q(X, 40 * up), Vector())
        p[f"LegL.{s}"] = (R.axis_q(X, -30 * up), Vector())
        p[f"ArmU.{s}"] = (R.axis_q(X, -25 * up), Vector())
    return p


def hop(fr):
    t = fr / 16
    up = math.sin(math.pi * t)
    p = {"Body": (R.axis_q(X, -14 * up), Vector((0, 0, 0.5 * up)))}
    for s in "LR":
        p[f"LegU.{s}"] = (R.axis_q(X, 45 * up), Vector())
        p[f"ArmU.{s}"] = (R.axis_q(X, -30 * up), Vector())
    return p


def ability(fr):
    """A big croak: rears back, the throat sac balloons out, arms fling wide (Shockwave / Electric Ball)."""
    t = fr / 20
    rise = math.sin(math.pi * min(1.0, t * 1.4)) if t < 0.7 else max(0.0, 1 - (t - 0.7) / 0.3)
    rise = max(0.0, min(1.0, rise))
    puff = math.sin(math.pi * min(1.0, max(0.0, (t - 0.15) / 0.55)))
    p = {"Body": (R.axis_q(X, -16 * rise), Vector((0, 0, 0.1 * rise))),
         "Head": (R.axis_q(X, -10 * rise), Vector()),
         "Throat": (R.axis_q(X, 0), Vector((0, -0.22 * puff, -0.16 * rise - 0.04 * puff))),
         "Mouth": (R.axis_q(X, 0), Vector((0, -0.3 * rise, -0.1 * rise))),  # open-mouthed croak
         "Tail": (R.axis_q(X, 22 * rise), Vector())}
    for s, sg in (("L", -1), ("R", 1)):
        p[f"ArmU.{s}"] = (R.axis_q(Y, sg * 40 * rise) @ R.axis_q(X, -20 * rise), Vector())
    return p


ANIMS = {
    "Idle": {"frames": 48, "loop": True, "bones": ALL, "fn": idle, "step": 4},
    "Walk": {"frames": 24, "loop": True, "bones": ALL, "fn": walk, "step": 2},
    "Run": {"frames": 16, "loop": True, "bones": ALL, "fn": run, "step": 2},
    "Hop": {"frames": 16, "loop": False, "bones": ALL, "fn": hop, "step": 2},
    "Ability": {"frames": 20, "loop": False, "bones": ALL, "fn": ability, "step": 2},
}
R.write_anims(os.path.join(OUT, "ToadAnims.lua"), "Toad", "tools/pets/thunder_toad.py", ANIMS)

meshes = [body, face, l2_ob, l3_ob]
SHEEN = (K.hexrgb(235, 245, 255)[:3], {"Toad_Blue": 0.35, "Toad_Cream": 0.15, "Toad_Yellow": 0.25, "Eye_Iris": 0.3}, (-0.3, -0.45, 0.85))
tex = R.bake_textures(meshes, OUT, size=512, ao_strength=0.6, sheen=SHEEN, ao_distance=0.35, sizes={PREFIX + "Body": 1024},
                      emissive={"Toad_Yellow": 1.0, "Toad_YellowDark": 0.8}, pbr=True)
R.use_baked(meshes, tex)
R.export_fbx(os.path.join(OUT, SLUG + ".fbx"), [arm] + meshes)
import bpy
src = os.path.join(OUT, "src")
os.makedirs(src, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(src, SLUG + ".blend"))

K.setup_render(1024)
for o in (l2_ob, l3_ob):
    o.hide_render = True
K.render_views(1.5, 0.75, OUT, SLUG + "_L1", [("front", 0, 12), ("three_quarter", 38, 18), ("side", 90, 8), ("back", 180, 14)], dist=7.0)
sc = bpy.context.scene
cam = sc.camera
head_at = Vector((0, -0.95, 1.25))
for name, pos in (("head_closeup", Vector((1.1, -3.6, 1.6))), ("head_front", Vector((0.0, -3.8, 1.35)))):
    cam.location = pos
    cam.rotation_euler = (head_at - pos).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(OUT, f"{SLUG}_{name}.png")
    bpy.ops.render.render(write_still=True)
l2_ob.hide_render = False
K.render_views(1.5, 0.75, OUT, SLUG + "_L2", [("three_quarter", 38, 18)], dist=7.0)
l3_ob.hide_render = False
K.render_views(1.5, 0.75, OUT, SLUG + "_L3", [("three_quarter", 38, 18)], dist=7.0)
R.apply_pose_blender(arm, ability(10))
for o in (l2_ob, l3_ob):
    o.hide_render = True
K.render_views(1.5, 0.85, OUT, SLUG + "_ability_pose", [("three_quarter", 38, 14)], dist=7.2)
print("DONE")
