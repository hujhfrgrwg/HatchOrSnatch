---
tags: [delivery, lobby, emotes]
ticket: HOS-EMOTE-002
date: 2026-10-18
---
# HOS-EMOTE-002: emote hologram on the Obelisk podium

Matthew: "Using the obelisk podium, let's have it be a rig for cycling through all the emotes. we can have it be it's own player as a ghost (forcefield) purple and have a beam below it kinda as if it's showing a hologram projection light from the ground." Follow-ups while building: "Too transparent", and "have it float up a bit with slight up and down. when it swaps through emotes, have it suck in and out from the bottom too". The Obelisk is where Matthew placed it, on the north side at about (26, 10, 1454).

## What players see
- **A hologram of you:** a copy of your own avatar with the clothes and face removed. Every part is **ForceField** in purple (176, 98, 255). **Each body part and accessory has its own Highlight** (fill 0.35, light purple outline), so every limb, the head and each hat or hair piece is outlined separately, not just the silhouette (Matthew's follow-up).
- **Floating:** it floats 0.9 studs above the podium's glow disc and bobs ±0.15 studs.
- **The emotes:** it plays **every emote in EmoteConfig (51)** in the list's order, with the emote's name above it in its rarity colour. A looping emote shows for whole loops, about 5.5 s (4–9 s); a once-only emote plays through and holds 0.6 s. Emotes that mime a prop (Trick or Treat's bag, Reaper's Ride's scythe, Surfer's board ...) get their light construct, as on a player.
- **Swapping:** between emotes it **sucks down into the projector** (0.22 s, shrinking to 5% toward the disc as it fades) and **grows back out** with the next emote (0.3 s). It also flickers briefly every few seconds.
- **The projector:** a soft purple cone of light from the disc that fades out around the chest (two camera-facing Beams, kept dim so the figure reads through them), small specks drifting up and a soft purple light.
- **Sound:** none. Emote songs only play on players and lobby NPCs.

## How it works
- **New client module** `StarterPlayer.StarterPlayerScripts.EOS.Controllers.EmoteShowcase`, started from `WeaponFXBoot`.
- **Data-driven:** any model tagged `HOS_EmoteShowcase` runs it. Tagged: `Workspace._PodiumPreview.Podium_Obelisk` (the lobby one) and the master `ServerStorage.HOS_RigPodiums.Podium_Obelisk`. `tools/build/HOS-POD-001_rig_podiums.lua` now tags the Obelisk, so a rebuild keeps it.
- **The copy** is built like the lobby pedestals' (`WeaponPedestals.makeAvatarTemplate`), then turned into the hologram. It stands on `StandGlow.RigStand`, facing the way the Dummy faced. The Dummy stays in the place and is removed on each client.
- **Emote clips** use each emote's published `animId`, so it works live. Each clip's show time starts once it has loaded, and the next one starts loading early. A clip that doesn't load in 6 s is skipped.
- **Prop constructs:** the copy carries `EOS_Emote` and `EmoteFX.update` builds the construct, the same way the results podium does.
- **The swap shrink** uses `Model:ScaleTo` on the copy. The root's height is scaled with it, so the figure shrinks toward the disc.
- **Performance:** looks only, nothing goes to the server. It rests in a match, when the camera is away from the lobby, and beyond 60 studs. Everything lives in a client-only folder, `Workspace.HOS_EmoteShowcase`; constructs go in `EOS_EmoteFXLive` like everyone's.

## Checks (Studio playtest, 18 Oct)
- The hologram had 8 ForceField parts plus the hidden root, no clothing, and showed the sign. Emote sequence: `thumbs_up 0.0, loser_dance 4.1, snappy_skip 9.6, idle_dance 15.2` (about 5.5 s each once loaded).
- Trick or Treat built its construct (`EOS_EmoteFXLive.trick_or_treat_EmoteHologram`).
- The scale dropped to 0.05 at a swap and was back to full after. At full size the root rode 0.9 ± 0.15 studs above standing height.
- No errors. The sword showcase, the pet showcase and the five weapon pedestals still ran alongside it.
- Screenshots: `docs/HOS-EMOTE-002_hologram_tpose.jpg` (floating, the cone below), `docs/HOS-EMOTE-002_hologram_trick_or_treat.jpg` (before the float), `docs/HOS-EMOTE-002_hologram_loser_dance.jpg`.

## Highlight budget
Roblox draws at most 31 Highlights at once, and the game's match outlines (`Outlines`: red Catchers, blue teammates) use them too. So the hologram uses at most `GLOW_MAX` = 16: the body parts first, then the largest accessories. A very accessory-heavy avatar leaves its smallest pieces unoutlined; they keep the ForceField and fill colour. All of them are switched off whenever the showcases rest (in a match, or with the camera away from the lobby). Checked: 8 Highlights for an 8-part avatar near the podium, 0 with the camera away, 8 again on return. Screenshot: `docs/HOS-EMOTE-002_hologram_part_outlines.jpg`.

## Notes
- The sign is plain FredokaOne text, like the pet showcase's.
- The Obelisk still sits inside `_PodiumPreview`. Move it out before that folder is deleted.

## Backup and undo
- `WeaponFXBoot` as it was: `docs/backups/HOS-EMOTE-002_2026-10-18/WeaponFXBoot.lua`.
- Studio undo step: "HOS-EMOTE-002 emote hologram showcase" (module, start line, tags). The module's source was set afterwards, then edited for the look and the float/swap.
- ScriptHistory updated (`EmoteShowcase.lua` new, `WeaponFXBoot.lua`).
