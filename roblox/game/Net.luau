--!strict
-- Net: the game's remotes in one place. The server creates them; clients wait for them.
-- Client -> server remotes carry HINTS only; the server validates every field.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

-- server -> client
Net.TO_CLIENT = {
	"MatchState", -- one-shot phase announcements (the live state is in EOSState attributes)
	"RoleChanged", -- { role, cause, bankedTier, by }
	"RunnerEvolved", -- { userId, prevTier, newTier, shells }
	"CaptureFeedback", -- { hunterId, victimId, stolenTier, creditedTier, position }
	"Results", -- results payload (top 3, your reward, next match time)
	"QuestState", -- quest list for the owner
	"ProfileState", -- full client view of the owner's profile
	"Toast", -- { text, kind }
	"OpenScreen", -- { name } walk-up prompts open screens
	"PracticeEvent", -- { kind = "tagged" | "crossed" }
	"HatchResult", -- { ok, reason, pet, plan } after RequestHatch
	"CrateResult", -- { ok, reason, emote, dupe, refund } after RequestOpenCrate
	"ShopResult", -- { ok, reason, itemId, robux?, refunded? } or a Gem pack { ok, gems }
	"AbilityFx", -- { userId, slot?, family, kind, ... } everyone: a pet's ability fired (telegraph)
	"AbilityState", -- { family, readyAt, ok, reason } owner: cooldown / refusal
	"ScoutPing", -- { targets = { { uid, slot?, pos } }, untilT } owner: Scout results
	"ServerList", -- { servers = { { id, players, max, country, code, city, phase, ping } }, here, t } after RequestServers
}
-- client -> server
Net.TO_SERVER = {
	"RequestTag", -- (targetUserId: number?, kind: "contact" | "swing" | "lunge", aim: Vector3? world direction of the hit)
	"RequestLunge", -- (dir: Vector3) a Catcher's lunge started (Space); the server times the slow after it
	"RequestOpenCrate", -- () open one Emote Crate with Gems (lobby only)
	"RequestEmote", -- (emoteId: string) play an owned emote in the lobby; "" stops
	"RequestQuestClaim", -- (questId: string)
	"RequestAFK", -- (on: boolean)
	"RequestVolunteer", -- (on: boolean)
	"RequestSettings", -- (settings: { sfx: boolean?, reduceEffects: boolean?, showHints: boolean? })
	"RequestProfile", -- ()
	"RequestLook", -- (headYaw: number, headPitch: number) radians, relative to the body; cosmetic only
	"RequestHatch", -- (rarity: string, family: string?, allowHigher: boolean?)
	"RequestEquipPet", -- (petId: string) "" = unequip
	"RequestBuy", -- (itemId: string)
	"RequestUseItem", -- (itemId: string) lobby consumables (confetti)
	"RequestSetCosmetic", -- (slot: "case" | "trailNext", itemId: string)
	"RequestAbility", -- (moveDir: Vector3?) the equipped pet's ability (Q / ability button)
	"RequestEmoteWheel", -- (slots: { string }) the 6 emotes on your wheel ("" = empty); owned emotes only
	"RequestServers", -- () the live server list (ServerList back)
	"RequestJoinServer", -- (jobId: string) teleport to another live server of this place
}

local FOLDER = "EOS_Remotes"

local function folder(): Folder
	local f = ReplicatedStorage:FindFirstChild(FOLDER)
	if not f then
		assert(RunService:IsServer(), "remotes are created by the server")
		f = Instance.new("Folder")
		f.Name = FOLDER
		f.Parent = ReplicatedStorage
	end
	return f :: Folder
end

-- Server: create every remote once. Unused server->client remotes get a no-op client listener
-- in ClientMain (avoids "invocation queue exhausted").
function Net.setup()
	local f = folder()
	for _, list in ipairs({ Net.TO_CLIENT, Net.TO_SERVER }) do
		for _, name in ipairs(list) do
			if not f:FindFirstChild(name) then
				local r = Instance.new("RemoteEvent")
				r.Name = name
				r.Parent = f
			end
		end
	end
end

function Net.event(name: string): RemoteEvent
	if RunService:IsServer() then
		local r = folder():FindFirstChild(name)
		assert(r, "unknown remote " .. name)
		return r :: RemoteEvent
	end
	local f = ReplicatedStorage:WaitForChild(FOLDER, 30)
	assert(f, "remotes folder missing")
	local r = f:WaitForChild(name, 30)
	assert(r, "unknown remote " .. name)
	return r :: RemoteEvent
end

-- The replicated live match state (attributes on a Configuration).
Net.STATE_NAME = "EOS_State"
function Net.state(): Configuration
	local s = ReplicatedStorage:FindFirstChild(Net.STATE_NAME)
	if not s then
		if RunService:IsServer() then
			s = Instance.new("Configuration")
			s.Name = Net.STATE_NAME
			s.Parent = ReplicatedStorage
		else
			s = ReplicatedStorage:WaitForChild(Net.STATE_NAME, 30)
		end
	end
	return s :: Configuration
end

return Net
