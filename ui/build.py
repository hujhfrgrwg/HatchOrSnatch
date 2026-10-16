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
    x, y, w, h = 228, 86, 460, 74
    out = f"<div class='glass' style='left:{x}px;top:{y}px;width:{w}px;height:{h}px'></div>"
    out += I('piece_common', x + 8, y + 6, 62, name='GoalIcon')
    out += at(x + 80, y + 8, T('YOUR FIRST PET', 20, 'xs', name='GoalTitle'))
    out += at(x + w - 14, y + 8, T('2 / 2', 20, 'xs', 'f-lime', name='GoalCount'), w=120, align='right')
    out += bar(x + 80, y + 38, w - 96, 24, 1, 'lime', 'GoalBar') + at(x + 80 + (w - 96) // 2, y + 39, T('READY TO HATCH!', 15, 'xs', name='GoalState'), w=w - 96, align='center')
    return sub('GoalPill', out, btn=True, opens='Incubator')


def s_hud():
    out = world() + topbar()
    tl = hv_pill(240, 12, 196, 'purple', 'quests', 'QUESTS', 'QuestsButton', 'Quests', badge=True)
    tl += hv_pill(452, 12, 236, 'lime', 'incubator', 'INCUBATOR', 'IncubatorButton', 'Incubator', badge=True) + hv_goal()
    tr = hv_pill(1468, 12, 196, 'blue', 'stats', 'STATS', 'StatsButton', 'Stats') + hv_pill(1680, 12, 228, 'grey', 'settings', 'SETTINGS', 'SettingsButton', 'Settings')
    tr = hv_pill(1236, 12, 216, 'teal', 'servers', 'SERVERS', 'ServersButton', 'Servers') + tr
    # AFK / Hunt sit on a grey plate; the coloured PlateOn shows while they're on (16 Oct: Hunt is purple, not red)
    rail = (hv_rail_btn(10, 290, 96, 'gold', 'shop', 'SHOP', 'ShopButton', 'Shop', key='B') + hv_rail_btn(10, 400, 96, 'sky', 'pets', 'PETS', 'PetsButton', 'Pets', key='P')
            + hv_rail_btn(10, 510, 96, 'pink', 'emote', 'EMOTES', 'EmotesButton', 'EmoteWheel', key='G')
            + hv_rail_btn(10, 620, 96, 'grey', 'afk', 'AFK', 'AFKToggle', state='OFF', on_color='blue')
            + hv_rail_btn(10, 730, 96, 'grey', 'hunt', 'HUNT', 'VolunteerToggle', state='ON', on_color='purple'))
    out += grp('TopLeft', tl, 'TL') + grp('TopRight', tr, 'TR') + grp('Rail', rail, 'L')
    out += hv_topcenter('LOBBY', 'Next match in 0:12', T('4 / 4 players ready  ·  you start as a Runner', 22, 'xs', name='SublineText'))
    out += grp('Watch', hv_pill(860, 140, 200, 'pink', 'spectate', 'SPECTATE', 'SpectateButton'), 'T')   # shown while a match runs
    plus = sub('GemsPlus', btn(286, 990, 54, 54, 'lime', T('+', 40, 'l'), cls='sm', name='Btn'), btn=True, opens='Shop')   # buy Gems (16 Oct)
    out += grp('Wallet', hv_plate(878, 'gold', '1,250', 'GOLD', 'f-gold', 'Gold') + hv_plate(972, 'gem', '12', 'GEMS', 'f-lime', 'Gems') + plus, 'BL')
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


SHOP_TABS = [('featured', 'Featured', 'star', 'gold'), ('trails', 'Trails', 'trail', 'gold'), ('cases', 'Egg Cases', 'case', 'gold'),
             ('effects', 'Effects', 'burst', 'gold'), ('emotes', 'Emotes', 'emote', 'gold'), ('gems', 'Gems', 'gem', 'lime')]
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
    inner += box(370, 178, 360, 264, I(icon, 70, 22, 220, name='Icon'), 'cw', 'border-radius:12px;background:radial-gradient(rgba(255,255,255,.18),rgba(0,0,0,.25))', name='ArtBox')
    inner += price_btns(22, 470, 708, 84, wal, price, rbx, 36)
    inner += state_btns(22, 470, 708, 84, None, 32)
    inner += at(w // 2, 570, T('', 17, 'xs', 'f-dim', name='Have'), w=w - 40, align='center')
    return box(x, y, w, h, inner, f'cs r-{acc}', 'border-radius:18px', name=name)


def s_shop(tab='featured'):
    """Shop by what you buy (16 Oct, after Huss Valley): Featured, Trails, Egg Cases, Effects, Emotes, Gems. Gold items cost
    Gold; Gem items show a Gem price and a Robux price. Short on Gems -> the Robux price is offered (or the Gems tab)."""
    x0, y0, W, H = 170, 118, 1580, 892
    b = ''
    for i, (key, lab, ic, col_) in enumerate(SHOP_TABS):
        b += dual(26 + i * 248, 20, 236, 62, col_, row(icn(ic, 38), bl(lab, 26)), 'Tab' + lab.replace(' ', ''), tab == key, cls='sm')
    # Featured: this week's colourway + a spotlight item
    feat = feature_card(26, 102, SHOP_ITEMS['cases'][1], "THIS WEEK'S COLOURWAY  ·  NEW IN 3D 4H",
                        [('case', 'Keep forever', 'Wear it every match'), ('egg_golden', 'Gold colourway', 'Only this week'), ('check', 'Looks only', 'No gameplay edge')], 'FeatA')
    feat += feature_card(800, 102, SHOP_ITEMS['effects'][3], 'SPOTLIGHT',
                         [('hatchfx', 'Bigger ceremony', 'Light beams and fanfare'), ('incubator', 'Every hatch', 'At the incubator'), ('check', 'Looks only', 'No gameplay edge')], 'FeatB')
    b += sub('PageFeatured', feat, hid=tab != 'featured')
    # Category pages: the runtime fills Cards from EconomyConfig.SHOP (ProtoGold / ProtoGems)
    if tab in ('trails', 'cases', 'effects'):
        cards = ''.join(item_card(26 + i * 384, 102, it) for i, it in enumerate(SHOP_ITEMS[tab]))
        b += sub('PageItems', cards)
    elif EXPORT_STATES:
        b += sub('PageItems', sub('ProtoGold', item_card(26, 102, SHOP_ITEMS['trails'][0], name='Card'), hid=True)
                 + sub('ProtoGems', item_card(26, 102, SHOP_ITEMS['trails'][2], name='Card'), hid=True), hid=True)
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
    y += slot(530, 112, 146, 'lime', 'gem', 'x4', 'Gems', name='GemsSlot')
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
    if EXPORT_STATES or not gems:
        h += btn(700, 920, 250, 84, 'lime', bl('WEAR IT', 36, name='Label'), name='BtnUse', hid=gems)
    h += btn(970 if (EXPORT_STATES or not gems) else 835, 920, 250, 84, 'purple', bl('NICE!', 36), name='BtnClose')
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
    return out


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
    return out


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


def page(title, body, h=1080):
    return (f"<!doctype html><html><head><meta charset='utf-8'><title>{title}</title>"
            f"<meta name='viewport' content='width=device-width,initial-scale=1'>{FONTS}"
            f"<link rel='stylesheet' href='kit.css'><link id='preset' rel='stylesheet' href='styles/{STYLE}.css'>"
            + (f"<link rel='stylesheet' href='styles/{SKIN}.css'>" if SKIN else '')
            + "</head><body>"
            f"<div id='wrap'><div id='stage' style='height:{h}px'>{body}</div></div>{JS}</body></html>")


SCREENS = [  # (file, title, description, fn, height)
    ('style.html', 'Style', 'Reference, lobby, accents, icons, eggs, buttons', s_style, 1580),
    ('hud.html', 'HUD (lobby)', 'Menus, first-pet goal, timer, wallet, equipped pet', s_hud, 1080),
    ('hud_match.html', 'HUD (match)', 'Role, crossing timer, teams, streak, egg level, ability, feed', s_hud_match, 1080),
    ('hud_phone.html', 'HUD (phone)', 'Bigger targets, thumbs kept clear', s_hud_phone, 1080),
    ('quests.html', 'Quests', 'Two daily quests, progress, rewards, claim', s_quests, 1080),
    ('incubator.html', 'Incubator', 'Pieces, first-pet path, families, species ladder, hatch', s_incubator, 1080),
    ('incubator_later.html', 'Incubator (after first pet)', 'Random 2 vs choose 3', lambda: s_incubator(False), 1080),
    ('pets.html', 'Pets', 'Collection grid, mastery stars, preview, equip', s_pets, 1080),
    ('shop.html', 'Shop (Featured)', "This week's colourway and a spotlight item", s_shop, 1080),
    ('shop_trails.html', 'Shop (Trails)', 'Egg trails: one match (Gold) or forever (Gems or Robux)', lambda: s_shop('trails'), 1080),
    ('shop_cases.html', 'Shop (Egg Cases)', 'Egg cases', lambda: s_shop('cases'), 1080),
    ('shop_effects.html', 'Shop (Effects)', 'Confetti, entrance, ability colours, hatching', lambda: s_shop('effects'), 1080),
    ('shop_emotes.html', 'Shop (Emotes)', 'The Emote Crate', lambda: s_shop('emotes'), 1080),
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
    ('templates.html', 'Banners + toasts + confirm', 'Runtime templates', s_templates, 1120),
    ('states.html', 'All states', 'Every element in every state', s_states, 1080),
    ('compare.html', 'Before', 'Current lobby HUD', s_compare, 1080),
]


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
        with open(os.path.join(HERE, fname), 'w') as f:
            f.write(page(title, fn(), h))
    with open(os.path.join(HERE, 'index.html'), 'w') as f:
        f.write(index())
    print('wrote', len(SCREENS), 'pages + index.html')
