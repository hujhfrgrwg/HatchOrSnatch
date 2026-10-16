-- ServersController (HOS-SERVERS-001, 16 Oct): the Servers panel ("find your people").
-- Asks ServerListService for the live list when the panel opens (and on REFRESH), then shows it:
-- your server pinned first, country filters (built from the list), sort by players or by ping,
-- 5 rows a page, JOIN / FULL / HERE. Your own ping is live from your client; the others are the
-- average ping of each server's players. Joining teleports you (live game only).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared"):WaitForChild("Net"))
local UI = require(script.Parent.UIController)

local ServersController = {}

local player = Players.LocalPlayer
local panel: Instance? = nil
local data: any = nil
local sortBy = "players"
local country = "" -- "" = all
local page = 1
local PER_PAGE = 5
local ROW_STEP = 108

local function find(scope: Instance?, name: string): Instance?
	return scope and scope:FindFirstChild(name, true)
end
local function setText(scope: Instance?, name: string, text: string)
	local t = find(scope, name)
	if t and (t:IsA("TextLabel") or t:IsA("TextButton")) then t.Text = text end
end
local function show(g: Instance?, on: boolean)
	if g and g:IsA("GuiObject") then g.Visible = on end
end
local function dual(b: Instance?, on: boolean)
	show(b and b:FindFirstChild("On"), on)
	show(b and b:FindFirstChild("Off"), not on)
end

local function myPing(): number
	local ok, p = pcall(function()
		return player:GetNetworkPing()
	end)
	return if ok and type(p) == "number" then math.floor(p * 1000 + 0.5) else 0
end

local function pingColour(ms: number): Color3
	if ms < 80 then return Color3.fromRGB(122, 224, 42) end
	if ms < 150 then return Color3.fromRGB(255, 178, 26) end
	return Color3.fromRGB(255, 80, 80)
end

local function place(v: any): string
	local c = tostring(v.country or "Unknown")
	if v.city and v.city ~= "" and v.city ~= c then
		return c .. "  ·  " .. v.city
	end
	return c
end

local function rows(): { any }
	local list = {}
	if not data or type(data.servers) ~= "table" then return list end
	for _, v in ipairs(data.servers) do
		if type(v) == "table" and (country == "" or v.country == country or v.id == data.here) then
			table.insert(list, v)
		end
	end
	table.sort(list, function(a, b)
		if a.id == data.here then return true end
		if b.id == data.here then return false end
		if sortBy == "ping" then
			return (a.ping or 999) < (b.ping or 999)
		end
		local fa, fb = (a.players or 0) >= (a.max or 1), (b.players or 0) >= (b.max or 1)
		if fa ~= fb then return fb end -- full servers sink
		return (a.players or 0) > (b.players or 0)
	end)
	return list
end

local rowFrames: { GuiObject } = {}
local countryBtns: { GuiObject } = {}

local function fillRow(f: GuiObject, v: any)
	local you = data and v.id == data.here
	local ping = if you then myPing() else (v.ping or 0)
	setText(f, "Region", (if you then "YOUR SERVER  ·  " else "") .. place(v))
	setText(f, "Detail", ("%d / %d players  ·  %s"):format(v.players or 0, v.max or 0, v.phase or "In lobby"))
	setText(f, "Ping", (if you then "%d ms" else "%d ms avg"):format(ping))
	local p = find(f, "Ping")
	if p and p:IsA("TextLabel") then p.TextColor3 = pingColour(ping) end
	local full = (v.players or 0) >= (v.max or 1)
	show(find(f, "BtnJoin"), not you and not full)
	show(find(f, "BtnFull"), not you and full)
	show(find(f, "BtnHere"), you)
	f:SetAttribute("JobId", v.id)
	local reg = find(f, "Region")
	if reg and reg:IsA("TextLabel") then reg.TextColor3 = if you then Color3.fromRGB(122, 224, 42) else Color3.new(1, 1, 1) end
	local st = find(f, "EOS_You")
	if st and st:IsA("UIStroke") then st.Enabled = you end
end

function ServersController.refresh()
	if not panel then return end
	dual(find(panel, "SortPlayers"), sortBy == "players")
	dual(find(panel, "SortPing"), sortBy == "ping")
	setText(panel, "PingText", ("%d ms"):format(myPing()))
	local list = rows()
	local total = if data and type(data.servers) == "table" then #data.servers else 0
	setText(panel, "CountText", if data then ("%d SERVER%s"):format(total, if total == 1 then "" else "S") else "LOADING...")
	local pages = math.max(1, math.ceil(#list / PER_PAGE))
	page = math.clamp(page, 1, pages)
	setText(panel, "PageText", ("PAGE %d / %d"):format(page, pages))
	show(find(panel, "BtnPrev"), page > 1)
	show(find(panel, "BtnNext"), page < pages)
	for i, f in ipairs(rowFrames) do
		local v = list[(page - 1) * PER_PAGE + i]
		f.Visible = v ~= nil
		if v then fillRow(f, v) end
	end
	-- country filters from the list (All first, then most players)
	local counts, order = {}, {}
	for _, v in ipairs(if data and type(data.servers) == "table" then data.servers else {}) do
		local c = tostring(v.country or "Unknown")
		if not counts[c] then
			counts[c] = 0
			table.insert(order, c)
		end
		counts[c] += v.players or 0
	end
	table.sort(order, function(a, b) return counts[a] > counts[b] end)
	for i, b in ipairs(countryBtns) do
		local c = if i == 1 then "" else order[i - 1]
		b.Visible = i == 1 or c ~= nil
		if b.Visible then
			b:SetAttribute("Country", c or "")
			for _, n in ipairs({ "On", "Off" }) do
				local s = b:FindFirstChild(n)
				setText(s, "Label", if i == 1 then "All countries" else (c or ""))
			end
			dual(b, (c or "") == country)
		end
	end
end

local function request()
	data = data or nil
	Net.event("RequestServers"):FireServer()
end

local function wire(root: Instance)
	local scr = root:FindFirstChild("Servers")
	panel = scr and scr:FindFirstChild("Servers")
	if not panel then return end
	local list = find(panel, "List")
	if list then
		-- the design rows become 5 live rows (YourRow + Row1..4 keep their places)
		for _, n in ipairs({ "YourRow", "Row1", "Row2", "Row3", "Row4" }) do
			local f = list:FindFirstChild(n)
			if f and f:IsA("GuiObject") then table.insert(rowFrames, f) end
		end
		-- YourRow's lime rim is for your server only: every row uses the plain plate, yours gets a lime stroke
		local plain = list:FindFirstChild("Row1")
		local plainArt = plain and plain:FindFirstChild("Art")
		for _, f in ipairs(rowFrames) do
			local art = f:FindFirstChild("Art")
			if art and art:IsA("ImageLabel") and plainArt and plainArt:IsA("ImageLabel") then art.Image = plainArt.Image end
		end
		show(list:FindFirstChild("ProtoRow"), false)
		for _, f in ipairs(rowFrames) do
			local join = find(f, "BtnJoin")
			if join and join:IsA("GuiButton") then
				UI.juicy(join, function()
					local id = f:GetAttribute("JobId")
					if type(id) == "string" then Net.event("RequestJoinServer"):FireServer(id) end
				end)
			end
			local fullB = find(f, "BtnFull")
			if fullB and fullB:IsA("GuiButton") then UI.juicy(fullB, function() UI.toast("That server is full", "warn") end) end
			local here = find(f, "BtnHere")
			if here and here:IsA("GuiButton") then UI.juicy(here, function() UI.toast("You're in this one", "info") end) end
		end
	end
	local cs = find(panel, "Countries")
	if cs then
		for i = 1, 7 do
			local b = cs:FindFirstChild("Country" .. i)
			if b and b:IsA("GuiButton") then
				table.insert(countryBtns, b)
				UI.juicy(b, function()
					country = b:GetAttribute("Country") or ""
					page = 1
					ServersController.refresh()
				end)
			end
		end
		show(cs:FindFirstChild("ProtoCountry"), false)
	end
	local function btn(name: string, fn: () -> ())
		local b = find(panel, name)
		if b and b:IsA("GuiButton") then UI.juicy(b, fn) end
	end
	btn("SortPlayers", function() sortBy = "players"; page = 1; ServersController.refresh() end)
	btn("SortPing", function() sortBy = "ping"; page = 1; ServersController.refresh() end)
	btn("BtnRefresh", request)
	btn("BtnPrev", function() page -= 1; ServersController.refresh() end)
	btn("BtnNext", function() page += 1; ServersController.refresh() end)
	local close = find(scr, "CloseButton")
	if close and close:IsA("GuiButton") then UI.juicy(close, function() UI.close() end) end
	local dim = scr:FindFirstChild("Dim")
	local f = dim and dim:FindFirstChild("F")
	if f and f:IsA("GuiObject") then
		f.Active = true
		f.InputBegan:Connect(function(input)
			if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and UI.openName() == "Servers" then
				UI.close()
			end
		end)
	end
	-- your-server stroke
	local yr = rowFrames[1]
	local yart = yr and yr:FindFirstChild("Art")
	if yart and yart:IsA("GuiObject") and not yart:FindFirstChild("EOS_You") then
		local st = Instance.new("UIStroke")
		st.Name = "EOS_You"
		st.Color = Color3.fromRGB(122, 224, 42)
		st.Thickness = 3
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		st.Parent = yart
		if not yart:FindFirstChildOfClass("UICorner") then
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, 14)
			c.Parent = yart
		end
	end
end

function ServersController.init()
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("EOSUI", 30)
	local root = gui and gui:WaitForChild("Root", 10)
	if root then wire(root) end
	Net.event("ServerList").OnClientEvent:Connect(function(t)
		if type(t) == "table" then
			data = t
			ServersController.refresh()
		end
	end)
	UI.onOpen = UI.onOpen or {}
	UI.onOpen.Servers = function()
		page = 1
		ServersController.refresh()
		request()
	end
	-- live ping while open
	task.spawn(function()
		while true do
			task.wait(2)
			if UI.openName() == "Servers" and panel then
				setText(panel, "PingText", ("%d ms"):format(myPing()))
				local yr = rowFrames[1]
				if yr and data and yr:GetAttribute("JobId") == data.here then
					local ms = myPing()
					setText(yr, "Ping", ("%d ms"):format(ms))
					local p = find(yr, "Ping")
					if p and p:IsA("TextLabel") then p.TextColor3 = pingColour(ms) end
				end
			end
		end
	end)
end

return ServersController
