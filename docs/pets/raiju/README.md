# Raiju (Tempest, Legendary): HOS-PET-030

From the concept card (`raiju_card.png`). Installed 17 Oct under Hunter's standing OK.

- **Model** (`tools/pet-kit/raiju/raiju.py`, rig taken from the Riot Hound's module, shapes and anims its own): a
  bulky royal-blue thunder beast with a huge gold lightning mane (two rings of jagged blades and bolts), gold
  zig-zag flank stripes that glow, a white chest and socks, a blue-white ghost-flame tail, gold cheek tufts, narrow
  gold slit eyes in a dark mask, a snarl with one fang. L2 "Storm Herald": a gold chest plate with a lightning crest,
  bolt pauldrons. L3 "Thunder God": a halo of seven lightning bolts behind the mane, a bolt crown, tail bolt blades,
  gold leg bracers, white-cyan eyes and glow. Tris 1,297 / 1,369 / 1,817. 23 bones. Anims (RaijuAnims): Idle (mane
  shudder, forepaw scrape, tail lash), Walk, Run, Hop, Ability (Knockback: sinks, springs up arched, crashes down on
  all four paws), Roar (Storm Ball: gathers, lunges roaring).
- **In the place**: template `EOS.Assets.Pets["Raiju"]` (FBX 129307707843957, Prefix Raiju_, BaseScale 0.7),
  `PetRig.RaijuAnims`, `Controllers.RaijuPet` (GroundPet; FLASH_AT 0.5, Roar clip for the Catcher).
- **Effects (its own, `vfx/raiju/textures.py`)**: `VFX.Abilities.Raiju{PulseCharge,PulseBlast,KnockHit,StormBall,
  StormBounce,StormHit}` (+_L2/_L3) and `VFX.RaijuSummon_L1-3`: a jagged lightning ring (drawn RaijuRing) for the
  charge warning and the shock (same size, rate and timing as the archetype, which opponents read), forked bolt bursts
  (drawn RaijuBurst), jagged gold mane-fire (drawn RaijuManeFire), falling strikes (AllVFX Lightning), a zig-zag bolt
  strip on the Storm Ball's cage / floor beams and trail (drawn RaijuBeam). The ball keeps the archetype orb structure
  re-dressed in blue glass and gold seams. L3 turns the bolts cyan and adds cyan arcs. Hooks via `_G.HOS_PetHooks`
  (Tempest, legendary). Tempest isn't in the egg list, so eggs don't hatch it yet.
- **Checks**: playtest at L3: Runner Knockback ok, RaijuSummon_L3 + RaijuPulseCharge_L3 + RaijuPulseBlast_L3
  (`ingame/playtest_knockback_L3.jpg`); Catcher Storm Ball ok, RaijuStormBall_L3 flies (`ingame/playtest_stormball_L3.jpg`).
- **Reshape (17 Oct, HOS-PET-RESHAPE)**: Hunter: "a lot of these pets look the same" (it shared the Riot Hound's
  body). Now its own body plan: a long, low lightning weasel on short legs with a slim tapering head, a very long
  S-curved flame tail with tufts and a row of gold spine bolts; bright electric cobalt with a big white underside
  (no longer the Hound's navy). Same bones and anim names; new Walk and a bounding-lope Run, lower Hop and Knockback.
  Tris 1,392 / 1,464 / 1,912. New FBX 119486282803488 and maps (ids in `Assets/asset_ids.json`; the old ones are kept
  there as `#superseded-HOS-PET-RESHAPE`). Old model, anims and renders: `docs/backups/HOS-PET-RESHAPE_20261017/`.
  Playtest L3 Runner: follower textured, Summon + PulseCharge + PulseBlast ok (`ingame/reshape_follower_L3.jpg`).
- **Redo (17 Oct, HOS-PET-REDO)**: Hunter: "small and thin, still blue/gold like the Riot Hound". Same weasel body plan, beefed up: a deep barrel chest, a big wedge head, thicker legs and a three-ring lightning lion's mane with cheek tufts and a white-hot chest ruff. New palette: crimson coat with a black storm saddle and black jagged socks, white-hot yellow lightning, a tail that burns to white at the tip; L3 lightning turns violet-white. Tris 1,627 / 1,699 / 2,179 (L3 over 2,000, inside the Legendary allowance). BaseScale 0.7 -> 0.8. Its own effects: the blue parts (storm-ball shell, dark ring backings, L3 cyan) recoloured to crimson / dark crimson / violet-white (26 colour keys), sizes and timing unchanged. Playtest L3: Runner Knockback ok (RaijuSummon_L3, PulseCharge_L3, PulseBlast_L3), Catcher Storm Ball ok (RaijuStormBall_L3), follower textured. New FBX 101082867047263 and maps (ids in `Assets/asset_ids.json`, the old ones kept as `#superseded-HOS-PET-REDO`; ledger rows "redo HOS-PET-REDO"). Old templates and anims: `docs/backups/HOS-PET-REDO_20261017/eight_pets_templates_and_anims_before.rbxm`; old sources and renders in the same folder. Not saved: Hunter saves the place.
