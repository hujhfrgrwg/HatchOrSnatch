---
tags: [ui]
updated: 2026-10-16
ticket: HOS-UI-001
---
# Emote Crate Spin

The on-screen opening for an emote crate: the crate wobbles and bursts, a reel of emote tiles whips past and eases onto the prize, the prize pops with a rarity glow, then a reveal card shows the emote with **Claim** and **Open again**. Made with the `roblox-ui-maker` skill (HTML first, then import).

**Status:** HTML built, waiting for Hunter's approval. Not imported into Studio yet (the skill imports only after an explicit yes).

## Files
| Path | What |
|---|---|
| `UI/web/build.py` | Source of truth for every page (never hand-edit the .html) |
| `UI/web/emote_crate_spin.html` | The whole opening, animated, same timings as the game script (review only) |
| `UI/web/emote_crate*.html` | Reel, crate wobble, reveal, templates, all states |
| `UI/web/rbx.json` | Export config: ScreenGui `EmoteCrateUI`, screen `EmoteCrate`, templates folder `EmoteCrateTemplates` |
| `UI/roblox/ui/client/EmoteCrateSpin.luau` | Client module that plays the opening on the imported screen |

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
- **Current crate code:** not read yet (Studio MCP unreachable from the cloud session). The hookup point is the existing emote crate purchase handler.
- **Sounds:** none chosen; tick, burst and land need real recordings.
