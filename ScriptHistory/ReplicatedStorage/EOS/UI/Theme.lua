--!strict
-- Theme: UI tokens. Oct 2026 restyle (the developer's reference screenshots): "less studdy but still
-- some subtle stud element". Dark see-through rounded panels with a thin light edge, white bold text
-- with a dark outline, pill buttons, coloured accent underlines, currency panels with a faint stud
-- texture. Coloured (solid) plates are kept for actions (claim, buy, hatch, tag, dash).

local Theme = {}

Theme.ink = Color3.fromRGB(7, 10, 14)
Theme.textOutline = Color3.fromRGB(18, 18, 18)
Theme.glass = Color3.fromRGB(8, 14, 22)
Theme.glassT = 0.12 -- big panels over a bright world stay ~90% opaque (LESSONS 6)
Theme.hudGlassT = 0.22 -- persistent HUD chrome lets the world read through a little
Theme.sel = Color3.fromRGB(255, 243, 90)
Theme.gold = Color3.fromRGB(255, 210, 58)
Theme.white = Color3.new(1, 1, 1)
Theme.mutedText = Color3.fromRGB(196, 206, 222)

-- restyle tokens
Theme.panel = Color3.fromRGB(17, 20, 27) -- dark glass for buttons, cards and panels
Theme.panelT = 0.22 -- HUD chrome: the world shows through a little
Theme.windowT = 0.08 -- open windows over a bright world stay nearly opaque
Theme.edge = Color3.fromRGB(255, 255, 255) -- thin light edge on dark glass
Theme.edgeT = 0.84
Theme.studT = 0.9 -- the subtle stud texture on dark glass (solid plates use studSolidT)
Theme.studSolidT = 0.62
Theme.goldText = Color3.fromRGB(255, 214, 64)
Theme.gemText = Color3.fromRGB(96, 236, 150)
Theme.badge = Color3.fromRGB(232, 52, 64)

Theme.font = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)
Theme.fontBody = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold)

-- uploaded from the toolkit (ui-resources.com / RoClicks packs), owned by the developer
Theme.img = {
	stud = "rbxassetid://75407673232479", -- EOS_StudUI: the ui-kit MAIN stud texture with alpha x3 (no overlay blend in Roblox)
	studRaw = "rbxassetid://129350760178240", -- EOS_Stud: untouched original
	sunburst = "rbxassetid://81132301762053",
	sparkle = "rbxassetid://103534805384652",
	shine = "rbxassetid://116455865107907",
	ring = "rbxassetid://112303046387576",
	twinkleFlip = "rbxassetid://94396983125593",
}

local function rgb(hex: string): Color3
	return Color3.fromHex(hex)
end

export type Ramp = { ol: Color3, rim: Color3, top: Color3, mid: Color3, bot: Color3, lip: Color3, lip2: Color3 }

-- colour ramps (stud.css .c-*): outline, rim, top/mid/bottom face, two-tone lip
Theme.ramps = {
	blue = { ol = rgb("04161d"), rim = rgb("9fe6f5"), top = rgb("7adcef"), mid = rgb("57c6e8"), bot = rgb("3cc6fb"), lip = rgb("127aa5"), lip2 = rgb("0b5f84") },
	green = { ol = rgb("031a06"), rim = rgb("b2ff92"), top = rgb("80ee5a"), mid = rgb("4ced41"), bot = rgb("20f633"), lip = rgb("0aa31a"), lip2 = rgb("058212") },
	red = { ol = rgb("1c0204"), rim = rgb("ffaab0"), top = rgb("ef747c"), mid = rgb("e24b51"), bot = rgb("f9505a"), lip = rgb("9c1b1f"), lip2 = rgb("7a1418") },
	yellow = { ol = rgb("241500"), rim = rgb("fff3b0"), top = rgb("ffe47a"), mid = rgb("ffc935"), bot = rgb("ffbd0a"), lip = rgb("b87400"), lip2 = rgb("8c5800") },
	orange = { ol = rgb("241000"), rim = rgb("ffd2a6"), top = rgb("ffb36a"), mid = rgb("ff8f2e"), bot = rgb("ff7d10"), lip = rgb("b44c00"), lip2 = rgb("8a3800") },
	purple = { ol = rgb("14041f"), rim = rgb("e9c2ff"), top = rgb("cf8fff"), mid = rgb("a95cf2"), bot = rgb("9b45f7"), lip = rgb("5c1d9c"), lip2 = rgb("46137a") },
	grey = { ol = rgb("101316"), rim = rgb("e9eef2"), top = rgb("c3cad0"), mid = rgb("9aa2a9"), bot = rgb("8c959d"), lip = rgb("4f575e"), lip2 = rgb("3c4349") },
	dark = { ol = rgb("06090c"), rim = rgb("5d6a76"), top = rgb("46525d"), mid = rgb("343e48"), bot = rgb("2c353e"), lip = rgb("161c22"), lip2 = rgb("0f1418") },
	gold = { ol = rgb("2a1700"), rim = rgb("fff6c4"), top = rgb("fff07a"), mid = rgb("ffd23a"), bot = rgb("ffbf1c"), lip = rgb("c27a00"), lip2 = rgb("965d00") },
	pink = { ol = rgb("1f0410"), rim = rgb("ffd0e6"), top = rgb("ffa3cf"), mid = rgb("ff74b4"), bot = rgb("ff5aa6"), lip = rgb("b02a6a"), lip2 = rgb("8a1f52") },
} :: { [string]: Ramp }

-- motion (STYLE.md section 5)
Theme.motion = {
	openFrom = 0.6,
	openTime = 0.34,
	closeTime = 0.16,
	hoverScale = 1.05,
	pressScale = 0.93,
	countUp = 0.45,
}

-- built-in client sounds (ship with every Roblox client, no permissions). Each id was probed in
-- Studio on 2026-10-14 (IsLoaded + TimeLength > 0); swoosh.wav / ping.wav did NOT load.
Theme.sounds = {
	click = "rbxasset://sounds/clickfast.wav", -- 0.29 s
	open = "rbxasset://sounds/switch.wav", -- 0.24 s
	reward = "rbxasset://sounds/victory.wav", -- 1.31 s
	capture = "rbxasset://sounds/hit.wav", -- 0.84 s
	swing = "rbxasset://sounds/swordslash.wav", -- 0.65 s
	evolve = "rbxasset://sounds/electronicpingshort.wav", -- 0.72 s
	tick = "rbxasset://sounds/button.wav", -- 0.58 s
	caught = "rbxasset://sounds/snap.mp3", -- 0.42 s
}

return Theme
