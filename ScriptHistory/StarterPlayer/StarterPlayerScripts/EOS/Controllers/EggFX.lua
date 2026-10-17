--!nocheck
-- EggFX (HOS-EGG-002 stage 5, 17 Oct 2026): the carried egg's effects, client side (spec section 6).
--   charge glow    every player's egg glows in its rarity colour by charge (EOS_EggCharge, replicated): off / soft /
--                  medium / strong = ReplicatedStorage.VFX.EggGlow (PointLight + glitter motes)
--   charge pulse   a short ring on the egg each time charge rises (VFX.EggPulse) + a glass tick for your own
--   roll flicker   ~1 s at safety: the egg cycles the rarity colours (a Highlight), your own gets the airy whoosh
--   upgrade burst  gentle: glitter + a thin ring + a soft light that fades (VFX.EggBurst). No flash, no camera motion
--   Reduce effects keeps only the glow (no motes, pulses, flicker or burst)
-- Textures: AllVFX (av_glitter, av_ring_glow, av_ring_thin, already uploaded). Sounds: the Sound controller's licensed
-- Pro Sound Effects recordings (gem, ability, evolve). Started by EggUIController.init.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local EggConfig = require(Shared:WaitForChild("EggConfig"))
local EggLogic = require(Shared:WaitForChild("EggLogic"))

local player = Players.LocalPlayer
local EggFX = {}

local VFX: any
local Sound: any
local NpcSkins: any
local lastCharge: { [Player]: number } = {}
local flickering: { [Instance]: number } = {}

local function colorOf(r: string?): Color3
	local i = r and EggConfig.RARITY_INFO[r]
	return if i then Color3.fromRGB(i.rgb[1], i.rgb[2], i.rgb[3]) else Color3.new(1, 1, 1)
end

local function reduceEffects(): boolean
	local ok, CameraFX = pcall(function()
		return require(script.Parent:WaitForChild("CameraFX", 2))
	end)
	return ok and CameraFX and CameraFX.reduceEffects == true
end

local function eggPart(model: Instance?): BasePart?
	local egg = model and model:FindFirstChild("EOS_Egg")
	return egg and (egg.PrimaryPart or egg:FindFirstChildWhichIsA("BasePart"))
end

local function template(name: string): Attachment?
	local m = ReplicatedStorage:FindFirstChild("VFX") and ReplicatedStorage.VFX:FindFirstChild(name)
	local a = m and m:FindFirstChild(name, true)
	return a and a:Clone()
end

local function tint(att: Instance, c: Color3)
	for _, d in att:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			d.Color = ColorSequence.new(c)
		elseif d:IsA("PointLight") then
			d.Color = c
		end
	end
end

---------------------------------------------------------------- glow (3 strengths)
local STRENGTH = { -- meter fill band (charge / the EPIC mark, CHARGE.MARKS[1]) -> light brightness, range, mote rate
	{ 0.5, 5, 2 }, -- (0, 0.5)
	{ 1.0, 7, 5 }, -- [0.5, 1)
	{ 1.8, 9, 10 }, -- 1.0
}

local function glow(plr: Player)
	local part = eggPart(plr.Character)
	if not part then return end
	local c = math.min(1, (tonumber(plr:GetAttribute("EOS_EggCharge")) or 0) / EggConfig.CHARGE.MARKS[1]) -- the meter's fill toward the first mark, 0..1
	local att = part:FindFirstChild("EggGlow")
	if c <= 0 and not att then return end
	if not att then
		att = template("EggGlow")
		if not att then return end
		att.Parent = part
	end
	local band = if c >= 1 then STRENGTH[3] elseif c >= 0.5 then STRENGTH[2] elseif c > 0 then STRENGTH[1] else nil
	local col = colorOf(EggLogic.rarityForLevel(plr:GetAttribute("EOS_Tier") or 1))
	tint(att, col)
	local light = att:FindFirstChild("Light")
	local motes = att:FindFirstChild("Motes")
	if light then
		light.Brightness = if band then band[1] else 0
		light.Range = if band then band[2] else 6
		light.Enabled = band ~= nil
	end
	if motes then
		motes.Rate = if band and not reduceEffects() then band[3] else 0
	end
end

local function pulse(plr: Player, c: number)
	if reduceEffects() then return end
	local part = eggPart(plr.Character)
	local att = part and template("EggPulse")
	if not att then return end
	tint(att, colorOf(EggLogic.rarityForLevel(plr:GetAttribute("EOS_Tier") or 1)))
	att.Parent = part
	VFX.emit(att)
	Debris:AddItem(att, 1.2)
	if plr == player and Sound then
		Sound.play("gem", 1 + 0.08 * math.floor(c / EggConfig.CHARGE.CAP * 4 + 0.5)) -- the tick climbs a little with each bar
	end
end

local function watchPlayer(plr: Player)
	lastCharge[plr] = tonumber(plr:GetAttribute("EOS_EggCharge")) or 0
	plr:GetAttributeChangedSignal("EOS_EggCharge"):Connect(function()
		local c = tonumber(plr:GetAttribute("EOS_EggCharge")) or 0
		if c > (lastCharge[plr] or 0) then pulse(plr, c) end
		lastCharge[plr] = c
		glow(plr)
	end)
	plr:GetAttributeChangedSignal("EOS_Tier"):Connect(function() glow(plr) end)
end

---------------------------------------------------------------- roll flicker + upgrade burst
local CYCLE = { "rare", "epic", "legendary" }

local function flicker(model: Instance, seconds: number, final: string, upgraded: boolean, mine: boolean)
	local egg = model:FindFirstChild("EOS_Egg")
	if not egg then return end
	if mine and Sound then Sound.play("ability", 1.15) end
	if reduceEffects() then return end
	flickering[egg] = (flickering[egg] or 0) + 1
	local token = flickering[egg]
	local h = Instance.new("Highlight") -- a colour wash over the egg (presentation only; removed after the roll)
	h.Name = "EggRollFlicker"
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.FillTransparency = 0.45
	h.OutlineTransparency = 1
	h.Adornee = egg
	h.Parent = egg
	task.spawn(function()
		local t0, i = os.clock(), 0
		while os.clock() - t0 < seconds and flickering[egg] == token and h.Parent do
			i += 1
			h.FillColor = colorOf(CYCLE[(i % 3) + 1])
			task.wait(0.1)
		end
		h:Destroy()
		if flickering[egg] ~= token then return end
		if upgraded then
			local part = eggPart(model)
			local att = part and template("EggBurst")
			if att then
				tint(att, colorOf(final))
				att.Parent = part
				VFX.emit(att)
				Debris:AddItem(att, 2)
			end
			if mine and Sound then Sound.play("evolve", 1.25) end
		end
	end)
end

local function onRolled(t: any)
	if type(t) ~= "table" then return end
	local model: Instance? = nil
	if t.slot and NpcSkins then
		model = NpcSkins.modelForSlot(t.slot)
	else
		local plr = Players:GetPlayerByUserId(t.userId or 0)
		model = plr and plr.Character
	end
	if not model then return end
	local seconds = (tonumber(t.seconds) or 0) * (if t.bonus then (tonumber(t.rolls) or 1) else 1)
	flicker(model, seconds, t.to, t.from ~= t.to, t.userId == player.UserId)
end

---------------------------------------------------------------- init
function EggFX.init()
	if not EggConfig.ENABLED then return end
	VFX = require(ReplicatedStorage:WaitForChild("VFX"):WaitForChild("Emit"))
	local ok, s = pcall(require, script.Parent:WaitForChild("Sound", 5))
	Sound = if ok then s else nil
	local ok2, n = pcall(require, script.Parent:WaitForChild("NpcSkins", 5))
	NpcSkins = if ok2 then n else nil
	for _, plr in Players:GetPlayers() do watchPlayer(plr) end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(plr) lastCharge[plr] = nil end)
	local remotes = ReplicatedStorage:WaitForChild("EOS_Egg", 30)
	if remotes then remotes:WaitForChild("Rolled").OnClientEvent:Connect(onRolled) end
	-- eggs are rebuilt on every role / level change: re-apply the glow a few times a second
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then return end
		acc = 0
		for _, plr in Players:GetPlayers() do
			if (tonumber(plr:GetAttribute("EOS_EggCharge")) or 0) > 0 then glow(plr) end
		end
	end)
end

return EggFX
