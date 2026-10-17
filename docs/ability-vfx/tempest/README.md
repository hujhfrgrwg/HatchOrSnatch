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

## Storm Ball v2 (HOS-VFX-003b)
Preview: `stormball_v2_preview.mp4` (gameplay angle, then side). Stills: `stormball_v2_still_1.jpg` (gameplay), `stormball_v2_still_2.jpg` (side).

- **Energy orb** (drawn on each client; the server's ball is hidden there and stays the gameplay part):
  - a dark metal core with three glowing yellow seams;
  - a crackling amber ForceField shell with a dark-brown outline so it reads on sand;
  - a yellow light.
  - It spins as the server rolls it.
- **Lightning cage:** three electric beams that jump around the shell about 20 times a second.
- **Floor arcs:** two bolts (with dark twins) that jump from the ball to random floor points.
- **Ground trail:** a dark scorch mark and a yellow electric streak along the path, fading out over about 0.5 s.
- The earlier arcs, halo, sparks and dust are kept. The gameplay numbers are unchanged.

Checked in a 2-player playtest: the orb, 7 beams and 2 trails are drawn, the server ball is hidden on the client, bounce at 0.36 s, hit and slow at 0.59 s, everything is cleaned up afterwards, and there are no errors.
