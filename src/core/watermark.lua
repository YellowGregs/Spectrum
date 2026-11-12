local S = ...

local env = S.env
local util = S.util
local style = S.style
local bold = Enum.Font.GothamBold

local watermark = {}

local function values()
	return style.values
end

local text = ""
local shown = false

local card = util.new("Frame", {
	Name = "watermark",
	BackgroundColor3 = values().panel,
	BackgroundTransparency = 0.12,
	BorderSizePixel = 0,
	AutomaticSize = Enum.AutomaticSize.X,
	Position = UDim2.fromOffset(12, 12),
	Size = UDim2.fromOffset(0, 24),
	Visible = false,
	ZIndex = 2,
	Parent = env.notes,
})
util.corner(card, 4)
util.new("UIPadding", {
	PaddingRight = UDim.new(0, 10),
	Parent = card,
})
local edge = util.stroke(card, values().line, 0.25)
util.shadow(card, 10, 0.55)
local tick = util.new("Frame", {
	BackgroundColor3 = values().accent,
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 10, 0.5, 0),
	Size = UDim2.fromOffset(2, 12),
	ZIndex = 3,
	Parent = card,
})
local label = util.new("TextLabel", {
	BackgroundTransparency = 1,
	AutomaticSize = Enum.AutomaticSize.X,
	Position = UDim2.fromOffset(19, 0),
	Size = UDim2.fromOffset(0, 24),
	Font = bold,
	Text = "",
	TextColor3 = values().text,
	TextSize = util.size(10),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Center,
	ZIndex = 3,
	Parent = card,
})

local function paint()
	card.Visible = shown and text ~= ""
	card.BackgroundColor3 = values().panel
	edge.Color = values().line
	tick.BackgroundColor3 = values().accent
	label.TextColor3 = values().text
end

function watermark.set(value)
	text = type(value) == "string" and value or ""
	shown = text ~= ""
	paint()
	return watermark.get()
end

function watermark.visible(state)
	shown = state == true
	paint()
	return shown
end

function watermark.get()
	return text, shown
end

style.paint(paint)
paint()

S.watermark = watermark
