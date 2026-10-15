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


# ================================================================== base helpers (roblox-ui-maker markers)
def dn(name):
    return f" data-n='{name}'" if name else ''


def T(text, size, cls='', fill='', style='', name=None, tag='span'):
    t = html.escape(str(text), quote=True)
    return f"<{tag} class='ot {cls} {fill}' data-t='{t}'{dn(name)} style='font-size:{size}px;{style}'>{t}</{tag}>"


def ipath(icon):
    """icons_ai/<slug>.png (ChatGPT set, docs/ui/chatgpt_icon_prompt.md) wins over icons/<slug>.png."""
    return f'icons_ai/{icon}.png' if os.path.exists(os.path.join(HERE, 'icons_ai', icon + '.png')) else f'icons/{icon}.png'


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
    'ShadesShark': 'Shades Shark', 'SurferDog': 'Surfer Dog', 'ThunderWolf': 'Thunder Wolf', 'PhoenixGull': 'Phoenix Gull', 'FireDragon': 'Fire Dragon',
    'KoiSpirit': 'Koi Spirit', 'JellyWisp': 'Jelly Wisp', 'SaucerPilot': 'Saucer Pilot', 'VoidOverlord': 'Void Overlord',
    'GamerAxolotl': 'Gamer Axolotl', 'BanditRaccoon': 'Bandit Raccoon', 'NinjaPenguin': 'Ninja Penguin', 'LilAlien': "Lil' Alien", 'MiniMothership': 'Mini Mothership',
    'PebbleFrog': 'Pebble Frog', 'PufferPup': 'Puffer Pup', 'HermitKnight': 'Hermit Knight', 'TreasureGolem': 'Treasure Golem',
    'SandCrab': 'Sand Crab', 'RoboCrab': 'Robo Crab', 'ArmoredRex': 'Armored Rex', 'FrostYeti': 'Frost Yeti', 'LavaScorpion': 'Lava Scorpion', 'MechaInvader': 'Mecha Invader',
    'VikingWalrus': 'Viking Walrus', 'CozyLion': 'Cozy Lion', 'NarwhalCalf': 'Narwhal Calf', 'KrakenHatchling': 'Kraken Hatchling', 'LeviathanPup': 'Leviathan Pup',
}
POOLS = [  # id, title, icon, colour key, blurb, pets (common -> rarest)
    ('DoubleDash', 'Double Dash', 'ab_dash', 'orange', 'Two quick dashes in a row', ['ShadesShark', 'SurferDog', 'ThunderWolf', 'PhoenixGull', 'FireDragon']),
    ('Invisibility', 'Invisibility', 'ab_invis', 'sky', 'Fade out for a few seconds', ['KoiSpirit', 'JellyWisp', 'SaucerPilot', 'VoidOverlord']),
    ('Decoy', 'Decoy', 'ab_decoy', 'gold', 'A running copy of you', ['GamerAxolotl', 'BanditRaccoon', 'NinjaPenguin', 'LilAlien', 'MiniMothership']),
    ('Shield', 'Shield', 'ab_shield', 'teal', 'A bubble that blocks one tag', ['PebbleFrog', 'PufferPup', 'HermitKnight', 'TreasureGolem']),
    ('Wall', 'Wall', 'ab_wall', 'violet', 'Drop a wall behind you', ['SandCrab', 'RoboCrab', 'ArmoredRex', 'FrostYeti', 'LavaScorpion', 'MechaInvader']),
    ('PetTackle', 'Pet Tackle', 'ab_tackle', 'red', 'Your pet bowls a Catcher over', ['VikingWalrus', 'CozyLion', 'NarwhalCalf', 'KrakenHatchling', 'LeviathanPup']),
]
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
    return T(text, size, 's', fill, name=name)


def well(x, y, w, h, inner='', name=None, solid=False, style=''):
    return box(x, y, w, h, inner, 'cw' + (' solid' if solid else ''), style, name=name)


def slot(x, y, s, rarity, icon=None, count=None, label=None, cls='', name=None, art_pad=.14, label_size=None, inner_extra=''):
    inner = ''
    if icon:
        p = int(s * art_pad)
        inner += f"<div class='art'>{I(icon, p, int(p * .7), s - 2 * p, name='Icon')}</div>"
    if count:
        inner += at(s - 10, 6, T(count, max(18, int(s * .17)), 'xs'), w=s, align='right', name='Count')
    if label:
        inner += at(s // 2, s - int(s * .26), T(label, label_size or max(16, int(s * .15)), 'xs', FILL.get(rarity, '')), w=s + 20, align='center', name='Label')
    inner += inner_extra
    return box(x, y, s, s, inner, f'cs r-{rarity} {cls}', name=name)


def stars(n, of=3, size=26):
    out = ''
    for i in range(of):
        out += f"<img class='icn' src='{ipath('star')}' style='width:{size}px;height:{size}px;{'' if i < n else 'filter:grayscale(1) brightness(.45);opacity:.8'}'>"
    return f"<span style='display:inline-flex;gap:2px'>{out}</span>"


def tag(x, y, text, color='blue', size=20, h=36, name=None):
    return f"<div class='ctag k-{color}'{dn(name)} style='left:{x}px;top:{y}px;height:{h}px'>{T(text, size, 'xs')}</div>"


def bar(x, y, w, h, frac, color='lime', name='Bar'):
    return (f"<div class='cbar k-{color}'{dn(name)} style='left:{x}px;top:{y}px;width:{w}px;height:{h}px'>"
            f"<i data-n='F' style='width:{max(0, min(1, frac)) * 100:.1f}%'></i></div>")


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


def panel_sport(gname, acc, title, icon, body, x, y, w, h, right='', head_h=112, title_size=62):
    """Units-reference panel: the angled banner overlaps the panel top-left, a grey chip holds the
    header info at the top right, the tilted X sits on the corner."""
    bw = min(int(w * .52), 760)
    out = f"<div class='cglow a-{acc}' style='left:{x - 16}px;top:{y - 12}px;width:{w + 32}px;height:{h + 28}px'></div>"
    out += (f"<div class='cp a-{acc}' data-n='Panel' style='left:{x}px;top:{y}px;width:{w}px;height:{h}px'>"
            f"<div class='body' style='top:{head_h}px'>{body}</div>"
            + (f"<div class='schip' data-n='HeaderInfo' style='right:118px;top:20px'>{right}</div>" if right else '') + "</div>")
    out += (f"<div class='sbn a-{acc}' data-n='Banner' style='left:{x - 18}px;top:{y - 50}px;width:{bw}px;height:132px'>"
            f"<div class='o'></div><div class='f'></div>"
            f"<img class='spk' src='{ipath('sparkle')}'>"
            f"<div class='lbl'>{icn(icon, 96) if icon else ''}{T(title.upper(), title_size + 6, 'xl', name='Title')}</div></div>")
    out += closex(x + w - 64, y - 38)
    return grp(gname, out, 'C')


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
        inner += box(x + w - 30, y - 14, 44, 44, T('!', 26, 'xs'), 'badge', name='Badge')
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
    out += f"<div class='keycap' data-n='Key' style='left:{x + w - 82}px;top:{y + 26}px'>{T('Q', 32, 's')}</div>"
    out += bar(x + 120, y + h - 20, w - 220, 14, 1 if cd is None else .42, 'orange', 'Cooldown')
    return grp('Ability', out, 'B')


def lobby_status():
    out = btn(880, 12, 160, 48, 'sky', T('LOBBY', 26, 's'), cls='sm', name='PhaseChip')
    out += at(960, 68, T('NEXT MATCH IN', 28, 's', 'f-dim', name='Headline'), w=500, align='center')
    out += at(960, 98, T('0:12', 92, 'xl', name='Timer'), w=500, align='center')
    out += at(960, 202, T('4 / 4 players ready', 28, 's', 'f-lime', name='Subline'), w=600, align='center')
    return grp('Status', out, 'T')


def goal_pill():
    x, y, w, h = 250, 116, 562, 104
    out = f"<div class='glass' style='left:{x}px;top:{y}px;width:{w}px;height:{h}px'></div>"
    out += slot(x + 14, y + 12, 80, 'common', 'piece_common', name='GoalSlot', art_pad=.1)
    out += at(x + 108, y + 12, T('YOUR FIRST PET', 28, 's', name='GoalTitle'))
    out += at(x + w - 20, y + 14, T('4 / 2', 26, 's', 'f-lime', name='GoalCount'), w=140, align='right')
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


def s_hud():
    return world() + topbar() + hud_groups()


def s_hud_phone():
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
def s_hud_match():
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


# ================================================================== Quests (QuestConfig: 2 daily, UTC reset)
QUESTS = [  # title, art, progress, target, gold reward, state
    ('Complete 3 crossings', 'art_boards', 2, 3, 25, 'active'),
    ('Make 1 capture', 'art_events', 1, 1, 15, 'ready'),
]


def s_quests():
    x0, y0, W, H = 300, 170, 1320, 760
    b = btn(28, 26, 300, 64, 'purple', bl('Today  [2]', 30), name='TabToday')
    b += btn(344, 26, 300, 64, 'grey', bl('Done  [0]', 30), name='TabDone')
    lst = ''
    for i, (title, art, p, t, g, st) in enumerate(QUESTS):
        y = 18 + i * 132
        card = f"<img src='{art}.jpg' style='position:absolute;inset:0;width:100%;height:100%;object-fit:cover'>"
        card += "<div class='abs fill' style='background:linear-gradient(90deg,rgba(40,10,70,.85),rgba(40,10,70,.25))'></div>"
        card += tag(14, 12, 'Daily Quest', 'blue', 18, 32)
        card += at(16, 52, T(title, 30, 's'))
        card += bar(16, 92, 300, 20, p / t, 'lime' if st == 'ready' else 'pink', 'Progress')
        card += at(330, 88, T(f'{p} / {t}', 22, 'xs', 'f-lime' if st == 'ready' else ''))
        if st == 'ready':
            card += btn(430, 30, 116, 56, 'lime', bl('CLAIM', 24), cls='sm', name='Claim')
        lst += box(18, y, 566, 120, card, 'cs r-pink' + (' sel' if i == 0 else ''), 'border-radius:14px', name=f'Quest{i + 1}')
    lst += box(18, 18 + 2 * 132, 566, 110, at(283, 24, row(icn('clock', 54), col(T('New quests tomorrow', 26, 's'), T('2 fresh quests every day', 18, 'xs', 'f-dim'), gap=0, align='flex-start'), gap=14), w=560, align='center'),
               'cs locked', 'border-radius:14px', name='Tomorrow')
    lst += btn(150, 430, 300, 76, 'lime', bl('CLAIM ALL', 32), name='ClaimAll')
    b += well(28, 112, 604, 520, lst, name='List')
    d = tag(24, 22, 'Daily Quest', 'blue', 20, 38)
    d += at(24, 74, T('Complete 3 crossings', 42, 'l', name='QuestTitle'))
    d += at(26, 130, T('Make it across to the safe zone as a Runner.', 24, 'xs', 'f-dim', name='QuestDesc'))
    d += at(26, 160, T('Each crossing that ends safe counts.', 24, 'xs', 'f-dim'))
    d += bar(24, 204, 470, 38, 2 / 3, 'pink', 'Progress') + at(260, 208, T('2 / 3', 26, 's'), w=470, align='center')
    d += at(24, 256, T('REWARDS', 24, 'xs', 'f-pink'))
    rw = slot(18, 14, 132, 'gold', 'gold', 'x25', 'Gold', name='Reward1') + slot(166, 14, 132, 'common', 'piece_common', 'x1', 'Bonus', name='Reward2', cls='hid')
    d += well(24, 290, 586, 162, rw, name='Rewards', solid=True)
    d += btn(170, 470, 300, 70, 'pink', bl('TRACK QUEST', 30), name='Track')
    b += well(650, 112, 642, 520, d, name='Detail')
    right = row(icn('clock', 52), T('Resets in 06:42:10', 34, 's', name='ResetText'), gap=8)
    return world('bg_lobby_blur.jpg', False) + dim() + panel('Quests', 'pink', 'Quests', 'quests', b, x0, y0, W, H, right)


# ================================================================== Incubator (GDD 03, 09, 14)
def s_incubator(first=True):
    x0, y0, W, H = 210, 104, 1500, 884
    b = ''
    pc = at(22, 14, T('YOUR PIECES', 24, 'xs', 'f-lime'))
    for i, m in enumerate(['common', 'rare', 'epic']):
        n = PIECES[m]
        pc += slot(22 + i * 132, 50, 118, m, 'piece_' + m, f'x{n}', TIER_NAME[m], cls='locked' if n == 0 else '', name=f'Piece_{m}', art_pad=.14)
    b += well(26, 24, 434, 196, pc, name='Pieces')
    b = incubator_top(b, first)
    b = incubator_rest(b, first)
    return world('bg_lobby_blur.jpg', False) + dim() + panel('Incubator', 'lime', 'Incubator', 'incubator', b, x0, y0, W, H)


def incubator_top(b, first):
    if not first:  # after the first pet: collection progress per family replaces the first-pet path
        tr = at(24, 14, T('YOUR COLLECTION', 24, 'xs', 'f-lime'))
        found = {'DoubleDash': 2, 'Invisibility': 1, 'Decoy': 1, 'Shield': 2, 'Wall': 1, 'PetTackle': 1}
        for i, (pid, title, ic, colr, blurb, pets) in enumerate(POOLS):
            cx = 22 + i * 160
            tr += slot(cx, 52, 88, colr, ic, cls='fill', art_pad=.14)
            tr += at(cx + 44, 146, T(f'{found[pid]} / {len(pets)}', 22, 's'), w=150, align='center')
        b += well(476, 24, 998, 196, tr, name='Collection')
    else:
        b += first_path()
    return b


def first_path():
    tr = at(24, 14, row(T('YOUR FIRST PET', 24, 'xs', 'f-lime'), T('free family choice!', 20, 'xs', 'f-gold'), gap=12))
    tr += bar(80, 102, 820, 26, 1, 'lime', 'Track')
    for i, (lab, ic) in enumerate([('Start', None), ('Match 1', 'piece_common'), ('Match 2', 'piece_common'), ('Hatch!', 'egg_basic')]):
        nx = 40 + i * 270
        tr += slot(nx, 66, 100, 'gold' if i == 3 else 'common', ic, label=None, name=f'Step{i}', art_pad=.14,
                   inner_extra='' if ic else at(50, 30, T('GO', 32, 's'), w=100, align='center'), cls='fill' if i == 0 else '')
        tr += at(nx + 50, 172, T(lab, 22, 's', 'f-gold' if i == 3 else ''), w=200, align='center')
    return well(476, 24, 998, 196, tr, name='FirstPet')


def incubator_rest(b, first):
    fp = at(22, 12, T('PICK A FAMILY', 24, 'xs', 'f-lime'))
    for i, (pid, title, ic, colr, blurb, pets) in enumerate(POOLS):
        cx, cy = 22 + (i % 3) * 146, 50 + (i // 3) * 158
        fp += slot(cx, cy, 132, colr, ic, label=title, cls='fill sel' if pid == 'DoubleDash' else 'fill', name=f'Family_{pid}', art_pad=.18, label_size=17)
    b += well(26, 236, 466, 380, fp, name='Families')
    pool = POOL['DoubleDash']
    lad = at(22, 12, row(icn(pool[2], 44), T(pool[1].upper(), 34, 's'), T(pool[4], 20, 'xs', 'f-dim'), gap=10))
    for i, pet in enumerate(pool[5][:3]):
        t = TIERS[i]
        sx = 22 + i * 186
        lad += slot(sx, 66, 172, t, pet_img(pet), name=f'Species_{t}', art_pad=.04)
        lad += at(sx + 86, 246, T(P[pet], 22, 's'), w=200, align='center') + at(sx + 86, 276, T(TIER_NAME[t], 18, 'xs', FILL[t]), w=200, align='center')
        lad += at(sx + 86, 304, row(icn('piece_' + t, 26), T(f'{RECIPES[t][0]} random · {RECIPES[t][1]} pick', 16, 'xs', 'f-dim'), gap=4), w=200, align='center')
    lad += slot(22 + 3 * 186 + 6, 66, 120, 'crowned', pet_img(pool[5][3]), cls='locked', name='Species_crowned', art_pad=.06, inner_extra=I('lock', 36, 34, 48))
    lad += at(22 + 3 * 186 + 66, 196, T('Crowned', 18, 'xs', 'f-gold'), w=140, align='center') + at(22 + 3 * 186 + 66, 220, T('coming later', 16, 'xs', 'f-dim'), w=140, align='center')
    b += well(508, 236, 966, 380, lad, name='Ladder')
    if first:
        hb = at(30, 22, row(icn('egg_basic', 70), col(T('HATCH YOUR FIRST PET', 32, 's'), T('Shades Shark  ·  Double Dash  ·  costs 2 Common pieces', 20, 'xs', 'f-dim'), gap=2, align='flex-start'), gap=14))
        hb += btn(1000, 18, 420, 86, 'lime', row(bl('HATCH', 38), icn('piece_common', 40), T('x2', 26, 's')), name='BtnHatch')
        hb += tag(810, 40, 'FREE CHOICE', 'gold', 20, 40, name='FreeTag')
    else:
        hb = btn(30, 18, 460, 86, 'grey', row(icn('dice', 44), bl('RANDOM FAMILY', 30), icn('piece_common', 34), T('x2', 24, 's')), name='BtnRandom')
        hb += btn(520, 18, 520, 86, 'lime', row(icn('target', 44), bl('HATCH DOUBLE DASH', 30), icn('piece_common', 34), T('x3', 24, 's')), name='BtnFocus')
    b += well(26, 632, 1448, 122, hb, name='HatchBar', solid=True)
    return b


# ================================================================== Pets (inventory + preview, equip)
OWNED = [('DoubleDash', 'ShadesShark', 3, True), ('DoubleDash', 'SurferDog', 1, False), ('Decoy', 'GamerAxolotl', 2, False), ('Shield', 'PebbleFrog', 1, False),
         ('Wall', 'SandCrab', 1, False), ('Invisibility', 'KoiSpirit', 1, False), ('PetTackle', 'VikingWalrus', 1, False), ('Shield', 'PufferPup', 1, False)]


def s_pets():
    x0, y0, W, H = 250, 160, 1420, 800
    b = ''
    for i, (lab, active) in enumerate([('All  8', True), ('Double Dash', False), ('Decoy', False), ('Shield', False), ('More...', False)]):
        b += btn(26 + i * 162, 22, 150, 54, 'purple' if active else 'grey', bl(lab, 20), cls='sm', name=f'Filter{i}')
    g = ''
    for i, (pid, pet, st, eq) in enumerate(OWNED):
        tier = tier_of(pid, pet)
        gx, gy = 18 + (i % 4) * 196, 18 + (i // 4) * 210
        extra = at(34, 150, stars(st, 3, 24))
        if eq:
            extra += tag(66, 8, 'EQUIPPED', 'lime', 14, 28)
        g += slot(gx, gy, 182, tier, pet_img(pet, st), cls='sel' if i == 0 else '', name=f'Pet{i + 1}', art_pad=.05, inner_extra=extra)
    for j in range(8, 12):
        gx, gy = 18 + (j % 4) * 196, 18 + (j // 4) * 210
        g += slot(gx, gy, 182, 'locked', None, cls='locked', name=f'Empty{j}', inner_extra=at(91, 64, T('?', 56, 'l', 'f-dim'), w=180, align='center'))
    b += well(26, 92, 820, 590, g, name='Grid', style='overflow:hidden')
    pv = slot(110, 18, 340, 'common', pet_img('ShadesShark', 3), name='PreviewSlot', art_pad=.06, cls='fill')
    pv += at(280, 372, T('Shades Shark', 44, 'l', name='PetName'), w=540, align='center')
    pv += at(280, 428, row(T('Common', 22, 'xs', 'f-common'), stars(3, 3, 26), T('mastery', 18, 'xs', 'f-dim'), gap=10), w=540, align='center')
    pv += at(30, 470, row(icn('ab_dash', 52), col(T('DOUBLE DASH', 26, 's'), T('Two quick dashes in a row  ·  cooldown 12s', 18, 'xs', 'f-dim'), gap=0, align='flex-start'), gap=10))
    pv += btn(30, 540, 330, 70, 'lime', row(icn('check', 36), bl('EQUIPPED', 28)), name='BtnEquip')
    pv += btn(376, 540, 130, 70, 'pink', icn('star', 40), name='BtnFavourite')
    b += well(862, 22, 532, 660, pv, name='Preview')
    right = row(icn('pets', 50), T('8 / 29 found', 32, 's', name='CountText'), gap=6)
    return world('bg_lobby_blur.jpg', False) + dim() + panel('Pets', 'sky', 'Pets', 'pets', b, x0, y0, W, H, right)


# ================================================================== Shop (EconomyConfig.SHOP + GDD emote)
SHOP = [  # icon, name, wallet, price, kind label, desc, state
    ('trail', 'Sparkle Trail', 'gold', '40', 'One match', 'Your egg leaves sparkles.', 'ok'),
    ('trail', 'Ember Trail', 'gold', '60', 'One match', 'Your egg leaves embers.', 'ok'),
    ('burst', 'Confetti Burst', 'gold', '75', 'Lobby, once', 'Pop confetti over your head.', 'ok'),
    ('emote', 'Happy Dance', 'gold', '500', 'Keep forever', 'A basic emote.', 'owned'),
    ('case', 'Frost Egg Case', 'gold', '900', 'Keep forever', 'An icy shell around your egg.', 'ok'),
    ('entrance', 'Bolt Entrance', 'gold', '1,400', 'Keep forever', 'Arrive with a lightning strike.', 'poor'),
    ('case', 'Sunset Egg Case', 'gold', '2,400', "This week's colour", 'Gold colourway, keep forever.', 'poor'),
]


def shop_card(x, y, it, w=250, h=278, sel=False):
    icon, name, wal, price, kind, desc, st = it
    r = 'gold' if wal == 'gold' else 'lime'
    inner = I(icon, (w - 132) // 2, 12, 132, name='Icon')
    inner += at(w // 2, 146, T(name, 24, 's', name='ItemName'), w=w + 10, align='center')
    inner += at(w // 2, 178, T(kind if st != 'poor' else 'need more ' + ('Gold' if wal == 'gold' else 'Gems'), 17, 'xs', 'f-dim' if st != 'poor' else 'f-red', name='Kind'), w=w, align='center')
    if st == 'owned':
        inner += btn(18, h - 68, w - 36, 54, 'grey', row(icn('check', 30), bl('OWNED', 24)), cls='sm', name='BtnOwned')
    else:
        inner += btn(18, h - 68, w - 36, 54, 'lime' if st == 'ok' else 'grey', row(icn(wal if wal != 'gems' else 'gem', 34), bl(price, 26, name='Price')), cls='sm', name='BtnBuy')
    return box(x, y, w, h, inner, f'cs r-{r}' + (' sel' if sel else ''), 'border-radius:16px', name=f'Item_{name.replace(" ", "")}')


def s_shop(tab='gold'):
    x0, y0, W, H = 220, 150, 1480, 820
    b = btn(26, 22, 260, 64, 'gold' if tab == 'gold' else 'grey', row(icn('gold', 40), bl('Gold', 30)), name='TabGold')
    b += btn(300, 22, 260, 64, 'lime' if tab == 'gems' else 'grey', row(icn('gem', 40), bl('Gems', 30)), name='TabGems')
    b += btn(574, 22, 300, 64, 'grey', row(icn('robux', 40), bl('Get Gems', 30)), name='TabGetGems', hid=True)
    items = SHOP if tab == 'gold' else [
        ('trail', 'Rainbow Trail', 'gems', '150', 'Keep forever', 'A rainbow trail on your egg.', 'ok'),
        ('abilityfx', 'Gold Ability FX', 'gems', '250', 'Keep forever', 'Same timing and size.', 'poor'),
        ('hatchfx', 'Royal Hatching', 'gems', '350', 'Keep forever', 'A bigger hatching ceremony.', 'poor'),
        ('crown', 'Showcase Slot', 'gems', '450', 'Keep forever', 'Show off one more pet in the lobby.', 'poor'),
        ('sparkle', 'Themed Override', 'gems', '700', 'Keep forever', 'A themed look for your ability.', 'poor'),
        ('trophy', 'Prestige Set', 'gems', '1,500', 'Keep forever', 'Trail, case and entrance set.', 'poor')]
    g = ''
    for i, it in enumerate(items[:8]):
        g += shop_card(18 + (i % 4) * 262, 16 + (i // 4) * 290, it, sel=(i == 4) if tab == 'gold' else (i == 0))
    b += well(26, 100, 1074, 596, g, name='Grid')
    sel = items[4] if tab == 'gold' else items[0]
    d = slot(60, 20, 220, 'gold' if tab == 'gold' else 'lime', sel[0], name='PreviewSlot', art_pad=.12, cls='fill')
    d += at(170, 258, T(sel[1], 34, 'l', name='ItemName'), w=330, align='center')
    d += at(170, 304, T(sel[4], 20, 'xs', 'f-gold'), w=330, align='center')
    d += at(170, 336, T(sel[5], 20, 'xs', 'f-dim', name='Desc'), w=330, align='center')
    d += at(170, 366, T('Looks only, no gameplay edge.', 17, 'xs', 'f-dim'), w=330, align='center')
    d += btn(30, 420, 280, 80, 'lime', row(icn('gold' if sel[2] == 'gold' else 'gem', 44), bl(sel[3], 34)), name='BtnBuy')
    d += at(170, 520, row(T('You have', 18, 'xs', 'f-dim'), icn('gold' if tab == 'gold' else 'gem', 26), T('1,250' if tab == 'gold' else '12', 20, 'xs', 'f-gold' if tab == 'gold' else 'f-lime'), gap=6), w=330, align='center')
    b += well(1116, 100, 340, 596, d, name='Detail')
    right = row(icn('gold', 48), T('1,250', 34, 's', 'f-gold'), icn('gem', 48), T('12', 34, 's', 'f-lime'), gap=8)
    return world('bg_lobby_blur.jpg', False) + dim() + panel('Shop', 'gold', 'Shop', 'shop', b, x0, y0, W, H, right)


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
        inner = I(ic, 14, 22, 120) + at(146, 34, T(lab, 22, 'xs', 'f-dim')) + at(146, 66, T(val, 52, 'l', FILL.get(c, ''), name='Value'))
        b += box(x, y, 386, 176, inner, f'cs r-{c}', 'border-radius:16px', name=f'Stat{i + 1}')
    right = row(icn('crown', 48), T('Your record', 32, 's'), gap=6)
    return world('bg_lobby_blur.jpg', False) + dim() + panel('Stats', 'violet', 'Stats', 'stats', b, x0, y0, W, H, right)


# ================================================================== Settings (real settings only)
SETTINGS = [('sound', 'Sound Effects', 'Hits, steals, crossings and UI clicks.', True),
            ('sparkle', 'Reduce Effects', 'Fewer particles, no camera shake or speed zoom.', False),
            ('info', 'Show Hints', 'Tips on screen while you learn the game.', True),
            ('hunt', 'Volunteer To Hunt', 'Start matches as a Catcher when there is room.', False)]


def s_settings():
    x0, y0, W, H = 360, 170, 1200, 760
    b = ''
    for i, (ic, title, desc, on) in enumerate(SETTINGS):
        y = 24 + i * 134
        inner = I(ic, 14, 12, 96) + at(128, 18, T(title, 36, 's', name='Title')) + at(130, 66, T(desc, 21, 'xs', 'f-dim', name='Desc'))
        inner += btn(860, 22, 236, 72, 'lime' if on else 'grey', bl('ON' if on else 'OFF', 32, name='ToggleText'), name='Toggle')
        b += well(26, y, 1136, 118, inner, name=f'Row{i + 1}')
    b += btn(26, 568, 360, 64, 'purple', bl('GAME', 28), name='TabGame')
    b += btn(414, 568, 360, 64, 'grey', bl('AUDIO', 28), name='TabAudio')
    b += btn(802, 568, 360, 64, 'grey', row(icn('controls', 36), bl('CONTROLS', 28)), name='TabControls')
    return world('bg_lobby_blur.jpg', False) + dim() + panel('Settings', 'violet', 'Settings', 'settings', b, x0, y0, W, H)


# ================================================================== Results (GDD 14 end-of-match breakdown)
def s_results():
    out = world('bg_lobby_blur.jpg', False) + dim(.5)
    hd = f"<img class='abs' src='tex/sunburst_b.png' style='left:610px;top:-230px;width:700px;height:700px;opacity:.35'>"
    hd += at(960, 26, T('RUNNERS WIN!', 104, 'xl', 'f-gold', name='TeamBanner'), w=1200, align='center')
    hd += at(960, 158, T('3 clean crossings in a row', 30, 's', 'f-dim', name='Reason'), w=900, align='center')
    out += grp('Banner', hd, 'T')
    pod = ''
    for i, (nm, pet, lab, h, c, r) in enumerate([('Zoe', 'SurferDog', '2nd', 150, 'sky', 'rare'), ('You', 'ShadesShark', '1st', 200, 'gold', 'gold'), ('Kai', 'GamerAxolotl', '3rd', 110, 'orange', 'common')]):
        x = 150 + i * 200
        pod += slot(x, 770 - h - 176, 170, r, pet_img(pet, 3 if i == 1 else 1), name=f'Podium{i + 1}', art_pad=.05)
        pod += btn(x, 770 - h, 170, h, c, col(T(lab, 40, 'l'), T(nm, 24, 's'), gap=0), name=f'Step{i + 1}')
    out += grp('Podium', pod, 'L')
    th = slot(26, 26, 130, 'red', 'steal', name='ThiefSlot', cls='fill')
    th += at(178, 36, T('TOP THIEF', 22, 'xs', 'f-red')) + at(178, 66, T('Kai', 44, 'l', name='ThiefName')) + at(180, 122, T('stole 4 eggs', 22, 'xs', 'f-dim'))
    out += grp('Thief', box(150, 820, 600, 184, th, 'glass', name='Thief'), 'BL')
    y = f"<div class='ch a-gold' style='height:84px'><div class='sweep'></div><div class='lbl'>{T('YOUR REWARDS', 40, 'l')}</div></div>"
    for i, (lab, amt) in enumerate([('PLAYED', 25), ('CROSSINGS  x3', 36), ('FIRST STEAL', 10), ('VICTORY', 15)]):
        y += at(40, 112 + i * 40, T(lab, 22, 'xs', 'f-dim')) + at(480, 106 + i * 40, row(T(f'+{amt}', 26, 's', 'f-gold'), icn('gold', 30), gap=4), w=200, align='right')
    y += "<div class='abs' style='left:36px;top:280px;width:444px;height:4px;background:rgba(255,255,255,.2)'></div>"
    y += at(40, 296, T('TOTAL', 26, 's')) + at(480, 288, row(T('+86', 40, 'l', 'f-gold', name='GoldTotal'), icn('gold', 44), gap=4), w=240, align='right')
    y += slot(530, 112, 146, 'gold', 'gem', 'x4', 'Gems', name='GemsSlot')
    y += slot(530, 274, 146, 'epic', 'piece_epic', 'x1', 'Epic', name='PieceSlot')
    y += at(40, 352, row(icn('egg_cosmic', 54), col(T('Best egg: Level 3', 26, 's', 'f-epic'), T('pays 1 Epic piece', 18, 'xs', 'f-dim'), gap=0, align='flex-start'), gap=8))
    y += bar(40, 434, 440, 32, 1 / 5, 'purple', 'RecipeBar') + at(260, 437, T('Epic pieces 1 / 5', 18, 'xs'), w=440, align='center')
    y += btn(510, 428, 186, 68, 'lime', bl('NEXT', 30), name='Continue')
    out += grp('You', f"<div class='cp a-gold' data-n='YouCard' style='left:1060px;top:280px;width:720px;height:530px'>{y}</div>", 'R')
    out += grp('NextMatch', at(1420, 846, T('Next match in 0:09', 30, 's', 'f-dim', name='NextText'), w=720, align='center'), 'BR')
    return out


# ================================================================== Hatch reveal
def s_hatch():
    out = world('bg_lobby_blur.jpg', False) + dim(.6)
    h = "<img class='abs' src='tex/sunburst_b.png' style='left:460px;top:40px;width:1000px;height:1000px;opacity:.55'>"
    h += "<img class='abs' src='tex/shine.png' style='left:560px;top:150px;width:800px;height:800px;opacity:.7'>"
    h += at(960, 70, T('NEW PET!', 110, 'xl', 'f-gold', name='Title'), w=1000, align='center')
    h += I(pet_img('ShadesShark'), 700, 230, 520, name='Pet')
    h += at(960, 760, T('Shades Shark', 72, 'xl', name='PetName'), w=1000, align='center')
    h += at(960, 852, row(T('Common', 30, 's', 'f-common'), icn('ab_dash', 46), T('Double Dash', 30, 's', 'f-orange'), gap=12), w=1000, align='center')
    h += btn(700, 920, 250, 84, 'lime', bl('EQUIP', 36), name='BtnEquip') + btn(970, 920, 250, 84, 'purple', bl('NICE!', 36), name='BtnClose')
    for sx, sy, s in [(560, 300, 70), (1300, 260, 90), (1360, 560, 54), (520, 620, 60)]:
        h += I('sparkle', sx, sy, s)
    return out + grp('Reveal', h, 'C')


# ================================================================== match banners + runtime templates
def banner_card(x, y, w, title, sub_txt, color, icon, name):
    inner = f"<div class='hp k-{color}' style='left:0;top:0;width:{w}px;height:120px'><div class='lbl' style='padding-left:150px'>{col(T(title, 54, 'xl'), T(sub_txt, 24, 's'), gap=0, align='flex-start')}</div></div>"
    inner += I(icon, -10, -26, 160)
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
    out += cap(1000, 24, 'Toasts: info / success / error / reward')
    out += toast(1000, 80, 'blue', 'info', 'Tip: hold Space to dash sideways', 'Toast_info')
    out += toast(1000, 190, 'lime', 'check', 'Sparkle Trail bought!', 'Toast_good')
    out += toast(1000, 300, 'red', 'gold', 'Need 150 more Gold', 'Toast_error')
    out += toast(1000, 410, 'gold', 'piece_rare', '+1 Rare piece', 'Toast_reward')
    cf = f"<div class='ch a-pink' style='height:84px'><div class='sweep'></div><div class='lbl'>{T('Are you sure?', 42, 'l', name='Title')}</div></div>"
    cf += at(380, 116, T('Buy Bolt Entrance for 1,400 Gold?', 30, 's', name='Body1'), w=740, align='center')
    cf += at(380, 160, T('Yours to keep. Looks only.', 22, 'xs', 'f-dim', name='Body2'), w=740, align='center')
    cf += btn(80, 214, 280, 80, 'lime', bl('BUY', 34, name='YesText'), name='BtnYes') + btn(400, 214, 280, 80, 'grey', bl('CANCEL', 34, name='NoText'), name='BtnNo')
    out += grp('Confirm', f"<div class='cp a-pink' data-n='Card' style='left:1000px;top:560px;width:760px;height:330px'>{cf}</div>", 'TL')
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
    out += cap(40, 930, '4. Icons (drawn for this game, one finish) + egg pieces matched to the eggs')
    for i, ic in enumerate(['gold', 'gem', 'piece_common', 'piece_rare', 'piece_epic', 'piece_crowned', 'quests', 'incubator', 'pets', 'shop', 'stats', 'settings',
                            'runner', 'catcher', 'safe', 'steal', 'ab_dash', 'ab_invis', 'ab_decoy', 'ab_shield', 'ab_wall', 'ab_tackle', 'trophy', 'crown']):
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
    ('shop.html', 'Shop (Gold)', 'Gold cosmetics: one-match and keep-forever', s_shop, 1080),
    ('shop_gems.html', 'Shop (Gems)', 'Premium cosmetics for Gems', lambda: s_shop('gems'), 1080),
    ('shop_robux.html', 'Shop (Robux Gem packs, later)', 'Hidden until approved', s_shop_robux, 1080),
    ('stats.html', 'Stats', 'Your record', s_stats, 1080),
    ('settings.html', 'Settings', 'Real settings, toggles, tabs', s_settings, 1080),
    ('results.html', 'Results', 'Winner, podium, top thief, your rewards', s_results, 1080),
    ('hatch.html', 'Hatch reveal', 'New pet moment', s_hatch, 1080),
    ('templates.html', 'Banners + toasts + confirm', 'Runtime templates', s_templates, 1080),
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
