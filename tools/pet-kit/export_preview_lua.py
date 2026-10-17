# HOS addition to the pet kit: an upload-free Studio preview. Writes a ModuleScript (.rbxmx) holding each level's
# rest-pose mesh (positions + UVs, split into the atlas mesh and the face mesh) plus the painted textures as base64
# (atlas 512 px RGB per level, face 128 px RGBA per level), for an EditableMesh + EditableImage lineup in Studio
# under the place's real lighting. Nothing is uploaded.
#   python export_preview_lua.py <pet folder> <out.rbxmx> <ModuleName>
import base64, importlib, os, sys
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
pet, out, modname = sys.argv[1], sys.argv[2], sys.argv[3]
sys.path.insert(0, os.path.join(HERE, pet)); sys.path.insert(0, HERE)
import petkit as K
P = importlib.import_module(pet)
mb = P.build()
rest = np.array(K.skin(mb, P.bones_def(), {}))
levels = {1: (0, 2, 3)[:1], 2: (0, 2), 3: (0, 2, 3)}


def fmt(v):
    return ('%.4f' % v).rstrip('0').rstrip('.') or '0'


def down(img, n):
    H = img.shape[0]
    k = H // n
    return img[:k * n, :k * n].reshape(n, k, n, k, -1).mean(axis=(1, 3))


def mesh(mats):
    vs, uv = [], []
    for f, uvs, m in zip(mb.F, mb.UV, mb.MAT):
        if m not in mats:
            continue
        for t in range(1, len(f) - 1):
            for idx, u in ((f[0], uvs[0]), (f[t], uvs[t]), (f[t + 1], uvs[t + 1])):
                p = rest[idx]
                vs += [-p[0], p[2], p[1]]          # kit (x, y, z) -> Roblox (-x, z, y)
                uv += [u[0], 1 - u[1]]
    return '{ v = {%s}, uv = {%s} }' % (','.join(fmt(x) for x in vs), ','.join(fmt(x) for x in uv))


def b64img(img, alpha):
    a = np.clip(img, 0, 1)
    if not alpha:
        a = np.concatenate([a[..., :3], np.ones(a.shape[:2] + (1,), np.float32)], -1)
    return base64.b64encode((a * 255 + 0.5).astype(np.uint8).tobytes()).decode()


lines = ['return {', '\tface = %s,' % mesh((1,))]
for lv, mats in levels.items():
    atlas = down(P.paint_atlas(lv)[0], 512)
    face = down(P.face_texture(lv), 128)
    lines.append('\t[%d] = { body = %s, atlas = "%s", face = "%s" },' % (lv, mesh(mats), b64img(atlas, False),
                                                                        b64img(face, True)))
lines.append('}')
src = '\n'.join(lines)
assert ']]>' not in src
open(out, 'w', encoding='utf-8').write('<roblox version="4"><Item class="ModuleScript" referent="RBX0"><Properties>'
                                       '<string name="Name">%s</string><ProtectedString name="Source"><![CDATA[%s]]>'
                                       '</ProtectedString></Properties></Item></roblox>' % (modname, src))
print(out, len(src))
