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
