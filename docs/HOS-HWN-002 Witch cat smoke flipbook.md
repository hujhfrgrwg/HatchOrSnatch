---
tags: [delivery, pets, vfx, fix]
ticket: HOS-HWN-002
date: 2026-10-18
requested_by: Matthew
---
# HOS-HWN-002: Witch's Cat smoke showed the whole flipbook sheet

Matthew: "Fix the witch cat pet showing a black flipbook particle. It needs to be set to flipbook because it's just displaying the template and not going through as a flipbook."

## Cause
The Witch's Cat's smoke uses texture `rbxassetid://115159881988143`, a 512 × 512 flipbook sheet of 4 × 4 frames. I read its pixels in Studio: it has empty gutters on the quarter and half lines and content between them. The same texture is already set up correctly elsewhere as a 4 × 4 one-shot flipbook (`Abilities.DecoySplit/DecoyPoof/StormHit/RiftFizzle … Smoke`). On the cat's emitters, `FlipbookLayout` was `None`, so every particle drew the whole 16-frame sheet. Those emitters have LightEmission 0, so the sheet read as a dark square.

## Fix (Studio, `ReplicatedStorage.VFX`)
I set `FlipbookLayout = Grid4x4` and `FlipbookMode = OneShot` on the 15 emitters, so the 16 frames play once over each particle's life:
- `CatSummon_L1`, `CatSummon_L2` and `CatSummon_L3`: `Root.Core.CauldronSmoke` and `Root.Core.VioletSmoke`, which play when the cat is summoned.
- `Abilities.CatDecoySplit`, `CatDecoyPoof` and `CatSnareTrigger`, each at levels 1, 2 (`_L2`) and 3 (`_L3`): `Root.Core.CauldronSmoke`.

Each emitter has a `HOS_WasFlipbook` attribute recording the old value (`None/Loop`). It's one undo step: "HOS-HWN-002: Witch's Cat smoke flipbooks".

I checked it by firing a copy of `CatSummon_L3`. The smoke now comes out as soft puffs instead of the sheet. No scripts were changed; nothing in the place rebuilds these templates.

## Not changed: the same bug elsewhere
The Mummy's templates use the same texture with no flipbook layout. That's 16 emitters:
- `MummySummon_L1`–`L3` `SandDust`
- `MummyTetherYank`, `MummyShieldBreak`, `MummyShieldUp` (`SandDust`) and `MummyShieldBubble` (`SandDrift`), at all three levels
- The level-3 `RoyalCrystals` emitters

The same fix would apply to them.
