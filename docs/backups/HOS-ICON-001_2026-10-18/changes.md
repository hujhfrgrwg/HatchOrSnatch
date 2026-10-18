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
