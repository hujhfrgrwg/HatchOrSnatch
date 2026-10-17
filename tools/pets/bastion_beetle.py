"""Bastion Beetle (Guardian Common), L1 form. HOS-PET-012.
Handoff look note: a rounded beetle with a big protective shell and a stout horn.
blender --background --factory-startup --python tools/pets/bastion_beetle.py -- <abs outdir>
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import petkit as K

SLUG = "bastion_beetle"
OUT = K.outdir_arg(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "docs", "pets", SLUG))
os.makedirs(OUT, exist_ok=True)
K.reset()

SHELL = K.material("Beetle_Shell", K.hexrgb(58, 96, 160), rough=0.4)
SEAM = K.material("Beetle_Seam", K.hexrgb(26, 38, 70), rough=0.5)
LIP = K.material("Beetle_Lip", K.hexrgb(34, 50, 88), rough=0.5)
DARK = K.material("Beetle_Dark", K.hexrgb(52, 54, 70), rough=0.7)
HORN = K.material("Beetle_Horn", K.hexrgb(232, 214, 168), rough=0.45)
WHITE = K.material("Eye_White", K.hexrgb(246, 246, 246), rough=0.3)
BLACK = K.material("Eye_Black", K.hexrgb(18, 18, 24), rough=0.3)
RIM = K.material("Eye_Rim", K.hexrgb(28, 32, 46), rough=0.5)

body = K.Builder("Beetle_Body")
# the big protective shell: two wing-case halves (a dark seam between) over a darker rim lip, wide
# and low so it overhangs the legs and comes forward over the head like a helmet
body.sphere(LIP, (0, 0.12, 0.74), (1.04, 1.24, 0.5), segs=12, rings=6)
for side in (-1, 1):
    body.sphere(SHELL, (side * 0.36, 0.16, 0.86), (0.64, 1.2, 0.64), segs=10, rings=7, rot=(0, side * -4, 0))
body.sphere(SEAM, (0, 0.18, 1.02), (0.05, 0.98, 0.48), segs=6, rings=5)
# underbody and a small head tucked under the shell's front
body.sphere(DARK, (0, 0.1, 0.42), (0.72, 0.98, 0.36), segs=10, rings=5)
body.sphere(DARK, (0, -1.02, 0.6), (0.46, 0.4, 0.4), segs=10, rings=6)
# the stout horn: three thick segments sweeping up and forward from the brow (rhino-beetle read)
body.limb(HORN, (0, -1.12, 0.86), (0, -1.38, 1.18), 0.21, 0.16, segs=8)
body.limb(HORN, (0, -1.38, 1.18), (0, -1.5, 1.5), 0.16, 0.1, segs=8)
body.limb(HORN, (0, -1.5, 1.5), (0, -1.46, 1.72), 0.1, 0.02, segs=8)
# six stubby bent legs: hip under the shell, knee out wide, foot on the ground
for side in (-1, 1):
    for y in (-0.55, 0.08, 0.66):
        hip = (side * 0.55, y, 0.42)
        knee = (side * 0.9, y - 0.06, 0.34)
        foot = (side * 0.98, y - 0.1, 0.04)
        body.limb(DARK, hip, knee, 0.12, 0.11, segs=6)
        body.limb(DARK, knee, foot, 0.11, 0.085, segs=6)
bodyOb = body.finish()

face = K.Builder("Beetle_Face")
for side in (-1, 1):
    K.toon_eye(face, WHITE, BLACK, RIM, (side * 0.21, -1.36, 0.66), 0.155, look=(side * 0.3, -1, 0.05), side=side)
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
K.render_views(1.6, 0.8, OUT, SLUG + "_L1", [("front", 0, 12), ("three_quarter", 38, 18), ("side", 90, 8), ("back", 180, 14)], dist=7.2)
print("DONE")
