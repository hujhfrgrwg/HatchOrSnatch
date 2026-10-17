"""HOS-EGG-002: add the export states + export pages to ui/build.py (run once)."""
P = r'C:\HatchOrSnatch\ui\build.py'


def edit(old, new, n=1):
    s = open(P, encoding='utf-8').read()
    assert s.count(old) == n, (old[:70], s.count(old))
    open(P, 'w', encoding='utf-8').write(s.replace(old, new))


edit('''    if ready:
        eg += I('sparkle', 360, 70, 70, name='Sparkle') + I('sparkle', 80, 330, 50, name='Sparkle2')''', '''    if ready or EXPORT_STATES:
        cls = 'ic' + (' hid' if not ready else '')
        eg += I('sparkle', 360, 70, 70, name='Sparkle', cls=cls) + I('sparkle', 80, 330, 50, name='Sparkle2', cls=cls)''')
edit('''        n = shards.get(r, 0)
        sc += slot(24 + i * 150, 22, 118, rs, sh, f'x{n}', word.title(), name=f'Shard_{r}', cls='locked' if n == 0 else '')''', '''        n = shards.get(r, 0)
        if EXPORT_STATES:   # both looks: On (has shards) / Off (x0, dimmed); runtime shows one
            sc += sub(f'Shard_{r}', slot(24 + i * 150, 22, 118, rs, sh, f'x{n}', word.title(), name='On', cls='' if n else 'hid')
                      + slot(24 + i * 150, 22, 118, rs, sh, 'x0', word.title(), name='Off', cls='locked' + ('' if not n else ' hid')))
        else:
            sc += slot(24 + i * 150, 22, 118, rs, sh, f'x{n}', word.title(), name=f'Shard_{r}', cls='locked' if n == 0 else '')''')
edit('''        if r == 'legendary' and not legendary_open:
            od += bar(250, yy + 6, 520, 30, 0, 'grey', f'OddsBar_{r}') + at(510, yy + 7, T('PETS COMING SOON', 18, 'xs', 'f-dim', name=f'OddsSoon_{r}'), w=520, align='center')
            od += at(880, yy + 4, T('0%', 26, 's', 'f-dim', name=f'OddsText_{r}'), w=90, align='right')
        else:''', '''        if EXPORT_STATES and r == 'legendary':   # both: the live bar, and the "coming soon" cover shown while folded
            od += bar(250, yy + 6, 520, 30, o[r], k, f'OddsBar_{r}') + at(880, yy + 4, T(pct(o[r]), 26, 's', f, name=f'OddsText_{r}'), w=90, align='right')
            od += sub('OddsSoon', bar(250, yy + 6, 520, 30, 0, 'grey', 'SoonBar') + at(510, yy + 7, T('PETS COMING SOON', 18, 'xs', 'f-dim', name='SoonText'), w=520, align='center'), hid=legendary_open)
        elif r == 'legendary' and not legendary_open:
            od += bar(250, yy + 6, 520, 30, 0, 'grey', f'OddsBar_{r}') + at(510, yy + 7, T('PETS COMING SOON', 18, 'xs', 'f-dim', name=f'OddsSoon_{r}'), w=520, align='center')
            od += at(880, yy + 4, T('0%', 26, 's', 'f-dim', name=f'OddsText_{r}'), w=90, align='right')
        else:''')
edit('''        sel = fam == focus
        fc += sub(f'Focus_{fam}', slot(cx, 18, 100, 'gold' if sel else ('common' if open_ else 'locked'), ic, label=fam if fam != 'Invisibility' else 'Invis',
                                       cls='fill' if open_ else 'fill soon', art_pad=.2, label_size=15,
                                       inner_extra='' if open_ else I('lock', 66, 6, 28)), btn=open_)''', '''        sel = fam == focus
        lab = fam if fam != 'Invisibility' else 'Invis'
        if EXPORT_STATES:   # three looks per chip: Sel (gold) / Open / Locked; runtime shows one (locks from the live pet data)
            st = 'Sel' if sel else ('Open' if open_ else 'Locked')
            looks = slot(cx, 18, 100, 'gold', ic, label=lab, cls='fill' + ('' if st == 'Sel' else ' hid'), art_pad=.2, label_size=15, name='Sel')
            looks += slot(cx, 18, 100, 'common', ic, label=lab, cls='fill' + ('' if st == 'Open' else ' hid'), art_pad=.2, label_size=15, name='Open')
            looks += slot(cx, 18, 100, 'locked', ic, label=lab, cls='fill soon' + ('' if st == 'Locked' else ' hid'), art_pad=.2, label_size=15, name='Locked',
                          inner_extra=I('lock', 66, 6, 28))
            fc += sub(f'Focus_{fam}', looks, btn=True)
        else:
            fc += sub(f'Focus_{fam}', slot(cx, 18, 100, 'gold' if sel else ('common' if open_ else 'locked'), ic, label=lab,
                                           cls='fill' if open_ else 'fill soon', art_pad=.2, label_size=15,
                                           inner_extra='' if open_ else I('lock', 66, 6, 28)), btn=open_)''')
edit('''    hb += btn(1060, 6, 360, 80, 'lime' if state == 'ready' else 'grey', row(icn('egg_golden' if ready else 'egg_starter', 50), bl(lab, 36)), name='BtnHatch')''', '''    if EXPORT_STATES:   # both plates; runtime shows BtnHatch (ready) or BtnHatchOff (filling / hatching) and sets the label
        hb += btn(1060, 6, 360, 80, 'lime', row(icn('egg_golden', 50, name='BtnIcon'), bl('HATCH!', 36)), name='BtnHatch', hid=not ready)
        hb += btn(1060, 6, 360, 80, 'grey', row(icn('egg_starter', 50, name='BtnIcon'), bl(lab, 36)), name='BtnHatchOff', hid=ready)
    else:
        hb += btn(1060, 6, 360, 80, 'lime' if state == 'ready' else 'grey', row(icn('egg_golden' if ready else 'egg_starter', 50), bl(lab, 36)), name='BtnHatch')''')
edit("""    out += cap(40, 16, 'HUD egg card: rarity x charge (3 segments, as the spec). The diamonds are gone: the name + colour already say the rarity.')""",
     """    out += cap(40, 16, 'HUD egg card: rarity x charge (4 segments: option B, approved 17 Oct). The diamonds are gone: the name + colour say the rarity.')""")

EXPORT = '''# ----- export pages (UI_EXPORT=1: every runtime state on the page, hidden ones too). ui_egg/rbx.json. Not on the index;
# written by docs/HOS-EGG-002/tools/build_egg_export.py so the other pages are untouched.
def egg_x_hud():
    """Screen EggHUD (hud): the egg card in every look (Runner_<rarity>, Catcher, CatcherEmpty; one shown at a time)
    + the bonus-rolls tag, and the one-time tip (top centre). EggUIController hides EOSUI MatchHUD.Egg while it shows."""
    card = ''
    for r in ['common', 'rare', 'epic', 'legendary']:
        card += sub(f'Runner_{r}', egg_card(r, 0), hid=r != 'rare')
    card += sub('Catcher', egg_card(role='catcher', snatched='rare', cap='epic'), hid=True)
    card += sub('CatcherEmpty', egg_card(role='catcher', snatched=None, cap='epic'), hid=True)
    card += sub('BonusTag', f"<div class='ctag k-lime' style='left:12px;top:838px;height:34px'>{T('RUNNERS WIN: BONUS ROLLS x2', 17, 'xs', name='BonusText')}</div>", hid=True)
    out = grp('EggCard', card, 'BL')
    out += grp('EggTip', sub('Tip', egg_tutorial(560, 196), hid=True), 'T')
    return out


def egg_x_incubator():
    """Screen EggIncubator (panel): the incubator egg; replaces opening EOSUI's Incubator while EggConfig.ENABLED."""
    return egg_incubator(18, {'rare': 9, 'epic': 2, 'legendary': 0}, 'Any', 'filling')


def egg_x_first_pet():
    """Screen EggFirstPet (panel): the free first pet card, over the incubator."""
    h = egg_first_pet()
    i = h.index("<div class='abs fill' style='z-index:5;isolation:isolate'>")
    return h[i:]


def egg_x_templates():
    """Runtime templates (ReplicatedStorage.EggUITemplates): +CHARGE pop, the three upgrade banners, READY TO HATCH badge,
    the results shard row with its small incubator egg."""
    out = "<div class='abs fill' style='background:linear-gradient(#3a1a66,#1e0a3e)'></div>"
    out += grp('ChargePop', egg_charge_pop(40, 40), 'TL')
    for i, r in enumerate(['rare', 'epic', 'legendary']):
        out += grp(f'EggBanner_{r}', egg_banner(r, 40, 140 + i * 160), 'TL')
    out += grp('ReadyBadge', f"<div class='ctag k-gold' data-n='Badge' style='left:1000px;top:40px;height:34px'>{T('READY TO HATCH', 17, 'xs', name='BadgeText')}</div>", 'TL')
    sr = at(1000, 140, row(icn('piece_epic', 36, name='ShardIcon'), T('+1 EPIC SHARD', 24, 's', 'f-epic', name='ShardText'), gap=6))
    sr += egg_ring(1300, 158, 22, 21 / 30, '#7cf05a', 7, 'MiniRing') + I('egg_starter', 1286, 140, 28, 34, name='MiniEgg')
    sr += at(1300, 184, T('21 / 30 FILL', 13, 'xs', name='MiniFill'), w=120, align='center')
    out += grp('ShardRow', sr, 'TL')
    return out


EGG_EXPORT = [('egg_x_hud.html', egg_x_hud, 1080), ('egg_x_incubator.html', egg_x_incubator, 1080),
              ('egg_x_first_pet.html', egg_x_first_pet, 1080), ('egg_x_templates.html', egg_x_templates, 1080)]


'''
s = open(P, encoding='utf-8').read()
i = s.index("SCREENS += [\n    ('egg_card_states.html'")
s = s[:i] + EXPORT + s[i:]
open(P, 'w', encoding='utf-8').write(s)
print('patched')
