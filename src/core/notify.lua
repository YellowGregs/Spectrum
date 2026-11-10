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
	Size = UDim2.fromOffset(env.mobile and 268 or 250, 0),
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

	local height = env.mobile and 56 or 50
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
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.fromScale(1, 1),
		Parent = wrap,
	})
	util.corner(face, 3)
	local edge = util.stroke(face, style.values.line, 1)
	util.shadow(face, 12, 0.6)

	local stripe = util.new("Frame", {
		BackgroundColor3 = tint,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 10),
		Size = UDim2.new(0, 2, 1, -20),
		Parent = face,
	})

	local badge = icons.kind(kind, face, 14, tint)
	badge.AnchorPoint = Vector2.new(0, 0.5)
	badge.Position = UDim2.new(0, 12, 0.5, 0)
	badge.ZIndex = 2

	local heading = util.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(32, 7),
		Size = UDim2.new(1, -42, 0, 14),
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
		Position = UDim2.fromOffset(32, 23),
		Size = UDim2.new(1, -42, 0, 14),
		Font = font,
		Text = body or "",
		TextColor3 = style.values.muted,
		TextSize = 10,
		TextTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = face,
	})

	local rail = util.new("Frame", {
		BackgroundColor3 = style.values.line,
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 12, 1, -6),
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
		util.tween(face, 0.16, { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 4) })
		util.tween(edge, 0.16, { Transparency = 1 })
		util.tween(heading, 0.14, { TextTransparency = 1 })
		util.tween(caption, 0.14, { TextTransparency = 1 })
		util.tween(stripe, 0.14, { BackgroundTransparency = 1 })
		util.tween(rail, 0.14, { BackgroundTransparency = 1 })
		util.tween(line, 0.14, { BackgroundTransparency = 1 })
		for _, child in ipairs(badge:GetDescendants()) do
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
		Parent = face,
	})
	hit.Activated:Connect(close)

	util.tween(face, 0.2, { BackgroundTransparency = 0, Position = UDim2.fromOffset(0, 0) })
	util.tween(edge, 0.2, { Transparency = 0.75 })
	util.tween(heading, 0.2, { TextTransparency = 0 })
	util.tween(caption, 0.2, { TextTransparency = 0 })
	util.tween(stripe, 0.2, { BackgroundTransparency = 0 })
	util.tween(line, duration, { Size = UDim2.fromScale(0, 1) }, Enum.EasingStyle.Linear, Enum.EasingDirection.In)
	task.delay(duration, close)

	return close
end

S.notify = notify
