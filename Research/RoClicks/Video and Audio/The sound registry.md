---
tags: [research, roclicks]
source: https://roclicks.gg/resources/video-audio/sound-registry
retrieved: 2026-10-15
---
# The sound registry

Put every sound in one ModuleScript in ReplicatedStorage (Sounds), keyed by name. Gameplay code calls Sound.play("cashcollect", pos) and never touches a SoundId.

## Contents

- [[#One registry, called by name]]
- [[#Entry fields]]
- [[#SoundGroups and the settings toggles]]
- [[#Supersedes: one reward sound per moment]]
- [[#3D sounds and voice limits]]
- [[#Common bugs and their fixes]]
- [[#Checklist]]

## One registry, called by name

Put every sound in one ModuleScript in ReplicatedStorage (`Sounds`), keyed by name. Gameplay code calls `Sound.play("cash_collect", pos)` and never touches a `SoundId`. Why:

- Swapping a sound, or re-pointing a failed upload to its fallback, is a one-line change.
- A script can preload and verify every id.
- Volumes and voice limits are tuned in one table instead of fifty call sites.

Play sounds on the **client**. The server sends an event ("Army.Trained", "Built") and the client decides sound, burst and text. Sounds created on the server replicate to everyone and can't be muted per player.

A generic version is in [snippets/SoundRegistry.luau](https://roclicks.gg/resources/code/sound-vfx/snippets/SoundRegistry.luau).

## Entry fields

``` lua
cash_collect = { id = "...", volume = 0.6, pitch = {0.95, 1.08}, group = "SFX", voices = 3, cooldown = 0.05 },
```

| Field        | Purpose                                                                                                             |
|--------------|---------------------------------------------------------------------------------------------------------------------|
| `id`         | Asset id. `""` means "not uploaded yet": play silently **but log once**.                                            |
| `fallback`   | Last known working id, used if `id` fails to preload.                                                               |
| `volume`     | Per-sound trim on top of the group volume. Files are already normalised, so this stays near 0.4–0.8.                |
| `pitch`      | Random `PlaybackSpeed` range per play, so repeats don't machine-gun. 0.92–1.08 for SFX, 1–1 for stingers and music. |
| `group`      | `"UI"`, `"SFX"`, `"Ambience"` or `"Music"`; maps to a SoundGroup.                                                   |
| `voices`     | Max copies of this name at once. Extra plays steal the farthest voice or are dropped.                               |
| `cooldown`   | Minimum seconds between two starts of this name.                                                                    |
| `rolloff`    | `{min, max}` studs for 3D plays (`RollOffMode.InverseTapered`). Plays beyond `max` are culled.                      |
| `duck`       | `{amount, seconds}`: dip music and ambience under this sound (explosions, fanfares).                                |
| `layer`      | Ambience only: beds on the same layer replace each other (`weather`, `battle`).                                     |
| `supersedes` | Names this sound replaces when both start within ~0.3 s.                                                            |

Scale `rolloff` by the world scale. If the world is built at 1/4 scale and the camera sits far up, author rolloffs at life size and multiply once at the bottom of the registry.

## SoundGroups and the settings toggles

Make one SoundGroup per group under SoundService and set `Sound.SoundGroup` on every voice. The settings page sets group volumes.

**Keep victory and defeat stingers out of Music.** Why: kids turn music off first, and with the stingers in Music they lost the single most rewarding sound in the game. Put stingers in UI (or a Stingers group) and let the Music toggle affect only the music beds.

Put beds in child groups (`MusicBed` under Music, `AmbienceBed` under Ambience) so ducking can scale the bed without touching the player's chosen volume.

Ducking that felt right: fast attack (~~80 ms), slow release (~~700 ms). Duck music by 85% for a fanfare (4 s), 25–40% for a big explosion (2 s), ambience by half as much as music.

## Supersedes: one reward sound per moment

The bug: a milestone raised a "good" toast, which plays `ui_reward`, and the caller also played `ui_levelup` on the same frame. Two reward sounds played on top of each other and the moment sounded muddy.

The fix is a registry field, not call-site discipline:

``` lua
ui_levelup = { ..., supersedes = { "ui_reward" } },
```

- If `ui_levelup` starts within 0.3 s **after** `ui_reward`, it cuts the reward.
- If `ui_reward` starts within 0.3 s **after** `ui_levelup`, it is skipped.

Test both orders. Also pass the sound through the toast (`toast(text, {sound = "ui_levelup"})`) instead of playing a second one beside it.

## 3D sounds and voice limits

- Parent 3D one-shots to an Attachment at the position (one pooled attachment per voice under `Workspace.Terrain`) instead of creating a Part.
- Measure your listener from the **camera**, not the character, in top-down or map-camera games.
- Cap noisy repeats. In a 150-unit battle, `rifle_shot` with 8 voices and a 25 ms cooldown was a constant hiss that buried explosions and the fanfare. 4 voices and a 70 ms cooldown, with the ambience bed carrying the density, was clearer.
- Virtualise loops: track every loop's position, but only give real voices to the nearest N.
- A land-flip wave played the same `build_place` thud 8–10 times. Cap repeats per event (at most 5) and **rise the pitch** across them (0.9 to 1.2) so it reads as a run instead of spam.

## Common bugs and their fixes

| Bug                                               | Cause                                                                                                                                                                         | Fix                                                                                                                                                 |
|---------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------|
| **Destroyed vehicles keep looping engine sounds** | Loops stopped only on model swap or despawn, not on death. Wrecks "idled" for the rest of the battle.                                                                         | Stop engine, rotor and afterburner loops (and their particle loops) in the death branch with a 0.5 s fade. Make `stop` idempotent.                  |
| **Fanfare plays twice**                           | Two systems each play `victory_fanfare`: the battle banner, then the conquest handler 1–5 s later. With `voices = 1` the second steals and restarts the first.                | One owner per moment. The second system plays a different, smaller cue (`conquest_flag`), or skips when the banner played within 6 s.               |
| **Missing sound names fail silently**             | `Sound.play("purchase")` when the key is `ui_purchase`: lookup returns nil, nothing plays, success feels broken.                                                              | Unknown names `warn` once with the caller's name; a test walks every `Sound.play("...")` string in the source and checks it exists in the registry. |
| **Training-complete never plays**                 | The server fires `Trained`, but no client listens; the `train_complete` entry exists and is never used.                                                                       | Grep the registry for unused names. Each one is either a missing listener or dead weight.                                                           |
| **Battle bed never stops**                        | The bed was stopped in `finish()` only; a view destroyed without `finish` left it running at home.                                                                            | Stop beds in `destroy()` too.                                                                                                                       |
| **Phantom loops in every server**                 | Edit-mode tooling ran the sound module, created a pool folder in SoundService with 3 playing Sounds, and **File \> Save** stored it. Every client heard battle noise at home. | Set `Archivable = false` on runtime folders when `not RunService:IsRunning()`, and replace any pool folder this session didn't create.              |
| **"Not approved" id**                             | Upload under the wrong creator, or moderation pending.                                                                                                                        | Fallback id; re-upload under the group.                                                                                                             |
| **Sound plays on wrong toggle**                   | Stinger in the Music group.                                                                                                                                                   | Stingers in UI.                                                                                                                                     |

## Checklist

- Every sound is played by name from the registry; no raw `SoundId`s in gameplay code.
- Unknown names warn; a test checks every name used in source exists.
- No unused registry names (each one is a missing listener or dead).
- Victory/defeat stingers are not in the Music group; the Music toggle leaves them audible.
- Reward sounds use `supersedes`; milestone moments play one sound.
- Each moment's sound has exactly one owner.
- Loops stop on death, and beds stop on destroy as well as on finish.
- Runtime sound folders are `Archivable = false` in edit mode.
- Noisy repeat sounds have voice caps and cooldowns tuned in a big fight.

Next: [[Sound sourcing and upload]]
