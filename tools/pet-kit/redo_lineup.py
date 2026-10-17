"""HOS-PET-REDO review sheets: before -> after (L1) plus the three new levels per pet, and a short anim clip.
usage: python redo_lineup.py <out.jpg> <out.mp4|-> <slug:Label> [<slug:Label> ...] [--l1only]
Before renders come from docs/backups/HOS-PET-REDO_20261017/<slug>_previews_old (moved there by redo_build.sh)."""
import os, subprocess, sys, tempfile
from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
BK = os.path.join(ROOT, 'docs', 'backups', 'HOS-PET-REDO_20261017')
args = [a for a in sys.argv[1:] if not a.startswith('--')]
l1only = '--l1only' in sys.argv
out_img, out_mp4, pets = args[0], args[1], [a.split(':', 1) for a in args[2:]]
T = 300
BG, FG, OK = (14, 18, 32), (235, 235, 255), (150, 230, 160)
cols = 2 if l1only else 4
per_row = 4 if l1only else 1
rows = (len(pets) + per_row - 1) // per_row
W = cols * T * per_row
sheet = Image.new('RGB', (W, rows * (T + 30) + 40), BG)
d = ImageDraw.Draw(sheet)
d.text((10, 12), 'Redo: before -> after' + (' (L1)' if l1only else ' (L1, then the three new levels)'), fill=FG)
for i, (slug, label) in enumerate(pets):
    r, c = divmod(i, per_row)
    x0, y0 = c * cols * T, 40 + r * (T + 30)
    new = os.path.join(ROOT, 'docs', 'pets', slug, 'previews_pass1')
    old = os.path.join(BK, slug + '_previews_old')
    tiles = [(label + ': before', os.path.join(old, 'bl_L1_card_angle.png'), FG),
             ('after L1', os.path.join(new, 'bl_L1_card_angle.png'), OK)]
    if not l1only:
        tiles += [('after L2', os.path.join(new, 'bl_L2_card_angle.png'), OK), ('after L3', os.path.join(new, 'bl_L3_card_angle.png'), OK)]
    for j, (lab, p, colr) in enumerate(tiles):
        if os.path.exists(p):
            sheet.paste(Image.open(p).convert('RGB').resize((T, T)), (x0 + j * T, y0 + 22))
        d.text((x0 + j * T + 6, y0 + 6), lab, fill=colr)
sheet.save(out_img, quality=88)
print('sheet', out_img, sheet.size)
if out_mp4 != '-':
    lst = tempfile.NamedTemporaryFile('w', suffix='.txt', delete=False)
    for slug, _ in pets:
        p = os.path.join(ROOT, 'docs', 'pets', slug, 'anims_pass1', slug + '_anims.mp4')
        if os.path.exists(p):
            tmp = os.path.join(tempfile.gettempdir(), 'redo_%s.mp4' % slug)
            subprocess.check_call(['ffmpeg', '-y', '-loglevel', 'error', '-i', p, '-t', os.environ.get('REDO_CLIP_SECS', '7'), '-vf', 'scale=480:-2',
                                   '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '24', '-an', tmp])
            lst.write("file '%s'\n" % tmp.replace('\\', '/'))
    lst.close()
    subprocess.check_call(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'concat', '-safe', '0', '-i', lst.name, '-c', 'copy', out_mp4])
    print('clip', out_mp4, os.path.getsize(out_mp4))
