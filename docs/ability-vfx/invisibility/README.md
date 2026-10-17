# Invisibility VFX (HOS-VFX-005)

Preview: `invisibility_preview.mp4` (an opponent's view, then side). Stills: fading out (1), cloaked while walking (2), side (3).

Both roles use the **default cloak** (template `ReplicatedStorage.VFX.Abilities.InvisShimmer`, effect key `InvisShimmer`) for pets that have no invisibility look of their own:
- **Glints:** lavender glints come off the body parts themselves, so they take the body's shape. Each has a dark violet twin so it reads on sand.
- **Scan ring:** a lavender ring with a dark twin slides up the body about twice a second. It reads as a cloaked figure from a distance.
- **Distance only:** full strength within 10 studs, fading to 35% at 45 studs (camera distance). Lighting never changes it, and Gold Ability Colors never applies.
- **Catcher reveal:** the 15-stud rule is unchanged. A Runner farther away sees nothing at all; closer, the cloak.
- **Your own view:** your body at 0.6 as before, plus the cloak, so you know you're hidden.
- **Other players' view:** body at 0.9 (unchanged), with name, tag, outline and egg sparkle hidden as before.

**Grim Ghost and Prism Chameleon** keep their existing glints exactly (Hunter, 17 Oct). `AbilityCosmetics` maps their `InvisShimmer` to NONE, and their old code path runs untouched.

**Bug fixed:** every invisible player was flickering. Once the fade reached full, `step()` stepped back off it every other frame, so the body pulsed between 0.9 and 0.63 transparency for opponents. It now holds at the target.

## Checked (2-player playtest)
- Mouse Runner: cloak on both screens (14 emitters), body at 0.9, name hidden, cleaned up afterwards.
- At a 30-stud camera distance the glints are at 0.47 transparency (0.15 up close), as designed.
- Grim Ghost: one original glint emitter on the root with its own tint; no cloak.
- Catcher with the 15-stud reveal: a Runner at 30 studs sees the body fully hidden and no glints; at 8 studs, the cloak at 0.9.
- Transparency holds steady at 0.9 while invisible (no flicker).
- No errors.
- The preview was staged in edit mode with the same template and the same body-part placement as the client code.
