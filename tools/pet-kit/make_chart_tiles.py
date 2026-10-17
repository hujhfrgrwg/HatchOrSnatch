"""Pet chart tiles + pets.json (HOS-PET-REDO, 17 Oct): crops the Studio roster captures (one per live template at L1,
three-quarter view on the HOS_RosterStage backdrop) to 420 px tiles and writes the roster data.
usage: python make_chart_tiles.py <capture dir>   (captures named *-<id>.jpg; ids below)"""
import glob, json, os, sys
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
OUT = os.path.join(ROOT, 'docs', 'pets', 'previews_page', 'chart')
T = sys.argv[1]
CAP = dict(raiju='ch8p64', void_seraph='g97cit', veil_nekomata='abliok', moonveil_moth='5g4k0g', scroll_tanuki='ts6eyk',
           crystal_warden='0hd50m', drum_oni='b26r8j', astral_djinn='b06emh', aegis_kirin='66zh06', bone_dragon='11vdej',
           compass_hare='k9ysjf', shadow_crow='6wi2uv', eclipse_tengu='l2z2v9', grin_ghost='yfuuju', spirit_kitsune='nvt4vq',
           mirage_manta='r6yiux', mummy='5u0amj', prism_chameleon='tdrt53', jack_o_lantern='t1u3of', ring_imp='6lxevz',
           riot_hound='ohlkum', shrine_lion='wo3uqi', thunder_toad='p9tw9b', witchs_cat='slca54', bastion_beetle='51ntua')
if len(sys.argv) > 2:          # overrides: slug=id,slug=id
    for kv in sys.argv[2].split(','):
        k, v = kv.split('=')
        CAP[k] = v

P = [
    ('Shadow Crow', 'shadow_crow', 'Crow', 'Decoy', 'common', 'roster', 'A sleek black crow with ragged wing feathers and a pale staring eye.'),
    ('Spirit Kitsune', 'spirit_kitsune', 'Kitsune', 'Decoy', 'rare', 'roster', 'A white fox spirit with red kitsune-mask markings, flame-tipped tails and ember socks.'),
    ('Scroll Tanuki', 'scroll_tanuki', 'Scroll Tanuki', 'Decoy', 'epic', 'roster', 'An upright brown tanuki with a bandit mask, a cream belly and bright teal-and-gold scrolls on its back.'),
    ("Witch's Cat", 'witchs_cat', "Witch's Cat", 'Decoy', 'epic', 'Halloween shop', 'A black cat riding a broom in a crooked witch hat, with glowing green slit eyes.'),
    ('Eclipse Tengu', 'eclipse_tengu', 'Eclipse Tengu', 'Decoy', 'legendary', 'roster', 'A plum-black crow spirit with gold horns, a red beak and wings that blaze red at the tips.'),
    ('Prism Chameleon', 'prism_chameleon', 'Prism Chameleon', 'Invisibility', 'common', 'roster', 'A faceted cyan crystal chameleon with green crystal spines, a curled lilac tail and one big blue eye.'),
    ('Grin Ghost', 'grin_ghost', 'Grim Ghost', 'Invisibility', 'rare', 'roster', 'A violet floating ghost with crescent horns, a wide toothy grin and glowing eyes.'),
    ('Mirage Manta', 'mirage_manta', 'Mirage Manta', 'Invisibility', 'epic', 'roster', 'A glassy blue manta ray that glides on long whip fins, speckled with sparkles.'),
    ('Moonveil Moth', 'moonveil_moth', 'Moonveil Moth', 'Invisibility', 'epic', 'roster', 'A lilac moth with pointed hooked wings marked with crescent-moon eyes and a gold crescent crown.'),
    ('Veil Nekomata', 'veil_nekomata', 'Veil Nekomata', 'Invisibility', 'legendary', 'roster', 'A slinky ghost-silver two-tailed cat with indigo ink stripes, a crimson rope collar and cyan ghost-fire tail tips.'),
    ("Jack-o'-Lantern", 'jack_o_lantern', 'Pumpkin Wraith', 'Invisibility', 'legendary', 'Halloween shop', 'A floating scorched carved pumpkin with a glowing jagged grin and thorny vine arms.'),
    ('Bastion Beetle', 'bastion_beetle', 'Bastion Beetle', 'Guardian', 'common', 'roster', 'A domed armoured scarab with ivory plates, bronze rims, a cyan crystal sickle horn and shield claws.'),
    ('Crystal Warden', 'crystal_warden', 'Crystal Warden', 'Guardian', 'rare', 'roster', 'A low indigo crawler armoured in plates with rows of bright cyan crystals and a gold crest.'),
    ('Shrine Lion', 'shrine_lion', 'Shrine Lion', 'Guardian', 'epic', 'roster', 'A white komainu temple lion with a red curly mane, red horns and a green rope of gold bells.'),
    ('Mummy', 'mummy', 'Mummy', 'Guardian', 'epic', 'Halloween shop', 'A hunched floating mummy in grimy wraps with one glowing cyan eye and reaching claws.'),
    ('Aegis Kirin', 'aegis_kirin', 'Aegis Kirin', 'Guardian', 'legendary', 'roster', 'A tall slender white qilin with branching gold antlers, a gold flame mane and blue scale plates.'),
    ('Thunder Toad', 'thunder_toad', 'Thunder Toad', 'Tempest', 'common', 'roster', 'A squat bottle-green storm toad with lime lightning markings, glowing back spines and narrow lime slit eyes.'),
    ('Riot Hound', 'riot_hound', 'Riot Hound', 'Tempest', 'rare', 'roster', 'A navy-black storm wolf with a spiky blue ruff, gold lightning spine bolts and gold slit eyes.'),
    ('Drum Oni', 'drum_oni', 'Drum Oni', 'Tempest', 'epic', 'roster', 'A hunched teal oni with red horns and mane, red legs, a rope sash and taiko drums on its back.'),
    ('Raiju', 'raiju', 'Raiju', 'Tempest', 'legendary', 'roster', 'A crimson thunder beast with a black storm saddle, a huge white-hot lightning mane and a burning tail.'),
    ('Bone Dragon', 'bone_dragon', 'Bone Dragon', 'Tempest', 'legendary', 'Halloween shop', 'A flying skeletal drake with a horned skull, torn bone wings and a green soul-fire heart.'),
    ('Ring Imp', 'ring_imp', 'Ring Imp', 'Rift', 'common', 'roster', 'A teal imp with black horns, a dark mask with yellow eyes, small bat wings and a glowing portal ring.'),
    ('Compass Hare', 'compass_hare', 'Compass Hare', 'Rift', 'rare', 'roster', 'A cold-white hare with very long glowing-tipped ears, a blue scarf and a gold compass on its flank.'),
    ('Astral Djinn', 'astral_djinn', 'Astral Djinn', 'Rift', 'epic', 'roster', 'A royal-blue genie with gold horns, gold rune bands, a pale chest panel and a gold-rimmed galaxy disc on its back.'),
    ('Void Seraph', 'void_seraph', 'Void Seraph', 'Rift', 'legendary', 'roster', 'A void-black starry beast with a pearl ruff, a gold circlet and big layered feathered wings with magenta tips.'),
]
UNSET = {'Bastion Beetle', 'Ring Imp', 'Thunder Toad'}

os.makedirs(OUT, exist_ok=True)
for slug, cid in CAP.items():
    f = glob.glob(os.path.join(T, '*-' + cid + '.jpg'))
    assert len(f) == 1, (slug, f)
    im = Image.open(f[0]).convert('RGB')
    W, H = im.size
    s = 730
    cx, y0 = W // 2, (H - s) // 2
    im.crop((cx - s // 2, y0, cx + s // 2, y0 + s)).resize((420, 420), Image.LANCZOS).save(os.path.join(OUT, slug + '.jpg'), quality=88)
pets = [{'name': n, 'image': 'chart/%s.jpg' % s, 'speciesId': sid, 'archetype': a, 'rarity': r,
         'rarityUnsetInConfig': sid in UNSET, 'source': src, 'look': look} for n, s, sid, a, r, src, look in P]
json.dump({'note': 'Rarity from EconomyConfig.SPECIES_RARITY in the live place, 17 Oct. Bastion Beetle, Ring Imp and Thunder '
                   'Toad were blank there; their roster rarity (Common) is shown and flagged. Tiles are Studio captures of each '
                   'live template at L1, three-quarter view.', 'pets': pets},
          open(os.path.join(OUT, 'pets.json'), 'w', encoding='utf8'), indent=1, ensure_ascii=False)
print('tiles', len(CAP), 'pets', len(pets))
