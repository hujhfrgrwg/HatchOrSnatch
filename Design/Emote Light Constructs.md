---
tags: [design, emotes, vfx]
updated: 2026-10-16
ticket: HOS-EMOTE-FX-001 (prototypes built)
---
# Emote Light Constructs

Hunter 2026-10-16: add VFX to emotes "similarly to how Destiny 2 does. it makes objects out of vfx", but **only for certain emotes**, ones where the dance mimes a prop that isn't there, "such as the reaper one where it appears like the emote is supposed to be him riding a scythe, or the surfing one". Common emotes with no implied prop stay plain.

## What the clips tell us
The emote pack (`ServerStorage["52+ Emotes (R15/R6)"]`) shipped animations only, no props. But some clips still animate their original prop's joint, so a construct part with that joint's name, welded at the right offset, is moved by the emote itself:

| Emote | Prop joint in the clip | Part0 | Fitted C0 |
|---|---|---|---|
| Reaper's Ride (L) | `BézierCircle.003` (literal text, backslash and all) | Torso | `CFrame` stored on the sample model's `C0` attribute (scythe under the crotch, along the hands' line, blade in front) |
| Surfer (R) | `Surf` | HumanoidRootPart | `CFrame.new(0, -3.35, 0.1)` (fit over all 11 keyframes; feet on the deck in most frames, ~0.6 studs off on the hops) |

Other clips with hand-grip joints (`Right Grip` / `Left Grip`, the item a hand holds): Toilet Sit, Company Dance, Gambler Dance, Threaten, Honored One, Shadow Emerge, Blossom Break. Emotes whose names imply a prop but have no joint: Ice Cream Cart, Couch Nap, Sunbath, Trick or Treat, Coconut Launch (the pack has a separate cannon animation). Skeleton and Lose It carry stray item poses (BloxyCola, Ghostburger, Hart).

## Sample look (v1, awaiting Hunter)
Glowing see-through "light" pieces in pale spectral cyan (Neon, ~50% transparent, with a brighter thin core), a soft PointLight and a few sparkle wisps / spray. No shadows, no collisions, massless.
- `docs/emote-fx/reapers_ride_scythe_construct_v1.jpg`: rider straddling a glowing scythe, crescent blade at the front.
- `docs/emote-fx/surfer_board_construct_v1.jpg`: glowing board under the feet, spray off the tail.

The samples live in the place only as an unsaved preview (`Workspace._EmoteFXPreview`, Archivable = false, 400 studs up).

## Prototypes (v1, 2026-10-16, Hunter: "Prototype the rest of them. Don't go too crazy though")
13 constructs, 2-9 glowing pieces each, saved as models in `ServerStorage.EmoteFXPrototypes.<emoteId>` (no code uses them yet). Each model: a root part (named after the clip's joint for the scythe and board), attributes `Part0` (body part it sits on), `C0` (offset from that part), `Joint` (Motor6D name the clip animates, or empty) and `Note`. Pieces are anchored in storage; the runtime will unanchor and weld them.

| Emote | Construct | Sits on |
|---|---|---|
| Reaper's Ride | scythe (shaft + crescent blade), wisps | Torso, via the clip's scythe joint |
| Surfer | surfboard with stringer and fin, tail spray | HumanoidRootPart, via `Surf` |
| Toilet Sit | toilet: seat, bowl, tank | HumanoidRootPart |
| Company Dance | office desk + laptop (guess: hands rest at desk height) | HumanoidRootPart |
| Ice Cream Cart | handle, cart, wheels, umbrella, pink scoop | HumanoidRootPart |
| Couch Nap | couch: seat, back, arms, pillow | HumanoidRootPart |
| Sunbath | reclined lounger + pink towel | HumanoidRootPart |
| Blossom Break | pink blossom tree behind, falling petals | HumanoidRootPart |
| Shadow Emerge | dark violet shadow pool with a glowing rim, rising smoke | HumanoidRootPart |
| Coconut Launch | cannon behind the feet (smoke puff) + coconut in the hands | HumanoidRootPart |
| Trick or Treat | pumpkin bucket | Right Arm |
| Gambler Dance | two dice | Right Arm |
| Threaten | bat hanging at the side (guess) | Right Arm |

Skipped: **Honored One** (floats on its back with arms spread: a power pose, no prop implied).

Screenshots: `docs/emote-fx/emote_constructs_sheet_v1.jpg` (all 13) and one `<id>_construct_v1.jpg` per emote. Furniture is fixed to the root part, so it stays put while the body moves; held props follow the hand.

Known limits: Sunbath stands up mid-clip, leaving the lounger empty for a moment; the Surfer's feet lift ~0.6 studs off the board on the hops; shapes are blocky by design (parts only, no meshes, nothing to upload).

## Plan once the look is approved
1. Store each construct as a model in `ReplicatedStorage.EOS_EmoteFX.<emoteId>` (root part named after the joint, `Part0` + `C0` attributes); `EmoteConfig` entries get `fx = true`.
2. Client (EmoteController, where the emote clip and song already play for every character): when a character's `EOS_Emote` is set to an fx emote, clone the construct, Motor6D it to the body part, fade it in (~0.4 s shimmer); fade out and destroy when the emote stops or the player moves.
3. Phones: particles capped, constructs skipped beyond ~120 studs.
4. Then pick the next emotes from the lists above with Hunter.
