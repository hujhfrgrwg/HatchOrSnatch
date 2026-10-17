---
tags: [hub]
updated: 2026-10-17
---
# Hatch or Snatch Home

Start page for the project. Agents read this first (see `CLAUDE.md`).

## The game
*Not written yet.* The one-paragraph pitch, core loop and target players go here, then a `Hatch or Snatch Game Plan.md` and a `Hatch or Snatch Decisions.md` (one line per decision Hunter makes, with the date).

## Studio place
| | |
|---|---|
| Place name | Hatch or Snatch |
| Place id / universe id | 128015050187408 / *(fill in)* |
| Owner | Group 228184582 |

## Setup
- **Studio MCP:** `.mcp.json` points at Hunter's ngrok tunnel; cloud sessions need `ROBLOX_MCP_TOKEN` in their environment. On the PC: `tools\mcp\start_mcp_server.ps1` (server and Studio plugin must be the same version, 3.2.1).
- **Uploads:** `tools\upload\upload_assets.py` (Open Cloud; key and creator from the environment). On the PC, Hunter's `ROBLOX_OPEN_CLOUD_API_KEY` works for the group (pass it as `HOS_ROBLOX_API_KEY` for the one process, group 228184582). Open Cloud returns Decal ids: resolve the Image id with `InsertService:LoadAsset(decalId)` before using it in a GUI.
- **Skills and research:** [[RoClicks Index]].
- **Game-Blueprint (Hunter's playbook):** `C:\Users\hunte\OneDrive\Documents\Game-Blueprint`, read-only. Use it whenever it applies; start with [[Game-Blueprint Digest]] (what's there, what applies, conflicts with his decisions).

## Design
- VFX resource review (HOS-VFX-RES-001, 17 Oct): `docs/vfx_review_2026-10-17/HOS-VFX-RES-001.md`. What in Hunter's UNSORTED OS RESOURCES place is worth using, what to avoid (anime/game IP), and the third-party texture ids now in the egg trails, Confetti Burst and the Void / Inferno / Frost Rift skins (shop `abilitySkin` items, worn from `cosmetics.riftSkin`).
- [[Emote Light Constructs]]: Destiny-style glowing props for the 13 emotes that mime one (scythe, surfboard, toilet, cart, ...). In the place since 2026-10-16: templates `ReplicatedStorage.EOS_EmoteFX`, client `Controllers.EmoteFX`; playtest owed.
- [[HOS-PET-001 Ability Framework]]: five pet ability archetypes (Decoy, Invisibility, Guardian, Tempest, Rift), a Runner and a Catcher handler each, numbers in `Shared.AbilityConfig`, species looks in `Shared.AbilityCosmetics`, handlers in `ServerScriptService.EOS.Abilities`. Scout and Brake removed; the starting Catcher has no pet ability. Since 2026-10-16; only Decoy and Invisibility (Runner side) are built.
- Compass Hare (HOS-PET-021, Rift Rare, installed 17 Oct): `docs/pets/compass_hare/README.md`.
- Scroll Tanuki (HOS-PET-022, Decoy Epic, installed 17 Oct): `docs/pets/scroll_tanuki/README.md`.
- Moonveil Moth (HOS-PET-023, Invisibility Epic, installed 17 Oct): `docs/pets/moonveil_moth/README.md`.
- Shrine Lion (HOS-PET-024, Guardian Epic, installed 17 Oct): `docs/pets/shrine_lion/README.md`.
- Drum Oni (HOS-PET-025, Tempest Epic, installed 17 Oct): `docs/pets/drum_oni/README.md`.
- Astral Djinn (HOS-PET-026, Rift Epic, installed 17 Oct): `docs/pets/astral_djinn/README.md`.
- Eclipse Tengu (HOS-PET-027, Decoy Legendary, installed 17 Oct): `docs/pets/eclipse_tengu/README.md`.
- Veil Nekomata (HOS-PET-028, Invisibility Legendary, installed 17 Oct): `docs/pets/veil_nekomata/README.md`.
- Aegis Kirin (HOS-PET-029, Guardian Legendary, installed 17 Oct): `docs/pets/aegis_kirin/README.md`.
- Raiju (HOS-PET-030, Tempest Legendary, installed 17 Oct): `docs/pets/raiju/README.md`.
- Void Seraph (HOS-PET-031, Rift Legendary, installed 17 Oct): `docs/pets/void_seraph/README.md`.
- Pumpkin Wraith (HOS-HWN-001, Invisibility, Legendary, Halloween, installed 17 Oct): `docs/pets/pumpkin_wraith/README.md`.
- Witch's Cat (HOS-HWN-001, Decoy, Epic, Halloween, installed 17 Oct): `docs/pets/witch_cat/README.md`.
- Mummy (HOS-HWN-001, Guardian, Epic, Halloween, installed 17 Oct): `docs/pets/mummy/README.md`.
- Halloween Featured store (HOS-HWN-001, 17 Oct, sale ends Nov 1 2026 UTC): `docs/pets/halloween_store/README.md`.
- Shop pet preview on hover, with each pet's own ability effect (HOS-SHOP-PREVIEW-001, 17 Oct): `docs/HOS-SHOP-PREVIEW-001/README.md`.
- Riot Hound (HOS-PET-020, Tempest Rare, installed 17 Oct): `docs/pets/riot_hound/README.md`.
- Crystal Warden (HOS-PET-019, Guardian Rare, installed 17 Oct): `docs/pets/crystal_warden/README.md`.
- Grin Ghost (HOS-PET-018, Invisibility Rare, installed 17 Oct): `docs/pets/grin_ghost/README.md`. Shared pet rules: `docs/pets/PET_LESSONS.md`.

## UI
- [[docs/HOS-EGG-002_report|Egg plan]] (HOS-EGG-002, 17 Oct): eggs charge from brave plays and roll at safety, one shard per match, one incubator egg with shown odds and a family focus. Switch `Shared.EggConfig.ENABLED` (**on** in the edit place). Server `EggService` + `Core.IncubatorLogic`, client `Controllers.EggUIController` / `EggFX`, UI `EggUI` (export `ui_egg/`). Spec, tests and playtests in `docs/HOS-EGG-002/`. Playtested; place not saved.
- [[docs/hero-chicken/README|Hero or Chicken]] (HOS-HOC-001, 17 Oct): the lead Catcher's cinematic pick at the start of every crossing: HERO (alone first) or CHICKEN. Server `HeroChickenService` / `CrossingLineup` / `CatcherGesture`, client `Controllers.HeroChicken`, UI `HeroChickenUI` (EOSUI project section, export `ui_hc/`). Playtested; place not saved.
- Paid Lead Catcher (HOS-LEAD-001, 17 Oct, 29 Robux, one buyer per match): `docs/HOS-LEAD-001/hooks.md` (design, hooks, to-do), module `docs/HOS-LEAD-001/LeadCatcherService.lua`, mockups `docs/HOS-LEAD-001/mockups/` (UI `lead_catcher_*` pages in UI/build.py), product 3719288426 (`tools/upload/create_lead_product.py`). Installed and playtested 17 Oct (server `LeadCatcherService`, client `Controllers.LeadCatcherController`, templates `LeadCatcherUITemplates` from `ui_lead/`); place saved by Hunter 17 Oct 20:18Z.
- Map vote (HOS-MAPVOTE-001, 17 Oct): NEXT MAP vote in the lobby intermission (2 of the maps not just played, switchable, tie = random, locks + shows the winner 1.5 s before 0:00), the Lead Catcher card turns into a small button under it. Server `MapVoteService` (2 MatchService lobbyLoop hooks), client `Controllers.MapVoteController` (started by LeadCatcherController), templates `MapVoteUITemplates` from `ui_mapvote/` (UI build.py `vote_panel` / `map_tile` / `lead_button`). Report `docs/HOS-MAPVOTE-001_report.md`, notes `docs/HOS-MAPVOTE-001/README.md`, playtest shots `docs/HOS-MAPVOTE-001/playtest/`. Installed and playtested; place saved by Hunter 17 Oct 20:18Z.
- [[HOS-CINE-002 Last One Standing]] (17 Oct): 3.4 s cut-scene once per match when one Runner is left (name close-up, VS "N CATCHERS", FACE OFF!), then a pill on later solo crossings. Server `LastStandingService`, client `Controllers.LastStanding` on the shared `Controllers.Cinematic` (comfort clamps for every cut-scene), UI `LastStandingUI` (EOSUI section, export `ui_laststanding/`). Playtested; place not saved.
- **How every thread makes UI** (Hunter, 2026-10-17): `docs/workflow/ui-how-to.md`. The roblox-ui-maker pipeline used for the retention prompts (HOS-RET-001): HTML pages in `ui/build.py`, Hunter approves, export, upload, Builder in Studio, own controller module.
- [[Emote Crate Spin]]: emote crate opening animation (HTML in `UI/web/`, client script in `UI/roblox/`). In the place since 2026-10-16 as `StarterGui.EmoteCrateUI`, played by EmoteController.
- [[docs/HOS-WEP-001 Weapon Skins Plan|Weapon skins plan]] (HOS-WEP-001, 17 Oct): sell the big blades in `ServerStorage["LargerWepModels(shouldsizedown?)"]` as Gem dagger skins at 3.0 studs, a Weapon Crate like the Emote Crate, lobby pedestals using the `swordshitr2` katana loop. Genshin swords, Yamato and the Korblox scythe flagged as IP risk. Preview `docs/HOS-WEP-001/weapon_skins_preview.png`. Waiting on Hunter's OK; nothing built.

## Folders
| Folder | For |
|---|---|
| `Design/`, `Dev/`, `Assets/`, `UI/` | Design notes, technical notes, asset lists, UI notes |
| `Research/` | Reference material (RoClicks guides and code) |
| `docs/` | Delivery reports, reference images; `docs/backups/` for pre-edit backups |
| `ScriptHistory/` | Read-only snapshots of the place's scripts |
| `tools/` | MCP and upload scripts |
