--!strict
-- PracticeService: the low-population fallback (GDD 5). A fenced practice field in the lobby with
-- two pads and a slow practice Catcher bot. Crossing pad-to-pad and getting tagged give feedback
-- only: NO Shells, eggs, wins or quest progress ever come from practice.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Layout = require(Shared:WaitForChild("Layout"))
local Net = require(Shared:WaitForChild("Net"))
local CharacterService = require(script.Parent.CharacterService)

local PracticeService = {}

local P = GameConfig.Practice
local bots: { Model } = {}
local lastPad: { [Player]: string } = {}
local tagCooldown: { [Player]: number } = {}

local function runtimeFolder(): Folder
	local f = workspace:FindFirstChild("EOS_Runtime")
	if not f then
		f = Instance.new("Folder")
		f.Name = "EOS_Runtime"
		f.Parent = workspace
	end
	return f :: Folder
end

local function makeBot(index: number): Model?
	local desc = Instance.new("HumanoidDescription")
	local red = Color3.fromRGB(230, 70, 70)
	desc.HeadColor = Color3.fromRGB(255, 205, 160)
	desc.TorsoColor = red
	desc.LeftArmColor = red
	desc.RightArmColor = red
	desc.LeftLegColor = Color3.fromRGB(60, 60, 80)
	desc.RightLegColor = Color3.fromRGB(60, 60, 80)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[EOS] practice bot could not be created: " .. tostring(model))
		return nil
	end
	model.Name = "PracticeCatcher" .. index
	local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.WalkSpeed = P.BOT_SPEED
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CollisionGroup = CharacterService.GROUPS.BOT
		end
	end
	local hl = Instance.new("Highlight")
	hl.FillColor = Color3.fromRGB(255, 72, 72)
	hl.FillTransparency = 0.78
	hl.OutlineColor = Color3.fromRGB(255, 72, 72)
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = model
	local head = model:FindFirstChild("Head") :: BasePart
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(8, 0, 1.2, 0)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	bb.MaxDistance = 120
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)
	t.TextScaled = true
	t.Text = "PRACTICE CATCHER"
	t.TextColor3 = Color3.fromRGB(255, 120, 120)
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(7, 10, 14)
	st.Thickness = 2
	st.Parent = t
	t.Parent = bb
	bb.Parent = head
	model:PivotTo(CFrame.new(Layout.Practice.bounds.center + Vector3.new(0, 0, (index - 1) * 6)))
	model.Parent = runtimeFolder()
	local hrp = model:FindFirstChild("HumanoidRootPart") :: BasePart
	hrp:SetNetworkOwner(nil)
	return model
end

local function clampToField(pos: Vector3): Vector3
	local b = Layout.Practice.bounds
	local half = b.size / 2
	local padDepth = Layout.Practice.padA.size.X
	local x = math.clamp(pos.X, b.center.X - half.X + padDepth + 1, b.center.X + half.X - padDepth - 1)
	local z = math.clamp(pos.Z, b.center.Z - half.Z + 2, b.center.Z + half.Z - 2)
	return Vector3.new(x, Layout.GROUND_Y, z)
end

local function practicePlayers(): { { plr: Player, pos: Vector3 } }
	local out = {}
	if not Layout.Practice.enabled then
		-- practice field removed from the lobby: nobody is ever in practice
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr:GetAttribute("EOS_InPractice") then
				plr:SetAttribute("EOS_InPractice", nil)
			end
		end
		return out
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr:GetAttribute("EOS_Role") == "LOBBY" then
			local pos = CharacterService.rootPosition(plr)
			if pos and Layout.inBox(pos, Layout.Practice.bounds) then
				table.insert(out, { plr = plr, pos = pos })
				if not plr:GetAttribute("EOS_InPractice") then
					plr:SetAttribute("EOS_InPractice", true)
				end
			elseif plr:GetAttribute("EOS_InPractice") then
				plr:SetAttribute("EOS_InPractice", nil)
				lastPad[plr] = nil
			end
		end
	end
	return out
end

local function step()
	local list = practicePlayers()
	-- pad crossings
	for _, e in ipairs(list) do
		local pad = if Layout.inBox(e.pos, Layout.Practice.padA) then "A" elseif Layout.inBox(e.pos, Layout.Practice.padB) then "B" else nil
		if pad then
			if lastPad[e.plr] and lastPad[e.plr] ~= pad then
				Net.event("PracticeEvent"):FireClient(e.plr, { kind = "crossed", pad = pad })
			end
			lastPad[e.plr] = pad
		end
	end
	for _, bot in ipairs(bots) do
		local hum = bot:FindFirstChildOfClass("Humanoid")
		local hrp = bot:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hum or not hrp or hum.Health <= 0 then
			continue
		end
		-- chase the nearest player who is out on the field (not on a pad)
		local best, target = math.huge, nil
		for _, e in ipairs(list) do
			if not Layout.inBox(e.pos, Layout.Practice.padA) and not Layout.inBox(e.pos, Layout.Practice.padB) then
				local d = (e.pos - hrp.Position).Magnitude
				if d < best then
					best, target = d, e
				end
			end
		end
		if target then
			hum:MoveTo(clampToField(target.pos))
			if best <= P.BOT_TAG_RADIUS and os.clock() > (tagCooldown[target.plr] or 0) then
				tagCooldown[target.plr] = os.clock() + 1.5
				local back = lastPad[target.plr] or "A"
				local box = if back == "A" then Layout.Practice.padA else Layout.Practice.padB
				CharacterService.teleport(target.plr, Vector3.new(box.center.X, Layout.GROUND_Y + 1, box.center.Z), Layout.Practice.bounds.center)
				Net.event("PracticeEvent"):FireClient(target.plr, { kind = "tagged" })
			end
		else
			hum:MoveTo(clampToField(Layout.Practice.bounds.center))
		end
		-- keep the bot inside the field no matter what
		if not Layout.inBox(hrp.Position, { center = Layout.Practice.bounds.center, size = Layout.Practice.bounds.size + Vector3.new(6, 20, 6) }) then
			bot:PivotTo(CFrame.new(Layout.Practice.bounds.center + Vector3.new(0, 3, 0)))
		end
	end
end

function PracticeService.init()
	if not GameConfig.Features.PRACTICE_BOT or not Layout.Practice.enabled then
		return -- no practice field in the lobby right now: no practice bots
	end
	task.spawn(function()
		for i = 1, P.BOT_COUNT do
			local b = makeBot(i)
			if b then
				table.insert(bots, b)
			end
		end
		while true do
			local ok, err = pcall(step)
			if not ok then
				warn("[EOS] practice step failed: " .. tostring(err))
			end
			-- respawn dead/missing bots
			for i, b in ipairs(bots) do
				local hum = b:FindFirstChildOfClass("Humanoid")
				if not b.Parent or not hum or hum.Health <= 0 then
					b:Destroy()
					local nb = makeBot(i)
					if nb then
						bots[i] = nb
					end
				end
			end
			task.wait(P.BOT_RETARGET)
		end
	end)
	Players.PlayerRemoving:Connect(function(plr)
		lastPad[plr] = nil
		tagCooldown[plr] = nil
	end)
end

return PracticeService
