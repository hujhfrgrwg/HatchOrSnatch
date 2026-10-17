--!nocheck
-- BakeIncubatorEgg (HOS-INC-001, 17 Oct 2026, Matthew): turns the incubator's cracked-shell puzzle egg (the client's
-- IncubatorWorld.EggPieces) into real mesh assets. EditableMesh is too memory-hungry to build 18 pieces on a player's
-- device, and plugins can't upload meshes yet, so the pieces go through Studio's 3D Importer once:
--   1. Bake.obj() returns the 18 pieces as one OBJ (objects Piece1..Piece18 in fill order, egg-local studs, UVs on
--      the egg shard atlas). It's saved as docs/HOS-INC-001/IncubatorEggPieces.obj.
--   2. In Studio: File > Import 3D, pick that file, creator = the group, import. The model lands in the workspace.
--   3. Bake.adopt(thatModel) moves its MeshParts into ReplicatedStorage.IncubatorEggPieces (what the client clones),
--      with attributes Centre and Mid (relative to the egg's centre) and MeshTurn (the importer turns meshes; this
--      undoes it), after checking each one's size and matching its uploaded mesh to the generator.
-- Run from the command bar:  require(game.ServerStorage.EOSBuild.BakeIncubatorEgg).adopt(workspace.IncubatorEggPieces)
local AssetService = game:GetService("AssetService")
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
		table.insert(out, "g Piece" .. i) -- the 3D Importer splits parts by group
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

-- the turn the importer gave a piece's mesh (it turned all 18 by 180 degrees about Y on 17 Oct): reads the uploaded
-- mesh back and finds the turn that lands the generator's vertices on it. Returns the turn and the worst miss (studs).
local TURNS = { CFrame.identity, CFrame.Angles(0, math.pi, 0), CFrame.Angles(math.pi, 0, 0), CFrame.Angles(0, 0, math.pi) }
local function turnOf(mp: MeshPart, gen: EditableMesh): (CFrame?, number)
	local ok, em = pcall(AssetService.CreateEditableMeshAsync, AssetService, Content.fromUri(mp.MeshId), { FixedSize = true })
	if not ok or not em then return nil, math.huge end
	local imp = {}
	for _, v in em:GetVertices() do table.insert(imp, em:GetPosition(v)) end
	em:Destroy()
	local g = {}
	for _, v in gen:GetVertices() do table.insert(g, gen:GetPosition(v)) end
	local best, bestErr = nil, math.huge
	for _, turn in TURNS do
		local worst = 0
		for k = 1, #g, 7 do
			local q = turn * g[k]
			local m = math.huge
			for _, p in imp do
				local d = (p - q).Magnitude
				if d < m then m = d end
			end
			worst = math.max(worst, m)
			if worst > bestErr then break end
		end
		if worst < bestErr then best, bestErr = turn, worst end
	end
	return best, bestErr
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
			local turn, miss = turnOf(mp, info.em)
			if turn and miss < 0.01 then
				info.turn = turn
			else
				table.insert(log, ("Piece%d: couldn't match the mesh to the generator (miss %.3f)"):format(i, miss))
				nFound -= 1
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
		mp.CFrame = CFrame.new(info.mid) * info.turn -- egg-local, round the origin
		for _, c in mp:GetChildren() do c:Destroy() end
		mp:SetAttribute("Centre", info.centre)
		mp:SetAttribute("Mid", info.mid)
		mp:SetAttribute("MeshTurn", info.turn) -- undoes the importer's turn (EggPieces applies it)
		mp.Parent = folder
	end
	folder.Parent = ReplicatedStorage
	if model.Parent and #model:GetDescendants() == 0 then model:Destroy() end
	pcall(ChangeHistoryService.SetWaypoint, ChangeHistoryService, "HOS-INC-001: egg pieces adopted")
	return ("adopted %d pieces into ReplicatedStorage.%s%s"):format(#list, Pieces.BAKED, if #log > 0 then "\n" .. table.concat(log, "\n") else "")
end

return Bake
