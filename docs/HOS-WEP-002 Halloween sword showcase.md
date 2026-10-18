---
tags: [delivery, lobby, weapons]
ticket: HOS-WEP-002
date: 2026-10-18
---
# HOS-WEP-002: All Hallow's Sword on the Halloween podium

Matthew: "put the hallow's sword on the rig. Have the showcase of it be the weapon equipped by the person's own avatar in the rig and have it loop through the jab animation, lunge animation, and idle."

## What players see
On the Halloween **Harvest** podium (HOS-POD-001, standing on the island at about (-42, 10, 1468)), each player sees **their own avatar** holding the **All Hallow's Sword** (Legendary, the featured weapon), facing the middle of the lobby. It loops:

1. idle (Roblox R6 idle, always playing underneath),
2. **jab** (`SwingJab`), with the Legendary slash from WeaponFXBoot,
3. a short idle,
4. **lunge** (`LungeStab`, the Catcher's two-handed overhead stab),

then back to the start. Measured in a playtest: a jab, the lunge about 2 s later, the next jab about 2.8 s after that. The sword gets the Legendary hand aura and pulsing glow like the lobby pedestals' weapons.

## How it works
- **New client module** `StarterPlayer.StarterPlayerScripts.EOS.Controllers.WeaponShowcase`, started from `WeaponFXBoot` right after `WeaponPedestals`.
- **Data-driven:** any model tagged `HOS_WeaponShowcase` with a `ShowcaseSkin` attribute becomes a showcase. The Harvest podium in `Workspace._PodiumPreview` and its master in `ServerStorage.HOS_RigPodiums` both carry the tag and `ShowcaseSkin = "rb_all_hallow_s_sword"`. `tools/build/HOS-POD-001_rig_podiums.lua` now adds both, so a rebuild keeps them. To show a different weapon, change the attribute.
- **The avatar:** a copy of your character (same clean-up as the lobby pedestals: no scripts, knife, egg, pets or name tag) stands on the podium's `StandGlow.RigStand`, facing the way the grey `Dummy` faces. The copy lives in a client-only folder `Workspace.HOS_WeaponShowcase` and updates when your character respawns (outfit changes).
- **The Dummy** stays in the place so the spot is visible in Studio. Each client removes it locally. If there's no R6 look to copy, the Dummy itself holds the sword instead.
- **Reuse:** `WeaponPedestals` now exports `makeAvatarTemplate` and `wield` (two lines) so both features build the copy and weapon the same way.
- **Performance:** looks only. Nothing goes to the server, and it rests in a match or when the camera is away from the lobby (`LobbyGate`).

## Needs doing before it's live
- **The lunge clip isn't published.** `AnimConfig.ids.LungeStab` is `""`. Studio plays the local KeyframeSequence (`ReplicatedStorage.EOS_Animations.LungeStab`); a live server skips the lunge and the showcase loops idle and jab only. The Catcher's real lunge has the same gap. Publishing the clip to the group (Eggs with Friends) and filling the id fixes both.
- The Harvest podium still sits inside `_PodiumPreview` (which HOS-POD-001 says to delete once a podium is picked). Move it out of that folder before deleting it; the tag goes with it.

## Checks (Studio playtest, 18 Oct)
- The copy had the player's own clothes, body colours and hair, held `rb_all_hallow_s_sword` on the right hand, and stood on the stand at the podium's facing. The Dummy was gone on the client.
- Track log over 12 s: `SwingJab 1.82, LungeStab 3.77, SwingJab 6.58, LungeStab 8.53, SwingJab 11.34`, with Idle looping throughout.
- No errors in the output. The five lobby weapon pedestals still showed their avatars, all holding weapons.
- Screenshots: `docs/HOS-WEP-002_showcase_lunge.jpg` (mid-lunge) and `docs/HOS-WEP-002_showcase_idle.jpg`.

## Backup and undo
- The two edited scripts as they were: `docs/backups/HOS-WEP-002_2026-10-18/` (`WeaponPedestals.lua`, `WeaponFXBoot.lua`).
- Studio undo step: "HOS-WEP-002 Halloween sword showcase" (tags, exports, start line). The module's source was set afterwards with `set_script_source`.
- ScriptHistory updated for the three scripts this touched.
