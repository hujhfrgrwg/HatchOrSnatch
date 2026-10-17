--!nocheck
-- BuildPetShowroom (Oct 15 2026): lays out every pet and egg ported from Fishing with Pets! so they
-- can be looked at (and watched animating) in Run / Play mode.
--   require(game.ServerStorage.EOSBuild.PetShowroom.BuildPetShowroom)()
-- Source: ServerStorage.FWP_PetLibrary (the organised port). Output: workspace.FWP_PetShowroom.
-- Layout (rows run west -> east, the showroom grows south, away from the lobby):
--   row 0  eggs on their bases (+ the egg-guide mascot), labelled with source, odds and hatch time
--   rows   one per rarity (Common .. Mythic), then Alien-egg exclusives, Huge exclusives, Archived
--   each pet "family" = base pet + its two colour variants (★★, ★★★) side by side on plinths
-- Labels are BillboardGuis (visible within 140 studs). Animations: the ShowroomAnimator script inside
-- the showroom cycles every model through all of its clips.
-- Delete workspace.FWP_PetShowroom before publishing if it shouldn't ship.

local ServerStorage = game:GetService("ServerStorage")
local D = require(script.Parent.FWPPetData)

local ORIGIN = Vector3.new(0, 1, 110) -- north-west corner of the deck (sea level is -13)
local SCALE = 2 -- pets are ~2.5 studs: show them at 2x
local EGG_SCALE = 2.4
local ROW_GAP = 14 -- walkway between rows
local FAMILY_GAP = 10
local VARIANT_GAP = 3
local TIER_COLOR = { [1] = Color3.fromRGB(235, 238, 245), [2] = Color3.fromRGB(120, 226, 255), [3] = Color3.fromRGB(255, 214, 70) }
local INK = Color3.fromRGB(20, 22, 30)

local function part(parent, name, size, cf, color, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props or {} do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function billboard(adornee, lines, height, maxDist)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Label"
	bb.Size = UDim2.fromScale(8, 0.9 * #lines + 0.3)
	bb.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	bb.MaxDistance = maxDist or 140
	bb.LightInfluence = 0
	bb.AlwaysOnTop = false
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = bb
	for i, l in lines do
		local t = Instance.new("TextLabel")
		t.Name = l.name or ("Line" .. i)
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1 / #lines)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.Text = l.text
		t.TextColor3 = l.color or Color3.new(1, 1, 1)
		t.TextStrokeTransparency = 0
		t.TextStrokeColor3 = INK
		t.LayoutOrder = i
		t.Parent = bb
	end
	bb.Parent = adornee
	return bb
end

local function sign(parent, name, text, sub, color, cf, w)
	local board = part(parent, name, Vector3.new(w, 6, 0.6), cf, INK)
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 30
	g.LightInfluence = 0
	g.Parent = board
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 0.62)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = color
	t.Parent = g
	local s = t:Clone()
	s.Position = UDim2.fromScale(0, 0.62)
	s.Size = UDim2.fromScale(1, 0.34)
	s.Text = sub
	s.TextColor3 = Color3.fromRGB(220, 224, 236)
	s.Parent = g
	part(parent, name .. "Trim", Vector3.new(w + 0.6, 0.6, 0.8), cf * CFrame.new(0, 3.2, 0), color)
	return board
end

-- ScaleTo is absolute (relative to the model's original size): some imports carry a shrunk scale already
local function grow(model: Model, k: number)
	model:ScaleTo(model:GetScale() * k)
end

local function width(model: Model): number
	local _, size = model:GetBoundingBox()
	return math.max(size.X, size.Z)
end

-- place a model standing on y = top at (x, z), facing -Z (north, towards the lobby and the front of the showroom)
local function stand(model: Model, x: number, top: number, z: number, lift: number)
	local cf, size = model:GetBoundingBox()
	local pivot = model:GetPivot()
	local bottomOffset = (cf.Position.Y - size.Y / 2) - pivot.Position.Y
	model:PivotTo(CFrame.new(x, top - bottomOffset + (lift or 0), z))
end

local function variantOf(model: Model, petId: string, v)
	local body = model:FindFirstChild(petId)
	if body and body:IsA("MeshPart") and v.Texture then
		body.TextureID = v.Texture
	end
	local glow = model:FindFirstChild(petId .. "_Glow")
	if glow and v.Glow then
		glow.Color = v.Glow
	end
end

local M = {}

-- Turn the raw export (_EOS_PetPort_Export) into ServerStorage.FWP_PetLibrary, sorted and labelled.
function M.organize(): Folder
	local lib = ServerStorage:FindFirstChild("FWP_PetLibrary")
	local raw = ServerStorage:FindFirstChild("_EOS_PetPort_Export")
	if lib and not raw then
		return lib
	end
	assert(raw, "no _EOS_PetPort_Export to organise")
	if lib then
		lib:Destroy()
	end
	lib = Instance.new("Folder")
	lib.Name = "FWP_PetLibrary"
	lib:SetAttribute("Source", "Fishing with Pets! (place 6909797319), ported Oct 15 2026")
	local pets = Instance.new("Folder")
	pets.Name = "Pets"
	pets.Parent = lib
	for i, rowName in { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" } do
		local f = Instance.new("Folder")
		f.Name = ("%d_%s"):format(i, rowName)
		f.Parent = pets
	end
	for _, m in raw.Pets:GetChildren() do
		local info = D.Pets[m.Name]
		if info then
			m:SetAttribute("DisplayName", info.Name)
			m:SetAttribute("Rarity", info.Rarity)
			m:SetAttribute("Archetype", info.Archetype)
			m:SetAttribute("Eggs", table.concat(info.Eggs, ", "))
			if info.Note ~= "" then
				m:SetAttribute("Note", info.Note)
			end
			local idx = table.find(D.RarityOrder, info.Rarity)
			m.Parent = pets:FindFirstChild(("%d_%s"):format(idx, info.Rarity))
		end
	end
	local eggs = raw.PetEggs
	eggs.Name = "Eggs"
	for i, e in D.Eggs do
		local m = eggs:FindFirstChild(e.Id)
		if m then
			m:SetAttribute("DisplayName", e.Name)
			m:SetAttribute("Source", e.Source)
			m:SetAttribute("Odds", e.Odds)
			m:SetAttribute("HatchTime", e.Hatch)
			m:SetAttribute("Order", i)
		end
	end
	eggs.Parent = lib
	raw.FloatingEggBases.Name = "EggBases"
	raw.EggBases.Parent = lib
	raw.EggGuide.Parent = lib
	raw.Clips.Parent = lib -- KeyframeSequences of every animation (named by the original asset id)
	raw.Reference.Parent = lib -- the original config modules, for reference only (not required by EOS)
	raw:Destroy()
	lib.Parent = ServerStorage
	return lib
end

-- Sort FWP_PetLibrary.Pets into one folder per ability pool (+ LeftOut), ordered like the showroom.
function M.regroup(lib: Folder)
	local pets = lib.Pets
	local all = {}
	for _, d in ipairs(pets:GetDescendants()) do
		if d:IsA("Model") and D.Pets[d.Name] and d.Parent:IsA("Folder") then
			all[d.Name] = d
		end
	end
	local folders = {}
	for i, pool in D.Pools do
		local f = Instance.new("Folder")
		f.Name = ("%d_%s"):format(i, pool.Id)
		f:SetAttribute("Ability", pool.Title)
		f:SetAttribute("Blurb", pool.Blurb)
		folders[pool.Title] = f
	end
	local left = Instance.new("Folder")
	left.Name = ("%d_LeftOut"):format(#D.Pools + 1)
	for id, m in all do
		local ability = D.AbilityOf[id]
		m:SetAttribute("Ability", ability)
		m:SetAttribute("LeftOutReason", if ability then nil else D.LeftOut[id])
		local pool
		for _, p in D.Pools do
			if p.Title == ability then
				pool = p
			end
		end
		m:SetAttribute("PoolOrder", if pool then table.find(pool.Pets, id) else table.find(D.LeftOutOrder, id))
		m.Parent = if ability then folders[ability] else left
	end
	for _, old in ipairs(pets:GetChildren()) do
		if old:IsA("Folder") and #old:GetChildren() == 0 then
			old:Destroy()
		end
	end
	for _, f in folders do
		f.Parent = pets
	end
	left.Parent = pets
end

function M.build()
	local lib = M.organize()
	M.regroup(lib)
	local variantData = require(lib.Reference.PetVariantData)
	local old = workspace:FindFirstChild("FWP_PetShowroom")
	if old then
		old:Destroy()
	end
	local room = Instance.new("Model")
	room.Name = "FWP_PetShowroom"
	local pieces = Instance.new("Folder")
	pieces.Name = "Deck"
	pieces.Parent = room
	local displays = Instance.new("Folder")
	displays.Name = "Displays"
	displays.Parent = room

	local function findPet(id)
		for _, f in lib.Pets:GetChildren() do
			local m = f:FindFirstChild(id)
			if m then
				return m
			end
		end
	end

	-- build every row's content first (so each row knows its width), then lay the deck under them
	local rows = {}
	-- eggs row
	do
		local items = {}
		for _, e in D.Eggs do
			local egg = lib.Eggs:FindFirstChild(e.Id)
			if egg then
				local g = Instance.new("Model")
				g.Name = "Egg_" .. e.Id
				local base = (if e.Id == "Alien" then lib.EggBases.EggBaseAlien else lib.EggBases.EggBase):Clone()
				base.Name = "Base"
				grow(base, EGG_SCALE)
				base.Parent = g
				local m = egg:Clone()
				grow(m, EGG_SCALE)
				m:SetAttribute("ShowroomAnimate", true)
				m.Parent = g
				table.insert(items, { model = g, egg = m, base = base, info = e })
			end
		end
		local guide = lib.EggGuide.BootedEgg:Clone()
		grow(guide, EGG_SCALE)
		guide:SetAttribute("ShowroomAnimate", true)
		table.insert(items, { model = guide, guide = true })
		table.insert(rows, { title = "EGGS", sub = "7 eggs + the egg-guide mascot", color = Color3.fromRGB(255, 214, 70), kind = "eggs", items = items })
	end
	for _, row in D.Rows do
		local fams = {}
		for _, id in row.Pets do
			local src = findPet(id)
			if src then
				local info = D.Pets[id]
				local fam = Instance.new("Model")
				fam.Name = id
				local members = {}
				local vd = variantData.Pets[id]
				for tier = 1, 3 do
					local v = vd and vd.Tiers and vd.Tiers[tier]
					if tier == 1 or v then
						local m = src:Clone()
						m.Name = if tier == 1 then id else ("%s_T%d"):format(id, tier)
						if v then
							variantOf(m, id, v)
						end
						local s = SCALE * (D.Huge[id] or 1)
						grow(m, s)
						m:SetAttribute("ShowroomAnimate", true)
						m:SetAttribute("Tier", tier)
						m:SetAttribute("VariantName", if v then v.Name else "Normal")
						m.Parent = fam
						table.insert(members, { model = m, tier = tier, v = v, scale = s })
					end
				end
				table.insert(fams, { model = fam, id = id, info = info, members = members })
			end
		end
		table.insert(rows, { title = string.upper(row.Title), sub = row.Sub .. " · " .. #fams .. " pets", color = row.Color, kind = "pets", fams = fams })
	end

	local z = ORIGIN.Z
	local deckW = 0
	local rowSpans = {}
	for ri, row in rows do
		local x = ORIGIN.X + 34 -- room for the row sign
		local depth = 0
		local top = ORIGIN.Y + 1
		if row.kind == "eggs" then
			for _, it in row.items do
				local w = width(it.model) + 8
				local cx = x + w / 2
				local cz = z + 10
				if it.guide then
					stand(it.model, cx, top, cz, 0)
					billboard(it.model.PrimaryPart or it.model:FindFirstChildWhichIsA("BasePart"), {
						{ text = "Egg Guide (Booted Egg)", color = Color3.fromRGB(255, 214, 70) },
						{ text = "the walking egg mascot · 7 clips", color = Color3.fromRGB(220, 224, 236) },
					}, 9)
				else
					stand(it.base, cx, top, cz, 0)
					local _, bsize = it.base:GetBoundingBox()
					stand(it.egg, cx, top + bsize.Y, cz, 0)
					billboard(it.egg.PrimaryPart, {
						{ text = it.info.Name, color = Color3.fromRGB(255, 214, 70) },
						{ text = it.info.Source .. " · hatch " .. it.info.Hatch, color = Color3.fromRGB(220, 224, 236) },
						{ text = it.info.Odds, color = Color3.fromRGB(170, 230, 255) },
						{ text = "▶ Idle", color = Color3.fromRGB(150, 255, 150), name = "Anim" },
					}, 10)
				end
				it.model.Parent = displays
				x += w
				depth = math.max(depth, 20)
			end
		else
			for _, fam in row.fams do
				local fx0 = x
				local tallest = 0
				for _, mem in fam.members do
					local w = math.max(width(mem.model), 4) + VARIANT_GAP
					local cx = x + w / 2
					local cz = z + 9
					-- plinth: rarity colour, rim in the variant's star colour
					local _, msize = mem.model:GetBoundingBox()
					local pr = math.max(msize.X, msize.Z) / 2 + 1.2
					local plinth = part(fam.model, "Plinth", Vector3.new(1.2, pr * 2, pr * 2), CFrame.new(cx, top + 0.6, cz) * CFrame.Angles(0, 0, math.rad(90)), row.color, { Shape = Enum.PartType.Cylinder })
					part(fam.model, "Rim", Vector3.new(0.4, pr * 2 + 0.6, pr * 2 + 0.6), CFrame.new(cx, top + 0.2, cz) * CFrame.Angles(0, 0, math.rad(90)), TIER_COLOR[mem.tier], { Shape = Enum.PartType.Cylinder })
					local lift = (D.Float[fam.id] or 0) * mem.scale * 0.5
					stand(mem.model, cx, top + 1.2, cz, lift)
					tallest = math.max(tallest, msize.Y + lift)
					local stars = string.rep("★", mem.tier)
					local vname = if mem.v then mem.v.DisplayName else fam.info.Name
					billboard(mem.model.PrimaryPart, {
						{ text = stars .. "  " .. vname, color = TIER_COLOR[mem.tier] },
						{ text = "▶ Idle", color = Color3.fromRGB(150, 255, 150), name = "Anim" },
					}, msize.Y / 2 + 1.5, 90)
					x += w
				end
				-- family label over the middle of the family
				local mid = part(fam.model, "FamilyLabel", Vector3.new(1, 1, 1), CFrame.new((fx0 + x) / 2, top + 1.2 + tallest + 3, z + 9), Color3.new(1, 1, 1), { Transparency = 1, CanCollide = false, CanQuery = false })
				local info = fam.info
				local ability = D.AbilityOf[fam.id]
				billboard(mid, {
					{ text = info.Name, color = D.Rarities[info.Rarity] },
					{ text = info.Rarity .. " · " .. (ability or "left out"), color = Color3.fromRGB(230, 232, 240) },
					{ text = if ability then "FwP: " .. (if info.Note ~= "" then info.Note else "egg pet") else D.LeftOut[fam.id] or "", color = Color3.fromRGB(170, 230, 255) },
				}, 1.5, 160)
				fam.model:SetAttribute("Rarity", info.Rarity)
				fam.model.Parent = displays
				x += FAMILY_GAP
				depth = math.max(depth, 18)
			end
		end
		local rowW = x - ORIGIN.X
		deckW = math.max(deckW, rowW)
		table.insert(rowSpans, { z0 = z, z1 = z + depth, row = row })
		z += depth + ROW_GAP
	end
	deckW += 6
	-- deck, row strips and row signs
	local deckZ1 = z - ROW_GAP + 6
	part(pieces, "Deck", Vector3.new(deckW, 2, deckZ1 - ORIGIN.Z + 6), CFrame.new(ORIGIN.X + deckW / 2, ORIGIN.Y, (ORIGIN.Z - 6 + deckZ1) / 2), Color3.fromRGB(64, 70, 92))
	for _, s in rowSpans do
		local cz = (s.z0 + s.z1) / 2
		part(pieces, "RowStrip", Vector3.new(deckW - 4, 0.2, s.z1 - s.z0), CFrame.new(ORIGIN.X + deckW / 2, ORIGIN.Y + 1.1, cz), s.row.color:Lerp(Color3.fromRGB(64, 70, 92), 0.72))
		sign(pieces, "RowSign", s.row.title, s.row.sub, s.row.color, CFrame.new(ORIGIN.X + 16, ORIGIN.Y + 5, cz), 28)
	end
	-- title over the deck, readable from the lobby
	local t = part(pieces, "TitleAnchor", Vector3.new(1, 1, 1), CFrame.new(ORIGIN.X + deckW / 2, ORIGIN.Y + 26, ORIGIN.Z - 4), Color3.new(1, 1, 1), { Transparency = 1, CanCollide = false, CanQuery = false })
	billboard(t, {
		{ text = "PET SHOWROOM", color = Color3.fromRGB(255, 214, 70) },
		{ text = "ported from Fishing with Pets! · press Run to see them animate", color = Color3.fromRGB(220, 224, 236) },
	}, 0, 600).Size = UDim2.fromScale(60, 7)

	script.Parent.ShowroomAnimator:Clone().Parent = room
	room.Parent = workspace
	local n = 0
	for _, d in room:GetDescendants() do
		if d:GetAttribute("ShowroomAnimate") then
			n += 1
		end
	end
	return ("showroom: %d animated models, deck %.0f x %.0f studs at %s"):format(n, deckW, deckZ1 - ORIGIN.Z, tostring(ORIGIN))
end

return setmetatable(M, { __call = function(_, ...)
	return M.build(...)
end })
