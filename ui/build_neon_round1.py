#!/usr/bin/env python3
"""Evolve or Steal UI (HTML first, roblox-ui-maker). Generates every page + index.html.

    cd ui && python3 tools/fetch_textures.py      # ui-resources.com textures -> tex/ (not committed)
    python3 tools/icons_svg.py && node tools/render_icons.mjs   # PLACEHOLDER icons -> icons/
    python3 build.py && python3 -m http.server 8870 --bind 127.0.0.1    # open /index.html

Style: styles/neon.css (read from ref.png "Season Pass" + ref2.png "Settings"; inspired by, not a copy).
Each screen has one accent: Incubator lime, Settings red, Shop gold, Pets cyan, Quests purple, Stats gold.
Data on the pages comes from the live game config (EconomyConfig / GameConfig, Oct 2026) where it exists.
Textures: ui-resources.com (credits in tools/textures.json). Icons: placeholder SVG set (tools/icons_svg.py)
until a licensed icon pack is chosen; slugs stay the same when it is swapped.
Export markers are the roblox-ui-maker ones (grp/sub/data-n/hid); never a double quote inside style='...'.
"""
import html
import os

HERE = os.path.dirname(os.path.abspath(__file__))
STYLE = os.environ.get('UI_STYLE', 'neon')
FONTS = ("<link rel='preconnect' href='https://fonts.googleapis.com'>"
         "<link href='https://fonts.googleapis.com/css2?family=Montserrat:ital,wght@0,600;0,700;0,800;0,900;1,700;1,800;1,900"
         "&display=block' rel='stylesheet'>")


# ---------------------------------------------------------------- base helpers (roblox-ui-maker markers)
def dn(name):
    return f" data-n='{name}'" if name else ''


def T(text, size, cls='', fill='', style='', name=None, tag='span'):
    t = html.escape(str(text), quote=True)
    return f"<{tag} class='ot {cls} {fill}' data-t='{t}'{dn(name)} style='font-size:{size}px;{style}'>{t}</{tag}>"


def TI(text, size, cls='', fill='', style='', name=None):
    """Italic heavy title text (the reference's look)."""
    return T(text, size, 'it ' + cls, fill, style, name)


def I(icon, x, y, w, h=None, name=None, extra='', cls='ic'):
    h = h or w
    return f"<img class='{cls}' src='icons/{icon}.png'{dn(name)} style='left:{x}px;top:{y}px;width:{w}px;height:{h}px;{extra}'>"


def icn(icon, w, name=None, extra=''):
    return f"<img class='icn' src='icons/{icon}.png'{dn(name)} style='width:{w}px;height:{w}px;{extra}'>"


def grp(name, inner, anchor='C'):
    return f"<div class='abs fill grp' data-g='{name}' data-a='{anchor}' style='pointer-events:none'>{inner}</div>"


def sub(name, inner, btn=False, opens=None, hid=False):
    extra = (' data-btn=1' if btn else '') + (f" data-opens='{opens}'" if opens else '')
    return f"<div class='abs fill sub{' hid' if hid else ''}' data-n='{name}'{extra} style='pointer-events:none'>{inner}</div>"


def box(x, y, w, h, inner='', cls='', style='', name=None, hid=False):
    return f"<div class='abs {cls}{' hid' if hid else ''}'{dn(name)} style='left:{x}px;top:{y}px;width:{w}px;height:{h}px;{style}'>{inner}</div>"


def at(x, y, inner, w=None, align='left', name=None, style=''):
    """Place inline content (text, icon rows) with its left (or centre/right edge) at x."""
    if align == 'center':
        return f"<div class='abs'{dn(name)} style='left:{x - (w or 600) // 2}px;width:{w or 600}px;top:{y}px;text-align:center;{style}'>{inner}</div>"
    if align == 'right':
        return f"<div class='abs'{dn(name)} style='left:{x - (w or 600)}px;width:{w or 600}px;top:{y}px;text-align:right;{style}'>{inner}</div>"
    return f"<div class='abs'{dn(name)} style='left:{x}px;top:{y}px;white-space:nowrap;{style}'>{inner}</div>"


def row(*parts, gap=10):
    return f"<span style='display:inline-flex;align-items:center;gap:{gap}px'>{''.join(parts)}</span>"


# ---------------------------------------------------------------- neon components
def banner(x, y, w, h, title, acc, icon=None, size=66, name='Title', spark=True):
    ic = icn(icon, int(h * .72)) if icon else ''
    spk = "<img class='spk' src='icons/sparkle.png'>" if spark else ''
    return (f"<div class='bn a-{acc}'{dn('Banner')} style='left:{x}px;top:{y}px;width:{w}px;height:{h}px;--sl:{int(h * .42)}px;--nt:{int(h * .3)}px'>"
            f"<div class='bn-ol'></div><div class='bn-face'></div><div class='lbl'>{ic}{TI(title, size, 'l k9', name=name)}</div>{spk}</div>")


def nb(x, y, w, h, color, label, name=None, cls='', cut=14, lip=7, style='', hid=False, opens=None):
    extra = (f" data-opens='{opens}'" if opens else '')
    return (f"<div class='nb b-{color} {cls}{' hid' if hid else ''}'{dn(name)}{extra} style='left:{x}px;top:{y}px;width:{w}px;height:{h}px;--cut:{cut}px;--lip:{lip}px;{style}'>"
            f"<div class='o'></div><div class='f'></div><div class='lbl'>{label}</div></div>")


def closex(x, y):
    return f"<div class='nx' data-n='CloseButton' data-btn=1 style='left:{x}px;top:{y}px'><div class='o'></div><div class='f'></div><div class='lbl'>{TI('X', 58, 'l k9')}</div></div>"


def tile(x, y, w, h, kind, inner='', art='', cls='', name=None, style=''):
    """Reward/item tile. `art` sits in an .art layer (dimmed when locked); `inner` stays bright (lock, labels)."""
    return (f"<div class='nt t-{kind} {cls}'{dn(name)} style='left:{x}px;top:{y}px;width:{w}px;height:{h}px;{style}'>"
            f"<div class='abs fill art'>{art}</div>{inner}</div>")


def chip(x, y, w, h, color, label, name=None, hid=False):
    return (f"<div class='chip b-{color}{' hid' if hid else ''}'{dn(name)} style='left:{x}px;top:{y}px;width:{w}px;height:{h}px'>"
            f"<div class='o'></div><div class='f'></div><div class='lbl'>{label}</div></div>")


def npanel(gname, title, acc, icon, body, x, y, w, h, bw=600):
    out = f"<div class='np-glow a-{acc}' style='left:{x - 24}px;top:{y - 12}px;width:{w + 48}px;height:{h + 36}px'></div>"
    out += f"<div class='np-back a-{acc}' style='left:{x - 22}px;top:{y + 30}px;width:{w + 34}px;height:{h + 22}px'></div>"
    out += (f"<div class='np a-{acc}' data-n='Panel' style='left:{x}px;top:{y}px;width:{w}px;height:{h}px'>"
            f"<div class='hc2'></div><div class='body'>{body}</div></div>")
    out += banner(x - 44, y - 64, bw, 112, title, acc, icon)
    out += closex(x + w - 78, y - 50)
    return grp(gname, out, 'C')


def hpill(x, y, w, h, acc, icon, label, name, opens=None, size=34, sub_txt=None):
    lab = TI(label, size, 's k9', name='Label')
    if sub_txt:
        lab = f"<span style='display:flex;flex-direction:column;gap:2px'>{lab}{T(sub_txt, 20, 'xs it', 'f-grey', name='Sub')}</span>"
    inner = (f"<div class='hp a-{acc}' style='left:{x}px;top:{y}px;width:{w}px;height:{h}px'>"
             f"<div class='o'></div><div class='f'></div><div class='lbl'>{icn(icon, int(h * .66))}{lab}</div></div>")
    return sub(name, inner, btn=True, opens=opens)


def hbtn(x, y, s, kind, icon, label, name, opens=None, state=None, badge=None):
    inner = (f"<div class='hb t-{kind}' style='left:{x}px;top:{y}px;width:{s}px;height:{s}px'><div class='o'></div><div class='f'></div></div>")
    inner += I(icon, x + int(s * .19), y + int(s * .1), int(s * .62), name='Icon')
    inner += at(x + s // 2, y + s - 42, TI(label, 27, 's k9', name='Label'), w=s + 30, align='center')
    if state:
        on = state == 'ON'
        inner += chip(x + s - 58, y - 12, 74, 34, 'green' if on else 'dark', T(state, 19, 'xs it', name='StateText'), name='State')
    if badge:
        inner += box(x + s - 30, y - 14, 44, 44, T(badge, 26, 'xs'), 'badge hid', name='Badge')
    return sub(name, inner, btn=True, opens=opens)


def world(img='bg_lobby.jpg', vign=True):
    return f"<img class='world' src='{img}' style='position:absolute;left:0;top:0;width:1920px;height:1080px;object-fit:cover'>" + ("<div class='vign'></div>" if vign else '')


def dim(a=.5):
    return grp('Dim', f"<div class='abs fill' style='background:rgba(2,4,8,{a})'></div>", 'FILL')


def topbar():
    return "<div class='rbx' style='left:16px;top:12px;width:200px;height:64px;border-radius:18px'>Roblox top bar</div>"


def cap(x, y, text):
    return f"<div class='cap' style='left:{x}px;top:{y}px'>{html.escape(text)}</div>"


# ---------------------------------------------------------------- game data (from the live config, Oct 2026)
FAMILIES = [  # family, ability, icon, tile kind, species by rarity, short, cooldown
    ('Decoy', 'DECOY', 'decoy', 'gold', {'common': 'Mouse', 'rare': 'Parrot', 'epic': 'Mirror Dragon'}, 'A running copy of you', 20),
    ('Scout', 'SCOUT', 'scout', 'cyan', {'common': 'Sparrow', 'rare': 'Seagull', 'epic': 'Celestial Owl'}, 'See the 3 nearest foes', 18),
    ('Brake', 'BRAKE', 'brake', 'lime', {'common': 'Turtle', 'rare': 'Hermit Crab', 'epic': 'Time Spirit'}, 'Stop dead and cut', 10),
]
RECIPES = {'common': (2, 3), 'rare': (3, 4), 'epic': (5, 6)}   # base (random family), focus (chosen family)
PIECES = {'common': 2, 'rare': 1, 'epic': 0}                     # sample player: 2 matches in, first pet not hatched


# ---------------------------------------------------------------- HUD (lobby)
def wallet():
    out = ''
    for i, (icon, acc, val, fill, label) in enumerate([('gem', 'lime', '12', 'f-green', 'GEMS'), ('gold', 'gold', '1,250', 'f-gold', 'GOLD')]):
        y = 856 + i * 104
        out += (f"<div class='hp a-{acc}' style='left:56px;top:{y}px;width:330px;height:86px'><div class='o'></div><div class='f'></div></div>")
        out += I(icon, 22, y - 8, 100, name=f'{label.title()}Icon')
        out += at(132, y + 8, TI(val, 46, 'k9', fill, name=f'{label.title()}Text'))
        out += at(134, y + 56, T(label, 18, 'xs it', 'f-grey'))
    return grp('Wallet', out, 'BL')


def ability_card(y=948, cd=None, lobby=True):
    fam = FAMILIES[0]
    x, w, h = 700, 520, 104
    out = f"<div class='hp a-gold' style='left:{x}px;top:{y}px;width:{w}px;height:{h}px'><div class='o'></div><div class='f'></div></div>"
    out += tile(x + 30, y + 10, 84, 84, fam[3], art=I(fam[2], 8, 6, 64), name='PetTile')
    out += at(x + 132, y + 10, TI(fam[1], 44, 'k9', name='AbilityName'))
    status = 'MOUSE  ·  EQUIPPED' if lobby else ('READY' if cd is None else f'RECHARGING  {cd}s')
    out += at(x + 134, y + 62, T(status, 21, 'xs it', 'f-yellow' if cd is None else 'f-grey', name='Status'))
    out += f"<div class='keycap' data-n='Key' style='left:{x + w - 92}px;top:{y + 20}px'>{T('Q', 34, 's')}</div>"
    frac = 1 if cd is None else .38
    out += f"<div class='cd a-gold' data-n='Cooldown' style='left:{x + 22}px;top:{y + h - 8}px;width:{w - 44}px'><i style='width:{frac * 100:.0f}%'></i></div>"
    return grp('Ability', out, 'B')


def lobby_status():
    out = chip(900, 14, 120, 40, 'cyan', T('LOBBY', 22, 'xs it'), name='PhaseChip')
    out += at(960, 62, TI('NEXT MATCH IN', 26, 's k9', 'f-grey', name='Headline'), w=500, align='center')
    out += at(960, 92, TI('0:12', 84, 'xl k9', name='Timer'), w=500, align='center')
    out += at(960, 186, TI('4 PLAYERS READY', 28, 's k9', 'f-lime', name='Subline'), w=600, align='center')
    return grp('Status', out, 'T')


def goal_pill():
    x, y, w, h = 236, 106, 530, 100
    out = f"<div class='hp a-lime' style='left:{x}px;top:{y}px;width:{w}px;height:{h}px'><div class='o'></div><div class='f'></div></div>"
    out += tile(x + 30, y + 12, 76, 76, 'common', art=I('piece_common', 6, 4, 64), name='GoalTile')
    out += at(x + 122, y + 12, TI('FIRST PET READY!', 28, 's k9', name='GoalTitle'))
    out += at(x + w - 34, y + 14, T('2 / 2', 26, 's it', 'f-lime', name='GoalCount'), w=140, align='right')
    out += f"<div class='trk a-lime' data-n='GoalBar' style='left:{x + 122}px;top:{y + 54}px;width:{w - 168}px;height:22px'><i style='width:100%'></i></div>"
    return sub('GoalPill', out, btn=True, opens='Incubator')


def hud_groups():
    tl = hpill(236, 18, 236, 74, 'cyan', 'scroll', 'QUESTS', 'QuestsButton', 'Quests') + hpill(486, 18, 296, 74, 'lime', 'incubator', 'INCUBATOR', 'IncubatorButton', 'Incubator', size=30)
    tl += goal_pill()
    tr = hpill(1366, 18, 238, 74, 'gold', 'chart', 'STATS', 'StatsButton', 'Stats') + hpill(1618, 18, 280, 74, 'red', 'gear', 'SETTINGS', 'SettingsButton', 'Settings')
    left = (hbtn(26, 252, 128, 'gold', 'bag', 'SHOP', 'ShopButton', 'Shop') +
            hbtn(26, 400, 128, 'cyan', 'paw', 'PETS', 'PetsButton', 'Pets') +
            hbtn(26, 548, 128, 'dark', 'afk', 'AFK', 'AFKToggle', state='OFF') +
            hbtn(26, 696, 128, 'red', 'crosshair', 'HUNT', 'VolunteerToggle', state='ON'))
    return grp('TopLeft', tl, 'TL') + grp('TopRight', tr, 'TR') + grp('LeftRail', left, 'L') + lobby_status() + wallet() + ability_card()


def s_hud():
    return world() + topbar() + hud_groups()


# ---------------------------------------------------------------- HUD (in a match: economy hidden, GDD 14)
def s_hud_match():
    out = world() + topbar()
    # role tag (top-left)
    out += grp('Role', hpill(236, 18, 340, 92, 'cyan', 'runner', 'RUNNER', 'RoleTag', size=40, sub_txt='Reach the safe zone!'), 'TL')
    # crossing bar (top-centre)
    mb = chip(830, 14, 260, 44, 'lime', TI('CROSSING 2', 24, 'xs k9', name='WaveText'), name='WaveChip')
    mb += at(960, 60, TI('0:21', 92, 'xl k9', name='Timer'), w=400, align='center')
    mb += chip(596, 86, 236, 56, 'cyan', row(icn('runner', 40), TI('14 RUNNERS', 24, 'xs k9', name='RunnersText')), name='Runners')
    mb += chip(1088, 86, 236, 56, 'red', row(icn('knife', 38), TI('4 CATCHERS', 24, 'xs k9', name='CatchersText')), name='Catchers')
    mb += at(960, 166, T('CLEAN STREAK', 20, 'xs it', 'f-grey'), w=300, align='center')
    for i in range(3):
        mb += f"<div class='pip a-lime{' on' if i == 0 else ''}' data-n='Streak{i + 1}' style='left:{918 + i * 34}px;top:{198}px'></div>"
    out += grp('MatchBar', mb, 'T')
    # egg level (bottom-left): the one unobtrusive indicator the GDD keeps on screen
    eg = f"<div class='hp a-cyan' style='left:56px;top:900px;width:420px;height:150px'><div class='o'></div><div class='f'></div></div>"
    eg += tile(30, 884, 150, 150, 'rare', art=I('egg', 18, 14, 114), name='EggTile')
    eg += at(198, 916, T('YOUR EGG', 22, 'xs it', 'f-grey'))
    eg += at(198, 944, TI('LEVEL 2', 50, 'l k9', 'f-blue', name='EggLevel'))
    for i in range(4):
        eg += f"<div class='pip a-cyan{' on' if i < 2 else ''}' data-n='Lv{i + 1}' style='left:{206 + i * 42}px;top:{1010}px'></div>"
    eg += at(380, 1006, row(T('PAYS', 16, 'xs it', 'f-grey'), T('RARE', 20, 'xs it', 'f-blue', name='PaysText'), gap=6))
    out += grp('Egg', eg, 'BL')
    # kill feed (top-right)
    fd = ''
    for i, (a, verb, b, col) in enumerate([('Kai', 'STOLE', "Mia's Lv2 egg", 'f-red'), ('Zoe', 'MADE IT', 'Lv3 egg!', 'f-lime'), ('Ben', 'CAUGHT', 'Leo', 'f-red')]):
        y = 130 + i * 62
        fd += f"<div class='hp a-{'red' if col == 'f-red' else 'lime'}' style='left:1440px;top:{y}px;width:460px;height:52px;opacity:{1 - i * .18}'><div class='o'></div><div class='f'></div></div>"
        fd += at(1476, y + 12, row(TI(a, 22, 'xs k9'), TI(verb, 22, 'xs k9', col), TI(b, 22, 'xs k9'), gap=8))
    out += grp('Feed', fd, 'TR')
    out += ability_card(cd=8, lobby=False)
    # dash (Space): small chip beside the ability card; touch gets a round button instead (phone page)
    out += grp('Dash', nb(1236, 958, 170, 84, 'dark', row(TI('DASH', 26, 's k9'), T('SPACE', 16, 'xs', 'f-grey')), name='DashChip', cut=12, lip=6), 'B')
    out += cap(470, 470, 'In a match only role, timer, egg level and ability stay (GDD 14). World = stand-in lobby capture.')
    return out


# ---------------------------------------------------------------- Incubator (GDD 03 / 09 / 14)
def s_incubator():
    x0, y0, W, H = 250, 170, 1420, 820
    b = at(40, 74, TI('YOUR PIECES', 28, 's k9'))
    D = 40  # content starts below the banner
    for i, (m, kind) in enumerate([('common', 'common'), ('rare', 'rare'), ('epic', 'epic')]):
        n = PIECES[m]
        tx = 40 + i * 166
        b += tile(tx, 80 + D, 150, 150, kind, cls='locked' if n == 0 else '', name=f'Piece_{m}',
                  art=I('piece_' + m, 27, 22, 96),
                  inner=at(75, 6, TI(m.upper(), 22, 'xs k9'), w=150, align='center') +
                  at(140, 104, TI(f'x{n}', 36, 's k9', name='Count'), w=120, align='right'))
    # first-pet track (season-pass language): Start -> match 1 -> match 2 -> hatch
    b += at(580, 74, row(TI('YOUR FIRST PET', 28, 's k9'), T('free family choice', 22, 'xs it', 'f-lime'), gap=14))
    b += f"<div class='trk a-lime' style='left:620px;top:{148 + D}px;width:720px'><i style='width:68%'></i></div>"
    nodes = [('START', True, None), ('1', True, 'check'), ('2', True, 'check'), ('HATCH', True, 'egg')]
    for i, (lab, on, ic) in enumerate(nodes):
        nx = 580 + i * 236
        inner = icn(ic, 54) if ic and lab not in ('1', '2') else TI(lab, 40 if len(lab) < 3 else 22, 'k9')
        b += f"<div class='node a-{'gold' if lab == 'HATCH' else 'lime'}{' on' if on else ''}' style='left:{nx}px;top:{118 + D}px'>{inner}</div>"
        sub_l = {'START': '', '1': '1st match', '2': '2nd match', 'HATCH': 'ready!'}[lab]
        if sub_l:
            b += at(nx + 47, 214 + D, T(sub_l, 20, 'xs it', 'f-lime' if lab == 'HATCH' else 'f-grey'), w=200, align='center')
    b += "<div class='abs' style='left:40px;top:302px;width:1340px;height:4px;background:rgba(255,255,255,.12)'></div>"
    # tier tabs (counts vs the base recipe)
    for i, m in enumerate(['common', 'rare', 'epic']):
        base = RECIPES[m][0]
        active = i == 0
        b += nb(40 + i * 236, 326, 220, 66, 'lime' if active else 'dark', row(TI(m.upper(), 26, 's k9'), T(f'{PIECES[m]}/{base}', 20, 'xs it', 'f-grey' if not active else '')),
                name=f'Tab_{m}', cut=12, lip=6)
    # family cards
    for i, (fam, ab, ic, kind, species, short, cd) in enumerate(FAMILIES):
        cx = 40 + i * 316
        sel = i == 0
        inner = at(150, 14, TI(ab, 34, 'k9'), w=300, align='center')
        inner += at(150, 214, TI(species['common'], 30, 's k9', name='Species'), w=300, align='center')
        inner += at(150, 256, T(short, 20, 'xs it', 'f-grey', name='Desc'), w=290, align='center')
        inner += chip(98 if not sel else 12, 296, 104, 34, 'dark', T(f'{cd}s', 18, 'xs it'))
        if sel:
            inner += chip(186, 296, 104, 34, 'green', T('PICKED', 16, 'xs it'), name='Picked')
        b += tile(cx, 412, 300, 350, kind, cls='sel' if sel else '', name=f'Family_{fam}',
                  art=I(ic, 70, 56, 160), inner=inner)
    # hatch box
    hb = at(184, 22, TI('HATCH', 40, 'l k9'), w=360, align='center')
    hb += at(184, 76, T('Common pet  ·  Decoy family', 21, 'xs it', 'f-grey'), w=360, align='center')
    hb += chip(42, 118, 284, 40, 'gold', TI('1ST PET: FREE CHOICE', 18, 'xs k9'), name='FirstFree')
    hb += nb(22, 178, 324, 112, 'green', f"<span style='display:flex;flex-direction:column;align-items:center;gap:4px'>{TI('HATCH MOUSE', 34, 's k9', name='HatchText')}{row(icn('piece_common', 30), T('2 pieces', 20, 'xs it', name='CostText'))}</span>", name='BtnHatch', lip=9)
    hb += at(184, 308, T('After your first pet:', 18, 'xs it', 'f-grey'), w=360, align='center')
    hb += at(184, 334, row(icn('dice', 28), T('random 2', 18, 'xs it'), icn('target', 28), T('choose 3', 18, 'xs it')), w=360, align='center')
    b += box(1006, 412, 368, 350, hb, '', 'background:rgba(0,0,0,.38);border:3px solid rgba(255,255,255,.14);border-radius:8px', name='HatchBox')
    return world('bg_lobby_blur.jpg', False) + dim(.25) + npanel('Incubator', 'INCUBATOR', 'lime', 'incubator', b, x0, y0, W, H, bw=600)


# ---------------------------------------------------------------- Settings (ref2 language, real settings only)
SETTINGS = [  # tab, title, desc, affects, on
    ('Reduce Effects', 'Fewer particles, no camera shake or speed zoom.', 'Visuals only', False),
    ('Show Hints', 'Tips on screen while you learn the game.', 'Visuals only', True),
    ('Volunteer To Hunt', 'Start matches as a Catcher when there is room.', 'Your starting role', False),
]


def s_settings():
    x0, y0, W, H = 330, 190, 1260, 770
    b = ''
    for i, (title, desc, aff, on) in enumerate(SETTINGS):
        y = 52 + i * 186
        inner = at(30, 18, TI(title, 50, 'l k9', name='Title'))
        inner += at(32, 84, TI(desc, 26, 's', 'f-red', name='Desc'))
        inner += at(32, 122, row(TI('Affects', 24, 's k9'), TI('-', 24, 's'), TI(aff.upper(), 24, 's k9', 'f-red', name='Affects'), gap=10))
        inner += nb(908, 22, 220, 74, 'green' if on else 'silver', TI('ON' if on else 'OFF', 32, 's k9', name='ToggleText'), name='Toggle', lip=7)
        b += box(52, y, 1156, 166, inner, 'nr a-red', name=f'Row{i + 1}')
    for i, (tab, active) in enumerate([('GAME', True), ('AUDIO', False), ('CONTROLS', False)]):
        b += nb(52 + i * 394, 640, 370, 80, 'red' if active else 'silver', TI(tab, 32, 's k9'), name=f'Tab{tab.title()}', lip=7)
    return world('bg_lobby_blur.jpg', False) + dim(.3) + npanel('Settings', 'SETTINGS', 'red', 'gear', b, x0, y0, W, H, bw=560)


# ---------------------------------------------------------------- style sheet: references -> tokens -> kit
def s_style():
    out = "<div class='abs fill' style='background:#0d1015'></div>"
    out += cap(40, 20, '1. The references (style only: their watermark, items and exact layout are not copied)')
    out += "<img class='abs' src='ref.png' style='left:40px;top:66px;width:900px;height:506px;object-fit:cover;border-radius:10px'>"
    out += "<img class='abs' src='ref2.png' style='left:980px;top:66px;width:900px;height:506px;object-fit:cover;border-radius:10px'>"
    out += cap(40, 600, '2. Our kit (styles/neon.css): one accent per screen, banner + panel + chamfer buttons + striped tiles')
    for i, (acc, t) in enumerate([('lime', 'INCUBATOR'), ('red', 'SETTINGS'), ('gold', 'SHOP'), ('cyan', 'PETS'), ('purple', 'QUESTS')]):
        out += banner(40 + (i % 3) * 610, 660 + (i // 3) * 150, 520, 100, t, acc, size=54)
    out += closex(1290, 820)
    y = 980
    out += cap(40, y - 10, 'buttons: normal / hover / pressed / off, colours')
    for j, st in enumerate(['', 'st-hover', 'st-press', 'off']):
        out += nb(40 + j * 250, y + 40, 230, 84, 'green', TI('HATCH', 34, 's k9'), cls=st)
    for j, c in enumerate(['red', 'pink', 'silver', 'gold', 'cyan', 'purple']):
        out += nb(1060 + (j % 3) * 280, y + 40 + (j // 3) * 100, 260, 84, c, TI(c.upper(), 30, 's k9'))
    y = 1230
    out += cap(40, y - 10, 'tiles: common / rare / epic / selected / locked (empty)')
    for j, (k, ic, cls) in enumerate([('common', 'piece_common', ''), ('rare', 'piece_rare', ''), ('epic', 'piece_epic', ''), ('gold', 'decoy', 'sel'), ('epic', 'piece_epic', 'locked')]):
        inner = at(85, 8, TI(['COMMON', 'RARE', 'EPIC', 'DECOY', 'EPIC'][j], 22, 'xs k9'), w=170, align='center')
        if cls == 'locked':
            inner += I('lock', 50, 56, 70)
        inner += nb(25, 124, 120, 40, 'green', T('Claim', 18, 'xs it'), cut=8, lip=4) if j in (0, 1) else ''
        out += tile(40 + j * 200, y + 40, 170, 170, k, art=I(ic, 40, 36, 90), cls=cls, inner=inner)
    out += cap(1060, y - 10, 'chips, track + nodes, key cap, cooldown, pips')
    out += chip(1060, y + 40, 150, 44, 'lime', T('LOBBY', 22, 'xs it')) + chip(1230, y + 40, 220, 50, 'cyan', row(icn('runner', 36), TI('14 RUNNERS', 20, 'xs k9')))
    out += f"<div class='trk a-lime' style='left:1060px;top:{y + 140}px;width:560px'><i style='width:44%'></i></div>"
    out += f"<div class='node a-lime on' style='left:1040px;top:{y + 110}px'>{TI('1', 40, 'k9')}</div><div class='node a-lime' style='left:1300px;top:{y + 110}px'>{TI('2', 40, 'k9')}</div>"
    out += f"<div class='keycap' style='left:1660px;top:{y + 110}px'>{T('Q', 34, 's')}</div>"
    out += f"<div class='cd a-gold' style='left:1060px;top:{y + 220}px;width:400px'><i style='width:60%'></i></div>"
    for i in range(4):
        out += f"<div class='pip a-cyan{' on' if i < 2 else ''}' style='left:{1520 + i * 40}px;top:{y + 214}px'></div>"
    y = 1500
    out += cap(40, y - 10, 'list row (settings / quests) and HUD pieces')
    out += box(40, y + 40, 1000, 150, at(26, 16, TI('Reduce Effects', 46, 'l k9')) + at(28, 76, TI('Fewer particles, no camera shake.', 24, 's', 'f-red')) +
               nb(760, 24, 200, 70, 'silver', TI('OFF', 30, 's k9')), 'nr a-red')
    out += hpill(1080, y + 40, 300, 74, 'lime', 'incubator', 'INCUBATOR', 'x', size=30) + hbtn(1400, y + 40, 136, 'gold', 'bag', 'SHOP', 'y')
    out += hbtn(1580, y + 40, 136, 'red', 'crosshair', 'HUNT', 'z', state='ON')
    return out


# ---------------------------------------------------------------- before / after
def s_compare():
    out = "<div class='abs fill' style='background:#0d1015'></div>"
    out += cap(40, 20, 'BEFORE: current lobby HUD (Studio capture, Hatch or Snatch place, 15 Oct 2026)')
    out += "<img class='abs' src='cap_lobby_before.jpg' style='left:40px;top:66px;width:1840px;height:982px;object-fit:contain'>"
    return out


# ---------------------------------------------------------------- page shell
JS = """
<script>
const q = new URLSearchParams(location.search);
if(q.get('style')) document.getElementById('preset').href='styles/'+q.get('style')+'.css';
function fit(){ const w=document.getElementById('wrap');
  if(q.has('raw')){ w.style.transform='none'; return; }
  const H=document.getElementById('stage').offsetHeight;
  const s=Math.min(innerWidth/1920, innerHeight/H); w.style.transform='scale('+s+')';
  w.style.left=((innerWidth-1920*s)/2)+'px'; w.style.top=((innerHeight-H*s)/2)+'px'; }
addEventListener('resize', fit); fit();
const BOX='.nb,.nt,.nr,.hp,.chip,.node,.keycap,.inset';
window.checkOverflow = function(){
  const bad=[]; const st=document.getElementById('stage').getBoundingClientRect();
  document.querySelectorAll('.ot').forEach(e=>{
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
            + ("<link rel='stylesheet' href='style.css'>" if os.path.exists(os.path.join(HERE, 'style.css')) else '')
            + "</head><body>"
            f"<div id='wrap'><div id='stage' style='height:{h}px'>{body}</div></div>{JS}</body></html>")


SCREENS = [  # (file, title, description, fn, height)
    ('style.html', 'Style: references -> kit', 'The two references and the neon kit drawn from them', s_style, 1740),
    ('hud.html', 'HUD (lobby)', 'Menus, wallet, first-pet goal, equipped ability', s_hud, 1080),
    ('hud_match.html', 'HUD (in a match)', 'Role, crossing timer, teams, clean streak, egg level, ability, feed', s_hud_match, 1080),
    ('incubator.html', 'Incubator', 'Pieces, first-pet track, tiers, families, hatch', s_incubator, 1080),
    ('settings.html', 'Settings', 'Game / Audio / Controls with the real settings', s_settings, 1080),
    ('compare.html', 'Before', 'The current lobby HUD, for comparison', s_compare, 1080),
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
:root{{--bg:#0b0e12;--card:#141a21;--ink:#eef3f8;--mute:#9aa7b4;--line:#26303b}}
body{{margin:0;background:var(--bg);color:var(--ink);font-family:'Montserrat',sans-serif}}
header{{padding:24px 16px 8px}} h1{{margin:0;font-weight:900;font-style:italic;font-size:30px}} header p{{color:var(--mute);margin:6px 0 0;font-weight:600}}
.grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:16px;padding:16px}}
.card{{display:block;background:var(--card);border:1px solid var(--line);border-radius:14px;overflow:hidden;color:inherit;text-decoration:none}}
.frame{{position:relative;width:100%;overflow:hidden;background:#000}}
.frame iframe{{position:absolute;left:0;top:0;width:1920px;border:0;transform-origin:0 0;pointer-events:none}}
h3{{margin:12px 14px 2px;font-size:18px}} .card p{{margin:0 14px 14px;color:var(--mute);font-size:13px;font-weight:600}}
</style></head><body><header><h1>Evolve or Steal UI</h1><p>{len(SCREENS)} pages at 1920 wide. Click one to open it full size.</p></header>
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
