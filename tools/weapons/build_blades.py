# HOS-WEP-002: three original dagger-skin blades (replacing the IP-risk models from HOS-WEP-001).
# Run headless:  blender --background --factory-startup --python build_blades.py -- <out_dir>
# Builds Stormfang Katana, Starforged Blade and Grave Crescent Scythe from scratch (no outside meshes),
# one object per material so Roblox gets one MeshPart per colour (Glow parts become Neon in Studio).
# Writes <out>/<Name>.fbx, <out>/<Name>.blend and preview renders.
import bpy, bmesh, math, os, sys
from mathutils import Vector

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.path.join(os.path.dirname(__file__), "out")
os.makedirs(OUT, exist_ok=True)

MATS = {  # name: (base colour, emission strength, metallic, roughness)
    "Steel": ((0.78, 0.82, 0.88), 0, 0.9, 0.25),
    "DarkSteel": ((0.10, 0.11, 0.15), 0, 0.8, 0.35),
    "Gold": ((1.0, 0.72, 0.22), 0, 1.0, 0.3),
    "Grip": ((0.06, 0.08, 0.20), 0, 0.0, 0.8),
    "Wrap": ((0.92, 0.86, 0.70), 0, 0.0, 0.7),
    "Bone": ((0.90, 0.86, 0.76), 0, 0.0, 0.55),
    "Wood": ((0.09, 0.06, 0.06), 0, 0.0, 0.7),
    "GlowCyan": ((0.30, 0.85, 1.0), 1.5, 0.0, 0.3),
    "GlowTeal": ((0.20, 1.0, 0.75), 1.5, 0.0, 0.3),
    "GlowCrimson": ((1.0, 0.12, 0.18), 1.5, 0.0, 0.3),
}


def mat(name):
    m = bpy.data.materials.get(name)
    if m:
        return m
    c, e, met, rough = MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*c, 1)
    b.inputs["Metallic"].default_value = met
    b.inputs["Roughness"].default_value = rough
    if e:
        for k in ("Emission Color", "Emission"):
            if k in b.inputs:
                b.inputs[k].default_value = (*c, 1)
                break
        b.inputs["Emission Strength"].default_value = e
    m.diffuse_color = (*c, 1)
    return m


def obj_from_bm(bm, name, material, smooth=False):
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = smooth
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(mat(material))
    return ob


def loft(rings, cap0=True, cap1=True):
    """rings: list of lists of Vector (same count, ordered around). Returns bmesh."""
    bm = bmesh.new()
    vr = [[bm.verts.new(p) for p in r] for r in rings]
    n = len(rings[0])
    for a, b in zip(vr, vr[1:]):
        for i in range(n):
            j = (i + 1) % n
            try:
                bm.faces.new((a[i], a[j], b[j], b[i]))
            except ValueError:
                pass
    if cap0:
        try: bm.faces.new(list(reversed(vr[0])))
        except ValueError: pass
    if cap1:
        try: bm.faces.new(vr[-1])
        except ValueError: pass
    return bm


def lathe(profile, seg=12, z0=0.0):
    """profile: list of (z, r). Round part around Z."""
    rings = []
    for z, r in profile:
        rings.append([Vector((r * math.cos(2 * math.pi * k / seg), r * math.sin(2 * math.pi * k / seg), z0 + z)) for k in range(seg)])
    return loft(rings)


def box(c, s):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * s[0] + c[0], v.co.y * s[1] + c[1], v.co.z * s[2] + c[2]))
    return bm


def join(bms):
    out = bmesh.new()
    for b in bms:
        me = bpy.data.meshes.new("tmp")
        b.to_mesh(me)
        b.free()
        out.from_mesh(me)
        bpy.data.meshes.remove(me)
    return out


def octa(c, r, h):
    bm = bmesh.new()
    pts = [Vector((c[0] + r, c[1], c[2])), Vector((c[0], c[1] + r * 0.6, c[2])), Vector((c[0] - r, c[1], c[2])), Vector((c[0], c[1] - r * 0.6, c[2]))]
    vs = [bm.verts.new(p) for p in pts]
    top = bm.verts.new(Vector((c[0], c[1], c[2] + h)))
    bot = bm.verts.new(Vector((c[0], c[1], c[2] - h)))
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((vs[i], vs[j], top))
        bm.faces.new((vs[j], vs[i], bot))
    return bm


def clear():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for m in list(bpy.data.meshes):
        bpy.data.meshes.remove(m)


# ------------------------------------------------------------------------------------- Stormfang Katana
def katana():
    L = 1.95          # blade length
    base = 0.0        # blade starts at z = 0 (handle below)
    curve = 0.10      # sori: back-edge offset at the tip
    parts = []
    N = 18
    rings, edge = [], []
    for i in range(N + 1):
        t = i / N
        z = base + t * L
        x0 = curve * t * t                               # curve toward +x (edge on -x side... back on +x)
        w = 0.115 * (1 - 0.25 * t)                       # width (back to edge)
        th = 0.028 * (1 - 0.4 * t)
        if t > 0.86:                                     # kissaki: back slopes down to the point
            k = (t - 0.86) / 0.14
            w *= (1 - k) + 0.02
            th *= (1 - 0.8 * k)
        back = Vector((x0 + w * 0.5, 0, z))
        ridge_p = Vector((x0 + w * 0.15, th * 0.5, z))
        ridge_n = Vector((x0 + w * 0.15, -th * 0.5, z))
        e = Vector((x0 - w * 0.5, 0, z + (0.0 if t < 0.86 else 0.03 * (t - 0.86) / 0.14)))
        rings.append([back, ridge_p, e, ridge_n])
        edge.append((e, w, th, x0))
    parts.append(("Blade", "Steel", loft(rings)))
    # glowing hamon strip just above the edge on both faces
    gr = []
    for (e, w, th, x0) in edge[1:-2]:
        a = e + Vector((w * 0.12, 0, 0))
        b = e + Vector((w * 0.34, 0, 0))
        gr.append([a + Vector((0, th * 0.18, 0)), b + Vector((0, th * 0.38, 0)), b + Vector((0, -th * 0.38, 0)), a + Vector((0, -th * 0.18, 0))])
    parts.append(("Glow", "GlowCyan", loft(gr)))
    # habaki collar
    parts.append(("Collar", "Gold", box((0.0, 0, 0.03), (0.13, 0.05, 0.08))))
    # tsuba: eight-point star guard with lightning-cut points
    bm = bmesh.new()
    pts = []
    for k in range(16):
        a = 2 * math.pi * k / 16
        r = 0.19 if k % 2 == 0 else 0.12
        pts.append((r * math.cos(a), r * math.sin(a) * 0.75))
    top = [bm.verts.new((x, y, -0.0)) for x, y in pts]
    bot = [bm.verts.new((x, y, -0.06)) for x, y in pts]
    bm.faces.new(top)
    bm.faces.new(list(reversed(bot)))
    for i in range(16):
        j = (i + 1) % 16
        bm.faces.new((bot[i], bot[j], top[j], top[i]))
    parts.append(("Guard", "DarkSteel", bm))
    parts.append(("GuardGem", "GlowCyan", octa((0.0, 0.0, -0.03), 0.045, 0.045)))
    # handle (tsuka): oval octagon from -0.04 to -0.80
    seg = 8
    def oval(z, r):
        return [Vector((r * math.cos(2 * math.pi * k / seg + math.pi / 8), 0.7 * r * math.sin(2 * math.pi * k / seg + math.pi / 8), z)) for k in range(seg)]
    parts.append(("Grip", "Grip", loft([oval(-0.04, 0.055), oval(-0.42, 0.058), oval(-0.78, 0.052)])))
    # wrap diamonds on both faces
    wr = []
    for i in range(6):
        zc = -0.10 - i * 0.115
        for side in (1, -1):
            bm = bmesh.new()
            y = side * 0.7 * 0.058
            v = [bm.verts.new((0, y, zc + 0.05)), bm.verts.new((0.05, y, zc)), bm.verts.new((0, y, zc - 0.05)), bm.verts.new((-0.05, y, zc))]
            v2 = [bm.verts.new((p.co.x * 0.8, y + side * 0.012, p.co.z * 1 + (zc - p.co.z) * 0.2)) for p in v]
            bm.faces.new(v2 if side > 0 else list(reversed(v2)))
            for a in range(4):
                b = (a + 1) % 4
                f = (v[a], v[b], v2[b], v2[a])
                bm.faces.new(f if side > 0 else tuple(reversed(f)))
            wr.append(bm)
    parts.append(("Wrap", "Wrap", join(wr)))
    parts.append(("Pommel", "Gold", lathe([(0, 0.0), (0.0, 0.06), (-0.05, 0.062), (-0.08, 0.04), (-0.09, 0.0)], 8, -0.78)))
    return "Stormfang_Katana", parts


# ------------------------------------------------------------------------------------- Starforged Blade
def starsword():
    L = 1.85
    N = 16
    rings, inlay = [], []
    for i in range(N + 1):
        t = i / N
        z = 0.06 + t * L
        # leaf profile: widens to 0.24 at 30% then tapers to a point
        w = 0.17 + 0.07 * math.sin(math.pi * min(t / 0.6, 1.0)) if t < 0.6 else 0.17 * (1 - (t - 0.6) / 0.4) + 0.006
        if t >= 0.6:
            w = (0.17 + 0.07 * math.sin(math.pi * 1.0)) * (1 - (t - 0.6) / 0.4) + 0.006
        th = 0.045 * (1 - 0.6 * t) + 0.004
        rings.append([Vector((w / 2, 0, z)), Vector((0, th / 2, z)), Vector((-w / 2, 0, z)), Vector((0, -th / 2, z))])
        if 0.05 < t < 0.78:
            iw = w * 0.16
            inlay.append([Vector((iw, th * 0.40, z)), Vector((0, th * 0.62, z)), Vector((-iw, th * 0.40, z)),
                          Vector((-iw, -th * 0.40, z)), Vector((0, -th * 0.62, z)), Vector((iw, -th * 0.40, z))])
    parts = [("Blade", "Steel", loft(rings)), ("Glow", "GlowTeal", loft(inlay))]
    # swept crossguard: two wings that rise outward
    wings = []
    for side in (1, -1):
        r = []
        M = 8
        for i in range(M + 1):
            t = i / M
            x = side * (0.04 + 0.30 * t)
            z = 0.02 + 0.16 * t * t
            h = 0.07 * (1 - 0.8 * t) + 0.01
            d = 0.05 * (1 - 0.6 * t) + 0.008
            r.append([Vector((x, d, z + h)), Vector((x, d, z - h)), Vector((x, -d, z - h)), Vector((x, -d, z + h))])
        if side < 0:
            r = [list(reversed(q)) for q in r]
        wings.append(loft(r))
    wings.append(box((0, 0, 0.02), (0.12, 0.10, 0.10)))
    parts.append(("Guard", "Gold", join(wings)))
    parts.append(("GuardGem", "GlowTeal", octa((0, 0.0, 0.02), 0.045, 0.05)))
    parts.append(("Grip", "Grip", lathe([(0.0, 0.045), (-0.25, 0.05), (-0.52, 0.045)], 8, -0.03)))
    parts.append(("Ring", "Gold", join([lathe([(0.0, 0.055), (-0.03, 0.058), (-0.06, 0.055)], 10, -0.04),
                                        lathe([(0.0, 0.055), (-0.03, 0.058), (-0.06, 0.055)], 10, -0.50)])))
    # four-point star pommel
    bm = bmesh.new()
    zc = -0.66
    pts = []
    for k in range(8):
        a = 2 * math.pi * k / 8
        r = 0.12 if k % 2 == 0 else 0.04
        pts.append(Vector((r * math.cos(a), 0, zc + r * math.sin(a))))
    f = [bm.verts.new(p + Vector((0, 0.03, 0))) for p in pts]
    b = [bm.verts.new(p - Vector((0, 0.03, 0))) for p in pts]
    bm.faces.new(f); bm.faces.new(list(reversed(b)))
    for i in range(8):
        j = (i + 1) % 8
        bm.faces.new((b[i], b[j], f[j], f[i]))
    parts.append(("Pommel", "Gold", bm))
    parts.append(("PommelGem", "GlowTeal", octa((0, 0, zc), 0.03, 0.035)))
    return "Starforged_Blade", parts


# ------------------------------------------------------------------------------------- Grave Crescent Scythe
def scythe():
    H = 2.55
    parts = []
    parts.append(("Staff", "Wood", lathe([(0, 0.035), (H * 0.5, 0.042), (H, 0.038)], 8, -0.6)))
    rings = []
    for z in (-0.55, 0.2, 0.95):
        rings.append(lathe([(0, 0.05), (0.03, 0.064), (0.06, 0.05)], 10, z))
    parts.append(("Rings", "Bone", join(rings)))
    top = H - 0.6
    # blade: quadratic Bezier from the socket out to -x, curling down to a point
    P0, P1, P2 = Vector((0.02, 0, top - 0.02)), Vector((-0.70, 0, top + 0.34)), Vector((-1.10, 0, top - 0.42))
    def bez(t):
        return (1 - t) ** 2 * P0 + 2 * (1 - t) * t * P1 + t * t * P2
    def tan(t):
        return (2 * (1 - t) * (P1 - P0) + 2 * t * (P2 - P1)).normalized()
    N = 20
    br, gl = [], []
    for i in range(N + 1):
        t = i / N
        c = bez(t)
        tg = tan(t)
        n = -Vector((tg.z, 0, -tg.x))                 # perpendicular, pointing to the concave (lower) side
        w = 0.22 * (1 - t) ** 0.8 + 0.01
        th = 0.04 * (1 - 0.7 * t) + 0.004
        outer = c - n * (w * 0.45)
        inner = c + n * (w * 0.55)
        mid = (outer + inner) / 2
        br.append([outer, mid + Vector((0, th / 2, 0)), inner, mid - Vector((0, th / 2, 0))])
        if 0.06 < t < 0.93:
            e0 = inner - n * (w * 0.08)
            e1 = inner - n * (w * 0.30)
            gl.append([e0 + Vector((0, th * 0.14, 0)), e1 + Vector((0, th * 0.34, 0)), e1 - Vector((0, th * 0.34, 0)), e0 - Vector((0, th * 0.14, 0))])
    parts.append(("Blade", "Bone", loft(br)))
    parts.append(("Glow", "GlowCrimson", loft(gl)))
    # two hooked thorns on the back of the blade
    thorns = []
    for t, ln in ((0.28, 0.20), (0.52, 0.15)):
        c = bez(t); tg = tan(t); n = -Vector((tg.z, 0, -tg.x))
        w = 0.22 * (1 - t) ** 0.8 + 0.01
        base = c - n * (w * 0.40)
        tip = base - n * ln - tg * ln * 0.6
        bm = bmesh.new()
        a = bm.verts.new(base + tg * 0.05); b = bm.verts.new(base - tg * 0.05)
        u = bm.verts.new(base + Vector((0, 0.015, 0))); d = bm.verts.new(base - Vector((0, 0.015, 0)))
        p = bm.verts.new(tip)
        for f in ((a, u, p), (u, b, p), (b, d, p), (d, a, p), (a, d, b, u)):
            bm.faces.new(f)
        thorns.append(bm)
    parts.append(("Thorns", "Bone", join(thorns)))
    parts.append(("Socket", "DarkSteel", join([box((0, 0, top - 0.02), (0.15, 0.11, 0.20)),
                                                lathe([(0, 0.05), (0.18, 0.0)], 8, top + 0.08)])))
    parts.append(("SocketGem", "GlowCrimson", octa((0.0, -0.06, top - 0.02), 0.035, 0.045)))
    parts.append(("Spike", "DarkSteel", lathe([(0, 0.045), (-0.2, 0.0)], 8, -0.6)))
    return "Grave_Crescent_Scythe", parts


def build(fn):
    clear()
    name, parts = fn()
    obs = []
    for pname, m, bm in parts:
        obs.append(obj_from_bm(bm, f"{name}_{pname}", m, smooth=pname in ("Grip", "Staff", "Rings", "Pommel")))
    return name, obs


def setup_render():
    sc = bpy.context.scene
    try:
        sc.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        try: sc.render.engine = "BLENDER_EEVEE"
        except TypeError: pass
    sc.render.resolution_x, sc.render.resolution_y = 700, 1000
    sc.render.film_transparent = False
    w = bpy.data.worlds.new("W") if not bpy.data.worlds else bpy.data.worlds[0]
    sc.world = w
    w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (0.05, 0.055, 0.07, 1)
    bg.inputs[1].default_value = 1.0
    try:
        sc.eevee.use_bloom = True
    except Exception:
        pass
    sc.view_settings.view_transform = "Standard"


def render(obs, path, view=(0.0, -1.0, 0.0)):
    from mathutils import Vector as V
    mn = V((1e9,) * 3); mx = V((-1e9,) * 3)
    for o in obs:
        for c in o.bound_box:
            w = o.matrix_world @ V(c)
            mn = V(map(min, mn, w)); mx = V(map(max, mx, w))
    ctr = (mn + mx) / 2
    size = max(mx - mn)
    cam = bpy.data.cameras.new("C"); cam.type = "ORTHO"; cam.ortho_scale = size * 1.15
    co = bpy.data.objects.new("C", cam); bpy.context.collection.objects.link(co)
    d = V(view).normalized()
    co.location = ctr - d * 10
    co.rotation_euler = (d).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = co
    for nm, loc, e in (("K", (3, -4, 5), 600), ("F", (-4, -3, 2), 250), ("R", (0, 4, 3), 300)):
        l = bpy.data.lights.new(nm, "AREA"); l.energy = e; l.size = 3
        lo = bpy.data.objects.new(nm, l); lo.location = ctr + V(loc); bpy.context.collection.objects.link(lo)
        lo.rotation_euler = (ctr - lo.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    for nm in ("C", "K", "F", "R"):
        o = bpy.data.objects.get(nm)
        if o: bpy.data.objects.remove(o, do_unlink=True)


for fn in (katana, starsword, scythe):
    name, obs = build(fn)
    setup_render()
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in obs)
    print(f"[HOS] {name}: {len(obs)} parts, {tris} tris")
    render(obs, os.path.join(OUT, f"{name}_front.png"))
    render(obs, os.path.join(OUT, f"{name}_3q.png"), (0.6, -1.0, -0.15))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, f"{name}.blend"))
    bpy.ops.object.select_all(action="DESELECT")
    for o in obs: o.select_set(True)
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, f"{name}.fbx"), use_selection=True, apply_unit_scale=True,
                             axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE")
print("[HOS] done")
