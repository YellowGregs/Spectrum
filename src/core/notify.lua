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
	Size = UDim2.fromOffset(env.mobile and 284 or 300, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Parent = env.notes,
})

util.new("UIListLayout", {
	Padding = UDim.new(0, 10),
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

	local width = env.mobile and 284 or 300
	local icon_size = env.mobile and 15 or 14
	local text_left = icon_size + 7
	local title_size = util.size(11)
	local body_size = util.size(10)
	local caption_y = env.mobile and 19 or 18
	local caption_height = math.max(env.mobile and 15 or 14, wrapped_height(body or "", width - text_left - 24, body_size) + 1)
	local height = caption_y + caption_height + (env.mobile and 9 or 8)

	local wrap = util.new("Frame", {
		Name = "note",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		LayoutOrder = noted,
		Size = UDim2.new(1, 0, 0, 0),
		Parent = holder,
	})

	local content = util.new("Frame", {
		Name = "content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, 0, 0, height),
		Parent = wrap,
	})
	local scale = util.new("UIScale", { Scale = 0.98, Parent = content })

	local badge = icons.kind(kind, content, icon_size, tint)
	badge.AnchorPoint = Vector2.new(0, 0)
	badge.Position = UDim2.fromOffset(0, 1)
	badge.ImageTransparency = 1
	icons.layer(badge, 4)
	local badge_scale = util.new("UIScale", { Scale = 0.6, Parent = badge })

	local heading = util.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(text_left, 0),
		Size = UDim2.new(1, -(text_left + 24), 0, 15),
		Font = bold,
		Text = tostring(title or "Spectrum"),
		TextColor3 = style.values.text,
		TextSize = title_size,
		TextTransparency = 1,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0.55,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 5,
		Parent = content,
	})

	local caption = util.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(text_left, caption_y),
		Size = UDim2.new(1, -(text_left + 18), 0, caption_height),
		Font = font,
		Text = body or "",
		TextColor3 = style.values.muted,
		TextSize = body_size,
		TextTransparency = 1,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0.7,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		ZIndex = 5,
		Parent = content,
	})

	local close_hit = util.new("TextButton", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -2, 0, 0),
		Size = UDim2.fromOffset(env.mobile and 22 or 18, env.mobile and 22 or 18),
		Text = "",
		AutoButtonColor = false,
		ZIndex = 7,
		Parent = content,
	})
	local close_icon = icons.close(close_hit, 7, style.values.muted)
	close_icon.AnchorPoint = Vector2.new(0.5, 0.5)
	close_icon.Position = UDim2.fromScale(0.5, 0.5)
	close_icon.ImageTransparency = 1
	icons.layer(close_icon, 8)
	close_hit.MouseEnter:Connect(function()
		icons.tint(close_icon, style.values.bad)
	end)
	close_hit.MouseLeave:Connect(function()
		icons.tint(close_icon, style.values.muted)
	end)

	local rail = util.new("Frame", {
		BackgroundColor3 = style.values.line,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, text_left, 1, -2),
		Size = UDim2.new(1, -(text_left + 16), 0, 2),
		ZIndex = 4,
		Parent = content,
	})

	local line = util.new("Frame", {
		BackgroundColor3 = tint,
		BackgroundTransparency = 1,
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
		if not wrap.Parent then
			return
		end
		util.cancel(line)
		util.tween(wrap, 0.16, { Size = UDim2.new(1, 0, 0, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		util.tween(content, 0.16, { Position = UDim2.fromOffset(18, -2) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		util.tween(scale, 0.16, { Scale = 0.96 })
		util.tween(heading, 0.12, { TextTransparency = 1 })
		util.tween(caption, 0.12, { TextTransparency = 1 })
		util.tween(badge, 0.12, { ImageTransparency = 1 })
		util.tween(close_icon, 0.12, { ImageTransparency = 1 })
		util.tween(rail, 0.12, { BackgroundTransparency = 1 })
		util.tween(line, 0.12, { BackgroundTransparency = 1 })
		task.delay(0.18, function()
			if wrap.Parent then
				wrap:Destroy()
			end
		end)
	end

	local hit = util.new("TextButton", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		AutoButtonColor = false,
		ZIndex = 3,
		Parent = content,
	})
	hit.Activated:Connect(close)
	close_hit.Activated:Connect(close)

	util.tween(wrap, 0.24, { Size = UDim2.new(1, 0, 0, height) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	util.tween(content, 0.26, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	util.tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	util.tween(badge_scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	util.tween(heading, 0.2, { TextTransparency = 0 })
	task.delay(0.04, function()
		if closed or not wrap.Parent then
			return
		end
		util.tween(caption, 0.22, { TextTransparency = 0 })
		util.tween(badge, 0.2, { ImageTransparency = 0 })
		util.tween(close_icon, 0.2, { ImageTransparency = 0 })
		util.tween(rail, 0.2, { BackgroundTransparency = 0.65 })
		util.tween(line, 0.2, { BackgroundTransparency = 0 })
	end)
	util.tween(line, duration, { Size = UDim2.fromScale(0, 1) }, Enum.EasingStyle.Linear, Enum.EasingDirection.In)
	task.delay(duration, close)

	return close
end

S.notify = notify
