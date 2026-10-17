-- hos_stage.lua: Studio edit-mode helpers for pet / ability previews (run once per Studio session with the MCP
-- execute_luau tool; Studio crashes clear _G). Everything it builds lives in Workspace.HOS_Stage (Archivable =
-- false, so it is never saved). Also defines _G.HOS_InstallPet / _G.HOS_ApplyPBR (pet template install).
local S = {}
_G.HOSStage = S
local RS = game.ReplicatedStorage
local Run = game:GetService("RunService")
local IS = game:GetService("InsertService")
local Emit = require(RS.VFX.Emit)
local F = RS.VFX.Abilities
local PetRig = require(RS.EOS.Shared.PetRig:Clone())
S.P = Vector3.new(-40, 0.2, -345)

function S.clear()
	local f = workspace:FindFirstChild("HOS_Stage")
	if f then f:Destroy() end
	local n = Instance.new("Folder"); n.Name = "HOS_Stage"; n.Archivable = false; n.Parent = workspace
	S.folder = n
	return n
end
S.clear()

function S.dummy(at, face)
	local d = workspace.EOS_PetLab.VFXDummy:Clone()
	for _, x in ipairs(d:GetDescendants()) do
		if x:IsA("BaseScript") then x:Destroy() elseif x:IsA("BasePart") then x.Anchored = true; x.CanCollide = false end
	end
	d:PivotTo(CFrame.lookAt(at + Vector3.new(0, 3, 0), at + Vector3.new(0, 3, 0) + (face or Vector3.new(0, 0, -1))))
	d.Parent = S.folder
	return d
end

function S.cam(target, from)
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = CFrame.lookAt(from, target)
	cam.Focus = CFrame.new(target)
end

function S.play(name, cf, folder)
	return Emit.play((folder or F)[name], cf, { parent = S.folder })
end

function S.persist(name, cf)
	local m = F[name]:Clone(); m.Parent = S.folder; m:PivotTo(cf)
	return m
end

function S.slide(model, to, seconds)
	local from = model:GetPivot()
	local rot = from - from.Position
	local t0 = os.clock()
	local conn
	conn = Run.Heartbeat:Connect(function()
		local k = math.min(1, (os.clock() - t0) / seconds)
		model:PivotTo(CFrame.new(from.Position:Lerp(to + Vector3.new(0, 3, 0), k)) * rot)
		if k >= 1 then conn:Disconnect() end
	end)
end

-- build like PetModel.build (rigged branch): template clone scaled to s * BaseScale * RigScale
function S.pet(species, s, level)
	local tpl = RS.EOS.Assets.Pets[species]
	PetRig.prime(tpl, species)
	local m = tpl:Clone()
	m.Name = "PetPreview"
	local prefix = tpl:GetAttribute("Prefix")
	if level < 3 then local x = m:FindFirstChild(prefix .. "L3") if x then x:Destroy() end end
	if level < 2 then local x = m:FindFirstChild(prefix .. "L2") if x then x:Destroy() end end
	m:ScaleTo(s * (tpl:GetAttribute("BaseScale") or 1) * (tpl:GetAttribute("RigScale") or 1))
	m.Parent = S.folder
	return m, PetRig.new(m, species)
end

function S.drive(rig, m)
	task.spawn(function()
		local last = os.clock()
		while m.Parent do
			local now = os.clock()
			rig:step(now - last)
			last = now
			Run.Heartbeat:Wait()
		end
	end)
end

-- a summon like <Species>Pet.summon: pops up at the user's front-right, plays Ability, flash, shrinks away
function S.summon(species, who, level, flashPrefix, flashAt)
	local root = who.HumanoidRootPart
	local m, rig = S.pet(species, 1.35, level or 1)
	local base = m:GetScale()
	rig:play("Ability", 0, rig:length("Ability") / (0.85 * 0.8), 0)
	local t0 = os.clock()
	local flashed = false
	task.spawn(function()
		while true do
			local k = (os.clock() - t0) / 0.85
			if k >= 1 then m:Destroy() return end
			local feetY = root.Position.Y - 3
			local pop = math.min(1, k / 0.15)
			local wp = root.CFrame * Vector3.new(2.1, 0, -1.2)
			local look = root.CFrame.LookVector
			m:PivotTo(CFrame.lookAt(Vector3.new(wp.X, feetY - 0.6 * (1 - pop), wp.Z), Vector3.new(wp.X, feetY, wp.Z) - look))
			local fade = math.clamp((k - 0.8) / 0.2, 0, 1)
			if fade > 0 then m:ScaleTo(base * (1 - 0.7 * fade)) end
			if not flashed and os.clock() - t0 >= (flashAt or 0.36) then
				flashed = true
				local cf, size = m:GetBoundingBox()
				Emit.play(RS.VFX[flashPrefix .. (level or 1)], CFrame.new(cf.Position + Vector3.new(0, size.Y * 0.3, 0)), { parent = S.folder })
			end
			rig:step(1 / 60)
			Run.Heartbeat:Wait()
		end
	end)
	return m
end
function S.beetleSummon(who, level) return S.summon("Bastion Beetle", who, level, "BeetleSummon_L", 0.36) end

function S.tether(templateName, fromModel, toModel, secs)
	local t = F[templateName]
	local made = {}
	local a0 = Instance.new("Attachment"); a0.Parent = fromModel.HumanoidRootPart
	local off = t:GetAttribute("FromOffset"); if typeof(off) == "Vector3" then a0.Position = off end
	local a1 = Instance.new("Attachment"); a1.Parent = toModel.HumanoidRootPart
	table.insert(made, a0); table.insert(made, a1)
	for _, src in ipairs(t:GetDescendants()) do
		if src:IsA("Beam") then local b = src:Clone(); b.Attachment0 = a0; b.Attachment1 = a1; b.Parent = S.folder; table.insert(made, b)
		elseif src:IsA("ParticleEmitter") then local e = src:Clone(); e.Parent = a1; table.insert(made, e) end
	end
	task.delay(secs, function() for _, x in ipairs(made) do x:Destroy() end end)
end

-- a storm ball template rolled along a straight path (dressed like AbilityVFX.DRESS.StormBall)
function S.rollBall(templateName, from, to, speed)
	local m = F[templateName]:Clone()
	local orb = m:FindFirstChild("Orb")
	local root = m:FindFirstChild("Root")
	m.Parent = S.folder
	local d = to - from; local L = d.Magnitude; local dir = d.Unit
	local t0 = os.clock()
	while true do
		local s = math.min(L, (os.clock() - t0) * speed)
		local p = from + dir * s
		root.CFrame = CFrame.lookAt(p, p + dir)
		if orb then orb:PivotTo(CFrame.lookAt(p, p + dir) * CFrame.Angles(-s / 1.2, 0, 0)) end
		if s >= L then break end
		Run.Heartbeat:Wait()
	end
	return m
end

-- install a rigged pet template from an uploaded FBX Model + colour decal ids (keeps the Kitsune's conventions)
function _G.HOS_InstallPet(o)
	local asset = IS:LoadAsset(o.model)
	local m = asset:FindFirstChildWhichIsA("Model")
	m.Parent = nil
	asset:Destroy()
	m.Name = o.species
	for _, n in ipairs({ "InitialPoses", "AnimationController" }) do local x = m:FindFirstChild(n) if x then x:Destroy() end end
	local root = m.RootPart
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("BasePart") then
			for _, d in ipairs(p:GetChildren()) do if d:IsA("Motor6D") then d:Destroy() end end
			p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = true; p.Massless = true
			if p:IsA("MeshPart") then
				local w = Instance.new("WeldConstraint"); w.Name = "RootWeld"; w.Part0 = p; w.Part1 = root; w.Parent = p
				local decal = o.tex[p.Name]
				if decal then
					local d = IS:LoadAsset(decal):FindFirstChildWhichIsA("Decal", true)
					local sa = Instance.new("SurfaceAppearance"); sa.ColorMap = d.Texture; sa.Parent = p
				end
			end
		end
	end
	root.Transparency = 1
	m.PrimaryPart = root
	m:ScaleTo(0.01)
	m:SetAttribute("Species", o.species)
	m:SetAttribute("Prefix", o.prefix)
	m:SetAttribute("RigScale", m:GetScale())
	m:SetAttribute("BaseScale", o.baseScale)
	m:SetAttribute("Tris", o.tris)
	m:SetAttribute("SourceModel", o.model)
	local pets = RS.EOS.Assets.Pets
	local old = pets:FindFirstChild(o.species)
	if old then old:Destroy() end
	m.Parent = pets
	return m
end

-- full PBR SurfaceAppearance per mesh (HOS-PET-014 standard): decal ids -> image content
function _G.HOS_ApplyPBR(m, maps)
	local cache = {}
	local function img(id)
		if not id then return nil end
		if not cache[id] then cache[id] = IS:LoadAsset(id):FindFirstChildWhichIsA("Decal", true).Texture end
		return Content.fromUri(cache[id])
	end
	for part, mp in pairs(maps) do
		local p = m:FindFirstChild(part)
		local sa = p:FindFirstChildOfClass("SurfaceAppearance") or Instance.new("SurfaceAppearance", p)
		if mp.color then sa.ColorMapContent = img(mp.color) end
		if mp.normal then sa.NormalMapContent = img(mp.normal) end
		if mp.rough then sa.RoughnessMapContent = img(mp.rough) end
		if mp.metal then sa.MetalnessMapContent = img(mp.metal) end
		if mp.emit then
			sa.EmissiveMaskContent = img(mp.emit); sa.EmissiveStrength = mp.strength or 1; sa.EmissiveTint = mp.tint or Color3.new(1, 1, 1)
			sa:SetAttribute("BaseEmissive", mp.strength or 1)
		end
	end
end

return "stage ready"
