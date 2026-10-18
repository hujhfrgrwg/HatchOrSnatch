--!strict
-- ReviveService (HOS-PTS-001, 17 Oct 2026): a caught Runner lies down for PointsConfig.Revive.WINDOW (6 s); a free
-- Runner within RANGE (6 studs) can hold the prompt for HOLD (1.5 s: E, tap and hold, or X on a controller) to get
-- them back up as a Runner with the egg they carried. Moving more than MOVE_CANCEL during the hold, or being caught,
-- cancels it. Once per Runner per crossing (both ways: REVIVES_PER_CROSSING / REVIVED_PER_CROSSING).
-- After the window nothing changes from before: down until the crossing ends, a Catcher from the next one.
-- The Catcher keeps the catch (+50). The reviver gets PointsService "revive" (+25).
--
-- It never edits MatchLogic: like HeroChickenService it changes the participant row itself (role, carried egg) and
-- re-applies the Runner through CharacterService. It never touches Anchored, WalkSpeed or EOS_LineFrozen itself.
-- The prompt is a ProximityPrompt (Style Custom) on the downed body's root, tagged EOS_RevivePrompt; the client
-- (Controllers/ReviveUI) draws the approved look and shows it to free Runners only.
-- Replicated: the downed character's attribute EOS_DownedUntil (server time) drives the DOWN tag on every client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local PointsConfig = require(Shared:WaitForChild("PointsConfig"))
local Net = require(Shared:WaitForChild("Net"))
local Analytics = require(script.Parent.Analytics)
local CharacterService = require(script.Parent.CharacterService)
local NpcService = require(script.Parent.NpcService)

local R = PointsConfig.Revive
local isBot = NpcService.isBot

local ReviveService = {}

local MatchService: any = nil
local PointsService: any = nil

local function now(): number
	return workspace:GetServerTimeNow()
end

function ReviveService.enabled(): boolean
	return PointsConfig.Enabled and R.Enabled
end

-- c.rv = { downed = { [uid] = { until, carried, prompt, wave } }, revived = { [uid] = n }, revives = { [uid] = n }, snap = { [uid] = role } }
local function stateOf(c: any): any
	c.rv = c.rv or { downed = {}, revived = {}, revives = {}, snap = {}, carried = {} }
	return c.rv
end

local function clearDowned(c: any, uid: number)
	local st = stateOf(c)
	local d = st.downed[uid]
	if d then
		if d.prompt then
			d.prompt:Destroy()
		end
		st.downed[uid] = nil
	end
	local actor = c.roster[uid]
	local char = actor and actor.Character
	if char then
		char:SetAttribute("EOS_DownedUntil", nil)
	end
end

local function freeRunner(c: any, plr: any): boolean
	local p = c.logic:get(plr.UserId)
	return p ~= nil and p.role == "RUNNER" and not p.disconnected and not p.isSafeThisWave
end

local function canRevive(c: any, reviver: any, uid: number): (boolean, string?)
	local st = stateOf(c)
	local d = st.downed[uid]
	if not d or now() > d.untilT then
		return false, "WINDOW"
	end
	if not freeRunner(c, reviver) then
		return false, "NOT_RUNNER"
	end
	if (st.revives[reviver.UserId] or 0) >= R.REVIVES_PER_CROSSING then
		return false, "USED"
	end
	local victim = c.roster[uid]
	local vp, rp = victim and CharacterService.rootPosition(victim), CharacterService.rootPosition(reviver)
	if not vp or not rp or (vp - rp).Magnitude > R.RANGE + 1.5 then -- a little slack for latency
		return false, "RANGE"
	end
	local char = victim.Character
	if char and char:GetAttribute("EOS_LineFrozen") then
		return false, "FROZEN" -- held on the line (a Hero run): CrossingLineup owns them until the group goes
	end
	return true, nil
end

local function revive(c: any, reviver: any, uid: number)
	local st = stateOf(c)
	local d = st.downed[uid]
	local victim = c.roster[uid]
	local p = c.logic:get(uid)
	if not d or not victim or not p or p.role ~= "CAUGHT" then
		return
	end
	-- back to a Runner with the egg they carried (the Catcher keeps the catch and its steal credit)
	p.role = "RUNNER"
	p.currentCarriedTier = d.carried
	p.isConverted = false
	p.convertedAt = nil
	p.convertedWave = nil
	p.conversionCause = nil
	p.capturedBy = nil
	p.isSafeThisWave = false
	st.revives[reviver.UserId] = (st.revives[reviver.UserId] or 0) + 1
	st.revived[uid] = (st.revived[uid] or 0) + 1
	clearDowned(c, uid)
	CharacterService.applyRole(victim, "RUNNER", d.carried) -- stands them up (unragdoll), Runner speed, egg back
	victim:SetAttribute("EOS_Secured", c.logic:securedTier(p))
	victim:SetAttribute("EOS_Safe", false)
	victim:SetAttribute("EOS_CatcherSource", nil)
	Net.state():SetAttribute("RunnersLeft", c.logic:runnersRemaining())
	if not isBot(victim) then
		Net.event("RoleChanged"):FireClient(victim, { role = "RUNNER", cause = "REVIVED", by = reviver.UserId, byName = reviver.DisplayName, bankedTier = c.logic:securedTier(p) })
	end
	if PointsService then
		PointsService.award(c, reviver, "revive")
	end
	Analytics.log("Revive", { matchId = c.matchId, wave = c.logic.wave, userId = if isBot(reviver) then nil else reviver.UserId,
		revived = if isBot(victim) then nil else uid, seconds = R.WINDOW - (d.untilT - now()) })
end

local function makePrompt(c: any, uid: number, root: BasePart): ProximityPrompt
	local victim = c.roster[uid]
	local pp = Instance.new("ProximityPrompt")
	pp.Name = "EOS_Revive"
	pp.ActionText = "Revive"
	pp.ObjectText = victim and victim.DisplayName or ""
	pp.HoldDuration = R.HOLD
	pp.MaxActivationDistance = R.RANGE
	pp.RequiresLineOfSight = false
	pp.KeyboardKeyCode = Enum.KeyCode.E
	pp.GamepadKeyCode = Enum.KeyCode.ButtonX
	pp.Style = Enum.ProximityPromptStyle.Custom -- Controllers/ReviveUI draws it (the approved kit look)
	pp:SetAttribute("EOS_ReviveUid", uid)
	pp:SetAttribute("EOS_NpcSlot", if victim and isBot(victim) then victim.slot else nil)
	CollectionService:AddTag(pp, "EOS_RevivePrompt")
	local holds: { [Player]: { start: Vector3, began: number, conn: RBXScriptConnection? } } = {}
	pp.PromptButtonHoldBegan:Connect(function(plr)
		local ok = canRevive(c, plr, uid)
		if not ok then
			pp.Enabled = false -- cancels the hold for everyone; back on next frame
			task.defer(function()
				if pp.Parent then
					pp.Enabled = true
				end
			end)
			return
		end
		local start = CharacterService.rootPosition(plr) or Vector3.zero
		local h = { start = start, began = os.clock(), conn = nil :: RBXScriptConnection? }
		holds[plr] = h
		h.conn = RunService.Heartbeat:Connect(function()
			local pos = CharacterService.rootPosition(plr)
			local moved = not pos or (Vector3.new(pos.X - start.X, 0, pos.Z - start.Z).Magnitude > R.MOVE_CANCEL)
			if moved or not freeRunner(c, plr) or not stateOf(c).downed[uid] then
				if h.conn then
					h.conn:Disconnect()
				end
				holds[plr] = nil
				if pp.Parent then
					pp.Enabled = false
					task.defer(function()
						if pp.Parent then
							pp.Enabled = true
						end
					end)
				end
			end
		end)
	end)
	pp.PromptButtonHoldEnded:Connect(function(plr)
		-- HOS-PTS-001: HoldEnded fires just before Triggered on a completed hold; clear a beat later so Triggered still sees it
		local h = holds[plr]
		if h and h.conn then
			h.conn:Disconnect()
			h.conn = nil
		end
		task.delay(0.25, function()
			if holds[plr] == h then
				holds[plr] = nil
			end
		end)
	end)
	pp.Triggered:Connect(function(plr)
		local h = holds[plr]
		holds[plr] = nil
		if h and h.conn then
			h.conn:Disconnect()
		end
		if MatchService.current() ~= c or not h or os.clock() - h.began < R.HOLD - 0.3 then
			return -- no server-seen (full) hold: no revive
		end
		local ok = canRevive(c, plr, uid)
		if ok then
			revive(c, plr, uid)
		end
	end)
	pp.Parent = root
	return pp
end

-- 10 Hz: a Runner who just went down opens a window; a window that ran out closes
local function watch(c: any)
	local st = stateOf(c)
	local t = now()
	for uid, actor in pairs(c.roster) do
		local p = c.logic:get(uid)
		if p and not p.disconnected and actor.Parent then
			local was = st.snap[uid]
			if p.role == "RUNNER" then
				st.carried[uid] = p.currentCarriedTier or 1
			end
			if p.role == "CAUGHT" and was == "RUNNER" and not st.downed[uid] and (st.revived[uid] or 0) < R.REVIVED_PER_CROSSING then
				local char = actor.Character
				local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					local d = { untilT = t + R.WINDOW, carried = st.carried[uid] or 1, prompt = nil :: ProximityPrompt?, wave = c.logic.wave }
					st.downed[uid] = d
					char:SetAttribute("EOS_DownedUntil", d.untilT)
					d.prompt = makePrompt(c, uid, root)
				end
			end
			st.snap[uid] = p.role
		end
	end
	for uid, d in pairs(st.downed) do
		local p = c.logic:get(uid)
		if t > d.untilT or not p or p.role ~= "CAUGHT" or p.disconnected then
			clearDowned(c, uid)
		end
	end
end

local function clearAll(c: any)
	if not c or not c.rv then
		return
	end
	for uid in pairs(c.rv.downed) do
		clearDowned(c, uid)
	end
	c.rv = nil
end

function ReviveService.init(matchService: any, pointsService: any)
	MatchService = matchService
	PointsService = pointsService
	if not ReviveService.enabled() then
		return
	end
	MatchService.onCrossing(function(c: any, event: string, _wave: number)
		-- a new crossing: fresh counts; the end (or the match): every window shuts
		clearAll(c)
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then
			return
		end
		acc = 0
		local c = MatchService.current()
		if c and c.logic.phase == "ACTIVE" then
			local ok, err = pcall(watch, c)
			if not ok then
				warn("[EOS] revive watch: " .. tostring(err))
			end
		end
	end)
end

return ReviveService
