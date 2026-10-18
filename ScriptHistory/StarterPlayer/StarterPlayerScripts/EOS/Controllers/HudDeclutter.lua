--!nonstrict
-- HudDeclutter (HOS-INV-001 clutter pass, Hunter 18 Oct "Do all"): fewer things on screen, changed on the PlayerGui
-- copy of EOSUI at runtime (like TopbarHover); StarterGui.EOSUI is not edited. Audit: docs/HOS-INV-001/README.md.
--
--   ClientMain: task.spawn(require(Controllers.HudDeclutter).init)   (after UIController.init and TopbarHover)
--
-- * MENU (2): the top right shows one square, SettingsButton relabelled MENU. Clicking it drops a short list of
--   Servers, Stats and Settings pills (copies of the exported pills from StarterGui.EOSUI) under it; a pick opens
--   that panel through UIController. ServersButton and StatsButton are hidden (TopbarHover only lays out MENU).
-- * Wallet (2): Gold and Gems share one plate, side by side, under the Level plate: three plates become two.
-- * Dash hints (3): after your first 3 finished matches the dash state and hint lines under SPACE · DASH hide.
-- * Clean streak (5, 10): the CLEAN STREAK row shows from your first clean crossing, not at 0 (the round header
--   is 3 lines until then, phones included).
-- Items 6 to 9 are small edits in their own scripts (UIController feed numbers, EggUIController card), and the
-- Lead Catcher Taken card (7) already left the match HUD in HOS-MAPVOTE-002.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local UIC = require(script.Parent.UIController)

local HudDeclutter = {}

local player = Players.LocalPlayer
local DASH_HINT_MATCHES = 3 -- finished matches before the dash hint lines go
local MENU_ITEMS = { { "ServersButton", "Servers" }, { "StatsButton", "Stats" }, { "SettingsButton", "Settings" } }

local root: Instance? = nil
local profile: any = nil

local function find(scope: Instance?, name: string): Instance?
	return scope and scope:FindFirstChild(name, true)
end

local function setLabels(scope: Instance?, text: string, only: string?)
	if not scope then
		return
	end
	for _, d in scope:GetDescendants() do
		if d:IsA("TextLabel") and (not only or d.Name == only or d.Name == only .. "Shadow") then
			d.Text = text
		end
	end
end

-- keep a GuiObject hidden while want() says so, whoever else shows it
local function holdHidden(g: GuiObject, want: () -> boolean)
	local busy = false
	local function apply()
		if busy then
			return
		end
		if want() and g.Visible then
			busy = true
			g.Visible = false
			busy = false
		end
	end
	g:GetPropertyChangedSignal("Visible"):Connect(apply)
	apply()
	return apply
end

-- ===== 2. MENU square + drop-down

local function buildMenu()
	local hud = root and root:FindFirstChild("HUD")
	local tr = hud and hud:FindFirstChild("TopRight")
	local settings = tr and tr:FindFirstChild("SettingsButton")
	local srcTr = StarterGui:FindFirstChild("EOSUI") and StarterGui.EOSUI:FindFirstChild("Root")
	srcTr = srcTr and srcTr:FindFirstChild("HUD") and srcTr.HUD:FindFirstChild("TopRight")
	if not (tr and settings and settings:IsA("GuiButton") and srcTr) then
		warn("[HudDeclutter] top bar not as exported: MENU left as it is")
		return
	end
	for _, n in { "ServersButton", "StatsButton" } do
		local b = tr:FindFirstChild(n)
		if b and b:IsA("GuiObject") then
			holdHidden(b, function()
				return true
			end)
		end
	end
	setLabels(settings, "MENU", "Label")
	settings:SetAttribute("OpensVia", nil) -- UIController's generic Opens wiring does nothing now; the list opens instead
	-- the list: full pills under the square, right-aligned, one per row
	local drop = Instance.new("Frame")
	drop.Name = "MenuDrop"
	drop.BackgroundTransparency = 1
	drop.AnchorPoint = Vector2.new(1, 0)
	drop.Position = UDim2.new(1, 0, 0, 84)
	drop.Size = UDim2.fromOffset(260, #MENU_ITEMS * 82)
	drop.Visible = false
	drop.ZIndex = 30
	drop.Parent = tr
	for i, it in MENU_ITEMS do
		local src = srcTr:FindFirstChild(it[1])
		if src and src:IsA("GuiButton") then
			local b = src:Clone()
			b.Name = "Menu" .. it[2]
			for _, a in { "Opens", "OpensVia", "JuiceRest" } do
				b:SetAttribute(a, nil)
			end
			b.AnchorPoint = Vector2.new(1, 0)
			b.Position = UDim2.new(1, 0, 0, (i - 1) * 82)
			b.Parent = drop
			UIC.juicy(b, function()
				drop.Visible = false
				UIC.open(it[2])
			end)
			for _, c in b:GetDescendants() do
				if c:IsA("GuiButton") then
					c.Activated:Connect(function()
						drop.Visible = false
						UIC.open(it[2])
					end)
				end
			end
		end
	end
	local function toggle()
		drop.Visible = not drop.Visible
	end
	settings.Activated:Connect(toggle)
	for _, c in settings:GetDescendants() do
		if c:IsA("GuiButton") then
			c.Activated:Connect(toggle)
		end
	end
	-- a click anywhere else, or any panel opening, closes the list
	UserInputService.InputEnded:Connect(function(input)
		if not drop.Visible then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		task.defer(function()
			local p = Vector2.new(input.Position.X, input.Position.Y)
			local sg = drop:FindFirstAncestorOfClass("ScreenGui")
			if sg and sg.IgnoreGuiInset then -- input positions skip the top bar inset; this gui's AbsolutePositions don't
				p += game:GetService("GuiService"):GetGuiInset()
			end
			local function inside(g: GuiObject): boolean
				local a, s = g.AbsolutePosition, g.AbsoluteSize
				return p.X >= a.X and p.X <= a.X + s.X and p.Y >= a.Y and p.Y <= a.Y + s.Y
			end
			if not inside(drop) and not inside(settings) then
				drop.Visible = false
			end
		end)
	end)
	task.spawn(function()
		while drop.Parent do
			if drop.Visible and UIC.isOpen() then
				drop.Visible = false
			end
			task.wait(0.25)
		end
	end)
end

-- ===== 2. wallet: Gold + Gems on one plate

local function mergeWallet()
	local hud = root and root:FindFirstChild("HUD")
	local w = hud and hud:FindFirstChild("Wallet")
	if not w then
		return
	end
	local plates, shadows = {}, {}
	for _, c in w:GetChildren() do
		if c.Name == "Glass" then
			table.insert(plates, c)
		elseif c.Name == "DropShadow" then
			table.insert(shadows, c)
		end
	end
	local byY = function(a, b)
		return a.Position.Y.Offset < b.Position.Y.Offset
	end
	table.sort(plates, byY)
	table.sort(shadows, byY)
	if #plates < 2 or not w:FindFirstChild("GemsText") or not w:FindFirstChild("GoldText") then
		warn("[HudDeclutter] wallet not as exported: left as it is")
		return
	end
	-- Gold left half, Gems right half of the first plate (y 94..178); the Gems plate goes
	local top = plates[1].Position.Y.Offset
	plates[2].Visible = false
	if shadows[2] then
		shadows[2].Visible = false
	end
	local function put(name: string, x: number, y: number, wdt: number?, hgt: number?)
		for k, n in { name, name .. "Shadow" } do
			local g = w:FindFirstChild(n)
			if g and g:IsA("GuiObject") then
				local off = if k == 2 then 3 else 0
				g.Position = UDim2.fromOffset(x, top + y + off)
				if wdt and hgt then
					g.Size = UDim2.fromOffset(wdt, hgt)
				end
				if g:IsA("TextLabel") and (name == "GoldText" or name == "GemsText") then
					-- shrink to fit the half plate as the number grows (TextScaled would wrap "12,345")
					local l = g :: TextLabel
					local old = l:FindFirstChildOfClass("UITextSizeConstraint")
					if old then
						old:Destroy()
					end
					l.TextScaled = false
					l.TextWrapped = false
					l.TextXAlignment = Enum.TextXAlignment.Left
					local fitting = false
					local function fit()
						if fitting then
							return
						end
						fitting = true
						l.TextScaled = false -- Fit turns TextScaled on for small screens; scaled text wraps "12,345"
						l.TextWrapped = false
						l.TextSize = 38
						-- TextBounds updates a frame after TextSize changes: measure once, then scale the size to fit
						game:GetService("RunService").Heartbeat:Wait()
						local k = math.min(1, l.AbsoluteSize.X / math.max(l.TextBounds.X, 1))
						l.TextSize = math.max(12, math.floor(38 * k))
						fitting = false
					end
					l:GetPropertyChangedSignal("Text"):Connect(function()
						task.spawn(fit)
					end)
					l:GetPropertyChangedSignal("TextScaled"):Connect(function()
						task.defer(fit)
					end)
					task.spawn(fit)
				end
			end
		end
	end
	put("GoldIcon", 6, 18, 44, 44)
	put("GoldText", 52, 6, 90, 44)
	put("T_Gold", 54, 54)
	put("GemsIcon", 144, 18, 44, 44)
	put("GemsText", 190, 6, 98, 44) -- phones cap this text at 13 px (Fit): 98 design px holds "12,345" there
	put("T_Gems", 192, 54)
	local plus = w:FindFirstChild("GemsPlus")
	if plus and plus:IsA("GuiObject") then
		plus.Position = UDim2.fromOffset(314, top + 42) -- juicy buttons are centre-anchored
	end
	-- the stack drops by one plate (the wallet is anchored at its bottom edge)
	local drop = plates[2].Position.Y.Offset - top
	for _, c in w:GetChildren() do
		if c:IsA("GuiObject") then
			c.Position = c.Position + UDim2.fromOffset(0, drop)
			if c:GetAttribute("JuiceRest") ~= nil then -- juicy buttons spring back to this spot
				c:SetAttribute("JuiceRest", c.Position)
			end
		end
	end
end

-- ===== 3. dash hint lines

local function dashHints()
	local function want(): boolean
		local s = profile and profile.stats
		return s ~= nil and (s.matchesCompleted or 0) >= DASH_HINT_MATCHES
	end
	local applies = {}
	for _, sc in { "HUD", "MatchHUD" } do
		local d = root and root:FindFirstChild(sc) and root[sc]:FindFirstChild("Dash")
		if d then
			for _, n in { "DashState", "DashStateShadow", "DashHint", "DashHintShadow" } do
				local l = d:FindFirstChild(n)
				if l and l:IsA("GuiObject") then
					table.insert(applies, holdHidden(l, want))
				end
			end
		end
	end
	return function()
		for _, a in applies do
			a()
		end
	end
end

-- ===== 5 / 10. CLEAN STREAK row from the first clean crossing

local function streakRow()
	local st = root and root:FindFirstChild("MatchHUD") and root.MatchHUD:FindFirstChild("Status")
	if not st then
		return
	end
	local state = Net.state()
	local function want(): boolean
		return (state:GetAttribute("CleanStreak") or 0) <= 0
	end
	local applies = {}
	for _, c in st:GetChildren() do
		if c:IsA("GuiObject") and (c.Name:match("^StreakPip%d$") or c.Name:match("^T_CleanStreak")) then
			local was = c.Visible
			table.insert(applies, holdHidden(c, want))
			c:SetAttribute("DeclutterShown", was)
		end
	end
	state:GetAttributeChangedSignal("CleanStreak"):Connect(function()
		for _, c in st:GetChildren() do
			if c:IsA("GuiObject") and (c.Name:match("^StreakPip%d$") or c.Name:match("^T_CleanStreak")) then
				if want() then
					c.Visible = false
				elseif (state:GetAttribute("StreakToWin") or 3) < 999 then
					c.Visible = true -- PointsController / UIController restyle the pips on their own refresh
				end
			end
		end
	end)
end


-- ===== orphan shadows (premium pass): a hidden row / card keeps its exported ShadowRing or DropShadow, which
-- draws as an empty outlined box (Settings had one under UI Colour). The shadow follows its partner's visibility:
-- the sibling at the same spot and size.
local function orphanShadows()
	for _, sh in root:GetDescendants() do
		if sh:IsA("GuiObject") and (sh.Name == "ShadowRing" or sh.Name == "DropShadow") and sh.Parent and not sh:GetAttribute("ShadowPaired") then
			local found = false
			for _, c in sh.Parent:GetChildren() do
				if c ~= sh and c:IsA("GuiObject") and c.Name ~= "ShadowRing" and c.Name ~= "DropShadow"
					and math.abs(c.Position.X.Offset - sh.Position.X.Offset) <= 4 and math.abs(c.Position.Y.Offset - sh.Position.Y.Offset) <= 4
					and math.abs(c.Size.X.Offset - sh.Size.X.Offset) <= 8 and math.abs(c.Size.Y.Offset - sh.Size.Y.Offset) <= 8 then
					sh:SetAttribute("ShadowPaired", true)
					local partner = c
					local function sync() -- hide with the partner; only bring back a shadow this hid
						if not partner.Visible and sh.Visible then
							sh.Visible = false
							sh:SetAttribute("ShadowHiddenByDeclutter", true)
						elseif partner.Visible and sh:GetAttribute("ShadowHiddenByDeclutter") then
							sh:SetAttribute("ShadowHiddenByDeclutter", nil)
							sh.Visible = true
						end
					end
					partner:GetPropertyChangedSignal("Visible"):Connect(sync)
					sync()
					found = true
					break
				end
			end
			-- nothing at its spot any more (Settings: Row5 moved up when Music was added, its ring stayed): stale
			-- (a selection ring's own shadows are folded inside it at scale size: never these)
			local inRing = sh.Parent.Name:match("Sel$") ~= nil or sh.Parent.Name == "SelRing"
			if not found and not inRing and sh.Name == "ShadowRing" and sh.Visible then
				sh.Visible = false
				sh:SetAttribute("ShadowPaired", true)
			end
		end
	end
end

function HudDeclutter.init()
	local pg = player:WaitForChild("PlayerGui")
	local gui = pg:WaitForChild("EOSUI", 30)
	root = gui and gui:WaitForChild("Root", 10)
	if not root then
		return
	end
	local reapplyDash = dashHints()
	Net.event("ProfileState").OnClientEvent:Connect(function(view)
		if type(view) == "table" then
			profile = view
			if reapplyDash then
				reapplyDash()
			end
		end
	end)
	pcall(mergeWallet)
	task.delay(2, function()
		pcall(orphanShadows)
	end)
	pcall(streakRow)
	task.delay(1, function() -- after TopbarHover has set the top bar up
		local ok, err = pcall(buildMenu)
		if not ok then
			warn("[HudDeclutter] menu: " .. tostring(err))
		end
	end)
end

return HudDeclutter
