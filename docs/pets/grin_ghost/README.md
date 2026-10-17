# Grin Ghost (Invisibility, Rare): HOS-PET-018

Internal species id **"Grim Ghost"** (shown as "Grin Ghost" via `EconomyConfig.DISPLAY_NAMES`; no save migration).
From the concept-library card (`grin_ghost_card.png`), read through `docs/pets/PET_LESSONS.md` (anime / edgy).
Installed in the place on 17 Oct (Hunter 08:07: "Finish it all and install it fully").

## Model (tools/pet-kit/ghost/ghost.py, the friend's pet kit)
- Dusky violet floating ghost: tall crescent horns with near-black jagged tops and glowing tips, cheek fins, spiky
  back ridge, stubby clawed arms, a near-black wisp tail with a glowing jagged edge and tail tatters. No legs.
- Face decal shell (flush, eyes-flush check 178 frames, max gap 0.009): narrow slanted slit eyes under a heavy brow,
  a wide shark-toothed grin, tear streaks, a glowing forehead crescent sigil.
- Levels: L1 violet glow. L2 "Haunt": wrist shackles + broken chains, two teal ghost-fire wisps, brow spikes, teal
  glow, cheek chevrons. L3 "Phantom King": floating jagged crown, extra tail tatters + back spikes, crimson eyes/glow.
- Tris L1 908 / L2 1,372 / L3 1,596 (cap 2,000). 14 bones (Root, Body, Head, Tail1-3, Wisp, Crown, Horn/ArmU/Hand L+R).
- Anims (GhostAnims): Idle 72 f (smoky hover, sly head cock, claws flex), Walk 24 / Run 16 (flight), Hop 16,
  Ability 24 (Vanish: wraps face, spins, flings open), Stalk 18 (Catcher: rears back, lunges a claw, yanks).

## In the place
- Template `ReplicatedStorage.EOS.Assets.Pets["Grim Ghost"]` from FBX Model 135100162634572 (Prefix Ghost_,
  BaseScale 0.75, RigScale 0.01), full PBR (colour / normal / roughness / emissive), Looks Body1-3 / Face1-3 /
  Extra2-3. Asset ids in `docs/VFX-LEDGER.md`.
- `Shared.PetRig.GhostAnims`, `Controllers.GhostPet` (Manta/Imp-style hover follower; summon seeps out of smoke at
  your front-right, plays Ability (Runner) or Stalk (Catcher), fires the level effect at 0.5 s, fades into you).
- Effects (`ReplicatedStorage.VFX`): `GhostVanish_L1-3` (Runner: dark smoke + violet glow burst, ring, glints and a
  floating grin afterimage; L2 adds teal ghost fire; L3 crimson, a chain sigil, a second big grin, sparks) and
  `GhostStalk_L1-3` (Catcher: dark shadow mist sweeping out, spiky dark ring, a pair of glowing eyes left hanging;
  L2 teal ghost fire; L3 crimson, extra eye pairs, chain sigil). The server's invisibility and its glints are
  unchanged (AbilityCosmetics already had the Ghost entry).
- Hooks (one line each, originals in `docs/backups/HOS-PET-018_20261017/ORIGINAL_LINES.md`): PetModel.RIGGED,
  PetRig.MODULES, PetBehaviors.MODULES, and `EconomyConfig.FAMILIES.Invisibility.species.rare = "Grim Ghost"` (the
  Invisibility Rare hatch now gives the Grin Ghost instead of a second Prism Chameleon, as the roster says).

## Checks
- Solo playtest: the textured ghost follows; Runner press -> invisible + GhostVanish summon; Catcher press ->
  `ok=true, role=Catcher`, invisible, GhostStalk summon. Edit mode: PetModel.build gives Body+Face / +L2 / +L3.
- Stills: `ingame/` (`grin_ghost_ingame.jpg` sheet). Blender renders `previews_pass1/`, clip `anims_pass1/`.

## Not done / notes
- The ability HUD icon still shows the Chameleon picture for Invisibility pets (icons are per family, not species).
- No licensed sound of its own yet (it uses the default invisibility sounds).
- ImpPet compares `EOS_Role == "Catcher"`, but the attribute is "CATCHER", so the Imp always plays its Runner clip.
  GhostPet checks the upper-case value.
