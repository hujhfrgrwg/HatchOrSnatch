-- HOS-PTS-001 podium (studify). Builds ServerStorage.HOS_Podium: a stud-style winners' podium, disabled by
-- default (PodiumService moves it into workspace at the end of a match while PointsConfig.Podium.Enabled).
-- Spot: the lobby's front strip between the spawn pad (z -202.5) and the leaderboard flower beds (z -195.3),
-- centred on the lobby's x, facing the spawn (-Z). Ground top Y = 16 (LobbyProto.Top.Field, surveyed).
-- No MaterialVariants in this place: SurfaceType fallback (Universal fills, Weld structure, Studs tops).
local CHS = game:GetService("ChangeHistoryService")
CHS:SetWaypoint("HOS-PTS-001 podium: before")

local old = game.ServerStorage:FindFirstChild("HOS_Podium") or workspace:FindFirstChild("HOS_Podium")
if old then old:Destroy() end

local GROUND = 16
local CX, CZ = 23.25, -199 -- podium centre (front face toward -Z)
local FRONT = -1 -- -Z is the front
local root = Instance.new("Model")
root.Name = "HOS_Podium"
root:SetAttribute("Enabled", false)

local C = {
	navy = Color3.fromRGB(38, 52, 120), navyDark = Color3.fromRGB(26, 34, 82), gold = Color3.fromRGB(255, 200, 40),
	goldDeep = Color3.fromRGB(224, 150, 20), white = Color3.fromRGB(240, 242, 248), silver = Color3.fromRGB(176, 186, 204),
	orange = Color3.fromRGB(240, 132, 52), red = Color3.fromRGB(214, 48, 58), cyan = Color3.fromRGB(110, 210, 255),
}

local function model(name, parent)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent or root
	return m
end

local function brick(parent, name, size, pos, color, pattern, props)
	local p = Instance.new((props and props.Class) or "Part")
	p.Name = name
	p.Size = size
	p.CFrame = typeof(pos) == "CFrame" and pos or CFrame.new(pos)
	p.Color = color
	p.Material = Enum.Material.Plastic
	p.Anchored = true
	local small = size.X < 0.5 and size.Y < 0.5 and size.Z < 0.5
	local surf = if small then Enum.SurfaceType.Smooth else Enum.SurfaceType[pattern or "Universal"]
	p.TopSurface, p.FrontSurface, p.BackSurface, p.LeftSurface, p.RightSurface = surf, surf, surf, surf, surf
	p.BottomSurface = if small then Enum.SurfaceType.Smooth else Enum.SurfaceType.Inlet
	for k, v in pairs(props or {}) do
		if k ~= "Class" then p[k] = v end
	end
	p.Parent = parent
	return p
end

local function at(x, y, z) return Vector3.new(CX + x, GROUND + y, CZ + z) end

-- ===== base: a navy plinth with a gold lip, the whole width =====
local base = model("Base")
local BW, BD, BH = 33, 6.4, 1
brick(base, "Plinth", Vector3.new(BW, BH, BD), at(0, BH / 2, 0), C.navyDark, "Universal")
brick(base, "LipFront", Vector3.new(BW + 0.2, 0.3, 0.3), at(0, BH - 0.15 + 0.0001, FRONT * (BD / 2 + 0.05)), C.gold, "Weld")
brick(base, "LipBack", Vector3.new(BW + 0.2, 0.3, 0.3), at(0, BH - 0.15 + 0.0001, -FRONT * (BD / 2 + 0.05)), C.gold, "Weld")

-- ===== the three steps: 2nd (viewer's left = +X), 1st (centre), 3rd (viewer's right = -X) =====
local SW, SD = 8, 5.2
local steps = {
	{ place = 1, x = 0, h = 5.2, top = C.gold, rim = C.goldDeep, label = "1ST" },
	{ place = 2, x = 8.6, h = 3.8, top = C.white, rim = C.silver, label = "2ND" },
	{ place = 3, x = -8.6, h = 2.8, top = C.orange, rim = Color3.fromRGB(196, 96, 34), label = "3RD" },
}
for _, s in ipairs(steps) do
	local m = model("Step" .. s.place)
	local y0 = BH
	-- body: navy with a darker recessed panel on the front (relief, not paint)
	brick(m, "Body", Vector3.new(SW, s.h, SD), at(s.x, y0 + s.h / 2, 0), C.navy, "Universal")
	brick(m, "Panel", Vector3.new(SW - 1.6, s.h - 1.6, 0.2), at(s.x, y0 + s.h / 2 - 0.1, FRONT * (SD / 2 + 0.1)), C.navyDark, "Studs")
	-- corner posts proud of the body (Weld structure)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			brick(m, "Post", Vector3.new(0.6, s.h + 0.0001, 0.6), at(s.x + sx * (SW / 2 - 0.2), y0 + s.h / 2, sz * (SD / 2 - 0.2)), s.rim, "Weld")
		end
	end
	-- the top: a studded slab overhanging by 0.3, a thin rim band under it
	brick(m, "Rim", Vector3.new(SW + 0.3, 0.3, SD + 0.3), at(s.x, y0 + s.h + 0.15, 0), s.rim, "Weld")
	brick(m, "Top", Vector3.new(SW + 0.6, 0.6, SD + 0.6), at(s.x, y0 + s.h + 0.6, 0), s.top, "Studs")
	-- the place number on the front panel (a sign, outlined like the UI)
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Label"
	sg.Face = Enum.NormalId.Front -- the panel's front points along its LookVector; panels face -Z below
	sg.PixelsPerStud = 40
	sg.LightInfluence = 0
	sg.Parent = m:FindFirstChild("Panel")
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = s.label
	t.TextScaled = true
	t.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
	t.TextColor3 = s.top
	t.Parent = sg
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0.18, 0), UDim.new(0.18, 0)
	pad.Parent = t
	local st = Instance.new("UIStroke")
	st.Thickness = 6
	st.Color = Color3.fromRGB(10, 12, 24)
	st.Parent = t
	-- where the winner stands, and where the push-in camera sits (invisible markers)
	local spot = brick(m, "Spot", Vector3.new(2, 0.2, 2), at(s.x, y0 + s.h + 1, 0), C.gold, "Smooth", { Transparency = 1, CanCollide = false, CanQuery = false })
	spot:SetAttribute("Place", s.place)
	local camPos = at(s.x * 0.6, y0 + s.h + 3.2, FRONT * 13)
	local look = at(s.x, y0 + s.h + 3, 0)
	brick(m, "Cam", Vector3.new(1, 1, 1), CFrame.lookAt(camPos, look), C.cyan, "Smooth", { Transparency = 1, CanCollide = false, CanQuery = false })
end
-- the panels face -Z: rotate each SurfaceGui's panel so Front = -Z (CFrame.lookAt toward -Z)
for _, s in ipairs(root:GetChildren()) do
	local panel = s:FindFirstChild("Panel")
	if panel then panel.CFrame = CFrame.lookAt(panel.Position, panel.Position + Vector3.new(0, 0, FRONT)) end
end

-- ===== side towers: tall navy pillars with gold bands and a stepped gold crown =====
for _, side in ipairs({ -1, 1 }) do
	local m = model(if side == 1 then "TowerLeft" else "TowerRight")
	local x = side * (BW / 2 - 1.5)
	local H = 13
	brick(m, "Shaft", Vector3.new(2.8, H, 2.8), at(x, BH + H / 2, 0), C.navy, "Universal")
	for b = 1, 3 do
		brick(m, "Band" .. b, Vector3.new(3.1, 0.4, 3.1), at(x, BH + b * 3.6, 0), C.gold, "Weld")
	end
	brick(m, "Crown1", Vector3.new(3.6, 0.8, 3.6), at(x, BH + H + 0.4, 0), C.gold, "Studs")
	brick(m, "Crown2", Vector3.new(2.6, 0.8, 2.6), at(x, BH + H + 1.2, 0), C.goldDeep, "Studs")
	brick(m, "Crown3", Vector3.new(1.4, 0.8, 1.4), at(x, BH + H + 2.0, 0), C.gold, "Studs")
	-- a thin glow strip down the front face (the one accent)
	brick(m, "Glow", Vector3.new(0.3, H - 2, 0.2), at(x, BH + H / 2, FRONT * 1.45), C.gold, "Smooth", { Material = Enum.Material.Neon })
	-- a spotlight in the crown aimed at the 1st place top
	local att = Instance.new("Attachment")
	att.Name = "Light"
	att.WorldCFrame = CFrame.lookAt(at(x, BH + H + 0.2, FRONT * 1.6), at(0, BH + 6, 0))
	att.Parent = m:FindFirstChild("Crown1")
	local sl = Instance.new("SpotLight")
	sl.Brightness, sl.Range, sl.Angle, sl.Color = 3, 26, 40, Color3.fromRGB(255, 236, 190)
	sl.Face = Enum.NormalId.Front
	sl.Parent = att
end

-- ===== back frame: a gold arch standing on the back of 1st place's top (reference 14's big frame) =====
local frame = model("Frame")
local FY = BH + 5.2 + 0.9 -- 1st place's top surface
local FX, FH, FZ = 3.7, 8.5, -FRONT * (SD / 2 - 0.3)
for _, side in ipairs({ -1, 1 }) do
	brick(frame, "Leg", Vector3.new(0.9, FH + 0.1, 0.9), at(side * FX, FY + FH / 2 - 0.05, FZ), C.gold, "Weld")
end
brick(frame, "Beam", Vector3.new(FX * 2 + 1.5, 1, 1.2), at(0, FY + FH + 0.4, FZ), C.gold, "Weld")
brick(frame, "BeamCap", Vector3.new(FX * 2 + 2.1, 0.4, 1.6), at(0, FY + FH + 1.1, FZ), C.goldDeep, "Studs")
-- navy banner hanging from the beam, behind the winner, with a gold hem (relief)
brick(frame, "Banner", Vector3.new(FX * 2 - 0.8, 4.2, 0.3), at(0, FY + FH - 2.05, FZ), C.navyDark, "Studs")
brick(frame, "BannerTrim", Vector3.new(FX * 2 - 0.4, 0.4, 0.5), at(0, FY + FH - 4.15, FZ), C.gold, "Weld")
-- a stepped star on the banner (five blocks, 15-degree tilt on the points)
local star = model("Star", frame)
local sc = at(0, FY + FH - 2.05, FZ + FRONT * 0.25)
brick(star, "Core", Vector3.new(1.2, 1.2, 0.3), sc, C.gold, "Studs")
for i = 0, 4 do
	local a = math.rad(i * 72)
	local off = Vector3.new(math.sin(a) * 1.0, math.cos(a) * 1.0, 0)
	brick(star, "Point" .. i, Vector3.new(0.7, 1.1, 0.25), CFrame.new(sc + off) * CFrame.Angles(0, 0, -a), C.gold, "Studs")
end

-- ===== confetti emitters (VFX attaches here) and the wide shot camera =====
local fx = model("FX")
for i, x in ipairs({ -10, -4, 4, 10 }) do
	local p = brick(fx, "Confetti" .. i, Vector3.new(1, 1, 1), at(x, BH + 16, 0), C.cyan, "Smooth", { Transparency = 1, CanCollide = false, CanQuery = false })
	p:SetAttribute("Confetti", true)
end
brick(root, "CamWide", Vector3.new(1, 1, 1), CFrame.lookAt(at(0, 7, FRONT * 26), at(0, 5, 0)), C.cyan, "Smooth", { Transparency = 1, CanCollide = false, CanQuery = false })

-- ===== invention: gold laurel sprigs either side of the banner star, a little crown on 1st place's front =====
for _, side in ipairs({ -1, 1 }) do
	local lm = model(if side == 1 then "LaurelL" else "LaurelR", frame)
	for i = 0, 2 do
		brick(lm, "Leaf" .. i, Vector3.new(0.5, 0.9, 0.2), CFrame.new(sc + Vector3.new(side * (1.9 + i * 0.35), -0.6 + i * 0.6, 0)) * CFrame.Angles(0, 0, side * math.rad(30 - i * 15)), C.gold, "Smooth")
	end
end
local crown = model("Crown", root:FindFirstChild("Step1"))
local cz = FRONT * (SD / 2 + 0.09)
brick(crown, "Band", Vector3.new(2.2, 0.5, 0.2), at(0, BH + 5.2 - 0.55, cz), C.gold, "Weld")
for i = -1, 1 do
	brick(crown, "Point" .. (i + 2), Vector3.new(0.45, if i == 0 then 0.7 else 0.5, 0.2), at(i * 0.85, BH + 5.2 - 0.3 + (if i == 0 then 0.35 else 0.25), cz), C.gold, "Smooth")
end

root.PrimaryPart = base:FindFirstChild("Plinth")
root.Parent = workspace -- built in place for QA; moved to ServerStorage (disabled) after the checks
CHS:SetWaypoint("HOS-PTS-001 podium: built")
local n = 0
for _, d in ipairs(root:GetDescendants()) do if d:IsA("BasePart") then n += 1 end end
return "parts " .. n