--!strict
-- PostFit (HOS-HOC-001, 17 Oct): run after Builder.build() + fit() x2 for HeroChickenUI.
-- roblox-ui-maker's fit() measures labels inside a "<Name>Big" frame (a UIScale on titles over
-- TextSize 100) against the frame's unscaled width, so it shrinks them by the frame's scale
-- (HERO! 100 -> 51 under x1.82). Inside a Big frame the UIScale already does the growing, so the
-- label's own TextSize goes back to the design size from Data_HeroChicken.
--   require(game.ServerStorage.HeroChickenUIBuild.PostFit).run()  -> report string

local HttpService = game:GetService("HttpService")

local PostFit = {}

function PostFit.run(): string
	local data = HttpService:JSONDecode(require(script.Parent:WaitForChild("Data_HeroChicken") :: any))
	local design: { [string]: number } = {}
	local function walk(n: any, path: string, inBig: boolean)
		local p = path .. "." .. tostring(n.n)
		local big = inBig or (type(n.n) == "string" and n.n:match("Big$") ~= nil)
		if n.c == "TextLabel" and big and n.ts then
			design[p] = n.ts
		end
		for _, k in ipairs(n.k or {}) do
			walk(k, p, big)
		end
	end
	walk(data, "", false)
	local root = game:GetService("StarterGui"):WaitForChild("HeroChickenUI"):WaitForChild("Root")
	local fixed = {}
	for path, ts in pairs(design) do
		local node: Instance? = root
		for part in string.gmatch(path, "[^%.]+") do
			node = node and node:FindFirstChild(part)
		end
		if node and node:IsA("TextLabel") and node.TextSize ~= ts then
			table.insert(fixed, node.Name .. " " .. node.TextSize .. "->" .. ts)
			node.TextSize = ts
		end
		-- Roblox's glyphs run a few % wider than the browser's: widen the box around its centre so the
		-- word never spills (TextBounds are on-screen pixels, so divide out the Big frame's scale)
		if node and node:IsA("TextLabel") then
			local scaleObj = node.Parent and node.Parent:FindFirstChildOfClass("UIScale")
			local k = if scaleObj then scaleObj.Scale else 1
			local need = math.ceil(node.TextBounds.X / k) + 10
			local w = node.Size.X.Offset
			if node.TextBounds.X > 0 and need > w then
				local grow = need - w
				node.Size = UDim2.new(node.Size.X.Scale, need, node.Size.Y.Scale, node.Size.Y.Offset)
				node.Position = UDim2.new(node.Position.X.Scale, node.Position.X.Offset - grow * (0.5 - node.AnchorPoint.X), node.Position.Y.Scale, node.Position.Y.Offset)
				table.insert(fixed, node.Name .. " w " .. w .. "->" .. need)
			end
		end
	end
	return "PostFit: " .. (if #fixed > 0 then table.concat(fixed, ", ") else "nothing to fix")
end

return PostFit
