# Bastion Beetle (Guardian, Common): HOS-PET-013

Built to Hunter's concept library sheet (`docs/pets/concepts/`): a chunky golden-armoured beetle with segmented gold shell plates and rim spikes, a gold helmet with a forked horn, a blue face with big yellow eyes, gold legs with blue joints, and teal accents. It follows the Crow / Kitsune pipeline and is **imported and wired into the place**.

## Review files
| File | What |
|---|---|
| `bastion_beetle_preview.mp4` | in-game clip, 9.9 s: idle, walking behind the player, then Runner **Shell Shield** (summon, shell rises, bubble, shatters on a tag), then Catcher **Horn Tether** (summon, tether from the horn, yank) |
| `bastion_beetle_ingame_idle / walk / shield / tether.jpg` | stills from the clip |
| `bastion_beetle_L1_turnaround.jpg` (+ `_L1_front / three_quarter / side / back.jpg`) | turnaround of the L1 form |
| `bastion_beetle_L3_three_quarter.jpg` | the L3 form (L2 teal gem studs + horn band, L3 teal crest + glowing horn tips) |
| `bastion_beetle_ability_pose_three_quarter.jpg` | the Ability pose (rears up, shell plates flare, horn thrusts) |

## Build (tools/pets/bastion_beetle.py, kits petkit.py + rigkit.py)
- **Meshes:** `Beetle_Body` 1,434 tris, `Beetle_Face` 264, `Beetle_L2` 72, `Beetle_L3` 34.
  - **Per form:** L1 1,698 / L2 1,770 / L3 1,804 triangles (budget 2,000).
  - The pivot, rig and face are the same at every level.
- **Rig:** 18 bones, rigid skin: Root, Body, ShellL, ShellR, Head, Horn, and 6 legs × upper/lower.
- **Animations:** `BeetleAnims` (24 fps), generated in code in PetRig's key format: Idle, Walk (tripod gait), Run, Hop, Ability.
- **Texture:** base colour × ambient occlusion, baked in Cycles, 512 px (face 256 px), on a SurfaceAppearance (like the Kitsune).

## In the place
- **Template:** `ReplicatedStorage.EOS.Assets.Pets["Bastion Beetle"]`, set up like the Kitsune's:
  - RootPart pivot, RootWelds, SurfaceAppearance
  - attributes Prefix `Beetle_`, RigScale 0.01, BaseScale 0.78, SourceModel
  - Uploaded FBX: Model **112661861588387**. Textures: Decals 87143270670829 / 98555643244464 / 79753997882057 / 131128713143507.
- **Registered in:**
  - `PetModel.RIGGED`
  - `PetRig.MODULES` (+ `PetRig.BeetleAnims`)
  - `PetBehaviors.MODULES` → `Controllers.BeetlePet`
  - `EconomyConfig.EXTRA_SPECIES` (Guardian)
- **`Controllers.BeetlePet`** (source `tools/pets/BeetlePet.lua`):
  - **Follower:** GroundPet.
  - **Summon (every ability press, both roles):** the beetle pops up at your front-right, plays Ability, flashes `VFX.BeetleSummon_L1/L2/L3` at the peak, then shrinks into you. Visual only; abilities still fire on the press.
- **Its own ability effects** through the per-pet lookup (`AbilityCosmetics.SPECIES["Bastion Beetle"]`); the archetype defaults are untouched:

| Role | Ability | Templates | What it looks like |
|---|---|---|---|
| Runner | Shell Shield | `BeetleShieldUp`, `BeetleShieldBubble`, `BeetleShieldBreak` | gold plates fly up and out with blue lightning, a gold crest, a gold rim with blue arcs on the bubble, gold shell fragments when it shatters |
| Catcher | Horn Tether | `BeetleTetherBeam`, `BeetleTetherYank` | a gold energy-strand rope with a blue core, starting at the summoned beetle's horn (template attribute `FromOffset`), and gold streaks on the yank |
| Sound | | `BeetleShieldUp` | metal clank when the shell goes up (Pro Sound Effects 9116524438) |

- **New pack textures** (AllVFX): `av_shard_plate` 71972571194465, `av_shard_frag` 104900057996838, `av_beam_strands_v_alpha` 72973681248777 (the strand strip with its black background turned into alpha).
- **Code changes:**
  - `AbilityVFX` DRESS.TetherBeam honours `FromOffset`.
  - `Shared.beam` passes the species to `tagVfx`, so tethers get per-pet looks.
  - Guardian sends `ctx.species`.
- **Checked in a 2-player playtest:**
  - The follower spawns.
  - Runner: summon, shell rising and bubble at 0.07 s, summon flash at 0.47 s, `BeetleShieldBreak` on a blocked tag.
  - Catcher: tether in gold from offset (2.1, -1.2, -2.9), then the yank.
  - No errors.
- `BastionBeetle_InPlace.rbxm` is an export of the template and summon effects.

## Not done / next
- The Shell Shield bubble keeps the server's blue ForceField sphere, which matches the concept's blue dome. The gold plates, rim and arcs are the Beetle's own.
- The rope could read more like a twisted cable; a later polish could use a braided strip.
