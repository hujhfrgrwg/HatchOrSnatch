"""Write a ground-walker pet controller (<Key>Pet.luau) and the .rbxmx import files for it and its <Key>Anims, from the
Crystal Warden's controller (docs/pets/crystal_warden/roblox/WardenPet.luau) as the template.
usage: python make_controller.py <module> <Key> "<Species>" <out dir> <catcher clip> <flash_at> <summon_scale> "<header text>"
"""
import os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
mod, key, species, out, cclip, flash, sscale, header = sys.argv[1:9]
os.makedirs(out, exist_ok=True)
src = open(os.path.join(ROOT, 'docs', 'pets', 'crystal_warden', 'roblox', 'WardenPet.luau'), encoding='utf8').read()
body = src[src.index('local Players'):]
body = (body.replace('WardenPet', key + 'Pet').replace('"Crystal Warden"', '"%s"' % species)
        .replace('EOS_WardenSummon', 'EOS_%sSummon' % key).replace('WardenSummon_L', '%sSummon_L' % key)
        .replace('then "Reach" else "Ability"', 'then "%s" else "Ability"' % cclip)
        .replace('%sPet.FLASH_AT = 0.4 -- seconds in: the paws slam (Shield) / the jaw opens (Reach)' % key,
                 '%sPet.FLASH_AT = %s -- seconds in: the cast peaks' % (key, flash))
        .replace('%sPet.SUMMON_SCALE = 1.3' % key, '%sPet.SUMMON_SCALE = %s' % (key, sscale)))
head = '--!strict\n' + ''.join('-- ' + l + '\n' for l in header.split('\\n')) + '\n'
open(os.path.join(out, key + 'Pet.luau'), 'w', encoding='utf8').write(head + body)
subprocess.check_call([sys.executable, os.path.join(HERE, 'export_pet_anims.py'), mod,
                       os.path.join(out, key + 'Anims.luau'), key + 'Anims'], cwd=HERE)
for name in (key + 'Pet', key + 'Anims'):
    s = open(os.path.join(out, name + '.luau'), encoding='utf8').read()
    open(os.path.join(out, name + '.rbxmx'), 'w', encoding='utf8').write(
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" version="4">\n<Item class="ModuleScript" referent="RBX0">\n'
        '<Properties>\n<string name="Name">%s</string>\n<ProtectedString name="Source"><![CDATA[%s]]></ProtectedString>\n'
        '</Properties>\n</Item>\n</roblox>\n' % (name, s))
print('wrote', key + 'Pet', key + 'Anims')
