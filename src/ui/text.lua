local S = ...

local util = S.util
local style = S.style
local icons = S.icons
local bold = Enum.Font.GothamBold
local font = Enum.Font.GothamMedium
local text = {}

local function values()
	return style.values
end

local function label(parent, title)
	return util.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -90, 0, 14),
		Font = font,
		Text = tostring(title or ""),
		TextColor3 = values().text,
		TextSize = util.size(11),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = parent,
	})
end

function text.section(win, title, icon)
	local height = win._mobile and 32 or 28
	local holder = win._slot(height)
	local band = util.new("Frame", {
		BackgroundColor3 = values().panel,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = holder,
	})
	local tick = util.new("Frame", {
		BackgroundColor3 = values().accent,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, height / 2 - 6),
		Size = UDim2.fromOffset(2, 12),
		ZIndex = 3,
		Parent = band,
	})
	local caption = util.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 0),
		Size = UDim2.new(1, -28, 1, 0),
		Font = bold,
		Text = tostring(title or "Section"),
		TextColor3 = values().text,
		TextSize = util.size(11),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = band,
	})
	local emblem
	if type(icon) == "string" and icon ~= "" then
		emblem = icons.image(band, icon, 12, values().accent)
		if emblem then
			tick.Visible = false
			emblem.Position = UDim2.fromOffset(10, height / 2 - 6)
			emblem.ZIndex = 3
			caption.Position = UDim2.fromOffset(28, 0)
			caption.Size = UDim2.new(1, -36, 1, 0)
		end
	end
	local bottom = util.new("Frame", {
		BackgroundColor3 = values().line,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, -1),
		Size = UDim2.new(1, 0, 0, 1),
		ZIndex = 3,
		Parent = band,
	})

	style.paint(function()
		band.BackgroundColor3 = values().panel
		tick.BackgroundColor3 = values().accent
		caption.TextColor3 = values().text
		bottom.BackgroundColor3 = values().line
		if emblem then
			icons.tint(emblem, values().accent)
		end
	end)

	win._fit(true)
	return caption
end

function text.label(win, body)
	local holder = win._slot(0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	util.new("UIPadding", {
		PaddingTop = UDim.new(0, 7),
		PaddingBottom = UDim.new(0, 7),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 12),
		Parent = holder,
	})
	local caption = util.new("TextLabel", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		Font = font,
		Text = tostring(body or ""),
		TextColor3 = values().muted,
		TextSize = util.size(10),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 2,
		Parent = holder,
	})

	style.paint(function()
		caption.TextColor3 = values().muted
	end)

	win._fit(true)
	return caption
end

function text.separator(win)
	local holder = win._slot(9)
	local bar = util.new("Frame", {
		BackgroundColor3 = values().line,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 0, 1),
		Parent = holder,
	})

	style.paint(function()
		bar.BackgroundColor3 = values().line
	end)

	win._fit(true)
	return bar
end

function text.textbox(win, title, default, callback)
	local mobile = win._mobile
	local row = win._row(mobile and 58 or 34)
	local name = label(row, title)
	if not mobile then
		name.Size = UDim2.new(0.4, -16, 1, 0)
	end
	local box
	if mobile then
		name.Position = UDim2.fromOffset(10, 7)
		name.Size = UDim2.new(1, -20, 0, 14)
		box = util.new("TextBox", {
			BackgroundColor3 = values().raised,
			BorderSizePixel = 0,
			ClearTextOnFocus = false,
			Font = font,
			PlaceholderColor3 = values().muted,
			PlaceholderText = "Enter text",
			Position = UDim2.new(0, 10, 0, 27),
			Size = UDim2.new(1, -20, 0, 26),
			Text = tostring(default or ""),
			TextColor3 = values().text,
			TextSize = util.size(11),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 3,
			Parent = row,
		})
	else
		box = util.new("TextBox", {
			BackgroundColor3 = values().raised,
			BorderSizePixel = 0,
			ClearTextOnFocus = false,
			Font = font,
			PlaceholderColor3 = values().muted,
			PlaceholderText = "Enter text",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.new(0.52, 0, 0, 22),
			Text = tostring(default or ""),
			TextColor3 = values().text,
			TextSize = util.size(11),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 3,
			Parent = row,
		})
	end
	util.corner(box)
	util.new("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = box,
	})
	local edge = util.stroke(box, values().line, 0.2)
	local stored
	local hotspot = util.new("TextButton", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		AutoButtonColor = false,
		ZIndex = 1,
		Parent = row,
	})
	util.hover(hotspot)

	hotspot.Activated:Connect(function()
		box:CaptureFocus()
	end)

	box.Focused:Connect(function()
		edge.Color = values().accent
		edge.Transparency = 0.2
	end)
	box.FocusLost:Connect(function()
		edge.Color = values().line
		edge.Transparency = 0.2
		win._store(stored, box.Text)
		if callback then
			callback(box.Text)
		end
	end)

	style.paint(function()
		box.BackgroundColor3 = values().raised
		box.TextColor3 = values().text
		box.PlaceholderColor3 = values().muted
		edge.Color = values().line
		name.TextColor3 = values().text
	end)

	stored = win._bind("text", title, {
		set = function(value)
			box.Text = tostring(value)
		end,
	})
	win._fit(true)

	return {
		Set = function(_, value)
			box.Text = tostring(value)
		end,
		Get = function()
			return box.Text
		end,
		Focus = function()
			box:CaptureFocus()
		end,
		Gui = row,
	}
end

S.text = text
