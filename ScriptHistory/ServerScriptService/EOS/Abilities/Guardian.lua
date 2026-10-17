--!strict
-- Abilities.Guardian (HOS-PET-007 prototype). Numbers: AbilityConfig.ARCHETYPES.Guardian.
--  * Runner, SHIELD: for `duration` seconds the next tag on you is blocked (Shared.grantTagBlock), then
--    `immunity` seconds of grace so a Catcher still touching you can't tag you straight after. A bubble in
--    the Guardian colour shows on you while the shield holds (placeholder look).
--  * Catcher, TETHER: the nearest Runner in front of you within `range` gets a visible beam for `windup`
--    seconds, then is pulled `pull` studs towards you (never into a safe zone, a wall or off the map:
--    Shared.validPosition; a shorter pull is tried before giving up). Nobody in range = refused, no cooldown.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = require(script.Parent.Shared)
local AbilityConfig = require(ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared"):WaitForChild("AbilityConfig"))

local Guardian = {}

local COLOR = AbilityConfig.ARCHETYPES.Guardian.color
local bubbles: { [any]: BasePart } = {}

local function dropBubble(actor: any)
	local b = bubbles[actor]
	bubbles[actor] = nil
	if b then
		b:Destroy()
	end
end

-- ===== SHIELD =====

function Guardian.Runner(ctx: any): (boolean, string?)
	local root = ctx.root :: BasePart?
	local char = ctx.player.Character
	if not root or not char then
		return false, "NO_CHARACTER"
	end
	local d = ctx.def
	Shared.grantTagBlock(ctx.player, d.charges or 1, d.duration, "Guardian", d.immunity or 0.5, ctx.species, ctx.level)
	dropBubble(ctx.player)
	local b = Instance.new("Part")
	b.Name = "EOS_GuardianShield"
	b.Shape = Enum.PartType.Ball
	b.Size = Vector3.new(6.5, 6.5, 6.5)
	b.Material = Enum.Material.ForceField
	b.Color = Color3.fromRGB(30, 150, 255) -- the Guardian blue, deeper so it reads on bright ground (HOS-VFX-002)
	b.Transparency = 0.1
	b.CanCollide, b.CanQuery, b.CanTouch, b.CastShadow, b.Massless = false, false, false, false, true
	b.CFrame = root.CFrame
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = b, root
	w.Parent = b
	b.Parent = char
	bubbles[ctx.player] = b
	Shared.tagVfx(b, "ShieldBubble", true, ctx.species, ctx.level) -- the bubble stays; clients add its rim and sparkles (HOS-VFX-002)
	Shared.vfx("ShieldUp", root.Position, nil, ctx.species, ctx.level)
	-- the bubble goes when the shield is used up (EOS_TagBlock cleared) or runs out
	local conn
	conn = char:GetAttributeChangedSignal("EOS_TagBlock"):Connect(function()
		if char:GetAttribute("EOS_TagBlock") == nil then
			conn:Disconnect()
			if bubbles[ctx.player] == b then
				dropBubble(ctx.player)
			end
		end
	end)
	return true, nil
end

-- ===== TETHER =====

local function inFront(from: BasePart, pos: Vector3, cosCone: number): boolean
	local off = Vector3.new(pos.X - from.Position.X, 0, pos.Z - from.Position.Z)
	local look = Vector3.new(from.CFrame.LookVector.X, 0, from.CFrame.LookVector.Z)
	return off.Magnitude < 1 or look.Magnitude < 0.01 or off.Unit:Dot(look.Unit) >= cosCone
end

function Guardian.Catcher(ctx: any): (boolean, string?)
	local root = ctx.root :: BasePart?
	if not root then
		return false, "NO_CHARACTER"
	end
	local d = ctx.def
	local cosCone = math.cos(math.rad(d.cone or 60))
	local best, bestD = nil, math.huge
	for _, r in ipairs(Shared.actorsInRole("RUNNER")) do
		local rr = r.Character.HumanoidRootPart :: BasePart
		local dist = (rr.Position - root.Position).Magnitude
		if dist <= d.range and dist < bestD and inFront(root, rr.Position, cosCone) then
			best, bestD = r, dist
		end
	end
	if not best then
		return false, "NO_TARGET"
	end
	local target = best
	local tr = target.Character.HumanoidRootPart :: BasePart
	Shared.beam(root, tr, COLOR, d.windup + 0.2, nil, "TetherBeam", ctx.species, ctx.level)
	local me = ctx.player
	local role = me:GetAttribute("EOS_Role")
	task.delay(d.windup, function()
		-- still a Catcher with a body, and the target still a Runner out in the field?
		if me:GetAttribute("EOS_Role") ~= role or not root.Parent or not tr.Parent then
			return
		end
		local still = false
		for _, r in ipairs(Shared.actorsInRole("RUNNER", true)) do
			if r == target then
				still = true
			end
		end
		if not still then
			return
		end
		local toMe = Vector3.new(root.Position.X - tr.Position.X, 0, root.Position.Z - tr.Position.Z)
		local gap = toMe.Magnitude
		if gap < 3.5 then
			return
		end
		local want = math.min(d.pull, gap - 3)
		for _, frac in ipairs({ 1, 0.66, 0.33 }) do
			local dest = tr.Position + toMe.Unit * want * frac
			if Shared.validPosition(target, dest) then
				Shared.slideTo(target, dest, 0.15)
				Shared.vfx("TetherYank", tr.Position, toMe.Unit, ctx.species, ctx.level) -- streaks fly towards the Catcher
				return
			end
		end
	end)
	return true, nil
end

function Guardian.cleanup(plr: Player)
	dropBubble(plr)
end

return Guardian
