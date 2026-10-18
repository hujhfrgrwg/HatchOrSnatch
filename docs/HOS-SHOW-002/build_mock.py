#!/usr/bin/env python3
"""HOS-SHOW-002 mockup: overhead signs for the lobby showcase podiums (sword, Halloween pets, emote hologram),
after Matthew's reference clip (reference_frame.png): a coloured tag pill, a dark rounded plate with a coloured rim,
a big title and a two-part subtitle, an optional ENDS IN pill, light rays behind, and a "price . VIEW" pill at the feet.
Built so every piece maps to plain Roblox UI (Frame + UICorner + UIStroke + UIGradient + TextLabel; the rays are the
game's own Burst image, the icons the game's own gem / Robux icons). The icons here are stand-ins.
Run: python3 build_mock.py  -> mock_sheet.html, mock_<podium>.html (render with render_mock.mjs)
Font: Fredoka One (SIL Open Font Licence), the game's UI face.
"""
import html

GEM = '<span class="ic gem"></span>'
ROBUX = '<span class="ic rbx"></span>'

CSS = """
@font-face { font-family: Fredoka; src: url(FredokaOne.woff2); }
* { box-sizing: border-box; margin: 0; padding: 0; }
body { background: #2a2140; font-family: Fredoka, sans-serif; color: #fff; }
.ov { position: absolute; width: 440px; display: flex; flex-direction: column; align-items: center; }
.rays { position: absolute; left: 50%; top: 58px; width: 330px; height: 330px; transform: translate(-50%, -50%);
  background: repeating-conic-gradient(var(--a) 0deg 7deg, transparent 7deg 22deg);
  -webkit-mask: radial-gradient(circle, #000 0%, rgba(0,0,0,.55) 30%, transparent 68%);
  mask: radial-gradient(circle, #000 0%, rgba(0,0,0,.55) 30%, transparent 68%); opacity: .55; }
.tag { position: relative; z-index: 3; margin-bottom: -11px; padding: 3px 22px 4px; border-radius: 99px;
  background: linear-gradient(180deg, var(--t1), var(--t2)); color: #2a1406; font-size: 15px; letter-spacing: .5px;
  box-shadow: 0 2px 0 rgba(0,0,0,.35); }
.plate { position: relative; z-index: 2; min-width: 300px; padding: 14px 26px 10px; border-radius: 14px;
  background: rgba(20,14,12,.88); border: 3px solid var(--a); text-align: center; box-shadow: 0 3px 0 rgba(0,0,0,.4); }
.title { font-size: 31px; line-height: 1; letter-spacing: .5px; color: #fff;
  -webkit-text-stroke: 1.5px #120a06; paint-order: stroke fill; text-shadow: 0 2px 0 #120a06; white-space: nowrap; }
.sub { margin-top: 5px; font-size: 14px; letter-spacing: .4px; white-space: nowrap; color: #f2ecff; }
.sub .k { color: var(--s); }
.sub .dot { color: #bdb3c9; padding: 0 5px; }
.ends { position: relative; z-index: 2; margin-top: 4px; padding: 2px 16px 3px; border-radius: 99px;
  background: rgba(20,14,12,.88); border: 2px solid var(--a); color: var(--a); font-size: 15px; letter-spacing: .4px; }
.feet { position: absolute; padding: 4px 14px 5px 10px; border-radius: 99px; display: flex; align-items: center; gap: 7px;
  background: linear-gradient(180deg, var(--f1), var(--f2)); color: #2a1406; font-size: 17px;
  border: 2px solid rgba(255,255,255,.35); box-shadow: 0 2px 0 rgba(0,0,0,.35); }
.feet .v { opacity: .85; }
.ic { width: 20px; height: 20px; display: inline-block; }
.ic.gem { background: linear-gradient(135deg, #8dffb0, #19c45a); clip-path: polygon(50% 0, 100% 38%, 50% 100%, 0 38%); }
.ic.rbx { background: #2b2b2b; border: 3px solid #fff; border-radius: 5px; transform: rotate(45deg) scale(.82); }
.card { position: relative; width: 460px; height: 300px; display: inline-block; vertical-align: top; margin: 10px;
  background: radial-gradient(circle at 50% 70%, #4b3a6b, #1e1730); border-radius: 12px; overflow: hidden; }
.card .ov { left: 10px; top: 70px; }
.card .cap { position: absolute; left: 12px; top: 10px; font-size: 14px; color: #cfc4e6; }
.card .feet { left: 50%; transform: translateX(-50%); bottom: 18px; }
.scene { position: relative; width: 1663px; height: 793px; background-size: cover; }
.note { position: absolute; left: 20px; bottom: 16px; font-size: 18px; color: #fff; background: rgba(0,0,0,.55);
  padding: 8px 14px; border-radius: 8px; max-width: 900px; line-height: 1.3; }
h1 { font-size: 26px; padding: 18px 20px 4px; }
p.lead { padding: 0 20px 6px; color: #d8cfee; font-size: 16px; max-width: 1300px; line-height: 1.35; }
"""

# accent colours: the sword in Halloween orange, each pet in its own shop colour, the emotes in the hologram purple
THEMES = {
	"orange": dict(a="#ff9a2a", t1="#ffb347", t2="#ff7a12", s="#ffc23a", f1="#ffc061", f2="#ff8a1f"),
	"gold": dict(a="#ffc81c", t1="#ffe066", t2="#ffbf1c", s="#ffd23a", f1="#ffe27a", f2="#ffc21c"),
	"green": dict(a="#7dff5a", t1="#a8ff7a", t2="#5ae63a", s="#9dff7a", f1="#b2ff8f", f2="#6fe84d"),
	"sky": dict(a="#5ac8ff", t1="#8fdcff", t2="#3ab4ff", s="#8fdcff", f1="#a5e3ff", f2="#5ac2ff"),
	"mint": dict(a="#6effa0", t1="#a0ffc0", t2="#48e888", s="#9effbe", f1="#b0ffcb", f2="#62ec98"),
	"purple": dict(a="#c47bff", t1="#d9a6ff", t2="#b062ff", s="#e0b8ff", f1="#dcb2ff", f2="#b875ff"),
}


def style(theme):
	return ";".join(f"--{k}:{v}" for k, v in THEMES[theme].items())


def overhead(theme, tag, title, sub_k, sub_v, ends=None, left=0, top=0, absolute=True, k_colour=None):
	kc = f' style="color:{k_colour}"' if k_colour else ""
	pos = f"left:{left}px;top:{top}px;" if absolute else ""
	e = f'<div class="ends">{html.escape(ends)}</div>' if ends else ""
	return (f'<div class="ov" style="{pos}{style(theme)}"><div class="rays"></div>'
		f'<div class="tag">{html.escape(tag)}</div>'
		f'<div class="plate"><div class="title">{html.escape(title)}</div>'
		f'<div class="sub"><span class="k"{kc}>{html.escape(sub_k)}</span><span class="dot">·</span>{html.escape(sub_v)}</div></div>'
		f'{e}</div>')


def feet(theme, icon, price, left=None, top=None):
	pos = f"left:{left}px;top:{top}px;" if left is not None else ""
	return f'<div class="feet" style="{pos}{style(theme)}">{icon}<span>{price}</span><span class="v">·  VIEW</span></div>'


def card(caption, ov, ft):
	return f'<div class="card"><div class="cap">{html.escape(caption)}</div>{ov}{ft}</div>'


ENDS = "ENDS IN 13D 17H"  # HalloweenShop.ENDS_AT (Nov 1 00:00 UTC), counting down live

SWORD = [("IDLE", "PREVIEW · IDLE"), ("JAB", "PREVIEW · JAB"), ("LUNGE", "PREVIEW · LUNGE")]
PETS = [
	("orange", "Jack-o'-Lantern", "LEGENDARY PET", "INVISIBILITY", "PREVIEW · VANISH", ROBUX, "399"),
	("green", "Witch's Cat", "EPIC PET", "DECOY", "PREVIEW · CLONE", GEM, "250"),
	("sky", "Mummy", "EPIC PET", "GUARDIAN", "PREVIEW · SHIELD", GEM, "250"),
	("mint", "Bone Dragon", "LEGENDARY PET", "TEMPEST", "PREVIEW · BREATH", ROBUX, "399"),
]
EMOTES = [("Loser Dance", "COMMON"), ("Breakdance", "EPIC"), ("Reaper's Ride", "LEGENDARY")]
# EmoteConfig.RARITY colours
RARITY_COL = {"COMMON": "#aab2be", "RARE": "#50a0ff", "EPIC": "#b260ff", "LEGENDARY": "#ffc428"}


def page(title, body):
	return (f'<!doctype html><html><head><meta charset="utf-8"><title>{html.escape(title)}</title>'
		f'<style>{CSS}</style></head><body>{body}</body></html>')


# ---- the sheet: every state of the three overheads
cards = []
for st, sub in SWORD:
	cards.append(card(f"Sword podium · {st}",
		overhead("orange", "FEATURED", "ALL HALLOW'S SWORD", "LEGENDARY", sub, absolute=False),
		feet("orange", GEM, "1,200")))
for theme, name, tag, fam, sub, icon, price in PETS:
	cards.append(card(f"Pet podium · {name}",
		overhead(theme, tag, name.upper(), fam, sub, ENDS, absolute=False),
		feet(theme, icon, price)))
for name, rar in EMOTES:
	cards.append(card(f"Emote podium · {name}",
		overhead("purple", "EMOTE CRATE", name.upper(), rar, "1 OF 51 EMOTES", absolute=False, k_colour=RARITY_COL[rar]),
		feet("purple", GEM, "250")))
sheet = ('<h1>HOS-SHOW-002 · showcase podium overheads (mockup)</h1>'
	'<p class="lead">After the reference clip (reference_frame.png). Sword: FEATURED tag, the preview line follows the '
	'loop (IDLE / JAB / LUNGE). Pets: the tag, title, ability, preview and colour follow the pet on show; ENDS IN counts '
	'down to the end of the Halloween sale. Emotes: the title is the emote playing, its rarity in the rarity colour. '
	'The feet pill shows the price (Gems or Robux) and VIEW. Icons here are stand-ins for the game\'s own gem / Robux '
	'icons; the rays are the game\'s own Burst image tinted.</p>'
	+ "".join(cards))
open("mock_sheet.html", "w").write(page("Showcase overheads", sheet))

# ---- in place, over real captures of the podiums (positions picked by eye per capture)
scenes = {
	"sword": ("../HOS-WEP-002_showcase_idle.jpg", overhead("orange", "FEATURED", "ALL HALLOW'S SWORD", "LEGENDARY",
		"PREVIEW · JAB", left=612, top=40) + feet("orange", GEM, "1,200", left=760, top=560)),
	"pets": ("../HOS-HWN-002_harvest2.jpg", overhead("orange", "LEGENDARY PET", "JACK-O'-LANTERN", "INVISIBILITY",
		"PREVIEW · IDLE", ENDS, left=612, top=150) + feet("orange", ROBUX, "399", left=770, top=640)),
	"emotes": ("../HOS-EMOTE-002_hologram_tpose.jpg", overhead("purple", "EMOTE CRATE", "T-POSE", "COMMON",
		"1 OF 51 EMOTES", left=612, top=130, k_colour=RARITY_COL["COMMON"]) + feet("purple", GEM, "250", left=775, top=600)),
}
for key, (bg, inner) in scenes.items():
	body = (f'<div class="scene" style="background-image:url({bg})">{inner}'
		f'<div class="note">Mockup over a real capture (the old plain sign is still in the capture underneath).</div></div>')
	open(f"mock_{key}.html", "w").write(page(f"Overhead · {key}", body))
print("wrote mock_sheet.html, mock_sword.html, mock_pets.html, mock_emotes.html")
