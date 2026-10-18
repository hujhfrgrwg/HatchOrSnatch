--!strict
-- TrailLook (shared): how each egg trail is drawn, HOS-TRAIL-002. One table for every place a trail shows: the
-- carried egg in a match and your back in the lobby (EconomyService.trailOn), the Shop's preview
-- (ShopItemPreview.trailScene) and the dash streaks (SlideFX).
--   TrailLook.LAYERS[itemId]   { { tex, width, life } }: each layer's texture, width (x 0.8 studs) and lifetime (s)
--   TrailLook.color(item)      the trail's ColorSequence (the rainbow for Rainbow Trail, else the item's colour)

local TrailLook = {}

-- HOS-VFX-RES-001 (Hunter, 17 Oct: use the UNSORTED OS RESOURCES place where it beats ours): textured trail
-- layers instead of flat colour strips. Not our uploads (realkilometers' Stardust, Arisu Club's wisp,
-- BloxenRBLX's ember); if one is ever deleted that layer just draws blank. Swap in our own when we draw them.
TrailLook.LAYERS = {
	trail_spark = { { tex = "rbxassetid://18568183566", width = 1, life = 0.5 }, { tex = "rbxassetid://18568048335", width = 0.6, life = 0.35 } },
	trail_ember = { { tex = "rbxassetid://70464235210468", width = 1, life = 0.4 } },
	trailp_rainbow = { { tex = "rbxassetid://99421661918040", width = 1, life = 0.55 }, { tex = "rbxassetid://18568048335", width = 0.7, life = 0.4 } },
}

TrailLook.RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 214, 72)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(110, 236, 120)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(90, 170, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 120, 255)),
})

function TrailLook.color(item: any): ColorSequence
	return if item.id == "trailp_rainbow" then TrailLook.RAINBOW else ColorSequence.new(item.color)
end

return TrailLook
