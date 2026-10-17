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

BLUE = K.material("Toad_Blue", K.hexrgb(38, 112, 222), rough=0.4)
BLUE_DK = K.material("Toad_BlueDark", K.hexrgb(20, 54, 140), rough=0.5)
CREAM = K.material("Toad_Cream", K.hexrgb(246, 226, 206), rough=0.5)
YELLOW = K.material("Toad_Yellow", K.hexrgb(255, 204, 36), rough=0.35)
YELLOW_DK = K.material("Toad_YellowDark", K.hexrgb(214, 140, 10), rough=0.4)
MOUTH = K.material("Toad_Mouth", K.hexrgb(18, 30, 70), rough=0.6)
IRIS = K.material("Eye_Iris", K.hexrgb(255, 210, 50), rough=0.3)
BLACK = K.material("Eye_Black", K.hexrgb(16, 16, 24), rough=0.3)
WHITE = K.material("Eye_White", K.hexrgb(250, 250, 250), rough=0.3)
RIM = K.material("Eye_Rim", K.hexrgb(14, 36, 96), rough=0.5)

# ===== skeleton (Blender: front -Y, up +Z) =====
bones = [
    ("Root", (0, 0, 0), (0, 0, 0.3), None),
    ("Body", (0, 0.15, 0.55), (0, 0.15, 0.95), "Root"),
    ("Head", (0, -0.35, 0.8), (0, -0.85, 0.95), "Body"),
    ("Throat", (0, -0.6, 0.58), (0, -0.98, 0.58), "Head"),
]
for side, sx in (("L", -1), ("R", 1)):
    bones += [
        (f"ArmU.{side}", (sx * 0.5, -0.58, 0.46), (sx * 0.72, -0.76, 0.26), "Body"),
        (f"ArmL.{side}", (sx * 0.72, -0.76, 0.26), (sx * 0.8, -0.92, 0.04), f"ArmU.{side}"),
        (f"LegU.{side}", (sx * 0.6, 0.4, 0.42), (sx * 0.86, 0.3, 0.26), "Body"),
        (f"LegL.{side}", (sx * 0.86, 0.3, 0.26), (sx * 0.94, -0.02, 0.04), f"LegU.{side}"),
    ]
arm = R.armature(bones)

# ===== L1 body =====
b = R.RigBuilder(PREFIX + "Body")
b.sphere(BLUE, (0, 0.22, 0.6), (0.94, 0.92, 0.62), segs=12, rings=7, bone="Body")
b.sphere(CREAM, (0, -0.18, 0.4), (0.72, 0.72, 0.34), segs=10, rings=5, bone="Body")
# a wide head with eye bumps, heavy angry brows and a wide mouth line
b.sphere(BLUE, (0, -0.56, 0.94), (0.86, 0.6, 0.5), segs=12, rings=7, bone="Head")
for side in (-1, 1):
    b.sphere(BLUE, (side * 0.42, -0.74, 1.26), (0.29, 0.27, 0.27), segs=9, rings=6, bone="Head")
    b.sphere(BLUE_DK, (side * 0.4, -0.94, 1.48), (0.26, 0.09, 0.08), segs=6, rings=4, rot=(10, side * -26, 0), bone="Head")
    b.sphere(BLUE_DK, (side * 0.1, -1.1, 1.0), (0.04, 0.03, 0.03), segs=4, rings=3, bone="Head")  # nostrils
b.sphere(MOUTH, (0, -1.08, 0.84), (0.5, 0.05, 0.04), segs=8, rings=3, bone="Head")
# the big cream throat sac (pumps on its own bone)
b.sphere(CREAM, (0, -0.86, 0.6), (0.6, 0.44, 0.4), segs=10, rings=6, bone="Throat")
# yellow lightning markings: a zigzag down the head and back, and two back spikes
for (x, y, z, rot) in ((0.12, -0.45, 1.42, (0, 0, 35)), (-0.1, -0.1, 1.3, (0, 0, -35)), (0.12, 0.28, 1.2, (0, 0, 35)), (-0.08, 0.6, 1.0, (0, 0, -35))):
    b.sphere(YELLOW, (x, y, z), (0.11, 0.24, 0.05), segs=6, rings=3, rot=rot, bone="Head" if y < -0.2 else "Body")
for side in (-1, 1):
    b.cone(YELLOW, (side * 0.32, 0.36, 1.18), 0.12, 0.0, 0.34, segs=5, rot=(30, side * 28, 0), bone="Body")
    b.sphere(YELLOW, (side * 0.72, -0.2, 0.86), (0.12, 0.2, 0.05), segs=6, rings=3, rot=(0, side * 50, 25), bone="Body")
# stubby front arms and big folded back legs, yellow toes
for side, sx in (("L", -1), ("R", 1)):
    b.limb(BLUE, (sx * 0.5, -0.58, 0.46), (sx * 0.72, -0.76, 0.26), 0.15, 0.13, segs=6, bone=f"ArmU.{side}")
    b.limb(BLUE, (sx * 0.72, -0.76, 0.26), (sx * 0.8, -0.92, 0.06), 0.13, 0.11, segs=6, bone=f"ArmL.{side}")
    b.sphere(BLUE, (sx * 0.82, 0.38, 0.34), (0.34, 0.48, 0.3), segs=8, rings=5, bone=f"LegU.{side}")
    b.limb(BLUE, (sx * 0.86, 0.3, 0.26), (sx * 0.94, -0.02, 0.06), 0.13, 0.11, segs=6, bone=f"LegL.{side}")
    for foot, bn in (((sx * 0.8, -0.94, 0.03), f"ArmL.{side}"), ((sx * 0.94, -0.06, 0.03), f"LegL.{side}")):
        for k in (-1, 0, 1):
            b.sphere(YELLOW, (foot[0] + k * 0.09, foot[1] - 0.1 + abs(k) * 0.03, foot[2]), (0.06, 0.09, 0.035), segs=5, rings=3, bone=bn)
body = b.finish_rigged(arm)

# ===== face: big yellow eyes on the eye bumps (same on L1-L3) =====
f = R.RigBuilder(PREFIX + "Face")
for side in (-1, 1):
    x, y, z, s = side * 0.42, -0.94, 1.27, 0.2
    f.sphere(RIM, (x, y + 0.02, z), (s * 1.12, s * 0.5, s * 1.12), segs=6, rings=4, bone="Head")
    f.sphere(IRIS, (x, y, z), (s, s * 0.55, s), segs=8, rings=5, bone="Head")
    f.sphere(BLACK, (x - side * 0.02, y - 0.1, z - 0.02), (s * 0.42, s * 0.12, s * 0.56), segs=6, rings=3, bone="Head")
    f.sphere(WHITE, (x + side * 0.05, y - 0.12, z + 0.06), (s * 0.15, s * 0.05, s * 0.15), segs=4, rings=2, bone="Head")
face = f.finish_rigged(arm)

# ===== L2: yellow storm stripes on the legs and a lightning crest on the head =====
l2 = R.RigBuilder(PREFIX + "L2")
for side, sx in (("L", -1), ("R", 1)):
    l2.sphere(YELLOW, (sx * 0.94, 0.4, 0.46), (0.08, 0.22, 0.05), segs=5, rings=3, rot=(0, sx * 60, 30), bone=f"LegU.{side}")
l2.cone(YELLOW, (0, -0.62, 1.5), 0.1, 0.0, 0.3, segs=4, rot=(-15, 0, 0), bone="Head")
l2_ob = l2.finish_rigged(arm)

# ===== L3: crackling gold spikes down the back =====
l3 = R.RigBuilder(PREFIX + "L3")
for y in (-0.05, 0.25, 0.55):
    l3.cone(YELLOW_DK, (0, y, 1.3 - 0.1 * y), 0.09, 0.0, 0.3, segs=4, rot=(25, 0, 0), bone="Body")
l3.gem(YELLOW, (0, -0.62, 1.68), 0.06, bone="Head")
l3_ob = l3.finish_rigged(arm)

forms = {"L1": [body, face], "L2": [body, face, l2_ob], "L3": [body, face, l2_ob, l3_ob]}
tris = {k: sum(K.tri_count(o) for o in v) for k, v in forms.items()}
print("TRIS", {o.name: K.tri_count(o) for o in (body, face, l2_ob, l3_ob)}, "per form", tris)
assert tris["L3"] <= 2000, tris

# ===== animations (24 fps) =====
X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)
ALL = ["Root", "Body", "Head", "Throat"] + [f"{p}.{s}" for s in "LR" for p in ("ArmU", "ArmL", "LegU", "LegL")]


def idle(fr):
    ph = fr / 48 * 2 * math.pi
    puff = max(0.0, math.sin(ph * 2))  # the throat sac pumps twice a loop
    return {"Body": (R.axis_q(X, 1.5 * math.sin(ph)), Vector((0, 0, 0.02 * math.sin(ph)))),
            "Head": (R.axis_q(Z, 5 * math.sin(ph * 0.5)), Vector()),
            "Throat": (R.axis_q(X, 0), Vector((0, -0.07 * puff, -0.02 * puff)))}


def walk(fr, n=24, swing=24, bob=0.05):
    ph = fr / n * 2 * math.pi
    p = {"Body": (R.axis_q(Y, 4 * math.sin(ph)), Vector((0, 0, bob * abs(math.sin(ph))))),
         "Head": (R.axis_q(Z, -4 * math.sin(ph)), Vector())}
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
         "Throat": (R.axis_q(X, 0), Vector((0, -0.22 * puff, -0.06 * puff)))}
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
tex = R.bake_textures(meshes, OUT, size=512, ao_strength=0.65)
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
for o in (l2_ob, l3_ob):
    o.hide_render = False
K.render_views(1.5, 0.75, OUT, SLUG + "_L3", [("three_quarter", 38, 18)], dist=7.0)
R.apply_pose_blender(arm, ability(10))
for o in (l2_ob, l3_ob):
    o.hide_render = True
K.render_views(1.5, 0.85, OUT, SLUG + "_ability_pose", [("three_quarter", 38, 14)], dist=7.2)
print("DONE")
