--!strict
-- WeaponFX (client, StarterPlayerScripts.EOS.WeaponFXBoot), HOS-WEP-001. Looks only: nothing here touches hits,
-- reach or timing. Hunter 17 Oct: "Is serverstorage.slashyay useful for slash vfx" (yes, trimmed and shrunk) and,
-- for the open questions (slash on Epic + Legendary swings, Legendaries standing out), "Fully implement this end
-- to end" (23:25).
--  * Swing slash: when a character holding an Epic or Legendary knife skin plays a swing clip (SwingJab /
--    SwingSlash / SwingDual), a knife-sized crescent slash (ReplicatedStorage.EOS_SlashFX, from Hunter's slashyay:
--    2 crescents + wind ring + specks) plays in front of them, tinted to the weapon. Every client draws it for every
--    character it sees, from the clip itself, so nothing goes over the network.
--  * Legendaries: the blade glow and the weapon's light pulse slowly, and a faint aura in the weapon's colour sits
--    round the hand while the weapon is out of the holster.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnimConfig = require(ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared"):WaitForChild("AnimConfig"))

local SLASH_DELAY = 0.08 -- seconds into the swing clip: the blade's fastest part
local SLASH_AHEAD = 2.6 -- studs in front of the body
local GLOW = "rbxassetid://105604239679551" -- our soft glow (vfx/weapon_aura)
local RARITY_COL = { epic = Color3.fromRGB(180, 77, 255), legendary = Color3.fromRGB(255, 194, 28) }

local swingIds: { [string]: boolean } = {}
for _, k in { "SwingJab", "SwingSlash", "SwingDual" } do
	local id = AnimConfig.ids and AnimConfig.ids[k]
	if type(id) == "string" and id ~= "" then
		swingIds[id] = true
	end
end

-- the weapon's own colour: its edge energy, else its blade glow, else its rarity colour
local function tintOf(knife: Instance, rarity: string): Color3
	for _, n in { "VfxRimWisps", "VfxAura", "VfxFlame" } do
		local e = knife:FindFirstChild(n, true)
		if e and e:IsA("ParticleEmitter") then
			local k = e.Color.Keypoints
			return k[#k].Value
		end
	end
	return RARITY_COL[rarity] or Color3.new(1, 1, 1)
end

local function knifeOf(char: Model): (BasePart?, string?)
	local k = char:FindFirstChild("Minute Dagger")
	if k and k:IsA("BasePart") then
		local r = k:GetAttribute("Rarity")
		return k, if type(r) == "string" then r else nil
	end
	return nil, nil
end

-- ===== the slash

local function playSlash(char: Model, knife: BasePart, rarity: string)
	local tpl = ReplicatedStorage:FindFirstChild("EOS_SlashFX")
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not tpl or not root then
		return
	end
	local fx = tpl:Clone() :: BasePart
	local look = root.CFrame.LookVector
	local at = root.Position + Vector3.new(0, 0.4, 0) + Vector3.new(look.X, 0, look.Z).Unit * SLASH_AHEAD
	-- flat (the crescents face along the attachment's up = world up), turned to the way the character faces,
	-- a random tilt so two swings never look the same
	fx.CFrame = CFrame.lookAt(at, at + Vector3.new(look.X, 0, look.Z)) * CFrame.Angles(0, 0, math.rad(math.random(-25, 25)))
	local col = tintOf(knife, rarity)
	local life = 0
	for _, e in fx:GetDescendants() do
		if e:IsA("ParticleEmitter") then
			if e:GetAttribute("SlashTint") then
				e.Color = ColorSequence.new(col:Lerp(Color3.new(1, 1, 1), 0.35), col)
			end
			life = math.max(life, e.Lifetime.Max + ((e:GetAttribute("EmitDelay") :: number?) or 0))
		end
	end
	fx.Parent = workspace
	for _, e in fx:GetDescendants() do
		if e:IsA("ParticleEmitter") then
			local n = (e:GetAttribute("EmitCount") :: number?) or 1
			local d = (e:GetAttribute("EmitDelay") :: number?) or 0
			if d > 0 then
				task.delay(d, function()
					if e.Parent then
						e:Emit(n)
					end
				end)
			else
				e:Emit(n)
			end
		end
	end
	task.delay(life + 0.2, function()
		fx:Destroy()
	end)
end

local watched: { [Animator]: boolean } = {}
local function watchAnimator(an: Animator, char: Model)
	if watched[an] then
		return
	end
	watched[an] = true
	an.AnimationPlayed:Connect(function(track)
		local anim = track.Animation
		local id = anim and anim.AnimationId or ""
		local name = anim and anim.Name or ""
		if not (swingIds[id] or name:sub(1, 5) == "Swing") then
			return
		end
		local knife, rarity = knifeOf(char)
		if not knife or (rarity ~= "epic" and rarity ~= "legendary") then
			return
		end
		task.delay(SLASH_DELAY, function()
			if knife.Parent == char then
				playSlash(char, knife, rarity :: string)
			end
		end)
	end)
	an.AncestryChanged:Connect(function()
		if not an:IsDescendantOf(workspace) then
			watched[an] = nil
		end
	end)
end

local function watchCharacter(char: Model)
	local hum = char:WaitForChild("Humanoid", 10)
	local an = hum and hum:WaitForChild("Animator", 10)
	if an and an:IsA("Animator") then
		watchAnimator(an, char)
	end
end

-- every character this client sees: players and NPCs (Catcher dummies) alike
local function scan(m: Instance)
	if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") then
		task.spawn(watchCharacter, m)
	end
end
for _, d in workspace:GetDescendants() do
	if d:IsA("Humanoid") and d.Parent then
		scan(d.Parent)
	end
end
workspace.DescendantAdded:Connect(function(d)
	if d:IsA("Humanoid") then
		task.defer(function()
			if d.Parent then
				scan(d.Parent)
			end
		end)
	elseif d:IsA("Animator") then
		local char = d:FindFirstAncestorOfClass("Model")
		if char then
			watchAnimator(d, char)
		end
	end
end)

-- ===== Legendaries: pulse + hand aura

type Leg = { knife: BasePart, char: Model, aura: ParticleEmitter?, base: { [Instance]: number }, hand: Attachment? }
local legs: { [BasePart]: Leg } = {}

local function handOf(char: Model): BasePart?
	local h = char:FindFirstChild("Right Arm") or char:FindFirstChild("RightHand")
	return if h and h:IsA("BasePart") then h else nil
end

local function track(knife: BasePart)
	if legs[knife] or knife:GetAttribute("Rarity") ~= "legendary" or knife:GetAttribute("EOS_Holstered") then
		return
	end
	local char = knife.Parent
	if not (char and char:IsA("Model") and char:FindFirstChildOfClass("Humanoid")) then
		return
	end
	local rec: Leg = { knife = knife, char = char, aura = nil, base = {}, hand = nil }
	for _, d in knife:GetDescendants() do
		if d:IsA("ParticleEmitter") and d.Name == "VfxAura" then
			rec.base[d] = d.Brightness
		elseif d:IsA("PointLight") then
			rec.base[d] = d.Brightness
		end
	end
	-- the hand aura: a soft glow round the hand, in the weapon's colour (this client's copy only)
	local hand = handOf(char)
	if hand then
		local a = Instance.new("Attachment")
		a.Name = "HOS_LegendHandFX"
		a.Position = Vector3.new(0, -hand.Size.Y / 2 + 0.2, 0)
		local e = Instance.new("ParticleEmitter")
		e.Name = "HandAura"
		e.Texture = GLOW
		e.Color = ColorSequence.new(tintOf(knife, "legendary"))
		e.LightEmission = 1
		e.LightInfluence = 0
		e.Brightness = 1.6
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 1.3) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.72), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(0.7, 1)
		e.Rate = 5
		e.Speed = NumberRange.new(0)
		e.LockedToPart = true
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-30, 30)
		e.ZOffset = -0.3
		e.Enabled = false
		e.Parent = a
		a.Parent = hand
		rec.aura = e
		rec.hand = a
	end
	legs[knife] = rec
end

local function untrack(knife: BasePart)
	local rec = legs[knife]
	if rec then
		legs[knife] = nil
		if rec.hand then
			rec.hand:Destroy()
		end
	end
end

for _, d in workspace:GetDescendants() do
	if d:IsA("BasePart") and d.Name == "Minute Dagger" then
		task.defer(track, d)
	end
end
workspace.DescendantAdded:Connect(function(d)
	if d:IsA("BasePart") and d.Name == "Minute Dagger" then
		task.defer(track, d)
	end
end)
workspace.DescendantRemoving:Connect(function(d)
	if d:IsA("BasePart") and legs[d :: BasePart] then
		untrack(d :: BasePart)
	end
end)

RunService.Heartbeat:Connect(function()
	local t = os.clock()
	local pulse = 1 + 0.55 * math.sin(t * 2.6) -- a slow breath, about every 2.4 s
	for knife, rec in legs do
		if knife.Parent ~= rec.char then
			untrack(knife)
			continue
		end
		for inst, b in rec.base do
			if inst.Parent then
				(inst :: any).Brightness = b * pulse
			end
		end
		-- the aura shows while the weapon is in the hand (the holster hides the hand copy while it's put away)
		if rec.aura then
			rec.aura.Enabled = knife.Transparency < 1 and knife.LocalTransparencyModifier < 1
		end
	end
end)

-- the lobby pedestals (today's store + the crate showcase): their own module, started here
require(script.Parent:WaitForChild("Controllers"):WaitForChild("WeaponPedestals")).start()

-- HOS-WEP-002: the Halloween podium's showcase (your avatar with the All Hallow's Sword), its own module
require(script.Parent:WaitForChild("Controllers"):WaitForChild("WeaponShowcase")).start()
