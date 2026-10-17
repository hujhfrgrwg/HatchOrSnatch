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
  - The orbit ring turns the other way.
  - The floating crystals circle, bob and spin.
  - The lanterns sway on their chains.
  - The neon strips, beams, runes, sign and lights breathe.
- **Walk-up:** stepping within 11 studs of the egg opens the incubator screen (`EggUIController`'s `openIncubator`), and walking past 14 studs closes it. It only closes a screen the walk-up opened, and it never opens during a match.
- **Your egg:**
  - The egg is cut along jagged crack lines into 18 pieces that fit together: a bottom cap, rings of 5, 6 and 5 pieces, and a top cap.
  - Pieces are placed bottom up, one per 1/18 of fill. Each piece wears the rarity of the shard that filled it, using the same texture atlas as the egg shards (`EggShardKit` `SA_<rarity>`).
  - Until the egg is whole, a lavender hologram egg (the model's wedge shell, in ForceField) shows what's being built, and the core glows brighter as it fills.
  - A full egg drops the hologram and glows gold.
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

## To do in Studio: import the egg pieces (one time)
The game builds each piece from a baked mesh. I generated them, but a plugin can't upload meshes yet ("CreateAssetAsync … not available yet"), so they need one pass through the 3D Importer. Until then the egg uses the fallback: the same cracks and animation, drawn with wedge parts in flat rarity colours and without the shard texture.

1. Get `docs/HOS-INC-001/IncubatorEggPieces.glb` from the `matthew` branch.
2. In Studio, go to **File → Import 3D** and pick the file. Set the creator to the group **Eggs with Friends**, then import. The preview should list `Piece1` … `Piece18` as separate parts.
3. In the command bar, run:
   `print(require(game.ServerStorage.EOSBuild.BakeIncubatorEgg).adopt(workspace.IncubatorEggPieces))`
   This checks each piece's size, moves the pieces into `ReplicatedStorage.IncubatorEggPieces` with the attributes the client needs, and removes the empty import model.
4. Save the place. Or ask me (or a later session) to do steps 3 and 4 and check the result in a playtest. That includes checking that the shard texture isn't upside down; if it is, the fix is a one-line change to the OBJ export.

## Checks (Studio playtests)
- **Fill 11/18:** pieces 1–11 show and the rest are hidden.
- **Walk-up:** the fly-in played, the screen opened, and the server's unseen list was cleared.
- **Ready egg:** 18/18 pieces, hologram fully transparent, gold glow.
- **Hatch:** a pet was granted, every piece part was thrown more than 3 studs out mid-burst, then 0 pieces showed and the hologram came back.
- **No errors** from IncubatorWorld in the logs.
- **Mesh pieces:** checked in edit mode, both whole and half built (screenshots above). The cracks line up, the inner faces and rim show, and the rarity textures map onto the outer faces.
- **EggTests:** 75 passed, 0 failed. G04 and E03 also print FAIL lines; they did before this ticket too (old pieces path).

## Notes
- **Why the pieces are baked:** building the pieces at runtime with EditableMesh worked in Studio, but a player's client ran out of its EditableMesh memory budget after 8 of the 18 pieces, and phones get less. Baked meshes have no such limit and don't need the "Allow Mesh / Image APIs" setting.
- **The egg HTML** lives on Hunter's PC and isn't in the repo, so the look follows the in-game `EggShardKit` shards and their texture atlas (`HOS-INC-001/shard_atlas_samples.png`: common, rare, epic, legendary).
- **Hunter's egg system:** the `unseen` list is the only change. The pre-edit scripts are in `docs/backups/HOS-INC-001_2026-10-17/`.
- **Tuning** (top of `EggPieces`): egg size `H`/`R`, shell thickness `TH`, crack width `GAP`, crack rings `RINGS`, pieces per ring `BANDS`. Changing any of these means re-exporting and re-importing the OBJ.
