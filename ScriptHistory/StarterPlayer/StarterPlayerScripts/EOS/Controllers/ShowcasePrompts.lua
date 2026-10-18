--!strict
-- ShowcasePrompts (client), HOS-SHOW-001 (Matthew, 18 Oct): "Make sure all of these have walk up pop up GUI that takes
-- them to that part of the shop. each one should then have a hold E to pop up if they close out of the shop but are
-- still standing"; then "Now do the same thing for the 2 crates. Just have one button called Buy and it takes you to the
-- page in the shop".
--  * The lobby showcase podiums, by tag: the sword (HOS_WeaponShowcase) and the Halloween pets (HOS_PetShowcase) open
--    the Shop on Featured, the emote hologram (HOS_EmoteShowcase) on Emotes. The two lobby crates
--    (Workspace.LobbyCrates.Crate_<id>, CrateId attribute) open it on Weapons, where both crates are sold.
--  * Walk up (within OPEN_AT of the podium's stand / the crate's glow) and the Shop opens on that tab, once. Walk away
--    (past CLOSE_AT) and it closes again if the walk opened it, and the walk-up is armed for next time (the spin
--    wheel's rule).
--  * Close the Shop while still standing there and an E prompt (a tap, no hold) opens it again: "View in Shop" on the
--    podiums, "Buy" on the crates. It sits low at the front, toward the middle of the lobby, clear of what's on show;
--    it only shows while the Shop is shut, and never in a match.
--  * Nothing goes to the server: the Shop is a client screen (UIController.openShopTab).
--   ShowcasePrompts.start()   WeaponFXBoot, once

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local LobbyGate = require(script.Parent:WaitForChild("LobbyGate")) -- HOS-LOBBY-004
local UIC = require(script.Parent:WaitForChild("UIController")) :: any
local Sound = require(script.Parent:WaitForChild("Sound")) :: any

local ShowcasePrompts = {}

local OPEN_AT, CLOSE_AT = 8, 12 -- studs (flat) from the centre: open inside, re-arm / close outside (the spin wheel's
-- distances; the podium slabs are 9-11 studs across, so you open it at the podium's edge)
local PROMPT_RANGE = 10 -- studs the prompt reaches
local HOLD = 0 -- a tap of E opens it (Matthew: no hold)
-- the prompt sits low at the front edge (toward the middle of the lobby), clear of what's on show
-- (Matthew: "Bring the prompt down to the feet and by the front of the podium so it doesnt interfere with the clone")
local PLACE = {
	podium = { front = 4.6, up = -0.9 }, -- from the stand (about 1.9 up the podium)
	crate = { front = 3.0, up = -0.8 }, -- from the glow in the crate's mouth (the crates are 5 wide, 4.7 deep)
}
local TICK = 0.2 -- seconds between checks

-- tag -> the Shop tab it opens and the prompt's words
local SHOWCASES: { { tag: string, tab: string, action: string, object: string } } = {
	{ tag = "HOS_WeaponShowcase", tab = "featured", action = "View in Shop", object = "Weapons" }, -- (Matthew: the sword's on Featured)
	{ tag = "HOS_PetShowcase", tab = "featured", action = "View in Shop", object = "Halloween Pets" },
	{ tag = "HOS_EmoteShowcase", tab = "emotes", action = "View in Shop", object = "Emotes" },
}
local CRATE_TAB, CRATE_ACTION = "weapons", "Buy"

type Spot = {
	model: Model,
	kind: string, -- "podium" | "crate"
	tab: string,
	action: string,
	object: string,
	prompt: ProximityPrompt?,
	armed: boolean,
	openedByWalk: boolean,
}

local spots: { [Model]: Spot } = {}
local started = false
local player = Players.LocalPlayer

-- the sword podium's prompt names its skin (ShowcaseSkin), e.g. "All Hallow's Sword"
local function skinName(model: Model): string?
	local skin = model:GetAttribute("ShowcaseSkin")
	if type(skin) ~= "string" then
		return nil
	end
	for _, k in EconomyConfig.KNIFE_SKINS do
		if k[1] == skin then
			return k[2]
		end
	end
	return nil
end

-- the part the prompt hangs on: the podium's glow disc, the crate's glow
local function anchorOf(s: Spot): BasePart?
	local p = s.model:FindFirstChild(if s.kind == "crate" then "Loot_Glow" else "StandGlow")
	return if p and p:IsA("BasePart") then p else nil
end

-- where distances are measured from: the podium's stand, the crate's glow
local function centreOf(s: Spot): Vector3?
	local glow = anchorOf(s)
	if s.kind == "podium" and glow then
		local att = glow:FindFirstChild("RigStand")
		if att and att:IsA("Attachment") then
			return att.WorldPosition
		end
	end
	return if glow then glow.Position else nil
end

local function inMatch(): boolean
	return player:GetAttribute("EOS_InMatch") == true
end

local function shopOpen(): boolean
	local ok, open = pcall(function()
		return UIC.isOpen()
	end)
	return ok and open == true
end

local function canOpen(): boolean
	if inMatch() or player:GetAttribute("EOS_Loaded") ~= true or not LobbyGate.active() then
		return false
	end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return false
	end
	if shopOpen() then
		return false
	end
	local ok, watching = pcall(function()
		return UIC.spectating and UIC.spectating()
	end)
	return not (ok and watching)
end

local function openShop(s: Spot)
	local ok = pcall(function()
		UIC.openShopTab(s.tab)
	end)
	if ok then
		s.openedByWalk = true
		pcall(Sound.play, "open")
	end
end

-- the prompt, on its own attachment low at the front (made again if the model streamed back in)
local function ensurePrompt(s: Spot)
	if s.prompt and s.prompt.Parent and s.prompt:IsDescendantOf(workspace) then
		return
	end
	local anchor = anchorOf(s)
	local centre = centreOf(s)
	if not anchor or not centre then
		return
	end
	local old = anchor:FindFirstChild("HOS_ShowcasePrompt")
	if old then
		old:Destroy()
	end
	local place = PLACE[s.kind] or PLACE.podium
	local toMid = LobbyGate.centre() - centre
	toMid = Vector3.new(toMid.X, 0, toMid.Z)
	local front = if toMid.Magnitude > 0.1 then toMid.Unit * place.front else Vector3.zero
	local at = Instance.new("Attachment")
	at.Name = "HOS_ShowcasePrompt" -- (this client only)
	at.Parent = anchor
	at.WorldPosition = centre + front + Vector3.new(0, place.up, 0) -- (after parenting: before, it's taken as 0,0,0)
	local pp = Instance.new("ProximityPrompt")
	pp.Name = "ShowcaseShop"
	pp.ActionText = s.action
	pp.ObjectText = skinName(s.model) or s.object
	pp.KeyboardKeyCode = Enum.KeyCode.E
	pp.HoldDuration = HOLD
	pp.MaxActivationDistance = PROMPT_RANGE
	pp.RequiresLineOfSight = false
	pp.Enabled = false
	pp.Parent = at
	pp.Triggered:Connect(function()
		if canOpen() then
			openShop(s)
		end
	end)
	s.prompt = pp
end

local function addSpot(model: Model, kind: string, tab: string, action: string, object: string)
	if spots[model] then
		return
	end
	spots[model] = {
		model = model, kind = kind, tab = tab, action = action, object = object, prompt = nil, armed = true,
		openedByWalk = false,
	}
end

local function add(model: Instance, def: any)
	if model:IsA("Model") then
		addSpot(model, "podium", def.tab, def.action, def.object)
	end
end

local function addCrate(model: Instance)
	local id = model:GetAttribute("CrateId")
	local def = type(id) == "string" and EconomyConfig.KNIFE_CRATES and EconomyConfig.KNIFE_CRATES[id]
	if model:IsA("Model") and def then
		addSpot(model, "crate", CRATE_TAB, CRATE_ACTION, def.name)
	end
end

local function remove(model: Instance)
	local s = spots[model :: Model]
	if s then
		spots[model :: Model] = nil
		if s.prompt and s.prompt.Parent then
			s.prompt.Parent:Destroy()
		end
	end
end

local function tick()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local open = shopOpen()
	for model, s in spots do
		if not model.Parent then
			remove(model)
			continue
		end
		ensurePrompt(s)
		local centre = centreOf(s)
		local d = math.huge
		if centre and root and root:IsA("BasePart") then
			d = Vector3.new(root.Position.X - centre.X, 0, root.Position.Z - centre.Z).Magnitude
		end
		if s.openedByWalk and not open then
			s.openedByWalk = false -- (closed with X: the prompt takes over while you stay)
		end
		if d > CLOSE_AT then
			s.armed = true
			if s.openedByWalk and open and not inMatch() then
				pcall(function()
					if UIC.openName() == "Shop" then
						UIC.close()
					end
				end)
				s.openedByWalk = false
				open = false
			end
		elseif d < OPEN_AT and s.armed and canOpen() then
			s.armed = false
			openShop(s)
			open = true
		end
		if s.prompt then
			s.prompt.Enabled = not open and not inMatch() and LobbyGate.active()
		end
	end
end

function ShowcasePrompts.start()
	if started then
		return
	end
	started = true
	for _, def in SHOWCASES do
		CollectionService:GetInstanceAddedSignal(def.tag):Connect(function(m)
			add(m, def)
		end)
		CollectionService:GetInstanceRemovedSignal(def.tag):Connect(remove)
		for _, m in CollectionService:GetTagged(def.tag) do
			add(m, def)
		end
	end
	-- the lobby crates (their own prompts are gone from LobbyCrates: this Buy prompt replaces them)
	task.spawn(function()
		local folder = workspace:WaitForChild("LobbyCrates", math.huge)
		if not folder then
			return
		end
		for _, m in folder:GetChildren() do
			addCrate(m)
		end
		folder.ChildAdded:Connect(function(m)
			task.defer(addCrate, m)
		end)
	end)
	task.spawn(function()
		while true do
			local ok, err = pcall(tick)
			if not ok then
				warn("[ShowcasePrompts] " .. tostring(err))
			end
			task.wait(TICK)
		end
	end)
end

return ShowcasePrompts
