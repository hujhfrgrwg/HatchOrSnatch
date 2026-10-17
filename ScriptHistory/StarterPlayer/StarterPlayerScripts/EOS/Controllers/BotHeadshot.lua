-- BotHeadshot (HOS-BOT-001): a head-and-shoulders picture of an NPC wherever a real player shows
-- their Roblox headshot (Match Points rows, results podium). NPCs have no UserId to look up, so this
-- renders the NPC's own look (Controllers/NpcSkins Skin<slot>, the same for everyone) into a
-- ViewportFrame inside the slot. fill(holder, slot): show it; slot nil (a real player) hides it.
-- One render per holder, rebuilt only when that holder's slot (or the slot's look) changes.

local NpcSkins = require(script.Parent:WaitForChild("NpcSkins"))

local BotHeadshot = {}
local NAME = "EOS_BotShot"

function BotHeadshot.fill(holder: Instance?, slot: number?): boolean
	if not holder or not holder:IsA("GuiObject") then
		return false
	end
	local vp = holder:FindFirstChild(NAME) :: ViewportFrame?
	local skin = if slot then NpcSkins.skinFor(slot) else nil
	local head = skin and skin:FindFirstChild("Head") :: BasePart?
	if not skin or not head then
		if vp then
			vp.Visible = false
		end
		return false
	end
	local key = skin:GetAttribute("FriendUserId")
	if vp and vp:GetAttribute("Slot") == slot and vp:GetAttribute("Key") == key then
		vp.Visible = true
		return true
	end
	if vp then
		vp:Destroy()
	end
	local v = Instance.new("ViewportFrame")
	v.Name = NAME
	v.BackgroundTransparency = 1
	v.Size = UDim2.fromScale(1, 1)
	v.ZIndex = holder.ZIndex + 5 -- over the (empty) headshot image
	v.Ambient = Color3.fromRGB(190, 190, 190)
	v.LightColor = Color3.new(1, 1, 1)
	v.LightDirection = Vector3.new(-0.4, -1, -0.8)
	v:SetAttribute("Slot", slot)
	v:SetAttribute("Key", key)
	local corner = holder:FindFirstChildOfClass("UICorner")
	if corner then
		corner:Clone().Parent = v -- same rounding as the slot
	end
	local m = skin:Clone()
	-- the skin sits outside the world (PlayerGui), so its accessory welds were never solved: put each
	-- hat/hair handle on its matching body attachment by hand
	for _, acc in ipairs(m:GetChildren()) do
		local handle = acc:IsA("Accessory") and acc:FindFirstChild("Handle") :: BasePart?
		local a0 = handle and handle:FindFirstChildOfClass("Attachment")
		if handle and a0 then
			for _, part in ipairs(m:GetChildren()) do
				local a1 = part:IsA("BasePart") and part ~= handle and part:FindFirstChild(a0.Name)
				if a1 and a1:IsA("Attachment") then
					handle.CFrame = a1.WorldCFrame * a0.CFrame:Inverse()
					break
				end
			end
		end
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BaseScript") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	local hum = m:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- (kept: clothing needs it)
	end
	m.Parent = v
	local h = m:FindFirstChild("Head") :: BasePart
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	-- in front of the face (R6 faces -Z), aimed a little below it so the shoulders show
	cam.CFrame = CFrame.lookAt((h.CFrame * CFrame.new(0, 0.35, -4.4)).Position, h.Position - Vector3.new(0, 0.15, 0))
	cam.Parent = v
	v.CurrentCamera = cam
	v.Parent = holder
	return true
end

return BotHeadshot
