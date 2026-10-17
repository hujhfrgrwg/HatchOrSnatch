#!/usr/bin/env python3
"""Hatch or Snatch UI (roblox-ui-maker project): HOS-CINE-002 Last One Standing.

The callout of the Last One Standing cut-scene (one Runner left, in the break before their solo crossing)
and the small pill at the top of the HUD during that solo crossing:
    Callout  "LAST ONE STANDING" title (STANDING in gold) + name plate (crown, name, "vs N Catchers")
             + one line written for your role (lone Runner / Catchers / anyone else)
    Pill     "LAST ONE STANDING · <name>" under the match status, while the solo crossing runs
Camera, letterbox bars, dim and HUD hide belong to the shared Cinematic module (Controllers/Cinematic);
the beam / ring are VFX. Controllers/LastStanding clones these two templates and fills them.

    python3 build.py                  # writes the pages below + index.html
    python3 -m http.server 8872 --bind 127.0.0.1    # then open http://127.0.0.1:8872/index.html

Style: the game's Oct 2026 restyle (ReplicatedStorage.EOS.UI.Theme) and the approved mockup
(claude.ai artifact Rinvo3aXZGrsrcSBjjuYeN): white Montserrat ExtraBold with a near-black outline, gold
accent, dark see-through glass with a thin light edge and a gold underline. Everything is native (glass,
gradients, strokes, corners). The only image is the game's own crown icon, already uploaded for EOSUI
(rbx/out/uploaded.json is seeded with its id), so nothing new is uploaded.
The shared components (T, grp, sub, box, page) come from ../web/build.py so all three UIs stay in step.

Pages (1920x1080, ?raw = 1:1 for export, ?check = overflow check):
    last_standing_templates.html  Callout + Pill, as exported                       -> templates
    last_standing_states.html     every state in context, PC and phone (review only)
"""
import importlib.util
import os

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location('webkit', os.path.join(HERE, '..', 'web', 'build.py'))
W = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(W)
T, grp, sub, box, page = W.T, W.grp, W.sub, W.box, W.page

# ---------------------------------------------------------------- tokens (Theme.luau)
GLASS = 'rgba(17,20,27,.86)'       # Theme.panel, ~0.14 transparency: the plate over a dimmed, letterboxed shot
HUD_GLASS = 'rgba(17,20,27,.78)'   # Theme.panel at Theme.panelT (0.22): HUD chrome
EDGE = 'rgba(255,255,255,.16)'     # Theme.edge at Theme.edgeT
LIP = '#c27a00'                    # ramps.gold lip: the plate's gold underline
TAIL = 'f-red'                     # "vs N Catchers" (the mockup's red)
LETTERBOX = 119                    # Cinematic bar height at 1080 (11%)

NAME = 'SunnyBunny42'
LONG = 'xXDragonSlayer2014Xx'      # 20 characters (Roblox display names max out at 20)
LINES = {
    'runner': "It's all on you. Make it across to win it for the Runners.",
    'catcher': 'Catch {n} to win it for the Catchers.',
    'other': '{n} crosses alone. Can they make it?',
}

# Callout layout: one 1400 x 420 template, everything centred on x = 700
CW, CH = 1400, 420
TITLE_PX = 112                     # design font-size (TextSize 136 -> TitleBig UIScale at export)
PLATE_H, PLATE_Y = 84, 168
SUB_Y = 288
# Pill: one 640 x 56 template (runtime resizes it around the name)
PW, PH = 640, 56


def center(inner, y, name=None, h=None, hid=False, w=CW):
    hh = f'height:{h}px;' if h else ''
    return (f"<div class='abs{' hid' if hid else ''}'{W.dn(name)} style='left:0;width:{w}px;top:{y}px;{hh}"
            f"display:flex;flex-direction:column;align-items:center'>{inner}</div>")


def title_row():
    """Two live labels on one baseline: LAST ONE (white) + STANDING (gold)."""
    a = T('LAST ONE', TITLE_PX, 'xl', name='TitleA')
    b = T('STANDING', TITLE_PX, 'xl', 'f-gold', name='TitleB')
    return (f"<div class='abs' data-n='Title' style='left:0;width:{CW}px;top:24px;display:flex;justify-content:center;gap:30px'>"
            f"{a}{b}</div>")


def plate(name=NAME, n=21):
    """Dark glass, thin light edge, gold underline (inset band = native InnerShade), crown + name + tail.
    Hugs its content (centred); the runtime re-fits it around each name the same way."""
    tail = f'vs {n} Catcher' + ('' if n == 1 else 's')
    return (f"<div data-n='Plate' style='display:flex;align-items:center;gap:16px;height:{PLATE_H}px;padding:0 30px 6px 24px;"
            f"background:{GLASS};border:3px solid {EDGE};border-radius:18px;box-shadow:inset 0 -7px 0 {LIP}'>"
            f"{W.icn('crown', 52, name='Crown')}{T(name, 40, 'l', name='NameText')}{T(tail, 40, 'l', TAIL, name='TailText')}</div>")


def callout(name=NAME, n=21, role='runner'):
    line = LINES[role].format(n=name)
    inner = title_row() + center(plate(name, n), PLATE_Y) + center(T(line, 36, 's', name='SubText'), SUB_Y, w=CW)
    return box(0, 0, CW, CH, inner, name='Box')


def pill(name=NAME):
    row = (f"<div class='abs fill' style='display:flex;align-items:center;justify-content:center;gap:12px'>"
           f"{T('LAST ONE STANDING', 26, 's', name='LeadText')}{T('·', 26, 's', 'f-gold', name='DotText')}"
           f"{T(name, 26, 's', 'f-gold', name='NameText')}</div>")
    return box(0, 0, PW, PH, row, '', f'background:{HUD_GLASS};border:3px solid {EDGE};border-radius:28px', name='Box')


# ---------------------------------------------------------------- templates (cloned by Controllers/LastStanding)
def s_templates():
    return (W.world() + grp('Callout', callout(), 'TL')
            + f"<div class='abs' style='left:0;top:520px;width:1920px;height:{PH}px'>{grp('Pill', pill(), 'TL')}</div>")


# ---------------------------------------------------------------- review sheet: every state in context
def bars(w=1920):
    return (f"<div class='abs' style='left:0;top:0;width:{w}px;height:{LETTERBOX}px;background:#05070a'></div>"
            f"<div class='abs' style='left:0;bottom:0;width:{w}px;height:{LETTERBOX}px;background:#05070a'></div>"
            "<div class='abs fill' style='background:radial-gradient(ellipse at center,rgba(0,0,0,0) 45%,rgba(0,0,0,.5))'></div>")


def shot(w=1920, dim=True, x=0):
    """The real in-match capture (a crossing on Beach, the face-off view) as the stand-in shot."""
    f = 'filter:saturate(.5) brightness(.8);' if dim else ''
    return f"<img class='world' src='bg_match.jpg' style='left:0;top:0;width:{w}px;height:1080px;object-fit:cover;{f}'>"


def at(inner, x, y, scale=1.0):
    return f"<div class='abs' style='left:{x}px;top:{y}px;transform:scale({scale});transform-origin:0 0'>{inner}</div>"


def callout_at(w, name=NAME, n=21, role='runner', scale=1.0):
    """Placed like the runtime: centred, its middle at 47% of the screen height."""
    cx, cy = w / 2, 1080 * .47
    return at(callout(name, n, role), cx - CW * scale / 2, cy - CH * scale / 2, scale)


def pill_at(w, name=NAME, scale=1.0, y=176):
    return at(pill(name), w / 2 - PW * scale / 2, y, scale)


def touch(w):
    """Roblox's thumbstick + jump placeholders (phone)."""
    return (f"<div class='rbx' style='left:90px;top:640px;width:300px;height:300px'>thumbstick</div>"
            f"<div class='rbx' style='left:{w - 330}px;top:720px;width:200px;height:200px'>jump</div>")


PHONE_W = 2337   # an 844 x 390 phone fitted by height: 844 / (390 / 1080) design px wide
PHONE_BOOST = 1.25   # the runtime's PhoneScale on small screens (sub line >= 12 px on screen)


def cell(cap, body, w=1920):
    return (f"<div style='position:relative;width:{w}px;height:1080px;overflow:hidden;border:2px solid #000;background:#000'>{body}"
            f"<div class='cap' style='left:12px;bottom:12px;font-size:30px'>{cap}</div></div>")


def s_states():
    pc = [
        ('PC: lone Runner (title, plate, their line)', shot() + bars() + callout_at(1920)),
        ('PC: a Catcher', shot() + bars() + callout_at(1920, role='catcher')),
        ('PC: anyone else (safe / out / watching)', shot() + bars() + callout_at(1920, role='other')),
        ('PC: longest name, 1 Catcher', shot() + bars() + callout_at(1920, LONG, 1, 'catcher')),
        ('PC: reduce effects (callout only: no bars, no dim)', shot(dim=False) + callout_at(1920)),
        ('PC: solo crossing pill under the match status', shot(dim=False) + pill_at(1920)),
        ('PC: pill, longest name', shot(dim=False) + pill_at(1920, LONG)),
    ]
    ph = [
        ('Phone 844x390: lone Runner', shot(PHONE_W, x=(PHONE_W - 1920) // 2) + bars(PHONE_W) + touch(PHONE_W)
         + callout_at(PHONE_W, scale=PHONE_BOOST)),
        ('Phone: a Catcher, longest name', shot(PHONE_W, x=(PHONE_W - 1920) // 2) + bars(PHONE_W) + touch(PHONE_W)
         + callout_at(PHONE_W, LONG, 21, 'catcher', PHONE_BOOST)),
        ('Phone: pill during the solo crossing', shot(PHONE_W, False, (PHONE_W - 1920) // 2) + touch(PHONE_W)
         + pill_at(PHONE_W, NAME, PHONE_BOOST, 170)),
    ]
    out = "<div class='abs' style='left:0;top:0;transform:scale(.5);transform-origin:0 0;display:flex;flex-wrap:wrap;gap:24px;width:3888px'>"
    for cap, body in pc:
        out += cell(cap, body)
    for cap, body in ph:
        out += cell(cap, body, PHONE_W)
    return out + '</div>'


SCREENS = [
    ('last_standing_states.html', 'Last One Standing: every state', 'Callout per role, longest name, reduce effects, the pill; PC and phone, over a real match capture', s_states, 3900, ''),
    ('last_standing_templates.html', 'Last One Standing: templates', 'Callout and Pill as exported (runtime clones these)', s_templates, 1080, ''),
]

if __name__ == '__main__':
    W.SCREENS = SCREENS
    for fname, title, desc, fn, h, extra in SCREENS:
        with open(os.path.join(HERE, fname), 'w', encoding='utf-8') as f:
            f.write(page(title, fn(), h, extra))
    with open(os.path.join(HERE, 'index.html'), 'w', encoding='utf-8') as f:
        f.write(W.index().replace('Hatch or Snatch UI', 'Last One Standing UI'))
    print('wrote', len(SCREENS), 'pages + index.html')
