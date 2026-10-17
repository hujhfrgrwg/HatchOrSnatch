--!strict
-- Abilities.Rift (HOS-PET-010 prototype). Numbers: AbilityConfig.ARCHETYPES.Rift.
--  * Runner, PORTAL HOP: `distance` studs the way you're moving (or facing, standing still). Portals show
--    at both ends for `windup` seconds, then you're there.
--  * Catcher, RIFT BLINK: not a dash (Hunter, 15 Oct). A ring shows at the spot `distance` studs ahead
--    for `windup` seconds, then you appear there.
-- Both are checked with Shared.validPosition on the press (a bad spot is refused: no cooldown) and again
-- as they land (if the spot went bad meanwhile, it fizzles and the cooldown is given back: ctx.refund).
-- Never across a crossing line / into a safe zone, never zone-locked, never into walls or off the map.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = require(script.Parent.Shared)
local AbilityConfig = require(ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared"):WaitForChild("AbilityConfig"))

local Rift = {}

local COLOR = AbilityConfig.ARCHETYPES.Rift.color

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- the root position `dist` studs along `dir`, at the same height above the ground as now. The ground there
-- may be a little higher or lower (a step, a slope), but never a climb onto a wall or a box: anything more
-- than MAX_UP above your ground keeps your height, so the validity check refuses the blocked spot.
local MAX_UP, MAX_DOWN = 3, 6
local function spotAhead(root: BasePart, dir: Vector3, dist: number): Vector3
	local here = Shared.groundBelow(root.Position)
	local lift = root.Position.Y - here.Y
	local p = root.Position + dir * dist
	local g = Shared.groundBelow(p + Vector3.new(0, 3, 0))
	local gy = if g.Y > here.Y + MAX_UP or g.Y < here.Y - MAX_DOWN then here.Y else g.Y
	return Vector3.new(p.X, gy + lift, p.Z)
end

local function teleport(ctx: any, dir: Vector3, showStart: boolean): (boolean, string?)
	local root = ctx.root :: BasePart?
	if not root then
		return false, "NO_CHARACTER"
	end
	local d = ctx.def
	local plr = ctx.player
	local dest = spotAhead(root, dir, d.distance)
	local ok, why = Shared.validPosition(plr, dest)
	if not ok then
		return false, why
	end
	local radius = 2.5
	local endRing = Shared.ring(Shared.groundBelow(dest) + Vector3.new(0, 0.12, 0), radius, COLOR, d.windup + 0.15, 0.2)
	endRing.Name = "EOS_RiftTarget"
	if showStart then
		Shared.ring(Shared.groundBelow(root.Position) + Vector3.new(0, 0.12, 0), radius, COLOR, d.windup + 0.15, 0.2)
	end
	local role = plr:GetAttribute("EOS_Role")
	local char = plr.Character
	task.delay(d.windup, function()
		if plr:GetAttribute("EOS_Role") ~= role or plr.Character ~= char or not root.Parent then
			return
		end
		-- the spot you'd land on now (you kept moving during the windup): same offset from where you are
		local now = spotAhead(root, dir, d.distance)
		local ok2, why2 = Shared.validPosition(plr, now)
		if not ok2 then
			ctx.refund("FIZZLED")
			Shared.ring(Shared.groundBelow(root.Position) + Vector3.new(0, 0.12, 0), 1.5, Color3.new(0.6, 0.6, 0.6), 0.3, 0.3)
			print(("[EOS] Rift %s fizzled: %s"):format(ctx.roleKey, tostring(why2)))
			return
		end
		local rot = root.CFrame - root.Position
		char:PivotTo(CFrame.new(now) * rot)
		root.AssemblyLinearVelocity = Vector3.zero
		plr:SetAttribute("EOS_TeleportedAt", os.clock())
		Shared.ring(Shared.groundBelow(now) + Vector3.new(0, 0.12, 0), radius + 1, COLOR, 0.3, 0.1)
	end)
	return true, nil
end

function Rift.Runner(ctx: any): (boolean, string?)
	local root = ctx.root :: BasePart?
	if not root then
		return false, "NO_CHARACTER"
	end
	local dir = flat(ctx.moveDir)
	if dir.Magnitude < 0.1 then
		dir = flat(root.CFrame.LookVector)
	end
	if dir.Magnitude < 0.01 then
		return false, "BAD_TARGET"
	end
	return teleport(ctx, dir.Unit, true)
end

function Rift.Catcher(ctx: any): (boolean, string?)
	local root = ctx.root :: BasePart?
	if not root then
		return false, "NO_CHARACTER"
	end
	local dir = flat(root.CFrame.LookVector)
	if dir.Magnitude < 0.01 then
		return false, "BAD_TARGET"
	end
	return teleport(ctx, dir.Unit, false)
end

return Rift
