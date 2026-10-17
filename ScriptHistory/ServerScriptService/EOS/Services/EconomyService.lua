--!strict
-- EconomyService: the incubator, pets and shops (GDD v0.4). Every request is validated here and
-- applied through DataService (exact-once ledgers live in ProfileLogic); clients only ask.
--  * RequestHatch(rarity, family?, allowHigher?)  pieces -> a pet (lobby only)
--  * RequestEquipPet(petId)                       one equipped pet = one ability (lobby only)
--  * RequestBuy(itemId) / RequestUseItem(itemId) / RequestSetCosmetic(slot, itemId)
-- Cosmetics are worn here too: egg case + trail on the carried egg, the lobby entrance effect and
-- the confetti burst. None of them change hitboxes, speed or timing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local Net = require(Shared:WaitForChild("Net"))
local ProfileLogic = require(ServerScriptService.EOS.Core.ProfileLogic)
local Analytics = require(script.Parent.Analytics)
local CharacterService = require(script.Parent.CharacterService)
local DataService = require(script.Parent.DataService)
local MatchService = require(script.Parent.MatchService)

local EconomyService = {}

local rng = Random.new()

local function toast(plr: Player, text: string, kind: string?)
	Net.event("Toast"):FireClient(plr, { text = text, kind = kind or "info" })
end

local function reject(plr: Player, remote: string)
	Analytics.warn("RemoteValidationRejected", remote .. plr.UserId, ("bad %s payload from %d"):format(remote, plr.UserId), { userId = plr.UserId, remote = remote })
end

local function inMatch(plr: Player): boolean
	return plr:GetAttribute("EOS_InMatch") == true
end

-- Run fn on a scratch copy first; only a change that succeeds there is queued for the save.
-- fn must be deterministic (it runs again against the stored profile when the save flushes).
local function tryUpdate(plr: Player, label: string, fn: (any) -> (boolean, any?)): (boolean, any?)
	local live = DataService.get(plr)
	if not live then
		return false, "NOT_LOADED"
	end
	local scratch = ProfileLogic.deepCopy(live)
	local ok, info = fn(scratch)
	if not ok then
		return false, info
	end
	local first: any = nil
	DataService.update(plr, label, function(p)
		local _, i = fn(p)
		if first == nil then
			first = i
		end
	end)
	return true, first or info
end

-- ===== incubator =====

local HATCH_WORDS = {
	NOT_ENOUGH = "Not enough pieces for that hatch yet",
	CHOOSE_FAMILY = "Pick a family for your first pet (it's free)",
	NEEDS_HIGHER = "That hatch would use higher pieces: confirm to use them",
	BAD_FAMILY = "That family isn't available yet",
	BAD_RARITY = "Unknown egg piece",
	NOT_LOADED = "Your save is still loading",
}

local function onHatch(plr: Player, rarity: any, family: any, allowHigher: any)
	if not MatchService.limiter:allow(plr.UserId, "RequestHatch", os.clock()) then
		return
	end
	if type(rarity) ~= "string" or (family ~= nil and type(family) ~= "string") or (allowHigher ~= nil and type(allowHigher) ~= "boolean") then
		return reject(plr, "RequestHatch")
	end
	if inMatch(plr) then
		return toast(plr, "Hatch at the incubator between matches", "info")
	end
	-- the random family is rolled once, here, so every replay of the change hatches the same pet
	local randomFamily = EconomyConfig.LAUNCH_FAMILIES[rng:NextInteger(1, #EconomyConfig.LAUNCH_FAMILIES)]
	local ctx = { econ = EconomyConfig, allowHigher = allowHigher == true, pickFamily = function()
		return randomFamily
	end }
	local planOut: any = nil
	local ok, info = tryUpdate(plr, "hatch", function(p)
		local good, reason, pet, plan = ProfileLogic.hatch(p, rarity, family, ctx)
		planOut = plan
		if not good then
			return false, reason
		end
		return true, pet
	end)
	local owns = DataService.get(plr)
	local royal = owns ~= nil and owns.cosmetics.owned.hatch_royal == true
	if not ok then
		Net.event("HatchResult"):FireClient(plr, { ok = false, reason = info, plan = planOut })
		if info ~= "NEEDS_HIGHER" and info ~= "CHOOSE_FAMILY" then
			toast(plr, HATCH_WORDS[info] or "Can't hatch that right now", "warn")
		end
		return
	end
	local pet = info
	Net.event("HatchResult"):FireClient(plr, { ok = true, pet = pet, plan = planOut, royal = royal })
	Analytics.log("PetCrafted", { userId = plr.UserId, speciesId = pet.species, abilityFamily = pet.family, rarity = pet.rarity, randomFlag = family == nil })
	if family ~= nil and planOut and not planOut.free then
		Analytics.log("FocusUsed", { userId = plr.UserId, tier = rarity, familyId = family, extraPieceOrGem = "piece" })
	end
end

local function onEquip(plr: Player, petId: any)
	if not MatchService.limiter:allow(plr.UserId, "RequestEquipPet", os.clock()) then
		return
	end
	if type(petId) ~= "string" or #petId > 16 then
		return reject(plr, "RequestEquipPet")
	end
	if inMatch(plr) then
		return toast(plr, "Pets can't be swapped mid-match", "info")
	end
	local ok = tryUpdate(plr, "equip", function(p)
		return ProfileLogic.equipPet(p, petId)
	end)
	if not ok then
		toast(plr, "You don't own that pet", "warn")
	end
end

-- ===== shop =====

local SHOP_WORDS = {
	NOT_ENOUGH = "Not enough %s",
	OWNED = "You already own that",
	UNKNOWN = "That item isn't for sale",
}

local function onBuy(plr: Player, itemId: any)
	if not MatchService.limiter:allow(plr.UserId, "RequestBuy", os.clock()) then
		return
	end
	if type(itemId) ~= "string" or #itemId > 32 then
		return reject(plr, "RequestBuy")
	end
	if inMatch(plr) then
		return toast(plr, "The shop opens between matches", "info")
	end
	local item = EconomyConfig.item(itemId)
	local ok, reason = tryUpdate(plr, "buy:" .. itemId, function(p)
		local good, why = ProfileLogic.buy(p, itemId, EconomyConfig)
		return good, why
	end)
	Net.event("ShopResult"):FireClient(plr, { ok = ok, reason = if ok then nil else reason, itemId = itemId })
	if not ok then
		local words = SHOP_WORDS[reason] or "Can't buy that right now"
		toast(plr, words:format(if item and item.wallet == "gems" then "Gems" else "Gold"), "warn")
		return
	end
	if item then
		Analytics.log(if item.wallet == "gems" then "GemsSink" else "GoldSink", { userId = plr.UserId, amount = item.price, reason = itemId })
		-- no toast: ShopResult opens the client's Reward reveal (16 Oct)
	end
end

-- ===== worn cosmetics =====

local function confetti(at: BasePart)
	local att = Instance.new("Attachment")
	att.Name = "EOS_Confetti"
	att.Position = Vector3.new(0, 3, 0)
	att.Parent = at
	local e = Instance.new("ParticleEmitter")
	-- HOS-VFX-RES-001: tumbling paper-confetti flipbook (IxJoke's upload, not ours) instead of sparkles
	e.Texture = "rbxassetid://11137599166"
	e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
	e.FlipbookMode = Enum.ParticleFlipbookMode.Loop
	e.FlipbookFramerate = NumberRange.new(16, 24)
	e.FlipbookStartRandom = true
	e.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 96, 160)),
		ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 214, 72)),
		ColorSequenceKeypoint.new(0.66, Color3.fromRGB(96, 200, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 236, 140)),
	})
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.2) })
	e.Lifetime = NumberRange.new(1.2, 2)
	e.Speed = NumberRange.new(14, 24)
	e.SpreadAngle = Vector2.new(50, 50)
	e.Acceleration = Vector3.new(0, -22, 0)
	e.Drag = 1.5
	e.RotSpeed = NumberRange.new(-300, 300)
	e.Rotation = NumberRange.new(0, 360)
	e.LightEmission = 0.3
	e.Rate = 0
	e.Parent = att
	e:Emit(70)
	task.delay(2.5, function()
		att:Destroy()
	end)
end

local function onUse(plr: Player, itemId: any)
	if not MatchService.limiter:allow(plr.UserId, "RequestUseItem", os.clock()) then
		return
	end
	if type(itemId) ~= "string" then
		return reject(plr, "RequestUseItem")
	end
	local item = EconomyConfig.item(itemId)
	if not item or item.kind ~= "burst" then
		return toast(plr, "That can't be used here", "info")
	end
	if inMatch(plr) then
		return toast(plr, "Save the confetti for the lobby", "info")
	end
	local char = plr.Character
	local head = char and char:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local ok = tryUpdate(plr, "use:" .. itemId, function(p)
		return ProfileLogic.consume(p, itemId), nil
	end)
	if not ok then
		return toast(plr, "You're out of " .. item.name .. ": the shop has more", "info")
	end
	confetti(head)
	Analytics.log("CosmeticUsed", { userId = plr.UserId, itemId = itemId })
end

local function onSetCosmetic(plr: Player, slot: any, itemId: any)
	if not MatchService.limiter:allow(plr.UserId, "RequestSetCosmetic", os.clock()) then
		return
	end
	if type(slot) ~= "string" or type(itemId) ~= "string" then
		return reject(plr, "RequestSetCosmetic")
	end
	local ok = tryUpdate(plr, "cosmetic", function(p)
		return ProfileLogic.setCosmetic(p, slot, itemId, EconomyConfig)
	end)
	if not ok then
		toast(plr, "You don't have that yet", "warn")
	elseif slot == "case" and plr.Character and plr.Character:FindFirstChild("EOS_Egg") then
		CharacterService.setEgg(plr, plr:GetAttribute("EOS_Tier")) -- re-dress the egg you carry
	end
end

-- the trail each player wears this match (decided once at match start)
local matchTrail: { [Player]: string } = {}

-- MatchService calls this as a match starts: an armed one-match trail is used up now.
function EconomyService.startMatch(plr: Player)
	matchTrail[plr] = nil
	local p = DataService.get(plr)
	if not p then
		return
	end
	local armed = p.cosmetics.trailNext
	if armed ~= "" and (p.cosmetics.consumables[armed] or 0) > 0 then
		local ok = tryUpdate(plr, "trail:" .. armed, function(pp)
			return ProfileLogic.consume(pp, armed), nil
		end)
		if ok then
			matchTrail[plr] = armed
			Analytics.log("CosmeticUsed", { userId = plr.UserId, itemId = armed })
			return
		end
	end
	if p.cosmetics.owned.trailp_rainbow then
		matchTrail[plr] = "trailp_rainbow"
	end
end

function EconomyService.endMatch(plr: Player)
	matchTrail[plr] = nil
end

-- HOS-VFX-RES-001 (Hunter, 17 Oct: use the UNSORTED OS RESOURCES place where it beats ours): textured trail
-- layers instead of flat colour strips. Not our uploads (realkilometers' Stardust, Arisu Club's wisp,
-- BloxenRBLX's ember); if one is ever deleted that layer just draws blank. Swap in our own when we draw them.
local TRAIL_LAYERS = {
	trail_spark = { { tex = "rbxassetid://18568183566", width = 1, life = 0.5 }, { tex = "rbxassetid://18568048335", width = 0.6, life = 0.35 } },
	trail_ember = { { tex = "rbxassetid://70464235210468", width = 1, life = 0.4 } },
	trailp_rainbow = { { tex = "rbxassetid://99421661918040", width = 1, life = 0.55 }, { tex = "rbxassetid://18568048335", width = 0.7, life = 0.4 } },
}
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 214, 72)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(110, 236, 120)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(90, 170, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 120, 255)),
})

local function trailOn(base: BasePart, item: any)
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailBottom"
	a1.Position = Vector3.new(0, 0.1, 0)
	a1.Parent = base
	local layers = TRAIL_LAYERS[item.id] or { { tex = "", width = 1, life = 0.45 } }
	for i, layer in ipairs(layers) do
		local a0 = Instance.new("Attachment")
		a0.Name = "TrailTop" .. i
		a0.Position = Vector3.new(0, 0.1 + 0.8 * layer.width, 0)
		a0.Parent = base
		local t = Instance.new("Trail")
		t.Attachment0 = a0
		t.Attachment1 = a1
		t.Texture = layer.tex
		t.TextureMode = Enum.TextureMode.Stretch
		t.Lifetime = layer.life
		t.MinLength = 0.1
		t.LightEmission = 0.6
		t.FaceCamera = true
		t.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, if i == 1 then 0.1 else 0.35), NumberSequenceKeypoint.new(1, 1) })
		t.Color = if item.id == "trailp_rainbow" then RAINBOW else ColorSequence.new(item.color)
		t.Parent = base
	end
	if item.id == "trail_spark" or item.id == "trail_ember" then
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(item.color)
		e.Size = NumberSequence.new(0.35, 0)
		e.Lifetime = NumberRange.new(0.4, 0.7)
		e.Rate = 18
		e.Speed = NumberRange.new(0.5, 2)
		e.LightEmission = 0.8
		e.Acceleration = if item.id == "trail_ember" then Vector3.new(0, 4, 0) else Vector3.new(0, -2, 0)
		e.Parent = a1
	end
end

local function caseOn(egg: Model, item: any)
	local cf, size = egg:GetBoundingBox()
	local base = egg.PrimaryPart :: BasePart
	local shell = Instance.new("Part")
	shell.Name = "Case"
	shell.Size = size + Vector3.new(0.35, 0.35, 0.35)
	shell.CFrame = cf
	shell.Material = Enum.Material.Glass
	shell.Color = item.color
	shell.Transparency = 0.45
	shell.CanCollide = false
	shell.CanQuery = false
	shell.CanTouch = false
	shell.Massless = true
	shell.CastShadow = false
	shell:SetAttribute("EOS_Egg", true)
	local w = Instance.new("WeldConstraint")
	w.Part0 = base
	w.Part1 = shell
	w.Parent = shell
	shell.Parent = egg
end

-- CharacterService calls this every time it builds a carried egg
local function decorateEgg(plr: Player, egg: Model)
	local p = DataService.get(plr)
	local base = egg.PrimaryPart
	if not p or not base then
		return
	end
	local case = EconomyConfig.item(p.cosmetics.case)
	if case and p.cosmetics.owned[case.id] then
		caseOn(egg, case)
	end
	local trail = matchTrail[plr] and EconomyConfig.item(matchTrail[plr] :: string)
	if trail and inMatch(plr) then
		trailOn(base, trail)
	end
end

-- lobby arrival: Bolt Entrance (permanent)
local function bolt(root: BasePart)
	local folder = Instance.new("Folder")
	folder.Name = "EOS_Bolt"
	local top = root.Position + Vector3.new(0, 60, 0)
	local pts = { top }
	for i = 1, 5 do
		local t = i / 6
		table.insert(pts, top:Lerp(root.Position, t) + Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3)))
	end
	table.insert(pts, root.Position - Vector3.new(0, 2.5, 0))
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local seg = Instance.new("Part")
		seg.Anchored = true
		seg.CanCollide = false
		seg.CanQuery = false
		seg.CanTouch = false
		seg.Material = Enum.Material.Neon
		seg.Color = Color3.fromRGB(170, 215, 255)
		seg.Size = Vector3.new(0.5, 0.5, (b - a).Magnitude)
		seg.CFrame = CFrame.lookAt((a + b) / 2, b)
		seg.Parent = folder
	end
	local flash = Instance.new("PointLight")
	flash.Brightness = 8
	flash.Range = 24
	flash.Color = Color3.fromRGB(170, 215, 255)
	flash.Parent = root
	folder.Parent = workspace
	task.delay(0.35, function()
		folder:Destroy()
		flash:Destroy()
	end)
end

function EconomyService.init()
	Net.event("RequestHatch").OnServerEvent:Connect(onHatch)
	Net.event("RequestEquipPet").OnServerEvent:Connect(onEquip)
	Net.event("RequestBuy").OnServerEvent:Connect(onBuy)
	Net.event("RequestUseItem").OnServerEvent:Connect(onUse)
	Net.event("RequestSetCosmetic").OnServerEvent:Connect(onSetCosmetic)
	CharacterService.onEggBuilt(decorateEgg)
	require(script.Parent.EggService).init({ tryUpdate = tryUpdate, toast = toast }) -- HOS-EGG-002: incubator remotes, egg watch
	MatchService.onPlayerMatchStart(EconomyService.startMatch)
	MatchService.onPlayerMatchEnd(EconomyService.endMatch)
	local function hook(plr: Player)
		plr.CharacterAdded:Connect(function(char)
			task.delay(1, function()
				local p = DataService.get(plr)
				local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if p and root and p.cosmetics.owned.entrance_bolt and not inMatch(plr) and char.Parent then
					bolt(root)
				end
			end)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, plr in ipairs(Players:GetPlayers()) do
		hook(plr)
	end
	Players.PlayerRemoving:Connect(function(plr)
		matchTrail[plr] = nil
	end)
end

return EconomyService
