"""Side-by-side effect clip from edit-mode stage frames (L1 left, L3 right).
usage: python make_clip.py frames.json out.mp4 [stills_dir]
frames.json: [[path, "label"], ...] in play order. Each frame is cropped to the stage centre, labelled, and held for
a few video frames so the step-frozen moments read on a phone."""
import json, os, subprocess, sys, tempfile
from PIL import Image, ImageDraw

frames = json.load(open(sys.argv[1]))
out = sys.argv[2]
tmp = tempfile.mkdtemp()
n = 0
W, H = 1280, 560
for path, label in frames:
    im = Image.open(path).convert('RGB')
    w, h = im.size
    cx, cy = w // 2, int(h * 0.55)
    box = (max(0, cx - 760), max(0, cy - 300), min(w, cx + 760), min(h, cy + 360))
    im = im.crop(box).resize((W, H))
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, W, 34), fill=(14, 10, 20))
    d.text((12, 10), label, fill=(240, 232, 255))
    for xx, t in ((W * 0.33, 'L1'), (W * 0.67, 'L3')):
        d.rectangle((xx - 22, H - 34, xx + 22, H - 8), fill=(14, 10, 20))
        d.text((xx - 7, H - 28), t, fill=(255, 255, 255))
    for _ in range(6):
        im.save(os.path.join(tmp, 'f%04d.png' % n))
        n += 1
subprocess.check_call(['ffmpeg', '-y', '-loglevel', 'error', '-framerate', '12', '-i', os.path.join(tmp, 'f%04d.png'),
                       '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '22', out])
print('clip', out, n, 'frames')
