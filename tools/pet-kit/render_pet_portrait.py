# HOS addition to the pet kit: a transparent 3/4 portrait of a built pet for UI cards (shop, pets list).
#   blender --background --factory-startup --python render_pet_portrait.py -- <pet dir> <out png> [level] [size]
import bpy, math, os, sys
from mathutils import Vector
args = sys.argv[sys.argv.index('--') + 1:]
PET_DIR, OUT_PNG = args[0], args[1]
LEVEL = args[2] if len(args) > 2 else '1'
SIZE = int(args[3]) if len(args) > 3 else 640
sys.argv = [sys.argv[0], '--', PET_DIR, os.path.dirname(OUT_PNG), LEVEL]
src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'render_pet_blender.py'), encoding='utf8').read()
src = src.split('\nD = size * 2.3')[0]
exec(compile(src, 'render_pet_blender.py', 'exec'))
scn.render.film_transparent = True
scn.render.resolution_x = scn.render.resolution_y = SIZE
ground.hide_render = True
a, p = math.radians(32), math.radians(10)
cam.location = ctr + Vector((math.sin(a) * math.cos(p), -math.cos(a) * math.cos(p), math.sin(p))) * size * 2.05
cam.rotation_euler = (ctr - cam.location).to_track_quat('-Z', 'Y').to_euler()
scn.render.filepath = OUT_PNG
bpy.ops.render.render(write_still=True)
print('PORTRAIT', OUT_PNG)
