# Void Seraph (Rift, Legendary) for Hatch or Snatch: HOS-PET-031, built on the pet kit (flier helpers from the Tengu).
# From the concept card (docs/pets/void_seraph/void_seraph_card.png): a pale lavender-white winged beast with big
# feathered angel wings, a gold circlet and gold collar, gold eyes, wrapped in violet void energy and magenta portals.
# Read through PET_LESSONS (anime / edgy): ivory-lavender fur with fur strokes split by glowing magenta void cracks,
# feathers that darken from white to void-violet with a glowing magenta rim, narrow slanted gold slit eyes with dark
# violet liner, a flat mouth (face decal shell), sharp pointed ears, a long tail ending in a void wisp. It hovers.
# L2 "Twin Halo": a second, lower pair of wings and a gold halo ring. L3 "Six-Winged Void": a third pair of small
# wings at the temples, a black void eye with a magenta rim behind the head, violet crystal crown points,
# magenta-gold eyes and glow.
import math, os, sys
try:
    _d = os.path.dirname(os.path.abspath(__file__))
    while not os.path.exists(os.path.join(_d, 'petkit.py')) and os.path.dirname(_d) != _d:
        _d = os.path.dirname(_d)
    if os.path.exists(os.path.join(_d, 'petkit.py')):
        sys.path.insert(0, _d)
except NameError:
    pass
from petkit import *   # noqa: F401,F403
import numpy as np

NAME = 'Seraph'
SHARP_ANGLE = 40
NORMAL_STRENGTH = 1.8
TS = 1024
ATLAS = Atlas({
    'skin': (0, 0, 1024, 384),      # body loft: u around (0 = back), v tail root -> head top
    'wing': (0, 384, 512, 256),     # main wings
    'wing2': (512, 384, 512, 256),  # L2 / L3 wings
    'tail': (0, 640, 256, 128),
    'ear': (256, 640, 128, 128),
    'muzzle': (384, 640, 128, 128),
    'gold': (512, 640, 256, 128),
    'gem': (768, 640, 128, 128),
    'wisp': (896, 640, 128, 128),
    'limb': (0, 768, 256, 128),
    'void': (256, 768, 256, 128),   # L3 void eye
    'crystal': (512, 768, 256, 128),
    'warm': (768, 768, 256, 128),   # wing arm
})

GLOW = {1: ('5a1a8a', 'd04aff', 'f8e0ff'), 2: ('5a1a9a', 'e050ff', 'fbe8ff'), 3: ('7a0a6a', 'ff3ad8', 'ffe8fa')}
EYE = {1: ('8a5a04', 'ffcc3a', 'fff6d0'), 2: ('8a5a04', 'ffd84a', 'fffae0'), 3: ('8a0a6a', 'ff5ad8', 'fff0fa')}
FUR = [(0, '9a8ab8'), (0.5, 'd8d0ec'), (1, 'f8f6ff')]


def bones_def():
    b = [
        ('Root', V(0, 0, 0), V(0, 0, 0.2), None),
        ('Body', V(0, 0.08, 0.96), V(0, -0.08, 1.14), 'Root'),
        ('Head', V(0, -0.12, 1.24), V(0, -0.2, 1.56), 'Body'),
        ('Tail1', V(0, 0.4, 0.82), V(0, 0.72, 0.7), 'Body'),
        ('Tail2', V(0, 0.72, 0.7), V(0, 0.98, 0.86), 'Tail1'),
        ('Halo', V(0, 0.06, 1.62), V(0, 0.06, 1.82), 'Body'),
    ]
    for s, x in (('L', 1), ('R', -1)):
        b += [
            ('Wing.' + s, V(x * 0.16, 0.04, 1.12), V(x * 0.9, 0.12, 1.6), 'Body'),
            ('Wing2.' + s, V(x * 0.15, 0.16, 0.92), V(x * 0.7, 0.3, 0.7), 'Body'),
            ('Wing3.' + s, V(x * 0.14, -0.12, 1.5), V(x * 0.45, -0.02, 1.72), 'Head'),
            ('Leg.' + s, V(x * 0.1, -0.06, 0.92), V(x * 0.12, -0.16, 0.66), 'Body'),
            ('Hind.' + s, V(x * 0.14, 0.3, 0.84), V(x * 0.16, 0.24, 0.62), 'Body'),
        ]
    return b


