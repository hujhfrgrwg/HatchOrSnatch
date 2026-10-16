---
tags: [dev, ui]
updated: 2026-10-16
---
# UI Runtime Changes

What the new UI controller changes at runtime, so the built GUI in Studio (`StarterGui.EOSUI`) doesn't look like a mistake when you open it. The source is `roblox/game/UIController.luau`; Studio runs it as `StarterPlayer.StarterPlayerScripts.EOS.Controllers.UIController`. How each button and remote is wired is in [[UI Wiring Map]].

## What the controller changes at join
- **The old UI is switched off.** `EOS_HUD`, `EOS_Menus`, `EOS_Results` and `EOS_Overlay` (from UIBuilder) are disabled in StarterGui since 16 Oct (HOS-UI-OLDOFF-001), so they no longer draw over the Studio viewport. The controller also keeps their PlayerGui copies off. EmoteController still reads `EOS_Menus.Emotes.Panel`, so those guis stay in the place. Re-running `ServerStorage.EOSBuild.UIBuilder` would recreate them Enabled, so don't.
- **Page dims cover any screen shape.** Each page's dim is a 1920×1080 design rect. The controller stretches it past the edges so tall or wide screens never show a gap.
- **There is an overlay layer.** `Root.Overlay` (ZIndex 40) holds toasts, banners and confirm boxes above every screen and shares the root's scale.
- **Selection rings move with their stroke.** The exporter turns a ring's box-shadow into `ShadowRing` siblings. The controller folds them into the ring (`FamilySel`, `ItemSel`, `PetSel`, `SwatchSel`, `SelRing`) so the visible stroke follows the selection.
- **Shadows follow their element.** Each state of a two-state control (Live/Soon, On/Off, Buy/Poor) and each card brings its own `DropShadow` or `ShadowRing`, drawn just below it. The controller ties each shadow's visibility to the element one ZIndex above it. Without this, a hidden state's shadow covered the visible one (black family tiles) or floated over another tab (lines across Settings → Controls).
- **The ability card's pet slot is rebuilt.** The export flattened `PetDisc` to a tinted glow and dropped the pet image, so the controller adds a round `PetIcon` with a green rim and a black outline.
- **The close button swaps to a clean render.** The export clipped the tilted box (and its corner tabs) to its layout rect, which left red slivers. `Assets/UI/art/close_clean.png` is the box without tabs. When `art.close_clean` has an id, the controller swaps it in, centred where the old art was.
- **Gamepad selection is a white rounded ring** (`PlayerGui.SelectionImageObject`), not Roblox's blue box.
- **The ladder title is tagged.** The Incubator ladder's folder-tab title has no name in the export, so it gets a `LadderTitle` attribute and is renamed per family.

## What the controller builds while you play
- **Piece tiles and the first-pet track show real state.** Piece art uses the real icon, dark when you have none. The Match 1/2 steps light up as pieces arrive, and the Hatch step pulses when ready.
- **Lists are cloned, not designed.** Pets (`Proto_common/rare/epic`) and Shop cards (`Item_SparkleTrail`, `ProtoGems.Item_RainbowTrail`) are cloned into a `Scroll` ScrollingFrame inside each Grid. The design tiles (Pet1–6, Empty6–10, the shop's design cards) stay hidden.
- **Dual-state controls only flip Visible.** On/off toggles, tabs and filters (`On`/`Off`), buy states (`BtnBuy`, `BtnPoor`, `BtnOwned`, `BtnWear`, `BtnTakeOff`, `BtnUse`) and hatch states were all exported, and the controller shows one at a time.
- **UI Colour tints the mono copies.** The default look shows `Glow`/`Fill`. Any other colour hides those and shows `GlowMono`/`FillMono`, tinted from `ACCENT_TINT`. The choice is saved with `RequestSettings({uiColour})`.

## Motion
- **Panels:** `UI.luau` handles the pop, dim fade, banner slide and close-button spin. On top of that, the controller cascades the panel's wells and buttons in reading order, 35 ms apart. Frames rise 22 px; buttons scale in so their hover springs keep their rest. The cascade is off with Reduce Effects, and on Results and Hatch, which have their own motion.
- **Rail toggles grey out when off.** AFK and Hunt show their full-colour icon on a coloured `PlateOn` when on (AFK blue, Hunt purple) and a greyed copy (`afk_off`, `hunt_off`, made by `ui/tools/icon_variants.py`) on the grey plate when off. Hunt shows only in private servers. Each toggle uses one drawing: the `afk_on` play moon is uploaded but unused (Hunter's pick, 16 Oct).
- **Selection:** rings tween to the new tile (0.22 s Quint). Tiles pulse when you pick them. Refused actions shake.
- **Toasts:** they slide in, merge repeats and show a time bar. In the lobby they stack top right. With a panel open they move to the top centre, clear of its close button. In a match only forced toasts show, at the top centre.
- **Hatch:** egg shake, then the reveal pops in with sparkles breathing.
- **Reward reveal (16 Oct, HOS-REWARD-001).** Every buy gets its own moment on the `Reward` screen (`UIC.showReward`): a shop item bought with Gold, Gems or Robux, and a Gem pack. Rays spin, the prize pops in, the title slams, then the words and sparkles follow, with the purchase and reveal sounds. The screen shows "UNLOCKED!" for items you keep, "ADDED!" for one-use items and a lime "GEMS ADDED!" with the pack's art for Gem packs. USE NOW appears only for a lobby burst. A bought case is already worn (`ProfileLogic.buy`), so it has no button. The server no longer sends a success toast for these: `ShopResult` drives the reveal (`{ ok, itemId, robux?, refunded? }` or `{ ok, gems }`). A Robux buy of an item you already own refunds its Gems with a toast and no reveal. Emote Crate wins keep their reveal in the Emotes panel, with the same beats through `UIC.revealBeats`.
- **Shop tag pills fit their words.** `tagText` measures the new text (`TextService:GetTextBoundsAsync`) and resizes the pill. Item cards sit at the page's top (the page already carries the 102 px offset) and the row is centred.
- **Results:** rays spin and the podium slides up in turn. Gold counts up.

## Not done yet
- All 371 images are live (16 Oct). They're uploaded to Hunter's account (Open Use), and their decal ids were resolved to image ids in Studio (`Assets/UI/resolved_image_ids.txt`). That includes `close_clean.png`, the 12 soft panel glows and Hunter's real `safe`, `catcher`, `runner`, `hunt` and `afk` icons.
- Emotes, Servers and Spectate are built (16 Oct): see [[Emotes Servers Spectate]].
- The game code still launches 3 families (Decoy, Scout, Brake) and the voxel pet species. The UI reads `LAUNCH_FAMILIES` at runtime, so more families light up as the game adds them.
