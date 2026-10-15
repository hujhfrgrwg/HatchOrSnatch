---
tags: [research, roclicks]
source: https://roclicks.gg/resources/vfx/checklist
retrieved: 2026-10-15
---
# Sound and VFX checklist

Run this before calling audio or effects "done". Each line links back to the bug it prevents.

Run this before calling audio or effects "done". Each line links back to the bug it prevents.

## Sourcing and upload

- All audio comes from licensed online libraries (CC0 Kenney/OpenGameArt, Mixkit SFX), never the Toolbox. *Toolbox audio from another creator plays as silence.*
- No music from a library whose music licence forbids games. *Mixkit's music licence does.*
- CREDITS.md lists source URL and licence per file.
- Files are trimmed, loudness-normalised per group, limited, faded or loop-wrapped (`tools/prep_sfx.py`).
- Uploaded with the **group that owns the game** as creator. *Personal uploads show "not approved" or play silent.*
- Ids mapped into the registry by script.
- Every id preloads (`IsLoaded`, `TimeLength > 0`); failures have a `fallback` id.
- A human listened in Studio (the agent can't hear).

## Registry

- One `Sounds` config with groups UI / SFX / Ambience / Music; gameplay code plays by name only.
- Victory and defeat stingers are **not** in Music. *Muting music muted the win sound.*
- `supersedes` set on milestone sounds. *Two reward sounds stacked on one frame.*
- Unknown names warn with the caller; a test checks every literal name used in source. *`"purchase"` vs `ui_purchase` failed silently.*
- No unused registry entries. *`train_complete` existed and was never played.*
- Each moment's sound has exactly one owner. *The fanfare played twice from two systems.*
- Loops stop when the owner **dies**. *Wrecked vehicles kept their engine loops.*
- Beds stop on destroy as well as on finish.
- Noisy repeats capped (voices, cooldown) and checked in the biggest fight.
- Repeated cues per event capped (≤ 5) and pitched up.

## Music and ambience

- Composed music, never random-note generative. *Players rejected it.*
- Music default is quiet.
- One ambience bed per weather/state on a named layer.
- Battle bed follows intensity and camera distance.

## VFX

- Effects are particles, beams and trails only; no Parts, spheres, Neon rings or physics debris. *The developer rejected 3D puffs.*
- One licensed texture pack, catalogued (grid, background, id).
- Explosions layered: flash, fire, smoke, sparks, debris, dust; offsets, rotation, staggered delays.
- Smoke is opaque with `LightInfluence 1`, in warm colours checked against rendered pixels. *A cyan sky turned grey smoke blue.*
- Verified in a playtest from the player's camera (particles freeze in edit mode).

## FX controller

- Templates in ReplicatedStorage with `Kind` and `EmitCount`; all plays go through one FX controller.
- Pooled records carry a generation counter checked by every timer and handle. *Stale timers parked reused effects mid-play.*
- Per-class token-bucket budgets, live caps and culling; drop, don't queue.
- Low quality is the default on phones; counts halved, weather capped.
- No camera shake from thunder or other ambient events.
- Runtime sound and FX folders are `Archivable = false` in edit mode; place audited before publish. *A saved sound pool played battle noise in every server.*

## Feedback

- Sound + burst + float text for collect, purchase, build, upgrade, level-up, tier-up, train complete, victory, reward, error.
- All of them go through one `Feedback.moment` helper.
- Every server event that matters has a client listener.

Previous: [[FX controller, pooling and budgets]] · Next: [[Anatomy of an impact]]
