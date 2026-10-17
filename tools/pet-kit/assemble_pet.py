"""Assemble a pet module from a source with markers, pulling shared helper blocks from hound/hound.py so every
quadruped module stays self-contained (the Blender build embeds one file).
Markers on their own line: #@helpers  #@shell  #@paint_helpers  #@seg  #@animh  #@gait
usage: python assemble_pet.py <src.py> <out.py>"""
import os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
L = open(os.path.join(HERE, 'hound', 'hound.py'), encoding='utf8').read().split('\n')


def block(start, end):
    a = next(i for i, l in enumerate(L) if l.startswith(start))
    b = next(i for i, l in enumerate(L) if i > a and l.startswith(end))
    return '\n'.join(L[a:b]).rstrip() + '\n'


PARTS = {
    '#@helpers': block('def _cum', 'FX, FZ, FZH'),
    '#@shell': block('def _vnormals', 'def build'),
    '#@paint_helpers': block('def _saw', 'def _navy'),
    '#@seg': block('def _seg', 'def _face_layers'),
    '#@animh': block('def _ease', 'def anim_idle'),
    '#@gait': block('def _gait', 'def anim_walk'),
}
src, out = sys.argv[1], sys.argv[2]
lines = []
for l in open(src, encoding='utf8').read().split('\n'):
    lines.append(PARTS[l.strip()] if l.strip() in PARTS else l)
open(out, 'w', encoding='utf8').write('\n'.join(lines))
print('assembled', out)
