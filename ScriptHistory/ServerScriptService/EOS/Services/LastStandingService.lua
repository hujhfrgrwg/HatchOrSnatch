--!strict
-- LastStandingService (HOS-CINE-002, 17 Oct 2026): the server half of the Last One Standing cut-scene.
-- MatchService calls moment(c, nextFinish) in WAVE_END right after lineUp. When the next crossing starts
-- with ONE Runner (their solo run decides the match; not in a Studio solo test), every real match player
-- gets the LastStanding remote and that WAVE_END gets GameConfig.Cinematic.LAST_STANDING_EXTRA seconds
-- longer (PhaseEndsAt moves with it, so countdowns stay right). Returns the extra seconds (0 = no moment).
-- Once per match: later solo crossings of the same match return 0 (the pill only, on the client).
-- The client half is StarterPlayerScripts/EOS/Controllers/LastStanding (+ Controllers/Cinematic).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Layout = require(Shared:WaitForChild("Layout"))
local Net = require(Shared:WaitForChild("Net"))
local Analytics = require(script.Parent.Analytics)
local CharacterService = require(script.Parent.CharacterService)
local NpcService = require(script.Parent.NpcService)

local LastStandingService = {}

function LastStandingService.moment(c: any, finishSide: string): number
	local CC = GameConfig.Cinematic
	if not CC or not CC.LAST_STANDING_ENABLED or c.logic.solo or c.logic:runnersRemaining() ~= 1 then
		return 0
	end
	-- the full moment plays once per match: a lone Runner can keep crossing (Match.SOLO_WIN_ENDS_MATCH = false), and
	-- later solo crossings get only the client's pill ("LAST ONE STANDING · CROSSING n"), no cut-scene, no longer break.
	-- The flag lives on the match table, so every new match starts without it.
	if c.lastStandingShownAt then
		return 0
	end
	c.lastStandingShownAt = c.logic.wave + 1
	local runner, catchers, sum = nil, 0, Vector3.zero
	local players: { Player } = {}
	for uid, actor in pairs(c.roster) do
		local p = c.logic:get(uid)
		if p and not p.disconnected and actor.Parent then
			if p.role == "RUNNER" then
				runner = actor
			elseif p.role == "CATCHER" then
				catchers += 1
				sum += CharacterService.rootPosition(actor) or Layout.Arena.CENTER
			end
			if not NpcService.isBot(actor) then
				table.insert(players, actor)
			end
		end
	end
	if not runner then
		return 0
	end
	local payload = {
		userId = runner.UserId,
		name = runner.DisplayName,
		npcSlot = if NpcService.isBot(runner) then runner.slot else nil, -- clients show their own friend's name
		catchers = catchers,
		pos = CharacterService.rootPosition(runner),
		from = if catchers > 0 then sum / catchers else Layout.Arena.CENTER, -- the middle of the Catcher line
		finish = Layout.Zones[finishSide].center,
	}
	local ev = Net.event("LastStanding")
	for _, plr in ipairs(players) do
		ev:FireClient(plr, payload)
	end
	local extra = CC.LAST_STANDING_EXTRA or 1.6
	local state = Net.state()
	state:SetAttribute("LastStandingFirstWave", c.logic.wave + 1) -- clients: later solo crossings show "CROSSING n"
	state:SetAttribute("PhaseEndsAt", (state:GetAttribute("PhaseEndsAt") or workspace:GetServerTimeNow()) + extra)
	Analytics.log("LastStandingShown", { matchId = c.matchId, userId = runner.UserId, catchers = catchers, wave = c.logic.wave + 1 })
	return extra
end

return LastStandingService
