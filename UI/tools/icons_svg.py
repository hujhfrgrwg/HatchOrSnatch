#!/usr/bin/env python3
"""Evolve or Steal icon set (drawn for this game; no third-party pack).
One treatment: 128x128 viewBox, gradient-shaded shapes (light top-left -> deep bottom), thin inner ink
detail lines, white glints. NO outer outline here: tools/outline.py adds the shared thick ink edge + drop
shadow so icons match the pet portraits. Writes icons_svg/<slug>.svg; tools/render_icons.mjs rasterises
them to icons_raw/, then `python3 tools/outline.py --icons` finishes them into icons/.
Pets and eggs are NOT here: they are photographed from Workspace.FWP_PetShowroom (tools/photo_booth.luau)."""
import os

INK = '#1a0e26'
_n = [0]


def uid():
    _n[0] += 1
    return f'g{_n[0]}'


def lg(stops, x1=0, y1=0, x2=0, y2=1):
    i = uid()
    s = ''.join(f"<stop offset='{o}' stop-color='{c}'/>" for o, c in stops)
    return i, f"<linearGradient id='{i}' x1='{x1}' y1='{y1}' x2='{x2}' y2='{y2}'>{s}</linearGradient>"


def rg(stops, cx=.35, cy=.3, r=.8):
    i = uid()
    s = ''.join(f"<stop offset='{o}' stop-color='{c}'/>" for o, c in stops)
    return i, f"<radialGradient id='{i}' cx='{cx}' cy='{cy}' r='{r}'>{s}</radialGradient>"


def svg(defs, body):
    return (f"<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 128 128' width='512' height='512'>"
            f"<defs>{''.join(defs)}</defs>{body}</svg>")


def glint(d, o=.9):
    return f"<path d='{d}' fill='#fff' opacity='{o}'/>"


def ramp(light, mid, dark):
    return lg([(0, light), (.55, mid), (1, dark)])


ICONS = {}

# ------------------------------------------------------------------ currencies
def coin():
    a, A = ramp('#fff3a8', '#ffcc2e', '#e88a00')
    b, B = ramp('#ffd84a', '#f5a400', '#c46a00')
    c, C = lg([(0, '#fff6c0'), (1, '#ffbf1f')])
    return svg([A, B, C],
               f"<circle cx='64' cy='68' r='54' fill='#b45f00'/>"
               f"<circle cx='64' cy='62' r='54' fill='url(#{a})'/>"
               f"<circle cx='64' cy='62' r='40' fill='url(#{b})'/>"
               f"<path d='M64 36 l8 16 18 3 -13 12 3 18 -16 -8 -16 8 3 -18 -13 -12 18 -3z' fill='url(#{c})' stroke='#b06000' stroke-width='3' stroke-linejoin='round'/>"
               + glint('M24 50 q6 -22 30 -32 q-20 16 -22 38z') + glint('M92 98 q8 -4 12 -12 q-2 10 -10 16z', .5))


ICONS['gold'] = coin()


def gem(light='#b8ffd0', mid='#2fe07a', dark='#0f9a4c', deep='#08703a'):
    a, A = lg([(0, light), (1, mid)])
    b, B = lg([(0, mid), (1, dark)])
    c, C = lg([(0, dark), (1, deep)])
    return svg([A, B, C],
               f"<path d='M64 120 L8 50 L30 14 H98 L120 50 Z' fill='url(#{c})'/>"
               f"<path d='M8 50 L30 14 H98 L120 50 Z' fill='url(#{a})'/>"
               f"<path d='M8 50 H120 L64 120 Z' fill='url(#{b})'/>"
               f"<path d='M44 50 L64 120 L84 50 Z' fill='{mid}' opacity='.65'/>"
               f"<path d='M30 14 L44 50 L64 14 L84 50 L98 14' fill='none' stroke='{deep}' stroke-width='3' stroke-linejoin='round' opacity='.6'/>"
               f"<path d='M8 50 H120' stroke='{deep}' stroke-width='3' opacity='.5'/>"
               + glint('M34 20 h18 l-10 26 h-18z') + glint('M70 20 h8 l-6 20 h-6z', .6))


ICONS['gem'] = gem()


def robux():
    a, A = ramp('#c8ffd8', '#4ad97a', '#16954a')
    return svg([A],
               f"<path d='M64 8 L114 37 V91 L64 120 L14 91 V37 Z' fill='url(#{a})'/>"
               f"<path d='M64 30 L94 47 V81 L64 98 L34 81 V47 Z' fill='#0e6b33'/>"
               f"<rect x='52' y='52' width='24' height='24' rx='3' fill='url(#{a})'/>"
               + glint('M24 40 L60 18 L58 30 L28 48z'))


ICONS['robux'] = robux()

# ------------------------------------------------------------------ egg pieces (materials): cracked shell halves
def piece(light, mid, dark, deep, spot):
    a, A = lg([(0, light), (.5, mid), (1, dark)], 0, 0, .3, 1)
    b, B = lg([(0, mid), (1, deep)])
    return svg([A, B],
               f"<path d='M14 72 C14 34 38 8 64 8 C90 8 114 34 114 72 L100 62 L86 78 L72 60 L58 80 L44 60 L30 78 Z' fill='url(#{a})'/>"
               f"<path d='M22 92 L34 82 L48 98 L62 82 L76 98 L90 82 L108 94 C104 112 86 122 64 122 C42 122 24 112 22 92Z' fill='url(#{b})'/>"
               f"<circle cx='44' cy='40' r='7' fill='{spot}'/><circle cx='80' cy='30' r='5' fill='{spot}'/><circle cx='88' cy='54' r='6' fill='{spot}'/>"
               f"<circle cx='50' cy='106' r='5' fill='{spot}' opacity='.8'/><circle cx='80' cy='108' r='4' fill='{spot}' opacity='.8'/>"
               + glint('M36 20 q-16 14 -18 36 q8 -20 24 -32z'))


ICONS['piece_common'] = piece('#ffffff', '#f4f6f2', '#d2dccd', '#9fb09a', '#6fd66a')   # Basic egg: white, green spots
ICONS['piece_rare'] = piece('#e8fbff', '#9fe6ff', '#56bde8', '#2a86c0', '#ffffff')      # Shiny egg: sky blue, white spots
ICONS['piece_epic'] = piece('#b9a8ff', '#5b3ad8', '#3a1fa8', '#22106e', '#a8f4ff')      # Cosmic egg: deep violet, cyan spots
ICONS['piece_crowned'] = piece('#fff6c8', '#ffd23a', '#f0a000', '#b86a00', '#ffffff')  # Golden egg (Level 4 / deferred tier)

# ------------------------------------------------------------------ menu
def scroll():
    a, A = lg([(0, '#fffaf0'), (1, '#f0d9a8')])
    b, B = ramp('#e9c58a', '#c99a55', '#9a6c2c')
    c, C = ramp('#9dffb0', '#2fd75a', '#139a36')
    return svg([A, B, C],
               f"<rect x='26' y='14' width='72' height='94' rx='10' fill='url(#{a})'/>"
               f"<rect x='18' y='8' width='88' height='18' rx='9' fill='url(#{b})'/>"
               f"<rect x='18' y='100' width='88' height='18' rx='9' fill='url(#{b})'/>"
               f"<path d='M40 42 H84 M40 58 H84 M40 74 H70' stroke='#a88452' stroke-width='6' stroke-linecap='round'/>"
               f"<circle cx='96' cy='96' r='24' fill='url(#{c})'/><path d='M84 96 l8 8 l14 -16' fill='none' stroke='#fff' stroke-width='7' stroke-linecap='round' stroke-linejoin='round'/>"
               + glint('M32 20 h20 v6 h-20z', .7))


ICONS['quests'] = scroll()


def incubator():
    a, A = lg([(0, '#ffffff'), (1, '#e8f6ff')])
    d, D = rg([(0, 'rgba(255,255,255,.95)'), (.6, 'rgba(190,240,255,.55)'), (1, 'rgba(120,210,255,.45)')], .4, .3, .8)
    b, B = ramp('#ffe27a', '#ffb21c', '#d07400')
    e, E = lg([(0, '#bfffa8'), (1, '#4fd04a')])
    return svg([A, B, D, E],
               f"<path d='M64 16 C44 16 34 44 34 58 C34 76 46 86 64 86 C82 86 94 76 94 58 C94 44 84 16 64 16Z' fill='url(#{e})'/>"
               f"<circle cx='54' cy='50' r='6' fill='#ffffff' opacity='.85'/><circle cx='74' cy='66' r='5' fill='#2f9a2c' opacity='.6'/>"
               f"<path d='M18 84 C18 30 110 30 110 84 Z' fill='url(#{d})' stroke='#7fd4ff' stroke-width='3'/>"
               f"<path d='M10 82 H118 L108 118 H20 Z' fill='url(#{b})'/>"
               f"<path d='M22 98 H106' stroke='#b85e00' stroke-width='5' stroke-linecap='round'/>"
               f"<circle cx='40' cy='108' r='4' fill='#fff3b0'/><circle cx='64' cy='108' r='4' fill='#fff3b0'/><circle cx='88' cy='108' r='4' fill='#fff3b0'/>"
               + glint('M32 70 q2 -26 22 -38 q-12 16 -14 38z', .8))


ICONS['incubator'] = incubator()


def paw():
    a, A = ramp('#ffd7a8', '#ff9f43', '#e06a10')
    return svg([A],
               f"<ellipse cx='64' cy='86' rx='32' ry='28' fill='url(#{a})'/>"
               f"<ellipse cx='22' cy='56' rx='14' ry='17' fill='url(#{a})'/><ellipse cx='106' cy='56' rx='14' ry='17' fill='url(#{a})'/>"
               f"<ellipse cx='44' cy='24' rx='14' ry='18' fill='url(#{a})'/><ellipse cx='84' cy='24' rx='14' ry='18' fill='url(#{a})'/>"
               f"<ellipse cx='64' cy='92' rx='18' ry='12' fill='#ffc48a' opacity='.7'/>"
               + glint('M44 70 q10 -10 22 -10 q-14 6 -16 16z') + glint('M38 12 q-6 4 -6 12 q4 -6 10 -8z') + glint('M78 12 q-6 4 -6 12 q4 -6 10 -8z')
               + glint('M14 46 q-4 4 -2 10 q2 -6 8 -8z') + glint('M98 46 q-4 4 -2 10 q2 -6 8 -8z'))


ICONS['pets'] = paw()


def bag():
    a, A = ramp('#ffb8d0', '#ff4f8a', '#d0145a')
    b, B = lg([(0, '#fff2a8'), (1, '#ffbf1f')])
    return svg([A, B],
               f"<path d='M40 42 C40 6 88 6 88 42' fill='none' stroke='#b00a4a' stroke-width='12' stroke-linecap='round'/>"
               f"<path d='M40 42 C40 6 88 6 88 42' fill='none' stroke='#ffd23a' stroke-width='5' stroke-linecap='round'/>"
               f"<path d='M16 40 H112 L104 120 H24 Z' fill='url(#{a})'/>"
               f"<path d='M16 40 H112 L111 52 H17 Z' fill='#ff86ae'/>"
               f"<path d='M64 60 l7 14 15 2 -11 10 3 15 -14 -7 -14 7 3 -15 -11 -10 15 -2z' fill='url(#{b})' stroke='#c4780a' stroke-width='3' stroke-linejoin='round'/>"
               + glint('M24 56 h12 l-4 44 h-12z', .6))


ICONS['shop'] = bag()


def chart():
    a, A = ramp('#a8f0ff', '#2fbfff', '#1478d8')
    b, B = ramp('#fff3a0', '#ffc21c', '#e08800')
    c, C = ramp('#b6ffa0', '#3ee05a', '#1a9a30')
    d, D = lg([(0, '#ffffff'), (1, '#dfe6f0')])
    return svg([A, B, C, D],
               f"<rect x='8' y='8' width='112' height='112' rx='20' fill='url(#{d})'/>"
               f"<rect x='22' y='68' width='22' height='40' rx='5' fill='url(#{a})'/>"
               f"<rect x='53' y='46' width='22' height='62' rx='5' fill='url(#{b})'/>"
               f"<rect x='84' y='24' width='22' height='84' rx='5' fill='url(#{c})'/>"
               + glint('M26 72 h6 v24 h-6z', .7) + glint('M57 50 h6 v30 h-6z', .7) + glint('M88 28 h6 v40 h-6z', .7)
               + glint('M14 14 h40 q-30 4 -36 20z', .8))


ICONS['stats'] = chart()


def gear():
    a, A = ramp('#f2f5fa', '#b9c3d0', '#7a8698')
    b, B = lg([(0, '#5a6678'), (1, '#2c3442')])
    return svg([A, B],
               "<path d='M56 6 H72 L75 21 L88 26 L100 18 L110 28 L102 40 L107 53 L122 56 V72 L107 75 L102 88 L110 100 L100 110 L88 102 L75 107 L72 122 H56 L53 107 L40 102 L28 110 L18 100 L26 88 L21 75 L6 72 V56 L21 53 L26 40 L18 28 L28 18 L40 26 L53 21 Z' fill='url(#" + a + ")'/>"
               f"<circle cx='64' cy='64' r='22' fill='url(#{b})'/><circle cx='64' cy='64' r='10' fill='#9aa6b8'/>"
               + glint('M28 36 q10 -16 28 -20 q-14 10 -18 26z'))


ICONS['settings'] = gear()


def afk():
    a, A = ramp('#fff6c8', '#ffd84a', '#f0a400')
    return svg([A],
               f"<path d='M78 14 A50 50 0 1 0 114 84 A40 40 0 1 1 78 14Z' fill='url(#{a})'/>"
               f"<text x='22' y='56' font-family='Arial Black,Arial' font-weight='900' font-size='34' fill='#9fd8ff' stroke='{INK}' stroke-width='4' paint-order='stroke'>Z</text>"
               f"<text x='4' y='30' font-family='Arial Black,Arial' font-weight='900' font-size='24' fill='#9fd8ff' stroke='{INK}' stroke-width='4' paint-order='stroke'>z</text>"
               + glint('M60 30 q-10 18 -4 40 q-12 -18 4 -40z', .6))


ICONS['afk'] = afk()


def crosshair():
    a, A = ramp('#ff9aa6', '#ff3d57', '#c00a28')
    return svg([A],
               f"<circle cx='64' cy='64' r='44' fill='none' stroke='url(#{a})' stroke-width='14'/>"
               f"<path d='M64 4 V36 M64 92 V124 M4 64 H36 M92 64 H124' stroke='url(#{a})' stroke-width='12' stroke-linecap='round'/>"
               f"<circle cx='64' cy='64' r='10' fill='url(#{a})'/>"
               + glint('M30 38 q8 -12 22 -16 q-12 8 -16 18z', .8))


ICONS['hunt'] = crosshair()

# ------------------------------------------------------------------ roles + match
def shoe():
    a, A = ramp('#a8eeff', '#2fb8ff', '#126ed0')
    return svg([A],
               f"<path d='M10 84 C10 62 26 54 44 56 L70 58 C82 46 92 44 104 52 L120 76 C124 86 120 100 110 102 H20 C14 102 10 96 10 84Z' fill='url(#{a})'/>"
               f"<path d='M8 102 H122 V112 Q122 118 116 118 H14 Q8 118 8 112Z' fill='#ffffff'/>"
               f"<path d='M44 58 L52 74 M58 58 L64 74 M72 56 L76 70' stroke='#ffffff' stroke-width='5' stroke-linecap='round'/>"
               f"<path d='M2 64 H24 M6 76 H22' stroke='#ffffff' stroke-width='5' stroke-linecap='round' opacity='.8'/>"
               + glint('M24 66 q10 -8 24 -6 q-14 2 -20 10z'))


ICONS['runner'] = shoe()


def knife():
    a, A = lg([(0, '#ffffff'), (.5, '#d9e2ec'), (1, '#8c9bad')], 0, 0, 1, 1)
    b, B = ramp('#c47a3a', '#8a4a1c', '#5a2c0c')
    c, C = ramp('#fff3a0', '#ffc21c', '#d07a00')
    return svg([A, B, C],
               f"<path d='M50 78 L104 12 Q120 6 116 22 L62 90 Z' fill='url(#{a})'/>"
               f"<path d='M56 84 L110 18' stroke='#7c8a9c' stroke-width='3' opacity='.6'/>"
               f"<rect x='34' y='70' width='40' height='14' rx='6' transform='rotate(45 54 77)' fill='url(#{c})'/>"
               f"<path d='M14 112 L38 88 L48 98 L24 122 Z' fill='url(#{b})'/>"
               + glint('M60 76 L100 26 L104 30 L66 80z', .7))


ICONS['catcher'] = knife()


def flag():
    a, A = ramp('#b6ffa0', '#3ee05a', '#16982e')
    b, B = lg([(0, '#ffffff'), (1, '#c9d2dc')])
    return svg([A, B],
               f"<rect x='18' y='10' width='12' height='112' rx='6' fill='url(#{b})'/>"
               f"<path d='M30 14 C60 4 76 28 112 16 V70 C76 82 60 58 30 68 Z' fill='url(#{a})'/>"
               f"<path d='M50 30 l14 14 l24 -22' fill='none' stroke='#fff' stroke-width='8' stroke-linecap='round' stroke-linejoin='round'/>"
               + glint('M34 20 q20 -6 32 2 q-16 0 -30 8z', .7))


ICONS['safe'] = flag()


def steal():
    e, E = lg([(0, '#ffffff'), (1, '#e3d6b4')])
    h, H = ramp('#ffd6b0', '#f2a46a', '#c06a30')
    return svg([E, H],
               f"<path d='M70 14 C52 14 44 42 44 56 C44 74 56 84 70 84 C86 84 96 74 96 56 C96 42 88 14 70 14Z' fill='url(#{e})'/>"
               f"<circle cx='62' cy='44' r='6' fill='#d8c79c'/><circle cx='80' cy='62' r='7' fill='#d8c79c'/>"
               f"<path d='M12 96 C24 72 44 74 52 86 L62 70 C66 64 74 66 72 74 L66 90 C80 84 96 86 104 96 L112 118 H20 Z' fill='url(#{h})'/>"
               f"<path d='M40 98 V110 M56 96 V112 M72 96 V112 M88 98 V110' stroke='#b0602a' stroke-width='3' stroke-linecap='round' opacity='.7'/>"
               + glint('M56 22 q-10 10 -10 26 q4 -14 14 -22z'))


ICONS['steal'] = steal()


def trophy():
    a, A = ramp('#fff7c0', '#ffcc2e', '#e08a00')
    b, B = ramp('#c47a3a', '#8a4a1c', '#5a2c0c')
    return svg([A, B],
               f"<path d='M30 22 C6 22 8 62 40 62 M98 22 C122 22 120 62 88 62' fill='none' stroke='#e08a00' stroke-width='10'/>"
               f"<path d='M28 10 H100 V46 C100 70 84 84 64 84 C44 84 28 70 28 46 Z' fill='url(#{a})'/>"
               f"<path d='M56 84 H72 V100 H56Z' fill='#e08a00'/>"
               f"<rect x='32' y='98' width='64' height='22' rx='6' fill='url(#{b})'/>"
               f"<path d='M64 30 l5 10 11 2 -8 8 2 11 -10 -5 -10 5 2 -11 -8 -8 11 -2z' fill='#fff3b0'/>"
               + glint('M36 16 h10 v30 q-8 -6 -10 -16z'))


ICONS['trophy'] = trophy()


def crown():
    a, A = ramp('#fff7c0', '#ffcc2e', '#e08a00')
    return svg([A],
               f"<path d='M10 40 L36 64 L64 18 L92 64 L118 40 L106 104 H22 Z' fill='url(#{a})'/>"
               f"<rect x='20' y='98' width='88' height='18' rx='5' fill='#e08a00'/>"
               f"<circle cx='64' cy='76' r='9' fill='#ff3d6e'/><circle cx='38' cy='84' r='6' fill='#2fbfff'/><circle cx='90' cy='84' r='6' fill='#3ee05a'/>"
               f"<circle cx='10' cy='40' r='7' fill='#fff3b0'/><circle cx='64' cy='18' r='8' fill='#fff3b0'/><circle cx='118' cy='40' r='7' fill='#fff3b0'/>"
               + glint('M30 72 L44 80 L40 92 L28 88z', .6))


ICONS['crown'] = crown()


def star(c1='#fff7c0', c2='#ffcc2e', c3='#e08a00'):
    a, A = ramp(c1, c2, c3)
    return svg([A], f"<path d='M64 6 L80 44 L122 46 L90 72 L100 114 L64 92 L28 114 L38 72 L6 46 L48 44 Z' fill='url(#{a})' stroke-linejoin='round'/>"
                    + glint('M56 22 L48 46 L24 48 L40 52z', .8))


ICONS['star'] = star()
ICONS['sparkle'] = svg([], "<path d='M64 4 C70 46 82 58 124 64 C82 70 70 82 64 124 C58 82 46 70 4 64 C46 58 58 46 64 4Z' fill='#ffffff'/>")


def lock():
    a, A = lg([(0, '#ffffff'), (1, '#c9d2dc')])
    b, B = ramp('#ffe27a', '#ffb21c', '#d07400')
    return svg([A, B],
               f"<path d='M38 58 V42 C38 12 90 12 90 42 V58' fill='none' stroke='url(#{a})' stroke-width='14'/>"
               f"<rect x='20' y='54' width='88' height='66' rx='14' fill='url(#{b})'/>"
               f"<circle cx='64' cy='80' r='10' fill='#6a3a00'/><path d='M64 84 V104' stroke='#6a3a00' stroke-width='9' stroke-linecap='round'/>"
               + glint('M28 62 h20 v8 h-20z', .7))


ICONS['lock'] = lock()


def check():
    a, A = ramp('#b6ffa0', '#3ee05a', '#16982e')
    return svg([A], f"<circle cx='64' cy='64' r='56' fill='url(#{a})'/><path d='M34 66 L56 88 L96 42' fill='none' stroke='#ffffff' stroke-width='16' stroke-linecap='round' stroke-linejoin='round'/>"
                    + glint('M24 44 q8 -18 26 -26 q-16 14 -20 30z', .7))


ICONS['check'] = check()


def clock():
    a, A = ramp('#a8eeff', '#2fb8ff', '#126ed0')
    return svg([A], f"<circle cx='64' cy='64' r='56' fill='url(#{a})'/><circle cx='64' cy='64' r='42' fill='#ffffff'/>"
                    f"<path d='M64 34 V66 L84 78' fill='none' stroke='{INK}' stroke-width='9' stroke-linecap='round' stroke-linejoin='round'/>"
                    f"<circle cx='64' cy='66' r='6' fill='{INK}'/>" + glint('M22 40 q8 -16 24 -22 q-14 10 -18 24z', .7))


ICONS['clock'] = clock()


def gift():
    a, A = ramp('#ffb8d0', '#ff4f8a', '#d0145a')
    b, B = ramp('#fff3a0', '#ffc21c', '#d07a00')
    return svg([A, B],
               f"<rect x='14' y='54' width='100' height='66' rx='8' fill='url(#{a})'/>"
               f"<rect x='8' y='38' width='112' height='24' rx='8' fill='#ff86ae'/>"
               f"<rect x='56' y='38' width='16' height='82' fill='url(#{b})'/>"
               f"<path d='M64 38 C44 8 20 20 36 38 Z M64 38 C84 8 108 20 92 38 Z' fill='url(#{b})'/>"
               + glint('M18 60 h14 v40 h-14z', .5))


ICONS['gift'] = gift()


def dice():
    a, A = lg([(0, '#ffffff'), (1, '#d7dee8')])
    return svg([A], f"<rect x='12' y='12' width='104' height='104' rx='22' fill='url(#{a})'/>"
                    + ''.join(f"<circle cx='{x}' cy='{y}' r='10' fill='#ff3d6e'/>" for x, y in [(40, 40), (88, 40), (64, 64), (40, 88), (88, 88)])
                    + glint('M20 24 q4 -8 14 -8 h30 q-36 4 -44 20z', .9))


ICONS['dice'] = dice()


def target():
    a, A = ramp('#ff9aa6', '#ff3d57', '#c00a28')
    return svg([A], f"<circle cx='64' cy='64' r='56' fill='url(#{a})'/><circle cx='64' cy='64' r='38' fill='#ffffff'/>"
                    f"<circle cx='64' cy='64' r='20' fill='url(#{a})'/>" + glint('M22 42 q8 -18 26 -24 q-16 12 -20 26z', .7))


ICONS['target'] = target()


def speaker():
    a, A = lg([(0, '#ffffff'), (1, '#c9d2dc')])
    return svg([A], f"<path d='M10 46 H38 L70 18 V110 L38 82 H10 Z' fill='url(#{a})'/>"
                    f"<path d='M86 44 Q98 64 86 84 M100 30 Q124 64 100 98' fill='none' stroke='#2fbfff' stroke-width='10' stroke-linecap='round'/>")


ICONS['sound'] = speaker()


def controller():
    a, A = lg([(0, '#5a6678'), (1, '#262c38')])
    return svg([A], f"<path d='M28 32 H100 C122 32 128 66 122 92 C118 112 98 114 90 100 L82 88 H46 L38 100 C30 114 10 112 6 92 C0 66 6 32 28 32Z' fill='url(#{a})'/>"
                    f"<path d='M34 52 V78 M21 65 H47' stroke='#ffffff' stroke-width='8' stroke-linecap='round'/>"
                    f"<circle cx='88' cy='56' r='8' fill='#ff3d6e'/><circle cx='102' cy='72' r='8' fill='#3ee05a'/><circle cx='76' cy='72' r='8' fill='#2fbfff'/>"
                    + glint('M24 40 h40 q-30 2 -40 10z', .4))


ICONS['controls'] = controller()


def refresh():
    a, A = ramp('#e6b0ff', '#b44dff', '#6a1fd6')
    return svg([A], f"<path d='M104 54 A42 42 0 1 0 98 92' fill='none' stroke='url(#{a})' stroke-width='16' stroke-linecap='round'/>"
                    f"<path d='M86 50 L118 56 L112 22 Z' fill='url(#{a})'/>")


ICONS['refresh'] = refresh()

# ------------------------------------------------------------------ ability pools (Workspace.FWP_PetShowroom)
def double_dash():
    a, A = ramp('#ffd8a0', '#ff8c2e', '#e04a00')
    return svg([A], f"<path d='M8 24 H48 L80 64 L48 104 H8 L40 64 Z' fill='url(#{a})'/>"
                    f"<path d='M52 24 H92 L124 64 L92 104 H52 L84 64 Z' fill='url(#{a})'/>"
                    + glint('M14 28 h28 l8 10 h-26z', .7) + glint('M58 28 h28 l8 10 h-26z', .7))


def invisibility():
    a, A = lg([(0, 'rgba(220,240,255,.98)'), (1, 'rgba(150,200,255,.9)')])
    return svg([A], f"<path d='M64 8 C34 8 18 32 18 58 V118 L32 106 L46 118 L60 106 L74 118 L88 106 L102 118 L110 110 V58 C110 32 94 8 64 8Z' fill='url(#{a})'/>"
                    f"<ellipse cx='48' cy='54' rx='8' ry='11' fill='#2a3a6a'/><ellipse cx='80' cy='54' rx='8' ry='11' fill='#2a3a6a'/>"
                    f"<path d='M50 82 Q64 90 78 82' fill='none' stroke='#2a3a6a' stroke-width='5' stroke-linecap='round'/>"
                    + glint('M32 36 q8 -18 26 -22 q-16 10 -20 26z'))


def decoy():
    a, A = ramp('#ffe6a8', '#ffc45c', '#e08a1a')
    b, B = lg([(0, 'rgba(255,214,140,.6)'), (1, 'rgba(255,170,60,.35)')])
    return svg([A, B],
               f"<path d='M86 20 C70 20 66 36 66 46 C66 56 72 64 76 66 L62 116 H118 L104 66 C108 64 114 56 114 46 C114 36 102 20 86 20Z' fill='url(#{b})'/>"
               f"<path d='M44 14 C26 14 20 32 20 44 C20 56 28 64 32 66 L14 120 H76 L58 66 C62 64 70 56 70 44 C70 32 62 14 44 14Z' fill='url(#{a})'/>"
               + glint('M30 24 q8 -8 18 -8 q-12 4 -14 14z'))


def shield():
    a, A = rg([(0, 'rgba(240,255,252,.98)'), (.7, 'rgba(120,236,220,.85)'), (1, 'rgba(40,180,170,.95)')], .38, .3, .8)
    return svg([A], f"<circle cx='64' cy='64' r='56' fill='url(#{a})'/>"
                    f"<path d='M64 30 L92 40 V62 C92 80 80 92 64 98 C48 92 36 80 36 62 V40 Z' fill='#1aa898' opacity='.85'/>"
                    + glint('M24 46 q10 -24 34 -30 q-22 14 -26 34z', .9) + glint('M92 96 q8 -6 10 -14 q0 10 -8 18z', .5))


def wall():
    a, A = ramp('#e2d4ff', '#b096ff', '#6a4ad0')
    rows = ''
    for r, y in enumerate(range(16, 112, 24)):
        off = 0 if r % 2 == 0 else -22
        for x in range(8 + off, 124, 44):
            rows += f"<rect x='{max(8, x)}' y='{y}' width='{min(40, 120 - max(8, x))}' height='20' rx='4' fill='url(#{a})'/>"
    return svg([A], rows + glint('M12 20 h30 v5 h-30z', .7) + glint('M56 20 h30 v5 h-30z', .7))


def tackle():
    a, A = ramp('#ffb0b0', '#ff5050', '#c01020')
    return svg([A], f"<path d='M20 52 C20 30 40 22 58 26 L92 30 C110 32 118 48 114 66 L108 92 C104 108 90 116 74 114 L40 110 C26 108 20 96 20 84 Z' fill='url(#{a})'/>"
                    f"<path d='M58 26 L60 60 M78 28 L78 60 M96 32 L94 60' stroke='#a00a18' stroke-width='5' stroke-linecap='round' opacity='.6'/>"
                    f"<rect x='8' y='54' width='20' height='40' rx='8' fill='#ffd23a'/>"
                    f"<path d='M118 14 L106 34 M126 40 L110 46 M98 6 L96 24' stroke='#ffd23a' stroke-width='7' stroke-linecap='round'/>"
                    + glint('M30 40 q10 -12 26 -12 q-16 6 -22 18z'))


def scout():  # radar: see the 3 nearest rivals
    a, A = ramp('#c8ffd8', '#3edc82', '#14894a')
    b, B = rg([(0, '#1f6a4a'), (.75, '#0c3a2a'), (1, '#062418')], .45, .4, .7)
    c, C = lg([(0, 'rgba(150,255,190,.85)'), (1, 'rgba(150,255,190,0)')], 0, 0, 1, 1)
    blips = ''.join(f"<circle cx='{x}' cy='{y}' r='7' fill='#ff4a4a'/><circle cx='{x - 2}' cy='{y - 2}' r='2.5' fill='#fff' opacity='.9'/>"
                    for x, y in ((84, 40), (94, 78), (44, 88)))
    return svg([A, B, C], f"<circle cx='64' cy='64' r='58' fill='url(#{a})'/><circle cx='64' cy='64' r='47' fill='url(#{b})'/>"
                          f"<circle cx='64' cy='64' r='32' fill='none' stroke='#3edc82' stroke-width='3' opacity='.55'/>"
                          f"<circle cx='64' cy='64' r='16' fill='none' stroke='#3edc82' stroke-width='3' opacity='.55'/>"
                          f"<path d='M64 17 V111 M17 64 H111' stroke='#3edc82' stroke-width='2.5' opacity='.4'/>"
                          f"<path d='M64 64 L64 17 A47 47 0 0 1 104 40 Z' fill='url(#{c})'/>"
                          f"<path d='M64 64 L64 17' stroke='#c8ffd8' stroke-width='4' stroke-linecap='round'/>"
                          + blips + f"<circle cx='64' cy='64' r='6' fill='#c8ffd8'/>" + glint('M16 52 q6 -26 34 -36 q-22 14 -28 38z', .8))


def brake():  # hard stop and sharp cut: arrow that skids into a right-angle turn
    a, A = ramp('#fff3a0', '#ffd23a', '#e88a00')
    skid = ''.join(f"<path d='M{x} 92 L{x - 6} 120' stroke='#3a2410' stroke-width='6' stroke-linecap='round' opacity='.75'/>" for x in (26, 40, 54))
    return svg([A], skid +
               f"<path d='M22 100 V56 Q22 38 40 38 H84 V18 L122 52 L84 86 V66 H50 V100 Z' fill='url(#{a})'/>"
               f"<path d='M8 30 L18 36 M10 50 L20 50 M14 16 L22 26' stroke='#ffd23a' stroke-width='5' stroke-linecap='round'/>"
               + glint('M28 92 V58 Q28 44 42 44 H60 V48 H44 Q34 48 34 60 V92z', .75) + glint('M90 28 l18 18 -4 3 -14 -14z', .6))


def spring():  # coil spring launching up
    a, A = lg([(0, '#e8ffd0'), (.5, '#8aff4a'), (1, '#3aa018')], 0, 0, 1, 0)
    b, B = ramp('#f0f4ff', '#b8c4dc', '#6a7898')
    c, C = ramp('#e8ffd0', '#8aff4a', '#3aa018')
    coil = ''.join(f"<ellipse cx='64' cy='{y}' rx='34' ry='9' fill='none' stroke='url(#{a})' stroke-width='9'/>" for y in (104, 90, 76, 62))
    return svg([A, B, C], f"<rect x='22' y='108' width='84' height='12' rx='5' fill='url(#{b})'/>" + coil +
               f"<rect x='22' y='46' width='84' height='12' rx='5' fill='url(#{b})'/>"
               f"<path d='M64 4 L96 38 H76 V44 H52 V38 H32 Z' fill='url(#{c})'/>"
               + glint('M40 34 L64 10 L68 14 L48 34z', .8) + glint('M28 48 h40 v3 h-40z', .7))


ICONS['ab_scout'] = scout()
ICONS['ab_brake'] = brake()
ICONS['ab_spring'] = spring()
ICONS['ab_dash'] = double_dash()
ICONS['ab_invis'] = invisibility()
ICONS['ab_decoy'] = decoy()
ICONS['ab_shield'] = shield()
ICONS['ab_wall'] = wall()
ICONS['ab_tackle'] = tackle()

# ------------------------------------------------------------------ shop item kinds
def trail():
    a, A = lg([(0, 'rgba(255,240,140,0)'), (1, '#ffe14a')], 0, 1, 1, 0)
    return svg([A], f"<path d='M8 120 C40 90 60 76 92 44' stroke='url(#{a})' stroke-width='22' stroke-linecap='round' fill='none'/>"
                    f"<path d='M98 10 L106 30 L126 34 L110 46 L114 66 L98 56 L82 66 L86 46 L70 34 L90 30Z' fill='#ffe14a'/>"
                    f"<circle cx='40' cy='70' r='5' fill='#fff'/><circle cx='62' cy='96' r='4' fill='#fff'/><circle cx='24' cy='96' r='3' fill='#fff'/>")


def bolt():
    a, A = ramp('#e8f6ff', '#7ec8ff', '#2a7ae0')
    return svg([A], f"<path d='M72 4 L20 72 H58 L44 124 L108 50 H68 L88 4 Z' fill='url(#{a})'/>" + glint('M66 12 L32 64 H44z', .8))


def confetti():
    a, A = ramp('#ffb8d0', '#ff4f8a', '#d0145a')
    bits = ''.join(f"<rect x='{x}' y='{y}' width='10' height='18' rx='3' transform='rotate({r} {x} {y})' fill='{c}'/>"
                   for x, y, r, c in [(70, 14, 30, '#ffd23a'), (96, 30, -20, '#3ee05a'), (104, 62, 40, '#2fbfff'), (84, 8, -40, '#b44dff'), (112, 10, 20, '#ff3d6e')])
    return svg([A], f"<path d='M10 118 L40 40 L88 88 Z' fill='url(#{a})'/><path d='M22 86 L56 104 M30 64 L70 86' stroke='#ffd23a' stroke-width='7'/>" + bits)


def case():
    a, A = lg([(0, 'rgba(230,248,255,.95)'), (1, 'rgba(140,210,255,.8)')])
    e, E = lg([(0, '#ffffff'), (1, '#e3d6b4')])
    return svg([A, E], f"<path d='M64 22 C46 22 38 50 38 64 C38 82 50 92 64 92 C78 92 90 82 90 64 C90 50 82 22 64 22Z' fill='url(#{e})'/>"
                       f"<path d='M64 6 L112 24 V60 C112 92 92 114 64 124 C36 114 16 92 16 60 V24 Z' fill='url(#{a})' stroke='#7fd4ff' stroke-width='4'/>"
                       + glint('M26 30 L52 18 L50 30 L28 40z', .9))


def palette():
    a, A = lg([(0, '#fff4dc'), (1, '#e8cd9a')])
    return svg([A], f"<path d='M64 8 C30 8 8 32 8 62 C8 92 30 118 58 118 C70 118 72 108 66 100 C60 92 66 84 76 84 H92 C110 84 120 72 120 56 C120 28 94 8 64 8Z' fill='url(#{a})'/>"
                    + ''.join(f"<circle cx='{x}' cy='{y}' r='10' fill='{c}'/>" for x, y, c in [(36, 50, '#ff3d6e'), (58, 30, '#ffd23a'), (86, 34, '#3ee05a'), (98, 58, '#2fbfff'), (32, 82, '#b44dff')]))


def hatch():
    a, A = lg([(0, '#ffffff'), (1, '#e3d6b4')])
    return svg([A], f"<path d='M14 74 C14 40 36 16 64 16 C92 16 114 40 114 74 L100 66 L86 80 L72 62 L58 82 L44 62 L30 80 Z' fill='url(#{a})' transform='rotate(-18 64 50) translate(-6 -16)'/>"
                    f"<path d='M20 84 L34 74 L48 90 L62 74 L76 90 L90 74 L108 86 C106 106 88 122 64 122 C40 122 22 106 20 84Z' fill='url(#{a})'/>"
                    f"<path d='M64 30 L68 44 L82 48 L68 52 L64 66 L60 52 L46 48 L60 44Z' fill='#ffd23a'/>"
                    f"<path d='M100 20 L102 28 L110 30 L102 32 L100 40 L98 32 L90 30 L98 28Z' fill='#ffd23a'/>")


def emote():
    a, A = ramp('#fff3a0', '#ffd23a', '#e09a00')
    return svg([A], f"<circle cx='64' cy='64' r='56' fill='url(#{a})'/><ellipse cx='46' cy='52' rx='7' ry='10' fill='{INK}'/><ellipse cx='82' cy='52' rx='7' ry='10' fill='{INK}'/>"
                    f"<path d='M36 74 Q64 104 92 74' fill='#c0304a' stroke='{INK}' stroke-width='5' stroke-linejoin='round'/>"
                    f"<circle cx='30' cy='72' r='8' fill='#ff8aa0' opacity='.7'/><circle cx='98' cy='72' r='8' fill='#ff8aa0' opacity='.7'/>"
                    + glint('M24 40 q8 -16 24 -22 q-14 10 -18 24z', .7))


ICONS['trail'] = trail()
ICONS['entrance'] = bolt()
ICONS['burst'] = confetti()
ICONS['case'] = case()
ICONS['abilityfx'] = palette()
ICONS['hatchfx'] = hatch()
ICONS['emote'] = emote()


def plus():
    a, A = ramp('#b6ffa0', '#3ee05a', '#16982e')
    return svg([A], f"<rect x='48' y='12' width='32' height='104' rx='12' fill='url(#{a})'/><rect x='12' y='48' width='104' height='32' rx='12' fill='url(#{a})'/>")


def info():
    a, A = ramp('#a8eeff', '#2fb8ff', '#126ed0')
    return svg([A], f"<circle cx='64' cy='64' r='56' fill='url(#{a})'/><circle cx='64' cy='36' r='9' fill='#fff'/><rect x='55' y='54' width='18' height='46' rx='8' fill='#fff'/>")


ICONS['plus'] = plus()
ICONS['info'] = info()


# ------------------------------------------------------------------ social (16 Oct): server list + spectate stand-ins
def globe():
    a, A = ramp('#a8fff0', '#22d3b8', '#0a8a86')
    return svg([A],
               f"<circle cx='64' cy='64' r='54' fill='url(#{a})'/>"
               f"<ellipse cx='64' cy='64' rx='22' ry='54' fill='none' stroke='{INK}' stroke-width='5' opacity='.55'/>"
               f"<path d='M10 64 H118 M18 36 H110 M18 92 H110 M64 10 V118' stroke='{INK}' stroke-width='5' opacity='.55' fill='none'/>"
               + glint('M26 40 q10 -22 34 -28 q-22 12 -28 34z', .8))


def eye():
    a, A = ramp('#ffffff', '#e4ecf6', '#a9b7c8')
    b, B = rg([(0, '#9ff3ff'), (.6, '#2fa8ff'), (1, '#1456c8')], .4, .35, .7)
    return svg([A, B],
               f"<path d='M6 64 Q64 2 122 64 Q64 126 6 64Z' fill='url(#{a})'/>"
               f"<circle cx='64' cy='64' r='30' fill='url(#{b})'/>"
               f"<circle cx='64' cy='64' r='13' fill='{INK}'/>"
               f"<circle cx='54' cy='54' r='7' fill='#fff'/>")


ICONS['servers'] = globe()
ICONS['spectate'] = eye()

if __name__ == '__main__':
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'icons_svg')
    os.makedirs(out, exist_ok=True)
    for k, v in ICONS.items():
        open(os.path.join(out, k + '.svg'), 'w').write(v)
    print('wrote', len(ICONS), 'svgs')
