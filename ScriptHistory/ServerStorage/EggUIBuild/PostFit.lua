--!strict
-- PostFit for EggUI (HOS-EGG-002 fixes, 17 Oct), from ui_hc/PostFit.luau (HOS-HOC-001). Run after
-- Builder.buildScreen / the templates rebuild + fit() x2:
--   require(game.ServerStorage.EggUIBuild.PostFit).run("Data_EggIncubator", game.StarterGui.EggUI.Root)
--   require(game.ServerStorage.EggUIBuild.PostFit).run("Data_Templates", game.ReplicatedStorage.EggUITemplates)
-- 1. fit() measures labels inside a "<Name>Big" frame (UIScale on titles over TextSize 100) against the unscaled width
--    and shrinks them by the frame's scale: inside a Big frame the label goes back to its design TextSize.
-- 2. Roblox's glyphs run a few % wider than the browser's: a label whose text spills its box is widened around its
--    anchor so the word never spills (TextBounds are screen pixels: divide out the Big frame's scale).

local HttpService = game:GetService("HttpService")

local PostFit = {}

function PostFit.run(dataName: string, root: Instance): string
	local data = HttpService:JSONDecode(require(script.Parent:WaitForChild(dataName) :: any))
	local design: { [string]: { ts: number, big: boolean } } = {}
	local function walk(n: any, path: string, inBig: boolean)
		local p = if path == "" then tostring(n.n) else path .. "." .. tostring(n.n)
		local big = inBig or (type(n.n) == "string" and n.n:match("Big$") ~= nil)
		if n.c == "TextLabel" and n.ts then
			design[p] = { ts = n.ts, big = big }
		end
		for _, k in ipairs(n.k or {}) do
			walk(k, p, big)
		end
	end
	walk(data, "", false)
	local fixed = {}
	for path, d in pairs(design) do
		local node: Instance? = root
		for part in string.gmatch(path, "[^%.]+") do
			node = node and node:FindFirstChild(part)
		end
		if node and node:IsA("TextLabel") then
			if d.big and node.TextSize ~= d.ts then
				table.insert(fixed, node.Name .. " " .. node.TextSize .. "->" .. d.ts)
				node.TextSize = d.ts
			end
			local scaleObj = node.Parent and node.Parent:FindFirstChildOfClass("UIScale")
			local k = if d.big and scaleObj then scaleObj.Scale else 1
			local fit = root:FindFirstAncestorWhichIsA("ScreenGui")
			local fs = fit and fit:FindFirstChild("FitScale", true)
			if fs and fs:IsA("UIScale") then k *= fs.Scale end
			local need = math.ceil(node.TextBounds.X / k) + 6
			local w = node.Size.X.Offset
			if node.TextBounds.X > 0 and node.Size.X.Scale == 0 and need > w then
				local grow = need - w
				node.Size = UDim2.new(0, need, node.Size.Y.Scale, node.Size.Y.Offset)
				node.Position = UDim2.new(node.Position.X.Scale, node.Position.X.Offset - grow * node.AnchorPoint.X, node.Position.Y.Scale, node.Position.Y.Offset)
				local sh = node.Parent and node.Parent:FindFirstChild(node.Name .. "Shadow")
				if sh and sh:IsA("TextLabel") then
					sh.Size = node.Size
					sh.Position = UDim2.new(sh.Position.X.Scale, sh.Position.X.Offset - grow * sh.AnchorPoint.X, sh.Position.Y.Scale, sh.Position.Y.Offset)
				end
				table.insert(fixed, node.Name .. " w " .. w .. "->" .. need)
			end
		end
	end
	return "PostFit " .. dataName .. ": " .. (if #fixed > 0 then table.concat(fixed, ", ") else "nothing to fix")
end

return PostFit
