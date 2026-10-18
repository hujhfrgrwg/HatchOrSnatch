---
tags: [delivery, map]
ticket: HOS-MAP-001
date: 2026-10-17
requested_by: Matthew
---
# HOS-MAP-001: Haunted Graveyard arena

A halloween sharks-and-minnows arena built from Matthew's approved concept (`docs/concepts/HOS-MAP-001_halloween_arena_concept.webp`). The preview sits next to the other maps, and since 17 Oct the map is in the game's rotation and map vote (see **In the game** below).

![Overview from the concept's camera angle](HOS-MAP-001/overview_concept_angle.jpg)

The overview was taken with the Ground model selected, which is where the outline comes from. Later screenshots were blocked because a playtest was running.

## Where it is
- **Studio:** `Workspace._MapPreview.Preview_Graveyard`, centred at x 1313.25, z −390. That's the next slot east of `Preview_Stadium`, at the same 430-stud spacing.
- **Builder:** `ServerStorage.EOSBuild.Maps.BuildGraveyard` (new). It uses the shared `ArenaFrame`, like the other map builders.
- **Definition:** `MapDefs.Graveyard`: Stadium sizes (field 192 × 140, `FIELD_HALF_X` 96, `ZONE_DEPTH` 24, `HALF_Z` 70), title "Haunted Graveyard", lobby colours from the field and cliff.
- **Rebuild the preview:** require `MapDefs` and `BuildGraveyard`, call `build(folder, MapDefs.Graveyard)`, then pivot the result by (1290, 0, 0). The build is seeded, so it comes out the same every time.

## What's in it
| Area | Build |
|---|---|
| Field | Plain dark purple studded floor with a faint checker. No cover and no colour patches, per Matthew. |
| Safe zones | A is purple and B is orange. Glow strips run along both long edges of each lane. Each zone is simply the floor past the field; past the zones is out-of-bounds paving. No chalk lines or flags. The tall back walls are now a low stone kerb. |
| Fence | Wooden ranch fence around the play area. Every fourth post is a stone pillar with a candle on top and candles at its foot. |
| Lantern posts | 5 posts with stone feet, purple crystal tops and hanging orange lanterns: one at each end of both zone edges and one by the shrine. |
| Walkways | 38 gravestones, 24 wooden crosses on grave mounds, 28 jack-o'-lanterns, 36 candle clusters and 19 stone-block ruins. Nothing overlaps. |
| Set pieces | A red stepped-roof shrine (back-left, lit inside, purple crystal on top) and a bubbling purple cauldron on a stone ring (east). |
| Loose fences | 5 standalone fence pieces near the boundaries (2 broken) in `Scenery.LooseFences`, for moving or copying. |
| Island | Paved top over a stepped cliff, plus 114 chunky stone columns hanging under the edges, like the concept's underside. |

Not built, by request: trees, the sky, moon, castle and clouds, other off-island assets, and lighting changes. The lanterns, cauldron and fence candles carry their own small PointLights, the same way `Kit.lamp` does on the other maps.

## Gameplay checks (done in Studio)
- Downward raycasts across both zones, including right on the glow strips, hit `Pad` with `Side` = A or B. Raycasts on the field hit `Field`.
- The glow strips have `CanQuery`, `CanCollide` and `CanTouch` off, so they can't block zone detection.
- There are 2 `EOS_Gate` gates, 2 `EOS_CatcherWall` walls and 4 invisible `ArenaWalls`. These are the same `ArenaFrame` pieces every map uses.
- The map attributes (`Map`, `MapTitle`, `FIELD_HALF_X`, `ZONE_DEPTH`, `HALF_Z`, `WALL_HEIGHT`, `CENTER`, `LobbyTop`/`LobbyBase`) are set like the other maps.

## Build checks
- **Clipping:** no prop overlaps another prop, the fence or the set pieces.
- **Flicker:** an automated sweep for shared face planes found 0 visible pairs. The fixes before it reached 0:
  - The fence corners had doubled posts and rails crossing at the same height (the `ArenaFrame` fence does this on every map).
  - The shrine's window sills and lantern bracket shared faces.
  - The cauldron's puddle overlapped its stone ring.

## Changes after review (17 Oct, Matthew)
- **Removed the glowing pool on the lobby side**, along with its stone rim, the broken fence and candles in it, its lantern post and the cross beside it. The walkway props now fill that space. Because the props are placed in sequence from one seed, removing the pool also moved where every walkway prop lands.
- **Muted the orange field patches** to rgb(136-156, 78-92, 66-68). They're still orange but sit closer to the floor's darkness, so they tint it instead of popping.
- Re-ran both checks after the rebuild: 0 overlaps and 0 visible shared faces.
- Pre-change builder: `docs/backups/HOS-MAP-001_2026-10-17/ServerStorage.EOSBuild.Maps.BuildGraveyard.before-pool-removal.lua`.

- **Removed the field colour patches altogether** (Matthew, after seeing the muted ones). The field is now plain. Props moved again for the same seed reason, and both checks are still 0. Pre-change builder: `docs/backups/HOS-MAP-001_2026-10-17/ServerStorage.EOSBuild.Maps.BuildGraveyard.before-patch-removal.lua`.

![Front walkway without the pool](HOS-MAP-001/front_walkway_no_pool.jpg)
![Plain field](HOS-MAP-001/plain_field.jpg)
![Shrine close-up](HOS-MAP-001/shrine_closeup.jpg)
![Zone B at player height](HOS-MAP-001/lane_B_player_height.jpg)

## In the game (17 Oct, Matthew: "make sure the game pulls from the one in workspace")
**Matthew's hand edits in the preview:**
- The 4 zone-edge lantern posts were nudged about 1 stud onto the apron and turned so their lanterns hang along the zone edge.
- The 4 invisible `ArenaWalls` were pulled in off the fence: N/S to z ∓73.65 / +73.85 and E/W to x ±125.15 from the map centre.

What was done:
- **Game copy:** `ServerStorage.EOS_Maps.Arena_Graveyard` is a copy of `Workspace._MapPreview.Preview_Graveyard` moved back to the map centre (23.25, 0, −390). The game only ever loads maps from `EOS_Maps`.
- **Code matches the hand edits:** `BuildGraveyard` now places those lantern posts and walls the same way. A part-by-part diff of a fresh code build against the preview matched all 1,825 parts, worst difference 0.0004 studs. Rebuilding from code won't undo the edits.
- **`BuildAll`** now makes `Arena_Graveyard` by copying the workspace preview (with `BuildGraveyard` as the fallback if the preview is gone). Before this, running `BuildAll` would have wiped the graveyard out of `EOS_Maps`. Later hand edits to the preview reach the game the next time `BuildAll` runs, or when the same copy is repeated by hand.
- **`MapService`:** `"Graveyard"` added to `ORDER` and `TITLES`. Without it the map would never be picked, even when stored.
- **`MapVoteController`:** tag "GRAVES + PUMPKINS". A map with no photo now shows an empty photo slot instead of the photo the tile showed last.
- **Playtest check (server):**
  - `MapService.available()` lists Graveyard.
  - `MapService.set("Graveyard")` swaps it in, and Layout gets field half-length 96 and centre (23.25, 0, −390).
  - Zone rays hit Pads A and B, and the lobby top takes the map colour.
  - Swapping back to Sunny Cove works. No map errors in the log.
- Backups of all four scripts are in `docs/backups/HOS-MAP-001_2026-10-17/`.

## Not done yet / for Matthew or Hunter
- **Map-vote photo:** `docs/HOS-MAP-001/map_graveyard_thumbnail.png` (858 × 452, the vote tile's 429:226 shape) is ready to upload with `tools/upload/upload_assets.py`. Then add `["map_graveyard"] = "rbxassetid://<id>"` to the `icons` table in the `MapVoteUI` AssetIds modules (`MapVoteController.Templates.AssetIds` is the one the controller reads). Until then the Graveyard tile shows an empty photo slot.
- **Out-of-bounds ground:** it's stone paving to match the concept. For grass instead, change `G.pave` and `G.pave2` in `BuildGraveyard`.
- **PetLab overlap:** `EOS_PetLab` floats about 18 studs above the island's south-east corner. Fine for a preview, but move one of them if it gets in the way.
- **ScriptHistory:** this ticket snapshotted `BuildGraveyard` and `MapDefs`. The full-place snapshot was taken afterwards under HOS-LB-001.
- **Backups:** the pre-edit `MapDefs` and the builder from before the pool was removed are in `docs/backups/HOS-MAP-001_2026-10-17/`.
