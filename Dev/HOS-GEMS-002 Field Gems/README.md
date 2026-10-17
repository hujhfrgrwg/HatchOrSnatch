# HOS-GEMS-002 Field Gems (17 Oct 2026)

Hunter showed a reference game that "spawns gems on the map, more as it gets into the later rounds but a modest amount". This is our prototype of that.

## What it does
- Each crossing drops a few green Gems on open field: 1 in crossing 1, 2 in crossings 2 and 3, 3 from crossing 4 on.
- They sit away from the safe zones (14 studs) and off the Catchers' start line, so a Runner has to leave their lane and risk the Catchers to grab one.
- A Runner who isn't safe yet picks one up by running into it. Catchers can't (they'd camp the Gems instead of chasing). Switch: `GameConfig.FieldGems.RUNNERS_ONLY`.
- Gems left on the field vanish when the crossing ends.
- Each is worth 1 Gem, paid with the match's other Gems on the results screen. Most you can pick up in one match: 2 (`EconomyConfig.GEMS.FIELD_CAP`). Practice matches never save, like every reward.
- Fewer than 20 real players scales the count down (never below 1), so small servers aren't flooded.
- Kill switch: `GameConfig.FieldGems.ENABLED = false`.

## Budget (Design/Economy Decisions.md, decision 31)
- Decided budget: about 0.67 earned Gems per match, about 30/h at 45 matches/h ("1 for a win + 1 for the first snatch, at most 2 per match").
- Field supply for a 4-crossing match: 1 + 2 + 2 + 3 = 8 Gems shared by about 30 players, so about 0.27 per player per match, about 12/h on average. A player who chases them gets at most 2 a match.
- That is too much to add on top. **To fit, field Gems take the place of the first-snatch Gem:** Gems a match = 1 for a win + up to 2 from the field, still at most 2. Catchers still get the snatched egg, which is the real snatch reward. The average stays near 30/h if the first-snatch Gem averaged about 0.27 a match (inferred, not measured; re-check from playtest telemetry `FieldGemPicked` and `RewardGranted`).
- The place still runs the old formula (up to 5 Gems a match, about 151/h). The decided formula isn't in the place yet; this ticket only adds the field term inside the existing cap. Switching to the decided formula is a separate change.

## Look
- Gem: `ReplicatedStorage.EOS_FieldGemTemplate` mesh if present (our HUD gem: green brilliant cut), else a green glass cube on its point.
- Client spins and bobs it, with a lean glitter sparkle and a soft green light (no Neon).
- Pickup: ring, rays and glitter burst from the AllVFX pack (already-uploaded `av_ring_glow`, `av_burst_rays`, `av_glitter`), a chime for everyone nearby, and for the collector a rising-pitch chime and a green "+1" floating up. "MAX" when at the cap.

## Files
- `ServerScriptService/EOS/Services/FieldGemService.lua` (new)
- `StarterPlayer/StarterPlayerScripts/EOS/Controllers/FieldGems.lua` (new)
- `PATCHES.md`: the small edits to GameConfig, EconomyConfig, MatchLogic, MatchService, Net, Analytics, Bootstrap, ClientMain and Sound.
