local S = ...

local style = {}

local defaults = {
	accent = Color3.fromRGB(230, 162, 58),
	background = Color3.fromRGB(13, 14, 16),
	panel = Color3.fromRGB(24, 26, 29),
	hover = Color3.fromRGB(35, 38, 42),
	raised = Color3.fromRGB(18, 20, 23),
	text = Color3.fromRGB(232, 232, 228),
	muted = Color3.fromRGB(126, 132, 138),
	line = Color3.fromRGB(52, 56, 62),
	good = Color3.fromRGB(116, 196, 122),
	warn = Color3.fromRGB(230, 174, 78),
	bad = Color3.fromRGB(176, 52, 46),
	ink = Color3.fromRGB(15, 13, 9),
	radius = 0,
}

local values = {}
for key, value in pairs(defaults) do
	values[key] = value
end

local painters = {}
local color_keys = {
	"accent",
	"background",
	"panel",
	"hover",
	"raised",
	"text",
	"muted",
	"line",
	"good",
	"warn",
	"bad",
	"ink",
}

function style.paint(fn)
	painters[#painters + 1] = fn
	fn()
end

function style.copy()
	local copy = {}
	for key, value in pairs(values) do
		copy[key] = value
	end
	return copy
end

function style.apply(props)
	if type(props) ~= "table" then
		return style.copy()
	end
	for _, key in ipairs(color_keys) do
		if typeof(props[key]) == "Color3" then
			values[key] = props[key]
		end
	end
	if typeof(props.radius) == "number" then
		values.radius = math.clamp(props.radius, 0, 12)
	end
	for _, painter in ipairs(painters) do
		pcall(painter)
	end
	return style.copy()
end

function style.on(color)
	local luma = color.R * 0.299 + color.G * 0.587 + color.B * 0.114
	if luma > 0.6 then
		return values.ink
	end
	return Color3.new(1, 1, 1)
end

function style.variant(kind)
	local name = tostring(kind or "primary"):lower()
	if name == "danger" or name == "destructive" then
		return values.bad, style.on(values.bad)
	end
	if name == "secondary" or name == "surface" then
		return values.raised, values.text
	end
	return values.accent, style.on(values.accent)
end

style.values = values
S.style = style
