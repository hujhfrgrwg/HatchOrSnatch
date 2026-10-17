# HOS-EGG-002 stage 6: full playtest (17 Oct 2026, ~11:25-11:55Z)

One claimed, self-closing solo playtest (claim line `PLAYTEST | Economy and name review (HOS-EGG-002 stage 6)`, removed
after). The knife-test sandbox flag (`workspace.EOS_Sandbox`) was turned off only on the playtest server, so matches could
run, and turned back on there at the end to stop new auto matches. The edit place's flag was never changed.
Device: the iPhone-sized simulator (844x390) with touch controls. Stills and a clip are on the review page (`review/img/s6_*`).

## The run
| Step | Seen | Result |
|---|---|---|
| Full match | 5 crossings, 22 participants, ended `SAFETY_CAP` | ok |
| Crossing 1 | a juke: `EggCharged` +0.25, a "+CHARGE" pop, a one-time tip ("Brave plays charge your egg.") | ok |
| Safety, crossing 1 | Common to Rare at charge 0.25, then charge resets; the RARE EGG! banner shows with its plate the first time (warm-up fix) | ok |
| Caught | my player was caught while idle and became a Catcher. Cap `EOS_EggCap = epic` (starting-Catcher cap), no stash | ok (Catcher path) |
| Results | "NO EGG THIS MATCH" plus the hint; no shard row | ok |
| Profile listener | the incubator showed the real fill at once (0 / 30), not the sample | fixed (stage 5 fix verified) |
| Focus | SetFocus(Decoy) via the remote: `FocusChanged`; the fill target changes to 37.5 and "+25% TO FILL" is lit | ok |
| Focus chip | **bug found:** the selected Decoy chip drew black and the white ring stayed on Any (see below) | fixed |
| Hatch | lobby only (a hatch during the auto match was refused, as designed). Hatch: `IncubatorHatched` rare, focused=true, family Decoy, fillUsed 37.5, duplicate=false. Ceremony "NEW PET! Shadow Crow · Rare · Decoy" | ok |
| After | 2.5 / 37.5 FILL, shards 0, odds 90/10/0, focus stays Decoy, HATCH greyed | ok |
| Early end | an extra auto match capped after crossing 1: 4 bonus rolls per egg holder (`EggRolled` bonus=true, rolls 4, matchCrossings 1) | ok |

The profile was seeded on the playtest server (fill 40, 12 Rare and 8 Epic shards) to reach a full egg in one session.

## Telemetry
Counts from the playtest server's event log: EggRolled 84, EggCharged 3, MatchEnded 2, HeroChickenResult 1, FocusChanged 1,
IncubatorHatched 1. All of these names are in `Analytics.KNOWN` (no unknown names). No `ShardGranted` this run: the only real player
ended as a Catcher with no stash, so got no shard. ShardGranted was seen in the stage 3 runs.

## Fixes re-verified
- Banner plate preload: RARE EGG! showed with its plate the first time. The warm-up holder is now at (0, 0) on screen.
  The old off-screen spot never decoded: 0/9 loaded off screen, 9/9 on screen.
- Profile listener order: the real fill showed at once.
- Mini ring placement: not re-seen (no shard this run). Last seen right in the previous run's results card.

## Bug found and fixed: focus chip
`show()` toggled a chip's Sel / Open / Locked plates but not their exported `DropShadow` siblings. A chip built in its Open
state kept Open's opaque shadow, drawn over its Sel plate, so the selected chip was black. Separately, the ring moved
`FocusSel` by the plate's offset inside the chip. That ignored the chip's own offset and its runtime centre anchor, and the
visible white ring is FocusSel's outline twins (`ShadowRing`). Both are fixed in `EggUIController`
(31007:242595952): checked live first by applying the same changes to the running client, then installed in the edit place.
