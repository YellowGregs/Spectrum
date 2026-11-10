local S = ...

local env = S.env
local util = S.util
local style = S.style
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

function inputs.button(win, text, callback)
	local mobile = win._mobile
	local holder = win._slot(mobile and 44 or 37)
	local btn = util.new("TextButton", {
		Name = "button",
		BackgroundColor3 = values().accent,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -16, 0, mobile and 34 or 27),
		Font = bold,
		Text = tostring(text or "Button"),
		TextColor3 = style.on(values().accent),
		TextSize = util.size(11),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = holder,
	})
	util.corner(btn)
	local pop = util.new("UIScale", { Parent = btn })
	local held = false

	local function face()
		if held then
			return values().accent:Lerp(Color3.new(1, 1, 1), 0.14)
		end
		return values().accent
	end

	btn.MouseEnter:Connect(function()
		held = true
		util.tween(btn, 0.12, { BackgroundColor3 = face() })
	end)
	btn.MouseLeave:Connect(function()
		held = false
		util.tween(btn, 0.15, { BackgroundColor3 = face() })
	end)
	btn.Activated:Connect(function()
		if callback then
			callback()
		end
	end)
	btn.MouseButton1Down:Connect(function()
		util.tween(pop, 0.08, { Scale = 0.97 }, Enum.EasingStyle.Quad)
	end)
	btn.MouseButton1Up:Connect(function()
		util.tween(pop, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	end)

	style.paint(function()
		btn.BackgroundColor3 = face()
		btn.TextColor3 = style.on(values().accent)
	end)

	win._fit(true)
	return btn
end

function inputs.toggle(win, text, a, b)
	local mobile = win._mobile
	local state, changed
	if type(a) == "function" then
		changed = a
		state = false
	else
		state = a == true
		changed = b
	end

	local row = win._row()
	local size = mobile and 20 or 16
	local box = util.new("Frame", {
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
	local pop = util.new("UIScale", { Parent = box })

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
		Parent = check,
	})
	local long = util.new("Frame", {
		BackgroundColor3 = values().ink,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.59, 0.51),
		Rotation = -45,
		Size = UDim2.new(0, size * 0.52, 0, math.max(1, size * 0.11)),
		Parent = check,
	})

	label(row, text, 0).Size = UDim2.new(1, -46, 1, 0)

	local hit = util.new("TextButton", {
		BackgroundColor3 = values().hover,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		ZIndex = 1,
		Parent = row,
	})
	util.hover(hit)

	local function sync()
		check.Visible = state
		local tint = state and values().accent or values().raised
		util.tween(box, 0.12, { BackgroundColor3 = tint })
		edge.Color = state and values().accent or values().line
		edge.Transparency = state and 1 or 0.15
		local ink = state and style.on(values().accent) or values().ink
		short.BackgroundColor3 = ink
		long.BackgroundColor3 = ink
	end

	local function set(value, fire)
		state = value == true
		sync()
		pop.Scale = 0.86
		util.tween(pop, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
		if fire and changed then
			changed(state)
		end
	end

	hit.Activated:Connect(function()
		set(not state, true)
	end)

	style.paint(function()
		row.BackgroundColor3 = values().hover
		hit.BackgroundColor3 = values().hover
		sync()
	end)

	sync()
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
		Gui = row,
	}
end

function inputs.slider(win, text, min, max, default, callback, step)
	local mobile = win._mobile
	local row = win._row(mobile and 46 or 40)
	local low = tonumber(min) or 0
	local high = tonumber(max) or 100
	if high <= low then
		high = low + 1
	end
	local notch = tonumber(step) or 1
	if notch <= 0 then
		notch = 1
	end
	local value = math.clamp(tonumber(default) or low, low, high)
	local decimals = notch >= 1 and 0 or (notch >= 0.1 and 1 or 2)

	local name = label(row, text, mobile and 7 or 5, 14)
	name.Size = UDim2.new(1, -80, 0, 14)

	local readout = util.new("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, mobile and 6 or 4),
		Size = UDim2.fromOffset(62, 14),
		Font = bold,
		Text = "",
		TextColor3 = values().muted,
		TextSize = util.size(10),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 3,
		Parent = row,
	})

	local track = util.new("Frame", {
		BackgroundColor3 = values().raised,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 10, 0, mobile and 31 or 27),
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
		Position = UDim2.new(0, 4, 0, mobile and 20 or 17),
		Size = UDim2.new(1, -8, 0, 22),
		Text = "",
		ZIndex = 2,
		Parent = row,
	})

	local dragging = false
	local function paintValue(fire)
		local alpha = (value - low) / (high - low)
		fill.Size = UDim2.fromScale(alpha, 1)
		thumb.Position = UDim2.new(alpha, 0, 0.5, 0)
		readout.Text = string.format("%." .. decimals .. "f", value)
		readout.TextColor3 = dragging and values().accent or values().muted
		if fire and callback then
			callback(value)
		end
	end

	local function snap(x)
		local alpha = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
		local raw = low + (high - low) * alpha
		local stepped = math.floor((raw - low) / notch + 0.5) * notch + low
		return math.clamp(math.floor(stepped * 1000 + 0.5) / 1000, low, high)
	end

	local function begin(input)
		dragging = true
		win._scroll.ScrollingEnabled = false
		thumb.Size = UDim2.fromOffset(7, mobile and 18 or 15)
		value = snap(input.Position.X)
		paintValue(true)
	end

	hit.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			begin(input)
		end
	end)

	win._link(env.uis.InputChanged, function(input)
		if not dragging then
			return
		end
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseMovement or kind == Enum.UserInputType.Touch then
			value = snap(input.Position.X)
			paintValue(true)
		end
	end)

	win._link(env.uis.InputEnded, function(input)
		local kind = input.UserInputType
		if dragging and (kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch) then
			dragging = false
			win._scroll.ScrollingEnabled = true
			thumb.Size = UDim2.fromOffset(6, mobile and 16 or 13)
			paintValue(false)
		end
	end)

	style.paint(function()
		track.BackgroundColor3 = values().raised
		fill.BackgroundColor3 = values().accent
		thumb.BackgroundColor3 = values().accent
		readout.TextColor3 = dragging and values().accent or values().muted
	end)

	paintValue(false)
	win._fit(true)

	return {
		Set = function(_, next)
			value = math.clamp(tonumber(next) or value, low, high)
			paintValue(true)
		end,
		Get = function()
			return value
		end,
		Gui = row,
	}
end

function inputs.keybind(win, text, default, callback)
	local mobile = win._mobile
	local row = win._row(mobile and 40 or 34)
	label(row, text, 0).Size = UDim2.new(1, -100, 1, 0)

	local pill = util.new("TextButton", {
		BackgroundColor3 = values().raised,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(mobile and 74 or 62, mobile and 26 or 21),
		Font = bold,
		Text = default or "None",
		TextColor3 = values().muted,
		TextSize = util.size(9),
		ZIndex = 3,
		Parent = row,
	})
	util.corner(pill, 3)
	local edge = util.stroke(pill, values().line, 0.35)
	util.hover(pill)

	local key = default
	local listening = false
	local held = {}

	local function sync()
		pill.Text = listening and "..." or (key and tostring(key) or "None")
		pill.TextColor3 = listening and values().accent or (key and values().text or values().muted)
		edge.Color = listening and values().accent or values().line
	end

	pill.Activated:Connect(function()
		listening = not listening
		sync()
	end)

	win._link(env.uis.InputBegan, function(input)
		if listening then
			if input.UserInputType == Enum.UserInputType.Keyboard then
				local code = input.KeyCode
				if code == Enum.KeyCode.Escape then
					listening = false
					sync()
					return
				end
				key = code.Name
				listening = false
				sync()
				held[code] = true
				if callback then
					callback(key, true)
				end
			end
			return
		end
		if key and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode.Name == key then
			held[input.KeyCode] = true
			if callback then
				callback(key, true)
			end
		end
	end)

	win._link(env.uis.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode.Name == key and held[input.KeyCode] then
			held[input.KeyCode] = nil
			if callback then
				callback(key, false)
			end
		end
	end)

	style.paint(function()
		edge.Color = listening and values().accent or values().line
		pill.BackgroundColor3 = values().raised
		sync()
	end)

	sync()
	win._fit(true)

	return {
		Set = function(_, next)
			key = next
			sync()
		end,
		Get = function()
			return key
		end,
		Gui = row,
	}
end

S.inputs = inputs
