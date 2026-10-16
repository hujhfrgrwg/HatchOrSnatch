---
tags: [design, ui]
updated: 2026-10-16
---
# UI redesign

Following `roblox-ui-maker`: the UI is designed in HTML first, Hunter approves it, and only then is it exported to a real ScreenGui in Studio. **Status (16 Oct): round 3 "sport" (`ui/styles/sport.css`, shots in `docs/ui/round3/`) is liked ("looks great so far"). Hunter's ChatGPT icons are in (40 of 45; `safe`, `catcher`, `runner`, `hunt`, `afk` still use the drawn stand-ins until they arrive as files). Next: Studio import. Nothing has changed in Studio** (a temporary photo-booth GUI was used to shoot the pets, then removed).

## History
- **Round 1 (neon), 15 Oct: rejected.** Hunter: "great job copying it, but this UI doesn't match our game or its theme at all." The lesson went into the ui-maker LESSONS: check a reference against the game's own world before building from it. The source is kept as `ui/build_neon_round1.py`, with shots in `docs/ui/round1/`.
- **Direction board, 15 Oct:** `docs/ui/direction_board.jpg`.
- **Round 2 (candy), 16 Oct:** Hunter picked the pink/purple "Quests" reference (`ui/ref_candy.png`) and asked for everything, premium, with nice icons. Hunter's correction: use the real pets and eggs from `Workspace.FWP_PetShowroom`, not `PetModel`/`EggModel`.

## Round 2: what's in it
Overview: `docs/ui/round2/_overview.jpg`. Every page is in `docs/ui/round2/`.

| Page | What it covers |
|---|---|
| `style` | The reference vs our lobby, header accents, icons, eggs, buttons |
| `hud` | Lobby: Quests and Incubator (with badges), first-pet goal pill, timer, Stats and Settings, rail (Shop, Pets, AFK, Hunt), Gems and Gold, equipped pet ability card |
| `hud_match` | Match: role, crossing chip and timer, Runner and Catcher counts, clean-streak pips, egg level 1–4 and the piece it pays, ability cooldown, Dash, steal feed. Economy hidden (GDD 14) |
| `hud_phone` | Bigger targets, thumbs kept clear |
| `quests` | 2 daily quests with lobby art, progress, reward slots, Claim and Claim All, reset timer (QuestConfig) |
| `incubator` | Pieces, first-pet path (Start → Match 1 → Match 2 → Hatch), 9 families in a 3×3 grid (wave 1 live, waves 2–3 greyed with a lock), what the ability does as Runner and as Catcher, species ladder (Common/Rare/Epic, Crowned locked), recipes 2/3, 3/4, 5/6, free first choice |
| `incubator_later` | After the first pet: collection progress per family, Random ×2 vs Choose ×3 |
| `pets` | Collection grid (rarity frames, ★ mastery = showroom T1/T2/T3), preview, equip, favourite |
| `shop`, `shop_gems` | Gold items (EconomyConfig + the GDD's 500-Gold emote) and Gem items (incl. GDD showcase / override / prestige), owned, unaffordable and selected states |
| `shop_robux` | Robux Gem packs at GDD prices. **Not live**: stays hidden until you approve developer products |
| `stats`, `settings` | Your record; real settings with ON/OFF, the UI Colour picker and tabs |
| `ui_colour` | The UI Colour setting: Default (one colour per screen) or one colour for every panel, shown on Quests in four choices |
| `results` | Winner banner, podium with pets, top thief, Gold breakdown (GDD formula), Gems, piece, recipe progress |
| `hatch` | The new-pet reveal |
| `templates` | Match banners (Runner/Catcher/Safe/Caught/Stolen), toasts, confirm dialog |
| `states` | Every button colour and state, rarity slots, mastery tiles, bars, tags, empty states |

## Data assumptions to confirm
- **Families (decided 15 Oct, HOS-ABIL-001):** nine, in `FWPPetData.Pools` and `POOLS`/`WAVE` in `ui/build.py`. Wave 1 (launch): Double Dash, Decoy, Scout. Wave 2: Brake, Invisibility, Wall. Wave 3: Shield, Spring, Pet Tackle. The Pets page only shows wave-1 pets (11). Scout, Brake and Spring use drawn stand-in icons until the ChatGPT ones arrive.
- **Rarity per pet:** 1st pet in a pool = Common hatch, 2nd = Rare, 3rd = Epic, the rest = Crowned (deferred). **T2/T3** showroom variants are shown as ★★/★★★ mastery colourways.
- **Egg per level:** L1 Basic, L2 Shiny, L3 Cosmic, L4 Golden (survivor). Piece icons are drawn to match those eggs.
- Cooldowns and some text on the Pets page are placeholders (no config exists yet for the new abilities).

## UI Colour setting (decided 15 Oct)
- Settings → Game → UI Colour: Default, Purple, Pink, Blue, Green, Gold, Red, Steel. Default keeps one accent per screen; any other choice sets the accent of every panel (banner, rim, glow). Buttons and rarity colours don't change, so meaning stays readable.
- In HTML: `UI_COLOUR` in `ui/build.py` overrides `acc` in `panel_sport()`; swatches are `.sw` in `ui/styles/sport.css`.
- In Studio (at import): store the choice in the player's profile (looks only, no gameplay effect), and have `UIController` re-tint the panel banner and rim when it changes. The banner art is exported once per accent, or as a white version tinted with `ImageColor3`.

## How it's made
- Style: `ui/styles/candy.css`, with Fredoka (Roblox **FredokaOne**). One accent per screen: Quests pink, Incubator lime, Pets sky, Shop gold, Settings/Stats violet. A faint stud texture in header bands ties the UI to the world.
- Pets and eggs: `ui/tools/photo_booth.luau` (temporary ViewportFrames on magenta in Studio) → `capture_screenshot` → `ui/tools/key_booth.py` (key out the magenta) → `ui/tools/outline.py` (shared ink edge and shadow). That gives 114 images: 29 pets × 3 colourways, 2 huge pets, 7 eggs.
- Icons: Hunter's ChatGPT set (prompt: `docs/ui/chatgpt_icon_prompt.md`). Originals go in `ui/icons_ai/inbox/<slug>.png|webp` (not committed); `python3 tools/ingest_ai_icons.py` trims them to 512 px in `ui/icons_ai/`, and `python3 tools/icon_variants.py` makes recoloured copies for items that share a drawing (Ember/Rainbow trail, Frost/Sunset case, Gold ability FX). `build.py` prefers `icons_ai/<slug>.png` over the 47 drawn stand-ins in `ui/icons/` (`tools/icons_svg.py` → `render_icons.mjs` → `outline.py`).
- Icons that drifted from the brief (ChatGPT's own note): `case` is a loot chest, not a crystal shell round an egg; `entrance` is a portal, not a lightning strike (the item is "Bolt Entrance"); `abilityfx` is a swirl, not a spray can; `emote` is a cheering figure, not a glove. All are usable; `case` and `entrance` are worth regenerating.
- Images pasted into chat while Claude is mid-task don't reach the cloud session's disk. Send icons as zips or attachments in a normal message.
- Textures: ui-resources.com (halftone, grid, scratch, stud, sunbursts, shines). Credits are in `ui/tools/textures.json`; the files are fetched by `tools/fetch_textures.py` and not committed.
- Rebuild: `cd ui && python3 tools/fetch_textures.py && python3 tools/icons_svg.py && node tools/render_icons.mjs && python3 tools/outline.py && python3 build.py`, then serve and open `index.html`. `node tools/shoot.mjs` renders `shots/`.

## Before import (after approval)
- Roblox caps images at 1024 px, so big panels need 9-slice header art plus native frames for the body.
- Check FredokaOne in Studio, then run the exporter (`export.mjs` → `gen.py` → uploads → `bundle.py` → `import_rbxm`) and rewire `UIController` to the new templates, one screen at a time.
