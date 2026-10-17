# Previews + checks for the Thunder Toad module (pet-kit section 4/5): writes out/turn_L1..3.png, head.png, anims.png,
# atlas/face PNGs, report.json and vs_card.png (L1 3/4 beside Hunter's Tempest card).
import json, math, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE); sys.path.insert(0, os.path.dirname(HERE))
import numpy as np
from PIL import Image
import petkit as K
import kview
import imp as T

OUT = os.path.join(HERE, 'out')
os.makedirs(OUT, exist_ok=True)
CARD = os.path.abspath(os.path.join(HERE, '..', '..', '..', 'docs', 'pets', 'concepts', 'ring_imp_card.png'))

bones = T.bones_def()
mb = T.build()
rest = K.skin(mb, bones, {})
rep = mb.report()
rep['bones'] = len(bones)
rep['open_edges_body'] = mb.open_edges(0)
Vv = np.array(rest)
rep['bbox_min'] = Vv.min(0).round(3).tolist()
rep['bbox_max'] = Vv.max(0).round(3).tolist()
by_level = {1: [0, 1], 2: [0, 1, 2], 3: [0, 1, 2, 3]}
rep['tris_per_level'] = {lv: sum(mb.tri_count(m) for m in mats) for lv, mats in by_level.items()}

texs = {}
for lv in (1, 2, 3):
    col, hgt, rgh = T.paint_atlas(lv)
    face = T.face_texture(lv)
    K.save_png(os.path.join(OUT, 'atlas_L%d.png' % lv), col)
    K.save_png(os.path.join(OUT, 'face_L%d.png' % lv), face)
    if lv == 1:
        K.save_png(os.path.join(OUT, 'glow_L1.png'), T.emissive_mask(1))
    tex = {0: col, 1: face, 2: col, 3: col}
    texs[lv] = tex
    kview.lit_turnaround(mb, rest, tex, os.path.join(OUT, 'turn_L%d.png' % lv), mats=set(by_level[lv]))

# head close-up (3/4 front, zoomed on the head)
ctr = np.array([0, -0.3, 1.1])
im = kview.lit_render(mb, rest, texs[1], -30, 12, size=520, scale=300, center=ctr, mats={0, 1})
im.save(os.path.join(OUT, 'head.png'))
# hero 3/4 beside the card
hero = kview.lit_render(mb, rest, texs[1], -40, 14, size=560, mats={0, 1})
if os.path.exists(CARD):
    card = Image.open(CARD).convert('RGB')
    kview.with_ref(hero, ref=None, label='card', height=None) if False else None
    h = hero.size[1]
    card = card.resize((int(card.size[0] * h / card.size[1]), h))
    out = Image.new('RGB', (hero.size[0] + card.size[0], h), (255, 255, 255))
    out.paste(hero, (0, 0)); out.paste(card, (hero.size[0], 0))
    out.save(os.path.join(OUT, 'vs_card.png'))

# anim sheet: each anim at 5 frames, side + 3/4
imgs, labels = [], []
ext = np.ptp(Vv, axis=0).max()
for name, fn in T.ANIMS.items():
    a = fn()
    for f in np.linspace(0, a['frames'], 5)[:-1] if a['loop'] else np.linspace(0, a['frames'], 4):
        pose = K.interp_pose(a, f)
        vv = K.skin(mb, bones, pose)
        imgs.append(kview.lit_render(mb, vv, texs[1], -60, 10, size=240, scale=240 * 0.75 / ext, center=(Vv.min(0) + Vv.max(0)) / 2 + np.array([0, 0, 0.1]), mats={0, 1}))
        labels.append('%s %d' % (name, int(f)))
K.sheet(imgs, 4, labels).save(os.path.join(OUT, 'anims.png'))

# ---------------- checks
body_parts = {'body'}
body_tris = K.tris_of(mb, body_parts)
issues = []
# weights
for i, w in enumerate(mb.W):
    if not w or len(w) > 4 or abs(sum(w.values()) - 1) > 1e-3:
        issues.append('weights v%d' % i)
        break
# lowest point
rep['lowest_z'] = float(Vv[:, 2].min())
if rep['lowest_z'] < -0.02:
    issues.append('below ground %.3f' % rep['lowest_z'])
# clipping: leg/foot/pad vertices that end up inside the body loft in any frame (ray parity test, sampled)
def inside(p, tris):
    hits = 0
    o = np.asarray(p, float)
    d = K.nrm(np.array([0.13, 0.27, 0.95]))
    v0, v1, v2 = tris[:, 0], tris[:, 1], tris[:, 2]
    e1, e2 = v1 - v0, v2 - v0
    pp = np.cross(d, e2); det = np.einsum('ij,ij->i', e1, pp)
    ok = np.abs(det) > 1e-12
    inv = np.where(ok, 1 / np.where(ok, det, 1), 0)
    tv = o - v0; uu = np.einsum('ij,ij->i', tv, pp) * inv
    q = np.cross(tv, e1); vv2 = np.einsum('j,ij->i', d, q) * inv
    t = np.einsum('ij,ij->i', e2, q) * inv
    return int((ok & (uu >= 0) & (vv2 >= 0) & (uu + vv2 <= 1) & (t > 0)).sum()) % 2 == 1
pad_idx = sorted({v for f, p in zip(mb.F, mb.PART) if p in ('spade', 'ring') for v in f})
foot_tip_idx = pad_idx[::5]
clip = []
for name, fn in T.ANIMS.items():
    a = fn()
    for f in range(0, a['frames'] + 1, 2):
        vv = K.skin(mb, bones, K.interp_pose(a, f))
        btris = np.array([[vv[fc[0]], vv[fc[t]], vv[fc[t + 1]]] for fc, p in zip(mb.F, mb.PART) if p == 'body'
                          for t in range(1, len(fc) - 1)])
        n_in = sum(1 for i in foot_tip_idx if inside(vv[i], btris))
        if n_in:
            clip.append('%s f%d: %d toe verts inside body' % (name, f, n_in))
rep['clip'] = clip[:12]
rep['issues'] = issues
json.dump(rep, open(os.path.join(OUT, 'report.json'), 'w'), indent=1)
print(json.dumps({k: rep[k] for k in ('total', 'by_mat', 'tris_per_level', 'bones', 'lowest_z', 'issues', 'open_edges_body')}))
print('clip:', clip[:6])
