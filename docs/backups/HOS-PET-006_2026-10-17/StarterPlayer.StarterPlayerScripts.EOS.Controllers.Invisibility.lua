--!strict
-- Invisibility (client): how a player under the Invisibility ability looks from this client.
--  * yourself: ghosted (SELF see-through) so you can still steer and read your own body
--  * everyone else: a faint shimmer (OTHERS see-through + a few soft glints in the pet's colour),
--    no overhead tag, no name, no outline (Outlines skips them), no egg trail/particles. An alert
--    opponent can still catch the movement; nobody can track you by your tag or your egg's sparkle.
-- The server owns it (AbilityService): character attributes EOS_Invisible (true while on),
-- EOS_InvisibleSpecies (tints the glints). Everything here is local; nothing is replicated.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

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

local function apply(model: Model, st: State, isSelf: boolean)
	local a = st.amount * (if isSelf then Invisibility.SELF else Invisibility.OTHERS)
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
		local sh = if hidden then shimmerFor(model, st) else st.shimmer
		if sh then
			sh.Enabled = hidden
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
					st = { amount = 0, saved = {}, nameType = nil, shimmer = nil }
					states[char] = st
				end
				local s = st :: State
				local target = if on then 1 else 0
				local k = dt / math.max(Invisibility.FADE, 1e-3)
				s.amount = if target > s.amount then math.min(1, s.amount + k) else math.max(0, s.amount - k)
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
