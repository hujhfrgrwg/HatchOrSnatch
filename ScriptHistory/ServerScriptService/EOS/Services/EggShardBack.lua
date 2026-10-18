--!strict
-- EggShardBack (HOS-EGG-002, 17 Oct ~20:25, Hunter approved): the carried egg is shown as a physical shard on the
-- Runner's back. CharacterService.setEgg still builds the egg model (EOS_Egg) on every role / tier change and calls its
-- onEggBuilt hooks; this hook hides the egg's own parts and welds the shard (ReplicatedStorage.EggShardKit) to the upper
-- torso, in the rarity of the egg's tier, with a soft PointLight in the rarity colour (no Neon). Rebuilt on every step
-- (recolour), removed with the egg (caught / Catcher / lobby), bots included. Off while EggConfig.ENABLED is false.
-- Hook (one line in EggService.init): CharacterService.onEggBuilt(EggShardBack.dress)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local EggConfig = require(Shared:WaitForChild("EggConfig"))
local EggLogic = require(Shared:WaitForChild("EggLogic"))

local Back = {}

-- placement (checked from directly behind, 17 Oct ~20:15): centred between the shoulder blades, convex side out,
-- a 12 deg tilt, inside the torso outline
local OFFSET_X, OFFSET_Y, TILT = -0.06, -0.02, math.rad(-12)

local function glowColor(r: string): Color3
	local i = EggConfig.RARITY_INFO[r]
	return if i then Color3.fromRGB(i.rgb[1], i.rgb[2], i.rgb[3]) else Color3.new(1, 1, 1)
end

function Back.build(rarity: string): BasePart?
	local kit = ReplicatedStorage:FindFirstChild("EggShardKit")
	local tpl = kit and kit:FindFirstChild("Shard")
	local sa = kit and kit:FindFirstChild("SA_" .. rarity)
	if not (tpl and tpl:IsA("BasePart")) then return nil end
	local s = tpl:Clone()
	s.Name = "EOS_Shard"
	if sa then sa:Clone().Parent = s end
	local light = Instance.new("PointLight")
	light.Color = glowColor(rarity)
	light.Brightness = 1.2
	light.Range = 6
	light.Shadows = false
	light.Parent = s
	s:SetAttribute("EOS_Egg", true) -- CharacterService.setGroup leaves egg parts alone
	s:SetAttribute("EOS_ShardRarity", rarity)
	return s
end

-- where the shard sits on a torso
function Back.cframe(torso: BasePart, shard: BasePart): CFrame
	return torso.CFrame * CFrame.new(OFFSET_X, OFFSET_Y, torso.Size.Z / 2 + shard.Size.Z / 2 - 0.05)
		* CFrame.Angles(0, math.pi, 0) * CFrame.Angles(0, 0, TILT)
end

function Back.dress(actor: any, egg: Model)
	if not EggConfig.ENABLED or not egg then return end
	local char = egg.Parent
	local torso = char and (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso"))
	if not (torso and torso:IsA("BasePart")) then return end
	local rarity = EggLogic.rarityForLevel(egg:GetAttribute("EOS_Tier") or 1)
	local s = Back.build(rarity)
	if not s then return end
	s.CFrame = Back.cframe(torso, s)
	local w = Instance.new("WeldConstraint")
	w.Part0 = torso
	w.Part1 = s
	w.Parent = s
	s.Parent = egg -- leaves with the egg
	egg.PrimaryPart = s -- EggFX's glow / pulse / burst attach to the egg's PrimaryPart: now the shard
	-- hide the egg itself, after the other dressing hooks (egg cases) have run this frame
	task.defer(function()
		if not egg.Parent then return end
		for _, d in egg:GetDescendants() do
			if d:IsA("BasePart") and d ~= s then
				d.Transparency = 1
			elseif (d:IsA("Decal") or d:IsA("Texture")) and not d:IsDescendantOf(s) then
				d.Transparency = 1
			end
		end
	end)
end

return Back
