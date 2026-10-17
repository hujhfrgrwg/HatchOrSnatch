"""Print a pet's uploaded ids as a Luau table for _G.HOS_FullInstall. usage: python ids_lua.py <docs slug> <Prefix>"""
import json, os, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
slug, pre = sys.argv[1:3]
ids = json.load(open(os.path.join(ROOT, 'Assets', 'asset_ids.json')))
b = 'docs/pets/%s/build/%s/%s_' % (slug, pre.lower(), pre)
m = {'fbx': 'Pet.fbx', 'c1': 'Color.png', 'c2': 'Color_L2.png', 'c3': 'Color_L3.png', 'n': 'Normal.png', 'r': 'Roughness.png',
     'e1': 'Emit.png', 'e2': 'Emit_L2.png', 'e3': 'Emit_L3.png', 'f1': 'Face.png', 'f2': 'Face_L2.png', 'f3': 'Face_L3.png',
     'fe1': 'FaceEmit.png', 'fe2': 'FaceEmit_L2.png', 'fe3': 'FaceEmit_L3.png'}
print('{' + ','.join('%s=%s' % (k, ids[b + v]['assetId']) for k, v in m.items()) + '}')
