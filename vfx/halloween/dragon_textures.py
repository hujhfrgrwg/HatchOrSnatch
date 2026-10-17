# Bone Dragon's own Tempest textures (HOS-HWN-001), drawn with the roblox-vfx numpy library.
#   DragonShard: a jagged bone shard (lit / shadow halves). DragonShardRing: the knockback ground ring, a ring of bone
#   shards pointing outward with a crack line. DragonSoulFire (4x4): a ghost-fire ball that flares and licks upward.
#   DragonSkull: a horned dragon-skull silhouette flash with slit sockets cut out.
import os, sys
sys.path.insert(0, r"C:\Users\hunte\.claude\skills\roblox-vfx\scripts")
import numpy as np
import vfxtex as vt
HERE = os.path.dirname(os.path.abspath(__file__))
vt.OUTPUT_DIR = os.path.join(HERE, "out")
os.makedirs(vt.OUTPUT_DIR, exist_ok=True)
NOISE = vt.tex_noise(256, scale=6, seed=171)


def shard(size):
    x, y = vt.tex_coords(size)
    pts = [(0.0, 0.9), (0.22, 0.2), (0.12, -0.6), (-0.05, -0.85), (-0.2, -0.1), (-0.16, 0.4)]
    inside = np.ones_like(x, dtype=bool)
    n = len(pts)
    for i in range(n):
        (ax, ay), (bx, by) = pts[i], pts[(i + 1) % n]
        inside &= ((bx - ax) * (y - ay) - (by - ay) * (x - ax)) >= 0
    a = inside.astype(np.float32)
    if a.mean() < 0.01:          # winding the other way
        inside = np.ones_like(x, dtype=bool)
        for i in range(n):
            (ax, ay), (bx, by) = pts[i], pts[(i + 1) % n]
            inside &= ((bx - ax) * (y - ay) - (by - ay) * (x - ax)) <= 0
        a = inside.astype(np.float32)
    v = np.where(x > 0.02 * y, 1.0, 0.68)
    return np.dstack([v, v, v, a])


def shard_ring(size):
    x, y = vt.tex_coords(size)
    r, ang = vt.tex_polar(x, y)
    ring = vt.tex_edge(0.035 - np.abs(r - 0.62), soft=0.008)
    k = 14
    sec = ((ang / (2 * np.pi)) * k) % 1
    spike = (np.abs(sec - 0.5) * 2)          # 0 at a spike centre
    tooth = vt.tex_edge((0.62 + 0.3 * (1 - spike) ** 1.6) - r, soft=0.008) * vt.tex_edge(r - 0.6, soft=0.008)
    crack = vt.tex_edge(0.012 - np.abs(r - 0.5 - 0.03 * np.sin(ang * 9)), soft=0.006) * 0.8
    a = np.clip(np.maximum.reduce([ring, tooth, crack]), 0, 1)
    v = np.clip(0.7 + 0.3 * (1 - spike) * tooth, 0, 1)
    return np.dstack([v, v, v, a])


def soul_fire(t, size):
    x, y = vt.tex_coords(size)
    g = vt.tex_ease(t * 2.0)
    wx, wy = vt.tex_warp(x, y, amount=0.12, scale=3, seed=5, t=t)
    body = 0.78 * g - np.hypot(wx, (wy + 0.1) * 1.1)
    lick = vt.tex_sample(NOISE, wx * 0.6 + 0.3, wy * 0.4 - t * 1.4) - 0.5
    flame = body + 0.45 * lick * vt.tex_edge(wy + 0.05, soft=0.4)
    fade = 1 - vt.tex_edge(t - 0.7, soft=0.3)
    a = vt.tex_edge(flame, soft=0.02) * fade
    core = vt.tex_edge(flame - 0.12, soft=0.08)
    return a, 0.6 + 0.4 * core


def skull(size):
    x, y = vt.tex_coords(size)
    ax = np.abs(x)
    cran = 0.42 - np.hypot(x / 1.0, (y - 0.15) / 0.85)
    snout = np.minimum(0.22 + 0.22 * np.clip(y, -0.75, 0.1) - ax, np.minimum(y + 0.75, 0.2 - y))
    horn = np.full_like(x, -1.0)
    for s in (1, -1):
        horn = np.maximum(horn, vt.tex_stroke(x, y, np.array([(s * 0.25, 0.45), (s * 0.42, 0.72), (s * 0.5, 0.92)]), [0.07, 0.04, 0.012]))
    shape = np.maximum(np.maximum(cran, snout), horn)
    sock = np.minimum(0.03 - np.abs(y - 0.12 - 0.35 * (ax - 0.17)), 0.12 - np.abs(ax - 0.17))
    a = vt.tex_edge(shape, soft=0.008) * (1 - vt.tex_edge(sock, soft=0.006))
    return np.dstack([np.ones_like(x), np.ones_like(x), np.ones_like(x), a])


vt.draw_texture("DragonShard", shard, size=256)
vt.draw_texture("DragonShardRing", shard_ring, size=512)
vt.draw_flipbook("DragonSoulFire", soul_fire, grid=4, fps=24)
vt.draw_texture("DragonSkull", skull, size=512)
print("done")
