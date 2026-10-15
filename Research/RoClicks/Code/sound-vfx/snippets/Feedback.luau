--!strict
-- Feedback.luau: every important action gets ONE sound + ONE particle burst + ONE float text.
-- Call sites say what happened; this table decides how it feels, so moments can't drift or double up.
--
--   Feedback.moment("collect", buildingPos, "+$120")
--   Feedback.moment("trained", barracksPos, "+5 Riflemen")
--
-- Each moment has ONE owner. If a second system also reacts, give it a different, smaller cue.
-- Every sound and burst name below must exist in your registry / template folder (unknown names warn).

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Sound = require(script.Parent:WaitForChild("Sound")) -- SoundRegistry.luau
local FX = require(script.Parent:WaitForChild("FX"))       -- FXPool.luau

type Moment = { sound: string?, burst: string?, scale: number?, color: Color3?, shake: number? }

local MOMENTS: { [string]: Moment } = {
	collect  = { sound = "cash_collect", burst = "collect", color = Color3.fromRGB(255, 214, 80) },
	purchase = { sound = "ui_purchase", burst = "sparkle", color = Color3.fromRGB(255, 255, 255) },
	build    = { sound = "build_complete", burst = "build", color = Color3.fromRGB(255, 255, 255), shake = 0.15 },
	upgrade  = { sound = "building_upgrade", burst = "levelup", color = Color3.fromRGB(120, 220, 255) },
	levelup  = { sound = "ui_levelup", burst = "levelup", scale = 1.6, color = Color3.fromRGB(255, 220, 90), shake = 0.3 },
	trained  = { sound = "train_complete", burst = "levelup", scale = 0.8, color = Color3.fromRGB(140, 255, 150) },
	reward   = { sound = "ui_reward", burst = "sparkle", color = Color3.fromRGB(200, 140, 255) },
	error    = { sound = "ui_error", color = Color3.fromRGB(255, 90, 90) },
}

local Feedback = {}
Feedback.MOMENTS = MOMENTS
Feedback.onShake = nil :: ((amount: number) -> ())? -- hook to your camera module; never shake for ambient events

local function floatText(text: string, pos: Vector3, color: Color3)
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.Transparency = true, false, false, 1
	anchor.Size = Vector3.one * 0.1
	anchor.CFrame = CFrame.new(pos)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 50)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	anchor.Parent = Workspace
	local info = TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffsetWorldSpace = Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.4, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0.7),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1.2, function() anchor:Destroy() end)
end

function Feedback.moment(kind: string, pos: Vector3, text: string?, opts: { pitch: number? }?)
	local m = MOMENTS[kind]
	if not m then
		warn("[Feedback] unknown moment " .. kind) -- never fail silently
		return
	end
	if m.sound then Sound.play(m.sound, pos, opts) end
	if m.burst then FX.burst(m.burst, pos, { scale = m.scale or 1, cull = false }) end
	if text then floatText(text, pos + Vector3.new(0, 2, 0), m.color or Color3.new(1, 1, 1)) end
	if m.shake and Feedback.onShake then Feedback.onShake(m.shake) end
end

-- A run of the same moment rises in pitch (coins, land claims): call with i = 1..n.
function Feedback.run(kind: string, positions: { Vector3 }, maxCount: number?)
	local n = math.min(#positions, maxCount or 5)
	for i = 1, n do
		task.delay((i - 1) * 0.08, function()
			Feedback.moment(kind, positions[i], nil, { pitch = 0.9 + 0.3 * (i - 1) / math.max(1, n - 1) })
		end)
	end
end

return Feedback
