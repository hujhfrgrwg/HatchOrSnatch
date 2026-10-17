#!/usr/bin/env python3
"""Evolve or Steal UI, round 2 "candy" (HTML first, roblox-ui-maker). Generates every page + index.html.

    cd ui && python3 tools/fetch_textures.py                       # ui-resources.com textures -> tex/ (not committed)
    python3 tools/icons_svg.py && node tools/render_icons.mjs      # game icons -> icons_raw/ -> outline.py -> icons/
    python3 build.py && python3 -m http.server 8870 --bind 127.0.0.1   # open /index.html ; node tools/shoot.mjs -> shots/

Style: styles/candy.css (Hunter picked the candy "Quests" reference, 16 Oct 2026; adapted to the stud lobby).
Pets + eggs: real models photographed from Workspace.FWP_PetShowroom (tools/photo_booth.luau + key_booth.py).
Data: EconomyConfig / GameConfig / QuestConfig (live game) + FWPPetData pools (ServerStorage.EOSBuild.PetShowroom).
  Pools: 1st pet = Common hatch, 2nd = Rare, 3rd = Epic, the rest = Crowned (deferred). T2/T3 = mastery colourways.
  Egg levels: L1 Basic, L2 Shiny, L3 Cosmic (pay Common/Rare/Epic pieces), L4 Golden (survivor; pays Epic + bonus).
Export markers are roblox-ui-maker's (grp/sub/data-n/hid). Never a double quote inside style='...'.
Round 1 (neon, rejected) is kept in build_neon_round1.py for reference.
"""
import html
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
STYLE = os.environ.get('UI_STYLE', 'candy')
FONTS = ("<link rel='preconnect' href='https://fonts.googleapis.com'>"
         "<link href='https://fonts.googleapis.com/css2?family=Fredoka:wght@500;600;700"
         "&family=Montserrat:ital,wght@0,700;0,800;0,900;1,800;1,900&display=block' rel='stylesheet'>")
SKIN = os.environ.get('UI_SKIN', 'sport')   # round 3: styles/sport.css on top of candy.css ('' = round 2 candy)
EXPORT_STATES = os.environ.get('UI_EXPORT') == '1'   # Studio export: every runtime state on the page (hidden ones too)


# ================================================================== base helpers (roblox-ui-maker markers)
def dn(name):
    return f" data-n='{name}'" if name else ''


def T(text, size, cls='', fill='', style='', name=None, tag='span'):
    t = html.escape(str(text), quote=True)
    return f"<{tag} class='ot {cls} {fill}' data-t='{t}'{dn(name)} style='font-size:{size}px;{style}'>{t}</{tag}>"


def ipath(icon):
    """set/icons/<slug>.png: the merged set (tools/merge_icons.py: ChatGPT icons_ai/ win over the drawn icons/).
    The 'icons/<slug>.png' tail is what the Studio exporter keys icons on, so every icon, pet and egg uploads
    once by slug and can be swapped at runtime."""
    return f'set/icons/{icon}.png'


def I(icon, x, y, w, h=None, name=None, extra='', cls='ic'):
    h = h or w
    return f"<img class='{cls}' src='{ipath(icon)}'{dn(name)} style='left:{x}px;top:{y}px;width:{w}px;height:{h}px;{extra}'>"


def icn(icon, w, name=None, extra=''):
    return f"<img class='icn' src='{ipath(icon)}'{dn(name)} style='width:{w}px;height:{w}px;{extra}'>"


def grp(name, inner, anchor='C'):
    return f"<div class='abs fill grp' data-g='{name}' data-a='{anchor}' style='pointer-events:none'>{inner}</div>"


def sub(name, inner, btn=False, opens=None, hid=False):
    extra = (' data-btn=1' if btn else '') + (f" data-opens='{opens}'" if opens else '')
    return f"<div class='abs fill sub{' hid' if hid else ''}' data-n='{name}'{extra} style='pointer-events:none'>{inner}</div>"


def box(x, y, w, h, inner='', cls='', style='', name=None, hid=False):
    return f"<div class='abs {cls}{' hid' if hid else ''}'{dn(name)} style='left:{x}px;top:{y}px;width:{w}px;height:{h}px;{style}'>{inner}</div>"


def at(x, y, inner, w=None, align='left', name=None, style=''):
    if align == 'center':
        return f"<div class='abs'{dn(name)} style='left:{x - (w or 600) // 2}px;width:{w or 600}px;top:{y}px;text-align:center;{style}'>{inner}</div>"
    if align == 'right':
        return f"<div class='abs'{dn(name)} style='left:{x - (w or 600)}px;width:{w or 600}px;top:{y}px;text-align:right;{style}'>{inner}</div>"
    return f"<div class='abs'{dn(name)} style='left:{x}px;top:{y}px;white-space:nowrap;{style}'>{inner}</div>"


def row(*parts, gap=10):
    return f"<span style='display:inline-flex;align-items:center;gap:{gap}px'>{''.join(parts)}</span>"


def col(*parts, gap=4, align='center'):
    return f"<span style='display:inline-flex;flex-direction:column;align-items:{align};gap:{gap}px'>{''.join(parts)}</span>"


def cap(x, y, text):
    return f"<div class='cap' style='left:{x}px;top:{y}px'>{html.escape(text)}</div>"


# ================================================================== game data
P = {  # FWPPetData display names
    'SeagullScout': 'Seagull Scout',
    'ShadesShark': 'Shades Shark', 'SurferDog': 'Surfer Dog', 'ThunderWolf': 'Thunder Wolf', 'PhoenixGull': 'Phoenix Gull', 'FireDragon': 'Fire Dragon',
    'KoiSpirit': 'Koi Spirit', 'JellyWisp': 'Jelly Wisp', 'SaucerPilot': 'Saucer Pilot', 'VoidOverlord': 'Void Overlord',
    'GamerAxolotl': 'Gamer Axolotl', 'BanditRaccoon': 'Bandit Raccoon', 'NinjaPenguin': 'Ninja Penguin', 'LilAlien': "Lil' Alien", 'MiniMothership': 'Mini Mothership',
    'PebbleFrog': 'Pebble Frog', 'PufferPup': 'Puffer Pup', 'HermitKnight': 'Hermit Knight', 'TreasureGolem': 'Treasure Golem',
    'SandCrab': 'Sand Crab', 'RoboCrab': 'Robo Crab', 'ArmoredRex': 'Armored Rex', 'FrostYeti': 'Frost Yeti', 'LavaScorpion': 'Lava Scorpion', 'MechaInvader': 'Mecha Invader',
    'VikingWalrus': 'Viking Walrus', 'CozyLion': 'Cozy Lion', 'NarwhalCalf': 'Narwhal Calf', 'KrakenHatchling': 'Kraken Hatchling', 'LeviathanPup': 'Leviathan Pup',
}
POOLS = [  # FWPPetData.Pools (HOS-ABIL-001): id, title, icon, colour key, blurb, pets (common -> rarest)
    ('DoubleDash', 'Double Dash', 'ab_dash', 'orange', 'Two quick dashes in a row', ['ShadesShark', 'SurferDog', 'ThunderWolf', 'PhoenixGull', 'FireDragon']),
    ('Decoy', 'Decoy', 'ab_decoy', 'gold', 'A running copy of you', ['GamerAxolotl', 'BanditRaccoon', 'NinjaPenguin', 'LilAlien', 'MiniMothership']),
    ('Scout', 'Scout', 'ab_scout', 'lime', 'See the 3 nearest rivals', ['SeagullScout']),
    ('Brake', 'Brake', 'ab_brake', 'pink', 'Stop dead and cut sharply', []),
    ('Invisibility', 'Invisibility', 'ab_invis', 'sky', 'Fade out for a few seconds', ['KoiSpirit', 'JellyWisp', 'SaucerPilot', 'VoidOverlord']),
    ('Wall', 'Wall', 'ab_wall', 'violet', 'Drop a wall in a lane', ['SandCrab', 'RoboCrab', 'ArmoredRex', 'FrostYeti', 'LavaScorpion', 'MechaInvader']),
    ('Shield', 'Shield', 'ab_shield', 'teal', 'A bubble that blocks one hit', ['PebbleFrog', 'PufferPup', 'HermitKnight', 'TreasureGolem']),
    ('Spring', 'Spring', 'ab_spring', 'rare', 'Leap forward', []),
    ('PetTackle', 'Pet Tackle', 'ab_tackle', 'red', 'Your pet bowls someone over', ['VikingWalrus', 'CozyLion', 'NarwhalCalf', 'KrakenHatchling', 'LeviathanPup']),
]
WAVE = {'DoubleDash': 1, 'Decoy': 1, 'Scout': 1, 'Brake': 2, 'Invisibility': 2, 'Wall': 2, 'Shield': 3, 'Spring': 3, 'PetTackle': 3}
ROLES = {  # what the ability does as a Runner / as a Catcher (it stays with you when you're caught)
    'DoubleDash': ('escape burst', 'close the gap'), 'Decoy': ('fake out chasers', 'fake out runners'),
    'Scout': ('see the 3 nearest Catchers', 'see the 3 nearest Runners'), 'Brake': ('stop and cut', 'cut off a juke'),
    'Invisibility': ('slip past', 'sneak up'), 'Wall': ('block the chaser', 'block the escape lane'),
    'Shield': ('blocks one tag', 'to be decided'), 'Spring': ('leap ahead', 'leap onto a Runner'),
    'PetTackle': ('knock a Catcher over', 'to be decided'),
}
POOL = {p[0]: p for p in POOLS}
TIERS = ['common', 'rare', 'epic', 'crowned']
TIER_NAME = {'common': 'Common', 'rare': 'Rare', 'epic': 'Epic', 'crowned': 'Crowned'}
RECIPES = {'common': (2, 3), 'rare': (3, 4), 'epic': (5, 6)}   # EconomyConfig.RECIPES (random, chosen family)
PIECES = {'common': 4, 'rare': 2, 'epic': 0}                     # sample player (a few matches in)
FILL = {'common': 'f-common', 'rare': 'f-rare', 'epic': 'f-epic', 'crowned': 'f-gold', 'orange': 'f-orange', 'sky': 'f-sky', 'gold': 'f-gold',
        'teal': 'f-teal', 'violet': 'f-violet', 'red': 'f-red', 'pink': 'f-pink', 'lime': 'f-lime'}


def slug(pet):
    return re.sub(r'(?<!^)(?=[A-Z])', '_', pet).lower()


def pet_img(pet, t=1):
    return f"pet_{slug(pet)}_t{t}"


def tier_of(pool_id, pet):
    return TIERS[min(POOL[pool_id][5].index(pet), 3)]


# ================================================================== candy components
def btn(x, y, w, h, color, label, name=None, cls='', style='', hid=False, opens=None):
    extra = (f" data-opens='{opens}'" if opens else '') + (' data-btn=1' if name else '')
    return (f"<div class='cb k-{color} {cls}{' hid' if hid else ''}'{dn(name)}{extra} style='left:{x}px;top:{y}px;width:{w}px;height:{h}px;{style}'>"
            f"<div class='lbl'>{label}</div></div>")


def bl(text, size=34, fill='', name=None):
    return T(text, size, 's', fill, name=name or 'Label')


def well(x, y, w, h, inner='', name=None, solid=False, style='', title=None, extra=''):
    """Sub-box. title = the reference's folder tab ("Status") sitting on the top edge, white text."""
    tab = (f"<div class='wtab' style='left:{x + 14}px;top:{y - 30}px'>{T(title, 22, 'xs')}{extra}</div>" if title else '')
    return tab + box(x, y, w, h, inner, 'cw' + (' solid' if solid else ''), style, name=name)


def slot(x, y, s, rarity, icon=None, count=None, label=None, cls='', name=None, art_pad=.14, label_size=None, inner_extra=''):
    inner = ''
    if icon:
        p = int(s * art_pad)
        inner += f"<div class='art'>{I(icon, p, int(p * .7), s - 2 * p, name='Icon')}</div>"
    if count:
        inner += at(s - 10, 6, T(count, max(18, int(s * .17)), 'xs', name='CountText'), w=s, align='right', name='Count')
    if label:
        inner += at(s // 2, s - int(s * .26), T(label, label_size or max(16, int(s * .15)), 'xs', FILL.get(rarity, ''), name='LabelText'), w=s + 20, align='center', name='Label')
    inner += inner_extra
    return box(x, y, s, s, inner, f'cs r-{rarity} {cls}' + (' lab' if label else ''), name=name)


def stars(n, of=3, size=26, name=None):
    out = ''
    for i in range(of):
        out += f"<img class='icn' data-n='Star{i + 1}' src='{ipath('star')}' style='width:{size}px;height:{size}px;{'' if i < n else 'filter:brightness(.3)'}'>"
    return f"<span{dn(name)} style='display:inline-flex;gap:2px'>{out}</span>"


def tag(x, y, text, color='blue', size=20, h=36, name=None):
    return f"<div class='ctag k-{color}'{dn(name)} style='left:{x}px;top:{y}px;height:{h}px'>{T(text, size, 'xs')}</div>"


def bar(x, y, w, h, frac, color='lime', name='Bar'):
    return (f"<div class='cbar k-{color}'{dn(name)} style='left:{x}px;top:{y}px;width:{w}px;height:{h}px'>"
            f"<i data-n='F' style='width:{max(0, min(1, frac)) * 100:.1f}%'></i></div>")


def selring(x, y, w, h, name='SelRing', r=6):
    """The selection ring the runtime moves between tiles (one per grid)."""
    return f"<div class='selring'{dn(name)} style='left:{x - 4}px;top:{y - 4}px;width:{w + 8}px;height:{h + 8}px;border-radius:{r}px'></div>"


def dual(x, y, w, h, on_color, label, name, active, cls='', off_label=None, off_color='grey'):
    """A tab/toggle exported in both states: <name>.On (coloured) and <name>.Off (grey); runtime shows one."""
    on = btn(x, y, w, h, on_color, label, name='On', cls=cls + ('' if active else ' hid'))
    off = btn(x, y, w, h, off_color, off_label if off_label is not None else label, name='Off', cls=cls + (' hid' if active else ''))
    return sub(name, on + off, btn=True)


def closex(x, y):
    return f"<div class='cx' data-n='CloseButton' data-btn=1 style='left:{x}px;top:{y}px'>{T('X', 48, 'l')}</div>"


def panel(gname, acc, title, icon, body, x, y, w, h, right='', head_h=112, title_size=62):
    if SKIN == 'sport':
        return panel_sport(gname, acc, title, icon, body, x, y, w, h, right, head_h, title_size)
    out = f"<div class='cglow a-{acc}' style='left:{x - 26}px;top:{y - 20}px;width:{w + 52}px;height:{h + 46}px'></div>"
    head = (f"<div class='ch' data-n='Header' style='height:{head_h}px'><div class='sweep'></div>"
            f"<img class='spk' src='tex/shine.png' style='left:{int(w * .3)}px;top:-34px;width:150px;height:150px;opacity:.9'>"
            f"<div class='lbl'>{icn(icon, int(head_h * .78)) if icon else ''}{T(title, title_size, 'l', name='Title')}"
            f"<span style='flex:1'></span>{right}<span style='width:96px'></span></div></div>")
    out += (f"<div class='cp a-{acc}' data-n='Panel' style='left:{x}px;top:{y}px;width:{w}px;height:{h}px'>{head}"
            f"<div class='body' style='top:{head_h}px'>{body}</div>{closex(w - 112, (head_h - 84) // 2 - 6)}</div>")
    return grp(gname, out, 'C')


UI_COLOUR = [None]   # Settings > UI Colour: None = default (one accent per screen), else one accent for every panel
UI_COLOURS = [(None, 'Default'), ('purple', 'Purple'), ('pink', 'Pink'), ('sky', 'Blue'), ('lime', 'Green'), ('gold', 'Gold'), ('coral', 'Red'), ('steel', 'Steel')]


def panel_sport(gname, acc, title, icon, body, x, y, w, h, right='', head_h=112, title_size=62):
    """Units-reference panel: the angled banner overlaps the panel top-left, a grey chip holds the
    header info at the top right, the tilted X sits on the corner."""
    acc = UI_COLOUR[0] or acc
    bw = min(int(w * .52), 760)
    out = f"<div class='cglow a-{acc}' data-n='Glow' style='left:{x - 16}px;top:{y - 12}px;width:{w + 32}px;height:{h + 28}px'></div>"
    if EXPORT_STATES:   # greyscale glow, tinted at runtime by the UI Colour setting
        out += f"<div class='cglow a-steel mono hid' data-n='GlowMono' style='left:{x - 16}px;top:{y - 12}px;width:{w + 32}px;height:{h + 28}px'></div>"
    out += (f"<div class='cp a-{acc}' data-n='Panel' style='left:{x}px;top:{y}px;width:{w}px;height:{h}px'>"
            f"<div class='body' style='top:{head_h}px'>{body}</div>"
            + (f"<div class='schip' data-n='HeaderInfo' style='right:118px;top:20px'>{right}</div>" if right else '') + "</div>")
    out += (f"<div class='sbn a-{acc}' data-n='Banner' style='left:{x - 18}px;top:{y - 50}px;width:{bw}px;height:132px'>"
            f"<div class='o' data-n='Edge'></div><div class='f' data-n='Fill'></div>"
            + ("<div class='f mono hid' data-n='FillMono'></div>" if EXPORT_STATES else '')
            + f"<div class='lbl'>{icn(icon, 96) if icon else ''}{T(title.upper(), title_size + 6, 'xl', name='Title')}</div></div>")
    out += closex(x + w - 64, y - 38)
    return grp(gname, out, 'C')


def rays(cx, cy, d, op=.25):
    """Light rays centred exactly on (cx, cy), diameter d: one white PNG (art/rays.png, tools in build.py history)
    so Studio gets a single ImageLabel 'Rays' it can spin and tint."""
    return f"<img class='rays' data-n='Rays' src='art/rays.png' style='position:absolute;left:{cx - d // 2}px;top:{cy - d // 2}px;width:{d}px;height:{d}px;opacity:{op}'>"


def world(img='bg_lobby.jpg', vign=True):
    return (f"<img class='world' src='{img}' style='position:absolute;left:0;top:0;width:1920px;height:1080px;object-fit:cover'>"
            + ("<div class='vign'></div>" if vign else ''))


def dim(a=.42):
    return grp('Dim', f"<div class='abs fill' style='background:rgba(26,6,48,{a})'></div>", 'FILL')


def topbar():
    return "<div class='rbx' style='left:16px;top:12px;width:200px;height:64px;border-radius:18px'>Roblox top bar</div>"


# ================================================================== HUD (lobby)
def hpill(x, y, w, h, color, icon, label, name, opens=None, size=34, badge=False):
    inner = f"<div class='hp k-{color}' style='left:{x}px;top:{y}px;width:{w}px;height:{h}px'><div class='lbl'>{T(label, size, 's', name='Label')}</div></div>"
    inner += I(icon, x - 14, y - 12, h + 24, name='Icon')
    if badge:
        inner += box(x + w - 18, y - 20, 40, 40, T('!', 24, 'xs'), 'badge', name='Badge')
    return sub(name, inner, btn=True, opens=opens)


def hbtn(x, y, s, color, icon, label, name, opens=None, state=None, badge=False):
    inner = f"<div class='hb k-{color}' style='left:{x}px;top:{y}px;width:{s}px;height:{s}px'></div>"
    inner += I(icon, x + int(s * .13), y + int(s * .06), int(s * .74), name='Icon')
    inner += at(x + s // 2, y + s - 30, T(label, 28, 's', name='Label'), w=s + 40, align='center')
    if state:
        on = state == 'ON'
        inner += btn(x + s - 52, y - 16, 70, 36, 'lime' if on else 'grey', T(state, 18, 'xs', name='StateText'), cls='sm', name='State')
    if badge:
        inner += box(x + s - 26, y - 14, 44, 44, T('!', 26, 'xs'), 'badge', name='Badge')
    return sub(name, inner, btn=True, opens=opens)


def wallet():
    out = ''
    for i, (icon, val, fill, nm, plus) in enumerate([('gem', '12', 'f-lime', 'Gems', True), ('gold', '1,250', 'f-gold', 'Gold', False)]):
        y = 864 + i * 102
        out += f"<div class='glass' style='left:62px;top:{y}px;width:300px;height:80px'></div>"
        out += I(icon, 16, y - 14, 108, name=f'{nm}Icon')
        out += at(126, y + 8, T(val, 50, 'l', fill, name=f'{nm}Text'))
        if plus:
            out += btn(306, y + 14, 50, 50, 'lime', T('+', 34, 's'), cls='sm', name=f'{nm}Plus', opens='Shop')
    return grp('Wallet', out, 'BL')


def ability_card(y=944, lobby=True, cd=None):
    pool = POOL['DoubleDash']
    x, w, h = 680, 560, 112
    out = f"<div class='glass' style='left:{x}px;top:{y}px;width:{w}px;height:{h}px'></div>"
    out += slot(x + 16, y + 12, 88, 'common', pet_img('ShadesShark'), name='PetSlot', art_pad=.06)
    out += at(x + 122, y + 12, row(icn(pool[2], 40), T(pool[1].upper(), 38, 's', name='AbilityName')), name='AbilityRow')
    sub_t = 'SHADES SHARK  ·  EQUIPPED' if lobby else ('READY!' if cd is None else f'RECHARGING  {cd}s')
    out += at(x + 124, y + 64, T(sub_t, 20, 'xs', 'f-orange' if cd is None else 'f-dim', name='Status'))
    out += f"<div class='keycap' data-n='Key' style='left:{x + w - 82}px;top:{y + 26}px'>{T('Q', 30, 's', style='font-family:Montserrat;font-weight:900')}</div>"
    out += bar(x + 120, y + h - 20, w - 220, 14, 1 if cd is None else .42, 'orange', 'Cooldown')
    return grp('Ability', out, 'B')


def lobby_status():
    out = f"<div class='glass' style='left:810px;top:14px;width:300px;height:206px'></div>"   # readable over bright sky
    out += btn(850, 0, 220, 44, 'purple', T('LOBBY', 24, 's'), cls='sm', name='PhaseChip')
    out += at(960, 54, T('NEXT MATCH IN', 22, 'xs', 'f-dim', name='Headline'), w=300, align='center')
    out += at(960, 78, T('0:12', 88, 'xl', name='Timer'), w=300, align='center')
    out += at(960, 176, T('4 / 4 players ready', 24, 's', 'f-lime', name='Subline'), w=300, align='center')
    return grp('Status', out, 'T')


def goal_pill():
    x, y, w, h = 250, 116, 562, 104
    out = f"<div class='glass' style='left:{x}px;top:{y}px;width:{w}px;height:{h}px'></div>"
    out += slot(x + 14, y + 12, 80, 'common', 'piece_common', name='GoalSlot', art_pad=.1)
    out += at(x + 108, y + 12, T('YOUR FIRST PET', 28, 's', name='GoalTitle'))
    out += at(x + w - 20, y + 14, T('2 / 2', 26, 's', 'f-lime', name='GoalCount'), w=140, align='right')
    out += bar(x + 108, y + 56, w - 128, 30, 1, 'lime', 'GoalBar')
    out += at(x + 108 + (w - 128) // 2, y + 57, T('READY TO HATCH!', 18, 'xs'), w=w - 128, align='center')
    return sub('GoalPill', out, btn=True, opens='Incubator')


def hud_groups():
    tl = hpill(250, 22, 250, 72, 'pink', 'quests', 'QUESTS', 'QuestsButton', 'Quests', size=30, badge=True)
    tl += hpill(534, 22, 290, 72, 'lime', 'incubator', 'INCUBATOR', 'IncubatorButton', 'Incubator', size=26, badge=True)
    tl += goal_pill()
    tr = hpill(1376, 22, 220, 72, 'blue', 'stats', 'STATS', 'StatsButton', 'Stats')
    tr += hpill(1632, 22, 262, 72, 'purple', 'settings', 'SETTINGS', 'SettingsButton', 'Settings', size=28)
    left = (hbtn(24, 252, 124, 'gold', 'shop', 'SHOP', 'ShopButton', 'Shop') +
            hbtn(24, 398, 124, 'sky', 'pets', 'PETS', 'PetsButton', 'Pets') +
            hbtn(24, 544, 124, 'white', 'afk', 'AFK', 'AFKToggle', state='OFF') +
            hbtn(24, 690, 124, 'red', 'hunt', 'HUNT', 'VolunteerToggle', state='ON'))
    return grp('TopLeft', tl, 'TL') + grp('TopRight', tr, 'TR') + grp('LeftRail', left, 'L') + lobby_status() + wallet() + ability_card()


def s_hud_v1():
    return world() + topbar() + hud_groups()


def s_hud_phone_v1():
    """Landscape phone: canvas ~0.36x, so the rail and wallet grow; Roblox thumbstick/jump kept clear."""
    out = world() + topbar()
    tl = hpill(250, 22, 262, 84, 'pink', 'quests', 'QUESTS', 'QuestsButton', 'Quests', size=32, badge=True)
    tl += hpill(546, 22, 330, 84, 'lime', 'incubator', 'INCUBATOR', 'IncubatorButton', 'Incubator', size=30, badge=True)
    tr = hpill(1446, 22, 226, 84, 'blue', 'stats', 'STATS', 'StatsButton', 'Stats', size=32) + hbtn(1700, 14, 120, 'purple', 'settings', 'MENU', 'SettingsButton', 'Settings')
    left = (hbtn(24, 250, 150, 'gold', 'shop', 'SHOP', 'ShopButton', 'Shop') + hbtn(24, 430, 150, 'sky', 'pets', 'PETS', 'PetsButton', 'Pets') +
            hbtn(1746, 330, 150, 'red', 'hunt', 'HUNT', 'VolunteerToggle', state='ON') + hbtn(1746, 510, 150, 'white', 'afk', 'AFK', 'AFKToggle', state='OFF'))
    out += grp('TopLeft', tl, 'TL') + grp('TopRight', tr, 'TR') + grp('Rail', left, 'L') + lobby_status()
    out += grp('Wallet', f"<div class='glass' style='left:540px;top:964px;width:300px;height:84px'></div>" + I('gold', 496, 950, 112) + at(616, 976, T('1,250', 52, 'l', 'f-gold'))
               + f"<div class='glass' style='left:900px;top:964px;width:220px;height:84px'></div>" + I('gem', 856, 950, 112) + at(976, 976, T('12', 52, 'l', 'f-lime')), 'B')
    out += "<div class='rbx' style='left:120px;top:640px;width:300px;height:300px'>Roblox thumbstick</div>"
    out += "<div class='rbx' style='left:1640px;top:760px;width:220px;height:220px'>Roblox jump / dash</div>"
    out += cap(560, 900, 'phone: taps >= 124 design px, text >= 26, nothing under the thumbs')
    return out


# ================================================================== HUD (match): economy hidden (GDD 14)
def s_hud_match_v1():
    out = world() + topbar()
    role = f"<div class='hp k-sky' style='left:250px;top:22px;width:360px;height:96px'><div class='lbl' style='padding-left:118px'>{col(T('RUNNER', 40, 'l', name='RoleText'), T('Reach the safe zone!', 20, 'xs', name='RoleHint'), gap=0, align='flex-start')}</div></div>"
    role += I('runner', 230, 8, 120, name='RoleIcon')
    out += grp('Role', role, 'TL')
    mb = btn(820, 12, 280, 50, 'lime', T('CROSSING 2', 26, 's', name='WaveText'), cls='sm', name='WaveChip')
    mb += at(960, 66, T('0:21', 104, 'xl', name='Timer'), w=500, align='center')
    mb += f"<div class='glass' style='left:600px;top:90px;width:222px;height:62px'></div>" + I('runner', 578, 76, 86) + at(682, 100, T('14', 40, 'l', 'f-sky', name='RunnersText'))
    mb += at(732, 114, T('RUNNERS', 15, 'xs', 'f-dim'))
    mb += f"<div class='glass' style='left:1098px;top:90px;width:222px;height:62px'></div>" + I('catcher', 1240, 74, 90) + at(1120, 100, T('4', 40, 'l', 'f-red', name='CatchersText'))
    mb += at(1152, 114, T('CATCHERS', 15, 'xs', 'f-dim'))
    mb += at(960, 186, T('CLEAN STREAK', 20, 'xs', 'f-dim'), w=300, align='center')
    for i in range(3):
        mb += f"<div class='pip k-lime{' on' if i == 0 else ''}' data-n='Streak{i + 1}' style='left:{907 + i * 40}px;top:218px'></div>"
    out += grp('MatchBar', mb, 'T')
    eg = f"<div class='glass' style='left:110px;top:880px;width:400px;height:150px'></div>"
    eg += slot(30, 864, 170, 'rare', 'egg_shiny', name='EggSlot', art_pad=.12)
    eg += at(214, 896, T('YOUR EGG', 22, 'xs', 'f-dim'))
    eg += at(214, 922, T('LEVEL 2', 56, 'l', 'f-rare', name='EggLevel'))
    for i in range(4):
        eg += f"<div class='pip k-sky{' on' if i < 2 else ''}' data-n='Lv{i + 1}' style='left:{218 + i * 42}px;top:{990}px'></div>"
    eg += at(392, 992, row(icn('piece_rare', 30), T('RARE', 20, 'xs', 'f-rare', name='PaysText'), gap=4))
    out += grp('Egg', eg, 'BL')
    fd = ''
    for i, (a, verb, b, ic, fill) in enumerate([('Kai', 'stole', "Mia's Lv 2 egg", 'steal', 'f-red'), ('Zoe', 'is safe with a', 'Lv 3 egg', 'safe', 'f-lime'), ('Ben', 'caught', 'Leo', 'catcher', 'f-red')]):
        y = 140 + i * 66
        fd += f"<div class='glass' style='left:1420px;top:{y}px;width:480px;height:56px;opacity:{1 - i * .16}'></div>"
        fd += I(ic, 1400, y - 8, 70)
        fd += at(1466, y + 12, row(T(a, 24, 'xs'), T(verb, 24, 'xs', fill), T(b, 24, 'xs'), gap=8))
    out += grp('Feed', fd, 'TR')
    out += ability_card(lobby=False, cd=8)
    out += grp('Dash', btn(1262, 958, 184, 86, 'blue', col(T('DASH', 30, 's'), T('SPACE', 15, 'xs', 'f-dim'), gap=0), name='DashChip'), 'B')
    out += cap(560, 470, 'In a match only role, timer, teams, egg level, ability and dash stay on screen (GDD 14).')
    return out



# ================================================================== HUD v2: Huss Valley LAYOUT (Hunter, 16 Oct), our style
# Positions copied from the Huss Valley lobby/round screenshots (1920 design): small pills beside Roblox's
# buttons (top-left), phase + one-line headline + subline (top-centre), two pills (top-right), a slim
# vertical rail (left middle), currency plates stacked (bottom-left), ability card + "SPACE · DASH" with a
# long dash bar (bottom-centre). Additions for our GDD: first-pet goal under the top-left pills (FTUE),
# egg level replacing the wallet in a match (GDD 14), a compact steal feed (top-right, match only).
def hv_pill(x, y, w, color, icon, label, name, opens=None, badge=False, h=58):
    inner = f"<div class='hp k-{color}' style='left:{x}px;top:{y}px;width:{w}px;height:{h}px'><div class='lbl' style='padding-left:{h + 6}px'>{T(label, 26, 's', name='Label')}</div></div>"
    inner += I(icon, x - 6, y - 8, h + 14, name='Icon')
    if badge:
        inner += box(x + w - 16, y - 14, 34, 34, T('!', 20, 'xs'), 'badge', name='Badge')
    return sub(name, inner, btn=True, opens=opens)


def hv_rail_btn(x, y, s, color, icon, label, name, opens=None, state=None, key=None, on_color=None):
    inner = f"<div class='hb k-{color}' style='left:{x}px;top:{y}px;width:{s}px;height:{s}px'></div>"
    if on_color:   # toggles: the coloured plate (PlateOn) the runtime shows while the toggle is on
        on = state == 'ON'
        inner += f"<div class='hb k-{on_color}{'' if on else ' hid'}' data-n='PlateOn' style='left:{x}px;top:{y}px;width:{s}px;height:{s}px'></div>"
    inner += I(icon, x + int(s * .14), y + int(s * .04), int(s * .72), name='Icon')
    inner += at(x + s // 2, y + s - 26, T(label, 19, 'xs', name='Label'), w=s + 20, align='center')
    if state:  # both states exported; runtime shows one (StateOn / StateOff)
        on = state == 'ON'
        inner += btn(x + s - 30, y - 12, 54, 28, 'lime', T('ON', 14, 'xs', name='StateText'), cls='sm' + ('' if on else ' hid'), name='StateOn')
        inner += btn(x + s - 30, y - 12, 54, 28, 'grey', T('OFF', 14, 'xs', name='StateText'), cls='sm' + (' hid' if on else ''), name='StateOff')
    if key:
        inner += f"<div class='keycap' style='left:{x + s - 20}px;top:{y - 10}px;width:32px;height:32px;border-width:3px'>{T(key, 16, 'xs', style='font-family:Montserrat;font-weight:900', name='KeyText')}</div>"
    return sub(name, inner, btn=True, opens=opens)


def hv_topcenter(phase, head, subline, extra=''):
    out = at(960, 6, T(phase, 22, 'xs', name='Phase'), w=600, align='center')
    out += at(960, 30, T(head, 50, 'l', name='Headline'), w=1200, align='center')
    out += at(960, 98, subline, w=900, align='center', name='Subline')
    return grp('Status', out + extra, 'T')


def hv_plate(y, icon, value, label, fill, name):
    out = f"<div class='glass' style='left:12px;top:{y}px;width:340px;height:84px'></div>"
    out += I(icon, 20, y + 8, 68, name=f'{name}Icon')
    out += at(100, y + 6, T(value, 46, 'l', fill, name=f'{name}Text'))
    out += at(102, y + 58, T(label, 15, 'xs', 'f-dim'))
    return out


def gem_pop(x, y, n=1, name='GemPop'):
    """HOS-GEMS-002 "+1" over a picked-up field Gem (world billboard, collector only): the HUD Gems wallet's
    gem icon and lime value text (hv_plate), no plate. (x, y) = top-left of the 190x86 billboard frame.
    Runtime: Icon, Amount ("+1"); the pop / rise / fade is tweened by Controllers/FieldGems."""
    inner = I('gem', 6, 6, 72, name='Icon') + at(84, 8, T(f'+{n}', 58, 'l', 'f-lime', name='Amount'))
    return box(x, y, 190, 86, inner, name=name)


def gem_max(x, y, name='GemMax'):
    """HOS-GEMS-002 "MAX" over a field Gem you can't take (2 per match): the sport card plate (cs, grey = locked,
    the same plate as the HOS-RET-001 offer card), the HUD wallet's gem icon and outlined text, plus a dim "2 / 2"
    line like the wallet's GEMS label. Runtime: Card, Icon, Label, Sub."""
    inner = box(0, 0, 250, 84, '', 'cs locked', 'border-radius:12px', name='Card')
    inner += I('gem', 8, 8, 68, name='Icon') + at(84, 6, T('MAX', 44, 'l', name='Label'))
    inner += at(86, 58, T('2 / 2 FIELD GEMS', 15, 'xs', 'f-dim', name='Sub'))
    return box(x, y, 250, 84, inner, name=name)


def field_gems_tag(x, y, n=2, hid=False):
    """HOS-GEMS-002 results: "FIELD GEMS +N" with the gem icon on the Gems reward (hidden when N = 0).
    Runtime: FieldGems.Tag.Icon / .TagText."""
    t = f"<div class='ctag k-lime' data-n='Tag' style='left:{x}px;top:{y}px;height:36px'>{row(icn('gem', 30, name='Icon'), T(f'FIELD GEMS +{n}', 22, 'xs', name='TagText'), gap=6)}</div>"
    return sub('FieldGems', t, hid=hid)


def hv_level(y=784):
    """Account level + XP bar, the top plate of the bottom-left Level / Gold / Gems column (16 Oct, Hunter:
    under the goal pill it read as misplaced). Runtime: LevelText, XpBar.F, XpText."""
    out = f"<div class='glass' style='left:12px;top:{y}px;width:340px;height:84px'></div>"
    out += I('star', 20, y + 8, 68, name='LevelIcon')
    out += at(100, y + 8, T('LEVEL 12', 32, 'l', 'f-gold', name='LevelText'))
    out += bar(102, y + 48, 236, 24, .33, 'sky', 'XpBar') + at(102 + 118, y + 50, T('124 / 375 XP', 15, 'xs', name='XpText'), w=236, align='center')
    return sub('LevelPlate', out)


def hv_ability(lobby=True, cd=None):
    pool = POOL['DoubleDash']
    x, y, w, h = 740, 820, 440, 96
    out = f"<div class='glass' style='left:{x}px;top:{y}px;width:{w}px;height:{h}px'></div>"
    out += f"<div class='wtab' style='left:{x + 12}px;top:{y - 26}px;height:28px'>{T('ABILITY', 14, 'xs')}</div>"
    out += box(x + 14, y + 16, 72, 72, I(pet_img('ShadesShark'), 2, 2, 68, name='PetIcon'), '', 'border-radius:50%;border:3px solid #4ed45a;box-shadow:0 0 0 2px #050506;background:radial-gradient(#2a6a34,#0e1a12);overflow:hidden', name='PetDisc')
    out += at(x + 100, y + 18, row(icn(pool[2], 30, name='AbilityIcon'), T(pool[1].upper(), 28, 's', name='AbilityName'), gap=6))
    st = 'EQUIPPED  ·  SHADES SHARK' if lobby else ('READY' if cd is None else f'RECHARGING  {cd}s')
    out += at(x + 102, y + 56, T(st, 15, 'xs', 'f-orange' if cd is None else 'f-dim', name='Status'))
    out += f"<div class='keycap' data-n='Key' style='left:{x + w - 64}px;top:{y + 22}px;width:48px;height:48px'>{T('Q', 26, 's', style='font-family:Arial,sans-serif;font-weight:900', name='KeyText')}</div>"
    out += bar(x + 100, y + h - 14, w - 180, 8, 1 if cd is None else .42, 'orange', 'Cooldown')
    return grp('Ability', out, 'B')


def hv_dash(left, right, frac=1):
    out = at(960, 934, T('SPACE  ·  DASH', 24, 's', name='DashTitle'), w=400, align='center')
    out += at(630, 966, T(left, 15, 'xs', name='DashState'))
    out += at(1290, 966, T(right, 15, 'xs', 'f-dim', name='DashHint'), w=500, align='right')
    out += bar(630, 990, 660, 14, frac, 'sky', 'DashBar')
    return grp('Dash', out, 'B')


def hv_goal():
    # 16 Oct (Hunter): off the top-left (it hung under QUESTS) to the top-right, under SERVERS / STATS / SETTINGS
    x, y, w, h = 1448, 86, 460, 74
    out = f"<div class='glass' style='left:{x}px;top:{y}px;width:{w}px;height:{h}px'></div>"
    out += I('piece_common', x + 8, y + 6, 62, name='GoalIcon')
    out += at(x + 80, y + 8, T('YOUR FIRST PET', 20, 'xs', name='GoalTitle'))
    out += at(x + w - 14, y + 8, T('2 / 2', 20, 'xs', 'f-lime', name='GoalCount'), w=120, align='right')
    out += bar(x + 80, y + 38, w - 96, 24, 1, 'lime', 'GoalBar') + at(x + 80 + (w - 96) // 2, y + 39, T('READY TO HATCH!', 15, 'xs', name='GoalState'), w=w - 96, align='center')
    return sub('GoalPill', out, btn=True, opens='Incubator')


def hv_menu():
    """The MENU dropdown (16 Oct): Settings · Stats · Servers under the one top-right button. Runtime toggles it."""
    out = f"<div class='glass' style='left:1668px;top:80px;width:252px;height:232px'></div>"
    for i, (col_, ic, lab, nm, opens) in enumerate([('grey', 'settings', 'SETTINGS', 'MenuSettings', 'Settings'),
                                                     ('blue', 'stats', 'STATS', 'MenuStats', 'Stats'),
                                                     ('teal', 'servers', 'SERVERS', 'MenuServers', 'Servers')]):
        out += hv_pill(1680, 98 + i * 70, 228, col_, ic, lab, nm, opens)
    return out


def s_hud(menu=False):
    out = world() + topbar()
    tl = hv_pill(240, 12, 196, 'purple', 'quests', 'QUESTS', 'QuestsButton', 'Quests', badge=True)
    tl += hv_pill(452, 12, 236, 'lime', 'incubator', 'INCUBATOR', 'IncubatorButton', 'Incubator', badge=True)
    # 16 Oct (Hunter, less clutter): SETTINGS, STATS and SERVERS live in the MENU dropdown (hv_menu); one button top-right
    tr = hv_pill(1680, 12, 228, 'grey', 'settings', 'MENU', 'SettingsButton')
    # AFK / Hunt sit on a grey plate; the coloured PlateOn shows while they're on (16 Oct: Hunt is purple, not red)
    # rail 60 px higher than first built (16 Oct) so the Level plate above Gold clears HUNT
    rail = (hv_rail_btn(10, 230, 96, 'gold', 'shop', 'SHOP', 'ShopButton', 'Shop', key='B') + hv_rail_btn(10, 340, 96, 'sky', 'pets', 'PETS', 'PetsButton', 'Pets', key='P')
            + hv_rail_btn(10, 450, 96, 'pink', 'emote', 'EMOTES', 'EmotesButton', 'EmoteWheel', key='G')
            + hv_rail_btn(10, 560, 96, 'grey', 'afk', 'AFK', 'AFKToggle', state='OFF', on_color='blue')
            + hv_rail_btn(10, 670, 96, 'grey', 'hunt', 'HUNT', 'VolunteerToggle', state='ON', on_color='purple'))
    out += grp('TopLeft', tl, 'TL') + grp('TopRight', tr, 'TR') + grp('Goal', hv_goal(), 'TR') + grp('Rail', rail, 'L')
    if EXPORT_STATES or menu:
        out += grp('MenuDrop', hv_menu(), 'TR')
    out += hv_topcenter('LOBBY', 'Next match in 0:12', T('4 / 4 players ready  ·  you start as a Runner', 22, 'xs', name='SublineText'))
    out += grp('Watch', hv_pill(860, 140, 200, 'pink', 'spectate', 'SPECTATE', 'SpectateButton'), 'T')   # shown while a match runs
    plus = sub('GemsPlus', btn(286, 990, 54, 54, 'lime', T('+', 40, 'l'), cls='sm', name='Btn'), btn=True, opens='Shop')   # buy Gems (16 Oct)
    out += grp('Wallet', hv_plate(878, 'gold', '1,250', 'GOLD', 'f-gold', 'Gold') + hv_plate(972, 'gem', '12', 'GEMS', 'f-lime', 'Gems') + plus + hv_level(), 'BL')
    out += hv_ability() + hv_dash('DASH READY', 'Move, then turn + dash')
    return out


def s_hud_match():
    out = world() + topbar()
    pips = ''.join(f"<span class='pip k-lime{' on' if i == 0 else ''}' data-n='StreakPip{i + 1}' style='position:relative;display:inline-block;margin:0 8px'></span>" for i in range(3))
    sub_l = T('Runner  ·  0:21  ·  14 Runners vs 4 Catchers', 22, 'xs', name='SublineText')   # RichText colours at runtime
    streak = at(960, 138, row(T('CLEAN STREAK', 15, 'xs', 'f-dim'), f"<span style='display:inline-flex'>{pips}</span>", gap=8), w=400, align='center')
    out += hv_topcenter('CROSSING 2', 'Cross to the opposite safe side!', sub_l, streak)
    eg = f"<div class='glass' style='left:12px;top:878px;width:340px;height:178px'></div>"
    eg += slot(26, 892, 112, 'rare', 'egg_shiny', name='EggSlot', art_pad=.1)
    eg += at(152, 896, T('YOUR EGG', 16, 'xs', 'f-dim', name='EggTitle')) + at(152, 918, T('LEVEL 2', 44, 'l', 'f-rare', name='EggLevel'))
    for i in range(4):
        eg += f"<div class='pip k-sky{' on' if i < 2 else ''}' data-n='LevelPip{i + 1}' style='left:{158 + i * 38}px;top:984px'></div>"
    eg += at(152, 1022, row(T('pays', 15, 'xs', 'f-dim'), icn('piece_rare', 24, name='PaysIcon'), T('Rare', 15, 'xs', 'f-rare', name='PaysText'), gap=4))
    out += grp('Egg', eg, 'BL')
    fd = ''
    for i, (a, verb, b, ic, fill) in enumerate([('Kai', 'stole', "Mia's Lv 2 egg", 'steal', 'f-red'), ('Zoe', 'is safe with', 'Lv 3', 'safe', 'f-lime'), ('Ben', 'caught', 'Leo', 'catcher', 'f-red')]):
        y = 84 + i * 50
        line = f"<div class='glass' style='left:1530px;top:{y}px;width:378px;height:42px'></div>" + I(ic, 1518, y - 4, 50, name='FeedIcon')
        line += at(1572, y + 10, T(f'{a} {verb} {b}', 18, 'xs', name='FeedText'))   # RichText colours the verb at runtime
        fd += sub(f'Feed{i + 1}', line)
    out += grp('Feed', fd, 'TR')
    out += hv_ability(lobby=False, cd=8) + hv_dash('DASH ON COOLDOWN', 'Space to dash sideways or back', .55)
    if EXPORT_STATES:
        out += grp('Touch', touch_buttons(), 'BR')
    out += cap(560, 470, 'Match: only phase, headline, role/timer/teams, streak, egg level, ability and dash (GDD 14).')
    return out


def touch_buttons():
    """Round thumb buttons (touch only): TAG (Catchers), DASH (LUNGE for Catchers), ABILITY. Each has a
    cooldown shade (Shade, sized by the runtime) and a seconds label."""
    out = ''
    for nm, x, y, d, col_, ic, lab in [('TouchTag', 1690, 640, 190, 'red', 'catcher', 'TAG'), ('TouchDash', 1520, 840, 150, 'sky', 'runner', 'DASH'),
                                       ('TouchAbility', 1730, 860, 150, 'orange', 'ab_dash', 'ABILITY')]:
        inner = f"<div class='hb k-{col_}' style='left:{x}px;top:{y}px;width:{d}px;height:{d}px;border-radius:50%'></div>"
        inner += I(ic, x + int(d * .18), y + int(d * .1), int(d * .64), name='Icon')
        inner += at(x + d // 2, y + d - int(d * .3), T(lab, int(d * .15), 's', name='Label'), w=d, align='center')
        inner += f"<div class='abs hid' data-n='Shade' style='left:{x}px;top:{y}px;width:{d}px;height:{d}px;border-radius:50%;background:rgba(0,0,0,.55)'></div>"
        inner += at(x + d // 2, y + d // 2 - int(d * .17), T('2', int(d * .26), 'l', name='Secs'), w=d, align='center').replace("class='abs", "class='abs hid", 1)
        out += sub(nm, inner, btn=True)
    return out


def s_hud_phone():
    """Landscape phone: same Huss Valley layout, bigger targets (>=124 design px), thumbs kept clear."""
    out = world() + topbar()
    tl = hv_pill(240, 12, 220, 'purple', 'quests', 'QUESTS', 'QuestsButton', 'Quests', badge=True, h=72)
    tl += hv_pill(476, 12, 270, 'lime', 'incubator', 'INCUBATOR', 'IncubatorButton', 'Incubator', badge=True, h=72)
    tr = hv_pill(1640, 12, 268, 'grey', 'settings', 'SETTINGS', 'SettingsButton', 'Settings', h=72)
    rail = (hv_rail_btn(10, 250, 130, 'gold', 'shop', 'SHOP', 'ShopButton', 'Shop') + hv_rail_btn(10, 396, 130, 'sky', 'pets', 'PETS', 'PetsButton', 'Pets')
            + hv_rail_btn(10, 542, 130, 'red', 'hunt', 'HUNT', 'VolunteerToggle', state='ON'))
    out += grp('TopLeft', tl, 'TL') + grp('TopRight', tr, 'TR') + grp('Rail', rail, 'L')
    out += hv_topcenter('LOBBY', 'Next match in 0:12', T('4 / 4 players ready', 26, 's', 'f-lime'))
    out += grp('Wallet', hv_plate(878, 'gold', '1,250', 'GOLD', 'f-gold', 'Gold') + hv_plate(972, 'gem', '12', 'GEMS', 'f-lime', 'Gems'), 'BL')
    out += hv_ability()
    out += "<div class='rbx' style='left:380px;top:640px;width:300px;height:300px'>Roblox thumbstick</div>"
    out += "<div class='rbx' style='left:1640px;top:760px;width:220px;height:220px'>Roblox jump (= DASH)</div>"
    return out

# ================================================================== Quests (QuestConfig: 2 daily, UTC reset)
QUESTS = [  # title, art, progress, target, gold reward, state
    ('Complete 3 crossings', 'art_boards', 2, 3, 25, 'active'),
    ('Make 1 capture', 'art_events', 1, 1, 15, 'ready'),
]


def s_quests():
    x0, y0, W, H = 300, 170, 1320, 760
    b = dual(28, 26, 300, 64, 'purple', bl('Today  [2]', 30), 'TabToday', True)
    b += dual(344, 26, 300, 64, 'purple', bl('Done  [0]', 30), 'TabDone', False)
    lst = ''
    for i, (title, art, p, t, g, st) in enumerate(QUESTS):
        y = 18 + i * 132
        card = f"<img src='{art}.jpg' style='position:absolute;inset:0;width:100%;height:100%;object-fit:cover'>"
        card += "<div class='abs fill' style='background:linear-gradient(90deg,rgba(14,10,22,.94) 0 45%,rgba(14,10,22,.6))'></div>"
        card += tag(14, 12, 'Daily Quest', 'blue', 18, 32)
        card += at(16, 52, T(title, 30, 's', name='QuestName'))
        card += bar(16, 92, 300, 20, p / t, 'lime' if st == 'ready' else 'pink', 'Progress')
        card += at(330, 88, T(f'{p} / {t}', 22, 'xs', 'f-lime' if st == 'ready' else '', name='ProgressText'))
        card += btn(430, 30, 116, 56, 'lime', bl('CLAIM', 24), cls='sm' + ('' if st == 'ready' else ' hid'), name='Claim')
        card += sub('Done', at(440, 44, T('DONE', 22, 's', 'f-lime', name='DoneText')), hid=True)
        lst += box(18, y, 566, 120, card, 'cs r-pink', 'border-radius:14px', name=f'Quest{i + 1}')
    lst += selring(18, 18, 566, 120, r=14)
    lst += box(18, 18 + 2 * 132, 566, 110, at(283, 24, row(icn('clock', 54), col(T('New quests tomorrow', 26, 's'), T('2 fresh quests every day', 18, 'xs', 'f-dim'), gap=0, align='flex-start'), gap=14), w=560, align='center'),
               'cs locked', 'border-radius:14px', name='Tomorrow')
    lst += btn(150, 430, 300, 76, 'lime', bl('CLAIM ALL', 32), name='ClaimAll')
    b += well(28, 112, 604, 520, lst, name='List')
    d = tag(24, 22, 'Daily Quest', 'blue', 20, 38)
    d += at(24, 74, T('Complete 3 crossings', 42, 'l', name='QuestTitle'))
    d += at(26, 130, T('Make it across to the safe zone as a Runner.', 24, 'xs', 'f-dim', name='QuestDesc'))
    d += at(26, 160, T('Each crossing that ends safe counts.', 24, 'xs', 'f-dim', name='QuestDesc2'))
    d += bar(24, 204, 470, 38, 2 / 3, 'pink', 'Progress') + at(260, 208, T('2 / 3', 26, 's', name='ProgressText'), w=470, align='center')

    rw = slot(18, 14, 132, 'gold', 'gold', 'x25', 'Gold', name='Reward1') + slot(166, 14, 132, 'common', 'piece_common', 'x1', 'Bonus', name='Reward2', cls='hid')
    d += well(24, 296, 300, 162, rw, name='Rewards', solid=True, title='Rewards')
    d += btn(344, 382, 270, 76, 'purple', bl('TRACK', 30), name='Track')
    b += well(650, 112, 642, 520, d, name='Detail')
    right = row(icn('clock', 52), T('Resets in 06:42:10', 34, 's', name='ResetText'), gap=8)
    return world('bg_lobby_blur.jpg', False) + dim() + panel('Quests', 'purple', 'Quests', 'quests', b, x0, y0, W, H, right)


# ================================================================== Incubator (GDD 03, 09, 14)
def s_incubator(first=True):
    x0, y0, W, H = 210, 104, 1500, 884
    b = ''
    pc = ''
    for i, m in enumerate(['common', 'rare', 'epic']):
        n = PIECES[m]
        pc += slot(22 + i * 132, 26, 118, m, 'piece_' + m, f'x{n}', TIER_NAME[m], cls='locked' if n == 0 else '', name=f'Piece_{m}', art_pad=.14)
    b += well(26, 40, 434, 170, pc, name='Pieces', title='Your Pieces')
    b = incubator_top(b, first)
    b = incubator_rest(b, first)
    return world('bg_lobby_blur.jpg', False) + dim() + panel('Incubator', 'lime', 'Incubator', 'incubator', b, x0, y0, W, H)


def incubator_top(b, first):
    if EXPORT_STATES:  # Studio export: both top wells, runtime shows one
        b += first_path()
        first = False
    if not first:  # after the first pet: collection progress per family replaces the first-pet path
        tr = ''
        found = {'DoubleDash': 2, 'Decoy': 1, 'Scout': 1}
        for i, (pid, title, ic, colr, blurb, pets) in enumerate(POOLS):
            cx = 22 + i * 106
            live = WAVE[pid] == 1
            tr += slot(cx, 20, 82, colr, ic, cls='fill' if live else 'fill soon', art_pad=.14, name=f'Fam_{pid}',
                       inner_extra='' if live else I('lock', 52, 4, 26))
            tr += at(cx + 41, 112, T(f'{found.get(pid, 0)} / {len(pets)}' if live else f'wave {WAVE[pid]}', 20 if live else 17, 's' if live else 'xs', '' if live else 'f-dim', name=f'FamCount_{pid}'), w=100, align='center')
        coll = well(476, 40, 998, 170, tr, name='Collection', title='Your Collection')
        b += sub('CollectionWrap', coll, hid=True) if EXPORT_STATES else coll
    else:
        b += first_path()
    return b


def first_path():
    tr = ''
    tr += bar(80, 64, 820, 26, 1, 'lime', 'Track')
    for i, (lab, ic) in enumerate([('Start', None), ('Match 1', 'piece_common'), ('Match 2', 'piece_common'), ('Hatch!', 'egg_basic')]):
        nx = 40 + i * 270
        tr += slot(nx, 28, 100, 'gold' if i == 3 else 'common', ic, label=None, name=f'Step{i}', art_pad=.14,
                   inner_extra='' if ic else I('check', 20, 18, 60), cls='fill' if i == 0 else '')
        tr += at(nx + 50, 132, T(lab, 22, 's', 'f-gold' if i == 3 else ''), w=200, align='center')
    return well(476, 40, 998, 170, tr, name='FirstPet', title='Your First Pet', extra=T('free family choice', 18, 'xs', 'f-gold', style='margin-left:12px'))


def incubator_rest(b, first):
    fp = ''
    for i, (pid, title, ic, colr, blurb, pets) in enumerate(POOLS):   # 3 x 3: wave 1 live, waves 2-3 "coming soon"
        s = 106
        cx, cy = 20 + (i % 3) * (s + 12), 22 + (i // 3) * (s + 10)
        live = WAVE[pid] == 1
        livet = slot(0, 0, s, colr, ic, label=title, cls='fill', name='Live', art_pad=.2, label_size=15)
        soont = slot(0, 0, s, colr, ic, label=title, cls='fill soon', name='Soon', art_pad=.2, label_size=15,
                     inner_extra=I('lock', s - 34, 6, 28) + at(10, 8, T(f'W{WAVE[pid]}', 14, 'xs', 'f-dim', name='WaveText')))
        if EXPORT_STATES:   # both looks; runtime picks from EconomyConfig.LAUNCH_FAMILIES
            livet = livet.replace("class='cs", "class='cs" + ('' if live else ' hid'), 1)
            soont = soont.replace("class='cs", "class='cs" + (' hid' if live else ''), 1)
            fp += sub(f'Family_{pid}', f"<div class='abs' style='left:{cx}px;top:{cy}px;width:{s}px;height:{s}px'>{livet}{soont}</div>", btn=True)
        else:
            fp += f"<div class='abs' style='left:{cx}px;top:{cy}px;width:{s}px;height:{s}px'>{livet if live else soont}</div>"
    fp += selring(20, 22, 106, 106, 'FamilySel')
    b += well(26, 262, 380, 372, fp, name='Families', title='Pick A Family', extra=T('more each wave', 16, 'xs', 'f-dim', style='margin-left:10px'))
    pool = POOL['DoubleDash']
    lad = ''
    for i, pet in enumerate(pool[5][:3]):
        t = TIERS[i]
        sx = 48 + i * 246
        sp = slot(sx, 24, 172, t, pet_img(pet), name='Tile', art_pad=.04)
        sp += at(sx + 86, 206, T(P[pet], 22, 's', name='PetName'), w=220, align='center') + at(sx + 86, 236, T(TIER_NAME[t], 18, 'xs', FILL[t], name='TierText'), w=200, align='center')
        sp += at(sx + 86, 266, row(icn('piece_' + t, 26, name='PieceIcon'), T(f'{RECIPES[t][0]} random · {RECIPES[t][1]} pick', 16, 'xs', 'f-dim', name='RecipeText'), gap=4), w=220, align='center')
        lad += sub(f'Species_{t}', sp, btn=True)
    lad += selring(48, 24, 172, 172, 'SpeciesSel')
    cx = 48 + 3 * 246 + 26
    lad += slot(cx, 24, 150, 'crowned', pet_img(pool[5][3]), cls='locked', name='Species_crowned', art_pad=.06, inner_extra=I('lock', 45, 40, 60))
    lad += at(cx + 75, 206, T('Crowned', 22, 's', 'f-gold'), w=180, align='center') + at(cx + 75, 236, T('coming later', 16, 'xs', 'f-dim'), w=140, align='center')
    run, cat = ROLES['DoubleDash']
    lad += at(36, 306, T(f'AS RUNNER  {run}  ·  AS CATCHER  {cat}  ·  you keep it when caught', 19, 'xs', name='RolesText'), name='Roles')   # RichText at runtime
    b += well(422, 262, 1052, 372, lad, name='Ladder', title=f'{pool[1]}  ·  {pool[4]}', extra='')
    if EXPORT_STATES:
        hb = sub('HatchFirst', hatch_first()) + sub('HatchLater', hatch_later(), hid=True)
        b += well(26, 650, 1448, 110, hb, name='HatchBar', solid=True)
        return b
    if first:
        hb = at(30, 16, row(icn('egg_basic', 70), col(T('HATCH YOUR FIRST PET', 32, 's'), T('Shades Shark  ·  Double Dash  ·  costs 2 Common pieces', 20, 'xs', 'f-dim'), gap=2, align='flex-start'), gap=14))
        hb += btn(1000, 12, 420, 86, 'lime', row(bl('HATCH', 38), icn('piece_common', 40), T('x2', 26, 's')), name='BtnHatch')
        hb += tag(810, 34, 'FREE CHOICE', 'gold', 20, 40, name='FreeTag')
    else:
        hb = btn(30, 12, 460, 86, 'grey', row(icn('dice', 44), bl('RANDOM FAMILY', 30), icn('piece_common', 34), T('x2', 24, 's')), name='BtnRandom')
        hb += btn(520, 12, 520, 86, 'lime', row(icn('target', 44), bl('HATCH DOUBLE DASH', 30), icn('piece_common', 34), T('x3', 24, 's')), name='BtnFocus')
    b += well(26, 650, 1448, 110, hb, name='HatchBar', solid=True)
    return b


def hatch_first():
    hb = at(30, 16, row(icn('egg_basic', 70, name='HatchEgg'), col(T('HATCH YOUR FIRST PET', 32, 's', name='HatchTitle'), T('Shades Shark  ·  Double Dash  ·  costs 2 Common pieces', 20, 'xs', 'f-dim', name='HatchSub'), gap=2, align='flex-start'), gap=14))
    hb += btn(1000, 12, 420, 86, 'lime', row(bl('HATCH', 38), icn('piece_common', 40, name='CostIcon'), T('x2', 26, 's', name='CostText')), name='BtnHatch')
    hb += btn(1000, 12, 420, 86, 'grey', row(bl('HATCH', 38), icn('piece_common', 40, name='CostIcon'), T('x2', 26, 's', name='CostText')), name='BtnHatchPoor', cls='hid')
    hb += tag(810, 34, 'FREE CHOICE', 'gold', 20, 40, name='FreeTag')
    return hb


def hatch_later():
    hb = btn(30, 12, 460, 86, 'grey', row(icn('dice', 44), bl('RANDOM FAMILY', 30), icn('piece_common', 34, name='CostIcon'), T('x2', 24, 's', name='CostText')), name='BtnRandom')
    hb += btn(520, 12, 560, 86, 'lime', row(icn('target', 44), bl('HATCH DOUBLE DASH', 30), icn('piece_common', 34, name='CostIcon'), T('x3', 24, 's', name='CostText')), name='BtnFocus')
    hb += btn(520, 12, 560, 86, 'grey', row(icn('target', 44), bl('HATCH DOUBLE DASH', 30), icn('piece_common', 34, name='CostIcon'), T('x3', 24, 's', name='CostText')), name='BtnFocusPoor', cls='hid')
    hb += at(1100, 34, T('2 / 3 Common pieces', 22, 's', 'f-dim', name='HaveText'))
    return hb


# ================================================================== Pets (inventory + preview, equip)
OWNED = [('DoubleDash', 'ShadesShark', 3, True), ('DoubleDash', 'SurferDog', 1, False), ('Decoy', 'GamerAxolotl', 2, False), ('Scout', 'SeagullScout', 1, False),
         ('Decoy', 'BanditRaccoon', 1, False), ('DoubleDash', 'ThunderWolf', 1, False)]
LAUNCH_PETS = sum(len(p[5]) for p in POOLS if WAVE[p[0]] == 1)   # wave 1 families only (11)


def s_pets():
    x0, y0, W, H = 250, 160, 1420, 800
    b = ''
    for i, (lab, active) in enumerate([(f'All  {len(OWNED)}', True), ('Double Dash', False), ('Decoy', False), ('Scout', False)]):
        b += dual(26 + i * 200, 22, 186, 54, 'purple', bl(lab, 20), f'Filter{i}', active, cls='sm')
    g = ''
    for i, (pid, pet, st, eq) in enumerate(OWNED):
        tier = tier_of(pid, pet)
        gx, gy = 18 + (i % 4) * 196, 18 + (i // 4) * 210
        extra = at(34, 150, stars(st, 3, 24), name='Stars')
        extra += tag(66, 8, 'EQUIPPED', 'lime', 14, 28, name='EquippedTag').replace("class='ctag", "class='ctag" + ('' if eq else ' hid'), 1)
        g += sub(f'Pet{i + 1}', slot(gx, gy, 182, tier, pet_img(pet, st), name='Tile', art_pad=.05, inner_extra=extra), btn=True)
    if EXPORT_STATES:   # one hidden tile per rarity so runtime clones the right rim
        for k, t in enumerate(['common', 'rare', 'epic']):
            g += sub(f'Proto_{t}', slot(18, 18, 182, t, pet_img(POOL['DoubleDash'][5][k]), name='Tile', art_pad=.05,
                                        inner_extra=at(34, 150, stars(1, 3, 24), name='Stars') + tag(66, 8, 'EQUIPPED', 'lime', 14, 28, name='EquippedTag').replace("class='ctag", "class='ctag hid", 1)), btn=True, hid=True)
    g += selring(18, 18, 182, 182, 'PetSel')
    for j in range(len(OWNED), LAUNCH_PETS):
        gx, gy = 18 + (j % 4) * 196, 18 + (j // 4) * 210
        g += slot(gx, gy, 182, 'locked', None, cls='locked', name=f'Empty{j}', inner_extra=at(91, 64, T('?', 56, 'l', 'f-dim', name='Q'), w=180, align='center'))
    b += well(26, 92, 820, 566, g, name='Grid', style='overflow:hidden')
    pv = slot(110, 18, 340, 'common', pet_img('ShadesShark', 3), name='PreviewSlot', art_pad=.06, cls='fill')
    pv += at(280, 372, T('Shades Shark', 44, 'l', name='PetName'), w=540, align='center')
    pv += at(280, 428, row(T('Common', 22, 'xs', 'f-common', name='RarityText'), stars(3, 3, 26, name='Stars'), T('copies', 18, 'xs', 'f-dim'), gap=10), w=540, align='center')
    pv += at(30, 470, row(icn('ab_dash', 52, name='AbilityIcon'), col(T('DOUBLE DASH', 26, 's', name='AbilityName'), T('Two quick dashes in a row  ·  cooldown 12s', 18, 'xs', 'f-dim', name='AbilityDesc'), gap=0, align='flex-start'), gap=10))
    pv += btn(30, 540, 476, 70, 'lime', row(icn('check', 36), bl('EQUIPPED', 28)), name='BtnEquipped')
    pv += btn(30, 540, 476, 70, 'sky', bl('EQUIP', 28), name='BtnEquip', cls='hid' if EXPORT_STATES else 'hid')
    b += well(862, 22, 532, 636, pv, name='Preview')
    right = row(icn('pets', 50), T(f'{len(OWNED)} / {LAUNCH_PETS} found', 32, 's', name='CountText'), gap=6)
    if EXPORT_STATES:
        b += sub('EmptyState', well(26, 92, 820, 566, at(410, 190, col(icn('egg_basic', 120), T('No pets yet', 40, 'l'), T('Hatch one at the Incubator', 24, 'xs', 'f-dim'), gap=8), w=800, align='center')
                                     + btn(260, 430, 300, 76, 'lime', bl('INCUBATOR', 30), name='GoIncubator', opens='Incubator'), name='EmptyWell'), hid=True)
    return world('bg_lobby_blur.jpg', False) + dim() + panel('Pets', 'sky', 'Pets', 'pets', b, x0, y0, W, H, right)


# ================================================================== Shop (EconomyConfig.SHOP + GDD emote)
SHOP = [  # icon, name, wallet, price, kind label, desc, state
    ('trail', 'Sparkle Trail', 'gold', '40', 'One match', 'Your egg leaves sparkles.', 'ok'),
    ('trail_ember', 'Ember Trail', 'gold', '60', 'One match', 'Your egg leaves embers.', 'ok'),
    ('burst', 'Confetti Burst', 'gold', '75', 'Lobby, once', 'Pop confetti over your head.', 'ok'),
    ('emote', 'Happy Dance', 'gold', '500', 'Keep forever', 'A basic emote.', 'owned'),
    ('case_frost', 'Frost Egg Case', 'gold', '900', 'Keep forever', 'An icy shell around your egg.', 'ok'),
    ('entrance', 'Bolt Entrance', 'gold', '1,400', 'Keep forever', 'Arrive with a lightning strike.', 'poor'),
    ('case_sunset', 'Sunset Egg Case', 'gold', '2,400', "This week's colour", 'Gold colourway, keep forever.', 'poor'),
]


def shop_card(x, y, it, w=250, h=278, sel=False):
    icon, name, wal, price, kind, desc, st = it
    r = 'gold' if wal == 'gold' else 'lime'
    inner = I(icon, (w - 132) // 2, 12, 132, name='Icon')
    inner += at(w // 2, 146, T(name, 24, 's', name='ItemName'), w=w + 10, align='center')
    inner += at(w // 2, 178, T(kind if st != 'poor' else 'need more ' + ('Gold' if wal == 'gold' else 'Gems'), 17, 'xs', 'f-dim' if st != 'poor' else 'f-red', name='Kind'), w=w, align='center')
    inner += shop_buttons(18, h - 68, w - 36, 54, wal, price, st, 'sm', 26)
    return box(x, y, w, h, inner, f'cs r-{r}', 'border-radius:16px', name=f'Item_{name.replace(" ", "")}')


def shop_buttons(x, y, w, h, wal, price, st, cls, ts):
    """Every buy-button state, stacked; runtime shows one: BtnBuy (can afford), BtnPoor (can't), BtnOwned,
    BtnWear / BtnTakeOff (cases), BtnUse (confetti you own)."""
    cur = icn(wal if wal != 'gems' else 'gem', int(h * .62), name='CurrencyIcon')
    states = [('BtnBuy', 'lime', row(cur, bl(price, ts, name='Price')), st == 'ok'),
              ('BtnPoor', 'grey', row(cur, bl(price, ts, name='Price')), st == 'poor'),
              ('BtnOwned', 'grey', row(icn('check', int(h * .55)), bl('OWNED', ts - 2)), st == 'owned'),
              ('BtnWear', 'sky', bl('WEAR', ts), st == 'wear'),
              ('BtnTakeOff', 'grey', bl('TAKE OFF', ts - 2), st == 'takeoff'),
              ('BtnUse', 'gold', row(bl('USE', ts), T('x1', ts - 6, 's', name='UseCount')), st == 'use')]
    out = ''
    for nm, col_, lab, on in states:
        if on or EXPORT_STATES:
            out += btn(x, y, w, h, col_, lab, cls=cls + ('' if on else ' hid'), name=nm)
    return out


GEM_PACKS = [(100, 49, ''), (225, 99, ''), (500, 199, 'POPULAR'), (1100, 399, ''), (2400, 799, ''), (5000, 1499, 'BEST VALUE')]   # EconomyConfig.GEM_PACKS


def shop_right():
    return row(icn('gold', 48), T('1,250', 34, 's', 'f-gold', name='GoldText'), icn('gem', 48), T('12', 34, 's', 'f-lime', name='GemsText'), gap=8)


def gem_packs(hid=False):
    """Buy Gems (16 Oct): six Robux developer products. Pack art grows with the pack (gempack1..6 when the ChatGPT
    icons arrive; the gem icon until then). Runtime fills amount, price and the tag from EconomyConfig.GEM_PACKS."""
    g = ''
    for i, (gems, rbx, tag_) in enumerate(GEM_PACKS):
        x, y = 18 + (i % 3) * 506, 16 + (i // 3) * 296
        sz = 118 + i * 14
        inner = I('gem', 30, (230 - sz) // 2 + 4, sz, name='Icon')
        inner += at(464, 44, T(f'{gems:,}', 60, 'l', 'f-lime', name='Amount'), w=280, align='right')
        inner += at(464, 114, T('GEMS', 26, 's', 'f-dim'), w=200, align='right')
        inner += tag(310, 12, tag_ or 'POPULAR', 'pink' if tag_ != 'BEST VALUE' else 'gold', 18, 34, name='Tag').replace("class='ctag", "class='ctag" + ('' if tag_ else ' hid'), 1)
        inner += btn(30, 194, 432, 70, 'purple', row(icn('robux', 40), bl(f'{rbx:,}', 34, name='Price')), name='BtnBuy')
        g += box(x, y, 492, 282, inner, 'cs r-lime', 'border-radius:16px', name=f'Pack{i + 1}')
    page = well(26, 102, 1528, 606, g, name='Packs')
    page += at(790, 724, T('Gems buy looks and Emote Crates, never pets or abilities.  Purchases go through Roblox.', 18, 'xs', 'f-dim'), w=1300, align='center')
    return sub('GetGemsPage', page, hid=hid)


# 16 Oct (Hunter): Trails, Egg Cases and Effects folded into one Cosmetics tab (filter chips inside) to keep the bar short
SHOP_TABS = [('featured', 'Featured', 'star', 'gold'), ('cosmetics', 'Cosmetics', 'case', 'gold'), ('emotes', 'Emotes', 'emote', 'gold'),
             ('passes', 'Passes', 'crown', 'gold'), ('gems', 'Gems', 'gem', 'lime')]
COS_FILTERS = [('all', 'All'), ('trails', 'Trails'), ('cases', 'Egg Cases'), ('effects', 'Effects')]
# Shop by what you buy (16 Oct, Huss Valley's organisation): id, name, wallet, price, robux, kind label, sub, desc 1, desc 2, icon
SHOP_ITEMS = {
    'trails': [('trail_spark', 'Sparkle Trail', 'gold', 40, None, 'ONE MATCH', 'EGG TRAIL', 'Your egg leaves sparkles.', 'Lasts one match.', 'trail'),
               ('trail_ember', 'Ember Trail', 'gold', 60, None, 'ONE MATCH', 'EGG TRAIL', 'Your egg leaves embers.', 'Lasts one match.', 'trail_ember'),
               ('trailp_rainbow', 'Rainbow Trail', 'gems', 150, 79, 'KEEP FOREVER', 'EGG TRAIL', 'A rainbow trail on your egg', 'in every match.', 'trail_rainbow')],
    'cases': [('case_frost', 'Frost Egg Case', 'gold', 900, None, 'KEEP FOREVER', 'EGG CASE', 'An icy shell around', 'the egg you carry.', 'case_frost'),
              ('case_sunset', 'Sunset Egg Case', 'gold', 2400, None, "THIS WEEK'S COLOUR", 'EGG CASE', "This week's Gold colourway.", 'Yours to keep.', 'case_sunset')],
    'effects': [('burst_confetti', 'Confetti Burst', 'gold', 75, None, 'LOBBY, ONCE', 'LOBBY EFFECT', 'Pop confetti over your head.', 'One use per buy.', 'burst'),
                ('entrance_bolt', 'Bolt Entrance', 'gold', 1400, None, 'KEEP FOREVER', 'ENTRANCE', 'Arrive in the lobby with', 'a lightning strike.', 'entrance'),
                ('fx_gold', 'Gold Ability Colors', 'gems', 250, 119, 'KEEP FOREVER', 'ABILITY FX', 'Your ability effects turn gold.', 'Same timing and size.', 'abilityfx_gold'),
                ('hatch_royal', 'Royal Hatching', 'gems', 350, 159, 'KEEP FOREVER', 'HATCH FX', 'A bigger hatching ceremony', 'at the incubator.', 'hatchfx')],
}


def price_btns(x, y, w, h, wallet, price, robux, ts=28):
    """Currency button (BtnPrice, or grey BtnPoor), plus a purple Robux button (BtnRobux) for Gem items."""
    cur = 'gem' if wallet == 'gems' else 'gold'
    col_ = 'lime' if wallet == 'gems' else 'gold'
    half = (w - 12) // 2 if robux else w
    out = btn(x, y, half, h, col_, row(icn(cur, int(h * .62)), bl(f'{price:,}', ts, name='Price')), name='BtnPrice')
    if EXPORT_STATES:
        out += btn(x, y, half, h, 'grey', row(icn(cur, int(h * .62)), bl(f'{price:,}', ts, name='Price')), name='BtnPoor', cls='hid')
    if robux:
        out += btn(x + half + 12, y, half, h, 'purple', row(icn('robux', int(h * .58)), bl(f'{robux:,}', ts, name='RobuxPrice')), name='BtnRobux')
    return out


def state_btns(x, y, w, h, st=None, ts=26):
    out = ''
    for nm, col_, lab in (('BtnOwned', 'grey', row(icn('check', int(h * .55)), bl('OWNED', ts))), ('BtnWear', 'sky', bl('WEAR', ts)),
                          ('BtnTakeOff', 'grey', bl('TAKE OFF', ts)), ('BtnUse', 'gold', row(bl('USE', ts), T('x1', ts - 4, 's', name='UseCount')))):
        if EXPORT_STATES or st == nm:
            out += btn(x, y, w, h, col_, lab, name=nm, cls='' if st == nm else 'hid')
    return out


def item_card(x, y, it, name=None, st=None):
    iid, nm, wal, price, rbx, kind, sub_, d1, d2, icon = it
    w, h = 360, 588
    inner = tag(16, 14, kind, 'gold' if wal == 'gold' else 'lime', 15, 30, name='KindTag')
    inner += I(icon, 80, 56, 200, name='Icon')
    inner += at(w // 2, 262, T(nm, 34, 'l', name='ItemName'), w=w, align='center')
    inner += at(w // 2, 306, T(sub_, 17, 'xs', 'f-gold' if wal == 'gold' else 'f-lime', name='Sub'), w=w, align='center')
    inner += at(w // 2, 342, T(d1, 18, 'xs', 'f-dim', name='Desc'), w=w - 20, align='center')
    inner += at(w // 2, 368, T(d2, 18, 'xs', 'f-dim', name='Desc2'), w=w - 20, align='center')
    inner += at(w // 2, 404, T('Looks only, no gameplay edge.', 15, 'xs', 'f-dim', name='Note'), w=w - 20, align='center')
    inner += price_btns(18, 444, w - 36, 66, wal, price, rbx)
    inner += state_btns(18, 444, w - 36, 66, st)
    inner += at(w // 2, 528, T('', 16, 'xs', 'f-dim', name='Have'), w=w - 20, align='center')
    return box(x, y, w, h, inner, 'cs ' + ('r-gold' if wal == 'gold' else 'r-lime'), 'border-radius:16px', name=name or f'Card_{iid}')


def feature_card(x, y, it, title_tag, perks, name):
    iid, nm, wal, price, rbx, kind, sub_, d1, d2, icon = it
    w, h = 752, 620
    acc = 'gold' if wal == 'gold' else 'lime'
    inner = tag(20, 18, title_tag, 'pink', 17, 34, name='FeatTag')
    inner += at(26, 66, T(nm.upper(), 52, 'xl', name='Title'))
    inner += at(28, 132, T(f'{d1} {d2}', 20, 's', name='Tagline'))
    for k, (pic, a, b_) in enumerate(perks):
        yy = 178 + k * 92
        inner += box(22, yy, 330, 80, I(pic, 10, 8, 62) + at(84, 12, T(a, 22, 's', name='PerkTitle')) + at(86, 44, T(b_, 15, 'xs', 'f-dim', name='PerkSub')),
                     'cw solid', 'border-radius:10px', name=f'Perk{k + 1}')
    # the glow box exports as one flat image, so the item art sits on top of it (inside, the exporter dropped it)
    inner += box(370, 178, 360, 264, '', 'cw', 'border-radius:12px;background:radial-gradient(rgba(255,255,255,.18),rgba(0,0,0,.25))', name='ArtBox')
    inner += I(icon, 440, 200, 220, name='Icon')
    inner += price_btns(22, 470, 708, 84, wal, price, rbx, 36)
    inner += state_btns(22, 470, 708, 84, None, 32)
    inner += at(w // 2, 570, T('', 17, 'xs', 'f-dim', name='Have'), w=w - 40, align='center')
    return box(x, y, w, h, inner, f'cs r-{acc}', 'border-radius:18px', name=name)


# Halloween featured pets (HOS-HWN-001, 17 Oct): three limited pets sold outright on the Featured page until Nov 1.
# Buying one gives the pet and its family's ability (Hunter's exception to looks-only, for these pets only).
# Runtime (HalloweenShop): while EconomyConfig.HALLOWEEN.endsAt is in the future the HalloweenRow shows and FeatA /
# FeatB hide; it fills EndsIn, price / OWNED / poor states from the item, and hides the row after the end date.
HWN_PETS = [  # id, name, rarity, rarity colour, family icon, family, line, wallet, price, robux, portrait, card colour
    ('hwn_wraith', "Jack-o'-Lantern", 'LEGENDARY', 'gold', 'ab_invis', 'INVISIBILITY', 'Vanishes in a burst of embers.', 'robux', 0, 399, 'pet_jack_o_lantern_t1', 'orange'),
    ('hwn_cat', "Witch's Cat", 'EPIC', 'violet', 'ab_decoy', 'DECOY', 'Fake clones pop in cauldron smoke.', 'gems', 250, None, 'pet_witch_cat_t1', 'lime'),
    ('hwn_mummy', 'Mummy', 'EPIC', 'violet', 'ab_shield', 'GUARDIAN', 'A bandage shield whips round you.', 'gems', 250, None, 'pet_mummy_t1', 'sky'),
]
# joins Featured from Oct 24 (HalloweenShop.ROTATION): Dragon NEW in the left slot, Jack-o'-Lantern, then the Cat and the
# Mummy swapping daily in the third slot, so all four stay buyable in the last week
HWN_DRAGON = ('hwn_dragon', 'Bone Dragon', 'LEGENDARY', 'gold', 'ab_tempest', 'TEMPEST', 'Bone shards blast, soul fire storms.', 'robux', 0, 399, 'pet_bone_dragon_t1', 'violet')


def hwn_card(x, y, it, st='ok', ends='ENDS IN 14D 13H', new=False, swap=None):
    """one Halloween pet card (494 x 620): rarity + countdown tags, the pet, its ability, one price button."""
    iid, nm, rar, rc, fam_ic, fam, line, wal, price, rbx, pic, acc = it
    w, h = 494, 620
    inner = tag(18, 18, rar, rc, 17, 34, name='RarityTag')
    inner += tag(w - 214, 18, ends, 'pink', 17, 34, name='EndsTag')
    if new or EXPORT_STATES:
        inner += tag(18, 58, 'NEW', 'lime', 17, 34, name='NewTag').replace("class='ctag", "class='ctag" + ('' if new else ' hid'), 1)
    if swap or EXPORT_STATES:
        inner += tag(w - 214, 58, swap or 'SWAPS DAILY', 'violet', 15, 30, name='SwapTag').replace("class='ctag", "class='ctag" + ('' if swap else ' hid'), 1)
    inner += box(18, 66, w - 36, 286, '', 'cw', 'border-radius:12px;background:radial-gradient(rgba(255,170,60,.22),rgba(0,0,0,.35))', name='ArtBox')
    inner += I(pic, (w - 280) // 2, 70, 280, name='Icon')
    inner += at(w // 2, 364, T(nm.upper(), 40, 'xl', name='Title'), w=w, align='center')
    inner += at(w // 2, 418, row(icn(fam_ic, 34), T(fam, 22, 's', 'f-gold', name='Family'), gap=8), w=w, align='center')
    inner += at(w // 2, 458, T(line, 18, 'xs', 'f-dim', name='Tagline'), w=w - 30, align='center')
    bx, by, bw, bh = 22, 494, w - 44, 76
    if wal == 'robux':
        inner += btn(bx, by, bw, bh, 'purple', row(icn('robux', 46), bl(f'{rbx:,}', 34, name='RobuxPrice')), name='BtnRobux', cls='' if st == 'ok' else 'hid')
    else:
        inner += btn(bx, by, bw, bh, 'lime', row(icn('gem', 46), bl(f'{price:,}', 34, name='Price')), name='BtnPrice', cls='' if st == 'ok' else 'hid')
        if EXPORT_STATES or st == 'poor':
            inner += btn(bx, by, bw, bh, 'grey', row(icn('gem', 46), bl(f'{price:,}', 34, name='Price')), name='BtnPoor', cls='' if st == 'poor' else 'hid')
    if EXPORT_STATES or st == 'owned':
        inner += btn(bx, by, bw, bh, 'grey', row(icn('check', 42), bl('OWNED', 32)), name='BtnOwned', cls='' if st == 'owned' else 'hid')
    have = {'ok': 'Yours to keep after the event', 'poor': 'You have 120 Gems', 'owned': 'In your pets  ·  equip it from Pets'}[st]
    inner += at(w // 2, 584, T(have, 16, 'xs', 'f-dim', name='Have'), w=w - 30, align='center')
    return box(x, y, w, h, inner, f'cs r-{acc}', 'border-radius:18px', name='Hwn_' + iid.split('_')[1].capitalize())


def hwn_row_oct24(day=0):
    """from Oct 24 (Hunter 17 Oct: "show mummy instead of witches cat in the shop"): Bone Dragon (NEW) | Jack-o'-Lantern |
    Mummy. The Witch's Cat leaves Featured that week (buyers keep it)."""
    cards = hwn_card(26, 102, HWN_DRAGON, 'ok', 'ENDS IN 7D 0H', new=True)
    cards += hwn_card(26 + 517, 102, HWN_PETS[0], 'ok', 'ENDS IN 7D 0H')
    cards += hwn_card(26 + 1034, 102, HWN_PETS[2], 'ok', 'ENDS IN 7D 0H')
    return sub('HalloweenRow', cards)


def hwn_row(states=('ok', 'ok', 'ok'), hid=False):
    cards = ''.join(hwn_card(26 + i * 517, 102, it, st) for i, (it, st) in enumerate(zip(HWN_PETS, states)))
    return sub('HalloweenRow', cards, hid=hid)


def s_hwn_templates():
    """HOS-HWN-001 export page (ui_hwn/rbx.json): each Halloween pet card becomes a template in
    ReplicatedStorage.HalloweenUITemplates; Controllers/HalloweenShopUI clones the three into the Shop's PageFeatured
    (in place of FeatA / FeatB) while the sale runs, and fills EndsTag / buttons / Have like the Featured cards."""
    out = "<div class='abs fill' style='background:#16161a'></div>"
    for i, it in enumerate(HWN_PETS + [HWN_DRAGON]):
        out += grp('HwnCard' + it[0].split('_')[1].capitalize(), hwn_card(40 + (i % 3) * 540, 40 + (i // 3) * 660, it, 'ok'), 'TL')
    return out


def pass_card(x, y, nm, robux, title_tag, line, icon, acc, perks, name):
    """A game pass (16 Oct): Featured-card layout, one purple Robux button (BtnBuy) or OWNED (BtnOwned)."""
    w, h = 752, 620
    inner = tag(20, 18, title_tag, 'pink', 17, 34, name='PassTag')
    inner += at(26, 66, T(nm.upper(), 52, 'xl', name='Title'))
    inner += at(28, 132, T(line, 20, 's', name='Tagline'))
    for k, (pic, a, b_) in enumerate(perks):
        yy = 178 + k * 92
        inner += box(22, yy, 330, 80, I(pic, 10, 8, 62) + at(84, 12, T(a, 22, 's', name='PerkTitle')) + at(86, 44, T(b_, 15, 'xs', 'f-dim', name='PerkSub')),
                     'cw solid', 'border-radius:10px', name=f'Perk{k + 1}')
    # the glow box exports as one flat image, so the item art sits on top of it (inside, the exporter dropped it)
    inner += box(370, 178, 360, 264, '', 'cw', 'border-radius:12px;background:radial-gradient(rgba(255,255,255,.18),rgba(0,0,0,.25))', name='ArtBox')
    inner += I(icon, 440, 200, 220, name='Icon')
    inner += btn(22, 470, 708, 84, 'purple', row(icn('robux', 52), bl(f'{robux:,}', 36, name='Price')), name='BtnBuy')
    if EXPORT_STATES:
        inner += btn(22, 470, 708, 84, 'grey', row(icn('check', 46), bl('OWNED', 32)), name='BtnOwned', cls='hid')
    inner += at(w // 2, 570, T('Bought once, yours on every server.', 17, 'xs', 'f-dim', name='Have'), w=w - 40, align='center')
    return box(x, y, w, h, inner, f'cs r-{acc}', 'border-radius:18px', name=name)


def s_shop(tab='featured', hwn=None, oct24=None):
    """Shop by what you buy (16 Oct, after Huss Valley): Featured, Cosmetics, Emotes, Passes, Gems. Gold items cost
    Gold; Gem items show a Gem price and a Robux price. Short on Gems -> the Robux price is offered (or the Gems tab)."""
    x0, y0, W, H = 170, 118, 1580, 892
    b = ''
    for i, (key, lab, ic, col_) in enumerate(SHOP_TABS):
        b += dual(26 + i * 306, 20, 290, 62, col_, row(icn(ic, 38), bl(lab, 26)), 'Tab' + lab.replace(' ', ''), tab == key, cls='sm')
    # Featured: this week's colourway + a spotlight item
    feat = feature_card(26, 102, SHOP_ITEMS['cases'][1], "THIS WEEK'S COLOURWAY  ·  NEW IN 3D 4H",
                        [('case', 'Keep forever', 'Wear it every match'), ('egg_golden', 'Gold colourway', 'Only this week'), ('check', 'Looks only', 'No gameplay edge')], 'FeatA')
    feat += feature_card(800, 102, SHOP_ITEMS['effects'][3], 'SPOTLIGHT',
                         [('hatchfx', 'Bigger ceremony', 'Light beams and fanfare'), ('incubator', 'Every hatch', 'At the incubator'), ('check', 'Looks only', 'No gameplay edge')], 'FeatB')
    if oct24 is not None:
        feat = sub('FeatPair', feat, hid=True) + hwn_row_oct24(oct24)
    elif hwn or EXPORT_STATES:   # Halloween event: the three pets replace the two cards (FeatA / FeatB hide at runtime)
        feat = (sub('FeatPair', feat, hid=True) if hwn else feat) + hwn_row(hwn or ('ok', 'ok', 'ok'), hid=not hwn)
    b += sub('PageFeatured', feat, hid=tab != 'featured')
    # Category pages: the runtime fills Cards from EconomyConfig.SHOP (ProtoGold / ProtoGems)
    # Cosmetics: filter chips, then one row of cards (scrolls sideways at runtime once there are more than four)
    if tab == 'cosmetics' or EXPORT_STATES:
        chips = ''.join(dual(26 + i * 196, 0, 184, 46, 'gold', bl(lab, 21), 'Filter' + key.capitalize(), key == 'all', cls='sm')
                        for i, (key, lab) in enumerate(COS_FILTERS))
        b += sub('CosFilters', at(0, 102, chips), hid=tab != 'cosmetics')
    if tab == 'cosmetics':
        allit = SHOP_ITEMS['trails'] + SHOP_ITEMS['cases'] + SHOP_ITEMS['effects']
        cards = ''.join(item_card(26 + i * 384, 160, it) for i, it in enumerate(allit[:4]))
        b += sub('PageItems', cards)
    elif EXPORT_STATES:
        b += sub('PageItems', sub('ProtoGold', item_card(26, 160, SHOP_ITEMS['trails'][0], name='Card'), hid=True)
                 + sub('ProtoGems', item_card(26, 160, SHOP_ITEMS['trails'][2], name='Card'), hid=True), hid=True)
    # Emotes: the Emote Crate
    if tab == 'emotes' or EXPORT_STATES:
        cr = I('gift', 40, 40, 360, name='CrateArt')
        cr += at(440, 46, T('EMOTE CRATE', 60, 'xl'))
        cr += at(442, 124, T('One of 51 emotes per crate  ·  every chance shown inside', 20, 's', name='CrateSub'))
        for k, (r, lab, odds) in enumerate([('common', 'COMMON', '2.88% each'), ('rare', 'RARE', '2% each'), ('epic', 'EPIC', '1.25% each'), ('crowned', 'LEGENDARY', '1% each')]):
            cr += at(444 + (k % 2) * 330, 176 + (k // 2) * 40, row(T(lab, 22, 's', FILL.get(r, '')), T(odds, 20, 'xs', 'f-dim'), gap=12))
        cr += at(444, 268, T('A duplicate refunds Gems.  Emotes you win go on your wheel (G).', 18, 'xs', 'f-dim'))
        cr += btn(440, 316, 340, 84, 'lime', row(icn('gem', 50), bl('250', 36)), name='BtnCrateGems')
        cr += btn(796, 316, 340, 84, 'purple', row(icn('robux', 46), bl('149', 36)), name='BtnCrateRobux')
        cr += btn(440, 418, 696, 64, 'grey', bl('SEE ALL 51 EMOTES', 26), name='BtnSeeEmotes')
        page = box(26, 102, 1528, 560, cr, 'cs r-pink', 'border-radius:18px', name='CrateCard')
        b += sub('PageEmotes', page, hid=tab != 'emotes')
    # Passes: VIP and 2x XP (game passes; Hunter 16 Oct: VIP +25% XP stacking with 2x XP); the runtime fills price / OWNED from EconomyConfig.PASSES
    if tab == 'passes' or EXPORT_STATES:
        pg = pass_card(26, 102, 'VIP', 499, 'FOREVER', 'Stand out in every lobby and every match.', 'crown', 'gold',
                       [('star', '+25% match XP', 'Stacks with 2x XP'), ('crown', 'VIP tag', 'Over your head and in chat'),
                        ('emote', 'Honored One emote', 'A legendary dance, yours')], 'PassVip')
        pg += pass_card(800, 102, '2x XP', 199, 'FOREVER', 'Every match pays double XP.', 'star', 'sky',
                        [('star', 'Double match XP', 'Level up twice as fast'), ('gift', 'Level-up rewards', 'Gold every level, Gems every 5th'),
                         ('check', 'Fair play', 'Levels change nothing in a match')], 'PassXp2x')
        b += sub('PagePasses', pg, hid=tab != 'passes')
    if tab == 'gems' or EXPORT_STATES:
        b += gem_packs(hid=tab != 'gems')
    return world('bg_lobby_blur.jpg', False) + dim() + panel('Shop', 'gold', 'Shop', 'shop', b, x0, y0, W, H, shop_right())


def s_shop_robux():
    """Robux Gem packs (GDD 06 prices). NOT LIVE: Features.SHOP_PURCHASES = false and no product ids yet."""
    x0, y0, W, H = 260, 170, 1400, 760
    b = btn(26, 22, 260, 64, 'grey', row(icn('gold', 40), bl('Gold', 30)), name='TabGold')
    b += btn(300, 22, 260, 64, 'grey', row(icn('gem', 40), bl('Gems', 30)), name='TabGems')
    b += btn(574, 22, 300, 64, 'lime', row(icn('robux', 40), bl('Get Gems', 30)), name='TabGetGems')
    g = ''
    for i, (gems, rbx) in enumerate([(100, 49), (225, 99), (500, 199), (1100, 399), (2400, 799), (5000, 1499)]):
        x, y = 18 + (i % 3) * 446, 16 + (i // 3) * 262
        inner = I('gem', 24, 16, 130 + i * 6)
        inner += at(408, 40, T(f'{gems:,}', 54, 'l', 'f-lime'), w=220, align='right') + at(408, 104, T('GEMS', 24, 's', 'f-dim'), w=220, align='right')
        if i == 2:
            inner += tag(240, 12, 'POPULAR', 'pink', 18, 34)
        inner += btn(30, 168, 372, 58, 'lime', row(icn('robux', 34), bl(f'{rbx:,}', 30)), cls='sm', name='BtnBuy')
        g += box(x, y, 432, 248, inner, 'cs r-sky', 'border-radius:16px', name=f'Pack{i + 1}')
    b += well(26, 100, 1348, 544, g, name='Packs')
    out = world('bg_lobby_blur.jpg', False) + dim() + panel('ShopGems', 'gold', 'Shop', 'shop', b, x0, y0, W, H)
    out += cap(500, 960, 'Ready for later: Robux Gem packs stay hidden until you approve real developer products (GDD 06 prices).')
    return out


# ================================================================== Stats (ProfileLogic stats)
def s_stats():
    x0, y0, W, H = 330, 180, 1260, 740
    rows = [('trophy', 'Wins', '14', 'gold'), ('safe', 'Safe crossings', '96', 'lime'), ('steal', 'Eggs stolen', '41', 'red'),
            ('egg_golden', 'Best egg', 'Level 4', 'gold'), ('incubator', 'Pets hatched', '8', 'sky'), ('hunt', 'Started as Catcher', '9', 'pink'),
            ('gold', 'Gold earned', '6,340', 'gold'), ('gem', 'Gems earned', '212', 'lime'), ('runner', 'Matches played', '153', 'violet')]
    b = ''
    for i, (ic, lab, val, c) in enumerate(rows):
        x, y = 26 + (i % 3) * 402, 26 + (i // 3) * 196
        inner = I(ic, 14, 22, 120, name='Icon') + at(146, 34, T(lab, 22, 'xs', 'f-dim', name='Label')) + at(146, 66, T(val, 52, 'l', FILL.get(c, ''), name='Value'))
        b += box(x, y, 386, 176, inner, f'cs r-{c}', 'border-radius:16px', name=f'Stat{i + 1}')
    right = row(icn('crown', 48), T('Your record', 32, 's'), gap=6)
    return world('bg_lobby_blur.jpg', False) + dim() + panel('Stats', 'coral', 'Stats', 'stats', b, x0, y0, W, H, right)


# ================================================================== Settings (real settings only)
SETTINGS = [('sound', 'Sound Effects', 'Hits, steals, crossings and UI clicks.', True),
            ('burst', 'Reduce Effects', 'Fewer particles, no camera shake or speed zoom.', False),
            ('info', 'Show Hints', 'Tips on screen while you learn the game.', True),
            ('hunt', 'Volunteer To Hunt', 'Start matches as a Catcher when there is room.', False)]
# Music (16 Oct) sits under Sound Effects; the other rows keep their export names (Row1..Row5) for the controller
SETTINGS_MUSIC = ('music', 'Music', 'Lobby and match music.', True)


def swatches(x, y, sel=None, size=54, gap=12, labels=False):
    """UI Colour picker: Default (split chip = each screen keeps its own colour) + one swatch per accent."""
    out = ''
    for i, (acc, lab) in enumerate(UI_COLOURS):
        sx = x + i * (size + gap)
        cls = 'sw' + (f' a-{acc}' if acc else ' sw-def')
        out += f"<div class='{cls}' data-n='Swatch_{lab}' data-btn=1 style='left:{sx}px;top:{y}px;width:{size}px;height:{size}px'></div>"
        if acc == sel:
            out += selring(sx, y, size, size, 'SwatchSel', 7) + I('check', sx + size - 26, y - 12, 38, name='SwatchCheck')
        if labels:
            out += at(sx + size // 2, y + size + 8, T(lab, 17, 'xs', '' if acc == sel else 'f-dim'), w=size + gap, align='center')
    return out


def s_settings():
    x0, y0, W, H = 360, 120, 1200, 850
    b = ''
    rows = SETTINGS[:1] + [SETTINGS_MUSIC] + SETTINGS[1:] + [('abilityfx', 'UI Colour', 'Colour of every menu panel. Looks only.', None)]
    names = ['Row1', 'RowMusic', 'Row2', 'Row3', 'Row4', 'Row5']
    for i, (ic, title, desc, on) in enumerate(rows):
        y = 24 + i * 104
        inner = I(ic, 16, 10, 76) + at(116, 10, T(title, 32, 's', name='Title')) + at(118, 54, T(desc, 20, 'xs', 'f-dim', name='Desc'))
        if on is None:
            inner += swatches(604, 21, None, 54, 10)
        else:
            inner += dual(860, 13, 236, 70, 'lime', bl('ON', 32), 'Toggle', on, off_label=bl('OFF', 32))
        b += well(26, y, 1136, 96, inner, name=names[i])
    ty = 24 + len(rows) * 104 + 6
    b += dual(26, ty, 554, 64, 'purple', bl('GAME', 28), 'TabGame', True)
    b += dual(608, ty, 554, 64, 'purple', row(icn('controls', 36), bl('CONTROLS', 28)), 'TabControls', False)
    ctl = ''
    for i, (k, v) in enumerate([('RUN', 'WASD  /  left stick'), ('DASH', 'Space  /  A  (sideways or back)'), ('TAG', 'Click, E  /  R2 or X'),
                                ('PET ABILITY', 'Q  /  Y'), ('CLOSE MENUS', 'Esc  /  B')]):
        ctl += at(40, 30 + i * 98, T(k, 30, 's', 'f-gold', name=f'Key{i + 1}')) + at(420, 34 + i * 98, T(v, 28, 's', name=f'Does{i + 1}'))
    b += sub('ControlsPage', well(26, 24, 1136, 600, ctl, name='ControlsList'), hid=True)
    return world('bg_lobby_blur.jpg', False) + dim() + panel('Settings', 'steel', 'Settings', 'settings', b, x0, y0, W, H)


def s_ui_colour():
    """Design board for the UI Colour setting: the picker, then the same screen in four choices."""
    out = "<div class='abs fill' style='background:#101014'></div>"
    out += at(40, 26, T('UI COLOUR SETTING', 52, 'xl'))
    out += at(44, 132, T('Settings > Game > UI Colour.  Default keeps one colour per screen; any other choice recolours every panel.  Saved per player, looks only.', 22, 'xs', 'f-dim'))
    out += swatches(640, 26, 'pink', 58, 10, labels=True)
    picks = [(None, 'Default (Quests is purple)'), ('pink', 'Pink'), ('sky', 'Blue'), ('steel', 'Steel')]
    sc = .47
    for i, (acc, lab) in enumerate(picks):
        UI_COLOUR[0] = acc
        body = s_quests()
        UI_COLOUR[0] = None
        tx, ty = 40 + (i % 2) * 930, 186 + (i // 2) * 540
        out += (f"<div class='abs' style='left:{tx}px;top:{ty}px;width:{int(1920 * sc)}px;height:{int(1080 * sc)}px;overflow:hidden;border-radius:10px;"
                f"box-shadow:0 0 0 3px #050506,0 0 0 5px rgba(255,255,255,.25)'>"
                f"<div class='abs' style='left:0;top:0;width:1920px;height:1080px;transform:scale({sc});transform-origin:0 0'>{body}</div></div>")
        out += at(tx + 6, ty + int(1080 * sc) + 6, T(lab, 22, 's'))
    return out



# ================================================================== Emotes (EmoteConfig: crate + My Emotes + wheel), 16 Oct
import json as _json
_SONGS = {'snappy_skip': 'Clap Your Hands And Smile', 'idle_dance': 'Soul Dancefloor', 'shuffle': 'Cyber Gym', 'wavy_grooves': 'Explosive Groove',
          'moongazer': 'Moonwalk', 'cat_dance': 'The Jitters', 'skeleton': 'Trick or Treat', 'electro_shuffle': 'Commodore Love',
          'jumpstyle': 'Free to Rave', 'wibbly_wobbly': 'Dubstep Orange', 'marat': 'Eurodance', 'kpop_dance': 'I Cannot Get Enough',
          'flexer': 'Night Sweats', 'rap_bounce': 'Brass Knuckles', 'e_dance': 'Accelerator',
          'idle_sit': 'Sunset Chill', 'anime_pose': 'Fight Of Utsusemi', 't_pose': 'Comical Tango', 'thumbs_up': 'Happy Song', 'loser_dance': 'Cartoony', 'trick_or_treat': 'Halloween Horrors Waltz', 'sunbath': 'Waikiki Beach', 'couch_nap': 'Music Box Lullaby', 'toilet_sit': 'Playful Promenade', 'dramatic_bow': 'To the Victor', 'candy_dance': 'Zambezi', 'neko_dance': 'Do My Best', 'beatbox': 'Take It Now', 'cossack_kick': 'Happy Balalaika', 'boogie_down': 'Discoball', 'orange_sway': 'Eurofax', 'company_dance': 'Retro Energy', 'surfer': 'Surf Rock', 'ice_cream_cart': 'Fun Polka', 'parrot_wiggle': 'Tropical Breeze', 'head_juggle': 'Circus And Clowns', 'zombie_dance': 'Halloween Funk', 'gambler_dance': 'Swing The Polka', 'breakdance': 'Into The Stratosphere', 'star_emote': 'Moved By Joy', 'coconut_launch': 'Bananas', 'dap_up': 'Ice Cold Drip', 'threaten': 'Darkness Distilled', 'lose_it': 'Cyber Generation', 'skeleton_grooves': 'Cosmic Lady', 'honored_one': 'Dream Of A Lifetime', 'shadow_emerge': 'Impending Doom', 'shadow_step': 'Dystopian Distortion', 'reapers_ride': 'Heavy Metal', 'floating_meditation': 'Meditation', 'blossom_break': 'Koto Chill'}
# id, name, rarity, song: roblox/game/emote_catalog.json is the one list (EmoteConfig is generated from it too)
EMOTES = [(e[0], e[1], 'crowned' if e[2] == 'legendary' else e[2], _SONGS.get(e[0], ''))
          for e in _json.load(open(os.path.join(HERE, '..', 'roblox', 'game', 'emote_catalog.json')))]
EMO_ODDS = {'common': '2.88%', 'rare': '2%', 'epic': '1.25%', 'crowned': '1%'}
EMO_RNAME = {'common': 'COMMON', 'rare': 'RARE', 'epic': 'EPIC', 'crowned': 'LEGENDARY'}
EMO_OWNED = ['idle_dance', 'shuffle', 'skeleton', 'jumpstyle', 'kpop_dance']


def emo_view(x, y, w, h, name='View'):
    """Where the runtime drops a ViewportFrame with your avatar doing the emote (the export can't make one)."""
    return box(x, y, w, h, I('emote', (w - min(w, h) * 7 // 10) // 2, (h - min(w, h) * 7 // 10) // 2, min(w, h) * 7 // 10, name='Placeholder'),
               '', 'border-radius:10px;background:radial-gradient(#3a3550,#16141e);box-shadow:inset 0 0 0 2px rgba(255,255,255,.08)', name=name)


def emo_card(x, y, e, w=250, h=276, on_wheel=False, name=None):
    eid, nm, r, song = e
    inner = emo_view(12, 12, w - 24, 128)
    inner += at(w // 2, 146, T(nm, 24, 's', name='EmoteName'), w=w, align='center')
    inner += at(w // 2, 178, T(EMO_RNAME[r], 16, 'xs', FILL.get(r, ''), name='Rarity'), w=w, align='center')
    inner += at(w // 2, 200, row(icn('music', 18, name='Note'), T(song or 'no song', 14, 'xs', 'f-dim', name='Song'), gap=4), w=w, align='center')
    bw = (w - 36) // 2
    inner += btn(12, h - 60, bw, 48, 'lime', bl('PLAY', 22), cls='sm', name='BtnPlay')
    inner += btn(24 + bw, h - 60, bw, 48, 'sky', bl('EQUIP', 22), cls='sm' + (' hid' if on_wheel else ''), name='BtnEquip')
    inner += btn(24 + bw, h - 60, bw, 48, 'grey', row(icn('check', 20), bl('ON', 20)), cls='sm' + ('' if on_wheel else ' hid'), name='BtnOnWheel')
    return box(x, y, w, h, inner, f'cs r-{r}', 'border-radius:16px', name=name or f'Mine_{eid}')


def emo_odds_card(x, y, e, owned=False, glow=False, name=None):
    eid, nm, r, song = e
    w, h = 200, 184
    inner = emo_view(10, 10, w - 20, 100)
    inner += at(w // 2, 116, T(nm, 19, 's', name='EmoteName'), w=w, align='center')
    inner += at(w // 2, 144, T(f'{EMO_RNAME[r]}  ·  {EMO_ODDS[r]}', 14, 'xs', FILL.get(r, ''), name='Rarity'), w=w, align='center')
    inner += tag(w - 92, 6, 'OWNED', 'lime', 13, 26, name='Owned').replace("class='ctag", "class='ctag" + ('' if owned else ' hid'), 1)
    inner += f"<div class='abs{'' if glow else ' hid'}' data-n='Glow' style='left:-6px;top:-6px;width:{w + 12}px;height:{h + 12}px;border-radius:20px;box-shadow:0 0 0 5px #fff,0 0 26px 6px rgba(255,255,255,.7)'></div>"
    return box(x, y, w, h, inner, f'cs r-{r}', 'border-radius:16px', name=name or f'Odds_{eid}')


def wheel_slots(cx, cy, rad, names, w=232, h=92, sel=None):
    import math
    out = ''
    for i in range(6):
        a = math.radians(-90 + i * 60)
        x, y = int(cx + rad * math.cos(a) - w / 2), int(cy + rad * math.sin(a) - h / 2)
        nm = names[i] if i < len(names) else None
        e = next((q for q in EMOTES if q[1] == nm), None)
        r = e[2] if e else 'locked'
        inner = at(14, 10, T(str(i + 1), 18, 'xs', 'f-dim', name='Num'))
        inner += at(w // 2, 20 if e else 30, T(nm or 'EMPTY', 24 if e else 20, 's' if e else 'xs', '' if e else 'f-dim', name='EmoteName'), w=w, align='center')
        inner += at(w // 2, 54, T(EMO_RNAME[r] if e else 'equip in My Emotes', 14, 'xs', FILL.get(r, 'f-dim'), name='Rarity'), w=w, align='center')
        out += sub(f'Slot{i + 1}', box(x, y, w, h, inner, f'cs r-{r}' + ('' if e else ' locked'), 'border-radius:14px', name='Tile')
                   + (selring(x, y, w, h, 'SlotSel', 14) if sel == i else ''), btn=True)
    return out


def s_emotes(tab='mine'):
    x0, y0, W, H = 220, 150, 1480, 820
    b = dual(26, 22, 300, 64, 'pink', row(icn('emote', 40), bl('My Emotes', 28)), 'TabMine', tab == 'mine')
    b += dual(340, 22, 300, 64, 'purple', row(icn('gift', 40), bl('Emote Crate', 28)), 'TabCrate', tab == 'crate')
    b += at(1430, 40, row(T('Emote wheel:', 20, 'xs', 'f-dim'), f"<span class='keycap' style='position:relative;display:inline-flex;width:38px;height:38px;border-width:3px'>{T('G', 20, 'xs', style='font-family:Montserrat;font-weight:900')}</span>", gap=8), w=500, align='right', name='WheelHint')
    # --- My Emotes: owned cards + your wheel
    mine = [e for e in EMOTES if e[0] in EMO_OWNED]
    g = ''
    for i, e in enumerate(mine[:8]):
        g += emo_card(18 + (i % 4) * 262, 16 + (i // 4) * 288, e, on_wheel=i < 4)
    if EXPORT_STATES:
        for r in ('common', 'rare', 'epic', 'crowned'):
            g += sub(f'Proto_{r}', emo_card(18, 16, next(q for q in EMOTES if q[2] == r), name='Card'), hid=True)
    pg = well(26, 100, 1074, 596, g, name='Grid', style='overflow:hidden')
    wl = at(170, 14, T('YOUR WHEEL', 26, 's'), w=330, align='center')
    wl += at(170, 50, T('Pick a slot, then EQUIP an emote', 16, 'xs', 'f-dim', name='WheelTip'), w=330, align='center')
    names = [e[1] for e in mine[:4]]
    for i in range(6):
        e = next((q for q in EMOTES if i < len(names) and q[1] == names[i]), None)
        r = e[2] if e else 'locked'
        y = 86 + i * 82
        inner = at(14, 22, T(str(i + 1), 22, 's', 'f-dim', name='Num')) + at(48, 12, T(e[1] if e else 'Empty', 22, 's' if e else 'xs', '' if e else 'f-dim', name='EmoteName'))
        inner += at(48, 42, T(EMO_RNAME[r] if e else 'pick an emote', 14, 'xs', FILL.get(r, 'f-dim'), name='Rarity'))
        inner += btn(240, 16, 44, 40, 'grey', T('X', 20, 's'), cls='sm' + ('' if e else ' hid'), name='BtnClear')
        wl += sub(f'WSlot{i + 1}', box(22, y, 296, 72, inner, f'cs r-{r}' + ('' if e else ' locked'), 'border-radius:12px', name='Tile'), btn=True)
    wl += selring(22, 86 + 4 * 82, 296, 72, 'WSlotSel', 12)
    pg += well(1116, 100, 340, 596, wl, name='Wheel')
    if EXPORT_STATES:
        pg += sub('EmptyState', well(26, 100, 1074, 596, at(537, 170, col(icn('emote', 130), T('No emotes yet', 40, 'l'), T('Open an Emote Crate to win one', 24, 'xs', 'f-dim'), gap=8), w=1000, align='center')
                                      + btn(387, 440, 300, 76, 'purple', bl('OPEN A CRATE', 28), name='GoCrate'), name='EmptyWell'), hid=True)
    b += sub('MinePage', pg, hid=tab != 'mine')
    # --- Emote Crate: odds board + open
    og = ''
    show = [e for e in EMOTES if e[2] == 'common'][:4] + [e for e in EMOTES if e[2] == 'rare'][:4] + [e for e in EMOTES if e[2] == 'epic'][:4] + [e for e in EMOTES if e[2] == 'crowned'][:3]
    for i, e in enumerate(show):   # runtime clones all of them (Proto_<rarity>) into a scrolling list
        og += emo_odds_card(18 + (i % 5) * 210, 16 + (i // 5) * 194, e, owned=e[0] in EMO_OWNED, glow=(i == 6 and tab == 'crate'))
    if EXPORT_STATES:
        for r in ('common', 'rare', 'epic', 'crowned'):
            og += sub(f'Proto_{r}', emo_odds_card(18, 16, next(q for q in EMOTES if q[2] == r), name='Card'), hid=True)
    cp = well(26, 100, 1074, 596, og, name='OddsGrid', style='overflow:hidden')
    d = I('gift', 70, 20, 200, name='CrateIcon')
    d += at(170, 228, T('EMOTE CRATE', 34, 'l'), w=330, align='center')
    d += at(170, 272, T(f'One of {len(EMOTES)} emotes per crate', 18, 'xs', 'f-dim', name='CrateSub'), w=330, align='center')
    for i, r in enumerate(['common', 'rare', 'epic', 'crowned']):
        d += at(60, 306 + i * 30, T(EMO_RNAME[r], 17, 'xs', FILL.get(r, ''))) + at(280, 306 + i * 30, T(EMO_ODDS[r] + ' each', 17, 'xs', 'f-dim'), w=200, align='right')
    d += at(170, 430, T('A duplicate refunds Gems', 16, 'xs', 'f-dim'), w=330, align='center')
    for nm, col_, on in (('BtnOpen', 'lime', True), ('BtnPoor', 'grey', False), ('BtnRolling', 'grey', False)):
        lab = row(icn('gem', 44), bl('250', 34, name='Price')) if nm != 'BtnRolling' else bl('OPENING...', 30)
        if on or EXPORT_STATES:
            d += btn(30, 462, 280, 78, col_, lab, name=nm, cls='' if on else 'hid')
    d += at(170, 552, row(T('You have', 18, 'xs', 'f-dim'), icn('gem', 26), T('312', 20, 'xs', 'f-lime', name='HaveText'), gap=6), w=330, align='center')
    cp += well(1116, 100, 340, 596, d, name='Detail')
    b += sub('CratePage', cp, hid=tab != 'crate')
    # --- reveal (after a crate)
    if EXPORT_STATES or tab == 'reveal':
        e = EMOTES[11]
        rv = rays(740, 330, 640, .22)
        rv += at(740, 6, T('NEW EMOTE!', 66, 'xl', 'f-gold', name='Title'), w=1200, align='center')
        rv += at(740, 86, T('ADDED TO MY EMOTES', 24, 's', name='Sub'), w=900, align='center')
        rv += box(560, 130, 360, 380, emo_view(18, 18, 324, 250) + at(180, 280, T(e[1], 34, 'l', name='EmoteName'), w=360, align='center')
                  + at(180, 324, T(EMO_RNAME[e[2]], 20, 's', FILL.get(e[2], ''), name='Rarity'), w=360, align='center')
                  + at(180, 352, T('Song: ' + e[3], 16, 'xs', 'f-dim', name='Song'), w=360, align='center'), f'cs r-{e[2]}', 'border-radius:20px', name='Card')
        for sx, sy, sz in [(500, 170, 56), (950, 140, 70), (990, 420, 46), (470, 430, 50)]:
            rv += I('sparkle', sx, sy, sz, name='Sparkle')
        rv += btn(470, 540, 260, 76, 'lime', bl('PLAY NOW', 30), name='PlayNow') + btn(750, 540, 260, 76, 'grey', bl('DONE', 30), name='Done')
        b += sub('Reveal', rv, hid=tab != 'reveal')
    right = row(icn('gem', 48), T('312', 34, 's', 'f-lime', name='GemsText'), gap=8)
    return world('bg_lobby_blur.jpg', False) + dim() + panel('Emotes', 'pink', 'Emotes', 'emote', b, x0, y0, W, H, right)


def s_emote_wheel():
    """G opens it anywhere in the lobby (Huss Valley's wheel): six of your emotes around a centre disc."""
    cx, cy = 960, 500
    w = f"<div class='abs' style='left:{cx - 330}px;top:{cy - 330}px;width:660px;height:660px;border-radius:50%;background:radial-gradient(rgba(20,18,28,.86) 58%,rgba(20,18,28,.5) 72%,transparent 73%);box-shadow:0 0 0 3px rgba(255,255,255,.12)'></div>"
    w += at(330, 70, T('EMOTES', 60, 'xl', name='Title'))
    w += at(334, 152, T('Pick one  ·  move to stop', 22, 'xs', 'f-dim', name='Tip'))
    w += wheel_slots(cx, cy, 250, ['Idle Dance', 'Shuffle', 'Skeleton', 'Jumpstyle', 'K-Pop Dance'], sel=1)
    disc = (f"<div class='abs' style='left:{cx - 118}px;top:{cy - 118}px;width:236px;height:236px;border-radius:50%;background:radial-gradient(#3b3550,#18161f);"
            f"box-shadow:0 0 0 4px #050506,0 0 0 7px rgba(255,255,255,.18)'></div>")
    disc += at(cx, cy - 92, T('SELECTED', 15, 'xs', 'f-dim'), w=220, align='center')
    disc += at(cx, cy - 66, T('Shuffle', 30, 'l', name='SelName'), w=230, align='center')
    disc += at(cx, cy - 26, T('COMMON  ·  Cyber Gym', 14, 'xs', 'f-common', name='SelInfo'), w=230, align='center')
    disc += btn(cx - 92, cy + 14, 184, 52, 'pink', bl('MY EMOTES', 20), cls='sm', name='BtnMine', opens='Emotes')
    disc += btn(cx - 92, cy + 72, 184, 40, 'grey', bl('STOP', 18), cls='sm', name='BtnStop')
    w += disc
    w += btn(cx - 140, cy + 350, 280, 70, 'lime', row(icn('gift', 40), bl('GET EMOTES', 26)), name='BtnGet')
    w += closex(cx + 300, cy - 330)
    return world() + dim(.3) + grp('Wheel', w, 'C')


# ================================================================== Servers (Huss Valley "find your people"), 16 Oct
SERVERS = [  # region, players, max, status, ping, you
    ('United States', 14, 18, 'Match in progress', 38, True), ('United States', 17, 18, 'Starting', 41, False),
    ('Brazil', 9, 18, 'Match in progress', 132, False), ('Germany', 18, 18, 'Match in progress', 96, False),
    ('Singapore', 6, 18, 'In lobby', 210, False)]


def server_row(x, y, sv, w=994, name=None):
    reg, n, mx, st, ping, you = sv
    inner = at(24, 14, T(('YOUR SERVER  ·  ' if you else '') + reg, 28, 's', 'f-lime' if you else '', name='Region'))
    inner += at(26, 54, T(f'{n} / {mx} players  ·  {st}', 18, 'xs', 'f-dim', name='Detail'))
    inner += at(w - 210, 32, T(f'{ping} ms avg', 18, 'xs', 'f-lime' if ping < 80 else ('f-gold' if ping < 150 else 'f-red'), name='Ping'), w=180, align='right')
    for nm, col_, lab, on in (('BtnJoin', 'lime', 'JOIN', not you and n < mx), ('BtnFull', 'grey', 'FULL', not you and n >= mx), ('BtnHere', 'grey', 'HERE', you)):
        if on or EXPORT_STATES:
            inner += btn(w - 176, 18, 150, 60, col_, bl(lab, 26), cls='sm' + ('' if on else ' hid'), name=nm)
    return box(x, y, w - 36, 96, inner, 'cs ' + ('r-lime' if you else 'r-steel'), 'border-radius:14px', name=name)


def s_servers():
    x0, y0, W, H = 290, 130, 1340, 860
    b = at(30, 36, T('SORT:', 20, 'xs', 'f-dim'))
    b += dual(100, 22, 200, 56, 'teal', bl('PLAYERS', 22), 'SortPlayers', True, cls='sm')
    b += dual(312, 22, 200, 56, 'teal', bl('PING', 22), 'SortPing', False, cls='sm')
    b += at(536, 38, T('12 SERVERS', 22, 'xs', 'f-dim', name='CountText'))
    b += btn(1110, 22, 200, 56, 'lime', row(icn('refresh', 30), bl('REFRESH', 22)), cls='sm', name='BtnRefresh')
    cs = ''
    for i, (c, on) in enumerate([('All countries', True), ('United States', False), ('Brazil', False), ('Germany', False), ('Singapore', False), ('Australia', False), ('Japan', False)]):
        cs += dual(14, 14 + i * 72, 232, 60, 'teal', bl(c, 19), f'Country{i + 1}', on, cls='sm')
    if EXPORT_STATES:
        cs += sub('ProtoCountry', dual(14, 14, 232, 60, 'teal', bl('Country', 19), 'Btn', False, cls='sm'), hid=True)
    b += well(26, 100, 260, 560, cs, name='Countries', style='overflow:hidden')
    ls = ''
    for i, sv in enumerate(SERVERS):
        ls += server_row(18, 14 + i * 108, sv, name='YourRow' if sv[5] else f'Row{i}')
    if EXPORT_STATES:
        ls += sub('ProtoRow', server_row(18, 14, SERVERS[1], name='Card'), hid=True)
    b += well(300, 100, 1014, 560, ls, name='List', style='overflow:hidden')
    b += btn(300, 676, 180, 56, 'grey', bl('PREV', 22), cls='sm', name='BtnPrev')
    b += at(807, 690, T('PAGE 1 / 2', 22, 's', name='PageText'), w=300, align='center')
    b += btn(1134, 676, 180, 56, 'teal', bl('NEXT', 22), cls='sm', name='BtnNext')
    b += at(30, 680, T('Your ping is live. Other pings', 15, 'xs', 'f-dim', name='Note1'))
    b += at(30, 702, T('are player averages, updated', 15, 'xs', 'f-dim', name='Note2'))
    b += at(30, 724, T('about every 20 s.', 15, 'xs', 'f-dim', name='Note3'))
    right = row(icn('servers', 46), T('YOUR PING', 18, 'xs', 'f-dim'), T('38 ms', 30, 's', 'f-lime', name='PingText'), gap=8)
    return world('bg_lobby_blur.jpg', False) + dim() + panel('Servers', 'teal', 'Servers', 'servers', b, x0, y0, W, H, right)


# ================================================================== Spectate (watch the match from the lobby), 16 Oct
def s_spectate(mode='follow'):
    out = world()
    x, y, w, h = 560, 926, 800, 118
    bar_ = f"<div class='glass' style='left:{x}px;top:{y}px;width:{w}px;height:{h}px'></div>"
    bar_ += f"<div class='wtab' style='left:{x + 12}px;top:{y - 26}px;height:28px'>{T('SPECTATING', 14, 'xs', name='ModeTab')}</div>"
    bar_ += at(x + 24, y + 18, T('Dommyle' if mode == 'follow' else 'Explore the field', 34, 'l', name='TargetName'))
    bar_ += at(x + 26, y + 70, T('Runner  ·  Level 2 egg' if mode == 'follow' else 'Free cam  ·  WASD to fly', 17, 'xs', 'f-dim', name='TargetInfo'))
    bar_ += btn(x + 330, y + 30, 60, 60, 'grey', bl('<', 32), cls='sm', name='BtnPrev')
    bar_ += btn(x + 398, y + 30, 60, 60, 'grey', bl('>', 32), cls='sm', name='BtnNext')
    bar_ += dual(x + 470, y + 14, 150, 42, 'lime', bl('FOLLOW', 18), 'TabFollow', mode == 'follow', cls='sm')
    bar_ += dual(x + 470, y + 62, 150, 42, 'sky', bl('FREE CAM', 18), 'TabFree', mode == 'free', cls='sm')
    bar_ += btn(x + 632, y + 24, 152, 70, 'red', bl('EXIT', 28), name='BtnExit')
    out += grp('Bar', bar_, 'B')
    hint = at(960, 880, T('Right-drag: orbit  ·  Scroll: zoom  ·  < >: next player' if mode == 'follow' else 'WASD: fly  ·  Q / E: down / up  ·  Right-drag: look  ·  Shift: fast', 18, 'xs', name='HintText'), w=1000, align='center')
    out += grp('Hint', hint, 'B')
    return out

# ================================================================== Results (GDD 14 end-of-match breakdown)
def s_results():
    out = world('bg_lobby_blur.jpg', False) + dim(.5)
    hd = rays(960, 92, 900, .22)   # centred exactly on the title (Hunter: the off-centre shine looked misplaced)
    hd += at(960, 26, T('RUNNERS WIN!', 104, 'xl', 'f-gold', name='TeamBanner'), w=1200, align='center')
    hd += at(960, 158, T('3 clean crossings in a row', 30, 's', 'f-dim', name='Reason'), w=900, align='center')
    if EXPORT_STATES:
        hd += at(960, 202, T('PRACTICE MATCH: REWARDS SAVE WITH 4+ REAL PLAYERS', 22, 'xs', 'f-orange', name='TestNote'), w=1000, align='center').replace("class='abs", "class='abs hid", 1)
    out += grp('Banner', hd, 'T')
    pod = ''
    for i, (nm, pet, lab, h, c, r) in enumerate([('Zoe', 'SurferDog', '2nd', 150, 'sky', 'rare'), ('You', 'ShadesShark', '1st', 200, 'gold', 'gold'), ('Kai', 'GamerAxolotl', '3rd', 110, 'orange', 'common')]):
        x = 150 + i * 200
        pod += slot(x, 770 - h - 176, 170, r, pet_img(pet, 3 if i == 1 else 1), name=f'Podium{i + 1}', art_pad=.05)
        pod += box(x, 770 - h, 170, h, f"<div class='lbl'>{col(T(lab, 40, 'l', name='Place'), T(nm, 24, 's', name='PlayerName'), gap=0)}</div>", f'cb k-{c}', name=f'Step{i + 1}')
    out += grp('Podium', pod, 'L')
    th = slot(26, 26, 130, 'red', 'steal', name='ThiefSlot', cls='fill')
    th += at(178, 36, T('TOP THIEF', 22, 'xs', 'f-red')) + at(178, 66, T('Kai', 44, 'l', name='ThiefName')) + at(180, 122, T('stole 4 eggs', 22, 'xs', 'f-dim', name='ThiefCount'))
    out += grp('Thief', box(150, 820, 600, 184, th, 'glass', name='Thief'), 'BL')
    y = f"<div class='ch a-gold' style='height:84px'><div class='sweep'></div><div class='lbl'>{T('YOUR REWARDS', 40, 'l')}</div></div>"
    for i, (lab, amt) in enumerate([('PLAYED', 25), ('CROSSINGS  x3', 36), ('FIRST STEAL', 10), ('VICTORY', 15)]):
        y += sub(f'Line{i + 1}', at(40, 112 + i * 40, T(lab, 22, 'xs', 'f-dim', name='LineLabel')) + at(480, 106 + i * 40, row(T(f'+{amt}', 26, 's', 'f-gold', name='LineAmount'), icn('gold', 30), gap=4), w=200, align='right'))
    y += "<div class='abs' style='left:36px;top:280px;width:444px;height:4px;background:rgba(255,255,255,.2)'></div>"
    y += at(40, 296, T('TOTAL', 26, 's')) + at(480, 288, row(T('+86', 40, 'l', 'f-gold', name='GoldTotal'), icn('gold', 44), gap=4), w=240, align='right')
    y += slot(530, 112, 146, 'lime', 'gem', 'x5', 'Gems', name='GemsSlot')
    y += field_gems_tag(466, 66, 2)   # HOS-GEMS-002: field Gems picked up this match (hidden when 0)
    y += slot(530, 274, 146, 'epic', 'piece_epic', 'x1', 'Epic', name='PieceSlot')
    y += at(40, 352, row(icn('egg_cosmic', 54, name='BestEggIcon'), col(T('Best egg: Level 3', 26, 's', 'f-epic', name='BestEgg'), T('pays 1 Epic piece', 18, 'xs', 'f-dim', name='BestEggPays'), gap=0, align='flex-start'), gap=8))
    y += bar(40, 434, 440, 32, 1 / 5, 'purple', 'RecipeBar') + at(260, 437, T('Epic pieces 1 / 5', 18, 'xs', name='RecipeText'), w=440, align='center')
    y += btn(510, 428, 186, 68, 'lime', bl('NEXT', 30), name='Continue')
    if EXPORT_STATES:
        y += at(360, 494, T('Move, cross or tag to earn rewards', 18, 'xs', 'f-orange', name='Ineligible'), w=700, align='center').replace("class='abs", "class='abs hid", 1)
    out += grp('You', f"<div class='cp a-gold' data-n='YouCard' style='left:1060px;top:280px;width:720px;height:530px'>{y}</div>", 'R')
    out += grp('NextMatch', at(1420, 846, T('Next match in 0:09', 30, 's', 'f-dim', name='NextText'), w=720, align='center'), 'BR')
    return out


# ================================================================== Hatch reveal
def s_hatch():
    out = world('bg_lobby_blur.jpg', False) + dim(.6)
    h = rays(960, 490, 1000, .3)    # centred on the pet
    h += at(960, 70, T('NEW PET!', 110, 'xl', 'f-gold', name='Title'), w=1000, align='center')
    h += I(pet_img('ShadesShark'), 700, 230, 520, name='Pet')
    h += at(960, 760, T('Shades Shark', 72, 'xl', name='PetName'), w=1000, align='center')
    h += at(960, 852, row(T('Common', 30, 's', 'f-common', name='RarityText'), icn('ab_dash', 46, name='AbilityIcon'), T('Double Dash', 30, 's', 'f-orange', name='AbilityText'), gap=12), w=1000, align='center')
    h += btn(700, 920, 250, 84, 'lime', bl('EQUIP', 36), name='BtnEquip') + btn(970, 920, 250, 84, 'purple', bl('NICE!', 36), name='BtnClose')
    for sx, sy, s in [(560, 300, 70), (1300, 260, 90), (1360, 560, 54), (520, 620, 60)]:
        h += I('sparkle', sx, sy, s, name='Sparkle')
    return out + grp('Reveal', h, 'C')


# ================================================================== Reward reveal (16 Oct)
def s_reward(kind='item'):
    """Every buy gets its moment (Hunter, 16 Oct): shop items (Gold, Gems or Robux) and Gem packs. Same beats as
    the hatch reveal: rays spin, the prize pops, the title slams, sparkles twinkle. Runtime fills it (UIC.showReward)."""
    out = world('bg_lobby_blur.jpg', False) + dim(.6)
    gems = kind == 'gems'
    h = rays(960, 440, 1000, .3)    # centred on the prize
    h += at(960, 70, T('GEMS ADDED!' if gems else 'UNLOCKED!', 110, 'xl', 'f-lime' if gems else 'f-gold', name='Title'), w=1200, align='center')
    h += I('gempack3' if gems else 'trail_rainbow', 720, 220, 480, name='Icon')
    h += at(960, 720, T('+500 Gems' if gems else 'Rainbow Trail', 72, 'xl', 'f-lime' if gems else '', name='ItemName'), w=1400, align='center')
    h += at(960, 808, T('THANK YOU FOR YOUR SUPPORT!' if gems else 'EGG TRAIL', 30, 's', 'f-gold' if gems else 'f-lime', name='KindText'), w=1200, align='center')
    h += at(960, 852, T('You now have 612 Gems' if gems else 'Yours to keep. It shows in every match.', 26, 's', 'f-dim', name='SubText'), w=1400, align='center')
    if EXPORT_STATES:    # USE NOW only for a lobby burst; NICE! slides to the middle when it is alone
        h += btn(700, 920, 250, 84, 'lime', bl('USE NOW', 36, name='Label'), name='BtnUse')
    h += btn(970 if EXPORT_STATES else 835, 920, 250, 84, 'purple', bl('NICE!', 36), name='BtnClose')
    for sx, sy, s in [(560, 280, 70), (1300, 250, 90), (1360, 580, 54), (500, 600, 60), (1420, 380, 44)]:
        h += I('sparkle', sx, sy, s, name='Sparkle')
    return out + grp('Reveal', h, 'C')


# ================================================================== match banners + runtime templates
def banner_card(x, y, w, title, sub_txt, color, icon, name):
    inner = f"<div class='hp k-{color}' style='left:0;top:0;width:{w}px;height:120px'><div class='lbl' style='padding-left:150px'>{col(T(title, 54, 'xl', name='Title'), T(sub_txt, 24, 's', name='Sub'), gap=0, align='flex-start')}</div></div>"
    inner += I(icon, -10, -26, 160, name='Icon')
    return box(x, y, w, 120, inner, name=name)


def toast(x, y, color, icon, text, gname):
    inner = f"<div class='glass' style='left:30px;top:0;width:620px;height:84px'></div>" + I(icon, 0, -10, 100, name='Icon')
    inner += at(116, 22, T(text, 30, 's', name='Msg')) + bar(110, 66, 520, 10, 1, color, 'Time')
    return grp(gname, box(x, y, 650, 84, inner, name='Toast'), 'TL')


def s_templates():
    out = "<div class='abs fill' style='background:linear-gradient(#3a1a66,#1e0a3e)'></div>"
    out += cap(60, 24, 'Match banners (pop in, hold 1.6 s, slide up)')
    out += grp('Banner_Runner', banner_card(60, 80, 820, "YOU'RE A RUNNER!", 'Cross 3 times to grow your egg', 'sky', 'runner', 'Banner'), 'TL')
    out += grp('Banner_Catcher', banner_card(60, 230, 820, "YOU'RE A CATCHER!", 'Steal eggs. Every catch joins your team', 'red', 'catcher', 'Banner'), 'TL')
    out += grp('Banner_Safe', banner_card(60, 380, 820, 'SAFE!', 'Your egg grew to Level 2', 'lime', 'egg_shiny', 'Banner'), 'TL')
    out += grp('Banner_Caught', banner_card(60, 530, 820, 'CAUGHT!', "You're a Catcher now. Go get them!", 'pink', 'catcher', 'Banner'), 'TL')
    out += grp('Banner_Stole', banner_card(60, 680, 820, 'STOLEN!', "You took Mia's Level 3 egg", 'gold', 'steal', 'Banner'), 'TL')
    out += grp('Banner_Last', banner_card(60, 830, 820, 'LAST ONE STANDING!', 'Make it across alone to win it for the Runners', 'purple', 'crown', 'Banner'), 'TL')
    out += grp('Banner_Slow', banner_card(60, 980, 820, 'TOO SLOW!', 'You missed the crossing: you hunt now', 'grey', 'clock', 'Banner'), 'TL')
    out += cap(1000, 24, 'Toasts: info / success / error / reward')
    out += toast(1000, 80, 'blue', 'info', 'Tip: hold Space to dash sideways', 'Toast_info')
    out += toast(1000, 190, 'lime', 'check', 'Sparkle Trail bought!', 'Toast_good')
    out += toast(1000, 300, 'red', 'gold', 'Need 150 more Gold', 'Toast_error')
    out += toast(1000, 410, 'gold', 'piece_rare', '+1 Rare piece', 'Toast_reward')
    cf = f"<div class='ch a-gold' style='height:84px'><div class='sweep'></div><div class='lbl'>{T('Are you sure?', 42, 'l', name='Title')}</div></div>"
    cf += at(380, 116, T('Buy Bolt Entrance for 1,400 Gold?', 30, 's', name='Body1'), w=740, align='center')
    cf += at(380, 160, T('Yours to keep. Looks only.', 22, 'xs', 'f-dim', name='Body2'), w=740, align='center')
    cf += btn(80, 214, 280, 80, 'lime', bl('BUY', 34, name='YesText'), name='BtnYes') + btn(400, 214, 280, 80, 'grey', bl('CANCEL', 34, name='NoText'), name='BtnNo')
    out += grp('Confirm', f"<div class='cp a-gold' data-n='Card' style='left:1000px;top:560px;width:760px;height:330px'>{cf}</div>", 'TL')
    out += cap(1000, 924, 'Field Gems (world billboards): "+1" pop / "MAX" at the cap')
    out += grp('GemPop', gem_pop(1000, 980), 'TL') + grp('GemMax', gem_max(1260, 982), 'TL')
    return out


# ================================================================== HOS-CINE-002 Last One Standing (templates)
# The cut-scene before a solo crossing (one Runner left), in the order of Hunter's reference clips
# (docs/references/17_last_standing_faceoff_to_podium.mp4, 07_last_one_standing.mp4), our own style:
#   LS_Name     shot 1, face-level close-up (Runner on the left third): the name as a hero title (white-to-gold,
#               like RUNNERS WIN!) on the right, the gold banner with the crown under it: LAST ONE STANDING
#   LS_Vs       shot 2, low telephoto on the Catcher wall: VS (red, tilted) over the wall, red banner "21 CATCHERS"
#   LS_FaceOff  shot 3, over the Runner's shoulder: the FACE OFF! banner drops in, the role line on a toast-style
#               glass plate with the role's icon (runner / catcher / spectate)
#   LS_Compact  Reduce effects: no camera, bars or dim; one compact card top-centre under the match Status
#   LS_Pill     the solo crossing: "LAST ONE STANDING · <name>" under the match Status
# Same vocabulary as the results header (hero title over rays), panel titles (sport angled banner) and toasts
# (glass + icon). Letterbox bars, dim, camera, the hidden HUD/nametags are Controllers/Cinematic's; the beam
# and ring are VFX. Exported from last_standing.html (templates); the review sheet and the animated
# sequence (last_standing_play.html, same timings as Controllers/LastStanding) are not exported.
LS_BAR = 119   # Cinematic letterbox bar at 1080 (11%)
LS_NAME = 'SunnyBunny42'
LS_LONG = 'xXDragonSlayer2014Xx'   # 20 characters: the longest Roblox display name
LS_LINES = {
    'runner': ("It's all on you. Make it across to win it for the Runners.", 'runner'),
    'catcher': ('Catch {n} to win it for the Catchers.', 'catcher'),
    'other': ('{n} crosses alone. Can they make it?', 'spectate'),
}
LS_NAME_PX = 172          # hero title (RUNNERS WIN! is 104; 1.4x the first pass's 128 = 180, fitted to the right half)
LS_NAME_MIN = 84          # the runtime shrinks long names to fit LS_NAME_W, never below this (20 chars fit)
LS_NAME_W = 900           # the right half of the shot, clear of the Runner (left third, arms to ~x 900)
LS_NAME_CX = 1370         # centre of that column


def ls_fit(name, px=LS_NAME_PX, w=LS_NAME_W):
    """The size the runtime gives a name: the display font runs ~0.53-0.58 em per character (measured on the sheet)."""
    return max(LS_NAME_MIN, min(px, int(w / (0.58 * max(len(name), 1)))))


def ls_banner(x, y, w, h, acc, inner, name='Banner'):
    """The sport angled banner exactly as panel_sport draws its title (Edge + Fill + label), on its own."""
    return (f"<div class='sbn a-{acc}' data-n='{name}' style='left:{x}px;top:{y}px;width:{w}px;height:{h}px'>"
            f"<div class='o' data-n='Edge'></div><div class='f' data-n='Fill'></div>"
            f"<div class='lbl' style='justify-content:center;padding-left:6px'>{inner}</div></div>")


def ls_rays(cx, cy, d, op):
    """rays() clipped to the picture between the letterbox bars (a ClipsDescendants frame in Roblox), so the light
    never draws over the bars."""
    return box(0, LS_BAR, 1920, 1080 - 2 * LS_BAR, rays(cx, cy - LS_BAR, d, op), style='overflow:hidden', name='RaysClip')


def ls_name(name=LS_NAME, gname='LS_Name'):
    """Shot 1: the right half of the close-up; the Runner fills the left third."""
    px = ls_fit(name)
    out = ls_rays(LS_NAME_CX, 520, 1200, .42)
    out += at(LS_NAME_CX, 520 - int(px * .62), T(name, px, 'xl', 'f-gold', name='NameText'), w=LS_NAME_W + 120, align='center')
    out += ls_banner(LS_NAME_CX - 330, 600, 660, 104, 'gold', icn('crown', 82, name='Crown') + T('LAST ONE STANDING', 46, 'l', name='TagText'), 'Tag')
    return grp(gname, out, 'TL')


def ls_vs(n=21, gname='LS_Vs'):
    """Shot 2: VS above the Catchers' heads, the count banner under their feet: the wall framed between them."""
    out = ls_rays(900, 300, 1000, .42)
    out += at(900, 128, T('VS', 280, 'xl', 'f-red', style='display:inline-block;transform:rotate(-7deg)', name='VsText'), w=800, align='center')
    out += ls_banner(900 - 310, 842, 620, 104, 'coral', icn('catcher', 82, name='Icon') + T(f'{n} CATCHER' + ('' if n == 1 else 'S'), 56, 'xl', name='CountText'), 'Count')
    return grp(gname, out, 'TL')


def ls_role(role='runner', name=LS_NAME, y=LS_BAR + 186, size=34, gname=None):
    """The role line on a compact glass plate that hugs its text, the role's icon on the left (toast style)."""
    text, icon = LS_LINES[role]
    text = text.format(n=name)
    h, ic = int(size * 2.2), int(size * 2.9)
    plate = (f"<div class='glass' data-n='Plate' style='position:relative;display:flex;align-items:center;height:{h}px;"
             f"padding:0 {int(size * .8)}px 0 {int(ic * .82)}px'>"
             f"{I(icon, -int(ic * .18), (h - ic) // 2 - 4, ic, name='Icon')}{T(text, size, 's', name='RoleText')}</div>")
    out = f"<div class='abs' data-n='Role' style='left:0;width:1920px;top:{y}px;display:flex;justify-content:center'>{plate}</div>"
    return grp(gname, out, 'TL') if gname else out


def ls_faceoff(role='runner', name=LS_NAME, gname='LS_FaceOff'):
    """Shot 3: the FACE OFF! banner under the letterbox bar, the role plate under it; the Catchers stay clear."""
    out = ls_banner(960 - 360, LS_BAR + 24, 720, 132, 'gold', T('FACE OFF!', 92, 'xl', name='TitleText'), 'Title')
    out += ls_role(role, name)
    return grp(gname, out, 'TL')


def ls_compact(role='runner', name=LS_NAME, gname='LS_Compact'):
    """Reduce effects: one compact card top-centre under the match Status (which ends ~160), clear of every HUD group
    and above the Catcher line: the name, the banner, and the role line right under them on a plate that hugs its
    text. The runtime fades the whole card out after ~2.5 s."""
    out = at(960, 172, T(name, 84, 'xl', 'f-gold', name='NameText'), w=1100, align='center')
    out += ls_banner(960 - 300, 272, 600, 84, 'gold', icn('crown', 66, name='Crown') + T('LAST ONE STANDING', 38, 'l', name='TagText'), 'Tag')
    out += ls_role(role, name, y=366, size=31)   # 31 design px = 11.2 px on an 844x390 phone
    return grp(gname, out, 'TL')


def ls_pill(name=LS_NAME, gname='LS_Pill', y=176):
    """The solo crossing: under the Status header (Phase, Headline, Subline, CLEAN STREAK row end at ~160).
    The HUD's glass with the crown, like the HUD's wallet plates (hv_plate). Text 32 design px = 11.5 px on an
    844x390 phone (the 11 px floor); the runtime re-fits the width around the name."""
    w = 760 if len(name) > 14 else 640
    inner = f"<div class='glass' style='left:{960 - w // 2}px;top:{y}px;width:{w}px;height:66px'></div>"
    inner += I('crown', 960 - w // 2 + 8, y + 3, 60, name='Crown')
    inner += at(960 + 30, y + 14, row(T('LAST ONE STANDING', 32, 's', name='LeadText'), T('·', 32, 's', 'f-gold', name='DotText'),
                                      T(name, 32, 's', 'f-gold', name='NameText'), gap=12), w=w - 84, align='center')
    return grp(gname, box(0, 0, 1920, y + 70, inner, name='Pill'), 'TL')


def s_last_standing():
    """Exported templates page: each card in place on a 1920x1080 stage (runtime clones and fills them)."""
    out = "<div class='abs fill' style='background:linear-gradient(#3a1a66,#1e0a3e)'></div>"
    return out + ls_name() + ls_vs() + ls_faceoff() + ls_compact() + ls_pill()


LS_SHOTS = {1: 'cap_ls_s1_15.jpg', 2: 'cap_ls_s2_06.jpg', 3: 'cap_ls_s3_11.jpg', 'hud': 'cap_ls_faceoff2.jpg'}   # end / mid / end of each shot
LS_FRAMES = {1: 16, 2: 12, 3: 12}   # Studio captures through each shot (cap_ls_s<shot>_<k>.jpg, k = 0..n-1), for the animation


def ls_shot(img, w=1920, dim_k=.86):
    """A real Studio capture of the shot (edit mode, Beach, the shot's own camera CFrame and FOV), with the
    cut-scene's ColorCorrection dim and vignette."""
    return (f"<img src='{img}' style='position:absolute;left:0;top:0;width:{w}px;height:1080px;object-fit:cover;"
            f"filter:saturate(.75) brightness({dim_k}) contrast(1.06)'>"
            "<div class='abs fill' style='background:radial-gradient(ellipse at center,rgba(0,0,0,0) 50%,rgba(0,0,0,.45))'></div>")


def ls_bars(w=1920):
    return (f"<div class='abs' style='left:0;top:0;width:{w}px;height:{LS_BAR}px;background:#05070a'></div>"
            f"<div class='abs' style='left:0;bottom:0;width:{w}px;height:{LS_BAR}px;background:#05070a'></div>")


def ls_cell(label, body, w=1920):
    return (f"<div style='position:relative;width:{w}px;height:1080px;overflow:hidden;border:3px solid #000;background:#000;flex:none'>"
            f"{body}<div class='cap' style='left:16px;bottom:14px;font-size:30px;position:absolute'>{html.escape(label)}</div></div>")


def ls_phone(img, cards, w=2337, bars=True, dim=True):
    """A phone frame fitted by height (844x390 -> 2337 design px wide; iPhone SE 667x375 -> 1921): the shot fills
    it, the cards keep the design centre at the plain fit (a 1.25 boost pushed the banners into the bars)."""
    body = ls_shot(img, w, .86 if dim else 1) + (ls_bars(w) if bars else '')
    body += f"<div class='abs' style='left:{(w - 1920) // 2}px;top:0;width:1920px;height:1080px'>{cards}</div>"
    body += ("<div class='rbx' style='left:90px;top:640px;width:300px;height:300px'>thumbstick</div>"
             f"<div class='rbx' style='left:{w - 330}px;top:720px;width:200px;height:200px'>jump</div>")
    return body


def hud_status_stub():
    """The live match Status header as the game shows it in a solo crossing (same call as s_hud_match)."""
    pips = ''.join(f"<span class='pip k-lime' style='position:relative;display:inline-block;margin:0 8px'></span>" for _ in range(3))
    sub_l = T('Runner  ·  0:21  ·  1 Runner vs 21 Catchers', 22, 'xs')
    streak = at(960, 138, row(T('CLEAN STREAK', 15, 'xs', 'f-dim'), f"<span style='display:inline-flex'>{pips}</span>", gap=8), w=400, align='center')
    return hv_topcenter('CROSSING 5', 'Cross to the opposite safe side!', sub_l, streak)


def hud_bottom_stub():
    """The match HUD's bottom groups (egg level, ability, dash) as s_hud_match draws them, for overlap checks."""
    eg = f"<div class='glass' style='left:12px;top:878px;width:340px;height:178px'></div>"
    eg += slot(26, 892, 112, 'rare', 'egg_shiny', art_pad=.1)
    eg += at(152, 896, T('YOUR EGG', 16, 'xs', 'f-dim')) + at(152, 918, T('LEVEL 2', 44, 'l', 'f-rare'))
    return eg + hv_ability(lobby=False, cd=8) + hv_dash('DASH ON COOLDOWN', 'Space to dash sideways or back', .55)


def s_last_standing_states():
    """Review sheet: every beat and state over real Studio captures of each shot (Beach), PC then phone, then
    next to two existing EOSUI pieces (the results header and the match HUD) for the style check."""
    S1, S2, S3, H = LS_SHOTS[1], LS_SHOTS[2], LS_SHOTS[3], LS_SHOTS['hud']
    pc = [
        ('1  Name card: close-up, 1.2 s', ls_shot(S1) + ls_bars() + ls_name()),
        ('1  Name card, 20-character name (fitted)', ls_shot(S1) + ls_bars() + ls_name(LS_LONG)),
        ('2  VS: the Catcher wall, 1.0 s', ls_shot(S2) + ls_bars() + ls_vs()),
        ('2  VS, 1 Catcher', ls_shot(S2) + ls_bars() + ls_vs(1)),
        ('3  Face off: the lone Runner sees', ls_shot(S3) + ls_bars() + ls_faceoff('runner')),
        ('3  Face off: Catchers see', ls_shot(S3) + ls_bars() + ls_faceoff('catcher')),
        ('3  Face off: everyone else (safe / out)', ls_shot(S3) + ls_bars() + ls_faceoff('other')),
        ('3  Face off: Catchers, 20-character name', ls_shot(S3) + ls_bars() + ls_faceoff('catcher', LS_LONG)),
        ('Reduce effects: one card under the Status, HUD stays', ls_shot(H, dim_k=1) + hud_status_stub() + hud_bottom_stub() + ls_compact()),
        ('Solo crossing: the pill under the match Status', ls_shot(H, dim_k=1) + hud_status_stub() + hud_bottom_stub() + ls_pill()),
        ('Solo crossing: pill, 20-character name', ls_shot(H, dim_k=1) + hud_status_stub() + ls_pill(LS_LONG)),
        ('Later solo crossings (no cut-scene again): the pill counts the crossing', ls_shot(H, dim_k=1) + hud_status_stub() + hud_bottom_stub() + ls_pill('CROSSING 4')),
    ]
    ph = [
        ('Phone 844x390: name card', ls_phone(S1, ls_name())),
        ('Phone 844x390: VS', ls_phone(S2, ls_vs())),
        ('Phone 844x390: face off (Catcher, 20-character name)', ls_phone(S3, ls_faceoff('catcher', LS_LONG))),
        ('Phone 844x390: pill under the Status', ls_phone(H, hud_status_stub() + ls_pill(), bars=False, dim=False)),
        ('Phone 844x390: later solo crossing, pill only', ls_phone(H, hud_status_stub() + ls_pill('CROSSING 4'), bars=False, dim=False)),
        ('iPhone SE 667x375: face off (lone Runner)', ls_phone(S3, ls_faceoff('runner'), w=1921)),
        ('iPhone SE 667x375: reduce effects', ls_phone(H, hud_status_stub() + ls_compact(), w=1921, bars=False, dim=False)),
    ]
    cmp_ = [
        ('Style check: EOSUI results header (existing)', s_results()),
        ('Style check: EOSUI match HUD (existing)', s_hud_match()),
    ]
    out = "<div style='position:absolute;left:0;top:0;transform:scale(.5);transform-origin:0 0;display:flex;flex-wrap:wrap;gap:30px;width:3900px'>"
    for label, body in pc + cmp_:
        out += ls_cell(label, body)
    for label, body in ph:
        out += ls_cell(label, body, 2337 if '844' in label else 1921)
    return out + '</div>'


LS_PLAY_JS = """
<script>
// HOS-CINE-002 animated sequence: the runtime timings (Controllers/LastStanding + Controllers/Cinematic).
// setT(t) draws the frame at t seconds (deterministic, for frame-by-frame recording); without ?t it plays on loop.
(function(){
const L = 0.4;                       // lead-in: the normal HUD before the cut-scene starts
const END = L + 3.4 + 0.5;           // 0.5 s of HUD after it
const $ = s => document.querySelector(s);
const $$ = s => [...document.querySelectorAll(s)];
const clamp = (x, a, b) => Math.max(a, Math.min(b, x));
const k = (t, t0, d) => clamp((t - t0) / d, 0, 1);
const outQuart = x => 1 - Math.pow(1 - x, 4);
const inQuad = x => x * x;
const outBack = (x, s) => { s = s || 1.9; return 1 + (s + 1) * Math.pow(x - 1, 3) + s * Math.pow(x - 1, 2); };
const n = (sel, name) => $(sel + ' [data-n=' + name + ']');
window.setT = function(t){
  const cut = t >= L && t < L + 3.1;                 // the camera is the cut-scene's (Scriptable)
  const shot = t < L ? 0 : t < L + 1.2 ? 1 : t < L + 2.2 ? 2 : t < L + 3.1 ? 3 : 0;
  // camera: the Studio frames captured through each shot (the real CFrames), cross-faded between neighbours
  $$('.lsbg').forEach(e => e.style.opacity = 0);
  if (shot === 0) { $('#bg0').style.opacity = 1; }
  else {
    const t0 = shot === 1 ? L : shot === 2 ? L + 1.2 : L + 2.2, d = shot === 1 ? 1.2 : shot === 2 ? 1.0 : .9;
    const fr = $$('.lsf' + shot), x = k(t, t0, d) * (fr.length - 1), i = Math.floor(x), f = x - i;
    fr[i].style.opacity = 1; if (fr[i + 1]) fr[i + 1].style.opacity = f;
  }
  // the cut between shots dips through letterbox black for 0.2 s (Cinematic.COMFORT.DIP)
  const cuts = [L + 1.2, L + 2.2];
  let dipA = 0; cuts.forEach(c => { if (t >= c && t < c + .2) dipA = 1 - Math.sin(Math.PI / 2 * (t - c) / .2); });
  $('#dip').style.opacity = dipA;
  // HUD while the cut-scene runs: hidden (the HUD frame is shot 0)
  // letterbox: in over 0.28 s, out at 3.1 over 0.28 s
  const bars = t < L + 3.1 ? outQuart(k(t, L, .28)) : 1 - inQuad(k(t, L + 3.1, .28));
  $('#barT').style.transform = 'translateY(' + (-100 + 100 * bars) + '%)';
  $('#barB').style.transform = 'translateY(' + (100 - 100 * bars) + '%)';
  $('#dim').style.opacity = cut ? Math.min(1, k(t, L, .3)) : 0;
  // cards: visible only in their shot; everything scales out at 3.1
  const out = 1 - k(t, L + 3.1, .2);
  $('#c1').style.opacity = shot === 1 ? 1 : 0;
  $('#c2').style.opacity = shot === 2 ? 1 : 0;
  $('#c3').style.opacity = shot === 3 || (t >= L + 3.1 && t < L + 3.3) ? out : 0;
  // 1: name slams in (2.4 -> 1 with overshoot, 0.32 s), rays fade up and turn, banner wipes in from the left + shine
  const a1 = k(t, L + .25, .32);
  n('#c1', 'NameText').style.transform = 'scale(' + (2.4 - 1.4 * outBack(a1)) + ')';
  n('#c1', 'NameText').style.opacity = k(t, L + .25, .08);
  const r1 = n('#c1', 'Rays'); r1.style.opacity = .42 * k(t, L + .3, .35); r1.style.transform = 'rotate(' + (t * 14) + 'deg)';
  const w1 = outQuart(k(t, L + .45, .22));
  n('#c1', 'Tag').style.clipPath = 'inset(-20px ' + (100 - 100 * w1) + '% -20px -20px)';
  shine('#c1', 'Tag', k(t, L + .64, .4));
  // 2: VS punches in (UI scale bounce only: 1.8 -> 1, 0.16 s; no flash, no shake: Cinematic.COMFORT); the count wipes in
  const a2 = k(t, L + 1.25, .16);
  n('#c2', 'VsText').style.transform = 'rotate(-7deg) scale(' + (1.8 - .8 * outBack(a2, 2.4)) + ')';
  n('#c2', 'VsText').style.opacity = k(t, L + 1.25, .04);
  const r2 = n('#c2', 'Rays'); r2.style.opacity = .42 * k(t, L + 1.25, .2); r2.style.transform = 'rotate(' + (-t * 18) + 'deg)';
  const w2 = outQuart(k(t, L + 1.42, .2));
  n('#c2', 'Count').style.clipPath = 'inset(-20px ' + (100 - 100 * w2) + '% -20px -20px)';
  shine('#c2', 'Count', k(t, L + 1.58, .4));
  // 3: FACE OFF! drops in (from -90 px, overshoot), the role plate rises in after it
  const a3 = k(t, L + 2.25, .3);
  n('#c3', 'Title').style.transform = 'translateY(' + (-90 + 90 * outBack(a3, 2.2)) + 'px)';
  n('#c3', 'Title').style.opacity = k(t, L + 2.25, .06);
  const a4 = outQuart(k(t, L + 2.45, .22));
  n('#c3', 'Role').style.transform = 'translateY(' + (30 - 30 * a4) + 'px)';
  n('#c3', 'Role').style.opacity = a4;
  $$('.lscard').forEach(e => { if (t >= L + 3.1) e.style.transform = 'scale(' + (.92 + .08 * out) + ')'; });
  $('#clock').textContent = t < L ? 'HUD' : t < L + 3.4 ? (t - L).toFixed(2) + ' s' : 'crossing';
};
function shine(card, name, x){
  const b = n(card, name); let s = b.querySelector('.lsshine');
  if (!s) { s = document.createElement('i'); s.className = 'lsshine'; b.appendChild(s); }
  s.style.opacity = x > 0 && x < 1 ? 1 : 0; s.style.left = (-30 + 140 * x) + '%';
}
const q = new URLSearchParams(location.search);
if (q.has('t')) { setT(parseFloat(q.get('t'))); }
else { const t0 = performance.now(); (function loop(){ setT(((performance.now() - t0) / 1000) % END); requestAnimationFrame(loop); })(); }
window.LS_END = END;
})();
</script>"""


def s_last_standing_play(phone=False):
    """Animated review page: the whole moment with the runtime timings over the captured shots (not exported).
    Phone: an 844x390 screen fitted by height (2337 design px wide), cards at the design centre."""
    w = 2337 if phone else 1920
    x0 = (w - 1920) // 2
    style = ("<style>#stage{width:" + str(w) + "px !important;overflow:hidden}"
             ".lsbg{position:absolute;left:0;top:0;width:" + str(w) + "px;height:1080px;object-fit:cover;transform-origin:50% 50%;"
             "filter:saturate(.8) contrast(1.05)}"
             ".lscard{position:absolute;left:" + str(x0) + "px;top:0;width:1920px;height:1080px;transform-origin:50% 50%}"
             ".lscard [data-n=NameText],.lscard [data-n=VsText]{transform-origin:50% 60%;display:inline-block}"
             ".lsshine{position:absolute;top:-10%;width:22%;height:120%;transform:skewX(-20deg);z-index:4;"
             "background:linear-gradient(90deg,rgba(255,255,255,0),rgba(255,255,255,.75),rgba(255,255,255,0));pointer-events:none}"
             "#clock{position:absolute;right:24px;bottom:" + str(LS_BAR + 16) + "px;font:600 26px var(--font2,sans-serif);color:#fff;"
             "background:rgba(0,0,0,.45);padding:4px 12px;border-radius:8px;z-index:20}</style>")
    hud = "<img class='lsbg' id='bg0' src='" + LS_SHOTS['hud'] + "'>"
    shots = ''.join(f"<img class='lsbg lsf{i}' data-k='{k}' src='cap_ls_s{i}_{k:02d}.jpg' style='opacity:0'>"
                    for i in (1, 2, 3) for k in range(LS_FRAMES[i]))
    dim = ("<div id='dim' class='abs fill' style='opacity:0;background:radial-gradient(ellipse at center,rgba(0,0,0,.08) 45%,rgba(0,0,0,.5));"
           "z-index:2'></div>")
    cards = (f"<div class='lscard' id='c1' style='opacity:0;z-index:5'>{ls_name()}</div>"
             f"<div class='lscard' id='c2' style='opacity:0;z-index:5'>{ls_vs()}</div>"
             f"<div class='lscard' id='c3' style='opacity:0;z-index:5'>{ls_faceoff('runner')}</div>")
    bars = (f"<div id='barT' class='abs' style='left:0;top:0;width:{w}px;height:{LS_BAR}px;background:#05070a;z-index:8;transform:translateY(-100%)'></div>"
            f"<div id='barB' class='abs' style='left:0;bottom:0;width:{w}px;height:{LS_BAR}px;background:#05070a;z-index:8;transform:translateY(100%)'></div>")
    flash = "<div id='dip' class='abs fill' style='background:#05070a;opacity:0;z-index:7'></div>"
    return style + hud + shots + dim + cards + bars + flash + "<div id='clock'>HUD</div>" + LS_PLAY_JS


# ================================================================== states sheet
def s_states():
    out = "<div class='abs fill' style='background:linear-gradient(#3a1a66,#1e0a3e)'></div>"
    out += cap(40, 24, 'Buttons: normal / hover / pressed / off, all colours')
    for j, st in enumerate(['', 'st-hover', 'st-press', 'off']):
        out += btn(40 + j * 270, 80, 240, 84, 'lime', bl('CLAIM', 34), cls=st)
    for j, c in enumerate(['pink', 'purple', 'blue', 'gold', 'red', 'orange', 'teal', 'grey', 'white', 'sky']):
        out += btn(40 + (j % 5) * 220, 200 + (j // 5) * 100, 200, 76, c, bl(c.upper(), 28))
    out += cap(1180, 24, 'Rarity slots: Common / Rare / Epic / Crowned / locked / selected')
    for j, (r, ic, cls) in enumerate([('common', 'piece_common', ''), ('rare', 'piece_rare', ''), ('epic', 'piece_epic', ''), ('crowned', 'piece_crowned', ''), ('epic', 'piece_epic', 'locked'), ('rare', pet_img('PufferPup'), 'sel')]):
        out += slot(1180 + (j % 3) * 236, 80 + (j // 3) * 236, 210, r, ic, 'x1', TIER_NAME.get(r, r), cls=cls)
    out += cap(40, 430, 'Pet tiles: mastery colourways (showroom T1 / T2 / T3)')
    for t in (1, 2, 3):
        out += slot(40 + (t - 1) * 230, 480, 210, 'common', pet_img('SurferDog', t), cls='fill', art_pad=.05, inner_extra=at(34, 170, stars(t)))
    out += cap(760, 430, 'Bars + pips + tags')
    out += bar(760, 490, 400, 34, .66, 'pink') + bar(760, 540, 400, 34, 1, 'lime') + bar(760, 590, 400, 34, .2, 'purple')
    for i in range(4):
        out += f"<div class='pip k-sky{' on' if i < 2 else ''}' style='left:{1200 + i * 44}px;top:670px'></div>"
    out += tag(1200, 560, 'Daily Quest', 'blue') + tag(1360, 560, 'EQUIPPED', 'lime') + tag(1200, 610, 'POPULAR', 'pink')
    out += cap(40, 740, 'Empty states')
    out += well(40, 790, 560, 220, at(280, 30, col(icn('pets', 90, extra='opacity:.7'), T('No pets yet. Win 2 matches!', 28, 's', 'f-dim'), gap=6), w=560, align='center'))
    out += well(640, 790, 560, 220, at(280, 30, col(icn('quests', 90, extra='opacity:.7'), T('All done! New quests tomorrow', 28, 's', 'f-dim'), gap=6), w=560, align='center'))
    out += cap(1240, 740, 'Close button / key cap / badge')
    out += closex(1260, 800) + f"<div class='keycap' style='left:1380px;top:812px'>{T('Q', 32, 's')}</div>" + box(1470, 816, 44, 44, T('!', 26, 'xs'), 'badge')
    # HOS-GEMS-002 field Gems: the "+1" pop over time, "MAX", the results tag hidden / +1 / +2
    out += cap(40, 1090, 'Field Gems "+1" (collector only): pop in 0.6x, overshoot 1.15x, settle, rise 3.5 studs, fade (0.9 s)')
    for i, (t, sc, op) in enumerate([('0.00 s', .6, 1), ('0.12 s', 1.15, 1), ('0.25 s', 1, 1), ('0.60 s', 1, .9), ('0.85 s', 1, .3)]):
        x = 40 + i * 300
        out += f"<div style='position:absolute;left:{x}px;top:{1150 - i * 12}px;transform:scale({sc});transform-origin:50% 100%;opacity:{op}'>{gem_pop(0, 0, name=None)}</div>"
        out += at(x + 95, 1250, T(t, 20, 'xs', 'f-dim'), w=260, align='center')
    out += cap(1560, 1090, '"MAX" at the cap (once a match)')
    out += gem_max(1560, 1150, name=None)
    out += cap(40, 1300, 'Results, Gems reward: no field Gems (tag hidden) / +1 / +2')
    for i, (n, c) in enumerate([(0, 'x3'), (1, 'x4'), (2, 'x5')]):
        x = 40 + i * 420
        out += slot(x + 80, 1380, 146, 'lime', 'gem', c, 'Gems')
        if n:
            out += f"<div class='ctag k-lime' style='left:{x + 16}px;top:1334px;height:36px'>{row(icn('gem', 30), T(f'FIELD GEMS +{n}', 22, 'xs'), gap=6)}</div>"
    return out


# ================================================================== HOS-GEMS-002 review page (not exported)
def s_field_gems_templates():
    """HOS-GEMS-002 export page (ui_gems/rbx.json): every top-level group becomes a template in
    ReplicatedStorage.FieldGemsUITemplates. GemPop / GemMax go into a BillboardGui over the Gem; FieldGemsTag is
    parented onto the Results card's GemsSlot by Controllers/FieldGems."""
    out = "<div class='abs fill' style='background:#16161a'></div>"
    out += grp('GemPop', gem_pop(40, 40), 'TL')
    out += grp('GemMax', gem_max(300, 40), 'TL')
    out += grp('FieldGemsTag', f"<div class='ctag k-lime' data-n='Tag' style='left:40px;top:200px;height:36px'>{row(icn('gem', 30, name='Icon'), T('FIELD GEMS +2', 22, 'xs', name='TagText'), gap=6)}</div>", 'TL')
    return out


def s_field_gems_phone():
    """Phone (844 x 390 landscape) at design scale: the billboards are sized in studs (BillboardGui Size scale =
    studs, about 4 x 1.8), so they keep the same share of the screen as on PC; the top bar stays clear."""
    out = "<img src='cap_match_field.jpg' style='position:absolute;left:0;top:0;width:1920px;height:1080px;object-fit:cover'>"
    out += topbar()
    out += grp('GemPop', gem_pop(1060, 380), 'C') + grp('GemMax', gem_max(560, 330), 'C')
    out += at(960, 1010, T('Phone 844 x 390: same share of the screen as on PC (billboards sized in studs)', 26, 's'), w=1600, align='center')
    return out


def s_field_gems():
    """The field Gem pieces next to what they borrow from: the HUD Gems wallet (hv_plate) and the Results card."""
    out = s_results()
    left = "<img src='cap_match_field.jpg' style='position:absolute;left:0;top:0;width:1040px;height:1080px;object-fit:cover'>"
    left += "<div class='abs' style='left:0;top:0;width:1040px;height:1080px;background:rgba(0,0,0,.18)'></div>"
    left += gem_pop(590, 400, name=None) + gem_max(200, 300, name=None)
    left += hv_plate(972, 'gem', '14', 'GEMS', 'f-lime', 'Gems')
    left += cap(24, 24, 'Match capture (HOS-GEMS-002 playtest): "+1" over the Gem you took, "MAX" at the cap')
    left += cap(380, 1000, '<- the HUD Gems wallet they borrow from')
    return out + f"<div class='abs' style='left:0;top:0;width:1040px;height:1080px;overflow:hidden;z-index:50'>{left}</div>"


# ================================================================== style sheet
def s_style():
    out = "<div class='abs fill' style='background:#1e0a3e'></div>"
    out += cap(40, 20, '1. The reference Hunter picked (style only; watermark, art and exact layout not copied)')
    out += "<img class='abs' src='ref_candy.png' style='left:40px;top:66px;width:900px;height:506px;object-fit:cover;border-radius:10px'>"
    out += cap(980, 20, '2. Our lobby (bright stud world) + the real showroom pets')
    out += "<img class='abs' src='bg_lobby.jpg' style='left:980px;top:66px;width:900px;height:506px;object-fit:cover;border-radius:10px'>"
    for i, p in enumerate(['ShadesShark', 'GamerAxolotl', 'PebbleFrog', 'KoiSpirit', 'SandCrab', 'VikingWalrus']):
        out += I(pet_img(p), 1000 + i * 140, 410, 150)
    out += cap(40, 600, '3. Header bands: one accent per screen (from the lobby palette)')
    for i, (acc, t, ic) in enumerate([('pink', 'Quests', 'quests'), ('lime', 'Incubator', 'incubator'), ('sky', 'Pets', 'pets'), ('gold', 'Shop', 'shop'), ('violet', 'Settings', 'settings'), ('coral', 'Alerts', 'info')]):
        x, y = 40 + (i % 3) * 620, 650 + (i // 3) * 130
        out += (f"<div class='cp a-{acc}' style='left:{x}px;top:{y}px;width:580px;height:100px'><div class='ch' style='height:100px;border-bottom:0'><div class='sweep'></div>"
                f"<div class='lbl'>{icn(ic, 76)}{T(t, 52, 'l')}</div></div></div>")
    out += cap(40, 930, '4. Icons (ChatGPT set, drawn stand-ins where missing), egg pieces and the nine ability families in wave order')
    for i, ic in enumerate(['gold', 'gem', 'piece_common', 'piece_rare', 'piece_epic', 'piece_crowned', 'quests', 'incubator', 'pets', 'shop', 'stats', 'settings',
                            'runner', 'catcher', 'safe'] + [p[2] for p in POOLS]):   # + the nine ability families in wave order
        out += I(ic, 40 + (i % 12) * 152, 980 + (i // 12) * 150, 130)
    out += cap(40, 1290, '5. Eggs: Level 1 Basic, 2 Shiny, 3 Cosmic, 4 Golden (survivor)')
    for i, e in enumerate(['basic', 'shiny', 'cosmic', 'golden']):
        out += slot(40 + i * 240, 1340, 210, ['common', 'rare', 'epic', 'crowned'][i], 'egg_' + e, label=f'Level {i + 1}')
    out += btn(1040, 1360, 260, 84, 'lime', bl('CLAIM ALL', 32)) + btn(1320, 1360, 260, 84, 'pink', bl('TRACK QUEST', 30)) + btn(1600, 1360, 260, 84, 'purple', bl('All [2]', 30))
    out += btn(1040, 1470, 260, 84, 'grey', bl('Done [0]', 30)) + closex(1340, 1470)
    return out


def s_compare():
    out = "<div class='abs fill' style='background:#1e0a3e'></div>"
    out += cap(40, 20, 'BEFORE: the current lobby HUD (Studio capture, 15 Oct 2026)')
    out += "<img class='abs' src='cap_lobby_before.jpg' style='left:40px;top:66px;width:1840px;height:982px;object-fit:contain'>"
    return out


# ================================================================== Welcome back gift + favorites prompt (HOS-RET-001)
GIFT_GOLD, GIFT_GEMS = 250, 2   # proposed daily welcome-back gift (economy decisions: ~2,700 Gold/h, ~30 Gems/h); Hunter to confirm


def gift_card(state='claim', x=410, y=300, scale=1.0):
    """One card, two states (like the reference): 'claim' = a returning player's gift is ready (CLAIM);
    'wait' = first visit, or just claimed: 'come back tomorrow' with the countdown to the next gift."""
    w, h = 1100, 520
    claim = state == 'claim'
    chip = row(icn('clock', 44), T('Next gift in 23:51:10' if not claim or EXPORT_STATES else 'Ready now!', 30, 's', '' if not claim or EXPORT_STATES else 'f-lime', name='TimerText'), gap=8)
    b = ''
    # left: the gift itself (reference: the item tile with its rarity word)
    b += slot(50, 56, 300, 'gold' if claim or EXPORT_STATES else 'locked', 'gift_daily', label='FREE GIFT', name='GiftTile', art_pad=.12, label_size=30)
    # right: what's inside + the action
    if claim:
        b += at(400, 52, T('Thanks for coming back!', 44, 'l', name='Head'))
        b += at(402, 112, T("Here's your free gift for today.", 28, 's', 'f-dim', name='Sub'))
    else:
        b += at(400, 52, T('Come back tomorrow', 44, 'l', name='Head'))
        b += at(402, 112, T('for another FREE gift!', 44, 'l', 'f-gold', name='Sub'))
    b += slot(400, 178, 136, 'gold', 'gold', f'x{GIFT_GOLD}', 'Gold', name='GoldSlot')
    b += slot(552, 178, 136, 'lime', 'gem', f'x{GIFT_GEMS}', 'Gems', name='GemsSlot')
    if claim or EXPORT_STATES:   # export: both buttons, the runtime shows one
        b += btn(720, 196, 320, 100, 'lime', bl('CLAIM', 44), name='BtnClaim')
    if not claim or EXPORT_STATES:
        b += btn(720, 196, 320, 100, 'grey', bl('COME BACK LATER', 28), name='BtnLater', cls='off', hid=claim)
    b += at(400, 334, T('One free gift every day you play.', 24, 'xs', 'f-dim', name='Note'))
    title = 'Welcome back!' if claim else 'Free gift'
    p = panel_sport('GiftCard', 'gold', title, 'gift_daily', b, x, y, w, h, right=chip, title_size=58)
    if scale != 1.0:
        p = p.replace("data-a='C' style='", f"data-a='C' style='transform:scale({scale});transform-origin:960px 560px;", 1)
    return p


def fav_prompt(x=760, y=330):
    """Roblox's own favorite dialog (AvatarEditorService:PromptSetFavorite). Drawn here only to show where and when it
    appears; Roblox draws it and we can't restyle it."""
    st = ("position:absolute;left:{x}px;top:{y}px;width:400px;height:370px;background:#232527;border-radius:14px;"
          "box-shadow:0 12px 40px rgba(0,0,0,.55);z-index:100;font-family:Arial,Helvetica,sans-serif;color:#fff;text-align:center").format(x=x, y=y)
    inner = "<div style='padding:18px 0 12px;font-size:20px;font-weight:700;border-bottom:1px solid #3a3d40'>Favorite Item</div>"
    inner += "<div style='padding:16px 30px 0;font-size:16px;line-height:22px;color:#e2e4e6'>Do you want to add Hatch or Snatch to favorites?</div>"
    inner += "<img src='bg_lobby.jpg' style='display:block;margin:14px auto 0;width:150px;height:150px;object-fit:cover;object-position:60% 60%;border-radius:6px'>"
    inner += ("<div style='position:absolute;left:16px;right:16px;bottom:18px;display:flex;gap:12px'>"
              "<div style='flex:1;height:36px;line-height:36px;border:1px solid #6b6e72;border-radius:8px;font-size:15px'>No</div>"
              "<div style='flex:1;height:36px;line-height:36px;background:#fff;color:#111;border-radius:8px;font-size:15px;font-weight:700'>Yes</div></div>")
    return f"<div style='{st}'>{inner}</div>"


def s_gift(state='claim'):
    out = world('bg_lobby_blur.jpg', False) + dim(.5)
    return out + gift_card(state)


def s_first_visit():
    """First visit, back in the lobby after the player's first finished match: the 'come back tomorrow' card,
    with Roblox's favorite prompt on top (the reference shows both together)."""
    out = world('bg_lobby_blur.jpg', False) + dim(.5) + gift_card('wait')
    out += "<div class='abs fill' style='background:rgba(0,0,0,.35);z-index:99'></div>" + fav_prompt()
    out += at(960, 868, T("Roblox's own favorite prompt on top: shown once ever, never mid-match", 28, 's'), w=1200, align='center', style='z-index:100')
    return out


def s_gift_phone():
    """Phone (844 x 390 landscape): the card grows 1.3x so CLAIM is a big thumb target; Roblox's top bar kept clear."""
    out = world('bg_lobby_blur.jpg', False) + dim(.5) + topbar() + gift_card('claim', scale=1.3)
    return out


def flow_card(x, y, w, h, color, head, lines):
    inner = f"<div class='ch a-{color}' style='height:84px'><div class='sweep'></div><div class='lbl'>{T(head, 34, 'l')}</div></div>"
    for i, ln in enumerate(lines):
        inner += at(28, 104 + i * 40, T(ln, 24, 's', 'f-dim' if ln.startswith('(') else ''))
    return f"<div class='cp a-{color}' style='left:{x}px;top:{y}px;width:{w}px;height:{h}px'>{inner}</div>"


def s_gift_flow():
    out = "<div class='abs fill' style='background:linear-gradient(#3a1a66,#1e0a3e)'></div>"
    out += cap(40, 24, 'When each one shows: lobby only, never mid-match, one at a time, 3+ minutes apart (the waiting card is the only one in a match)')
    cards = [
        ('gold', '0. You rejoin', ['A new day (UTC) since your', 'last gift: WELCOME BACK!', 'a few seconds after you', 'spawn in the lobby. You tap', 'CLAIM (never auto-claimed),', 'the card flips to the', 'countdown.', '(Same day again: nothing.)']),
        ('pink', '1. First match done', ['Back in the lobby after', 'your first finished match:', '"Come back tomorrow" card', 'with Roblox\'s favorite', 'prompt on top.', '', '(Favorite: once ever.)', '(No reward for a favorite.)']),
        ('sky', '2. Next lobby break', ["Roblox's Join Event prompt", 'for the next event, if one', 'is set up in config.', '', '', '', '(Once per event.)', '(No event set: skipped.)']),
        ('lime', '3. After your first pet', ['Starter pack offer, once.', 'Economy rule 33: no shop', 'prompts before the first', 'pet. The 48 h timer is real', 'and kept on the server.', '', '(Not wired to a purchase', 'until you set the offer.)']),
    ]
    for i, (c, head, lines) in enumerate(cards):
        out += flow_card(40 + i * 465, 80, 440, 450, c, head, lines)
    out += cap(40, 570, 'Proposed daily gift (for Hunter to confirm)')
    out += slot(40, 620, 200, 'gold', 'gold', f'x{GIFT_GOLD}', 'Gold')
    out += slot(260, 620, 200, 'lime', 'gem', f'x{GIFT_GEMS}', 'Gems')
    out += at(500, 630, col(T(f'{GIFT_GOLD} Gold + {GIFT_GEMS} Gems a day', 40, 'l'),
                            T('About 6 minutes of normal play (2,700 Gold and ~30 Gems an hour).', 26, 's', 'f-dim'),
                            T('Small on purpose: no big Gem gifts (economy decisions 30-31).', 26, 's', 'f-dim'), gap=8, align='flex-start'))
    out += cap(40, 860, 'Starter pack: what you need to decide')
    out += at(40, 910, col(T('Contents and Robux price. Robux buys looks only (decision 32): Gems, a trail, an emote, an egg case.', 26, 's', 'f-dim'),
                           T('The timer is a real 48 h window from when it first shows; no made-up "was" price.', 26, 's', 'f-dim'), gap=8, align='flex-start'))
    return out


def rsvp_prompt(x=760, y=170):
    """Roblox's own event RSVP dialog (SocialService:PromptRsvpToEventAsync). Placeholder event; only shown when an
    event id is set in config."""
    st = ("position:absolute;left:{x}px;top:{y}px;width:400px;height:540px;background:#232527;border-radius:14px;"
          "box-shadow:0 12px 40px rgba(0,0,0,.55);z-index:100;font-family:Arial,Helvetica,sans-serif;color:#fff").format(x=x, y=y)
    inner = "<div style='padding:18px 0 14px;font-size:20px;font-weight:700;text-align:center;border-bottom:1px solid #3a3d40'>Join Event</div>"
    inner += ("<div style='position:relative;margin:18px 24px 0;height:190px;border-radius:8px;overflow:hidden'>"
              "<img src='bg_lobby.jpg' style='width:100%;height:100%;object-fit:cover'>"
              "<div style='position:absolute;left:10px;top:10px;background:#fff;color:#111;font-size:13px;padding:5px 10px;border-radius:12px'>[Event date and time]</div></div>")
    inner += "<div style='margin:16px 24px 0;font-size:17px;font-weight:700'>[Event title, e.g. Update 2]</div>"
    inner += ("<div style='margin:10px 24px 0;font-size:15px;line-height:22px;color:#e2e4e6'>[Event description from the Creator Dashboard: "
              "what's new, written by you when you create the event.]</div>")
    inner += ("<div style='position:absolute;left:24px;right:24px;bottom:24px;height:36px;line-height:36px;text-align:center;"
              "background:#335fff;border-radius:8px;font-size:15px'>Notify Me</div>")
    return f"<div style='{st}'>{inner}</div>"


def s_event_rsvp():
    out = world('bg_lobby_blur.jpg', False) + dim(.5) + rsvp_prompt(760, 220)
    out += at(960, 840, T("Roblox's own Join Event prompt: once per event, only when one is set up", 28, 's'), w=1300, align='center', style='z-index:100')
    out += at(960, 884, T('Event image, date and text come from the Creator Dashboard (placeholders here)', 24, 'xs', 'f-dim'), w=1300, align='center', style='z-index:100')
    return out


STARTER = [  # placeholders only: Hunter sets the real contents and price (Robux buys looks only, decision 32)
    ('gem', 'lime', 'Gems', 'x??'),
    ('trail_rainbow', 'sky', 'Trail', '??'),
    ('emote', 'epic', 'Emote', '??'),
    ('case', 'gold', 'Egg Case', '??'),
]


def starter_card(scale=1.0):
    x, y, w, h = 360, 250, 1200, 600
    chip = row(icn('clock', 44), T('Offer ends in 47:59:12', 30, 's', 'f-gold', name='TimerText'), gap=8)
    b = at(60, 26, T('A one-time bundle of looks for new players.', 30, 's', 'f-dim', name='Sub'))
    for i, (ic, r, lab, cnt) in enumerate(STARTER):
        b += slot(70 + i * 270, 80, 230, r, ic, cnt, lab, name=f'Item{i + 1}', label_size=30)
    b += at(70, 326, T('PLACEHOLDER CONTENTS AND PRICE: Hunter sets the real offer', 24, 'xs', 'f-orange', name='Note'))
    b += btn(70, 372, 360, 96, 'grey', bl('NO THANKS', 32), name='BtnNo')
    b += btn(690, 372, 440, 96, 'lime', row(icn('robux', 54), T('???', 48, 'l', name='PriceText'), gap=10), name='BtnBuy')
    b += tag(950, 318, 'ONE TIME ONLY', 'pink', 22, 40, name='Tag')
    p = panel_sport('StarterPack', 'pink', 'Starter pack', 'shop', b, x, y, w, h, right=chip, title_size=58)
    if scale != 1.0:
        p = p.replace("data-a='C' style='", f"data-a='C' style='transform:scale({scale});transform-origin:960px 560px;", 1)
    return p


def s_starter():
    return world('bg_lobby_blur.jpg', False) + dim(.5) + starter_card()


WAIT_OFFERS = [  # rotate every ~8 s while you wait out a Hero run. Looks and XP only (decision 32): no abilities, eggs or focus.
    ('vip', 'VIP', 'crown', 'gold', '499', ['+25% match XP', 'VIP tag over your head', 'Honored One emote']),
    ('xp2', '2x XP', 'star', 'sky', '199', ['Double XP every match', 'Level up twice as fast', 'Yours forever']),
    ('starter', 'Starter Pack', 'shop', 'pink', '???', ['Gems x??, a trail', 'An emote, an egg case', 'PLACEHOLDER offer']),
]


def wait_offer(o, x=1300, y=700, dot=0, gname=None):
    key, title, icon, acc, price, lines = o
    w, h = 580, 230
    inner = box(0, 0, w, h, '', f'cs r-{acc}', 'border-radius:16px', name='Card')
    inner += I(icon, 24, 18, 130, name='Icon')
    inner += btn(14, 152, 156, 62, 'lime', row(icn('robux', 38), T(price, 30, 'l', name='PriceText'), gap=6), name='BtnBuy')
    for i, ln in enumerate(lines):
        inner += at(196, 34 + i * 52, T(ln, 28, 's', 'f-orange' if ln.startswith('PLACEHOLDER') else '', name=f'Line{i + 1}'))
    inner += at(w // 2 + 90, 196, row(*[f"<span data-n='Dot{i + 1}' style='display:inline-block;width:12px;height:12px;border-radius:6px;background:{'#fff' if i == dot else 'rgba(255,255,255,.35)'}'></span>" for i in range(len(WAIT_OFFERS))], gap=8), w=200, align='center', name='Dots')
    inner += f"<div class='cx' data-n='CloseButton' data-btn=1 style='left:{w - 46}px;top:-30px;transform:scale(.62);transform-origin:0 0'>{T('X', 48, 'l')}</div>"
    inner += at(w // 2, -64, T(title, 56, 'xl', name='Title'), w=w, align='center')
    return grp(gname or f'WaitOffer_{key}', box(x, y, w, h, inner, name='Offer'), 'BR')


def s_wait_offer():
    out = world() + topbar()
    out += hv_topcenter('HERO RUN', 'Mia is crossing alone!', T('Round 1  ·  0:19  ·  you are waiting', 22, 'xs', name='SublineText'))
    out += wait_offer(WAIT_OFFERS[0], gname='WaitOffer')
    out += at(960, 1020, T('Only while you wait out a Hero run. Never while you play a crossing.', 26, 's'), w=1400, align='center')
    return out


def s_wait_offers():
    out = "<div class='abs fill' style='background:linear-gradient(#3a1a66,#1e0a3e)'></div>"
    out += cap(40, 24, 'The card cycles these every 8 s (VIP and 2x XP prices come from the shop pass config; the starter pack is a placeholder)')
    for i, o in enumerate(WAIT_OFFERS):
        out += wait_offer(o, 60 + (i % 3) * 620, 170, dot=i)
    out += cap(40, 470, 'Left out on purpose')
    out += at(40, 520, col(T("The reference's Catcher Pack sells an ability and Gems. We don't sell abilities (economy decision 32).", 28, 's', 'f-dim'),
                           T('No offer before your first pet (decision 33). X hides the card for the rest of the session.', 28, 's', 'f-dim'),
                           T('Never shown to the Hero, to anyone crossing, or while a first-visit prompt is up.', 28, 's', 'f-dim'), gap=12, align='flex-start'))
    return out


# ================================================================== Lead Catcher (HOS-LEAD-001)
# One paid Lead Catcher per match (29 Robux): that match's starting Catcher and the Hero or Chicken picker.
# A small corner card in the lobby wait, the waiting offer's treatment (cs plate, icon left, lime Robux button),
# shown only between matches (LeadCatcherState free / reserved / taken; hidden while closed or off).
# Four states, one per viewer: Buy (free), Pending (the buyer, prompt open), Taken (everyone else), Yours (holder).
LEAD_PRICE = '29'
LEAD_HOLDER = 'SunnyBunny42'


def lead_card(state='buy', x=1300, y=800, gname='LeadCatcher', scale=1.0):
    w, h = 580, 176
    rim = {'buy': 'red', 'pending': 'red', 'taken': 'red', 'yours': 'gold'}[state]   # taken = the red plate greyed
    inner = box(0, 0, w, h, '', f'cs r-{rim}', 'border-radius:16px' + (';filter:grayscale(1) brightness(.8)' if state == 'taken' else ''), name='Card')
    icon_css = 'filter:grayscale(1) brightness(.75)' if state == 'taken' else ''
    inner += I('catcher', 16, 20, 136, name='Icon', extra=icon_css)
    tx = 166
    if state == 'buy':
        inner += at(tx, 18, T('BE LEAD CATCHER', 38, 'l', name='Title'))
        inner += at(tx, 66, T('Start as the Catcher and pick', 22, 's', name='Line1'))
        inner += at(tx, 94, T('Hero or Chicken all match', 22, 's', name='Line2'))
        inner += btn(tx, 122, 170, 44, 'lime', row(icn('robux', 30), T(LEAD_PRICE, 28, 'l', name='PriceText'), gap=6), name='BtnBuy')
        inner += tag(tx + 190, 128, '1 PER MATCH', 'pink', 18, 32, name='Tag')
    elif state == 'pending':
        inner += at(tx, 18, T('BE LEAD CATCHER', 38, 'l', name='Title'))
        inner += at(tx, 66, T("It's held for you: finish the", 22, 's', name='Line1'))
        inner += at(tx, 94, T('Roblox purchase to lock it in', 22, 's', name='Line2'))
        inner += btn(tx, 122, 300, 44, 'grey', T('Waiting for purchase...', 22, 's', name='Label'), name='BtnBuy')
        inner += at(tx + 316, 128, row(icn('clock', 30), T('0:24', 26, 's', 'f-gold', name='TimerText'), gap=4))
    elif state == 'taken':
        inner += at(tx, 22, T('LEAD CATCHER TAKEN', 34, 'l', 'f-dim', name='Title'))
        inner += at(tx, 70, row(icn('lock', 28), T(LEAD_HOLDER, 26, 's', name='HolderText'), gap=6))
        inner += at(tx, 108, T('has it this match. Next match', 22, 's', 'f-dim', name='Line1'))
        inner += at(tx, 136, T('it opens up again.', 22, 's', 'f-dim', name='Line2'))
    else:
        inner += at(tx, 18, T("YOU'RE LEAD CATCHER", 32, 'l', 'f-gold', name='Title'))   # 36 ran to the edge in-game (17 Oct)
        inner += at(tx, 62, T('NEXT MATCH', 26, 's', name='Sub'))
        inner += at(tx, 100, row(icn('check', 28), T('You start as the Catcher', 22, 's', name='Line1'), gap=6))
        inner += at(tx, 134, T('and pick Hero or Chicken', 22, 's', name='Line2'))
    card = box(x, y, w, h, inner, name='Card_' + state)
    if scale != 1.0:
        card = f"<div class='abs fill' style='transform:scale({scale});transform-origin:{x + w}px {y + h}px'>{card}</div>"
    return grp(gname, card, 'BR')


def s_lead_lobby(state='buy'):
    """The card in place: the lobby wait (Next match in 0:12), bottom right, clear of the ability and dash."""
    return s_hud() + lead_card(state)


def s_lead_states():
    out = "<div class='abs fill' style='background:linear-gradient(#3a1a66,#1e0a3e)'></div>"
    out += cap(40, 20, 'HOS-LEAD-001 Lead Catcher card: one per viewer, in the lobby wait only (hidden once roles are assigned)')
    labels = [('buy', 'a  BUY: the slot is free (everyone)'), ('pending', 'b  PENDING: you pressed it, your Roblox prompt is open (30 s hold)'),
              ('taken', 'c  TAKEN: someone else has it (greyed, no button)'), ('yours', "d  YOURS: you hold a pass (bought, or saved from before)")]
    for i, (st, lab) in enumerate(labels):
        x, y = 40 + (i % 2) * 940, 80 + (i // 2) * 290
        out += cap(x, y, lab)
        out += lead_card(st, x, y + 60, gname=f'LeadCatcher_{st}')
    out += cap(40, 680, 'Beside the existing waiting offer (same plate, icon, button and text sizes)')
    out += wait_offer(WAIT_OFFERS[0], 40, 790, gname='WaitOffer_ref')
    out += lead_card('buy', 680, 844, gname='LeadCatcher_ref')
    out += at(1320, 760, col(T('Rules shown by the card', 28, 'l'),
                             T('Only one buyer per match: the server holds', 22, 's', 'f-dim'),
                             T('the slot for one player while they pay.', 22, 's', 'f-dim'),
                             T('Beaten to it? The purchase is saved as a', 22, 's', 'f-dim'),
                             T('pass for your next match.', 22, 's', 'f-dim'),
                             T('Same powers as any Catcher (no buffs).', 22, 's', 'f-dim'), gap=6, align='flex-start'))
    return out


def s_lead_phone():
    """Phone: the lobby HUD (phone) with the card 1.25x, bottom right above Roblox's jump button."""
    return s_hud_phone() + lead_card('buy', 1316, 540, scale=1.25)


def s_lead_templates():
    """HOS-LEAD-001 export page (ui_lead/rbx.json): each state card becomes a template in
    ReplicatedStorage.LeadCatcherUITemplates; Controllers/LeadCatcherController clones the one for this viewer
    bottom right in the lobby and fills HolderText / TimerText / PriceText."""
    out = "<div class='abs fill' style='background:#16161a'></div>"
    for i, st in enumerate(['buy', 'pending', 'taken', 'yours']):
        out += lead_card(st, 40 + (i % 2) * 640, 40 + (i // 2) * 240, gname='LeadCard' + st.capitalize())
    return out


# ================================================================== Map vote (HOS-MAPVOTE-001, mockup)
# NEXT MAP vote during the lobby INTERMISSION (15 s): two of the maps not just played (MapService ORDER), counts,
# voter heads, a timer, then the winner. The approved Lead Catcher card docks centred under it (Hunter's reference).
# Map photos don't exist yet: themed placeholder tiles until they're captured in Studio.
MAPS_V = {
    'SunnyCove': ('Sunny Cove', 'linear-gradient(160deg,#7fd6ff 0%,#3fb0e8 38%,#f4d58a 62%,#e8b866 100%)', 'SAND + PALMS'),
    'FrostyPass': ('Frosty Pass', 'linear-gradient(160deg,#cfe9ff 0%,#9cc8f0 40%,#ffffff 64%,#b8d8f4 100%)', 'ICE + SNOW'),
    'Farm': ('Hatchery Farm', 'linear-gradient(160deg,#9fe0ff 0%,#78c850 45%,#4fa63a 70%,#8a5a34 100%)', 'THE CLASSIC'),
    'Stadium': ('Egg Bowl Stadium', 'linear-gradient(160deg,#5a6cff 0%,#3a3f9a 40%,#4fbf4a 66%,#2e8a2e 100%)', 'BIG CROWD'),
}
VOTERS = ['#ff7a59', '#59b8ff', '#ffd23f', '#9b6bff', '#4ed45a', '#ff5fa2', '#c0c0c0', '#ffa03a']


def heads(n, x, y, size=40, name='Voters'):
    out = ''
    shown = min(n, 5)
    for i in range(shown):
        c = VOTERS[i % len(VOTERS)]
        out += (f"<div class='abs' style='left:{x + i * (size - 10)}px;top:{y}px;width:{size}px;height:{size}px;border-radius:50%;"
                f"background:radial-gradient(circle at 50% 38%,#ffe0c4 0 30%,{c} 31%);border:3px solid #fff;box-shadow:0 0 0 2px #050506'></div>")
    if n > shown:
        out += box(x + shown * (size - 10), y, size + 8, size, T(f'+{n - shown}', 18, 'xs'), '', f'border-radius:{size // 2}px;background:#1d1f2a;border:3px solid #fff;display:flex;align-items:center;justify-content:center')
    return f"<div class='abs fill' data-n='{name}' style='pointer-events:none'>{out}</div>"


IT = ''   # the kit's Fredoka has no italic in Roblox; titles stay upright like every other panel


def name_size(title, box_w=409, base=40):
    """Map names fit their plate: the size shrinks for long names (EGG BOWL STADIUM) instead of overflowing."""
    est = len(title) * base * 0.62
    return base if est <= box_w else max(24, int(base * box_w / est))


def map_tile(x, y, key, votes, idx, mode='open', export=False):
    """One map card, 445 x 310 (reference proportions), in the kit's card plate (cs, like the Results podium cards):
    the map photo inset in the plate, an outlined vote count top-right, a tag (ctag) top-left, voter headshots on
    the photo, the map name on the plate under it (sized to fit). mode: open | mine (lime plate) | win (gold plate +
    WINNER) | lose (dimmed). export=True: every plate / state layer on the page, the 8 heads as image slots."""
    title, bg, tagline = MAPS_V[key]
    w, h = 445, 310
    pw, ph = w - 16, 226   # 429 x 226: the map photos are cropped to exactly this aspect (858 x 452)
    plate = {'open': 'sky', 'mine': 'lime', 'win': 'gold', 'lose': 'sky'}[mode]
    if export:   # the runtime swaps plates: Plate (sky) always, PlateMine / PlateWin on top when they apply
        inner = box(0, 0, w, h, '', 'cs r-sky fill lab', '', name='Plate')
        inner += box(0, 0, w, h, '', 'cs r-lime fill lab', '', name='PlateMine', hid=mode != 'mine')
        inner += box(0, 0, w, h, '', 'cs r-gold fill lab', '', name='PlateWin', hid=mode != 'win')
    else:
        inner = box(0, 0, w, h, '', f'cs r-{plate} fill lab', '', name='Plate')
    photo = os.path.exists(os.path.join(HERE, 'set', 'icons', f'map_{key.lower()}.png'))
    inner += (I(f'map_{key.lower()}', 8, 8, pw, ph, name='Art', extra='border-radius:2px;object-fit:fill') if photo
              else box(8, 8, pw, ph, '', '', f'border-radius:2px;background:{bg}', name='Art'))
    inner += tag(20, 20, tagline, 'blue', 18, 36, name='Tag')
    inner += at(w - 20, 12, T(str(votes), 66, 'xl', name='VotesText'), w=200, align='right')
    hs = 44
    for k in range(8):
        on = k < votes
        if export:
            inner += box(18 + k * 32, 176, hs, hs, I('runner', 3, 3, hs - 6, name='Img', extra='border-radius:50%'), '', 'border-radius:50%;background:#2a2d3a;border:3px solid #fff;box-shadow:0 0 0 2px #050506', name=f'Head{k + 1}', hid=not on)
        elif on:
            c = VOTERS[k % len(VOTERS)]
            inner += (f"<div class='abs' style='left:{18 + k * 32}px;top:176px;width:{hs}px;height:{hs}px;border-radius:50%;"
                      f"background:radial-gradient(circle at 50% 38%,#ffe0c4 0 30%,{c} 31%);border:3px solid #fff;box-shadow:0 0 0 2px #050506'></div>")
    more = box(18 + 8 * 32 + 16, 178, 58, 40, T(f'+{max(0, votes - 8)}', 20, 's', name='MoreText'), '', 'border-radius:20px;background:#1c1c1e;border:3px solid #fff;box-shadow:0 0 0 2px #050506;display:flex;align-items:center;justify-content:center', name='More', hid=votes <= 8)
    if export or votes > 8:
        inner += more
    ns = name_size(title.upper())
    inner += box(8, 238, pw, 64, T(title.upper(), ns, 'l', name='MapName'), '', 'display:flex;align-items:center;padding:0 14px', name='NameBox')
    if export or mode == 'win':
        win = tag(w - 140, 96, 'WINNER', 'gold', 22, 40, name='WinTag')
        inner += win if mode == 'win' else win.replace("class='ctag", "class='ctag hid", 1)
    inner += box(0, 0, w, h, '', '', 'background:rgba(0,0,0,.5)', name='Dim', hid=mode != 'lose')
    return box(x, y, w, h, inner, name=f'Tile{idx}')


MV_W, MV_H, MV_Y = 960, 473, 200


def vote_panel(x=None, y=MV_Y, mode='open', timer='0:12', frac=.8, a=('SunnyCove', 3), b=('FrostyPass', 12), export=False):
    """NEXT MAP, laid out like Hunter's reference 03 (960 x 473 = 50% x 44% of 1080p) in the kit's sport finish:
    the Results panel (glow, dark plate, blue frame), a full-width halftone banner header with NEXT MAP centred and the
    stopwatch beside it, the tilted red X, the 8 px bar, two 445 x 310 card plates, a centred hint line."""
    x = (1920 - MV_W) // 2 if x is None else x
    w, h = MV_W, MV_H
    out = f"<div class='cglow a-sky' data-n='Glow' style='left:-16px;top:-12px;width:{w + 32}px;height:{h + 28}px'></div>"
    out += f"<div class='cp a-sky' data-n='Panel' style='left:0;top:0;width:{w}px;height:{h}px'></div>"
    out += (f"<div class='sbn a-sky' data-n='Banner' style='left:0;top:0;width:{w}px;height:88px'>"
            "<div class='o' data-n='Edge' style='clip-path:none'></div><div class='f' data-n='Fill' style='clip-path:none'></div></div>")
    out += at(w // 2, 8, T('NEXT MAP', 60, 'xl', name='Title'), w=520, align='center', style='z-index:6')
    out += at(w // 2 + 200, 18, row(icn('clock', 46, name='TimerIcon'), T(timer, 42, 'xl', name='TimerText'), gap=6), name='Timer', style='z-index:6')
    out += closex(w - 58, -30)
    out += bar(28, 100, w - 56, 8, frac, 'sky', 'TimeBar')
    ma = 'open' if mode == 'open' else ('win' if mode == 'result_a' else ('lose' if mode == 'result_b' else 'open'))
    mb = 'mine' if mode == 'voted' else ('win' if mode == 'result_b' else ('lose' if mode == 'result_a' else 'open'))
    out += map_tile(26, 118, a[0], a[1], 1, ma, export)
    out += map_tile(w - 26 - 445, 118, b[0], b[1], 2, mb, export)
    foot = {'open': 'Click or Press 1/2', 'voted': 'Click or Press 1/2', 'result_b': f'{MAPS_V[b[0]][0]} wins!', 'result_a': f'{MAPS_V[a[0]][0]} wins!'}[mode]
    out += at(w // 2, 436, T(foot, 25, 's', name='Footer'), w=w, align='center')
    out = box(x, y, w, h, out, name='Vote', style='overflow:visible')
    return grp('MapVote', out, 'T')


LB_W, LB_H = 210, 62


def lead_button(state='buy', x=None, y=None, gname='LeadButton'):
    """While the vote shows: the small Lead Catcher button centred 20 px under the panel (reference: "Become Lead
    Catcher"), a kit button (cb) in the Catcher red. States at one size: buy (red), buying (red, dimmed), taken (grey,
    holder's name), yours (gold). The R key-cap sits outside the right edge so it never covers the text."""
    x = (1920 - LB_W) // 2 if x is None else x
    y = MV_Y + MV_H + 20 if y is None else y
    col_ = {'buy': 'red', 'buying': 'red', 'taken': 'grey', 'yours': 'gold'}[state]
    l1, l2 = {'buy': ('Become Lead', 'Catcher'), 'buying': ('Buying...', ''), 'taken': ('Lead Catcher:', LEAD_HOLDER), 'yours': ("You're Lead", 'Catcher!')}[state]
    lab = col(T(l1, 22, 's', name='Line1'), T(l2, 22 if state != 'taken' else 19, 's', name='Line2'), gap=0) if l2 else T(l1, 26, 's', name='Line1')
    b = btn(0, 0, LB_W, LB_H, col_, lab, name='Btn', style='opacity:.62' if state == 'buying' else '')
    if state in ('buy', 'buying'):
        b += f"<div class='keycap' data-n='Key' style='left:{LB_W + 8}px;top:{(LB_H - 34) // 2}px;width:34px;height:34px;border-width:3px'>{T('R', 20, 'xs', style='font-family:Montserrat;font-weight:900', name='KeyText')}</div>"
    return grp(gname, box(x, y, LB_W, LB_H, b, name='LeadBtn_' + state), 'T')


def lead_under(state='buy', vx=None, vy=None):
    """The Lead Catcher while the vote shows: the small button (states buy / buying / taken / yours)."""
    st = {'pending': 'buying'}.get(state, state)
    x = None if vx is None else vx + (MV_W - LB_W) // 2
    y = None if vy is None else vy + MV_H + 20
    return lead_button(st, x, y)


def mv_scene(mode='open', lead='buy', timer='0:12', frac=.8, a=('SunnyCove', 3)):
    out = s_hud().replace('Next match in 0:12', 'Next match in ' + timer)   # the real lobby HUD underneath
    out += "<style>[data-g=Watch]{visibility:hidden}</style>"   # SPECTATE only shows while a match runs
    out += vote_panel(mode=mode, timer=timer, frac=frac, a=a) + lead_under(lead)
    return out


def s_mapvote_templates():
    """HOS-MAPVOTE-001 export page (ui_mapvote/rbx.json): the NEXT MAP panel as one template in
    ReplicatedStorage.MapVoteUITemplates; Controllers/MapVoteController clones it under the round header."""
    out = "<div class='abs fill' style='background:#16161a'></div>"
    out += vote_panel(40, 40, export=True).replace("data-g='MapVote'", "data-g='MapVotePanel'", 1).replace("data-a='T'", "data-a='TL'", 1)
    # the small Lead Catcher button the card turns into while the vote shows (Controllers/LeadCatcherController)
    for i, st in enumerate(['buy', 'buying', 'taken', 'yours']):
        out += lead_button(st, 60 + i * 260, 560, gname='LeadBtn' + st.capitalize()).replace("data-a='T'", "data-a='TL'", 1)
    return out


def s_mapvote():
    return mv_scene('open', 'buy')


def s_mapvote_states():
    """Four moments, each the full 1920x1080 lobby scaled to 0.5."""
    out = "<div class='abs fill' style='background:linear-gradient(#3a1a66,#1e0a3e)'></div>"
    cells = [('1  Vote open: nobody has Lead Catcher yet', mv_scene('open', 'buy')),
             ('2  You voted Frosty Pass and pressed Lead Catcher (paying)', mv_scene('voted', 'pending', '0:08', .53)),
             ('3  Someone else is Lead Catcher; a long map name fits its card', mv_scene('voted', 'taken', '0:05', .33, a=('Stadium', 6))),
             ('4  Vote over: Frosty Pass wins, you are Lead Catcher', mv_scene('result_b', 'yours', '0:00', 0))]
    for i, (lab, sc) in enumerate(cells):
        x, y = (i % 2) * 960, 40 + (i // 2) * 560
        out += cap(x + 16, y - 34, lab)
        out += f"<div class='abs' style='left:{x}px;top:{y}px;width:1920px;height:1080px;transform:scale(.5);transform-origin:0 0;overflow:hidden'>{sc}</div>"
    return out


def s_mapvote_phone():
    """Phone: the same design scaled with the screen (Fit), so it keeps the reference's proportions."""
    return s_hud_phone() + vote_panel() + lead_under('buy')


def s_mapvote_compare():
    """Size check beside existing panels: the vote panel next to the waiting offer and the Halloween starter card scale."""
    out = "<div class='abs fill' style='background:linear-gradient(#3a1a66,#1e0a3e)'></div>"
    out += cap(40, 20, 'Size check: NEXT MAP (920 x 372) + Lead Catcher card (580 x 176) beside the existing waiting offer (580 x 230)')
    out += vote_panel(40, 110).replace("data-a='T'", "data-a='TL'", 1)
    out += lead_under('buy', 40, 110).replace("data-a='T'", "data-a='TL'", 1)
    out += wait_offer(WAIT_OFFERS[0], 1060, 170, gname='WaitOffer_ref')
    out += at(1060, 470, col(T('Same plate, title and button sizes as the', 26, 's', 'f-dim'),
                             T('waiting offer and the Lead Catcher card.', 26, 's', 'f-dim'),
                             T('Vote + card = 920 x 564 together, centred', 26, 's', 'f-dim'),
                             T('under the round header; nothing else moves.', 26, 's', 'f-dim'), gap=6, align='flex-start'))
    return out


SCREENS_LEAD = [
    ('mapvote_templates.html', 'Map vote panel (export)', 'HOS-MAPVOTE-001 template for ui_mapvote/rbx.json', s_mapvote_templates, 680),
    ('mapvote.html', 'Map vote (lobby)', 'HOS-MAPVOTE-001: NEXT MAP vote + Lead Catcher card under it', s_mapvote, 1080),
    ('mapvote_states.html', 'Map vote: states', 'HOS-MAPVOTE-001: open, voted + paying, taken, result', s_mapvote_states, 1160),
    ('mapvote_phone.html', 'Map vote: phone', 'HOS-MAPVOTE-001: phone, panel 1.12x', s_mapvote_phone, 1080),
    ('mapvote_compare.html', 'Map vote: size check', 'HOS-MAPVOTE-001: beside the waiting offer', s_mapvote_compare, 1080),
    ('lead_templates.html', 'Lead Catcher cards (export)', 'HOS-LEAD-001 templates for ui_lead/rbx.json', s_lead_templates, 520),
    ('lead_catcher_states.html', 'Lead Catcher: states', 'HOS-LEAD-001: buy, pending, taken, yours + beside the waiting offer', s_lead_states, 1080),
    ('lead_catcher_lobby.html', 'Lead Catcher: in the lobby', 'HOS-LEAD-001: the buy card in the lobby wait', s_lead_lobby, 1080),
    ('lead_catcher_lobby_taken.html', 'Lead Catcher: taken (lobby)', 'HOS-LEAD-001: what everyone else sees', lambda: s_lead_lobby('taken'), 1080),
    ('lead_catcher_phone.html', 'Lead Catcher: phone', 'HOS-LEAD-001: phone HUD, card 1.25x', s_lead_phone, 1080),
]


# ================================================================== page shell
JS = """
<script>
const q = new URLSearchParams(location.search);
function fit(){ const w=document.getElementById('wrap');
  if(q.has('raw')){ w.style.transform='none'; return; }
  const H=document.getElementById('stage').offsetHeight;
  const s=Math.min(innerWidth/1920, innerHeight/H); w.style.transform='scale('+s+')';
  w.style.left=((innerWidth-1920*s)/2)+'px'; w.style.top=((innerHeight-H*s)/2)+'px'; }
addEventListener('resize', fit); fit();
const BOX='.cb,.cs,.hp,.hb,.ctag,.glass,.keycap';
window.checkOverflow = function(){
  const bad=[]; const st=document.getElementById('stage').getBoundingClientRect();
  document.querySelectorAll('.ot').forEach(e=>{
    if(e.closest('.hid')) return;
    const r=e.getBoundingClientRect(); const c=e.closest(BOX);
    if(c){ const b=c.getBoundingClientRect();
      if(r.left<b.left-3||r.right>b.right+3){bad.push(e.dataset.t); e.classList.add('overflowing');} }
    if(r.right>st.right+1||r.left<st.left-1||r.bottom>st.bottom+1){ bad.push('STAGE:'+e.dataset.t); e.classList.add('overflowing'); }
  });
  const broken=[...document.images].filter(i=>i.complete && !i.naturalWidth).map(i=>i.getAttribute('src'));
  return {overflow:bad, broken};
};
</script>"""



# ================================================================== HOS-PTS-001 match points, revive, podium, favourite emote
# Pages: points_*.html. Pops and podium cards copy the reference format (docs/references 12-14b): outlined words on the
# scene, no plate; everything else is the kit (glass, slots, tags, keycap, panel_sport). Names are pts_* / PTS_*.
PTS_NAME = 'SunnyBunny42'
PTS_LONG = 'xXDragonSlayer2014Xx'      # 20 characters: the longest Roblox display name

# ================================================================== points (PointsConfig on the runtime side)
# kind: (amount, words, amount fill, icon)
PTS_KINDS = {
    'safe': (100, 'Reached Safety!', 'f-lime', 'safe'),
    'hero': (200, 'Hero crossing!', 'f-gold', 'crown'),
    'juke': (10, 'Juke!', '', 'runner'),
    'revive': (25, 'Revive!', 'f-sky', 'plus'),
    'catch': (50, 'Catch!', 'f-red', 'catcher'),
    'snatch_rare': (25, 'Rare egg snatched!', 'f-rare', 'egg_shiny'),
    'snatch_epic': (50, 'Epic egg snatched!', 'f-epic', 'egg_cosmic'),
    'snatch_legendary': (100, 'Legendary egg snatched!', 'f-gold', 'egg_golden'),
}
# Points labelling rule (Hunter 17 Oct: "the +200 is very vague"): a points amount is never a bare number. It is
# always a pill reading "+N PTS" with the trophy icon (the star is Level/XP on the HUD), in the points teal (the kit's k-teal, used for no other value:
# Gold is yellow with the coin and the word GOLD, XP is sky blue with the word XP).
PTS_TEAL = ('#4affd8', '#16c8aa', '#0a807a')


def pts_pill(n, size=40, sign='+', name='PointsText', pill_name='PtsPill', width=None):
    """The points pill: trophy + "+100 PTS", white outlined text on a teal plate (native: gradient, dark rim, lip)."""
    t1, t2, t3 = PTS_TEAL
    txt = f'{sign}{n:,} PTS' if isinstance(n, int) else f'{sign}{n} PTS'
    h = int(size * 1.45)
    return (f"<span data-n='{pill_name}' style='position:relative;display:inline-flex;align-items:center;gap:{int(size * .18)}px;height:{h}px;"
            f"padding:0 {int(size * .45)}px 0 {int(size * .22)}px;border-radius:{h // 2}px;background:linear-gradient({t1},{t2});"
            f"box-shadow:0 0 0 3px #050506,0 {max(3, int(size * .12))}px 0 {t3};flex:none;{f'width:{width}px;box-sizing:border-box;justify-content:center' if width else ''}'>"
            f"{icn('trophy', int(size * 1.05), name='PtsIcon')}{T(txt, size, 's', name=name)}</span>")


PTS_EGG = {  # carried egg rarity -> kit icon, fill, word (the ladder: Common -> Rare -> Epic -> Legendary)
    'common': ('egg_basic', 'f-common', 'COMMON'), 'rare': ('egg_shiny', 'f-rare', 'RARE'),
    'epic': ('egg_cosmic', 'f-epic', 'EPIC'), 'legendary': ('egg_golden', 'f-gold', 'LEGENDARY'),
}
PTS_PIECE = {'common': 'piece_common', 'rare': 'piece_rare', 'epic': 'piece_epic', 'legendary': 'piece_crowned'}
PTS_RSLOT = {'common': 'common', 'rare': 'rare', 'epic': 'epic', 'legendary': 'crowned'}


# ================================================================== in-match pieces
PTS_POP_W, PTS_POP_H = 640, 112


def pts_pop(kind='safe', name='PointsPop'):
    """Beside your Runner (screen space, right of centre), left-aligned so it grows to the right: the points pill
    ("+100 PTS", the one points look) over the reason line (the kind's icon + "Reached Safety!").
    Runtime: PtsPill.PointsText, Icon, WordsText."""
    n, words, fill, icon = PTS_KINDS[kind]
    inner = at(0, 0, pts_pill(n, 40))
    inner += at(6, 64, row(icn(icon, 44, name='Icon'), T(words, 34, 'l', name='WordsText'), gap=8))
    return box(0, 0, PTS_POP_W, PTS_POP_H, inner, name=name)


def pts_juke_word(name='JukeWord'):
    """Short slam (about 0.6 s) in the upper middle, clear of the crosshair (Hunter: half size, off-centre)."""
    return box(0, 0, 360, 110, f"<div class='abs fill' style='display:flex;align-items:center;justify-content:center'>{T('JUKE!', 84, 'xl', name='WordText')}</div>", name=name)


# ================================================================== revive pieces
PTS_RING = 132   # the ring billboard's design size (px); the key cap hangs under it


def pts_revive_ring(window=.66, hold=None, key=None, name='ReviveRing'):
    """ONE compact billboard over a downed Runner (Hunter: merge the DOWN tag and the prompt; no name, no side panel).
    Hidden for everyone by default; Catchers and far players never see it. A free Runner within
    PointsConfig.Revive.SHOW_RADIUS (20 studs) sees the ring pop in (scale 0.6 -> 1 + fade, 0.2 s, ease out back;
    out: fade + shrink 0.15 s). Within PROMPT_RADIUS (6 studs) the key cap pops in under it (E, HOLD on touch, the
    button image on a controller); while they hold, the SAME ring fills green over 1.5 s. Red = the 6 s window draining.
    Ring = native at runtime (disc + UIStroke track + two clipped halves); conic here.
    Runtime: Ring (Track, Fill), Icon, Key.KeyText / Key.KeyIcon. key: None | 'E' | 'HOLD' | 'pad'."""
    r = PTS_RING
    frac, col_ = (hold, '#7be84a') if hold is not None else (window, '#ff4d55')
    ring = (f"<div class='abs' data-n='Ring' style='left:0;top:0;width:{r}px;height:{r}px;border-radius:50%;"
            f"background:conic-gradient({col_} {frac * 360:.0f}deg,rgba(255,255,255,.14) 0);box-shadow:0 0 0 4px #050506'>"
            f"<div class='abs' style='left:14px;top:14px;width:{r - 28}px;height:{r - 28}px;border-radius:50%;background:rgba(17,16,22,.92);"
            f"box-shadow:0 0 0 3px #050506'></div></div>")
    ring += I('plus' if hold is not None or key else 'clock', 30, 28, r - 60, name='Icon')
    if key:
        kw = 112 if key == 'HOLD' else 72
        capt = (I('target', 8, 6, 56, name='KeyIcon') if key == 'pad'
                else T(key, 24 if key == 'HOLD' else 38, 's', style='font-family:Montserrat;font-weight:900', name='KeyText'))
        ring += f"<div class='keycap' data-n='Key' style='left:{(r - kw) // 2}px;top:{r - 18}px;width:{kw}px;height:68px'>{capt}</div>"
    return box(0, 0, r, r + 56, ring, name=name)


# ================================================================== podium pieces
PTS_CARD_W, PTS_CARD_H = 460, 230
PTS_PLACE = {1: ('1st', 'f-gold'), 2: ('2nd', ''), 3: ('3rd', 'f-orange')}


def pts_podium_card(place=1, name=PTS_NAME, pts=388, left=False, big=False, cname='PodiumCard'):
    """Over each podium step (BillboardGui) and, big, centre screen during the push-in (reference 14, 14b):
    place, name, points; outlined text, no plate. A player who left keeps the spot, greyed: (left)."""
    p, fill = PTS_PLACE[place]
    k = 1.6 if big else 1
    nm = T(name, int(46 * k), 'l', 'f-dim' if left else '', name='NameText')
    pts_t = pts_pill(pts, int(36 * k), sign='')
    out = col(T(p, int(64 * k), 'xl', fill, name='PlaceText'), nm, pts_t, gap=0)
    if left:
        out = col(out, T('left the match', int(22 * k), 'xs', 'f-dim', name='LeftText'), gap=2)
    w, h = int(PTS_CARD_W * k), int(PTS_CARD_H * k)
    return box(0, 0, w, h, f"<div class='abs fill' style='display:flex;align-items:center;justify-content:center'>{out}</div>", name=cname)


def pts_podium_banner(kind='escaped', n=7, m=20, hid=False):
    """Top centre for the whole podium (reference 14: "CATCHERS WIN!" + "Back to the lobby soon"), sized and
    coloured like the Results title. Runtime: Title, Sub (Rays spin)."""
    if kind == 'escaped':
        title = T(f'{n} OF {m} ESCAPED!', 92, 'xl', 'f-lime', name='Title')
    elif kind == 'all':
        title = T(f'ALL {m} ESCAPED!', 92, 'xl', 'f-gold', name='Title')
    else:
        title = T('CATCHERS WIN!', 92, 'xl', 'f-red', name='Title')
    out = rays(960, 70, 760, .18)
    out += at(960, 10, title, w=1400, align='center')
    out += at(960, 124, T('Back to the lobby soon', 28, 's', 'f-dim', name='Sub'), w=900, align='center')
    return grp('PodiumBanner', out, 'T')


# ================================================================== leaderboard (end of match)
PTS_SAMPLE = [  # name, outcome, stats line, points
    ('Liam67', 'ESCAPED', '5 safe  ·  3 jukes  ·  1 revive', 618),
    (PTS_NAME, 'HERO', '4 safe  ·  Hero  ·  2 jukes', 544),
    ('mo201948', 'CATCHER', '4 catches  ·  Epic snatch', 344),
    ('Takis_4', 'CAUGHT', '3 safe  ·  1 juke', 280),
    ('Mustang', 'CATCHER', '2 catches  ·  2 safe', 240),
    ('cjcoolman098', 'CAUGHT', '2 safe  ·  1 revive', 225),
    ('Aviatrus', 'CAUGHT', '2 safe', 200),
]
PTS_OUT_TAG = {'ESCAPED': 'lime', 'HERO': 'gold', 'CATCHER': 'red', 'CAUGHT': 'grey'}
# role tag tints (Hunter 17 Oct: "catcher ... red, and hero ... gold"): the round header's Runners blue / Catchers red,
# Hero or Chicken's HERO_GOLD. Border + word tinted, the kit's dark plate and outline kept. CAUGHT stays neutral.
PTS_TAG_TINT = {'RUNNER': '#6ad8ff', 'ESCAPED': '#6ad8ff', 'CATCHER': '#ff5a5a', 'HERO': '#ffc42e', 'TOP THIEF': '#ff5a5a'}


def pts_tag(word, name, tname):
    c = PTS_TAG_TINT.get(word)
    edge = f'border-color:{c};' if c else ''
    fill = f'--fg:linear-gradient({c},{c})' if c else ''
    return (f"<span class='ctag' data-n='{name}' style='position:relative;display:inline-flex;height:32px;{edge}'>"
            f"{T(word, 18, 'xs', style=fill, name=tname)}</span>")
PTS_RANK_SLOT = {1: 'gold', 2: 'common', 3: 'orange'}
PTS_ROW_H, PTS_ROW_GAP = 70, 6
PTS_PILL_W = 236  # row pill column (design px): trophy + "+2,000 PTS" at 30 px with the pill's own padding


def pts_lb_row(y, rank, name, outcome, stats, pts, you=False, rname=None, w=960, thief=False):
    r = PTS_RANK_SLOT.get(rank, 'locked')
    inner = slot(10, 3, 64, r, None, name='RankSlot', cls='fill') + at(42, 14, T(str(rank), 30, 'l', name='RankText'), w=64, align='center')
    inner += box(86, 3, 64, 64, '', '', 'border-radius:4px;background:radial-gradient(#3a3550,#16141e);box-shadow:inset 0 0 0 2px rgba(255,255,255,.08)', name='Head')  # headshot (rbxthumb) at runtime
    inner += at(166, 2, row(T(name, 30, 's', name='NameText'), pts_tag(outcome, 'Outcome', 'OutcomeText')
                            + (pts_tag('TOP THIEF', 'Thief', None) if thief else ''), gap=12))
    inner += at(168, 42, T(stats, 18, 'xs', 'f-dim', name='StatsText'))
    inner += at(w - 20, 9, pts_pill(pts, 30, sign='', width=PTS_PILL_W), w=300, align='right')  # fixed column: "+2,000 PTS" fits
    cls = 'cs r-gold' if you else 'cs locked'
    out = box(0, y, w, PTS_ROW_H, inner, cls, 'border-radius:6px', name=rname)
    if you:
        out += selring(0, y, w, PTS_ROW_H, 'YouRing', 6)
    return out


def pts_leaderboard(rows=PTS_SAMPLE, you_at=2, pinned=None, crossings=5, escaped='2 of 7 escaped', pts=544, xp=544, thief_at=3,
                    gold_parts=(('PLAYED', 25), ('POT SHARE', 33)), gems=3, egg='epic', egg_from='rare', egg_at=3, early=False, rewards=True):
    """The ONE end-of-match screen while Points is on (it replaces the Results screen): everyone ranked by points,
    the Top thief tag on that row, and your rewards with the egg you secured in the same card."""
    # early Runners win (3 clean crossings in a row, Hunter 17 Oct): the same subtitle line says so, in Runner blue
    cr = f"{crossings} crossing{'' if crossings == 1 else 's'}"
    sub_txt = f'RUNNERS WON EARLY!  ·  {cr}  ·  {escaped}' if early else f'{cr}  ·  {escaped}'
    body = at(36, 18, T(sub_txt, 26, 's', 'f-sky' if early else 'f-dim', name='SubText'))
    lst = ''
    for i, r in enumerate(rows[:7]):
        lst += pts_lb_row(i * (PTS_ROW_H + PTS_ROW_GAP), i + 1, *r, you=(i + 1 == you_at), rname='Row' if i == 0 else None, thief=(i + 1 == thief_at))
    if pinned:
        rank, r = pinned
        y = 7 * (PTS_ROW_H + PTS_ROW_GAP)
        lst += f"<div class='abs' style='left:0;top:{y - 5}px;width:960px;height:3px;background:repeating-linear-gradient(90deg,rgba(255,255,255,.4) 0 10px,transparent 10px 20px)'></div>"
        lst += pts_lb_row(y, rank, *r, you=True, rname='YouRow')
    h = 8 * (PTS_ROW_H + PTS_ROW_GAP) + 22
    body += well(26, 66, 1000, h, f"<div class='abs' style='left:20px;top:16px;width:960px;height:100%'>{lst}</div>", name='List')
    # your rewards: points, XP (= points), Gold (PLAYED floor + share of the pot), the egg and its piece, Gems
    ic, fill, word = PTS_EGG[egg]
    # one labelled row each: POINTS (teal pill), XP (sky, the word XP), GOLD (yellow, coin + the word GOLD)
    y = at(30, 22, T('POINTS', 24, 's', 'f-dim')) + at(410, 12, pts_pill(pts, 34, sign='', name='PointsTotal'), w=300, align='right')
    y += at(30, 84, T('XP', 24, 's', 'f-dim')) + at(410, 74, T(f'+{xp} XP', 38, 'l', 'f-sky', name='XpText'), w=300, align='right')
    for i, (lab, amt) in enumerate(gold_parts):
        y += sub(f'Line{i + 1}', at(30, 136 + i * 34, T(lab, 20, 'xs', 'f-dim', name='LineLabel'))
                 + at(410, 130 + i * 34, row(T(f'+{amt} GOLD', 24, 's', 'f-gold', name='LineAmount'), icn('gold', 28), gap=4), w=240, align='right'))
    y += "<div class='abs' style='left:28px;top:208px;width:384px;height:4px;background:rgba(255,255,255,.2)'></div>"
    tot = sum(a for _, a in gold_parts)
    y += at(30, 226, T('GOLD', 24, 's', 'f-dim')) + at(410, 216, row(T(f'+{tot} GOLD', 38, 'l', 'f-gold', name='GoldTotal'), icn('gold', 44), gap=4), w=300, align='right')
    # the egg (no separate reveal screen): slot in its rarity, the piece it pays, how it got there
    y += slot(30, 290, 120, PTS_RSLOT[egg], ic, name='EggSlot', art_pad=.08)
    y += at(166, 294, T(f'{word} EGG', 34, 'l', fill, name='EggText'))
    how = f'{egg_from.title()} to {word.title()} on crossing {egg_at}' if egg_from else 'Kept it all match'
    y += at(168, 340, T(how, 18, 'xs', 'f-dim', name='EggHow'))
    y += at(166, 370, row(icn(PTS_PIECE[egg], 36, name='PieceIcon'), T(f'+1 {word.title()} piece', 24, 's', fill, name='PieceText'), gap=6))
    y += "<div class='abs' style='left:28px;top:430px;width:384px;height:4px;background:rgba(255,255,255,.2)'></div>"
    y += slot(30, 452, 120, 'lime', 'gem', f'x{gems}', 'Gems', name='GemsSlot')
    # NEXT (Hunter 17 Oct: "looks out of place"): the live Results card's button exactly (lime 186 x 68, 30 label: 54 px
    # either side of the word), right edge on the line every row aligns to (410), centred on the Gems slot
    y += btn(224, 478, 186, 68, 'lime', bl('NEXT', 30), name='Continue')
    if rewards:   # the export leaves it out (results v2 has the rewards; the board between crossings never shows them)
        body += well(1050, 66, 440, h, y, name='You')
    return panel('Leaderboard', 'gold', 'Match Points', 'trophy', body, 200, 150, 1520, 840)


# ================================================================== favourite emote star
def pts_emo_card_star(x, y, e, on=False, on_wheel=False):
    """The Emotes card with a favourite star in its top-right corner (a small kit button). One favourite:
    your podium spot plays it. Runtime: BtnFav.On / BtnFav.Off (dual)."""
    card = emo_card(x, y, e, on_wheel=on_wheel)
    star_on = btn(186, 20, 48, 48, 'gold', I('star', 4, 4, 40, name='Icon'), cls='sm' + ('' if on else ' hid'), name='On')
    star_off = btn(186, 20, 48, 48, 'grey', I('star', 4, 4, 40, name='Icon', extra='filter:brightness(.45)'), cls='sm' + (' hid' if on else ''), name='Off')
    fav = sub('BtnFav', star_on + star_off, btn=True)
    badge = at(125, 108, f"<span class='ctag k-gold' style='position:relative;display:inline-flex;height:30px'>{T('PODIUM EMOTE', 16, 'xs')}</span>",
               w=250, align='center', name='FavTag') if on else ''
    i = card.rfind('</div>')
    return card[:i] + fav + badge + card[i:]


def pts_s_emotes_fav():
    """My Emotes with the star: the existing Emotes screen, cards swapped for the starred card."""
    page = s_emotes('mine')
    mine = [e for e in EMOTES if e[0] in EMO_OWNED][:8]
    for i, e in enumerate(mine):
        old = emo_card(18 + (i % 4) * 262, 16 + (i // 4) * 288, e, on_wheel=i < 4)
        page = page.replace(old, pts_emo_card_star(18 + (i % 4) * 262, 16 + (i // 4) * 288, e, on=(i == 2), on_wheel=i < 4), 1)
    return page


# ================================================================== scenes
def pts_match_hud(crossing=2):
    """The live match HUD (build.s_hud_match) over a real match capture, crossing count out of 5."""
    h = s_hud_match().replace("src='bg_lobby.jpg'", "src='cap_match_field.jpg'")
    h = re.sub(r"<div class='cap'[^>]*>Match: only phase.*?</div>", '', h)
    i = h.find("data-t='CLEAN STREAK'")
    if i >= 0:   # drop the whole streak row (its at() wrapper)
        a = h.rfind("<div class='abs'", 0, i)
        b = h.find('</span></span></div>', i) + len('</span></span></div>')
        h = h[:a] + h[b:]
    # the capture itself shows the old CLEAN STREAK row: blur it out (no streak while FIXED_CROSSINGS is on)
    h += "<div class='abs' style='left:820px;top:132px;width:280px;height:42px;backdrop-filter:blur(16px);border-radius:12px'></div>"
    return h.replace("data-t='CROSSING 2'", f"data-t='CROSSING {crossing} / 5'").replace('>CROSSING 2<', f'>CROSSING {crossing} / 5<')


def pts_runner(cx, y=560, col_='#2d6fd1'):
    """Stand-in for your Runner under the shoulder camera (the capture has none in the middle)."""
    return (f"<div class='abs' style='left:{cx - 50}px;top:{y}px;width:100px;height:210px;border-radius:24px;background:{col_};"
            f"box-shadow:0 0 0 4px rgba(0,0,0,.35)'></div>")


def pts_pops(x, y, kinds, scale=1.0):
    out = ''
    n = len(kinds)
    for i, k in enumerate(kinds):
        a = 1 - (n - 1 - i) * .28
        out += (f"<div class='abs' style='left:{x}px;top:{y - (n - 1 - i) * (PTS_POP_H + 6) * scale}px;transform:scale({scale});"
                f"transform-origin:0 0;opacity:{a}'>{pts_pop(k)}</div>")
    return out


def pts_place(inner, x, y, scale=1.0):
    return f"<div class='abs' style='left:{x}px;top:{y}px;transform:scale({scale});transform-origin:0 0'>{inner}</div>"


def pts_podium_scene(bg='bg_lobby.jpg'):
    """Stand-in podium (studify builds the real one after approval): three stepped blocks, players on top."""
    out = world(bg, False)
    for i, (lab, h, c, x) in enumerate([('2ND', 210, '#9aa6b4', 560), ('1ST', 290, '#ffcf3a', 820), ('3RD', 160, '#e6893d', 1080)]):
        out += (f"<div class='abs' style='left:{x}px;top:{900 - h}px;width:280px;height:{h + 180}px;background:linear-gradient({c},#1d2a5c);"
                f"box-shadow:0 0 0 6px #050506;border-radius:6px'></div>")
        out += at(x + 140, 920 - h, T(lab, 54, 'xl'), w=280, align='center')
        out += f"<div class='abs' style='left:{x + 100}px;top:{900 - h - 200}px;width:80px;height:200px;border-radius:22px;background:#3b4f7a;box-shadow:0 0 0 4px rgba(0,0,0,.4)'></div>"
    for cx, cy, c in [(700, 200, '#ff5aa5'), (1000, 160, '#5ad1ff'), (1260, 240, '#ffe14a'), (860, 320, '#7cff6a'), (1150, 380, '#b06aff')]:
        out += f"<div class='abs' style='left:{cx}px;top:{cy}px;width:22px;height:12px;background:{c};transform:rotate(30deg)'></div>"
    return out


def pts_podium_cards():
    return (pts_place(pts_podium_card(2, 'mo201948', 344), 470, 262) + pts_place(pts_podium_card(1, 'Liam67', 618), 730, 178)
            + pts_place(pts_podium_card(3, 'Takis_4', 280), 990, 312))


# ================================================================== pages
def pts_s_match():
    return pts_match_hud() + pts_runner(960) + pts_place(pts_juke_word(), 780, 214) + pts_pops(1040, 640, ['safe', 'juke'])


def pts_downed(cx, y=760):
    return (f"<div class='abs' style='left:{cx - 130}px;top:{y}px;width:260px;height:72px;border-radius:30px;background:#2d6fd1;"
            f"box-shadow:0 0 0 4px rgba(0,0,0,.35);transform:rotate(-8deg)'></div>")


def pts_ring_scene(window, hold, key, x=1144, y=560, s=1.0, runner_x=860, hide=False, note=None):
    out = pts_match_hud(3) + pts_downed(1210) + pts_runner(runner_x)
    if not hide:
        out += pts_place(pts_revive_ring(window, hold, key), x, y, s)
    if note:
        out += cap(1000, 470, note)
    return out


def pts_s_revive():
    return pts_ring_scene(.5, None, 'E')


def pts_s_podium():
    return pts_podium_scene() + pts_podium_banner('escaped', 7, 20) + pts_podium_cards()


def pts_s_board():
    return world('bg_lobby_blur.jpg', False) + dim() + pts_leaderboard()


def pts_s_templates():
    out = "<div class='abs fill' style='background:linear-gradient(#3a1a66,#1e0a3e)'></div>"
    out += cap(40, 20, 'In match: points pop beside you (screen), JUKE! slam (screen, upper middle)')
    out += grp('PointsPop', pts_place(pts_pop('safe'), 40, 70), 'TL')
    out += grp('JukeWord', pts_place(pts_juke_word(), 40, 170), 'TL')
    out += cap(40, 330, 'Revive: one ring billboard (Runners within 20 studs; key cap within 6)')
    out += grp('ReviveRing', pts_place(pts_revive_ring(.45, None, 'E'), 40, 380), 'TL')
    out += cap(40, 600, 'Podium: card over each step (billboard), the same card big for the push-in')
    out += grp('PodiumCard', pts_place(pts_podium_card(1, 'Liam67', 618), 40, 650), 'TL')
    out += grp('PodiumCardBig', pts_place(pts_podium_card(2, 'mo201948', 344, big=True), 560, 600), 'TL')
    return out


def pts_s_states():
    """Every state, PC first, then phone (844 x 390 fitted by height = 2337 wide, runtime PhoneScale 1.25)."""
    PW = 2337
    pop_in = "transform:scale(.6);opacity:.45"
    shots = [
        ('PC: Reached Safety +100 (beside you, no plate)', pts_match_hud() + pts_runner(960) + pts_pops(1040, 640, ['safe'])),
        ('PC: Hero across alone +200', pts_match_hud() + pts_runner(960) + pts_pops(1040, 640, ['hero'])),
        ('PC: JUKE! (half size, upper middle, about 0.6 s) + "+10 Juke!"', pts_s_match()),
        ('PC: two jukes then a revive: stack, older fade up', pts_match_hud() + pts_runner(960) + pts_pops(1040, 640, ['juke', 'juke', 'revive'])),
        ('PC: Catcher: catch + Epic snatch on one tag', pts_match_hud() + pts_runner(960, col_='#c23b3b') + pts_pops(1040, 640, ['catch', 'snatch_epic'])),
        ('PC: Legendary snatch (longest line)', pts_match_hud() + pts_runner(960, col_='#c23b3b') + pts_pops(1040, 640, ['catch', 'snatch_legendary'])),
        ('PC: revive hidden: Catchers, and Runners further than 20 studs', pts_ring_scene(.66, None, None, hide=True, runner_x=300)),
        ('PC: a Runner within 20 studs: the ring pops in (0.6 -> 1, 0.2 s), draining red', pts_ring_scene(.66, None, None, runner_x=560)),
        ('PC: ring popping in (mid-tween frame)', pts_match_hud(3) + pts_downed(1210) + pts_runner(560)
         + f"<div class='abs' style='left:1144px;top:560px;transform-origin:66px 66px;{pop_in}'>{pts_revive_ring(.7, None, None)}</div>"),
        ('PC: within 6 studs: the E cap pops in under the ring', pts_ring_scene(.5, None, 'E')),
        ('PC: holding E: the same ring fills green (1.5 s)', pts_ring_scene(.5, .6, 'E')),
        ('PC: controller: the button image in the cap', pts_ring_scene(.4, None, 'pad')),
        ('PC: podium wide: N of M ESCAPED (banner + cards only)', pts_s_podium()),
        ('PC: podium wide: CATCHERS WIN!', pts_podium_scene() + pts_podium_banner('catchers') + pts_podium_cards()),
        ('PC: podium wide: everyone made it', pts_podium_scene() + pts_podium_banner('all', m=20) + pts_podium_cards()),
        ('PC: push-in on 2nd (big card), banner stays', pts_podium_scene() + pts_podium_banner('escaped', 7, 20) + pts_place(pts_podium_card(2, 'mo201948', 344, big=True), 592, 330)),
        ('PC: 3rd place left the match: still pose, greyed', pts_podium_scene() + pts_podium_banner('escaped', 7, 20) + pts_place(pts_podium_card(3, PTS_LONG, 280, left=True, big=True), 592, 330)),
        ('PC: results (replaces Results): you 2nd, Epic egg, Top thief tag', pts_s_board()),
        ('PC: results: early Runners win (3 clean crossings in a row)', world('bg_lobby_blur.jpg', False) + dim()
         + pts_leaderboard(crossings=3, escaped='20 of 22 escaped', early=True, gold_parts=(('PLAYED', 25), ('POT SHARE', 51)), egg='rare', egg_from='common', egg_at=1)),
        ('PC: results: you 14th pinned under the top 7, Rare egg', world('bg_lobby_blur.jpg', False) + dim()
         + pts_leaderboard(you_at=0, pinned=(14, (PTS_NAME, 'CAUGHT', '1 safe  ·  1 juke', 110)), pts=110, xp=110, gold_parts=(('PLAYED', 25), ('POT SHARE', 6)), gems=1, egg='rare', egg_from='common', egg_at=1)),
        ('PC: results: CATCHERS WIN, longest name, Legendary egg', world('bg_lobby_blur.jpg', False) + dim()
         + pts_leaderboard(rows=[(PTS_LONG, 'CATCHER', '6 catches  ·  Legendary snatch', 760)] + [(n, 'CATCHER' if o == 'CATCHER' else 'CAUGHT', st, p) for n, o, st, p in PTS_SAMPLE[1:]],
                           escaped='nobody escaped', you_at=2, thief_at=1, pts=544, egg='legendary', egg_from='epic', egg_at=5)),
        ('PC: My Emotes: one emote starred (PODIUM EMOTE)', pts_s_emotes_fav()),
    ]
    phone = [
        ('Phone: Reached Safety', pts_match_hud() + pts_runner(960) + pts_pops(1040, 620, ['safe'], 1.25)),
        ('Phone: JUKE!', pts_match_hud() + pts_runner(960) + pts_place(pts_juke_word(), 735, 200, 1.25) + pts_pops(1040, 640, ['juke'], 1.25)),
        ('Phone: revive: tap and hold (HOLD cap), ring filling', pts_ring_scene(.5, .35, 'HOLD', 1120, 540, 1.25)),
        ('Phone: results', world('bg_lobby_blur.jpg', False) + dim() + pts_leaderboard()),
    ]
    out = "<div class='abs' style='left:0;top:0;transform:scale(.5);transform-origin:0 0;display:flex;flex-wrap:wrap;gap:24px;width:3888px'>"
    for cap_, body in shots:
        out += (f"<div style='position:relative;width:1920px;height:1080px;overflow:hidden;border:2px solid #000;background:#000'>{body}"
                f"<div class='cap' style='left:12px;bottom:12px;font-size:30px;z-index:90'>{cap_}</div></div>")
    for cap_, body in phone:
        out += (f"<div style='position:relative;width:{PW}px;height:1080px;overflow:hidden;border:2px solid #000;background:#000'>"
                f"<div class='abs' style='left:{(PW - 1920) // 2}px;top:0;width:1920px;height:1080px'>{body}</div>"
                f"<div class='rbx' style='left:90px;top:640px;width:300px;height:300px'>thumbstick</div>"
                f"<div class='rbx' style='left:{PW - 330}px;top:720px;width:200px;height:200px'>jump</div>"
                f"<div class='cap' style='left:12px;bottom:12px;font-size:30px;z-index:90'>{cap_}</div></div>")
    return out + '</div>'


def pts_hero_after():
    """MOCKUP ONLY (the Hero or Chicken thread owns the HERO! banner): their d2 success beat with the chip replaced by
    the points pill, so the +200 reads as points."""
    page = world(HC_BG) + hc_bars() + hc_g_success(False)
    i = page.find("data-n='PointsChip'")
    a = page.rfind("<div", 0, i)
    depth, j = 0, a
    while True:   # the chip's whole box: walk to its matching </div>
        o, c = page.find('<div', j + 1), page.find('</div>', j + 1)
        if o != -1 and o < c:
            depth += 1
            j = o
        else:
            if depth == 0:
                end = c + len('</div>')
                break
            depth -= 1
            j = c
    pill = at(960 - 200, HC_LB + 240, f"<div style='display:flex;justify-content:center;width:400px'>{pts_pill(200, 44)}</div>")
    return page[:a] + pill + page[end:]


def pts_s_labels_phone():
    """Phone (844 x 390, PhoneScale 1.25): the pops and the results card with the labelling rule."""
    PW = 2337
    out = f"<div class='abs' style='left:0;top:0;width:{PW}px;height:1080px;overflow:hidden;background:#000'>"
    out += f"<div class='abs' style='left:{(PW - 1920) // 2}px;top:0;width:1920px;height:1080px'>"
    out += pts_match_hud() + pts_runner(960) + pts_pops(1040, 600, ['juke', 'safe'], 1.25) + '</div>'
    out += f"<div class='rbx' style='left:90px;top:640px;width:300px;height:300px'>thumbstick</div>"
    out += f"<div class='rbx' style='left:{PW - 330}px;top:720px;width:200px;height:200px'>jump</div>"
    return out + '</div>'


# ================================================================== results v2 (MOCKUP ONLY, 17 Oct: the reference game's layout)
# Hunter's reference: a top-3 headshot podium with tabs that cycle (POINTS / SURVIVED / CATCHES), you under it, then
# the rewards. Review only: not exported, not built into Studio until Hunter approves the look.
# Headshots: rbxthumb://type=AvatarHeadShot at runtime; placeholders here are Roblox thumbnails in art/heads/.
RV_HEADS = ['art/heads/head_1.png', 'art/heads/head_156.png', 'art/heads/head_261.png', 'art/heads/head_2.png', 'art/heads/head_16.png']
RV_TABS = [('points', 'POINTS', 'trophy'), ('survived', 'SURVIVED', 'safe'), ('catches', 'CATCHES', 'catcher')]
RV_TOP = {  # tab -> top 3 (#1, #2, #3): name, role word, stat, head, joint
    'points': [('Liam67', 'RUNNER', 618, 0, False), (PTS_NAME, 'HERO', 544, 1, False), ('mo201948', 'CATCHER', 344, 2, False)],
    'survived': [('Liam67', 'RUNNER', 5, 0, False), ('Takis_4', 'RUNNER', 5, 3, False), ('Aviatrus', 'RUNNER', 4, 4, False)],
    'catches': [('mo201948', 'CATCHER', 4, 2, False), ('Mustang', 'CATCHER', 3, 3, False), (PTS_LONG, 'CATCHER', 2, 4, True)],
}
RV_PLACE = {1: ('gold', 'f-gold'), 2: ('silver', ''), 3: ('orange', 'f-orange')}
RV_SILVER = '--r1:#f4f6fa;--r2:#b4bfcf;--r3:#3e4656;'   # no silver rarity in the kit: #2's frame takes these three vars
RV_W, RV_H = 1440, 916     # panel (design px); 1920 x 1080 stage, centred
RV_STAGE = 50   # emote podium (Hunter OK 17 Oct): each card is 50 px taller, a live full-body view above the name
RV_CARD = {True: (360, 150, 334 + RV_STAGE), False: (320, 120, 290 + RV_STAGE)}   # big?: width, headshot, height
RV_EXPORT = [False]        # ui_points/pages.py sets it: every runtime state on the page, headshot slots as plain frames
RV_REW_W, RV_EGG_W = 540, 500   # rewards box / egg block (Hunter 17 Oct: POINTS dropped from the rewards, the YOU strip has it)
RV_SHARD_W = 250           # the egg block's shard line box: EggUIController writes it ("+1 RARE SHARD", "+10 FILL · LEGENDARY")


def rv_fit(name, size, w):
    """Mirror the runtime's TextScaled cap: shrink a name until it fits w (Fredoka 600 is about .56 em per char)."""
    return max(18, min(size, int(w / (len(name) * .56))))


def rv_stat(tab, v, size):
    if tab == 'points':
        return pts_pill(v, size, sign='+', name='StatText', pill_name='StatPill')
    word = 'crossing' if tab == 'survived' else 'catch'
    plural = '' if v == 1 else ('s' if tab == 'survived' else 'es')
    fill = 'f-sky' if tab == 'survived' else 'f-red'
    nm = 'SafeText' if tab == 'survived' else 'CatchText'
    return row(icn('safe' if tab == 'survived' else 'catcher', int(size * 1.1)), T(f'{v} {word}{plural}', size, 'l', fill, name=nm), gap=6)


def rv_head(x, y, s, head, name='Head'):
    """The headshot slot. Export: a plain frame (the runtime puts rbxthumb://AvatarHeadShot in a child 'Shot')."""
    ring = 'box-shadow:0 0 0 3px #050506,0 0 0 6px var(--r2)'
    if RV_EXPORT[0]:
        return box(x, y, s, s, '', '', f'border-radius:4px;background:radial-gradient(#4a4560,#16141e);{ring}', name=name)
    return (f"<img data-n='{name}' src='{RV_HEADS[head]}' style='position:absolute;left:{x}px;top:{y}px;width:{s}px;height:{s}px;"
            f"border-radius:4px;background:radial-gradient(#4a4560,#16141e);{ring}'>")


RV_VIEW = [False]          # step 2 (mock only): a ViewportFrame of each top-3 player doing their favourite emote
RV_AVATARS = ['art/avatars/av_1_waist.png', 'art/avatars/av_156_waist.png', 'art/avatars/av_261_waist.png', 'art/avatars/av_2_waist.png', 'art/avatars/av_16_waist.png']
RV_EMOTES = ['Shuffle', 'K-Pop Dance', 'Idle Dance']


def rv_view(x, y, w, h, head, emote):
    """The character viewport: the card's colour as a soft stage light behind the player (waist up, Roblox avatar render as a
    stand-in for the live ViewportFrame), the emote's name in a small chip. Falls back to the headshot slot at runtime."""
    stage = (f"background:radial-gradient(ellipse at 50% 30%,color-mix(in srgb,var(--r1) 55%,transparent) 0,"
             f"color-mix(in srgb,var(--r2) 35%,#16141e) 55%,#121018 100%)")
    img = (f"<img src='{RV_AVATARS[head]}' style='position:absolute;left:50%;bottom:0;height:{h + 8}px;transform:translateX(-50%)'>")
    chip = (f"<div class='abs' style='left:8px;bottom:8px;display:flex;align-items:center;gap:6px;height:30px;padding:0 10px 0 6px;"
            f"border-radius:15px;background:rgba(10,10,14,.72);box-shadow:0 0 0 2px #050506'>{icn('emote', 24)}{T(emote, 16, 'xs')}</div>")
    return (f"<div class='abs' data-n='View' style='left:{x}px;top:{y}px;width:{w}px;height:{h}px;border-radius:4px;overflow:hidden;{stage};"
            f"box-shadow:0 0 0 3px #050506,0 0 0 6px var(--r2)'>{img}{chip}</div>")


def rv_card(x, y, place, tab, who, big=False):
    """One podium card: rank, headshot, name, role tag, the tab's stat. #1 is bigger with the gold frame and crown.
    Runtime: Place<n>.Head, RankText, JointText, NameText, Role.RoleText, StatPts (StatPill.StatText) / StatSafe.SafeText /
    StatCatch.CatchText (one shown per tab)."""
    name, role, v, head, joint = who
    w, hs, h = RV_CARD[big]
    r, fill = RV_PLACE[place]
    ex = RV_EXPORT[0]
    if RV_VIEW[0]:   # step 2 mock: the player's character doing their favourite emote, framed waist up
        vw, vh = (236, 176) if big else (196, 140)
        inner = rv_view((w - vw) // 2, 14, vw, vh, head, RV_EMOTES[(place - 1) % 3])
        hs = vh - 6
    else:
        inner = rv_head((w - hs) // 2, 20 + RV_STAGE // 2, hs, head)   # the fallback headshot, centred in the stage
    # a tie: JOINT over the number, same corner (exported always; the runtime shows it and drops the number 22 px)
    if joint or ex:
        inner += at(12, 6, T('JOINT', 22, 's', fill, name='JointText'))
    inner += at(12, 28 if joint else 8, T(f'#{place}', 40 if joint else (44 if big else 40), 'xl', fill, name='RankText'))
    ny = hs + (24 if RV_VIEW[0] else 30) + RV_STAGE
    inner += at(w // 2, ny, T(name, rv_fit(name, 34 if big else 30, w - 28), 's', name='NameText'), w=w - 20, align='center')
    inner += at(w // 2, ny + 46, f"<span style='display:inline-flex'>{pts_tag(role, 'Role', 'RoleText')}</span>", w=w, align='center')
    sz = 32 if big else 28
    for t, nm in (('points', 'StatPts'), ('survived', 'StatSafe'), ('catches', 'StatCatch')):
        if t == tab or ex:
            vv = v if t == tab else {'points': 618, 'survived': 5, 'catches': 4}[t]
            inner += sub(nm, at(w // 2, ny + 88, f"<span style='display:inline-flex'>{rv_stat(t, vv, sz)}</span>", w=w, align='center'), hid=(t != tab))
    if RV_EXPORT[0]:
        pill = (f"<span style='display:inline-flex;align-items:center;height:28px;padding:0 12px;border-radius:14px;"
                f"background:rgba(10,10,14,.72);box-shadow:0 0 0 2px #050506'>{T('K-Pop Dance', 16, 'xs', name='EmoteText')}</span>")
        inner += at(w - 14, 10, pill, w=240, align='right', name='EmoteChip').replace("class='abs'", "class='abs hid'", 1)
    cls = 'cs lab' if r == 'silver' else f'cs r-{r} lab'
    out = box(x, y, w, h, inner, cls, (RV_SILVER if r == 'silver' else '') + 'overflow:visible', name=f'Place{place}')
    if big:
        out += I('crown', x + w // 2 - 38, y - 56, 76, name='Crown')
    return out, h


def rv_body(tab='points', winner='runners', early=False, you=(19, 200, 'RUNNER'), xp=(12, 1240, 2000), gold=58, gems=2):
    W = RV_W
    out = ''
    # tabs (auto-cycle every 4 s; tap to pick): the cycle bar under the row shows the time to the next tab
    tw, gap = 236, 14
    x0 = (W - 3 * tw - 2 * gap) // 2
    for i, (key, lab, ic) in enumerate(RV_TABS):
        lbl = row(icn(ic, 40), bl(lab, 28), gap=8)
        out += dual(x0 + i * (tw + gap), -24, tw, 56, 'sky', lbl, f'Tab{lab.title()}', key == tab)
    cyc = {'points': .35, 'survived': .7, 'catches': .55}[tab]
    out += bar(x0, 42, 3 * tw + 2 * gap, 8, cyc, 'sky', name='CycleBar')
    # podium: #2 left, #1 centre (raised by the size difference), #3 right; bottoms on one line
    top = RV_TOP[tab]
    w1, _, h1 = RV_CARD[True]
    w2, _, h2 = RV_CARD[False]
    base = 132 - RV_STAGE + h1   # the cards grow upward; the bottom line stays
    c1, _ = rv_card(W // 2 - w1 // 2, base - h1, 1, tab, top[0], big=True)
    c2, _ = rv_card(W // 2 - w1 // 2 - 40 - w2, base - h2, 2, tab, top[1])
    c3, _ = rv_card(W // 2 + w1 // 2 + 40, base - h2, 3, tab, top[2])
    out += sub('Podium', c1 + c2 + c3)
    # you, one strip under the podium, as wide as the podium
    yr, ypts, yrole = you
    sw = w1 + 2 * (40 + w2)
    strip = rv_head(8, 6, 48, 1, name='YouHead').replace('0 0 0 6px var(--r2)', '0 0 0 2px #050506')
    strip += at(70, 8, row(T('YOU', 30, 'l', 'f-gold', name='YouLabel'), T(f'#{yr}', 34, 'l', name='YouRank'), pts_tag(yrole, 'YouRole', 'YouRoleText'), gap=14))
    strip += at(sw - 14, 3, pts_pill(ypts, 34, name='YouPts'), w=300, align='right')
    out += box((W - sw) // 2, base + 14, sw, 60, strip, 'cs r-gold lab', name='You')
    # bottom row: rewards (XP / GOLD / GEMS + level bar) | the egg block (EggUIController's content and size) | NEXT
    by, bh = base + 14 + 60 + 44, 140
    lv, cur, need = xp
    rw = RV_REW_W
    rew = ''
    cols = [('ColXp', 'XP', T(f'+{ypts} XP', 30, 'l', 'f-sky', name='XpText')),
            ('ColGold', 'GOLD', row(T(f'+{gold} GOLD', 28, 'l', 'f-gold', name='GoldTotal'), icn('gold', 32), gap=4)),
            ('ColGems', 'GEMS', row(T(f'+{gems} GEMS', 28, 'l', 'f-lime', name='GemsText'), icn('gem', 32), gap=4))]
    for i, (nm, lab, piece) in enumerate(cols):
        cx_ = rw * (2 * i + 1) // 6
        rew += sub(nm, at(cx_, 8, T(lab, 22, 'xs', 'f-dim'), w=180, align='center')
                   + at(cx_, 36, f"<span style='display:inline-flex'>{piece}</span>", w=240, align='center'), hid=(nm == 'ColGems' and not gems))
    rew += at(18, 92, row(icn('star', 34), T(f'LEVEL {lv}', 24, 's', name='LevelText'), gap=6))
    rew += bar(170, 96, 150, 26, (cur + ypts) / need, 'sky', name='XpBar')
    rew += at(rw - 18, 95, T(f'{cur + ypts:,} / {need:,} XP', 22, 'xs', 'f-dim', name='XpLine'), w=200, align='right')
    out += well(36, by, rw, bh, rew, name='Rewards', title='YOUR REWARDS')
    # egg block: what EggUIController fills (EggSlot 120, EggText, EggHow, PieceIcon + PieceText); the shard line is a fixed
    # RV_SHARD_W box so their longer label fits; their mini fill ring (EggMini) sits at the block's right edge
    ew = RV_EGG_W
    egg = slot(12, 10, 120, 'rare', 'egg_shiny', name='EggSlot', art_pad=.08)
    egg += at(148, 12, T('RARE EGG', 34, 'l', 'f-rare', name='EggText'))
    egg += at(150, 56, T('Safe to the end', 20, 'xs', 'f-dim', name='EggHow'))
    egg += at(148, 86, row(icn('piece_rare', 36, name='PieceIcon'),
                            T('+1 RARE SHARD', 24, 's', 'f-rare', name='PieceText', style=f'display:inline-block;width:{RV_SHARD_W}px'), gap=6))
    if not RV_EXPORT[0]:
        egg += egg_ring(ew - 40, 104, 18, 21 / 30, '#7cf05a', 7, 'MiniRing') + I('egg_starter', ew - 51, 90, 22, 27, name='MiniEgg')
        egg += at(ew - 52, 50, T('21 / 30 FILL', 14, 'xs', 'f-dim', name='MiniFill'), w=110, align='center')
    out += well(36 + rw + 24, by, ew, bh, egg, name='EggBlock', title='EGG')
    nx = 36 + rw + 24 + ew + 24
    out += btn(nx, by + (bh - 92) // 2, W - 36 - nx, 92, 'lime', bl('NEXT', 44), name='Continue')
    return out


def rv_panel(tab='points', winner='runners', early=False, secs=9, crossings=5, escaped='20 of 22 escaped', **kw):
    if early:
        title, acc = 'RUNNERS WON EARLY!', 'sky'
    elif winner == 'runners':
        title, acc = 'RUNNERS WIN', 'sky'
    else:
        title, acc = 'CATCHERS WIN', 'coral'
    cr = f"{crossings} crossing{'' if crossings == 1 else 's'}"
    subline = at(36, -12, T(f'{cr}  ·  {escaped}', 26, 's', 'f-dim', name='SubText'))
    chip = row(icn('clock', 40), T(f'Next match  ·  {secs}s', 26, 's', name='NextText'), gap=8)
    body = subline + f"<div class='abs' style='left:0;top:46px;width:{RV_W}px;height:{RV_H - 112 - 46}px'>{rv_body(tab, winner, early, **kw)}</div>"
    x, y = (1920 - RV_W) // 2, (1080 - RV_H) // 2 + 30
    return panel('ResultsV2', acc, title, None, body, x, y, RV_W, RV_H, right=chip, title_size=60 if not early else 50)


def rv_screen(**kw):
    return world('bg_lobby_blur.jpg', False) + dim() + rv_panel(**kw)


def rv_phone(scale=1.1, **kw):
    """844 x 390 (2.16:1) = 2337 x 1080 design px (open with ?raw). Results own the whole screen (no thumbstick), so the
    panel is scaled 1.1 (the most that fits: banner top to panel bottom is 966 px -> 1063) instead of PhoneScale 1.25."""
    PW = 2337
    out = f"<style>#stage{{width:{PW}px!important}}</style>"
    out += f"<div class='abs' style='left:0;top:0;width:{PW}px;height:1080px;overflow:hidden;background:#000'>"
    out += f"<img class='world' src='bg_lobby_blur.jpg' style='position:absolute;left:0;top:0;width:{PW}px;height:1080px;object-fit:cover'>"
    out += "<div class='abs fill' style='background:rgba(26,6,48,.42)'></div>"
    py = (1080 - RV_H) // 2 + 30 - 50          # banner top in the 1920 design
    top = (1080 - 966 * scale) / 2 - py * scale
    out += (f"<div class='abs' style='left:{(PW - 1920 * scale) / 2:.0f}px;top:{top:.0f}px;width:1920px;height:1080px;"
            f"transform:scale({scale});transform-origin:0 0'>{rv_panel(**kw)}</div>")
    return out + '</div>'


def rv_emote_screen(**kw):
    RV_VIEW[0] = True
    try:
        return rv_screen(**kw)
    finally:
        RV_VIEW[0] = False


RV_SCREENS = [
    ('results_v2_emote.html', 'Results v2: emote podium (mock)', 'Step 2 MOCK: characters doing their favourite emote', lambda: rv_emote_screen(tab='points'), 1080),
    ('results_v2_emote_catches.html', 'Results v2: emote podium, CATCHES (mock)', 'Step 2 MOCK', lambda: rv_emote_screen(tab='catches'), 1080),
    ('results_v2_points.html', 'Results v2: POINTS tab', 'MOCKUP: headshot podium, tabs, you, rewards, egg, NEXT', lambda: rv_screen(tab='points'), 1080),
    ('results_v2_survived.html', 'Results v2: SURVIVED tab', 'MOCKUP: most crossings', lambda: rv_screen(tab='survived'), 1080),
    ('results_v2_catches.html', 'Results v2: CATCHES tab', 'MOCKUP: most catches, Joint #3', lambda: rv_screen(tab='catches'), 1080),
    ('results_v2_catchers.html', 'Results v2: Catchers win', 'MOCKUP: CATCHERS WIN', lambda: rv_screen(tab='points', winner='catchers', escaped='6 of 22 escaped', you=(19, 200, 'CATCHER')), 1080),
    ('results_v2_early.html', 'Results v2: early win', 'MOCKUP: RUNNERS WON EARLY!', lambda: rv_screen(tab='points', early=True, crossings=3), 1080),
    ('results_v2_phone.html', 'Results v2: phone 844x390', 'MOCKUP: phone', lambda: rv_phone(tab='points'), 1080),
]


PTS_SCREENS = [
    ('points_match.html', 'Points: in match', '+100 Reached Safety! and +10 Juke! beside you, a short JUKE! up top, over the live match HUD', pts_s_match, 1080),
    ('points_revive.html', 'Points: revive', 'One ring billboard for Runners nearby: the 6 s window draining, E within 6 studs, the hold filling the same ring', pts_s_revive, 1080),
    ('points_podium.html', 'Points: podium', 'Banner and the top-3 cards (name and points)', pts_s_podium, 1080),
    ('points_board.html', 'Points: results', 'The one results screen: leaderboard + your rewards with the egg', pts_s_board, 1080),
    ('points_emotes.html', 'Points: favourite emote', 'The star on My Emotes', pts_s_emotes_fav, 1080),
    ('points_templates.html', 'Points: templates', 'Runtime templates as exported', pts_s_templates, 1080),
    ('points_states.html', 'Points: every state', 'PC and phone, every state', pts_s_states, 7300),
    ('points_hero_after.html', 'Points: HERO! banner (mockup)', 'The Hero or Chicken banner with the points pill (mockup only)', pts_hero_after, 1080),
    ('points_labels_phone.html', 'Points: labels on phone', 'Pops with the points pill at phone scale', pts_s_labels_phone, 1080),
]



def page(title, body, h=1080):
    return (f"<!doctype html><html><head><meta charset='utf-8'><title>{title}</title>"
            f"<meta name='viewport' content='width=device-width,initial-scale=1'>{FONTS}"
            f"<link rel='stylesheet' href='kit.css'><link id='preset' rel='stylesheet' href='styles/{STYLE}.css'>"
            + (f"<link rel='stylesheet' href='styles/{SKIN}.css'>" if SKIN else '')
            + "</head><body>"
            f"<div id='wrap'><div id='stage' style='height:{h}px'>{body}</div></div>{JS}</body></html>")


# ================================================================== Hero or Chicken (HOS-HOC-001)
# The overlay for the Hero or Chicken pick at the start of every crossing, drawn ONLY with this file's
# components (T, at, grp, sub, box, world, topbar) and the sport skin. Two lines per beat at most:
#   a small label (22 'xs', the timer folded in as "· 0:08") + a big title (50 'l'), the round header's
#   own treatment (hv_topcenter), no backing panel.
# When the HUD is back (ready, Hero run, group-ready) the overlay does not add a second block: HCHeader
# sits exactly where the round header is (y 6 / 30 / 98) and the runtime hides EOSUI's Status while it shows.
# Pick buttons + the +200 chip = the best-egg card (.glass) with an accent inner ring (gold HERO, Runner-blue
# CHICKEN). Every group is symmetric about x = 960 so it centres at any aspect ratio.
# Build with PYTHONUTF8=1 so the "·" separator reaches the page as UTF-8 (it is the round header's separator).
# Exported with its own config: ui_hc/rbx.json -> roblox/ui_hc (gui HeroChickenUI).
HC_LB = 119                          # Cinematic letterbox bar at 1080 (11%), same as UI/last-standing
HC_NAME = 'SunnyBunny42'
HC_DOT = '  ·  '                # the round header's separator ("Runner · 0:21")
HC_BG = 'hc_bg_clean.jpg'            # cap_match_field.jpg with its HUD painted out (cinematic beats hide the HUD)
HC_BG_HUD = 'cap_match_field.jpg'    # the real match capture WITH the existing HUD (round header, egg card, dash)
HC_GOLD_RING = 'rgba(255,210,58,.85)'
HC_BLUE_RING = 'rgba(92,200,255,.85)'    # the "Runner" blue of the round header's subline (f-rare)


def hc_mid(y, inner, w=1600, name=None):
    """Centred on x = 960 (the round header's at(960, ..., align='center'))."""
    return at(960, y, inner, w=w, align='center', name=name)


def hc_pair(y, label, title, names, label_fill='', title_fill='', title_size=50):
    """The two lines: small label (timer folded in) over the big title."""
    return (hc_mid(y, T(label, 22, 'xs', label_fill, name=names[0]), w=900)
            + hc_mid(y + 26, T(title, title_size, 'l', title_fill, name=names[1]), w=1500))


def hc_g_letterbox(hid=True):
    bars = box(0, 0, 1920, HC_LB, '', '', 'background:#000', name='BarTop') + box(0, 1080 - HC_LB, 1920, HC_LB, '', '', 'background:#000', name='BarBottom')
    return grp('Letterbox', sub('LetterboxBox', bars, hid=hid), 'FILL')


def hc_g_title(hid=True, label=f'CROSSING 2{HC_DOT}0:06', title='THE CATCHER IS CHOOSING...'):
    """Every cinematic beat a / b title: label + title just under the top letterbox bar."""
    return grp('Title', sub('TitleBox', hc_pair(HC_LB + 10, label, title, ('TitleLabel', 'TitleText')), hid=hid), 'T')


def hc_g_choice(hid=True, hover=None):
    """Picked Runner only: two best-egg cards near the bottom safe edge (600..930 and 990..1320)."""
    y = 1080 - HC_LB - 132
    def pick(nm, x, ring, label, word, fill, hov):
        lift = 'transform:translateY(-4px) scale(1.04);' if hov else ''
        inner = at(165, 14, T(label, 16, 'xs', 'f-dim', name='Label'), w=310, align='center')
        inner += at(165, 38, T(word, 50, 'l', fill, name='Word'), w=310, align='center')
        card = box(x, y, 330, 112, inner, 'glass', f'box-shadow:inset 0 0 0 2px {ring},0 4px 0 rgba(0,0,0,.4);{lift}', name=nm + 'Card')
        return sub(nm, card, btn=True)
    out = pick('HeroButton', 600, HC_GOLD_RING, f'CROSS ALONE{HC_DOT}2x POINTS', 'HERO', 'f-gold', hover == 'hero')
    out += pick('ChickenButton', 990, HC_BLUE_RING, 'STAY WITH THE GROUP', 'CHICKEN', '', hover == 'chicken')
    return grp('Choice', sub('ChoiceBox', out, hid=hid), 'B')


def hc_g_reveal(which=None):
    hero = hc_mid(318, T('HERO!', 150, 'xl', 'f-gold', name='Word'), w=1200) + hc_mid(520, T(f'{HC_NAME} is crossing alone', 34, 'l', name='Sub'), w=1500)
    chick = hc_mid(318, T('CHICKEN!', 150, 'xl', name='Word'), w=1500) + hc_mid(520, T(f'{HC_NAME} runs with the group', 34, 'l', name='Sub'), w=1500)
    return grp('Reveal', sub('RevealHero', hero, hid=which != 'hero') + sub('RevealChicken', chick, hid=which != 'chicken'), 'C')


def hc_g_header(hid=True, phase='CROSSING 2', head=f'{HC_NAME} is going HERO', subline=f'get ready{HC_DOT}3', phase_fill='', head_fill=''):
    """HUD back (ready / Hero run / group-ready): the round header's own three lines in its own spot
    (hv_topcenter: 22 / 50 / 22 at y 6 / 30 / 98). The runtime hides EOSUI's Status while this shows."""
    # each accent is its own label (the runtime shows one): white / gold / red phase, white / gold headline
    out = ''
    for nm, fill in (('HPhase', ''), ('HPhaseGold', 'f-gold'), ('HPhaseRed', 'f-red')):
        show_it = (fill == phase_fill) if hid is False else nm == 'HPhase'
        out += hc_mid(6, T(phase, 22, 'xs', fill, name=nm, style='' if show_it else 'opacity:0'), w=900)
    for nm, fill in (('HHeadline', ''), ('HHeadlineGold', 'f-gold')):
        show_it = (fill == head_fill) if hid is False else nm == 'HHeadline'
        out += hc_mid(30, T(head, 50, 'l', fill, name=nm, style='' if show_it else 'opacity:0'), w=1500)
    out += hc_mid(98, T(subline, 22, 'xs', name='HSubline'), w=900)
    return grp('HCHeader', sub('HCHeaderBox', out, hid=hid), 'T')


def hc_g_success(hid=True):
    """The Hero made it: HERO!, one line, the +200 chip right under it (even 24 px gaps)."""
    inner = hc_mid(HC_LB + 16, T('HERO!', 130, 'xl', 'f-gold', name='Word'), w=1200)
    inner += hc_mid(HC_LB + 172, T(f'{HC_NAME} made it alone', 36, 'l', name='Sub'), w=1500)
    # always with its unit (Hunter 17 Oct: a bare "+200" reads as Gold or XP; project rule: "+N PTS"); the runtime writes HERO_POINTS
    # the project's points pill (HOS-PTS-001 pts_pill: teal plate + trophy, "+N PTS"), right under the line
    inner += hc_mid(HC_LB + 236, f"<span data-n='PointsChip' style='display:inline-flex'>{pts_pill(200, size=40)}</span>", w=600)
    return grp('Success', sub('SuccessBox', inner, hid=hid), 'T')


def hc_g_dip():
    """A 0.2 s dip through black between beats (comfort: cuts, never white / gold full-screen flashes)."""
    return grp('Dip', box(0, 0, 1920, 1080, '', '', 'background:#000', name='DipFill', hid=True), 'FILL')


def hc_s_screen():
    return (world(HC_BG) + hc_g_letterbox() + hc_g_title() + hc_g_choice() + hc_g_reveal() + hc_g_header()
            + hc_g_success() + hc_g_dip())


def hc_s_templates():
    # the HERO line that sits ABOVE the name inside the game's own overhead tag (EOS_Tag), styled like its
    # gold "VIP" (Montserrat ExtraBold, #FFD23A, dark outline); the runtime fits it to the tag's top row
    tag = grp('HeroTag', box(0, 0, 160, 34, at(80, 2, T('HERO', 24, 's', 'f-gold', name='TagText', style='font-family:Montserrat;font-weight:800'), w=160, align='center'), name='Tag'), 'TL')
    # (17 Oct: the separate "+200 HERO PTS" pop is retired: the HERO! banner's pts_pill chip carries the points)
    return world(HC_BG) + tag


# ---------------------------------------------------------------- review pages: each beat in context
def hc_bars():
    return (f"<div class='abs' style='left:0;top:0;width:1920px;height:{HC_LB}px;background:#000'></div>"
            f"<div class='abs' style='left:0;bottom:0;width:1920px;height:{HC_LB}px;background:#000'></div>")


def hc_hud_cover():
    """The capture has the round header baked in; while HCHeader shows, EOSUI's Status is hidden: cover it."""
    return "<img src='hc_bg_clean.jpg' style='position:absolute;left:0;top:0;width:1920px;height:1080px;object-fit:cover;clip-path:inset(0 590px 898px 590px)'>"


HC_BEATS = [  # (file, caption, body)
    ('hc_a1_lead.html', 'a1 Lead Catcher intro', lambda: world(HC_BG) + hc_bars() + hc_g_title(False, f'LEAD CATCHER{HC_DOT}0:08', 'xSiege')),
    ('hc_a2_choosing.html', 'a2 choosing (everyone)', lambda: world(HC_BG) + hc_bars() + hc_g_title(False)),
    ('hc_a3_pick.html', 'a3 choosing (the lead Catcher)', lambda: world(HC_BG) + hc_bars() + hc_g_title(False, f'CLICK A RUNNER{HC_DOT}0:05', 'PICK A RUNNER')),
    ('hc_b1_picked.html', 'b1 picked (everyone else)', lambda: world(HC_BG) + hc_bars() + hc_g_title(False, f'HERO OR CHICKEN?{HC_DOT}0:05', HC_NAME)),
    ('hc_b2_choose.html', 'b2 picked (the picked Runner)', lambda: world(HC_BG) + hc_bars() + hc_g_title(False, f'HERO OR CHICKEN?{HC_DOT}0:05', 'YOU WERE PICKED') + hc_g_choice(False, 'hero')),
    ('hc_c1_hero.html', 'c1 HERO reveal', lambda: world(HC_BG) + hc_bars() + hc_g_reveal('hero')),
    ('hc_c2_chicken.html', 'c2 CHICKEN reveal', lambda: world(HC_BG) + "<div class='abs fill' style='background:rgba(40,40,48,.45)'></div>" + hc_bars() + hc_g_reveal('chicken')),
    ('hc_c3_ready.html', 'c3 ready (header)', lambda: world(HC_BG_HUD) + hc_hud_cover() + hc_g_header(False)),
    ('hc_d1_herorun.html', 'd1 HERO ATTEMPT (header)', lambda: world(HC_BG_HUD) + hc_hud_cover() + hc_g_header(False, 'CROSSING 2', 'HERO ATTEMPT', f'{HC_NAME} crosses alone{HC_DOT}0:12', head_fill='f-gold')),
    ('hc_d2_success.html', 'd2 HERO! success', lambda: world(HC_BG) + hc_bars() + hc_g_success(False)),
    ('hc_d3_group.html', 'd3 the group goes next (header)', lambda: world(HC_BG_HUD) + hc_hud_cover() + hc_g_header(False, 'HERO ATTEMPT COMPLETE', 'THE GROUP GOES NEXT', f'get ready{HC_DOT}3', phase_fill='f-gold')),
    ('hc_d4_caught.html', 'd4 Hero caught (header)', lambda: world(HC_BG_HUD) + hc_hud_cover() + hc_g_header(False, 'THE HERO WAS CAUGHT', 'THE GROUP GOES NEXT', f'get ready{HC_DOT}3', phase_fill='f-red')),
]


def hc_s_phone():
    """Phone (844 x 390 landscape): like gift_phone, the pick cards grow 1.3x for thumbs, Roblox's top bar kept clear."""
    cards = hc_g_choice(False, None).replace("class='abs fill grp'", "class='abs fill grp' style='transform:scale(1.3);transform-origin:960px 961px'", 1)
    return world(HC_BG) + hc_bars() + topbar() + hc_g_title(False, f'HERO OR CHICKEN?{HC_DOT}0:05', 'YOU WERE PICKED') + cards


HC_BEATS.append(('hc_e1_phone.html', 'e1 phone (844 x 390): picked Runner, cards 1.3x', hc_s_phone))


def hc_s_compare_height():
    return len(HC_BEATS) * 290


def hc_s_compare():
    """Each beat (small + top half at 2x) beside the existing in-game round header + best-egg card."""
    out = ''
    for i, (_, cap, fn) in enumerate(HC_BEATS):
        y = i * 290
        out += (f"<div class='abs' style='left:0;top:{y}px;width:480px;height:270px;overflow:hidden;border:2px solid #000'>"
                f"<div class='abs' style='left:0;top:0;width:1920px;height:1080px;transform:scale(.25);transform-origin:0 0'>{fn()}</div></div>")
        out += (f"<div class='abs' style='left:500px;top:{y}px;width:980px;height:270px;overflow:hidden;border:2px solid #000'>"
                f"<div class='abs' style='left:-470px;top:0;width:1920px;height:1080px;transform:scale(.5);transform-origin:960px 0'>{fn()}</div></div>")
        out += f"<div class='cap' style='left:8px;top:{y + 234}px;font-size:18px'>{cap}</div>"
        out += (f"<div class='abs' style='left:1500px;top:{y}px;width:420px;height:270px;background:#111;border:2px solid #000'>"
                "<img src='hc_ref_header.png' style='position:absolute;left:10px;top:10px;width:400px'>"
                "<img src='hc_ref_egg.png' style='position:absolute;left:10px;top:120px;width:190px'>"
                "<div class='cap' style='left:210px;top:226px;font-size:16px'>existing HUD</div></div>")
    return out, len(HC_BEATS) * 290


SCREENS = [  # (file, title, description, fn, height)
    ('style.html', 'Style', 'Reference, lobby, accents, icons, eggs, buttons', s_style, 1580),
    ('hud_menu.html', 'HUD (menu open)', 'MENU opens Settings · Stats · Servers', lambda: s_hud(True), 1080),
    ('hud.html', 'HUD (lobby)', 'Menus, first-pet goal, timer, wallet, equipped pet', s_hud, 1080),
    ('hud_match.html', 'HUD (match)', 'Role, crossing timer, teams, streak, egg level, ability, feed', s_hud_match, 1080),
    ('hud_phone.html', 'HUD (phone)', 'Bigger targets, thumbs kept clear', s_hud_phone, 1080),
    ('quests.html', 'Quests', 'Two daily quests, progress, rewards, claim', s_quests, 1080),
    ('incubator.html', 'Incubator', 'Pieces, first-pet path, families, species ladder, hatch', s_incubator, 1080),
    ('incubator_later.html', 'Incubator (after first pet)', 'Random 2 vs choose 3', lambda: s_incubator(False), 1080),
    ('pets.html', 'Pets', 'Collection grid, mastery stars, preview, equip', s_pets, 1080),
    ('shop.html', 'Shop (Featured)', "This week's colourway and a spotlight item", s_shop, 1080),
    ('shop_halloween.html', 'Shop (Featured, Halloween)', 'The three Halloween pets replace the Featured pair until Nov 1', lambda: s_shop('featured', ('ok', 'ok', 'ok')), 1080),
    ('shop_halloween_oct24.html', 'Shop (Halloween, from Oct 24)', 'Bone Dragon joins: Dragon NEW, Jack-o-Lantern, Mummy', lambda: s_shop('featured', None, 0), 1080),
    ('hwn_templates.html', 'Halloween cards (export)', 'HOS-HWN-001 templates for ui_hwn/rbx.json', s_hwn_templates, 1400),
    ('shop_halloween_states.html', 'Shop (Halloween states)', 'Wraith owned, Cat short on Gems, Mummy buyable', lambda: s_shop('featured', ('owned', 'poor', 'ok')), 1080),
    ('shop_cosmetics.html', 'Shop (Cosmetics)', 'Trails, egg cases and effects in one row, with filter chips', lambda: s_shop('cosmetics'), 1080),
    ('shop_emotes.html', 'Shop (Emotes)', 'The Emote Crate', lambda: s_shop('emotes'), 1080),
    ('shop_passes.html', 'Shop (Passes)', 'VIP and 2x XP game passes', lambda: s_shop('passes'), 1080),
    ('shop_getgems.html', 'Shop (Gems)', 'Six Robux Gem packs (developer products, live 16 Oct)', lambda: s_shop('gems'), 1080),
    ('stats.html', 'Stats', 'Your record', s_stats, 1080),
    ('settings.html', 'Settings', 'Real settings, toggles, UI colour, tabs', s_settings, 1080),
    ('ui_colour.html', 'UI colour', 'The UI Colour setting and the same screen in four choices', s_ui_colour, 1280),
    ('emotes.html', 'Emotes', 'My Emotes, your wheel, the Emote Crate', s_emotes, 1080),
    ('emotes_crate.html', 'Emotes (crate)', 'Odds board and open', lambda: s_emotes('crate'), 1080),
    ('emotes_reveal.html', 'Emotes (new emote)', 'After a crate', lambda: s_emotes('reveal'), 1080),
    ('emote_wheel.html', 'Emote wheel', 'G in the lobby: six emotes, stop, My Emotes', s_emote_wheel, 1080),
    ('servers.html', 'Servers', 'Find your people: regions, sort, join', s_servers, 1080),
    ('spectate.html', 'Spectate', 'Watch the match from the lobby', s_spectate, 1080),
    ('spectate_free.html', 'Spectate (free cam)', 'Fly around the field', lambda: s_spectate('free'), 1080),
    ('results.html', 'Results', 'Winner, podium, top thief, your rewards', s_results, 1080),
    ('hatch.html', 'Hatch reveal', 'New pet moment', s_hatch, 1080),
    ('reward.html', 'Reward', 'You got it: a shop item (Gold, Gems or Robux)', s_reward, 1080),
    ('reward_gems.html', 'Reward (Gems)', 'A Gem pack bought with Robux', lambda: s_reward('gems'), 1080),
    ('gift_claim.html', 'Welcome back (gift ready)', 'A returning player gets a free daily gift: CLAIM', lambda: s_gift('claim'), 1080),
    ('gift_wait.html', 'Come back tomorrow', 'After claiming, or on a first visit: countdown to the next gift', lambda: s_gift('wait'), 1080),
    ('gift_first_visit.html', 'First visit + favorite', "After the first match: come-back card with Roblox's favorite prompt on top", s_first_visit, 1080),
    ('event_rsvp.html', 'Join event', "Roblox's Notify Me prompt for the next event (only when one is set up)", s_event_rsvp, 1080),
    ('starter_pack.html', 'Starter pack', 'One-time bundle of looks, placeholder contents and price', s_starter, 1080),
    ('wait_offer.html', 'Waiting offer (Hero run)', 'Corner offer card while you wait out a Hero run', s_wait_offer, 1080),
    ('wait_offers.html', 'Waiting offers (all)', 'The three offers the card cycles, and what is left out', s_wait_offers, 1080),
    ('gift_phone.html', 'Welcome back (phone)', 'Same card 1.3x on a phone', s_gift_phone, 1080),
    ('gift_flow.html', 'When they show', 'Order and timing of all four prompts, the proposed gift', s_gift_flow, 1080),
    ('templates.html', 'Banners + toasts + confirm', 'Runtime templates', s_templates, 1120),
    ('states.html', 'All states', 'Every element in every state', s_states, 1560),
    ('field_gems_templates.html', 'Field Gems (export)', 'HOS-GEMS-002 templates for ui_gems/rbx.json', s_field_gems_templates, 1080),
    ('field_gems_phone.html', 'Field Gems (phone)', 'HOS-GEMS-002 billboards on a landscape phone', s_field_gems_phone, 1080),
    ('field_gems.html', 'Field Gems (review)', 'HOS-GEMS-002: "+1", "MAX" and the results tag next to the wallet and results card', s_field_gems, 1080),
    ('last_standing.html', 'Last One Standing (templates)', 'HOS-CINE-002: name card, VS card, face off + role line, solo-crossing pill', s_last_standing, 1080),
    ('last_standing_play.html', 'Last One Standing (animated)', 'The whole moment with the runtime timings over the captured shots; ?t=1.3 draws one frame', s_last_standing_play, 1080),
    ('last_standing_play_phone.html', 'Last One Standing (animated, phone)', 'Same on an 844x390 phone (2337 design px wide)', lambda: s_last_standing_play(True), 1080),
    ('last_standing_states.html', 'Last One Standing (review)', 'Every beat and state over a real match capture, PC, phone and next to EOSUI', s_last_standing_states, 7400),
    ('compare.html', 'Before', 'Current lobby HUD', s_compare, 1080),
    # HOS-PTS-001 (match points, revive, podium, favourite emote)
    ('points_match.html', 'Points: in match', '+100 Reached Safety! and +10 Juke! beside you, a short JUKE! up top, over the live match HUD', pts_s_match, 1080),
    ('points_revive.html', 'Points: revive', 'One ring billboard for Runners nearby: the 6 s window draining, E within 6 studs, the hold filling the same ring', pts_s_revive, 1080),
    ('points_podium.html', 'Points: podium', 'Banner and the top-3 cards (name and points)', pts_s_podium, 1080),
    ('points_board.html', 'Points: results', 'The one results screen: leaderboard + your rewards with the egg', pts_s_board, 1080),
    ('points_emotes.html', 'Points: favourite emote', 'The star on My Emotes', pts_s_emotes_fav, 1080),
    ('points_templates.html', 'Points: templates', 'Runtime templates as exported', pts_s_templates, 1080),
    ('points_states.html', 'Points: every state', 'PC and phone, every state', pts_s_states, 7300),
    ('points_hero_after.html', 'Points: HERO! banner (mockup)', 'The Hero or Chicken banner with the points pill (mockup only)', pts_hero_after, 1080),
    ('points_labels_phone.html', 'Points: labels on phone', 'Pops with the points pill at phone scale', pts_s_labels_phone, 1080),
]
SCREENS += RV_SCREENS   # HOS-PTS-001 results v2 mockup (review only)
# Hero or Chicken (HOS-HOC-001): the exported screen + templates, every beat, phone, and the side-by-side
SCREENS += [('hc_screen.html', 'Hero or Chicken (screen)', 'Every Hero or Chicken group in place, all start hidden (exported)', hc_s_screen, 1080),
            ('hc_templates.html', 'Hero or Chicken (templates)', 'HERO tag over the Hero, +200 HERO pop (exported)', hc_s_templates, 1080)]
SCREENS += [(f, 'Hero or Chicken: ' + c, c, fn, 1080) for f, c, fn in HC_BEATS]
SCREENS += [('hc_compare.html', 'Hero or Chicken beside the HUD', 'Each beat next to the existing round header and egg card', lambda: hc_s_compare()[0], hc_s_compare_height())]


# ================================================================== HOS-EGG-002 egg plan (charge, roll at safety, shards, incubator egg)
# Spec: docs/HOS-EGG-002/Egg Plan Build Spec.md section 5. Numbers mirror Shared.EggConfig (the screen shows the odds the
# server rolls). Units rule: never a bare number ("+1 RARE SHARD", "18 / 30 FILL", pts_pill for points, coin + GOLD).
# Shards use the kit's piece_* art (they ARE egg-shell shards); Legendary = piece_crowned / egg_golden / gold.
# Pages: egg_*.html (review only until Hunter approves; export later from ui_egg/rbx.json).
EGG_R = {  # rarity -> (egg icon, shard icon, slot rarity, text fill, bar colour key, WORD)
    'common': ('egg_basic', 'piece_common', 'common', 'f-common', 'lime', 'COMMON'),
    'rare': ('egg_shiny', 'piece_rare', 'rare', 'f-rare', 'sky', 'RARE'),
    'epic': ('egg_cosmic', 'piece_epic', 'epic', 'f-epic', 'purple', 'EPIC'),
    'legendary': ('egg_golden', 'piece_crowned', 'crowned', 'f-gold', 'gold', 'LEGENDARY'),
}
EGG_GLOW = {'common': '#8ef07a', 'rare': '#5cc8ff', 'epic': '#c88aff', 'legendary': '#ffd23a'}
EGG_FAM = [  # focus chips: EggConfig.FAMILIES order; open = has a pet in EconomyConfig today
    ('Decoy', 'ab_decoy', True), ('Invisibility', 'ab_invis', True), ('Guardian', 'ab_shield', False),
    ('Tempest', 'ab_tempest', False), ('Rift', 'ab_rift', False)]
EGG_FILL, EGG_FOCUS_MULT = 30, 1.25


def egg_meter(x, y, charge, rarity, segs=4, w=150, h=22, name='Charge'):
    """The charge meter: segs segments filling left to right (charge 0..1), rarity colour, glow when full.
    Native at runtime: Seg1..SegN frames, each with a Fill child sized to its share of the charge."""
    col_ = EGG_R[rarity][4]
    gap = 6
    sw = (w - gap * (segs - 1)) / segs
    out = ''
    for i in range(segs):
        part = max(0.0, min(1.0, charge * segs - i))
        out += (f"<div class='cbar k-{col_}' data-n='Seg{i + 1}' style='left:{x + i * (sw + gap):.1f}px;top:{y}px;width:{sw:.1f}px;height:{h}px;"
                f"{'box-shadow:0 0 12px ' + EGG_GLOW[rarity] if charge >= 1 else ''}'><i data-n='Fill' style='width:{part * 100:.0f}%'></i></div>")
    return f"<div class='abs' data-n='{name}' style='left:0;top:0;width:0;height:0'>{out}</div>"


# the shard meter (17 Oct ~18:47, no roll): one meter a match, marks at 2.0 (EPIC) and 5.0 (LEGENDARY) = EggConfig.CHARGE
EGG_MARKS, EGG_MCAP = [(2.0, 'epic'), (5.0, 'legendary')], 5.0


def egg_meter_marks(x, y, charge, w=168, h=20, name='Charge'):
    """Two segments: Seg1 fills 0 -> 2.0 (purple, "EPIC" under its end), Seg2 2.0 -> 5.0 (gold, "LEGENDARY").
    Native at runtime: Seg1 / Seg2 frames, each with a Fill child sized to its share; Mark1 / Mark2 labels."""
    gap = 6
    out, x0, prev = '', x, 0.0
    for i, (at_, r) in enumerate(EGG_MARKS):
        sw = (w - gap) * (at_ - prev) / EGG_MCAP
        part = max(0.0, min(1.0, (charge - prev) / (at_ - prev)))
        col_ = EGG_R[r][4]
        out += (f"<div class='cbar k-{col_}' data-n='Seg{i + 1}' style='left:{x0:.1f}px;top:{y}px;width:{sw:.1f}px;height:{h}px;"
                f"{'box-shadow:0 0 12px ' + EGG_GLOW[r] if part >= 1 else ''}'><i data-n='Fill' style='width:{part * 100:.0f}%'></i></div>")
        out += f"<div class='abs' style='left:{x0 + sw - 120:.1f}px;top:{y + h + 3}px;width:120px;text-align:right'>{T(EGG_R[r][5], 13, 'xs', EGG_R[r][3], name=f'Mark{i + 1}')}</div>"
        x0 += sw + gap
        prev = at_
    return f"<div class='abs' data-n='{name}' style='left:0;top:0;width:0;height:0'>{out}</div>"


def egg_glow_slot(x, y, s, rarity, charge, name='EggSlot', icon=None):
    """The egg slot with the charge glow (3 strengths: none / soft / strong), in the rarity colour."""
    g = EGG_GLOW[rarity]
    out = slot(x, y, s, EGG_R[rarity][2], icon or EGG_R[rarity][0], name=name, art_pad=.1)
    if charge > 0 or EXPORT_STATES:   # radial glow (exports as the tinted glow image; runtime sets its transparency)
        a = .55 if charge < 1 else .95
        pad = int(s * .32)
        out = (f"<div class='abs{' hid' if EXPORT_STATES else ''}' data-n='ChargeGlow' style='left:{x - pad}px;top:{y - pad}px;width:{s + 2 * pad}px;height:{s + 2 * pad}px;"
               f"background:radial-gradient({g}{int(a * 255):02x} 30%, {g}00 70%)'></div>") + out
    return out


def egg_card(rarity='rare', charge=0.0, role='runner', snatched=None, cap='epic', segs=4, x=12, y=878):
    """The HUD egg card (edits the live best-egg card: same glass plate and title; the rarity diamonds become the
    charge meter, "pays" reads the shard). Catchers: their stash (best snatch) and their snatch cap, no meter."""
    def big(word):   # the rarity word fills the 196 px column: LEGENDARY is the longest
        return 44 if len(word) <= 4 else (38 if len(word) <= 6 else 31)
    eg = f"<div class='glass' style='left:{x}px;top:{y}px;width:340px;height:178px'></div>"
    tx = x + 128
    if role == 'runner':
        ic, sh, rs, fill, colk, word = EGG_R[rarity]
        eg += egg_glow_slot(x + 14, y + 20, 100, rarity, charge)
        eg += at(tx, y + 16, T('YOUR EGG', 16, 'xs', 'f-dim', name='EggTitle'))
        eg += at(tx, y + 40, T(word, big(word), 'l', fill, name='EggLevel'))
        eg += I('sparkle', tx, y + 96, 26, name='ChargeIcon')
        eg += egg_meter_marks(tx + 32, y + 99, charge, w=168)
        eg += at(tx, y + 146, row(T('pays', 14, 'xs', 'f-dim'), icn(sh, 22, name='PaysIcon'), T(f'+1 {word} SHARD', 13 if len(word) > 6 else 14, 'xs', fill, name='PaysText'), gap=4))
    else:
        has = snatched is not None
        r = snatched or 'common'
        ic, sh, rs, fill, colk, word = EGG_R[r]
        eg += slot(x + 14, y + 20, 100, rs if has else 'locked', ic if has else 'steal', name='EggSlot', art_pad=.1, cls='' if has else 'fill')
        eg += at(tx, y + 16, T('YOUR STASH', 16, 'xs', 'f-dim', name='EggTitle'))
        eg += at(tx, y + 40, T(word if has else 'EMPTY', big(word) if has else 38, 'l', fill if has else 'f-dim', name='EggLevel'))
        cw = EGG_R[cap][5]
        eg += at(tx, y + 102, row(T('snatch up to', 14, 'xs', 'f-dim'), T(cw, 14, 'xs', EGG_R[cap][3], name='CapText'), gap=5))
        pays = row(T('pays', 14, 'xs', 'f-dim'), icn(sh, 22, name='PaysIcon'), T(f'+1 {word} SHARD', 13 if len(word) > 6 else 14, 'xs', fill, name='PaysText'), gap=4) if has             else T('catch to snatch an egg', 14, 'xs', 'f-dim', name='PaysText')
        eg += at(tx, y + 140, pays)
    return eg


def egg_charge_pop(x, y, rarity='rare', name='ChargePop'):
    """"+CHARGE" beside the "+10 PTS Juke!" pop: no card, sparkle + word in the egg's colour."""
    return at(x, y, row(icn('sparkle', 34, name='Icon'), T('+CHARGE', 34, 'l', EGG_R[rarity][3], name='ChargeText'), gap=6), name=name)


def egg_banner(rarity='epic', x=60, y=80, name='Banner'):
    """Upgrade at safety: the egg-grew banner style (banner_card) in the rarity colour. Only on an upgrade."""
    col_ = {'rare': 'sky', 'epic': 'purple', 'legendary': 'gold'}[rarity]
    word = EGG_R[rarity][5]
    # banner_card's look with a smaller title: "SHARD UPGRADED: LEGENDARY" is the longest line
    inner = (f"<div class='hp k-{col_}' style='left:0;top:0;width:820px;height:120px'><div class='lbl' style='padding-left:150px'>"
             f"{col(T(f'SHARD UPGRADED: {word}', 40 if len(word) > 4 else 50, 'xl', name='Title'), T('Keep it safe to the end', 24, 's', name='Sub'), gap=0, align='flex-start')}</div></div>")
    inner += I(EGG_R[rarity][0], -10, -26, 160, name='Icon')
    return box(x, y, 820, 120, inner, name=name)


def egg_tutorial(x=560, y=640):
    """Once, on the first charge: one short card (2 lines, <= 6 words each), sparkle icon, no buttons; fades after 4 s."""
    inner = f"<div class='glass' style='left:0;top:0;width:800px;height:118px'></div>" + I('sparkle', 18, 14, 90, name='Icon')
    inner += at(124, 16, T('Brave plays fill your meter.', 34, 'l', name='Line1'))
    inner += at(126, 66, T('Pass a mark: your shard steps up at the next safe.', 24, 's', 'f-dim', name='Line2'))
    return box(x, y, 800, 118, inner, name='Tutorial')


# ----- the incubator egg screen (replaces the recipe panel; Data_Incubator)
def egg_ring(cx, cy, r, frac, col_='#7cf05a', stroke=22, name='FillRing', hole='#19191b'):
    """Fill ring around an egg, built to export natively (approved 17 Oct): a dark track disc, the fill as a conic
    wedge (-> Builder "Cooldown" frame, attribute Frac, recoloured / refilled at runtime) and an inner disc for the
    hole. Runtime: <name>.Cooldown (Builder.cooldown-style update)."""
    R = r + stroke // 2
    f = max(0.0, min(1.0, frac)) * 100
    inner = (f"<div class='abs' data-n='Track' style='left:0;top:0;width:{2 * R}px;height:{2 * R}px;border-radius:50%;background:#2c2c30;border:4px solid #050506;box-sizing:border-box'></div>"
             f"<div class='abs' style='left:4px;top:4px;width:{2 * R - 8}px;height:{2 * R - 8}px;border-radius:50%;background:conic-gradient({col_} 0% {f:.2f}%, rgba(0,0,0,0) {f:.2f}% 100%)'></div>"
             f"<div class='abs' data-n='Hole' style='left:{stroke + 4}px;top:{stroke + 4}px;width:{2 * R - 2 * stroke - 8}px;height:{2 * R - 2 * stroke - 8}px;border-radius:50%;background:{hole};border:4px solid #050506;box-sizing:border-box'></div>")
    return box(cx - R, cy - R, 2 * R, 2 * R, inner, name=name)


def egg_odds(shards, legendary_open=False):
    """EggLogic.incubatorOdds in Python (the page shows what the server rolls)."""
    epic = min(.50, .085 + .025 * shards.get('epic', 0))
    leg = min(.25, .015 + .04 * shards.get('legendary', 0))
    if not legendary_open:
        epic, leg = epic + leg, 0.0
    return {'rare': max(0.0, 1 - epic - leg), 'epic': epic, 'legendary': leg}


def pct(v):
    return f'{v * 100:.1f}%'.replace('.0%', '%')


def egg_incubator(fill=18.0, shards=None, focus='Any', state='filling', legendary_open=False):
    """state: filling | ready | hatching. Focus raises the fill needed by 25% and never costs Gems."""
    shards = shards or {'rare': 9, 'epic': 2, 'legendary': 0}
    need = EGG_FILL * (EGG_FOCUS_MULT if focus != 'Any' else 1)
    frac = min(1.0, fill / need)
    ready = state != 'filling'
    b = ''
    # left: the big egg in its fill ring
    eg = egg_ring(250, 250, 186, frac, '#ffd23a' if ready else '#7cf05a')
    eg += I('egg_starter' if not ready else 'egg_golden', 120, 104, 260, 290, name='BigEgg')
    if ready or EXPORT_STATES:
        cls = 'ic' + (' hid' if not ready else '')
        eg += I('sparkle', 360, 70, 70, name='Sparkle', cls=cls) + I('sparkle', 80, 330, 50, name='Sparkle2', cls=cls)
    fill_txt = f'{fill:g} / {need:g} FILL'
    eg += at(250, 470, T(fill_txt, 40, 'l', 'f-gold' if ready else '', name='FillText'), w=440, align='center')
    eg += at(250, 524, T('READY TO HATCH!' if ready else f'{need - fill:g} more fill to hatch', 22, 's', 'f-gold' if ready else 'f-dim', name='FillSub'), w=440, align='center')
    b += well(26, 40, 500, 572, eg, name='Egg', title='Your Egg')
    # right top: shard counters (Rare, Epic, Legendary)
    sc = ''
    for i, r in enumerate(['rare', 'epic', 'legendary']):
        ic, sh, rs, f, k, word = EGG_R[r]
        n = shards.get(r, 0)
        if EXPORT_STATES:   # both looks: On (has shards) / Off (x0, dimmed); runtime shows one
            sc += sub(f'Shard_{r}', slot(24 + i * 150, 22, 118, rs, sh, f'x{n}', word.title(), name='On', cls='' if n else 'hid')
                      + slot(24 + i * 150, 22, 118, rs, sh, 'x0', word.title(), name='Off', cls='locked' + ('' if not n else ' hid')))
        else:
            sc += slot(24 + i * 150, 22, 118, rs, sh, f'x{n}', word.title(), name=f'Shard_{r}', cls='locked' if n == 0 else '')
    sc += at(500, 40, col(T('Rarer shards fill more', 22, 's', name='WeightLine1'),
                         T('Rare 1  ·  Epic 3  ·  Legendary 10', 20, 'xs', 'f-dim', name='WeightLine2'),
                         T('Epic and Legendary shards raise the odds', 20, 'xs', 'f-dim', name='WeightLine3'), gap=6, align='flex-start'))
    b += well(552, 40, 922, 166, sc, name='Shards', title='Shards In This Egg')
    # right middle: odds bars (the same numbers the hatch rolls)
    o = egg_odds(shards, legendary_open)
    od = ''
    for i, r in enumerate(['rare', 'epic', 'legendary']):
        ic, sh, rs, f, k, word = EGG_R[r]
        yy = 18 + i * 52
        od += at(24, yy + 2, row(icn(ic, 36), T(word.title(), 24, 's', f, name=f'OddsName_{r}'), gap=6))
        if EXPORT_STATES and r == 'legendary':   # both: the live bar, and the "coming soon" cover shown while folded
            od += bar(250, yy + 6, 520, 30, max(o[r], .2), k, f'OddsBar_{r}') + at(880, yy + 4, T(pct(o[r]), 26, 's', f, name=f'OddsText_{r}'), w=90, align='right')
            od += sub('OddsSoon', box(250, yy + 6, 520, 30, '', 'cbar k-grey', name='SoonBar') + at(510, yy + 7, T('PETS COMING SOON', 18, 'xs', 'f-dim', name='SoonText'), w=520, align='center'), hid=legendary_open)
        elif r == 'legendary' and not legendary_open:
            od += bar(250, yy + 6, 520, 30, 0, 'grey', f'OddsBar_{r}') + at(510, yy + 7, T('PETS COMING SOON', 18, 'xs', 'f-dim', name=f'OddsSoon_{r}'), w=520, align='center')
            od += at(880, yy + 4, T('0%', 26, 's', 'f-dim', name=f'OddsText_{r}'), w=90, align='right')
        else:
            od += bar(250, yy + 6, 520, 30, o[r], k, f'OddsBar_{r}') + at(880, yy + 4, T(pct(o[r]), 26, 's', f, name=f'OddsText_{r}'), w=90, align='right')
    note = 'Legendary pets are coming: until then their chance goes to Epic' if not legendary_open else 'These are the exact odds of your hatch'
    od += at(24, 172, T(note, 18, 'xs', 'f-dim', name='OddsNote'))
    b += well(552, 248, 922, 206, od, name='Odds', title='Hatch Odds')
    # right lower: focus picker (Any + 5 families)
    fc = ''
    chips = [('Any', 'dice', True)] + EGG_FAM
    for i, (fam, ic, open_) in enumerate(chips):
        cx = 20 + i * 114
        sel = fam == focus
        lab = fam if fam != 'Invisibility' else 'Invis'
        if EXPORT_STATES:   # three looks per chip: Sel (gold) / Open / Locked; runtime shows one (locks from the live pet data)
            st = 'Sel' if sel else ('Open' if open_ else 'Locked')
            looks = slot(cx, 18, 100, 'gold', ic, label=lab, cls='fill' + ('' if st == 'Sel' else ' hid'), art_pad=.2, label_size=15, name='Sel')
            looks += slot(cx, 18, 100, 'common', ic, label=lab, cls='fill' + ('' if st == 'Open' else ' hid'), art_pad=.2, label_size=15, name='Open')
            looks += slot(cx, 18, 100, 'locked', ic, label=lab, cls='fill soon' + ('' if st == 'Locked' else ' hid'), art_pad=.2, label_size=15, name='Locked',
                          inner_extra=I('lock', 66, 6, 28))
            fc += sub(f'Focus_{fam}', looks, btn=True)
        else:
            fc += sub(f'Focus_{fam}', slot(cx, 18, 100, 'gold' if sel else ('common' if open_ else 'locked'), ic, label=lab,
                                           cls='fill' if open_ else 'fill soon', art_pad=.2, label_size=15,
                                           inner_extra='' if open_ else I('lock', 66, 6, 28)), btn=open_)
    fc += selring(20 + [c[0] for c in chips].index(focus) * 114, 18, 100, 100, 'FocusSel')
    fc += at(714, 20, col(T('+25% TO FILL', 22, 's', 'f-gold' if focus != 'Any' else 'f-dim', name='FocusCost'),
                          T('for a family', 16, 'xs', 'f-dim'), T('change any time', 16, 'xs', 'f-dim'), T('never costs Gems', 16, 'xs', 'f-dim'), gap=3, align='flex-start'))
    fc += at(20, 126, T('Locked families get pets soon', 16, 'xs', 'f-dim'))
    b += well(552, 496, 922, 154, fc, name='Focus', title='Focus')
    # bottom: the hatch button (filling / ready / hatching) + the one-line explainer
    hb = at(30, 26, T('Every match adds one shard to this egg. Fill it, then hatch a pet.', 24, 's', 'f-dim', name='Explainer'))
    lab = {'filling': 'HATCH', 'ready': 'HATCH!', 'hatching': 'HATCHING...'}[state]
    if EXPORT_STATES:   # both plates; runtime shows BtnHatch (ready) or BtnHatchOff (filling / hatching) and sets the label
        hb += btn(1060, 6, 360, 80, 'lime', row(icn('egg_golden', 50, name='BtnIcon'), bl('HATCH!', 36)), name='BtnHatch', hid=not ready)
        hb += btn(1060, 6, 360, 80, 'grey', row(icn('egg_starter', 50, name='BtnIcon'), bl(lab, 36)), name='BtnHatchOff', hid=ready)
    else:
        hb += btn(1060, 6, 360, 80, 'lime' if state == 'ready' else 'grey', row(icn('egg_golden' if ready else 'egg_starter', 50), bl(lab, 36)), name='BtnHatch')
    b += well(26, 668, 1448, 92, hb, name='HatchBar', solid=True)
    return world('bg_lobby_blur.jpg', False) + dim() + panel('Incubator', 'lime', 'Incubator', 'incubator', b, 210, 104, 1500, 884)


# ----- the incubator with overfill + the Lucky Egg pass (17 Oct ~18:04 / 18:10; MOCKUP ONLY until Hunter approves).
# Mirrors EggConfig.INCUBATOR (FILL 18, MAX_MULT 2, FOCUS_COST .25, ODDS 100/150/200%) and LUCKY_PASS (x1.5): the
# screen shows exactly the odds EggLogic rolls (incubatorOdds -> applyLuck), read from the fill after the focus cost.
EGG_OVER = {'fill': 18, 'max': 2.0, 'focus': .25,
            'odds': [(1.0, .16, .04), (1.5, .22, .06), (2.0, .28, .08)], 'luck': 1.5}


def egg_over_odds(fill, focus='Any', lucky=False, legendary_open=True):
    """EggLogic.oddsAt(oddsLevel) -> fold -> applyLuck, in Python."""
    O = EGG_OVER
    cost = O['fill'] * O['focus'] if focus != 'Any' else 0
    lv = max(0, fill - cost) / O['fill']
    pts = O['odds']
    a = b = pts[0]
    if lv >= pts[-1][0]:
        a = b = pts[-1]
    elif lv > pts[0][0]:
        for i in range(len(pts) - 1):
            if pts[i][0] <= lv <= pts[i + 1][0]:
                a, b = pts[i], pts[i + 1]
                break
    t = (lv - a[0]) / (b[0] - a[0]) if b[0] > a[0] else 0
    epic, leg = a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t
    if not legendary_open:
        epic, leg = epic + leg, 0.0
    if lucky:
        epic, leg = epic * O['luck'], leg * O['luck']
    return {'rare': max(0.0, 1 - epic - leg), 'epic': epic, 'legendary': leg}, lv


def egg_ring_marks(cx, cy, r, stroke=22):
    """Tick marks on the fill ring: HATCH at FILL (half-way round) and MAX at the cap (the ring runs 0 -> 2 x FILL).
    Fill only, never percent (Hunter 17 Oct: "use FILL only")."""
    import math
    out = ''
    for frac, lab in [(.5, 'HATCH'), (1.0, 'MAX')]:
        ang = frac * 2 * math.pi
        R = r + stroke // 2
        x, y = cx + math.sin(ang) * R, cy - math.cos(ang) * R
        out += (f"<div class='abs' style='left:{x - 4:.0f}px;top:{y - 18:.0f}px;width:8px;height:36px;background:#fff;"
                f"box-shadow:0 0 0 3px #050506;border-radius:3px;transform:rotate({frac * 360:.0f}deg)'></div>")
        if frac == .5:   # HATCH sits at the bottom, over the fill text: label it beside its tick
            lx, ly = x + 62, y + 6
        else:            # MAX at the top, beside its tick
            lx, ly = x + 58, y + 2
        out += at(lx, ly - 12, T(lab, 20, 'xs', 'f-gold' if frac > .5 else '', name=f'Mark{lab.title()}'), w=90, align='center')
    return out


# the hatch boost ladder (EggConfig.HATCH_BOOST): Robux dev products, the current egg's hatch only. Prices are Hunter's
# (Creator Hub); the button shows the product's live price. These are placeholders for the mockup.
EGG_BOOST = {'mults': [2, 3, 4], 'cap': .20, 'price': [49, 50, 50]}


def egg_hatch_odds(fill, focus='Any', lucky=False, boost=0, legendary_open=True):
    """EggLogic.hatchOdds in Python: overfill odds -> Lucky Egg pass -> boost tier -> Legendary cap (Rare the rest)."""
    o, lv = egg_over_odds(fill, focus, lucky, legendary_open)
    epic, leg = o['epic'], o['legendary']
    if lucky:   # applyLuck never lets Epic + Legendary pass 1
        epic -= max(0.0, epic + leg - 1)
    if boost:
        m = EGG_BOOST['mults'][boost - 1]
        epic, leg = epic * m, leg * m
    leg = min(leg, EGG_BOOST['cap'])
    epic = min(epic, 1 - leg)
    return {'rare': max(0.0, 1 - epic - leg), 'epic': epic, 'legendary': leg}, lv


def egg_boost_btn(boost, x=690, y=6, w=340, h=80):
    """The ladder button beside HATCH: x2 ODDS -> UPGRADE TO x3 -> UPGRADE TO x4 -> x4 MAXED (disabled).
    Export: BtnBoost (purple, BoostLabel + BoostPrice set at runtime) and BtnBoostMax (grey); hidden while the ids are 0."""
    M = EGG_BOOST['mults']
    out = ''
    if EXPORT_STATES or boost < len(M):
        lab = f'x{M[0]} ODDS' if boost == 0 else f'UPGRADE TO x{M[min(boost, len(M) - 1)]}'
        price = EGG_BOOST['price'][min(boost, len(M) - 1)]
        inner = row(icn('star', 46, name='BoostIcon'),
                    col(bl(lab, 26, name='BoostLabel'), row(icn('robux', 26, name='RobuxIcon'), T(f'{price}', 24, 's', name='BoostPrice'), gap=4), gap=0),
                    gap=8)
        out += btn(x, y, w, h, 'purple', inner, name='BtnBoost', hid=boost >= len(M))
    if EXPORT_STATES or boost >= len(M):
        out += btn(x, y, w, h, 'grey', row(icn('star', 46, name='BoostIcon'), bl(f'x{M[-1]} MAXED', 30, name='BoostLabel'), gap=8),
                   name='BtnBoostMax', hid=boost < len(M))
    return out


def egg_incubator_over(fill=27.0, focus='Any', lucky=False, shards=None, hatching=False, boost=0, legendary_open=True, bare=False):
    """The incubator with overfill, the Lucky Egg pass and the hatch boost ladder. Fill only, never percent:
    "27 / 36 FILL", ring marks HATCH (18) and MAX (36), "Odds at 27 fill". boost = tiers bought for this egg (0..3).
    With UI_EXPORT=1 every runtime state is on the page (hidden ones too); EggUIController shows one of each."""
    O = EGG_OVER
    X = EXPORT_STATES
    shards = shards or {'rare': 11, 'epic': 4, 'legendary': 1}
    full, cap_ = O['fill'], O['fill'] * O['max']
    cost = full * O['focus'] if focus != 'Any' else 0
    need = full + cost
    ready = fill >= need
    o, lv = egg_hatch_odds(fill, focus, lucky, boost, legendary_open)
    over = ready and lv > 1.0 + 1e-9
    b = ''
    # left: the egg in a 0 -> 36 ring (green to 18, gold past it), marks HATCH / MAX
    eg = egg_ring(250, 250, 186, fill / cap_, '#ffd23a' if fill > full else '#7cf05a')
    eg += egg_ring_marks(250, 250, 186)
    eg += I('egg_golden' if ready else 'egg_starter', 120, 104, 260, 290, name='BigEgg')
    if ready or X:
        cls = 'ic' + (' hid' if not ready else '')
        eg += I('sparkle', 360, 70, 70, name='Sparkle', cls=cls) + I('sparkle', 80, 330, 50, name='Sparkle2', cls=cls)
    eg += at(250, 470, T(f'{fill:g} / {cap_:g} FILL', 40, 'l', 'f-gold' if ready else '', name='FillText'), w=460, align='center')
    if not ready:
        sub_ = f'{need - fill:g} more fill to hatch'
    elif fill >= cap_:
        sub_ = 'MAX FILL: the best odds this egg can give'
    else:
        sub_ = f'Hatch now, or fill to {cap_:g} for bigger odds'
    eg += at(250, 524, T(sub_, 22, 's', 'f-gold' if ready else 'f-dim', name='FillSub'), w=460, align='center')
    b += well(26, 40, 500, 572, eg, name='Egg', title='Your Egg')
    # right top: shard counters; a shard's rarity only sets its fill
    sc = ''
    for i, r in enumerate(['rare', 'epic', 'legendary']):
        ic, sh, rs, f, k, word = EGG_R[r]
        n = shards.get(r, 0)
        if X:   # both looks: On (has shards) / Off (x0, dimmed)
            sc += sub(f'Shard_{r}', slot(24 + i * 150, 22, 118, rs, sh, f'x{n}', word.title(), name='On', cls='' if n else 'hid')
                      + slot(24 + i * 150, 22, 118, rs, sh, 'x0', word.title(), name='Off', cls='locked' + ('' if not n else ' hid')))
        else:
            sc += slot(24 + i * 150, 22, 118, rs, sh, f'x{n}', word.title(), name=f'Shard_{r}', cls='locked' if n == 0 else '')
    W = {r: EGG_CFG[r][2] for r in EGG_CFG}
    sc += at(500, 40, col(T('Rarer shards fill more', 22, 's', name='WeightLine1'),
                         T(f'Rare {W["rare"]:g}  ·  Epic {W["epic"]:g}  ·  Legendary {W["legendary"]:g}', 20, 'xs', 'f-dim', name='WeightLine2'),
                         T(f'Fill past {full:g} for bigger odds', 20, 'xs', 'f-gold', name='WeightLine3'), gap=6, align='flex-start'))
    b += well(552, 40, 922, 166, sc, name='Shards', title='Shards In This Egg')
    # right middle: the odds the hatch rolls (fill after the focus cost, the pass, the boost, the cap)
    od = ''
    for i, r in enumerate(['rare', 'epic', 'legendary']):
        ic, sh, rs, f, k, word = EGG_R[r]
        yy = 12 + i * 44
        od += at(24, yy, row(icn(ic, 34), T(word.title(), 24, 's', f, name=f'OddsName_{r}'), gap=6))
        od += bar(250, yy + 3, 520, 30, o[r], k, f'OddsBar_{r}') + at(880, yy + 2, T(pct(o[r]), 26, 's', f, name=f'OddsText_{r}'), w=90, align='right')
        if X and r == 'legendary':   # the "coming soon" cover, shown while Legendary folds into Epic
            od += sub('OddsSoon', box(250, yy + 3, 520, 30, '', 'cbar k-grey', name='SoonBar') + at(510, yy + 5, T('PETS COMING SOON', 18, 'xs', 'f-dim', name='SoonText'), w=520, align='center'), hid=True)
    basis = f'Odds at {max(fill - cost, full):g} fill'
    note2 = f'after the {cost:g} focus cost' if cost else ('what your hatch rolls' if ready else f'they grow as you fill past {full:g}')
    od += at(24, 146, col(T(basis, 20, 'xs', name='OddsNote'), T(note2, 16, 'xs', 'f-dim', name='OddsNote2'), gap=2, align='flex-start'))
    # the Lucky Egg pass: a tag on the header + a line when owned, a phone-readable buy strip when not
    if lucky or X:
        od += f"<div class='ctag k-gold{'' if lucky else ' hid'}' data-n='LuckyTag' style='left:736px;top:-44px;height:34px'>{row(icn('sparkle', 26), T('LUCKY +50%', 18, 'xs', name='LuckyText'), gap=4)}</div>"
        od += box(400, 144, 500, 52, at(0, 12, row(icn('sparkle', 30), T('Lucky Egg: Epic and Legendary x1.5', 20, 'xs', 'f-gold', name='LuckyOnText'), gap=6)), name='LuckyOn', hid=not lucky)
    if not lucky or X:
        od += btn(400, 144, 500, 52, 'gold', row(icn('sparkle', 34), T('Lucky Egg: +50% Epic & Legendary', 22, 's', name='LuckyBtnText'), gap=6), name='BtnLucky', hid=lucky)
    if boost or X:   # the boost tag sits left of LUCKY on the header
        tag = f"x{EGG_BOOST['mults'][max(1, boost) - 1]} BOOST"
        od += f"<div class='ctag k-purple{'' if boost else ' hid'}' data-n='BoostTag' style='left:566px;top:-44px;height:34px'>{row(icn('star', 26), T(tag, 18, 'xs', name='BoostTagText'), gap=4)}</div>"
    b += well(552, 248, 922, 206, od, name='Odds', title='Hatch Odds')
    # right lower: focus (every family open now); the chip shows what it spends at hatch
    fc = ''
    chips = [('Any', 'dice', True)] + [(f, ic, True) for f, ic, _ in EGG_FAM]
    for i, (fam, ic, open_) in enumerate(chips):
        cx = 20 + i * 114
        sel = fam == focus
        lab = fam if fam != 'Invisibility' else 'Invis'
        if X:   # three looks per chip: Sel / Open / Locked
            st = 'Sel' if sel else 'Open'
            looks = slot(cx, 18, 100, 'gold', ic, label=lab, cls='fill' + ('' if st == 'Sel' else ' hid'), art_pad=.2, label_size=15, name='Sel')
            looks += slot(cx, 18, 100, 'common', ic, label=lab, cls='fill' + ('' if st == 'Open' else ' hid'), art_pad=.2, label_size=15, name='Open')
            looks += slot(cx, 18, 100, 'locked', ic, label=lab, cls='fill soon hid', art_pad=.2, label_size=15, name='Locked', inner_extra=I('lock', 66, 6, 28))
            fc += sub(f'Focus_{fam}', looks, btn=True)
        else:
            fc += sub(f'Focus_{fam}', slot(cx, 18, 100, 'gold' if sel else 'common', ic, label=lab, cls='fill', art_pad=.2, label_size=15), btn=True)
    fc += selring(20 + [c[0] for c in chips].index(focus) * 114, 18, 100, 100, 'FocusSel')
    fc += at(714, 20, col(T(f'-{full * O["focus"]:g} FILL', 22, 's', 'f-gold' if focus != 'Any' else 'f-dim', name='FocusCost'),
                          T('spent at hatch', 16, 'xs', 'f-dim'), T('change any time', 16, 'xs', 'f-dim'), T('never costs Gems', 16, 'xs', 'f-dim'), gap=3, align='flex-start'))
    b += well(552, 496, 922, 154, fc, name='Focus', title='Focus')
    # bottom: the explainer, the boost ladder, HATCH NOW at 18 / HATCH (BIGGER ODDS) past it
    hb = at(30, 14, col(T('Every match adds a shard.', 22, 's', 'f-dim', name='Explainer'),
                        T(f'Hatch at {full:g}, or fill to {cap_:g} for bigger odds.', 22, 's', 'f-dim', name='Explainer2'), gap=2, align='flex-start'))
    hb += egg_boost_btn(boost)
    if X:   # both plates; runtime shows one and sets the label (HATCH NOW / HATCH (BIGGER ODDS) / HATCH / HATCHING...)
        hb += btn(1060, 6, 360, 80, 'lime', row(icn('egg_golden', 50, name='BtnIcon'), bl('HATCH NOW', 36)), name='BtnHatch', hid=not ready)
        hb += btn(1060, 6, 360, 80, 'grey', row(icn('egg_starter', 50, name='BtnIcon'), bl('HATCH', 36)), name='BtnHatchOff', hid=ready)
    elif hatching:
        hb += btn(1060, 6, 360, 80, 'grey', row(icn('egg_golden', 50), bl('HATCHING...', 32)), name='BtnHatchOff')
    elif not ready:
        hb += btn(1060, 6, 360, 80, 'grey', row(icn('egg_starter', 50), bl('HATCH', 36)), name='BtnHatchOff')
    else:
        hb += btn(1060, 6, 360, 80, 'lime', row(icn('egg_golden', 50), bl('HATCH (BIGGER ODDS)' if over else 'HATCH NOW', 26 if over else 36)), name='BtnHatch')
    b += well(26, 668, 1448, 92, hb, name='HatchBar', solid=True)
    pn = panel('Incubator', 'lime', 'Incubator', 'incubator', b, 210, 104, 1500, 884)
    return pn if bare else world('bg_lobby_blur.jpg', False) + dim() + pn


def egg_inc_phone(scale=1.1, **kw):
    """844 x 390 (2.16:1) = 2337 x 1080 design px (open with ?raw): the incubator panel at the phone scale (1.2, the
    most that fits: the title plate's top (y 55) to the panel's bottom is ~935 px)."""
    PW = 2337
    h = egg_incubator_over(bare=True, **kw)
    out = f"<style>#stage{{width:{PW}px!important}}</style>"
    out += f"<div class='abs' style='left:0;top:0;width:{PW}px;height:1080px;overflow:hidden;background:#000'>"
    out += f"<img class='world' src='bg_lobby_blur.jpg' style='position:absolute;left:0;top:0;width:{PW}px;height:1080px;object-fit:cover'>"
    out += "<div class='abs fill' style='background:rgba(26,6,48,.42)'></div>"
    top = (1080 - 935 * scale) / 2 - 55 * scale
    out += (f"<div class='abs' style='left:{(PW - 1920 * scale) / 2:.0f}px;top:{top:.0f}px;width:1920px;height:1080px;"
            f"transform:scale({scale});transform-origin:0 0'>{h}</div>")
    return out + '</div>'


def egg_first_pet():
    """Economy Decisions #15: the first egg a player wins gives a free Common pet of a family they choose (outside the
    incubator egg). Shown over the incubator once, after the first shard."""
    base = egg_incubator(fill=1, shards={'rare': 1, 'epic': 0, 'legendary': 0})
    c = f"<div class='ch a-gold' style='height:96px'><div class='sweep'></div><div class='lbl'>{T('YOUR FIRST PET IS FREE!', 46, 'l', name='Title')}</div></div>"
    c += at(430, 118, T('You won your first egg. Pick a family:', 28, 's', name='Body'), w=800, align='center')
    for i, (fam, ic, species) in enumerate([('Decoy', 'ab_decoy', 'Mouse'), ('Invisibility', 'ab_invis', 'Prism Chameleon')]):
        x = 120 + i * 340
        c += sub(f'Pick_{fam}', slot(x, 170, 260, 'common', ic, label=fam, cls='', name='Tile', art_pad=.16, label_size=26)
                 + at(x + 130, 436, T(f'Common {species}', 20, 's', 'f-common', name='SpeciesText'), w=320, align='center'), btn=True)
    c += selring(120, 170, 260, 260, 'PickSel')
    c += btn(250, 478, 360, 86, 'lime', bl('CLAIM', 38), name='BtnClaim')
    base = f"<div class='abs fill' style='z-index:0;isolation:isolate'>{base}</div>"
    return base + "<div class='abs fill' style='z-index:5;isolation:isolate'>" + dim(.5) + grp('FirstPet', f"<div class='cp a-gold' data-n='Card' style='left:530px;top:200px;width:860px;height:590px'>{c}</div>", 'C') + "</div>"


# ----- match pages
def egg_match_bg():
    """The live match capture, its old egg card covered by the new one (blurred stand-in under it)."""
    h = world('cap_match_field.jpg', False)
    h += "<div class='abs' style='left:0;top:820px;width:372px;height:260px;backdrop-filter:blur(22px);background:rgba(40,120,40,.35)'></div>"
    return h


def egg_s_card_states():
    """Every HUD egg card state: 4 rarities x charge 0 / 0.5 / 1, Catcher stash states, and the 3- vs 4-segment option."""
    out = "<div class='abs fill' style='background:linear-gradient(#3a1a66,#1e0a3e)'></div>"
    out += cap(40, 16, 'HUD egg card: rarity x charge (4 segments: option B, approved 17 Oct). The diamonds are gone: the name + colour say the rarity.')
    for j, ch in enumerate([0, .5, 1]):
        out += cap(40 + j * 400, 46, ['charge 0', 'charge 0.5 (2 jukes, or 1 revive)', 'charge 1.0 (full: Hero, or 2 jukes + revive)'][j])
    for i, r in enumerate(['common', 'rare', 'epic', 'legendary']):
        for j, ch in enumerate([0, .5, 1]):
            if r == 'common' and ch > 0:
                continue   # a Common egg only exists before the first safety: it can charge, shown at 0.5 once
            out += egg_card(r, ch, x=40 + j * 400, y=80 + i * 210)
    out += egg_card('common', .25, x=440, y=80) + cap(800, 120, '<- 1 juke (0.25)')
    out += cap(1260, 46, 'Catcher: the stash (best snatch) and the +1 cap')
    out += egg_card(role='catcher', snatched=None, cap='epic', x=1260, y=80)
    out += egg_card(role='catcher', snatched='rare', cap='epic', x=1260, y=290)
    out += egg_card(role='catcher', snatched='epic', cap='legendary', x=1260, y=500)
    out += cap(1260, 710, 'Option B: 4 segments (one per juke, 0.25 each)')
    out += egg_card('rare', .5, segs=4, x=1260, y=740)
    out += egg_card('epic', .75, segs=4, x=1260, y=940)
    return out


def egg_s_noroll():
    """No roll (17 Oct ~18:47): the HUD card's two-mark meter through a match, NEXT SAFE tags, the new banners and tip."""
    out = "<div class='abs fill' style='background:linear-gradient(#3a1a66,#1e0a3e)'></div>"
    out += cap(40, 16, 'One meter a match: marks at 2.0 (EPIC) and 5.0 (LEGENDARY). A passed mark steps the shard up once at the next safe. No random chance.')
    seq = [('rare', 0, None, 'Rare after crossing 1, meter empty'), ('rare', 1.25, None, '5 jukes later: 1.25'),
           ('rare', 2.0, 'epic', 'Mark 1 passed: the tag says what the next safe gives'), ('epic', 2.5, None, 'Safe: now EPIC; the meter keeps going'),
           ('epic', 5.0, 'legendary', 'Mark 2 passed'), ('legendary', 5.0, None, 'Safe: LEGENDARY (both marks spent)')]
    for i, (r, ch, nxt, label) in enumerate(seq):
        x, y = 40 + (i % 3) * 420, 110 + (i // 3) * 260
        out += cap(x, y - 34, label)
        out += egg_card(r, ch, x=x, y=y + 30)
        if nxt:
            out += f"<div class='ctag k-{EGG_R[nxt][4]}' style='left:{x + 12}px;top:{y + 4}px;height:34px'>{T('NEXT SAFE: ' + EGG_R[nxt][5], 17, 'xs')}</div>"
    out += cap(1000, 650, 'Upgrade banner (instead of SAFE!)')
    out += egg_banner('epic', 1040, 720) + egg_banner('legendary', 1040, 880)
    out += cap(40, 650, 'The one-time tip, on the first meter fill')
    out += egg_tutorial(40, 690)
    out += cap(40, 840, 'Fill: juke +0.25 (2 a crossing), revive +0.5, Hero +2.0. New players (first 10 h) x1.5.')
    return out


def egg_s_match():
    """In context, over the real match capture: the new card (Rare, half charged), +10 PTS Juke! with +CHARGE beside it,
    and the one-time tutorial card."""
    out = egg_match_bg()
    out += egg_card('rare', .5)
    out += pts_place(pts_pop('juke'), 1120, 420) + egg_charge_pop(1346, 430)
    out += egg_tutorial(560, 196)
    return out


def egg_s_roll():
    """The roll at safety: about 1 s on the egg itself (the card's egg flickers through rarity colours; the egg on your
    back does the same in VFX), then either the existing SAFE! line (no upgrade) or the EPIC EGG! banner (upgrade).
    Section 10: an early Runners win adds BONUS ROLLS xN on the card (same flicker, banner only on an upgrade)."""
    out = "<div class='abs fill' style='background:linear-gradient(#3a1a66,#1e0a3e)'></div>"
    out += cap(40, 12, '1. Entering safety: the card egg flickers ~1 s (frames 0.0 / 0.33 / 0.66 s). Play never pauses.')
    for i, (r, t) in enumerate([('rare', '0.0 s'), ('epic', '0.33 s'), ('legendary', '0.66 s')]):
        out += egg_card(r, 1, x=40 + i * 400, y=46)
        out += cap(60 + i * 400, 230, t)
    out += cap(1260, 12, '3. Early Runners win (section 10): bonus rolls')
    bn = egg_card('rare', 0, x=1260, y=46)
    bn += f"<div class='ctag k-lime' data-n='BonusTag' style='left:1260px;top:232px;height:34px'>{T('RUNNERS WIN: BONUS ROLLS x2', 17, 'xs', name='BonusText')}</div>"
    out += bn + cap(1580, 236, 'one flicker per roll, ~1 s each')
    out += cap(40, 300, '2a. No upgrade: the existing SAFE! banner only ("You made it across"); the meter empties.')
    out += banner_card(40, 366, 820, 'SAFE!', 'You made it across', 'lime', 'egg_shiny', 'Banner')
    out += egg_card('rare', 0, x=920, y=342)
    out += cap(40, 532, '2b. Upgrade: the egg-grew banner style, in the rarity colour (only on an upgrade). Crossing 1 is always RARE EGG!')
    out += egg_banner('rare', 40, 598) + egg_banner('legendary', 40, 778)
    out += egg_card('epic', 0, x=920, y=574) + egg_card('legendary', 0, x=920, y=766)
    out += cap(1300, 600, 'The banner replaces SAFE! on an upgrade:')
    out += cap(1300, 630, 'one banner per safety, never two.')
    out += cap(1300, 680, 'EPIC EGG! is the same banner in purple.')
    return out


def egg_s_incubator(state='filling'):
    if state == 'filling':
        return egg_incubator_over(12, shards={'rare': 8, 'epic': 2, 'legendary': 0})   # every state on the page (UI_EXPORT=1)
    if state == 'focus':
        return egg_incubator(31, {'rare': 13, 'epic': 5, 'legendary': 0}, 'Decoy', 'filling')
    if state == 'ready':
        return egg_incubator(32, {'rare': 14, 'epic': 6, 'legendary': 0}, 'Any', 'ready')
    if state == 'hatching':
        return egg_incubator(32, {'rare': 14, 'epic': 6, 'legendary': 0}, 'Any', 'hatching')
    if state == 'legendary':   # later, once a Legendary pet exists (switches on by itself)
        return egg_incubator(26, {'rare': 10, 'epic': 2, 'legendary': 1}, 'Any', 'filling', legendary_open=True)
    return ''


def egg_s_results():
    """The one results screen (Match Points) with the shard row replacing the piece row; then the crack + core-fly frames."""
    h = pts_s_board()
    h = h.replace("data-t='+1 Epic piece'", "data-t='+1 EPIC SHARD'").replace('>+1 Epic piece<', '>+1 EPIC SHARD<')
    h = h.replace("data-n='PieceText'", "data-n='ShardText'").replace("data-n='PieceIcon'", "data-n='ShardIcon'")
    # the small incubator egg the core flies to (ring fills by the shard's weight: 18 -> 21 / 30)
    mini = egg_ring(1652, 712, 22, 21 / 30, '#7cf05a', 7, 'MiniRing') + I('egg_starter', 1638, 694, 28, 34, name='MiniEgg')
    mini += at(1652, 738, T('21 / 30 FILL', 13, 'xs', name='MiniFill'), w=120, align='center')
    return h + grp('ShardFly', mini, 'R')


def egg_s_results_frames():
    """Results: the egg icon cracks, its glowing core flies to the small incubator egg, whose ring fills (UI space)."""
    out = "<div class='abs fill' style='background:linear-gradient(#3a1a66,#1e0a3e)'></div>"
    beats = [('0.0 s  egg', 'egg_cosmic', None, 18), ('0.3 s  crack', 'piece_epic', None, 18), ('0.6 s  core flies', 'piece_epic', 'core', 18),
             ('0.9 s  ring fills', 'piece_epic', None, 21)]
    for i, (lab, ic, core, f) in enumerate(beats):
        x = 60 + i * 460
        out += cap(x, 40, lab)
        out += slot(x, 90, 150, 'epic', ic, name=f'Beat{i}', art_pad=.08)
        if core:
            out += f"<div class='abs' style='left:{x + 200}px;top:130px;width:46px;height:46px;border-radius:50%;background:radial-gradient(#fff,#c88aff 55%,rgba(200,138,255,0));box-shadow:0 0 30px 10px #c88aff'></div>"
        out += egg_ring(x + 340, 165, 40, f / 30, '#7cf05a', 10, 'MiniRing') + I('egg_starter', x + 316, 135, 48, 58)
        out += at(x + 340, 222, T(f'{f} / 30 FILL', 18, 'xs'), w=200, align='center')
    out += cap(60, 300, 'Reduce effects: no flight, the ring just steps up. The row text stays "+1 EPIC SHARD" (shard icon + words).')
    for i, r in enumerate(['common', 'rare', 'epic', 'legendary']):
        ic, sh, rs, f, k, word = EGG_R[r]
        out += at(60 + i * 460, 360, row(icn(sh, 36), T(f'+1 {word} SHARD', 24, 's', f), gap=6))
    out += cap(60, 430, 'Caught with nothing snatched: the egg row says it and pays no shard.')
    out += at(60, 470, col(T('NO EGG THIS MATCH', 34, 'l', 'f-dim'), T('Snatch an egg as a Catcher to keep one', 18, 'xs', 'f-dim'), gap=2, align='flex-start'))
    return out


def egg_s_lobby():
    """Lobby: READY TO HATCH on the incubator button (data-driven: only while the egg is full) + the goal pill."""
    h = s_hud()
    badge = (f"<div class='ctag k-gold' data-n='ReadyBadge' style='left:560px;top:72px;height:34px'>{T('READY TO HATCH', 17, 'xs')}</div>")
    h += grp('IncubatorBadge', badge, 'TL')
    return h


def egg_s_phone():
    """Phone (844 x 390 -> 1920-wide design at ~0.46x): the card 1.3x, and the incubator panel (fits as-is, k = 1)."""
    out = egg_match_bg()
    out += f"<div class='abs' style='left:0;top:0;transform:scale(1.3);transform-origin:12px 1056px'>{egg_card('epic', .5)}</div>"
    out += cap(500, 980, 'Phone: card at 1.3x (text >= 20 design px on the rarity line, 15 -> 19.5 on the small lines)')
    return out


def egg_s_compare():
    """Beside the existing EOSUI: the round header + best-egg card (live capture) next to the new card, at 1920 and 1366."""
    out = world('cap_match_field.jpg', False)
    out += egg_card('rare', .5, x=360, y=878)
    out += cap(360, 846, 'new card (right of the live one, same plate and size)')
    out += f"<div class='abs' style='left:1100px;top:540px;width:780px;height:440px;overflow:hidden;border:3px solid #050506'>" \
           f"<div style='transform:scale({1366 / 1920:.3f});transform-origin:0 0;width:1920px;height:1080px;position:relative'>{egg_match_bg()}{egg_card('rare', .5)}</div></div>"
    out += cap(1100, 990, '1366 x 768 (scaled)')
    return out


# ----- results: the shard as "+N FILL" (Hunter 17 Oct 18:02; MOCKUP ONLY until he approves). Fills the egg block of the
# match-points thread's Results v2 (rv_body's EggBlock well, 440 x 140): only that block's shard line changes, their
# layout is untouched (these pages swap the block's contents in their rendered screen). Data-driven like the runtime:
# name, colour and weight per rarity mirror Shared.EggConfig RARITY_INFO / SHARD_WEIGHT; EggUIController will read
# EggConfig itself, so a new rarity needs no UI change. Units rule: "+8 FILL", "17 / 18 FILL".
EGG_CFG = {  # rarity -> (EggConfig.RARITY_INFO name, rgb, EggConfig.SHARD_WEIGHT)
    'common': ('Common', (142, 240, 122), 0.5), 'rare': ('Rare', (92, 200, 255), 1),
    'epic': ('Epic', (200, 138, 255), 2), 'legendary': ('Legendary', (255, 210, 58), 8),
}
EGG_NEED = 18  # EggConfig.INCUBATOR.FILL (17 Oct: 18)


def egg_num(v):
    return f'{v:g}'


def egg_rgb(rgb, k):
    """k > 0 mixes toward white, k < 0 toward black."""
    t = 255 if k > 0 else 0
    return '#%02x%02x%02x' % tuple(int(c + (t - c) * abs(k)) for c in rgb)


def egg_fill_pill(r, size=26, name='FillPill'):
    """The shard's reward: shard icon + "+N FILL" on a pill in the rarity colour (like the points pill: gradient, dark rim, lip)."""
    _, rgb, w = EGG_CFG[r]
    h = int(size * 1.45)
    return (f"<span data-n='{name}' style='position:relative;display:inline-flex;align-items:center;gap:{int(size * .18)}px;height:{h}px;"
            f"padding:0 {int(size * .45)}px 0 {int(size * .2)}px;border-radius:{h // 2}px;"
            f"background:linear-gradient({egg_rgb(rgb, .35)},{egg_rgb(rgb, -.12)});box-shadow:0 0 0 3px #050506,0 {max(3, int(size * .12))}px 0 {egg_rgb(rgb, -.5)};flex:none'>"
            f"{icn(PTS_PIECE[r], int(size * 1.2), name='ShardIcon')}{T(f'+{egg_num(w)} FILL', size, 's', name='FillText')}</span>")


# Results v2 owns the egg block's layout (rv_body: RV_EGG_W wide, the shard line a fixed RV_SHARD_W box at (148, 86),
# the mini ring at the right). We only change what EggUIController writes: the egg's rarity, the shard line and the mini
# fill. These pieces are rebuilt with their exact calls so a layout change on their side trips the asserts below.
def egg_rv_parts(r='rare', shard_line=None, mini=None):
    ic, _, rs, fill, _, word = EGG_R[r]
    ew = RV_EGG_W
    p = {
        'slot': slot(12, 10, 120, rs, ic, name='EggSlot', art_pad=.08),
        'text': at(148, 12, T(f'{word} EGG', 34, 'l', fill, name='EggText')),
        'line': shard_line or at(148, 86, row(icn('piece_rare', 36, name='PieceIcon'), T('+1 RARE SHARD', 24, 's', 'f-rare', name='PieceText',
                                                                                         style=f'display:inline-block;width:{RV_SHARD_W}px'), gap=6)),
    }
    f, need = mini or (21, 30)
    gold = f >= EGG_NEED if mini else f >= need
    p['ring'] = egg_ring(ew - 40, 104, 18, min(1, f / need), '#ffd23a' if gold and mini else '#7cf05a', 7, 'MiniRing') + \
        I('egg_golden' if gold and mini else 'egg_starter', ew - 51, 90, 22, 27, name='MiniEgg')
    p['fill'] = at(ew - 52, 50, T(f'{egg_num(f)} / {egg_num(need)} FILL', 14, 'xs', 'f-gold' if gold and mini else 'f-dim', name='MiniFill'), w=110, align='center')
    return p


def egg_shard_line(r):
    """The new shard line, inside Results v2's shard box: the +N FILL pill (shard icon inside) and a small rarity word."""
    name, _, _ = EGG_CFG[r]
    fill = EGG_R[r][3]
    word = col(T(name.upper(), 15, 'xs', fill, name='ShardWord'), T('SHARD', 15, 'xs', 'f-dim', name='ShardWord2'), gap=0, align='flex-start')
    return at(148, 82, row(egg_fill_pill(r, 24), word, gap=8), name='ShardLine')


def egg_mini(before, r):
    """The results mini egg after this shard: x / 18 FILL until it can hatch, then x / 36 FILL (gold) up to the cap."""
    f = min(before + EGG_CFG[r][2], EGG_NEED * 2)
    return (f, EGG_NEED if f < EGG_NEED else EGG_NEED * 2)


def egg_rv_swap(html, r, before=9):
    """Results v2 rendered by its own code, with only our three writes changed (rarity, shard line, mini fill)."""
    old, new = egg_rv_parts('rare'), egg_rv_parts(r, egg_shard_line(r), egg_mini(before, r))
    for k in ('slot', 'text', 'line', 'ring', 'fill'):
        assert old[k] in html, f'Results v2 egg block changed ({k}): re-read rv_body before swapping'
        html = html.replace(old[k], new[k], 1)
    return html


def egg_block_now():
    p = egg_rv_parts('rare')
    return p['slot'] + p['text'] + at(150, 56, T('Safe to the end', 20, 'xs', 'f-dim', name='EggHow')) + p['line'] + p['ring'] + p['fill']


def egg_block_fill(r, before=9):
    p = egg_rv_parts(r, egg_shard_line(r), egg_mini(before, r))
    return p['slot'] + p['text'] + at(150, 56, T('Safe to the end', 20, 'xs', 'f-dim', name='EggHow')) + p['line'] + p['ring'] + p['fill']


def egg_s_fill_states():
    """Today's shard line beside the four new ones (live EggConfig weights), each block at 1.5x, mini egg 9 -> after / 18."""
    out = "<div class='abs fill' style='background:linear-gradient(#2a1650,#140a2c)'></div>"
    def blk(x, y, inner, label):
        return cap(x, y - 74, label) + f"<div class='abs' style='left:{x}px;top:{y}px;transform:scale(1.4);transform-origin:0 0'>{well(0, 0, RV_EGG_W, 140, inner, title='EGG')}</div>"
    out += blk(60, 90, egg_block_now(), 'NOW (Results v2 egg block): +1 RARE SHARD')
    for i, r in enumerate(['common', 'rare', 'epic', 'legendary']):
        x, y = 60 + (i % 2) * 920, 390 + (i // 2) * 300
        out += blk(x, y, egg_block_fill(r), f'NEW: {EGG_CFG[r][0]} shard  +{egg_num(EGG_CFG[r][2])} FILL  (9 -> {egg_num(min(9 + EGG_CFG[r][2], EGG_NEED))} / {EGG_NEED})')
    out += cap(980, 120, 'Pill colour, icon, word and number come from EggConfig (RARITY_INFO, SHARD_WEIGHT):')
    out += cap(980, 150, 'a new rarity needs no UI change. Only the shard line, the egg and the mini fill change;')
    out += cap(980, 180, 'Results v2 keeps its layout. A shard that fills the egg turns the mini egg gold.')
    return out


def egg_s_fill_results():
    return egg_rv_swap(rv_screen(tab='points'), 'legendary')


def egg_s_fill_phone():
    return egg_rv_swap(rv_phone(tab='points'), 'epic')


# ----- export pages (UI_EXPORT=1: every runtime state on the page, hidden ones too). ui_egg/rbx.json. Not on the index;
# written by docs/HOS-EGG-002/tools/build_egg_export.py so the other pages are untouched.
def egg_x_hud():
    """Screen EggHUD (hud): the egg card in every look (Runner_<rarity>, Catcher, CatcherEmpty; one shown at a time)
    + the bonus-rolls tag, and the one-time tip (top centre). EggUIController hides EOSUI MatchHUD.Egg while it shows."""
    card = ''
    for r in ['common', 'rare', 'epic', 'legendary']:
        card += sub(f'Runner_{r}', egg_card(r, EGG_MCAP), hid=r != 'rare')   # fills exported full: runtime sizes each Seg's Fill
    card += sub('Catcher', egg_card(role='catcher', snatched='rare', cap='epic'), hid=True)
    card += sub('CatcherEmpty', egg_card(role='catcher', snatched=None, cap='epic'), hid=True)
    card += sub('BonusTag', f"<div class='ctag k-gold' style='left:12px;top:838px;height:34px'>{T('NEXT SAFE: LEGENDARY', 17, 'xs', name='BonusText')}</div>", hid=True)   # no roll: the next safe's step
    out = grp('EggCard', card, 'BL')
    out += grp('EggTip', sub('Tip', egg_tutorial(560, 196), hid=True), 'T')
    return out


def egg_x_incubator():
    """Screen EggIncubator (panel): the incubator egg; replaces opening EOSUI's Incubator while EggConfig.ENABLED."""
    return egg_incubator_over(12, shards={'rare': 8, 'epic': 2, 'legendary': 0})   # every state on the page (UI_EXPORT=1)


def egg_x_first_pet():
    """Screen EggFirstPet (panel): the free first pet card, over the incubator."""
    h = egg_first_pet()
    i = h.index("<div class='abs fill' style='z-index:5;isolation:isolate'>")
    return h[i:]


def egg_x_templates():
    """Runtime templates (ReplicatedStorage.EggUITemplates): +CHARGE pop, the three upgrade banners, READY TO HATCH badge,
    the results shard row with its small incubator egg."""
    out = "<div class='abs fill' style='background:linear-gradient(#3a1a66,#1e0a3e)'></div>"
    out += grp('ChargePop', egg_charge_pop(40, 40), 'TL')
    for i, r in enumerate(['rare', 'epic', 'legendary']):
        out += grp(f'EggBanner_{r}', egg_banner(r, 40, 140 + i * 160), 'TL')
    out += grp('ReadyBadge', f"<div class='ctag k-gold' data-n='Badge' style='left:1000px;top:40px;height:34px'>{T('READY TO HATCH', 17, 'xs', name='BadgeText')}</div>", 'TL')
    sr = at(1000, 140, row(icn('piece_epic', 36, name='ShardIcon'), T('+1 EPIC SHARD', 24, 's', 'f-epic', name='ShardText'), gap=6))
    sr += egg_ring(1300, 158, 22, 21 / 30, '#7cf05a', 7, 'MiniRing') + I('egg_starter', 1286, 140, 28, 34, name='MiniEgg')
    sr += at(1300, 184, T('21 / 30 FILL', 13, 'xs', name='MiniFill'), w=120, align='center')
    out += grp('ShardRow', sr, 'TL')
    # Fixes (17 Oct): the results shard line as "+N FILL" (pill in the rarity colour + the small rarity word), one per rarity;
    # EggResultsRow clones one into Results v2's EggBlock in place of PieceIcon / PieceText
    for i, r in enumerate(['common', 'rare', 'epic', 'legendary']):
        name, _, _ = EGG_CFG[r]
        word = col(T(name.upper(), 15, 'xs', EGG_R[r][3], name='ShardWord'), T('SHARD', 15, 'xs', 'f-dim', name='ShardWord2'), gap=0, align='flex-start')
        out += grp(f'FillLine_{r}', at(1000, 260 + i * 70, row(egg_fill_pill(r, 24), word, gap=8)), 'TL')
    return out


EGG_EXPORT = [('egg_x_hud.html', egg_x_hud, 1080), ('egg_x_incubator.html', egg_x_incubator, 1080),
              ('egg_x_first_pet.html', egg_x_first_pet, 1080), ('egg_x_templates.html', egg_x_templates, 1080)]


SCREENS += [
    ('egg_card_states.html', 'Egg plan: HUD egg card', 'HOS-EGG-002: rarity x charge, Catcher stash and cap, 3 vs 4 segments', egg_s_card_states, 1160),
    ('egg_match.html', 'Egg plan: in match', 'The card over the live match, +CHARGE beside +10 PTS Juke!, the one-time tip', egg_s_match, 1080),
    ('egg_roll.html', 'Egg plan: roll at safety', 'The 1 s flicker, SAFE! (no upgrade) and the RARE / EPIC / LEGENDARY EGG! banners', egg_s_roll, 1080),
    ('egg_incubator.html', 'Egg plan: incubator (filling)', '18 / 30 fill, shard counters, odds, focus Any, hatch greyed', lambda: egg_s_incubator('filling'), 1080),
    ('egg_incubator_focus.html', 'Egg plan: incubator (focused)', 'Focus on Decoy: 37.5 to fill (+25%)', lambda: egg_s_incubator('focus'), 1080),
    ('egg_incubator_ready.html', 'Egg plan: incubator (ready)', 'Full egg, HATCH! lit', lambda: egg_s_incubator('ready'), 1080),
    ('egg_incubator_hatching.html', 'Egg plan: incubator (hatching)', 'Pressed: the existing ceremony (Royal Hatching) plays next', lambda: egg_s_incubator('hatching'), 1080),
    ('egg_incubator_legendary.html', 'Egg plan: incubator (Legendary open)', 'Later, once a Legendary pet exists: Legendary odds show', lambda: egg_s_incubator('legendary'), 1080),
    ('egg_first_pet.html', 'Egg plan: first pet', 'After the first egg won: a free Common of a chosen family', egg_first_pet, 1080),
    ('egg_results.html', 'Egg plan: results', '+1 EPIC SHARD row and the small incubator egg it flies to', egg_s_results, 1080),
    ('egg_results_frames.html', 'Egg plan: results (frames)', 'Crack, core flies, ring fills; every shard row; nothing snatched', egg_s_results_frames, 1080),
    ('egg_lobby.html', 'Egg plan: lobby badge', 'READY TO HATCH on the incubator button', egg_s_lobby, 1080),
    ('egg_phone.html', 'Egg plan: phone', 'The card at phone scale over the match', egg_s_phone, 1080),
    ('egg_compare.html', 'Egg plan: beside the live HUD', 'New card next to the live one; 1366 x 768', egg_s_compare, 1080),
    ('egg_fill_states.html', 'Egg plan: shard as +FILL (states)', 'MOCKUP: today\'s "+1 RARE SHARD" beside +0.5 / +1 / +2 / +8 FILL', egg_s_fill_states, 1080),
    ('egg_fill_results.html', 'Egg plan: shard as +FILL (results 1920)', 'MOCKUP: Results v2 with the Legendary +8 FILL pill', egg_s_fill_results, 1080),
    ('egg_fill_phone.html', 'Egg plan: shard as +FILL (phone)', 'MOCKUP: Results v2 at phone size, Epic +2 FILL', egg_s_fill_phone, 1080),
    ('egg_over_100.html', 'Egg plan: overfill 100%', 'MOCKUP: 18 FILL, HATCH NOW, odds 80 / 16 / 4, Get Lucky Egg', lambda: egg_incubator_over(18, shards={'rare': 10, 'epic': 2, 'legendary': 0}), 1080),
    ('egg_over_150.html', 'Egg plan: overfill 150%', 'MOCKUP: 27 FILL, HATCH (BIGGER ODDS), 72 / 22 / 6', lambda: egg_incubator_over(27), 1080),
    ('egg_over_200.html', 'Egg plan: overfill 200%', 'MOCKUP: 36 FILL (max), 64 / 28 / 8', lambda: egg_incubator_over(36, shards={'rare': 14, 'epic': 5, 'legendary': 2}), 1080),
    ('egg_over_focus125.html', 'Egg plan: focused at 125%', 'MOCKUP: Decoy focus, 27 FILL - 4.5 = 125% odds, 76 / 19 / 5', lambda: egg_incubator_over(27, 'Decoy'), 1080),
    ('egg_over_lucky.html', 'Egg plan: Lucky Egg owned', 'MOCKUP: 150% with the pass, LUCKY +50%, 58 / 33 / 9', lambda: egg_incubator_over(27, lucky=True), 1080),
    ('egg_over_filling.html', 'Egg plan: overfill, still filling', 'MOCKUP: 12 FILL, 6 more to hatch, HATCH greyed', lambda: egg_incubator_over(12, shards={'rare': 8, 'epic': 2, 'legendary': 0}), 1080),
]


# ----- Fixes (17 Oct ~18:30, Hunter "make the fixes and then implement fully"): FILL only, bigger Lucky strip, boost ladder
def egg_s_fix_results(phone=False, r='epic', before=15):
    return egg_rv_swap((rv_phone if phone else rv_screen)(tab='points'), r, before)


EGG_FIX = [  # name, caption, kwargs
    ('filling', '12 / 36 FILL, 6 more to hatch, x2 ODDS, Get Lucky Egg', dict(fill=12, shards={'rare': 8, 'epic': 2, 'legendary': 0})),
    ('18', '18 / 36 FILL: HATCH NOW, x2 ODDS (none bought)', dict(fill=18, shards={'rare': 10, 'epic': 2, 'legendary': 0})),
    ('27', '27 / 36 FILL, x2 owned: UPGRADE TO x3, x2 BOOST tag', dict(fill=27, boost=1)),
    ('36', '36 / 36 FILL (MAX), x3 owned: UPGRADE TO x4, x3 BOOST tag', dict(fill=36, boost=2, shards={'rare': 14, 'epic': 5, 'legendary': 2})),
    ('maxed', '27 FILL, Lucky owned + x4: x4 MAXED (disabled), LUCKY and x4 BOOST tags, Legendary at the 20% cap', dict(fill=27, boost=3, lucky=True)),
    ('focus', 'Decoy focus at 27 FILL: odds at 22.5 fill, Lucky owned, no boost', dict(fill=27, focus='Decoy', lucky=True)),
]
for _n, _c, _k in EGG_FIX:
    SCREENS.append((f'egg_fix_{_n}.html', f'Egg fixes: incubator {_n}', _c, (lambda k=_k: egg_incubator_over(**k)), 1080))
    SCREENS.append((f'egg_fix_{_n}_phone.html', f'Egg fixes: incubator {_n} (phone)', _c + ' (844 x 390)', (lambda k=_k: egg_inc_phone(**k)), 1080))
SCREENS += [
    ('egg_noroll_states.html', 'Egg: no roll, two-mark meter', 'MOCKUP: EPIC at 2.0, LEGENDARY at 5.0, NEXT SAFE tags, SHARD UPGRADED banners', egg_s_noroll, 1080),
    ('egg_fix_results.html', 'Egg fixes: results egg row', 'Epic shard +2 FILL, mini egg 15 -> 17 / 18 FILL', lambda: egg_s_fix_results(False, 'epic', 15), 1080),
    ('egg_fix_results_phone.html', 'Egg fixes: results egg row (phone)', 'Legendary +8 FILL past hatch: 19 -> 27 / 36 FILL (gold)', lambda: egg_s_fix_results(True, 'legendary', 19), 1080),
]


# ================================================================== Shard intro (17 Oct ~19:25, Hunter approved the idea; MOCKUP ONLY)
# The match-start egg breaks into shards that land on every Runner's back; the back egg becomes a chunky glowing shard in
# its rarity colour (recolours on upgrade); the HUD egg card becomes a shard card. Kill switch: GameConfig SHARD_INTRO_ENABLED.
SH_BACKS = [(300, 577, 56, 'rare'), (570, 577, 46, 'rare'), (885, 632, 52, 'epic'), (1590, 737, 72, 'rare'), (1812, 674, 62, 'legendary')]   # capture stretched 1026 -> 1080


def shard_glow(cx, cy, d, r):
    g = EGG_GLOW[r]
    return (f"<div class='abs' style='left:{cx - d:.0f}px;top:{cy - d:.0f}px;width:{2 * d:.0f}px;height:{2 * d:.0f}px;"
            f"background:radial-gradient({g}cc 25%, {g}00 70%)'></div>")


def shard_on_back(cx, cy, d, r):
    """The back shard drawn over the old egg: a chunky shard (the kit's piece art) with a soft glow in its rarity colour."""
    s_ = d * 2.3
    return shard_glow(cx, cy, d * 1.5, r) + I(EGG_R[r][1], cx - s_ / 2, cy - s_ / 2, s_)


def shard_card(rarity='rare', charge=0.0, x=12, y=878, nxt=None):
    """The HUD card as a shard: same glass plate, slot shows the shard, 'YOUR SHARD', the two-mark meter."""
    h = egg_card(rarity, charge, x=x, y=y)
    h = h.replace("data-t='YOUR EGG'", "data-t='YOUR SHARD'").replace('>YOUR EGG<', '>YOUR SHARD<')
    h = h.replace(ipath(EGG_R[rarity][0]), ipath(EGG_R[rarity][1]), 1)
    if nxt:
        h += f"<div class='ctag k-{EGG_R[nxt][4]}' style='left:{x + 12}px;top:{y - 30}px;height:34px'>{T('NEXT SAFE: ' + EGG_R[nxt][5], 17, 'xs')}</div>"
    return h


def sh_crop_bg():
    """The start line (the capture's upper middle, no eggs in it), 2x."""
    return ("<div class='abs' style='left:0;top:0;width:1920px;height:1080px;overflow:hidden'>"
            "<img src='cap_match_field.jpg' style='position:absolute;left:-1240px;top:-60px;width:3840px;height:2052px'></div>")


def sh_bars(t='', sub_=''):
    out = "<div class='abs' style='left:0;top:0;width:1920px;height:110px;background:#05070a'></div>"
    out += "<div class='abs' style='left:0;top:970px;width:1920px;height:110px;background:#05070a'></div>"
    if t:
        out += at(960, 994, T(t, 30, 's'), w=1600, align='center') + at(960, 1036, T(sub_, 20, 'xs', 'f-dim'), w=1600, align='center')
    return out


def sh_backs_layer(rarity_of):
    out = "<img src='cap_match_field.jpg' style='position:absolute;left:0;top:0;width:1920px;height:1080px'>"
    for cx, cy, d, r in SH_BACKS:
        out += shard_on_back(cx, cy, d, rarity_of(r))
    out += "<div class='abs' style='left:10px;top:872px;width:346px;height:184px;background:#202024;border-radius:6px'></div>"  # the old card under it
    return out


def sh_frame(n):
    """Storyboard frame n (1..4) of the ~3 s intro."""
    import math
    if n == 4:
        out = sh_backs_layer(lambda r: 'common') + shard_card('common', 0, x=12, y=784)
        return out + sh_bars('4 · LAND (2.4 - 3.0 s)', 'Each Runner wears a Common shard; the camera eases back to play; the HUD card pops in')
    out = sh_crop_bg()
    ex, ey, es = 960, 400, 260
    if n == 1:
        out += shard_glow(ex, ey, 230, 'common') + I('egg_basic', ex - es / 2, ey - es / 2 - 10, es, es * 1.1)
        out += sh_bars('1 · FLOAT (0 - 0.8 s)', 'An egg rises over the start line; the camera eases up to it (slow, no shake)')
    elif n == 2:
        out += shard_glow(ex, ey, 280, 'common') + I('egg_basic', ex - es / 2, ey - es / 2 - 10, es, es * 1.1)
        for ang, ln in [(-28, 120), (12, 150), (54, 110), (100, 130), (150, 120), (210, 140)]:
            out += (f"<div class='abs' style='left:{ex}px;top:{ey}px;width:{ln}px;height:6px;background:#1b1b1b;"
                    f"transform-origin:0 50%;transform:rotate({ang}deg);border-radius:3px;box-shadow:0 0 0 2px #ffffff88'></div>")
        out += sh_bars('2 · CRACK (0.8 - 1.4 s)', 'Cracks spread (AllVFX crack + dust textures); a soft glow, no flash')
    else:
        targets = [(260, 900), (620, 930), (960, 950), (1300, 930), (1660, 900)]
        for tx, ty in targets:
            for k in range(1, 6):
                t = k / 6
                px = ex + (tx - ex) * t
                py = ey + (ty - ey) * t - math.sin(t * math.pi) * 220
                out += f"<div class='abs' style='left:{px - 5:.0f}px;top:{py - 5:.0f}px;width:10px;height:10px;border-radius:5px;background:#ffffff{int(60 + 30 * k):02x}'></div>"
            t = .72
            px = ex + (tx - ex) * t
            py = ey + (ty - ey) * t - math.sin(t * math.pi) * 220
            out += shard_glow(px, py, 70, 'common') + I('piece_common', px - 55, py - 55, 110)
        out += sh_bars('3 · SCATTER (1.4 - 2.4 s)', 'The shards arc out to every Runner (one each); the camera follows down to the field')
    return out


def sh_s_storyboard():
    out = "<div class='abs fill' style='background:#140a2c'></div>"
    for i in range(4):
        x, y = 16 + (i % 2) * 952, 16 + (i // 2) * 532
        out += f"<div class='abs' style='left:{x}px;top:{y}px;width:1920px;height:1080px;transform:scale(.4875);transform-origin:0 0;overflow:hidden'>{sh_frame(i + 1)}</div>"
    return out


def sh_s_backs():
    out = sh_backs_layer(lambda r: r) + shard_card('epic', 2.5, x=12, y=874)
    out += cap(1060, 150, 'Back shards in their rarity colour (Rare, Rare, Epic, Rare, Legendary)')
    out += cap(1060, 186, 'A shard recolours when it steps up; a Catcher snatches the shard')
    return out


def sh_s_cards():
    out = "<div class='abs fill' style='background:linear-gradient(#3a1a66,#1e0a3e)'></div>"
    out += cap(40, 16, 'HUD card as a shard, each rarity (with the no-roll two-mark meter)')
    for i, (r, ch, nx) in enumerate([('common', 0.25, None), ('rare', 1.25, None), ('rare', 2.0, 'epic'), ('epic', 3.5, None), ('epic', 5.0, 'legendary'), ('legendary', 5.0, None)]):
        out += shard_card(r, ch, x=40 + (i % 3) * 420, y=120 + (i // 3) * 300, nxt=nx)
    return out


SCREENS += [
    ('shard_intro_storyboard.html', 'Shard intro: storyboard', 'MOCKUP: float, crack, scatter, land (~3 s, comfort camera)', sh_s_storyboard, 1080),
    ('shard_backs.html', 'Shard intro: shards on backs', 'MOCKUP: chunky glowing shard per rarity on each Runner, shard HUD card', sh_s_backs, 1080),
    ('shard_cards.html', 'Shard intro: HUD shard card', 'MOCKUP: the card as a shard in each rarity', sh_s_cards, 1080),
]


# ----- phone fixes (17 Oct ~20:10): the HUD card in compact (plate hugs slot + word + meter; Controllers.EggShardMeter)
# and the results shard line on a narrow EggBlock (one bigger rarity word; EggResultsRow). Mirrors the runtime.
def egg_card_compact(rarity='rare', charge=1.25, x=12, y=160):
    ic, sh, rs, fill, colk, word = EGG_R[rarity]
    big = 44 if len(word) <= 4 else (38 if len(word) <= 6 else 31)
    eg = f"<div class='glass' style='left:{x}px;top:{y}px;width:340px;height:134px'></div>"
    eg += egg_glow_slot(x + 14, y + 20, 100, rarity, charge)
    tx = x + 128
    eg += at(tx, y + 22, T(word, big, 'l', fill, name='EggLevel'))
    eg += I('sparkle', tx, y + 80, 26, name='ChargeIcon')
    eg += egg_meter_marks(tx + 32, y + 83, charge, w=168).replace("font-size:13px", "font-size:0px")
    return eg


def egg_shard_line_narrow(r):
    name, _, _ = EGG_CFG[r]
    return at(148, 80, row(egg_fill_pill(r, 24), T(name.upper(), 22, 'xs', EGG_R[r][3], name='ShardWord'), gap=8), name='ShardLine')


def egg_s_phone_hud():
    """844 x 390 = 2337 x 1080 design: the match capture, Roblox's top-left buttons, the compact card under them."""
    PW = 2337
    out = f"<style>#stage{{width:{PW}px!important}}</style>"
    out += f"<img src='cap_match_field.jpg' style='position:absolute;left:0;top:0;width:{PW}px;height:1080px;object-fit:cover'>"
    out += "<div class='abs' style='left:0;top:820px;width:420px;height:260px;background:#3fbf3f'></div>"
    out += f"<div class='abs' style='transform:scale(1.25);transform-origin:0 0;left:0;top:0;width:1px;height:1px'>{egg_card_compact('rare', 1.25, 12, 150)}</div>"
    return out


def egg_s_phone_results():
    h = rv_phone(tab='points')
    old, new = egg_rv_parts('rare'), egg_rv_parts('rare', egg_shard_line_narrow('rare'), (1, 18))
    for k in ('slot', 'text', 'line', 'ring', 'fill'):
        assert old[k] in h, k
        h = h.replace(old[k], new[k], 1)
    return h


SCREENS += [
    ('egg_phone_hud_compact.html', 'Egg phone: compact HUD card', 'The card hugs its content under the top-left buttons (844 x 390)', egg_s_phone_hud, 1080),
    ('egg_phone_results_narrow.html', 'Egg phone: results shard line', '+1 FILL with one rarity word, 1 / 18 FILL unclipped (844 x 390)', egg_s_phone_results, 1080),
]


# ================================================================== Top bar hover (HOS-TOPBAR-001, 17 Oct)
# The five lobby top-bar buttons rest as icon squares (same plate, outline and icon, the ! badge on the
# corner) and grow out to the full pill on hover. TopLeft grows rightward, TopRight leftward; neighbours
# slide to make room. Touch screens stay square (no hover). Runtime: Controllers/TopbarHover.
TB_LEFT = [('purple', 'quests', 'QUESTS', 'QuestsButton', 196, True), ('lime', 'incubator', 'INCUBATOR', 'IncubatorButton', 236, True)]
TB_RIGHT = [('teal', 'servers', 'SERVERS', 'ServersButton', 216, False), ('blue', 'stats', 'STATS', 'StatsButton', 196, False),
            ('grey', 'settings', 'SETTINGS', 'SettingsButton', 228, False)]
TB_SQ = 66   # collapsed plate width: a square behind the 72 px icon


def tb_pill(x, y, w, color, icon, label, badge, open_):
    """hv_pill drawn collapsed (open_=0) or part / fully open (0..1): plate width and label alpha follow open_."""
    full = w
    w = round(TB_SQ + (full - TB_SQ) * open_)
    a = max(0.0, min(1.0, (open_ - .35) / .65))   # the label fades in after the width
    inner = (f"<div class='hp k-{color}' style='left:{x}px;top:{y}px;width:{w}px;height:58px;overflow:hidden'>"
             f"<div class='lbl' style='padding-left:64px;opacity:{a:.2f}'>{T(label, 26, 's')}</div></div>")
    inner += I(icon, x - 6, y - 8, 72)
    if badge:
        inner += box(x + w - 16, y - 14, 34, 34, T('!', 20, 'xs'), 'badge')
    return inner, w + 6


def tb_bar(y, hover=None, t=1.0, phone=False):
    """One top bar strip at height y. hover = the button name that is open (t = how far)."""
    out, x = '', 240
    for c, ic, lab, nm, w, bd in TB_LEFT:
        h, used = tb_pill(x, y, w, c, ic, lab, bd, t if nm == hover else 0)
        out += h
        x += used + 10
    right = 1908
    for c, ic, lab, nm, w, bd in reversed(TB_RIGHT):
        o = t if nm == hover else 0
        ww = round(TB_SQ + (w - TB_SQ) * o) + 6
        h, _ = tb_pill(right - ww + 6, y, w, c, ic, lab, bd, o)
        out += h
        right -= ww + 10
    out += at(960, y - 6, T('LOBBY', 22, 'xs'), w=600, align='center') + at(960, y + 18, T('Waiting for players', 44, 'l'), w=1000, align='center')
    return out


def s_topbar_states():
    out = world()
    out += "<div style='position:absolute;inset:0;background:rgba(10,6,20,.35)'></div>"
    rows = [('COLLAPSED (default, and always on touch screens)', None, 1),
            ('SETTINGS HOVERED: grows leftward, Stats and Servers slide left', 'SettingsButton', 1),
            ('QUESTS HOVERED: grows rightward, Incubator slides right; the ! stays on the corner', 'QuestsButton', 1),
            ('STATS HOVER TWEEN 0%  (0.18 s Quad Out, label fades in after the width)', 'StatsButton', 0),
            ('STATS HOVER TWEEN 50%', 'StatsButton', .5),
            ('STATS HOVER TWEEN 100%', 'StatsButton', 1)]
    for i, (title, hv, t) in enumerate(rows):
        y = 60 + i * 168
        out += f"<div style='position:absolute;left:0;top:{y - 44}px;width:1920px;height:150px;background:rgba(0,0,0,.18)'></div>"
        out += cap(24, y - 40, title)
        out += tb_bar(y + 20, hv, t)
    return out


SCREENS += [
    ('hud_topbar_states.html', 'Top bar: hover to open', 'HOS-TOPBAR-001: icon squares; hover grows the pill out (TopRight leftward)', s_topbar_states, 1060),
]
SCREENS += SCREENS_LEAD  # HOS-LEAD-001


def index():
    cards = ''
    for fname, title, desc, _, h in SCREENS:
        cards += (f"<a class='card' href='{fname}'><div class='frame' style='aspect-ratio:1920/{h}'>"
                  f"<iframe src='{fname}?raw' loading='lazy' tabindex='-1' scrolling='no' style='height:{h}px'></iframe></div>"
                  f"<h3>{title}</h3><p>{desc}</p></a>")
    return f"""<!doctype html><html><head><meta charset='utf-8'><title>Evolve or Steal UI</title>
<meta name='viewport' content='width=device-width,initial-scale=1'>{FONTS}
<style>
:root{{--bg:#1e0a3e;--card:#2c1458;--ink:#fff;--mute:#cdb8f0;--line:#4a2a80}}
body{{margin:0;background:var(--bg);color:var(--ink);font-family:'Fredoka',sans-serif}}
header{{padding:24px 16px 8px}} h1{{margin:0;font-weight:700;font-size:32px}} header p{{color:var(--mute);margin:6px 0 0;font-weight:500}}
.grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:16px;padding:16px}}
.card{{display:block;background:var(--card);border:2px solid var(--line);border-radius:16px;overflow:hidden;color:inherit;text-decoration:none}}
.frame{{position:relative;width:100%;overflow:hidden;background:#000}}
.frame iframe{{position:absolute;left:0;top:0;width:1920px;border:0;transform-origin:0 0;pointer-events:none}}
h3{{margin:12px 14px 2px;font-size:19px}} .card p{{margin:0 14px 14px;color:var(--mute);font-size:14px}}
</style></head><body><header><h1>Evolve or Steal UI (round 2)</h1><p>{len(SCREENS)} pages at 1920 wide. Click one to open it full size.</p></header>
<div class='grid'>{cards}</div>
<script>function sz(){{document.querySelectorAll('.frame').forEach(f=>{{f.firstChild.style.transform='scale('+(f.clientWidth/1920)+')'}})}}addEventListener('resize',sz);sz();</script>
</body></html>"""


if __name__ == '__main__':
    for p in ('tex', 'icons'):
        if not os.path.exists(os.path.join(HERE, p)):
            print('WARN missing', p, '- see the usage lines at the top of this file')
    for fname, title, desc, fn, h in SCREENS:
        with open(os.path.join(HERE, fname), 'w', encoding='utf-8') as f:
            f.write(page(title, fn(), h))
    with open(os.path.join(HERE, 'index.html'), 'w', encoding='utf-8') as f:
        f.write(index())
    print('wrote', len(SCREENS), 'pages + index.html')
