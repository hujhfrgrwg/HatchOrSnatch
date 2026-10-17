# Decoy VFX (HOS-VFX-001)

Preview: `decoy_preview.mp4` (gameplay angle, then side angle; edit-mode staging with stand-in dummies). Stills: `decoy_still_1-3.jpg`.

- **DecoySplit** (Runner, on the press): golden cel-smoke puff, orange ground ring with a dark twin (reads on bright sand), spiky ring, stars, small light. You and the copy both leave it, so nobody can tell which is which; the copy itself has no effect on it.
- **DecoyPoof** (the copy runs out, species without their own poof): smaller golden puff + stars.
- **Snare** (Catcher, lasting): chain seal decal (pack Sigils/22.png) turning slowly, soft orange fill over the whole 4-stud radius, pulsing edge ring, rim sparks.
- **SnareTrigger**: chain seal snaps tight, spiky ring, stars, flash. **Rooted**: a small spinning chain seal under the stuck Runner for the 1.2 s.
- Decoy icon recoloured to Decoy orange-gold (gold copy, orange runner).

Colours are fixed to the archetype (Gold Ability Colors never applies), so the snare always reads. Templates: `ReplicatedStorage.VFX.Abilities` (exported to `vfx/abilities/VFX_Abilities.rbxm`); client: `Controllers.AbilityVFX`.
