"""rigkit: rigged roster pets for Hatch or Snatch (HOS-PET-012+), to the Crow / Kitsune pipeline.

What a pet script produces (all under docs/pets/<slug>/):
  * <Prefix>Body, <Prefix>Face, <Prefix>L2, <Prefix>L3 meshes, rigidly skinned to one armature
    (bone per moving part), pivot at the ground centre, Blender front = -Y (FBX/Roblox front = +Z, like the Crow);
  * a baked colour texture per mesh (base colour x ambient occlusion, Cycles), tex/<Prefix><Part>.png;
  * <slug>.fbx (default FBX axes: Blender (x, y, z) -> Roblox (x, z, -y), centimetres -> the template is
    scaled to studs in Studio and its scale kept as the RigScale attribute);
  * <Species>Anims.lua for ReplicatedStorage.EOS.Shared.PetRig (the KitsuneAnims format): per key and bone
    qx, qy, qz, qw, tx, ty, tz = the bone's OWN rotation delta in model axes, about its rest head, and its
    translation in studs (Blender units). Animations are generated here from code, not keyed in Blender.
"""
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix, Quaternion, Euler

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import petkit as K


class RigBuilder(K.Builder):
    """A Builder that remembers which bone each piece's vertices follow (rigid skinning)."""

    def __init__(self, name):
        super().__init__(name)
        self.vbone = []  # bone name per vertex, in order

    def add(self, geom_fn, mat, matrix, bone="Body"):
        before = len(self.bm.verts)
        super().add(geom_fn, mat, matrix)
        self.vbone.extend([bone] * (len(self.bm.verts) - before))

    def sphere(self, mat, loc, scale, segs=12, rings=8, rot=(0, 0, 0), bone="Body"):
        m = Matrix.Translation(loc) @ K.euler(rot) @ Matrix.Diagonal((*scale, 1))
        self.add(lambda b: bmesh.ops.create_uvsphere(b, u_segments=segs, v_segments=rings, radius=1.0), mat, m, bone)

    def cone(self, mat, loc, r1, r2, depth, segs=8, rot=(0, 0, 0), scale=(1, 1, 1), bone="Body"):
        m = Matrix.Translation(loc) @ K.euler(rot) @ Matrix.Diagonal((*scale, 1))
        self.add(lambda b: bmesh.ops.create_cone(b, cap_ends=True, segments=segs, radius1=r1, radius2=r2, depth=depth), mat, m, bone)

    def limb(self, mat, a, b, r1, r2, segs=6, bone="Body"):
        a, b = Vector(a), Vector(b)
        d = b - a
        q = d.normalized().to_track_quat("Z", "Y")
        m = Matrix.Translation((a + b) / 2) @ q.to_matrix().to_4x4()
        self.add(lambda bm: bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r1, radius2=r2, depth=d.length), mat, m, bone)

    def gem(self, mat, loc, size, rot=(0, 0, 0), bone="Body"):
        """A small octahedron (8 tris): studs, gems, spike tips."""
        def g(bm):
            vs = [bm.verts.new(v) for v in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1.4), (0, 0, -1))]
            for a, b, c in ((0, 2, 4), (2, 1, 4), (1, 3, 4), (3, 0, 4), (2, 0, 5), (1, 2, 5), (3, 1, 5), (0, 3, 5)):
                bm.faces.new((vs[a], vs[b], vs[c]))
        m = Matrix.Translation(loc) @ K.euler(rot) @ Matrix.Diagonal((size, size, size, 1))
        self.add(g, mat, m, bone)

    def finish_rigged(self, arm, smooth_angle=40.0):
        ob = self.finish(smooth_angle)
        for name in sorted(set(self.vbone)):
            ob.vertex_groups.new(name=name)
        for i, bn in enumerate(self.vbone):
            ob.vertex_groups[bn].add([i], 1.0, "REPLACE")
        mod = ob.modifiers.new("Armature", "ARMATURE")
        mod.object = arm
        ob.parent = arm
        return ob


def armature(bones):
    """bones: list of (name, head, tail, parent or None). Returns the armature object."""
    data = bpy.data.armatures.new("Rig")
    arm = bpy.data.objects.new("Rig", data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for name, head, tail, parent in bones:
        eb = data.edit_bones.new(name)
        eb.head, eb.tail = Vector(head), Vector(tail)
        eb.roll = 0
        if parent:
            eb.parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


# ===== baked colour texture =====
def bake_textures(obs, outdir, size=512, ao_strength=0.55):
    """Smart-UV each mesh and bake base colour x ambient occlusion into tex/<object>.png (Cycles, CPU)."""
    import numpy as np
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 64
    try:
        sc.cycles.device = "CPU"
    except Exception:
        pass
    texdir = os.path.join(outdir, "tex")
    os.makedirs(texdir, exist_ok=True)
    out = {}
    for ob in obs:
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.03)
        bpy.ops.object.mode_set(mode="OBJECT")
        res = size if "Face" not in ob.name else size // 2
        imgs = {}
        for kind in ("DIFFUSE", "AO"):
            img = bpy.data.images.new(f"{ob.name}_{kind}", res, res, float_buffer=True)  # linear pixels
            imgs[kind] = img
            for m in ob.data.materials:
                nt = m.node_tree
                node = nt.nodes.get("BakeTarget") or nt.nodes.new("ShaderNodeTexImage")
                node.name = "BakeTarget"
                node.image = img
                nt.nodes.active = node
            if kind == "DIFFUSE":
                bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, margin=4)
            else:
                bpy.ops.object.bake(type="AO", margin=4)
        col = np.array(imgs["DIFFUSE"].pixels[:]).reshape(-1, 4)
        ao = np.array(imgs["AO"].pixels[:]).reshape(-1, 4)[:, :1]
        shade = (1 - ao_strength) + ao_strength * ao
        rgb = col[:, :3] * shade
        # linear -> sRGB for the PNG Roblox reads
        rgb = np.where(rgb <= 0.0031308, rgb * 12.92, 1.055 * np.power(np.clip(rgb, 0, 1), 1 / 2.4) - 0.055)
        final = bpy.data.images.new(f"{ob.name}_tex", res, res)
        final.colorspace_settings.name = "Non-Color"
        final.pixels[:] = np.concatenate([np.clip(rgb, 0, 1), np.ones((rgb.shape[0], 1))], axis=1).ravel()
        path = os.path.join(texdir, ob.name + ".png")
        final.filepath_raw = path
        final.file_format = "PNG"
        final.save()
        out[ob.name] = path
        for m in ob.data.materials:
            n = m.node_tree.nodes.get("BakeTarget")
            if n:
                m.node_tree.nodes.remove(n)
    return out


def use_baked(obs, texpaths):
    """Swap each mesh to one material showing its baked texture (for renders that match the game)."""
    for ob in obs:
        img = bpy.data.images.load(texpaths[ob.name])
        img.colorspace_settings.name = "sRGB"
        m = bpy.data.materials.new(ob.name + "_Baked")
        m.use_nodes = True
        nt = m.node_tree
        bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Roughness"].default_value = 0.55
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = img
        nt.links.new(t.outputs["Color"], bsdf.inputs["Base Color"])
        ob.data.materials.clear()
        ob.data.materials.append(m)


def export_fbx(path, objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"ARMATURE", "MESH"},
                             add_leaf_bones=False, bake_anim=False, use_armature_deform_only=True,
                             mesh_smooth_type="FACE", path_mode="STRIP")


# ===== animations (generated in code) =====
def to_roblox_q(q):
    """Blender (w, x, y, z) quaternion in model axes -> Roblox model axes (x, z, -y)."""
    return Quaternion((q.w, q.x, q.z, -q.y))


def to_roblox_v(v):
    return Vector((v.x, v.z, -v.y))


def axis_q(axis, deg):
    return Quaternion(Vector(axis).normalized(), math.radians(deg))


def write_anims(path, species, src, anims, fps=24):
    """anims: { name: { frames, loop, bones: [names], fn(frame) -> {bone: (Quaternion blender-model, Vector offset)} } }"""
    lines = [f"-- {species}Anims: generated by {src} (HOS-PET-012). Do not edit by hand.",
             "-- Per key: for each bone in `bones`: qx, qy, qz, qw, tx, ty, tz (model axes, rest-relative,",
             "-- rotation about the bone head in model space; translation in studs at rig scale 1).",
             "return {"]
    for name, a in anims.items():
        bones = a["bones"]
        lines.append(f"\t{name} = {{")
        lines.append(f"\t\tframes = {a['frames']}, loop = {'true' if a['loop'] else 'false'},")
        lines.append("\t\tbones = { " + ", ".join(f'"{b}"' for b in bones) + " },")
        lines.append("\t\tkeys = {")
        step = a.get("step", 2)
        frames = list(range(0, a["frames"] + 1, step))
        if frames[-1] != a["frames"]:
            frames.append(a["frames"])
        for f in frames:
            pose = a["fn"](f)
            vals = []
            for b in bones:
                q, t = pose.get(b, (Quaternion(), Vector()))
                rq, rt = to_roblox_q(q), to_roblox_v(t)
                vals += [rq.x, rq.y, rq.z, rq.w, rt.x, rt.y, rt.z]
            lines.append("\t\t\t{ f = %d, v = { %s } }," % (f, ", ".join(("%.4f" % v).rstrip("0").rstrip(".") if v != 0 else "0" for v in vals)))
        lines.append("\t\t},")
        lines.append("\t},")
    lines.append("}")
    with open(path, "w") as fh:
        fh.write("\n".join(lines) + "\n")


def apply_pose_blender(arm, pose):
    """Show a generated pose on the Blender armature (for turnaround / pose renders)."""
    for pb in arm.pose.bones:
        q, t = pose.get(pb.name, (Quaternion(), Vector()))
        R = pb.bone.matrix_local.to_quaternion()
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = R.inverted() @ q @ R
        pb.location = R.inverted() @ t
    bpy.context.view_layer.update()
