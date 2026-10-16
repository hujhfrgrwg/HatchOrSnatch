---
tags: [dev, ui]
updated: 2026-10-16
---
# UI Runtime Changes

What the new UI controller changes at runtime, so the built GUI in Studio (`StarterGui.EOSUI`) doesn't look like a mistake when you open it. The source is `roblox/game/UIController.luau`; Studio runs it as `StarterPlayer.StarterPlayerScripts.EOS.Controllers.UIController`. How each button and remote is wired is in [[UI Wiring Map]].

## What the controller changes at join
- **The old UI is switched off.** `EOS_HUD`, `EOS_Menus`, `EOS_Results` and `EOS_Overlay` (from UIBuilder) are still Enabled in StarterGui. The controller disables their PlayerGui copies and keeps them off. EmoteController still reads `EOS_Menus.Emotes.Panel`, so those guis stay in the place.
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
- **Selection:** rings tween to the new tile (0.22 s Quint). Tiles pulse when you pick them. Refused actions shake.
- **Toasts:** they slide in, merge repeats and show a time bar. In the lobby they stack top right. With a panel open they move to the top centre, clear of its close button. In a match only forced toasts show, at the top centre.
- **Hatch:** egg shake, then the reveal pops in with sparkles breathing.
- **Results:** rays spin and the podium slides up in turn. Gold counts up.

## Not done yet
- All 354 images are live (16 Oct): uploaded to Hunter's account (Open Use), decal ids resolved to image ids in Studio (`Assets/UI/resolved_image_ids.txt`). `close_clean.png` is uploaded. Queued for the next `upload_ui.ps1` run: the 12 soft panel glows (`<key>s.png`), plus Hunter's real `safe`, `catcher`, `runner`, `hunt` and `afk` icons, which replace the drawn stand-ins under the same names. Their old ids were cleared from `Assets/asset_ids.json` so they upload again.
- Emotes: the new UI has no emotes panel yet. Opening it shows a toast, and EmoteController still uses the hidden old `EOS_Menus`.
- The game code still launches 3 families (Decoy, Scout, Brake) and the voxel pet species. The UI reads `LAUNCH_FAMILIES` at runtime, so more families light up as the game adds them.
