"""HOS-LOBBY-007 (18 Oct 2026, Matthew): a stud texture for MaterialVariants that matches Roblox's Studs surface (the
rounded-square studs on the incubator and the rest of the lobby's parts), for meshes, which can't show surfaces.
The egg pack's "Studs" variant (HOS_Studs) draws an embossed L instead.

One tile is one stud (use StudsPerTile = 1). The stud is a rounded square 0.5 studs across with corners of 0.11, a soft
dark outline and a faint bevel, measured off a close-up of the Studs surface on the incubator. Near-white, so the part's
colour tints it.
  stud_color.png   colour map (the outline, a little shading)
  stud_normal.png  tangent-space normal map, OpenGL style (the stud's bevelled edge stands up a touch)

Run: python3 tools/build/HOS-LOBBY-007_stud_texture.py docs/HOS-LOBBY-007/stud_texture
"""
import sys
import numpy as np
from PIL import Image, ImageFilter

N = 512  # pixels per stud
SIZE, RADIUS, LINE = 0.5, 0.11, 0.04  # stud width, corner radius, outline width (studs)


def rounded_square_sdf(n, size, radius):
    """signed distance (studs) to a rounded square centred in a 1-stud tile; negative inside"""
    c = (np.arange(n) + 0.5) / n - 0.5
    x, y = np.meshgrid(c, c)
    q = np.stack([np.abs(x) - (size / 2 - radius), np.abs(y) - (size / 2 - radius)])
    outside = np.linalg.norm(np.maximum(q, 0), axis=0)
    inside = np.minimum(np.maximum(q[0], q[1]), 0)
    return outside + inside - radius


def main(out):
    d = rounded_square_sdf(N, SIZE, RADIUS)
    # colour: near-white field, a soft dark outline on the edge, the inside a hair lighter
    base = np.full((N, N), 232.0)
    base[d < 0] = 238.0
    line = np.clip(1 - np.abs(d) / (LINE / 2), 0, 1) ** 1.5
    col = base - 85 * line
    img = Image.fromarray(np.clip(col, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2.2)).convert("RGB")
    img.save(f"{out}/stud_color.png")
    # normal: height rises over a narrow bevel just inside the outline; gradient -> tangent-space normal
    h = np.clip(-d / 0.03, 0, 1)  # 0 outside, 1 on the stud's top
    h = np.array(Image.fromarray((h * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3)), float) / 255
    gy, gx = np.gradient(h)
    strength = 6.0
    nx, ny, nz = -gx * strength, gy * strength, np.ones_like(h)  # image y runs down; OpenGL wants +G = up
    l = np.sqrt(nx ** 2 + ny ** 2 + nz ** 2)
    rgb = np.stack([nx / l, ny / l, nz / l], -1) * 0.5 + 0.5
    Image.fromarray((rgb * 255).astype(np.uint8)).save(f"{out}/stud_normal.png")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else ".")
