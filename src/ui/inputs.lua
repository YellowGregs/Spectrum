local S = ...

local env = S.env
local util = S.util
local style = S.style
local icons = S.icons
local tooltip = S.tooltip
local bold = Enum.Font.GothamBold
local font = Enum.Font.GothamMedium
local inputs = {}

local function values()
	return style.values
end

local function label(parent, text, y, height)
	return util.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, y or 0),
		Size = UDim2.new(1, -90, 0, height or 14),
		Font = font,
		Text = tostring(text or ""),
		TextColor3 = values().text,
		TextSize = util.size(11),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = parent,
	})
end

local function row_emblem(parent, icon, size, color, y)
	if type(icon) ~= "string" or icon == "" then
		return nil
	end
	local emblem = icons.image(parent, icon, size or 14, color or values().muted)
	if not emblem then
		return nil
	end
	if y then
		emblem.AnchorPoint = Vector2.new(0, 0)
		emblem.Position = UDim2.fromOffset(10, y)
	else
		emblem.AnchorPoint = Vector2.new(0, 0.5)
		emblem.Position = UDim2.new(0, 10, 0.5, 0)
	end
	icons.layer(emblem, 4)
	return emblem
end

function inputs.button(win, text, callback, icon, opts)
	if type(icon) == "table" and opts == nil then
		opts = icon
		icon = opts.icon
	end
	opts = type(opts) == "table" and opts or {}
	local disabled = opts.disabled == true
	local variant = tostring(opts.variant or opts.style or "primary"):lower()
	local confirm = type(opts.confirm) == "string" and opts.confirm ~= "" and opts.confirm
		or (opts.confirm == true and "Click again to confirm" or nil)
	local _, front = style.variant(variant)
	local mobile = win._mobile
	local holder = win._slot(mobile and 46 or 32)
	local btn = util.new("TextButton", {
		Name = "button",
		BackgroundColor3 = values().accent,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = not disabled,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -16, 0, mobile and 36 or 24),
		Font = bold,
		Text = tostring(text or "Button"),
		TextColor3 = front,
		TextSize = util.size(mobile and 11 or 9),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = holder,
	})
	util.corner(btn)
	local emblem
	if type(icon) == "string" and icon ~= "" then
		emblem = icons.image(btn, icon, 14, style.on(values().accent))
		if emblem then
			emblem.AnchorPoint = Vector2.new(0, 0.5)
			emblem.Position = UDim2.new(0, 10, 0.5, 0)
			icons.layer(emblem, 4)
		end
	end
	local pop = util.new("UIScale", { Parent = btn })
	local held = false
	local armed = false
	local arm_token = 0

	local function ink()
		if disabled then
			return values().muted
		end
		local _, tone = style.variant(variant)
		return tone
	end

	local function face()
		if disabled then
			return values().raised
		end
		local back = style.variant(variant)
		if held then
			return back:Lerp(Color3.new(1, 1, 1), 0.14)
		end
		return back
	end

	local function paint()
		btn.BackgroundColor3 = face()
		btn.TextColor3 = ink()
		if emblem then
			icons.tint(emblem, ink())
		end
	end

	local function run()
		if disabled then
			return
		end
		if confirm and not armed then
			armed = true
			arm_token = arm_token + 1
			local mine = arm_token
			btn.Text = confirm
			task.delay(3, function()
				if btn.Parent and armed and arm_token == mine then
					armed = false
					btn.Text = tostring(text or "Button")
				end
			end)
			return
		end
		armed = false
		arm_token = arm_token + 1
		btn.Text = tostring(text or "Button")
		if callback then
			callback()
		end
	end

	if tooltip and opts.tooltip then
		tooltip.attach(btn, opts.tooltip)
	end

	btn.MouseEnter:Connect(function()
		if disabled then
			return
		end
		held = true
		util.tween(btn, 0.12, { BackgroundColor3 = face() })
	end)
	btn.MouseLeave:Connect(function()
		held = false
		util.tween(btn, 0.15, { BackgroundColor3 = face() })
	end)
	btn.Activated:Connect(run)
	btn.MouseButton1Down:Connect(function()
		if disabled then
			return
		end
		util.tween(pop, 0.08, { Scale = 0.97 }, Enum.EasingStyle.Quad)
	end)
	btn.MouseButton1Up:Connect(function()
		if disabled then
			return
		end
		util.tween(pop, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	end)

	local function set_disabled(value)
		disabled = value == true
		btn.Active = not disabled
		if disabled then
			held = false
			armed = false
			btn.Text = tostring(text or "Button")
			util.tween(pop, 0.1, { Scale = 1 })
		end
		if btn:GetAttribute("SpectrumDisabled") ~= disabled then
			btn:SetAttribute("SpectrumDisabled", disabled)
		end
		paint()
		if win._nav_refresh then
			win._nav_refresh()
		end
	end

	btn:SetAttribute("SpectrumDisabled", disabled)
	btn:GetAttributeChangedSignal("SpectrumDisabled"):Connect(function()
		set_disabled(btn:GetAttribute("SpectrumDisabled") == true)
	end)
	style.paint(paint)

	win._options(holder, text, function()
		return {
			{ label = "Run action", icon = "arrow", accent = true, run = run },
		}
	end)

	win._nav_register(holder, {
		kind = "button",
		label = text,
		is_enabled = function()
			return not disabled
		end,
		activate = run,
	})

	win._fit(true)
	return btn
end

function inputs.toggle(win, text, a, b, opts)
	local mobile = win._mobile
	local listeners = {}
	local state, changed
	if type(a) == "function" then
		changed = a
		state = false
	else
		state = a == true
		changed = b
	end
	if type(opts) == "string" then
		opts = { style = opts }
	elseif type(opts) ~= "table" then
		opts = {}
	end
	local kind = tostring(opts.style or "switch"):lower()
	local checkbox = kind == "checkbox" or kind == "check"
	local disabled = opts.disabled == true
	local row = win._row()
	local initial = state
	local heading = label(row, text, 0)
	local emblem = row_emblem(row, opts.icon, 14, values().muted)
	local inset = checkbox and 44 or 64
	if emblem then
		inset = inset + 18
		heading.Position = UDim2.fromOffset(28, 0)
	end
	heading.Size = UDim2.new(1, -inset, 1, 0)

	local hit = util.new("TextButton", {
		BackgroundColor3 = values().hover,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = not disabled,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		ZIndex = 1,
		Parent = row,
	})
	util.hover(hit)

	local pop
	local sync
	if checkbox then
		local size = mobile and 20 or 16
		local box = util.new("Frame", {
			Name = "checkbox",
			BackgroundColor3 = values().raised,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(size, size),
			ZIndex = 3,
			Parent = row,
		})
		util.corner(box, 3)
		local edge = util.stroke(box, values().line, 0.15)
		pop = util.new("UIScale", { Parent = box })
		local check = util.new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 4,
			Parent = box,
		})
		local short = util.new("Frame", {
			BackgroundColor3 = values().ink,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.34, 0.6),
			Rotation = 45,
			Size = UDim2.new(0, size * 0.3, 0, math.max(1, size * 0.11)),
			ZIndex = 5,
			Parent = check,
		})
		local long = util.new("Frame", {
			BackgroundColor3 = values().ink,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.59, 0.51),
			Rotation = -45,
			Size = UDim2.new(0, size * 0.52, 0, math.max(1, size * 0.11)),
			ZIndex = 5,
			Parent = check,
		})

		sync = function()
			check.Visible = state
			local accent = disabled and values().muted or values().accent
			local tint = state and accent or values().raised
			util.tween(box, 0.12, { BackgroundColor3 = tint })
			edge.Color = state and accent or values().line
			edge.Transparency = state and 1 or 0.15
			local ink = state and (disabled and values().ink or style.on(values().accent)) or values().ink
			short.BackgroundColor3 = ink
			long.BackgroundColor3 = ink
		end
	else
		local width = mobile and 40 or 36
		local height = mobile and 20 or 18
		local thumb_size = height - 4
		local track = util.new("Frame", {
			Name = "switch_track",
			BackgroundColor3 = state and values().accent or values().raised,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(width, height),
			ZIndex = 3,
			Parent = row,
		})
		util.corner(track, height / 2)
		local edge = util.stroke(track, state and values().accent or values().line, state and 1 or 0.2)
		local thumb = util.new("Frame", {
			Name = "switch_thumb",
			BackgroundColor3 = state and Color3.new(1, 1, 1) or values().muted,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, state and (width - thumb_size - 2) or 2, 0.5, 0),
			Size = UDim2.fromOffset(thumb_size, thumb_size),
			ZIndex = 4,
			Parent = track,
		})
		util.corner(thumb, thumb_size / 2)
		pop = util.new("UIScale", { Parent = track })

		sync = function()
			local x = state and (width - thumb_size - 2) or 2
			local accent = disabled and values().muted or values().accent
			util.tween(thumb, 0.16, {
				Position = UDim2.new(0, x, 0.5, 0),
				BackgroundColor3 = state and (disabled and values().muted or Color3.new(1, 1, 1)) or values().muted,
			}, Enum.EasingStyle.Quart)
			util.tween(track, 0.14, { BackgroundColor3 = state and accent or values().raised })
			edge.Color = state and accent or values().line
			edge.Transparency = state and 1 or 0.2
		end
	end

	local key
	local function set(value, fire)
		if disabled and fire then
			return
		end
		state = value == true
		sync()
		pop.Scale = 0.9
		util.tween(pop, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
		if fire then
			win._store(key, state)
			if changed then
				changed(state)
			end
		end
		for _, listener in ipairs(listeners) do
			pcall(listener, state)
		end
	end

	hit.Activated:Connect(function()
		if disabled then
			return
		end
		set(not state, true)
	end)

	local function set_disabled(value)
		disabled = value == true
		hit.Active = not disabled
		heading.TextColor3 = disabled and values().muted or values().text
		if emblem then
			icons.tint(emblem, disabled and values().line or values().muted)
		end
		sync()
		if win._nav_refresh then
			win._nav_refresh()
		end
	end

	style.paint(function()
		row.BackgroundColor3 = values().hover
		hit.BackgroundColor3 = values().hover
		heading.TextColor3 = disabled and values().muted or values().text
		if emblem then
			icons.tint(emblem, disabled and values().line or values().muted)
		end
		sync()
	end)

	sync()
	key = win._bind("toggle", text, {
		set = function(value)
			set(value, false)
		end,
		apply = function(value)
			set(value, false)
			if changed then
				local next = state
				task.defer(function()
					if changed then
						changed(next)
					end
				end)
			end
		end,
	})
	win._options(row, text, function()
		return {
			{ label = state and "Turn off" or "Turn on", icon = "sliders", accent = true, run = function() set(not state, true) end },
			{ label = "Reset to default", icon = "arrow", run = function() set(initial, true) end },
		}
	end)
	win._nav_register(row, {
		kind = "toggle",
		label = text,
		is_enabled = function()
			return not disabled
		end,
		activate = function()
			set(not state, true)
		end,
		adjust = function(direction)
			set(direction > 0, true)
		end,
	})
	if tooltip and opts.tooltip then
		tooltip.attach(row, opts.tooltip)
	end
	win._fit(true)

	return {
		Set = function(_, value)
			set(value, false)
		end,
		Get = function()
			return state
		end,
		Toggle = function()
			set(not state, true)
		end,
		OnChanged = function(_, fn)
			if type(fn) ~= "function" then
				return function() end
			end
			listeners[#listeners + 1] = fn
			return function()
				for index, entry in ipairs(listeners) do
					if entry == fn then
						table.remove(listeners, index)
						break
					end
				end
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

function inputs.slider(win, text, min, max, default, callback, step, icon, opts)
	opts = type(opts) == "table" and opts or {}
	local disabled = opts.disabled == true
	local mobile = win._mobile
	local compact = opts.compact == true
	local suffix = type(opts.suffix) == "string" and opts.suffix or ""
	local show_max = opts.showMax == true or opts.hideMax == false
	local row = win._row(compact and (mobile and 40 or 34) or (mobile and 46 or 40))
	local low = tonumber(min) or 0
	local high = tonumber(max) or 100
	if high <= low then
		high = low + 1
	end
	local notch = tonumber(step) or 1
	if notch <= 0 then
		notch = 1
	end
	local initial = math.clamp(tonumber(default) or low, low, high)
	local value = initial
	local precision = tonumber(opts.decimals)
	local decimals = math.clamp(
		math.floor(precision ~= nil and precision or (notch >= 1 and 0 or (notch >= 0.1 and 1 or 2))),
		0,
		3
	)
	local label_y = compact and 3 or (mobile and 7 or 5)
	local track_y = compact and (mobile and 24 or 22) or (mobile and 31 or 27)

	local emblem = row_emblem(row, icon, 14, values().muted, label_y)
	local name = label(row, text, label_y, 14)
	if emblem then
		name.Position = UDim2.fromOffset(28, label_y)
		name.Size = UDim2.new(1, -120, 0, 14)
	else
		name.Size = UDim2.new(1, -100, 0, 14)
	end

	local readout = util.new("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, compact and 2 or (mobile and 6 or 4)),
		Size = UDim2.fromOffset(88, 14),
		Font = bold,
		Text = "",
		TextColor3 = values().muted,
		TextSize = util.size(10),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = row,
	})

	local track = util.new("Frame", {
		BackgroundColor3 = values().raised,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 10, 0, track_y),
		Size = UDim2.new(1, -20, 0, mobile and 5 or 4),
		ZIndex = 3,
		Parent = row,
	})
	util.corner(track, 3)

	local fill = util.new("Frame", {
		BackgroundColor3 = values().accent,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 4,
		Parent = track,
	})
	util.corner(fill, 3)

	local thumb = util.new("Frame", {
		BackgroundColor3 = values().accent,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(6, mobile and 16 or 13),
		ZIndex = 5,
		Parent = track,
	})
	util.corner(thumb, 3)

	local hit = util.new("TextButton", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = not disabled,
		Position = UDim2.new(0, 4, 0, math.max(0, track_y - 10)),
		Size = UDim2.new(1, -8, 0, 22),
		Text = "",
		ZIndex = 2,
		Parent = row,
	})

	local dragging = false
	local key
	local function paint_value(fire)
		local alpha = (value - low) / (high - low)
		fill.Size = UDim2.fromScale(alpha, 1)
		thumb.Position = UDim2.new(alpha, 0, 0.5, 0)
		local shown = string.format("%." .. decimals .. "f", value) .. suffix
		if show_max then
			shown = shown .. " / " .. string.format("%." .. decimals .. "f", high) .. suffix
		end
		readout.Text = shown
		readout.TextColor3 = disabled and values().muted or (dragging and values().accent or values().muted)
		if fire then
			win._store(key, value)
			if callback then
				callback(value)
			end
		end
	end

	local function apply(next, fire)
		value = math.clamp(tonumber(next) or value, low, high)
		paint_value(fire)
	end

	local function snap(x)
		local alpha = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
		local raw = low + (high - low) * alpha
		local stepped = math.floor((raw - low) / notch + 0.5) * notch + low
		return math.clamp(math.floor(stepped * 1000 + 0.5) / 1000, low, high)
	end

	local function begin(input)
		if disabled then
			return
		end
		dragging = true
		win._scroll.ScrollingEnabled = false
		thumb.Size = UDim2.fromOffset(7, mobile and 18 or 15)
		value = snap(input.Position.X)
		paint_value(true)
	end

	hit.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			begin(input)
		end
	end)

	win._link(env.uis.InputChanged, function(input)
		if disabled or not dragging then
			return
		end
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseMovement or kind == Enum.UserInputType.Touch then
			value = snap(input.Position.X)
			paint_value(true)
		end
	end)

	win._link(env.uis.InputEnded, function(input)
		local kind = input.UserInputType
		if dragging and (kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch) then
			dragging = false
			win._scroll.ScrollingEnabled = true
			thumb.Size = UDim2.fromOffset(6, mobile and 16 or 13)
			paint_value(false)
		end
	end)

	style.paint(function()
		track.BackgroundColor3 = values().raised
		fill.BackgroundColor3 = disabled and values().muted or values().accent
		thumb.BackgroundColor3 = disabled and values().muted or values().accent
		name.TextColor3 = disabled and values().muted or values().text
		readout.TextColor3 = disabled and values().muted or (dragging and values().accent or values().muted)
		if emblem then
			icons.tint(emblem, disabled and values().line or values().muted)
		end
	end)

	local function set_disabled(value)
		disabled = value == true
		hit.Active = not disabled
		if disabled and dragging then
			dragging = false
			win._scroll.ScrollingEnabled = true
			thumb.Size = UDim2.fromOffset(6, mobile and 16 or 13)
		end
		fill.BackgroundColor3 = disabled and values().muted or values().accent
		thumb.BackgroundColor3 = disabled and values().muted or values().accent
		name.TextColor3 = disabled and values().muted or values().text
		if emblem then
			icons.tint(emblem, disabled and values().line or values().muted)
		end
		paint_value(false)
		if win._nav_refresh then
			win._nav_refresh()
		end
	end

	paint_value(false)
	key = win._bind("slider", text, {
		set = function(value)
			apply(value, false)
		end,
		apply = function(value)
			apply(value, false)
			if callback then
				local next = value
				task.defer(function()
					callback(next)
				end)
			end
		end,
	})
	win._options(row, text, function()
		return { -- you can change this if you want
			{ label = "Reset to default", icon = "arrow", run = function()
				if not disabled then
					apply(initial, true)
				end
			end },
			{ label = "Set minimum", run = function()
				if not disabled then
					apply(low, true)
				end
			end },
			{ label = "Set maximum", run = function()
				if not disabled then
					apply(high, true)
				end
			end },
		}
	end)
	win._nav_register(row, {
		kind = "slider",
		label = text,
		is_enabled = function()
			return not disabled
		end,
		adjust = function(direction)
			if not disabled then
				apply(math.clamp(value + direction * notch, low, high), true)
			end
		end,
	})
	if tooltip and opts.tooltip then
		tooltip.attach(row, opts.tooltip)
	end
	win._fit(true)

	return {
		Set = function(_, next)
			apply(next, false)
		end,
		Get = function()
			return value
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

function inputs.keybind(win, text, default, callback, icon, opts)
	if type(icon) == "table" and opts == nil then
		opts = icon
		icon = opts.icon
	end
	opts = type(opts) == "table" and opts or {}
	local on_change = type(opts.onChange) == "function" and opts.onChange or nil
	local on_press = type(opts.onPress) == "function" and opts.onPress or nil
	local on_release = type(opts.onRelease) == "function" and opts.onRelease or nil
	local mirror_toggle = type(opts.syncToggle) == "table" and opts.syncToggle or nil
	local mode = tostring(opts.mode or (on_release and "hold" or "toggle")):lower()
	if mode ~= "hold" and mode ~= "toggle" then
		mode = "hold"
	end
	local action = on_press ~= nil or on_release ~= nil or mirror_toggle ~= nil or opts.mode ~= nil
	local empty_text = type(opts.emptyText) == "string" and opts.emptyText ~= "" and opts.emptyText or "None"
	local disabled = opts.disabled == true
	local allow_mouse = opts.allowMouse ~= false
	local allow_gamepad = opts.allowGamepad ~= false
	local clear_on_delete = opts.clearOnDelete ~= false
	local mobile = win._mobile
	local row = win._row(mobile and 40 or 34)
	row.ClipsDescendants = true
	local initial = default
	local reset_key = opts.resetKey ~= nil and opts.resetKey or initial
	local emblem = row_emblem(row, icon, 14, values().muted)
	local caption = label(row, text, 0)
	if emblem then
		caption.Position = UDim2.fromOffset(28, 0)
		caption.Size = UDim2.new(1, -136, 1, 0)
	else
		caption.Size = UDim2.new(1, -128, 1, 0)
	end

	local pill = util.new("TextButton", {
		BackgroundColor3 = values().raised,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = not disabled,
		ClipsDescendants = true,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(mobile and 96 or 84, mobile and 30 or 22),
		Font = bold,
		Text = default or empty_text,
		TextColor3 = values().muted,
		TextSize = util.size(9),
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
		Parent = row,
	})
	util.corner(pill, 3)
	local edge = util.stroke(pill, values().line, 0.35)
	util.hover(pill)

	local key = default
	local listening = false
	local held = {}
	local stored
	local active = false
	local toggled = false

	local function display(value)
		if value == nil or value == "" then
			return empty_text
		end
		local label = util.input_label(value)
		if #label > 14 then
			label = string.sub(label, 1, 12) .. "..."
		end
		return label
	end

	local function sync()
		local fill = values().raised
		local tone = key and values().text or values().muted
		local border = values().line
		local border_alpha = 0.35
		if disabled then
			tone = values().muted
		elseif listening then
			tone = values().accent
			border = values().accent
			border_alpha = 0.2
		elseif active then
			tone = style.on(values().accent)
			fill = values().accent
			border = values().accent
			border_alpha = 1
		end
		pill.Text = listening and "..." or display(key)
		pill.TextColor3 = tone
		pill.BackgroundColor3 = fill
		edge.Color = border
		edge.Transparency = border_alpha
	end

	local function release_action()
		if not active then
			return
		end
		active = false
		sync()
		if on_release then
			pcall(on_release)
		end
	end

	local function press_action()
		if not action then
			return
		end
		if mode == "toggle" then
			toggled = not toggled
			active = toggled
			sync()
			if mirror_toggle then
				pcall(function()
					if type(mirror_toggle.Toggle) == "function" then
						mirror_toggle:Toggle()
					else
						mirror_toggle:Set(toggled)
					end
				end)
			end
			if on_press then
				pcall(on_press, toggled)
			end
		else
			active = true
			sync()
			if on_press then
				pcall(on_press, true)
			end
		end
	end

	local function mirror_state()
		if not mirror_toggle then
			return
		end
		local ok, value = pcall(function()
			return mirror_toggle:Get()
		end)
		if ok and type(value) == "boolean" and value ~= toggled then
			toggled = value
			if mode == "toggle" then
				active = value
				sync()
			end
		end
	end

	if mirror_toggle and type(mirror_toggle.OnChanged) == "function" then
		local stop = mirror_toggle:OnChanged(function(value)
			toggled = value == true
			if mode == "toggle" then
				active = toggled
				sync()
			end
		end)
		if type(stop) == "function" then
			row.Destroying:Connect(stop)
		end
	end

	local function toggle_capture()
		if disabled then
			return
		end
		listening = not listening
		S.binding = listening
		sync()
	end

	pill.Activated:Connect(toggle_capture)

	row.Destroying:Connect(function()
		if listening then
			listening = false
			S.binding = false
		end
		if active then
			active = false
			if on_release then
				pcall(on_release)
			end
		end
	end)

	local function cancel_capture()
		listening = false
		S.binding = false
		sync()
	end

	local function clear_key()
		key = nil
		toggled = false
		release_action()
		cancel_capture()
		win._store(stored, key)
		if on_change then
			on_change(nil)
		end
		if callback then
			callback(nil, false)
		end
	end

	win._link(env.uis.InputBegan, function(input, processed)
		if disabled then
			return
		end
		local id = util.input_id(input)
		if listening then
			if not id then
				return
			end
			local kind_name = input.UserInputType.Name
			local is_keyboard = input.UserInputType == Enum.UserInputType.Keyboard
			if is_keyboard and input.KeyCode == Enum.KeyCode.Escape then
				cancel_capture()
				return
			end
			if is_keyboard and clear_on_delete and (input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Delete) then
				clear_key()
				return
			end
			local is_mouse = string.match(kind_name, "^MouseButton%d+$") ~= nil
			local is_gamepad = string.match(kind_name, "^Gamepad%d+$") ~= nil
			if (is_mouse and not allow_mouse) or (is_gamepad and not allow_gamepad) then
				return
			end
			key = id
			cancel_capture()
			win._store(stored, key)
			held[id] = true
			if on_change then
				on_change(key)
			end
			if callback then
				callback(key, true)
			end
			return
		end
		if processed or util.focused_text_box() or S.splash_open or not win.Gui.Visible then
			return
		end
		if key and id == key and not held[id] then
			held[id] = true
			mirror_state()
			press_action()
			if callback then
				callback(key, true)
			end
		end
	end)

	win._link(env.uis.InputEnded, function(input)
		if disabled then
			return
		end
		local id = util.input_id(input)
		if id and id == key and held[id] then
			held[id] = nil
			release_action()
			if callback then
				callback(key, false)
			end
		end
	end)

	style.paint(function()
		caption.TextColor3 = disabled and values().muted or values().text
		if emblem then
			icons.tint(emblem, disabled and values().line or values().muted)
		end
		sync()
	end)

	if tooltip and opts.tooltip then
		tooltip.attach(row, opts.tooltip)
	end

	local function set_disabled(value)
		disabled = value == true
		pill.Active = not disabled
		if disabled then
			if listening then
				listening = false
				S.binding = false
			end
			held = {}
			if active then
				active = false
				if on_release then
					pcall(on_release)
				end
			end
		end
		sync()
		if win._nav_refresh then
			win._nav_refresh()
		end
	end

	sync()
	stored = win._bind("key", text, {
		set = function(value)
			if key == value then
				return
			end
			key = value
			sync()
			if on_change then
				on_change(key)
			end
		end,
	})
	win._options(row, text, function()
		return {
			{ label = "Clear key", icon = "close", run = function()
				if disabled then
					return
				end
				key = nil
				toggled = false
				release_action()
				sync()
				win._store(stored, key)
				if on_change then
					on_change(nil)
				end
				if callback then
					callback(key, false)
				end
			end },
			{ label = "Reset to default", icon = "arrow", run = function()
				if disabled then
					return
				end
				key = reset_key
				sync()
				win._store(stored, key)
				if on_change then
					on_change(reset_key)
				end
			end },
		}
	end)
	win._nav_register(row, {
		kind = "keybind",
		label = text,
		is_enabled = function()
			return not disabled
		end,
		activate = toggle_capture,
	})
	win._fit(true)

	return {
		Set = function(_, next)
			if key == next then
				return
			end
			key = next
			sync()
			win._store(stored, key)
			if on_change then
				on_change(key)
			end
		end,
		Get = function()
			return key
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

S.inputs = inputs
