---
tags: [delivery, lobby, pets, halloween]
ticket: HOS-HWN-002
date: 2026-10-18
---
# HOS-HWN-002: Halloween pet showcase on the Crown podium

Matthew: "make one of the other pedestals be a pet cycling animation of all our sellable halloween pets. Show what it does with the ability and different animations." Podium: **Crown** (HOS-POD-001), where Matthew placed it at the south end of the island, about (0, 10, 1547). Later: "Remove the legendary line with the description on it" (done; see the sign below).

## What players see
The Crown podium cycles the Halloween shop's pets (`HalloweenShop.PETS`): **Jack-o'-Lantern, Witch's Cat, Mummy, Bone Dragon**. Each pet faces the middle of the lobby and runs through its moves, about 16 s per pet:

1. idle
2. its move clip (FLOAT / FLY / WALK) while it turns a full circle
3. two hops
4. run while it turns a full circle
5. **its Runner cast** with its real match effect: Jack-o'-Lantern *Vanish* (also turns see-through), Witch's Cat *Clone*, Mummy *Shield*, Bone Dragon *Breath*
6. **its Catcher cast**: *Stalk*, *Snare*, *Lash*, *Slam*
7. fades out; the next pet fades in

Flying and floating pets hover a little above the stand and bob.

**Sign** above the pet: the pet's name in its rarity colour (gold Legendary, purple Epic) and what it's doing now (`IDLE`, `FLOAT`, `HOP`, `RUN`, `AS RUNNER: VANISH`, `AS CATCHER: STALK` ...). A third line, `ON SALE <date>`, appears only for a pet whose sale hasn't started yet. There's no rarity or description line (removed at Matthew's request).

## How it works
- **New client module** `StarterPlayer.StarterPlayerScripts.EOS.Controllers.PetShowcase`, started from `WeaponFXBoot` after the sword showcase.
- **Data-driven:** any model tagged `HOS_PetShowcase` runs it. Tagged: `Workspace._PodiumPreview.Podium_Crown` (the lobby one) and the master `ServerStorage.HOS_RigPodiums.Podium_Crown`. `tools/build/HOS-POD-001_rig_podiums.lua` now tags the Crown, so a rebuild keeps it.
- **The pets** are built with `PetModel.build` (level 1, the look you buy) at scale 2.8, about 3.5 studs tall. A pet wider than 5.6 studs (the Bone Dragon's wings) is built smaller to fit. They are animated with `PetRig`, using the same baked clips as in a match.
- **The casts and effects** come from the shop's own pet preview (`ShopPetPreview.CASTS`: clip, effect and label per species), with timing from `PetBehaviors` (`INTRO`, `FLASH_AT`). The effects are each pet's real summon templates (`ReplicatedStorage.VFX.<name>L1`) played with `VFX.Emit`. In the world these are real particles; the shop has to redraw them as UI. Effects are scaled by the square root of the pet's size against the size they were authored at (about 1.4×). At full proportion (1.7×) the Mummy's bandages swamped the podium and the sign.
- **The pet list** follows the shop. A pet whose sale window has closed (`to` passed) drops out, and one that hasn't started gets the `ON SALE` line. Right now all four are on sale with no windows (the shop's dates were removed), so all four cycle.
- **The Dummy** stays in the place to mark the spot in Studio and is removed on each client.
- **Performance:** looks only, nothing goes to the server. It rests in a match, when the camera is away from the lobby, and when you're more than 60 studs from the podium (`LobbyGate`). With Reduce effects on, the animations still play but the effects don't. Everything lives in a client-only folder, `Workspace.HOS_PetShowcase`.

## Checks (Studio playtest, 18 Oct)
- Sign sequence for the Jack-o'-Lantern: `IDLE 1.4 s, FLOAT 3.5, HOP 6.0, RUN 7.4, IDLE 9.2, AS RUNNER: VANISH 9.8 (WraithVanish_L1 effect 10.3), IDLE 12.0, AS CATCHER: STALK 12.8 (WraithStalk_L1 13.3), IDLE 15.1`, then the Witch's Cat at 16.6.
- Also seen: the Mummy's Shield (bandages), the Bone Dragon's Breath and Slam (bone smoke), and the Jack-o'-Lantern 85% see-through during Vanish.
- Effects clean themselves up: only the pet and the sign anchor remain in the folder. No errors. The sword showcase and the five weapon pedestals still showed their avatars.
- Screenshots: `docs/HOS-HWN-002_lantern_vanish.jpg`, `docs/HOS-HWN-002_dragon_slam.jpg`, `docs/HOS-HWN-002_mummy_hop.jpg`.

## Notes
- The sign is plain text in the game's FredokaOne face. It isn't a designed UI piece, so Hunter may want a styled plate later.
- The Crown podium still sits inside `_PodiumPreview`. Move it out before that folder is deleted; the tag goes with it.

## Backup and undo
- `WeaponFXBoot` as it was: `docs/backups/HOS-HWN-002_2026-10-18/WeaponFXBoot.lua`.
- Studio undo step: "HOS-HWN-002 Halloween pet showcase" (module, start line, tags). The module's source was set afterwards (`set_script_source`, then the sizing and sign edits).
- ScriptHistory updated (`PetShowcase.lua` new, `WeaponFXBoot.lua`).
