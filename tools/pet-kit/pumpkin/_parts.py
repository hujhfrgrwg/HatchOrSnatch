#@helpers
def _cum(centers):
    c = [np.asarray(p, float) for p in centers]
    d = [0.0]
    for a, b in zip(c, c[1:]):
        d.append(d[-1] + float(np.linalg.norm(b - a)))
    return [x / max(d[-1], 1e-9) for x in d]


def tube(mb, region, centers, radii, n, weights, part, start='point', end='point', start_pt=None, end_pt=None,
         side_hint=None, anti=True, th0=-math.pi / 2, lobes=0, lobe_amp=0.0):
    vv = _cum(centers)

    def profile(k, nn, a, b, i):
        th = th0 + 2 * math.pi * (k + (0.5 if (anti and i % 2) else 0.0)) / nn
        r = 1.0 + (lobe_amp * math.cos(lobes * (th - th0)) if lobes else 0.0)
        return a * r * math.cos(th), b * r * math.sin(th)

    def uvf(i, k, seg, fk):
        return ATLAS.uv(region, k / n, vv[i])
    return loft(mb, centers, radii, n, weights, uvf, part, start=start, end=end, profile=profile,
                start_pt=start_pt, end_pt=end_pt, side_hint=side_hint)


def torus(mb, region, c, normal, R, r, n_around, n_tube, w, part):
    normal = nrm(np.asarray(normal, float))
    a = nrm(np.cross(normal, V(0, 0, 1) if abs(normal[2]) < 0.9 else V(1, 0, 0)))
    b = np.cross(normal, a)
    cen = [np.asarray(c, float) + (a * math.cos(2 * math.pi * i / n_around) + b * math.sin(2 * math.pi * i / n_around)) * R
           for i in range(n_around + 1)]
    tube(mb, region, cen, [(r, r)] * len(cen), n_tube, [w] * len(cen), part, start='open', end='open',
         side_hint=normal, anti=False)


#@vn
def _vnormals(mb, faces):
    acc = {}
    for fi in faces:
        f = mb.F[fi]
        a, b, c = mb.V[f[0]], mb.V[f[1]], mb.V[f[2]]
        n = np.cross(b - a, c - a)
        for v in f:
            acc[v] = acc.get(v, np.zeros(3)) + n
    return {v: nrm(n) for v, n in acc.items()}


#@paint
def _saw(x):
    f = x - np.floor(x)
    return 1 - np.abs(2 * f - 1)


def _pgrain(h, w, seed):
    a = grit(h, 2 * w, seed)
    t = (np.arange(w, dtype=np.float32) / w)[None, :]
    return a[:, w:] * (1 - t) + a[:, :w] * t


def _streaks(h, w, cells, seed):
    a = vnoise(max(8, h // 24), 2 * w, cells, seed)
    t = (np.arange(w, dtype=np.float32) / w)[None, :]
    a = a[:, w:] * (1 - t) + a[:, :w] * t
    yi = np.linspace(0, a.shape[0] - 1, h)
    i0 = np.floor(yi).astype(int)
    i1 = np.minimum(i0 + 1, a.shape[0] - 1)
    f = (yi - i0)[:, None]
    return (a[i0] * (1 - f) + a[i1] * f) - 0.5


def _orange(level):
    if level == 3:
        return [(0, '2a0a04'), (0.4, '7a2408'), (0.8, 'c4520e'), (1, 'e07a22')]
    return [(0, '220803'), (0.4, '6a1e06'), (0.8, 'b2440c'), (1, 'd2661a')]


def _reg(name):
    y0, y1, x0, x1 = ATLAS.px(name)
    h, w = y1 - y0, x1 - x0
    v, u = np.mgrid[0:h, 0:w].astype(np.float32)
    return (y0, y1, x0, x1), v / h, u / w


#@face
# ---------------------------------------------------------------- face decal (carved eyes, nose, mouth)
def _seg(X, Z, a, b, w0, w1):
    ax, az = a; bx, bz = b
    dx, dz = bx - ax, bz - az
    L2 = dx * dx + dz * dz
    t = np.clip(((X - ax) * dx + (Z - az) * dz) / L2, 0, 1)
    d = np.sqrt((X - ax - t * dx) ** 2 + (Z - az - t * dz) ** 2)
    wd = w0 + (w1 - w0) * t
    return ss(wd, wd - 0.003, d)


def _tri(X, Z, p0, p1, p2):
    """inside of the triangle p0 p1 p2 (soft 0..1)."""
    def side(a, b):
        return (b[0] - a[0]) * (Z - a[1]) - (b[1] - a[1]) * (X - a[0])
    s0, s1, s2 = side(p0, p1), side(p1, p2), side(p2, p0)
    sgn = 1 if ((p1[0] - p0[0]) * (p2[1] - p0[1]) - (p1[1] - p0[1]) * (p2[0] - p0[0])) > 0 else -1
    m = np.minimum(np.minimum(s0 * sgn, s1 * sgn), s2 * sgn)
    return ss(0.0, 0.0006, m)


def _face_layers(level, size):
    x, y = coords(size)
    X, Z = x * FX, FZ + y * FZH
    aX = np.abs(X)
    # carved eyes: narrow blades slanting down toward the nose (inner corner low and pointed, outer corner high)
    eye = _tri(aX, Z, (0.045, 1.215), (0.27, 1.32), (0.25, 1.245))
    eye = np.maximum(eye, _tri(aX, Z, (0.045, 1.215), (0.25, 1.245), (0.16, 1.215)))
    # a dark slit "pupil" flame inside each eye (anime slit)
    cx, cz = 0.175, 1.255
    slit = ss(0.008, 0.002, np.abs(aX - cx) - 0.003 * np.clip(1 - ((Z - cz) / 0.04) ** 2, 0, 1)) * ss(0.045, 0.035, np.abs(Z - cz)) * eye
    # heavy carved brow notch above each eye (a dark wedge, not cut through)
    brow = _seg(aX, Z, (0.03, 1.26), (0.29, 1.36), 0.014, 0.004)
    # small inverted nose cut
    nose = _tri(X, Z, (-0.032, 1.2), (0.032, 1.2), (0.0, 1.155))
    # mouth: a wide, nearly flat jagged slash, corners pulled DOWN (menacing), with sharp teeth points
    top = 1.125 - 0.25 * aX ** 2 + 0.012 * _saw(X / 0.07 + 0.5)
    bot = 1.035 - 0.18 * aX ** 2
    span = aX < 0.29
    mouth = ss(0.003, 0.0, np.maximum(Z - top, bot - Z)) * span
    gap = top - bot
    tw = 0.07
    ph = _saw(X / tw + 0.5)
    up_t = (top - Z) < (0.55 * gap * ph) + 0.002            # upper fangs hang down
    lo_t = (Z - bot) < (0.45 * gap * _saw(X / tw)) + 0.002  # lower fangs point up, offset
    teeth = mouth * np.clip(up_t * 1.0 + lo_t * 1.0, 0, 1)
    cut = np.clip(mouth * (1 - teeth), 0, 1)
    # mouth corners: thin cracks running down the cheeks
    crack = np.maximum(_seg(aX, Z, (0.28, top_at(0.28) - 0.03), (0.33, 0.98), 0.008, 0.001),
                       _seg(aX, Z, (0.3, 1.05), (0.36, 1.09), 0.006, 0.001))
    # carved-wall rim (the thickness of the shell round every cut, a lighter flesh colour)
    allcut = np.maximum.reduce([eye, nose, cut])
    marks = np.zeros_like(X)
    if level >= 2:                                   # L2: ember rune scars under the eyes
        marks = np.maximum(_seg(aX, Z, (0.15, 1.19), (0.2, 1.12), 0.008, 0.002), _seg(aX, Z, (0.22, 1.2), (0.26, 1.15), 0.006, 0.002))
    if level >= 3:                                   # L3: a third carved eye mark on the brow
        marks = np.maximum(marks, _tri(X, Z, (-0.04, 1.35), (0.04, 1.35), (0.0, 1.41)))
    return X, Z, eye, slit, brow, nose, cut, teeth, mouth, crack, allcut, marks


def _blur(a, r):
    out = a.copy()
    for _ in range(3):
        acc = np.zeros_like(out)
        for d in range(-r, r + 1):
            acc += np.roll(out, d, 0)
        out = acc / (2 * r + 1)
        acc = np.zeros_like(out)
        for d in range(-r, r + 1):
            acc += np.roll(out, d, 1)
        out = acc / (2 * r + 1)
    return out


def top_at(x):
    return 1.125 - 0.25 * x ** 2


def face_texture(level, size=512):
    X, Z, eye, slit, brow, nose, cut, teeth, mouth, crack, allcut, marks = _face_layers(level, size)
    gc, ghi = CUT[level]
    rgba = np.zeros((size, size, 4), np.float32)
    # carved openings: ember at the cut edge, white-hot toward the middle of each cut (lit from inside)
    hot = _blur(allcut, 6)
    hot = np.clip((hot - 0.45) * 2.2, 0, 1) * allcut
    c = hx(gc) * (1 - hot[..., None]) + hx(ghi) * hot[..., None]
    rim = np.clip(allcut - _blur(allcut, 2) * 0.0, 0, 1) * (1 - _blur(allcut, 2) ** 4)
    c = c * (1 - 0.35 * rim[..., None]) + hx('a83a08') * 0.35 * rim[..., None]
    c = c * (1 - slit[..., None]) + hx('1a0602') * slit[..., None]
    # pumpkin-flesh teeth (lit from below by the glow)
    tcol = grad(np.clip((Z - 1.03) / 0.1, 0, 1), [(0, 'e0802a'), (1, '8a3010')])
    c = c * (1 - teeth[..., None]) + tcol * teeth[..., None]
    # dark brow wedge, cheek cracks and marks
    ln = np.clip(np.maximum(brow, crack), 0, 1)
    c = c * (1 - ln[..., None]) + hx('140602') * ln[..., None]
    c = c * (1 - marks[..., None]) + hx(GLOW[level][0]) * marks[..., None]
    rgba[..., :3] = c
    rgba[..., 3] = np.clip(np.maximum.reduce([allcut, teeth, ln, marks]), 0, 1)
    return rgba


def face_emissive(level, size=512):
    X, Z, eye, slit, brow, nose, cut, teeth, mouth, crack, allcut, marks = _face_layers(level, size)
    g = np.clip(np.maximum.reduce([allcut * (1 - slit), teeth * 0.35, marks * 0.9, crack * 0.25]), 0, 1)
    return np.repeat(g[..., None], 3, -1)


#@anim
def _ease(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def _pulse(t, a, b):
    if t <= a or t >= b:
        return 0.0
    return math.sin(math.pi * (t - a) / (b - a))


