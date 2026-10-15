--!nocheck
-- Base-compare apply for a folder made by stage.py and imported into ServerStorage.
-- Paste into execute_luau with STAGE_NAME (and LANDMARK) edited. All-or-nothing: if any target changed since
-- you pulled it, NOTHING is applied, the stage is destroyed, and the conflicts are listed. Re-pull, re-merge, retry.
local STAGE_NAME = "Stage_Agent_1"
local LANDMARK = function() return true end -- e.g. function() return game.Name == "MyGame" end

assert(LANDMARK(), "wrong place: refusing to apply")
local stage = game:GetService("ServerStorage"):FindFirstChild(STAGE_NAME)
if not stage then return "no stage named " .. STAGE_NAME end

local function norm(s) return (string.gsub(s or "", "\r\n", "\n")) end

-- "ServerScriptService/Game/Services/Data" -> parent instance (or nil), leaf name
local function resolve(path)
	local parts = string.split(path, "/")
	local ok, cur = pcall(game.GetService, game, parts[1])
	if not ok then cur = game:FindFirstChild(parts[1]) end
	for i = 2, #parts - 1 do cur = cur and cur:FindFirstChild(parts[i]) end
	return cur, parts[#parts]
end

local plan, conflicts = {}, {}
for _, item in ipairs(stage:GetChildren()) do
	local parent, leaf = resolve(item.Name)
	local target = parent and parent:FindFirstChild(leaf)
	local base, new = item:FindFirstChild("Base"), item:FindFirstChild("New")
	local want = norm(item.Source)
	if new then
		if target then table.insert(conflicts, item.Name .. " (exists, staged as NEW)") end
		if not parent then table.insert(conflicts, item.Name .. " (parent missing)") end
	elseif not target then
		table.insert(conflicts, item.Name .. " (missing)")
	elseif base then
		local live = norm(target.Source)
		-- live == base: nobody touched it; live == want: already applied (idempotent re-run)
		if live ~= norm(base.Source) and live ~= want then table.insert(conflicts, item.Name .. " (changed in Studio)") end
	end
	table.insert(plan, { item = item, parent = parent, leaf = leaf, target = target, class = new and new.Value })
end

if #conflicts > 0 then
	stage:Destroy()
	return "CONFLICT (nothing applied):\n" .. table.concat(conflicts, "\n")
end

local out = {}
for _, p in ipairs(plan) do
	local t = p.target
	if not t then
		t = Instance.new(p.class ~= "" and p.class or "ModuleScript")
		t.Name = p.leaf
		t.Source = p.item.Source
		t.Parent = p.parent
		table.insert(out, "new " .. p.item.Name)
	else
		t.Source = p.item.Source
		table.insert(out, "ok  " .. p.item.Name)
	end
end
stage:Destroy()
return table.concat(out, "\n")
