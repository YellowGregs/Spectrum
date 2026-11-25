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
	Size = UDim2.fromOffset(env.mobile and 316 or 340, 0),
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
local kind_labels = {
	info = "INFO",
	good = "SUCCESS",
	warn = "WARNING",
	bad = "ERROR",
}

local function wrapped_height(text, width, size)
	local ok, box = pcall(function()
		return TextService:GetTextSize(text, size or 10, font, Vector2.new(width, 4096))
	end)
	if ok and typeof(box) == "Vector2" then
		return math.ceil(box.Y)
	end
	return (size or 10) + 2
end

local function fade_icon(object, alpha, time)
	if not object or not object.Parent then
		return
	end
	local items = { object }
	for _, child in ipairs(object:GetDescendants()) do
		items[#items + 1] = child
	end
	for _, child in ipairs(items) do
		local base = child:GetAttribute("SpectrumIconAlpha")
		if base == nil then
			if child:IsA("Frame") then
				base = child.BackgroundTransparency
			elseif child:IsA("ImageLabel") then
				base = child.ImageTransparency
			elseif child:IsA("TextLabel") then
				base = child.TextTransparency
			elseif child:IsA("UIStroke") then
				base = child.Transparency
			end
			if base ~= nil then
				child:SetAttribute("SpectrumIconAlpha", base)
			end
		end
		if base ~= nil then
			local target = base + (1 - base) * alpha
			local delay = math.max(0.01, time or 0.12)
			if child:IsA("Frame") then
				util.tween(child, delay, { BackgroundTransparency = target })
			elseif child:IsA("ImageLabel") then
				util.tween(child, delay, { ImageTransparency = target })
			elseif child:IsA("TextLabel") then
				util.tween(child, delay, { TextTransparency = target })
			elseif child:IsA("UIStroke") then
				util.tween(child, delay, { Transparency = target })
			end
		end
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

	local width = env.mobile and 316 or 340
	local pad = 20
	local chip_size = 28
	local chip_x = pad + 2
	local icon_size = 15
	local text_left = chip_x + chip_size + 6
	local title_size = util.size(12)
	local body_size = util.size(10)
	local caption_y = env.mobile and 29 or 28
	local caption_height = math.max(env.mobile and 15 or 14, wrapped_height(body or "", width - text_left - 20, body_size) + 2)
	local height = math.max(env.mobile and 64 or 60, caption_y + caption_height + 16)

	local face = util.new("Frame", {
		Name = "note",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		LayoutOrder = noted,
		Size = UDim2.new(1, 0, 0, 0),
		Parent = holder,
	})

	local scrim = util.new("Frame", {
		Name = "scrim",
		BackgroundColor3 = style.values.panel,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Parent = face,
	})
	util.corner(scrim, 6)
	util.new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, style.values.panel),
			ColorSequenceKeypoint.new(1, style.values.raised),
		}),
		Rotation = 90,
		Parent = scrim,
	})

	local content = util.new("Frame", {
		Name = "content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(6, 0),
		Size = UDim2.new(1, 0, 0, height),
		ZIndex = 3,
		Parent = face,
	})
	local scale = util.new("UIScale", { Scale = 0.98, Parent = content })

	local chip = util.new("Frame", {
		Name = "chip",
		BackgroundColor3 = tint,
		BackgroundTransparency = 0.82,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(chip_x, env.mobile and 11 or 10),
		Size = UDim2.fromOffset(chip_size, chip_size),
		ZIndex = 4,
		Parent = content,
	})
	util.corner(chip, 7)
	util.stroke(chip, tint, 0.4)
	local chip_scale = util.new("UIScale", { Scale = 0.7, Parent = chip })

	local badge = icons.kind(kind, chip, icon_size, tint)
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.fromScale(0.5, 0.5)
	icons.layer(badge, 5)
	fade_icon(chip, 1, 0.01)

	local heading = util.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(text_left, env.mobile and 10 or 9),
		Size = UDim2.new(1, -(text_left + 110), 0, 18),
		Font = bold,
		Text = tostring(title or "Spectrum"),
		TextColor3 = style.values.text,
		TextSize = title_size,
		TextTransparency = 1,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 5,
		Parent = content,
	})

	local kind_label = util.new("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -34, 0, env.mobile and 12 or 11),
		Size = UDim2.fromOffset(64, 12),
		Font = bold,
		Text = kind_labels[kind] or "INFO",
		TextColor3 = tint,
		TextSize = util.size(8),
		TextTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 6,
		Parent = content,
	})

	local caption = util.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(text_left, caption_y),
		Size = UDim2.new(1, -(text_left + 20), 0, caption_height),
		Font = font,
		Text = body or "",
		TextColor3 = style.values.muted:Lerp(style.values.text, 0.5),
		TextSize = body_size,
		TextTransparency = 1,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		ZIndex = 5,
		Parent = content,
	})

	local close_hit = util.new("TextButton", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(18, 18),
		Text = "",
		AutoButtonColor = false,
		ZIndex = 7,
		Parent = content,
	})
	local close_color = style.values.muted:Lerp(style.values.text, 0.35)
	local close_icon = icons.close(close_hit, 7, close_color)
	close_icon.AnchorPoint = Vector2.new(0.5, 0.5)
	close_icon.Position = UDim2.fromScale(0.5, 0.5)
	icons.layer(close_icon, 8)
	fade_icon(close_icon, 1, 0.01)
	close_hit.MouseEnter:Connect(function()
		icons.tint(close_icon, style.values.bad)
	end)
	close_hit.MouseLeave:Connect(function()
		icons.tint(close_icon, close_color)
	end)

	local rail = util.new("Frame", {
		BackgroundColor3 = style.values.line,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, pad, 1, -4),
		Size = UDim2.new(1, -(pad * 2), 0, 2),
		ZIndex = 4,
		Parent = content,
	})
	util.corner(rail, 1)

	local line = util.new("Frame", {
		BackgroundColor3 = tint,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
		Parent = rail,
	})
	util.corner(line, 1)
	local dot = util.new("Frame", {
		BackgroundColor3 = tint,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(4, 4),
		ZIndex = 5,
		Parent = line,
	})
	util.corner(dot, 2)

	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		if not face.Parent then
			return
		end
		util.cancel(line)
		util.tween(face, 0.16, { Size = UDim2.new(1, 0, 0, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		util.tween(content, 0.16, { Position = UDim2.fromOffset(6, -2) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		util.tween(scale, 0.16, { Scale = 0.96 })
		util.tween(scrim, 0.12, { BackgroundTransparency = 1 })
		util.tween(heading, 0.12, { TextTransparency = 1, TextStrokeTransparency = 1 })
		util.tween(kind_label, 0.12, { TextTransparency = 1 })
		util.tween(caption, 0.12, { TextTransparency = 1, TextStrokeTransparency = 1 })
		fade_icon(chip, 1, 0.12)
		fade_icon(close_icon, 1, 0.12)
		util.tween(rail, 0.12, { BackgroundTransparency = 1 })
		util.tween(line, 0.12, { BackgroundTransparency = 1 })
		util.tween(dot, 0.12, { BackgroundTransparency = 1 })
		task.delay(0.18, function()
			if face.Parent then
				face:Destroy()
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

	util.tween(face, 0.26, { Size = UDim2.new(1, 0, 0, height) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	util.tween(content, 0.28, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	util.tween(scale, 0.32, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	util.tween(chip_scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	util.tween(scrim, 0.22, { BackgroundTransparency = 0.28 })
	util.tween(heading, 0.2, { TextTransparency = 0, TextStrokeTransparency = 0.25 })
	task.delay(0.04, function()
		if closed or not face.Parent then
			return
		end
		util.tween(caption, 0.22, { TextTransparency = 0, TextStrokeTransparency = 0.35 })
		util.tween(kind_label, 0.2, { TextTransparency = 0 })
		fade_icon(chip, 0, 0.2)
		fade_icon(close_icon, 0, 0.2)
		util.tween(rail, 0.2, { BackgroundTransparency = 0.55 })
		util.tween(line, 0.2, { BackgroundTransparency = 0 })
		util.tween(dot, 0.2, { BackgroundTransparency = 0 })
	end)
	util.tween(line, duration, { Size = UDim2.fromScale(0, 1) }, Enum.EasingStyle.Linear, Enum.EasingDirection.In)
	task.delay(duration, close)

	return close
end

S.notify = notify
