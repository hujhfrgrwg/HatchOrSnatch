--!strict
-- Abilities.Shared (HOS-PET-001): helpers every archetype module uses (ServerScriptService.EOS.Abilities).
--
-- Handler contract: each archetype module returns { Runner = fn, Catcher = fn, cleanup = fn? }.
--   fn(ctx) -> (ok: boolean, reason: string?)
--   ctx = { player, role ("RUNNER" | "CATCHER"), roleKey ("Runner" | "Catcher"), archetype, def
--           (AbilityConfig role table: every number), species, level, gold, moveDir (flat Vector3, may
--           be zero), root (BasePart) }
--   Returning false refuses the press: no cooldown is spent (e.g. an invalid teleport). A handler with
--   a windup (def.windup) waits it out itself and re-checks before it lands.
--   Species reach a handler only for looks (AbilityCosmetics); numbers come from ctx.def.
--
--  * Shared.validPosition: may this body be put at `to`? (teleports, hops, blinks, pulls)
--  * Shared.grantTagBlock / consumeTagBlock: "blocks one tag" charges that MatchService's capture asks
--    about before a tag lands (AbilityService registers the capture guard)
--  * Shared.stub: a handler that only logs (archetypes not built yet)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SharedRS = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local Layout = require(SharedRS:WaitForChild("Layout"))
local Net = require(SharedRS:WaitForChild("Net"))
local Analytics = require(ServerScriptService.EOS.Services.Analytics)

local Shared = {}

function Shared.runtimeFolder(name: string): Folder
	local rt = workspace:FindFirstChild("EOS_Runtime")
	if not rt then
		rt = Instance.new("Folder")
		rt.Name = "EOS_Runtime"
		rt.Parent = workspace
	end
	local f = rt:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = rt
	end
	return f :: Folder
end

-- everyone sees it: { userId, family, kind, pos?, species?, level?, ... }
function Shared.fx(payload: { [string]: any })
	Net.event("AbilityFx"):FireAllClients(payload)
end

-- ===== species intros (VISUAL ONLY) =====
-- How long each species' summon animation runs on the client (fly-in / run-in, then the flash).
-- VISUAL ONLY, per Hunter on 17 Oct: every ability fires the instant the button is pressed and the
-- entrance plays over it. Species never change timing, so don't wait on these in a handler (the old
-- afterIntro delay was removed on purpose). Client modules: CrowPet, KitsunePet, ChameleonPet, GhostPet.
Shared.INTRO = { Crow = 0.5, Kitsune = 1.25, ["Prism Chameleon"] = 0.7, ["Grim Ghost"] = 0.55 } :: { [string]: number }

function Shared.introFor(species: any): number
	return if type(species) == "string" then Shared.INTRO[species] or 0 else 0
end

-- ===== stubs =====

function Shared.stub(archetype: string, roleKey: string)
	return function(ctx: any): (boolean, string?)
		print(("[EOS] %s %s ability is a stub (not built yet): %s pressed it"):format(archetype, roleKey, ctx.player.Name))
		Analytics.log("AbilityStub", { userId = ctx.player.UserId, family = archetype, role = ctx.role })
		return false, "NOT_BUILT"
	end
end

-- ===== position validity =====
-- Server truth for any ability that moves a body (hop, blink, pull). A position is refused when it:
--  * leaves the arena (off the map) or has no ground under it (a hole, the edge)
--  * is in, or the straight path to it passes through, a safe zone: no skipping a crossing line, no
--    hopping into or out of a zone, and Catchers never get in
--  * belongs to a body that is zone-locked / safe this crossing
--  * is blocked by geometry on the way, or there's no room to stand there (walls, gates and Catcher
--    walls count for whoever they stop: the cast uses the body's own collision group)

local function flatIn(pos: Vector3, box: { center: Vector3, size: Vector3 }): boolean
	local d = pos - box.center
	return math.abs(d.X) <= box.size.X / 2 and math.abs(d.Z) <= box.size.Z / 2
end

local function inSafeZone(pos: Vector3): boolean
	return flatIn(pos, Layout.Zones.A) or flatIn(pos, Layout.Zones.B)
end
Shared.inSafeZone = inSafeZone

local function bodies(): { Instance }
	local list: { Instance } = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	local rt = workspace:FindFirstChild("EOS_Runtime")
	if rt then
		table.insert(list, rt) -- NPC bodies, decoys, effects
	end
	return list
end

Shared.BODY_RADIUS = 1.25 -- sweep radius along the path
Shared.STAND_SIZE = Vector3.new(2.5, 4.5, 2.5) -- room a body needs at the target (centred on the root)
Shared.GROUND_PROBE = 8 -- studs below the target root that must have ground

function Shared.validPosition(actor: any, to: Vector3, from: Vector3?): (boolean, string?)
	local char = actor and actor.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not char or not root then
		return false, "NO_CHARACTER"
	end
	if to ~= to then
		return false, "BAD_TARGET"
	end
	local start = from or root.Position
	if char:GetAttribute("EOS_ZoneLocked") == true or actor:GetAttribute("EOS_Safe") == true then
		return false, "ZONE_LOCKED"
	end
	if not flatIn(start, Layout.ArenaBounds) or not flatIn(to, Layout.ArenaBounds) then
		return false, "OFF_MAP"
	end
	local delta = to - start
	local steps = math.max(1, math.ceil(delta.Magnitude / 1.5))
	for i = 0, steps do
		if inSafeZone(start:Lerp(to, i / steps)) then
			return false, "SAFE_ZONE"
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = bodies()
	params.RespectCanCollide = true
	params.CollisionGroup = root.CollisionGroup
	if delta.Magnitude > 0.05 and workspace:Spherecast(start, Shared.BODY_RADIUS, delta, params) then
		return false, "BLOCKED"
	end
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = bodies()
	op.RespectCanCollide = true
	op.CollisionGroup = root.CollisionGroup
	if #workspace:GetPartBoundsInBox(CFrame.new(to), Shared.STAND_SIZE, op) > 0 then
		return false, "NO_ROOM"
	end
	if not workspace:Raycast(to, Vector3.new(0, -Shared.GROUND_PROBE, 0), params) then
		return false, "NO_GROUND"
	end
	return true, nil
end

-- ===== "blocks one tag" =====
-- A charge on a body: the next tag that would land on it is stopped instead (and uses the charge).
-- After the last charge goes, `immunity` seconds of grace stop any tag too (HOS-PET-007: a Catcher in
-- contact retries every tick, so without it the next touch would tag you a moment after the block).
-- Keyed by actor (a Player or an NPC bot). The body carries EOS_TagBlock (charges left) for clients.

type Block = { charges: number, untilT: number, archetype: string, immunity: number, graceUntil: number }
local blocks: { [any]: Block } = {}

local function show(actor: any, n: number?)
	local char = actor and actor.Character
	if char then
		char:SetAttribute("EOS_TagBlock", n)
	end
end

function Shared.grantTagBlock(actor: any, charges: number, seconds: number, archetype: string, immunity: number?)
	local b = {
		charges = math.max(1, math.floor(charges)),
		untilT = os.clock() + seconds,
		archetype = archetype,
		immunity = immunity or 0,
		graceUntil = 0,
	}
	blocks[actor] = b
	show(actor, b.charges)
	task.delay(seconds, function()
		if blocks[actor] == b and b.charges > 0 then
			blocks[actor] = nil
			show(actor, nil)
		end
	end)
end

function Shared.hasTagBlock(actor: any): boolean
	local b = blocks[actor]
	if not b then
		return false
	end
	local now = os.clock()
	return (b.charges > 0 and now < b.untilT) or now < b.graceUntil
end

-- true = this tag is blocked (a charge used, or still inside the grace after the last one)
function Shared.consumeTagBlock(victim: any, hunter: any): boolean
	if not Shared.hasTagBlock(victim) then
		return false
	end
	local b = blocks[victim] :: Block
	if b.charges <= 0 then
		return true -- grace after the block: quietly stopped
	end
	b.charges -= 1
	if b.charges <= 0 then
		show(victim, nil)
		b.graceUntil = os.clock() + b.immunity
		task.delay(b.immunity, function()
			if blocks[victim] == b then
				blocks[victim] = nil
			end
		end)
	else
		show(victim, b.charges)
	end
	local char = victim.Character
	local r = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	Shared.fx({ userId = victim.UserId, family = b.archetype, kind = "blocked", pos = r and r.Position or nil, by = hunter and hunter.UserId })
	Analytics.log("AbilityTagBlocked", { userId = victim.UserId, by = hunter and hunter.UserId, family = b.archetype })
	return true
end

function Shared.clearTagBlock(actor: any)
	if blocks[actor] then
		blocks[actor] = nil
		show(actor, nil)
	end
end

-- ===== match helpers (HOS-PET-007) =====

-- every match actor (player or NPC bot) in `role`, with a body, not safe this crossing and not in a
-- safe zone. Invisible bodies are left out unless includeHidden.
function Shared.actorsInRole(role: string, includeHidden: boolean?): { any }
	local MatchService = require(ServerScriptService.EOS.Services.MatchService)
	local c = MatchService.current()
	local out = {}
	if not c then
		return out
	end
	for uid, actor in pairs(c.roster) do
		local p = c.logic:get(uid)
		local char = actor.Character
		local r = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if p and p.role == role and not p.disconnected and not p.isSafeThisWave and r and not inSafeZone(r.Position)
			and (includeHidden or char:GetAttribute("EOS_Invisible") ~= true) then
			table.insert(out, actor)
		end
	end
	return out
end

-- slide a body to `to` (root position) over `seconds` in a few steps, keeping its facing. Players' bodies
-- are moved by the server (it wins over their client for the step); call validPosition first.
function Shared.slideTo(actor: any, to: Vector3, seconds: number)
	local char = actor and actor.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local from = root.Position
	local steps = math.max(1, math.ceil(seconds / 0.04))
	task.spawn(function()
		for i = 1, steps do
			if not root.Parent then
				return
			end
			local p = from:Lerp(to, i / steps)
			local rot = root.CFrame - root.Position
			char:PivotTo(CFrame.new(p) * rot)
			root.AssemblyLinearVelocity = Vector3.zero
			task.wait(seconds / steps)
		end
	end)
end

-- a placeholder telegraph everyone sees: a neon bar between two bodies for `seconds` (prototype look)
function Shared.beam(a: BasePart, b: BasePart, color: Color3, seconds: number, width: number?)
	local p = Instance.new("Part")
	p.Name = "EOS_AbilityBeam"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.25
	p.Parent = Shared.runtimeFolder("AbilityFx")
	local w = width or 0.35
	local t0 = os.clock()
	local conn
	conn = game:GetService("RunService").Heartbeat:Connect(function()
		if os.clock() - t0 > seconds or not a.Parent or not b.Parent then
			conn:Disconnect()
			p:Destroy()
			return
		end
		local d = (b.Position - a.Position)
		p.Size = Vector3.new(w, w, math.max(0.1, d.Magnitude))
		p.CFrame = CFrame.lookAt(a.Position + d / 2, b.Position)
	end)
	return p
end

-- a placeholder flat ring on the ground everyone sees (prototype look); returns the part
function Shared.ring(at: Vector3, radius: number, color: Color3, seconds: number, transparency: number?): Part
	local p = Instance.new("Part")
	p.Name = "EOS_AbilityRing"
	p.Shape = Enum.PartType.Cylinder
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = transparency or 0.35
	p.Size = Vector3.new(0.2, radius * 2, radius * 2)
	p.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
	p.Parent = Shared.runtimeFolder("AbilityFx")
	if seconds > 0 then
		task.delay(seconds, function()
			p:Destroy()
		end)
	end
	return p
end

-- the ground point under a position (or the position itself if there's none)
function Shared.groundBelow(pos: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = bodies()
	params.RespectCanCollide = true
	local hit = workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -20, 0), params)
	return if hit then hit.Position else pos
end

return Shared
