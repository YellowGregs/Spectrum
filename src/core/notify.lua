local S = ...

local env = S.env
local util = S.util
local style = S.style
local icons = S.icons
local bold = Enum.Font.GothamBold
local font = Enum.Font.RobotoCondensed

local holder = util.new("Frame", {
	Name = "notifications",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -12, 1, -12),
	Size = UDim2.fromOffset(env.mobile and 276 or 292, 0),
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

	local height = env.mobile and 58 or 52
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
		Position = UDim2.fromOffset(6, 0),
		Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true,
		ZIndex = 2,
		Parent = wrap,
	})
	util.corner(face, 0)
	local edge = util.stroke(face, tint, 0.55)
	util.depth(face, 0.45)
	util.shadow(face, 18, 0.3)

	local accent = util.new("Frame", {
		Name = "accent",
		BackgroundColor3 = tint,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 2, 1, 0),
		ZIndex = 4,
		Parent = face,
	})

	local badge = icons.kind(kind, face, env.mobile and 15 or 14, tint)
	badge.Position = UDim2.fromOffset(12, 7)
	icons.layer(badge, 5)

	local heading = util.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(33, env.mobile and 7 or 6),
		Size = UDim2.new(1, -68, 0, 13),
		Font = bold,
		Text = string.upper(tostring(title or "Spectrum")),
		TextColor3 = style.values.text,
		TextSize = 10,
		TextTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 5,
		Parent = face,
	})

	local caption = util.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(33, env.mobile and 23 or 22),
		Size = UDim2.new(1, -68, 0, env.mobile and 26 or 22),
		Font = font,
		Text = body or "",
		TextColor3 = style.values.muted,
		TextSize = 9,
		TextTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 5,
		Parent = face,
	})

	local close_hit = util.new("TextButton", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -5, 0, 2),
		Size = UDim2.fromOffset(env.mobile and 26 or 20, env.mobile and 26 or 20),
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
		BackgroundTransparency = 0.62,
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
		util.tween(face, 0.16, { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 2) })
		for _, child in ipairs(face:GetDescendants()) do
			fade(child)
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
		ZIndex = 3,
		Parent = face,
	})
	hit.Activated:Connect(close)
	close_hit.Activated:Connect(close)

	util.tween(face, 0.2, { BackgroundTransparency = 0, Position = UDim2.fromOffset(0, 0) })
	util.tween(edge, 0.2, { Transparency = 0.35 })
	util.tween(heading, 0.2, { TextTransparency = 0 })
	util.tween(caption, 0.2, { TextTransparency = 0 })
	util.tween(line, duration, { Size = UDim2.fromScale(0, 1) }, Enum.EasingStyle.Linear, Enum.EasingDirection.In)
	task.delay(duration, close)

	return close
end

S.notify = notify
