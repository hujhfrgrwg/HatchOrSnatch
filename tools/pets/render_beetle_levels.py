# Render the Bastion Beetle L1 / L2 / L3 with its real per-level textures (Blender Eevee, same studio look as the pet
# kit's render_pet_blender.py), from the shipped FBX.
#   blender --background --factory-startup --python tools/pets/render_beetle_levels.py -- <out png>
import bpy, math, os, sys
from mathutils import Vector

OUT = sys.argv[sys.argv.index('--') + 1]
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'docs', 'pets', 'bastion_beetle')
TEX = os.path.join(ROOT, 'tex')
bpy.ops.wm.read_factory_settings(use_empty=True)
scn = bpy.context.scene
for eng in ('BLENDER_EEVEE_NEXT', 'BLENDER_EEVEE'):
    try:
        scn.render.engine = eng
        break
    except TypeError:
        pass
scn.render.resolution_x, scn.render.resolution_y = 1500, 560
scn.view_settings.view_transform = 'Standard'
bpy.ops.import_scene.fbx(filepath=os.path.join(ROOT, 'bastion_beetle.fbx'))
meshes = [o for o in scn.objects if o.type == 'MESH']


def mat(col, emit, strength):
    m = bpy.data.materials.new('M')
    m.use_nodes = True
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    t = nt.nodes.new('ShaderNodeTexImage'); t.image = bpy.data.images.load(col, check_existing=True)
    nt.links.new(t.outputs['Color'], b.inputs['Base Color'])
    b.inputs['Roughness'].default_value = 0.4
    if emit and os.path.exists(emit):
        e = nt.nodes.new('ShaderNodeTexImage'); e.image = bpy.data.images.load(emit, check_existing=True)
        e.image.colorspace_settings.name = 'Non-Color'
        mul = nt.nodes.new('ShaderNodeMixRGB'); mul.blend_type = 'MULTIPLY'; mul.inputs[0].default_value = 1
        nt.links.new(t.outputs['Color'], mul.inputs[1]); nt.links.new(e.outputs['Color'], mul.inputs[2])
        nt.links.new(mul.outputs[0], b.inputs['Emission Color'])
        b.inputs['Emission Strength'].default_value = strength
    return m


def part_of(o):
    n = o.name
    for p in ('Body', 'Face', 'L2', 'L3'):
        if p in n:
            return p
    return 'Body'


src = {o: part_of(o) for o in meshes}
lv_objs = {}
lo = Vector((1e9,) * 3); hi = -lo
for o in meshes:
    for c in o.bound_box:
        p = o.matrix_world @ Vector(c)
        lo = Vector(map(min, lo, p)); hi = Vector(map(max, hi, p))
size = max(hi - lo)
gap = size * 1.25
for lv in (1, 2, 3):
    for o, p in src.items():
        if (p == 'L2' and lv < 2) or (p == 'L3' and lv < 3):
            continue
        c = o.copy(); c.data = o.data.copy(); scn.collection.objects.link(c)
        c.location = o.location + Vector(((lv - 2) * gap, 0, 0))
        if p == 'Face':
            col, emit = os.path.join(TEX, 'Beetle_Face.png'), os.path.join(TEX, 'Beetle_Face_emit.png')
        elif lv == 1:
            col, emit = os.path.join(TEX, 'Beetle_%s.png' % p), os.path.join(TEX, 'Beetle_%s_emit.png' % p)
        else:
            col = os.path.join(TEX, 'levels', 'Beetle_%s_L%d.png' % (p, lv))
            emit = os.path.join(TEX, 'levels', 'Beetle_%s_emit_L%d.png' % (p, lv))
        c.data.materials.clear(); c.data.materials.append(mat(col, emit, (1.2, 1.5, 1.9)[lv - 1]))
        for poly in c.data.polygons:
            poly.use_smooth = False
for o in meshes:
    o.hide_render = True
for ob in [x for x in scn.objects if x.type == 'ARMATURE']:
    ob.hide_render = True

world = bpy.data.worlds.new('W'); scn.world = world; world.use_nodes = True
bg = next(n for n in world.node_tree.nodes if n.type == 'BACKGROUND')
bg.inputs['Color'].default_value = (0.03, 0.045, 0.09, 1); bg.inputs['Strength'].default_value = 1.6
for name, energy, rot in (('Key', 3.2, (52, 0, -40)), ('Fill', 1.2, (65, 0, 140)), ('Rim', 2.0, (40, 0, 175))):
    L = bpy.data.lights.new(name, 'SUN'); L.energy = energy
    ob = bpy.data.objects.new(name, L); ob.rotation_euler = [math.radians(a) for a in rot]; scn.collection.objects.link(ob)
ctr = (lo + hi) / 2
cam_d = bpy.data.cameras.new('Cam'); cam_d.lens = 40
cam = bpy.data.objects.new('Cam', cam_d); scn.collection.objects.link(cam); scn.camera = cam
yaw, pitch, D = math.radians(28), math.radians(14), size * 5.2
cam.location = ctr + Vector((math.sin(yaw) * math.cos(pitch), -math.cos(yaw) * math.cos(pitch), math.sin(pitch))) * D
cam.rotation_euler = (ctr - cam.location).to_track_quat('-Z', 'Y').to_euler()
scn.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print('RENDERED', OUT)
