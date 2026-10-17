#!/usr/bin/env python3
"""Hatch or Snatch UI (roblox-ui-maker project): HOS-HOC-001 Hero or Chicken.

The overlay for the Hero or Chicken pick at the start of every crossing: the lead Catcher intro, the
choosing title, the pick hint, the picked Runner's name card and HERO / CHICKEN buttons, both reveals,
the GET READY line, the HERO ATTEMPT banner, the HERO! success banner and the group's GET READY.
Camera, letterbox and HUD fade belong to the shared Cinematic module; confetti / feathers are VFX.

    python3 build.py                  # writes the pages below + index.html
    python3 -m http.server 8871 --bind 127.0.0.1    # then open http://127.0.0.1:8871/index.html

Style: the game's Oct 2026 restyle (ReplicatedStorage.EOS.UI.Theme): dark see-through glass with a thin
light edge, white Montserrat ExtraBold with a near-black outline, solid coloured plates for actions.
Everything here is native (glass, gradients, strokes, corners): no raster art, nothing to upload.
The shared components (T, grp, sub, box, page) come from ../web/build.py so both UIs stay in step.

Pages (1920x1080, ?raw = 1:1 for export, ?check = overflow check):
    hero_chicken.html            every group of the HeroChicken screen, in place      -> exported
    hero_chicken_templates.html  HERO tag, +200 HERO pop, LEAD CATCHER marker        -> templates
    hero_chicken_states.html     every beat as it looks in game (review only)
"""
import importlib.util
import os

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location('webkit', os.path.join(HERE, '..', 'web', 'build.py'))
W = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(W)
T, grp, sub, box, page = W.T, W.grp, W.sub, W.box, W.page

# ---------------------------------------------------------------- tokens (Theme.luau)
GLASS = 'rgba(17,20,27,.86)'      # Theme.panel at ~0.14 transparency (over a letterboxed shot)
EDGE = 'rgba(255,255,255,.16)'    # Theme.edge / edgeT
INK = '#07090e'
GOLD = ('#fff07a', '#ffd23a', '#ffbf1c', '#c27a00', '#2a1700')    # ramps.gold: top mid bot lip ol
WHITE = ('#ffffff', '#eef1f4', '#d4dbe1', '#8c959d', '#101316')
RED = ('#ef747c', '#e24b51', '#f9505a', '#9c1b1f', '#1c0204')
LETTERBOX = 118                   # bar height in design px (Cinematic draws the bars)

NAME = 'SunnyBunny42'             # longest-ish sample name (state sheet also shows a 20-char one)


def glass(x, y, w, h, inner='', name=None, rad=26, hid=False, extra=''):
    return box(x, y, w, h, inner, '', f'background:{GLASS};border:3px solid {EDGE};border-radius:{rad}px;{extra}', name=name, hid=hid)


def solid(x, y, w, h, ramp, inner='', name=None, rad=30, hid=False, extra=''):
    """A solid action plate, all native: dark outline, bright inner rim, face gradient, dark lip below."""
    top, mid, bot, lip, ol = ramp
    return box(x, y, w, h, inner, '',
               f'background:linear-gradient({top},{mid} 50%,{bot});border:6px solid {ol};border-radius:{rad}px;'
               f'box-shadow:inset 0 0 0 3px rgba(255,255,255,.55),0 9px 0 {lip};{extra}', name=name, hid=hid)


def center(inner, y, name=None, h=None, hid=False):
    hh = f'height:{h}px;' if h else ''
    return (f"<div class='abs{' hid' if hid else ''}'{W.dn(name)} style='left:0;right:0;top:{y}px;{hh}"
            f"display:flex;flex-direction:column;align-items:center'>{inner}</div>")


def timer(x, y, n='5', name='Timer', s=96, hid=False):
    return box(x, y, s, s, W.flex(T(n, int(s * .5), 'l', name=name + 'Text')), '',
               f'background:{GLASS};border:4px solid rgba(255,255,255,.55);border-radius:50%', name=name, hid=hid)


# ---------------------------------------------------------------- groups of the HeroChicken screen
def g_title(hid=True, title='THE CATCHER IS CHOOSING...', kicker='CROSSING 2'):
    """Beat a: top centre, under the letterbox bar. Timer pill on the right of the line."""
    inner = center(T(kicker, 30, 's', 'f-grey', name='Kicker'), LETTERBOX + 22)
    inner += center(T(title, 64, 'xl', name='TitleText'), LETTERBOX + 62)
    inner += timer(960 + 560, LETTERBOX + 46, '6', 'Timer')
    return grp('Title', sub('TitleBox', inner, hid=hid), 'T')


def g_lead(hid=True):
    """Intro shot: over the lead Catcher's head (runtime places it at the projected head point)."""
    inner = box(860, 300, 200, 150, W.flex(T('8', 120, 'xl', name='CountText')), name='Count')
    inner += box(800, 452, 320, 64, W.flex(T('LEAD CATCHER', 34, 's', name='LeadText')), '',
                 f'background:linear-gradient({RED[0]},{RED[1]} 55%,{RED[2]});border:5px solid {RED[4]};border-radius:32px;'
                 f'box-shadow:inset 0 0 0 2px rgba(255,255,255,.45),0 6px 0 {RED[3]}', name='LeadPill')
    inner += center(T('picks who goes HERO or CHICKEN', 30, 's', 'f-grey', name='LeadSub'), 530)
    return grp('Lead', sub('LeadBox', inner, hid=hid), 'C')


def g_pickhint(hid=True):
    """Beat a, lead Catcher only: bottom centre above the letterbox bar."""
    hint = (f"<div class='abs' style='left:0;right:0;top:0;bottom:0;display:flex;align-items:center;justify-content:center;gap:18px'>"
            f"{T('TAP A RUNNER TO PICK THEM', 34, 's', name='HintText')}</div>")
    inner = glass(560, 1080 - LETTERBOX - 112, 800, 84, hint, 'HintPill', rad=42)
    inner += box(560, 1080 - LETTERBOX - 112 - 52, 800, 44, W.flex(T('Hover to aim the spotlight', 26, 'xs', 'f-grey', name='HintSub')))
    return grp('PickHint', sub('PickHintBox', inner, hid=hid), 'B')


def g_namecard(hid=True, name=NAME, waiting=True):
    """Beat b: the picked Runner's name, HERO OR CHICKEN? and a small countdown above it."""
    inner = timer(912, 236, '5', 'ChoiceTimer', 96)
    inner += center(T(name, 92, 'xl', name='NameText'), 346)
    inner += center(T('HERO OR CHICKEN?', 52, 'l', 'f-yellow', name='AskText'), 466)
    inner += center(T(f'Waiting for {name}...', 30, 's', 'f-grey', name='WaitText'), 540, hid=not waiting)
    return grp('NameCard', sub('NameCardBox', inner, hid=hid), 'T')


def g_choice(hid=True, press=None):
    """Beat b, picked Runner only: two big buttons (tap targets well over 124 design px)."""
    def btn(nm, x, ramp, word, line, chip, st):
        k = ''
        if st == 'hover':
            k = 'transform:scale(1.05) translateY(-3px);'
        elif st == 'press':
            k = 'transform:scale(.93) translateY(4px);'
        inner = center(T(word, 76, 'xl', 'f-gold' if ramp is GOLD else '', name='Word'), 26)
        inner += center(T(line, 28, 's', name='Line'), 122)
        if chip:
            inner += box(110, 172, 300, 54, W.flex(T(chip, 28, 's', 'f-gold', name='ChipText')), '',
                         f'background:{INK};border:3px solid {GOLD[1]};border-radius:27px', name='Chip')
        return sub(nm, solid(x, 0, 520, 250 if chip else 196, ramp, inner, name=nm + 'Face', extra=k), btn=True)
    row = btn('HeroButton', 380, GOLD, 'HERO', 'Cross alone. First.', 'HERO = 2x POINTS', press if press and press[0] == 'H' else '')
    row += btn('ChickenButton', 1020, WHITE, 'CHICKEN', 'Run with the group', '', press if press and press[0] == 'C' else '')
    return grp('Choice', sub('ChoiceBox', box(0, 1080 - LETTERBOX - 300, 1920, 260, row), hid=hid), 'B')


def g_reveal(which=None):
    """Beat c: the big word over the picked Runner, one sub per outcome."""
    hero = center(T('HERO!', 190, 'xl', 'f-gold', name='Word'), 300) + center(T(f'{NAME} is crossing alone', 44, 'l', name='Sub'), 540)
    chicken = center(T('CHICKEN!', 170, 'xl', name='Word'), 310) + center(T(f'{NAME} runs with the group', 44, 'l', 'f-grey', name='Sub'), 530)
    return grp('Reveal', sub('RevealHero', hero, hid=which != 'hero') + sub('RevealChicken', chicken, hid=which != 'chicken'), 'C')


def g_ready(hid=True, word='HERO'):
    """After the swoop, HUD back: who is going what, then 3-2-1."""
    inner = glass(560, 150, 800, 150,
                  center(T(f'{NAME} is going {word}', 44, 'l', name='ReadyText'), 18) +
                  center(T('GET READY', 30, 's', 'f-yellow', name='ReadySub'), 90), 'ReadyPill')
    inner += center(T('3', 140, 'xl', name='CountText'), 320)
    return grp('Ready', sub('ReadyBox', inner, hid=hid), 'T')


def g_herorun(hid=True):
    """During the Hero run: small banner top centre (the HUD is back, so it sits under the timer row)."""
    inner = box(700, 150, 520, 92,
                center(T('HERO ATTEMPT', 44, 'l', 'f-gold', name='RunText'), 8) +
                center(T(f'{NAME} crosses alone', 26, 'xs', name='RunSub'), 58), '',
                f'background:{GLASS};border:4px solid {GOLD[1]};border-radius:24px', name='RunPill')
    return grp('HeroRun', sub('HeroRunBox', inner, hid=hid), 'T')


def g_success(hid=True):
    """The Hero made it: an angled banner wipes in across the top of the letterboxed shot."""
    band = box(-60, LETTERBOX + 40, 2040, 230, '', '',
               f'background:linear-gradient(90deg,rgba(20,14,0,0),rgba(20,14,0,.88) 18%,rgba(20,14,0,.88) 82%,rgba(20,14,0,0));'
               f'border-top:6px solid {GOLD[1]};border-bottom:6px solid {GOLD[1]};transform:rotate(-3deg)', name='Band')
    words = box(0, LETTERBOX + 40, 1920, 230,
                center(T('HERO!', 128, 'xl', 'f-gold', name='Word'), 6) +
                center(T(f'{NAME} made it alone', 40, 'l', name='Sub'), 160), '', 'transform:rotate(-3deg)', name='Words')
    chip = solid(1440, LETTERBOX + 230, 260, 92, GOLD, W.flex(T('+200', 54, 'l', name='PointsText')), 'PointsChip', rad=46,
                 extra='transform:rotate(-3deg)')
    badge = box(240, LETTERBOX + 210, 230, 70, W.flex(T('SOLO RUN', 30, 's', name='BadgeText')), '',
                f'background:{INK};border:4px solid {GOLD[1]};border-radius:35px;transform:rotate(-3deg)', name='Badge')
    return grp('Success', sub('SuccessBox', band + words + chip + badge, hid=hid), 'T')


def g_group(hid=True, caught=False):
    """After the Hero run: what happened, the group goes next, GET READY countdown."""
    head = 'THE HERO WAS CAUGHT' if caught else 'HERO ATTEMPT COMPLETE'
    inner = glass(510, 300, 900, 250,
                  center(T(head, 54, 'l', 'f-red' if caught else 'f-gold', name='HeadText'), 26) +
                  center(T('The group goes next', 40, 'l', name='SubText'), 110) +
                  center(T('GET READY', 30, 's', 'f-yellow', name='ReadyText'), 180), 'GroupPill')
    inner += center(T('3', 140, 'xl', name='CountText'), 580)
    return grp('Group', sub('GroupBox', inner, hid=hid), 'C')


def g_letterbox():
    """Stand-in cinematic bars (used only while the shared Cinematic module is missing): the runtime
    slides them in from the edges. FILL group so they span any aspect ratio."""
    top = box(0, 0, 1920, LETTERBOX, '', '', 'background:#000', name='BarTop')
    bot = box(0, 1080 - LETTERBOX, 1920, LETTERBOX, '', '', 'background:#000', name='BarBottom')
    return grp('Letterbox', sub('LetterboxBox', top + bot, hid=True), 'FILL')


def g_flash():
    """Full-screen flash: white on the pick and the rush, gold on HERO, black for the success fade-out."""
    return grp('Flash', box(0, 0, 1920, 1080, '', '', 'background:#fff', name='FlashFill', hid=True), 'FILL')


def s_screen():
    return (W.world() + g_letterbox() + g_title() + g_lead() + g_pickhint() + g_namecard() + g_choice() + g_reveal() + g_ready()
            + g_herorun() + g_success() + g_group() + g_flash())


# ---------------------------------------------------------------- templates (cloned by the controller)
def s_templates():
    tag = grp('HeroTag', box(0, 0, 220, 64, W.flex(T('HERO', 38, 'l', 'f-gold', name='TagText')), '',
                                f'background:{INK};border:4px solid {GOLD[1]};border-radius:32px', name='Pill'), 'TL')
    pop = grp('PointsPop', box(0, 120, 420, 110, W.flex(T('+200 HERO', 64, 'xl', 'f-gold', name='PopText')), name='Pop'), 'TL')
    return "<div class='world'></div>" + tag + pop


# ---------------------------------------------------------------- review sheet: every beat in context
def bars():
    return (f"<div class='abs' style='left:0;top:0;width:1920px;height:{LETTERBOX}px;background:#000'></div>"
            f"<div class='abs' style='left:0;bottom:0;width:1920px;height:{LETTERBOX}px;background:#000'></div>"
            "<div class='abs fill' style='background:radial-gradient(ellipse at center,rgba(0,0,0,0) 55%,rgba(0,0,0,.55))'></div>")


def scene(kind):
    """Stand-in shot behind each beat (a real Studio capture replaces this once the playtest runs)."""
    if kind == 'line':
        runners = ''.join(f"<div class='abs' style='left:{300 + i * 180}px;top:560px;width:70px;height:170px;border-radius:20px;background:#3b4f7a'></div>" for i in range(8))
        spot = "<div class='abs' style='left:820px;top:0;width:200px;height:740px;background:linear-gradient(rgba(255,236,170,.0),rgba(255,236,170,.45));clip-path:polygon(40% 0,60% 0,100% 100%,0 100%)'></div>"
        return W.world() + runners + spot
    if kind == 'close':
        return W.world() + "<div class='abs' style='left:760px;top:330px;width:300px;height:700px;border-radius:60px;background:#3b4f7a'></div>"
    return W.world()


def s_states():
    shots = [
        ('a1 intro: lead Catcher', scene('close') + bars() + g_lead(False) + g_title(False, 'WHO WILL IT BE?', 'CROSSING 2')),
        ('a2 choosing: everyone', scene('line') + bars() + g_title(False)),
        ('a3 choosing: the Catcher', scene('line') + bars() + g_title(False, 'PICK A RUNNER', 'YOU ARE THE LEAD CATCHER') + g_pickhint(False)),
        ('b1 picked: everyone else', scene('close') + bars() + g_namecard(False)),
        ('b2 picked: the picked Runner', scene('close') + bars() + g_namecard(False, waiting=False) + g_choice(False, 'Hover')),
        ('c1 HERO reveal', scene('close') + bars() + g_reveal('hero')),
        ('c2 CHICKEN reveal', scene('close') + "<div class='abs fill' style='background:rgba(40,40,48,.45)'></div>" + bars() + g_reveal('chicken')),
        ('c3 ready (HUD back)', scene('') + g_ready(False)),
        ('d1 HERO ATTEMPT', scene('') + g_herorun(False)),
        ('d2 HERO! success', scene('close') + bars() + g_success(False)),
        ('d3 group goes next', scene('') + g_group(False)),
        ('d4 Hero caught', scene('') + g_group(False, True)),
    ]
    cells = ''
    for i, (cap, body) in enumerate(shots):
        x, y = (i % 4) * 480, (i // 4) * 300
        cells += (f"<div class='abs' style='left:{x}px;top:{y}px;width:480px;height:300px;overflow:hidden;border:2px solid #000'>"
                  f"<div class='abs' style='left:0;top:0;width:1920px;height:1080px;transform:scale(.25);transform-origin:0 0'>{body}</div>"
                  f"<div class='cap' style='left:8px;bottom:8px;font-size:18px'>{cap}</div></div>")
    return cells


SCREENS = [
    ('hero_chicken_states.html', 'Hero or Chicken: every beat', 'Each beat as it looks in game (letterbox + stand-in shot)', s_states, 900, ''),
    ('hero_chicken.html', 'Hero or Chicken: screen', 'Every group in place (exported; all start hidden)', s_screen, 1080, ''),
    ('hero_chicken_templates.html', 'Hero or Chicken: templates', 'HERO tag over the Hero, +200 HERO pop', s_templates, 1080, ''),
]

if __name__ == '__main__':
    W.SCREENS = SCREENS
    for fname, title, desc, fn, h, extra in SCREENS:
        with open(os.path.join(HERE, fname), 'w') as f:
            f.write(page(title, fn(), h, extra))
    with open(os.path.join(HERE, 'index.html'), 'w') as f:
        f.write(W.index().replace('Hatch or Snatch UI', 'Hero or Chicken UI'))
    print('wrote', len(SCREENS), 'pages + index.html')
