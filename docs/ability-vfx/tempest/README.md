# Tempest VFX (HOS-VFX-003)

Preview: `tempest_preview.mp4` (gameplay angle, then side). Stills: pulse blast, storm ball rolling, Runner hit and slowed.

Colour: Tempest yellow for the ball and sparks; ground rings in amber with a dark-brown twin underneath, because plain yellow disappears on the bright sand.

- **PulseCharge** (Runner windup, 0.3 s): amber warning ring the size of the real 10-stud push radius, small arcs.
- **PulseBlast** (the push): flash, amber shock ring with a dark twin, spiky ring, cel-smoke dust, lightning bolts, stars.
- **KnockHit** (each Catcher pushed): zap and streaks in the push direction.
- **StormBall** (Catcher, lasting): the ball itself is a solid yellow sphere with a dark outline and a rolling spin (one big readable shape). Clients add amber arcs, a halo, sparks and a dust trail along the floor (Wrecking Ball reference).
- **StormBounce** (any wall hit): flash, sparks, zap. On the first wall the ball bounces once; a second wall stops it. The total range stays 50 studs.
- **StormHit** (first Runner hit): a small smoke-and-spark pop plus bolts (it only slows, so no detonation).
- **Slowed** (1 s on the Runner): amber ring with a dark twin and arcs.

Gameplay change (authorised by the brief): `AbilityConfig.Tempest.Catcher.bounces = 1`. There are no pads and no detonation, and all other timings are unchanged.

Checked in a 2-player playtest with a temporary test wall:
- Pulse: warning ring at 0.09 s, blast and knock at 0.35 s, Catcher pushed 12 studs.
- Ball: drawn at 0.06 s, bounce at 0.39 s, hit at 0.6 s; the Runner is slowed ×0.5 for about 1.1 s.
- With a second wall: the ball stops there with no hit and is cleaned up.
- No script errors.
