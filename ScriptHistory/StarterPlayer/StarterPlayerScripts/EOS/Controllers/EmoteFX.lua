-- EmoteFX (HOS-EMOTE-FX-001, 16 Oct): Destiny-style "light constructs" for the emotes that mime a prop
-- that isn't there (Reaper's Ride's scythe, Surfer's board, Toilet Sit's toilet, ...). Cosmetic, client only:
-- every client builds the construct for every character whose EOS_Emote is set (EmoteController calls
-- update), so everyone nearby sees it.
--  * Templates: ReplicatedStorage.EOS_EmoteFX.<emoteId> (a model per emote; no model = no construct).
--    Attributes: Part0 (body part it sits on), C0 (offset from it), Joint (Motor6D name the clip animates,
--    "" for a plain weld). Set EOS_EmoteFX's attribute Enabled = false to switch every construct off.
--  * Jointed props (scythe, board) get a Motor6D in the character named after the clip's joint, and this
--    module plays that joint's keyframes from the clip (ReplicatedStorage.EOS_Emotes) in time with the
--    character's playing track, so the prop moves like the original even if the Animator never picks up a
--    joint added mid-dance (if it does, it writes the same pose). Everything else is welded and stays still.
--  * The construct itself lives in Workspace.EOS_EmoteFXLive (never inside the character: hitboxes,
--    outlines and ragdolls only see the joint), non-collidable, massless, unqueryable.
--  * Build-in: pieces light up bottom to top over ~0.45 s with a sparkle burst; fade out in 0.25 s.
--    Constructs farther than FAR studs from the camera are skipped; touch devices get half the particles.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local EmoteFX = {}

local FOLDER = "EOS_EmoteFX"
local FAR = 140
local SWEEP, PIECE_IN, FADE_OUT = 0.45, 0.22, 0.25

type Live = { id: string, model: Model, joint: Instance?, alive: boolean, drive: RBXScriptConnection? }
type Track = { times: { number }, cfs: { CFrame }, styles: { Enum.EasingStyle? }, dirs: { Enum.EasingDirection }, length: number }
local CLIPS = "EOS_Emotes"
local tracks: { [string]: Track | false } = {}

-- the joint's keyframes in the emote's clip (cached); false when the clip has none
local function jointTrack(id: string, joint: string): Track?
	local key = id .. "|" .. joint
	local cached = tracks[key]
	if cached ~= nil then return cached or nil end
	local lib = ReplicatedStorage:FindFirstChild(CLIPS)
	local seq = lib and lib:FindFirstChild(id)
	local frames = {}
	if seq then
		for _, kf in seq:GetChildren() do
			if kf:IsA("Keyframe") then
				for _, p in kf:GetDescendants() do
					if p:IsA("Pose") and p.Name == joint then table.insert(frames, { t = kf.Time, pose = p }) break end
				end
			end
		end
	end
	table.sort(frames, function(a, b) return a.t < b.t end)
	if #frames == 0 then
		tracks[key] = false
		return nil
	end
	local styleMap = { [Enum.PoseEasingStyle.Linear] = Enum.EasingStyle.Linear, [Enum.PoseEasingStyle.Cubic] = Enum.EasingStyle.Cubic,
		[Enum.PoseEasingStyle.Elastic] = Enum.EasingStyle.Elastic, [Enum.PoseEasingStyle.Bounce] = Enum.EasingStyle.Bounce }
	local dirMap = { [Enum.PoseEasingDirection.In] = Enum.EasingDirection.In, [Enum.PoseEasingDirection.Out] = Enum.EasingDirection.Out,
		[Enum.PoseEasingDirection.InOut] = Enum.EasingDirection.InOut }
	local tr: Track = { times = {}, cfs = {}, styles = {}, dirs = {}, length = frames[#frames].t }
	for i, f in frames do
		local p = f.pose :: Pose
		tr.times[i] = f.t
		tr.cfs[i] = p.CFrame
		tr.styles[i] = if p.EasingStyle == Enum.PoseEasingStyle.Constant then nil else (styleMap[p.EasingStyle] or Enum.EasingStyle.Cubic)
		tr.dirs[i] = dirMap[p.EasingDirection] or Enum.EasingDirection.In
	end
	tracks[key] = tr
	return tr
end

local function sample(tr: Track, t: number): CFrame
	local n = #tr.times
	if n == 1 or t <= tr.times[1] then return tr.cfs[1] end
	if t >= tr.times[n] then return tr.cfs[n] end
	for i = 1, n - 1 do
		local a, b = tr.times[i], tr.times[i + 1]
		if t <= b then
			local style = tr.styles[i]
			if not style or b - a <= 0 then return tr.cfs[i] end
			local alpha = TweenService:GetValue((t - a) / (b - a), style, tr.dirs[i])
			return tr.cfs[i]:Lerp(tr.cfs[i + 1], alpha)
		end
	end
	return tr.cfs[n]
end

-- the character's playing emote track (matched by length), for its TimePosition
local function playingTrack(char: Model, length: number): AnimationTrack?
	local hum = char:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not animator then return nil end
	local best: AnimationTrack? = nil
	for _, t in animator:GetPlayingAnimationTracks() do
		if t.Length > 0 and math.abs(t.Length - length) < 0.08 and (not best or t.Priority.Value > best.Priority.Value) then best = t end
	end
	return best
end
local live: { [Model]: Live } = {}

local function templates(): Instance?
	local f = ReplicatedStorage:FindFirstChild(FOLDER)
	if f and f:GetAttribute("Enabled") == false then return nil end
	return f
end

local function liveFolder(): Folder
	local f = Workspace:FindFirstChild("EOS_EmoteFXLive")
	if not f then
		f = Instance.new("Folder")
		f.Name = "EOS_EmoteFXLive"
		f.Archivable = false
		f.Parent = Workspace
	end
	return f :: Folder
end

local function tween(obj: Instance, t: number, props: { [string]: any }, delay: number?)
	local tw = TweenService:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, delay or 0), props)
	tw:Play()
	return tw
end

function EmoteFX.clear(char: Model, instant: boolean?)
	local cur = live[char]
	if not cur then return end
	live[char] = nil
	cur.alive = false
	if cur.drive then cur.drive:Disconnect() end
	local model, joint = cur.model, cur.joint
	if instant then
		model:Destroy()
		if joint then joint:Destroy() end
		return
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			tween(d, FADE_OUT, { Transparency = 1 })
		elseif d:IsA("SelectionBox") then
			tween(d, FADE_OUT, { Transparency = 1 })
		elseif d:IsA("ParticleEmitter") then
			d.Enabled = false
		elseif d:IsA("PointLight") then
			tween(d, FADE_OUT, { Brightness = 0 })
		end
	end
	task.delay(FADE_OUT + 0.05, function()
		model:Destroy()
		if joint then joint:Destroy() end
	end)
end

local function spawnFor(char: Model, id: string)
	local f = templates()
	local tpl = f and f:FindFirstChild(id)
	if not (tpl and tpl:IsA("Model") and tpl.PrimaryPart) then return end
	local part0 = char:FindFirstChild(tpl:GetAttribute("Part0") or "")
	if not (part0 and part0:IsA("BasePart")) then return end
	local cam = Workspace.CurrentCamera
	if cam and (cam.CFrame.Position - part0.Position).Magnitude > FAR then return end
	local c0 = tpl:GetAttribute("C0")
	if typeof(c0) ~= "CFrame" then c0 = CFrame.new() end
	local model = tpl:Clone()
	local root = model.PrimaryPart :: BasePart
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local pieces: { { obj: Instance, target: number, y: number } } = {}
	local lights: { { obj: PointLight, target: number } } = {}
	local emitters: { ParticleEmitter } = {}
	model:PivotTo(part0.CFrame * c0)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			if d ~= root then
				table.insert(pieces, { obj = d, target = d.Transparency, y = d.Position.Y })
				d.Transparency = 1
			end
		elseif d:IsA("SelectionBox") then
			local p = d.Parent :: BasePart
			table.insert(pieces, { obj = d, target = d.Transparency, y = if p and p:IsA("BasePart") then p.Position.Y else 0 })
			d.Transparency = 1
		elseif d:IsA("PointLight") then
			table.insert(lights, { obj = d, target = d.Brightness })
			d.Brightness = 0
		elseif d:IsA("ParticleEmitter") then
			if touch then d.Rate = d.Rate * 0.5 end
			d.Enabled = false
			table.insert(emitters, d)
		end
	end
	-- weld to the body: a Motor6D in the character when the clip animates the prop's joint
	local jointName = tpl:GetAttribute("Joint")
	local joint: Instance
	if type(jointName) == "string" and jointName ~= "" then
		local m6 = Instance.new("Motor6D")
		m6.Name = jointName
		m6.Part0 = part0
		m6.Part1 = root
		m6.C0 = c0
		m6.Parent = part0
		joint = m6
	else
		local w = Instance.new("Weld")
		w.Name = "EOS_EmoteFXWeld"
		w.Part0 = part0
		w.Part1 = root
		w.C0 = c0
		w.Parent = root
		joint = w
	end
	model.Name = id .. "_" .. char.Name
	model.Parent = liveFolder()
	local entry: Live = { id = id, model = model, joint = if joint.Parent == part0 then joint else nil, alive = true }
	live[char] = entry
	-- jointed props: play the joint's keyframes in step with the character's track (own clock as fallback)
	local tr = if joint:IsA("Motor6D") then jointTrack(id, joint.Name) else nil
	if tr then
		local m6 = joint :: Motor6D
		local t0 = os.clock()
		local function step()
			local track = playingTrack(char, tr.length)
			local t = if track then track.TimePosition else (os.clock() - t0) % math.max(tr.length, 0.01)
			m6.Transform = sample(tr, t)
		end
		step()
		entry.drive = RunService.RenderStepped:Connect(function()
			if not entry.alive or not m6.Parent then return end
			step()
		end)
	end
	-- build-in: bottom to top
	local lo, hi = math.huge, -math.huge
	for _, p in pieces do lo = math.min(lo, p.y); hi = math.max(hi, p.y) end
	local span = math.max(hi - lo, 0.01)
	for _, p in pieces do
		tween(p.obj, PIECE_IN, { Transparency = p.target }, (p.y - lo) / span * SWEEP)
	end
	for _, l in lights do tween(l.obj, SWEEP, { Brightness = l.target }) end
	for _, e in emitters do e:Emit(if touch then 4 else 8) end
	task.delay(SWEEP, function()
		if not entry.alive then return end
		for _, e in emitters do e.Enabled = true end
	end)
end

-- call whenever a character's EOS_Emote may have changed
function EmoteFX.update(char: Model)
	local id = char:GetAttribute("EOS_Emote")
	local cur = live[char]
	if type(id) ~= "string" or id == "" then
		if cur then EmoteFX.clear(char) end
		return
	end
	if cur and cur.id == id then return end
	if cur then EmoteFX.clear(char) end
	spawnFor(char, id)
end

-- one-time hookup for a character: follows EOS_Emote and cleans up when the character goes
function EmoteFX.watch(char: Model)
	EmoteFX.update(char)
	char:GetAttributeChangedSignal("EOS_Emote"):Connect(function() EmoteFX.update(char) end)
	char.Destroying:Connect(function() EmoteFX.clear(char, true) end)
	char.AncestryChanged:Connect(function(_, parent)
		if not parent then EmoteFX.clear(char, true) end
	end)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then hum.Died:Connect(function() EmoteFX.clear(char) end) end
end

return EmoteFX
