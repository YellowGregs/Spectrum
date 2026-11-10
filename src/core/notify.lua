local S = ...

local env = S.env
local util = S.util
local style = S.style
local icons = S.icons
local bold = Enum.Font.GothamBold
local font = Enum.Font.GothamMedium

local holder = util.new("Frame", {
	Name = "notifications",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -12, 1, -12),
	Size = UDim2.fromOffset(env.mobile and 272 or 260, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Parent = env.notes,
})

util.new("UIListLayout", {
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	VerticalAlignment = Enum.VerticalAlignment.Bottom,
	Parent = holder,
})

local noted = 0

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

	local height = env.mobile and 64 or 58
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
		Size = UDim2.fromScale(1, 1),
		Parent = wrap,
	})
	util.corner(face, 6)
	local edge = util.stroke(face, style.values.line, 1)
	util.shadow(face, 14, 0.55)

	local chip = util.new("Frame", {
		Name = "chip",
		BackgroundColor3 = tint,
		BackgroundTransparency = 0.84,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
		Parent = face,
	})
	util.corner(chip, 7)
	local chip_edge = util.stroke(chip, tint, 0.45)
	local badge = icons.kind(kind, chip, 14, tint)
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.new(0.5, 0, 0.5, 0)
	icons.layer(badge, 2)

	local heading = util.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(48, 8),
		Size = UDim2.new(1, -68, 0, 14),
		Font = bold,
		Text = title or "Spectrum",
		TextColor3 = style.values.text,
		TextSize = 11,
		TextTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = face,
	})

	local caption = util.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(48, 25),
		Size = UDim2.new(1, -68, 0, 26),
		Font = font,
		Text = body or "",
		TextColor3 = style.values.muted,
		TextSize = 10,
		TextTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = face,
	})

	local close_hit = util.new("TextButton", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(18, 18),
		Text = "",
		AutoButtonColor = false,
		ZIndex = 5,
		Parent = face,
	})
	local close_icon = icons.close(close_hit, 10, style.values.muted)
	close_icon.AnchorPoint = Vector2.new(0.5, 0.5)
	close_icon.Position = UDim2.new(0.5, 0, 0.5, 0)
	icons.layer(close_icon, 6)

	local rail = util.new("Frame", {
		BackgroundColor3 = style.values.line,
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 12, 1, -5),
		Size = UDim2.new(1, -24, 0, 2),
		Parent = face,
	})

	local line = util.new("Frame", {
		BackgroundColor3 = tint,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = rail,
	})

	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		util.tween(face, 0.16, { BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 4) })
		util.tween(edge, 0.16, { Transparency = 1 })
		util.tween(heading, 0.14, { TextTransparency = 1 })
		util.tween(caption, 0.14, { TextTransparency = 1 })
		util.tween(chip, 0.14, { BackgroundTransparency = 1 })
		util.tween(chip_edge, 0.14, { Transparency = 1 })
		util.tween(rail, 0.14, { BackgroundTransparency = 1 })
		util.tween(line, 0.14, { BackgroundTransparency = 1 })
		for _, child in ipairs(badge:GetDescendants()) do
			if child:IsA("Frame") then
				util.tween(child, 0.14, { BackgroundTransparency = 1 })
			end
		end
		for _, child in ipairs(close_icon:GetDescendants()) do
			if child:IsA("Frame") then
				util.tween(child, 0.14, { BackgroundTransparency = 1 })
			end
		end
		task.delay(0.18, function()
			wrap:Destroy()
		end)
	end

	local hit = util.new("TextButton", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		AutoButtonColor = false,
		ZIndex = 1,
		Parent = face,
	})
	hit.Activated:Connect(close)
	close_hit.Activated:Connect(close)

	util.tween(face, 0.2, { BackgroundTransparency = 0, Position = UDim2.fromOffset(0, 0) })
	util.tween(edge, 0.2, { Transparency = 0.8 })
	util.tween(heading, 0.2, { TextTransparency = 0 })
	util.tween(caption, 0.2, { TextTransparency = 0 })
	util.tween(line, duration, { Size = UDim2.fromScale(0, 1) }, Enum.EasingStyle.Linear, Enum.EasingDirection.In)
	task.delay(duration, close)

	return close
end

S.notify = notify
