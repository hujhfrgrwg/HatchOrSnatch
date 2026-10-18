-- HOS-PTS-001 PointsUI build step, run once after Builder.build() and the two Builder.fit() passes (edit mode):
--   require(game.StarterGui.PointsUI.PostFit)()   (it ships in the bundle) or paste the body into execute_luau.
-- 1. Builder.fit() measures a label inside a "...Big" frame (exported titles over TextSize 100 carry a "BigText"
--    UIScale) against its unscaled design width, so it shrinks the label by the frame's scale. The exporter writes
--    those labels at TextSize 100 with scale = design / 100, so 100 is their right size: put it back (and the shadow's).
-- 2. The leaderboard rows' points pill is a fixed column (build.py PTS_PILL_W). The exported text box is only as wide
--    as the sample "618 PTS", so "+200 PTS" or "1,250 PTS" would shrink (UI.setText scales text to its box): stretch
--    the box (and its shadow) from the trophy to the pill's right padding and centre the text in it.
return function(gui: Instance?): string
	gui = gui or game:GetService("StarterGui"):FindFirstChild("PointsUI")
	assert(gui, "PointsUI missing")
	local fixed = {}
	for _, d in ipairs(gui:GetDescendants()) do
		if d:IsA("TextLabel") and d.Parent and d.Parent:FindFirstChild("BigText") and d.TextSize ~= 100 then
			table.insert(fixed, ("%s %d -> 100"):format(d.Name, d.TextSize))
			d.TextSize = 100
		end
	end
	local pills = 0
	for _, pill in ipairs(gui:GetDescendants()) do
		local row = pill.Parent
		if pill.Name == "PtsPill" and pill:IsA("Frame") and row and (row.Name == "Row" or row.Name == "YouRow") then
			local icon = pill:FindFirstChild("PtsIcon") :: GuiObject?
			local x0 = if icon then icon.Position.X.Offset + icon.Size.X.Offset + 2 else 12
			local w = pill.Size.X.Offset - x0 - 14
			for _, n in ipairs({ "PointsText", "PointsTextShadow" }) do
				local l = pill:FindFirstChild(n) :: TextLabel?
				if l then
					l.Position = UDim2.new(0, x0, l.Position.Y.Scale, l.Position.Y.Offset)
					l.Size = UDim2.new(0, w, l.Size.Y.Scale, l.Size.Y.Offset)
					l.TextXAlignment = Enum.TextXAlignment.Center
					l:SetAttribute("FitW", nil) -- the box is the column now, not the sample's width
				end
			end
			pills += 1
		end
	end
	return ("postfit: %s; %d row pills set to the fixed column"):format(if #fixed == 0 then "no Big labels to fix" else table.concat(fixed, ", "), pills)
end
