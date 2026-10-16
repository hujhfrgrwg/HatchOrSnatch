---
tags: [dev, ui, social]
updated: 2026-10-16
---
# Emotes, Servers and Spectate

Three lobby systems were added on 16 Oct, modelled on Huss Valley's server list, emote wheel and spectate bar. Hunter sent screen recordings of them. Each one has its own client controller, so the UI controller doesn't grow. The designs are pages in `ui/build.py`: `emotes`, `emote_wheel`, `servers` and `spectate`. Backups of the replaced scripts are in `docs/backups/HOS-UI-SOCIAL-001_2026-10-16/` and `docs/backups/HOS-EMOTE-001_2026-10-16/`.

## Emotes (HOS-EMOTE-001)
- **51 R6 emotes** come from `Workspace["52+ Emotes (R15/R6)"]`. That pack also contains the "20+ R6 Emotes" pack. The game is R6 only.
- **One list:** `roblox/game/emote_catalog.json` has the id, name, rarity and source clip for each emote. `ReplicatedStorage.EOS_Emotes` holds the clips, and `Shared/EmoteConfig` is generated from the catalogue.
- **Rarities:**
  - 16 Common at 2.875% each
  - 16 Rare at 2% each
  - 12 Epic at 1.25% each
  - 7 Legendary at 1% each
- **Renamed** to avoid Fortnite and TF2 names:
  - Take the L → Loser Dance
  - Orange Justice → Orange Sway
  - Kazotsky Kick → Cossack Kick
  - The earlier DaBaby / BTS swaps stay (Rap Bounce, K-Pop Dance).
- **Published:** all 51 clips are Animation assets owned by group 228184582, all approved. They were exported with the Studio MCP's `export_rbxm` and uploaded with `upload_asset`. The ids are in `roblox/game/emote_anim_ids.json` and in `EmoteConfig`, so emotes play in live servers.
- **Play-once clips:** six clips don't loop (`once = true`): Trick or Treat, Dramatic Bow, Threaten, Lose It, Shadow Emerge and Chill Sit. They play once, then the emote ends. The two zero-length poses hold until you move.
- **No props:** Ice Cream Cart, Couch Nap, Toilet Sit, Surfer, Coconut Launch, Reaper's Ride and Sunbath are mimed.
- **Songs:** every emote has a licensed APM track (Roblox's library). The 36 added on 16 Oct were picked to fit each emote's mood (`EmoteConfig`; all checked to load in Studio). For example: Surfer gets surf rock, Head Juggle a circus march, Reaper's Ride heavy metal, Blossom Break koto, Cossack Kick balalaika.
- **Emotes panel:**
  - My Emotes shows a card per owned emote with a live preview of your avatar, plus PLAY and EQUIP buttons. YOUR WHEEL has 6 slots: pick a slot, then EQUIP.
  - The Emote Crate tab has the odds board for all 51, OPEN for 250 Gems, a reel, then the reveal.
- **Emote wheel (G):** your six emotes sit around a centre disc. Clicking a slot or pressing 1-6 plays it; there are also STOP, MY EMOTES and GET EMOTES. It's lobby only.
- **The wheel is saved:** `profile.emoteWheel`, set through `RequestEmoteWheel` and cleaned by `EmoteConfig.cleanWheel`. A new crate win fills the first empty slot. Older saves fill with the first six emotes owned.

## Servers (HOS-SERVERS-001)
- **Registry:** `ServerListService` writes this server to the MemoryStore sorted map `EOS_Servers_v1` every 15 s, with a 45 s expiry. Each entry has players / max, the country and city of the server, the match phase, and the average ping of its players.
- **Location:** read once from `http://ip-api.com/json/`. **This needs Game Settings → Security → Allow HTTP Requests**, which is off now, so servers show "Unknown". Studio's command line can't change it; Hunter turns it on.
- **Panel:**
  - Your server is pinned first. Country filters are built from the list.
  - Sort by players (full servers sink) or by ping, 5 rows a page, REFRESH.
  - Your ping is live; the others are player averages.
- **Joining:** JOIN calls `TeleportAsync` with `ServerInstanceId`. It works in the live game only, between matches, and never into a full server.

## Spectate (HOS-SPECTATE-001)
- **The pill:** a SPECTATE pill under the lobby timer shows while a match runs (role reveal, crossing, wave end) and you're not in it.
- **Targets:** real players in the match first, then NPC Runners. NPC names come from their overhead tag.
- **The bar:**
  - ‹ › (or ← → / LB RB) switch player.
  - FOLLOW uses Roblox's camera on that player.
  - FREE CAM (F) flies: WASD, Q/E, right-drag to look, Shift for speed, the gamepad sticks too.
  - EXIT (or Esc / B) ends it.
- **While watching:** the HUD hides, your character's root is anchored (the game has no PlayerModule to switch off) and Space is sunk.
- **It ends itself** when the match ends or you're put into one.
- **Tested** in a 2-player playtest on 16 Oct: the pill, 22 targets, follow, next, free cam movement, and exit restoring the camera, HUD and movement.

## HUD changes that came with these
- **The rail:** SHOP, PETS, EMOTES (G), AFK and HUNT. AFK and HUNT sit on a grey plate, with a coloured `PlateOn` while on: AFK blue, Hunt purple.
- **HUNT shows only in private servers**, as does the Settings "Volunteer To Hunt" row; UI Colour moves up into its place in public servers. `MatchService` honours Volunteer only in private servers and in Studio.
- **SERVERS** sits in the top right, next to STATS.
- **Buttons** have a 10 px radius on both ends (`sport.css .cb`); the old 4 px read as square on the dark left end.
