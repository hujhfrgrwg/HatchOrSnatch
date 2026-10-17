"""Export a pet module's ANIMS as a Luau data module for PetRig (Roblox model axes).
usage: python3 export_pet_anims.py <pet folder> <out.luau> <ModuleName>"""
import sys, os, math, importlib
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
pet = sys.argv[1]
sys.path.insert(0, os.path.join(HERE, pet)); sys.path.insert(0, HERE)
P = importlib.import_module(pet)
M = np.array([[-1, 0, 0], [0, 0, 1], [0, 1, 0]], float)
BONES = [b[0] for b in P.bones_def()]


def quat(R):
    t = np.trace(R)
    if t > 0:
        s = math.sqrt(t + 1.0) * 2
        w = 0.25 * s; x = (R[2, 1] - R[1, 2]) / s; y = (R[0, 2] - R[2, 0]) / s; z = (R[1, 0] - R[0, 1]) / s
    elif R[0, 0] > R[1, 1] and R[0, 0] > R[2, 2]:
        s = math.sqrt(1.0 + R[0, 0] - R[1, 1] - R[2, 2]) * 2
        w = (R[2, 1] - R[1, 2]) / s; x = 0.25 * s; y = (R[0, 1] + R[1, 0]) / s; z = (R[0, 2] + R[2, 0]) / s
    elif R[1, 1] > R[2, 2]:
        s = math.sqrt(1.0 + R[1, 1] - R[0, 0] - R[2, 2]) * 2
        w = (R[0, 2] - R[2, 0]) / s; x = (R[0, 1] + R[1, 0]) / s; y = 0.25 * s; z = (R[1, 2] + R[2, 1]) / s
    else:
        s = math.sqrt(1.0 + R[2, 2] - R[0, 0] - R[1, 1]) * 2
        w = (R[1, 0] - R[0, 1]) / s; x = (R[0, 2] + R[2, 0]) / s; y = (R[1, 2] + R[2, 1]) / s; z = 0.25 * s
    q = np.array([x, y, z, w])
    return q / np.linalg.norm(q)


def fmt(v):
    s = ('%.4f' % v).rstrip('0').rstrip('.')
    return '0' if s in ('-0', '') else s


out = ['-- %s: baked from pets/%s/%s.py. Do not edit by hand.' % (sys.argv[3], pet, pet),
       '-- Per key: for each bone in `bones`: qx, qy, qz, qw, tx, ty, tz (model axes, rest-relative,',
       '-- rotation about the bone head in model space; translation in studs at rig scale 1).',
       'return {']
for name, fn in P.ANIMS.items():
    a = fn()
    keys = a['keys']
    ks = sorted(keys)
    used = [b for b in BONES if any(b in keys[k] for k in ks)]
    out.append('\t%s = {' % name)
    out.append('\t\tframes = %d, loop = %s,' % (a['frames'], 'true' if a['loop'] else 'false'))
    out.append('\t\tbones = { %s },' % ', '.join('"%s"' % b for b in used))
    out.append('\t\tkeys = {')
    prevq = {}
    for k in ks:
        vals = []
        for b in used:
            R, t = keys[k].get(b, (np.eye(3), np.zeros(3)))
            q = quat(M @ R @ M.T)
            tr = M @ np.asarray(t, float)
            if b in prevq and np.dot(prevq[b], q) < 0:
                q = -q
            prevq[b] = q
            vals += [fmt(v) for v in q] + [fmt(v) for v in tr]
        out.append('\t\t\t{ f = %s, v = { %s } },' % (fmt(k), ', '.join(vals)))
    out.append('\t\t},')
    out.append('\t},')
out.append('}')
src = '\n'.join(out) + '\n'
open(sys.argv[2], 'w').write(src)
print(sys.argv[3], 'bytes', len(src), {n: (fn()['frames'], fn()['loop'], len(fn()['keys'])) for n, fn in P.ANIMS.items()})
