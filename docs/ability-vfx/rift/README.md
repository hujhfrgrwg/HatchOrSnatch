# Rift VFX (HOS-VFX-004)

Preview: `rift_preview.mp4` (gameplay angle, then side). Stills:
1. Portal Hop: portals at both ends, from behind the Runner.
2. Portal Hop from the side.
3. Rift Blink warning reticle.

Colour: Rift pink #FF6EDC fading to violet, with dark violet twins and fill so it reads on sand.

- **RiftPortal** (Runner, PORTAL HOP, on the press): an upright portal at your feet and one at the landing spot, facing the way you go, for the 0.35 s windup. Each has a dark violet swirling fill, a pink swirl, a pink rim with a dark rim behind it, a soft glow and a flash as it opens. Pink-to-violet sparks are thrown along the rim and fall a little.
- **RiftArrive** (where you land; for Blink also where the Catcher left): a spinning pink swirl ring on the ground with a dark twin, a flash, glitter and stars.
- **RiftReticle** (Catcher, RIFT BLINK, 0.5 s warning): a pink targeting reticle with a dark twin on the landing spot, closing in as it locks on, with motes rising. It is drawn on the server's ring, so every Runner sees it for the whole windup.
- **RiftFizzle** (the spot went bad during the windup; cooldown refunded): a small grey-violet smoke puff with sparks.

## About DoctorStrangePortalVFX (ServerStorage, left untouched)
It is a ring of 37 invisible parts, each with 4 orange "spec" spark emitters (about 3,700 particles a second), plus a blurred glow.

It has **no glyph, rune or sigil textures**, so there was nothing recognisable to remove. I used its idea (sparks thrown along a ring) and its two spark textures (8292854478, 15264803886) in our own template:
- 12 points with one emitter each instead of 148 emitters (about 310 particles a second for 0.5 s per portal).
- Recoloured pink to violet.
- Added our own swirl, rim and fill layers (our uploaded textures).

## Server (Abilities.Rift)
- Portal Hop: two `Shared.vfx("RiftPortal", ground + 3.2, dir)`; the target ring is kept (invisible) as the gameplay telegraph part.
- Blink: the target ring is tagged `RiftReticle`.
- Landing fires `RiftArrive`; a fizzle fires `RiftFizzle`.
- No timings or distances changed.

## Checked (2-player playtest)
- Hop: both portals on the client at 0.07 s, arrive at 0.41 s, moved 12 studs.
- Blink seen from the Runner: reticle at the press, gone 0.65 s later, arrive bursts at both ends, Catcher moved 10.
- Wall dropped on the landing spot mid-windup: fizzle puff, no move.
- No script errors.
