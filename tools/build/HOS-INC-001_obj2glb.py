# Converts the egg pieces OBJ (o/g PieceN blocks) into a GLB with one mesh + node per piece.
import json, struct, sys
src, dst = sys.argv[1], sys.argv[2]
V, VT, VN = [], [], []
pieces = []
for line in open(src):
    t = line.split()
    if not t: continue
    if t[0] == 'o': pieces.append({'name': t[1], 'f': []})
    elif t[0] == 'v': V.append(tuple(map(float, t[1:4])))
    elif t[0] == 'vt': VT.append(tuple(map(float, t[1:3])))
    elif t[0] == 'vn': VN.append(tuple(map(float, t[1:4])))
    elif t[0] == 'f': pieces[-1]['f'].append([tuple(int(x) - 1 for x in c.split('/')) for c in t[1:4]])
bin_ = bytearray(); views = []; accessors = []; meshes = []; nodes = []
def add_view(data, target):
    while len(bin_) % 4: bin_.append(0)
    off = len(bin_); bin_.extend(data)
    views.append({'buffer': 0, 'byteOffset': off, 'byteLength': len(data), 'target': target})
    return len(views) - 1
for p in pieces:
    idx = {}; pos = []; uv = []; nrm = []; ind = []
    for tri in p['f']:
        for key in tri:
            if key not in idx:
                idx[key] = len(pos)
                pos.append(V[key[0]]); u = VT[key[1]]; uv.append((u[0], 1 - u[1])); nrm.append(VN[key[2]])
            ind.append(idx[key])
    acc = {}
    for name, arr, typ in (('POSITION', pos, 'VEC3'), ('TEXCOORD_0', uv, 'VEC2'), ('NORMAL', nrm, 'VEC3')):
        n = len(arr[0])
        data = b''.join(struct.pack('<' + 'f' * n, *a) for a in arr)
        a = {'bufferView': add_view(data, 34962), 'componentType': 5126, 'count': len(arr), 'type': typ}
        if name == 'POSITION':
            a['min'] = [min(x[i] for x in arr) for i in range(3)]; a['max'] = [max(x[i] for x in arr) for i in range(3)]
        accessors.append(a); acc[name] = len(accessors) - 1
    data = struct.pack('<' + 'I' * len(ind), *ind)
    accessors.append({'bufferView': add_view(data, 34963), 'componentType': 5125, 'count': len(ind), 'type': 'SCALAR'})
    meshes.append({'name': p['name'], 'primitives': [{'attributes': acc, 'indices': len(accessors) - 1, 'material': 0}]})
    nodes.append({'name': p['name'], 'mesh': len(meshes) - 1})
while len(bin_) % 4: bin_.append(0)
gltf = {'asset': {'version': '2.0', 'generator': 'HOS-INC-001 obj2glb'},
        'scene': 0, 'scenes': [{'name': 'IncubatorEggPieces', 'nodes': list(range(len(nodes)))}],
        'nodes': nodes, 'meshes': meshes, 'accessors': accessors, 'bufferViews': views,
        'materials': [{'name': 'EggShell', 'pbrMetallicRoughness': {'baseColorFactor': [1, 1, 1, 1], 'metallicFactor': 0, 'roughnessFactor': 0.8}}],
        'buffers': [{'byteLength': len(bin_)}]}
j = json.dumps(gltf, separators=(',', ':')).encode()
while len(j) % 4: j += b' '
out = struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(j) + 8 + len(bin_)) + struct.pack('<II', len(j), 0x4E4F534A) + j + struct.pack('<II', len(bin_), 0x004E4942) + bytes(bin_)
open(dst, 'wb').write(out)
print(len(pieces), 'pieces,', sum(len(p['f']) for p in pieces), 'triangles,', len(out), 'bytes')
