# ===================== PETKIT: shared, pure python + numpy (also runs inside Blender) =====================
# Procedural low-poly Roblox pets. Conventions:
#   1 unit = 1 stud. The pet faces -Y, up is +Z, its LEFT side is +X (".L" bones), feet/ground at z = 0.
#   Materials (MB.MAT ids): 0 = body (atlas + SurfaceAppearance), 1 = eyes/face (own swappable texture),
#   2 = level-2 extras (body atlas), 3 = level-3 extras (body atlas). Each id becomes one MeshPart.
#   Poses: {bone: (R 3x3 in rest-relative WORLD axes about the bone head, t world translation)}.
import math
import numpy as np


# ---------------------------------------------------------------- math
def V(*a):
    return np.array(a, dtype=float)


def nrm(v):
    n = np.linalg.norm(v)
    return v / n if n > 1e-12 else v


def rot(axis, deg):
    """3x3 rotation about a WORLD axis ('x','y','z' or vector) by degrees."""
    if isinstance(axis, str):
        axis = {'x': V(1, 0, 0), 'y': V(0, 1, 0), 'z': V(0, 0, 1)}[axis]
    a = nrm(np.asarray(axis, float))
    t = math.radians(deg)
    c, s = math.cos(t), math.sin(t)
    x, y, z = a
    C = 1 - c
    return np.array([[c + x * x * C, x * y * C - z * s, x * z * C + y * s],
                     [y * x * C + z * s, c + y * y * C, y * z * C - x * s],
                     [z * x * C - y * s, z * y * C + x * s, c + z * z * C]])


def chain(*mats):
    """chain(A, B, C) = apply A first, then B, then C."""
    M = np.eye(3)
    for m in mats:
        M = m @ M
    return M


def lerp(a, b, t):
    return a + (b - a) * t


def smooth(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * (3 - 2 * t)


# ---------------------------------------------------------------- atlas UVs
class Atlas:
    """regions in IMAGE pixels (x0, y0 from the TOP-left, w, h). uv(name, a, b): a across, b DOWN."""

    def __init__(self, regions, size=1024, pad=4):
        self.R, self.N, self.pad = regions, size, pad

    def uv(self, name, a, b):
        x0, y0, w, h = self.R[name]
        p = self.pad
        x = x0 + p + min(max(a, 0.0), 1.0) * (w - 2 * p)
        y = y0 + p + min(max(b, 0.0), 1.0) * (h - 2 * p)
        return (x / self.N, 1.0 - y / self.N)

    def px(self, name):
        """(y0, y1, x0, x1) slice bounds in the image (row 0 = top)."""
        x0, y0, w, h = self.R[name]
        return y0, y0 + h, x0, x0 + w


# ---------------------------------------------------------------- mesh builder
class MB:
    def __init__(self):
        self.V, self.W, self.F, self.UV, self.MAT, self.PART = [], [], [], [], [], []
        self.mat = 0                      # default material for new faces

    def vert(self, p, w):
        self.V.append(np.asarray(p, float))
        if isinstance(w, str):
            w = {w: 1.0}
        s = sum(w.values())
        w = {k: v / s for k, v in w.items() if v / s > 1e-4}
        if len(w) > 4:                    # Roblox skinning: at most 4 influences
            top = sorted(w.items(), key=lambda kv: -kv[1])[:4]
            s = sum(v for _, v in top)
            w = {k: v / s for k, v in top}
        self.W.append(w)
        return len(self.V) - 1

    def face(self, idx, uvs, inside=None, mat=None, part=''):
        idx = list(idx)
        uvs = list(uvs)
        if inside is not None:
            P = [self.V[i] for i in idx]
            n = np.zeros(3)
            for i in range(len(P)):
                a, b = P[i], P[(i + 1) % len(P)]
                n += np.cross(a, b)
            c = sum(P) / len(P)
            if np.dot(n, c - np.asarray(inside, float)) < 0:
                idx.reverse()
                uvs.reverse()
        self.F.append(idx)
        self.UV.append(uvs)
        self.MAT.append(self.mat if mat is None else mat)
        self.PART.append(part)

    def tri_count(self, mat=None):
        return sum(len(f) - 2 for f, m in zip(self.F, self.MAT) if mat is None or m == mat)

    def report(self):
        from collections import Counter
        c = Counter()
        for f, p in zip(self.F, self.PART):
            c[p] += len(f) - 2
        mats = {m: self.tri_count(m) for m in sorted(set(self.MAT))}
        return {'total': self.tri_count(), 'by_mat': mats, 'by_part': dict(c)}

    def open_edges(self, mat=None):
        """edges used by only one face (holes / unclosed shells), per part."""
        from collections import Counter, defaultdict
        cnt = Counter()
        owner = {}
        for f, m, p in zip(self.F, self.MAT, self.PART):
            if mat is not None and m != mat:
                continue
            for i in range(len(f)):
                e = tuple(sorted((f[i], f[(i + 1) % len(f)])))
                cnt[e] += 1
                owner[e] = p
        out = defaultdict(int)
        for e, n in cnt.items():
            if n == 1:
                out[owner[e]] += 1
        return dict(out)


def blendw(stations_w, t):
    """stations_w: list of (t, {bone:w}); piecewise-linear blend at t."""
    if t <= stations_w[0][0]:
        return dict(stations_w[0][1])
    for (t0, w0), (t1, w1) in zip(stations_w, stations_w[1:]):
        if t <= t1:
            f = (t - t0) / max(t1 - t0, 1e-9)
            out = {}
            for k in set(w0) | set(w1):
                out[k] = w0.get(k, 0) * (1 - f) + w1.get(k, 0) * f
            return out
    return dict(stations_w[-1][1])


def loft(mb, centers, radii, n, weights, uvf, part, start='point', end='open',
         profile=None, up_hint=V(0, 0, 1), start_pt=None, end_pt=None, side_hint=None):
    """Tube through `centers`. radii: list of (a, b) half-widths (a along the ring's x, b along its up).
    weights: dict per station. profile(k, n, a, b, i) -> (x, z) ring offsets.
    uvf(i, k, seg, fk) -> (u, v)  (i station, k ring index possibly fractional, seg segment, fk face ring index).
    start/end: 'open' | 'point' (cone cap to start_pt/end_pt or the station centre) | 'flat' (fan cap)."""
    m = len(centers)
    C = [np.asarray(c, float) for c in centers]
    T = []
    for i in range(m):
        if i == 0:
            t = C[1] - C[0]
        elif i == m - 1:
            t = C[-1] - C[-2]
        else:
            t = C[i + 1] - C[i - 1]
        T.append(nrm(t))
    rings = []
    for i in range(m):
        ex = V(1, 0, 0) if side_hint is None else nrm(np.asarray(side_hint[i] if isinstance(side_hint, list) else side_hint, float))
        ex = nrm(ex - np.dot(ex, T[i]) * T[i])
        if np.linalg.norm(ex) < 1e-6:
            ex = nrm(np.cross(T[i], V(0, 0, 1)))
        ez = nrm(np.cross(T[i], ex))
        if np.dot(ez, up_hint) < 0 and abs(np.dot(T[i], up_hint)) < 0.7:
            ez = -ez
            ex = -ex
        a, b = radii[i]
        ring = []
        for k in range(n):
            if profile is not None:
                x, z = profile(k, n, a, b, i)
            else:
                th = math.pi / 2 + 2 * math.pi * k / n
                x, z = a * math.cos(th), b * math.sin(th)
            ring.append(mb.vert(C[i] + ex * x + ez * z, weights[i]))
        rings.append(ring)
    for i in range(m - 1):
        inside = (C[i] + C[i + 1]) / 2
        for k in range(n):
            k2 = (k + 1) % n
            q = [rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]]
            uv = [uvf(i, k, i, k), uvf(i, k + 1, i, k), uvf(i + 1, k + 1, i, k), uvf(i + 1, k, i, k)]
            mb.face(q[:3], uv[:3], inside, part=part)
            mb.face([q[0], q[2], q[3]], [uv[0], uv[2], uv[3]], inside, part=part)
    for which, mode, pt in ((0, start, start_pt), (m - 1, end, end_pt)):
        if mode == 'open':
            continue
        ring = rings[which]
        other = C[1] if which == 0 else C[-2]
        seg = 0 if which == 0 else m - 2
        if mode == 'point':
            p = np.asarray(pt, float) if pt is not None else C[which]
            ci = mb.vert(p, weights[which])
            for k in range(n):
                k2 = (k + 1) % n
                mb.face([ring[k], ring[k2], ci], [uvf(which, k, seg, k), uvf(which, k + 1, seg, k), uvf(which, k + 0.5, seg, k)],
                        inside=other, part=part)
        elif mode == 'flat':
            for k in range(1, n - 1):
                mb.face([ring[0], ring[k], ring[k + 1]], [uvf(which, 0, seg, 0), uvf(which, k, seg, k), uvf(which, k + 1, seg, k)],
                        inside=other, part=part)
    return rings


def slab(mb, LE, TE, th, wLE, wTE, uLE, uTE, part, up=V(0, 0, 1), ridge_at=0.30, close_end=True,
         close_start=False, uR=None, wR=None, top_frac=0.62):
    """A thick blade/wing slab: per station a leading-edge point, a trailing-edge point and a thickness."""
    n = len(LE)
    if uR is None:
        uR = uLE
    ups = up if isinstance(up, list) else [up] * n
    iL, iT, iB, iE = [], [], [], []
    for i in range(n):
        r = LE[i] + (TE[i] - LE[i]) * ridge_at
        iL.append(mb.vert(LE[i], wLE[i]))
        wr = wR[i] if wR is not None else wLE[i]
        iT.append(mb.vert(r + ups[i] * th[i] * top_frac, wr))
        iB.append(mb.vert(r - ups[i] * th[i] * (1 - top_frac), wr))
        iE.append(mb.vert(TE[i], wTE[i]))
    for i in range(n - 1):
        mid = (LE[i] + LE[i + 1] + TE[i] + TE[i + 1]) / 4
        upm = nrm(ups[i] + ups[i + 1])
        for R, sgn in ((iT, 1), (iB, -1)):
            inside = mid - upm * 0.5 * sgn
            mb.face([iL[i], iL[i + 1], R[i + 1]], [uLE[i], uLE[i + 1], uR[i + 1]], inside, part=part)
            mb.face([iL[i], R[i + 1], R[i]], [uLE[i], uR[i + 1], uR[i]], inside, part=part)
            mb.face([R[i], R[i + 1], iE[i + 1]], [uR[i], uR[i + 1], uTE[i + 1]], inside, part=part)
            mb.face([R[i], iE[i + 1], iE[i]], [uR[i], uTE[i + 1], uTE[i]], inside, part=part)
    if close_end:
        j = n - 1
        mb.face([iL[j], iT[j], iE[j]], [uLE[j], uR[j], uTE[j]], (LE[j - 1] + TE[j - 1]) / 2, part=part)
        mb.face([iL[j], iE[j], iB[j]], [uLE[j], uTE[j], uR[j]], (LE[j - 1] + TE[j - 1]) / 2, part=part)
    if close_start:
        mb.face([iL[0], iT[0], iE[0]], [uLE[0], uR[0], uTE[0]], (LE[1] + TE[1]) / 2, part=part)
        mb.face([iL[0], iE[0], iB[0]], [uLE[0], uTE[0], uR[0]], (LE[1] + TE[1]) / 2, part=part)
    return iL, iT, iB, iE


def bipyramid(mb, base, tip, side, up, width, height, w, uvb, uvt, part, wide_at=0.5, ridge_at=0.45, curl=0.0):
    """Flattened 6-vertex crystal/spike/feather (8 tris), closed."""
    base, tip = np.asarray(base, float), np.asarray(tip, float)
    d = tip - base
    L = np.linalg.norm(d)
    d = d / L
    s = nrm(side - np.dot(side, d) * d)
    u = nrm(np.cross(s, d))
    if np.dot(u, up) < 0:
        u, s = -u, -s
    tipc = tip + u * curl * L
    pl = base + d * L * wide_at + s * width / 2
    pr = base + d * L * wide_at - s * width / 2
    pu = base + d * L * ridge_at + u * height / 2 + u * curl * L * 0.4
    pd = base + d * L * ridge_at - u * height / 2 + u * curl * L * 0.4
    ws = w if isinstance(w, list) else [w] * 6
    ib = mb.vert(base, ws[0]); it = mb.vert(tipc, ws[1]); il = mb.vert(pl, ws[2])
    ir = mb.vert(pr, ws[3]); iu = mb.vert(pu, ws[4]); idn = mb.vert(pd, ws[5])
    um = (uvb[0] * 0.4 + uvt[0] * 0.6, uvb[1] * 0.4 + uvt[1] * 0.6)
    center = base + d * L * 0.5
    for top in (iu, idn):
        mb.face([ib, il, top], [uvb, um, um], center, part=part)
        mb.face([il, it, top], [um, uvt, um], center, part=part)
        mb.face([it, ir, top], [uvt, um, um], center, part=part)
        mb.face([ir, ib, top], [um, uvb, um], center, part=part)
    return [ib, it, il, ir, iu, idn]


def raycast(origin, direction, tris):
    """tris: (N,3,3). Nearest hit distance along direction (or None)."""
    o = np.asarray(origin, float)
    dvec = nrm(np.asarray(direction, float))
    v0, v1, v2 = tris[:, 0], tris[:, 1], tris[:, 2]
    e1, e2 = v1 - v0, v2 - v0
    p = np.cross(dvec, e2)
    det = np.einsum('ij,ij->i', e1, p)
    ok = np.abs(det) > 1e-12
    inv = np.where(ok, 1.0 / np.where(ok, det, 1), 0)
    tv = o - v0
    uu = np.einsum('ij,ij->i', tv, p) * inv
    q = np.cross(tv, e1)
    vv = np.einsum('j,ij->i', dvec, q) * inv
    t = np.einsum('ij,ij->i', e2, q) * inv
    hit = ok & (uu >= 0) & (vv >= 0) & (uu + vv <= 1) & (t > 0)
    if not hit.any():
        return None
    return float(t[hit].min())


def tris_of(mb, parts=None):
    out = []
    for f, p in zip(mb.F, mb.PART):
        if parts is not None and p not in parts:
            continue
        for t in range(1, len(f) - 1):
            out.append([mb.V[f[0]], mb.V[f[t]], mb.V[f[t + 1]]])
    return np.array(out)


def nearest_weights(mb, p, parts, k=3):
    """inverse-distance blend of the k nearest vertices' weights from the given parts (skin-attached pieces)."""
    idx = sorted({v for f, pp in zip(mb.F, mb.PART) if pp in parts for v in f})
    P = np.array([mb.V[i] for i in idx])
    d = np.linalg.norm(P - np.asarray(p, float), axis=1)
    order = np.argsort(d)[:k]
    acc = {}
    tot = 0
    for o in order:
        wv = 1.0 / max(d[o], 1e-3)
        tot += wv
        for b, w in mb.W[idx[o]].items():
            acc[b] = acc.get(b, 0) + w * wv
    return {b: w / tot for b, w in acc.items()}


# ---------------------------------------------------------------- textures (row 0 = TOP)
def hx(h):
    return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)], dtype=np.float32)


def grad(t, stops):
    t = np.clip(t, 0, 1)
    out = np.zeros(np.shape(t) + (3,), np.float32)
    for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
        m = (t >= t0) & (t <= t1)
        f = ((t - t0) / max(t1 - t0, 1e-6))[..., None]
        out = np.where(m[..., None], hx(c0) * (1 - f) + hx(c1) * f, out)
    return out


def ss(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def vnoise(h, w, cells, seed):
    """smooth value noise in [0,1]."""
    rng = np.random.default_rng(seed)
    cy, cx = max(1, int(cells * h / max(h, w))), max(1, int(cells * w / max(h, w)))
    g = rng.random((cy + 2, cx + 2)).astype(np.float32)
    y = np.linspace(0, cy, h, endpoint=False, dtype=np.float32)
    x = np.linspace(0, cx, w, endpoint=False, dtype=np.float32)
    y0 = np.floor(y).astype(int); x0 = np.floor(x).astype(int)
    fy = (y - y0)[:, None]; fx = (x - x0)[None, :]
    fy = fy * fy * (3 - 2 * fy); fx = fx * fx * (3 - 2 * fx)
    a = g[y0][:, x0]; b = g[y0][:, x0 + 1]; c = g[y0 + 1][:, x0]; d = g[y0 + 1][:, x0 + 1]
    return a * (1 - fx) * (1 - fy) + b * fx * (1 - fy) + c * (1 - fx) * fy + d * fx * fy


def grit(h, w, seed):
    """multi-octave grain in [-0.5, 0.5]."""
    return (0.45 * vnoise(h, w, 10, seed) + 0.33 * vnoise(h, w, 40, seed + 1) +
            0.22 * vnoise(h, w, 160, seed + 2)) - 0.5


def normal_from_height(hgt, strength=3.0):
    """tangent-space (OpenGL, +Y up) normal map from a height map whose row 0 is the TOP."""
    H = hgt[::-1]
    dy, dx = np.gradient(H)
    n = np.stack([-dx * strength, -dy * strength, np.ones_like(H)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return (n * 0.5 + 0.5)[::-1].astype(np.float32)


def coords(size):
    """x, y in -1..1 (x right, y UP) for a square texture, row 0 = top."""
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float32)
    return (xs + 0.5) / size * 2 - 1, 1 - (ys + 0.5) / size * 2


def save_png(path, arr):
    from PIL import Image
    a = np.clip(arr, 0, 1)
    if a.ndim == 2:
        a = np.repeat(a[..., None], 3, -1)
    mode = 'RGBA' if a.shape[2] == 4 else 'RGB'
    Image.fromarray((a * 255 + 0.5).astype(np.uint8), mode).save(path)


# ---------------------------------------------------------------- poses / FK / skinning
def P(*rots, loc=(0, 0, 0)):
    return (chain(*[rot(a, d) for a, d in rots]) if rots else np.eye(3), V(*loc))


def mirror_pose(p):
    """Mirror a left-side (rotation, loc) to the right side (reflect through X)."""
    R, t = p
    S = np.diag([-1.0, 1.0, 1.0])
    return (S @ R @ S, V(-t[0], t[1], t[2]))


def sym(d):
    """{'X.L': pose} -> also adds the mirrored 'X.R'."""
    out = dict(d)
    for k, v in d.items():
        if k.endswith('.L'):
            out[k[:-2] + '.R'] = mirror_pose(v)
    return out


def merge(*ds):
    out = {}
    for d in ds:
        out.update(d)
    return out


def pose_mats(bones, pose):
    """bones: [(name, head, tail, parent)], pose: {bone: (R, t)} -> {bone: 4x4 deform}."""
    G = {}
    for name, head, tail, parent in bones:
        R, t = pose.get(name, (np.eye(3), V(0, 0, 0)))
        A = np.eye(4); A[:3, 3] = np.asarray(head, float) + t
        Rm = np.eye(4); Rm[:3, :3] = R
        Bm = np.eye(4); Bm[:3, 3] = -np.asarray(head, float)
        L = A @ Rm @ Bm
        G[name] = (G[parent] @ L) if parent else L
    return G


def skin(mb, bones, pose):
    G = pose_mats(bones, pose)
    out = np.zeros((len(mb.V), 3))
    for i, (p, w) in enumerate(zip(mb.V, mb.W)):
        ph = np.append(p, 1)
        acc = np.zeros(3)
        for b, wt in w.items():
            acc += wt * (G[b] @ ph)[:3]
        out[i] = acc
    return out


def interp_pose(anim, f):
    keys = anim['keys']
    ks = sorted(keys)
    if anim.get('loop'):
        f = f % anim['frames']
    if f <= ks[0]:
        return keys[ks[0]]
    for a, b in zip(ks, ks[1:]):
        if f <= b:
            t = (f - a) / (b - a)
            t = t * t * (3 - 2 * t)
            out = {}
            for bone in set(keys[a]) | set(keys[b]):
                Ra, ta = keys[a].get(bone, (np.eye(3), V(0, 0, 0)))
                Rb, tb = keys[b].get(bone, (np.eye(3), V(0, 0, 0)))
                M = Ra * (1 - t) + Rb * t
                U, _, Vt = np.linalg.svd(M)
                out[bone] = (U @ Vt, ta * (1 - t) + tb * t)
            return out
    return keys[ks[-1]]


# ---------------------------------------------------------------- preview (textured software rasterizer)
def _sample(img, uv):
    H, W = img.shape[:2]
    x = np.clip((uv[..., 0] % 1.0) * W, 0, W - 1).astype(int)
    y = np.clip((1 - (uv[..., 1] % 1.0)) * H, 0, H - 1).astype(int)
    return img[y, x, :3]


def render(mb, verts, textures, yaw, pitch, size=520, scale=None, center=None, bg=(200, 214, 230),
           mats=None, light=(-0.4, -0.7, 0.8), outline=True):
    """textures: {mat_id: (H,W,3|4) float image, row 0 = top}. mats: set of mat ids to draw (None = all)."""
    from PIL import Image
    Vv = np.asarray(verts)
    cy, sy = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    cp, sp = math.cos(math.radians(pitch)), math.sin(math.radians(pitch))
    Rz = np.array([[cy, -sy, 0], [sy, cy, 0], [0, 0, 1]])
    Rx = np.array([[1, 0, 0], [0, cp, -sp], [0, sp, cp]])
    R = Rx @ Rz
    if center is None:
        center = (Vv.min(0) + Vv.max(0)) / 2
    Pp = (Vv - center) @ R.T
    if scale is None:
        ext = max(np.ptp(Pp[:, 0]), np.ptp(Pp[:, 2]))
        scale = size * 0.85 / ext
    sx = size / 2 + Pp[:, 0] * scale
    syy = size / 2 - Pp[:, 2] * scale
    depth = Pp[:, 1]
    img = np.zeros((size, size, 3)); img[:] = np.array(bg) / 255
    zb = np.full((size, size), np.inf)
    lv = nrm(np.array(light)) @ R.T
    for f, uvs, m in zip(mb.F, mb.UV, mb.MAT):
        if mats is not None and m not in mats:
            continue
        tex = textures.get(m)
        for t in range(1, len(f) - 1):
            ids = [f[0], f[t], f[t + 1]]
            uv3 = np.array([uvs[0], uvs[t], uvs[t + 1]], float)
            p3 = Pp[ids]
            n = np.cross(p3[1] - p3[0], p3[2] - p3[0])
            nn = np.linalg.norm(n)
            if nn < 1e-12:
                continue
            n /= nn
            if n[1] > 0:
                continue
            lam = max(0.0, np.dot(n, -lv))
            rim = max(0.0, 1 - abs(n[1])) ** 3 * 0.18
            xs, ys, zs = sx[ids], syy[ids], depth[ids]
            x0, x1 = int(max(0, math.floor(xs.min()))), int(min(size - 1, math.ceil(xs.max())))
            y0, y1 = int(max(0, math.floor(ys.min()))), int(min(size - 1, math.ceil(ys.max())))
            if x1 < x0 or y1 < y0:
                continue
            gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
            d = (ys[1] - ys[2]) * (xs[0] - xs[2]) + (xs[2] - xs[1]) * (ys[0] - ys[2])
            if abs(d) < 1e-9:
                continue
            w0 = ((ys[1] - ys[2]) * (gx - xs[2]) + (xs[2] - xs[1]) * (gy - ys[2])) / d
            w1 = ((ys[2] - ys[0]) * (gx - xs[2]) + (xs[0] - xs[2]) * (gy - ys[2])) / d
            w2 = 1 - w0 - w1
            inside = (w0 >= -1e-6) & (w1 >= -1e-6) & (w2 >= -1e-6)
            z = w0 * zs[0] + w1 * zs[1] + w2 * zs[2]
            sub = zb[y0:y1 + 1, x0:x1 + 1]
            upd = inside & (z < sub)
            if not upd.any():
                continue
            sub[upd] = z[upd]
            if tex is not None:
                uvp = (w0[..., None] * uv3[0] + w1[..., None] * uv3[1] + w2[..., None] * uv3[2])[upd]
                col = _sample(tex, uvp)
            else:
                col = np.full((upd.sum(), 3), 0.7)
            shade = col * (0.42 + 0.78 * lam) + rim
            img[y0:y1 + 1, x0:x1 + 1][upd] = np.clip(shade, 0, 1)
    if outline:
        zf = np.where(np.isinf(zb), 1e3, zb)
        edge = np.zeros_like(zf, bool)
        edge[1:, :] |= np.abs(zf[1:, :] - zf[:-1, :]) > 0.12
        edge[:, 1:] |= np.abs(zf[:, 1:] - zf[:, :-1]) > 0.12
        img[edge] = img[edge] * 0.35
    return Image.fromarray((img * 255).astype(np.uint8))


def sheet(images, cols, labels=None):
    from PIL import Image, ImageDraw
    w, h = images[0].size
    rows = (len(images) + cols - 1) // cols
    out = Image.new('RGB', (w * cols, h * rows), (255, 255, 255))
    d = ImageDraw.Draw(out)
    for i, im in enumerate(images):
        out.paste(im, ((i % cols) * w, (i // cols) * h))
        if labels:
            d.text(((i % cols) * w + 8, (i // cols) * h + 6), labels[i], fill=(0, 0, 0))
    return out


VIEWS = [(-35, 12, '3/4 front'), (-90, 5, 'side (left)'), (0, 5, 'front'), (35, 15, '3/4 front R'),
         (-150, 15, '3/4 back'), (-90, 80, 'top')]


def turnaround(mb, verts, textures, path, mats=None, size=420, views=VIEWS):
    Vv = np.asarray(verts)
    ctr = (Vv.min(0) + Vv.max(0)) / 2
    ext = np.ptp(Vv, axis=0).max()
    imgs = [render(mb, Vv, textures, y, p, size=size, scale=size * 0.8 / ext, center=ctr, mats=mats) for y, p, _ in views]
    sheet(imgs, 3, [v[2] for v in views]).save(path)
    return path
