--!nocheck
-- BakeIncubatorEgg (HOS-INC-001, 17 Oct 2026, Matthew): turns the incubator's cracked-shell puzzle egg (the client's
-- IncubatorWorld.EggPieces) into real mesh assets. EditableMesh is too memory-hungry to build 18 pieces on a player's
-- device, and plugins can't upload meshes yet, so the pieces go through Studio's 3D Importer once:
--   1. Bake.obj() returns the 18 pieces as one OBJ (objects Piece1..Piece18 in fill order, egg-local studs, UVs on
--      the egg shard atlas). It's saved as docs/HOS-INC-001/IncubatorEggPieces.obj.
--   2. In Studio: File > Import 3D, pick that file, creator = the group, import. The model lands in the workspace.
--   3. Bake.adopt(thatModel) moves its MeshParts into ReplicatedStorage.IncubatorEggPieces (what the client clones),
--      with attributes Centre and Mid (relative to the egg's centre), after checking each one's size.
-- Run from the command bar:  require(game.ServerStorage.EOSBuild.BakeIncubatorEgg).adopt(workspace.IncubatorEggPieces)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local Bake = {}

local function pieces()
	local src = game:GetService("StarterPlayer").StarterPlayerScripts.EOS.Controllers.IncubatorWorld.EggPieces
	local Pieces = require(src:Clone()) -- a fresh copy, so edits to the module are picked up
	return Pieces, Pieces.editableMeshes()
end

local function f(x: number): string
	return string.format("%.5f", x)
end

-- the OBJ text (positions egg-local; OBJ's v runs up, so v = 1 - the atlas's v)
function Bake.obj(): string
	local _, list = pieces()
	local out = { "# Hatch or Snatch incubator egg, 18 puzzle pieces (HOS-INC-001). Units: studs, Y up." }
	local nv, nt, nn = 0, 0, 0
	for i, info in list do
		local em, mid = info.em, info.mid
		table.insert(out, "o Piece" .. i)
		local vIndex, tIndex, nIndex = {}, {}, {}
		for _, v in em:GetVertices() do
			local p = em:GetPosition(v) + mid
			nv += 1
			vIndex[v] = nv
			table.insert(out, "v " .. f(p.X) .. " " .. f(p.Y) .. " " .. f(p.Z))
		end
		for _, face in em:GetFaces() do
			local vs = em:GetFaceVertices(face)
			local uvs = em:GetFaceUVs(face)
			local ns = em:GetFaceNormals(face)
			local parts = {}
			for k = 1, 3 do
				local uid, nid = uvs[k], ns[k]
				if not tIndex[uid] then
					local uv = em:GetUV(uid)
					nt += 1
					tIndex[uid] = nt
					table.insert(out, "vt " .. f(uv.X) .. " " .. f(1 - uv.Y))
				end
				if not nIndex[nid] then
					local n = em:GetNormal(nid)
					nn += 1
					nIndex[nid] = nn
					table.insert(out, "vn " .. f(n.X) .. " " .. f(n.Y) .. " " .. f(n.Z))
				end
				parts[k] = vIndex[vs[k]] .. "/" .. tIndex[uid] .. "/" .. nIndex[nid]
			end
			table.insert(out, "f " .. table.concat(parts, " "))
		end
		em:Destroy()
	end
	return table.concat(out, "\n") .. "\n"
end

-- moves the imported pieces into ReplicatedStorage.IncubatorEggPieces
function Bake.adopt(model: Instance): string
	assert(model, "pass the imported model (e.g. workspace.IncubatorEggPieces)")
	local Pieces, list = pieces()
	local found, nFound, log = {}, 0, {}
	for _, d in model:GetDescendants() do
		local i = d:IsA("MeshPart") and tonumber(d.Name:match("^Piece(%d+)$"))
		if i and list[i] and not found[i] then
			found[i] = d
			nFound += 1
		end
	end
	for i, info in list do
		local mp = found[i]
		if not mp then
			table.insert(log, "Piece" .. i .. " missing from the import")
		else
			-- the mesh's bounding box should match the generator's
			local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
			for _, v in info.em:GetVertices() do
				local p = info.em:GetPosition(v)
				lo, hi = lo:Min(p), hi:Max(p)
			end
			local want = hi - lo
			local err = (mp.Size - want).Magnitude
			if err > 0.05 then
				table.insert(log, ("Piece%d size %s, expected %s: resized"):format(i, tostring(mp.Size), tostring(want)))
				mp.Size = want
			end
		end
		info.em:Destroy()
	end
	if nFound < #list then
		return "not adopted:\n" .. table.concat(log, "\n")
	end
	pcall(ChangeHistoryService.SetWaypoint, ChangeHistoryService, "HOS-INC-001: before adopting egg pieces")
	local old = ReplicatedStorage:FindFirstChild(Pieces.BAKED)
	if old then old:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = Pieces.BAKED
	for i, info in list do
		local mp = found[i]
		mp.Name = "Piece" .. i
		mp.Anchored, mp.CanCollide, mp.CanQuery, mp.CanTouch, mp.CastShadow = true, false, false, false, false
		mp.Material = Enum.Material.SmoothPlastic
		mp.Color = Color3.new(1, 1, 1)
		mp.CFrame = CFrame.new(info.mid) -- egg-local, round the origin
		for _, c in mp:GetChildren() do c:Destroy() end
		mp:SetAttribute("Centre", info.centre)
		mp:SetAttribute("Mid", info.mid)
		mp.Parent = folder
	end
	folder.Parent = ReplicatedStorage
	if model.Parent and #model:GetDescendants() == 0 then model:Destroy() end
	pcall(ChangeHistoryService.SetWaypoint, ChangeHistoryService, "HOS-INC-001: egg pieces adopted")
	return ("adopted %d pieces into ReplicatedStorage.%s%s"):format(#list, Pieces.BAKED, if #log > 0 then "\n" .. table.concat(log, "\n") else "")
end

return Bake
