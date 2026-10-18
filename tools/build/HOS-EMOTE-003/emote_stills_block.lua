-- HOS-EMOTE-003 (18 Oct, Matthew): a still picture of each emote for the crate reel, its reveal card and the
-- Claim flight. There are no 2D emote icons, so the picture is your avatar held in the clip's most expressive
-- keyframe (EOS_Emotes KeyframeSequence, posed by hand: no Animator or WorldModel), built once per emote.
local GuiService = game:GetService("GuiService")
local stills: { [string]: Model } = {}
player.CharacterAppearanceLoaded:Connect(function() table.clear(stills) end)

-- the keyframe that moves the most from the rest pose (the middle 70% of the clip; short clips: any)
local function keyPose(id: string): Keyframe?
	local lib = ReplicatedStorage:FindFirstChild(EmoteConfig.LIBRARY)
	local ks = lib and lib:FindFirstChild(id)
	if not (ks and ks:IsA("KeyframeSequence")) then return nil end
	local frames = ks:GetKeyframes()
	local last = 0
	for _, k in frames do last = math.max(last, (k :: Keyframe).Time) end
	local best, score = nil, -1
	for _, k in frames do
		local kf = k :: Keyframe
		if #frames < 3 or (kf.Time >= last * 0.15 and kf.Time <= last * 0.85) then
			local s = 0
			for _, p in kf:GetDescendants() do
				if p:IsA("Pose") and p.Weight > 0 then
					local _, ang = p.CFrame:ToAxisAngle()
					s += math.abs(ang) + p.CFrame.Position.Magnitude * 0.5
				end
			end
			if s > score then best, score = kf, s end
		end
	end
	return best
end

-- place every part from the root out through its joints (Motor6D poses from the keyframe), then freeze it
local function poseRig(rig: Model, kf: Keyframe?)
	local poses: { [string]: CFrame } = {}
	for _, p in (kf and kf:GetDescendants()) or {} do
		if p:IsA("Pose") and p.Weight > 0 then poses[p.Name] = p.CFrame end
	end
	local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart
	local joints, rigid = {}, {}
	for _, d in rig:GetDescendants() do
		if d:IsA("JointInstance") and d.Part0 and d.Part1 then
			table.insert(joints, d)
		elseif d:IsA("WeldConstraint") and d.Part0 and d.Part1 then
			table.insert(rigid, { a = d.Part0, b = d.Part1, rel = d.Part0.CFrame:ToObjectSpace(d.Part1.CFrame) })
		end
	end
	local placed = { [root] = true }
	local moved = true
	while moved do
		moved = false
		for _, j in joints do
			local a, b = j.Part0 :: BasePart, j.Part1 :: BasePart
			local t = if j:IsA("Motor6D") then poses[b.Name] or CFrame.identity else CFrame.identity
			if placed[a] and not placed[b] then
				b.CFrame = a.CFrame * j.C0 * t * j.C1:Inverse()
				placed[b], moved = true, true
			elseif placed[b] and not placed[a] then
				a.CFrame = b.CFrame * j.C1 * t:Inverse() * j.C0:Inverse()
				placed[a], moved = true, true
			end
		end
		for _, w in rigid do
			if placed[w.a] and not placed[w.b] then
				w.b.CFrame = w.a.CFrame * w.rel
				placed[w.b], moved = true, true
			elseif placed[w.b] and not placed[w.a] then
				w.a.CFrame = w.b.CFrame * w.rel:Inverse()
				placed[w.a], moved = true, true
			end
		end
	end
	for _, d in rig:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		elseif d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Animator") then
			d:Destroy()
		end
	end
end

local function emoteStill(id: string): Model?
	local m = stills[id]
	if m then return m end
	local rig = makeRig()
	if not rig then return nil end
	poseRig(rig, keyPose(id))
	stills[id] = rig
	return rig
end

-- the still in its own ViewportFrame, framed to fit (a little from the side)
local function stillView(id: string): ViewportFrame?
	local m = emoteStill(id)
	if not m then return nil end
	local v = Instance.new("ViewportFrame")
	v.Name = "EmoteStill"
	v.BackgroundTransparency = 1
	v.Ambient = Color3.fromRGB(205, 205, 212)
	v.LightColor = Color3.fromRGB(255, 250, 240)
	v.LightDirection = Vector3.new(0.4, -1, 0.8)
	local rig = m:Clone()
	rig.Parent = v
	local cf, size = rig:GetBoundingBox()
	local r = math.max(size.X, size.Y, size.Z) * 0.5
	local dist = r / math.tan(math.rad(15)) * 1.08
	local a = math.rad(20)
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(-math.sin(a) * dist, r * 0.15, -math.cos(a) * dist), cf.Position)
	cam.Parent = v
	v.CurrentCamera = cam
	return v
end

-- EmoteCrateSpin decorateTile: the still takes the placeholder icon's place on a reel / reveal tile
local function decorateTile(tile: GuiObject, e: any)
	local icon = tile:FindFirstChild("Icon", true)
	if not (icon and icon:IsA("GuiObject")) then return end
	local v = stillView(e.id)
	if not v then return end
	v.Position = icon.Position - UDim2.fromOffset(12, 12)
	v.Size = icon.Size + UDim2.fromOffset(24, 24)
	v.ZIndex = icon.ZIndex
	v.Parent = icon.Parent
	icon.Visible = false
	local sh = icon.Parent and icon.Parent:FindFirstChild("IconShadow")
	if sh and sh:IsA("GuiObject") then sh.Visible = false end
end

-- EmoteCrateSpin onClaim: a new emote's still flies from the reveal card into the HUD's Backpack button
local flyGui: ScreenGui? = nil
local flightEnds = 0
local function centre(g: GuiObject): Vector2
	local sg = g:FindFirstAncestorWhichIsA("ScreenGui")
	local off = if sg and not sg.IgnoreGuiInset then GuiService:GetGuiInset() else Vector2.zero
	return g.AbsolutePosition + g.AbsoluteSize / 2 + off
end
local function flyToBackpack(r: any, big: Instance?)
	if r.isNew == false then return end -- a duplicate refunds Gems instead
	local still = big and big:FindFirstChild("EmoteStill", true)
	local eos = player.PlayerGui:FindFirstChild("EOSUI")
	local target = eos and eos:FindFirstChild("PetsButton", true) -- the HUD rail's BACKPACK
	if not (still and still:IsA("ViewportFrame") and target and target:IsA("GuiObject")) then return end
	local from, size = centre(still), still.AbsoluteSize
	if not flyGui or not flyGui.Parent then
		local g = Instance.new("ScreenGui")
		g.Name = "EOS_EmoteFly"
		g.IgnoreGuiInset = true
		g.ResetOnSpawn = false
		g.DisplayOrder = 20
		g.Parent = player.PlayerGui
		flyGui = g
	end
	local v = still:Clone()
	v.CurrentCamera = v:FindFirstChildOfClass("Camera")
	v.AnchorPoint = Vector2.new(0.5, 0.5)
	v.Position = UDim2.fromOffset(from.X, from.Y)
	v.Size = UDim2.fromOffset(size.X, size.Y)
	v.ZIndex = 1
	v.Parent = flyGui
	local POP, FLY = 0.16, 0.62
	flightEnds = os.clock() + POP + FLY + 0.15
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < POP do -- a small pop up first
			local u = (os.clock() - t0) / POP
			local s = size * (1 + 0.12 * math.sin(u * math.pi))
			v.Position = UDim2.fromOffset(from.X, from.Y - 30 * u)
			v.Size = UDim2.fromOffset(s.X, s.Y)
			RunService.RenderStepped:Wait()
		end
		local a = from + Vector2.new(0, -30)
		t0 = os.clock()
		while true do -- then a curve down into the button, shrinking and speeding up
			local u = math.min(1, (os.clock() - t0) / FLY)
			local e = u * u
			local to = centre(target)
			local mid = (a + to) / 2 + Vector2.new(0, -160)
			local p = a * ((1 - e) ^ 2) + mid * (2 * (1 - e) * e) + to * (e * e)
			local s = size:Lerp(target.AbsoluteSize * 0.7, e)
			v.Position = UDim2.fromOffset(p.X, p.Y)
			v.Size = UDim2.fromOffset(s.X, s.Y)
			v.Rotation = -12 * e
			if u >= 1 then break end
			RunService.RenderStepped:Wait()
		end
		v:Destroy()
		Sound.play("reward")
		-- the button bumps and sparkles as it lands
		local at = centre(target)
		local sp = Instance.new("ImageLabel")
		sp.BackgroundTransparency = 1
		sp.Image = "rbxassetid://125948263137023"
		sp.AnchorPoint = Vector2.new(0.5, 0.5)
		sp.Position = UDim2.fromOffset(at.X, at.Y)
		sp.Size = UDim2.fromOffset(24, 24)
		sp.Parent = flyGui
		TweenService:Create(sp, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = UDim2.fromOffset(130, 130), ImageTransparency = 1, Rotation = 90 }):Play()
		task.delay(0.4, function() sp:Destroy() end)
		local us = target:FindFirstChildOfClass("UIScale")
		if us then
			local base = us.Scale
			TweenService:Create(us, TweenInfo.new(0.09, Enum.EasingStyle.Quad), { Scale = base * 1.2 }):Play()
			task.delay(0.09, function()
				TweenService:Create(us, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = base }):Play()
			end)
		end
	end)
end

