"""Meshes for the Bastion Beetle's Shell Shield (HOS-PET-013c, Hunter's model sheet "Protective Shield"):
  * BeetleHexDome: a unit hemisphere, inside and out, UVs tiled so the AllVFX hex-cell lines repeat 8 times
    around and ~2 times up (it gets MeshPart.TextureID = hex lines and Material ForceField in Studio);
  * BeetleCrystalRing: 12 clusters of cyan crystal shards on a unit circle, tilting outward (the shards that
    spike up around the dome's base).
blender --background --factory-startup --python tools/vfx/beetle_shield_meshes.py -- <abs outdir>
"""
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix

OUT = os.path.abspath(sys.argv[sys.argv.index("--") + 1]) if "--" in sys.argv else os.path.abspath("docs/ability-vfx/beetle_v3")
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)


def obj(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


# ===== hex dome =====
SEG, RINGS, AROUND, UP = 32, 10, 8, 1.9
bm = bmesh.new()
uv = bm.loops.layers.uv.new("UVMap")
grid = []
for r in range(RINGS + 1):
    el = (math.pi / 2) * r / RINGS
    row = []
    for s in range(SEG + 1):
        az = 2 * math.pi * s / SEG
        row.append((Vector((math.cos(el) * math.cos(az), math.cos(el) * math.sin(az), math.sin(el))), (AROUND * s / SEG, UP * r / RINGS)))
    grid.append(row)
verts = [[bm.verts.new(p) for p, _ in row] for row in grid]
for flip in (False, True):
    for r in range(RINGS):
        for s in range(SEG):
            quad = [(r, s), (r, s + 1), (r + 1, s + 1), (r + 1, s)]
            if r == RINGS - 1:
                quad = [(r, s), (r, s + 1), (r + 1, s)]  # pole
            if flip:
                quad = quad[::-1]
            vs = [verts[a][b] for a, b in quad]
            if flip:  # the inside: its own copies of the verts so normals stay separate
                vs = [bm.verts.new(v.co) for v in vs]
            try:
                f = bm.faces.new(vs)
            except ValueError:
                continue
            for loop, (a, b) in zip(f.loops, quad):
                loop[uv].uv = grid[a][b][1]
bmesh.ops.remove_doubles(bm, verts=[v for v in bm.verts if not v.link_faces], dist=0.0)
for v in [v for v in bm.verts if not v.link_faces]:
    bm.verts.remove(v)
dome = obj("BeetleHexDome", bm)

# ===== crystal ring =====
def prism(bm, base, direction, length, radius, segs=6, twist=0.0):
    d = Vector(direction).normalized()
    q = d.to_track_quat("Z", "Y")
    m = Matrix.Translation(base) @ q.to_matrix().to_4x4() @ Matrix.Rotation(twist, 4, "Z")
    ring0 = [bm.verts.new(m @ Vector((radius * 0.75 * math.cos(2 * math.pi * i / segs), radius * 0.75 * math.sin(2 * math.pi * i / segs), -0.02))) for i in range(segs)]
    ring1 = [bm.verts.new(m @ Vector((radius * math.cos(2 * math.pi * i / segs), radius * math.sin(2 * math.pi * i / segs), length * 0.66))) for i in range(segs)]
    tip = bm.verts.new(m @ Vector((0, 0, length)))
    for i in range(segs):
        j = (i + 1) % segs
        bm.faces.new((ring0[i], ring0[j], ring1[j], ring1[i]))
        bm.faces.new((ring1[i], ring1[j], tip))


bm = bmesh.new()
import random
random.seed(7)
N = 12
for k in range(N):
    a = 2 * math.pi * (k + random.uniform(-0.15, 0.15)) / N
    out = Vector((math.cos(a), math.sin(a), 0))
    base = out * 1.0
    tilt = random.uniform(0.35, 0.6)
    prism(bm, base, out * tilt + Vector((0, 0, 1)), random.uniform(0.26, 0.36), 0.055, twist=random.uniform(0, 1))
    side = Vector((-out.y, out.x, 0))
    prism(bm, base + side * 0.07, out * (tilt + 0.3) + side * 0.4 + Vector((0, 0, 1)), random.uniform(0.14, 0.2), 0.035, segs=5)
    prism(bm, base - side * 0.07, out * (tilt + 0.2) - side * 0.4 + Vector((0, 0, 1)), random.uniform(0.12, 0.18), 0.032, segs=5)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
ring = obj("BeetleCrystalRing", bm)

for ob in (dome, ring):
    me = ob.data
    me.calc_loop_triangles()
    print("TRIS", ob.name, len(me.loop_triangles))
bpy.ops.object.select_all(action="DESELECT")
for ob in (dome, ring):
    ob.select_set(True)
bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, "beetle_shield_meshes.fbx"), use_selection=True, object_types={"MESH"},
                         mesh_smooth_type="FACE", path_mode="STRIP")
print("DONE")
