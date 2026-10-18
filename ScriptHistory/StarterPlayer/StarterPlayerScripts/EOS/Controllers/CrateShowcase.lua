--!nonstrict
-- CrateShowcase (HOS-INV-001, Hunter 18 Oct: "Is there any visual indication when a player is opening a chest" ->
-- "Both"). Other players see crate openings, the strongest nudge to open one yourself:
--   * over the opener's head: a glowing crate pops in and shakes harder and harder, then bursts in the rarity's
--     colour with the rarity word and the prize's name (everyone nearby, the opener too)
--   * Epic and Legendary pulls also post one line in chat for the whole server: "X pulled a LEGENDARY Spirit Blast!"
-- The server sets the player attribute EOS_CrateOpen = "kind|rarity|name|stamp" when a crate opens
-- (Services.WeaponCrateService, Services.EmoteService: one line each); this draws it.
--
--   ClientMain: task.spawn(require(Controllers.CrateShowcase).init)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local CrateShowcase = {}

local player = Players.LocalPlayer
local SHAKE_FOR = 3.2 -- seconds of suspense before the burst (the opener's own reel lands about then)
local HOLD = 2.6 -- seconds the result stays up
local RARITY = {
	common = { "COMMON", Color3.fromRGB(190, 198, 206) },
	rare = { "RARE", Color3.fromRGB(47, 168, 255) },
	epic = { "EPIC", Color3.fromRGB(180, 77, 255) },
	legendary = { "LEGENDARY", Color3.fromRGB(255, 194, 28) },
	crowned = { "LEGENDARY", Color3.fromRGB(255, 194, 28) },
}
local SHOUT = { epic = true, legendary = true, crowned = true }

local icons: any = nil
local function icon(slug: string): string
	if not icons then
		local gui = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("EOSUI")
		local m = gui and gui:FindFirstChild("AssetIds")
		local ok, a = pcall(function()
			return m and require(m)
		end)
		icons = if ok and a then a.icons or {} else {}
	end
	return icons[slug] or ""
end

-- the crate picture: the Weapon Crate's own art, the gift for the Emote Crate
local function crateImage(kind: string): string
	if kind == "weapon" then
		local t = ReplicatedStorage:FindFirstChild("WeaponUITemplates")
		local art = t and t:FindFirstChild("CrateArt", true)
		if art and art:IsA("ImageLabel") and art.Image ~= "" then
			return art.Image
		end
	end
	return icon("gift")
end

local function label(parent: Instance, text: string, color: Color3, y: number, size: number): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(0.5, y)
	l.Size = UDim2.fromScale(1.6, size)
	l.Font = Enum.Font.FredokaOne
	l.Text = text
	l.TextColor3 = color
	l.TextScaled = true
	l.TextTransparency = 1
	l.ZIndex = 5
	local s = Instance.new("UIStroke")
	s.Thickness = 2.5
	s.Transparency = 1
	s.Parent = l
	l.Parent = parent
	return l
end

local function fadeText(l: TextLabel, to: number, t: number)
	TweenService:Create(l, TweenInfo.new(t), { TextTransparency = to }):Play()
	local s = l:FindFirstChildOfClass("UIStroke")
	if s then
		TweenService:Create(s, TweenInfo.new(t), { Transparency = to }):Play()
	end
end

local function overhead(plr: Player, kind: string, rarity: string, name: string)
	local char = plr.Character
	local head = char and char:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local old = head:FindFirstChild("EOS_CrateShow")
	if old then
		old:Destroy()
	end
	local r = RARITY[rarity] or RARITY.common
	local bb = Instance.new("BillboardGui")
	bb.Name = "EOS_CrateShow"
	bb.Size = UDim2.fromScale(3, 3) -- small and subtle (Hunter 18 Oct)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 6.2, 0) -- above the name tag
	bb.MaxDistance = 110
	bb.LightInfluence = 0
	bb.ResetOnSpawn = false
	bb.Adornee = head
	local stage = Instance.new("Frame")
	stage.BackgroundTransparency = 1
	stage.Size = UDim2.fromScale(1, 1)
	stage.Parent = bb
	-- soft glow behind the crate
	local glow = Instance.new("Frame")
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(0.7, 0.7)
	glow.BackgroundColor3 = Color3.fromRGB(255, 236, 170)
	glow.BackgroundTransparency = 0.55
	glow.ZIndex = 1
	local gc = Instance.new("UICorner")
	gc.CornerRadius = UDim.new(0.5, 0)
	gc.Parent = glow
	glow.Parent = stage
	local crate = Instance.new("ImageLabel")
	crate.BackgroundTransparency = 1
	crate.AnchorPoint = Vector2.new(0.5, 0.5)
	crate.Position = UDim2.fromScale(0.5, 0.5)
	crate.Size = UDim2.fromScale(0.1, 0.1)
	crate.Image = crateImage(kind)
	crate.ZIndex = 3
	crate.Parent = stage
	-- the spin: a small reel under the crate flicks through the rarities, slowing down, and lands on the pull
	local pill = Instance.new("TextLabel")
	pill.AnchorPoint = Vector2.new(0.5, 0.5)
	pill.Position = UDim2.fromScale(0.5, 0.8)
	pill.Size = UDim2.fromScale(0.95, 0.2)
	pill.Font = Enum.Font.FredokaOne
	pill.TextScaled = true
	pill.TextColor3 = Color3.new(1, 1, 1)
	pill.BackgroundTransparency = 0.1
	pill.ZIndex = 4
	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0.5, 0)
	pc.Parent = pill
	local ps = Instance.new("UIStroke")
	ps.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ps.Color = Color3.fromRGB(10, 8, 18)
	ps.Thickness = 2
	ps.Parent = pill
	local pt = Instance.new("UIPadding")
	pt.PaddingTop = UDim.new(0.12, 0)
	pt.PaddingBottom = UDim.new(0.12, 0)
	pt.Parent = pill
	pill.Parent = stage
	bb.Parent = head
	TweenService:Create(crate, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Size = UDim2.fromScale(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4) }):Play()
	glow.Position = UDim2.fromScale(0.5, 0.4)
	local ORDER = { "common", "rare", "epic", "legendary" }
	local function show(key: string)
		local rr = RARITY[key] or RARITY.common
		pill.Text = rr[1]
		pill.BackgroundColor3 = rr[2]:Lerp(Color3.new(0, 0, 0), 0.25)
	end
	task.spawn(function()
		local t0 = os.clock()
		local k = math.random(1, #ORDER)
		while bb.Parent and os.clock() - t0 < SHAKE_FOR - 0.05 do
			k = k % #ORDER + 1
			show(ORDER[k])
			local p = (os.clock() - t0) / SHAKE_FOR
			task.wait(0.06 + 0.32 * p * p) -- fast, then slowing like a reel
		end
		if bb.Parent then
			show(if rarity == "crowned" then "legendary" else rarity)
		end
	end)
	-- the crate bobs gently while it spins
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not bb.Parent or os.clock() - t0 > SHAKE_FOR then
			conn:Disconnect()
			return
		end
		local t = os.clock() - t0
		crate.Rotation = math.sin(t * 6) * 6
		glow.BackgroundTransparency = 0.6 + 0.1 * math.sin(t * 8)
	end)
	task.delay(SHAKE_FOR, function()
		if not bb.Parent then
			return
		end
		-- the burst: the crate pops away, a ring of the rarity's colour spreads, sparkles fly, the result reads
		TweenService:Create(crate, TweenInfo.new(0.25), { Size = UDim2.fromScale(1, 1), ImageTransparency = 1 }):Play()
		glow.BackgroundColor3 = r[2]
		TweenService:Create(glow, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(1.5, 1.5), BackgroundTransparency = 1 }):Play()
		local ring = Instance.new("Frame")
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.fromScale(0.5, 0.5)
		ring.Size = UDim2.fromScale(0.3, 0.3)
		ring.BackgroundTransparency = 1
		ring.ZIndex = 2
		local rc = Instance.new("UICorner")
		rc.CornerRadius = UDim.new(0.5, 0)
		rc.Parent = ring
		local rs = Instance.new("UIStroke")
		rs.Color = r[2]
		rs.Thickness = 6
		rs.Parent = ring
		ring.Parent = stage
		TweenService:Create(ring, TweenInfo.new(0.7, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(1.6, 1.6) }):Play()
		TweenService:Create(rs, TweenInfo.new(0.7, Enum.EasingStyle.Quad), { Transparency = 1, Thickness = 1 }):Play()
		for i = 1, 8 do
			local sp = Instance.new("ImageLabel")
			sp.BackgroundTransparency = 1
			sp.AnchorPoint = Vector2.new(0.5, 0.5)
			sp.Image = icon("sparkle")
			sp.ImageColor3 = r[2]
			sp.Position = UDim2.fromScale(0.5, 0.5)
			sp.Size = UDim2.fromScale(0.16, 0.16)
			sp.ZIndex = 4
			sp.Parent = stage
			local a = (i / 8) * math.pi * 2
			TweenService:Create(sp, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { Position = UDim2.fromScale(0.5 + math.cos(a) * 0.55, 0.5 + math.sin(a) * 0.55), ImageTransparency = 1, Rotation = 120 }):Play()
		end
		-- the reel pill already reads the rarity: the prize's name takes the crate's place
		local prize = label(stage, name, r[2]:Lerp(Color3.new(1, 1, 1), 0.35), 0.45, 0.2)
		fadeText(prize, 0, 0.3)
		task.delay(HOLD, function()
			fadeText(prize, 1, 0.4)
			TweenService:Create(pill, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
			task.delay(0.45, function()
				bb:Destroy()
			end)
		end)
	end)
end

-- one chat line for the whole server on Epic and Legendary pulls (after the burst, so it never spoils a reel)
local function shout(plr: Player, kind: string, rarity: string, name: string)
	if not SHOUT[rarity] then
		return
	end
	local r = RARITY[rarity] or RARITY.common
	task.delay(SHAKE_FOR + 0.2, function()
		local ch = TextChatService:FindFirstChild("TextChannels")
		local general = ch and ch:FindFirstChild("RBXGeneral")
		if not (general and general:IsA("TextChannel")) then
			return
		end
		local hex = r[2]:ToHex()
		local function esc(x: string): string
			return (x:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
		end
		local who = if plr == player then "You" else esc(plr.DisplayName)
		name = esc(name)
		local text = ('<font color="#ffe14a"><b>%s</b></font> pulled a <font color="#%s"><b>%s %s</b></font> from the %s!'):format(
			who, hex, r[1], name, if kind == "weapon" then "Weapon Crate" else "Emote Crate")
		pcall(function()
			general:DisplaySystemMessage(text)
		end)
	end)
end

local function watch(plr: Player)
	plr:GetAttributeChangedSignal("EOS_CrateOpen"):Connect(function()
		local v = plr:GetAttribute("EOS_CrateOpen")
		if type(v) ~= "string" then
			return
		end
		local kind, rarity, name = v:match("^([^|]*)|([^|]*)|([^|]*)|")
		if not kind then
			return
		end
		if plr ~= player or workspace:GetAttribute("EOS_CrateShowSelf") then -- the opener has their own reel (Studio test switch: workspace EOS_CrateShowSelf)
			pcall(overhead, plr, kind, rarity, name)
		end
		shout(plr, kind, rarity, name)
	end)
end

function CrateShowcase.init()
	for _, plr in Players:GetPlayers() do
		watch(plr)
	end
	Players.PlayerAdded:Connect(watch)
end

return CrateShowcase
