--!strict
-- EggModel: the tier egg. Uses the six egg meshes from the pet library (ReplicatedStorage.EOS_EggMeshes,
-- copied from ServerStorage.FWP_PetLibrary.Eggs), picked so each level matches the egg icon the HUD
-- shows for it (bottom-left while playing):
--   Lv 1 Basic · Lv 2 Shiny · Lv 3 Cosmic · Lv 4+ Golden
-- The egg grows with the level (TierConfig scale). Used for the Runner's carried egg (wearable =
-- massless, no collision / query / touch) and for showcase eggs (anchored, any scale).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TierConfig = require(ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared"):WaitForChild("TierConfig"))

local EggModel = {}

local LIB = "EOS_EggMeshes"
local WIDTH = 1.32 -- egg width in studs at scale 1 (developer, Oct 15: 1.62 was a bit big)
local MESH_W = 1.99 -- the library meshes' width

function EggModel.kindFor(tier: number): string
	-- same picture the HUD's egg card shows (UIController eggSlug)
	if tier <= 1 then
		return "Basic"
	elseif tier == 2 then
		return "Shiny"
	elseif tier == 3 then
		return "Cosmic"
	end
	return "Golden"
end

local function libFolder(kind: string): Instance?
	local lib = ReplicatedStorage:FindFirstChild(LIB) or ReplicatedStorage:WaitForChild(LIB, 5)
	return lib and lib:FindFirstChild(kind)
end

local function factor(tier: number, size: number?): number
	return (WIDTH / MESH_W) * TierConfig.get(tier).scale * (size or 1)
end

-- wearable=true: unanchored, massless, welded to the body, no collision/query/touch.
-- size: overall multiplier on top of the tier's own scale (showcase eggs use ~2-3).
-- The model's pivot sits at the bottom of the egg (as the old block egg's did).
function EggModel.build(tier: number, wearable: boolean, size: number?): Model
	local model = Instance.new("Model")
	model.Name = "EOS_Egg"
	model:SetAttribute("EOS_Tier", tier)
	local folder = libFolder(EggModel.kindFor(tier))
	local f = factor(tier, size)
	local parts: { BasePart } = {}
	local body: BasePart
	if folder and folder:FindFirstChild("Body") then
		body = (folder :: any).Body:Clone()
		body.Size *= f
		body.CFrame = CFrame.new(0, body.Size.Y / 2, 0)
		table.insert(parts, body)
		local g = folder:FindFirstChild("Glow") :: BasePart?
		if g then
			local glow = g:Clone()
			glow.Size *= f
			local rel = g.CFrame
			glow.CFrame = body.CFrame * CFrame.new(rel.Position * f) * rel.Rotation
			table.insert(parts, glow)
		end
	else
		-- library missing: a plain egg-coloured ball so nothing breaks
		body = Instance.new("Part")
		body.Shape = Enum.PartType.Ball
		body.Size = Vector3.new(1.5, 2.1, 1.5) * TierConfig.get(tier).scale * (size or 1)
		body.CFrame = CFrame.new(0, body.Size.Y / 2, 0)
		body.Color = TierConfig.get(tier).shell
		table.insert(parts, body)
	end
	body.Name = "Body"
	for _, p in ipairs(parts) do
		p:SetAttribute("EOS_Egg", true)
		if wearable then
			p.Anchored = false
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Massless = true
			p.CastShadow = false
		else
			p.Anchored = true
		end
		p.Parent = model
	end
	-- pivot at the bottom of the egg
	body.PivotOffset = CFrame.new(0, -body.Size.Y / 2, 0)
	model.PrimaryPart = body
	if wearable then
		for i = 2, #parts do
			local w = Instance.new("WeldConstraint")
			w.Part0 = body
			w.Part1 = parts[i]
			w.Parent = body
		end
	end
	return model
end

-- total height of a tier egg at a size (for placing it on pedestals)
function EggModel.height(tier: number, size: number?): number
	local folder = libFolder(EggModel.kindFor(tier))
	local b = folder and folder:FindFirstChild("Body") :: BasePart?
	if b then
		return b.Size.Y * factor(tier, size)
	end
	return 2.1 * TierConfig.get(tier).scale * (size or 1)
end

return EggModel
