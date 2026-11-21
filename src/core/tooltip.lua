local S = ...

local env = S.env
local util = S.util
local style = S.style
local icons = S.icons
local font = Enum.Font.RobotoCondensed
local bold = Enum.Font.GothamBold

local tooltip = {}

local DELAY = 0.26
local GAP = 8
local EDGE = 10
local PAD = 9
local PAD_Y = 7
local MARK = 11
local MARK_GAP = 7
local MIN_TEXT = 40
local MAX_TEXT = 208
local LINE = 12

local TextService = game:GetService("TextService")

local function values()
	return style.values
end

local panel = util.new("Frame", {
	Name = "tooltip",
	Active = false,
	BackgroundColor3 = values().panel,
	BorderSizePixel = 0,
	Size = UDim2.fromOffset(0, 0),
	Visible = false,
	ZIndex = 60,
	Parent = env.modal,
})
util.corner(panel, 0)
util.depth(panel, 0.8)
local edge = util.stroke(panel, values().line, 0.18)
util.shadow(panel, 18, 0.4)

local mark = icons.image(panel, "info", MARK, values().muted)
if mark then
	mark.AnchorPoint = Vector2.new(0, 0)
	mark.Position = UDim2.fromOffset(PAD, PAD_Y)
	mark.ZIndex = 62
	icons.layer(mark, 62)
end

local kicker = util.new("TextLabel", {
	Name = "heading",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(PAD, PAD_Y),
	Size = UDim2.fromOffset(0, 0),
	Font = bold,
	Text = "",
	TextColor3 = values().text,
	TextSize = util.size(9),
	TextTruncate = Enum.TextTruncate.AtEnd,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	ZIndex = 61,
	Parent = panel,
})

local body = util.new("TextLabel", {
	Name = "body",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(PAD, PAD_Y),
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

local group_ok = pcall(function()
	panel.GroupTransparency = 0
end)

local current

local function measure(text, size, face, width)
	local ok, box = pcall(function()
		return TextService:GetTextSize(text, size, face, Vector2.new(width, 2048))
	end)
	if ok and typeof(box) == "Vector2" then
		return math.ceil(box.X), math.ceil(box.Y)
	end
	return math.min(width, math.ceil(#text * size * 0.52)), size + 2
end

local function split(value)
	value = string.gsub(value, "^\n+", "")
	value = string.gsub(value, "\n+$", "")
	local head, rest = string.match(value, "^([^\r\n]+)\r?\n(.+)$")
	return head, rest or value
end

local function render(value)
	local head, rest = split(value)
	local text_size = util.size(10)
	local head_size = util.size(9)
	local head_w, head_h = 0, 0
	if head then
		head = string.upper(head)
		head_w, head_h = measure(head, head_size, bold, MAX_TEXT)
	end
	local body_w = measure(rest, text_size, font, MAX_TEXT)
	local text_w = math.clamp(math.max(head_w, body_w), MIN_TEXT, MAX_TEXT)
	local _, wrapped_body = measure(rest, text_size, font, text_w)
	local wrapped_head = head_h
	if head then
		local _, fit = measure(head, head_size, bold, text_w)
		wrapped_head = math.max(1, fit)
	end
	local content = wrapped_body + (head and (wrapped_head + 2) or 0)
	content = math.max(content, LINE)

	local left = PAD + (mark and (MARK + MARK_GAP) or 0)
	local width = left + text_w + PAD + 2
	local height = content + PAD_Y * 2 + 1
	panel.Size = UDim2.fromOffset(math.floor(width + 0.5), math.floor(height + 0.5))

	kicker.Visible = head ~= nil
	kicker.Text = head or ""
	kicker.Position = UDim2.fromOffset(left, PAD_Y)
	kicker.Size = UDim2.fromOffset(text_w, wrapped_head + 2)

	body.Text = rest
	body.Position = UDim2.fromOffset(left, head and (PAD_Y + wrapped_head + 3) or PAD_Y)
	body.Size = UDim2.fromOffset(text_w, wrapped_body + 2)
	body.TextColor3 = head and values().muted or values().text

	if mark then
		local top = PAD_Y
		local block = head and wrapped_head or wrapped_body
		if block > MARK then
			top = PAD_Y + math.floor((block - MARK) * 0.5)
		end
		mark.Position = UDim2.fromOffset(PAD, top)
	end
end

local function place(target)
	local view = env.viewport()
	local pos = target.AbsolutePosition
	local size = target.AbsoluteSize
	local width = panel.Size.X.Offset
	local height = panel.Size.Y.Offset
	if width <= 0 or height <= 0 then
		return
	end
	local y
	if pos.Y + size.Y + GAP + height <= view.Y - EDGE then
		y = pos.Y + size.Y + GAP
	elseif pos.Y - height - GAP >= EDGE then
		y = pos.Y - height - GAP
	else
		y = pos.Y + size.Y + GAP
	end
	local x = pos.X + size.X * 0.5 - width * 0.5
	x = math.clamp(x, EDGE, math.max(EDGE, view.X - width - EDGE))
	y = math.clamp(y, EDGE, math.max(EDGE, view.Y - height - EDGE))
	panel.Position = UDim2.fromOffset(math.floor(x + 0.5), math.floor(y + 0.5))
end

local function hide()
	current = nil
	if not panel.Parent then
		return
	end
	if group_ok then
		util.cancel(panel)
		panel.GroupTransparency = 0
	end
	panel.Visible = false
end

local function show(target, value)
	if type(value) ~= "string" or value == "" or not target.Parent then
		return
	end
	current = target
	render(value)
	place(target)
	panel.Visible = true
	if group_ok then
		panel.GroupTransparency = 1
		util.tween(panel, 0.12, { GroupTransparency = 0 }, Enum.EasingStyle.Quad)
	end
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
		local value = source()
		if not value then
			return
		end
		token = token + 1
		local mine = token
		task.delay(DELAY, function()
			if mine ~= token or not target.Parent then
				return
			end
			if current == target then
				place(target)
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

function tooltip.destroy()
	hide()
	if input_link then
		input_link:Disconnect()
		input_link = nil
	end
end

local input_link = env.uis.InputBegan:Connect(function(input)
	local kind = input.UserInputType
	if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
		hide()
	end
end)

style.paint(function()
	panel.BackgroundColor3 = values().panel
	edge.Color = values().line
	kicker.TextColor3 = values().text
	body.TextColor3 = kicker.Visible and values().muted or values().text
	if mark then
		icons.tint(mark, values().muted)
	end
end)

S.tooltip = tooltip
