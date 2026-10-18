--!nocheck
-- LobbyGate (HOS-LOBBY-004, 18 Oct 2026, Matthew): one answer for the lobby's client-side animations (the lanterns, the
-- incubator, the wind, the leaderboards turning, the pro gate's fade, the weapon pedestals): run this frame or not.
--   LobbyGate.active()             false while this player is in a match (EOS_InMatch) or the camera is away from the
--                                  lobby (spectating the field): then they all stop completely
--   LobbyGate.near(pos, range)     your character (else the camera) within `range` studs of pos, measured flat
--   LobbyGate.onScreen(pos, r)     a sphere of radius r at pos is (at least partly) inside the camera's view
--   LobbyGate.ANIM_RANGE           how close lobby things animate: half the lobby's width (60 studs)
--   LobbyGate.centre(), radius(), floorY()   the lobby island (workspace.Ground.Ground_Outer), measured once it streams in
local Players = game:GetService("Players")

local LobbyGate = {}
LobbyGate.ANIM_RANGE = 60

local AWAY = 40 -- studs past the island's edge where the camera counts as away from the lobby

local player = Players.LocalPlayer
local centre, radius, floorY = Vector3.new(0, 10, 1500), 62, 10
local measured = false

local function measure()
	if measured then return end
	local g = workspace:FindFirstChild("Ground")
	local outer = g and g:FindFirstChild("Ground_Outer")
	if outer and #outer:GetChildren() > 0 then
		local cf, sz = outer:GetBoundingBox()
		centre, radius, floorY = cf.Position, math.max(sz.X, sz.Z) / 2, cf.Position.Y + sz.Y / 2
		measured = true
	end
end

function LobbyGate.centre(): Vector3
	measure()
	return centre
end

function LobbyGate.radius(): number
	measure()
	return radius
end

function LobbyGate.floorY(): number
	measure()
	return floorY
end

function LobbyGate.active(): boolean
	if player:GetAttribute("EOS_InMatch") == true then return false end
	local cam = workspace.CurrentCamera
	if not cam then return false end
	measure()
	local p = cam.CFrame.Position
	return Vector3.new(p.X - centre.X, 0, p.Z - centre.Z).Magnitude < radius + AWAY
end

function LobbyGate.near(pos: Vector3, range: number): boolean
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local from = if root then root.Position else (workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position or pos)
	return Vector3.new(from.X - pos.X, 0, from.Z - pos.Z).Magnitude < range
end

function LobbyGate.onScreen(pos: Vector3, r: number): boolean
	local cam = workspace.CurrentCamera
	if not cam then return false end
	local v, inFront = cam:WorldToViewportPoint(pos)
	local depth = v.Z
	if depth < r then
		return (cam.CFrame.Position - pos).Magnitude < r * 2 or inFront -- the camera is in it, or right at it
	end
	local vp = cam.ViewportSize
	local focal = vp.Y / (2 * math.tan(math.rad(cam.FieldOfView) / 2))
	local pad = r * focal / depth -- the sphere's radius in pixels
	return v.X > -pad and v.X < vp.X + pad and v.Y > -pad and v.Y < vp.Y + pad
end

return LobbyGate
