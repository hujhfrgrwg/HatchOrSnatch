---
tags: [design, emotes, vfx]
updated: 2026-10-16
ticket: HOS-EMOTE-FX-001 (built, needs a playtest)
---
# Emote Light Constructs

Hunter 2026-10-16: add VFX to emotes "similarly to how Destiny 2 does. it makes objects out of vfx", but **only for certain emotes**, ones where the dance mimes a prop that isn't there, "such as the reaper one where it appears like the emote is supposed to be him riding a scythe, or the surfing one". Common emotes with no implied prop stay plain.

## What the clips tell us
The emote pack (`ServerStorage["52+ Emotes (R15/R6)"]`) shipped animations only, no props. But some clips still animate their original prop's joint, so a construct part with that joint's name, welded at the right offset, is moved by the emote itself:

| Emote | Prop joint in the clip | Part0 | Fitted C0 |
|---|---|---|---|
| Reaper's Ride (L) | `BÃ©zierCircle.003` (literal text, backslash and all) | Torso | `CFrame` stored on the sample model's `C0` attribute (scythe under the crotch, along the hands' line, blade in front) |
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

## Built (2026-10-16, Hunter: "Get them all done.")
In the place, wired into the game; edit-mode verified, **not playtested yet**.

- **Templates:** `ReplicatedStorage.EOS_EmoteFX.<emoteId>`, one model per emote (13). Attribute `Enabled` on the folder switches every construct off (`false`) without touching code. The prototype folder `ServerStorage.EmoteFXPrototypes` was removed (superseded).
- **Look (v2):** see-through Neon fill (~0.6) with a bright **hard-light edge** (SelectionBox) on every block piece, a soft light, a few particles. Pink for blossoms / umbrella / parasol / towel, orange jack-o'-lantern, violet shadow pool, cyan for the rest. Rebuilt from v1: desk (glass top, 4 legs, laptop, mug), lounger (+ parasol), blossom tree (two-part trunk, branches, six blooms), dice (bigger, pips), bat (tapered with tape and cap), cannon (bands, breech, carriage, hubs), cart (lid, cone + scoop, umbrella top), toilet (flush handle, roll), pumpkin (face).
- **Code:** `StarterPlayer.StarterPlayerScripts.EOS.Controllers.EmoteFX` (new, client). `EmoteController.watchCharacter` calls `EmoteFX.watch(char)` for every character (yours included), next to the song. Server untouched.
  - A character's `EOS_Emote` set to an emote with a template -> the construct is cloned into `Workspace.EOS_EmoteFXLive` (never inside the character), welded to its body part and built in bottom-to-top over 0.45 s with a sparkle burst. Cleared or changed emote -> 0.25 s fade-out and cleanup; character removed or died -> cleared.
  - Scythe and board: a Motor6D in the character named after the clip's joint, and EmoteFX plays that joint's keyframes from `ReplicatedStorage.EOS_Emotes` in time with the character's playing track (own clock as fallback), so they move with the dance even if the Animator doesn't pick up a joint added mid-dance.
  - Skipped farther than 140 studs from the camera; touch devices get half the particles.
- **Verified in edit mode** (harness on posed dummies, the real module): all 13 spawn, every piece fades in to its target, welds hold, scythe joint is removed on clear, swapping emotes replaces the construct, an emote with no template clears it, `Enabled = false` spawns nothing, distance cull skips far ones, the board's joint gets the clip's pose (2.24 studs lift at t = 0). Edit mode doesn't render Motor6D.Transform, so the moving scythe/board can only be judged in a playtest.
- Screenshots: `docs/emote-fx/emote_constructs_sheet_v2.jpg` and `<id>_construct_v2.jpg`.
- Backup before editing EmoteController: `docs/backups/HOS-EMOTE-FX-001_2026-10-16/pre_edit_EmoteController.rbxm`.

## Refit to real playback (2026-10-16, Hunter: "toilet sit is glitching out a bit")
- Cause: the clips are full of **weight-0 placeholder poses** (Toilet Sit 1,304, Blossom Break 630, Couch Nap 318, ...). Roblox's Animator ignores them and interpolates across; my first fits and the first videos read raw keyframes, so the dummy popped to standing and several props were fitted to poses players never see. Verified with the real Animator (`Animator:StepAnimations` in edit mode): Toilet Sit's torso holds a steady 0.65-stud offset, no pops. The emote itself never glitched in game.
- EmoteFX's clip-joint reader now skips weight-0 poses too (same as the Animator).
- Refits from real playback:
  - **Toilet Sit:** toilet moved +0.4 x, +0.7 z under the real seated hips (they were sinking into the tank).
  - **Ice Cream Cart:** the dance holds the hands at the mouth, it never pushes: a held cone + scoops at the face, the cart parked beside.
  - **Coconut Launch:** the dancer is upside down (head at the floor, feet up): rebuilt as an upright cannon they dive into head-first, with a lit fuse.
  - **Sunbath:** lounger lowered 0.35 (hips were under the seat).
  - **Surfer:** the body rides ~2.5 studs up and back: the board now follows the feet every frame (`Follow = "Feet"`: centred between the soles, along the feet, upright with the torso).
  - **Reaper's Ride:** the torso rocks ~50 deg and the rider faces sideways: the scythe now rides under the hips every frame, kept level and pointing where the rider faces (`Follow = "Hips"`), instead of seesawing through the body.
- New template attribute `Follow` ("Feet" | "Hips") handled by EmoteFX; the clip-joint path stays for future props.
- Known: Blossom Break's own clip sinks the body ~2 studs into the ground (only the head and an arm stay above); Gambler Dance rolls the dice on the floor so they dip into it; both are the clips, not the props.

## Video previews (2026-10-16)
`docs/emote-fx/video/`: one clip per emote and `emote_constructs_all.mp4` (all 13, labelled, ~1.6 min). Recorded from Studio's viewport in edit mode: a dummy is driven by Roblox's own Animator playing each emote's clip (`Animator:StepAnimations`, poses baked into the joints each frame) while its construct builds in, follows the body / hand / joint for 6 s and fades out, the same way `Controllers.EmoteFX` does in game.

## Needs Hunter's playtest
- Do each emote in the lobby: build-in, fade-out on stop / moving, a second player seeing it.
- Scythe and board actually following the dance (joint driven from the clip).
- Sunbath stands up mid-clip (lounger stays put); Surfer's feet lift ~0.6 studs off the board on the hops.
- Phone look and frame rate with several players emoting.
