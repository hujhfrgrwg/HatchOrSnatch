

def build():
    mb = MB()
    mb.mat = 0
    W_B, W_H = {'Body': 1}, {'Head': 1}
    # one loft: tail root -> hips -> chest -> neck -> round head (a small beast floating upright)
    st = [(V(0, 0.42, 0.8), (0.1, 0.09), {'Body': 0.6, 'Tail1': 0.4}), (V(0, 0.3, 0.86), (0.2, 0.19), W_B),
          (V(0, 0.1, 0.94), (0.24, 0.24), W_B), (V(0, -0.06, 1.08), (0.22, 0.23), W_B),
          (V(0, -0.12, 1.22), (0.15, 0.15), {'Body': 0.5, 'Head': 0.5}),
          (V(0, -0.18, 1.35), (0.25, 0.23), W_H), (V(0, -0.18, 1.5), (0.23, 0.21), W_H), (V(0, -0.14, 1.62), (0.12, 0.12), W_H)]
    n0 = len(mb.F)
    tube(mb, 'skin', [s[0] for s in st], [s[1] for s in st], 18, [s[2] for s in st], 'body', start='point', end='point',
         start_pt=V(0, 0.48, 0.76), end_pt=V(0, -0.1, 1.67), side_hint=V(1, 0, 0), th0=math.pi / 2)
    body_faces = list(range(n0, len(mb.F)))
    # short cat muzzle
    tube(mb, 'muzzle', [V(0, -0.34, 1.37), V(0, -0.44, 1.34), V(0, -0.5, 1.31)], [(0.11, 0.08), (0.08, 0.06), (0.04, 0.035)],
         8, [W_H] * 3, 'muzzle', start='point', end='point', start_pt=V(0, -0.28, 1.38), end_pt=V(0, -0.53, 1.3), side_hint=V(1, 0, 0))
    gb, gt = ATLAS.uv('gold', 0.5, 0.05), ATLAS.uv('gold', 0.5, 0.95)
    for s, x in (('L', 1), ('R', -1)):
        # tall sharp ears
        bipyramid(mb, V(x * 0.1, -0.16, 1.56), V(x * 0.24, -0.08, 1.9), V(0, 1, 0), V(0, -1, 0.1), 0.17, 0.06, W_H,
                  ATLAS.uv('ear', 0.5, 0.9), ATLAS.uv('ear', 0.5, 0.05), 'ear', wide_at=0.32, ridge_at=0.32)
        # big feathered main wings, swept up like the card
        Ww = {'Wing.' + s: 1}
        lead = [(0.34, 0.04, 1.36), (0.6, 0.08, 1.64), (0.8, 0.12, 1.86)]
        pts = _wing_outline(x, (1.02, 0.16, 1.92), (0.3, 0.18, 0.86), 11, lead)
        wing(mb, 'wing', V(x * 0.16, 0.06, 1.12), pts, Ww, 'wing')
        tube(mb, 'warm', [V(x * 0.14, 0.04, 1.14), V(x * 0.36, 0.04, 1.38), V(x * 0.62, 0.08, 1.66), V(x * 0.82, 0.12, 1.87)],
             [(0.065, 0.065), (0.055, 0.055), (0.04, 0.04), (0.028, 0.028)], 6, [Ww] * 4, 'warm', start='point', end='point',
             start_pt=V(x * 0.08, 0.04, 1.08), end_pt=V(x * 1.04, 0.17, 1.96), side_hint=V(0, 1, 0))
        # tucked paws
        Wl = {'Leg.' + s: 1}
        tube(mb, 'limb', [V(x * 0.1, -0.06, 0.94), V(x * 0.12, -0.12, 0.78), V(x * 0.12, -0.18, 0.68)],
             [(0.07, 0.07), (0.05, 0.05), (0.055, 0.05)], 6, [Wl] * 3, 'leg', start='point', end='point',
             start_pt=V(x * 0.09, -0.02, 1.0), end_pt=V(x * 0.12, -0.22, 0.64))
        Wk = {'Hind.' + s: 1}
        tube(mb, 'limb', [V(x * 0.14, 0.3, 0.86), V(x * 0.16, 0.26, 0.72), V(x * 0.16, 0.2, 0.64)],
             [(0.09, 0.09), (0.06, 0.06), (0.06, 0.05)], 6, [Wk] * 3, 'leg', start='point', end='point',
             start_pt=V(x * 0.12, 0.3, 0.92), end_pt=V(x * 0.16, 0.16, 0.6))
    # gold circlet round the brow with a violet gem, gold collar with a pendant
    ring(mb, 'gold', V(0, -0.18, 1.55), V(0, 0.35, 1), 0.2, 0.025, 14, 4, W_H, 'gold')
    bipyramid(mb, V(0, -0.38, 1.58), V(0, -0.38, 1.7), V(1, 0, 0), V(0, -1, 0), 0.08, 0.06, W_H,
              ATLAS.uv('gem', 0.5, 0.1), ATLAS.uv('gem', 0.5, 0.9), 'gem')
    for x in (1, -1):
        bipyramid(mb, V(x * 0.08, -0.36, 1.6), V(x * 0.16, -0.32, 1.74), V(0, 1, 0), V(0, -1, 0), 0.05, 0.03, W_H, gb, gt, 'gold', wide_at=0.3)
    ring(mb, 'gold', V(0, -0.12, 1.2), V(0, -0.35, 1), 0.17, 0.03, 12, 4, W_B, 'gold')
    bipyramid(mb, V(0, -0.3, 1.14), V(0, -0.32, 0.98), V(1, 0, 0), V(0, -1, 0), 0.1, 0.05, W_B, gb, gt, 'gold', wide_at=0.4)
    # long tail with a void wisp tuft
    tube(mb, 'tail', [V(0, 0.42, 0.8), V(0, 0.66, 0.72), V(0, 0.86, 0.76), V(0, 0.98, 0.88)], [(0.07, 0.07), (0.06, 0.06), (0.05, 0.05), (0.04, 0.04)],
         6, [{'Body': 0.4, 'Tail1': 0.6}, {'Tail1': 1}, {'Tail2': 1}, {'Tail2': 1}], 'tail', start='point', end='point',
         start_pt=V(0, 0.36, 0.82), end_pt=V(0, 1.02, 0.94))
    for d in (V(0.4, 0.6, 0.6), V(-0.4, 0.6, 0.6), V(0, 0.4, 1), V(0, 1, 0.2)):
        bipyramid(mb, V(0, 0.96, 0.88), V(0, 0.96, 0.88) + nrm(d) * 0.26, V(1, 0, 0) if abs(d[0]) < 0.1 else V(0, 1, 0), V(0, 0, 1),
                  0.13, 0.04, {'Tail2': 1}, ATLAS.uv('wisp', 0.5, 0.05), ATLAS.uv('wisp', 0.5, 0.95), 'tail', wide_at=0.3, ridge_at=0.3, curl=0.15)
    mb.mat = 1
    face_shell(mb, body_faces)
    # ---- L2 "Twin Halo": a lower wing pair, a gold halo ring
    mb.mat = 2
    for s, x in (('L', 1), ('R', -1)):
        pts = _wing_outline(x, (0.74, 0.32, 0.74), (0.22, 0.24, 0.72), 8, [(0.36, 0.22, 0.98), (0.56, 0.28, 0.92)])
        wing(mb, 'wing2', V(x * 0.15, 0.18, 0.94), pts, {'Wing2.' + s: 1}, 'L2', thick=0.03)
    ring(mb, 'gold', V(0, 0.06, 1.8), V(0, 0.15, 1), 0.26, 0.022, 16, 4, {'Halo': 1}, 'L2')
    # ---- L3 "Six-Winged Void": temple wings, a void eye behind the head, crystal crown points
    mb.mat = 3
    for s, x in (('L', 1), ('R', -1)):
        pts = _wing_outline(x, (0.5, -0.02, 1.84), (0.16, -0.1, 1.56), 6, [(0.26, -0.12, 1.66), (0.38, -0.06, 1.8)])
        wing(mb, 'wing2', V(x * 0.14, -0.12, 1.52), pts, {'Wing3.' + s: 1}, 'L3', thick=0.025)
        bipyramid(mb, V(x * 0.12, -0.3, 1.66), V(x * 0.2, -0.26, 1.88), V(0, 1, 0), V(0, -1, 0), 0.06, 0.05, W_H,
                  ATLAS.uv('crystal', 0.5, 0.1), ATLAS.uv('crystal', 0.5, 0.95), 'L3', wide_at=0.35)
    bipyramid(mb, V(0, -0.36, 1.68), V(0, -0.34, 1.94), V(1, 0, 0), V(0, -1, 0), 0.07, 0.05, W_H,
              ATLAS.uv('crystal', 0.5, 0.1), ATLAS.uv('crystal', 0.5, 0.95), 'L3', wide_at=0.35)
    disc(mb, 'void', V(0, 0.2, 1.5), V(0, 1, -0.1), 0.34, 16, {'Halo': 1}, 'L3', thick=0.02)
    mb.mat = 0
    return mb


# ----------------------------------------------------------------- painting
def _saw(x):
    f = x - np.floor(x)
    return 1 - np.abs(2 * f - 1)


def _streaks(h, w, cells, seed):
    a = vnoise(max(8, h // 24), 2 * w, cells, seed)
    t = (np.arange(w, dtype=np.float32) / w)[None, :]
    a = a[:, w:] * (1 - t) + a[:, :w] * t
    yi = np.linspace(0, a.shape[0] - 1, h)
    i0 = np.floor(yi).astype(int)
    i1 = np.minimum(i0 + 1, a.shape[0] - 1)
    f = (yi - i0)[:, None]
    return (a[i0] * (1 - f) + a[i1] * f) - 0.5


def _reg(name):
    y0, y1, x0, x1 = ATLAS.px(name)
    h, w = y1 - y0, x1 - x0
    v, u = np.mgrid[0:h, 0:w].astype(np.float32)
    return (y0, y1, x0, x1), v / h, u / w


VOIDC = [(0, '0a0418'), (0.5, '3a1460'), (1, '8a4ad8')]


def paint_atlas(level):
    col = np.zeros((TS, TS, 3), np.float32)
    hgt = np.full((TS, TS), 0.5, np.float32)
    rgh = np.full((TS, TS), 0.6, np.float32)
    glow = np.zeros((TS, TS), np.float32)
    gd, gm, gh = GLOW[level]
    # body: ivory-lavender fur, a darker violet underside fading to void, glowing magenta void cracks
    (y0, y1, x0, x1), v, u = _reg('skin')
    h, w = y1 - y0, x1 - x0
    top = np.cos(u * 2 * math.pi)
    c = grad(np.clip(0.6 + 0.35 * top, 0, 1), FUR)
    under = ss(-0.3, -0.75, top + 0.15 * _saw(v * 14)) * ss(0.65, 0.5, v)
    c = c * (1 - 0.8 * under[..., None]) + grad(np.clip(v * 1.5, 0, 1), VOIDC) * (0.8 * under[..., None])
    side = np.abs(np.sin(u * 2 * math.pi))
    crack = ss(0.012, 0.0, np.abs(_saw(v * 5 + 0.6 * _saw(u * 3)) - 0.5) - 0.012) * ss(0.55, 0.8, side) * ss(0.12, 0.2, v) * ss(0.62, 0.55, v)
    c = c * (1 - crack[..., None]) + hx(gm) * crack[..., None]
    st = _streaks(h, w, 170, 61)
    col[y0:y1, x0:x1] = c * (1 + 0.18 * st[..., None])
    hgt[y0:y1, x0:x1] = 0.5 + 0.4 * st
    glow[y0:y1, x0:x1] = crack * (0.5 if level == 1 else 1.0)
    # wings: white feathers darkening to void-violet at the tips, feather lines, a glowing magenta rim
    for reg in ('wing', 'wing2'):
        (y0, y1, x0, x1), v, u = _reg(reg)
        A, B = u, 1 - v
        nf = 12 if reg == 'wing' else 8
        fl = np.abs(_saw(A * nf * 0.5 + B * 2.2) - 0.5)
        lines = ss(0.04, 0.0, fl - 0.02)
        teeth = 0.6 + 0.1 * _saw(B * 14) - 0.06 * B
        dark = ss(0.0, 0.08, A - teeth)
        base = grad(np.clip(0.45 + 0.6 * (1 - A), 0, 1), FUR)
        tip = grad(np.clip((A - teeth) * 3, 0, 1), [(0, '6a4ab8'), (0.5, '2a0c50'), (1, '0a0418')])
        c = base * (1 - dark[..., None]) + tip * dark[..., None]
        rim = ss(0.03, 0.0, np.abs(A - teeth - 0.01) - 0.012)
        c = c * (1 - rim[..., None]) + hx(gm) * rim[..., None]
        c = c * (1 - 0.35 * lines[..., None])
        cov = ss(0.0, 0.04, 0.22 - A + 0.05 * _saw(B * 18))
        c = c * (1 - 0.15 * cov[..., None])
        col[y0:y1, x0:x1] = c
        hgt[y0:y1, x0:x1] = 0.5 - 0.25 * lines + 0.1 * cov
        rgh[y0:y1, x0:x1] = 0.55
        glow[y0:y1, x0:x1] = np.clip(rim * (0.7 + 0.3 * (level >= 2)) + dark * 0.15 * (level >= 2), 0, 1)
    (y0, y1, x0, x1), v, u = _reg('warm')
    st = _streaks(y1 - y0, x1 - x0, 40, 62)
    col[y0:y1, x0:x1] = grad(np.clip(0.7 + 0.2 * v, 0, 1), FUR) * (1 + 0.15 * st[..., None])
    (y0, y1, x0, x1), v, u = _reg('tail')
    col[y0:y1, x0:x1] = grad(np.clip(v * 1.2, 0, 1), [(0, 'e8e2f6'), (0.6, '9a7ad8'), (1, '2a0c50')])
    (y0, y1, x0, x1), v, u = _reg('wisp')
    col[y0:y1, x0:x1] = grad(v, [(0, '3a1460'), (0.5, gm), (1, gh)])
    glow[y0:y1, x0:x1] = 0.4 + 0.5 * v
    (y0, y1, x0, x1), v, u = _reg('ear')
    inner = ss(0.32, 0.42, np.cos(u * 2 * math.pi) * 0.5 + 0.5) * ss(0.95, 0.75, v)
    col[y0:y1, x0:x1] = grad(v, FUR) * (1 - inner[..., None]) + grad(v, [(0, '3a1460'), (1, '8a4ad8')]) * inner[..., None]
    (y0, y1, x0, x1), v, u = _reg('muzzle')
    col[y0:y1, x0:x1] = grad(v, [(0, 'f4f0fc'), (0.8, 'e0d8f0'), (1, '2a1840')])
    (y0, y1, x0, x1), v, u = _reg('limb')
    col[y0:y1, x0:x1] = grad(np.clip(0.9 - 0.3 * v, 0, 1), FUR)
    (y0, y1, x0, x1), v, u = _reg('gold')
    eng = ss(0.02, 0.0, np.abs(_saw(v * 5) - 0.5) - 0.03)
    col[y0:y1, x0:x1] = grad(u, [(0, 'fff0a0'), (0.45, 'f0b030'), (1, '8a5a08')]) * (1 - 0.35 * eng[..., None])
    rgh[y0:y1, x0:x1] = 0.25
    glow[y0:y1, x0:x1] = 0.12
    (y0, y1, x0, x1), v, u = _reg('gem')
    col[y0:y1, x0:x1] = grad(v, [(0, 'ffd0ff'), (0.5, 'b03ae0'), (1, '3a0a60')])
    rgh[y0:y1, x0:x1] = 0.1
    glow[y0:y1, x0:x1] = 0.8
    (y0, y1, x0, x1), v, u = _reg('crystal')
    facet = 0.5 + 0.5 * np.sign(np.sin(u * 2 * math.pi * 3))
    col[y0:y1, x0:x1] = grad(v, [(0, '3a0a60'), (0.6, gm), (1, gh)]) * (0.8 + 0.2 * facet[..., None])
    glow[y0:y1, x0:x1] = 0.4 + 0.5 * v
    (y0, y1, x0, x1), v, u = _reg('void')
    r = np.sqrt((u - 0.5) ** 2 + (v - 0.5) ** 2) / 0.48
    col[y0:y1, x0:x1] = grad(np.clip(r, 0, 1), [(0, '000000'), (0.62, '0a0418'), (0.8, '6a1aa8'), (0.92, gm), (1, gh)])
    glow[y0:y1, x0:x1] = ss(0.7, 0.95, r)
    paint_atlas._glow = np.clip(glow, 0, 1)
    return np.clip(col, 0, 1), hgt, rgh


def emissive_mask(level):
    paint_atlas(level)
    return np.repeat(paint_atlas._glow[..., None], 3, -1)


def _seg(X, Z, a, b, w0, w1):
    ax, az = a; bx, bz = b
    dx, dz = bx - ax, bz - az
    L2 = dx * dx + dz * dz
    t = np.clip(((X - ax) * dx + (Z - az) * dz) / L2, 0, 1)
    d = np.sqrt((X - ax - t * dx) ** 2 + (Z - az - t * dz) ** 2)
    wd = w0 + (w1 - w0) * t
    return ss(wd, wd - 0.003, d)


def _face_layers(level, size):
    x, y = coords(size)
    X, Z = x * FX, FZ + y * FZH
    aX = np.abs(X)
    ix, iz, ox, oz = 0.06, 1.44, 0.18, 1.5
    ex, ez = ox - ix, oz - iz
    L = math.hypot(ex, ez)
    s = ((aX - ix) * ex + (Z - iz) * ez) / (L * L)
    d = (-(aX - ix) * ez + (Z - iz) * ex) / L
    sc = np.clip(s, 0, 1)
    top = 0.028 * np.clip(sc * 3.0, 0, 1) * (1 - sc ** 4) + 0.002
    bot = -0.02 * np.clip(np.sin(math.pi * sc), 0, 1) ** 0.9 - 0.001
    eye = ss(0.003, 0.0, np.maximum(d - top, bot - d)) * (s > 0) * (s < 1)
    cxs, czs = ix + 0.52 * ex, iz + 0.52 * ez
    rr = np.sqrt((aX - cxs) ** 2 + (Z - czs) ** 2)
    _face_layers.rr = rr
    iris = ss(0.04, 0.036, rr)
    slit = ss(0.005 * np.clip(1 - ((Z - czs) / 0.03) ** 2, 0, 1) + 0.0005, 0.0, np.abs(aX - cxs)) * ss(0.03, 0.026, rr)
    brow = np.maximum(_seg(aX, Z, (0.04, 1.49), (0.2, 1.56), 0.011, 0.005), _seg(aX, Z, (0.18, 1.555), (0.25, 1.6), 0.007, 0.001))
    lid = ss(0.006, 0.003, np.abs(d - top - 0.003)) * (s > -0.05) * (s < 1.02)
    # dark violet liner flicks and void tear marks under the eyes
    liner = np.maximum(_seg(aX, Z, (0.17, 1.5), (0.24, 1.53), 0.008, 0.002), _seg(aX, Z, (0.12, 1.42), (0.15, 1.34), 0.009, 0.002))
    mark = _seg(X, Z, (0.0, 1.56), (0.0, 1.6), 0.012, 0.004) * (level >= 2)
    if level >= 3:
        mark = np.maximum(mark, _seg(aX, Z, (0.15, 1.36), (0.18, 1.3), 0.006, 0.002))
    mouth = _seg(X, Z, (-0.045, 1.275), (0.045, 1.275), 0.004, 0.004)
    nose = ss(0.004, 0.0, aX / 0.03 + np.abs(Z - 1.33) / 0.016 - 1)
    return X, Z, eye, iris, slit, brow, lid, liner, mark, mouth, nose


def face_texture(level, size=512):
    X, Z, eye, iris, slit, brow, lid, liner, mark, mouth, nose = _face_layers(level, size)
    rr = _face_layers.rr
    ed, em, eh = EYE[level]
    gd, gm, gh = GLOW[level]
    rgba = np.zeros((size, size, 4), np.float32)
    c = np.zeros((size, size, 3), np.float32) + hx('2a0c48')
    c = c * (1 - liner[..., None]) + hx('3a0a60') * liner[..., None]
    c = c * (1 - mark[..., None]) + hx(gm) * mark[..., None]
    irisc = grad(np.clip(1 - rr / 0.036, 0, 1), [(0, ed), (0.45, em), (1, eh)])
    e = hx('0a0610') * (1 - iris[..., None]) + irisc * iris[..., None]
    e = e * (1 - slit[..., None]) + hx('020104') * slit[..., None]
    c = c * (1 - eye[..., None]) + e * eye[..., None]
    ln = np.maximum.reduce([lid, brow, mouth])
    c = c * (1 - ln[..., None]) + hx('14081e') * ln[..., None]
    c = c * (1 - nose[..., None]) + hx('5a3a7a') * nose[..., None]
    rgba[..., :3] = c
    rgba[..., 3] = np.clip(np.maximum.reduce([eye, ln, liner, mark, nose]), 0, 1)
    return rgba


def face_emissive(level, size=512):
    X, Z, eye, iris, slit, brow, lid, liner, mark, mouth, nose = _face_layers(level, size)
    g = np.clip(np.maximum(iris * eye * (1 - slit), mark * 0.9), 0, 1)
    return np.repeat(g[..., None], 3, -1)


# ----------------------------------------------------------------- animation
def _ease(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def _wings(w, amp, base=0.0):
    f = amp * math.sin(w) + base
    g = 0.8 * amp * math.sin(w - 0.6) + base * 0.5
    h = 0.6 * amp * math.sin(w + 0.6) + base * 0.4
    return {'Wing.L': P(('y', -f)), 'Wing.R': P(('y', f)), 'Wing2.L': P(('y', -g)), 'Wing2.R': P(('y', g)),
            'Wing3.L': P(('y', -h)), 'Wing3.R': P(('y', h))}


def _tailw(w, amp):
    return {'Tail1': P(('z', amp * math.sin(w)), ('x', -6)), 'Tail2': P(('z', amp * 1.4 * math.sin(w - 0.8)))}


def anim_idle():
    """A slow, regal hover: deep wing strokes, the head turning to watch, the tail curling, the halo turning."""
    F = 72
    keys = {}
    for f in range(0, F + 1, 2):
        t = f / F
        w = 2 * math.pi * t
        k = {'Body': P(('x', 3 * math.sin(w)), loc=(0, 0, 0.09 * math.sin(w * 2 - 0.8))),
             'Head': P(('z', 16 * math.sin(w * 0.5)), ('x', -4 * math.sin(w))),
             'Halo': P(('y', 360 * t), loc=(0, 0, 0.03 * math.sin(w))),
             'Leg.L': P(('x', 25 + 5 * math.sin(w * 2))), 'Leg.R': P(('x', 25 + 5 * math.sin(w * 2 + 0.5))),
             'Hind.L': P(('x', -20)), 'Hind.R': P(('x', -20))}
        k.update(_wings(w * 2, 18, 6))
        k.update(_tailw(w, 14))
        keys[f] = k
    keys[F] = dict(keys[0])
    keys[F]['Halo'] = P(('y', 0))
    return {'frames': F, 'loop': True, 'keys': keys}


def _fly(frames, pitch, amp):
    keys = {}
    for f in range(0, frames + 1):
        t = f / frames
        w = 2 * math.pi * t
        k = {'Body': P(('x', pitch + 3 * math.sin(w)), loc=(0, 0, 0.06 * math.sin(w - 1.4))),
             'Head': P(('x', -pitch * 0.7)), 'Halo': P(('x', -pitch * 0.5)),
             'Leg.L': P(('x', 55)), 'Leg.R': P(('x', 55)), 'Hind.L': P(('x', -45)), 'Hind.R': P(('x', -45))}
        k.update(_wings(w, amp, 4))
        k.update(_tailw(w, 8))
        keys[f] = k
    return {'frames': frames, 'loop': True, 'keys': keys}


def anim_walk():
    return _fly(22, 20, 32)


def anim_run():
    return _fly(14, 40, 40)


def anim_hop():
    keys = {}
    for f in range(0, 17, 2):
        t = f / 16
        up = math.sin(math.pi * t)
        k = {'Body': P(('x', -8 * up), loc=(0, 0, 0.3 * up))}
        k.update(_wings(math.pi / 2, 40 * up, 0))
        keys[f] = k
    return {'frames': 16, 'loop': False, 'keys': keys}


def anim_ability():
    """Portal Relocation (~1 s, Runner): folds every wing forward into a closed cocoon, spins inside it (the portal
    opens at ~0.5), then throws all the wings wide in a burst and settles."""
    keys = {}
    F = 24
    for f in range(0, F + 1, 2):
        t = f / F
        wrap = _ease(t / 0.3) * (1 - _ease((t - 0.45) / 0.08))
        spin = _ease((t - 0.15) / 0.35)
        burst = _ease((t - 0.45) / 0.08) * (1 - _ease((t - 0.78) / 0.22))
        k = {'Body': P(('z', -360 * spin), ('x', 10 * wrap - 12 * burst), loc=(0, 0, -0.05 * wrap + 0.16 * burst)),
             'Head': P(('x', 18 * wrap - 16 * burst)), 'Halo': P(('y', 720 * t)),
             'Wing.L': P(('y', 30 * wrap - 60 * burst), ('z', -75 * wrap)), 'Wing.R': P(('y', -30 * wrap + 60 * burst), ('z', 75 * wrap)),
             'Wing2.L': P(('y', 20 * wrap - 45 * burst), ('z', -60 * wrap)), 'Wing2.R': P(('y', -20 * wrap + 45 * burst), ('z', 60 * wrap)),
             'Wing3.L': P(('y', 20 * wrap - 35 * burst), ('z', -40 * wrap)), 'Wing3.R': P(('y', -20 * wrap + 35 * burst), ('z', 40 * wrap)),
             'Leg.L': P(('x', 40 * wrap)), 'Leg.R': P(('x', 40 * wrap))}
        k.update(_tailw(6 * t, 20 * burst))
        keys[f] = k
    keys[F]['Body'] = P(('z', -360))
    return {'frames': F, 'loop': False, 'keys': keys}


def anim_blink():
    """Blink (~0.75 s, Catcher): snaps the wings tight against its body, flickers forward low (the blink at ~0.4),
    then flares to brake."""
    keys = {}
    F = 18
    for f in range(0, F + 1):
        t = f / F
        tuck = _ease(t / 0.3) * (1 - _ease((t - 0.42) / 0.08))
        dart = _ease((t - 0.3) / 0.1) * (1 - _ease((t - 0.6) / 0.3))
        brake = _ease((t - 0.5) / 0.12) * (1 - _ease((t - 0.8) / 0.2))
        k = {'Body': P(('x', 12 * tuck + 30 * dart - 20 * brake), loc=(0, -0.35 * dart, -0.08 * tuck)),
             'Head': P(('x', -10 * dart + 8 * brake)),
             'Wing.L': P(('y', 40 * tuck - 50 * brake), ('z', -30 * tuck)), 'Wing.R': P(('y', -40 * tuck + 50 * brake), ('z', 30 * tuck)),
             'Wing2.L': P(('y', 30 * tuck - 30 * brake)), 'Wing2.R': P(('y', -30 * tuck + 30 * brake)),
             'Wing3.L': P(('y', 30 * tuck)), 'Wing3.R': P(('y', -30 * tuck)),
             'Leg.L': P(('x', 50 * tuck)), 'Leg.R': P(('x', 50 * tuck))}
        k.update(_tailw(4 * t, 10))
        keys[f] = k
    return {'frames': F, 'loop': False, 'keys': keys}


ANIMS = {'Idle': anim_idle, 'Walk': anim_walk, 'Run': anim_run, 'Hop': anim_hop, 'Ability': anim_ability,
         'Blink': anim_blink}
