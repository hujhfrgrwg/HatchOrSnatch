"""Bastion Beetle (Guardian Common), v2 to Hunter's concept library sheet (docs/pets/concepts). HOS-PET-012.
Concept: a chunky, heroic golden-armoured beetle: segmented gold shell plates with spikes along the rim,
a gold helmet with a big forked horn, a blue face with big yellow eyes, gold armoured legs with blue joints,
blue-teal accents. Rigged (rigid skin), animated from code (Idle, Walk, Run, Hop, Ability), baked colour texture.
blender --background --factory-startup --python tools/pets/bastion_beetle.py -- <abs outdir>
"""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import petkit as K
import rigkit as R
from mathutils import Vector, Quaternion

SLUG, SPECIES, PREFIX = "bastion_beetle", "Bastion Beetle", "Beetle_"
OUT = K.outdir_arg(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "docs", "pets", SLUG))
os.makedirs(OUT, exist_ok=True)
K.reset()

GOLD = K.material("Beetle_Gold", K.hexrgb(222, 150, 32), rough=0.35)
GOLD_LT = K.material("Beetle_GoldLight", K.hexrgb(250, 196, 84), rough=0.3)
GOLD_DK = K.material("Beetle_GoldDark", K.hexrgb(124, 70, 12), rough=0.45)
BLUE = K.material("Beetle_Blue", K.hexrgb(52, 142, 226), rough=0.45)
BLUE_DK = K.material("Beetle_BlueDark", K.hexrgb(28, 70, 150), rough=0.5)
TEAL = K.material("Beetle_Teal", K.hexrgb(70, 214, 220), rough=0.35)
IRIS = K.material("Eye_Iris", K.hexrgb(255, 214, 72), rough=0.3)
BLACK = K.material("Eye_Black", K.hexrgb(16, 16, 24), rough=0.3)
WHITE = K.material("Eye_White", K.hexrgb(250, 250, 250), rough=0.3)
RIM = K.material("Eye_Rim", K.hexrgb(18, 40, 90), rough=0.5)

# ===== skeleton (Blender: front -Y, up +Z) =====
LEGS = [("F", -0.55), ("M", 0.05), ("B", 0.6)]
bones = [
    ("Root", (0, 0, 0), (0, 0, 0.3), None),
    ("Body", (0, 0.1, 0.62), (0, 0.1, 1.0), "Root"),
    ("ShellL", (-0.12, -0.45, 1.05), (-0.12, 0.55, 1.05), "Body"),
    ("ShellR", (0.12, -0.45, 1.05), (0.12, 0.55, 1.05), "Body"),
    ("Head", (0, -0.74, 0.74), (0, -1.14, 0.82), "Body"),
    ("Horn", (0, -1.3, 0.86), (0, -1.6, 1.5), "Head"),
]
for tag, y in LEGS:
    for side, sx in (("L", -1), ("R", 1)):
        bones.append((f"Leg{tag}U.{side}", (sx * 0.56, y, 0.46), (sx * 0.86, y - 0.04, 0.36), "Body"))
        bones.append((f"Leg{tag}L.{side}", (sx * 0.86, y - 0.04, 0.36), (sx * 0.92, y - 0.08, 0.05), f"Leg{tag}U.{side}"))
arm = R.armature(bones)

# ===== L1 body =====
b = R.RigBuilder(PREFIX + "Body")
# blue underbody showing under the shell rim
b.sphere(BLUE_DK, (0, 0.12, 0.5), (0.74, 1.0, 0.36), segs=10, rings=6, bone="Body")
# the shell: one big smooth gold dome per side (each on its own bone so it lifts for Shell Shield), split by
# a blue seam, with dark plate seams across it (front / middle / back plates) and a light ridge on top
for side, bn in ((-1, "ShellL"), (1, "ShellR")):
    b.sphere(GOLD, (side * 0.4, 0.14, 0.92), (0.66, 1.1, 0.62), segs=10, rings=7, bone=bn)
    # plate seams: thin dark rings just proud of the dome's surface at that slice
    for y, rx, rz in ((-0.36, 0.615, 0.585), (0.42, 0.66, 0.62)):
        b.sphere(GOLD_DK, (side * 0.4, y, 0.92), (rx, 0.05, rz), segs=8, rings=4, bone=bn)
    b.sphere(GOLD_LT, (side * 0.38, 0.02, 1.42), (0.16, 0.62, 0.07), segs=6, rings=3, bone=bn)
    # rim spikes (3 per side), short and stout
    for y in (-0.48, 0.14, 0.7):
        b.cone(GOLD_LT, (side * 1.02, y, 0.78), 0.12, 0.0, 0.3, segs=5, rot=(0, side * 72, 0), bone=bn)
b.sphere(BLUE, (0, 0.18, 1.0), (0.06, 1.0, 0.5), segs=6, rings=4, bone="Body")  # seam
b.cone(GOLD_LT, (0, 1.2, 0.86), 0.13, 0.0, 0.32, segs=5, rot=(-80, 0, 0), bone="Body")
# head: big, a blue face under a gold helmet with side spikes
b.sphere(BLUE, (0, -1.0, 0.72), (0.52, 0.46, 0.46), segs=10, rings=7, bone="Head")
b.sphere(BLUE_DK, (0, -1.43, 0.6), (0.2, 0.04, 0.035), segs=6, rings=3, bone="Head")  # mouth line
b.sphere(GOLD, (0, -0.94, 1.0), (0.58, 0.48, 0.28), segs=10, rings=5, rot=(-14, 0, 0), bone="Head")
for side in (-1, 1):
    b.cone(GOLD_LT, (side * 0.52, -0.9, 1.08), 0.1, 0.0, 0.26, segs=5, rot=(-20, side * 44, 0), bone="Head")
# the forked horn: a big front horn and a second prong from the helmet, gold
b.limb(GOLD, (0, -1.3, 0.86), (0, -1.56, 1.16), 0.18, 0.13, segs=7, bone="Horn")
b.limb(GOLD, (0, -1.56, 1.16), (0, -1.68, 1.52), 0.13, 0.07, segs=7, bone="Horn")
b.limb(GOLD_LT, (0, -1.68, 1.52), (0, -1.62, 1.72), 0.07, 0.0, segs=7, bone="Horn")
b.limb(GOLD, (0, -1.02, 1.16), (0, -1.16, 1.44), 0.1, 0.06, segs=6, bone="Head")
b.limb(GOLD_LT, (0, -1.16, 1.44), (0, -1.32, 1.56), 0.06, 0.0, segs=6, bone="Head")
# six short, chunky armoured legs: gold upper plate, blue knee, gold lower and foot
for tag, y in LEGS:
    for side, sx in (("L", -1), ("R", 1)):
        hip, knee, foot = (sx * 0.56, y, 0.46), (sx * 0.86, y - 0.04, 0.36), (sx * 0.92, y - 0.08, 0.05)
        b.limb(GOLD, hip, knee, 0.16, 0.14, segs=5, bone=f"Leg{tag}U.{side}")
        b.sphere(BLUE, knee, (0.13, 0.13, 0.13), segs=5, rings=3, bone=f"Leg{tag}L.{side}")
        b.limb(GOLD, knee, foot, 0.14, 0.11, segs=5, bone=f"Leg{tag}L.{side}")
        b.sphere(GOLD_DK, (foot[0], foot[1] - 0.05, 0.05), (0.14, 0.17, 0.06), segs=5, rings=3, bone=f"Leg{tag}L.{side}")
body = b.finish_rigged(arm)

# ===== face: big yellow eyes under the helmet brim (same on L1-L3) =====
f = R.RigBuilder(PREFIX + "Face")
for side in (-1, 1):
    x, y, z, s = side * 0.25, -1.36, 0.8, 0.19
    f.sphere(RIM, (x, y + 0.02, z), (s * 1.14, s * 0.5, s * 1.14), segs=6, rings=4, bone="Head")
    f.sphere(IRIS, (x, y, z), (s, s * 0.55, s), segs=8, rings=5, bone="Head")
    f.sphere(BLACK, (x + side * 0.015, y - 0.095, z - 0.01), (s * 0.5, s * 0.12, s * 0.62), segs=6, rings=3, bone="Head")
    f.sphere(WHITE, (x + side * 0.06, y - 0.115, z + 0.055), (s * 0.15, s * 0.05, s * 0.15), segs=4, rings=2, bone="Head")
face = f.finish_rigged(arm)

# ===== L2: teal gem studs on the shell plates and a teal band on the horn =====
l2 = R.RigBuilder(PREFIX + "L2")
for side, bn in ((-1, "ShellL"), (1, "ShellR")):
    for y in (-0.3, 0.2, 0.66):
        l2.gem(TEAL, (side * 0.64, y, 1.22 if y != 0.66 else 1.08), 0.07, rot=(0, side * 35, 0), bone=bn)
l2.limb(TEAL, (0, -1.5, 1.08), (0, -1.57, 1.2), 0.16, 0.14, segs=7, bone="Horn")
l2_ob = l2.finish_rigged(arm)

# ===== L3: a teal crest along the seam and glowing teal horn tips =====
l3 = R.RigBuilder(PREFIX + "L3")
for y in (-0.3, 0.1, 0.5):
    l3.cone(TEAL, (0, y, 1.5), 0.08, 0.0, 0.26, segs=4, bone="Body")
l3.gem(TEAL, (0, -1.63, 1.74), 0.06, bone="Horn")
l3.gem(TEAL, (0, -1.33, 1.58), 0.045, bone="Head")
l3_ob = l3.finish_rigged(arm)

forms = {"L1": [body, face], "L2": [body, face, l2_ob], "L3": [body, face, l2_ob, l3_ob]}
tris = {k: sum(K.tri_count(o) for o in v) for k, v in forms.items()}
print("TRIS", {o.name: K.tri_count(o) for o in (body, face, l2_ob, l3_ob)}, "per form", tris)
assert tris["L3"] <= 2000, tris

# ===== animations (24 fps), bone deltas in Blender model axes =====
X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)
TRIPOD_A = {"LegFU.L", "LegMU.R", "LegBU.L"}
LEG_NAMES = [f"Leg{t}{p}.{s}" for t, _ in LEGS for p in "UL" for s in "LR"]
ALL = ["Root", "Body", "ShellL", "ShellR", "Head", "Horn"] + LEG_NAMES


def legs_pose(ph, swing, lift):
    """Tripod gait: legs in TRIPOD_A swing opposite to the rest."""
    out = {}
    for t, _ in LEGS:
        for s in "LR":
            u = f"Leg{t}U.{s}"
            p = ph + (0 if u in TRIPOD_A else math.pi)
            side = -1 if s == "L" else 1
            fwd = math.sin(p) * swing            # swing about the vertical axis (forward / back)
            up = max(0.0, math.cos(p)) * lift      # lift while swinging forward
            out[u] = (R.axis_q(Z, -side * fwd) @ R.axis_q(Y, side * up), Vector())
            out[f"Leg{t}L.{s}"] = (R.axis_q(Y, -side * up * 0.6), Vector())
    return out


def idle(fr):
    ph = fr / 48 * 2 * math.pi
    p = {"Body": (R.axis_q(X, 1.2 * math.sin(ph)), Vector((0, 0, 0.025 * math.sin(ph)))),
         "Head": (R.axis_q(Z, 6 * math.sin(ph * 0.5)) @ R.axis_q(X, -2 * math.sin(ph)), Vector()),
         "Horn": (R.axis_q(X, 2 * math.sin(ph + 1)), Vector()),
         "ShellL": (R.axis_q(Y, -1.5 * (1 + math.sin(ph)) / 2), Vector()),
         "ShellR": (R.axis_q(Y, 1.5 * (1 + math.sin(ph)) / 2), Vector())}
    return p


def walk(fr, n=24, swing=22, lift=18, bob=0.035):
    ph = fr / n * 2 * math.pi
    p = legs_pose(ph, swing, lift)
    p["Body"] = (R.axis_q(Y, 3 * math.sin(ph)) @ R.axis_q(X, 1.5 * math.sin(2 * ph)), Vector((0, 0, bob * abs(math.sin(ph)))))
    p["Head"] = (R.axis_q(Z, -4 * math.sin(ph)), Vector())
    return p


def run(fr):
    return walk(fr, n=16, swing=30, lift=26, bob=0.06)


def hop(fr):
    t = fr / 16
    up = math.sin(math.pi * t)
    crouch = max(0.0, math.cos(math.pi * t * 2)) * (1 - t)
    p = {"Body": (R.axis_q(X, -10 * up), Vector((0, 0, 0.4 * up - 0.06 * crouch)))}
    for t2, _ in LEGS:
        for s in "LR":
            side = -1 if s == "L" else 1
            p[f"Leg{t2}U.{s}"] = (R.axis_q(Y, side * 25 * up), Vector())
    return p


def ability(fr):
    """Rear up, shells flare open, head lifts and the horn thrusts (Shell Shield / Horn Tether): 0.8 s."""
    t = fr / 20
    rise = math.sin(math.pi * min(1.0, t * 1.6)) if t < 0.62 else max(0.0, 1 - (t - 0.62) / 0.38)
    rise = max(0.0, min(1.0, rise))
    p = {"Body": (R.axis_q(X, -18 * rise), Vector((0, 0.1 * rise, 0.12 * rise))),
         "ShellL": (R.axis_q(Y, -38 * rise), Vector()),
         "ShellR": (R.axis_q(Y, 38 * rise), Vector()),
         "Head": (R.axis_q(X, -12 * rise), Vector()),
         "Horn": (R.axis_q(X, 16 * math.sin(math.pi * min(1.0, t * 2.2)) * (1 if t < 0.46 else 0)), Vector())}
    for t2, _ in LEGS:
        for s in "LR":
            side = -1 if s == "L" else 1
            if t2 == "F":
                p[f"Leg{t2}U.{s}"] = (R.axis_q(Y, side * 30 * rise), Vector())
    return p


ANIMS = {
    "Idle": {"frames": 48, "loop": True, "bones": ALL, "fn": idle, "step": 4},
    "Walk": {"frames": 24, "loop": True, "bones": ALL, "fn": walk, "step": 2},
    "Run": {"frames": 16, "loop": True, "bones": ALL, "fn": run, "step": 2},
    "Hop": {"frames": 16, "loop": False, "bones": ALL, "fn": hop, "step": 2},
    "Ability": {"frames": 20, "loop": False, "bones": ALL, "fn": ability, "step": 2},
}
R.write_anims(os.path.join(OUT, "BeetleAnims.lua"), "Beetle", "tools/pets/bastion_beetle.py", ANIMS)

# ===== texture, export, renders =====
meshes = [body, face, l2_ob, l3_ob]
tex = R.bake_textures(meshes, OUT, size=512, ao_strength=0.7)
R.use_baked(meshes, tex)
R.export_fbx(os.path.join(OUT, SLUG + ".fbx"), [arm] + meshes)
import bpy
src = os.path.join(OUT, "src")
os.makedirs(src, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(src, SLUG + ".blend"))

K.setup_render(1024)
for o in (l2_ob, l3_ob):
    o.hide_render = True
K.render_views(1.6, 0.8, OUT, SLUG + "_L1", [("front", 0, 12), ("three_quarter", 38, 18), ("side", 90, 8), ("back", 180, 14)], dist=7.4)
for o in (l2_ob, l3_ob):
    o.hide_render = False
K.render_views(1.6, 0.8, OUT, SLUG + "_L3", [("three_quarter", 38, 18)], dist=7.4)
R.apply_pose_blender(arm, ability(9))
for o in (l2_ob, l3_ob):
    o.hide_render = True
K.render_views(1.6, 0.9, OUT, SLUG + "_ability_pose", [("three_quarter", 38, 14)], dist=7.6)
print("DONE")
