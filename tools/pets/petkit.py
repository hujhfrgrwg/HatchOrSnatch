"""petkit: shared helpers for Hatch or Snatch roster pets (HOS-PET-012+).

Pets are built procedurally, one script per species (tools/pets/<slug>.py), to the Mimic Crow's
conventions (the cofounder handoff's production benchmark):
  * stylised low-poly, smooth shaded with hard edges kept at ~40 degrees, muted body colours,
    toon eyes (white, black pupil, a white highlight, dark rim);
  * two meshes per form: <Prefix>Body and <Prefix>Face (the face is the same on L1-L3);
  * <= 1,500 triangles per form, pivot at the ground centre, facing -Y in Blender (= -Z, Roblox front);
  * sizes in studs (1 Blender unit = 1 stud).
Run: blender --background --factory-startup --python tools/pets/<slug>.py -- <outdir>
"""
import bpy, bmesh, math, json, os, sys
from mathutils import Vector, Matrix


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hexrgb(r, g, b):
    """An sRGB colour as Blender wants it (linear), so renders match the same colour in Roblox."""
    return (_lin(r), _lin(g), _lin(b), 1.0, (r, g, b))


def material(name, rgb, rough=0.6, emit=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    srgb = rgb[4] if len(rgb) > 4 else tuple(round(c * 255) for c in rgb[:3])
    rgb = rgb[:4]
    bsdf.inputs["Base Color"].default_value = rgb
    bsdf.inputs["Roughness"].default_value = rough
    if emit > 0:
        bsdf.inputs["Emission Color"].default_value = rgb
        bsdf.inputs["Emission Strength"].default_value = emit
    m["rgb"] = [c / 255.0 for c in srgb]  # sRGB 0..1, what Roblox shows
    return m


class Builder:
    """Collects pieces (bmesh primitives) into one mesh object with per-face materials."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.mats = []

    def _mat_index(self, mat):
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)

    def add(self, geom_fn, mat, matrix):
        tmp = bmesh.new()
        geom_fn(tmp)
        tmp.transform(matrix)
        idx = self._mat_index(mat)
        for f in tmp.faces:
            f.material_index = idx
        me = bpy.data.meshes.new("tmp")
        tmp.to_mesh(me)
        tmp.free()
        self.bm.from_mesh(me)
        bpy.data.meshes.remove(me)

    def sphere(self, mat, loc, scale, segs=12, rings=8, rot=(0, 0, 0)):
        m = Matrix.Translation(loc) @ euler(rot) @ Matrix.Diagonal((*scale, 1))
        self.add(lambda b: bmesh.ops.create_uvsphere(b, u_segments=segs, v_segments=rings, radius=1.0), mat, m)

    def cone(self, mat, loc, r1, r2, depth, segs=8, rot=(0, 0, 0), scale=(1, 1, 1)):
        m = Matrix.Translation(loc) @ euler(rot) @ Matrix.Diagonal((*scale, 1))
        self.add(lambda b: bmesh.ops.create_cone(b, cap_ends=True, segments=segs, radius1=r1, radius2=r2, depth=depth), mat, m)

    def limb(self, mat, a, b, r1, r2, segs=6):
        """A tapered cylinder from point a to point b (a joint-to-joint limb segment)."""
        a, b = Vector(a), Vector(b)
        d = b - a
        q = d.normalized().to_track_quat("Z", "Y")
        m = Matrix.Translation((a + b) / 2) @ q.to_matrix().to_4x4()
        self.add(lambda bm: bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r1, radius2=r2, depth=d.length), mat, m)

    def finish(self, smooth_angle=40.0):
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.mats:
            me.materials.append(m)
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        for p in me.polygons:
            p.use_smooth = True
        try:
            me.set_sharp_from_angle(angle=math.radians(smooth_angle))
        except AttributeError:
            pass
        return ob


def euler(rot):
    from mathutils import Euler
    return Euler([math.radians(a) for a in rot], "XYZ").to_matrix().to_4x4()


def tri_count(ob):
    me = ob.data
    me.calc_loop_triangles()
    return len(me.loop_triangles)


def toon_eye(b, white, black, rim, loc, size, look=(0, -1, 0), side=1):
    """A toon eye: dark rim, white ball, black pupil and a small white highlight, facing `look`."""
    lx, ly, lz = loc
    d = Vector(look).normalized()
    b.sphere(rim, (lx, ly + 0.012, lz), (size * 1.12, size * 0.5, size * 1.12), segs=8, rings=5)
    b.sphere(white, (lx, ly, lz), (size, size * 0.55, size), segs=8, rings=5)
    p = Vector((lx, ly, lz)) + d * (size * 0.5)
    b.sphere(black, (p.x + side * size * 0.08, p.y, p.z), (size * 0.5, size * 0.12, size * 0.56), segs=6, rings=4)
    h = p + d * (size * 0.07)
    b.sphere(white, (h.x + side * size * 0.24, h.y, h.z + size * 0.22), (size * 0.13, size * 0.05, size * 0.13), segs=4, rings=3)


def setup_render(res=1024, bg=(0.86, 0.88, 0.92)):
    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "BLENDER_WORKBENCH"):
        try:
            sc.render.engine = eng
            break
        except TypeError:
            continue
    sc.render.resolution_x = res
    sc.render.resolution_y = res
    sc.render.film_transparent = False
    try:
        sc.view_settings.view_transform = "Standard"
    except Exception:
        pass
    world = bpy.data.worlds.new("W")
    sc.world = world
    world.use_nodes = True
    bgn = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bgn.inputs["Color"].default_value = (*[c ** 2.2 for c in bg], 1)
    bgn.inputs["Strength"].default_value = 0.55
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 2.2
    so = bpy.data.objects.new("Sun", sun)
    so.rotation_euler = (math.radians(50), math.radians(10), math.radians(-35))
    sc.collection.objects.link(so)
    fill = bpy.data.lights.new("Fill", "SUN")
    fill.energy = 0.6
    fo = bpy.data.objects.new("Fill", fill)
    fo.rotation_euler = (math.radians(70), 0, math.radians(150))
    sc.collection.objects.link(fo)
    # ground disc for a contact shadow
    bpy.ops.mesh.primitive_circle_add(vertices=48, radius=3.2, fill_type="NGON")
    g = bpy.context.active_object
    g.name = "Ground"
    g.data.materials.append(material("Ground", (*bg, 1), rough=0.9))
    try:
        sc.view_settings.view_transform = "Standard"
    except Exception:
        pass


def render_views(target_h, center_z, outdir, slug, views, dist=6.5):
    sc = bpy.context.scene
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = 70
    cam = bpy.data.objects.new("Cam", cam_data)
    sc.collection.objects.link(cam)
    sc.camera = cam
    paths = []
    for name, yaw, pitch in views:
        a = math.radians(yaw)
        p = math.radians(pitch)
        # yaw 0 = looking at the pet's front (pet faces -Y), so the camera sits at -Y
        pos = Vector((math.sin(a) * dist * math.cos(p), -math.cos(a) * dist * math.cos(p), center_z + dist * math.sin(p)))
        cam.location = pos
        look = Vector((0, 0, center_z)) - pos
        cam.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()
        out = os.path.join(outdir, f"{slug}_{name}.png")
        sc.render.filepath = out
        bpy.ops.render.render(write_still=True)
        paths.append(out)
    return paths


def export_mesh_json(obs, path):
    """Vertices, triangles and per-face colours (from each face's material) for a Studio EditableMesh preview."""
    out = []
    for ob in obs:
        me = ob.data
        me.calc_loop_triangles()
        verts = [list(ob.matrix_world @ v.co) for v in me.vertices]
        tris = []
        for t in me.loop_triangles:
            mat = me.materials[t.material_index]
            rgb = list(mat["rgb"]) if mat and "rgb" in mat else [0.6, 0.6, 0.6]
            tris.append([list(t.vertices), [round(c, 4) for c in rgb], list(t.normal)])
        out.append({"name": ob.name, "verts": [[round(c, 4) for c in v] for v in verts], "tris": tris})
    with open(path, "w") as fh:
        json.dump(out, fh)


def outdir_arg(default):
    argv = sys.argv
    if "--" in argv:
        rest = argv[argv.index("--") + 1:]
        if rest:
            return os.path.abspath(rest[0])
    return os.path.abspath(default)
