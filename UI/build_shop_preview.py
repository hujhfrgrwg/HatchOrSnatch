#!/usr/bin/env python3
"""HOS-SHOP-PREVIEW-001 mockups (roblox-ui-maker, HTML first): hovering a Featured pet card tweens its art box into a
live pet preview on a themed backdrop. Kept out of build.py (the Halloween thread edits it); reuses its components.

    cd ui && python build_shop_preview.py      # -> shop_preview_states.html, shop_preview_hover.html, shop_preview_phone.html

Hunter (17 Oct): "in our shop, if you hover over the item, such as the bone dragon pet, it should tween in that frame to a
viewport preview of the pet doing animations or something on a backdrop".
Pet frames: Bone Dragon L1 clips (Idle / Walk = its fly / Breath / Ability) rendered from Dragon_Pet.blend with the
pet-kit scene, transparent (shop_preview/dragon_*.png). In game they are the real rig in a ViewportFrame.
"""
import os
import build as B
from build import T, I, icn, at, box, tag, btn, bl, row, sub, grp, cap, page, EXPORT_STATES

HERE = os.path.dirname(os.path.abspath(__file__))
W, H = 494, 620
REST = (18, 66, 458, 286)          # the card's ArtBox
OPEN = (10, 10, 474, 478)          # the preview stage: 10 px UIPadding left / top / right, stops 6 px above the buy button
FRAMES = {'idle': 'shop_preview/dragon_l1_idle_10.png', 'fly': 'shop_preview/dragon_l1_walk_8.png',
          'cast': 'shop_preview/dragon_l1_breath_10.png', 'cast2': 'shop_preview/dragon_l1_ability_8.png'}
# backdrop per card colour (Halloween night; the card's own accent tints sky, moon glow and the floor light)
THEME = {
    'violet': dict(sky0='#3a1a7a', sky1='#0c0520', moon='#e9ffe9', glow='#7dffb6', hill='#1b0c3d', near='#0b0418', floor='#5dffb0'),
    'orange': dict(sky0='#7a2a08', sky1='#160602', moon='#ffe2a8', glow='#ffae3a', hill='#3a1204', near='#140502', floor='#ffb040'),
    'sky':    dict(sky0='#16408a', sky1='#040b1e', moon='#e6f6ff', glow='#7fd8ff', hill='#0c1f4a', near='#030817', floor='#7fd8ff'),
}
CLIPS = {'hwn_dragon': ('IDLE', 'FLY', 'BREATH'), 'hwn_wraith': ('IDLE', 'FLOAT', 'VANISH'), 'hwn_mummy': ('IDLE', 'WALK', 'SHIELD'),
         'hwn_cat': ('IDLE', 'WALK', 'DECOY')}


def backdrop(acc, w, h):
    """One flat image in Roblox (Backdrop ImageLabel behind the transparent ViewportFrame): sky, moon, graves, floor light."""
    t = THEME.get(acc, THEME['violet'])
    stars = ''.join(f"<circle cx='{x}' cy='{y}' r='{r}' fill='#fff' opacity='{o}'/>" for x, y, r, o in
                    ((40, 40, 2, .7), (96, 88, 1.5, .5), (150, 30, 2, .6), (230, 64, 1.5, .5), (300, 26, 2, .7), (60, 150, 1.5, .4), (420, 170, 1.5, .4)))
    return (f"<svg class='abs' viewBox='0 0 474 474' preserveAspectRatio='xMidYMid slice' style='left:0;top:0;width:{w}px;height:{h}px'>"
            f"<defs><linearGradient id='sk{acc}' x1='0' y1='0' x2='0' y2='1'><stop offset='0' stop-color='{t['sky0']}'/><stop offset='.75' stop-color='{t['sky1']}'/></linearGradient>"
            f"<radialGradient id='mg{acc}'><stop offset='0' stop-color='{t['glow']}' stop-opacity='.55'/><stop offset='1' stop-color='{t['glow']}' stop-opacity='0'/></radialGradient>"
            f"<radialGradient id='fl{acc}'><stop offset='0' stop-color='{t['floor']}' stop-opacity='.55'/><stop offset='.6' stop-color='{t['floor']}' stop-opacity='.12'/><stop offset='1' stop-color='{t['floor']}' stop-opacity='0'/></radialGradient>"
            f"<linearGradient id='sh{acc}' x1='0' y1='0' x2='0' y2='1'><stop offset='0' stop-color='#000' stop-opacity='0'/><stop offset='1' stop-color='#000' stop-opacity='.82'/></linearGradient></defs>"
            f"<rect width='474' height='474' fill='url(#sk{acc})'/>{stars}"
            f"<circle cx='378' cy='92' r='96' fill='url(#mg{acc})'/><circle cx='378' cy='92' r='44' fill='{t['moon']}'/>"
            f"<circle cx='362' cy='80' r='8' fill='#000' opacity='.08'/><circle cx='390' cy='108' r='6' fill='#000' opacity='.08'/>"
            f"<path d='M0 300 Q60 250 130 278 T260 262 T380 270 T474 250 V474 H0Z' fill='{t['hill']}'/>"
            # dead tree, left
            f"<path d='M58 330 L64 240 M64 262 L36 226 M63 250 L92 214 M48 238 L40 210 M80 226 L104 220' stroke='{t['near']}' stroke-width='8' stroke-linecap='round' fill='none'/>"
            # graves and a fence, right
            f"<path d='M372 340 v-38 a16 16 0 0 1 32 0 v38Z M414 340 v-26 a12 12 0 0 1 24 0 v26Z M330 340 v-22 h26 v22Z' fill='{t['near']}'/>"
            f"<path d='M0 338 Q237 316 474 338 V474 H0Z' fill='{t['near']}'/>"
            f"<ellipse cx='237' cy='326' rx='300' ry='26' fill='#fff' opacity='.06'/>"
            f"<ellipse cx='237' cy='336' rx='170' ry='40' fill='url(#fl{acc})'/>"
            f"<ellipse cx='237' cy='338' rx='86' ry='14' fill='#000' opacity='.45'/>"
            f"<rect y='300' width='474' height='174' fill='url(#sh{acc})'/></svg>")


def lerp(a, b, k):
    return tuple(round(x + (y - x) * k) for x, y in zip(a, b))


def fx_layer(items):
    """The cast effect, drawn as UI over / under the ViewportFrame with the pet's own effect textures (tinted like
    ImageColor3). item = (texture, centre x, centre y, w, h, transparency-as-opacity, rotation) in stage px."""
    out = ''
    for src, cx, cy, w, h, op, rot in items:
        out += (f"<img class='abs' src='shop_preview/fx_{src}.png' style='left:{cx - w // 2}px;top:{cy - h // 2}px;width:{w}px;height:{h}px;"
                f"opacity:{op};transform:rotate({rot}deg)'>")
    return out


def preview_card(x, y, it, view='rest', frame='idle', clip=0, phone=False, ends='ENDS IN 7D 0H', new=False, pic_override=None,
                 fx=(), fx_under=(), pet_alpha=1.0, chip_note=None):
    """hwn_card with a preview stage. view: rest | mid | open. The text never moves: title, family and buy button keep
    their spots; the stage grows from the ArtBox rect to OPEN behind them, the tagline swaps for the clip chips."""
    iid, nm, rar, rc, fam_ic, fam, line, wal, price, rbx, pic, acc = it
    k = {'rest': 0, 'mid': .62, 'open': 1}[view]          # mid = 0.12 s into a 0.25 s Quad Out tween (eased .62)
    sx, sy, sw, sh = lerp(REST, OPEN, k)
    glow = f'box-shadow:0 0 0 2px #050506,0 0 {int(30 * k)}px {int(6 * k)}px var(--r2);' if k else ''
    inner = ''
    # the static art box and portrait (fade + zoom out as the stage opens)
    inner += box(*REST, '', 'cw', f'border-radius:12px;opacity:{1 - k:.2f};background:radial-gradient(rgba(255,170,60,.22),rgba(0,0,0,.35))', name='ArtBox')
    ps = 280 * (1 + .12 * k)
    inner += I(pic, int((W - ps) / 2), int(70 - 10 * k), int(ps), name='Icon', extra=f'opacity:{1 - k:.2f}')
    # the stage: backdrop image + ViewportFrame (here: the rendered clip frame), clipped to the stage rect
    if k:
        fr = pic_override or FRAMES[frame]
        fs = 372
        stage = backdrop(acc, sw, sh)
        stage += fx_layer(fx_under)
        stage += (f"<img class='abs' data-n='Viewport' src='{fr}' style='left:{(sw - fs) // 2}px;top:{int(sh * .40 - fs / 2)}px;"
                  f"width:{fs}px;height:{fs}px;opacity:{min(1, k * 1.3) * pet_alpha:.2f}'>")
        stage += fx_layer(fx)
        inner += box(sx, sy, sw, sh, stage, 'cw', f'border-radius:6px;overflow:hidden;opacity:{min(1, k * 1.25):.2f};background:#000', name='Stage')
    # tags (always on top)
    inner += tag(18, 18, rar, rc, 17, 34, name='RarityTag')
    inner += tag(W - 214, 18, ends, 'pink', 17, 34, name='EndsTag')
    if new:
        inner += tag(18, 58, 'NEW', 'lime', 17, 34, name='NewTag')
    # preview hint (rest only; on phone it is the tap target hint)
    if k < 1:
        hint = row(icn('spectate', 26), T('TAP TO PREVIEW' if phone else 'PREVIEW', 17, 'xs'), gap=6)
        inner += (f"<div class='ctag k-violet' data-n='PreviewHint' style='left:{REST[0] + REST[2] - (196 if phone else 132)}px;"
                  f"top:{REST[1] + REST[3] - 44}px;height:34px;opacity:{1 - k:.2f}'>{hint}</div>")
    inner += at(W // 2, 364, T(nm.upper(), 40, 'xl', name='Title'), w=W, align='center')
    inner += at(W // 2, 418, row(icn(fam_ic, 34), T(fam, 22, 's', 'f-gold', name='Family'), gap=8), w=W, align='center')
    inner += at(W // 2, 458, T(line, 18, 'xs', 'f-dim', name='Tagline'), w=W - 30, align='center', style=f'opacity:{max(0, 1 - 2 * k):.2f}')
    if k:
        chips = ''
        names = CLIPS.get(iid, ('IDLE', 'MOVE', 'ABILITY'))
        for i, c in enumerate(names):
            on = i == clip
            chips += (f"<div class='ctag' data-n='Clip{i + 1}' style='position:relative;height:26px;"
                      + ("background:var(--r2);border-color:#fff'" if on else "opacity:.7'") + f">{T(c, 15, 'xs')}</div>")
        inner += (f"<div data-n='Clips' style='position:absolute;left:0;top:456px;width:{W}px;display:flex;justify-content:center;gap:10px;"
                  f"opacity:{max(0, 2 * k - 1):.2f}'>{chips}</div>")
    bx, by, bw, bh = 22, 494, W - 44, 76
    if wal == 'robux':
        inner += btn(bx, by, bw, bh, 'purple', row(icn('robux', 46), bl(f'{rbx:,}', 34, name='RobuxPrice')), name='BtnRobux')
    else:
        inner += btn(bx, by, bw, bh, 'lime', row(icn('gem', 46), bl(f'{price:,}', 34, name='Price')), name='BtnPrice')
    inner += at(W // 2, 584, T('Yours to keep after the event', 16, 'xs', 'f-dim', name='Have'), w=W - 30, align='center')
    return box(x, y, W, H, inner, f'cs r-{acc}', f'border-radius:18px;{glow}', name='Hwn_' + iid.split('_')[1].capitalize())


DRAGON, JACK, MUMMY = B.HWN_DRAGON, B.HWN_PETS[0], B.HWN_PETS[2]


def s_states():
    bg = "<div class='abs fill' style='background:#16161a'></div>"
    xs = (70, 713, 1356)
    out = bg
    labels = [('A  At rest', 'Same card as now. A small PREVIEW chip says it can be previewed.'),
              ('B  Mid-tween (0.12 s of 0.25 s, Quad Out)', 'The art box grows into the stage, the portrait fades.'),
              ('C  Hovered: IDLE', 'Pet idles on the backdrop. Name, ability, price stay put.')]
    cards = [preview_card(xs[0], 110, DRAGON, 'rest', new=True), preview_card(xs[1], 110, DRAGON, 'mid', new=True),
             preview_card(xs[2], 110, DRAGON, 'open', 'idle', 0, new=True)]
    labels += [('C  Hovered: FLY (move loop)', 'Then its move clip, gliding across the floor light.'),
               ('C  Hovered: BREATH (cast)', 'Then its cast clip with its own ability effect (next page).'),
               ("Same stage, Jack-o'-Lantern theme", 'Backdrop takes the card colour (orange / violet / blue).')]
    cards += [preview_card(xs[0], 880, DRAGON, 'open', 'fly', 1, new=True), preview_card(xs[1], 880, DRAGON, 'open', 'cast', 2, new=True),
              preview_card(xs[2], 880, JACK, 'open', clip=0, pic_override='set/icons/pet_jack_o_lantern_t1.png')]
    for i, ((a, b_), c) in enumerate(zip(labels, cards)):
        x, y = xs[i % 3], (110 if i < 3 else 880)
        out += cap(x, y - 84, a) + f"<div class='cap' style='left:{x}px;top:{y - 50}px;font-size:18px;opacity:.75'>{b_}</div>" + c
    return out


def shop_with(card_html):
    s = B.s_shop('featured', None, 0)
    old = B.hwn_card(26, 102, DRAGON, 'ok', 'ENDS IN 7D 0H', new=True)
    assert old in s
    return s.replace(old, card_html)


def s_hover():
    return shop_with(preview_card(26, 102, DRAGON, 'open', 'idle', 0, new=True))


def s_phone():
    """Landscape phone (19.5:9). First tap on the art flips it to the preview; tap again (or another card) flips back.
    The buy button is never covered and always buys on the first tap."""
    pw, ph = 1720, 794
    px, py = (1920 - pw) // 2, 70
    k = ph / 1080
    shop = shop_with(preview_card(26, 102, DRAGON, 'open', 'fly', 1, phone=True, new=True))
    shop = shop.replace(B.hwn_card(26 + 1034, 102, MUMMY, 'ok', 'ENDS IN 7D 0H'),
                        preview_card(26 + 1034, 102, MUMMY, 'rest', phone=True))
    shop = shop.replace(B.hwn_card(26 + 517, 102, JACK, 'ok', 'ENDS IN 7D 0H'),
                        preview_card(26 + 517, 102, JACK, 'rest', phone=True))
    inner_w = int(pw / k)
    pre = B.world('bg_lobby_blur.jpg', False) + B.dim()
    assert shop.startswith(pre)
    shop = shop[len(pre):]   # one backdrop + dim across the whole (wider) phone screen instead
    out = "<div class='abs fill' style='background:#101014'></div>"
    out += (f"<div class='abs' style='left:{px - 26}px;top:{py - 26}px;width:{pw + 52}px;height:{ph + 52}px;border-radius:70px;background:#050506;"
            f"box-shadow:0 0 0 4px #2a2a30'></div>")
    out += (f"<div class='abs' style='left:{px}px;top:{py}px;width:{pw}px;height:{ph}px;border-radius:48px;overflow:hidden'>"
            f"<div class='abs' style='left:0;top:0;width:{inner_w}px;height:1080px;transform:scale({k:.4f});transform-origin:0 0'>"
            f"<img class='world' src='bg_lobby_blur.jpg' style='position:absolute;left:0;top:0;width:{inner_w}px;height:1080px;object-fit:cover'>"
            f"<div class='abs' style='left:0;top:0;width:{inner_w}px;height:1080px;background:rgba(26,6,48,.42)'></div>"
            f"<div class='abs' style='left:{(inner_w - 1920) // 2}px;top:0;width:1920px;height:1080px'>{shop}</div></div></div>")
    # tap marker on the Dragon's stage: the shop panel sits at x0 170, y0 118 (+ body 112) inside the 1920 scene
    sx = px + ((inner_w - 1920) // 2 + 170 + 26 + 330) * k
    sy = py + (118 + 112 + 102 + 250) * k
    out += (f"<div class='abs' style='left:{sx - 46:.0f}px;top:{sy - 46:.0f}px;width:92px;height:92px;border-radius:50%;"
            f"border:6px solid #fff;box-shadow:0 0 0 4px #050506,0 0 24px #fff'></div>")
    out += cap(70, 900, '1st tap on the art: the card flips to the preview (the tapped card only; tap again or tap another card to flip back).')
    out += cap(70, 944, 'Press-and-hold works too. The buy button is never covered: one tap buys, preview or not.')
    out += cap(70, 988, 'Jack-o\'-Lantern and Mummy at rest show TAP TO PREVIEW. Card size, padding and button spots never change.')
    return out


def s_cast():
    """Cast beat with the pet's own ability effect (HOS-SHOP-PREVIEW-001 round 2, Hunter 16:43: "shouldnt we try to find a
    way to showcase the ability vfx and effect"). Times are from the cast clip start; FLASH_AT = the pet's own."""
    bg = "<div class='abs fill' style='background:#16161a'></div>"
    xs = (70, 713, 1356)
    d_cast = 'shop_preview/dragon_l1_breath_10.png'
    jack = 'set/icons/pet_jack_o_lantern_t1.png'
    rows = [
        ('BONE DRAGON  ·  BREATH (Storm Ball)', [
            ('0.20 s  charge', 'Soul fire gathers at the jaw.', dict(frame='cast', fx=[('dragon_fire4', 128, 262, 120, 120, .95, 0)],
                                                                      fx_under=[('dragon_glow', 128, 262, 220, 220, .5, 0)])),
            ('0.45 s  release (FLASH_AT)', 'Skull flash, the soul-fire ball spits out, shard ring on the floor.',
             dict(frame='cast', fx=[('dragon_fire7', 92, 270, 170, 170, 1, 0), ('dragon_shard', 300, 250, 46, 90, .9, 40),
                                    ('dragon_shard', 360, 300, 40, 80, .85, 75), ('dragon_shard', 70, 196, 40, 80, .8, -35)],
                  fx_under=[('dragon_glow', 237, 180, 330, 330, .45, 0), ('dragon_skull', 237, 180, 280, 280, .55, 0), ('dragon_glow', 110, 260, 280, 280, .55, 0),
                            ('dragon_ring', 237, 316, 320, 84, .9, 0)])),
            ('0.80 s  fade', 'Fire burns out, the ring fades, then back to IDLE.',
             dict(frame='cast2', fx=[('dragon_fire11', 96, 280, 190, 190, .55, 0), ('dragon_shard', 410, 360, 34, 66, .5, 100)],
                  fx_under=[('dragon_ring', 237, 316, 380, 96, .35, 0)])),
        ], DRAGON, None),
        ("JACK-O'-LANTERN  ·  VANISH (Invisibility)", [
            ('0.12 s  wind-up', 'Ember swirl winds round the pumpkin.', dict(fx=[('wraith_swirl3', 237, 200, 330, 330, .95, 0)], pic_override=jack)),
            ('0.32 s  grin flash', 'The carved grin flashes in the smoke.',
             dict(fx=[('wraith_swirl8', 237, 200, 380, 380, .9, 30), ('wraith_grin', 237, 196, 260, 260, .95, 0)],
                  fx_under=[('wraith_grin_glow', 237, 196, 340, 340, .7, 0)], pic_override=jack)),
            ('0.57 s  gone', 'Fades into smoke and cinders, then back in.',
             dict(fx=[('wraith_swirl13', 237, 210, 400, 400, .75, 60), ('wraith_cinder', 150, 140, 30, 30, .9, 0),
                      ('wraith_cinder', 330, 120, 24, 24, .8, 0), ('wraith_cinder', 300, 250, 34, 34, .9, 0), ('wraith_cinder', 170, 280, 22, 22, .7, 0)],
                  pet_alpha=.18, pic_override=jack)),
        ], JACK, None),
    ]
    out = bg
    for r, (title, beats, it, _) in enumerate(rows):
        y = 140 + r * 800
        out += cap(70, y - 124, title)
        for i, (a, b_, kw) in enumerate(beats):
            x = xs[i]
            out += cap(x, y - 84, a) + f"<div class='cap' style='left:{x}px;top:{y - 50}px;font-size:18px;opacity:.75'>{b_}</div>"
            out += preview_card(x, y, it, 'open', clip=2, new=(it is DRAGON), **kw)
    return out


PAGES = [('shop_preview_cast.html', 'Shop preview: cast effects', s_cast, 1580),
('shop_preview_states.html', 'Shop preview: states', s_states, 1520),
         ('shop_preview_hover.html', 'Shop preview: hovered in the shop', s_hover, 1080),
         ('shop_preview_phone.html', 'Shop preview: phone', s_phone, 1060)]

if __name__ == '__main__':
    for fname, title, fn, h in PAGES:
        with open(os.path.join(HERE, fname), 'w', encoding='utf-8') as f:
            f.write(page(title, fn(), h))
    print('wrote', [p[0] for p in PAGES])
