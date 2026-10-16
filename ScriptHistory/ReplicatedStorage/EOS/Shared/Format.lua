--!strict
-- Format: the ONE number/time formatter (adapted from the toolkit's NumberFormat snippet,
-- keeping its fix: zeros are only stripped after a decimal point, so 250,000 stays "250K").

local Format = {}

local SUFFIX = { "K", "M", "B", "T" }

function Format.full(n: number): string
	n = math.floor(n + 0.5)
	local s = tostring(math.abs(n))
	local out = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1,")))
	out = string.gsub(out, "^,", "")
	return (if n < 0 then "-" else "") .. out
end

function Format.short(n: number): string
	local a = math.abs(n)
	if a < 10000 then
		return Format.full(n)
	end
	local i = 0
	while a >= 1000 and i < #SUFFIX do
		a /= 1000
		i += 1
	end
	local s
	if a >= 100 then
		s = string.format("%d", math.floor(a))
	elseif a >= 10 then
		s = string.format("%.1f", math.floor(a * 10) / 10)
	else
		s = string.format("%.2f", math.floor(a * 100) / 100)
	end
	if string.find(s, ".", 1, true) then
		s = string.gsub(s, "0+$", "")
		s = string.gsub(s, "%.$", "")
	end
	return (if n < 0 then "-" else "") .. s .. SUFFIX[i]
end

-- 75 -> "1:15", 3725 -> "1:02:05"
function Format.time(sec: number): string
	sec = math.max(0, math.ceil(sec))
	local h, m, s = sec // 3600, (sec // 60) % 60, sec % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

-- 3725 -> "1h 2m", 125 -> "2m 5s"
function Format.duration(sec: number): string
	sec = math.max(0, math.floor(sec))
	local h, m, s = sec // 3600, (sec // 60) % 60, sec % 60
	if h > 0 then
		return string.format("%dh %dm", h, m)
	end
	if m > 0 then
		return string.format("%dm %ds", m, s)
	end
	return string.format("%ds", s)
end

function Format.plural(n: number, one: string, many: string?): string
	local suffix = if string.upper(one) == one then "S" else "s" -- "CAPTURES", not "CAPTUREs"
	return Format.full(n) .. " " .. (if n == 1 then one else (many or (one .. suffix)))
end

return Format
