# HOS-LOBBY-005 (18 Oct 2026, Matthew): a low-poly, faceted jack-o'-lantern mesh, from his reference sheet
# (front / side / back / 3-4 views): a squashed pumpkin with ribbed lobes, an angry carved face that glows (slanted eyes,
# triangle nose, jagged grin) and a curved stem. Writes one GLB with four meshes for Studio's 3D Importer:
#   JackBody   the pumpkin (flat-shaded facets)
#   JackRim    the carved edge round each face hole (a darker band just above the skin)
#   JackGlow   the glowing face shapes (just above the rim; Neon in Roblox)
#   JackStem   the curved stem
# Units: studs, Y up, the face looks along -Z (Roblox's Front). About 2.2 wide and 2.4 tall with the stem.
# Run: python3 tools/build/HOS-LOBBY-005_jack_o_lantern.py docs/HOS-LOBBY-005/JackOLantern.glb
import json, math, struct, sys
import numpy as np

rng = np.random.default_rng(7)

# ---------------------------------------------------------------- body
LOBES = 10
SEG = LOBES * 2  # a vertex on each lobe's crest and in each groove
RINGS = [  # (y, radius) bottom pole -> top pole; the top dips in where the stem sits
    (-0.70, 0.0), (-0.79, 0.45), (-0.71, 0.80), (-0.48, 1.01), (-0.17, 1.10),
    (0.13, 1.09), (0.41, 0.99), (0.62, 0.78), (0.76, 0.46), (0.72, 0.19), (0.62, 0.0),
]

def body_triangles():
    verts = []
    for j, (y, r) in enumerate(RINGS):
        ring = []
        for i in range(SEG):
            u = 2 * math.pi * i / SEG
            k = 1.07 if i % 2 == 0 else 0.93  # crest / groove
            if 0 < j < len(RINGS) - 1:
                jitter = 1 + rng.uniform(-0.015, 0.015)
                yy = y + rng.uniform(-0.012, 0.012)
            else:
                jitter, yy = 1, y
            rr = r * k * jitter
            ring.append((rr * math.cos(u), yy, rr * math.sin(u)))
        verts.append(ring)
    tris = []
    for j in range(len(RINGS) - 1):
        a, b = verts[j], verts[j + 1]
        for i in range(SEG):
            i2 = (i + 1) % SEG
            if j == 0:
                tris.append((a[0], b[i2], b[i]))  # bottom fan
            elif j == len(RINGS) - 2:
                tris.append((a[i], a[i2], b[0]))  # top fan
            else:
                tris.append((a[i], a[i2], b[i2]))
                tris.append((a[i], b[i2], b[i]))
    return [tuple(np.array(p, float) for p in t) for t in tris]

def outward(tris, centre=np.zeros(3)):
    out = []
    for a, b, c in tris:
        n = np.cross(b - a, c - a)
        if np.dot(n, (a + b + c) / 3 - centre) < 0:
            b, c = c, b
        out.append((a, b, c))
    return out

body = outward(body_triangles())

# ---------------------------------------------------------------- the face (front view, x right, y up; on the -Z side)
LEFT_EYE = [(-0.74, 0.34), (-0.22, 0.17), (-0.34, 0.03), (-0.66, 0.11)]
RIGHT_EYE = [(-x, y) for x, y in reversed(LEFT_EYE)]
NOSE = [(0.0, 0.07), (0.12, -0.11), (-0.12, -0.11)]
MOUTH = [  # a wide grin: two fangs hanging from the top, a square tooth standing on the bottom
    (-0.82, -0.08), (-0.56, -0.22), (-0.47, -0.36), (-0.37, -0.23), (0.37, -0.23), (0.47, -0.36), (0.56, -0.22),
    (0.82, -0.08), (0.64, -0.42), (0.33, -0.58), (0.13, -0.58), (0.13, -0.45), (-0.13, -0.45), (-0.13, -0.58),
    (-0.33, -0.58), (-0.64, -0.42),
]
SHAPES = [LEFT_EYE, RIGHT_EYE, NOSE, MOUTH]

def area(poly):
    return 0.5 * sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1] for i in range(len(poly)))

def ear_clip(poly):
    pts = list(poly)
    if area(pts) < 0:
        pts.reverse()
    idx = list(range(len(pts)))
    tris = []
    def inside(p, a, b, c):
        def s(p1, p2, p3):
            return (p1[0] - p3[0]) * (p2[1] - p3[1]) - (p2[0] - p3[0]) * (p1[1] - p3[1])
        d1, d2, d3 = s(p, a, b), s(p, b, c), s(p, c, a)
        return not ((d1 < 0 or d2 < 0 or d3 < 0) and (d1 > 0 or d2 > 0 or d3 > 0))
    guard = 0
    while len(idx) > 3 and guard < 1000:
        guard += 1
        for k in range(len(idx)):
            i0, i1, i2 = idx[k - 1], idx[k], idx[(k + 1) % len(idx)]
            a, b, c = pts[i0], pts[i1], pts[i2]
            if (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]) <= 0:
                continue  # reflex
            if any(inside(pts[j], a, b, c) for j in idx if j not in (i0, i1, i2)):
                continue
            tris.append((a, b, c))
            idx.pop(k)
            break
    tris.append(tuple(pts[i] for i in idx))
    return tris

def subdivide(tri, n):
    if n == 0:
        return [tri]
    a, b, c = (np.array(p, float) for p in tri)
    ab, bc, ca = (a + b) / 2, (b + c) / 2, (c + a) / 2
    out = []
    for t in ((a, ab, ca), (ab, b, bc), (ca, bc, c), (ab, bc, ca)):
        out += subdivide(t, n - 1)
    return out

BODY = np.array([[p for p in t] for t in body])  # (n, 3, 3)

def project(x, y, lift):
    # where a ray from the front (-Z) at (x, y) first meets the body; lifted off it along the facet's normal
    o = np.array([x, y, -5.0]); d = np.array([0.0, 0.0, 1.0])
    v0, v1, v2 = BODY[:, 0], BODY[:, 1], BODY[:, 2]
    e1, e2 = v1 - v0, v2 - v0
    h = np.cross(d, e2)
    a = np.einsum('ij,ij->i', e1, h)
    ok = np.abs(a) > 1e-9
    f = np.where(ok, 1 / np.where(ok, a, 1), 0)
    s = o - v0
    u = f * np.einsum('ij,ij->i', s, h)
    q = np.cross(s, e1)
    v = f * (q @ d)
    t = f * np.einsum('ij,ij->i', e2, q)
    hit = ok & (u >= -1e-6) & (v >= -1e-6) & (u + v <= 1 + 1e-6) & (t > 0)
    if not hit.any():
        raise ValueError(f'no hit at {x},{y}')
    t = np.where(hit, t, np.inf)
    k = int(np.argmin(t))
    n = np.cross(e1[k], e2[k]); n /= np.linalg.norm(n)
    if n[2] > 0:
        n = -n
    return o + d * t[k] + n * lift

def grow(poly, by):
    # push each corner out along its corner bisector by `by` (a simple offset for the carved rim)
    out = []
    pts = [np.array(p, float) for p in poly]
    sign = 1 if area(poly) > 0 else -1
    for i, p in enumerate(pts):
        a, b = pts[i - 1], pts[(i + 1) % len(pts)]
        e1 = (p - a) / np.linalg.norm(p - a); e2 = (b - p) / np.linalg.norm(b - p)
        n1 = np.array([e1[1], -e1[0]]) * sign; n2 = np.array([e2[1], -e2[0]]) * sign
        m = n1 + n2
        m = m / max(np.linalg.norm(m), 1e-6)
        cos = max(np.dot(m, n1), 0.35)
        out.append(tuple(p + m * by / cos))
    return out

def face_mesh(polys, lift, level):
    tris = []
    for poly in polys:
        for t in ear_clip(poly):
            for s in subdivide(t, level):
                tris.append(tuple(project(p[0], p[1], lift) for p in s))
    return outward(tris)

glow = face_mesh(SHAPES, 0.03, 3)
rim = face_mesh([grow(s, 0.055) for s in SHAPES], 0.016, 3)

# ---------------------------------------------------------------- stem
def stem_triangles():
    path = [np.array(p, float) for p in [(0, 0.50, 0), (0, 0.78, 0), (0.02, 0.98, 0), (0.10, 1.12, 0), (0.24, 1.20, 0), (0.34, 1.21, 0)]]
    radii = [0.17, 0.16, 0.145, 0.13, 0.115, 0.105]
    sides = 6
    rings = []
    for k, p in enumerate(path):
        t = path[min(k + 1, len(path) - 1)] - path[max(k - 1, 0)]
        t /= np.linalg.norm(t)
        side = np.cross(t, [0, 0, 1.0]); side /= np.linalg.norm(side)
        up = np.cross(side, t)
        rings.append([p + (side * math.cos(2 * math.pi * i / sides + 0.3) + up * math.sin(2 * math.pi * i / sides + 0.3)) * radii[k] for i in range(sides)])
    tris = []
    for k in range(len(rings) - 1):
        a, b = rings[k], rings[k + 1]
        for i in range(sides):
            i2 = (i + 1) % sides
            tris.append((a[i], a[i2], b[i2]))
            tris.append((a[i], b[i2], b[i]))
    tip = path[-1] + (path[-1] - path[-2]) / np.linalg.norm(path[-1] - path[-2]) * 0.03
    for i in range(sides):
        tris.append((rings[-1][i], rings[-1][(i + 1) % sides], tip))
    out = []
    for a, b, c in tris:  # outward from the stem's own axis
        cen = (a + b + c) / 3
        k = min(range(len(path)), key=lambda j: np.linalg.norm(path[j] - cen))
        n = np.cross(b - a, c - a)
        if np.dot(n, cen - path[k]) < 0:
            b, c = c, b
        out.append((a, b, c))
    return out

stem = stem_triangles()

# ---------------------------------------------------------------- GLB (flat shading: every triangle has its own vertices)
def write_glb(path, meshes):
    bin_ = bytearray(); views = []; accessors = []; gmeshes = []; nodes = []; materials = []
    def view(data, target):
        while len(bin_) % 4: bin_.append(0)
        off = len(bin_); bin_.extend(data)
        views.append({'buffer': 0, 'byteOffset': off, 'byteLength': len(data), 'target': target})
        return len(views) - 1
    for name, tris, color in meshes:
        pos, nrm, uv = [], [], []
        for a, b, c in tris:
            n = np.cross(b - a, c - a); n = n / max(np.linalg.norm(n), 1e-9)
            for p in (a, b, c):
                pos.append(p); nrm.append(n); uv.append((0.0, 0.0))
        pos = np.array(pos, np.float32); nrm = np.array(nrm, np.float32); uv = np.array(uv, np.float32)
        ind = np.arange(len(pos), dtype=np.uint32)
        acc = {}
        for key, arr, typ in (('POSITION', pos, 'VEC3'), ('NORMAL', nrm, 'VEC3'), ('TEXCOORD_0', uv, 'VEC2')):
            a = {'bufferView': view(arr.tobytes(), 34962), 'componentType': 5126, 'count': len(arr), 'type': typ}
            if key == 'POSITION':
                a['min'] = pos.min(0).tolist(); a['max'] = pos.max(0).tolist()
            accessors.append(a); acc[key] = len(accessors) - 1
        accessors.append({'bufferView': view(ind.tobytes(), 34963), 'componentType': 5125, 'count': len(ind), 'type': 'SCALAR'})
        materials.append({'name': name, 'pbrMetallicRoughness': {'baseColorFactor': [c / 255 for c in color] + [1], 'metallicFactor': 0, 'roughnessFactor': 0.9}})
        gmeshes.append({'name': name, 'primitives': [{'attributes': acc, 'indices': len(accessors) - 1, 'material': len(materials) - 1}]})
        nodes.append({'name': name, 'mesh': len(gmeshes) - 1})
    while len(bin_) % 4: bin_.append(0)
    gltf = {'asset': {'version': '2.0', 'generator': 'HOS-LOBBY-005 jack-o-lantern'}, 'scene': 0,
            'scenes': [{'name': 'JackOLantern', 'nodes': list(range(len(nodes)))}], 'nodes': nodes, 'meshes': gmeshes,
            'materials': materials, 'accessors': accessors, 'bufferViews': views, 'buffers': [{'byteLength': len(bin_)}]}
    j = json.dumps(gltf, separators=(',', ':')).encode()
    while len(j) % 4: j += b' '
    out = struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(j) + 8 + len(bin_)) + struct.pack('<II', len(j), 0x4E4F534A) + j + struct.pack('<II', len(bin_), 0x004E4942) + bytes(bin_)
    open(path, 'wb').write(out)

if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else 'JackOLantern.glb'
    meshes = [('JackBody', body, (214, 102, 38)), ('JackRim', rim, (120, 44, 12)), ('JackGlow', glow, (255, 196, 70)), ('JackStem', stem, (92, 98, 44))]
    write_glb(out, meshes)
    for name, tris, _ in meshes:
        pts = np.array([p for t in tris for p in t])
        print(name, len(tris), 'triangles, bbox', np.round(pts.min(0), 2).tolist(), np.round(pts.max(0), 2).tolist())
