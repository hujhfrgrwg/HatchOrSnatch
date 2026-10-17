--!nocheck
-- Field Gem (HOS-GEMS-002): green brilliant cut like the HUD icon (Assets/UI/icons/gem.png).
-- One part (Body), no moving pieces. 1.8 studs across the girdle, 96 flat-shaded triangles:
-- octagonal table, 8 star + 16 upper-girdle crown facets, girdle band, 16 lower-girdle + 8 main
-- pavilion facets to a point. Per-facet flat colours, deep to light green with white glints.
-- lib.seed = 1 builds it pre-rotated for FieldGemService, which stands every Gem at
-- CFrame.Angles(45deg, 0, 35deg): the mesh carries Rz(-35) * Rx(-20), so in game the Gem ends up
-- table-up, tilted 25deg toward the player, spinning about world Y. No seed = upright, for previews.
return function(em, lib, Shapes)
	local V3, C3 = lib.Vector3, lib.Color3
	local S = Shapes.new(em, lib)

	local R = 0.9 -- girdle radius (1.8 across)
	local TR, CH = 0.55 * R, 0.46 * R -- table radius, crown height
	local G = 0.04 -- half girdle thickness
	local PD, PR = 0.95 * R, 0.5 * R -- pavilion depth, radius of the pavilion-main ring
	local PY = -0.5 * PD

	local col = {
		table = C3.fromRGB(170, 255, 190),
		glint = C3.fromRGB(245, 255, 248),
		starA = C3.fromRGB(120, 250, 150),
		starB = C3.fromRGB(80, 230, 115),
		upperA = C3.fromRGB(55, 205, 95),
		upperB = C3.fromRGB(30, 160, 70),
		girdle = C3.fromRGB(25, 120, 55),
		lowerA = C3.fromRGB(35, 170, 80),
		lowerB = C3.fromRGB(15, 105, 50),
		main = C3.fromRGB(70, 220, 110),
		deep = C3.fromRGB(10, 80, 40),
	}

	local tilt = lib.seed == 1
	local function rx(a, v)
		local c, s = math.cos(a), math.sin(a)
		return V3.new(v.X, c * v.Y - s * v.Z, s * v.Y + c * v.Z)
	end
	local function rz(a, v)
		local c, s = math.cos(a), math.sin(a)
		return V3.new(c * v.X - s * v.Y, s * v.X + c * v.Y, v.Z)
	end
	local function place(v)
		if tilt then
			return rz(math.rad(-35), rx(math.rad(-20), v))
		end
		return v + V3.new(0, PD, 0) -- upright preview: culet on the ground
	end
	local function ring(n, r, y, off)
		local out = {}
		for i = 0, n - 1 do
			local a = 2 * math.pi * (i + (off or 0)) / n
			out[i] = V3.new(r * math.cos(a), y, r * math.sin(a))
		end
		return out
	end
	-- a flat facet, wound so it faces away from the gem's centre
	local centre = V3.new(0, 0, 0)
	local function facet(a, b, c, color)
		local n = (b - a):Cross(c - a)
		if n:Dot((a + b + c) / 3 - centre) < 0 then
			b, c = c, b
		end
		S:tri(place(a), place(b), place(c), color)
	end

	local T = ring(8, TR, CH)
	local TC = V3.new(0, CH, 0)
	local GU, GL = ring(16, R, G), ring(16, R, -G)
	local P = ring(8, PR, PY)
	local CU = V3.new(0, -PD, 0)

	for i = 0, 7 do
		local j = (i + 1) % 8
		facet(TC, T[i], T[j], if i % 3 == 0 then col.glint else col.table) -- table
		facet(T[i], T[j], GU[2 * i + 1], if i == 1 then col.glint elseif i % 2 == 0 then col.starA else col.starB) -- star
		facet(T[i], GU[2 * i + 1], GU[2 * i], if i % 2 == 0 then col.upperA else col.upperB) -- upper girdle
		facet(T[j], GU[(2 * i + 2) % 16], GU[2 * i + 1], if i % 2 == 0 then col.upperB else col.upperA)
	end
	for k = 0, 15 do
		local m = (k + 1) % 16
		facet(GU[k], GU[m], GL[m], col.girdle)
		facet(GU[k], GL[m], GL[k], col.girdle)
	end
	for i = 0, 7 do
		local j = (i + 1) % 8
		facet(GL[2 * i], GL[2 * i + 1], P[i], if i % 2 == 0 then col.lowerA else col.lowerB) -- lower girdle
		facet(GL[2 * i + 1], GL[(2 * i + 2) % 16], P[j], if i % 2 == 0 then col.lowerB else col.lowerA)
		facet(P[i], GL[2 * i + 1], P[j], col.main) -- pavilion main
		facet(P[i], P[j], CU, if i % 2 == 0 then col.lowerA else col.deep)
	end
end
