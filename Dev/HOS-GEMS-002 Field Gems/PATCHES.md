# HOS-GEMS-002 Field Gems: edits to existing place scripts

New scripts (copy in as ModuleScripts, same paths):
- `ServerScriptService/EOS/Services/FieldGemService.lua`
- `StarterPlayer/StarterPlayerScripts/EOS/Controllers/FieldGems.lua`

The edits below are written against the ScriptHistory snapshot on branch `claude/project-thread-kzlb7q`. If the live script has moved on, make the same change by hand at the same spot. Back up every script you touch to `docs/backups/HOS-GEMS-002_2026-10-17/` first.

## 1. `ReplicatedStorage/EOS/Shared/GameConfig.lua`
Add after the `GameConfig.Match = { ... }` table:

```lua
-- Field Gems (HOS-GEMS-002, 17 Oct; after the reference game Hunter showed): a few Gems lie on the field each
-- crossing, more in later crossings. Runners who aren't safe yet pick one up by walking into it. Each is worth
-- 1 Gem, paid with the match's Gems at settlement (EconomyConfig.GEMS.FIELD_CAP per match, inside CAP).
GameConfig.FieldGems = {
	ENABLED = true, -- kill switch
	PER_CROSSING = { 1, 2, 2, 3 }, -- Gems on the field in crossing 1, 2, 3, 4+ (the last entry repeats)
	FULL_AT_PLAYERS = 20, -- real players for the full count; fewer scale it down (never below 1)
	RUNNERS_ONLY = true, -- Catchers can't take them (they'd camp the Gems instead of chasing)
	PICKUP_RADIUS = 4, -- studs, flat, from the root
	ZONE_INSET = 14, -- studs: never this close to a safe zone (no free Gems on the doorstep)
	CENTER_GAP = 10, -- studs: never on the Catchers' start line
	EDGE_INSET = 10, -- studs from the side walls
	MIN_SPACING = 18, -- studs between two Gems
	HOVER = 2, -- studs above the ground
	TICK = 0.1,
}
```

## 2. `ReplicatedStorage/EOS/Shared/EconomyConfig.lua`
Replace
```lua
EconomyConfig.GEMS = { CAP = 5, ACTIVE = 1, FIRST_CROSSING = 1, SECOND_CROSSING = 1, VICTORY = 1, FIRST_THEFT = 1 }
```
with
```lua
-- + 1 per Gem picked up on the field (HOS-GEMS-002), at most FIELD_CAP a match, still inside CAP
EconomyConfig.GEMS = { CAP = 5, ACTIVE = 1, FIRST_CROSSING = 1, SECOND_CROSSING = 1, VICTORY = 1, FIRST_THEFT = 1, FIELD_CAP = 2 }
```
In `export type MatchOutcome`, add the line `fieldGems: number?, -- Gems picked up on the field`.
In `EconomyConfig.gemsFor`, just before `return math.min(M.CAP, n)`, add:
```lua
	n += math.min(M.FIELD_CAP or 0, o.fieldGems or 0)
```

## 3. `ServerScriptService/EOS/Core/MatchLogic.lua`
Add this method (e.g. after `MatchLogic:markActivity`):
```lua
-- HOS-GEMS-002: a Gem picked up on the field. Returns ok and this player's field Gems so far.
function MatchLogic:addFieldGem(userId: number, cap: number): (boolean, number)
	local p = self.participants[userId]
	if self.phase ~= "ACTIVE" or not p or p.disconnected then
		return false, 0
	end
	local n = (p :: any).fieldGems or 0
	if n >= cap then
		return false, n
	end
	(p :: any).fieldGems = n + 1
	return true, n + 1
end
```
Add `fieldGems = (p :: any).fieldGems or 0` to the `outcome` table in BOTH `computeResults` and the disconnected branch of `settlementFor` (so someone who leaves keeps the Gems they picked up), e.g.
```lua
local outcome = { active = eligible, crossings = p.crossingsCompleted, captures = p.captureCount, win = win, fieldGems = (p :: any).fieldGems or 0 }
```
and add `fieldGems = (p :: any).fieldGems or 0,` to the `perPlayer[id] = { ... }` table.

## 4. `ServerScriptService/EOS/Services/MatchService.lua`
a) After the `MatchService.onCatcherAttack` block, add:
```lua
-- HOS-GEMS-002: crossings start and end (field Gems). fn(c, event: "start" | "end" | "match", wave)
local crossingHooks: { (any, string, number) -> () } = {}
function MatchService.onCrossing(fn: (any, string, number) -> ())
	table.insert(crossingHooks, fn)
end
local function crossingEvent(c: any, event: string, wave: number)
	for _, fn in ipairs(crossingHooks) do
		local ok, err = pcall(fn, c, event, wave)
		if not ok then
			warn("[EOS] crossing hook: " .. tostring(err))
		end
	end
end
```
b) In `runMatch`, right after `setPhase("CROSSING", T.CROSSING)` add `crossingEvent(c, "start", logic.wave)`.
c) Right after `local res = logic:endWave(now())` (inside the wave loop) add `crossingEvent(c, "end", logic.wave)`.
d) After the wave loop, right after `logic:forceEnd(c.abortReason or logic.endReason or "END")` add `crossingEvent(c, "match", logic.wave)`.
e) In `onLeaving`, the condition `if s and ((s.gold or 0) > 0 or (s.gems or 0) > 0) then` stays as is (field Gems are already in `s.gems`).

## 5. `ReplicatedStorage/EOS/Shared/Net.lua`
In `Net.TO_CLIENT` add:
```lua
	"FieldGemPicked", -- { id, position, userId, total, cap, full? } a field Gem was picked up (full = you're at the cap)
```

## 6. `ServerScriptService/EOS/Services/Analytics.lua`
In `Analytics.KNOWN` add `FieldGemPicked = true,`.

## 7. `ServerScriptService/EOS/Bootstrap.lua`
Add `local FieldGemService = require(Services.FieldGemService)` with the other requires, and `FieldGemService.init()` right after `AbilityService.init()`.

## 8. `StarterPlayer/StarterPlayerScripts/EOS/ClientMain.lua`
Add `local FieldGems = require(Controllers.FieldGems)` with the other requires, and `FieldGems.init() -- field Gems: spin, sparkle, pickup burst, "+1"` after `SlideFX.init()`.

## 9. `StarterPlayer/StarterPlayerScripts/EOS/Controllers/Sound.lua`
Add a `gem` entry to `SFX` (match section). Use a real recording from Roblox's licensed library (Pro Sound Effects), short and bright: a crystal / glass chime or a single small bell tink, under 0.6 s. Level it like the others (AudioAnalyzer RMS) and add 0.03 pitch jitter. Until one is picked, reuse the coin jingle:
```lua
	gem = { 9113849492, 1.6, 0.08, 0.03 }, -- field Gem pickup (HOS-GEMS-002); placeholder: Coins Or Keys Jingle 6
```

## 10. The Gem model (optional, the code runs without it)
`ReplicatedStorage.EOS_FieldGemTemplate`: one MeshPart, our HUD gem (`Assets/UI/icons/gem.png`): a green brilliant-cut gem, about 1.8 studs across, under 200 triangles, flat-shaded facets, Glass or SmoothPlastic with a green SurfaceAppearance or colour, Anchored, CanCollide/CanQuery/CanTouch off. Without it the server uses a green glass cube stood on its point.
