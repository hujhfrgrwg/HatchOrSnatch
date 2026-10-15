---
tags: [research, roclicks]
source: https://roclicks.gg/resources/video-audio/music-and-ambience
retrieved: 2026-10-15
---
# Music and ambience

In a player test of a chiptune RPG prototype, the first music was random-note generative: a procedural melody over a procedural bass. The players' verdict: they liked 8-bit music, "but not this".

## Contents

- [[#Composed music beats generative music]]
- [[#Music per state]]
- [[#Ambience beds per weather or state]]
- [[#Intensity beds]]
- [[#Checklist]]

## Composed music beats generative music

In a player test of a chiptune RPG prototype, the first music was random-note generative: a procedural melody over a procedural bass. The players' verdict: they liked 8-bit music, "but not this". Composed melodies (a pulse lead plus a triangle bass, written as real tunes) replaced it, and the complaint went away.

- Use **composed** tracks, either licensed (CC0 game music from OpenGameArt) or written note by note. A random walk over a scale never sounds like a song.
- Procedural "music pads" built in a sound script also rated "weak" next to real CC0 orchestral and militaristic loops in a later pass.
- **Default music volume low.** About 0.18 for a chiptune lead; 0.4–0.45 for orchestral loops already normalised to −18 dBFS. Players turn loud music off and never turn it back on.
- Loop length 90–120 s is enough. Trim long tracks to their first two minutes and crossfade the wrap.

## Music per state

Have a small set: `music_menu`, `music_build` (home/peaceful), `music_battle`. Switch with a 1–2 s crossfade on state change. Don't restart a track that is already playing when the state "changes" to itself.

Big moments are **stingers**, not music: a fanfare for victory, a dark sting for defeat. They duck the music for their length and live in the UI group (see [[The sound registry|sound-registry.md]]).

## Ambience beds per weather or state

Give each world state its own looping bed on a named **layer**, so the beds on one layer replace each other:

| Layer     | Beds                                                                         |
|-----------|------------------------------------------------------------------------------|
| `weather` | `birds_ambience` (clear), `rain_loop` (rain/storm), `wind_loop` (windy/snow) |
| `battle`  | `battle_ambience_loop` (distant gunfire and explosions)                      |

- Starting a bed on a layer fades out whatever else is on that layer.
- Thunder is a one-shot in the Ambience group, triggered by the weather system, with a flash. **Don't shake the camera on thunder.** A storm that shakes the camera every 4–13 s while a kid is placing a building is just annoying.
- The default bed is what players hear most of the time. If its id fails moderation, home is silent for everyone. Give it a fallback id and verify it first.

## Intensity beds

A battle bed at a flat volume either buries the action or vanishes. Drive it from the fight:

- Count shots per second (explosions and heavy weapons count triple) and map that to `0.35` to `1.2` times the bed volume, smoothed.
- Fade the bed to 25% when the camera is far from the battle, so a fight the player isn't watching stays in the background.
- Measured result: the bed went 0.17 → 0.42 → 0.19 as a raid built and ended, which is what you want.

Expose it as `Sound.ambienceLevel(name, mult)` so the battle view can push a number each frame.

## Checklist

- Music is composed (licensed or hand-written), never a random-note generator.
- Default music volume is low; stingers are separate from music.
- One bed per weather/state on a named layer; beds on a layer replace each other.
- The default home bed's id is verified, with a fallback.
- Battle bed volume follows intensity and distance.
- No camera shake from ambient weather.

Previous: [[Sound sourcing and upload]] · Next: [[Roblox-legal gameplay trailers]]
