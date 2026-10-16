-- NpcSkins: dresses every NPC as one of YOUR friends, on your screen only.
-- The server sends this player (and nobody else) avatar models of their friends in
-- PlayerGui.EOS_FriendSkins as Skin1, Skin2, ... (NpcSkinService). Each NPC body carries a slot
-- number (attribute EOS_NpcSlot); slot n wears Skin<n>: a local copy of the avatar is welded limb
-- for limb onto the NPC's body (which is hidden locally), so it moves and animates with the
-- server's NPC for free. The NPC's overhead name shows the friend's name too.
-- Until a look arrives (or if you have no friends to show) an NPC keeps its plain shared look.
-- Other UI asks nameForSlot / userIdForSlot so feeds and results use the same friend.

local Players = game:GetService("Players")

local NpcSkins = {}

local player = Players.LocalPlayer
local LIMBS = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
local skins: Instance? = nil
local npcs: Instance? = nil
local hookedLabels: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

function NpcSkins.skinFor(slot: number?): Model?
	if not slot or not skins then
		return nil
	end
	return (skins :: Instance):FindFirstChild("Skin" .. slot) :: Model?
end

function NpcSkins.nameForSlot(slot: number?): string?
	local s = NpcSkins.skinFor(slot)
	local n = s and s:GetAttribute("FriendName")
	return if type(n) == "string" then n else nil
end

function NpcSkins.userIdForSlot(slot: number?): number?
	local s = NpcSkins.skinFor(slot)
	local id = s and s:GetAttribute("FriendUserId")
	return if type(id) == "number" then id else nil
end

-- the NPC body wearing this slot right now
function NpcSkins.modelForSlot(slot: number?): Model?
	if not slot or not npcs then
		return nil
	end
	for _, m in ipairs((npcs :: Instance):GetChildren()) do
		if m:IsA("Model") and m:GetAttribute("EOS_NpcSlot") == slot then
			return m
		end
	end
	return nil
end

local function applyName(npc: Model)
	local name = NpcSkins.nameForSlot(npc:GetAttribute("EOS_NpcSlot"))
	local head = npc:FindFirstChild("Head")
	local tag = head and head:FindFirstChild("EOS_Tag")
	local label = tag and tag:FindFirstChild("NameLabel")
	if not name or not label or not label:IsA("TextLabel") then
		return
	end
	if label.Text ~= name then
		label.Text = name
	end
	if not hookedLabels[label] then
		hookedLabels[label] = true
		-- the server rewrites the tag when roles change: put the friend's name straight back
		label:GetPropertyChangedSignal("Text"):Connect(function()
			local n = NpcSkins.nameForSlot(npc:GetAttribute("EOS_NpcSlot"))
			if n and label.Text ~= n then
				label.Text = n
			end
		end)
	end
end

local function dress(npc: Model)
	local skin = NpcSkins.skinFor(npc:GetAttribute("EOS_NpcSlot"))
	if not skin then
		return
	end
	local current = npc:FindFirstChild("EOS_Skin")
	if current and current:GetAttribute("FriendUserId") == skin:GetAttribute("FriendUserId") then
		return
	end
	for _, name in ipairs(LIMBS) do
		if not npc:FindFirstChild(name) then
			return -- body still streaming in; ChildAdded will try again
		end
	end
	if current then
		current:Destroy()
	end
	local look = skin:Clone()
	look.Name = "EOS_Skin"
	local hrp = look:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp:Destroy()
	end
	for _, d in ipairs(look:GetDescendants()) do
		if d:IsA("Motor6D") or d:IsA("BaseScript") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false -- (its Humanoid switches the Torso back on: the group is what really stops it)
			d.CollisionGroup = "EOS_Skin" -- collides with nothing (CharacterService.setupCollisionGroups)
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		end
	end
	local hum = look:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		hum.RequiresNeck = false
		hum.BreakJointsOnDeath = false
		pcall(function()
			hum.EvaluateStateMachine = false -- appearance only (clothing needs a Humanoid in the model)
		end)
	end
	for _, name in ipairs(LIMBS) do
		local mine = npc:FindFirstChild(name) :: BasePart
		local theirs = look:FindFirstChild(name) :: BasePart?
		if theirs then
			theirs.CFrame = mine.CFrame
			local w = Instance.new("Weld")
			w.Part0 = mine
			w.Part1 = theirs
			w.Parent = theirs
		end
		-- hide the shared plain body (this client only)
		mine.LocalTransparencyModifier = 1
		for _, d in ipairs(mine:GetChildren()) do
			if d:IsA("Decal") then
				d.LocalTransparencyModifier = 1
			end
		end
	end
	look.Parent = npc
	applyName(npc)
end

local function watch(npc: Instance)
	if not npc:IsA("Model") then
		return
	end
	npc.ChildAdded:Connect(function(c)
		if table.find(LIMBS, c.Name) then
			dress(npc)
		end
	end)
	npc.DescendantAdded:Connect(function(d)
		if d.Name == "NameLabel" then
			task.defer(applyName, npc)
		end
	end)
	npc:GetAttributeChangedSignal("EOS_NpcSlot"):Connect(function()
		dress(npc)
	end)
	dress(npc)
	applyName(npc)
end

local function dressAll()
	if not npcs then
		return
	end
	for _, m in ipairs((npcs :: Instance):GetChildren()) do
		if m:IsA("Model") then
			dress(m)
		end
	end
end

function NpcSkins.init()
	task.spawn(function()
		local pg = player:WaitForChild("PlayerGui")
		local folder = pg:FindFirstChild("EOS_FriendSkins")
		while not folder do
			task.wait(1) -- arrives once the server has built your first friend look
			folder = pg:FindFirstChild("EOS_FriendSkins")
		end
		skins = folder
		folder.ChildAdded:Connect(function()
			task.defer(dressAll)
		end)
		dressAll()
	end)
	task.spawn(function()
		local runtime = workspace:FindFirstChild("EOS_Runtime")
		local folder = runtime and runtime:FindFirstChild("Npcs")
		while not folder do
			task.wait(1) -- created when the first NPC appears
			runtime = workspace:FindFirstChild("EOS_Runtime")
			folder = runtime and runtime:FindFirstChild("Npcs")
		end
		npcs = folder
		folder.ChildAdded:Connect(watch)
		for _, m in ipairs(folder:GetChildren()) do
			watch(m)
		end
	end)
end

return NpcSkins
