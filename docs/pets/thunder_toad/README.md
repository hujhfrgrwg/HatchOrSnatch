# Thunder Toad (Tempest, Common): HOS-PET-016

Built to Hunter's model sheet, `docs/pets/concepts/thunder_toad_model_sheet.png`. It follows the HOS-PET-014 texture standard (painted detail + PBR + emissive) and is **imported and wired into the place**.

## Review files
| File | What |
|---|---|
| `thunder_toad_preview.mp4` | in-game clip, 10.6 s: idle, walking beside the player, Runner **Shockwave** (summon, croak, yellow shock ring with branching ground lightning and rock debris, catchers knocked back), Catcher **Electric Ball** (summon, crackling orb rolls to the Runner, shock burst) |
| `thunder_toad_ingame_idle / walk / shockwave / electric_ball.jpg` | stills from the clip |
| `thunder_toad_ingame_daylight_L1_L3.jpg` | L1 and L3 in Studio daylight (glowing markings, crest, toe pads; L3 crest gem and sparks) |
| `thunder_toad_L1_front / three_quarter / side / back.jpg`, `_L2_`, `_L3_` | Blender turnaround (colour bake only; the Studio stills show the full PBR look) |
| `thunder_toad_head_closeup.jpg`, `_head_front.jpg` | eyes: big glossy yellow, dark pupils, white highlights under the brow ridge |
| `thunder_toad_ability_pose_three_quarter.jpg` | the croak: rears back, throat sac swells, mouth opens |

## Model (tools/pets/thunder_toad.py)
- **Look:**
  - A stout, round cobalt toad (#1E4FD8) with a cream belly and throat (#F7E7B0). Its underside darkens toward navy in the painted gradient.
  - Big yellow eyes under a heavy brow ridge.
  - Flat yellow lightning-bolt markings (#FFD93B) on the back, flanks, head sides and thighs.
  - A three-spike yellow crest behind the head, yellow warts, and round yellow toe pads.
  - The open mouth (dark red with an orange tongue) sits hidden inside the head and slides out on the croak.
- **Levels:**
  - L2 adds bolts on the arms and a taller crest spike.
  - L3 adds gold back spikes and a crest gem, plus a yellow aura (PointLight + sparks on the L3 mesh).
- **Triangles:** L1 1,923 / L2 1,967 / L3 1,993 (budget 2,000).
- **Rig:** 16 bones: Root, Body, Head, Throat, Mouth, Tail (unused), arms and legs U/L ×2.
- **Animations:** `ToadAnims`: Idle (throat pumps), Walk, Run (hop-run), Hop, Ability (the croak).
- **Texture standard:**
  - Painted colour map: mottling and a top-lit gradient in every area.
  - Normal map from a smoothed copy, plus roughness (glossy wet skin, satin belly, glossy eyes).
  - Emissive mask on the markings, crest and toe pads, tinted yellow. Strength: body 1.6 / L2 2.2 / L3 2.6.
- **Assets:** Model 125164665550745; every map id is in `docs/VFX-LEDGER.md`.

## In the place
- **Template:** `ReplicatedStorage.EOS.Assets.Pets["Thunder Toad"]`, BaseScale 0.8.
- **Registered in:**
  - `PetModel.RIGGED`
  - `PetRig.MODULES` + `PetRig.ToadAnims`
  - `PetBehaviors.MODULES` → `Controllers.ToadPet` (source `tools/pets/ToadPet.lua`)
  - `EconomyConfig.EXTRA_SPECIES` (Tempest)
- **Summon:** on every ability press, both roles. The toad pops up at your front-right and croaks, `VFX.ToadSummon_L1-3` flashes yellow, then it shrinks into you. This is visual only; the ability fires on the press.
- **Its own effects** (`AbilityCosmetics.SPECIES["Thunder Toad"]`); the archetype defaults are untouched:

| Role | Ability | Templates | Look |
|---|---|---|---|
| Runner | Shockwave (Pulse) | `ToadPulseCharge`, `ToadPulseBlast`, `ToadKnockHit` | yellow charge ripples; blast = yellow shock ring, branching lightning on the ground (AllVFX `goodcrack`, glowing), rock debris (AllVFX rock), yellow-white bolts and stars |
| Catcher | Electric Ball (Storm Ball) | `ToadStormBall`, `ToadStormBounce`, `ToadStormHit` | blue rim shell, yellow glowing core and yellow lightning cage, yellow spark trail; shock burst with ground bolts on contact |
| Sound | croak | `ToadCroak` (sfx override on PulseCharge) | Pro Sound Effects "Comic Frog Croaks Ribbit 41" (9113859723), from Roblox's licensed library |

- **Opponent readability:** the ball keeps its size, speed and yellow floor scorch, and `Slowed` stays the default.
- **Export:** `ThunderToad_InPlace.rbxm` holds the template and all Toad effect templates.


## v2 pass (17 Oct, after review against the sheet)

**Model** (L1 1,937 / L2 1,943 / L3 1,963 tris)
- **Finish:** a glossy, rounded vinyl-toy look. Smooth shading, higher-segment head, body, limbs and eyes; blue roughness 0.18, softer cream.
- **Eyes:** round and large, with a big round dark pupil, one large and one small white highlight, and a warm rim. These are painted into the eye texture as true circles, so no hex shapes and no orange ring. The eyes sit forward on top of the head under a heavy brow angled down toward the centre.
- **Mouth:** a wide grin line curving up at the corners, with the cream throat below it. No nostril dots.
- **Markings** (all glow through the emissive mask): one big bolt down the back, a bolt on each flank, thigh and foreleg, round warts, and the crest.
- **Limbs:** chunky and rounded, with round yellow toe-pad domes.
- **Asset ids:** Model 130646365247241; map ids are in `docs/VFX-LEDGER.md`. Meshes are set to RenderFidelity Precise.

**Shockwave**
- Pulled back from white: Flash halved, no beige dust.
- The rings and branching ground bolts read yellow on the sand.
- 8 small dark-grey rocks.
- The toad stays visible during the croak.

**Electric Ball** (per-pet template; the default storm ball is untouched)
- The scorch strip, dark floor beams and dust are removed.
- Blue rim with blue seams, plus a flickering yellow lightning-bolt core (AllVFX lightning sprite).
- The hit no longer has the mud-coloured smoke.

**Previews**
- `thunder_toad_vs_sheet.jpg`: the sheet's 3/4 view and close-up next to Studio stills.
- `thunder_toad_studio_three_quarter.jpg` and `thunder_toad_studio_closeup.jpg`.
- `thunder_toad_preview.mp4` (re-recorded) and the `thunder_toad_ingame_*.jpg` stills.

**Touch-up (v8, Model 72829019761560; L1 1,975 / L3 1,995 tris)**
- One big yellow lightning crest, solid from both sides.
- Warmer cream, softer and thinner navy grin, and brows blended into the eye bumps.
- Rounder toe-pad domes.

**Remaining gaps against the sheet**
- The cream still reads slightly grey where it's in shade in Studio's daylight.

## Not done / next
- **No live playtest:** FACEOFF! had its own test running, and the two places share server.rbxl, so starting one would clash. The clip is staged in edit mode.
