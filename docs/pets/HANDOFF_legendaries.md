# Handoff: the five Legendaries (done 17 Oct)

All five are built, uploaded to group 228184582, installed, hooked and playtested at L3. Hunter must save the place.

| Pet | Ticket | Family | README |
|---|---|---|---|
| Eclipse Tengu | HOS-PET-027 | Decoy | `docs/pets/eclipse_tengu/README.md` (effects v2, its own) |
| Veil Nekomata | HOS-PET-028 | Invisibility | `docs/pets/veil_nekomata/README.md` (Grin Ghost untouched) |
| Aegis Kirin | HOS-PET-029 | Guardian | `docs/pets/aegis_kirin/README.md` |
| Raiju | HOS-PET-030 | Tempest | `docs/pets/raiju/README.md` |
| Void Seraph | HOS-PET-031 | Rift | `docs/pets/void_seraph/README.md` |

- Previews for Hunter: artifact https://claude.ai/artifact/Dubk74eHAxLTAtj7uJNAUB (`docs/pets/previews_page/legendaries.html`).
- Every Legendary has its OWN ability effects (`vfx/<pet>/textures.py`, `assets.json`); none is a recolour.
- Studio helpers: `tools/studio/hos_stage.lua` then `tools/studio/hos_pet_helpers.lua` (HOS_PetHooks / HOS_CheckPet /
  HOS_FullInstall) after a Studio restart.
- Not live-tested (solo sandbox limits): Tengu snare trigger, Kirin Long Reach (NO_TARGET), Seraph Portal / Blink
  (OFF_MAP; summon played through the controller instead).
- Rarity "legendary" is set in `EconomyConfig.SPECIES_RARITY` (not read by any script yet); no egg table changed.
- Done (Hunter, 10:06): the eight recoloured-clone effect sets are rebuilt with each pet's own effects, same names,
  sizes and timing: Scroll Tanuki, Moonveil Moth, Shrine Lion, Crystal Warden, Drum Oni, Riot Hound, Compass Hare,
  Astral Djinn (`vfx/<pet>2/`, "Effects v2" in each README, old sets in `docs/backups/HOS-VFX-OWN_20261017/`).
  Hare and Djinn were checked through their controllers' summon (Rift casts are OFF_MAP in the sandbox).
- Hunter: save the place (nothing has been saved or published from these sessions).

## Redo of eight pets (HOS-PET-REDO, 17 Oct, after Hunter's review)
Installed in Studio, not saved. Each README has a "Redo" line; uploads in the ledger ("redo HOS-PET-REDO").
- Raiju: bigger chest, head and three-ring lightning mane; crimson / black / white-hot yellow (L3 violet-white).
  Its effects' blue parts recoloured. BaseScale 0.8. L3 2,179 tris (over 2,000, Legendary allowance).
- Void Seraph: void-black nebula coat with stars, pearl ruff, gold, big layered feather wings. BaseScale 1.0.
- Veil Nekomata: longer slimmer arched body, thin whip tails with wisp plumes, ghost-silver with indigo ink and a
  crimson collar. BaseScale 0.8.
- Moonveil Moth: pointed hooked forewings over pointed hindwings with swept tails.
- Scroll Tanuki: lighter coat, cream belly and muzzle, bright teal / gold scrolls.
- Crystal Warden: brighter crystals, BaseScale 1.0.
- Drum Oni: rope sash and chest stripes (L3 2,056 tris).
- Astral Djinn: chest panel, nebula, rune bands, constellation; collar fix kept.
- Checks: all eight build at L1-L3 (HOS_CheckPet), textured and animating in an edit-mode lineup
  (`docs/pets/redo_ingame/studio_lineup_L1.jpg`); sandbox playtest of the Raiju at L3: Knockback and Storm Ball ok.
- Tools: `tools/pet-kit/redo_build.sh` (reshape_build with its own backup folder), `tools/pet-kit/redo_lineup.py`
  (before / after sheets and clip). Backups: `docs/backups/HOS-PET-REDO_20261017/`.
- Not changed (mentioned only): Hunter finds the Bastion Beetle's cream cuter than the rest.
- Hunter: save the place.


## Thunder Toad remake, Bastion Beetle touch-up, rarities, pet chart (HOS-PET-REDO, 17 Oct, Hunter's "Both")
- Thunder Toad remade on the pet kit (`tools/pet-kit/toad/toad.py`): a bottle-green storm toad with lime lightning,
  L3 1,773 tris; `PetRig.ToadAnims` replaced; its own effects recoloured lime / storm green. README "Remade".
- Bastion Beetle touched up: bigger sharper eyes, engraved and scratched plates, engraving glows at L2 / L3; cream /
  bronze look kept. README "Touch-up".
- `EconomyConfig.SPECIES_RARITY`: Bastion Beetle, Thunder Toad and Ring Imp set to "common" (one line edit).
- Pet chart data for the project page: `docs/pets/previews_page/chart/` (25 Studio tiles of the live templates at L1 +
  `pets.json`), made by `tools/pet-kit/make_chart_tiles.py`.
- Hunter: save the place.
