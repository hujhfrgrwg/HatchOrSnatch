--!nocheck
-- IncubatorWorld (HOS-INC-001, 17 Oct 2026, Matthew): the lobby incubator (workspace.Incubator.Incubator), client side.
--   idle      the egg turns and bobs over its pedestal, the orbit ring precesses, the floating crystals circle and bob,
--             the lanterns sway on their chains and the neon (strips, beams, runes, sign, base disc, ring) breathes
--   your egg  every player sees their own egg, a cracked-shell puzzle (EggPieces): SLOTS pieces that fit together,
--             placed bottom up, one per FILL / SLOTS of fill, each wearing the rarity of the shard that filled it
--             (ProfileState incubator.shards; the EggShardKit look). Until it's whole, a hologram egg (the model's wedge
--             shell as ForceField) shows what's being built and the core glows brighter as it fills; a ready egg is
--             whole, the hologram fades and it glows gold
--   walk-up   stepping onto the platform opens the incubator screen (EggUIController's openIncubator); walking away
--             closes it. Shards earned since the last visit (incubator.unseen) first fly from the player's back to the
--             egg one by one and their pieces snap into the puzzle; then EOS_Egg.SeenShards clears them on the server
--   hatch     a hatched egg's pieces burst outward and fade, then the next egg starts (from the new fill)
-- Everything here is local: the server's parts never move. Reduce effects keeps the egg building and the screen
-- opening but drops trails, motes and bursts. Hook (one line in EggUIController.init):
--   IncubatorWorld.init({ view = () -> incubator view, open = openIncubator, ui = EggUI's UI module, remotes = EOS_Egg })
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local EggConfig = require(Shared:WaitForChild("EggConfig"))
local Net = require(Shared:WaitForChild("Net"))
local EggPieces = require(script:WaitForChild("EggPieces"))

local player = Players.LocalPlayer
local World = {}

local OPEN_RADIUS, CLOSE_RADIUS = 11, 14 -- studs from the egg's axis (the platform is 15 x 15)
local ANIM_RANGE = 260 -- the camera must be this close for the idle animation to run
local SLOTS = EggPieces.COUNT -- puzzle pieces (EggConfig.INCUBATOR.FILL is 18: one fill each)
local SNAP = 1.6 -- studs out from its place a piece appears before it snaps in
local HOLO = Color3.fromRGB(190, 130, 255)
local GOLD = Color3.fromRGB(255, 210, 58)

local deps: any = {}
local S: any = nil -- the bound model's state (rebuilt when the model streams in again)
local EGG: any = nil -- the puzzle egg (EggPieces.build), made once and kept across rebinds
local VFX: any = nil
local Sound: any = nil

local displayFill = 0 -- the fill the egg shows (lags the real fill while unseen shards are still to fly in)
local near = false
local openedByWalk = false
local playing = false
local seenPending = 0 -- os.clock() of the last SeenShards (wait for the profile to clear the list)
local bursting: number? = nil -- os.clock() a hatch burst started

local function colorOf(r: string?): Color3
	local i = r and EggConfig.RARITY_INFO[r]
	return if i then Color3.fromRGB(i.rgb[1], i.rgb[2], i.rgb[3]) else Color3.new(1, 1, 1)
end

local function reduceEffects(): boolean
	local ok, CameraFX = pcall(function()
		return require(script.Parent:FindFirstChild("CameraFX"))
	end)
	return ok and type(CameraFX) == "table" and CameraFX.reduceEffects == true
end

local function inMatch(): boolean
	return player:GetAttribute("EOS_InMatch") == true
end

local function view(): any
	local v = deps.view and deps.view()
	return if type(v) == "table" and type(v.need) == "number" and v.need > 0 then v else nil
end

local function unseenOf(v: any): { string }
	return if v and type(v.unseen) == "table" then v.unseen else {}
end

local function unseenWaiting(): boolean
	return os.clock() - seenPending > 5
end

-- the fill the egg should show right now: the real fill minus shards that haven't flown in yet
local function restingFill(v: any): number
	if not v then return 0 end
	local f = v.fill or 0
	if unseenWaiting() then
		for _, r in unseenOf(v) do
			f -= EggConfig.SHARD_WEIGHT[r] or 0
		end
	end
	return math.max(0, f)
end

-- the shards in the egg as it rests, low rarities first (the unseen ones are left out: they fly in last)
local function restingShards(v: any): { string }
	local count = {}
	for _, r in EggConfig.RARITIES do
		count[r] = (v and type(v.shards) == "table" and tonumber(v.shards[r])) or 0
	end
	if unseenWaiting() then
		for _, r in unseenOf(v) do
			count[r] = math.max(0, (count[r] or 0) - 1)
		end
	end
	local out = {}
	for _, r in EggConfig.RARITIES do
		for _ = 1, count[r] do table.insert(out, r) end
	end
	return out
end

-- which rarity each slot shows: slot k is the shard covering fill (k - 0.5) of the egg's SLOTS
local function slotRarities(list: { string }, need: number): { string }
	local out = {}
	local per = need / SLOTS
	local acc, j = 0, 0
	local last = list[#list] or "rare"
	for k = 1, SLOTS do
		local at = (k - 0.5) * per
		while j < #list and acc + (EggConfig.SHARD_WEIGHT[list[j + 1]] or 0) < at do
			j += 1
			acc += EggConfig.SHARD_WEIGHT[list[j]] or 0
		end
		out[k] = list[j + 1] or last
	end
	return out
end

---------------------------------------------------------------- binding the model
local function partsOf(inst: Instance?): { BasePart }
	local out = {}
	if not inst then return out end
	if inst:IsA("BasePart") then table.insert(out, inst) end
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then table.insert(out, d) end
	end
	return out
end

local function group(list: { BasePart }): any
	local g = { parts = list, rest = {} }
	for i, p in list do g.rest[i] = p.CFrame end
	return g
end

local function findModel(): Model?
	local f = workspace:FindFirstChild("Incubator")
	local m = f and f:FindFirstChild("Incubator")
	return if m and m:IsA("Model") then m else nil
end

local function unbind()
	if not S then return end
	if S.anchor then S.anchor:Destroy() end
	if EGG then EGG.model.Parent = nil end -- hidden until the incubator streams back in
	S = nil
end

local function bind(m: Model)
	local s: any = { model = m }
	local core = m:FindFirstChild("A09_EggCore")
	if not core then return nil end
	local ccf = (core :: Model):GetBoundingBox()
	s.E = ccf.Position
	-- the hologram: the model's wedge shell, as a shimmering ForceField egg
	s.holo = partsOf(m:FindFirstChild("A09_EggShards"))
	for _, p in s.holo do
		p.Material = Enum.Material.ForceField
		p.Color = HOLO
		p.Transparency = 0
		p.CastShadow = false
	end
	-- the real egg: the puzzle pieces, hidden until filled (they ride the egg's turn in step)
	s.slots = {}
	if EGG then
		for i, pc in EGG.pieces do
			s.slots[i] = pc
			for k, p in pc.parts do p.CFrame = CFrame.new(s.E) * pc.locals[k] end
		end
		EGG.model.Parent = workspace
	end
	s.core = partsOf(core) -- fades in as the egg fills
	-- the egg turns and bobs as one: hologram, core and its light (and the pieces)
	local eggParts = {}
	for _, p in s.holo do table.insert(eggParts, p) end
	for _, p in s.core do table.insert(eggParts, p) end
	for _, p in partsOf(m:FindFirstChild("A09_EggLight_OPTIONAL")) do table.insert(eggParts, p) end
	s.egg = group(eggParts)
	s.ring = group(partsOf(m:FindFirstChild("A09_OrbitRings_OPTIONAL")))
	s.float = group(partsOf(m:FindFirstChild("A09_FloatShards")))
	-- lanterns swing from the top of their chains
	s.lanterns = {}
	for i, side in { "Left", "Right" } do
		local chain = m:FindFirstChild("A09_Lantern" .. side .. "_Chain")
		if chain then
			local list = {}
			for _, nm in { "_Frame", "_Glass", "_Chain", "_Light_OPTIONAL" } do
				for _, p in partsOf(m:FindFirstChild("A09_Lantern" .. side .. nm)) do table.insert(list, p) end
			end
			local cf, sz = (chain :: Model):GetBoundingBox()
			local g = group(list)
			g.pivot = cf.Position + Vector3.new(0, sz.Y / 2, 0)
			g.phase = i * 1.7
			table.insert(s.lanterns, g)
		end
	end
	-- neon that breathes (base transparency kept)
	s.neon = {}
	for _, nm in { "A09_NeonStrip_L", "A09_NeonStrip_R", "A09_NeonBeams", "A09_Rune_L", "A09_Rune_R", "A09_SignGlow", "A09_CoreEmitter", "A09_OrbitRings_OPTIONAL", "A09_FloatShards" } do
		for _, p in partsOf(m:FindFirstChild(nm)) do
			if p.Material == Enum.Material.Neon then table.insert(s.neon, { p = p, t = p.Transparency }) end
		end
	end
	-- lights
	local function light(nm)
		local holder = m:FindFirstChild(nm)
		local l = holder and holder:FindFirstChildWhichIsA("PointLight")
		return if l then { l = l, b = l.Brightness, c = l.Color } else nil
	end
	s.eggLight = light("A09_EggLight_OPTIONAL")
	s.coreLight = light("A09_CoreLight_OPTIONAL")
	-- a local anchor at the egg for glow motes and bursts
	local anchor = Instance.new("Part")
	anchor.Name = "IncubatorFX"
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch, anchor.CastShadow = true, false, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(s.E)
	anchor.Parent = workspace.CurrentCamera
	s.anchor = anchor
	return s
end

---------------------------------------------------------------- the egg (your fill)
local function setSlot(i: number, rarity: string?, animate: boolean, pop: boolean?)
	local sl = S and S.slots[i]
	if not sl then return end
	if rarity and rarity ~= sl.rarity then
		local kit = ReplicatedStorage:FindFirstChild("EggShardKit")
		local sa = kit and kit:FindFirstChild("SA_" .. rarity)
		for _, p in sl.parts do
			if p:IsA("MeshPart") then -- the shard atlas
				local old = p:FindFirstChildOfClass("SurfaceAppearance")
				if old then old:Destroy() end
				if sa then sa:Clone().Parent = p end
			else -- wedge fallback: the rarity's colour
				p.Color = colorOf(rarity)
			end
		end
	end
	local was = sl.rarity
	sl.rarity = rarity
	local t = if rarity then 0 else 1
	for _, p in sl.parts do
		if animate and (was == nil) ~= (rarity == nil) then
			TweenService:Create(p, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = t }):Play()
		else
			p.Transparency = t
		end
	end
	if pop and rarity then sl.popAt = os.clock() end -- appears SNAP studs out and snaps into its place (step)
end

local function placedFor(fill: number, need: number): number
	if fill >= need - 1e-9 then return SLOTS end
	return math.clamp(math.floor(SLOTS * fill / need + 0.5), 0, SLOTS - 1) -- never whole until it's really ready
end

local function ready(): boolean
	local v = view()
	return v ~= nil and displayFill >= v.need - 1e-9
end

local function setHologram(on: boolean, animate: boolean)
	if not S then return end
	for _, p in S.holo do
		local goal = { Transparency = if on then 0 else 1 }
		if animate then
			TweenService:Create(p, TweenInfo.new(0.6), goal):Play()
		else
			p.Transparency = goal.Transparency
		end
	end
end

local function applyEgg(animate: boolean)
	if not S then return end
	local v = view()
	local need = if v then v.need else 1
	local n = placedFor(displayFill, need)
	local rar = slotRarities(restingShards(v), need)
	for i = 1, SLOTS do
		local keep = S.slots[i] and S.slots[i].rarity -- a placed slot keeps its look (a hatch clears them)
		setSlot(i, if i <= n then (keep or rar[i]) else nil, animate)
	end
	setHologram(n < SLOTS, animate)
	-- the core glows brighter through the cracks as it fills; a whole egg hides it (it's taller than the egg, and the
	-- ready glow takes over)
	local frac = math.clamp(displayFill / need, 0, 1)
	for _, p in S.core do
		local goal = { Transparency = if n == SLOTS then 1 else 0.3 + 0.55 * (1 - frac) }
		if animate then
			TweenService:Create(p, TweenInfo.new(0.4), goal):Play()
		else
			p.Transparency = goal.Transparency
		end
	end
	-- a ready egg glows gold, with motes when effects are on
	local isReady = v ~= nil and n == SLOTS
	if S.eggLight then
		S.eggLight.l.Color = if isReady then GOLD else S.eggLight.c
	end
	local glow = S.anchor and S.anchor:FindFirstChild("ReadyGlow")
	if isReady and not glow and S.anchor and not reduceEffects() then
		local tpl = ReplicatedStorage:FindFirstChild("VFX") and ReplicatedStorage.VFX:FindFirstChild("EggGlow")
		local att = tpl and tpl:FindFirstChild("EggGlow", true)
		if att then
			glow = att:Clone()
			glow.Name = "ReadyGlow"
			for _, d in glow:GetDescendants() do
				if d:IsA("ParticleEmitter") then
					d.Color = ColorSequence.new(GOLD)
					d.Rate = 6
				elseif d:IsA("PointLight") then
					d.Color, d.Brightness, d.Range, d.Enabled = GOLD, 1.4, 10, true
				end
			end
			glow.Parent = S.anchor
		end
	elseif not isReady and glow then
		glow:Destroy()
	end
end

---------------------------------------------------------------- effects
local function burstAt(cf: CFrame, color: Color3, name: string?)
	if not (VFX and S and S.anchor) or reduceEffects() then return end
	local tpl = ReplicatedStorage:FindFirstChild("VFX") and ReplicatedStorage.VFX:FindFirstChild(name or "EggBurst")
	local att = tpl and tpl:FindFirstChild(name or "EggBurst", true)
	if not att then return end
	att = att:Clone()
	for _, d in att:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			d.Color = ColorSequence.new(color)
		elseif d:IsA("PointLight") then
			d.Color = color
		end
	end
	att.Parent = S.anchor
	att.WorldCFrame = cf
	VFX.emit(att)
	Debris:AddItem(att, 2.5)
end

local function play(name: string, pitch: number?)
	if Sound then pcall(Sound.play, name, pitch) end
end

-- the egg's turn and bob at time t (applied to its rest CFrames)
local function eggT(t: number): (CFrame, number)
	local E = S.E
	local bob = math.sin(t * 2 * math.pi / 3.2) * 0.18
	return CFrame.new(E + Vector3.new(0, bob, 0)) * CFrame.Angles(0, t * math.rad(18), 0) * CFrame.new(-E), bob
end

-- one shard: from the player's back, up in an arc to just outside the egg's next empty piece, which snaps in
local function flyShard(rarity: string, index: number, v: any)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not (S and hrp) then return end
	local col = colorOf(rarity)
	local kit = ReplicatedStorage:FindFirstChild("EggShardKit")
	local tpl = kit and kit:FindFirstChild("Shard")
	local proj: BasePart
	if tpl and tpl:IsA("BasePart") then
		proj = tpl:Clone()
		local sa = kit:FindFirstChild("SA_" .. rarity)
		if sa then sa:Clone().Parent = proj end
	else
		proj = Instance.new("Part")
		proj.Size = Vector3.new(0.7, 1.4, 0.7)
		proj.Material = Enum.Material.Neon
		proj.Color = col
	end
	proj.Name = "IncubatorShardFlight"
	proj.Anchored, proj.CanCollide, proj.CanQuery, proj.CanTouch, proj.CastShadow = true, false, false, false, false
	local startSize = proj.Size * 1.3
	proj.Size = startSize
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range, light.Shadows = col, 1.6, 7, false
	light.Parent = proj
	if not reduceEffects() then
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position, a1.Position = Vector3.new(0, 0.5, 0), Vector3.new(0, -0.5, 0)
		a0.Parent, a1.Parent = proj, proj
		local tr = Instance.new("Trail")
		tr.Attachment0, tr.Attachment1 = a0, a1
		tr.Color = ColorSequence.new(col, Color3.new(1, 1, 1))
		tr.Transparency = NumberSequence.new(0.1, 1)
		tr.LightEmission = 1
		tr.Lifetime = 0.35
		tr.FaceCamera = true
		tr.Parent = proj
	end
	local start = hrp.Position - hrp.CFrame.LookVector * 0.7 + Vector3.new(0, 1, 0)
	proj.CFrame = CFrame.new(start)
	proj.Parent = workspace
	play("ability", 1.1 + index * 0.04)
	-- the slots this shard fills (between the egg before and after its weight)
	local before = placedFor(displayFill, v.need)
	displayFill = math.min(displayFill + (EggConfig.SHARD_WEIGHT[rarity] or 0), v.fill)
	local after = placedFor(displayFill, v.need)
	local target = S.slots[math.clamp(before + 1, 1, SLOTS)]
	local t0 = os.clock()
	local dist = (start - S.E).Magnitude
	local dur = math.clamp(dist / 20, 0.8, 1.4)
	local spinAxis = Vector3.new(0.3, 1, 0.2).Unit
	while true do
		local now = os.clock()
		local a = math.min(1, (now - t0) / dur)
		local e = 1 - (1 - a) ^ 2 -- ease out
		if not S then break end
		local goal = eggT(now) * (S.E + (if target then target.centre + target.out * SNAP else Vector3.zero))
		local mid = (start + goal) / 2 + Vector3.new(0, 7, 0)
		local p = (1 - e) ^ 2 * start + 2 * (1 - e) * e * mid + e ^ 2 * goal
		proj.CFrame = CFrame.new(p) * CFrame.fromAxisAngle(spinAxis, a * math.pi * 4)
		-- the last quarter: shrinks into a spark as its piece appears
		local k = math.clamp((a - 0.75) / 0.25, 0, 1)
		if k > 0 then proj.Size = startSize * (1 - 0.8 * k) end
		if a >= 1 then break end
		RunService.RenderStepped:Wait()
	end
	proj:Destroy()
	if not S then return end
	-- lock in: this shard's pieces snap into the puzzle in its rarity
	for i = before + 1, after do
		setSlot(i, rarity, true, true)
		task.wait(0.06)
	end
	burstAt(CFrame.new(S.E), col, "EggPulse")
	play("gem", 1 + 0.08 * index)
end

local function flyIn(v: any, list: { string })
	playing = true
	for i, r in list do
		if not S then break end
		flyShard(r, i, v)
		task.wait(0.15)
	end
	seenPending = os.clock()
	displayFill = v.fill or displayFill
	applyEgg(true)
	if ready() then
		burstAt(CFrame.new(S and S.E or Vector3.zero), GOLD, "EggBurst")
		play("evolve", 1.2)
	end
	if deps.remotes and deps.remotes:FindFirstChild("SeenShards") then
		deps.remotes.SeenShards:FireServer()
	end
	playing = false
end

---------------------------------------------------------------- walk-up
local function openScreen()
	if near and not inMatch() and deps.open then
		openedByWalk = true
		deps.open()
	end
end

local function closeScreen()
	if not openedByWalk then return end
	openedByWalk = false
	local ui = deps.ui
	if ui and ui.current then
		local cur = ui.current()
		if cur == "EggIncubator" or cur == "EggFirstPet" then ui.close() end
	end
end

local function checkNear()
	if not S then return end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp or inMatch() then
		if near then near = false closeScreen() end
		return
	end
	local d = hrp.Position - S.E
	local flat = Vector3.new(d.X, 0, d.Z).Magnitude
	local inside = flat < (if near then CLOSE_RADIUS else OPEN_RADIUS) and math.abs(d.Y) < 12
	if inside and not near then
		near = true
		local v = view()
		local list = unseenOf(v)
		if v and #list > 0 and not playing and unseenWaiting() then
			task.spawn(function()
				flyIn(v, table.clone(list))
				openScreen()
			end)
		elseif not playing then
			openScreen()
		end
	elseif not inside and near then
		near = false
		closeScreen()
	end
end

---------------------------------------------------------------- the hatch burst
local function onHatch(t: any)
	if not (type(t) == "table" and t.ok and t.incubator and S) then return end
	bursting = os.clock()
	for _, sl in S.slots do
		sl.popAt = nil
		for _, p in sl.parts do
			TweenService:Create(p, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
		end
	end
	burstAt(CFrame.new(S.E), GOLD, "EggBurst")
	task.delay(1.1, function()
		bursting = nil
		displayFill = restingFill(view())
		if S then
			for _, sl in S.slots do sl.rarity = nil end
			applyEgg(true)
		end
	end)
end

---------------------------------------------------------------- the frame loop
local neonAcc = 0
local function step(dt: number)
	-- (re)bind when the model streams in again
	local m = findModel()
	if not S or S.model ~= m or not (S.model and S.model:IsDescendantOf(workspace)) then
		unbind()
		S = if m then bind(m) else nil
		if S then
			displayFill = restingFill(view())
			applyEgg(false)
		end
	end
	if not S then return end
	local cam = workspace.CurrentCamera
	if not cam or (cam.CFrame.Position - S.E).Magnitude > ANIM_RANGE then return end
	local t = os.clock()
	local E = S.E
	local parts, cfs = {}, {}
	local function add(g, T)
		for i, p in g.parts do
			table.insert(parts, p)
			table.insert(cfs, T * g.rest[i])
		end
	end
	-- egg: slow turn + bob
	local Tegg, bob = eggT(t)
	add(S.egg, Tegg)
	-- its pieces: a new one snaps in from SNAP studs out; a hatch throws them all outward, tumbling, while they fade
	local k = if bursting then math.min(1, (t - bursting) / 0.7) else 0
	for i, sl in S.slots do
		local off, spin = 0, CFrame.identity
		if k > 0 then
			off = k * 3.5
			spin = CFrame.Angles(k * (1 + i % 3), k * (i % 2 - 0.5) * 2, 0)
		elseif sl.popAt then
			local a = (t - sl.popAt) / 0.35
			if a >= 1 then
				sl.popAt = nil
			else
				off = SNAP * (1 - a) ^ 3
			end
		end
		local C = CFrame.new(E + sl.centre + sl.out * off) * spin * CFrame.new(-sl.centre) -- tumble about the piece's centre
		for j, p in sl.parts do
			table.insert(parts, p)
			table.insert(cfs, Tegg * C * sl.locals[j])
		end
	end
	-- ring precesses the other way, riding the bob
	add(S.ring, CFrame.new(E + Vector3.new(0, bob, 0)) * CFrame.Angles(0, -t * math.rad(40), 0) * CFrame.new(-E))
	-- floating crystals circle, bob and spin on their own
	local Torbit = CFrame.new(E) * CFrame.Angles(0, t * math.rad(25), 0) * CFrame.new(-E)
	for i, p in S.float.parts do
		local r = S.float.rest[i]
		local own = CFrame.new(r.Position + Vector3.new(0, math.sin(t * 1.7 + i) * 0.25, 0)) * r.Rotation * CFrame.Angles(0, t * math.rad(60) + i, 0)
		table.insert(parts, p)
		table.insert(cfs, Torbit * own)
	end
	-- lanterns sway from their chain tops
	for _, g in S.lanterns do
		local P = g.pivot
		add(g, CFrame.new(P) * CFrame.Angles(math.sin(t * 1.9 + g.phase) * math.rad(3.5), 0, math.sin(t * 1.3 + g.phase) * math.rad(2.5)) * CFrame.new(-P))
	end
	workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	if S.anchor then S.anchor.CFrame = CFrame.new(E + Vector3.new(0, bob, 0)) end
	-- neon + lights breathe (15 Hz is plenty)
	neonAcc += dt
	if neonAcc >= 1 / 15 then
		neonAcc = 0
		local b = 0.5 + 0.5 * math.sin(t * 1.6)
		for _, n in S.neon do
			n.p.Transparency = math.min(0.9, n.t + 0.25 * b)
		end
		if S.eggLight then
			S.eggLight.l.Brightness = S.eggLight.b * (if ready() then 2.2 else 1) * (0.8 + 0.4 * b)
		end
		if S.coreLight then S.coreLight.l.Brightness = S.coreLight.b * (0.8 + 0.4 * b) end
	end
end

---------------------------------------------------------------- init
local lastKey = ""
function World.init(d: any)
	if not EggConfig.ENABLED then return end
	deps = d or {}
	local okEgg, egg = pcall(EggPieces.build, nil)
	if okEgg then
		EGG = egg
	else
		warn("IncubatorWorld: egg pieces failed:", egg)
	end
	local ok, e = pcall(require, ReplicatedStorage:WaitForChild("VFX"):WaitForChild("Emit"))
	VFX = if ok then e else nil
	local ok2, s = pcall(require, script.Parent:WaitForChild("Sound", 5))
	Sound = if ok2 then s else nil
	Net.event("HatchResult").OnClientEvent:Connect(onHatch)
	RunService.RenderStepped:Connect(step)
	-- the profile (fill, need, shards, unseen) and the walk-up, a few times a second
	task.spawn(function()
		while true do
			task.wait(0.15)
			local v = view()
			if S and v and not playing and not bursting then
				local key = ("%s|%s|%s|%d"):format(tostring(v.fill), tostring(v.need), table.concat(restingShards(v), ","), #unseenOf(v))
				if key ~= lastKey then
					lastKey = key
					displayFill = restingFill(v)
					applyEgg(true)
				end
			end
			checkNear()
		end
	end)
end

return World
