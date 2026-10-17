import bpy, sys
a = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.obj_import(filepath=a[0])
ob = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
ob.name = ob.data.name = "FieldGem"
for p in ob.data.polygons: p.use_smooth = False
import math, mathutils
ob.data.transform(mathutils.Matrix.Rotation(math.pi, 4, "Y"))  # Roblox FBX import turns the mesh 180 deg about its up axis (Blender Y here): pre-turn
print("COLORS", [c.name for c in ob.data.color_attributes], "TRIS", len(ob.data.polygons))
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.fbx(filepath=a[1], use_selection=True, axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE", colors_type="SRGB")
