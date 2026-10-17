--!strict
-- Outlines: who gets an outline in a match, drawn by each client for its own point of view.
--  * Catchers: red, for everyone (yourself too, when you're one)
--  * caught players (down on the floor until the crossing ends): red, for everyone
--  * Runners: blue for the other Runners (your team); you never see one on yourself as a Runner, and
--    Catchers / caught players see no outline on Runners at all
--  * DECOY copies take their owner's outline, so they still fool people
-- Outline only (no fill), and hidden behind walls and bricks (DepthMode Occluded): no wallhacks.
-- Nothing outside a match (lobby, practice) gets one. A Scout ping on a body takes over while it shows.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Outlines = {}

Outlines.RED = Color3.fromRGB(255, 64, 64)
Outlines.BLUE = Color3.fromRGB(70, 165, 255)

local player = Players.LocalPlayer
local NAME = "EOS_Outline"
local REFRESH = 0.15 -- seconds between passes (roles change a few times a crossing, not every frame)

-- the colour `viewerRole` sees on a body whose role is `role` (nil = no outline)
function Outlines.colorFor(viewerRole: string?, role: string?, isSelf: boolean): Color3?
	if role == "CATCHER" or role == "CAUGHT" then
		return Outlines.RED
	elseif role == "RUNNER" then
		if isSelf or viewerRole ~= "RUNNER" then
			return nil
		end
		return Outlines.BLUE
	end
	return nil
end

local function setOutline(model: Model, color: Color3?)
	local h = model:FindFirstChild(NAME)
	if not color then
		if h and h:IsA("Highlight") then
			h.Enabled = false
		end
		return
	end
	if not h or not h:IsA("Highlight") then
		local nh = Instance.new("Highlight")
		nh.Name = NAME
		nh.FillTransparency = 1 -- outline only
		nh.OutlineTransparency = 0
		nh.DepthMode = Enum.HighlightDepthMode.Occluded -- never through walls or bricks
		nh.Adornee = model
		nh.Parent = model -- client-only instance inside the body
		h = nh
	end
	local hl = h :: Highlight
	if hl.OutlineColor ~= color then
		hl.OutlineColor = color
	end
	hl.Enabled = true
end

local function runtimeFolder(name: string): Instance?
	local runtime = workspace:FindFirstChild("EOS_Runtime")
	return runtime and runtime:FindFirstChild(name)
end

local outlined: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function refresh()
	local inMatch = player:GetAttribute("EOS_InMatch") == true
	local viewerRole = player:GetAttribute("EOS_Role")
	local want: { [Model]: Color3 } = {}
	if inMatch then
		-- players
		for _, plr in ipairs(Players:GetPlayers()) do
			local char = plr.Character
			-- an invisible player (Invisibility pets) shows no outline to anyone else
			if char and plr:GetAttribute("EOS_InMatch") == true and (plr == player or char:GetAttribute("EOS_Invisible") ~= true) then
				local c = Outlines.colorFor(viewerRole, plr:GetAttribute("EOS_Role"), plr == player)
				if c then
					want[char] = c
				end
			end
		end
		-- NPCs (their role lives on the body)
		local npcs = runtimeFolder("Npcs")
		if npcs then
			for _, m in ipairs(npcs:GetChildren()) do
				if m:IsA("Model") and m:GetAttribute("EOS_InMatch") == true then
					local c = Outlines.colorFor(viewerRole, m:GetAttribute("EOS_Role"), false)
					if c then
						want[m] = c
					end
				end
			end
		end
		-- decoys look like their owner
		local decoys = runtimeFolder("Decoys")
		if decoys then
			for _, m in ipairs(decoys:GetChildren()) do
				local owner = m:IsA("Model") and m:GetAttribute("EOS_Decoy")
				local plr = if type(owner) == "number" then Players:GetPlayerByUserId(owner) else nil
				if plr then
					local c = Outlines.colorFor(viewerRole, plr:GetAttribute("EOS_Role"), false)
					if c then
						want[m :: Model] = c
					end
				end
			end
		end
		-- a Scout ping (Pets) owns the body while it shows: one highlight per body reads best
		local cam = workspace.CurrentCamera
		if cam then
			for _, h in ipairs(cam:GetChildren()) do
				if h.Name == "EOS_ScoutPing" and h:IsA("Highlight") and h.Adornee and h.Adornee:IsA("Model") then
					want[h.Adornee :: Model] = nil
				end
			end
		end
	end
	for model in pairs(outlined) do
		if not want[model] then
			setOutline(model, nil)
			outlined[model] = nil
		end
	end
	for model, color in pairs(want) do
		setOutline(model, color)
		outlined[model] = true
	end
end

function Outlines.init()
	local acc = REFRESH
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= REFRESH then
			acc = 0
			refresh()
		end
	end)
	-- a role change shows at once
	player:GetAttributeChangedSignal("EOS_Role"):Connect(refresh)
	player:GetAttributeChangedSignal("EOS_InMatch"):Connect(refresh)
end

return Outlines
