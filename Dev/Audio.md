---
tags: [dev, audio]
updated: 2026-10-16
---
# Audio

All game audio goes through one client module: `roblox/game/Sound.luau`, which runs as `StarterPlayer.StarterPlayerScripts.EOS.Controllers.Sound`. Ticket HOS-AUDIO-001; the pre-edit copies are in `docs/backups/HOS-AUDIO-001_2026-10-16/`.

## Sources (licensed, real recordings)
- **Pro Sound Effects** (Toolbox creator `ProSoundEffects`): Roblox's licensed effects library. Most game sounds come from here. Anything labelled "Synth" is skipped (Hunter's rule).
- **Roblox UI pack** (`Roblox_UI_*`, made by Roblox): clicks, whooshes and pops.
- **APM Music** (`APMOfficial`): Roblox's licensed music library.
- No user uploads. Most of them are rips from other games.

## What plays when
| Name | Moment | Sound |
|---|---|---|
| click / open / close / tab / toggle / pop / error | UI | Roblox UI pack, temple block, switch |
| reward / purchase | gold, claims / shop buy | coin jingle / cash register |
| tick / go / role / alert | countdown / crossing starts / role reveal / last one standing | temple block / referee whistle / tonal stinger / indicator |
| swing / dash / caught / capture | tag / dash / you're caught / a steal (others' steals are 3D, positioned) | whooshes, body hit, body grab |
| evolve | safe crossing, egg levels up | bell tree |
| crack / reveal / applause | hatch shake / new pet | egg crack, bell tree, applause |
| poof / ping / ability | Decoy / Scout / other pet abilities | magic poof, triangle, airy whip |
| win / lose | results | APM Celebration Fanfare / slide whistle |

Every effect was checked in the place (16 Oct): all load, and each one's lead-in silence and loudness were measured with an AudioAnalyzer. The table in `Sound.luau` holds the trims (start offsets) and levelled volumes. For example, the reveal bells start 1.8 s in.

## Music
- The system is wired: lobby and match playlists, crossfades, ducking under the hatch reveal and the results sting, and a Music toggle in Settings (`settings.music`, saved by the server).
- **The playlists are empty.** Hunter rejected the first picks on 16 Oct (Paradise Falls, Tender Tropical House, Really Fast, Funky (A)). Add asset ids to `MUSIC.lobby` / `MUSIC.match` in `Sound.luau` once tracks are chosen.
