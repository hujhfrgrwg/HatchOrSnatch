---
tags: [delivery, lobby, shop]
ticket: HOS-SHOW-001
date: 2026-10-18
---
# HOS-SHOW-001: walk-up Shop and hold-E on the showcase podiums

Matthew: "Make sure all of these have walk up pop up GUI that takes them to that part of the shop. each one should then have a hold E to pop up if they close out of the shop but are still standing"

## What players get
| Podium | Showcase | Opens the Shop on | Prompt text |
|---|---|---|---|
| `Podium_Harvest` (west) | All Hallow's Sword on your avatar (HOS-WEP-002) | **Featured** (changed from Weapons at Matthew's request: the sword is sold on Featured) | View in Shop / All Hallow's Sword |
| `Podium_Harvest2` (east) | Halloween pets (HOS-HWN-002) | **Featured** (where the Halloween pets are sold) | View in Shop / Halloween Pets |
| `Podium_Obelisk` (north) | Emote hologram (HOS-EMOTE-002) | **Emotes** | View in Shop / Emotes |

- **Walk up:** within 8 studs of the podium's stand (about its edge), the Shop opens on that tab, once.
- **Close it but stay:** an **E prompt (a tap, no hold;** changed from a 0.5 s hold at Matthew's request) on the podium opens the same tab again. It only shows while the Shop is shut, never in a match, and reaches 10 studs.
- **Walk away:** past 12 studs, a Shop the podium opened closes, and the walk-up is armed for next time. These are the spin wheel's distances and rule.
- **Never opens over something else:** not when another menu is open, in a match, while spectating, dead, or before your profile has loaded.

## How it works
- **New client module** `StarterPlayer.StarterPlayerScripts.EOS.Controllers.ShowcasePrompts`, started from `WeaponFXBoot`. It finds the podiums by their showcase tags (`HOS_WeaponShowcase` → `featured`, `HOS_PetShowcase` → `featured`, `HOS_EmoteShowcase` → `emotes`), so any podium tagged later gets the same walk-up and prompt.
- **Opening the Shop** uses `UIController.openShopTab(tab)`, the same call the Featured page's banner uses. It's a client screen, so nothing goes to the server.
- **The prompt** is a ProximityPrompt this client creates on an attachment (`StandGlow.HOS_ShowcasePrompt`). It sits low at the podium's front edge, 4.6 studs out from the stand toward the middle of the lobby and 0.9 studs below the stand's height, so it doesn't cover the avatar, pet or hologram (moved down from 2.6 studs over the stand at Matthew's request). It's made again if the podium streams back in. The sword podium's prompt names its skin from `ShowcaseSkin`.

## Checks (Studio playtest, 18 Oct)
For each podium, starting away from it and stepping to its edge:
- Sword: opened on **PageWeapons**. After closing, the prompt was enabled; hold E reopened PageWeapons.
- Pets: opened on **PageFeatured**. Prompt enabled after closing; hold E reopened PageFeatured.
- Emotes: opened on **PageEmotes**. Prompt enabled after closing; hold E reopened PageEmotes.
- Walking away from the Obelisk closed the Shop it had opened.
- Standing at each podium, the only prompt shown was that podium's own (the lobby crates' E prompts are out of range). No warnings or errors.
- The prompt UI doesn't appear in Studio screenshots (Roblox draws it in its own GUI layer), so it was checked through `ProximityPromptService.PromptShown` instead.

Re-checked after the change: the sword podium's walk-up and prompt both open **PageFeatured**. After the tap change, a single press and release of the prompt opened the Shop on all three podiums. After the move, each prompt measured 4.6 studs out at the front (facing the lobby's middle) and 0.9 below the stand, and a tap still opened the Shop on all three.

## Backup and undo
- `WeaponFXBoot` as it was: `docs/backups/HOS-SHOW-001_2026-10-18/WeaponFXBoot.lua`. That is the live script, including another session's lobby crates start line, checked against Studio by length and checksum.
- Studio undo step: "HOS-SHOW-001 showcase walk-up shop prompts" (module and start line). The module's source was set afterwards.
- ScriptHistory updated (`ShowcasePrompts.lua` new, `WeaponFXBoot.lua`, which now also carries the lobby crates line).
