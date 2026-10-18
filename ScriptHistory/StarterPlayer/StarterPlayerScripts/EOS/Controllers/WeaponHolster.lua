--!strict
-- WeaponHolster (HOS-HOLSTER-001): an equipped weapon that isn't being used is carried on the body,
-- not in the hand (developer, Oct 17: "knife ... on your hip. obviously if its a scythe or a sword or
-- something its on your back").
--  * Client only, looks only: every character this client sees (you, other players, NPCs) that has a
--    weapon part (attribute EOS_Knife, EOS_Weapon or HolsterSlot) gets a local copy of it welded to
--    the torso. The real weapon, its joint, stats and clips are never touched.
--  * Slot: the weapon's HolsterSlot attribute, "Hip" or "Back". Unmarked: "Back" when it is longer
--    than BACK_MIN_LENGTH, else "Hip".
--      Hip  = across the lower back at the belt, hilt at the right hip, blade out past the left hip.
--      Back = diagonal across the back, handle up over the right shoulder (where the right hand
--             reaches back and up to draw it), blade down toward the left hip (developer, Oct 17).
--    Both sit below / behind an egg carried on the back when there is one.
--  * In use = the clip is moving the weapon's joint (the swing / lunge clips pose it; idle and run
--    don't), plus a short hold so it doesn't flicker. In use: the hand weapon shows, the copy hides.
--    Otherwise the reverse (Transparency set on this client only, so LocalTransparencyModifier stays
--    free for Invisibility and the camera; the hand weapon's trails are paused while it is put away).
--  * R6 (Torso) and R15 (LowerTorso for Hip, UpperTorso for Back).
-- Started by StarterPlayerScripts.EOS.WeaponHolsterBoot. WeaponHolster.attach(character, weapon) also
-- works on its own (e.g. a ViewportFrame preview), returning a function that removes the copy.

local RunService = game:GetService("RunService")

local WeaponHolster = {}

local BACK_MIN_LENGTH = 4 -- studs: longer than this goes on the back unless HolsterSlot says otherwise
local HOLD_TIME = 0.15 -- seconds the weapon stays in the hand after its joint stops moving
local MOVE_EPS = 1e-3

type Entry = {
	weapon: BasePart,
	character: Model,
	copy: BasePart?,
	motor: Motor6D?,
	nextMotorLook: number,
	lastUse: number,
	born: number,
	baseT: number,
	shown: boolean?, -- true = in the hand, false = holstered, nil = not decided yet
	trails: { [Instance]: boolean },
}

local entries: { [BasePart]: Entry } = {}

local function isWeapon(inst: Instance): boolean
	return inst:IsA("BasePart")
		and not inst:GetAttribute("EOS_Holstered")
		and (inst:GetAttribute("EOS_Knife") ~= nil or inst:GetAttribute("EOS_Weapon") ~= nil or inst:GetAttribute(
			"HolsterSlot"
		) ~= nil)
end

local function slotOf(weapon: BasePart): string
	local s = weapon:GetAttribute("HolsterSlot")
	if s == "Hip" or s == "Back" or s == "HipLeft" then -- HipLeft: a dual-wield skin's left blade (HOS-WEP-001)
		return s
	end
	local size = weapon.Size
	return if math.max(size.X, size.Y, size.Z) > BACK_MIN_LENGTH then "Back" else "Hip"
end

-- the weapon's own axes: long (pointing at the handle), thin (the flat of the blade) and the third
local function weaponAxes(weapon: BasePart, grip: Vector3?): (Vector3, Vector3, number, number)
	-- HOS-WEP-001 dagger skins carry their own axes (several welded parts: the main part's box isn't the blade)
	local tip, thinA = weapon:GetAttribute("SkinTip"), weapon:GetAttribute("SkinThin")
	if typeof(tip) == "Vector3" and typeof(thinA) == "Vector3" then
		return -tip, thinA, (weapon:GetAttribute("SkinLength") :: number?) or 3, 0.2
	end
	local s = weapon.Size
	local axes = {
		{ v = Vector3.xAxis, n = s.X },
		{ v = Vector3.yAxis, n = s.Y },
		{ v = Vector3.zAxis, n = s.Z },
	}
	table.sort(axes, function(a, b)
		return a.n > b.n
	end)
	local long, thin = axes[1].v, axes[3].v
	-- the handle end: the end the hand is at (`grip`, the hand in the weapon's space); no joint, the -long end
	local sign = if grip and grip:Dot(long) > 0 then 1 else -1
	return long * sign, thin, axes[1].n, axes[3].n
end

-- the egg on the back, if any: its lowest point and furthest-back point in `body`'s space
local function eggExtent(character: Model, body: BasePart): (number?, number?)
	for _, c in ipairs(character:GetChildren()) do
		if c:IsA("Model") and c:GetAttribute("EOS_Egg") then
			local cf, size = c:GetBoundingBox()
			local rel = body.CFrame:ToObjectSpace(cf)
			local half = size / 2
			-- extent of the box along the body's Y and Z
			local r = rel.Rotation
			local ey = math.abs(r.RightVector.Y) * half.X + math.abs(r.UpVector.Y) * half.Y + math.abs(-r.LookVector.Y) * half.Z
			local ez = math.abs(r.RightVector.Z) * half.X + math.abs(r.UpVector.Z) * half.Y + math.abs(-r.LookVector.Z) * half.Z
			return rel.Position.Y - ey, rel.Position.Z + ez
		end
	end
	return nil, nil
end

local function findMotor(character: Model, weapon: BasePart): Motor6D?
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("Motor6D") and d.Part1 == weapon then
			return d
		end
	end
	return nil
end

-- where the copy sits, relative to the body part it is welded to
local function holsterOffset(character: Model, weapon: BasePart, body: BasePart, grip: Vector3?, slot: string): CFrame
	local toHandle, thin, length, thickness = weaponAxes(weapon, grip)
	local eggBottom, eggBack = eggExtent(character, body)
	local backZ = body.Size.Z / 2 + thickness / 2 + 0.05
	local pos: Vector3
	local handleDir: Vector3
	if slot == "Back" then
		-- handle up over the right shoulder, blade down toward the left hip (~35 deg off vertical)
		local a = math.rad(35)
		handleDir = Vector3.new(math.sin(a), math.cos(a), 0)
		-- high on the back so the blade's tip stays clear of the swinging legs; a little off the back
		local z = if eggBack then math.max(backZ + 0.1, eggBack + thickness / 2 + 0.1) else backZ + 0.1
		pos = Vector3.new(0.05, body.Size.Y * 0.35, z)
	else
		-- across the lower back at the belt: hilt at the right hip, a little up; blade past the left hip
		local a = math.rad(18)
		handleDir = Vector3.new(math.cos(a), math.sin(a), 0)
		local y = -body.Size.Y * 0.42
		if eggBottom then
			y = math.min(y, eggBottom - 0.3)
		end
		-- the handle end sits just past the right edge of the body
		local x = body.Size.X / 2 + 0.25 - (length / 2) * math.cos(a)
		pos = Vector3.new(x, y, backZ)
		if slot == "HipLeft" then -- the mirror image: hilt at the left hip, a little further off the back
			handleDir = Vector3.new(-handleDir.X, handleDir.Y, 0)
			pos = Vector3.new(-x, y, backZ + thickness + 0.02)
		end
	end
	-- turn the weapon so its handle points handleDir and the flat of the blade lies on the back (+Z)
	local want = CFrame.fromMatrix(Vector3.zero, handleDir, Vector3.zAxis)
	local have = CFrame.fromMatrix(Vector3.zero, toHandle, thin)
	local center = weapon:GetAttribute("SkinCenter") -- skins: the whole blade's middle, not the main part's
	return CFrame.new(pos) * want * have:Inverse() * CFrame.new(-(if typeof(center) == "Vector3" then center else Vector3.zero))
end

-- where the hand is, in the weapon's own space: the bottom of the arm / hand part the joint hangs off,
-- carried through the joint (its pivot can sit well off the grip: the Minute Dagger's is 1.8 studs ahead)
function WeaponHolster.gripOf(motor: Motor6D?): Vector3?
	local p0 = motor and motor.Part0
	if not motor or not p0 then
		return nil
	end
	return (motor.C1 * motor.C0:Inverse()) * Vector3.new(0, -p0.Size.Y / 2, 0)
end

local function bodyFor(character: Model, slot: string): BasePart?
	local torso = character:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		return torso
	end
	local name = if slot == "Back" then "UpperTorso" else "LowerTorso"
	local p = character:FindFirstChild(name) or character:FindFirstChild("UpperTorso")
	return if p and p:IsA("BasePart") then p else nil
end

-- a local copy of `weapon` on `character`'s body. Returns the copy and a function that removes it.
function WeaponHolster.attach(character: Model, weapon: BasePart, grip: Vector3?): (BasePart?, () -> ())
	local slot = slotOf(weapon)
	local body = bodyFor(character, slot)
	if not body then
		return nil, function() end
	end
	local copy = weapon:Clone()
	local function visual(d: Instance): boolean
		return d:IsA("SurfaceAppearance") or d:IsA("Decal") or d:IsA("Texture") or d:IsA("SpecialMesh")
	end
	for _, d in ipairs(copy:GetChildren()) do
		-- keep only what draws the mesh (+ a dagger skin's welded parts, HOS-WEP-001)
		if d:IsA("BasePart") and d:FindFirstChild("SkinWeld") then
			for _, k in ipairs(d:GetChildren()) do
				if k.Name ~= "SkinWeld" and not visual(k) then
					k:Destroy()
				end
			end
			d.Transparency = (d:GetAttribute("EOS_BaseT") :: number?) or 0
			d.CanCollide, d.CanQuery, d.CanTouch, d.Massless = false, false, false, true
		elseif not visual(d) then
			d:Destroy()
		end
	end
	copy.Name = weapon.Name .. "_Holstered"
	copy:SetAttribute("EOS_Knife", nil)
	copy:SetAttribute("EOS_Weapon", nil)
	copy:SetAttribute("EOS_Holstered", true)
	copy:SetAttribute("EOS_Egg", nil) -- (the hand knife carries it for the server; the copy is client-only)
	copy.Anchored = false
	copy.CanCollide = false
	copy.CanQuery = false
	copy.CanTouch = false
	copy.Massless = true
	local offset = holsterOffset(character, weapon, body, grip, slot)
	copy.CFrame = body.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Part0 = body
	weld.Part1 = copy
	weld.C0 = offset
	weld.Parent = copy
	copy.Parent = character
	return copy, function()
		copy:Destroy()
	end
end

local function setTrails(e: Entry, on: boolean)
	for _, d in ipairs(e.weapon:GetDescendants()) do
		if d:IsA("Trail") or d:IsA("ParticleEmitter") then
			if e.trails[d] == nil then
				e.trails[d] = (d :: any).Enabled
			end
			;(d :: any).Enabled = on and e.trails[d]
		end
	end
end

-- a dagger skin's welded parts follow the main part: shown at their own transparency, or hidden
local function showKids(root: BasePart, show: boolean)
	for _, d in ipairs(root:GetChildren()) do
		if d:IsA("BasePart") then
			local t = if show then ((d:GetAttribute("EOS_BaseT") :: number?) or 0) else 1
			if d.Transparency ~= t then
				d.Transparency = t
			end
		end
	end
end

local function drop(weapon: BasePart)
	local e = entries[weapon]
	if not e then
		return
	end
	entries[weapon] = nil
	if e.copy then
		e.copy:Destroy()
	end
	if weapon.Parent then
		weapon.Transparency = e.baseT
		showKids(weapon, true)
		setTrails(e, true)
	end
end

local function track(weapon: BasePart)
	if entries[weapon] or not isWeapon(weapon) or weapon:GetAttribute("NoHolster") then
		return -- (NoHolster: effect weapons like Spirit Blast stay in the hand, HOS-WEP-001)
	end
	local character = weapon.Parent
	if not (character and character:IsA("Model") and character:FindFirstChildOfClass("Humanoid")) then
		return
	end
	entries[weapon] = {
		weapon = weapon,
		character = character,
		copy = nil,
		motor = nil,
		nextMotorLook = 0,
		lastUse = -math.huge,
		born = os.clock(),
		baseT = weapon.Transparency,
		shown = nil,
		trails = {},
	}
end

local function inUse(e: Entry, now: number): boolean
	local m = e.motor
	if m then
		local t = m.Transform
		if t.Position.Magnitude > MOVE_EPS or (1 - t.LookVector:Dot(Vector3.new(0, 0, -1))) > MOVE_EPS or (1 - t.UpVector.Y) > MOVE_EPS then
			e.lastUse = now
		end
	end
	local h = e.character:FindFirstChildOfClass("Humanoid")
	if h and h:GetAttribute("EOS_WeaponInUse") == true then
		e.lastUse = now
	end
	return now - e.lastUse < HOLD_TIME
end

local function step()
	local now = os.clock()
	for weapon, e in pairs(entries) do
		if weapon.Parent ~= e.character or not e.character.Parent then
			drop(weapon)
			continue
		end
		if not e.motor or e.motor.Part1 ~= weapon or not e.motor.Parent then
			e.motor = nil
			if now >= e.nextMotorLook then
				e.nextMotorLook = now + 0.5
				e.motor = findMotor(e.character, weapon)
			end
		end
		if not e.copy or not e.copy.Parent then
			if e.motor or now - e.born > 0.6 then -- give the joint a moment to arrive first
				e.copy = WeaponHolster.attach(e.character, weapon, WeaponHolster.gripOf(e.motor))
				e.shown = nil
			end
		end
		local using = inUse(e, now)
		if e.shown ~= using then
			e.shown = using
			setTrails(e, using)
		end
		local handT = if using then e.baseT else 1
		if weapon.Transparency ~= handT then
			weapon.Transparency = handT
		end
		showKids(weapon, using)
		local copy = e.copy
		if copy then
			local copyT = if using then 1 else e.baseT
			if copy.Transparency ~= copyT then
				copy.Transparency = copyT
			end
			showKids(copy, not using)
		end
	end
end

local started = false
function WeaponHolster.start()
	if started then
		return
	end
	started = true
	workspace.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") and isWeapon(d) then
			task.defer(track, d)
		end
	end)
	workspace.DescendantRemoving:Connect(function(d)
		if entries[d :: any] then
			drop(d :: any)
		end
	end)
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("BasePart") and isWeapon(d) then
			track(d)
		end
	end
	-- after the clips have posed the joints this frame, before it is drawn
	RunService.PreSimulation:Connect(step)
end

return WeaponHolster
