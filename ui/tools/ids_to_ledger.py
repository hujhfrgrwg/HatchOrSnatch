#!/usr/bin/env python3
"""Turn Hunter's upload results (Assets/asset_ids.json from tools/upload/upload_ui.ps1) into the
roblox-ui-maker ledger (ui/rbx/out/uploaded.json): Assets/UI/icons/<slug>.png -> icon:<slug>,
Assets/UI/art/<key>.png -> art:<key>.
Open Cloud "Decal" uploads return DECAL ids; ImageLabels need the IMAGE id. Studio resolves them
(tools/resolve_images.luau prints decal=image pairs); pass that output file with --resolved to use them.
    python3 tools/ids_to_ledger.py [--resolved resolved.txt]
Then: python3 $SK/scripts/assets.py && python3 $SK/scripts/bundle.py"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..', '..')
ids = json.load(open(os.path.join(ROOT, 'Assets', 'asset_ids.json')))
resolved = {}
if '--resolved' in sys.argv:
    for line in open(sys.argv[sys.argv.index('--resolved') + 1]):
        if '=' in line:
            d, i = line.strip().split('=', 1)
            if i:
                resolved[d] = i
led_p = os.path.join(HERE, '..', 'rbx', 'out', 'uploaded.json')
led = json.load(open(led_p)) if os.path.exists(led_p) else {}
n = pending = 0
for path, e in ids.items():
    if not path.startswith('Assets/UI/'):
        continue
    aid = str(e.get('assetId') or '')
    if not aid:
        pending += 1
        continue
    aid = resolved.get(aid, aid)
    stem = os.path.splitext(os.path.basename(path))[0]
    key = ('icon:' if '/icons/' in path else 'art:') + stem
    led[key] = 'rbxassetid://' + aid
    n += 1
# re-exports that only re-raster an image (headless noise, mean diff < 0.1/255) reuse the uploaded id
# instead of a new upload; a6f725533cd is the close button re-exported without its corner tabs (16 Oct)
ALIAS = {'art:a0f5b258ae1': 'art:a9256f992b1', 'art:a176585b5fb': 'art:a0d93acb115', 'art:af3958efa26': 'art:acc69c05fca',
         'art:a6f725533cd': 'art:close_clean'}
for new, old in ALIAS.items():
    if old in led:
        led[new] = led[old]
os.makedirs(os.path.dirname(led_p), exist_ok=True)
json.dump(led, open(led_p, 'w'), indent=1, sort_keys=True)
print(f'{n} ids -> {led_p}; {pending} still processing; {len(resolved)} decal ids swapped for image ids')
