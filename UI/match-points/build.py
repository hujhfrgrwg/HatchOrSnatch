#!/usr/bin/env python3
"""Hatch or Snatch UI (roblox-ui-maker project): HOS-PTS-001 match points, revive and the end leaderboard.

In-match feedback that never pauses play, and the ranking at the end of a match:
    PointsPop    "+100 Reached Safety!" beside your Runner (screen space, right of centre), stacks upward
    JukeWord     the big "JUKE!" slam over your Runner when a Catcher's lunge or stab misses you
    HeadPop      a small "+10" over the head (BillboardGui), the same moment
    DownedTag    over a downed Runner for 6 s: "DOWN" + the revive window draining (everyone sees it)
    RevivePrompt the custom ProximityPrompt look for Runners: key cap, REVIVE, the 1.5 s hold filling
    Leaderboard  end of match: every player ranked by points, what they did, your earnings (XP, Gold)
Points (PointsConfig): safety +100, Hero alone +200, juke +10, revive +25, catch +50, snatch +25 / +50 / +100
(Rare / Epic / Legendary egg). Points become XP 1:1; Gold is today's pot split by points.

    python build.py                   # writes the pages below + index.html
    python -m http.server 8873 --bind 127.0.0.1    # then open http://127.0.0.1:8873/index.html

Style: the game's Oct 2026 restyle (ReplicatedStorage.EOS.UI.Theme), as in Hero or Chicken and Last One
Standing: white Montserrat ExtraBold with a near-black outline, gold accent, dark see-through glass with a
thin light edge and a gold underline. The pops copy the reference game's format (docs/references 12, 13):
outlined words straight on the scene, no plate. Everything is native except the crown (already uploaded for
EOSUI), so nothing new is uploaded. Shared components come from ../web/build.py.

Pages (1920x1080, ?raw = 1:1 for export, ?check = overflow check):
    match_points_states.html     every state in context, PC and phone (review only)
    match_points.html            the Leaderboard screen as exported                  -> exported
    match_points_templates.html  PointsPop, JukeWord, HeadPop, DownedTag, RevivePrompt -> templates
"""
import importlib.util
import os

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location('webkit', os.path.join(HERE, '..', 'web', 'build.py'))
W = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(W)
T, grp, sub, box, page = W.T, W.grp, W.sub, W.box, W.page

# ---------------------------------------------------------------- tokens (Theme.luau)
GLASS = 'rgba(17,20,27,.90)'       # Theme.panel: big panel bodies 90% over a bright world (LESSONS 6)
HUD_GLASS = 'rgba(17,20,27,.78)'   # Theme.panel at Theme.panelT: small world chrome
ROW = 'rgba(255,255,255,.06)'
ROW_YOU = 'rgba(255,210,58,.16)'
EDGE = 'rgba(255,255,255,.16)'
LIP = '#c27a00'                    # ramps.gold lip: the gold underline
INK = '#07090e'
GOLD = '#ffd23a'
SILVER = '#d4dbe1'
BRONZE = '#e08a4a'

NAME = 'SunnyBunny42'
LONG = 'xXDragonSlayer2014Xx'      # 20 characters (Roblox display names max out at 20)

# the pop kinds: amount colour class, words (PointsConfig.KINDS on the runtime side)
KINDS = {
    'safe': ('f-green', 'Reached Safety!'),
    'hero': ('f-gold', 'Hero crossing!'),
    'juke': ('', 'Juke!'),
    'revive': ('f-blue', 'Revive!'),
    'catch': ('f-red', 'Catch!'),
    'snatch_rare': ('f-blue', 'Rare egg snatched!'),
    'snatch_epic': ('f-purple', 'Epic egg snatched!'),
    'snatch_legendary': ('f-gold', 'Legendary egg snatched!'),
}
AMOUNT = {'safe': 100, 'hero': 200, 'juke': 10, 'revive': 25, 'catch': 50, 'snatch_rare': 25, 'snatch_epic': 50, 'snatch_legendary': 100}


# ---------------------------------------------------------------- pieces
POP_W, POP_H = 620, 64


def pop(kind='safe', name='PointsPop'):
    """One line, left-aligned (it grows to the right of the Runner): +amount (coloured) then the words."""
    fill, words = KINDS[kind]
    row = (f"<div class='abs fill' style='display:flex;align-items:center;gap:14px'>"
           f"{T('+' + str(AMOUNT[kind]), 46, 'l', fill, name='AmountText')}{T(words, 36, 'l', name='WordsText')}</div>")
    return box(0, 0, POP_W, POP_H, row, name=name)


def juke_word():
    return box(0, 0, 640, 200, W.flex(T('JUKE!', 150, 'xl', name='WordText')), name='Word')


def head_pop(text='+10', fill=''):
    return box(0, 0, 200, 70, W.flex(T(text, 48, 'l', fill, name='PopText')), name='Pop')


TAG_W, TAG_H = 300, 92


def downed_tag(frac=.7, secs=4):
    """Glass pill over the body: DOWN + seconds left, the revive window draining under it."""
    inner = (f"<div class='abs' style='left:0;right:0;top:6px;height:52px;display:flex;align-items:center;justify-content:center;gap:12px'>"
             f"{T('DOWN', 36, 'l', 'f-red', name='DownText')}{T(f'{secs}s', 36, 'l', name='SecsText')}</div>"
             f"<div class='bar' data-n='Bar' style='left:22px;top:62px;width:{TAG_W - 44}px;height:14px'>"
             f"<i class='g-red' data-n='F' style='width:{frac * 100:.0f}%'></i></div>")
    return box(0, 0, TAG_W, TAG_H, inner, '', f'background:{HUD_GLASS};border:3px solid {EDGE};border-radius:24px', name='Tag')


PR_W, PR_H = 420, 110


def revive_prompt(frac=0.0, key='E', touch=False):
    """The ProximityPrompt (Style Custom) for Runners: key cap, REVIVE + the name, a fill bar for the hold."""
    cap = (T('HOLD', 26, 's', name='KeyText') if touch else T(key, 44, 'l', name='KeyText'))
    keyw = 104 if touch else 84
    inner = (f"<div class='abs' data-n='Key' style='left:14px;top:13px;width:{keyw}px;height:84px;background:{INK};"
             f"border:4px solid {GOLD};border-radius:20px;display:flex;align-items:center;justify-content:center'>{cap}</div>"
             f"<div class='abs' style='left:{keyw + 32}px;top:12px;right:16px;height:50px;display:flex;align-items:center'>"
             f"{T('REVIVE', 40, 'l', 'f-gold', name='ActionText')}</div>"
             f"<div class='abs' style='left:{keyw + 32}px;top:58px;right:16px;height:36px;display:flex;align-items:center'>"
             f"{T(NAME, 26, 's', name='ObjectText')}</div>"
             f"<div class='bar' data-n='Hold' style='left:14px;top:{PR_H - 4}px;width:{PR_W - 28}px;height:12px'>"
             f"<i class='g-gold' data-n='F' style='width:{frac * 100:.0f}%'></i></div>")
    return box(0, 0, PR_W, PR_H + 12, inner, '', f'background:{HUD_GLASS};border:3px solid {EDGE};border-radius:26px', name='Prompt')


# ---------------------------------------------------------------- the leaderboard (end of match)
LB_W, LB_H = 1180, 900
LB_X, LB_Y = (1920 - LB_W) // 2, 90
ROW_H, ROW_GAP = 70, 8
ROWS_SHOWN = 8

SAMPLE = [  # name, outcome, stats, points
    ('Liam67', 'ESCAPED', '5 safe · 3 jukes · 1 revive', 618),
    (NAME, 'HERO', '4 safe · Hero · 2 jukes', 544),
    ('mo201948', 'CATCHER', '4 catches · Epic snatch', 344),
    ('Takis_4', 'CAUGHT', '3 safe · 1 juke', 280),
    ('Mustang', 'CATCHER', '2 catches · 2 safe', 240),
    ('cjcoolman098', 'CAUGHT', '2 safe · 1 revive', 225),
    ('Aviatrus', 'CAUGHT', '2 safe', 200),
    ('BinaryGlork', 'CATCHER', '1 catch · 1 safe', 150),
]
CHIP = {'ESCAPED': ('#2f9e44', 'ESCAPED'), 'HERO': ('#c27a00', 'HERO'), 'CATCHER': ('#b3262d', 'CATCHER'),
        'CAUGHT': ('#5b6470', 'CAUGHT')}
RANK_COL = {1: GOLD, 2: SILVER, 3: BRONZE}


def chip(kind, name='Chip'):
    col, word = CHIP[kind]
    return (f"<div{W.dn(name)} style='display:flex;align-items:center;justify-content:center;height:40px;padding:0 16px;"
            f"background:{col};border-radius:20px;flex:none'>{T(word, 22, 'xs', name='ChipText')}</div>")


def lb_row(i, rank, name, outcome, stats, pts, you=False, rname=None, hid=False):
    y = i * (ROW_H + ROW_GAP)
    rc = RANK_COL.get(rank, 'rgba(255,255,255,.14)')
    rtext = T(str(rank), 30, 'l' if rank <= 3 else 's', name='RankText')
    disc = (f"<div class='abs' data-n='Rank' style='left:14px;top:9px;width:52px;height:52px;border-radius:26px;background:{rc};"
            f"display:flex;align-items:center;justify-content:center'>{rtext}</div>")
    head = (f"<div class='abs' data-n='Head' style='left:80px;top:7px;width:56px;height:56px;border-radius:14px;"
            f"background:#2a3140;border:2px solid {EDGE}'></div>")
    mid = (f"<div class='abs' style='left:152px;top:0;width:640px;height:{ROW_H}px;display:flex;flex-direction:column;justify-content:center'>"
           f"<div style='display:flex;align-items:center;gap:14px'>{T(name, 32, 'l', name='NameText')}{chip(outcome)}</div>"
           f"{T(stats, 22, 'xs', 'f-grey', name='StatsText')}</div>")
    right = (f"<div class='abs' style='right:22px;top:0;width:260px;height:{ROW_H}px;display:flex;align-items:center;justify-content:flex-end;gap:10px'>"
             f"{T(f'{pts:,}', 40, 'l', 'f-gold', name='PointsText')}{T('pts', 24, 's', 'f-grey', name='PtsText')}</div>")
    bg = ROW_YOU if you else ROW
    edge = f'border:3px solid {GOLD};' if you else 'border:3px solid transparent;'
    return box(0, y, LB_W - 60, ROW_H, disc + head + mid + right, '', f'background:{bg};{edge}border-radius:18px', name=rname, hid=hid)


def leaderboard(rows=SAMPLE, you_at=2, pinned=None, crossings=5, escaped='2 of 8 ESCAPED', you_xp=544, you_gold=58):
    title = (f"<div class='abs' style='left:0;right:0;top:22px;display:flex;justify-content:center;gap:24px'>"
             f"{T('MATCH', 64, 'xl', name='TitleA')}{T('POINTS', 64, 'xl', 'f-gold', name='TitleB')}</div>")
    subl = (f"<div class='abs' style='left:0;right:0;top:112px;display:flex;justify-content:center'>"
            f"{T(f'{crossings} crossings · {escaped}', 30, 's', 'f-grey', name='SubText')}</div>")
    body = ''
    for i, r in enumerate(rows[:ROWS_SHOWN]):
        body += lb_row(i, i + 1, *r, you=(i + 1 == you_at), rname='Row' if i == 0 else None)
    if pinned:
        rank, r = pinned
        body += (f"<div class='abs' style='left:0;width:{LB_W - 60}px;top:{ROWS_SHOWN * (ROW_H + ROW_GAP) - 2}px;height:2px;"
                 f"background:repeating-linear-gradient(90deg,rgba(255,255,255,.35) 0 10px,transparent 10px 20px)'></div>")
        body += lb_row(ROWS_SHOWN, rank, *r, you=True, rname='YouRow')
    list_h = (ROWS_SHOWN + 1) * (ROW_H + ROW_GAP)
    lst = box(30, 170, LB_W - 60, list_h, body, name='List')
    # your earnings: points -> XP 1:1, Gold from the pot split by points
    earn = (f"<div class='abs' data-n='Earn' style='left:30px;right:30px;bottom:24px;height:84px;background:rgba(255,255,255,.05);"
            f"border-radius:20px;box-shadow:inset 0 -6px 0 {LIP};display:flex;align-items:center;justify-content:center;gap:40px'>"
            f"{T('YOU EARNED', 30, 's', 'f-grey', name='EarnLabel')}"
            f"{T(f'+{you_xp} XP', 44, 'l', 'f-blue', name='XpText')}"
            f"{T(f'+{you_gold} Gold', 44, 'l', 'f-gold', name='GoldText')}</div>")
    inner = title + subl + lst + earn
    return box(LB_X, LB_Y, LB_W, LB_H, inner, '', f'background:{GLASS};border:3px solid {EDGE};border-radius:34px;'
               f'box-shadow:inset 0 -9px 0 {LIP}', name='Panel')


# ---------------------------------------------------------------- pages
def s_screen():
    """The exported Leaderboard screen: Dim + Board (hidden until the podium hands over)."""
    return W.world() + W.dim(.5) + grp('Board', leaderboard(), 'C')


def s_templates():
    out = W.world()
    out += f"<div class='abs' style='left:40px;top:40px;width:{POP_W}px;height:{POP_H}px'>{grp('PointsPop', pop(), 'TL')}</div>"
    out += f"<div class='abs' style='left:40px;top:160px;width:640px;height:200px'>{grp('JukeWord', juke_word(), 'TL')}</div>"
    out += f"<div class='abs' style='left:760px;top:40px;width:200px;height:70px'>{grp('HeadPop', head_pop(), 'TL')}</div>"
    out += f"<div class='abs' style='left:760px;top:160px;width:{TAG_W}px;height:{TAG_H}px'>{grp('DownedTag', downed_tag(), 'TL')}</div>"
    out += f"<div class='abs' style='left:760px;top:300px;width:{PR_W}px;height:{PR_H + 12}px'>{grp('RevivePrompt', revive_prompt(.45), 'TL')}</div>"
    return out


# ---------------------------------------------------------------- review sheet
def shot(w=1920, dim=False):
    f = 'filter:saturate(.55) brightness(.7);' if dim else ''
    return f"<img class='world' src='bg_match.jpg' style='left:0;top:0;width:{w}px;height:1080px;object-fit:cover;{f}'>"


def at(inner, x, y, scale=1.0, extra=''):
    return f"<div class='abs' style='left:{x}px;top:{y}px;transform:scale({scale});transform-origin:0 0;{extra}'>{inner}</div>"


def runner(cx, y=600, w=110, h=230, col='#3b4f7a'):
    """Stand-in for your Runner in the middle of the shot (the real one is under the camera)."""
    return (f"<div class='abs' style='left:{cx - w // 2}px;top:{y}px;width:{w}px;height:{h}px;border-radius:26px;background:{col};"
            f"border:3px solid rgba(0,0,0,.35)'></div>")


def downed_body(cx, y=760):
    return (f"<div class='abs' style='left:{cx - 120}px;top:{y}px;width:240px;height:70px;border-radius:30px;background:#3b4f7a;"
            f"border:3px solid rgba(0,0,0,.35);transform:rotate(-6deg)'></div>")


def pops_at(cx, y, kinds, scale=1.0):
    """Pops stack upward beside the Runner: newest at the bottom, older ones pushed up and fading."""
    out = ''
    n = len(kinds)
    for i, k in enumerate(kinds):
        a = 1 - (n - 1 - i) * .25
        out += at(pop(k), cx, y - (n - 1 - i) * (POP_H + 6) * scale, scale, f'opacity:{a}')
    return out


def juke_at(w, scale=1.0, x=None):
    cx = (x or w / 2)
    return (at(juke_word(), cx - 320 * scale, 330, scale)
            + at(head_pop(), cx - 100 * scale, 520 - 20 * scale, scale))


def touch(w):
    return (f"<div class='rbx' style='left:90px;top:640px;width:300px;height:300px'>thumbstick</div>"
            f"<div class='rbx' style='left:{w - 330}px;top:720px;width:200px;height:200px'>jump</div>")


PHONE_W = 2337   # an 844 x 390 phone fitted by height: 844 / (390 / 1080) design px wide
PHONE_BOOST = 1.25


def cell(cap, body, w=1920):
    return (f"<div style='position:relative;width:{w}px;height:1080px;overflow:hidden;border:2px solid #000;background:#000'>{body}"
            f"<div class='cap' style='left:12px;bottom:12px;font-size:30px'>{cap}</div></div>")


def board_at(w, scale=1.0, **kw):
    lb = leaderboard(**kw)
    # the panel carries its own LB_X/LB_Y: shift so it is centred on this canvas at this scale
    return (f"<div class='abs' style='left:{(w - LB_W * scale) / 2 - LB_X * scale}px;top:{(1080 - LB_H * scale) / 2 - LB_Y * scale}px;"
            f"transform:scale({scale});transform-origin:0 0;width:1920px;height:1080px'>{lb}</div>")


def s_states():
    C = 960
    you_low = (14, (NAME, 'CAUGHT', '1 safe · 1 juke', 110))
    all_caught = [(n, 'CATCHER', s, p) for n, _, s, p in SAMPLE]
    all_caught[1] = (NAME, 'CAUGHT', '3 safe · 2 jukes', 330)
    pc = [
        ('PC: Reached Safety (+100)', shot() + runner(C) + pops_at(C + 90, 640, ['safe'])),
        ('PC: Hero across alone (+200)', shot() + runner(C) + pops_at(C + 90, 640, ['hero'])),
        ('PC: JUKE! (big word, +10 over the head, +10 Juke!)', shot() + runner(C) + juke_at(1920) + pops_at(C + 90, 640, ['juke'])),
        ('PC: two jukes then a revive (stacking, older fade up)', shot() + runner(C) + pops_at(C + 90, 640, ['juke', 'juke', 'revive'])),
        ('PC: Catcher: catch + Epic snatch (two pops at once)', shot() + runner(C, col='#8c2a2f') + pops_at(C + 90, 640, ['catch', 'snatch_epic'])),
        ('PC: Legendary snatch (longest line)', shot() + runner(C, col='#8c2a2f') + pops_at(C + 90, 640, ['catch', 'snatch_legendary'])),
        ('PC: a Runner near a downed teammate: tag + prompt', shot() + runner(700) + downed_body(1150)
         + at(downed_tag(.72, 4), 1000, 600) + at(revive_prompt(0), 1240, 730)),
        ('PC: holding E: the bar fills over 1.5 s', shot() + runner(700) + downed_body(1150)
         + at(downed_tag(.55, 3), 1000, 600) + at(revive_prompt(.6), 1240, 730)),
        ('PC: a Catcher sees the tag only (no prompt)', shot() + runner(700, col='#8c2a2f') + downed_body(1150) + at(downed_tag(.3, 2), 1000, 600)),
        ('PC: end leaderboard, you 2nd (Hero)', shot(dim=True) + board_at(1920)),
        ('PC: end leaderboard, you 14th: pinned under the top 8', shot(dim=True) + board_at(1920, pinned=you_low, you_at=0, you_xp=110, you_gold=31)),
        ('PC: CATCHERS WIN (nobody escaped), longest name', shot(dim=True)
         + board_at(1920, rows=[(LONG, 'CATCHER', '6 catches · Legendary snatch', 760)] + all_caught[1:], escaped='nobody escaped',
                    you_xp=330, you_gold=44)),
    ]
    ph = [
        ('Phone 844x390: Reached Safety', shot(PHONE_W) + touch(PHONE_W) + runner(PHONE_W // 2) + pops_at(PHONE_W // 2 + 90, 620, ['safe'], PHONE_BOOST)),
        ('Phone: JUKE!', shot(PHONE_W) + touch(PHONE_W) + runner(PHONE_W // 2) + juke_at(PHONE_W, PHONE_BOOST)
         + pops_at(PHONE_W // 2 + 90, 640, ['juke'], PHONE_BOOST)),
        ('Phone: revive prompt (tap and hold)', shot(PHONE_W) + touch(PHONE_W) + downed_body(1300)
         + at(downed_tag(.6, 4), 1150, 560, PHONE_BOOST) + at(revive_prompt(.3, touch=True), 1450, 720, PHONE_BOOST)),
        ('Phone: end leaderboard', shot(PHONE_W, True) + board_at(PHONE_W, 1.18)),
    ]
    out = "<div class='abs' style='left:0;top:0;transform:scale(.5);transform-origin:0 0;display:flex;flex-wrap:wrap;gap:24px;width:3888px'>"
    for cap, body in pc:
        out += cell(cap, body)
    for cap, body in ph:
        out += cell(cap, body, PHONE_W)
    return out + '</div>'


SCREENS = [
    ('match_points_states.html', 'Match points: every state', 'Pops, JUKE!, revive tag and prompt, the end leaderboard; PC and phone over a real match capture', s_states, 4500, ''),
    ('match_points.html', 'Match points: leaderboard', 'The end-of-match ranking as exported (Dim + Board)', s_screen, 1080, ''),
    ('match_points_templates.html', 'Match points: templates', 'PointsPop, JukeWord, HeadPop, DownedTag, RevivePrompt (runtime clones these)', s_templates, 1080, ''),
]

if __name__ == '__main__':
    W.SCREENS = SCREENS
    for fname, title, desc, fn, h, extra in SCREENS:
        with open(os.path.join(HERE, fname), 'w', encoding='utf-8') as f:
            f.write(page(title, fn(), h, extra))
    with open(os.path.join(HERE, 'index.html'), 'w', encoding='utf-8') as f:
        f.write(W.index().replace('Hatch or Snatch UI', 'Match Points UI'))
    print('wrote', len(SCREENS), 'pages + index.html')
