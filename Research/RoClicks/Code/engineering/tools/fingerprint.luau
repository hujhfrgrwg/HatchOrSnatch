--!nocheck
-- Cheap drift check: one line per script, "<path>\t<bytes>\t<fnv1a32>", with no source text in the reply.
-- Paste into execute_luau (edit ROOTS), save the returned text to a file, then compare it with a local copy:
--   python3 snapshot_diff.py --fingerprint studio_fp.txt <local_dir>
-- Paths use "/" and the same file suffixes as rbxm_extract.py (.server.luau / .client.luau / .luau), relative to
-- each root's PARENT, so they line up with an extracted snapshot. The hash matches snapshot_diff.py (CRLF -> LF first).
local ROOTS = {
	game:GetService("ServerScriptService"),
	game:GetService("ReplicatedStorage"),
	game:GetService("StarterPlayer"),
}

local function fnv1a32(s)
	local h = 2166136261
	for i = 1, #s do
		h = bit32.bxor(h, string.byte(s, i))
		-- h * 16777619 mod 2^32 without losing precision: prime = 2^24 + 403
		h = (bit32.lshift(h, 24) + h * 403) % 4294967296
	end
	return h
end

local SUFFIX = { Script = ".server.luau", LocalScript = ".client.luau", ModuleScript = ".luau" }

local lines = {}
for _, root in ipairs(ROOTS) do
	for _, inst in ipairs(root:GetDescendants()) do
		if inst:IsA("LuaSourceContainer") and SUFFIX[inst.ClassName] then
			local segs, cur = {}, inst
			while cur and cur ~= root.Parent do
				table.insert(segs, 1, (string.gsub(cur.Name, "/", "_")))
				cur = cur.Parent
			end
			local src = string.gsub(inst.Source, "\r\n", "\n")
			table.insert(lines, string.format("%s%s\t%d\t%08x", table.concat(segs, "/"), SUFFIX[inst.ClassName], #src, fnv1a32(src)))
		end
	end
end
table.sort(lines)
return table.concat(lines, "\n")
