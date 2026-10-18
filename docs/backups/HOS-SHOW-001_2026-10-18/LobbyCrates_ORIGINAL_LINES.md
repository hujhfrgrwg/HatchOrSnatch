# LobbyCrates: original lines replaced by HOS-SHOW-001 (18 Oct 2026)

`StarterPlayer.StarterPlayerScripts.EOS.Controllers.LobbyCrates` (HOS-WEP-001, another session's script; not in ScriptHistory yet, 19,211 bytes before this change, CRLF line endings). Only these two spots changed; put them back to restore the crates' own prompts.

## Header (lines 10-11)
```lua
-- * Walk up: "Open" (hold E / tap) buys one crate: RequestWeaponCrate(1, id), the same as the Shop's OPEN; short on
--   Gems, the Gems offer instead. "What's inside" (F) opens the Shop on that crate's popup.
```

## In setup(model), after the old-prompt clean-up loop
```lua
	local at = Instance.new("Attachment")
	at.Name = "LobbyCratePrompts"
	at.Parent = body
	at.WorldPosition = glow.Position + Vector3.new(0, 0.6, 0) -- (after parenting: before, it's taken as 0,0,0)
	table.insert(c.prompts, prompt(at, ("Open  ·  %d Gems"):format(def.gems), def.name, Enum.KeyCode.E, 0.4, -PROMPT_GAP, function()
		task.spawn(buy, c)
	end))
	table.insert(c.prompts, prompt(at, "What's inside", def.name, Enum.KeyCode.F, 0, PROMPT_GAP, function()
		local W = controller("WeaponShopUI")
		if W and W.showInside then
			W.showInside(c.id)
		end
	end))
```
