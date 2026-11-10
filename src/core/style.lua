local S = ...

local style = {}

local defaults = {
	accent = Color3.fromRGB(74, 134, 255),
	background = Color3.fromRGB(27, 29, 35),
	panel = Color3.fromRGB(38, 41, 49),
	hover = Color3.fromRGB(45, 49, 59),
	raised = Color3.fromRGB(33, 36, 43),
	text = Color3.fromRGB(232, 235, 242),
	muted = Color3.fromRGB(150, 157, 172),
	line = Color3.fromRGB(52, 56, 67),
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
local colorKeys = {
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
	for _, key in ipairs(colorKeys) do
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

style.values = values
S.style = style
