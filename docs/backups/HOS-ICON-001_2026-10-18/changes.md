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
