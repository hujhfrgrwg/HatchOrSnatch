# Pending (needs Hunter's "Shared-scripts ok" for the no-roll change): EggUIController upgradeBanner
Replace the first 4 lines of `local function upgradeBanner` with:
```lua
local function upgradeBanner(to: string, guaranteed: boolean?)
	if not require(script.Parent.EggResultsRow).whenSettled(function() upgradeBanner(to, guaranteed) end) then return end -- never over the results opening (fixes)
	local b = place("EggBanner_" .. to, (root.Size.X.Offset) / 2, 300, true)
	if not b then return end
	require(script.Parent.EggResultsRow).bannerText(b, to, { setText = setText, find = find }) -- "SHARD UPGRADED: EPIC" (no-roll wording)
```
