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
-- Keyed by actor (a Player or an NPC bot). The body carries EOS_TagBlock (charges left) for clients.

type Block = { charges: number, untilT: number, archetype: string }
local blocks: { [any]: Block } = {}

local function show(actor: any, n: number?)
	local char = actor and actor.Character
	if char then
		char:SetAttribute("EOS_TagBlock", n)
	end
end

function Shared.grantTagBlock(actor: any, charges: number, seconds: number, archetype: string)
	local b = { charges = math.max(1, math.floor(charges)), untilT = os.clock() + seconds, archetype = archetype }
	blocks[actor] = b
	show(actor, b.charges)
	task.delay(seconds, function()
		if blocks[actor] == b then
			blocks[actor] = nil
			show(actor, nil)
		end
	end)
end

function Shared.hasTagBlock(actor: any): boolean
	local b = blocks[actor]
	return b ~= nil and b.charges > 0 and os.clock() < b.untilT
end

-- true = this tag is blocked (one charge used)
function Shared.consumeTagBlock(victim: any, hunter: any): boolean
	if not Shared.hasTagBlock(victim) then
		return false
	end
	local b = blocks[victim] :: Block
	b.charges -= 1
	if b.charges <= 0 then
		blocks[victim] = nil
		show(victim, nil)
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

return Shared
