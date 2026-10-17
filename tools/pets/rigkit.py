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
def bake_textures(obs, outdir, size=512, ao_strength=0.55, sheen=None, ao_distance=None, sizes=None, emissive=None, pbr=False):
    """Smart-UV each mesh and bake base colour x ambient occlusion into tex/<object>.png (Cycles, CPU).
    sheen = (highlight linear rgb, {material name: strength}, light dir (Blender model axes)): a soft baked
    highlight on the faces of those materials that point toward the light, so armour reads as polished
    even under flat in-game light.
    emissive = {material name: 0..1}: a glow mask tex/<object>_emit.png (SurfaceAppearance.EmissiveMaskContent).
    pbr = True: also tex/<object>_normal.png (tangent space, OpenGL, baked from a smoothed subdivided copy so
    low-poly plates and limbs shade rounded), _rough.png (each material's Roughness) and _metal.png (each
    material's custom property "metal", 0..1). Meshes are triangulated first so Roblox's tangents match."""
    import numpy as np
    import bmesh
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 64
    try:
        sc.cycles.device = "CPU"
    except Exception:
        pass
    if ao_distance:  # contact shadows only, so far-off parts don't smudge big flat plates
        if not sc.world:
            sc.world = bpy.data.worlds.new("BakeWorld")
        sc.world.light_settings.distance = ao_distance
    texdir = os.path.join(outdir, "tex")
    os.makedirs(texdir, exist_ok=True)
    out = {}
    for oi, ob in enumerate(obs):
        # later meshes in the list are higher-level add-ons (L2, L3): keep them out of this mesh's shadows
        later = [o for o in obs[oi + 1:] if not o.hide_render]
        for o in later:
            o.hide_render = True
        if pbr:
            bm = bmesh.new()
            bm.from_mesh(ob.data)
            bmesh.ops.triangulate(bm, faces=bm.faces[:])
            bm.to_mesh(ob.data)
            bm.free()
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.03)
        bpy.ops.object.mode_set(mode="OBJECT")
        res = (sizes or {}).get(ob.name) or (size if "Face" not in ob.name else size // 2)
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
        if sheen and any(m.name in sheen[1] for m in ob.data.materials):
            hl, strengths, ldir = sheen
            nimg = bpy.data.images.new(f"{ob.name}_N", res, res, float_buffer=True)
            mimg = bpy.data.images.new(f"{ob.name}_M", res, res, float_buffer=True)
            saved = []
            for m in ob.data.materials:
                bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
                saved.append((bsdf, tuple(bsdf.inputs["Emission Color"].default_value), bsdf.inputs["Emission Strength"].default_value))
                k = strengths.get(m.name, 0.0)
                bsdf.inputs["Emission Color"].default_value = (k, k, k, 1)
                bsdf.inputs["Emission Strength"].default_value = 1.0
            for img, kind in ((nimg, "NORMAL"), (mimg, "EMIT")):
                for m in ob.data.materials:
                    m.node_tree.nodes["BakeTarget"].image = img
                    m.node_tree.nodes.active = m.node_tree.nodes["BakeTarget"]
                if kind == "NORMAL":
                    bpy.ops.object.bake(type="NORMAL", normal_space="OBJECT", margin=4)
                else:
                    bpy.ops.object.bake(type="EMIT", margin=4)
            for bsdf, c, st in saved:
                bsdf.inputs["Emission Color"].default_value = c
                bsdf.inputs["Emission Strength"].default_value = st
            n = np.array(nimg.pixels[:]).reshape(-1, 4)[:, :3] * 2 - 1
            mask = np.array(mimg.pixels[:]).reshape(-1, 4)[:, :1]
            L = np.array(ldir, dtype=float)
            L = L / np.linalg.norm(L)
            d = np.clip((n @ L)[:, None], 0, 1)
            h = mask * np.clip((d - 0.45) / 0.55, 0, 1) ** 1.6
            rgb = rgb * (1 - h) + np.array(hl)[None, :] * h
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
        if emissive and any(m.name in emissive for m in ob.data.materials):
            # a grayscale glow mask for SurfaceAppearance.EmissiveMaskContent: tex/<object>_emit.png
            eimg = bpy.data.images.new(f"{ob.name}_E", res, res, float_buffer=True)
            saved = []
            for m in ob.data.materials:
                bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
                saved.append((bsdf, tuple(bsdf.inputs["Emission Color"].default_value), bsdf.inputs["Emission Strength"].default_value))
                k = emissive.get(m.name, 0.0)
                bsdf.inputs["Emission Color"].default_value = (k, k, k, 1)
                bsdf.inputs["Emission Strength"].default_value = 1.0
                m.node_tree.nodes["BakeTarget"].image = eimg
                m.node_tree.nodes.active = m.node_tree.nodes["BakeTarget"]
            bpy.ops.object.bake(type="EMIT", margin=4)
            for bsdf, c, st in saved:
                bsdf.inputs["Emission Color"].default_value = c
                bsdf.inputs["Emission Strength"].default_value = st
            e = np.clip(np.array(eimg.pixels[:]).reshape(-1, 4)[:, :1], 0, 1)
            em = bpy.data.images.new(f"{ob.name}_emit", res, res)
            em.colorspace_settings.name = "Non-Color"
            em.pixels[:] = np.concatenate([e, e, e, np.ones_like(e)], axis=1).ravel()
            em.filepath_raw = os.path.join(texdir, ob.name + "_emit.png")
            em.file_format = "PNG"
            em.save()
            out[ob.name + "_emit"] = em.filepath_raw
        if pbr:
            def target(img):
                for m in ob.data.materials:
                    m.node_tree.nodes["BakeTarget"].image = img
                    m.node_tree.nodes.active = m.node_tree.nodes["BakeTarget"]

            def save(name, arr):
                im = bpy.data.images.new(f"{ob.name}_{name}", res, res)
                im.colorspace_settings.name = "Non-Color"
                im.pixels[:] = np.concatenate([np.clip(arr, 0, 1), np.ones((arr.shape[0], 1))], axis=1).ravel()
                im.filepath_raw = os.path.join(texdir, f"{ob.name}_{name}.png")
                im.file_format = "PNG"
                im.save()
                out[f"{ob.name}_{name}"] = im.filepath_raw

            # grayscale masks from per-material values
            for name, val in (("rough", lambda m, b: b.inputs["Roughness"].default_value), ("metal", lambda m, b: float(m.get("metal", 0.0)))):
                gimg = bpy.data.images.new(f"{ob.name}_{name}_f", res, res, float_buffer=True)
                saved = []
                for m in ob.data.materials:
                    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
                    saved.append((bsdf, tuple(bsdf.inputs["Emission Color"].default_value), bsdf.inputs["Emission Strength"].default_value))
                    k = val(m, bsdf)
                    bsdf.inputs["Emission Color"].default_value = (k, k, k, 1)
                    bsdf.inputs["Emission Strength"].default_value = 1.0
                target(gimg)
                bpy.ops.object.bake(type="EMIT", margin=4)
                for bsdf, c, st in saved:
                    bsdf.inputs["Emission Color"].default_value = c
                    bsdf.inputs["Emission Strength"].default_value = st
                g = np.array(gimg.pixels[:]).reshape(-1, 4)[:, :1]
                save(name, np.repeat(g, 3, axis=1))
            # tangent-space normals from a smoothed, subdivided copy (rounded bevels without extra triangles)
            hp = ob.copy()
            hp.data = ob.data.copy()
            hp.name = ob.name + "_HP"
            bpy.context.scene.collection.objects.link(hp)
            for mod in list(hp.modifiers):
                hp.modifiers.remove(mod)
            for e in hp.data.edges:
                e.use_edge_sharp = False
            for poly in hp.data.polygons:
                poly.use_smooth = True
            sub = hp.modifiers.new("Sub", "SUBSURF")
            sub.levels = sub.render_levels = 2
            nimg = bpy.data.images.new(f"{ob.name}_normal_f", res, res, float_buffer=True)
            target(nimg)
            bpy.ops.object.select_all(action="DESELECT")
            hp.select_set(True)
            ob.select_set(True)
            bpy.context.view_layer.objects.active = ob
            bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", use_selected_to_active=True,
                                cage_extrusion=0.03, max_ray_distance=0.09, margin=4)
            bpy.data.objects.remove(hp, do_unlink=True)
            nm = np.array(nimg.pixels[:]).reshape(-1, 4)[:, :3]
            save("normal", nm)
        for m in ob.data.materials:
            n = m.node_tree.nodes.get("BakeTarget")
            if n:
                m.node_tree.nodes.remove(n)
        for o in later:
            o.hide_render = False
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
                             mesh_smooth_type="FACE", use_tspace=True, path_mode="STRIP")


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


# ===== painted surface detail (HOS-PET-014, Hunter's "premium" Manta reference) =====
# Procedural node graphs feeding each material's Base Colour (and a Bump into its Normal) before the bake, so
# the baked colour / normal maps carry real surface detail instead of flat fills: tonal gradients inside every
# area, micro-pattern, edge wear, crystal facets and sparkle. Object-space coordinates keep the pattern scale
# the same across separate pieces. Styles:
#   "skin"     soft mottling + top-lit gradient (fur, skin, scales at a distance)
#   "filigree" ivory/stone armour: mottling, top-lit gradient, engraved swirl lines (darker, bumped in)
#   "metal"    worn metal rims: dark-to-bright variation, bright worn convex edges (pointiness), fine scratches
#   "crystal"  faceted cells of lighter / darker hue, white inner sparkle specks
#   "dark"     understructure: low-contrast noise
def paint_material(mat, style, scale=1.0, strength=1.0):
    nt = mat.node_tree
    N, L = nt.nodes, nt.links
    bsdf = next(n for n in N if n.type == "BSDF_PRINCIPLED")
    base = tuple(bsdf.inputs["Base Color"].default_value)
    tc = N.new("ShaderNodeTexCoord")
    mp = N.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (scale, scale, scale)
    L.new(tc.outputs["Object"], mp.inputs["Vector"])

    def rgb(c):
        n = N.new("ShaderNodeRGB")
        n.outputs[0].default_value = c
        return n.outputs[0]

    def shade(k):  # base colour times k (k > 1 lightens)
        return (min(1, base[0] * k), min(1, base[1] * k), min(1, base[2] * k), 1)

    def mix(a, b, fac, blend="MIX"):
        m = N.new("ShaderNodeMix")
        m.data_type = "RGBA"
        m.blend_type = blend
        L.new(fac, m.inputs["Factor"])
        L.new(a, m.inputs[6])
        L.new(b, m.inputs[7])
        return m.outputs[2]

    def noise(s, detail=4.0, rough=0.55):
        n = N.new("ShaderNodeTexNoise")
        n.inputs["Scale"].default_value = s
        n.inputs["Detail"].default_value = detail
        n.inputs["Roughness"].default_value = rough
        L.new(mp.outputs["Vector"], n.inputs["Vector"])
        return n.outputs["Fac"]

    def ramp(fac, a, b, p0=0.35, p1=0.65):
        r = N.new("ShaderNodeValToRGB")
        r.color_ramp.elements[0].position, r.color_ramp.elements[1].position = p0, p1
        r.color_ramp.elements[0].color, r.color_ramp.elements[1].color = a, b
        L.new(fac, r.inputs["Fac"])
        return r.outputs["Color"]

    # top-lit gradient: object Z -> darker underneath, lighter on top
    sep = N.new("ShaderNodeSeparateXYZ")
    L.new(tc.outputs["Object"], sep.inputs["Vector"])
    grad = N.new("ShaderNodeMapRange")
    grad.inputs["From Min"].default_value, grad.inputs["From Max"].default_value = 0.1, 1.6
    L.new(sep.outputs["Z"], grad.inputs["Value"])
    lit = ramp(grad.outputs["Result"], shade(1 - 0.22 * strength), shade(1 + 0.12 * strength), 0.0, 1.0)
    out = lit
    bump_h = None
    if style in ("skin", "filigree", "dark"):
        mott = ramp(noise(9.0), shade(1 - 0.12 * strength), shade(1 + 0.08 * strength))
        out = mix(out, mott, noise(3.0, 2.0), "MULTIPLY") if style == "dark" else mix(out, mott, rgb((0.45, 0.45, 0.45, 1)))
    if style == "filigree":
        w = N.new("ShaderNodeTexWave")
        w.wave_type = "RINGS"
        w.inputs["Scale"].default_value = 4.5
        w.inputs["Distortion"].default_value = 3.0
        w.inputs["Detail"].default_value = 1.0
        L.new(mp.outputs["Vector"], w.inputs["Vector"])
        lines = N.new("ShaderNodeMapRange")  # thin engraved lines where the wave is near its trough
        lines.inputs["From Min"].default_value, lines.inputs["From Max"].default_value = 0.0, 0.035
        lines.inputs["To Min"].default_value, lines.inputs["To Max"].default_value = 1.0, 0.0
        L.new(w.outputs["Fac"], lines.inputs["Value"])
        out = mix(out, rgb(shade(0.8)), lines.outputs["Result"])
        bump_h = lines.outputs["Result"]
    if style == "metal":
        geo = N.new("ShaderNodeNewGeometry")
        edge = N.new("ShaderNodeMapRange")
        edge.inputs["From Min"].default_value, edge.inputs["From Max"].default_value = 0.54, 0.62
        L.new(geo.outputs["Pointiness"], edge.inputs["Value"])
        var = ramp(noise(6.0, 6.0, 0.6), shade(0.62), shade(1.05))
        out = mix(out, var, rgb((0.55, 0.55, 0.55, 1)))
        out = mix(out, rgb(shade(1.3)), edge.outputs["Result"])
        scr = N.new("ShaderNodeTexWave")
        scr.inputs["Scale"].default_value = 40.0
        scr.inputs["Distortion"].default_value = 2.0
        L.new(mp.outputs["Vector"], scr.inputs["Vector"])
        out = mix(out, rgb(shade(1.25)), ramp(scr.outputs["Fac"], (0, 0, 0, 1), (0.25, 0.25, 0.25, 1), 0.9, 1.0))
    if style == "crystal":
        v = N.new("ShaderNodeTexVoronoi")
        v.inputs["Scale"].default_value = 14.0
        L.new(mp.outputs["Vector"], v.inputs["Vector"])
        cells = ramp(v.outputs["Color"], shade(0.55), shade(1.4), 0.2, 0.8)
        out = mix(out, cells, rgb((0.85, 0.85, 0.85, 1)))
        ve = N.new("ShaderNodeTexVoronoi")
        ve.feature = "DISTANCE_TO_EDGE"
        ve.inputs["Scale"].default_value = 14.0
        L.new(mp.outputs["Vector"], ve.inputs["Vector"])
        facet = ramp(ve.outputs["Distance"], (1, 1, 1, 1), (0, 0, 0, 1), 0.0, 0.06)
        out = mix(out, rgb(shade(1.6)), facet)
        sp = ramp(noise(60.0, 1.0), (0, 0, 0, 1), (1, 1, 1, 1), 0.72, 0.78)
        out = mix(out, rgb((1, 1, 1, 1)), sp)
        bump_h = ve.outputs["Distance"]
    L.new(out, bsdf.inputs["Base Color"])
    if bump_h is not None:
        b = N.new("ShaderNodeBump")
        b.inputs["Strength"].default_value = 0.35
        b.inputs["Distance"].default_value = 0.02
        L.new(bump_h, b.inputs["Height"])
        L.new(b.outputs["Normal"], bsdf.inputs["Normal"])


# ===== painted eyes (HOS-PET-016: round pupils + highlights painted as true circles, never hex geometry) =====
def paint_eyes(mat, cx, cz, size, front_y, iris_rim=None, pupil=(0.055, 0.055, 0.086, 1), mirror=True):
    """Paint round pupils and a large + small highlight onto an eye material in object space. The eye centre is
    (±cx, front_y, cz) (mirrored in x), radius `size`; front_y is where the eye's front surface begins."""
    nt = mat.node_tree
    N, L = nt.nodes, nt.links
    bsdf = next(n for n in N if n.type == "BSDF_PRINCIPLED")
    base = tuple(bsdf.inputs["Base Color"].default_value)[:4]
    tc = N.new("ShaderNodeTexCoord")
    sep = N.new("ShaderNodeSeparateXYZ")
    L.new(tc.outputs["Object"], sep.inputs["Vector"])
    ax = N.new("ShaderNodeMath"); ax.operation = "ABSOLUTE" if mirror else "ADD"
    L.new(sep.outputs["X"], ax.inputs[0])
    if not mirror:
        ax.inputs[1].default_value = 0.0

    def disc(dcx, dcz, r, soft=0.008):
        dx = N.new("ShaderNodeMath"); dx.operation = "SUBTRACT"; L.new(ax.outputs[0], dx.inputs[0]); dx.inputs[1].default_value = dcx
        dz = N.new("ShaderNodeMath"); dz.operation = "SUBTRACT"; L.new(sep.outputs["Z"], dz.inputs[0]); dz.inputs[1].default_value = dcz
        c = N.new("ShaderNodeCombineXYZ"); L.new(dx.outputs[0], c.inputs["X"]); L.new(dz.outputs[0], c.inputs["Y"])
        ln = N.new("ShaderNodeVectorMath"); ln.operation = "LENGTH"; L.new(c.outputs[0], ln.inputs[0])
        m = N.new("ShaderNodeMapRange"); m.inputs["From Min"].default_value = r - soft; m.inputs["From Max"].default_value = r + soft
        m.inputs["To Min"].default_value, m.inputs["To Max"].default_value = 1.0, 0.0
        L.new(ln.outputs["Value"], m.inputs["Value"])
        front = N.new("ShaderNodeMath"); front.operation = "LESS_THAN"; L.new(sep.outputs["Y"], front.inputs[0]); front.inputs[1].default_value = front_y
        both = N.new("ShaderNodeMath"); both.operation = "MULTIPLY"; L.new(m.outputs["Result"], both.inputs[0]); L.new(front.outputs[0], both.inputs[1])
        return both.outputs[0]

    def mix(a, color, fac):
        mm = N.new("ShaderNodeMix"); mm.data_type = "RGBA"
        L.new(fac, mm.inputs["Factor"])
        if isinstance(a, tuple):
            mm.inputs[6].default_value = a
        else:
            L.new(a, mm.inputs[6])
        mm.inputs[7].default_value = tuple(color)[:4]
        return mm.outputs[2]
    col = base
    if iris_rim:
        col = mix(col, iris_rim, disc(cx, cz, size * 0.9, size * 0.2))
        col = mix(col, base, disc(cx, cz, size * 0.66, size * 0.17))
    col = mix(col, pupil, disc(cx, cz, size * 0.5))
    col = mix(col, (1, 1, 1, 1), disc(cx + size * 0.15, cz + size * 0.28, size * 0.17))
    col = mix(col, (1, 1, 1, 1), disc(cx - size * 0.24, cz - size * 0.27, size * 0.07))
    L.new(col, bsdf.inputs["Base Color"])
