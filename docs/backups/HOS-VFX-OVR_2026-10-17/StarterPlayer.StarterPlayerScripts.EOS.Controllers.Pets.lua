-- Pets: the client side of pets and their abilities (GDD v0.4 section 13).
--  * follower: your equipped pet floats by your shoulder (yours only during a match; in the lobby
--    everyone's pets show, nearest few). Built locally from Shared/PetModel, never physical.
--  * ability: Q / gamepad Y / the round touch button asks the server, which runs the archetype's Runner
--    or Catcher handler for your role (HOS-PET-001, AbilityConfig). The server owns the cooldown; the
--    match's starting Catcher has none (EOS_PetAbilityOff), so for them there's no ability at all.
--  * effects: a short pet summon + ring over whoever used an ability (everyone sees it), the Decoy
--    poof, and a ring where a tag was blocked. Species pick looks and sound only (AbilityCosmetics).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local AbilityConfig = require(Shared:WaitForChild("AbilityConfig"))
local AbilityCosmetics = require(Shared:WaitForChild("AbilityCosmetics"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local Net = require(Shared:WaitForChild("Net"))
local PetModel = require(Shared:WaitForChild("PetModel"))
local Movement = require(script.Parent.Movement)
local Sound = require(script.Parent.Sound)
local CrowPet = require(script.Parent.CrowPet) -- rigged crow: walking follower, swoop-in summon
local PetBehaviors = require(script.Parent.PetBehaviors) -- rigged pets: follower + summon per species
local Invisibility = require(script.Parent.Invisibility) -- how invisible players look from here
local AbilityVFX = require(script.Parent.AbilityVFX) -- the abilities' effects (HOS-VFX-001)

local Pets = {}
Pets.readyAt = 0 -- os.clock() when the ability is ready again
Pets.cooldown = 1
Pets.onToast = nil :: ((string, string?) -> ())?
Pets.onUsed = nil :: ((string) -> ())?

local player = Players.LocalPlayer

function Pets.family(): string?
	local f = player:GetAttribute("EOS_PetFamily")
	local test = player:GetAttribute("EOS_TestPet")
	if RunService:IsStudio() and type(test) == "string" and test ~= "" then
		-- Studio pet test (CrowPet.speciesOf): the test pet's own family
		f = player:GetAttribute("EOS_TestPetFamily") or EconomyConfig.familyOfSpecies(test) or "Decoy"
	end
	if player:GetAttribute("EOS_PetAbilityOff") == true then
		return nil -- the match's starting Catcher: no pet ability this match
	end
	return if AbilityConfig.get(f) then f else nil -- (a pet of a removed family has no ability)
end

-- 0..1 (1 = ready)
function Pets.charge(): number
	local left = Pets.readyAt - os.clock()
	return if left <= 0 then 1 else 1 - left / math.max(Pets.cooldown, 0.01)
end

local function toast(text: string, kind: string?)
	if Pets.onToast then
		Pets.onToast(text, kind)
	end
end

function Pets.use()
	local fam = Pets.family()
	if player:GetAttribute("EOS_InMatch") ~= true and player:GetAttribute("EOS_Sandbox") ~= true then
		return
	end
	if not fam then
		toast("No pet yet: hatch one at the incubator", "info")
		return
	end
	if os.clock() < Pets.readyAt then
		Sound.play("tick", 0.8)
		return
	end
	local role = player:GetAttribute("EOS_Role")
	if role ~= "RUNNER" and role ~= "CATCHER" then
		return
	end
	local def = AbilityConfig.forRole(fam, role)
	if def and def.built then
		-- predicted: the server answers with the real cooldown (AbilityState), or refuses and it's back
		local cd = def.cooldown
		local testCd = if RunService:IsStudio() then workspace:GetAttribute("EOS_TestCooldown") else nil
		if type(testCd) == "number" and testCd > 0 then
			cd = testCd -- Studio pet test (AbilityService.studioTest)
		end
		Pets.cooldown = cd
		Pets.readyAt = os.clock() + cd
	end
	Net.event("RequestAbility"):FireServer(Movement.wishDir())
	if Pets.onUsed then
		Pets.onUsed(fam)
	end
end

-- ===== followers =====

type Follower = {
	model: Model,
	species: string,
	owner: Player,
	pos: Vector3,
	t: number,
	level: number,
	crow: any?, -- follower state for rigged pets (driven by `beh`)
	beh: any?, -- the species' behaviour module (PetBehaviors)
	hiddenUntil: number, -- the pet flew into its ability; back after the copy is gone
}
local followers: { [Player]: Follower } = {}
local LOBBY_SHOW = 8 -- other people's pets drawn in the lobby (nearest first)

local function wanted(): { [Player]: boolean }
	local out: { [Player]: boolean } = {}
	local myChar = player.Character
	local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	local inMatch = player:GetAttribute("EOS_InMatch") == true
	local others = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		local sp = CrowPet.speciesOf(plr)
		local c = plr.Character
		local r = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
		if type(sp) == "string" and sp ~= "" and r then
			if plr == player then
				out[plr] = true
			elseif not inMatch and plr:GetAttribute("EOS_InMatch") ~= true and myRoot then
				table.insert(others, { plr = plr, d = (r.Position - myRoot.Position).Magnitude })
			end
		end
	end
	table.sort(others, function(a, b)
		return a.d < b.d
	end)
	for i = 1, math.min(LOBBY_SHOW, #others) do
		if others[i].d < 140 then
			out[others[i].plr] = true
		end
	end
	return out
end

local function updateFollowers(dt: number)
	local want = wanted()
	for plr, f in pairs(followers) do
		local sp, lv = CrowPet.speciesOf(plr)
		if not want[plr] or sp ~= f.species or lv ~= f.level or not plr.Parent then
			f.model:Destroy()
			followers[plr] = nil
		end
	end
	local now = os.clock()
	for plr in pairs(want) do
		local c = plr.Character
		local r = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
		if r then
			local f = followers[plr]
			if not f then
				local sp, lv = CrowPet.speciesOf(plr)
				local name = sp :: string
				local beh = PetBehaviors.get(name)
				if PetModel.isRigged(name) and beh then
					-- rigged pets walk with you (the crow flies to keep up, the chameleon rides your shoulder)
					local cf = beh.newFollower(lv, r)
					f = { model = cf.model, species = name, owner = plr, pos = r.Position, t = 0, level = lv, crow = cf, beh = beh, hiddenUntil = 0 }
				else
					local m = PetModel.build(name, 1.05)
					m.Name = "EOS_Follower"
					m.Parent = workspace.CurrentCamera -- local only, never in the server's world
					f = { model = m, species = name, owner = plr, pos = r.Position, t = math.random() * 6, level = lv, crow = nil, hiddenUntil = 0 }
				end
				followers[plr] = f
			end
			-- hidden while it's in the ability, and for as long as its owner is invisible: it never shows
			-- up before they do (the reveal clears EOS_Invisible, then it pops back)
			if f.hiddenUntil > now or (r.Parent and r.Parent:GetAttribute("EOS_Invisible")) then
				f.model.Parent = nil -- it flew into the ability
			elseif f.crow and f.beh then
				if f.model.Parent == nil then
					f.model.Parent = workspace.CurrentCamera
					f.beh.respawnFollower(f.crow, r)
				end
				f.beh.updateFollower(f.crow, r, dt)
			else
				if f.model.Parent == nil then
					f.model.Parent = workspace.CurrentCamera
				end
				f.t += dt
				-- behind the right shoulder, bobbing; trails a little when you run
				local goal = (r.CFrame * CFrame.new(2.1, 1.4 + math.sin(f.t * 3) * 0.18, 1.6)).Position
				f.pos = f.pos:Lerp(goal, 1 - math.exp(-dt * 9))
				local look = r.CFrame.LookVector
				f.model:PivotTo(CFrame.lookAt(f.pos, f.pos + Vector3.new(look.X, 0, look.Z)))
			end
		end
	end
end

-- ===== effects =====

local function modelFor(uid: number): Model?
	local plr = Players:GetPlayerByUserId(uid)
	if plr then
		return plr.Character
	end
	local rt = workspace:FindFirstChild("EOS_Runtime")
	local npcs = rt and rt:FindFirstChild("Npcs")
	if npcs then
		for _, m in ipairs(npcs:GetChildren()) do
			if m:GetAttribute("EOS_UserId") == uid then
				return m :: Model
			end
		end
	end
	return nil
end

local function ring(at: Vector3, color: Color3)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.2, 2, 2)
	p.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
	p.Transparency = 0.2
	p.Parent = workspace.CurrentCamera
	TweenService:Create(p, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.2, 12, 12), Transparency = 1 }):Play()
	task.delay(0.5, function()
		p:Destroy()
	end)
end

local function summon(t: any)
	local who = modelFor(t.userId)
	local beh = PetBehaviors.get(t.species)
	if who and beh then
		-- the rigged pet's own entrance; its level's flash fires as the ability lands (PetBehaviors)
		beh.summon(who, tonumber(t.level) or 1)
		local owner = Players:GetPlayerByUserId(t.userId)
		local f = owner and followers[owner]
		if f then
			f.hiddenUntil = os.clock() + (beh.INTRO or 0.5) + (tonumber(t.duration) or 3) + 0.3
		end
		return
	end
	local head = who and who:FindFirstChild("Head") :: BasePart?
	local color = AbilityCosmetics.resolve(t.species, t.family, t.gold == true).ringColor
	local root = who and who:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		ring(root.Position - Vector3.new(0, 2.6, 0), color)
	end
	if not head or type(t.species) ~= "string" then
		return
	end
	-- the pet pops up over the user's head for a moment (opponents never see followers)
	local m = PetModel.build(t.species, 1.6)
	m.Parent = workspace.CurrentCamera
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local k = os.clock() - t0
		if k > 0.9 or not head.Parent then
			conn:Disconnect()
			m:Destroy()
			return
		end
		local rise = math.min(k / 0.18, 1)
		local s = 1 - math.max(0, k - 0.7) / 0.2
		m:ScaleTo(math.max(0.05, s))
		m:PivotTo(CFrame.new(head.Position + Vector3.new(0, 1.4 + rise * 1.2, 0)) * CFrame.Angles(0, k * 6, 0))
	end)
end

local function poof(pos: Vector3)
	local a = Instance.new("Part")
	a.Anchored = true
	a.CanCollide = false
	a.CanQuery = false
	a.Transparency = 1
	a.Size = Vector3.new(1, 1, 1)
	a.CFrame = CFrame.new(pos)
	a.Parent = workspace.CurrentCamera
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(235, 235, 245))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 4.5) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.5, 0.8)
	e.Speed = NumberRange.new(4, 9)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 0
	e.Parent = a
	e:Emit(24)
	task.delay(1, function()
		a:Destroy()
	end)
end

function Pets.init()
	ContextActionService:BindAction("EOS_PetAbility", function(_, state)
		if state == Enum.UserInputState.Begin then
			Pets.use()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.Q, Enum.KeyCode.ButtonY)
	Net.event("AbilityState").OnClientEvent:Connect(function(t)
		if type(t) ~= "table" then
			return
		end
		if t.ok then
			Pets.cooldown = t.readyIn or Pets.cooldown
			Pets.readyAt = os.clock() + (t.readyIn or 0)
		elseif t.reason == "COOLDOWN" and type(t.readyIn) == "number" then
			Pets.readyAt = os.clock() + t.readyIn
		else
			Pets.readyAt = 0 -- refused: nothing was spent
		end
	end)
	Net.event("AbilityFx").OnClientEvent:Connect(function(t)
		if type(t) ~= "table" then
			return
		end
		if t.kind == "summon" then
			summon(t)
			Sound.play("evolve", 1.4)
		elseif t.kind == "poof" and typeof(t.pos) == "Vector3" then
			-- the crow's copy leaves in a scatter of crows at level 2+
			local beh = PetBehaviors.get(t.species)
			if not (beh and beh.poof(t.pos, tonumber(t.level) or 1)) then
				AbilityVFX.play("DecoyPoof", CFrame.new(t.pos)) -- (the old grey puff: poof)
			end
		elseif t.kind == "vfx" and type(t.name) == "string" and typeof(t.pos) == "Vector3" then
			-- an ability's one-shot effect (Abilities.Shared.vfx), facing `look` when given
			local look = if typeof(t.look) == "Vector3" and t.look.Magnitude > 0.01 then t.look else nil
			AbilityVFX.play(t.name, if look then CFrame.lookAt(t.pos, t.pos + look) else CFrame.new(t.pos))
		elseif t.kind == "blocked" and typeof(t.pos) == "Vector3" then
			-- a "blocks one tag" charge stopped a tag: everyone sees where (archetype colour, never gold)
			ring(t.pos - Vector3.new(0, 1.5, 0), AbilityCosmetics.resolve(nil, t.family).color)
			Sound.play("tick", 1.2)
		end
	end)
	Invisibility.init()
	AbilityVFX.init()
	-- a new match: the cooldown starts fresh
	player:GetAttributeChangedSignal("EOS_InMatch"):Connect(function()
		Pets.readyAt = 0
	end)
	RunService.RenderStepped:Connect(updateFollowers)
end

return Pets
