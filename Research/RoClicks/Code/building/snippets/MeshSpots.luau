--!strict
-- MeshSpots: runtime-baked EditableMesh content that survives saves, slow starts and pools.
--
-- Why: EditableMesh -> MeshPart content is NOT saved with the place (after a reopen or rbxm round trip
-- only collision survives; the part is invisible). So models store invisible "spots" carrying a recipe,
-- and the game bakes meshes at runtime. Lessons baked into this module:
--   * bake in the BACKGROUND: a 4,400-spot bake at the top of server Main blocked every service for 11 s
--     and clients timed out waiting for remotes;
--   * bake each unique key once, clone per spot;
--   * a REPAIR loop fills spots that were cloned before the bake finished (pools reuse those forever);
--   * a spot that cannot bake gets a STAND-IN block (bounds, colour, material), never a hole;
--   * probe the FULL path: an empty CreateEditableMesh() succeeds even when the API is disabled.
--
-- A spot: an invisible BasePart tagged "MeshSpot" with attributes MeshKey (string) and MeshParams (JSON).
-- Its Size/CFrame/Color/Material describe the result. Recipes are yours: build(em, params, size) adds the
-- vertices/triangles in the spot's local space.
--
--   MeshSpots.register("roundedBox", function(em, params, size) ... end)
--   task.spawn(MeshSpots.bakeAll, ReplicatedStorage.Templates)    -- server, after services start
--   MeshSpots.watch(workspace)                                     -- repair loop
--   MeshSpots.repair(clone)                                        -- right after cloning a template

local AssetService = game:GetService("AssetService")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

local TAG = "MeshSpot"
local MESH_NAME = "BakedMesh"
local STANDIN = "MeshStandIn"

type Recipe = (em: any, params: { [string]: any }, size: Vector3) -> ()

local MeshSpots = {}
MeshSpots.FORCE_FALLBACK = false -- tests: pretend the API is off

local recipes: { [string]: Recipe } = {}
local cache: { [string]: MeshPart | false } = {} -- false = failed, use a stand-in
local available: boolean? = nil

function MeshSpots.register(name: string, fn: Recipe)
	recipes[name] = fn
end

-- EditableMesh -> MeshPart. If clients must see server-made meshes, check the current docs for the
-- step that turns the editable into replicating content (one working pipeline went through
-- AssetService:CreateDataModelContentAsync before CreateMeshPartAsync).
local function toMeshPart(em: any): MeshPart
	return AssetService:CreateMeshPartAsync(Content.fromObject(em))
end

-- One triangle, all the way to a MeshPart. Catches "Allow Mesh & Image APIs" being off.
function MeshSpots.available(): boolean
	if available == nil then
		available = not MeshSpots.FORCE_FALLBACK and pcall(function()
			local em = AssetService:CreateEditableMesh()
			local a = em:AddVertex(Vector3.new(0, 0, 0))
			local b = em:AddVertex(Vector3.new(1, 0, 0))
			local c = em:AddVertex(Vector3.new(0, 0, 1))
			em:AddTriangle(a, b, c)
			toMeshPart(em):Destroy()
		end)
		if not available then
			print("[MeshSpots] mesh API unavailable; using stand-ins")
		end
	end
	return available :: boolean
end

local function keyOf(spot: BasePart): string
	return `{spot:GetAttribute("MeshKey")}|{spot:GetAttribute("MeshParams") or ""}|{spot.Size}`
end

local function bakeKey(spot: BasePart): MeshPart | false
	local key = keyOf(spot)
	local hit = cache[key]
	if hit ~= nil then
		return hit
	end
	local recipe = recipes[spot:GetAttribute("MeshKey") :: string]
	local result: MeshPart | false = false
	if recipe and MeshSpots.available() then
		local ok, mp = pcall(function()
			local params = HttpService:JSONDecode((spot:GetAttribute("MeshParams") :: string?) or "{}")
			local em = AssetService:CreateEditableMesh()
			recipe(em, params, spot.Size)
			return toMeshPart(em)
		end)
		if ok then
			result = mp
		else
			warn(`[MeshSpots] bake failed for {spot:GetAttribute("MeshKey")}: {mp}`)
		end
	end
	cache[key] = result
	return result
end

local function hasReal(spot: BasePart): boolean
	local m = spot:FindFirstChild(MESH_NAME)
	return m ~= nil and not m:GetAttribute(STANDIN)
end

local function attach(spot: BasePart, part: BasePart, standIn: boolean)
	local old = spot:FindFirstChild(MESH_NAME)
	if old then
		old:Destroy()
	end
	part.Name = MESH_NAME
	part.Size = spot.Size
	part.CFrame = spot.CFrame
	part.Color = spot.Color
	part.Material = spot.Material
	part.MaterialVariant = spot.MaterialVariant
	part.Anchored = spot.Anchored
	part.CanCollide = false
	part.CanQuery = spot.CanQuery
	part.Transparency = 0
	part:SetAttribute(STANDIN, standIn or nil)
	part.Archivable = spot.Archivable -- edit-mode previews: spot non-archivable => never saved
	if not spot.Anchored then
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = spot, part
		w.Parent = part
	end
	part.Parent = spot
end

-- Give one spot its mesh (or a stand-in). Returns "real", "standin" or "skip".
function MeshSpots.fill(spot: BasePart): string
	if hasReal(spot) then
		return "skip"
	end
	local tpl = bakeKey(spot)
	if tpl then
		attach(spot, tpl:Clone(), false)
		return "real"
	end
	if spot:FindFirstChild(MESH_NAME) then
		return "skip" -- already has a stand-in; a later successful bake swaps it
	end
	attach(spot, Instance.new("Part"), true)
	return "standin"
end

-- Fill every spot under root. Yields every `batch` spots so it never blocks a frame for long.
function MeshSpots.repair(root: Instance, batch: number?): (number, number)
	local real, stand, n = 0, 0, 0
	for _, spot in CollectionService:GetTagged(TAG) do
		if spot:IsA("BasePart") and spot:IsDescendantOf(root) and not hasReal(spot) then
			local r = MeshSpots.fill(spot)
			if r == "real" then real += 1 elseif r == "standin" then stand += 1 end
			n += 1
			if batch and n % batch == 0 then
				task.wait()
			end
		end
	end
	return real, stand
end

-- Server: bake every template once, in the background. Retry failures once, then publish a flag.
function MeshSpots.bakeAll(root: Instance)
	local t0 = os.clock()
	MeshSpots.repair(root, 50)
	for k, v in cache do
		if v == false then
			cache[k] = nil -- one retry
		end
	end
	local _, stand = MeshSpots.repair(root, 50)
	workspace:SetAttribute("MeshesBaked", true)
	print(`[MeshSpots] baked in {string.format("%.1f", os.clock() - t0)} s, {stand} stand-ins`)
end

-- Repair loop: every 1 s until the bake flag is set and 3 passes come back clean, then every 6 s as a
-- safety net for pooled copies made before the bake.
function MeshSpots.watch(root: Instance)
	task.spawn(function()
		local clean = 0
		while true do
			local real, stand = MeshSpots.repair(root, 50)
			local baked = workspace:GetAttribute("MeshesBaked") == true
			clean = if baked and real + stand == 0 then clean + 1 else 0
			task.wait(if clean >= 3 then 6 else 1)
		end
	end)
end

return MeshSpots
