#!/usr/bin/env python3
"""HOS-PTS-001: the Studio export pages for PointsUI (roblox-ui-maker). The approved designs live in
UI/build.py, section "HOS-PTS-001" (pts_* functions); this only lays the exported pieces out once each, with
every runtime state present (hidden ones too), so export.mjs sees one clean tree. Run from anywhere:

    python ui_points/pages.py        # writes UI/points_x_screen.html + UI/points_x_templates.html

Exported (rbx.json): screen "Points" (Dim, Leaderboard, PodiumBanner) and the templates
PointsPop, JukeWord, ReviveRing, PodiumCard, PodiumCardBig, FavStar, FavTag.
"""
import os
import sys

UI = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'UI')
sys.path.insert(0, UI)
os.environ.setdefault('UI_SKIN', 'sport')
import build as B  # noqa: E402


def screen():
    """Dim + the results Leaderboard (one Row template + the pinned YouRow) + the podium banner, all hidden."""
    rows = B.PTS_SAMPLE[:1]
    board = B.pts_leaderboard(rows=rows, you_at=0, thief_at=1, rewards=False,
                              pinned=(14, (B.PTS_NAME, 'CAUGHT', '1 safe  ·  1 juke', 110)))
    return B.world('bg_lobby_blur.jpg', False) + B.dim() + board + B.pts_podium_banner('escaped', 7, 20) + results_v2()


def results_v2():
    """Results v2 (approved 17 Oct, build.py rv_*): the end-of-match screen. Every runtime state is on the page (all three
    stat rows per card, JOINT, GEMS). ResultsSkinRed = the same panel in the Catchers red with no body: the runtime copies
    its art (Glow, Panel, Banner Edge / Fill) onto ResultsV2 for a Catchers win."""
    B.RV_EXPORT[0] = True
    try:
        out = B.rv_panel(tab='points')
    finally:
        B.RV_EXPORT[0] = False
    x, y = (1920 - B.RV_W) // 2, (1080 - B.RV_H) // 2 + 30
    out += B.panel('ResultsSkinRed', 'coral', 'CATCHERS WIN', None, '', x, y, B.RV_W, B.RV_H)
    return out


def ring_export():
    """The approved revive ring (build.pts_revive_ring), laid out as export-friendly siblings: the exporter turns
    a conic-gradient into a native Cooldown wedge and skips its children, so the track, the wedge and the inner
    disc are separate frames here. Same sizes and colours. Runtime: Cooldown (Frac + wedge colour), Icon,
    Key.KeyText (E / HOLD) or Key.KeyIcon (gamepad button image)."""
    r = B.PTS_RING
    out = (f"<div class='abs' data-n='Track' style='left:0;top:0;width:{r}px;height:{r}px;border-radius:50%;"
           f"background:rgba(255,255,255,.14);box-shadow:0 0 0 4px #050506'></div>")
    out += (f"<div class='abs' data-n='Cooldown' style='left:0;top:0;width:{r}px;height:{r}px;border-radius:50%;"
            f"background:conic-gradient(#ff4d55 180deg,transparent 0)'></div>")
    out += (f"<div class='abs' data-n='Disc' style='left:14px;top:14px;width:{r - 28}px;height:{r - 28}px;border-radius:50%;"
            f"background:rgb(17,16,22);box-shadow:0 0 0 3px #050506'></div>")
    out += B.I('plus', 30, 28, r - 60, name='Icon')
    kw = 72
    cap = (B.T('E', 38, 's', style='font-family:Montserrat;font-weight:900', name='KeyText')
           + B.I('target', 8, 6, 56, name='KeyIcon', cls='ic hid'))
    out += f"<div class='keycap' data-n='Key' style='left:{(r - kw) // 2}px;top:{r - 18}px;width:{kw}px;height:68px'>{cap}</div>"
    return B.box(0, 0, r, r + 56, out, name='ReviveRing')


def templates():
    out = "<div class='abs fill' style='background:linear-gradient(#3a1a66,#1e0a3e)'></div>"
    P = B.pts_place
    out += B.grp('PointsPop', P(B.pts_pop('safe'), 40, 40), 'TL')
    out += B.grp('JukeWord', P(B.pts_juke_word(), 40, 140), 'TL')
    out += B.grp('ReviveRing', P(ring_export(), 460, 120), 'TL')
    out += B.grp('PodiumCard', P(B.pts_podium_card(1, 'Liam67', 618), 40, 330), 'TL')
    out += B.grp('PodiumCardBig', P(B.pts_podium_card(2, 'mo201948', 344, big=True), 560, 330), 'TL')
    # favourite star + PODIUM EMOTE tag: cloned into each My Emotes card at runtime (EOSUI is not re-exported)
    star_on = B.btn(0, 0, 48, 48, 'gold', B.I('star', 4, 4, 40, name='Icon'), cls='sm', name='On')
    star_off = B.btn(0, 0, 48, 48, 'grey', B.I('star', 4, 4, 40, name='Icon', extra='filter:brightness(.45)'), cls='sm hid', name='Off')
    out += B.grp('FavStar', P(B.box(0, 0, 48, 48, B.sub('BtnFav', star_on + star_off, btn=True), name='Star'), 1400, 60), 'TL')
    tag = B.box(0, 0, 160, 30, f"<span class='ctag k-gold' style='position:relative;display:inline-flex;height:30px'>{B.T('PODIUM EMOTE', 16, 'xs', name='TagText')}</span>", name='Tag')
    out += B.grp('FavTag', P(tag, 1400, 160), 'TL')
    return out


if __name__ == '__main__':
    for name, fn in (('points_x_screen', screen), ('points_x_templates', templates)):
        with open(os.path.join(UI, name + '.html'), 'w', encoding='utf-8') as f:
            f.write(B.page('HOS-PTS-001 export: ' + name, fn(), 1080))
    print('wrote points_x_screen.html, points_x_templates.html')
