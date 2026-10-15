--!strict
-- Discovery: find map content without hard-coding where it lives.
--
-- Why: services that scan workspace:GetChildren() for "Stage1" or WaitForChild("Checkpoints") die
-- SILENTLY when a level designer moves content into folders: the scan finds nothing (no error) and
-- WaitForChild yields forever. One shared module that walks Folders, matches by tag/attribute, and
-- warns on empty results turns that silence into a log line.
--
--   local Discovery = require(path.to.Discovery)
--   local stages = Discovery.containers(function(f) return f:GetAttribute("MapRole") == "Stages" end, "stages")
--   local spawns = Discovery.tagged("Checkpoint")            -- CollectionService, anywhere
--   local lava   = Discovery.find(function(i) return i.Name:match("^Lava") ~= nil end, "lava parts")

local CollectionService = game:GetService("CollectionService")

local Discovery = {}

-- Every Folder (and Model, if includeModels) under root, walking ONLY through Folders. Never descends into
-- Models/Parts, so a map with 50k mesh parts costs ~100 visits instead of 50k.
function Discovery.folders(root: Instance?, includeModels: boolean?): { Instance }
	local out = {}
	local stack = { root or workspace }
	while #stack > 0 do
		local node = table.remove(stack) :: Instance
		for _, child in node:GetChildren() do
			if child:IsA("Folder") then
				table.insert(out, child)
				table.insert(stack, child)
			elseif includeModels and child:IsA("Model") then
				table.insert(out, child)
			end
		end
	end
	return out
end

-- Containers (Folders/Models reachable through Folders) that pass the predicate. Match on what a container
-- HOLDS or an attribute you control, not on a name that will churn.
function Discovery.containers(pred: (Instance) -> boolean, what: string, root: Instance?): { Instance }
	local out = {}
	if pred(root or workspace) then
		table.insert(out, root or workspace)
	end
	for _, f in Discovery.folders(root, true) do
		if pred(f) then
			table.insert(out, f)
		end
	end
	if #out == 0 then
		warn(`[Discovery] found no {what} under {(root or workspace):GetFullName()}`)
	end
	return out
end

-- Everything with a tag that lives under root (default Workspace). Warns when empty.
function Discovery.tagged(tag: string, root: Instance?): { Instance }
	local out = {}
	local r = root or workspace
	for _, inst in CollectionService:GetTagged(tag) do
		if inst:IsDescendantOf(r) then
			table.insert(out, inst)
		end
	end
	if #out == 0 then
		warn(`[Discovery] no instances tagged "{tag}" under {r:GetFullName()}`)
	end
	return out
end

-- Full descendant search inside the containers you already found. Use it for leaves, never on all of
-- Workspace in a hot path.
function Discovery.find(pred: (Instance) -> boolean, what: string, roots: { Instance }?): { Instance }
	local out = {}
	for _, r in roots or { workspace } do
		for _, d in r:GetDescendants() do
			if pred(d) then
				table.insert(out, d)
			end
		end
	end
	if #out == 0 then
		warn(`[Discovery] found no {what}`)
	end
	return out
end

-- WaitForChild replacement for map content: bounded wait, then a loud warning instead of a hang.
function Discovery.waitFor(parent: Instance, name: string, timeout: number?): Instance?
	local inst = parent:WaitForChild(name, timeout or 10)
	if not inst then
		warn(`[Discovery] {parent:GetFullName()}.{name} did not appear; was the map reorganised?`)
	end
	return inst
end

return Discovery
