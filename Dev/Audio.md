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
Direction (Hunter, 16 Oct): sporty and mindful of Huss Valley; the game is moving away from bright and kiddy. All tracks are APM Music.

| State | When | Tracks |
|---|---|---|
| lobby | lobby, menus, after the results sting | Sports Hip Hop underscores: Want to be Great, Ain't No Competition, Go Hard or Go Home |
| match | role reveal and crossings | Trailer Beats – Sports Hip Hop: Heat Check, Endgame Drive; Sport – Bass and Drums: In The Race |
| tension | the last 12 s of a crossing, or 2 runners left (held until the crossing ends) | Trailer Beats – Sports Hip Hop: All Or Nothing |
| results | first 9 s of the results screen | silence; the sting plays: win = Looking at the Winner (30 sec), lose = a final buzzer |

- Each state keeps its own player. Leaving a state pauses its track and coming back resumes it, so a crossing → tension → crossing round trip continues the same song. Each new match starts the match playlist fresh.
- Tracks are levelled with a measured per-track gain (`{ id, gain }` in `MUSIC`). The Music toggle in Settings fades the EOS_Music SoundGroup, and big moments (hatch reveal, results) duck it.
- Rejected, don't reuse: Paradise Falls, Tender Tropical House, Really Fast, Funky (A). Also dropped as too kiddy: the slide whistle (lose) and the cute pop (toasts).
- To swap a track, change its id in `MUSIC` in `roblox/game/Sound.luau`, measure its loudness and set the gain.
