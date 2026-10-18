---
tags: [delivery, egg, incubator]
ticket: HOS-INC-001
date: 2026-10-17
requested_by: Matthew
---
# HOS-INC-001: Animated incubator with a puzzle egg

The lobby incubator (`Workspace.Incubator.Incubator`) is now animated and wired into the egg and shard system. Walking up opens the incubator screen. Each player sees their own egg, built from cracked-shell puzzle pieces as their fill goes up, over a hologram of the finished egg.

![The puzzle egg, whole (test build next to the incubator, mixed rarities)](HOS-INC-001/puzzle_egg_whole.jpg)
![Half built: 9 of 18 pieces, with the inner faces and crack edges showing](HOS-INC-001/puzzle_egg_half_built.jpg)

## What players see
- **Idle animation** (client only; the server's parts never move):
  - The egg turns and bobs.
  - The orbit ring and the floating crystals have been removed for now (18 Oct). The code still animates them if they're put back.
  - The lanterns sway on their chains.
  - The neon strips, beams, runes, sign and lights breathe.
- **Walk-up:** stepping within 11 studs of the egg opens the incubator screen (`EggUIController`'s `openIncubator`), and walking past 14 studs closes it. It only closes a screen the walk-up opened, and it never opens during a match.
- **Your egg:**
  - The egg is cut along jagged crack lines into 18 pieces that fit together: a bottom cap, rings of 5, 6 and 5 pieces, and a top cap.
  - Pieces are placed bottom up, one per 1/18 of fill. Since 18 Oct (Matthew: "have all the shards look the same for color"), every piece wears one look, whatever shard filled it. That look is `PIECE_LOOK` in `IncubatorWorld`, now `"epic"` (purple), taken from the egg shard texture atlas (`EggShardKit` `SA_<rarity>`). The shard flying in still shows the rarity you earned.

    ![All pieces in one look](HOS-INC-001/ingame_one_look.jpg)
  - Every piece that isn't placed yet shows as a ForceField hologram of its own curved mesh. An empty egg is a whole hologram egg with the crack lines showing, and it fills in solid piece by piece.
  - A full egg is solid and glows gold.
- **Shards flying in:** shards earned since the last visit fly from the player's back to the egg one by one when they walk up. As each one lands, its pieces appear just outside the egg and snap into place, with a pulse and a sound. After that the server's list of unseen shards is cleared.
- **Hatch:** the pieces burst outward, tumbling and fading, and the next egg starts.

## Files
| Where | What |
|---|---|
| `StarterPlayerScripts.EOS.Controllers.IncubatorWorld` (new) | All of the above, client side |
| `…IncubatorWorld.EggPieces` (new) | The puzzle generator: crack layout, curved shell pieces with thickness and rims, UVs on the shard atlas; builds the egg from the baked meshes, or from wedge parts as a fallback |
| `ServerStorage.EOSBuild.BakeIncubatorEgg` (new) | `obj()` exports the pieces as an OBJ; `adopt(model)` takes the imported meshes into `ReplicatedStorage.IncubatorEggPieces` |
| `EggUIController` | One line in `init` starts `IncubatorWorld` |
| `IncubatorLogic` | `incubator.unseen` (each settled shard's rarity, capped at 12), `markSeen`, and `view` includes `unseen`. Hatching clears it. |
| `EggService` | New `EOS_Egg.SeenShards` remote (1 s cooldown) calling `IncubatorLogic.markSeen` |
| `EggTests.ProfileIncubatorSpec` | 3 tests for the unseen list |
| `docs/HOS-INC-001/IncubatorEggPieces.glb` | The 18 pieces, ready for Studio's 3D Importer (made from the `.obj` by `tools/build/HOS-INC-001_obj2glb.py`; the importer merges an OBJ's objects into one mesh, so use the `.glb`) |

The Incubator model's `ModelStreamingMode` is `Atomic`, so the client gets it whole.

## The baked egg pieces (done 17 Oct)
The game builds each piece from a baked mesh. A plugin can't upload meshes yet ("CreateAssetAsync … not available yet"), and Studio's importer merges an OBJ's objects into one mesh. So the pieces went through the 3D Importer as `docs/HOS-INC-001/IncubatorEggPieces.glb`, which keeps one node per piece:
- Matthew imported the file with creator **Eggs with Friends**.
- `BakeIncubatorEgg.adopt` moved the 18 MeshParts into `ReplicatedStorage.IncubatorEggPieces` (Piece1–Piece18, attributes `Centre` / `Mid`), and the sizes matched the generator.
- Mesh ids, Piece1 to Piece18: 84269797617090, 88118522965095, 122256290543998, 120066833790496, 127530689738706, 120913288208629, 74531545298493, 113063044109553, 77904836546807, 121436036274647, 107033692907946, 125280533840727, 89072925326374, 109207612983235, 88905020084450, 80226418040872, 73834036291579, 128125464800223.

**If the shape ever changes** (the tuning values below), re-export and re-import:
1. Save `BakeIncubatorEgg.obj()` to the `.obj`.
2. Run `tools/build/HOS-INC-001_obj2glb.py <obj> <glb>`.
3. Import the `.glb` and run `adopt`.

Without the folder, the egg falls back to wedge parts in flat rarity colours.

**Fixed 17 Oct (Matthew: "the eggs are not put together"):** the importer had turned every mesh 180° about Y, so each piece sat in its right spot but faced the wrong way. Reading the uploaded meshes back confirmed the same exact turn on all 18 (0.0000 stud miss). Each baked piece now has a `MeshTurn` attribute that `EggPieces` applies, and `adopt` detects the turn itself on any future import. No re-import was needed.

![In game, 13 of 18 pieces, with the hologram dome on top](HOS-INC-001/ingame_building_13of18.jpg)
![In game, ready to hatch](HOS-INC-001/ingame_ready.jpg)

## Checks (Studio playtests)
- **Fill 11/18:** pieces 1–11 show and the rest are hidden.
- **Walk-up:** the fly-in played, the screen opened, and the server's unseen list was cleared.
- **Ready egg:** 18/18 pieces, hologram fully transparent, gold glow.
- **Hatch:** a pet was granted, every piece part was thrown more than 3 studs out mid-burst, then 0 pieces showed and the hologram came back.
- **No errors** from IncubatorWorld in the logs.
- **Mesh pieces:** checked in edit mode, both whole and half built, and in game after the import: 18 baked MeshParts with rarity textures, 7 of 18 shown at fill 7, all 18 when ready, all 18 thrown out by the hatch.
- **Hologram:** at fill 7, 7 pieces are solid and 11 are hologram. A full egg is 18 solid and 0 hologram. After a hatch, 0 are solid and 18 are hologram again.
- **EggTests:** 75 passed, 0 failed. G04 and E03 also print FAIL lines; they did before this ticket too (old pieces path).

## Old egg removed (17 Oct, Matthew: "we just need a curved hologram mesh and the new fragments")
- **Removed:** the model's faceted egg shell `A09_EggShards` (160 parts, the first hologram) and its neon core `A09_EggCore` (6 discs).
- **Backups:** the originals are in `ServerStorage._Backups.HOS-INC-001_2026-10-17_IncubatorOldEgg`, and a part dump is in `docs/backups/HOS-INC-001_2026-10-17/`.
- **New marker:** `A09_EggCentre`, an invisible part at the old core's centre (−51.30, 16.31, 1494.97). The client places the egg on it.
- **Hologram:** a ForceField copy of each piece mesh, 1% larger, in light lavender (225, 175, 255). It fades out as its piece snaps in and comes back after a hatch.

![Empty egg: all hologram](HOS-INC-001/ingame_hologram_empty.jpg)

## Test bench (Studio only)
`ServerScriptService.HOS_IncubatorTestBench` (server) and `StarterPlayerScripts.HOS_IncubatorTestBenchCamera` (camera) do nothing outside Studio. Studio profiles live in their own datastore.

When you press Play, the bench:
- empties your egg (attribute `ResetOnPlay`)
- gives you the fragments in the `Shards` attribute (default `common,rare,rare,epic,legendary`) as unseen fragments
- puts you 17 studs in front of the incubator, facing it

Walk up and they fly in.

**Chat commands:**
- `!shards`: give the `Shards` list again
- `!shards epic legendary`: give those rarities
- `!shards 5`: give 5 random fragments
- `!full`: fill the egg to ready
- `!reset`: empty the egg
- `!tp`: go back in front of the incubator

Fragments fly in when you walk up, or straight away if you're already standing at the incubator. Set the `Enabled` attribute to false to turn the bench off.

Checked in a playtest:
- **Spawn:** you start at the spot, facing the incubator, with 5 fragments waiting.
- **Walk-up:** the fly-in placed 13 of 18 pieces and the screen opened.
- **`!full`:** brought the fill to exactly 18. `DataService.update` runs its callback twice; the first version of the bench didn't account for that and gave double.

## Changes 18 Oct (Matthew)
- **Second lantern:** the left outside lantern is mirrored onto the outside of the right pillar (`A09_LanternBracket_R`, `A09_LanternRight_Chain/_Frame/_Glass/_Light_OPTIONAL`). It sways like the left one.
- **Bigger egg:** `A09_EggCentre` moved up to y 17.05 and has a new attribute `EggScale` = 1.7. The egg now spans y 13.1–20.6, about 6 studs wide, filling most of the arch. Change `EggScale` in Studio to resize it; the client scales the pieces, their holograms and the fly-in target.
- **Removed for now:** the pink floating crystals (`A09_FloatShards`), the white orbit rings (`A09_OrbitRings_OPTIONAL`), and the two lights left behind by the deleted interior lanterns. They're in `ServerStorage._Backups.HOS-INC-001_2026-10-18_IncubatorRingsCrystalsStrayLights`.
- **Fragments while standing at the incubator:** these now fly in too. Before, the fly-in only started when you stepped onto the platform.

![Front, with both lanterns and the bigger egg](HOS-INC-001/ingame_front_big_egg.jpg)

- **Sign:** the INCUBATOR plaque is now a trapezoid, 6.6 studs wide at the bottom and 5.0 at the top (`A09_Sign.A09_SignPlaque`, a SubtractAsync union). It leans back 40° from its front-bottom edge, so the text faces up at players.
  - The text panel narrowed to 5.0 studs, and the sparkles moved in to match.
  - The egg-icon block that sat on top of the plaque, and its neon outline, are removed (Matthew).
  - Rebuild or tweak (lean, top width) with `tools/build/HOS-INC-001_incubator_sign.lua`. It always starts from the originals in `ServerStorage._Backups.HOS-INC-001_2026-10-18_IncubatorSign`.

![The leaned trapezoid sign](HOS-INC-001/sign_trapezoid.jpg)

## Notes
- **Why the pieces are baked:** building the pieces at runtime with EditableMesh worked in Studio, but a player's client ran out of its EditableMesh memory budget after 8 of the 18 pieces, and phones get less. Baked meshes have no such limit and don't need the "Allow Mesh / Image APIs" setting.
- **The egg HTML** lives on Hunter's PC and isn't in the repo, so the look follows the in-game `EggShardKit` shards and their texture atlas (`HOS-INC-001/shard_atlas_samples.png`: common, rare, epic, legendary).
- **Hunter's egg system:** the `unseen` list is the only change. The pre-edit scripts are in `docs/backups/HOS-INC-001_2026-10-17/`.
- **Tuning** (top of `EggPieces`): egg size `H`/`R`, shell thickness `TH`, crack width `GAP`, crack rings `RINGS`, pieces per ring `BANDS`. Changing any of these means re-exporting and re-importing the OBJ.
