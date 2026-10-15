#!/usr/bin/env python3
"""PLACEHOLDER icon set for Evolve or Steal, drawn as SVG (no icon pack owned yet).
One treatment for every icon: 128x128 viewBox, thick near-black outline (OL), a base fill, a darker
lower shade and a white highlight. Swap for a licensed pack later: keep the slugs, the layout won't change.
Writes icons_src/<slug>.svg; tools/render_icons.mjs rasterises them to icons/<slug>.png (256 px).
"""
import os

OL = '#120d14'
W = 7  # outline width in viewBox units


def svg(body):
    return (f"<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 128 128' width='256' height='256'>"
            f"<g stroke='{OL}' stroke-width='{W}' stroke-linejoin='round' stroke-linecap='round'>{body}</g></svg>")


def hl(d):  # white highlight, no outline
    return f"<path d='{d}' fill='#fff' fill-opacity='.85' stroke='none'/>"


def shade(d, c):
    return f"<path d='{d}' fill='{c}' stroke='none'/>"


ICONS = {}

# ---- currencies
ICONS['gold'] = svg(
    "<circle cx='64' cy='66' r='50' fill='#f5a90f'/>"
    "<circle cx='64' cy='60' r='50' fill='#ffd23a'/>"
    "<circle cx='64' cy='60' r='34' fill='#ffb81c' stroke-width='5'/>"
    "<path d='M64 38 l6 14 15 1 -11 10 4 15 -14 -8 -14 8 4 -15 -11 -10 15 -1z' fill='#fff3b0' stroke-width='5'/>"
    + hl('M30 44 q8 -18 26 -24 q-14 12 -18 28z'))
ICONS['gem'] = svg(
    "<path d='M64 116 L10 48 L32 18 H96 L118 48 Z' fill='#2fd47a'/>"
    + shade('M64 112 L14 50 H114 Z', '#18a85a') +
    "<path d='M10 48 H118 M32 18 L46 48 L64 116 L82 48 L96 18 M46 48 L64 18 L82 48' fill='none' stroke-width='5'/>"
    + hl('M36 24 h16 l-10 20 h-16z'))

# ---- eggs and materials
ICONS['egg'] = svg(
    "<path d='M64 10 C30 10 18 62 18 80 C18 106 40 120 64 120 C88 120 110 106 110 80 C110 62 98 10 64 10Z' fill='#f6eed6'/>"
    + shade('M22 86 C26 108 44 116 64 116 C84 116 102 108 106 86 C96 98 82 104 64 104 C46 104 32 98 22 86Z', '#d9c9a0') +
    "<circle cx='48' cy='58' r='8' fill='#d6c49a' stroke-width='4'/><circle cx='80' cy='80' r='10' fill='#d6c49a' stroke-width='4'/>"
    "<circle cx='70' cy='42' r='5' fill='#d6c49a' stroke-width='3'/>"
    + hl('M42 22 q-14 14 -16 40 q10 -24 24 -36z'))


def piece(top, mid, dark, name):
    ICONS[name] = svg(
        f"<path d='M20 70 C20 40 40 14 64 14 C88 14 108 40 108 70 L94 62 L82 76 L68 60 L54 78 L40 62 L28 76 Z' fill='{mid}'/>"
        + shade('M24 72 L28 76 L40 62 L54 78 L68 60 L82 76 L94 62 L104 68 C102 60 98 52 94 46 L80 58 L68 46 L54 60 L40 48 L28 58Z', dark) +
        f"<path d='M28 92 L40 80 L54 96 L68 80 L82 96 L94 82 L108 92 C104 110 86 118 64 118 C42 118 24 110 28 92Z' fill='{mid}'/>"
        + shade('M30 102 C36 112 50 116 64 116 C78 116 92 112 100 104 C88 108 76 110 64 110 C52 110 40 108 30 102Z', dark)
        + hl('M44 24 q-14 10 -18 28 q10 -16 24 -24z'))


piece('#fff', '#efe6cf', '#cbbd97', 'piece_common')
piece('#fff', '#5cb6ff', '#2a78d6', 'piece_rare')
piece('#fff', '#be72ff', '#8236d8', 'piece_epic')

ICONS['incubator'] = svg(
    "<path d='M64 8 C40 8 30 44 30 58 C30 76 44 86 64 86 C84 86 98 76 98 58 C98 44 88 8 64 8Z' fill='#9ef06a'/>"
    + shade('M34 66 C38 78 50 84 64 84 C78 84 90 78 94 66 C86 74 76 78 64 78 C52 78 42 74 34 66Z', '#5cc23c') +
    "<path d='M14 70 H114 L104 116 H24 Z' fill='#ffb21c'/>"
    + shade('M20 96 H108 L104 114 H24Z', '#e08800') +
    "<path d='M14 70 H114' fill='none'/><path d='M28 84 H100' fill='none' stroke-width='5'/>"
    + hl('M50 16 q-12 10 -14 28 q8 -14 18 -22z'))

ICONS['paw'] = svg(
    "<ellipse cx='64' cy='86' rx='30' ry='26' fill='#ff9f43'/>"
    "<ellipse cx='26' cy='58' rx='13' ry='16' fill='#ff9f43'/><ellipse cx='102' cy='58' rx='13' ry='16' fill='#ff9f43'/>"
    "<ellipse cx='46' cy='28' rx='13' ry='17' fill='#ff9f43'/><ellipse cx='82' cy='28' rx='13' ry='17' fill='#ff9f43'/>"
    + shade('M38 96 C44 108 54 110 64 110 C74 110 84 108 90 96 C82 102 74 104 64 104 C54 104 46 102 38 96Z', '#e0731a')
    + hl('M46 70 q8 -8 18 -8 q-12 4 -14 12z') + hl('M40 16 q-6 4 -6 12 q4 -6 10 -8z'))

ICONS['bag'] = svg(
    "<path d='M42 40 C42 14 86 14 86 40' fill='none' stroke-width='9'/>"
    "<path d='M42 40 C42 14 86 14 86 40' fill='none' stroke='#ffd23a' stroke-width='3'/>"
    "<path d='M20 40 H108 L100 118 H28 Z' fill='#ff5b8a'/>"
    + shade('M24 92 H104 L100 116 H28Z', '#d6336a') +
    "<circle cx='64' cy='74' r='16' fill='#ffd23a' stroke-width='5'/>"
    + hl('M30 48 h14 l-4 30 h-12z'))

ICONS['scroll'] = svg(
    "<rect x='26' y='16' width='76' height='96' rx='8' fill='#fff1c9'/>"
    + shade('M30 92 H98 V104 Q98 108 94 108 H34 Q30 108 30 104Z', '#e3cf98') +
    "<path d='M42 42 H86 M42 60 H86 M42 78 H72' fill='none' stroke-width='6'/>"
    "<circle cx='96' cy='100' r='20' fill='#3ee05a'/><path d='M86 100 l7 7 l12 -14' fill='none' stroke-width='6'/>")

ICONS['gear'] = svg(
    "<path d='M56 8 H72 L75 22 L88 27 L100 19 L111 30 L103 42 L108 55 L122 58 V72 L108 75 L103 88 L111 100 L100 111 L88 103 L75 108 L72 122 H56 L53 108 L40 103 L28 111 L17 100 L25 88 L20 75 L6 72 V58 L20 55 L25 42 L17 30 L28 19 L40 27 L53 22 Z' fill='#c9d2dc'/>"
    + shade('M22 80 Q36 110 64 110 Q92 110 106 80 Q92 98 64 98 Q36 98 22 80Z', '#8e9aa8') +
    "<circle cx='64' cy='65' r='18' fill='#3a4350'/>" + hl('M30 40 q10 -14 26 -18 q-12 10 -16 22z'))

ICONS['chart'] = svg(
    "<rect x='14' y='70' width='26' height='44' rx='4' fill='#40c4ff'/>"
    "<rect x='51' y='44' width='26' height='70' rx='4' fill='#ffd23a'/>"
    "<rect x='88' y='16' width='26' height='98' rx='4' fill='#3ee05a'/>"
    + hl('M19 76 h6 v20 h-6z') + hl('M56 50 h6 v24 h-6z') + hl('M93 22 h6 v30 h-6z'))

ICONS['afk'] = svg(
    "<path d='M14 34 H54 L22 78 H62' fill='none' stroke-width='16'/><path d='M14 34 H54 L22 78 H62' fill='none' stroke='#9fd8ff' stroke-width='8'/>"
    "<path d='M70 66 H106 L76 106 H112' fill='none' stroke-width='14'/><path d='M70 66 H106 L76 106 H112' fill='none' stroke='#9fd8ff' stroke-width='6'/>")

ICONS['crosshair'] = svg(
    "<circle cx='64' cy='64' r='42' fill='none' stroke-width='18'/><circle cx='64' cy='64' r='42' fill='none' stroke='#ff4d57' stroke-width='9'/>"
    "<path d='M64 6 V40 M64 88 V122 M6 64 H40 M88 64 H122' fill='none' stroke-width='16'/>"
    "<path d='M64 9 V38 M64 90 V119 M9 64 H38 M90 64 H119' fill='none' stroke='#ffffff' stroke-width='7'/>"
    "<circle cx='64' cy='64' r='9' fill='#ff4d57' stroke-width='5'/>")

ICONS['lock'] = svg(
    "<path d='M38 58 V40 C38 10 90 10 90 40 V58' fill='none' stroke-width='22'/>"
    "<path d='M38 58 V40 C38 10 90 10 90 40 V58' fill='none' stroke='#d7dde4' stroke-width='9'/>"
    "<rect x='22' y='56' width='84' height='62' rx='12' fill='#eef2f6'/>"
    + shade('M26 96 H102 V106 Q102 114 94 114 H34 Q26 114 26 106Z', '#b8c2cc') +
    "<path d='M64 76 V96' fill='none' stroke-width='10'/><circle cx='64' cy='78' r='8' fill='{OL}' stroke='none'/>")
ICONS['lock'] = ICONS['lock'].replace('{OL}', OL)

ICONS['check'] = svg("<path d='M18 66 L50 98 L112 30' fill='none' stroke-width='30'/>"
                     "<path d='M18 66 L50 98 L112 30' fill='none' stroke='#3ee05a' stroke-width='16'/>")

ICONS['clock'] = svg("<circle cx='64' cy='66' r='50' fill='#ffd23a'/><circle cx='64' cy='66' r='38' fill='#fff8de' stroke-width='5'/>"
                     "<path d='M64 40 V66 L82 78' fill='none' stroke-width='8'/>" + hl('M30 46 q8 -16 24 -22 q-12 10 -16 24z'))

ICONS['trophy'] = svg(
    "<path d='M30 22 C8 22 10 58 38 58 M98 22 C120 22 118 58 90 58' fill='none' stroke-width='14'/>"
    "<path d='M30 22 C8 22 10 58 38 58 M98 22 C120 22 118 58 90 58' fill='none' stroke='#ffd23a' stroke-width='5'/>"
    "<path d='M30 12 H98 V44 C98 66 82 78 64 78 C46 78 30 66 30 44 Z' fill='#ffd23a'/>"
    + shade('M34 50 C38 66 50 74 64 74 C78 74 90 66 94 50 C86 60 76 66 64 66 C52 66 42 60 34 50Z', '#f0a000') +
    "<path d='M56 78 H72 V96 H56Z' fill='#f0a000'/><rect x='34' y='96' width='60' height='22' rx='5' fill='#7a4a1c'/>"
    + hl('M40 18 h10 v26 q-8 -6 -10 -14z'))

# ---- roles and abilities
ICONS['knife'] = svg(
    "<path d='M18 110 L40 88 L50 98 L28 120Z' fill='#7a4a1c'/>"
    "<path d='M36 80 L56 100' fill='none' stroke-width='14'/><path d='M36 80 L56 100' fill='none' stroke='#ffd23a' stroke-width='5'/>"
    "<path d='M48 82 L106 14 Q118 10 116 22 L54 90 Z' fill='#e8eef4'/>"
    + shade('M56 88 L114 24 Q116 30 112 34 L60 92Z', '#a9b6c4'))
ICONS['runner'] = svg(
    "<path d='M14 84 C14 64 30 58 46 60 L70 62 C82 52 90 50 100 56 L114 76 C118 84 116 96 108 100 H22 C16 100 14 94 14 84Z' fill='#40c4ff'/>"
    + shade('M16 88 H114 C114 96 110 100 104 100 H22 C18 100 16 96 16 88Z', '#1f86d6') +
    "<path d='M10 108 H118' fill='none' stroke-width='10'/><path d='M44 60 L52 74 M58 61 L64 74' fill='none' stroke-width='5'/>"
    + hl('M24 70 q10 -6 22 -4 q-12 2 -18 10z'))

ICONS['decoy'] = svg(  # mask: a copy of you
    "<path d='M14 40 C14 22 114 22 114 40 C114 80 92 112 64 112 C36 112 14 80 14 40Z' fill='#ffc45c'/>"
    + shade('M18 64 C26 92 44 108 64 108 C84 108 102 92 110 64 C100 84 84 96 64 96 C44 96 28 84 18 64Z', '#e8962a') +
    "<path d='M30 52 Q42 42 54 52 Q42 62 30 52Z M74 52 Q86 42 98 52 Q86 62 74 52Z' fill='#120d14' stroke-width='4'/>"
    "<path d='M48 84 Q64 94 80 84' fill='none' stroke-width='6'/>" + hl('M26 34 q20 -8 40 -6 q-24 4 -36 14z'))
ICONS['scout'] = svg(  # eye with ping rings
    "<path d='M8 64 C30 26 98 26 120 64 C98 102 30 102 8 64Z' fill='#e9f8ff'/>"
    "<circle cx='64' cy='64' r='26' fill='#40c4ff'/><circle cx='64' cy='64' r='12' fill='#120d14' stroke='none'/>"
    + hl('M54 50 a8 8 0 1 0 1 0z'))
ICONS['brake'] = svg(  # stop hand on a sign
    "<path d='M42 8 H86 L120 42 V86 L86 120 H42 L8 86 V42 Z' fill='#4fe36a'/>"
    + shade('M14 84 L44 114 H84 L114 84 V90 L86 116 H42 L12 88Z', '#25b046') +
    "<path d='M44 56 V40 M56 54 V32 M68 54 V32 M80 58 V40 M44 56 C44 96 84 100 88 70 L94 58' fill='none' stroke-width='10'/>"
    "<path d='M44 56 V40 M56 54 V32 M68 54 V32 M80 58 V40 M44 56 C44 96 84 100 88 70 L94 58' fill='none' stroke='#ffffff' stroke-width='4'/>"
    + hl('M30 24 h18 l-20 20 v-12z'))
ICONS['dice'] = svg(
    "<rect x='16' y='16' width='96' height='96' rx='18' fill='#ffffff'/>"
    + shade('M20 92 H108 V96 Q108 108 96 108 H32 Q20 108 20 96Z', '#c9d2dc') +
    "".join(f"<circle cx='{x}' cy='{y}' r='9' fill='{OL}' stroke='none'/>" for x, y in [(42, 42), (86, 42), (64, 64), (42, 86), (86, 86)]))
ICONS['target'] = svg(
    "<circle cx='64' cy='64' r='52' fill='#ff4d57'/><circle cx='64' cy='64' r='36' fill='#ffffff' stroke-width='5'/>"
    "<circle cx='64' cy='64' r='18' fill='#ff4d57' stroke-width='5'/>" + hl('M26 44 q8 -16 24 -22 q-12 10 -16 24z'))
ICONS['sound'] = svg(
    "<path d='M14 48 H38 L66 22 V106 L38 80 H14 Z' fill='#e9f8ff'/>"
    "<path d='M82 46 Q94 64 82 82 M96 32 Q118 64 96 96' fill='none' stroke-width='9'/>")
ICONS['controller'] = svg(
    "<path d='M30 34 H98 C118 34 124 64 120 88 C116 106 100 108 92 96 L84 84 H44 L36 96 C28 108 12 106 8 88 C4 64 10 34 30 34Z' fill='#c9d2dc'/>"
    + shade('M10 86 C14 104 28 104 34 94 L42 82 H86 L94 94 C100 104 114 104 118 86 C112 94 104 94 98 84 L90 74 H38 L30 84 C24 94 16 94 10 86Z', '#8e9aa8') +
    "<path d='M36 50 V74 M24 62 H48' fill='none' stroke-width='8'/><circle cx='88' cy='56' r='6' fill='#ff4d57' stroke-width='4'/>"
    "<circle cx='100' cy='70' r='6' fill='#3ee05a' stroke-width='4'/>")
ICONS['eye'] = ICONS['scout']
ICONS['sparkle'] = svg("<path d='M64 6 C70 46 82 58 122 64 C82 70 70 82 64 122 C58 82 46 70 6 64 C46 58 58 46 64 6Z' fill='#ffffff'/>")

if __name__ == '__main__':
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'icons_src')
    os.makedirs(out, exist_ok=True)
    for k, v in ICONS.items():
        open(os.path.join(out, k + '.svg'), 'w').write(v)
    print('wrote', len(ICONS), 'svgs')
