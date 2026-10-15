---
tags: [research, roclicks]
source: https://roclicks.gg/resources/video-audio/game-music-loops
retrieved: 2026-10-15
---
# Game music that loops without a seam

Planning a score, cutting loops on the bar line, mastering quieter than a song, and wiring it with SoundGroups.

## Plan before generating anything

- **Instrumental by default.** Vocals fight the game's sounds, and lyrics are banned in game page videos anyway.
- **One key and one tempo family per game,** so zone tracks crossfade cleanly into each other.
- **Genre from the game's feel:** cosy idles and sims suit lo-fi or chiptune; combat wants drive.
- Keep a cue sheet: every track, where it plays, its key and tempo.

## Cut a seamless loop

1.  **Bar length:** seconds per bar = 4 x 60 / BPM (in 4/4). Make the loop a whole number of bars.
2.  **Cut on a bar line** after the intro, so the loop starts at full energy rather than replaying the intro.
3.  **Hide the seam:** crossfade the loop's last ~0.5 s into its first ~0.5 s.
4.  **Zero crossings:** trim a few milliseconds so both ends sit at silence or a zero crossing. That removes the click.

Listen to the seam at least twice in a row before calling it done.

## Master quieter than a song

Background music sits around **-18 LUFS** integrated, quieter than a streaming song, so effects and UI sounds stay on top. Export OGG or MP3 at 44.1 kHz stereo and keep files small.

## Wire it in Studio

- **SoundGroups:** `SoundService.Music`, `SFX` and `UI`, each with its own volume, so settings sliders control whole categories.
- **Music plays on the client.** It's presentation, and per-player zone music can't be done from the server.
- **Zone music:** one Sound per cue, crossfaded when the player changes zone.
- **Intensity layers:** start every layer of a cue at the same moment (some silent) and fade layers in, so they stay in sync.
- **Stingers** (win, level up) are separate non-looping sounds in the SFX group; duck the music briefly under them.
- Give players a music volume slider bound to the Music group, and save it.

Previous: [[Roblox-legal gameplay trailers]]
