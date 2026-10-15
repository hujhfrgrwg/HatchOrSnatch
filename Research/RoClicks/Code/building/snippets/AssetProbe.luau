--!strict
-- AssetProbe: find meshes and images your experience is not allowed to load.
--
-- Why: a MeshPart whose mesh belongs to another creator, or an image id you lack permission for, renders
-- as NOTHING. No error at the call site, no placeholder: an invisible model, an empty ImageLabel, a Decal
-- that stays the part colour. The only trace is an easy-to-miss output line. Probe before you build around
-- an id, and sweep asset folders after importing toolbox content.
--
-- Run in edit mode (command bar / execute_luau) or on the server. Each probe is a network round trip, so
-- results are cached per id.
--
--   local bad = AssetProbe.sweepMeshes(game.ReplicatedStorage.Assets)
--   for _, b in bad do print(b.id, b.path, b.err) end
--   print(AssetProbe.image("rbxassetid://123"))   -- ok, err

local AssetService = game:GetService("AssetService")

local AssetProbe = {}

local meshCache: { [string]: { ok: boolean, err: string? } } = {}
local imageCache: { [string]: { ok: boolean, err: string? } } = {}

local function idOf(content: string): string?
	return content:match("%d+")
end

-- true if a mesh id loads in THIS experience
function AssetProbe.mesh(meshId: string): (boolean, string?)
	local key = idOf(meshId)
	if not key then
		return false, "no id"
	end
	local c = meshCache[key]
	if not c then
		local ok, err = pcall(function()
			return AssetService:CreateMeshPartAsync(Content.fromUri("rbxassetid://" .. key))
		end)
		c = { ok = ok, err = if ok then nil else tostring(err) }
		meshCache[key] = c
	end
	return c.ok, c.err
end

-- true if an image id loads ("...no permission to load asset" when it does not)
function AssetProbe.image(imageId: string): (boolean, string?)
	local key = idOf(imageId)
	if not key then
		return false, "no id"
	end
	local c = imageCache[key]
	if not c then
		local ok, err = pcall(function()
			local img = AssetService:CreateEditableImageAsync(Content.fromUri("rbxassetid://" .. key))
			img:Destroy()
		end)
		c = { ok = ok, err = if ok then nil else tostring(err) }
		imageCache[key] = c
	end
	return c.ok, c.err
end

export type Bad = { id: string, path: string, err: string? }

-- Every MeshPart under root whose mesh fails to load. Reports each failing instance (blast radius).
function AssetProbe.sweepMeshes(root: Instance): { Bad }
	local bad = {}
	for _, d in root:GetDescendants() do
		if d:IsA("MeshPart") and d.MeshId ~= "" then
			local ok, err = AssetProbe.mesh(d.MeshId)
			if not ok then
				table.insert(bad, { id = d.MeshId, path = d:GetFullName(), err = err })
			end
		end
	end
	return bad
end

-- Every Decal/Texture/ImageLabel/ImageButton under root whose image fails to load.
function AssetProbe.sweepImages(root: Instance): { Bad }
	local bad = {}
	for _, d in root:GetDescendants() do
		local id: string? = nil
		if d:IsA("Decal") then -- Texture inherits from Decal
			id = d.Texture
		elseif d:IsA("ImageLabel") or d:IsA("ImageButton") then
			id = d.Image
		end
		if id and id ~= "" and not id:match("^rbxasset://") then
			local ok, err = AssetProbe.image(id)
			if not ok then
				table.insert(bad, { id = id, path = d:GetFullName(), err = err })
			end
		end
	end
	return bad
end

-- Note on EditableImage/EditableMesh probes: they need "Allow Mesh & Image APIs" enabled for the
-- experience. If that is off, EVERY image probe fails; check one known-good image you own first.
-- Whose asset is it? MarketplaceService:GetProductInfo(id).Creator tells you who must share it.

return AssetProbe
