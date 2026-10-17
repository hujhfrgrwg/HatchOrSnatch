# HOS addition to the pet kit: render each baked action of a built <Name>_Pet.blend to a looping GIF (Blender Eevee,
# same studio look as render_pet_blender.py), so Hunter can judge the motion, not just poses.
#   blender --background --factory-startup --python render_pet_anims.py -- <pet dir> <out dir> [level] [size]
import bpy, math, os, sys
from mathutils import Vector

args = sys.argv[sys.argv.index('--') + 1:]
PET_DIR, OUT = args[0], args[1]
LEVEL = int(args[2]) if len(args) > 2 else 1
SIZE = int(args[3]) if len(args) > 3 else 420
os.makedirs(OUT, exist_ok=True)
sys.argv = [sys.argv[0], '--', PET_DIR, OUT, str(LEVEL)]
# reuse the still renderer's scene setup (materials, lights, ground, camera), without its stills
src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'render_pet_blender.py'), encoding='utf8').read()
src = src.split('\nD = size * 2.3')[0]
exec(compile(src, 'render_pet_blender.py', 'exec'))
scn.render.resolution_x = scn.render.resolution_y = SIZE
rig = next(o for o in scn.objects if o.type == 'ARMATURE')
if rig.animation_data is None:
    rig.animation_data_create()
frames_dir = os.path.join(OUT, '_frames')
os.makedirs(frames_dir, exist_ok=True)
D = size * 2.5
yaw, pitch = math.radians(35), math.radians(10)
cam.location = ctr + Vector((math.sin(yaw) * math.cos(pitch), -math.cos(yaw) * math.cos(pitch), math.sin(pitch))) * D
cam.rotation_euler = (ctr - cam.location).to_track_quat('-Z', 'Y').to_euler()
with bpy.data.libraries.load(os.path.join(PET_DIR, blend)) as (_s, _d):
    _d.actions = _s.actions
made = []
for act in list(bpy.data.actions):
    if not act.name.startswith(NAME + '_') or act.users == 0 and False:
        continue
    an = act.name[len(NAME) + 1:]
    rig.animation_data.action = act
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    paths = []
    for f in range(f0, f1 + 1):
        scn.frame_set(f)
        p = os.path.join(frames_dir, '%s_%03d.png' % (an, f))
        scn.render.filepath = p
        bpy.ops.render.render(write_still=True)
        paths.append(p)
    made.append((an, paths, scn.render.fps))
# write GIFs with Blender's bundled numpy-free path: hand the frame lists to a tiny manifest for PIL outside
with open(os.path.join(OUT, 'frames.txt'), 'w') as fh:
    for an, paths, fps in made:
        fh.write('%s|%d|%s\n' % (an, fps, ';'.join(paths)))
print('ANIM FRAMES', [m[0] for m in made])
