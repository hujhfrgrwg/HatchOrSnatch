--!nocheck
-- Photo booth for UI art (run with execute_luau on the Hatch or Snatch place, EDIT mode).
-- Shows 8 showroom models per frame in a temporary, non-saving ScreenGui (StarterGui, Archivable=false)
-- of ViewportFrames on pure magenta, lit like PetModel.viewport, yaw 25. Capture the viewport with
-- capture_screenshot(format=png) after each call, then: python3 tools/key_booth.py shots.json
-- (shots.json = [[capture.png, [ "Family/Model", ... ]], ...]). ALWAYS run the cleanup at the end.
-- StarterGui is used because CoreGui is not in captures. The developer's viewport shows magenta meanwhile.
local SG = game:GetService("StarterGui")
local gui = SG:FindFirstChild("EOS_PhotoBooth") or Instance.new("ScreenGui")
gui.Name = "EOS_PhotoBooth"; gui.Archivable = false; gui.IgnoreGuiInset = true; gui.DisplayOrder = 1000000
local bg = gui:FindFirstChildOfClass("Frame") or Instance.new("Frame", gui)
bg.Size = UDim2.fromScale(1, 1); bg.BackgroundColor3 = Color3.fromRGB(255, 0, 255); bg.BorderSizePixel = 0
gui.Parent = SG

_G.EOSBooth = function(list, yaw, zooms)
	for _, c in ipairs(bg:GetChildren()) do c:Destroy() end
	local cols, rows = 4, 2
	local D = workspace.FWP_PetShowroom.Displays
	for i, path in ipairs(list) do
		local fam, name = path:match("([^/]+)/(.+)")
		local src = D[fam]:FindFirstChild(name)
		local vp = Instance.new("ViewportFrame")
		vp.Size = UDim2.fromScale(1 / cols, 1 / rows)
		vp.Position = UDim2.fromScale(((i - 1) % cols) / cols, math.floor((i - 1) / cols) / rows)
		vp.BackgroundColor3 = Color3.fromRGB(255, 0, 255); vp.BorderSizePixel = 0
		vp.Ambient = Color3.fromRGB(205, 205, 210); vp.LightColor = Color3.new(1, 1, 1); vp.LightDirection = Vector3.new(-0.4, -1, 0.6)
		vp.Parent = bg
		if src then
			local m = src:Clone()
			local cf = m:GetBoundingBox()
			m:PivotTo(CFrame.Angles(0, math.rad(yaw or 25), 0) * (cf - cf.Position):Inverse() * CFrame.new(-cf.Position) * m:GetPivot())
			m.Parent = vp
			local _, size = m:GetBoundingBox()
			local cam = Instance.new("Camera"); cam.FieldOfView = 30
			local aspect = (vp.AbsoluteSize.X > 0 and vp.AbsoluteSize.X / vp.AbsoluteSize.Y) or 1
			local halfV = math.rad(15); local halfH = math.atan(math.tan(halfV) * aspect)
			local d = size.Magnitude / 2 * 0.82 / math.sin(math.min(halfV, halfH)) * ((zooms and zooms[i]) or 1)
			cam.CFrame = CFrame.lookAt(Vector3.new(0, d * 0.22, -d), Vector3.zero)
			cam.Parent = vp; vp.CurrentCamera = cam
		end
	end
	return #list
end
-- cleanup (run when done):
-- game:GetService("StarterGui").EOS_PhotoBooth:Destroy(); _G.EOSBooth = nil
