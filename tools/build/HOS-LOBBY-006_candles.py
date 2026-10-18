"""HOS-LOBBY-006 (18 Oct 2026, Matthew): low-poly candles for the Halloween lobby, to replace the block ones.

Writes one GLB with five nodes, laid out side by side (the adopt script, HOS-LOBBY-006_candles.lua, assembles them):
  CandleWaxLarge, CandleWaxMedium, CandleWaxSmall   an 8-sided wax stick, a lumpy melted lip with a dished pool on top,
                                                     and a few drips running down the sides (seeded, so the same every run)
  CandleFlame                                        a faceted teardrop flame
  CandleWick                                         a short hexagonal wick
Flat shaded (every triangle has its own normal), like the jack-o'-lantern (HOS-LOBBY-005).

Run: python3 tools/build/HOS-LOBBY-006_candles.py docs/HOS-LOBBY-006/Candles.glb
"""
import json
import math
import random
import struct
import sys

import numpy as np

N = 8  # sides
SIZES = {  # name: (radius, body height)
    'CandleWaxLarge': (0.39, 2.0),
    'CandleWaxMedium': (0.37, 1.35),
    'CandleWaxSmall': (0.34, 0.62),
}


def v(x, y, z):
    return np.array([x, y, z], dtype=float)


def facing(tri, out):
    """the triangle wound so its normal points along `out`"""
    a, b, c = tri
    n = np.cross(b - a, c - a)
    return (a, b, c) if np.dot(n, out) >= 0 else (a, c, b)


def ring(y, r, jitter=None, phase=0.0):
    pts = []
    for i in range(N):
        a = 2 * math.pi * i / N + phase
        rr = r * (1 + (jitter[i] if jitter else 0))
        pts.append(v(rr * math.cos(a), y, rr * math.sin(a)))
    return pts


def wax(r, h, rng):
    tris = []
    lip_y = [h + rng.uniform(-0.035, 0.035) for _ in range(N)]
    lip = [v(p[0], lip_y[i], p[2]) for i, p in enumerate(ring(0, r * 1.05, [rng.uniform(-0.02, 0.03) for _ in range(N)]))]
    under = ring(h - 0.14, r)
    bottom = ring(0, r)
    inner = [v(p[0], min(lip_y) - 0.03, p[2]) for p in ring(0, r * 0.74)]
    pool = v(0, min(lip_y) - 0.08, 0)

    def side(a, b, c, d):  # quad a-b (lower), d-c (upper), facing out from the axis
        mid = (a + b + c + d) / 4
        out = v(mid[0], 0, mid[2])
        tris.append(facing((a, b, c), out))
        tris.append(facing((a, c, d), out))

    for i in range(N):
        j = (i + 1) % N
        side(bottom[i], bottom[j], under[j], under[i])
        side(under[i], under[j], lip[j], lip[i])
        # lip -> pool rim (faces up), pool rim -> pool centre (faces up)
        tris.append(facing((lip[i], lip[j], inner[j]), v(0, 1, 0)))
        tris.append(facing((lip[i], inner[j], inner[i]), v(0, 1, 0)))
        tris.append(facing((inner[i], inner[j], pool), v(0, 1, 0)))
        tris.append(facing((bottom[i], bottom[j], v(0, 0, 0)), v(0, -1, 0)))

    # drips: flat tongues of wax on some of the facets, from under the lip down, rounded at the end
    apothem = r * math.cos(math.pi / N)
    for i in rng.sample(range(N), 4 if h > 1 else 3):
        a = 2 * math.pi * (i + 0.5) / N  # middle of facet i
        n = v(math.cos(a), 0, math.sin(a))
        u = v(-math.sin(a), 0, math.cos(a))
        off = rng.uniform(-0.25, 0.25) * r * math.sin(math.pi / N)
        w = rng.uniform(0.14, 0.2)
        length = rng.uniform(0.22, 0.55) * min(h, 1.4)
        top = h - 0.02
        outline = [(-w / 2, top), (-w / 2, top - length + w / 2)]
        for k in range(1, 4):  # rounded end
            t = math.pi + math.pi * k / 4
            outline.append((math.cos(t) * w / 2, top - length + w / 2 + math.sin(t) * w / 2))
        outline += [(w / 2, top - length + w / 2), (w / 2, top)]
        base = [n * (apothem - 0.01) + u * (off + x) + v(0, y, 0) for x, y in outline]
        front = [n * (apothem + 0.055) + u * (off + x) + v(0, y, 0) for x, y in outline]
        centre = sum(front) / len(front)
        for k in range(1, len(front) - 1):
            tris.append(facing((front[0], front[k], front[k + 1]), n))
        for k in range(len(front) - 1):
            mid = (base[k] + base[k + 1] + front[k] + front[k + 1]) / 4
            out = mid - (centre - n * 0.02)
            tris.append(facing((base[k], base[k + 1], front[k + 1]), out))
            tris.append(facing((base[k], front[k + 1], front[k]), out))
        tris.append(facing((base[-1], front[-1], front[0]), v(0, 1, 0)))
        tris.append(facing((base[-1], front[0], base[0]), v(0, 1, 0)))
    return tris


def lathe(profile, sides, phase=0.0):
    """a faceted solid of revolution from (y, radius) pairs, bottom to top; radius 0 makes a point"""
    tris = []
    rings = []
    for y, r in profile:
        rings.append([v(r * math.cos(2 * math.pi * i / sides + phase), y, r * math.sin(2 * math.pi * i / sides + phase)) for i in range(sides)])
    for k in range(len(rings) - 1):
        lo, hi = rings[k], rings[k + 1]
        for i in range(sides):
            j = (i + 1) % sides
            mid = (lo[i] + lo[j] + hi[i] + hi[j]) / 4
            out = v(mid[0], 0, mid[2])
            if profile[k][1] > 0:
                tris.append(facing((lo[i], lo[j], hi[j]), out))
            if profile[k + 1][1] > 0:
                tris.append(facing((lo[i], hi[j], hi[i]), out))
    if profile[0][1] > 0:
        c = v(0, profile[0][0], 0)
        for i in range(sides):
            tris.append(facing((rings[0][i], rings[0][(i + 1) % sides], c), v(0, -1, 0)))
    if profile[-1][1] > 0:
        c = v(0, profile[-1][0], 0)
        for i in range(sides):
            tris.append(facing((rings[-1][i], rings[-1][(i + 1) % sides], c), v(0, 1, 0)))
    return tris


FLAME = lathe([(0.0, 0.0), (0.06, 0.085), (0.17, 0.125), (0.3, 0.1), (0.44, 0.05), (0.58, 0.0)], 6)
WICK = lathe([(0.0, 0.035), (0.16, 0.03)], 6)


def write_glb(path, meshes):
    bin_ = bytearray(); views = []; accessors = []; gmeshes = []; nodes = []; materials = []

    def view(data, target):
        while len(bin_) % 4: bin_.append(0)
        off = len(bin_); bin_.extend(data)
        views.append({'buffer': 0, 'byteOffset': off, 'byteLength': len(data), 'target': target})
        return len(views) - 1
    for name, tris, color, at in meshes:
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
        nodes.append({'name': name, 'mesh': len(gmeshes) - 1, 'translation': list(at)})
    while len(bin_) % 4: bin_.append(0)
    gltf = {'asset': {'version': '2.0', 'generator': 'HOS-LOBBY-006 candles'}, 'scene': 0,
            'scenes': [{'name': 'Candles', 'nodes': list(range(len(nodes)))}], 'nodes': nodes, 'meshes': gmeshes,
            'materials': materials, 'accessors': accessors, 'bufferViews': views, 'buffers': [{'byteLength': len(bin_)}]}
    j = json.dumps(gltf, separators=(',', ':')).encode()
    while len(j) % 4: j += b' '
    out = struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(j) + 8 + len(bin_)) + struct.pack('<II', len(j), 0x4E4F534A) + j + struct.pack('<II', len(bin_), 0x004E4942) + bytes(bin_)
    open(path, 'wb').write(out)


rng = random.Random(1006)
WAX = {name: wax(r, h, rng) for name, (r, h) in SIZES.items()}
CREAM, FLAME_COL, WICK_COL = (247, 210, 160), (255, 232, 170), (40, 30, 25)

if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else 'Candles.glb'
    meshes = [(name, tris, CREAM, (i * 1.2, 0, 0)) for i, (name, tris) in enumerate(WAX.items())]
    meshes += [('CandleFlame', FLAME, FLAME_COL, (3.6, 0, 0)), ('CandleWick', WICK, WICK_COL, (4.2, 0, 0))]
    write_glb(out, meshes)
    for name, tris, _, _ in meshes:
        pts = np.array([p for t in tris for p in t])
        print(name, len(tris), 'triangles, bbox', np.round(pts.min(0), 3).tolist(), np.round(pts.max(0), 3).tolist())
