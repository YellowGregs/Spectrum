local S = ...

local env = S.env
local util = S.util
local style = S.style
local icons = S.icons
local bold = Enum.Font.GothamBold
local font = Enum.Font.Gotham
local TextService = game:GetService("TextService")

local holder = util.new("Frame", {
	Name = "notifications",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -12, 1, -12),
	Size = UDim2.fromOffset(env.mobile and 284 or 304, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Parent = env.notes,
})

util.new("UIListLayout", {
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	VerticalAlignment = Enum.VerticalAlignment.Bottom,
	Parent = holder,
})

local noted = 0

local function wrapped_height(text, width, size)
	local ok, box = pcall(function()
		return TextService:GetTextSize(text, size or 10, font, Vector2.new(width, 4096))
	end)
	if ok and typeof(box) == "Vector2" then
		return math.ceil(box.Y)
	end
	return (size or 10) + 2
end

local function fade(object)
	if not object then
		return
	end
	if object:IsA("TextLabel") or object:IsA("TextButton") then
		util.tween(object, 0.14, { TextTransparency = 1 })
	elseif object:IsA("ImageLabel") then
		util.tween(object, 0.14, { ImageTransparency = 1 })
	elseif object:IsA("Frame") then
		util.tween(object, 0.14, { BackgroundTransparency = 1 })
	elseif object:IsA("UIStroke") then
		util.tween(object, 0.14, { Transparency = 1 })
	end
end

local function notify(title, body, duration, kind)
	noted = noted + 1
	duration = duration or 3
	local tint = style.values.accent
	if kind == "good" then
		tint = style.values.good
	elseif kind == "warn" then
		tint = style.values.warn
	elseif kind == "bad" then
		tint = style.values.bad
	end

	local width = env.mobile and 284 or 304
	local pad = 12
	local icon_size = env.mobile and 28 or 26
	local text_left = pad + icon_size + 10
	local text_width = width - text_left - 34
	local title_size = util.size(11)
	local body_size = util.size(10)
	local caption_y = env.mobile and 29 or 27
	local caption_height = math.max(env.mobile and 24 or 20, wrapped_height(body or "", text_width, body_size) + 2)
	local height = math.max(env.mobile and 58 or 56, caption_y + caption_height + (env.mobile and 11 or 10))
	local wrap = util.new("Frame", {
		Name = "note",
		BackgroundTransparency = 1,
		LayoutOrder = noted,
		Size = UDim2.new(1, 0, 0, height),
		Parent = holder,
	})

	local face = util.new("Frame", {
		Name = "face",
		BackgroundColor3 = style.values.panel,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -8, 1, 0),
		ClipsDescendants = true,
		ZIndex = 2,
		Parent = wrap,
	})
	util.corner(face, 6)
	local edge = util.stroke(face, style.values.line, 0.25)
	util.shadow(face, 18, 0.3)

	local tile = util.new("Frame", {
		Name = "icon",
		BackgroundColor3 = tint,
		BackgroundTransparency = 0.82,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(pad, pad),
		Size = UDim2.fromOffset(icon_size, icon_size),
		ZIndex = 4,
		Parent = face,
	})
	util.corner(tile, 6)

	local badge = icons.kind(kind, tile, env.mobile and 15 or 14, tint)
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.fromScale(0.5, 0.5)
	icons.layer(badge, 5)

	local heading = util.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(text_left, env.mobile and 9 or 8),
		Size = UDim2.new(1, -(text_left + 30), 0, 15),
		Font = bold,
		Text = tostring(title or "Spectrum"),
		TextColor3 = style.values.text,
		TextSize = title_size,
		TextTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 5,
		Parent = face,
	})

	local caption = util.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(text_left, caption_y),
		Size = UDim2.new(1, -(text_left + 24), 0, caption_height),
		Font = font,
		Text = body or "",
		TextColor3 = style.values.muted,
		TextSize = body_size,
		TextTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		ZIndex = 5,
		Parent = face,
	})

	local close_hit = util.new("TextButton", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 2),
		Size = UDim2.fromOffset(env.mobile and 26 or 22, env.mobile and 26 or 22),
		Text = "",
		AutoButtonColor = false,
		ZIndex = 7,
		Parent = face,
	})
	local close_icon = icons.close(close_hit, 8, style.values.muted)
	close_icon.AnchorPoint = Vector2.new(0.5, 0.5)
	close_icon.Position = UDim2.fromScale(0.5, 0.5)
	icons.layer(close_icon, 8)
	close_hit.MouseEnter:Connect(function()
		icons.tint(close_icon, style.values.bad)
	end)
	close_hit.MouseLeave:Connect(function()
		icons.tint(close_icon, style.values.muted)
	end)

	local rail = util.new("Frame", {
		BackgroundColor3 = style.values.line,
		BackgroundTransparency = 0.65,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, -2),
		Size = UDim2.new(1, 0, 0, 2),
		ZIndex = 4,
		Parent = face,
	})

	local line = util.new("Frame", {
		BackgroundColor3 = tint,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
		Parent = rail,
	})

	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		if not face.Parent then
			return
		end
		util.tween(face, 0.18, { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 0) })
		for _, child in ipairs(face:GetDescendants()) do
			fade(child)
		end
		task.delay(0.2, function()
			wrap:Destroy()
		end)
	end

	local hit = util.new("TextButton", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		AutoButtonColor = false,
		ZIndex = 3,
		Parent = face,
	})
	hit.Activated:Connect(close)
	close_hit.Activated:Connect(close)

	util.tween(face, 0.22, { BackgroundTransparency = 0, Position = UDim2.fromOffset(0, 0) })
	util.tween(edge, 0.22, { Transparency = 0.2 })
	util.tween(heading, 0.22, { TextTransparency = 0 })
	util.tween(caption, 0.22, { TextTransparency = 0 })
	util.tween(line, duration, { Size = UDim2.fromScale(0, 1) }, Enum.EasingStyle.Linear, Enum.EasingDirection.In)
	task.delay(duration, close)

	return close
end

S.notify = notify
