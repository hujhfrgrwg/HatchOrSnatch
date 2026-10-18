# HOS-ICON-001: what changed (18 Oct 2026)

The full pre-edit copy of `CrateShowcase` is in Studio at `ServerStorage._Backups.HOS-ICON-001_2026-10-18.CrateShowcase`. The repo's ScriptHistory copy is older than Studio's, so only the changed lines are recorded here.

## StarterPlayerScripts.EOS.Controllers.CrateShowcase, `crateImage()`
Before:
```lua
-- the crate picture: the Weapon Crate's own art, the gift for the Emote Crate
...
	return icon("gift")
```
After:
```lua
-- the crate picture: the Weapon Crate's own art, the Emote Crate's icon for the Emote Crate
...
	return "rbxassetid://78853379381316" -- HOS-ICON-001: the Emote Crate's own icon (was the gift)
```

## StarterGui.EOSUI images (was `rbxassetid://87833590533916`, now `rbxassetid://78853379381316`)
Each one keeps its old id in a `HOS_WasImage` attribute.
- `Root.Shop.Shop.Panel.PageEmotes.CrateCard.CrateArt` and `CrateArtShadow`
- `Root.Emotes.Emotes.Panel.CratePage.Detail.CrateIcon` and `CrateIconShadow`

## Second round (18 Oct): the Emotes tab icon, and the Shop card decluttered
The Studio copies from before this round are `ServerStorage._Backups.HOS-ICON-001_2026-10-18.CrateCard_before` and `TabCrate_before`.

- `EOSUI.Root.Emotes.Emotes.Panel.TabCrate.On` / `Off`: `I_gift` and `I_giftShadow` now use the Emote Crate icon. Each keeps its old image in `HOS_WasImage`.
- `EOSUI.Root.Shop.Shop.Panel.PageEmotes.CrateCard`:
  - **Hidden (Visible = false):** `CrateSub`, the odds rows (`T_Common`, `T_Rare`, `T_Epic`, `T_Legendary` and their `T_*Each` lines) and `T_ADuplicateRefundsGemsEmo`, each with its shadow.
  - **Moved up** to one stack beside the crate: `T_EmoteCrate` (and its shadow) to y 92 / 97, `BtnCrateGems` and `BtnCrateRobux` to y 196, `BtnSeeEmotes` to y 298. Each keeps its old position in `HOS_WasPos`.
  - CrateExtras puts its runtime OPEN 10 button where SEE ALL is when it mounts, so it follows.

## Third round (18 Oct): less dead space, a brighter SEE ALL
Every moved or resized element keeps its old values in `HOS_WasPos`, `HOS_WasSize`, `HOS_WasTextSize` and `HOS_WasImage`.
- **Crate art:** `CrateArt` and its shadow go from 360 to 440, at (20, 62) and (20, 66).
- **Title:** `T_EmoteCrate` and its shadow are 1.3× (520 × 94, text and stroke ×1.3), at (470, 136) and (470, 142).
- **Price buttons:** `BtnCrateGems` at (470, 252), `BtnCrateRobux` at (826, 252).
- **SEE ALL:** `BtnSeeEmotes` is at (470, 358), now 340 × 64, the width CrateExtras gives it at runtime. CrateExtras puts OPEN 10 at 470 and moves SEE ALL to 826.
  - Its art is the Shop's active-tab orange (`134988778468442`), sliced so the corners stay crisp. It used to be the gray `118469927722961`.
  - It has a new eye icon (`I_eye` with `I_eyeShadow`, the `spectate` icon `90110240378916`), and the label moved right to make room.

## Fourth round (18 Oct): the final icon id
Every `rbxassetid://78853379381316` is now `rbxassetid://86101813885240`:
- the 8 EOSUI images: the Shop card art and shadow, the Emotes tab On/Off icons and shadows, and the Emotes crate panel icon and shadow;
- the one reference in CrateShowcase.

## Fifth round (18 Oct): less dead space (Matthew: "remove some of the dead space, you can probably make things bigger")
**CrateCard** (old values are still in each element's `HOS_Was*` attributes):
- **Crate:** `CrateArt` and its shadow are 480, at (12, 42) and (12, 46).
- **Title:** `T_EmoteCrate` and its shadow have text 1.6× the original (`HOS_WasTextSize`), are 676 × 112, and sit at (500, 106) and (500, 113).
- **Price buttons:** `BtnCrateGems` at (500, 234) and `BtnCrateRobux` at (846, 234), both 330 × 120.
  - Their art is sliced so the corners keep their size.
  - The icon and label are scaled 1.4× about the old centre and moved to the new centre.
- **SEE ALL:** `BtnSeeEmotes` at (500, 370), 330 × 84. It has a 48 px eye at x 18, and its label is 246 × 38 at x 72, text size 34, scaled to fit.
  - At runtime OPEN 10 takes this slot, and SEE ALL moves to x 846.

**StarterPlayerScripts.EOS.Controllers.CrateExtras** (the pre-edit copy is in Studio at `ServerStorage._Backups.HOS-ICON-001_2026-10-18.CrateExtras`). Before:
```lua
	local half = 340
...
			d.TextSize = math.min(d.TextSize, math.floor(h * 0.5))
```
After:
```lua
	local half = gems.Size.X.Offset -- HOS-ICON-001: as wide as the Gems button above (was 340)
...
			d.TextSize = math.min(d.TextSize, math.floor(h * 0.5), math.floor((w - 24) / (#d.Text * 0.44))) -- HOS-ICON-001: and fits the width
```
The second line only ever makes OPEN 10's text smaller, so it fits the button's width. The Weapon Crate's OPEN 10 uses the same code, and is unchanged unless its text would overflow.

## Sixth round (18 Oct): button faces (Matthew: "Theyre being incorrected clipped, especially the bottom ones ... it doesnt feel so saturated")
**Why they clipped.** The buttons' art is pre-rendered raster images (Gems and Robux are 340 × 88 exports, so 680 × 176 px; the orange tab art is 290 × 66, so 580 × 132 px). Each has a dotted fade baked into its right side.
- Slicing them to 330 × 120 stretched the right 12 px of that fade into a light strip down the right edge.
- CrateExtras' `sliceArt` sets each slice rect from the element's size, not the image's. That gave OPEN 10 `Rect(24, 24, 636, 224)` on a 176 px tall image, and SEE ALL `Rect(24, 24, 636, 152)` on a 580 × 132 image. Both rects run past the image, which cut off the bottom edge and broke the corners.

**What changed.** In `BtnCrateGems`, `BtnCrateRobux` and `BtnSeeEmotes`, the `Art` ImageLabel was replaced by an `Art` Frame built from frames (`tools/build/HOS-ICON-001/button_faces.lua`):
- **`Edge`:** dark outline (20, 14, 26), radius 14.
- **`Lip`:** darker bottom, inset 3, radius 11.
- **`Face`:** inset 3 and 6 px shorter than the lip. A white frame with a top-to-bottom UIGradient (the gradient multiplies the frame colour, so the frame must be white).
- **`Studs`:** the place's stud tile `75407673232479` (the one on the quests pill), tiled at 40 px. Its transparency fades from 1 on the left to 0.35 on the right, like the dots on the other buttons.
- **Colours:** lighter top / face / lip, all less saturated than the old art.
  - Gems: (122, 206, 92) / (86, 176, 66) / (46, 112, 44)
  - Robux: (170, 112, 214) / (132, 78, 184) / (82, 44, 124)
  - SEE ALL: (246, 182, 84) / (222, 140, 48) / (150, 84, 28)
- **Old image ids:** each new `Art` keeps its old id in `HOS_WasImage`. The full pre-edit buttons are in Studio at `ServerStorage._Backups.HOS-ICON-001_2026-10-18.Btn*_round6_before`.
- **CrateExtras is unchanged.** Its `sliceArt` only touches ImageLabels named Art, so it skips the Frame. Its `resize` still sizes the Frame (offset size = button size), so the runtime OPEN 10 clone gets a 330 × 84 face.
- **Checked in a playtest:** all four buttons have clean corners and full bottom edges. Screenshot: `docs/HOS-ICON-001/shop_card_buttons_round6.png`.

## Seventh round (18 Oct): one colour per job (Matthew: "it's just confusing to know whats what without reading")
Gems was green and Robux was purple, but both icons are green and the rest of the shop uses purple for many things, so the colours didn't say which was which. Only `Art.Lip.BackgroundColor3` and `Art.Face.UIGradient.Color` changed (top / face / lip):
- **Robux (149):** gold, (255, 214, 92) / (240, 176, 36) / (166, 106, 18). It was purple, (170, 112, 214) / (132, 78, 184) / (82, 44, 124).
- **SEE ALL:** blue, matching its blue eye, (110, 188, 255) / (56, 138, 232) / (28, 78, 158). It was orange, (246, 182, 84) / (222, 140, 48) / (150, 84, 28). It moved off orange so it isn't mistaken for the gold Robux button.
- **Gems (250) and OPEN 10:** still green, like the gem icon and the Gems wallet.
