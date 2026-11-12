local S = ...

local style = {}

local defaults = {
	accent = Color3.fromRGB(10, 132, 255),
	background = Color3.fromRGB(16, 17, 20),
	panel = Color3.fromRGB(28, 29, 33),
	hover = Color3.fromRGB(37, 38, 43),
	raised = Color3.fromRGB(23, 24, 28),
	text = Color3.fromRGB(238, 239, 242),
	muted = Color3.fromRGB(148, 150, 158),
	line = Color3.fromRGB(46, 48, 54),
	good = Color3.fromRGB(90, 214, 154),
	warn = Color3.fromRGB(255, 190, 100),
	bad = Color3.fromRGB(255, 96, 112),
	ink = Color3.fromRGB(12, 15, 22),
	radius = 4,
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
