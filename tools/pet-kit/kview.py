"""kview: alpha-aware preview renderer: petkit's textured rasterizer + alpha blending for RGBA decal materials (mat 1, the
face decal shell, is shown the way Roblox shows SurfaceAppearance AlphaMode=Transparency: transparent texels let
the fur underneath show through). Camera-relative key light as in lit_view.py.
Use it instead of lit_view when mat 1 is an RGBA face decal shell (painted face markings over the fur)."""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))   # the kit folder (petkit.py sits next to this file)
from petkit import nrm, sheet, VIEWS  # noqa: E402

CAM_LIGHT = np.array([0.45, 0.62, -0.64])
BG = (196, 206, 222)


def view_R(yaw, pitch):
    cy, sy = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    cp, sp = math.cos(math.radians(pitch)), math.sin(math.radians(pitch))
    Rz = np.array([[cy, -sy, 0], [sy, cy, 0], [0, 0, 1]])
    Rx = np.array([[1, 0, 0], [0, cp, -sp], [0, sp, cp]])
    return Rx @ Rz


def _sample4(img, uv):
    H, W = img.shape[:2]
    x = np.clip((uv[..., 0] % 1.0) * W, 0, W - 1).astype(int)
    y = np.clip((1 - (uv[..., 1] % 1.0)) * H, 0, H - 1).astype(int)
    px = img[y, x]
    if px.shape[-1] == 4:
        return px[..., :3], px[..., 3]
    return px[..., :3], np.ones(px.shape[:-1])


def render(mb, verts, textures, yaw, pitch, size=520, scale=None, center=None, bg=BG, mats=None,
           light=(-0.4, -0.7, 0.8), outline=True, alpha_mats=(1,)):
    from PIL import Image
    Vv = np.asarray(verts)
    R = view_R(yaw, pitch)
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
    order = [i for i, m in enumerate(mb.MAT) if m not in alpha_mats] + \
            [i for i, m in enumerate(mb.MAT) if m in alpha_mats]
    for fi in order:
        f, uvs, m = mb.F[fi], mb.UV[fi], mb.MAT[fi]
        if mats is not None and m not in mats:
            continue
        tex = textures.get(m)
        blend = m in alpha_mats and tex is not None and tex.shape[-1] == 4
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
            if tex is not None:
                uvp = (w0[..., None] * uv3[0] + w1[..., None] * uv3[1] + w2[..., None] * uv3[2])[upd]
                col, a = _sample4(tex, uvp)
            else:
                col, a = np.full((upd.sum(), 3), 0.7), np.ones(upd.sum())
            shade = np.clip(col * (0.42 + 0.78 * lam) + rim, 0, 1)
            region = img[y0:y1 + 1, x0:x1 + 1]
            if blend:
                a = a[:, None]
                region[upd] = shade * a + region[upd] * (1 - a)
                zz = z[upd]
                keep = a[:, 0] > 0.5
                tmp = sub[upd]
                tmp[keep] = zz[keep]
                sub[upd] = tmp
            else:
                sub[upd] = z[upd]
                region[upd] = shade
    if outline:
        zf = np.where(np.isinf(zb), 1e3, zb)
        edge = np.zeros_like(zf, bool)
        edge[1:, :] |= np.abs(zf[1:, :] - zf[:-1, :]) > 0.12
        edge[:, 1:] |= np.abs(zf[:, 1:] - zf[:, :-1]) > 0.12
        img[edge] = img[edge] * 0.35
    return Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8))


def lit_render(mb, verts, tex, yaw, pitch, size=420, scale=None, center=None, mats=None):
    R = view_R(yaw, pitch)
    light = (CAM_LIGHT / np.linalg.norm(CAM_LIGHT)) @ R
    return render(mb, verts, tex, yaw, pitch, size=size, scale=scale, center=center, mats=mats, light=tuple(light))


def lit_turnaround(mb, verts, tex, path, mats=None, size=420, views=VIEWS):
    Vv = np.asarray(verts)
    ctr = (Vv.min(0) + Vv.max(0)) / 2
    ext = np.ptp(Vv, axis=0).max()
    imgs = [lit_render(mb, Vv, tex, y, p, size=size, scale=size * 0.8 / ext, center=ctr, mats=mats)
            for y, p, _ in views]
    sheet(imgs, 3, [v[2] for v in views]).save(path)
    return path


REF = None   # set to the path of a reference picture (e.g. one the game owner gave you), or pass ref= to with_ref


def with_ref(img, height=None, label='reference', ref=None):
    """img (PIL) next to the reference picture (ref= path, or REF) scaled to the same height."""
    from PIL import Image, ImageDraw
    path = ref or REF
    if not path:
        raise ValueError('with_ref: pass ref=<path to the reference picture> or set kview.REF')
    ref = Image.open(path).convert('RGB')
    h = height or img.size[1]
    ref = ref.resize((int(ref.size[0] * h / ref.size[1]), h))
    out = Image.new('RGB', (img.size[0] + ref.size[0], h), (255, 255, 255))
    out.paste(img, (0, 0))
    out.paste(ref, (img.size[0], 0))
    ImageDraw.Draw(out).text((img.size[0] + 8, 6), label, fill=(255, 255, 255))
    return out
