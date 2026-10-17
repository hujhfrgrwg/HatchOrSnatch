--!strict
-- Invisibility (client): how a player under the Invisibility ability looks from this client.
--  * yourself: ghosted (SELF see-through) so you can still steer and read your own body
--  * everyone else: a faint shimmer (OTHERS see-through + a few soft glints in the pet's colour),
--    no overhead tag, no name, no outline (Outlines skips them), no egg trail/particles. An alert
--    opponent can still catch the movement; nobody can track you by your tag or your egg's sparkle.
-- The server owns it (AbilityService): character attributes EOS_Invisible (true while on),
-- EOS_InvisibleSpecies (tints the glints). Everything here is local; nothing is replicated.
-- HOS-VFX-005: pets without their own invisibility look get the default cloak (template
-- ReplicatedStorage.VFX.Abilities.InvisShimmer, effect key "InvisShimmer" in AbilityCosmetics): lavender
-- glints over the body and a thin scan ring sliding up it, fading with distance only (never with light,
-- never gold). Grim Ghost and Prism Chameleon keep the glints below exactly as built (Hunter, 17 Oct).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AbilityCosmetics = require(ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared"):WaitForChild("AbilityCosmetics"))
local Templates = ReplicatedStorage:WaitForChild("VFX"):WaitForChild("Abilities")

local Invisibility = {}

Invisibility.SELF = 0.6
Invisibility.OTHERS = 0.9
Invisibility.FADE = 0.22 -- seconds to fade in / out

local TINT: { [string]: ColorSequence } = {
	["Prism Chameleon"] = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 255, 240)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(170, 140, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 160, 230)),
	}),
	["Grim Ghost"] = ColorSequence.new(Color3.fromRGB(205, 180, 255)),
}
local DEFAULT_TINT = ColorSequence.new(Color3.fromRGB(235, 240, 255))

local player = Players.LocalPlayer

type State = {
	amount: number,
	saved: { [Instance]: any },
	nameType: Enum.HumanoidDisplayDistanceType?,
	shimmer: ParticleEmitter?,
	cloak: { Instance }?, -- the default cloak's emitters (HOS-VFX-005)
	base: { [ParticleEmitter]: NumberSequence }?,
	fadeAt: number?,
}
local states: { [Model]: State } = {}

function Invisibility.isHidden(model: Instance?): boolean
	return model ~= nil and model:GetAttribute("EOS_Invisible") == true
end

local function shimmerFor(model: Model, st: State): ParticleEmitter?
	if st.shimmer and st.shimmer.Parent then
		return st.shimmer
	end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local e = Instance.new("ParticleEmitter")
	e.Name = "EOS_InvisShimmer"
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	local sp = model:GetAttribute("EOS_InvisibleSpecies")
	e.Color = if type(sp) == "string" and TINT[sp] then TINT[sp] else DEFAULT_TINT
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Brightness = 2
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.4, 0.28), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new(0.35)
	e.Lifetime = NumberRange.new(0.35, 0.6)
	e.Speed = NumberRange.new(0.2, 0.8)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rotation = NumberRange.new(0, 360)
	e.Rate = 7
	e.LockedToPart = false
	e.Parent = root
	st.shimmer = e
	return e
end

-- ===== the default cloak (HOS-VFX-005) =====
local BODY = { "Head", "UpperTorso", "LowerTorso", "Torso", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
Invisibility.NEAR, Invisibility.FAR, Invisibility.FAR_VIS = 10, 45, 0.35 -- studs; how much is left at FAR

-- true when this species draws the default cloak (its own look otherwise)
local function usesCloak(model: Model): boolean
	return AbilityCosmetics.vfx(model:GetAttribute("EOS_InvisibleSpecies"), "InvisShimmer") ~= AbilityCosmetics.NONE
end

local function cloakFor(model: Model, st: State): { Instance }?
	if st.cloak then
		return st.cloak
	end
	local key = AbilityCosmetics.vfx(model:GetAttribute("EOS_InvisibleSpecies"), "InvisShimmer")
	local t = Templates:FindFirstChild(key) or Templates:FindFirstChild("InvisShimmer")
	local tr = t and t:FindFirstChild("Root")
	local body, feet = tr and tr:FindFirstChild("Body"), tr and tr:FindFirstChild("Feet")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not body or not feet or not root then
		return nil
	end
	local parts = {}
	for _, n in ipairs(BODY) do
		local p = model:FindFirstChild(n)
		if p and p:IsA("BasePart") then
			table.insert(parts, p)
		end
	end
	local made: { Instance } = {}
	local base: { [ParticleEmitter]: NumberSequence } = {}
	-- glints come off the body parts' own volumes, so they take the body's shape
	for _, src in ipairs(body:GetChildren()) do
		if src:IsA("ParticleEmitter") then
			for _, p in ipairs(parts) do
				local e = src:Clone()
				e.Name = "EOS_InvisShimmer"
				e.Rate = math.max(1, src.Rate * 1.6 / math.max(1, #parts))
				e.Parent = p
				table.insert(made, e)
				base[e] = src.Transparency
			end
		end
	end
	local a = Instance.new("Attachment")
	a.Name = "EOS_InvisShimmer"
	a.Position = (feet :: Attachment).Position
	a.Parent = root
	table.insert(made, a)
	for _, src in ipairs(feet:GetChildren()) do
		if src:IsA("ParticleEmitter") then
			local e = src:Clone()
			e.Name = "EOS_InvisShimmer"
			e.Parent = a
			table.insert(made, e)
			base[e] = src.Transparency
		end
	end
	st.cloak, st.base = made, base
	return made
end

-- distance only: full at NEAR, FAR_VIS left at FAR (checked ten times a second)
local function fadeCloak(model: Model, st: State, isSelf: boolean)
	local now = os.clock()
	if st.fadeAt and now - st.fadeAt < 0.1 then
		return
	end
	st.fadeAt = now
	local vis = 1
	local cam = workspace.CurrentCamera
	local r = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not isSelf and cam and r then
		local d = (cam.CFrame.Position - r.Position).Magnitude
		local k = math.clamp((d - Invisibility.NEAR) / (Invisibility.FAR - Invisibility.NEAR), 0, 1)
		vis = 1 - k * (1 - Invisibility.FAR_VIS)
	end
	for e, seq in pairs(st.base or {}) do
		local kps = {}
		for _, kp in ipairs(seq.Keypoints) do
			table.insert(kps, NumberSequenceKeypoint.new(kp.Time, 1 - (1 - kp.Value) * vis))
		end
		e.Transparency = NumberSequence.new(kps)
	end
end

-- HOS-PET-006: a Catcher's invisibility carries EOS_InvisibleReveal (studs). A Runner farther away than
-- that sees nothing at all; closer, the usual shimmer. Other Catchers always see the shimmer.
local function tooFar(model: Model): boolean
	local reveal = model:GetAttribute("EOS_InvisibleReveal")
	if type(reveal) ~= "number" or player:GetAttribute("EOS_Role") == "CATCHER" then
		return false
	end
	local me = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local r = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	return not me or not r or (me.Position - r.Position).Magnitude > reveal
end

local function apply(model: Model, st: State, isSelf: boolean)
	local far = not isSelf and tooFar(model)
	local a = st.amount * (if isSelf then Invisibility.SELF elseif far then 1 else Invisibility.OTHERS)
	local hidden = st.amount > 0.5
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			(d :: any).LocalTransparencyModifier = a
		elseif not isSelf and d.Name ~= "EOS_InvisShimmer"
			and (d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("BillboardGui")) then
			if hidden and st.saved[d] == nil then
				st.saved[d] = (d :: any).Enabled
				;(d :: any).Enabled = false
			end
		end
	end
	if not isSelf then
		local hum = model:FindFirstChildOfClass("Humanoid")
		if hum and hidden and st.nameType == nil then
			st.nameType = hum.DisplayDistanceType
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
		if usesCloak(model) then
			local c = if hidden then cloakFor(model, st) else st.cloak
			for _, e in ipairs(c or {}) do
				if e:IsA("ParticleEmitter") then
					e.Enabled = hidden and not far
				end
			end
			fadeCloak(model, st, false)
		else
			local sh = if hidden then shimmerFor(model, st) else st.shimmer
			if sh then
				sh.Enabled = hidden and not far
			end
		end
	elseif usesCloak(model) then
		-- yourself: the cloak at full strength, so you know you're hidden
		local c = if st.amount > 0.5 then cloakFor(model, st) else st.cloak
		for _, e in ipairs(c or {}) do
			if e:IsA("ParticleEmitter") then
				e.Enabled = st.amount > 0.5
			end
		end
	end
end

local function restore(model: Model, st: State)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			(d :: any).LocalTransparencyModifier = 0
		end
	end
	for inst, was in pairs(st.saved) do
		if inst.Parent then
			(inst :: any).Enabled = was
		end
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum and st.nameType then
		hum.DisplayDistanceType = st.nameType
	end
	if st.shimmer then
		st.shimmer:Destroy()
	end
	for _, x in ipairs(st.cloak or {}) do
		x:Destroy()
	end
end

local function step(dt: number)
	local seen: { [Model]: boolean } = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		if char then
			seen[char] = true
			local on = char:GetAttribute("EOS_Invisible") == true
			local st = states[char]
			if on or st then
				if not st then
					st = { amount = 0, saved = {}, nameType = nil, shimmer = nil, cloak = nil, base = nil, fadeAt = nil }
					states[char] = st
				end
				local s = st :: State
				local target = if on then 1 else 0
				local k = dt / math.max(Invisibility.FADE, 1e-3)
				-- (HOS-VFX-005: hold once the target is reached; the old else-branch stepped back off 1 every
				-- other frame, so invisible players flickered)
				s.amount = if target > s.amount then math.min(target, s.amount + k)
					elseif target < s.amount then math.max(target, s.amount - k)
					else s.amount
				if s.amount <= 0 and not on then
					restore(char, s)
					states[char] = nil
				else
					apply(char, s, plr == player)
				end
			end
		end
	end
	for char, st in pairs(states) do
		if not seen[char] then
			if char.Parent then
				restore(char, st)
			end
			states[char] = nil
		end
	end
end

function Invisibility.init()
	RunService.RenderStepped:Connect(step)
end

return Invisibility
