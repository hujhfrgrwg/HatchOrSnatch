--!strict
-- ChatTags (HOS-PASS-001, 16 Oct): a gold [VIP] ahead of VIP pass holders' names in chat.
-- TextChatService allows one OnIncomingMessage callback per client; this is it.
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local ChatTags = {}

function ChatTags.init()
	TextChatService.OnIncomingMessage = function(msg: TextChatMessage): TextChatMessageProperties?
		local src = msg.TextSource
		local plr = src and Players:GetPlayerByUserId(src.UserId)
		if not plr or plr:GetAttribute("EOS_VIP") ~= true then return nil end
		local props = Instance.new("TextChatMessageProperties")
		props.PrefixText = '<font color="#FFD23A">[VIP]</font> ' .. msg.PrefixText
		return props
	end
end

return ChatTags
