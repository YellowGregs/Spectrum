local S = ...

local env = S.env
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
	local holder = win._slot(height, true)
	local record = win._new_section()
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
		Size = UDim2.new(1, -44, 1, 0),
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
		emblem = icons.image(band, icon, 14, values().accent)
		if emblem then
			tick.Visible = false
			emblem.Position = UDim2.fromOffset(10, height / 2 - 7)
			emblem.ZIndex = 3
			caption.Position = UDim2.fromOffset(29, 0)
			caption.Size = UDim2.new(1, -53, 1, 0)
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
	local chevron = util.chevron(band, 8, values().muted)
	chevron.AnchorPoint = Vector2.new(0.5, 0.5)
	chevron.Position = UDim2.new(1, -14, 0.5, 0)
	chevron.ZIndex = 4
	chevron.Rotation = 180

	local hit = util.new("TextButton", {
		BackgroundColor3 = values().hover,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		ZIndex = 7,
		Parent = band,
	})
	local hovered = false
	local function tint_band(on)
		hovered = on
		util.tween(band, 0.1, { BackgroundColor3 = on and values().hover or values().panel })
	end
	hit.MouseEnter:Connect(function()
		tint_band(true)
	end)
	hit.MouseLeave:Connect(function()
		tint_band(false)
	end)
	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			tint_band(true)
		end
	end)
	hit.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			tint_band(false)
		end
	end)

	local function set_open(state, animate)
		if state == nil then
			state = not record.open
		end
		win._toggle_section(record, state)
		if animate then
			util.tween(chevron, 0.15, { Rotation = state and 180 or 0 })
		else
			chevron.Rotation = state and 180 or 0
		end
	end

	hit.Activated:Connect(function()
		set_open(nil, true)
	end)

	style.paint(function()
		band.BackgroundColor3 = values().panel
		tick.BackgroundColor3 = values().accent
		caption.TextColor3 = values().text
		bottom.BackgroundColor3 = values().line
		band.BackgroundColor3 = hovered and values().hover or values().panel
		if emblem then
			icons.tint(emblem, values().accent)
		end
	end)

	win._nav_register(holder, {
		kind = "section",
		label = title,
		is_enabled = function()
			return true
		end,
		activate = function()
			set_open(nil, true)
		end,
	})

	win._focus_section(record)
	win._fit(true)

	return {
		Header = caption,
		Toggle = function(_, state)
			set_open(state, true)
		end,
		Open = function()
			set_open(true, true)
		end,
		Close = function()
			set_open(false, true)
		end,
		IsOpen = function()
			return record.open
		end,
	}
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

function text.textbox(win, title, default, callback, icon, opts)
	if type(icon) == "table" and opts == nil then
		opts = icon
		icon = opts.icon
	end
	opts = type(opts) == "table" and opts or {}
	local disabled = opts.disabled == true
	local mobile = win._mobile
	local row = win._row(mobile and 58 or 34)
	row.ClipsDescendants = true
	local initial = default
	local name = label(row, title)
	local emblem
	if type(icon) == "string" and icon ~= "" then
		emblem = icons.image(row, icon, 14, values().muted)
		if emblem then
			icons.layer(emblem, 4)
			if mobile then
				emblem.AnchorPoint = Vector2.new(0, 0)
				emblem.Position = UDim2.fromOffset(10, 7)
			else
				emblem.AnchorPoint = Vector2.new(0, 0.5)
				emblem.Position = UDim2.new(0, 10, 0.5, 0)
			end
		end
	end
	if mobile then
		name.Position = UDim2.fromOffset(emblem and 28 or 10, 7)
		name.Size = UDim2.new(1, emblem and -46 or -20, 0, 14)
	else
		name.Position = UDim2.fromOffset(emblem and 28 or 10, 0)
		name.Size = UDim2.new(0.4, emblem and -34 or -16, 1, 0)
	end
	local box
	if mobile then
		box = util.new("TextBox", {
			Name = "textbox",
			BackgroundColor3 = values().raised,
			BorderSizePixel = 0,
			ClearTextOnFocus = false,
			Active = not disabled,
			TextEditable = not disabled,
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
			Name = "textbox",
			BackgroundColor3 = values().raised,
			BorderSizePixel = 0,
			ClearTextOnFocus = false,
			Active = not disabled,
			TextEditable = not disabled,
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

	box.Focused:Connect(function()
		edge.Color = values().accent
		edge.Transparency = 0.2
	end)
	box.FocusLost:Connect(function()
		edge.Color = values().line
		edge.Transparency = 0.2
		if disabled then
			return
		end
		win._store(stored, box.Text)
		if callback then
			callback(box.Text)
		end
	end)

	win._link(env.uis.InputBegan, function(input)
		if not box:IsFocused() then
			return
		end
		local code = input.KeyCode
		local kind = input.UserInputType
		local keyboard_release = kind == Enum.UserInputType.Keyboard and (code == Enum.KeyCode.Escape or code == Enum.KeyCode.Return or code == Enum.KeyCode.KeypadEnter)
		local gamepad_release = string.match(kind.Name, "^Gamepad") and code == Enum.KeyCode.ButtonB
		if keyboard_release or gamepad_release then
			box:ReleaseFocus()
		end
	end)

	style.paint(function()
		box.BackgroundColor3 = values().raised
		box.TextColor3 = disabled and values().muted or values().text
		box.PlaceholderColor3 = values().muted
		edge.Color = values().line
		name.TextColor3 = disabled and values().muted or values().text
		if emblem then
			icons.tint(emblem, disabled and values().line or values().muted)
		end
	end)

	local function set_disabled(value)
		disabled = value == true
		box.TextEditable = not disabled
		box.Active = not disabled
		if disabled and box:IsFocused() then
			box:ReleaseFocus()
		end
		box.TextColor3 = disabled and values().muted or values().text
		name.TextColor3 = disabled and values().muted or values().text
		if emblem then
			icons.tint(emblem, disabled and values().line or values().muted)
		end
		if win._nav_refresh then
			win._nav_refresh()
		end
	end

	stored = win._bind("text", title, {
		set = function(value)
			box.Text = tostring(value)
		end,
		apply = function(value)
			box.Text = tostring(value)
			if callback then
				local next = box.Text
				task.defer(function()
					callback(next)
				end)
			end
		end,
	})
	win._options(row, title, function()
		return {
			{ label = "Clear text", icon = "close", run = function()
				if disabled then
					return
				end
				box.Text = ""
				win._store(stored, "")
				if callback then
					callback("")
				end
			end },
			{ label = "Reset to default", icon = "arrow", run = function()
				if disabled then
					return
				end
				box.Text = tostring(initial or "")
				win._store(stored, box.Text)
				if callback then
					callback(box.Text)
				end
			end },
		}
	end)
	win._nav_register(row, {
		kind = "textbox",
		label = title,
		is_enabled = function()
			return not disabled
		end,
		activate = function()
			if not disabled then
				box:CaptureFocus()
			end
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
			if not disabled then
				box:CaptureFocus()
			end
		end,
		SetDisabled = function(_, value)
			set_disabled(value)
		end,
		GetDisabled = function()
			return disabled
		end,
		Gui = row,
	}
end

S.text = text
