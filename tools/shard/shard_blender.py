"""Blender (headless): import tools/shard/out/shard.obj, flat-shade it, render a turntable sheet of the 4 rarities and
export Shard.fbx for Roblox. Run: blender -b -P tools/shard/shard_blender.py
FBX note (HOS-GEMS-002): Roblox imports it turned 180 deg about the up axis and at 100x: the export is pre-turned 180 deg
about Blender Y here; in Studio set Size = MeshSize / 100."""
import math
import os

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'out')
RAR = ['common', 'rare', 'epic', 'legendary']

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene


def import_obj():
    bpy.ops.wm.obj_import(filepath=os.path.join(OUT, 'shard.obj'), forward_axis='Y', up_axis='Z')
    ob = bpy.context.selected_objects[0]
    for p in ob.data.polygons:
        p.use_smooth = False
    return ob


def material(r):
    m = bpy.data.materials.new('Shard_' + r)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    tex = nt.nodes.new('ShaderNodeTexImage')
    tex.image = bpy.data.images.load(os.path.join(OUT, 'shard_%s.png' % r))
    tex.interpolation = 'Closest'
    nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    bsdf.inputs['Roughness'].default_value = 0.45
    return m


base = import_obj()
base.name = 'Shard'

# ---- turntable sheet: 4 rarities x 3 angles
objs = []
for i, r in enumerate(RAR):
    for j, yaw in enumerate([0, 50, 150]):
        o = base.copy()
        o.data = base.data.copy()
        o.data.materials.clear()
        o.data.materials.append(material(r))
        o.location = ((j - 1) * 1.9, 0, (1.5 - i) * 1.9)
        o.rotation_euler = (0, 0, math.radians(yaw))
        sc.collection.objects.link(o)
        objs.append(o)
base.hide_render = True

cam_d = bpy.data.cameras.new('Cam')
cam_d.type = 'ORTHO'
cam_d.ortho_scale = 8.2
cam = bpy.data.objects.new('Cam', cam_d)
cam.location = (0, -20, 0)
cam.rotation_euler = (math.radians(90), 0, 0)
sc.collection.objects.link(cam)
sc.camera = cam
for name, loc, energy in (('Key', (-6, -10, 8), 2600), ('Fill', (8, -6, -2), 1000), ('Rim', (0, 8, 6), 1400)):
    ld = bpy.data.lights.new(name, 'AREA')
    ld.energy = energy
    ld.size = 6
    lo = bpy.data.objects.new(name, ld)
    lo.location = loc
    lo.rotation_euler = (math.atan2(math.hypot(loc[0], loc[1]), loc[2]) * 0 + math.radians(60), 0, math.atan2(loc[0], -loc[1]))
    sc.collection.objects.link(lo)
    tr = lo.constraints.new('TRACK_TO')
    tr.target = objs[4]
world = bpy.data.worlds.new('W')
world.use_nodes = True
world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.09, 0.05, 0.16, 1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.6
sc.world = world
try:
    sc.render.engine = 'BLENDER_EEVEE_NEXT'
except TypeError:
    sc.render.engine = 'BLENDER_EEVEE'
sc.render.resolution_x, sc.render.resolution_y = 1200, 1600
sc.render.filepath = os.path.join(OUT, 'shard_turntable.png')
bpy.ops.render.render(write_still=True)
print('rendered', sc.render.filepath)

# ---- FBX: one shard, pre-turned 180 deg about Blender Y (Roblox turns it back), common material
for o in objs + [cam]:
    bpy.data.objects.remove(o, do_unlink=True)
base.hide_render = False
base.data.materials.clear()
base.data.materials.append(material('common'))
base.rotation_euler = (0, math.radians(180), 0)
bpy.context.view_layer.objects.active = base
for o in bpy.context.scene.objects:
    o.select_set(o == base)
bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, 'Shard.fbx'), use_selection=True, mesh_smooth_type='FACE',
                         path_mode='COPY', embed_textures=False, axis_forward='-Z', axis_up='Y')
print('exported', os.path.join(OUT, 'Shard.fbx'), 'tris', sum(len(p.vertices) - 2 for p in base.data.polygons))
