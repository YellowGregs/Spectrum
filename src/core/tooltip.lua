local S = ...

local env = S.env
local util = S.util
local style = S.style
local font = Enum.Font.GothamMedium

local tooltip = {}

local DELAY = 0.35
local GAP = 6
local EDGE = 6

local function values()
	return style.values
end

local panel = util.new("Frame", {
	Name = "tooltip",
	Active = false,
	BackgroundColor3 = values().panel,
	BorderSizePixel = 0,
	AutomaticSize = Enum.AutomaticSize.XY,
	Size = UDim2.fromOffset(0, 0),
	Visible = false,
	ZIndex = 60,
	Parent = env.modal,
})
util.corner(panel, 4)
local edge = util.stroke(panel, values().line, 0.15)
util.shadow(panel, 12, 0.4)
util.new("UISizeConstraint", {
	MaxSize = Vector2.new(260, 320),
	Parent = panel,
})
util.new("UIPadding", {
	PaddingTop = UDim.new(0, 6),
	PaddingBottom = UDim.new(0, 6),
	PaddingLeft = UDim.new(0, 8),
	PaddingRight = UDim.new(0, 8),
	Parent = panel,
})

local label = util.new("TextLabel", {
	Name = "body",
	BackgroundTransparency = 1,
	AutomaticSize = Enum.AutomaticSize.Y,
	Size = UDim2.fromOffset(0, 0),
	Font = font,
	Text = "",
	TextColor3 = values().text,
	TextSize = util.size(10),
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	ZIndex = 61,
	Parent = panel,
})

local current

local function hide()
	current = nil
	if panel.Parent then
		panel.Visible = false
	end
end

local function place(target)
	local view = env.viewport()
	local pos = target.AbsolutePosition
	local size = target.AbsoluteSize
	local width = panel.AbsoluteSize.X
	local height = panel.AbsoluteSize.Y
	if width <= 0 or height <= 0 then
		return
	end
	local x = pos.X + size.X * 0.5 - width * 0.5
	x = math.clamp(x, EDGE, math.max(EDGE, view.X - width - EDGE))
	local y = pos.Y + size.Y + GAP
	if y + height > view.Y - EDGE then
		y = pos.Y - height - GAP
	end
	y = math.clamp(y, EDGE, math.max(EDGE, view.Y - height - EDGE))
	panel.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
end

local function show(target, body)
	if type(body) ~= "string" or body == "" or not target.Parent then
		return
	end
	current = target
	label.Text = body
	label.Size = UDim2.fromOffset(math.clamp(math.floor(#body * 5.6) + 6, 44, 236), 0)
	panel.Visible = true
	place(target)
	task.defer(function()
		if current == target and panel.Parent and panel.Visible then
			place(target)
		end
	end)
end

function tooltip.attach(target, text)
	if not target or (type(text) ~= "string" and type(text) ~= "function") then
		return
	end
	if type(text) == "string" and text == "" then
		return
	end
	local token = 0

	local function source()
		if type(text) == "function" then
			local ok, value = pcall(text)
			if ok and type(value) == "string" and value ~= "" then
				return value
			end
			return nil
		end
		return text
	end

	target.MouseEnter:Connect(function()
		local body = source()
		if not body then
			return
		end
		token = token + 1
		local mine = token
		task.delay(DELAY, function()
			if mine ~= token or current == target or not target.Parent then
				return
			end
			show(target, source())
		end)
	end)

	target.MouseLeave:Connect(function()
		token = token + 1
		if current == target then
			hide()
		end
	end)

	target.Destroying:Connect(function()
		token = token + 1
		if current == target then
			hide()
		end
	end)
end

function tooltip.hide()
	hide()
end

env.uis.InputBegan:Connect(function(input)
	local kind = input.UserInputType
	if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
		hide()
	end
end)

style.paint(function()
	panel.BackgroundColor3 = values().panel
	edge.Color = values().line
	label.TextColor3 = values().text
end)

S.tooltip = tooltip
