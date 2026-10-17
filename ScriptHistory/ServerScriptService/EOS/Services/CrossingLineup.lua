--!strict
-- CrossingLineup (HOS-HOC-001, 17 Oct, Hunter: "Ensure all runners and catchers are forcibly lined up").
-- At the start of every crossing: Runners in one evenly spaced row on their start line (shoulder to
-- shoulder, extra rows behind when the zone is too narrow), all facing the field; Catchers in a row
-- across the middle facing them (MatchService's catcherLine, which steps around the centre structure),
-- with the lead Catcher one step in front at the centre of the Runner row. Everyone is frozen in place
-- (root anchored + held: no walking, dashing or sliding) until HeroChickenService lets them go.
-- A body that respawns while frozen is put back in its slot and frozen again.
-- Numbers: HeroChickenConfig.Lineup. Positions come from Layout (the live map's zones), so every map works.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local Layout = require(Shared:WaitForChild("Layout"))
local HC = require(Shared:WaitForChild("HeroChickenConfig"))
local CharacterService = require(script.Parent.CharacterService)
local NpcService = require(script.Parent.NpcService)

local L = HC.Lineup
local isBot = NpcService.isBot

local CrossingLineup = {}

-- uid -> { actor, cf } for everyone frozen now
local frozen: { [number]: { actor: any, cf: CFrame } } = {}

local function rootOf(actor: any): BasePart?
	local char = actor.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function place(actor: any, cf: CFrame)
	local char = actor.Character :: Model?
	if not char or not char.PrimaryPart then
		return
	end
	CharacterService.unragdoll(actor) -- caught last crossing: stand up first
	char:PivotTo(cf)
	local root = rootOf(actor)
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
	actor:SetAttribute("EOS_TeleportedAt", os.clock()) -- MatchService's activity check ignores the jump
end

-- feet on the real ground (17 Oct, Hunter: "players are floating in the hero vs chicken select"): slots
-- came from Layout.GROUND_Y + a constant, which floated everyone on maps whose ground isn't there. Ray
-- straight down at the slot, past characters, EOS_Runtime and see-through / non-colliding parts, and stand
-- the root on the hit: R6 = leg height + half the root, R15 = HipHeight + half the root.
local function standY(actor: any, at: Vector3): number?
	local char = actor.Character :: Model?
	local root = rootOf(actor)
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not char or not root or not hum then
		return nil
	end
	local ex: { Instance } = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(ex, p.Character)
		end
	end
	local rt = workspace:FindFirstChild("EOS_Runtime")
	if rt then
		table.insert(ex, rt)
	end
	table.insert(ex, char)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	-- from just above head height: a roof over the slot (Frosty Pass's cabin) must not become the floor
	local from = Vector3.new(at.X, at.Y + 4, at.Z)
	for _ = 1, 8 do
		rp.FilterDescendantsInstances = ex
		local hit = workspace:Raycast(from, Vector3.new(0, -80, 0), rp)
		if not hit then
			return nil
		end
		local part = hit.Instance
		if part.CanCollide and part.Transparency < 0.95 then
			local leg = char:FindFirstChild("Right Leg") :: BasePart?
			local lift = if hum.RigType == Enum.HumanoidRigType.R6
				then (if leg then leg.Size.Y else 2) + root.Size.Y / 2
				else hum.HipHeight + root.Size.Y / 2
			return hit.Position.Y + lift
		end
		table.insert(ex, part)
	end
	return nil
end

function CrossingLineup.freeze(actor: any, cf: CFrame?)
	local root = rootOf(actor)
	if not root then
		return
	end
	local at = cf or root.CFrame
	local y = standY(actor, at.Position)
	if y then
		at = at + Vector3.new(0, y - at.Position.Y, 0)
	end
	place(actor, at)
	root.Anchored = true
	CharacterService.setHold(actor, true)
	actor.Character:SetAttribute("EOS_LineFrozen", true)
	frozen[actor.UserId] = { actor = actor, cf = at }
end

function CrossingLineup.unfreeze(actor: any, keepHold: boolean?)
	frozen[actor.UserId] = nil
	local char = actor.Character
	local root = rootOf(actor)
	if char then
		char:SetAttribute("EOS_LineFrozen", nil)
	end
	if root and root.Anchored and not (char and char:GetAttribute("EOS_RagdollFrozen")) then
		root.Anchored = false
		if isBot(actor) then
			pcall(function()
				root:SetNetworkOwner(nil) -- the server drives NPCs; anchoring reset the owner
			end)
		end
	end
	if not keepHold then
		CharacterService.setHold(actor, false)
	end
end

function CrossingLineup.isFrozen(uid: number): boolean
	return frozen[uid] ~= nil
end

function CrossingLineup.releaseAll()
	for _, e in pairs(table.clone(frozen)) do
		if e.actor.Parent then
			CrossingLineup.unfreeze(e.actor)
		end
	end
	frozen = {}
end

-- Runner slots: rows across the start zone at its field-side edge, centred, L.RUNNER_SPACING apart
local function runnerSlots(zone: string, n: number): ({ Vector3 }, number)
	local box = Layout.Zones[zone]
	local towardField = if box.center.X < Layout.Arena.CENTER.X then 1 else -1
	local width = box.size.Z - 2 * L.EDGE_MARGIN
	local perRow = math.max(1, math.min(n, math.floor(width / L.RUNNER_SPACING) + 1))
	local frontX = box.center.X + towardField * (box.size.X / 2 - L.FRONT_INSET)
	local out = {}
	for i = 0, n - 1 do
		local row = math.floor(i / perRow)
		local inRow = math.min(perRow, n - row * perRow)
		local col = i % perRow
		local z = box.center.Z + (col - (inRow - 1) / 2) * L.RUNNER_SPACING
		table.insert(out, Vector3.new(frontX - towardField * row * L.ROW_GAP, Layout.GROUND_Y + 3, z))
	end
	return out, towardField
end

-- a spot is clear when a body fits there, nothing is overhead (no roof) and the Runner row can be seen from
-- it. 17 Oct, Frosty Pass: the lead Catcher's centre spot was inside an ice-fishing cabin, so the camera
-- (and everyone's view of the point) was stuck inside it. Characters, EOS_Runtime and see-through parts
-- (gates, walls nobody sees) never count.
local function opaqueHit(from: Vector3, to: Vector3, params: RaycastParams): boolean
	local ex = table.clone(params.FilterDescendantsInstances)
	for _ = 1, 6 do
		params.FilterDescendantsInstances = ex
		local hit = workspace:Raycast(from, to - from, params)
		if not hit then
			return false
		end
		if hit.Instance.Transparency < 0.95 then
			return true
		end
		table.insert(ex, hit.Instance)
	end
	return false
end

local function clearSpot(s: Vector3, lookAt: Vector3): boolean
	local ex: { Instance } = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(ex, p.Character)
		end
	end
	local rt = workspace:FindFirstChild("EOS_Runtime")
	if rt then
		table.insert(ex, rt)
	end
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = ex
	for _, part in ipairs(workspace:GetPartBoundsInBox(CFrame.new(s + Vector3.new(0, 3, 0)), Vector3.new(3, 4.5, 3), op)) do
		if part.CanCollide and part.Transparency < 0.95 then
			return false
		end
	end
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = ex
	local eye = s + Vector3.new(0, 4, 0) -- s is about root height, so the eye is a little above head height
	return not opaqueHit(eye, eye + Vector3.new(0, 14, 0), rp) and not opaqueHit(eye, Vector3.new(lookAt.X, eye.Y, lookAt.Z), rp)
end

-- the nearest clear spot to s along the line (z), then stepping toward the Runners (x)
local function nearestClear(s: Vector3, lookAt: Vector3, towardField: number): Vector3
	if clearSpot(s, lookAt) then
		return s
	end
	for _, dx in ipairs({ 0, 4, 8 }) do
		for step = 1, 12 do
			for _, sign in ipairs({ 1, -1 }) do
				local t = s + Vector3.new(-towardField * dx, 0, sign * step * 3)
				if clearSpot(t, lookAt) then
					return t
				end
			end
		end
	end
	return s
end

-- hooks.catcherLine(n, startSide) -> { Vector3 } (MatchService). Returns the Runner uids along the row.
function CrossingLineup.arrange(c: any, startSide: string, lead: any?, hooks: any): { number }
	local runners, catchers = {}, {}
	for uid, actor in pairs(c.roster) do
		local p = c.logic:get(uid)
		if p and not p.disconnected and actor.Parent and rootOf(actor) then
			if p.role == "RUNNER" then
				table.insert(runners, actor)
			elseif p.role == "CATCHER" and actor ~= lead then
				table.insert(catchers, actor)
			end
		end
	end
	-- keep the order people already stand in (no shuffling between crossings)
	local function byZ(a, b)
		return (rootOf(a) :: BasePart).Position.Z < (rootOf(b) :: BasePart).Position.Z
	end
	table.sort(runners, byZ)
	table.sort(catchers, byZ)
	local slots, towardField = runnerSlots(startSide, #runners)
	local ids = {}
	local rowZ = Layout.Zones[startSide].center.Z
	for i, actor in ipairs(runners) do
		local s = slots[i]
		CrossingLineup.freeze(actor, CFrame.lookAt(s + Vector3.new(0, 2.5, 0), Vector3.new(s.X + towardField * 50, s.Y + 2.5, s.Z)))
		table.insert(ids, actor.UserId)
	end
	local runnerX = if slots[1] then slots[1].X else Layout.Zones[startSide].center.X
	local cs = if hooks.catcherLine then hooks.catcherLine(#catchers, startSide) else {}
	for i, actor in ipairs(catchers) do
		local s = cs[i] or Layout.Arena.CENTER
		CrossingLineup.freeze(actor, CFrame.lookAt(s + Vector3.new(0, 2.5, 0), Vector3.new(runnerX, s.Y + 2.5, s.Z)))
	end
	if lead then
		-- the lead Catcher: one step in front of the Catchers' row, at the centre of the Runner row
		local s = Vector3.new(Layout.Arena.CENTER.X + towardField * -L.LEAD_STEP, Layout.GROUND_Y + 3, rowZ)
		s = Vector3.new(s.X, standY(lead, s) or s.Y, s.Z) -- the clear-spot test from real standing height
		s = nearestClear(s, Vector3.new(runnerX, s.Y, rowZ), towardField)
		CrossingLineup.freeze(lead, CFrame.lookAt(s + Vector3.new(0, 2.5, 0), Vector3.new(runnerX, s.Y + 2.5, s.Z)))
	end
	return ids
end

function CrossingLineup.init()
	-- a body that respawned (or was moved) while frozen goes back to its slot, frozen again
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		for uid, e in pairs(frozen) do
			local actor = e.actor
			if not actor.Parent then
				frozen[uid] = nil
			else
				local root = rootOf(actor)
				if root and (not root.Anchored or (root.Position - e.cf.Position).Magnitude > 3) then
					CrossingLineup.freeze(actor, e.cf)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(plr)
		frozen[plr.UserId] = nil
	end)
end

return CrossingLineup
