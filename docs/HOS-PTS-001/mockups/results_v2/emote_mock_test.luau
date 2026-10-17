-- HOS-PTS-001 emote podium MOCK (playtest client only; a throwaway ScreenGui, deleted afterwards).
-- A copy of the exported ResultsV2 card (sample data). Each podium card gets a ViewportFrame behind its name and stat:
-- a bot's own outfit (NpcSkins Skin<n>) playing an emote on loop, full body, slight 3/4 angle. #1's is bigger.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local pg = player.PlayerGui
local old = pg:FindFirstChild("EmoteMockUI")
if old then old:Destroy() end

local EmoteConfig = require(RS.EOS.Shared.EmoteConfig)
local function emote(id)
	for _, e in ipairs(EmoteConfig.LIST) do
		if e.id == id then return e end
	end
	return nil
end
local PICK = _G.EMOTE_PICK or { "loser_dance", "snappy_skip", "shuffle" } -- #1, #2, #3

local src = game.StarterGui.PointsUI
local sg = Instance.new("ScreenGui")
sg.Name = "EmoteMockUI"
sg.IgnoreGuiInset = src.IgnoreGuiInset
sg.ZIndexBehavior = src.ZIndexBehavior
sg.ResetOnSpawn = false
sg.DisplayOrder = 60
local root = src:FindFirstChild("Root"):Clone()
for _, d in ipairs(root:GetDescendants()) do
	if d:IsA("LuaSourceContainer") then d:Destroy() end
end
root.Parent = sg
-- fit like UI.fit: root = viewport / s, FitScale = s
local vp = workspace.CurrentCamera.ViewportSize
local s = math.min(vp.X / 1920, vp.Y / 1080)
root.Size = UDim2.fromOffset(vp.X / s, vp.Y / s)
local fs = root:FindFirstChild("FitScale")
if fs then fs.Scale = s end
local pts = root:FindFirstChild("Points")
pts.Visible = true
for _, g in ipairs(pts:GetChildren()) do
	if g:IsA("GuiObject") then g.Visible = (g.Name == "ResultsV2" or g.Name == "Dim") end
end
local g = pts.ResultsV2
-- only the POINTS stat on each card, JOINT hidden (the export carries every state)
for _, d in ipairs(g:GetDescendants()) do
	if d.Name == "StatSafe" or d.Name == "StatCatch" then d.Visible = false end
	if d.Name == "JointText" or d.Name == "JointTextShadow" then d.Visible = false end
	if d.Name == "ColGems" then d.Visible = true end
	if (d.Name == "Off" and d.Parent and d.Parent.Name == "TabPoints") or (d.Name == "On" and d.Parent and d.Parent.Name ~= "TabPoints" and d.Parent.Name:match("^Tab")) then
		d.Visible = false
	end
end
sg.Parent = pg

local skinsFolder = pg:FindFirstChild("EOS_FriendSkins")
local skins = {}
if skinsFolder then
	for i = 1, 12 do
		local m = skinsFolder:FindFirstChild("Skin" .. i)
		if m then table.insert(skins, m) end
	end
end

local tracks = {}
local function viewport(card: GuiObject, i: number)
	local W, H = card.Size.X.Offset, card.Size.Y.Offset
	local head = card:FindFirstChild("Head")
	if head then head.Visible = false end
	-- draw order: the card art at the back, the character over it, the words on top
	for _, c in ipairs(card:GetChildren()) do
		if c:IsA("GuiObject") then
			if c.Name == "Art" then c.ZIndex = 0 else c.ZIndex = math.max(c.ZIndex, 2) + 2 end
			for _, d in ipairs(c:GetDescendants()) do
				if d:IsA("GuiObject") and c.Name ~= "Art" then d.ZIndex = math.max(d.ZIndex, 2) + 2 end
			end
		end
	end
	local vf = Instance.new("ViewportFrame")
	vf.Name = "EmoteView"
	vf.BackgroundTransparency = 1
	vf.ZIndex = 1
	-- the card's width, from just under the top edge to the stat pill (name and tag overlap the shins)
	local top = 8
	local bottom = H - 52
	vf.Position = UDim2.fromOffset(6, top)
	vf.Size = UDim2.fromOffset(W - 12, bottom - top)
	vf.Ambient = Color3.fromRGB(170, 170, 180)
	vf.LightColor = Color3.new(1, 1, 1)
	vf.LightDirection = Vector3.new(-0.5, -1, -0.6)
	local wm = Instance.new("WorldModel")
	wm.Parent = vf
	vf.Parent = card
	local skin = skins[((i - 1) % math.max(1, #skins)) + 1]
	if not skin then return "no skin" end
	local m = skin:Clone()
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BaseScript") then d:Destroy() end
	end
	local hrp = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("Torso")
	m.PrimaryPart = hrp
	m:PivotTo(CFrame.new(0, 3, 0))
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then p.Anchored = (p == hrp) p.CanCollide = false end
	end
	m.Parent = wm
	-- accessories: put each handle on its body attachment (no physics in a viewport)
	for _, acc in ipairs(m:GetChildren()) do
		local handle = acc:IsA("Accessory") and acc:FindFirstChild("Handle")
		local a0 = handle and handle:FindFirstChildOfClass("Attachment")
		if handle and a0 then
			for _, part in ipairs(m:GetChildren()) do
				local a1 = part:IsA("BasePart") and part ~= handle and part:FindFirstChild(a0.Name)
				if a1 and a1:IsA("Attachment") then
					local w = Instance.new("WeldConstraint")
					handle.CFrame = a1.WorldCFrame * a0.CFrame:Inverse()
					w.Part0, w.Part1 = handle, part
					w.Parent = handle
					handle.Anchored = false
					break
				end
			end
		end
	end
	local hum = m:FindFirstChildOfClass("Humanoid")
	local e = emote(PICK[i]) or EmoteConfig.LIST[5 + i]
	if hum and e then
		local an = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
		local a = Instance.new("Animation")
		a.AnimationId = "rbxassetid://" .. e.animId
		local ok, tr = pcall(function() return an:LoadAnimation(a) end)
		if ok and tr then
			tr.Looped = true
			tr:Play()
			tr.TimePosition = 0.6 * (i - 1)
			table.insert(tracks, tr)
		end
	end
	-- camera: full body with room for arms up and kicks, slight 3/4 from the front
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.Parent = vf
	vf.CurrentCamera = cam
	local look = CFrame.new(0, 3, 0) * CFrame.Angles(0, math.rad(if i == 3 then -25 else 25), 0)
	local focus = Vector3.new(0, 2.6, 0)
	local aspect = vf.Size.X.Offset / vf.Size.Y.Offset
	local needH = 7.6 -- studs of height in frame (R6 is about 5; arms up and jumps need the rest)
	local dist = (needH / 2) / math.tan(math.rad(cam.FieldOfView / 2))
	if aspect < 0.75 then dist *= 0.75 / aspect end
	cam.CFrame = CFrame.lookAt(focus + look.LookVector * -1 * -dist, focus)
	-- the emote's name, a small chip in the corner (mock)
	local chip = Instance.new("TextLabel")
	chip.Name = "EmoteChip"
	chip.Text = "♪ " .. (e and e.name or "Emote")
	chip.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
	chip.TextColor3 = Color3.new(1, 1, 1)
	chip.TextSize = 16
	chip.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
	chip.BackgroundTransparency = 0.28
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.Size = UDim2.fromOffset(0, 26)
	chip.Position = UDim2.fromOffset(W - 12 - 8, 8)
	chip.AnchorPoint = Vector2.new(1, 0)
	chip.ZIndex = 9
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
	pad.Parent = chip
	Instance.new("UICorner", chip).CornerRadius = UDim.new(1, 0)
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(5, 5, 6)
	st.Thickness = 2
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = chip
	chip.Parent = card
	return (e and e.name or "?") .. " on " .. skin.Name
end

local out = { "skins " .. #skins }
for i = 1, 3 do
	local card = g:FindFirstChild("Place" .. i, true)
	if card then table.insert(out, viewport(card, i)) end
end
_G.EMOTE_MOCK_TRACKS = tracks
return table.concat(out, " | ")
