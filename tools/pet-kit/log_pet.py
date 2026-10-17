"""After a pet install: log its uploads in docs/VFX-LEDGER.md (from Assets/asset_ids.json), mark it done in the
HOS-PET-011 build order, link its README from the Home note, and copy its new scripts into ScriptHistory.
usage: python log_pet.py <docs slug> <Key> "<Species>" <ticket> "<archetype, rarity>"
"""
import json, os, re, shutil, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
slug, key, species, ticket, arch = sys.argv[1:6]
ids = json.load(open(os.path.join(ROOT, 'Assets', 'asset_ids.json')))
pref = 'docs/pets/%s/build/' % slug
kinds = [('Pet.fbx', 'model (FBX)'), ('FaceEmit', 'face emissive'), ('Face', 'face decal'), ('Emit', 'emissive mask'),
         ('Normal', 'normal map'), ('Roughness', 'roughness map'), ('Color', 'colour map')]
rows = []
for path, v in ids.items():
    if path.startswith(pref) and v.get('assetId'):
        base = os.path.basename(path)
        kind = next(k for s, k in kinds if s in base)
        rows.append("| %s (17 Oct) | `%s` | {'assetId': '%s'} | %s |\n" % (species, base, v['assetId'], kind))
led = os.path.join(ROOT, 'docs', 'VFX-LEDGER.md')
s = open(led, encoding='utf8').read()
if '| %s (17 Oct) |' % species not in s:
    open(led, 'w', encoding='utf8').write(s.rstrip('\n') + '\n' + ''.join(rows))
inv = os.path.join(ROOT, 'docs', 'HOS-PET-011 Pet Inventory.md')
s = open(inv, encoding='utf8').read()
s = re.sub(r'(\| \d+ \| %s \| [^|]+\|) *\|' % re.escape(species), r'\1 done (%s, installed; docs/pets/%s) |' % (ticket, slug), s)
open(inv, 'w', encoding='utf8').write(s)
home = os.path.join(ROOT, 'Hatch or Snatch Home.md')
s = open(home, encoding='utf8').read()
if 'pets/%s/' % slug not in s:
    i = s.index('- Riot Hound (HOS-PET-020')
    s = s[:i] + '- %s (%s, %s, installed 17 Oct): `docs/pets/%s/README.md`.\n' % (species, ticket, arch, slug) + s[i:]
    open(home, 'w', encoding='utf8').write(s)
rb = os.path.join(ROOT, 'docs', 'pets', slug, 'roblox')
shutil.copy(os.path.join(rb, key + 'Pet.luau'), os.path.join(ROOT, 'ScriptHistory', 'StarterPlayer', 'StarterPlayerScripts',
                                                         'EOS', 'Controllers', key + 'Pet.lua'))
shutil.copy(os.path.join(rb, key + 'Anims.luau'), os.path.join(ROOT, 'ScriptHistory', 'ReplicatedStorage', 'EOS', 'Shared',
                                                           'PetRig', key + 'Anims.lua'))
print('logged', species, len(rows), 'uploads')
