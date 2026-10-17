# lit_view: lit preview renderer for any pet (camera-relative key light from the upper left, so every view is
# front-lit; petkit's default render light sits below/behind the model and makes white look grey).
# Use lit_render / lit_turnaround in your make_previews.py. Lives next to petkit.py in the pet kit.
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))   # the kit folder (petkit.py sits next to this file)
from petkit import render, sheet, VIEWS  # noqa: E402

CAM_LIGHT = np.array([0.45, 0.62, -0.64])   # camera space travel direction: key light from upper-left, toward the model
BG = (196, 206, 222)


def view_R(yaw, pitch):
    cy, sy = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    cp, sp = math.cos(math.radians(pitch)), math.sin(math.radians(pitch))
    Rz = np.array([[cy, -sy, 0], [sy, cy, 0], [0, 0, 1]])
    Rx = np.array([[1, 0, 0], [0, cp, -sp], [0, sp, cp]])
    return Rx @ Rz


def lit_render(mb, verts, tex, yaw, pitch, size=420, scale=None, center=None, mats=None, ground=None):
    R = view_R(yaw, pitch)
    light = (CAM_LIGHT / np.linalg.norm(CAM_LIGHT)) @ R        # world vector that maps back to CAM_LIGHT
    im = render(mb, verts, tex, yaw, pitch, size=size, scale=scale, center=center, mats=mats, light=tuple(light),
                bg=BG)
    if ground is not None and center is not None and scale is not None:
        from PIL import ImageDraw
        # ground line: project the z=0 plane's centre line
        p = (np.array([0, 0, ground]) - center) @ R.T
        y = size / 2 - p[2] * scale
        d = ImageDraw.Draw(im)
        d.line([(0, y), (size, y)], fill=(150, 160, 178), width=1)
    return im


def lit_turnaround(mb, verts, tex, path, mats=None, size=420, views=VIEWS):
    Vv = np.asarray(verts)
    ctr = (Vv.min(0) + Vv.max(0)) / 2
    ext = np.ptp(Vv, axis=0).max()
    imgs = [lit_render(mb, Vv, tex, y, p, size=size, scale=size * 0.8 / ext, center=ctr, mats=mats)
            for y, p, _ in views]
    sheet(imgs, 3, [v[2] for v in views]).save(path)
    return path
