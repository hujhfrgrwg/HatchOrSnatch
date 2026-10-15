--!nocheck
-- stage_apply: run in Studio (command bar or an execute_luau tool) after importing the .rbxmx built by
-- stage_rbxmx.py into ServerStorage.
--
-- Base-compare rule: a target is a CONFLICT when its live Source equals neither the Base you edited on
-- nor the new Source (someone changed it in Studio since you pulled it). Any conflict aborts the whole
-- push and nothing is written, so a half-applied set of modules can never reach a playtest.
-- Returns a one-line-per-item report. The stage folder is always destroyed afterwards.
--
-- Note: on a ModuleScript that a running session already required, the change only takes effect for
-- new requires. In edit mode, `require` caches across command-bar runs; test the new code in a fresh
-- playtest (or require a clone).

local STAGE = "Stage" -- must match -n in stage_rbxmx.py

local stage = game:GetService("ServerStorage"):FindFirstChild(STAGE)
if not stage then
	return "no stage folder ServerStorage." .. STAGE
end

local function resolve(path: string)
	local parts = string.split(path, ".")
	local ok, cur = pcall(game.GetService, game, parts[1])
	if not ok then
		cur = game:FindFirstChild(parts[1])
	end
	for i = 2, #parts - 1 do
		cur = cur and cur:FindFirstChild(parts[i])
	end
	return cur, parts[#parts]
end

local function norm(s)
	return (string.gsub(s or "", "\r\n", "\n"))
end

local plan, conflicts = {}, {}
for _, m in ipairs(stage:GetChildren()) do
	local parent, leaf = resolve(m.Name)
	local target = parent and parent:FindFirstChild(leaf)
	local base = m:FindFirstChild("Base")
	if m:FindFirstChild("New") then
		if target then
			table.insert(conflicts, m.Name .. " (already exists)")
		end
	elseif not parent then
		table.insert(conflicts, m.Name .. " (parent missing)")
	elseif not target then
		table.insert(conflicts, m.Name .. " (target missing)")
	elseif base and norm(target.Source) ~= norm(base.Source) and norm(target.Source) ~= norm(m.Source) then
		table.insert(conflicts, m.Name .. " (changed live since you pulled it)")
	end
	table.insert(plan, { m = m, parent = parent, leaf = leaf, target = target })
end

if #conflicts > 0 then
	stage:Destroy()
	return "CONFLICT, nothing applied:\n  " .. table.concat(conflicts, "\n  ")
end

local out = {}
for _, p in ipairs(plan) do
	local t = p.target
	if not t then
		t = Instance.new("ModuleScript")
		t.Name = p.leaf
		t.Parent = p.parent
	end
	if norm(t.Source) == norm(p.m.Source) then
		table.insert(out, "same " .. p.m.Name)
	else
		t.Source = p.m.Source
		table.insert(out, "ok   " .. p.m.Name)
	end
end
stage:Destroy()
return table.concat(out, "\n")
