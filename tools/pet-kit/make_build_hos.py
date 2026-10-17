"""HOS copy of make_build.py: same, but embeds pet_blender_hos.py (headless Blender + emissive masks).
Writes build/<pet>_build.py: a single self-contained script for Blender's Python console
(petkit + the pet module embedded as base64 modules, then pet_blender.py).

usage (from the pet-kit folder):
    python3 make_build.py mypet/mypet.py [other/other.py ...] [--save-root "C:\\path\\to\\models"]

  <pet>.py       one or more pet modules (SPEC.md module API). The build key is the file name without .py.
                 Relative paths are tried against the current folder first, then against this kit folder.
  --save-root    optional: bake an output folder into the build script (sets SAVE_ROOT in pet_blender.py).
                 Without it the script writes to SAVE_ROOT as set in pet_blender.py, or, if that is None,
                 to build/models/<name>/ next to the build script.

The pet module is embedded on its own: it may import only petkit, numpy and the standard library
(no PIL, no helper files of your own; those are not inside Blender).

Then in Blender 5: Scripting workspace > Python console:
    exec(open(r'<full path>/build/<pet>_build.py').read())
"""
import base64
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
BUILD = os.path.join(HERE, 'build')


def b64(path):
    return base64.b64encode(open(path, 'rb').read()).decode()


def resolve(p):
    for cand in (os.path.abspath(p), os.path.join(HERE, p)):
        if os.path.isfile(cand):
            return cand
    sys.exit('make_build: pet module not found: %s' % p)


def main(argv):
    save_root, pets = None, []
    it = iter(argv)
    for a in it:
        if a == '--save-root':
            save_root = next(it, None)
            if not save_root:
                sys.exit('make_build: --save-root needs a folder')
        elif a.startswith('--save-root='):
            save_root = a.split('=', 1)[1]
        elif a in ('-h', '--help'):
            print(__doc__)
            return
        else:
            pets.append(a)
    if not pets:
        print(__doc__)
        sys.exit('make_build: give at least one pet module, e.g. python3 make_build.py mypet/mypet.py')

    body = open(os.path.join(HERE, 'pet_blender_hos.py')).read()
    if save_root:
        body, n = re.subn(r'(?m)^SAVE_ROOT = .*$', lambda m: 'SAVE_ROOT = %r' % save_root, body, count=1)
        assert n == 1, 'pet_blender.py: SAVE_ROOT line not found'
    os.makedirs(BUILD, exist_ok=True)
    for p in pets:
        path = resolve(p)
        key = os.path.splitext(os.path.basename(path))[0]
        src = ['# Auto-generated: build the %s pet in Blender (exec this file from the Python console).' % key,
               'import sys, types, base64, math',
               'import numpy as np',
               'BUILD_DIR = %r   # folder this script was generated in (default output: BUILD_DIR/models)' % BUILD,
               'def _petmod(name, data):',
               '    m = types.ModuleType(name)',
               "    m.__file__ = name + '.py'",
               '    sys.modules[name] = m',
               "    exec(compile(base64.b64decode(data).decode('utf-8'), name + '.py', 'exec'), m.__dict__)",
               '    return m',
               "_petmod('petkit', '%s')" % b64(os.path.join(HERE, 'petkit.py')),
               "_PET = _petmod('pet_%s', '%s')" % (key, b64(path)),
               "globals().update({k: v for k, v in vars(_PET).items() if not k.startswith('__')})",
               '']
        out = os.path.join(BUILD, '%s_build.py' % key)
        open(out, 'w').write('\n'.join(src) + body)
        print(out, os.path.getsize(out))


if __name__ == '__main__':
    main(sys.argv[1:])
