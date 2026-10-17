"""Write a floating / flying pet controller (<Key>Pet.luau, the Ghost / Moth / Tengu hover follower) and the .rbxmx
import files for it and its <Key>Anims, from the Eclipse Tengu's controller (docs/pets/eclipse_tengu/roblox/TenguPet.luau).
usage: python make_float_controller.py <module> <Key> "<Species>" <out dir> <catcher clip> <flash_at> "<runner fx>" "<catcher fx>" "<header>"
  fx names get the level appended (e.g. WraithVanish_L -> WraithVanish_L3)."""
import os, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
mod, key, species, out, cclip, flash, rfx, cfx, header = sys.argv[1:10]
os.makedirs(out, exist_ok=True)
src = open(os.path.join(ROOT, 'docs', 'pets', 'eclipse_tengu', 'roblox', 'TenguPet.luau'), encoding='utf8').read()
body = src[src.index('local Players'):]
rep = [('local fx = "TenguSummon_L" .. level', 'local fx = (if catcher then "%s" else "%s") .. level' % (cfx, rfx)),
       ('then "Snare" else "Ability"', 'then "%s" else "Ability"' % cclip),
       ('TenguPet.FLASH_AT = 0.45 -- seconds in: the clone splits off (Fake Clone) / the talons stamp (Snare)',
        'TenguPet.FLASH_AT = %s -- seconds in: the cast peaks' % flash),
       ('"Eclipse Tengu"', '"%s"' % species), ('EOS_TenguSummon', 'EOS_%sSummon' % key), ('TenguPet', key + 'Pet')]
for a, b in rep:
    assert a in body, a
    body = body.replace(a, b)
head = '--!strict\n' + ''.join('-- ' + l + '\n' for l in header.split('\n')) + '\n'
open(os.path.join(out, key + 'Pet.luau'), 'w', encoding='utf8').write(head + body)
subprocess.check_call([sys.executable, os.path.join(HERE, 'export_pet_anims.py'), mod, os.path.join(out, key + 'Anims.luau'), key + 'Anims'], cwd=HERE)
for name in (key + 'Pet', key + 'Anims'):
    s = open(os.path.join(out, name + '.luau'), encoding='utf8').read()
    open(os.path.join(out, name + '.rbxmx'), 'w', encoding='utf8').write(
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" version="4">\n<Item class="ModuleScript" referent="RBX0">\n'
        '<Properties>\n<string name="Name">%s</string>\n<ProtectedString name="Source"><![CDATA[%s]]></ProtectedString>\n'
        '</Properties>\n</Item>\n</roblox>\n' % (name, s))
print('wrote', key + 'Pet', key + 'Anims')
