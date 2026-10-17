"""HOS-EGG-002: write only the egg export pages (egg_x_*.html) with UI_EXPORT=1, leaving every other page as is.
Run from anywhere: python docs/HOS-EGG-002/tools/build_egg_export.py"""
import os
import sys

UI = r'C:\HatchOrSnatch\ui'
os.environ['UI_EXPORT'] = '1'
sys.path.insert(0, UI)
import build  # noqa: E402

for fname, fn, h in build.EGG_EXPORT:
    with open(os.path.join(UI, fname), 'w', encoding='utf-8') as f:
        f.write(build.page(fname[:-5], fn(), h))
    print('wrote', fname)
