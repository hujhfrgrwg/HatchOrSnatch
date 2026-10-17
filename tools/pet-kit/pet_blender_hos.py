

# ===================================================================== GENERIC PET BLENDER BUILD
# Appended after petkit + one pet module (NAME, SHARP_ANGLE, ATLAS, bones_def, build, paint_atlas,
# face_texture, ANIMS). Builds a fresh scene, the rig, 4 meshes (Body / Face / L2 / L3), bakes the
# actions, writes every texture next to the .blend, saves <NAME>_Pet.blend and exports <NAME>_Pet.fbx.
import os

# ------------------------------------------------------------------ SET THIS (where the outputs go)
# Folder that receives <name>/ with <Name>_Pet.blend, <Name>_Pet.fbx and every texture PNG, for example
#   SAVE_ROOT = r"C:\Users\you\Documents\RobloxPets\models"
# None = a 'models' folder next to the generated build script (make_build.py records that folder in BUILD_DIR).
# You can also leave this file alone and run `python3 make_build.py <pet.py> --save-root "<folder>"`.
SAVE_ROOT = None


def _save_root():
    if SAVE_ROOT:
        return SAVE_ROOT
    bdir = globals().get('BUILD_DIR')
    if bdir and os.path.isdir(bdir):
        return os.path.join(bdir, 'models')
    # the build script was generated on another machine: fall back to the home folder
    fb = os.path.join(os.path.expanduser('~'), 'RobloxPets_pet_models')
    print('SAVE_ROOT not set and BUILD_DIR %r not found on this machine; writing to %s' % (bdir, fb))
    return fb


import bpy
from mathutils import Matrix, Vector

ROOT_DIR = _save_root()
SAVE_DIR = os.path.join(ROOT_DIR, NAME.lower())
print('Pet outputs ->', SAVE_DIR)
FPS = 24


def save_rgba(name, arr, data=False):
    H, W = arr.shape[:2]
    if arr.ndim == 2:
        arr = np.repeat(arr[..., None], 3, -1)
    if arr.shape[2] == 3:
        arr = np.concatenate([arr, np.ones((H, W, 1), np.float32)], -1)
    img = bpy.data.images.get(name)
    if img is None:
        img = bpy.data.images.new(name, W, H, alpha=True)
    if tuple(img.size) != (W, H):
        img.scale(W, H)
    if data:
        try:
            img.colorspace_settings.name = 'Non-Color'
        except Exception:
            pass
    img.pixels.foreach_set(np.ascontiguousarray(np.clip(arr, 0, 1)[::-1], dtype=np.float32).ravel())
    img.update()
    os.makedirs(SAVE_DIR, exist_ok=True)
    img.filepath_raw = os.path.join(SAVE_DIR, name + '.png')
    img.file_format = 'PNG'
    img.save()
    img.pack()
    return img


def _principled(name, diffuse):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial'); out.location = (500, 0)
    bsdf = nt.nodes.new('ShaderNodeBsdfPrincipled'); bsdf.location = (200, 0)
    nt.links.new(bsdf.outputs['BSDF'], out.inputs['Surface'])
    m.diffuse_color = diffuse
    return m, nt, bsdf


def make_body_material(col_img, nrm_img, rgh_img):
    m, nt, bsdf = _principled(NAME + '_Skin', (0.8, 0.8, 0.8, 1))
    tex = nt.nodes.new('ShaderNodeTexImage'); tex.location = (-350, 120); tex.image = col_img
    ntex = nt.nodes.new('ShaderNodeTexImage'); ntex.location = (-350, -200); ntex.image = nrm_img
    nmap = nt.nodes.new('ShaderNodeNormalMap'); nmap.location = (-50, -200)
    nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    nt.links.new(ntex.outputs['Color'], nmap.inputs['Color'])
    nt.links.new(nmap.outputs['Normal'], bsdf.inputs['Normal'])
    rtex = nt.nodes.new('ShaderNodeTexImage'); rtex.location = (-350, -480); rtex.image = rgh_img
    nt.links.new(rtex.outputs['Color'], bsdf.inputs['Roughness'])
    return m


def make_face_material(img):
    m, nt, bsdf = _principled(NAME + '_FaceMat', (0.9, 0.9, 0.9, 1))
    tex = nt.nodes.new('ShaderNodeTexImage'); tex.location = (-300, 0); tex.image = img
    nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    nt.links.new(tex.outputs['Alpha'], bsdf.inputs['Alpha'])
    bsdf.inputs['Roughness'].default_value = 0.3
    try:
        m.surface_render_method = 'BLENDED'
    except Exception:
        pass
    return m


def mesh_from(mb, mat_id, name, material, bones):
    faces = [i for i, m in enumerate(mb.MAT) if m == mat_id]
    if not faces:
        return None
    used = sorted({v for i in faces for v in mb.F[i]})
    remap = {v: k for k, v in enumerate(used)}
    verts = [tuple(mb.V[v]) for v in used]
    polys = [[remap[v] for v in mb.F[i]] for i in faces]
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], polys)
    me.update()
    uv = me.uv_layers.new(name='UVMap')
    for p, fi in zip(me.polygons, faces):
        for li, (u, v) in zip(p.loop_indices, mb.UV[fi]):
            uv.data[li].uv = (u, v)
    me.materials.append(material)
    try:
        me.shade_smooth()
        me.set_sharp_from_angle(angle=math.radians(SHARP_ANGLE))
    except Exception as ex:
        print('smooth fallback', ex)
        for p in me.polygons:
            p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    for b in bones:
        ob.vertex_groups.new(name=b[0])
    for v in used:
        for bone, w in mb.W[v].items():
            ob.vertex_groups[bone].add([remap[v]], w, 'REPLACE')
    return ob


def build_rig(name, coll, bones):
    arm = bpy.data.armatures.new(name)
    rig = bpy.data.objects.new(name, arm)
    coll.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    rig.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    ebs = {}
    for bname, head, tail, parent in bones:
        eb = arm.edit_bones.new(bname)
        eb.head = Vector(tuple(head))
        eb.tail = Vector(tuple(tail))
        d = Vector(tuple(tail)) - Vector(tuple(head))
        if d.length < 1e-4:
            eb.tail = eb.head + Vector((0, 0, 0.1))
            d = Vector((0, 0, 0.1))
        if abs(d.normalized().z) < 0.9:
            eb.align_roll(Vector((0, 0, 1)))
        else:
            eb.align_roll(Vector((0, -1, 0)))
        eb.use_deform = True
        ebs[bname] = eb
    for bname, head, tail, parent in bones:
        if parent:
            ebs[bname].parent = ebs[parent]
            ebs[bname].use_connect = False
    bpy.ops.object.mode_set(mode='OBJECT')
    arm.display_type = 'STICK'
    rig.show_in_front = True
    for pb in rig.pose.bones:
        pb.rotation_mode = 'QUATERNION'
    return rig


def bind(ob, rig):
    ob.parent = rig
    mod = ob.modifiers.new('Armature', 'ARMATURE')
    mod.object = rig


def to_local(rig, bname, R, t):
    Rb = rig.data.bones[bname].matrix_local.to_3x3()
    Rw = Matrix([list(R[0]), list(R[1]), list(R[2])])
    Rl = Rb.transposed() @ Rw @ Rb
    return Rl.to_quaternion(), Rb.transposed() @ Vector(tuple(t))


def bake_action(rig, aname, anim, bones):
    act = bpy.data.actions.get(aname)
    if act:
        bpy.data.actions.remove(act)
    act = bpy.data.actions.new(aname)
    act.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = act
    try:
        if len(act.slots) == 0 and hasattr(act, 'slots'):
            pass
    except Exception:
        pass
    names = [b[0] for b in bones]
    prev = {}
    for f in sorted(anim['keys']):
        pose = anim['keys'][f]
        for bname in names:
            R, t = pose.get(bname, (np.eye(3), V(0, 0, 0)))
            q, loc = to_local(rig, bname, R, t)
            if bname in prev:
                q.make_compatible(prev[bname])
            prev[bname] = q
            pb = rig.pose.bones[bname]
            pb.rotation_quaternion = q
            pb.location = loc
            pb.keyframe_insert('rotation_quaternion', frame=f, group=bname)
            pb.keyframe_insert('location', frame=f, group=bname)
    return act


def run():
    bones = bones_def()
    mb = build()
    sname = NAME + 'Pet'
    if bpy.context.window is None:   # headless (blender --background): build into the context scene
        scn = bpy.context.scene
        for ob in list(scn.objects):
            bpy.data.objects.remove(ob, do_unlink=True)
        scn.name = sname
        old = None
    else:
        old = bpy.data.scenes.get(sname)
        if old:
            old.name = sname + '_old'
        scn = bpy.data.scenes.new(sname)
        bpy.context.window.scene = scn
    if old:
        for ob in list(old.objects):
            bpy.data.objects.remove(ob, do_unlink=True)
        for c in list(old.collection.children_recursive):
            bpy.data.collections.remove(c)
        bpy.data.scenes.remove(old)
    scn.render.fps = FPS
    scn.view_settings.view_transform = 'Standard'
    exp = bpy.data.collections.new(NAME + '_Export')
    scn.collection.children.link(exp)

    col1, hgt, rgh = paint_atlas(1)
    col2 = paint_atlas(2)[0]
    col3 = paint_atlas(3)[0]
    ns = globals().get('NORMAL_STRENGTH', 2.5)
    col_img = save_rgba(NAME + '_Color', col1)
    save_rgba(NAME + '_Color_L2', col2)
    save_rgba(NAME + '_Color_L3', col3)
    nrm_img = save_rgba(NAME + '_Normal', normal_from_height(hgt, ns), data=True)
    rgh_img = save_rgba(NAME + '_Roughness', rgh, data=True)
    face1 = save_rgba(NAME + '_Face', face_texture(1))
    save_rgba(NAME + '_Face_L2', face_texture(2))
    save_rgba(NAME + '_Face_L3', face_texture(3))
    # HOS addition: emissive masks per level, when the module paints them (white = glows)
    if 'emissive_mask' in globals():
        for lv, suf in ((1, ''), (2, '_L2'), (3, '_L3')):
            save_rgba(NAME + '_Emit' + suf, emissive_mask(lv), data=True)
    # HOS addition: face decal emissive masks (glowing eyes / runes), when the module paints them
    if 'face_emissive' in globals():
        for lv, suf in ((1, ''), (2, '_L2'), (3, '_L3')):
            save_rgba(NAME + '_FaceEmit' + suf, face_emissive(lv), data=True)
    m_body = make_body_material(col_img, nrm_img, rgh_img)
    m_face = make_face_material(face1)

    rig = build_rig(NAME + '_Rig', exp, bones)
    objs = []
    for mat_id, suffix, material in ((0, 'Body', m_body), (1, 'Face', m_face), (2, 'L2', m_body), (3, 'L3', m_body)):
        ob = mesh_from(mb, mat_id, NAME + '_' + suffix, material, bones)
        if ob is not None:
            exp.objects.link(ob)
            bind(ob, rig)
            objs.append(ob)
    acts = {}
    for aname, fn in ANIMS.items():
        acts[aname] = bake_action(rig, NAME + '_' + aname, fn(), bones)
    rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)

    tc = lambda o: sum(len(p.vertices) - 2 for p in o.data.polygons)
    counts = {o.name: tc(o) for o in objs}
    os.makedirs(SAVE_DIR, exist_ok=True)
    bpy.data.libraries.write(os.path.join(SAVE_DIR, NAME + '_Pet.blend'), {scn, *acts.values()}, fake_user=True, compress=True)  # HOS: keep the actions
    # FBX in the bind pose: textures referenced by file name, found next to the .fbx by Studio's importer
    rig.data.pose_position = 'REST'
    keep = {o.name for o in objs} | {rig.name}      # HOS: by name; object identity fails in headless Blender
    for o in bpy.context.view_layer.objects:
        o.select_set(o.name in keep)
    bpy.context.view_layer.objects.active = rig
    fp = os.path.join(SAVE_DIR, NAME + '_Pet.fbx')
    bpy.ops.export_scene.fbx(filepath=fp, use_selection=False, object_types={'ARMATURE', 'MESH'}, add_leaf_bones=False,  # HOS: the scene holds only the pet
                             bake_anim=False, axis_forward='Z', axis_up='Y',
                             path_mode='STRIP', embed_textures=False)
    rig.data.pose_position = 'POSE'
    print('PET BUILT', NAME, counts, 'ALL:', sum(counts.values()), 'bones:', len(rig.data.bones),
          'actions:', list(acts), 'fbx:', os.path.getsize(fp))
    return counts


run()
