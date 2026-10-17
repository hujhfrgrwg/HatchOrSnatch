"""Thunder Toad (Tempest Common), L1 form. HOS-PET-012.
Handoff look note: a round toad with an oversized throat sac and a cheerful, aggressive face.
blender --background --factory-startup --python tools/pets/thunder_toad.py -- <abs outdir>
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import petkit as K

SLUG = "thunder_toad"
OUT = K.outdir_arg(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "docs", "pets", SLUG))
os.makedirs(OUT, exist_ok=True)
K.reset()

SKIN = K.material("Toad_Skin", K.hexrgb(112, 150, 62), rough=0.5)
BELLY = K.material("Toad_Belly", K.hexrgb(214, 200, 120), rough=0.55)
SAC = K.material("Toad_Sac", K.hexrgb(250, 206, 58), rough=0.35)
SPOT = K.material("Toad_Spot", K.hexrgb(70, 96, 40), rough=0.55)
BOLT = K.material("Toad_Bolt", K.hexrgb(255, 214, 40), rough=0.4)
MOUTH = K.material("Toad_Mouth", K.hexrgb(40, 26, 30), rough=0.6)
BROW = K.material("Toad_Brow", K.hexrgb(64, 88, 36), rough=0.5)
WHITE = K.material("Eye_White", K.hexrgb(246, 246, 246), rough=0.3)
BLACK = K.material("Eye_Black", K.hexrgb(18, 18, 24), rough=0.3)
RIM = K.material("Eye_Rim", K.hexrgb(40, 52, 26), rough=0.5)

body = K.Builder("Toad_Body")
# round squat body and a wide head merged into it
body.sphere(SKIN, (0, 0.15, 0.62), (0.92, 0.9, 0.62), segs=12, rings=7)
body.sphere(SKIN, (0, -0.42, 0.88), (0.8, 0.62, 0.52), segs=10, rings=6)
body.sphere(BELLY, (0, -0.1, 0.42), (0.74, 0.74, 0.4), segs=8, rings=5)
# the oversized throat sac, puffed out under the chin (Tempest yellow)
body.sphere(SAC, (0, -0.86, 0.42), (0.5, 0.42, 0.38), segs=10, rings=6)
# the wide cheeky grin above the sac: a dark lip line that curls up at both corners
body.sphere(MOUTH, (0, -1.0, 0.86), (0.36, 0.06, 0.05), segs=8, rings=3)
for side in (-1, 1):
    body.sphere(MOUTH, (side * 0.45, -0.94, 0.92), (0.16, 0.06, 0.045), segs=6, rings=3, rot=(0, side * -32, 0))
# eye bumps on top of the head and angled brows (the "aggressive" half of the face)
for side in (-1, 1):
    body.sphere(SKIN, (side * 0.36, -0.62, 1.2), (0.27, 0.27, 0.25), segs=8, rings=5)
    body.sphere(BROW, (side * 0.34, -0.8, 1.42), (0.22, 0.07, 0.06), segs=6, rings=4, rot=(0, side * -24, 0))
# back spots and a lightning-bolt marking (two slanted plates) down the spine
for x, y, s in ((-0.5, 0.25, 0.14), (0.52, 0.12, 0.12), (-0.28, 0.6, 0.1), (0.36, 0.58, 0.13)):
    body.sphere(SPOT, (x, y, 1.0 + 0.08 * (1 - abs(x))), (s, s, 0.05), segs=6, rings=3)
body.sphere(BOLT, (0.1, -0.02, 1.2), (0.13, 0.36, 0.06), segs=6, rings=3, rot=(-10, 0, 32))
body.sphere(BOLT, (-0.1, 0.5, 1.1), (0.13, 0.34, 0.06), segs=6, rings=3, rot=(12, 0, 32))
# thick folded back legs and short front arms
for side in (-1, 1):
    body.sphere(SKIN, (side * 0.82, 0.42, 0.32), (0.34, 0.5, 0.3), segs=8, rings=4)
    body.limb(SKIN, (side * 0.9, 0.2, 0.18), (side * 0.98, -0.22, 0.06), 0.12, 0.1, segs=6)
    body.sphere(BELLY, (side * 1.0, -0.32, 0.04), (0.2, 0.17, 0.05), segs=6, rings=3)
    body.limb(SKIN, (side * 0.56, -0.62, 0.4), (side * 0.66, -0.84, 0.06), 0.15, 0.12, segs=6)
    body.sphere(BELLY, (side * 0.64, -0.94, 0.03), (0.15, 0.13, 0.04), segs=6, rings=3)
bodyOb = body.finish()

face = K.Builder("Toad_Face")
for side in (-1, 1):
    K.toon_eye(face, WHITE, BLACK, RIM, (side * 0.37, -0.82, 1.2), 0.17, look=(side * 0.25, -1, 0.15), side=side)
faceOb = face.finish()

tb, tf = K.tri_count(bodyOb), K.tri_count(faceOb)
print("TRIS body", tb, "face", tf, "total", tb + tf)
obs = (bodyOb, faceOb)
mn = [min((o.matrix_world @ v.co)[i] for o in obs for v in o.data.vertices) for i in range(3)]
mx = [max((o.matrix_world @ v.co)[i] for o in obs for v in o.data.vertices) for i in range(3)]
print("SIZE", [round(mx[i] - mn[i], 3) for i in range(3)], "MINZ", round(mn[2], 3))

K.export_mesh_json([bodyOb, faceOb], os.path.join(OUT, "preview_mesh.json"))
import bpy
src = os.path.join(OUT, "src")
os.makedirs(src, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(src, SLUG + "_L1.blend"))

K.setup_render(1024)
K.render_views(1.4, 0.7, OUT, SLUG + "_L1", [("front", 0, 12), ("three_quarter", 38, 18), ("side", 90, 8), ("back", 180, 14)], dist=6.4)
print("DONE")
