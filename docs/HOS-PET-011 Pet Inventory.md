---
tags: [pets, inventory]
updated: 2026-10-17
---
# HOS-PET-011: pet inventory (read-only)

This is a snapshot of every pet in the Hatch or Snatch place and repo on 17 Oct, measured against the cofounder's 20-species roster. Nothing in the place was changed.

**Sources:**
- the place (`ReplicatedStorage.EOS.Assets.Pets`, `PetModel`, `PetRig` / `CrowRig`, the client pet modules, `ReplicatedStorage.VFX`, `EconomyConfig`, `ProfileLogic.hatch`, the Incubator GUI data);
- `ServerStorage.FWP_PetLibrary` and the workspace showcases;
- all branches (`git branch -a`).

Rarity order in the roster is Common → Rare → Epic → Legendary, per `Design/Economy Decisions.md` on `claude/economy-audit-0kz3a9`. That file names the five Commons as Mimic Crow, Veil Chameleon, Bastion Beetle, Thunder Toad and Ring Imp.

## The 20 roster species

None of the 20 roster names appear anywhere in the place yet. Four roster species line up with an existing pet under an older name, marked "≈".

| Archetype | Rarity | Roster species | In the place today | Model | L1 / L2 / L3 forms | Summon / intro | Own VFX / sound | Eggs hatch it? |
|---|---|---|---|---|---|---|---|---|
| Decoy | Common | Mimic Crow | ≈ **Crow** | **Finished**: rigged skinned mesh `Assets.Pets.Crow`, posed by `CrowRig` + `CrowAnims` | Same mesh at every level; L3 only swaps the eyes to red (`EyeL3`). Each level has its own summon effect (`VFX.CrowDecoy_L1/L2/L3`) | `Controllers.CrowPet`: swoops in from behind/above, flares at the chest | Yes: CrowDecoy_L1–L3 + CrowDecoy_Poof (crow scatter at L2+, grey puff at L1); `AbilityCosmetics`: DecoySplit = NONE, sound "poof" | **No.** Only via the Studio test attribute `EOS_TestPet` (a Decoy Common hatch gives Mouse) |
| Decoy | Rare | Tricktail Kitsune | ≈ **Kitsune** | **Finished**: rigged mesh `Assets.Pets.Kitsune` (`PetRig` + `KitsuneAnims`) | Full L1 / L2 / L3: extra meshes `Kitsune_L2`, `Kitsune_L3` + 6 looks (body + face per level) | `Controllers.KitsunePet`: runs in, hops left/right, leaps into the user's back (`VFX.KitsuneHop_L1–L3`) | Yes: KitsuneDecoy_L1–L3, KitsuneHop_L1–L3, KitsuneDecoy_Poof; DecoySplit = NONE, sound "poof" | **No** (test attribute only) |
| Decoy | Epic | Paper Tanuki | — | None | — | — | — | No |
| Decoy | Legendary | Eclipse Tengu | — | None | — | — | — | No |
| Invisibility | Common | Veil Chameleon | ≈ **Prism Chameleon** | **Finished**: rigged mesh `Assets.Pets.Prism Chameleon` (`PetRig` + `ChameleonAnims`) | Full L1 / L2 / L3: `Chameleon_L2`, `Chameleon_L3` + 8 looks | `Controllers.ChameleonPet`: pops up beside you, rides your shoulder, melts in (`VFX.PrismInvis_L1–L3`, prism shards) | Yes: PrismInvis_L1–L3, prism-tinted invisibility glints; InvisShimmer = NONE | **No**: Invisibility isn't a launch family. `EconomyConfig` lists it as the Invisibility **Rare and Epic** (the roster has it as Common) |
| Invisibility | Rare | Grin Ghost | ≈ **Grim Ghost** (note: Grim vs Grin) | **None.** No mesh, no voxel spec, not in `PetModel.RIGGED`. `GhostPet` is mentioned in a comment in `Abilities.Shared`, but no such module exists | — | Generic: the voxel pop-up over the head (no model, so likely empty) + summon ring | Own invisibility glint tint (lavender); InvisShimmer = NONE | **No**: Invisibility isn't a launch family (`EconomyConfig` lists it as the Invisibility Common) |
| Invisibility | Epic | Moonveil Moth | — | None ("Moth" appears only in the Fishing with Pets reference data) | — | — | — | No |
| Invisibility | Legendary | Phantom Nekomata | — | None | — | — | — | No |
| Guardian | Common–Legendary | Bastion Beetle, Crystal Warden, Shrine Lion, Aegis Kirin | — | None (no Guardian family in `EconomyConfig`) | — | — | Archetype defaults only | No |
| Tempest | Common–Legendary | Thunder Toad, Riot Hound, Drum Oni, Raiju | — | None (no Tempest family) | — | — | Archetype defaults only | No |
| Rift | Common–Legendary | Ring Imp, Compass Hare, Astral Djinn, Void Seraph | — | None (no Rift family) | — | — | Archetype defaults only | No |

**Totals:**
- **Finished models:** 3 of 20 (Crow, Kitsune, Chameleon). Kitsune and Chameleon have true L1–L3 forms; the Crow's L1–L3 is eyes plus summon effects.
- **Missing:** 17 models, including the Ghost.
- **Hatchable from eggs today:** 0 of 20.

The three finished pets stand side by side at every level in `Workspace.EOS_PetTierShowcase` (9 displays). There's a crow test bay in `Workspace.EOS_PetLab`.

## Pets in the place that are not on the roster

| Species | Archetype now | Model | Eggs hatch it? |
|---|---|---|---|
| Mouse | Decoy (Common) | Voxel placeholder (`PetModel.SPECS`, built from Parts) | **Yes**: Decoy Common hatch |
| Parrot | Decoy (Rare) | Voxel placeholder | **Yes**: Decoy Rare hatch |
| Mirror Dragon | Decoy (Epic) | Voxel placeholder | **Yes**: Decoy Epic hatch |
| Grim Ghost | Invisibility (Common) | None (see above) | No |
| Prism Chameleon | Invisibility (Rare + Epic) | Finished rigged mesh (see above) | No |
| Sparrow, Seagull, Celestial Owl | old **Scout** family (removed in HOS-PET-001) | Voxel placeholders still in `PetModel.SPECS` | No (the family is gone; old saved pets of these species keep a look but have no ability) |
| Turtle, Hermit Crab, Time Spirit | old **Brake** family (removed) | Voxel placeholders still in `PetModel.SPECS` | No (same as above) |

**Fishing with Pets assets copied into this place** (not wired into any Hatch or Snatch gameplay):
- `ServerStorage.FWP_PetLibrary.Pets`: 37 rigged Fishing with Pets pets sorted into an older ability plan:
  - Double Dash (5): Thunder Wolf, Phoenix Gull, Fire Dragon, Surfer Dog, Shades Shark
  - Invisibility (4): Void Overlord, Koi Spirit, Saucer Pilot, Jelly Wisp
  - Decoy (5): Lil Alien, Bandit Raccoon, Gamer Axolotl, Mini Mothership, Ninja Penguin
  - Shield (4): Hermit Knight, Puffer Pup, Treasure Golem, Pebble Frog
  - Wall (6): Mecha Invader, Sand Crab, Robo Crab, Armored Rex, Frost Yeti, Lava Scorpion
  - Pet Tackle (5): Cozy Lion, Viking Walrus, Leviathan Pup, Kraken Hatchling, Narwhal Calf
  - Left Out (8): Cloud Whale, Lil Otter, Parrot Pirate, Mini Fisherman, Sushi Cat, Golden Otter, Floatie Giraffe, Seagull Scout
- The same library also holds 7 Fishing with Pets eggs (Starter, Basic, Shiny, Golden, Cosmic, Royal, Alien), 2 egg bases, the walking egg guide, 195 animation clips, and reference configs (`PetConfig`, `EggConfig`, `PetVariantData`, `HugePetConfig`).
- `Workspace.FWP_PetShowroom` has 45 displays of these pets.
- None of these share a name with the roster. They're another game's pets; reuse would be a separate decision.

**Other:**
- `Workspace["Vynx's_Opensource_Eggpack :D"]`: an open-source pack of about 250 egg models in 53 themed sets (Haunted, Storm, Zen, Celestial…). Its `ReadMe` script throws a parse error on every server start. Its licence isn't recorded in the repo; check before use.

## Eggs and hatching today

- **There is no egg item to open.** A match pays egg *pieces* by the highest egg level you secured: Common (L1), Rare (L2), Epic (L3 and L4). There's no Legendary piece; "crowned" is deferred.
- **Hatching** (`ProfileLogic.hatch`) costs pieces: Common 2, Rare 3, Epic 5, plus 1 more to choose the family. The first Common is free with a family choice.
- The species is `EconomyConfig.FAMILIES[family].species[rarity]`.
- `LAUNCH_FAMILIES = { "Decoy" }`, so **every hatch is Decoy: Common = Mouse, Rare = Parrot, Epic = Mirror Dragon.** Nothing else can hatch.
- `EXTRA_SPECIES` maps Crow and Kitsune to Decoy, so equipping one works, but no hatch produces them.
- **Incubator:**
  - It still has the 3×3 family grid from the old plan, with tiles `Fam_Decoy`, `Fam_Invisibility`, `Fam_Scout` and `Fam_Brake` (plus their counters).
  - The Scout and Brake tiles are hidden at runtime (HOS-PET-001), leaving two empty slots.
  - There are no tiles for Guardian, Tempest or Rift.
- **Planned egg economy (not merged).** The economy branch (`claude/economy-audit-0kz3a9`, `Design/Economy Decisions.md`) has:
  - eggs won rather than handed out, 4 rarities including Legendary, visible egg rarity;
  - 3 Common eggs hatch a missing Common;
  - duplicates raise the cosmetic level L1 → L2 → L3, and no rarity stat bonus.
  - It also flags an open question: the 5-archetype roster vs the older nine-family plan.

## Concept art and other branches

- **Repo `Assets/`:**
  - `Assets/Icons`: the ability icons (`ab_decoy`, `ab_snare`, `ab_tether`, `ab_tempest`, `ab_stormball`, `ab_rift`, `ab_blink` + previews).
  - `Assets/VFXPack`: textures (one `ghost` flipbook).
  - `Assets/Emotes`: untracked, belongs to another session.
  - There are **no pet concept sheets, renders or the cofounder's handoff images** in the repo or on any branch.
- **Repo `docs/`:** the ability framework, ability VFX previews and backups. No pet concepts.
- **Branches:**
  - `claude/economy-audit-0kz3a9`: the roster appears only as text in the economy decisions plus `tools/sim/roster.py` (careers across 5 archetypes × 4 rarities). The handoff itself isn't committed.
  - `claude/nifty-carson-ml33ob`: 37 pet icons (`pet_*_t1–t3.png`), but they're the Fishing with Pets pets above, not roster species.
  - `main`, `claude/crate-spin-animation-6w7dwx`: nothing pet-related.
- If the cofounder's handoff images exist, they're likely in the project's Library or with Hunter, not in git.

## What this means for the pet work

1. **Rename or keep:** decide whether Crow → Mimic Crow, Kitsune → Tricktail Kitsune, Prism Chameleon → Veil Chameleon and Grim Ghost → Grin Ghost are the same pets under new names. Renaming touches saved pets' `species` field, so it needs a migration that keeps the old names working.
2. **Chameleon's rarity:** it's Invisibility Rare/Epic in config but Invisibility Common in the roster.
3. **The Ghost has no model at all,** although it's in the hatch table as the Invisibility Common.
4. **17 species need models**, and Guardian, Tempest and Rift need families in `EconomyConfig` (and incubator tiles) before they can hatch.
5. **Placeholders to retire:**
   - Mouse, Parrot and Mirror Dragon are the only hatchable pets today, so they can't simply be removed (rule 21 disposition needed).
   - The Scout and Brake voxel specs only serve old saves.

## Corrections and follow-ups (HOS-PET-012, 17 Oct)
- **Correction:** the live place's hatch tables differ from the script snapshots this inventory was first written from. Another session had already changed them:
  - `LAUNCH_FAMILIES = { "Decoy", "Invisibility" }`
  - Decoy hatches Mouse (Common), **Crow (Rare)** and **Kitsune (Epic)**
  - Invisibility hatches the **Prism Chameleon** at every rarity
  - So Crow, Kitsune and Chameleon *are* hatchable today. HOS-PET-012 does not touch these tables (no hatch changes yet); they differ from the roster rarities, and a later ticket swaps roster pets in.
- **Display names:** roster names are now shown on screen (`EconomyConfig.DISPLAY_NAMES` / `displayName()`): Crow → Mimic Crow, Kitsune → Tricktail Kitsune, Prism Chameleon → Veil Chameleon, Grim Ghost → Grin Ghost.
  - Internal ids are unchanged, so no save migration.
  - The HUD equipped card, the hatch reveal, the pet preview and the incubator ladder use these names; other pets keep their placeholder showroom names.
- **Roster rarities:** recorded as `EconomyConfig.SPECIES_RARITY` (Crow Common, Kitsune Rare, Chameleon Common, Ghost Rare). The hatch tables are unchanged.
- **Egg pack readme:** the `ReadMe.Read` script in `Workspace["Vynx's_Opensource_Eggpack :D"]` is now **Disabled** (it threw a parse error on every server start). The models are kept.

## Build order (Hunter, 17 Oct)
Build one pet at a time, rotating through the archetypes. Each pet is finished fully, with previews pushed, before the next one starts, and no two pets are worked on in parallel. Crow, Kitsune and Chameleon already exist, so they're skipped.

| # | Pet | Archetype, rarity | Status |
|---|---|---|---|
| 1 | Bastion Beetle | Guardian, Common | done (HOS-PET-013c + full PBR) |
| 2 | Thunder Toad | Tempest, Common | in progress (HOS-PET-014) |
| 3 | Ring Imp | Rift, Common | |
| 4 | Grin Ghost | Invisibility, Rare | |
| 5 | Crystal Warden | Guardian, Rare | |
| 6 | Riot Hound | Tempest, Rare | |
| 7 | Compass Hare | Rift, Rare | |
| 8 | Scroll Tanuki | Decoy, Epic | |
| 9 | Moonveil Moth | Invisibility, Epic | |
| 10 | Shrine Lion | Guardian, Epic | |
| 11 | Drum Oni | Tempest, Epic | |
| 12 | Astral Djinn | Rift, Epic | |
| 13 | Eclipse Tengu | Decoy, Legendary | |
| 14 | Veil Nekomata | Invisibility, Legendary | |
| 15 | Aegis Kirin | Guardian, Legendary | |
| 16 | Raiju | Tempest, Legendary | |
| 17 | Void Seraph | Rift, Legendary | |

**Standard for every pet (Hunter, 17 Oct, "premium"):**
- Each MeshPart's SurfaceAppearance carries the full PBR set: colour, normal (baked from a smoothed copy, so plates shade rounded), roughness and metalness maps.
- An emissive mask covers the crystals, eyes, glowing markings and runes. The glow is tuned to read in daylight on the sand map.
- Uploads are logged in [[VFX-LEDGER]].
