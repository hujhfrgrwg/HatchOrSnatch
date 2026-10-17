"""Level sheet, card comparison and the labelled animation MP4 for a pet's review.
usage: python make_sheets.py <docs slug> "<Species>" "<L2 name>" "<L3 name>" "<Clip:Label,...>"
"""
import glob, os, subprocess, sys
from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
slug, species, n2, n3, clips = sys.argv[1:6]
D = os.path.join(ROOT, 'docs', 'pets', slug)
P = os.path.join(D, 'previews_pass1')
W = 600
ims = [('L1', 'bl_L1_card_angle.png'), ('L2 ' + n2, 'bl_L2_card_angle.png'), ('L3 ' + n3, 'bl_L3_card_angle.png')]
sheet = Image.new('RGB', (W * 3, W + 40), (14, 18, 32))
d = ImageDraw.Draw(sheet)
for i, (lab, f) in enumerate(ims):
    sheet.paste(Image.open(os.path.join(P, f)).convert('RGB').resize((W, W)), (i * W, 40))
    d.text((i * W + 12, 12), lab, fill=(235, 235, 255))
sheet.save(os.path.join(D, slug + '_levels.jpg'), quality=88)
cp = os.path.join(D, slug + '_card.png')
if not os.path.exists(cp):   # no concept card (pets built from a brief): use the L1 front render in its place
    cp = os.path.join(P, 'bl_L1_front.png')
card = Image.open(cp).convert('RGB')
card = card.resize((int(card.size[0] * W / card.size[1]), W))
r = [Image.open(os.path.join(P, f)).convert('RGB').resize((W, W)) for f in ('bl_L1_side.png', 'bl_L1_head.png')]
s2 = Image.new('RGB', (card.size[0] + W * 2, W), (14, 18, 32))
s2.paste(card, (0, 0)); s2.paste(r[0], (card.size[0], 0)); s2.paste(r[1], (card.size[0] + W, 0))
s2.save(os.path.join(D, slug + '_vs_card.jpg'), quality=88)
A = os.path.join(D, 'anims_pass1')
if os.path.exists(os.path.join(A, 'frames.txt')):
    rows = {l.split('|')[0]: l.rstrip('\n').split('|')[2].split(';') for l in open(os.path.join(A, 'frames.txt'))}
    cl = os.path.join(A, '_clip')
    os.makedirs(cl, exist_ok=True)
    for f in glob.glob(os.path.join(cl, '*.png')):
        os.remove(f)
    n = 0
    for item in clips.split(','):
        k, lab = item.split(':')
        paths = rows.get(k, [])
        reps = 1 if len(paths) > 40 else (3 if k not in ('Walk', 'Run') else 2)
        for _ in range(reps):
            for p in paths:
                im = Image.open(p).convert('RGB')
                dd = ImageDraw.Draw(im)
                dd.rectangle((0, 0, im.size[0], 26), fill=(10, 12, 24))
                dd.text((8, 7), '%s L3 - %s' % (species, lab), fill=(235, 235, 255))
                im.save(os.path.join(cl, 'f%04d.png' % n)); n += 1
    subprocess.check_call(['ffmpeg', '-y', '-loglevel', 'error', '-framerate', '24', '-i', os.path.join(cl, 'f%04d.png'),
                           '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '20', os.path.join(A, slug + '_anims.mp4')])
print('sheets done')
