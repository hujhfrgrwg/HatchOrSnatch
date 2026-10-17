---
tags: [ui]
updated: 2026-10-16
ticket: HOS-UI-001
---
# Emote Crate Spin

The on-screen opening for an emote crate: the crate wobbles and bursts, a reel of emote tiles whips past and eases onto the prize, the prize pops with a rarity glow, then a reveal card shows the emote with **Claim** and **Open again**. Made with the `roblox-ui-maker` skill (HTML first, then import).

**Status:** Approved by Hunter 2026-10-16. Imported into the Hatch or Snatch place 2026-10-16 and wired into the existing Emote Crate (EmoteController). Edit-mode verified; not yet playtested.

**Next:** Hunter playtests an opening (Gems, Robux and Open again) and judges the look and feel; then the open items below.

## Import (2026-10-16)
- 35 images uploaded to group 228184582 with Open Cloud (`tools/upload/upload_assets.py`, Hunter's `ROBLOX_OPEN_CLOUD_API_KEY`). Open Cloud returns Decal ids; the Image ids behind them (InsertService) are in `UI/web/rbx/out/uploaded.json` -> `UI/roblox/ui/AssetIds.luau`. Decal ids: `Assets/asset_ids.json`.
- `ServerStorage.EmoteCrateUIBuild` -> `Builder.build()` made `StarterGui.EmoteCrateUI` (Enabled = false; EmoteController enables it) and `ReplicatedStorage.EmoteCrateTemplates` (Tile_common/rare/epic/legendary). `fit()` x2: 4.0% then 1.5%.
- The skill's template `Controller` LocalScript is not shipped: EOSUI's UIController runs the game's UI, so a second controller would fight it. `UI`/`Toasts` ship but nothing requires them.
- Backup before editing: `docs/backups/HOS-UI-001_2026-10-16/pre_edit_EmoteController_EmoteService.rbxm`.

## Hookup in the game
`StarterPlayer.StarterPlayerScripts.EOS.Controllers.EmoteController` (client only; EmoteService on the server is unchanged):
- OPEN (Gems) fires `RequestOpenCrate` and waits; the old glow-hop reel over the odds board and the panel's Reveal are no longer used (their functions stay in the script, unused).
- Every `CrateResult` with `ok` (Gems or Robux) becomes an `EmoteCrateSpin.Result`: pool = all 51 emotes, weights = EmoteConfig odds per rarity, `isNew` = not dupe, `dupeText` = "Already owned: +N Gems", Open again price = `CRATE_GEMS` (hidden where paid random items are restricted), short text "Need N more".
- A refused open (`ok = false`) unlocks the button; during Open again it calls `EmoteCrateSpin.cancelAgain()` so the screen closes at once. Refusals that only toast unlock after 10 s.
- The Emotes panel closes while the opening plays and comes back on the crate tab after Claim. `EmoteCrateUI.DisplayOrder` = 8 (EOSUI is 5).
- Sounds: the game's Sound module (`tick` per tile with pitch jitter, `crack` for the burst, `reward` / `evolve` (Epic, Legendary) on landing, `reveal`), so the Settings sound toggle applies. All are recordings already in the game.

## Module changes made at import
- `playSound(cue, rarity)` option: the game's own sound player instead of Sound instances.
- `cancelAgain()`: stop waiting for an Open again the server refused.
- `groupRays`: the export split the rays SVG into 16 white `Shape` pieces under Reveal; init gathers them into one `Rays` holder (1096 x 1096, centred on the glow) so the reveal spins them and tints them the rarity colour.

## Mobile pass (2026-10-16, Hunter: "fix what you think needs to be fixed for mobile")
- **Fit to screen (was broken everywhere but 1920x1080):** nothing scaled `EmoteCrateUI.Root` (the game's UIController only fits EOSUI, and the kit's `UI.init` isn't used), so on a phone the opening sat at design size, mostly off screen. `fitScreen()` in EmoteCrateSpin now sizes Root + FitScale to the viewport like the kit does and follows rotation / window changes.
- **Phone boost:** on small screens CrateStage, Reel and Reveal get a `PhoneScale` UIScale so CLAIM / OPEN AGAIN reach 48 px tall (were 36), capped so the reveal card still fits the height: 1.33 on 844x390, 1.38 on 667x375, 1.0 on PC and tablets.
- **Top bar:** CrateTitle moves below Roblox's top bar (TopbarInset); on phones it hides while the bigger reveal card is up (the card would reach it).
- **Long emote names:** 26 of the 51 names were wider than the tile's name label (up to 274 px against 173) and spilled over the next tile. Tile names now shrink to fit (measured once per name, min 12).
- Checked: sweep at 844x390 and 667x375 with those values: no TAP_SMALL; card 56-373 px of 390; title 61-96 px under the reel at 113-277 px; tiles 91 px wide. The 2-4 px TEXT_NOFIT on CLAIM / the skip hint is harmless (centred, non-wrapping labels draw a hair past their box).

## Verified (edit mode, 2026-10-16)
- 0 empty images in the gui and templates; probed ids are Images owned by the group.
- Every name EmoteCrateSpin looks up exists (after groupRays).
- `plan()` x200 with the real pool: prize always on the landing tile; flavour tiles Common 45.8 / Rare 32.4 / Epic 15.0 / Legendary 6.8 % against odds 46 / 32 / 15 / 7.
- EmoteController and EmoteCrateSpin compile; `init` runs on a clone.
- PropertySweep at 1920x1080, 1366x768, 844x390: CLIPPED on the reel Track and the card shadow (by design); IMG_NOTLOADED everywhere (edit mode can't tell; ids probed fine); TEXT_NOFIT by 2 px on CLAIM and 4 px on the skip hint at phone size; **TAP_SMALL: Claim and Open again are 36 px tall on an 844x390 phone (minimum 44).**
- Not run: playtest, phone device simulator, real clicks, sounds (needs Hunter's playtest).

## Files
| Path | What |
|---|---|
| `UI/web/build.py` | Source of truth for every page (never hand-edit the .html) |
| `UI/web/emote_crate_spin.html` | The whole opening, animated, same timings as the game script (review only) |
| `UI/web/emote_crate*.html` | Reel, crate wobble, reveal, templates, all states |
| `UI/web/rbx.json` | Export config: ScreenGui `EmoteCrateUI`, screen `EmoteCrate`, templates folder `EmoteCrateTemplates` |
| `UI/roblox/ui/client/EmoteCrateSpin.luau` | Client module that plays the opening on the imported screen |
| `UI/roblox/ui/` | Generated `Data_*.luau` plus the skill's runtime modules (Builder, UIKit, UI, ...); the gui is `EmoteCrateUI` |

Preview: `cd UI/web && python3 make_placeholders.py && python3 build.py && python3 -m http.server 8870 --bind 127.0.0.1`, then open `http://127.0.0.1:8870/index.html`.

## How it plays (seconds)
Wobble 1.25 (0.6 on Open again), burst 0.35, spin 5.0 first time / 3.6 after with Quint Out onto a random spot on the prize tile, then a 0.45 Back Out settle to its centre. One tick per tile crossing (sound capped at one per 30 ms) and a marker wiggle. Landing dims the other tiles, pops the prize (1.08 to 1.16 by rarity), glows in the rarity colour, and shakes the reel for Epic and Legendary. Tap anywhere skips to the landing. The reveal waits for a button; Escape or gamepad B count as Claim. Results that arrive mid-spin queue up.

## Rules it follows
- The server charges, rolls and grants before the client plays anything. The reel is built around the known prize.
- Flavour tiles use the crate's real rarity weights, so the strip looks like the real odds. No rigged near-miss tile next to the prize.
- Nothing is drawn over the prize: markers sit above and below the strip.
- World blur goes on the camera, not Lighting.

## Wiring (once the screen is imported)
```lua
local Spin = require(ReplicatedStorage.UI.EmoteCrateSpin) -- wherever the client modules live
Spin.init({
	gui = Players.LocalPlayer.PlayerGui:WaitForChild("EmoteCrateUI"),
	templates = ReplicatedStorage:WaitForChild("EmoteCrateTemplates"),
	sounds = { tick = ..., burst = ..., land = { Legendary = ... } }, -- optional; real recordings only
	onOpenAgain = function() BuyEmoteCrate:FireServer(crateId) end,
})
-- the existing purchase remote's reply, reshaped into EmoteCrateSpin.Result
EmoteCrateOpened.OnClientEvent:Connect(function(r) Spin.play(r) end)
```
`Result` needs `prize` and `pool` (`{ id, name, rarity, image }`), plus optional `weights`, `crateName`, `crateImage`, `isNew`, `dupeText`, `againPrice`, `canAffordAgain`, `shortText`.

## Open items
- **Style:** stud preset. Needs a screenshot of the current game UI as `UI/web/ref.png` to match it.
- **Stud texture:** `stud.png` is a stand-in; drop in the ui-resources.com Stud texture.
- **Phone look:** the mobile pass is checked by numbers only; Hunter should open a crate on a phone (or Studio's device emulator) to judge it.
- **Emote pictures:** emotes have no images, so every reel tile shows the same `emote_slot` icon with the name and rarity colour. Per-emote pictures would need art (or a rendered pose per emote).
- **Sounds:** borrowed from the game's existing set (see Hookup); Hunter may want crate-specific recordings.
