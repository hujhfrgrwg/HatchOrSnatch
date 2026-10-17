#!/usr/bin/env python3
"""Downloads the ui-resources.com textures this UI uses into ui/tex/ as real PNGs.
The files are not committed (ui-resources asks not to redistribute downloads; credit stays on the site).
Sources and creator credits: tools/textures.json. Run from ui/: python3 tools/fetch_textures.py"""
import io, json, os, ssl, urllib.request
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__)); OUT = os.path.join(HERE, '..', 'tex'); os.makedirs(OUT, exist_ok=True)
ca = '/root/.ccr/ca-bundle.crt'; ctx = ssl.create_default_context(cafile=ca) if os.path.exists(ca) else None
for name, s in json.load(open(os.path.join(HERE, 'textures.json'))).items():
    dst = os.path.join(OUT, name + '.png')
    if os.path.exists(dst): continue
    data = urllib.request.urlopen(urllib.request.Request(s['url'], headers={'User-Agent': 'Mozilla/5.0'}), context=ctx, timeout=60).read()
    Image.open(io.BytesIO(data)).convert('RGBA').save(dst)   # many are WebP named .png; Roblox needs real PNG
    print('saved', name)
