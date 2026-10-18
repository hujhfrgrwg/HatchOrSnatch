"""HOS-ICON-001 (18 Oct 2026, Matthew: "generate a 2d icon for the emote crate... Take inspiration from our other icon
styles"): the Emote Crate's icon, in the family of the game's crate icons (the Weapon Crate / Dual Wield chests: a chunky
3/4-view chest, gold bands and corner brackets with rivets, a glowing gap under an open lid, an emblem plate on the
front, a dark outline). The emote one is teal with a glossy pink music note, notes and sparkles bursting from the lid.

The chest is a little 3D model (a box and a barrel-top lid opened on its back hinge) drawn in an oblique projection, at
4x and scaled down to 512 x 512 with a transparent background.

    python3 tools/build/HOS-ICON-001_emote_crate_icon.py  ->  docs/HOS-ICON-001/emote_crate_icon.png (+ _preview.png)
"""
import math
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter

S = 4  # supersampling
N = 512 * S
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "docs", "HOS-ICON-001")

INK = (28, 12, 46, 255)
CLEAR = (0, 0, 0, 0)

# ---- the model (studs-ish units) and the projection: seen from the front, a little right and above
BW, BH, BD = 262, 150, 128      # body width (x), height (y up), depth (z back)
LH = 22                         # the lid's straight front lip
LR = BD / 2                     # the barrel top's radius
OPEN = math.radians(13)         # how far the lid is open
KX, KY = 0.46, 0.20             # oblique projection: z goes right KX and up KY
OX, OY = 86, 452                # where the body's front-bottom-left corner lands (512 space)


def P(x, y, z):
    return (OX + x + z * KX, OY - y - z * KY)


def px(v):
    return int(round(v * S))


def pts(points):
    return [(px(x), px(y)) for x, y in points]


def poly_mask(points):
    m = Image.new("L", (N, N), 0)
    ImageDraw.Draw(m).polygon(pts(points), fill=255)
    return m


def hull(points):
    p = sorted(set(points))
    if len(p) < 3:
        return p

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    lower, upper = [], []
    for q in p:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], q) <= 0:
            lower.pop()
        lower.append(q)
    for q in reversed(p):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], q) <= 0:
            upper.pop()
        upper.append(q)
    return lower[:-1] + upper[:-1]


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(len(a)))


def vgrad(top, bottom, y0, y1):
    col = Image.new("RGBA", (1, N))
    for y in range(N):
        t = min(1.0, max(0.0, (y / S - y0) / max(1e-6, y1 - y0)))
        col.putpixel((0, y), lerp(top, bottom, t))
    return col.resize((N, N))


def paint(canvas, fill, mask):
    src = fill if isinstance(fill, Image.Image) else Image.new("RGBA", (N, N), fill)
    canvas.alpha_composite(Image.composite(src, Image.new("RGBA", (N, N), CLEAR), mask))


def grow(mask, r):
    return mask.filter(ImageFilter.MaxFilter(px(r) * 2 + 1))


def glow(canvas, mask, radius, color):
    paint(canvas, color, mask.filter(ImageFilter.GaussianBlur(px(radius))))


def shift(mask, dx, dy):
    return mask.transform((N, N), Image.AFFINE, (1, 0, -px(dx), 0, 1, -px(dy)), resample=Image.BILINEAR)


def top_light(mask, dy=4):
    """the thin lit edge along the top of a shape"""
    return ImageChops.subtract(mask, shift(mask, 0, dy))


# ---- the lid: a profile in (z, y) swept along x, turned open on the back hinge (z = BD, y = BH)
def lid_profile(steps=28):
    prof = [(0.0, 0.0), (0.0, LH)]
    for i in range(steps + 1):
        t = math.pi * i / steps
        prof.append((LR - LR * math.cos(t), LH + LR * math.sin(t)))
    prof.append((BD, 0.0))
    return prof


def lid_point(x, z, y):
    dz, dy = z - BD, y
    zz = dz * math.cos(OPEN) - dy * math.sin(OPEN) + BD
    yy = dy * math.cos(OPEN) - dz * math.sin(OPEN) + BH
    return P(x, yy, zz)


def note_mask(x, y, h, double=False, tilt=0.0):
    """a music note: head(s) at the bottom, stem, flag / beam. (x, y) = head centre, h = height"""
    m = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(m)
    hw, hh = h * 0.30, h * 0.22
    heads = [(x, y)] if not double else [(x, y), (x + h * 0.64, y - h * 0.16)]
    for hx, hy in heads:
        d.ellipse([px(hx - hw), px(hy - hh), px(hx + hw), px(hy + hh)], fill=255)
        sx = hx + hw * 0.80
        d.rectangle([px(sx - h * 0.08), px(hy - h * 0.95), px(sx + h * 0.02), px(hy)], fill=255)
    if double:
        (x1, y1), (x2, y2) = [(hx + hw * 0.80, hy) for hx, hy in heads]
        d.polygon(pts([(x1 - h * 0.08, y1 - h * 0.95), (x2 + h * 0.02, y2 - h * 0.95),
                       (x2 + h * 0.02, y2 - h * 0.70), (x1 - h * 0.08, y1 - h * 0.70)]), fill=255)
    else:
        sx = x + hw * 0.80
        d.polygon(pts([(sx - h * 0.02, y - h * 0.95), (sx + h * 0.38, y - h * 0.60), (sx + h * 0.30, y - h * 0.45),
                       (sx - h * 0.02, y - h * 0.68)]), fill=255)
    if tilt:
        m = m.rotate(tilt, resample=Image.BICUBIC, center=(px(x), px(y)))
    return m


def star4(cx, cy, r, thin=0.22):
    out = []
    for i in range(8):
        a = math.pi / 4 * i - math.pi / 2
        rr = r if i % 2 == 0 else r * thin
        out.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    return out


GOLD_T, GOLD_B, GOLD_EDGE = (255, 238, 150, 255), (212, 128, 16, 255), (110, 56, 6, 255)


def gold(c, mask, y0, y1, edge=2.5):
    paint(c, GOLD_EDGE, grow(mask, edge))
    paint(c, vgrad(GOLD_T, GOLD_B, y0, y1), mask)
    paint(c, (255, 252, 220, 210), top_light(mask, 4))


def rivet(c, x, y, r=6.5):
    m = Image.new("L", (N, N), 0)
    ImageDraw.Draw(m).ellipse([px(x - r), px(y - r), px(x + r), px(y + r)], fill=255)
    paint(c, GOLD_EDGE, grow(m, 1.8))
    paint(c, vgrad((255, 246, 196, 255), (196, 116, 14, 255), y - r, y + r), m)
    h = Image.new("L", (N, N), 0)
    ImageDraw.Draw(h).ellipse([px(x - r * 0.55), px(y - r * 0.7), px(x + r * 0.05), px(y - r * 0.1)], fill=255)
    paint(c, (255, 255, 255, 230), h)


def build():
    c = Image.new("RGBA", (N, N), CLEAR)

    # ---- faces of the body
    front = [P(0, 0, 0), P(BW, 0, 0), P(BW, BH, 0), P(0, BH, 0)]
    right = [P(BW, 0, 0), P(BW, 0, BD), P(BW, BH, BD), P(BW, BH, 0)]
    opening = [P(0, BH, 0), P(BW, BH, 0), P(BW, BH, BD), P(0, BH, BD)]

    # ---- the lid
    prof = lid_profile()
    left_cap = [lid_point(0, z, y) for z, y in prof]
    right_cap = [lid_point(BW, z, y) for z, y in prof]
    lid_all = hull(left_cap + right_cap)
    lip = [lid_point(0, 0, 0), lid_point(BW, 0, 0), lid_point(BW, 0, LH), lid_point(0, 0, LH)]

    body_m = ImageChops.lighter(ImageChops.lighter(poly_mask(front), poly_mask(right)), poly_mask(opening))
    lid_m = poly_mask(lid_all)
    sil = ImageChops.lighter(body_m, lid_m)

    # ---- light pouring out of the open lid, behind everything
    gx, gy = P(BW / 2, BH + 10, BD / 2)
    beams = Image.new("L", (N, N), 0)
    bd = ImageDraw.Draw(beams)
    for ang, half in ((-60, 12), (-36, 16), (-13, 19), (11, 18), (34, 15), (58, 11)):
        a = math.radians(ang - 90)
        far = 330
        x2, y2 = gx + far * math.cos(a), gy + far * math.sin(a)
        nx, ny = -math.sin(a) * half * 2.2, math.cos(a) * half * 2.2
        bd.polygon(pts([(gx - 6, gy), (gx + 6, gy), (x2 + nx, y2 + ny), (x2 - nx, y2 - ny)]), fill=255)
    rad = Image.new("L", (N, N), 0)
    for i in range(40, 0, -1):  # fade the beams out with distance from the gap
        r = 8 * i
        ImageDraw.Draw(rad).ellipse([px(gx - r), px(gy - r), px(gx + r), px(gy + r)], fill=int(255 * (1 - i / 40) ** 1.4))
    beams = ImageChops.multiply(beams.filter(ImageFilter.GaussianBlur(px(5))), rad)
    paint(c, (255, 200, 245, 235), beams)
    glow_spot = Image.new("L", (N, N), 0)
    ImageDraw.Draw(glow_spot).ellipse([px(gx - 120), px(gy - 70), px(gx + 120), px(gy + 50)], fill=255)
    glow(c, glow_spot, 40, (255, 120, 225, 190))

    # ---- soft shadow on the ground
    sh = Image.new("L", (N, N), 0)
    x0, y0 = P(-20, 0, 0)
    x1, y1 = P(BW + 30, 0, BD)
    ImageDraw.Draw(sh).ellipse([px(x0), px(y1 - 8), px(x1), px(y0 + 22)], fill=170)
    paint(c, (22, 6, 40, 255), sh.filter(ImageFilter.GaussianBlur(px(12))))

    # ---- the dark outline (drawn first: the faces cover all but the rim)
    paint(c, INK, grow(sil, 7))

    # ---- inside the chest: white-hot at the back, hot pink toward the front edge
    paint(c, vgrad((255, 255, 255, 255), (255, 120, 214, 255), opening[3][1], opening[0][1] + 4), poly_mask(opening))

    # ---- body faces
    TEAL_T, TEAL_B = (52, 214, 222, 255), (12, 92, 142, 255)
    paint(c, vgrad(TEAL_T, TEAL_B, front[3][1], front[0][1]), poly_mask(front))
    paint(c, vgrad((22, 140, 168, 255), (8, 58, 98, 255), right[3][1], right[0][1]), poly_mask(right))
    # planks
    for yy in (BH * 0.36, BH * 0.68):
        m = Image.new("L", (N, N), 0)
        dd = ImageDraw.Draw(m)
        dd.line(pts([P(0, yy, 0), P(BW, yy, 0)]), fill=255, width=px(3))
        dd.line(pts([P(BW, yy, 0), P(BW, yy, BD)]), fill=255, width=px(3))
        paint(c, (4, 46, 80, 170), ImageChops.multiply(m, body_m))
    # the light from the gap spilling down the top of the front face
    spill = poly_mask([P(30, BH, 0), P(BW - 30, BH, 0), P(BW - 30, BH - 40, 0), P(30, BH - 40, 0)])
    paint(c, (255, 140, 230, 60), spill.filter(ImageFilter.GaussianBlur(px(14))))
    # a soft sheen down the front-left
    sheen = poly_mask([P(34, BH - 30, 0), P(70, BH - 30, 0), P(52, 30, 0), P(34, 30, 0)])
    paint(c, (190, 255, 255, 60), sheen.filter(ImageFilter.GaussianBlur(px(7))))

    # ---- body gold: corner bands, bottom and top bands
    for xa, xb in ((-4, 26), (BW - 26, BW + 2)):
        m = poly_mask([P(xa, -3, 0), P(xb, -3, 0), P(xb, BH + 2, 0), P(xa, BH + 2, 0)])
        gold(c, m, P(0, BH, 0)[1], P(0, 0, 0)[1])
    m = poly_mask([P(BW, -3, BD - 24), P(BW, -3, BD + 2), P(BW, BH + 2, BD + 2), P(BW, BH + 2, BD - 24)])
    gold(c, m, P(BW, BH, BD)[1], P(BW, 0, BD)[1])
    for ya, yb in ((-4, 22), (BH - 18, BH + 2)):
        m = ImageChops.lighter(poly_mask([P(-4, ya, 0), P(BW + 2, ya, 0), P(BW + 2, yb, 0), P(-4, yb, 0)]),
                               poly_mask([P(BW, ya, 0), P(BW, ya, BD + 2), P(BW, yb, BD + 2), P(BW, yb, 0)]))
        gold(c, m, P(0, yb, 0)[1] - 6, P(0, ya, 0)[1])
    for x, y, z in ((10, 10, 0), (BW - 12, 10, 0), (10, BH - 30, 0), (BW - 12, BH - 30, 0), (BW, 10, BD - 10),
                    (BW, BH - 30, BD - 10), (BW * 0.33, 8, 0), (BW * 0.67, 8, 0), (10, BH - 8, 0), (BW - 12, BH - 8, 0)):
        rivet(c, *P(x, y, z))

    # ---- the emblem: a gold shield with a glossy pink double note
    ex, ey = P(BW / 2, BH * 0.46, 0)
    shield = [(ex - 52, ey - 60), (ex + 52, ey - 60), (ex + 52, ey + 6), (ex, ey + 62), (ex - 52, ey + 6)]
    gold(c, poly_mask(shield), ey - 60, ey + 62, edge=3.5)
    inner = [(ex - 41, ey - 49), (ex + 41, ey - 49), (ex + 41, ey + 2), (ex, ey + 47), (ex - 41, ey + 2)]
    paint(c, vgrad((78, 26, 120, 255), (34, 8, 62, 255), ey - 49, ey + 47), poly_mask(inner))
    # sized to sit inside the purple (Matthew 18 Oct: "fit the tune note inside the purple")
    note = note_mask(ex - 12, ey + 6, 38, double=True, tilt=-6)
    glow(c, note, 6, (255, 80, 210, 200))
    paint(c, (110, 8, 84, 255), grow(note, 2.6))
    paint(c, vgrad((255, 176, 242, 255), (232, 36, 168, 255), ey - 32, ey + 16), note)
    paint(c, (255, 240, 255, 210), ImageChops.subtract(note, shift(note, 3, 4)))

    # ---- the lid: barrel top, right end cap, front lip, gold end bands
    lid_top = ImageChops.subtract(lid_m, poly_mask(right_cap))
    ly0 = min(p[1] for p in lid_all)
    ly1 = max(p[1] for p in lid_all)
    paint(c, vgrad((70, 228, 232, 255), (16, 118, 160, 255), ly0, ly1), lid_m)
    paint(c, vgrad((26, 150, 176, 255), (10, 74, 112, 255), ly0, ly1), poly_mask(right_cap))
    # a highlight along the barrel's crest
    crest = [lid_point(x, LR - LR * math.cos(t), LH + LR * math.sin(t)) for x, t in ((8, 0.9), (BW - 30, 0.9))]
    crest2 = [lid_point(x, LR - LR * math.cos(t), LH + LR * math.sin(t)) for x, t in ((BW - 30, 1.5), (8, 1.5))]
    paint(c, (220, 255, 255, 110), poly_mask(crest + crest2).filter(ImageFilter.GaussianBlur(px(4))))
    gold(c, poly_mask(lip), lip[3][1], lip[0][1], edge=2)
    inner_lip = [lid_point(28, 0, 5), lid_point(BW - 28, 0, 5), lid_point(BW - 28, 0, LH - 5), lid_point(28, 0, LH - 5)]
    paint(c, (16, 110, 150, 255), poly_mask(inner_lip))
    for xa, xb in ((0, 26), (BW - 26, BW)):
        band = hull([lid_point(xa, z, y) for z, y in prof] + [lid_point(xb, z, y) for z, y in prof])
        gold(c, poly_mask(band), ly0, ly1)
    # the right end cap's own rim
    paint(c, GOLD_EDGE, ImageChops.subtract(grow(poly_mask(right_cap), 1.5), poly_mask(right_cap)))
    for x, z, y in ((13, 0, LH / 2), (BW - 13, 0, LH / 2)):
        rivet(c, *lid_point(x, z, y))

    # ---- the light spilling out of the gap, over the lid's lip and the body's top edge
    gap = poly_mask([P(20, BH, 0), P(BW - 20, BH, 0), lid_point(BW - 20, 0, 0), lid_point(20, 0, 0)])
    glow(c, gap, 14, (255, 150, 230, 170))

    # ---- outline again over the lid / body seam so the parts read separately
    seam = ImageChops.subtract(grow(lid_m, 2.5), lid_m)
    paint(c, (28, 12, 46, 200), ImageChops.multiply(seam, body_m))

    # ---- notes and sparkles bursting out
    for (x, y, h, dbl, tilt, col) in ((138, 136, 66, False, 16, ((130, 246, 255), (18, 168, 222))),
                                      (330, 104, 76, True, -12, ((255, 182, 242), (230, 36, 168))),
                                      (238, 62, 50, False, 4, ((255, 238, 140), (238, 150, 14)))):
        m = note_mask(x, y, h, double=dbl, tilt=tilt)
        glow(c, m, 12, col[0] + (170,))
        paint(c, INK, grow(m, 4.5))
        paint(c, vgrad(col[0] + (255,), col[1] + (255,), y - h, y + h * 0.3), m)
        paint(c, (255, 255, 255, 200), ImageChops.subtract(m, shift(m, 3, 4)))
    for x, y, r in ((86, 210, 26), (430, 170, 30), (396, 46, 18), (60, 320, 14), (466, 330, 16), (192, 30, 13)):
        m = poly_mask(star4(x, y, r))
        glow(c, m, 8, (255, 230, 255, 210))
        paint(c, (255, 255, 255, 255), m)

    return c.resize((512, 512), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    icon = build()
    path = os.path.join(OUT, "emote_crate_icon.png")
    icon.save(path)
    sheet = Image.new("RGBA", (1200, 560), (34, 26, 44, 255))
    ImageDraw.Draw(sheet).rectangle([600, 0, 1200, 560], fill=(120, 70, 170, 255))
    sheet.alpha_composite(icon, (44, 24))
    sheet.alpha_composite(icon.resize((228, 228), Image.LANCZOS), (640, 30))
    sheet.alpha_composite(icon.resize((98, 98), Image.LANCZOS), (900, 60))
    sheet.alpha_composite(icon.resize((60, 60), Image.LANCZOS), (1040, 80))
    sheet.save(os.path.join(OUT, "emote_crate_icon_preview.png"))
    print("wrote", path)


if __name__ == "__main__":
    main()
