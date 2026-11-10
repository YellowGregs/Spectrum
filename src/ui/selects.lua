local S = ...

local env = S.env
local util = S.util
local style = S.style
local modal = S.modal
local bold = Enum.Font.GothamBold
local font = Enum.Font.GothamMedium
local selects = {}

local function values()
	return style.values
end

local function caption(parent, title)
	return util.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(0.5, -20, 1, 0),
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

function selects.dropdown(win, title, options, default, callback, multi)
	local mobile = win._mobile
	local choices = {}
	for _, option in ipairs(options or {}) do
		choices[#choices + 1] = tostring(option)
	end

	if type(default) == "function" then
		callback = default
		default = nil
	end

	local picks = {}
	local single = nil
	if multi then
		for _, option in ipairs(type(default) == "table" and default or {}) do
			picks[tostring(option)] = true
		end
	elseif default ~= nil then
		single = tostring(default)
	end

	local row = win._row(mobile and 40 or 34)
	local name = caption(row, title)
	name.Size = UDim2.new(0.48, -20, 1, 0)

	local readout = util.new("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -29, 0.5, 0),
		Size = UDim2.new(0.4, 0, 1, 0),
		Font = font,
		Text = "None",
		TextColor3 = values().muted,
		TextSize = util.size(10),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = row,
	})

	local chevron = util.chevron(row, 8, values().muted)
	chevron.AnchorPoint = Vector2.new(0.5, 0.5)
	chevron.Position = UDim2.new(1, -12, 0.5, 0)
	chevron.ZIndex = 3

	local pad = 4
	local itemH = mobile and 34 or 28
	local panelHeight = math.clamp(#choices * itemH + pad * 2, 40, mobile and 226 or 190)
	local panel = util.new("Frame", {
		Name = "dropdown",
		Active = true,
		BackgroundColor3 = values().background,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = UDim2.fromOffset(200, 0),
		Visible = false,
		ZIndex = 2,
		Parent = env.modal,
	})
	local edge = util.stroke(panel, values().line, 0.2)
	util.shadow(panel, 14, 0.55)
	win._popover(panel)

	local area = util.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(pad, pad),
		Size = UDim2.new(1, -pad * 2, 1, -pad * 2),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = values().muted,
		ScrollBarImageTransparency = 0.5,
		ZIndex = 3,
		Parent = panel,
	})
	util.new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = area,
	})

	local marks = {}
	local items = {}

	local function current()
		if not multi then
			return single
		end
		local out = {}
		for _, option in ipairs(choices) do
			if picks[option] then
				out[#out + 1] = option
			end
		end
		return out
	end

	local function refresh()
		local picked = 0
		for _, option in ipairs(choices) do
			if picks[option] then
				picked = picked + 1
			end
		end
		if multi then
			if picked == 0 then
				readout.Text = "None"
			elseif picked <= 2 then
				local names = {}
				for _, option in ipairs(choices) do
					if picks[option] then
						names[#names + 1] = option
					end
				end
				readout.Text = table.concat(names, ", ")
			else
				readout.Text = picked .. " selected"
			end
		else
			readout.Text = single or "None"
		end
		readout.TextColor3 = (multi and picked > 0 or single) and values().text or values().muted
		for option, item in pairs(items) do
			local on = multi and picks[option] or single == option
			item.TextColor3 = on and values().accent or values().muted
			item.Font = on and bold or font
			marks[option].Visible = on
		end
	end

	local open = false
	local setOpen

	local function close()
		setOpen(false)
	end

	function setOpen(state)
		if state == open then
			return
		end
		open = state
		if open then
			modal.claim(close)
			local view = env.viewport()
			local pos, size = row.AbsolutePosition, row.AbsoluteSize
			local width = math.min(math.max(size.X, 180), view.X - 12)
			local x = math.clamp(pos.X, 6, math.max(6, view.X - width - 6))
			local y = pos.Y + size.Y + 1
			if y + panelHeight > view.Y - 6 then
				y = pos.Y - panelHeight - 1
			end
			y = math.clamp(y, 6, math.max(6, view.Y - panelHeight - 6))
			panel.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
			panel.Size = UDim2.fromOffset(math.floor(width), 0)
			panel.Visible = true
			util.tween(panel, 0.13, { Size = UDim2.fromOffset(math.floor(width), panelHeight) })
			util.tween(chevron, 0.15, { Rotation = 180 })
		else
			modal.drop(close)
			util.tween(panel, 0.1, { Size = UDim2.fromOffset(panel.Size.X.Offset, 0) })
			util.tween(chevron, 0.15, { Rotation = 0 })
			task.delay(0.12, function()
				if not open and panel.Parent then
					panel.Visible = false
				end
			end)
		end
	end

	for index, option in ipairs(choices) do
		local item = util.new("TextButton", {
			BackgroundColor3 = values().hover,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, itemH),
			Font = font,
			Text = option,
			TextColor3 = values().muted,
			TextSize = util.size(11),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 4,
			Parent = area,
		})
		util.new("UIPadding", {
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 8),
			Parent = item,
		})
		util.hover(item)
		marks[option] = util.new("Frame", {
			BackgroundColor3 = values().accent,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.new(0, 2, 1, -14),
			Visible = false,
			ZIndex = 5,
			Parent = item,
		})
		items[option] = item

		item.Activated:Connect(function()
			if multi then
				if picks[option] then
					picks[option] = nil
				else
					picks[option] = true
				end
				refresh()
				if callback then
					callback(current())
				end
			else
				single = option
				refresh()
				setOpen(false)
				if callback then
					callback(option)
				end
			end
		end)
	end

	if #choices == 0 then
		local empty = util.new("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, itemH),
			Font = font,
			Text = "No options",
			TextColor3 = values().muted,
			TextSize = util.size(10),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 4,
			Parent = area,
		})
		util.new("UIPadding", { PaddingLeft = UDim.new(0, 12), Parent = empty })
	end

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
	hit.Activated:Connect(function()
		setOpen(not open)
	end)

	style.paint(function()
		panel.BackgroundColor3 = values().background
		edge.Color = values().line
		area.ScrollBarImageColor3 = values().muted
		hit.BackgroundColor3 = values().hover
		for option, item in pairs(items) do
			item.BackgroundColor3 = values().hover
			marks[option].BackgroundColor3 = values().accent
		end
		refresh()
	end)

	refresh()
	win._fit(true)

	return {
		Set = function(_, value)
			if multi then
				picks = {}
				for _, option in ipairs(type(value) == "table" and value or {}) do
					picks[tostring(option)] = true
				end
			else
				single = value ~= nil and tostring(value) or nil
			end
			refresh()
		end,
		Get = function()
			return current()
		end,
		SetList = function(_, values)
			picks = {}
			for _, option in ipairs(values or {}) do
				picks[tostring(option)] = true
			end
			refresh()
		end,
		Open = function()
			setOpen(true)
		end,
		Close = function()
			setOpen(false)
		end,
		Gui = row,
	}
end

function selects.colorpicker(win, title, default, callback)
	local mobile = win._mobile
	local hue, sat, val = 0.58, 0.68, 1
	if typeof(default) == "Color3" then
		hue, sat, val = Color3.toHSV(default)
	end

	local row = win._row(mobile and 40 or 34)
	local name = caption(row, title)
	name.Size = UDim2.new(1, -58, 1, 0)

	local swatch = util.new("Frame", {
		BackgroundColor3 = Color3.fromHSV(hue, sat, val),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(mobile and 30 or 26, mobile and 18 or 15),
		ZIndex = 3,
		Parent = row,
	})
	util.corner(swatch, 3)
	util.stroke(swatch, Color3.new(1, 1, 1), 0.7)

	local pad = 8
	local fieldH = mobile and 100 or 94
	local panelW = mobile and 240 or 226
	local bottomY = pad + fieldH + 29
	local panelH = bottomY + 36

	local panel = util.new("Frame", {
		Name = "colorpicker",
		Active = true,
		BackgroundColor3 = values().background,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(panelW, panelH),
		Visible = false,
		ZIndex = 2,
		Parent = env.modal,
	})
	local edge = util.stroke(panel, values().line, 0.2)
	util.shadow(panel, 16, 0.5)
	win._popover(panel)
	local pop = util.new("UIScale", { Parent = panel })

	local field = util.new("Frame", {
		BackgroundColor3 = Color3.fromHSV(hue, 1, 1),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(pad, pad),
		Size = UDim2.new(1, -pad * 2, 0, fieldH),
		ZIndex = 3,
		Parent = panel,
	})
	util.corner(field, 2)

	local light = util.new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
		Parent = field,
	})
	util.new("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1)),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = light,
	})
	util.corner(light, 2)

	local dark = util.new("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
		Parent = field,
	})
	util.new("UIGradient", {
		Color = ColorSequence.new(Color3.new(0, 0, 0)),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Rotation = 90,
		Parent = dark,
	})
	util.corner(dark, 2)

	local cursor = util.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(mobile and 15 or 13, mobile and 15 or 13),
		ZIndex = 6,
		Parent = field,
	})
	util.corner(cursor, 8)
	local ring = util.stroke(cursor, Color3.new(1, 1, 1), 0.15)
	ring.Thickness = 2

	local fieldHit = util.new("TextButton", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		ZIndex = 7,
		Parent = field,
	})

	local hueBar = util.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 0, 0),
		BorderSizePixel = 0,
		Position = UDim2.new(0, pad, 0, pad + fieldH + 8),
		Size = UDim2.new(1, -pad * 2, 0, 12),
		ZIndex = 3,
		Parent = panel,
	})
	util.corner(hueBar, 2)
	util.new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
			ColorSequenceKeypoint.new(1 / 6, Color3.fromRGB(255, 255, 0)),
			ColorSequenceKeypoint.new(2 / 6, Color3.fromRGB(0, 255, 0)),
			ColorSequenceKeypoint.new(3 / 6, Color3.fromRGB(0, 255, 255)),
			ColorSequenceKeypoint.new(4 / 6, Color3.fromRGB(0, 0, 255)),
			ColorSequenceKeypoint.new(5 / 6, Color3.fromRGB(255, 0, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
		}),
		Parent = hueBar,
	})

	local knob = util.new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(4, 18),
		ZIndex = 4,
		Parent = hueBar,
	})
	util.corner(knob, 2)

	local hueHit = util.new("TextButton", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Position = UDim2.new(0, pad, 0, pad + fieldH + 5),
		Size = UDim2.new(1, -pad * 2, 0, 19),
		Text = "",
		ZIndex = 5,
		Parent = panel,
	})

	local preview = util.new("Frame", {
		BackgroundColor3 = Color3.fromHSV(hue, sat, val),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(pad, bottomY),
		Size = UDim2.fromOffset(28, 28),
		ZIndex = 3,
		Parent = panel,
	})
	util.corner(preview, 3)
	util.stroke(preview, values().line, 0.2)

	local hex = util.new("TextBox", {
		BackgroundColor3 = values().raised,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Font = Enum.Font.Code,
		Position = UDim2.fromOffset(pad + 36, bottomY),
		Size = UDim2.new(1, -(pad * 2 + 36), 0, 28),
		Text = "#000000",
		TextColor3 = values().text,
		TextSize = util.size(11),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		Parent = panel,
	})
	util.corner(hex, 3)
	local hexEdge = util.stroke(hex, values().line, 0.2)
	util.new("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 6),
		Parent = hex,
	})

	local function color()
		return Color3.fromHSV(hue, sat, val)
	end

	local function refresh(fire)
		cursor.Position = UDim2.fromScale(sat, 1 - val)
		knob.Position = UDim2.new(hue, 0, 0.5, 0)
		field.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
		preview.BackgroundColor3 = color()
		swatch.BackgroundColor3 = color()
		if not hex:IsFocused() then
			hex.Text = "#" .. string.upper(color():ToHex())
		end
		if fire and callback then
			callback(color())
		end
	end

	local fieldDrag = false
	local hueDrag = false

	local function readField(x, y)
		sat = math.clamp((x - field.AbsolutePosition.X) / math.max(1, field.AbsoluteSize.X), 0, 1)
		val = 1 - math.clamp((y - field.AbsolutePosition.Y) / math.max(1, field.AbsoluteSize.Y), 0, 1)
		refresh(true)
	end

	local function readHue(x)
		hue = math.clamp((x - hueBar.AbsolutePosition.X) / math.max(1, hueBar.AbsoluteSize.X), 0, 1)
		refresh(true)
	end

	fieldHit.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			fieldDrag = true
			readField(input.Position.X, input.Position.Y)
		end
	end)
	hueHit.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			hueDrag = true
			readHue(input.Position.X)
		end
	end)

	win._link(env.uis.InputChanged, function(input)
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.MouseMovement and kind ~= Enum.UserInputType.Touch then
			return
		end
		if fieldDrag then
			readField(input.Position.X, input.Position.Y)
		elseif hueDrag then
			readHue(input.Position.X)
		end
	end)

	win._link(env.uis.InputEnded, function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			fieldDrag = false
			hueDrag = false
		end
	end)

	local function commitHex()
		local raw = string.gsub(hex.Text, "#", "")
		if #raw == 3 then
			raw = string.sub(raw, 1, 1) .. string.sub(raw, 1, 1) .. string.sub(raw, 2, 2) .. string.sub(raw, 2, 2) .. string.sub(raw, 3, 3) .. string.sub(raw, 3, 3)
		end
		if #raw == 6 and tonumber(raw, 16) then
			local picked = Color3.fromHex("#" .. raw)
			hue, sat, val = Color3.toHSV(picked)
			refresh(true)
		else
			refresh(false)
		end
	end

	hex.Focused:Connect(function()
		hexEdge.Color = values().accent
		hexEdge.Transparency = 0.2
	end)
	hex.FocusLost:Connect(function()
		hexEdge.Color = values().line
		hexEdge.Transparency = 0.2
		commitHex()
	end)

	local open = false
	local setOpen

	local function close()
		setOpen(false)
	end

	function setOpen(state)
		if state == open then
			return
		end
		open = state
		if open then
			modal.claim(close)
			local view = env.viewport()
			local pos, size = row.AbsolutePosition, row.AbsoluteSize
			local width = math.min(panelW, view.X - 12)
			local x = math.clamp(pos.X + size.X - width, 6, math.max(6, view.X - width - 6))
			local y = pos.Y + size.Y + 2
			if y + panelH > view.Y - 6 then
				y = pos.Y - panelH - 2
			end
			y = math.clamp(y, 6, math.max(6, view.Y - panelH - 6))
			panel.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
			panel.Visible = true
			pop.Scale = 0.96
			util.tween(pop, 0.14, { Scale = 1 }, Enum.EasingStyle.Back)
			refresh(false)
		else
			modal.drop(close)
			util.tween(pop, 0.1, { Scale = 0.96 })
			task.delay(0.11, function()
				if not open and panel.Parent then
					panel.Visible = false
				end
			end)
		end
	end

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
	hit.Activated:Connect(function()
		setOpen(not open)
	end)

	style.paint(function()
		panel.BackgroundColor3 = values().background
		edge.Color = values().line
		hex.BackgroundColor3 = values().raised
		hex.TextColor3 = values().text
		hexEdge.Color = values().line
		hit.BackgroundColor3 = values().hover
		refresh(false)
	end)

	refresh(false)
	win._fit(true)

	return {
		Set = function(_, value)
			if typeof(value) == "Color3" then
				hue, sat, val = Color3.toHSV(value)
				refresh(false)
			end
		end,
		Get = function()
			return color()
		end,
		Open = function()
			setOpen(true)
		end,
		Close = function()
			setOpen(false)
		end,
		Gui = row,
	}
end

S.selects = selects
