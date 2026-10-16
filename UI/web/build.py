#!/usr/bin/env python3
"""Hatch or Snatch UI (roblox-ui-maker project): the emote crate opening.

Made with the roblox-ui-maker skill (.claude/skills/roblox-ui-maker). This file is the source of truth:
edit it, run it, never hand-edit the generated .html.

    python3 make_placeholders.py      # stand-in stud.png (if missing) + the empty emote image slot
    python3 build.py                  # writes the pages below + index.html
    python3 -m http.server 8870 --bind 127.0.0.1    # then open http://127.0.0.1:8870/index.html

Style: the skill's stud preset (styles/stud.css). There is no Hatch or Snatch style reference yet:
drop a screenshot of the current game UI in as ref.png, run read_reference.py (SKILL.md step 1) and put
the overrides in style.css. Textures: replace the stand-in stud.png with the ui-resources.com "Stud
texture". Icons: none from a pack yet; the emote and crate pictures are swapped in at runtime.

Pages (1920x1080 stage, ?raw = 1:1 for headless/export, ?check = flag overflowing text):
    style.html                  tokens in use (stud preset) and where the reference goes
    emote_crate.html            the reel at rest, prize under the markers            -> exported
    emote_crate_intro.html      the crate wobbling before it bursts (CrateStage)     -> exported (hidden)
    emote_crate_reveal.html     the reveal card over the landed reel (Reveal)        -> exported (hidden)
    emote_crate_templates.html  one reel tile per rarity                             -> templates
    emote_crate_states.html     every state on one sheet (review only)
    emote_crate_spin.html       the whole opening, animated, same timings as the runtime (review only)

Export markers (scripts/dump.js): grp(name, html, anchor) = top-level frame anchored to a screen edge;
sub(name, html, btn) = invisible named frame / button; name=... = the instance name the runtime looks up;
hid=True = exported but Visible=false. Never put a double quote inside an inline style="...".
"""
import html
import os

HERE = os.path.dirname(os.path.abspath(__file__))
STYLE = os.environ.get('UI_STYLE', 'stud')
FONTS = ("<link rel='preconnect' href='https://fonts.googleapis.com'>"
         "<link href='https://fonts.googleapis.com/css2?family=Montserrat:wght@700;800;900"
         "&family=Source+Sans+3:wght@600;700&display=block' rel='stylesheet'>")


# ---------------------------------------------------------------- components
def dn(name):
    return f" data-n='{name}'" if name else ''


def T(text, size, cls='', fill='', style='', name=None, tag='span'):
    """Outlined live text. cls: xs/s/(default)/l/xl stroke sizes; fill: f-green etc."""
    t = html.escape(str(text), quote=True)
    return f"<{tag} class='ot {cls} {fill}' data-t='{t}'{dn(name)} style='font-size:{size}px;{style}'>{t}</{tag}>"


def I(icon, x, y, w, h=None, name=None, extra='', cls='ic'):
    h = h or w
    return f"<img class='{cls}' src='icons/{icon}.png'{dn(name)} style='left:{x}px;top:{y}px;width:{w}px;height:{h}px;{extra}'>"


def icn(icon, w, name=None, extra=''):
    return f"<img class='icn' src='icons/{icon}.png'{dn(name)} style='width:{w}px;height:{w}px;{extra}'>"


def grp(name, inner, anchor='C'):
    """Export group: invisible full-stage wrapper (coordinates unchanged) naming a top-level frame and
    the screen edge it sticks to: TL T TR L C R BL B BR, or FILL (full screen, e.g. Dim)."""
    return f"<div class='abs fill grp' data-g='{name}' data-a='{anchor}' style='pointer-events:none'>{inner}</div>"


def sub(name, inner, btn=False, opens=None, hid=False):
    """Invisible named frame whose box is the union of its children (btn=True -> TextButton)."""
    extra = (' data-btn=1' if btn else '') + (f" data-opens='{opens}'" if opens else '')
    return f"<div class='abs fill sub{' hid' if hid else ''}' data-n='{name}'{extra} style='pointer-events:none'>{inner}</div>"


def box(x, y, w, h, inner='', cls='', style='', name=None, hid=False):
    return f"<div class='abs {cls}{' hid' if hid else ''}'{dn(name)} style='left:{x}px;top:{y}px;width:{w}px;height:{h}px;{style}'>{inner}</div>"


def flex(inner, style=''):
    return f"<div class='abs fill' style='display:flex;align-items:center;justify-content:center;{style}'>{inner}</div>"


def plate(x, y, w, h, color, label='', cls='', name=None, opens=None, style='', lbl_style='', hid=False):
    extra = dn(name) + (f" data-opens='{opens}'" if opens else '')
    return (f"<div class='plate c-{color} {cls}{' hid' if hid else ''}'{extra} style='left:{x}px;top:{y}px;width:{w}px;height:{h}px;{style}'>"
            f"<div class='lbl' style='{lbl_style}'>{label}</div></div>")


def closeb():
    return f"<div class='plate c-red closeb' data-n='CloseButton'><div class='lbl'>{T('X', 50, 'l')}</div></div>"


def badge(x, y, text, name=None, hid=False):
    return f"<div class='badge{' hid' if hid else ''}'{dn(name)} style='left:{x}px;top:{y}px'>{T(text, 28, 'xs', name='BadgeText')}</div>"


def bar(x, y, w, h, frac, grad='g-green', name='Bar'):
    """Bar frame + fill child F (runtime: UIKit.bar(bar, frac))."""
    return (f"<div class='bar' data-n='{name}' style='left:{x}px;top:{y}px;width:{w}px;height:{h}px'>"
            f"<i class='{grad}' data-n='F' style='width:{frac * 100:.1f}%'></i></div>")


def dim(a=.45):
    return grp('Dim', "<div class='abs fill' style='background:rgba(0,8,12,%s)'></div>" % a, 'FILL')


def panel(gname, title, color, icon, body, x, y, w, h):
    head = plate(-7, -7, w, 104, color, icn(icon, 84) + T(title, 58, 'l'), 'head', style=f'left:-7px;top:-7px;width:{w}px')
    return grp(gname, f"<div class='panel' data-n='Panel' style='left:{x}px;top:{y}px;width:{w}px;height:{h}px'>"
               f"{head}{closeb()}<div class='abs' style='left:0;top:97px;right:0;bottom:0'>{body}</div></div>", 'C')


def world():
    """Stand-in game world behind the UI (class .world is never exported). Swap for a real Studio
    capture of the game (<img class='world' src='bg.png'>) as soon as one exists."""
    return "<div class='world'></div>"


def roblox_topbar():
    return ("<div class='rbx' style='left:16px;top:12px;width:200px;height:64px;border-radius:18px'>Roblox top bar</div>")



# ---------------------------------------------------------------- emote crate: one rarity table
# Rarity look (border, light, dark, text fill, glow). The runtime copies these colours from
# UI/roblox/ui/client/EmoteCrateSpin.luau RARITY; keep the two in step.
RARITY = {
    'common': ('#9aa2a9', '#eef1f4', '#9aa2a9', 'f-grey', '#d9e0e6'),
    'rare': ('#2fa8ff', '#bfe6ff', '#2a7fd6', 'f-blue', '#45cfff'),
    'epic': ('#b44dff', '#efc8ff', '#8a2fd8', 'f-purple', '#d955ff'),
    'legendary': ('#ffc21c', '#fff3b8', '#f0a000', 'f-gold', '#ffd23a'),
}
HEAD_COL = {'common': 'grey', 'rare': 'blue', 'epic': 'purple', 'legendary': 'gold'}
TITLE = {'common': 'COMMON', 'rare': 'RARE!', 'epic': 'EPIC!', 'legendary': 'LEGENDARY!'}
# SAMPLE emotes for the mock only. In game the reel is filled from the crate's real emote list.
SAMPLE = {'common': ['Wave', 'Clap', 'Point', 'Cheer'], 'rare': ['Robot', 'Floss'], 'epic': ['Moonwalk'],
          'legendary': ['Golden Strut']}
TILE, GAP = 190, 16
PITCH = TILE + GAP          # 206: the runtime lays tiles out on the same pitch
STRIP_Y, STRIP_H = 415, 250
CX = 960                    # the markers point at the strip's centre


def emote_tile(x, y, emote, rarity, s=TILE, name=None, shade=False, extra=''):
    """One reel tile: rarity border + gradient, the emote's picture (Icon, swapped at runtime) and
    its name. `Shade` is the dark cover the runtime fades in on every tile but the prize."""
    bc, lt, dk, _, _ = RARITY[rarity]
    k = s / TILE
    inner = I('emote_slot', int(s * .19), int(s * .07), int(s * .62), name='Icon')
    inner += (f"<div class='abs' style='left:{int(8 * k)}px;right:{int(8 * k)}px;bottom:{int(10 * k)}px;text-align:center'>"
              f"{T(emote, int(26 * k), 's', name='EmoteName')}</div>")
    inner += f"<div class='abs fill{'' if shade else ' hid'}' data-n='Shade' style='background:rgba(4,8,12,.62)'></div>"
    return box(x, y, s, s, inner, 'tile',
               f'border:{max(3, int(7 * k))}px solid {bc};border-radius:{int(20 * k)}px;background:linear-gradient({lt},{dk});'
               f'box-shadow:0 0 0 {max(2, int(4 * k))}px #070a0e;{extra}', name=name or f'Tile_{rarity}')


def sample_row(prize_rarity='epic', n=9, prize_at=4):
    """A believable stretch of reel around the prize (sample data)."""
    seq = ['common', 'rare', 'common', 'common', prize_rarity, 'common', 'rare', 'common', 'epic'][:n]
    out = []
    used = {}
    for r in seq:
        i = used.get(r, 0)
        used[r] = i + 1
        out.append((SAMPLE[r][i % len(SAMPLE[r])], r))
    return out


def markers():
    return ("<svg class='abs' style='left:0;top:0;width:1920px;height:1080px;overflow:visible'>"
            "<polygon data-n='MarkerTop' points='930,370 990,370 960,412' fill='#ffd23a' stroke='#070a0e' stroke-width='6' stroke-linejoin='round'/>"
            "<polygon data-n='MarkerBottom' points='930,710 990,710 960,668' fill='#ffd23a' stroke='#070a0e' stroke-width='6' stroke-linejoin='round'/></svg>")


def title_grp(text='Emote Crate'):
    return grp('CrateTitle', f"<div class='abs' style='left:0;right:0;top:150px;text-align:center'>{T(text, 76, 'xl', 'f-gold', name='Title')}</div>", 'T')


def reel_grp(row=None, prize_at=4, landed=False, blur=False):
    """The strip. Track holds the tiles (runtime clears it and fills it from the plan), the prize
    sits under the markers; nothing is ever drawn over the prize."""
    row = row or sample_row()
    x0 = CX - TILE // 2 - prize_at * PITCH
    tiles = ''
    for i, (em, r) in enumerate(row):
        prize = i == prize_at
        st = ''
        if blur:
            st = 'filter:blur(5px);transform:scaleX(1.08)'
        if landed and prize:
            st = 'transform:scale(1.12);z-index:2'
        tiles += emote_tile(x0 + i * PITCH, 30, em, r, name='Prize' if prize else f'Tile{i + 1}', shade=landed and not prize, extra=st)
    pr = RARITY[row[prize_at][1]][4]
    glow = box(CX - 220, -60, 440, 370, '', '', f'background:radial-gradient(closest-side,{pr},rgba(0,0,0,0))', name='PrizeGlow', hid=not landed)
    track = box(0, 0, 1920, STRIP_H, glow + tiles, '', 'overflow:visible;z-index:0', name='Track')
    strip = box(0, STRIP_Y, 1920, STRIP_H, track, '',
                'background:rgba(0,0,0,.52);border-top:5px solid #070a0e;border-bottom:5px solid #070a0e;'
                'box-shadow:inset 0 3px 0 rgba(255,210,58,.55),inset 0 -3px 0 rgba(255,210,58,.55);overflow:hidden', name='Strip')
    fades = (box(0, STRIP_Y + 5, 260, STRIP_H - 10, '', '', 'background:linear-gradient(90deg,rgba(4,8,12,.95),rgba(4,8,12,0))', name='FadeL') +
             box(1660, STRIP_Y + 5, 260, STRIP_H - 10, '', '', 'background:linear-gradient(90deg,rgba(4,8,12,0),rgba(4,8,12,.95))', name='FadeR'))
    return grp('Reel', strip + fades + markers(), 'C')


def skip_grp():
    return grp('SkipHint', f"<div class='abs' style='left:0;right:0;top:990px;text-align:center'>{T('Tap to skip', 30, 's', 'f-grey', name='Hint')}</div>", 'B')


def crate_stage(shake=0):
    """Before the reel: the crate the player bought wobbles, then bursts. CrateIcon gets the crate's
    own picture at runtime (the one the shop shows)."""
    inner = box(660, 240, 600, 600, '', '', 'background:radial-gradient(closest-side,rgba(255,226,120,.85),rgba(255,180,40,.25) 55%,rgba(0,0,0,0))', name='Burst', hid=True)
    inner += I('emote_slot', 810, 390, 300, name='CrateIcon', extra=f'transform:rotate({shake}deg)')
    inner += f"<div class='abs' style='left:0;right:0;top:740px;text-align:center'>{T('Opening...', 40, 's', name='Status')}</div>"
    return grp('CrateStage', inner, 'C')


def rays_svg(w=1100):
    """Sunburst behind the reveal, exported WHITE and tinted with ImageColor3 per rarity; the
    runtime spins it slowly."""
    import math
    c = w / 2
    wedges = ''
    for i in range(16):
        a0, a1 = math.radians(i * 22.5 - 5), math.radians(i * 22.5 + 5)
        wedges += (f"<polygon points='{c:.0f},{c:.0f} {c + c * math.cos(a0):.0f},{c + c * math.sin(a0):.0f} "
                   f"{c + c * math.cos(a1):.0f},{c + c * math.sin(a1):.0f}' fill='url(#rf)'/>")
    return (f"<svg data-n='Rays' class='abs' width='{w}' height='{w}' style='left:{960 - c:.0f}px;top:{540 - c:.0f}px'>"
            f"<defs><radialGradient id='rf' cx='{c:.0f}' cy='{c:.0f}' r='{c:.0f}' gradientUnits='userSpaceOnUse'>"
            "<stop offset='0' stop-color='#fff' stop-opacity='.55'/><stop offset='1' stop-color='#fff' stop-opacity='0'/>"
            f"</radialGradient></defs>{wedges}</svg>")


def reveal_grp(rarity='epic', emote='Moonwalk', dupe=False, poor=False):
    bc, lt, dk, fill, gl = RARITY[rarity]
    x, y, w, h = 580, 250, 760, 660
    out = box(960 - 420, 540 - 420, 840, 840, '', '', f'background:radial-gradient(closest-side,{gl},rgba(0,0,0,0))', name='Glow')
    out += rays_svg()
    heads = ''
    for r in RARITY:
        heads += plate(-5, -5, w, 104, HEAD_COL[r], T(TITLE[r], 60, 'l', name='Title'), 'head',
                       name=f'Head_{r}', hid=r != rarity, style='left:-5px;top:-5px', lbl_style='justify-content:center;padding-left:0')
    body = heads
    body += emote_tile((w - 250) // 2, 122, emote, rarity, s=250, name='TileSample')
    body += f"<div class='abs' style='left:0;right:0;top:388px;text-align:center'>{T(emote, 62, 'l', name='EmoteName')}</div>"
    body += f"<div class='abs{' hid' if dupe else ''}' data-n='NewTagRow' style='left:0;right:0;top:462px;text-align:center'>{T('New emote!', 34, 's', 'f-green', name='NewTag')}</div>"
    body += f"<div class='abs{'' if dupe else ' hid'}' data-n='DupeTagRow' style='left:0;right:0;top:462px;text-align:center'>{T('You already have this one', 30, 's', 'f-grey', name='DupeTag')}</div>"
    body += sub('BtnClaim', plate(40, 526, 290, 100, 'green', T('Claim', 48, 'l'), name='ClaimPlate'), btn=True)
    again = T('Open again', 32, 's') + icn('emote_slot', 38, name='CurrencyIcon') + T('250', 32, 's', 'f-yellow', name='Price')
    # both looks exported; the runtime shows the grey one (and Short) when the player can't afford it
    looks = (plate(350, 526, 370, 100, 'blue', again, name='AgainPlate', lbl_style='gap:8px', hid=poor) +
             plate(350, 526, 370, 100, 'grey', again, name='AgainPlatePoor', lbl_style='gap:8px', hid=not poor))
    body += sub('BtnAgain', looks, btn=True)
    body += (f"<div class='abs{'' if poor else ' hid'}' data-n='ShortRow' style='left:350px;width:370px;top:630px;text-align:center'>"
             f"{T('Need 120 more', 24, 'xs', 'f-red', name='Short')}</div>")
    out += f"<div class='glass' data-n='Card' style='left:{x}px;top:{y}px;width:{w}px;height:{h}px;background:rgba(8,14,22,.92)'>{body}</div>"
    return grp('Reveal', out, 'C')


def s_crate():
    """Exported: the reel at rest with the prize under the markers."""
    return world() + dim(.62) + title_grp() + reel_grp() + skip_grp()


def s_crate_intro():
    """Exported (CrateStage only): the crate wobbling before it bursts into the reel."""
    return world() + dim(.62) + title_grp() + crate_stage(-8)


def s_crate_reveal():
    """Exported (Reveal only): the reveal card over the landed reel."""
    return world() + dim(.62) + title_grp() + reel_grp(landed=True) + reveal_grp()


def s_templates():
    out = "<div class='abs fill' style='background:linear-gradient(#1d3a33,#142620)'></div>"
    out += "<div class='cap' style='left:60px;top:30px'>Runtime templates: one reel tile per rarity (the runtime clones these into the reel and the reveal)</div>"
    for i, r in enumerate(RARITY):
        out += grp(f'Tile_{r}', emote_tile(60 + i * 260, 110, SAMPLE[r][0], r, name=f'Tile_{r}'), 'TL')
    return out


def s_states():
    out = "<div class='abs fill' style='background:linear-gradient(#1d3a33,#142620)'></div>"
    out += "<div class='cap' style='left:40px;top:30px'>Reel tiles: common / rare / epic / legendary, longest name, dimmed (not the prize)</div>"
    for i, r in enumerate(RARITY):
        out += emote_tile(40 + i * 230, 90, SAMPLE[r][0], r, name='x')
    out += emote_tile(40 + 4 * 230, 90, 'Hatch-or-Snatch Shuffle', 'rare', name='x')
    out += emote_tile(40 + 5 * 230, 90, 'Wave', 'common', name='x', shade=True)
    out += "<div class='cap' style='left:1440px;top:30px'>Landed prize (1.12x + rarity glow)</div>"
    out += box(1460, 50, 380, 300, '', '', f"background:radial-gradient(closest-side,{RARITY['legendary'][4]},rgba(0,0,0,0))")
    out += emote_tile(1555, 105, 'Golden Strut', 'legendary', name='x', extra='transform:scale(1.12)')

    out += "<div class='cap' style='left:40px;top:330px'>Reveal headers (one per rarity; the runtime shows the one that matches)</div>"
    for i, r in enumerate(RARITY):
        out += plate(40 + i * 470, 390, 440, 100, HEAD_COL[r], T(TITLE[r], 56, 'l'), 'head', lbl_style='justify-content:center;padding-left:0')

    out += "<div class='cap' style='left:40px;top:530px'>Buttons: Claim normal / hover / pressed, Open again normal / can't afford (grey, price stays readable)</div>"
    for j, st in enumerate(['', 'st-hover', 'st-press']):
        out += plate(40 + j * 320, 600, 290, 100, 'green', T('Claim', 48, 'l'), st)
    again = T('Open again', 32, 's') + icn('emote_slot', 38) + T('250', 32, 's', 'f-yellow')
    out += plate(1000, 600, 370, 100, 'blue', again, lbl_style='gap:8px')
    out += plate(1410, 600, 370, 100, 'grey', again, lbl_style='gap:8px')
    out += f"<div class='abs' style='left:1410px;width:370px;top:708px;text-align:center'>{T('Need 120 more', 24, 'xs', 'f-red')}</div>"

    out += "<div class='cap' style='left:40px;top:770px'>Reveal lines: new emote / already owned</div>"
    out += box(40, 820, 700, 70, T('New emote!', 34, 's', 'f-green'), 'inset', 'display:flex;align-items:center;justify-content:center')
    out += box(780, 820, 700, 70, T('You already have this one', 30, 's', 'f-grey'), 'inset', 'display:flex;align-items:center;justify-content:center')

    out += ("<div class='cap' style='left:40px;top:930px'>Phone: this is a full-screen overlay, so it scales as one piece (~0.36x on a landscape phone). "
            "Smallest text is 26 design px (tile names); buttons are 290x100 and 370x100.</div>")
    return out


def s_style():
    """Tokens in use: the stud preset (no Hatch or Snatch style reference yet)."""
    out = "<div class='abs fill' style='background:#14181f'></div>"
    ref = 'ref.png' if os.path.exists(os.path.join(HERE, 'ref.png')) else ''
    out += "<div class='cap' style='left:40px;top:24px'>1. Style reference (the game's current UI)</div>"
    out += (f"<img class='abs' src='{ref}' style='left:40px;top:80px;width:820px;height:520px;object-fit:contain;background:#000;border-radius:12px'>"
            if ref else "<div class='rbx' style='left:40px;top:80px;width:820px;height:520px;border-radius:12px'>no ref.png yet: send a screenshot of the current UI (stud preset until then)</div>")
    css = open(os.path.join(HERE, 'style.css')).read() if os.path.exists(os.path.join(HERE, 'style.css')) else '/* no style.css yet: styles/stud.css as is */'
    out += (f"<pre class='abs' style='left:40px;top:640px;width:820px;height:400px;overflow:hidden;margin:0;padding:12px;background:#0b0e13;"
            f"border-radius:10px;font:600 15px var(--font2);color:#b9c4d0;white-space:pre-wrap'>{html.escape(css)}</pre>")
    out += f"<div class='cap' style='left:920px;top:24px'>2. Tokens drawn: styles/{STYLE}.css + style.css</div>"
    for i, c in enumerate(['green', 'blue', 'red', 'gold', 'purple', 'grey']):
        out += plate(920 + (i % 3) * 330, 90 + (i // 3) * 110, 300, 90, c, T(c.capitalize(), 40, 's'))
    out += "<div class='cap' style='left:920px;top:330px'>text: sizes and fills</div>"
    out += box(920, 380, 960, 90, T('Emote Crate', 64, 'xl', 'f-gold') + "<span style='width:30px;display:inline-block'></span>" +
               T('EPIC!', 56, 'l', 'f-purple') + "<span style='width:30px;display:inline-block'></span>" + T('Tap to skip', 30, 's', 'f-grey'),
               style='display:flex;align-items:center')
    out += "<div class='cap' style='left:920px;top:500px'>rarity tiles + glass card</div>"
    inner = ''.join(emote_tile(30 + i * 225, 40, SAMPLE[r][0], r) for i, r in enumerate(RARITY))
    out += box(920, 550, 960, 290, inner, 'glass')
    return out


def s_spin():
    """Review only: the whole opening animated in the browser with the same timings as the runtime."""
    return (world() + dim(.62) + title_grp() + crate_stage() + reel_grp(row=[('Wave', 'common')], prize_at=0)
            + skip_grp() + reveal_grp() + "<div id='flash' class='abs fill' style='background:#fff;opacity:0;pointer-events:none'></div>")


# ---------------------------------------------------------------- animated preview (review only)
# Same numbers as UI/roblox/ui/client/EmoteCrateSpin.luau TIMING / PITCH / weights: change both together.
SPIN_JS = """
<script>
const CFG = {shake: 1.25, burst: 0.35, spinFirst: 5.0, spinRepeat: 3.6, settle: 0.45, landHold: 0.7,
             pitch: 206, tile: 190, len: 48, fromEnd: 6, cx: 960, jitter: 0.32};
const WEIGHTS = {common: 55, rare: 30, epic: 12, legendary: 3};
const POOL = {common: ['Wave', 'Clap', 'Point', 'Cheer'], rare: ['Robot', 'Floss'], epic: ['Moonwalk'], legendary: ['Golden Strut']};
const GLOW = {common: '#d9e0e6', rare: '#45cfff', epic: '#d955ff', legendary: '#ffd23a'};
const $ = (s, r = document) => r.querySelector(s);
const G = n => $(`[data-g='${n}']`);
const N = (n, r = document) => r.querySelector(`[data-n='${n}']`);
const wait = s => new Promise(r => setTimeout(r, s * 1000));
const quintOut = t => 1 - Math.pow(1 - t, 5);
const backOut = t => { const c1 = 1.70158, c3 = c1 + 1; return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2); };
const pick = a => a[Math.floor(Math.random() * a.length)];
function rollRarity() {
  let x = Math.random() * Object.values(WEIGHTS).reduce((a, b) => a + b, 0);
  for (const [r, w] of Object.entries(WEIGHTS)) { x -= w; if (x <= 0) return r; }
  return 'common';
}
function setText(el, t) {   // keep the designed size; undo any earlier autofit squeeze, then refit
  el.dataset.fs = el.dataset.fs || el.style.fontSize;
  el.textContent = t; el.dataset.t = t; el.style.transform = ''; el.style.fontSize = el.dataset.fs;
}
function show(el, on) { el.style.opacity = on ? 1 : 0; el.style.pointerEvents = on ? 'auto' : 'none'; }
let spins = 0, busy = false, skipping = false, dupe = false;

function makeTile(emote, rarity) {
  const t = N('Tile_' + rarity, $('#tpl')).cloneNode(true);
  t.dataset.n = 'Tile';
  setText(N('EmoteName', t), emote);
  return t;
}
// cosmetic strip around the known prize: flavour tiles follow the real odds, no rigged neighbours
function plan(prize) {
  const strip = [];
  for (let i = 0; i < CFG.len; i++) { const r = rollRarity(); strip.push({emote: pick(POOL[r]), rarity: r}); }
  const landing = CFG.len - CFG.fromEnd;
  strip[landing] = prize;
  return {strip, landing};
}
const txFor = i => CFG.cx - (i * CFG.pitch + CFG.tile / 2);

function wiggle() {
  for (const m of [N('MarkerTop'), N('MarkerBottom')]) {
    m.style.transition = 'none'; m.style.transform = 'rotate(' + (m.dataset.n === 'MarkerTop' ? -10 : 10) + 'deg)';
    requestAnimationFrame(() => { m.style.transition = 'transform .12s ease-out'; m.style.transform = 'rotate(0deg)'; });
  }
}

function tween(dur, fn) {
  return new Promise(res => {
    const t0 = performance.now();
    function step(now) {
      const t = Math.min(1, (now - t0) / (dur * 1000));
      if (skipping) { res(false); return; }
      fn(t);
      if (t < 1) requestAnimationFrame(step); else res(true);
    }
    requestAnimationFrame(step);
  });
}

async function open(forced) {
  if (busy) return;
  busy = true; skipping = false; spins++;
  const rarity = forced || rollRarity();
  const prize = {emote: pick(POOL[rarity]), rarity};
  const stage = G('CrateStage'), reel = G('Reel'), rev = G('Reveal'), hint = G('SkipHint');
  show(rev, false); show(reel, false); show(hint, false); show(G('CrateTitle'), true); show(G('Dim'), true);
  show(stage, true);
  const icon = N('CrateIcon'), burst = N('Burst');
  burst.style.opacity = 0; burst.style.transform = 'scale(.6)';
  // 1. the crate wobbles harder and harder, then bursts
  await tween(CFG.shake, t => {
    const a = (4 + 14 * t) * Math.sin(t * CFG.shake * 2 * Math.PI * (3 + 5 * t));
    icon.style.transform = `rotate(${a.toFixed(2)}deg) scale(${1 + 0.12 * t})`;
  });
  skipping = false;
  const flash = $('#flash');
  flash.style.transition = 'none'; flash.style.opacity = .85;
  burst.style.transition = `opacity ${CFG.burst}s, transform ${CFG.burst}s cubic-bezier(.2,.8,.3,1)`;
  burst.style.opacity = 1; burst.style.transform = 'scale(2)';
  requestAnimationFrame(() => { flash.style.transition = 'opacity .35s'; flash.style.opacity = 0; });
  show(stage, false);
  // 2. build the reel around the prize
  const {strip, landing} = plan(prize);
  const track = N('Track');
  track.querySelectorAll("[data-n^='Tile'],[data-n='Prize']").forEach(e => e.remove());
  const glow = N('PrizeGlow');
  glow.style.opacity = 0; glow.style.background = `radial-gradient(closest-side,${GLOW[rarity]},rgba(0,0,0,0))`;
  glow.style.left = (landing * CFG.pitch + CFG.tile / 2 - 220) + 'px';
  const tiles = strip.map((s, i) => {
    const t = makeTile(s.emote, s.rarity);
    t.style.left = (i * CFG.pitch) + 'px'; t.style.top = '30px';
    track.appendChild(t); return t;
  });
  const start = txFor(2), final = txFor(landing);
  const over = final - (Math.random() * 2 - 1) * CFG.jitter * CFG.pitch;   // stop somewhere on the prize tile
  track.style.transform = `translateX(${start}px)`;
  show(reel, true); show(hint, true);
  if (window.autofit) autofit();   // long names squeeze to fit their tile
  let last = 2;
  const place = x => {
    track.style.transform = `translateX(${x.toFixed(1)}px)`;
    const idx = Math.round((CFG.cx - x - CFG.tile / 2) / CFG.pitch);
    if (idx !== last) { last = idx; wiggle(); }   // in game: one tick sound per tile
  };
  // 3. fast whip, long ease-out onto the prize tile, then settle to its centre
  const dur = spins === 1 ? CFG.spinFirst : CFG.spinRepeat;
  if (await tween(dur, t => place(start + (over - start) * quintOut(t))))
    await tween(CFG.settle, t => place(over + (final - over) * backOut(t)));
  skipping = false;
  place(final);
  show(hint, false);
  // 4. landing: dim the rest, pop the prize, rarity glow (+ a shake for epic and legendary)
  tiles.forEach((t, i) => { if (i !== landing) { const s = N('Shade', t); s.style.transition = 'opacity .3s'; s.style.opacity = 1; } });
  const p = tiles[landing];
  p.style.zIndex = 2; p.style.transition = 'transform .35s cubic-bezier(.34,1.56,.64,1)'; p.style.transform = 'scale(1.12)';
  glow.style.transition = 'opacity .3s'; glow.style.opacity = 1;
  if (rarity === 'epic' || rarity === 'legendary') {
    const amp = rarity === 'legendary' ? 14 : 7;
    await tween(0.4, t => { reel.style.transform = `translate(${(Math.random() * 2 - 1) * amp * (1 - t)}px,${(Math.random() * 2 - 1) * amp * (1 - t)}px)`; });
    reel.style.transform = '';
  }
  await wait(CFG.landHold);
  // 5. reveal card: the player claims it themselves
  for (const r of Object.keys(GLOW)) show(N('Head_' + r), r === rarity);
  const ts = N('TileSample');
  const big = makeTile(prize.emote, rarity);
  big.dataset.n = 'TileSample';
  big.style.left = ts.style.left; big.style.top = ts.style.top;
  big.style.transformOrigin = '0 0'; big.style.transform = `scale(${250 / CFG.tile})`;
  ts.replaceWith(big);
  [...N('Card').querySelectorAll("[data-n='EmoteName']")].slice(-1).forEach(e => setText(e, prize.emote));
  show(N('NewTagRow'), !dupe); show(N('DupeTagRow'), dupe);
  N('Glow').style.background = `radial-gradient(closest-side,${GLOW[rarity]},rgba(0,0,0,0))`;
  $("[data-n='Rays'] stop").setAttribute('stop-color', GLOW[rarity]);
  $("[data-n='Rays'] stop:last-child").setAttribute('stop-color', GLOW[rarity]);
  const card = N('Card');
  card.style.transition = 'none'; card.style.transform = 'scale(.6)';
  show(rev, true);
  if (window.autofit) autofit();
  requestAnimationFrame(() => requestAnimationFrame(() => {
    card.style.transition = 'transform .35s cubic-bezier(.34,1.56,.64,1)'; card.style.transform = 'scale(1)';
  }));
  busy = false;
}

function claim() {
  if (busy) return;
  for (const g of ['Reveal', 'Reel', 'CrateStage', 'SkipHint', 'CrateTitle', 'Dim']) show(G(g), false);
  show($('#idle'), true);
}

document.addEventListener('pointerdown', e => {
  if (e.target.closest('#ctl')) return;
  if (busy) { skipping = true; return; }       // tap anywhere skips to the landing
  if (e.target.closest("[data-n='BtnClaim']")) claim();
  else if (e.target.closest("[data-n='BtnAgain']")) open();
});
document.querySelectorAll('#ctl [data-r]').forEach(b => b.addEventListener('click', () => {
  show($('#idle'), false); open(b.dataset.r || undefined);
}));
$('#dupe').addEventListener('change', e => { dupe = e.target.checked; });
for (const g of ['Reveal', 'Reel', 'SkipHint']) show(G(g), false);
document.fonts.ready.then(() => setTimeout(() => open(), 400));
</script>
<style>
[data-n='Rays'] { animation: spinrays 24s linear infinite; transform-origin: 50% 50%; }
@keyframes spinrays { to { transform: rotate(360deg); } }
[data-n='MarkerTop'], [data-n='MarkerBottom'] { transform-box: fill-box; transform-origin: 50% 50%; }
[data-n='Track'] { will-change: transform; }
#ctl { position: absolute; left: 24px; top: 24px; display: flex; gap: 10px; align-items: center; z-index: 50;
  font: 700 22px var(--font2); color: #fff; background: rgba(0,0,0,.55); padding: 10px 14px; border-radius: 14px; }
#ctl button { font: 700 22px var(--font2); padding: 8px 16px; border-radius: 10px; border: 0; cursor: pointer; background: #e9eef2; }
#ctl label { display: flex; gap: 6px; align-items: center; }
#idle { position: absolute; left: 0; right: 0; top: 500px; text-align: center; opacity: 0; pointer-events: none; }
</style>"""


def spin_controls():
    btns = "".join(f"<button data-r='{r}'>{lbl}</button>" for r, lbl in
                   [('', 'Open crate'), ('common', 'Common'), ('rare', 'Rare'), ('epic', 'Epic'), ('legendary', 'Legendary')])
    tpl = "<div id='tpl' style='display:none'>" + ''.join(emote_tile(0, 0, SAMPLE[r][0], r, name=f'Tile_{r}') for r in RARITY) + "</div>"
    idle = f"<div id='idle'>{T('Press Open crate to spin again', 40, 's')}</div>"
    return (f"<div id='ctl'>Preview only: {btns}<label><input id='dupe' type='checkbox'>already owned</label>"
            "<span style='opacity:.8'>tap the screen to skip</span></div>" + tpl + idle)
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
// autofit: an outlined label wider than its plate/tile/panel is squeezed (scaleX to .8, then font-size)
function autofit(){
  document.querySelectorAll('.ot').forEach(e=>{
    const c=e.closest('.plate,.tile,.inset,.panel,.glass'); if(!c) return;
    const cs=getComputedStyle(e.parentElement);
    const cr=c.getBoundingClientRect(), er=e.getBoundingClientRect(), k=cr.width/c.offsetWidth||1, pad=(c.classList.contains('plate')?14:8)*k;
    let avail, origin='left';
    if(cs.textAlign==='center'||cs.justifyContent==='center'){ avail=Math.min(e.parentElement.getBoundingClientRect().width, cr.width)-2*pad; origin='center'; }
    else if(cs.textAlign==='right'||cs.justifyContent==='flex-end'){ avail=er.right-cr.left-pad; origin='right'; }
    else { avail=cr.right-pad-er.left; }
    if(er.width<=avail) return;
    let sc=avail/er.width;
    if(sc<.8){ const fs=parseFloat(getComputedStyle(e).fontSize); e.style.fontSize=(fs*sc/.8)+'px'; sc=.8; }
    e.style.transform='scaleX('+sc.toFixed(3)+')'; e.style.transformOrigin=origin+' center';
  });
}
document.fonts.ready.then(autofit);
// ?check: outline text that spills out of its box + list broken images (also callable from devtools)
window.checkOverflow = function(){
  const bad=[]; const st=document.getElementById('stage').getBoundingClientRect();
  document.querySelectorAll('.ot').forEach(e=>{
    const r=e.getBoundingClientRect(); const c=e.closest('.plate,.tile,.inset,.panel,.glass');
    const k=(r.width/e.offsetWidth)||1;
    if(c){ const b=c.getBoundingClientRect();
      if(r.left<b.left-3*k||r.right>b.right+3*k||r.top<b.top-12*k||r.bottom>b.bottom+12*k){bad.push(e.dataset.t); e.classList.add('overflowing');} }
    if(r.right>st.right+1||r.left<st.left-1||r.bottom>st.bottom+1){ bad.push('STAGE:'+e.dataset.t); e.classList.add('overflowing'); }
  });
  const broken=[...document.images].filter(i=>i.complete && !i.naturalWidth).map(i=>i.getAttribute('src'));
  return {overflow:bad, broken};
};
if(q.has('check')) document.fonts.ready.then(()=>setTimeout(()=>console.log(JSON.stringify(checkOverflow())), 300));
</script>"""


def page(title, body, h=1080, extra=''):
    return (f"<!doctype html><html><head><meta charset='utf-8'><title>{title}</title>"
            f"<meta name='viewport' content='width=device-width,initial-scale=1'>{FONTS}"
            f"<link rel='stylesheet' href='kit.css'><link id='preset' rel='stylesheet' href='styles/{STYLE}.css'>"
            + ("<link rel='stylesheet' href='style.css'>" if os.path.exists(os.path.join(HERE, 'style.css')) else '')
            + "</head><body>"
            f"<div id='wrap'><div id='stage' style='height:{h}px'>{body}</div></div>{JS}{extra}</body></html>")



SCREENS = [  # (file, title, description, fn, height, extra)
    ('emote_crate_spin.html', 'Emote crate: spin (animated)', 'The whole opening, animated with the runtime timings. Tap to skip', lambda: s_spin() + spin_controls(), 1080, SPIN_JS),
    ('emote_crate.html', 'Emote crate: reel', 'Reel at rest, prize under the markers, nothing drawn over it', s_crate, 1080, ''),
    ('emote_crate_intro.html', 'Emote crate: crate wobble', 'The crate shakes, then bursts into the reel', s_crate_intro, 1080, ''),
    ('emote_crate_reveal.html', 'Emote crate: reveal', 'Rarity header, the emote, Claim and Open again', s_crate_reveal, 1080, ''),
    ('emote_crate_states.html', 'Emote crate: all states', 'Tiles per rarity, headers, buttons, new / owned', s_states, 1080, ''),
    ('emote_crate_templates.html', 'Emote crate: templates', 'One reel tile per rarity (runtime clones these)', s_templates, 1080, ''),
    ('style.html', 'Style tokens', 'Stud preset in use; the current UI screenshot goes here', s_style, 1080, ''),
]


def index():
    cards = ''
    for fname, title, desc, _, h, _ in SCREENS:
        cards += (f"<a class='card' href='{fname}'><div class='frame' style='aspect-ratio:1920/{h}'>"
                  f"<iframe src='{fname}?raw' loading='lazy' tabindex='-1' scrolling='no' style='height:{h}px'></iframe></div>"
                  f"<h3>{title}</h3><p>{desc}</p></a>")
    return f"""<!doctype html><html><head><meta charset='utf-8'><title>Hatch or Snatch UI</title>
<meta name='viewport' content='width=device-width,initial-scale=1'>{FONTS}
<style>
:root{{--bg:#0f1a14;--card:#16241c;--ink:#eef6f0;--mute:#9fb3a6;--line:#2a3d31}}
body{{margin:0;background:var(--bg);color:var(--ink);font-family:'Montserrat',sans-serif}}
header{{padding:24px 16px 8px}} h1{{margin:0;font-weight:900;font-size:30px}} header p{{color:var(--mute);margin:6px 0 0;font-weight:600}}
.grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:16px;padding:16px}}
.card{{display:block;background:var(--card);border:1px solid var(--line);border-radius:14px;overflow:hidden;color:inherit;text-decoration:none}}
.frame{{position:relative;width:100%;overflow:hidden;background:#000}}
.frame iframe{{position:absolute;left:0;top:0;width:1920px;border:0;transform-origin:0 0;pointer-events:none}}
h3{{margin:12px 14px 2px;font-size:18px}} .card p{{margin:0 14px 14px;color:var(--mute);font-size:13px;font-weight:600}}
</style></head><body><header><h1>Hatch or Snatch UI</h1><p>{len(SCREENS)} pages at 1920 wide. Click one to open it full size.</p></header>
<div class='grid'>{cards}</div>
<script>function sz(){{document.querySelectorAll('.frame').forEach(f=>{{f.firstChild.style.transform='scale('+(f.clientWidth/1920)+')'}})}}addEventListener('resize',sz);sz();</script>
</body></html>"""


if __name__ == '__main__':
    missing = [p for p in ('stud.png', 'icons/emote_slot.png') if not os.path.exists(os.path.join(HERE, p))]
    if missing:
        print('WARN missing', missing, '- run make_placeholders.py first')
    for fname, title, desc, fn, h, extra in SCREENS:
        with open(os.path.join(HERE, fname), 'w') as f:
            f.write(page(title, fn(), h, extra))
    with open(os.path.join(HERE, 'index.html'), 'w') as f:
        f.write(index())
    print('wrote', len(SCREENS), 'pages + index.html')
