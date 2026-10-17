# HOS addition to the pet kit: Blender-rendered previews (what Hunter judges), from a built <Name>_Pet.blend.
# Smooth shading, the real textures (+ emissive mask as glow), soft studio light on a dark background like the card.
#   blender --background --factory-startup --python render_pet_blender.py -- <pet dir with <Name>_Pet.blend> <out dir> [level]
import bpy, math, os, sys
from mathutils import Vector

args = sys.argv[sys.argv.index('--') + 1:]
PET_DIR, OUT = args[0], args[1]
LEVEL = int(args[2]) if len(args) > 2 else 1
os.makedirs(OUT, exist_ok=True)
blend = [f for f in os.listdir(PET_DIR) if f.endswith('_Pet.blend')][0]
NAME = blend[:-len('_Pet.blend')]
with bpy.data.libraries.load(os.path.join(PET_DIR, blend)) as (src, dst):
    dst.scenes = src.scenes
scn = dst.scenes[0]
bpy.context.window_manager.windows[0].scene = scn if bpy.context.window_manager.windows else None
bpy.context.window.scene = scn if bpy.context.window else None
scn = bpy.data.scenes[scn.name]
if bpy.context.window is None:
    # headless: render this scene directly
    pass
for eng in ('BLENDER_EEVEE_NEXT', 'BLENDER_EEVEE'):
    try:
        scn.render.engine = eng
        break
    except TypeError:
        pass
scn.render.resolution_x = scn.render.resolution_y = 900
scn.view_settings.view_transform = 'Standard'
scn.render.film_transparent = False
try:
    scn.eevee.use_bloom = True
except Exception:
    pass

meshes = [o for o in scn.objects if o.type == 'MESH']
lv_hide = {1: (NAME + '_L2', NAME + '_L3'), 2: (NAME + '_L3',), 3: ()}[LEVEL]
for o in meshes:
    o.hide_render = o.name in lv_hide
    for p in o.data.polygons:
        p.use_smooth = True
    try:
        o.data.set_sharp_from_angle(angle=math.radians(80))
    except Exception:
        pass

# per-level colour + emissive on the body material
def tex_path(stem):
    p = os.path.join(PET_DIR, stem + '.png')
    return p if os.path.exists(p) else None

suf = '' if LEVEL == 1 else '_L%d' % LEVEL
mat = bpy.data.materials.get(NAME + '_Skin')
if mat:
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    texs = [n for n in nt.nodes if n.type == 'TEX_IMAGE']
    cp = tex_path(NAME + '_Color' + suf)
    if cp:
        texs[0].image = bpy.data.images.load(cp, check_existing=True)
    ep = tex_path(NAME + '_Emit' + suf)
    if ep:
        e = nt.nodes.new('ShaderNodeTexImage')
        e.image = bpy.data.images.load(ep, check_existing=True)
        e.image.colorspace_settings.name = 'Non-Color'
        mul = nt.nodes.new('ShaderNodeMixRGB'); mul.blend_type = 'MULTIPLY'; mul.inputs[0].default_value = 1
        nt.links.new(texs[0].outputs['Color'], mul.inputs[1])
        nt.links.new(e.outputs['Color'], mul.inputs[2])
        nt.links.new(mul.outputs[0], bsdf.inputs['Emission Color'])
        bsdf.inputs['Emission Strength'].default_value = 1.4

# face decal: per-level texture + glowing eyes / runes from the face emissive mask
fmat = bpy.data.materials.get(NAME + '_FaceMat')
if fmat:
    nt = fmat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    ftex = next(n for n in nt.nodes if n.type == 'TEX_IMAGE')
    fp = tex_path(NAME + '_Face' + suf)
    if fp:
        ftex.image = bpy.data.images.load(fp, check_existing=True)
    fe = tex_path(NAME + '_FaceEmit' + suf)
    if fe:
        e = nt.nodes.new('ShaderNodeTexImage')
        e.image = bpy.data.images.load(fe, check_existing=True)
        e.image.colorspace_settings.name = 'Non-Color'
        mul = nt.nodes.new('ShaderNodeMixRGB'); mul.blend_type = 'MULTIPLY'; mul.inputs[0].default_value = 1
        nt.links.new(ftex.outputs['Color'], mul.inputs[1])
        nt.links.new(e.outputs['Color'], mul.inputs[2])
        nt.links.new(mul.outputs[0], bsdf.inputs['Emission Color'])
        bsdf.inputs['Emission Strength'].default_value = 2.5

# lights + dark backdrop
world = bpy.data.worlds.new('W'); scn.world = world; world.use_nodes = True
bg = next(n for n in world.node_tree.nodes if n.type == 'BACKGROUND')
bg.inputs['Color'].default_value = (0.03, 0.045, 0.09, 1); bg.inputs['Strength'].default_value = 1.6
for name, energy, rot, size in (('Key', 3.2, (52, 0, -40), 6), ('Fill', 1.2, (65, 0, 140), 8), ('Rim', 2.0, (40, 0, 175), 3)):
    L = bpy.data.lights.new(name, 'SUN'); L.energy = energy; L.angle = math.radians(size)
    ob = bpy.data.objects.new(name, L); ob.rotation_euler = [math.radians(a) for a in rot]; scn.collection.objects.link(ob)
bpy.ops.mesh.primitive_circle_add(vertices=64, radius=4, fill_type='NGON')
ground = bpy.context.active_object
gm = bpy.data.materials.new('Ground'); gm.use_nodes = True
gb = next(n for n in gm.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'); gb.inputs['Base Color'].default_value = (0.05, 0.065, 0.11, 1)
gb.inputs['Roughness'].default_value = 0.5
ground.data.materials.append(gm)
if ground.name not in scn.objects:
    scn.collection.objects.link(ground)

cam_data = bpy.data.cameras.new('Cam'); cam_data.lens = 60
cam = bpy.data.objects.new('Cam', cam_data); scn.collection.objects.link(cam); scn.camera = cam
pts = [o.matrix_world @ Vector(c) for o in meshes if not o.hide_render for c in o.bound_box]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
ctr = (lo + hi) / 2
size = max(hi - lo)


def shot(name, yaw, pitch, dist, target=None, lens=60):
    cam_data.lens = lens
    t = target if target is not None else ctr
    a, p = math.radians(yaw), math.radians(pitch)
    cam.location = t + Vector((math.sin(a) * math.cos(p), -math.cos(a) * math.cos(p), math.sin(p))) * dist
    cam.rotation_euler = (t - cam.location).to_track_quat('-Z', 'Y').to_euler()
    scn.render.filepath = os.path.join(OUT, name + '.png')
    bpy.ops.render.render(write_still=True)


D = size * 2.3
tag = 'L%d' % LEVEL
# the card's angle: front-right three-quarter, slightly low
shot('bl_%s_card_angle' % tag, 38, 8, D)
if LEVEL == 1:
    for nm, yaw, pitch in (('front', 0, 6), ('side', 90, 5), ('back', 180, 12), ('three_quarter_left', -38, 14)):
        shot('bl_L1_' + nm, yaw, pitch, D)
    head = Vector((ctr.x, lo.y + (hi.y - lo.y) * 0.12, lo.z + (hi.z - lo.z) * 0.62))
    shot('bl_L1_head', 28, 6, size * 1.05, target=head)
print('RENDERED', OUT)
