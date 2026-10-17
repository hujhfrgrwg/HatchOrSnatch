# Eyes-flush check (Hunter 17 Oct: "the eyes arent attached"): every face-decal-shell vertex must stay within a hair
# of the head-surface vertex it was lifted from, in the rest pose and in every frame of every animation.
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE); sys.path.insert(0, os.path.dirname(HERE))
import numpy as np
import petkit as K
import lion as T

mb = T.build()
bones = T.bones_def()
pairs = np.array(list(T.face_shell.src.items()))          # (source vertex, shell vertex)
worst = 0.0
frames = 1
for name, fn in [('rest', None)] + list(T.ANIMS.items()):
    if fn is None:
        poses = [{}]
    else:
        a = fn()
        poses = [K.interp_pose(a, f) for f in range(a['frames'] + 1)]
    for pose in poses:
        vv = np.array(K.skin(mb, bones, pose))
        d = np.linalg.norm(vv[pairs[:, 1]] - vv[pairs[:, 0]], axis=1).max()
        worst = max(worst, d)
        frames += 1
ok = worst < 0.015
print('eyes-flush: %d shell verts, %d frames, max gap %.4f studs -> %s' % (len(pairs), frames, worst, 'OK' if ok else 'FAIL'))
sys.exit(0 if ok else 1)
