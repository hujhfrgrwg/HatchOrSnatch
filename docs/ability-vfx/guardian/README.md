# Guardian VFX (HOS-VFX-002)

Preview: `guardian_preview.mp4` (gameplay angle, then side). Stills: shield up, shield shatters, tether.

- **ShieldUp** (Runner, on the press): blue ring at the feet with a dark twin, a blue shield crest rising over the head, sparks.
- **ShieldBubble** (lasting): the ForceField sphere stays (deeper Guardian blue), clients add a swirling blue rim with a dark twin and sparkles.
- **ShieldBreak** (the shield blocks a tag): flash, a cracked blue shield over the head, shards, spiky ring; the bubble disappears at the same moment.
- **TetherBeam** (Catcher windup, 0.4 s): real Beams drawn on each client between the Catcher and the Runner (dark backing, blue energy rope, light core) plus pulsing hook rings and sparks on the Runner. The server no longer stretches a part every frame.
- **TetherYank** (the pull lands): flash, streaks flying towards the Catcher, ring.

Checked in a 2-player playtest: bubble + raise burst at 0.05 s, shatter shows and the bubble goes on a blocked tag (Runner stays a Runner), tether shows 3 beams on the Runner's screen for the windup, yank 0.42 s later, no errors.
