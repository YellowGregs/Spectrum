local S = ...

local env = S.env
local util = S.util
local style = S.style
local modal = S.modal
local icons = S.icons
local bold = Enum.Font.GothamBold
local font = Enum.Font.GothamMedium
local selects = {}
local GuiService = game:GetService("GuiService")

local function gui_inset()
	local ok, inset = pcall(function()
		return GuiService:GetGuiInset()
	end)
	return ok and inset or Vector2.new()
end

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

function selects.dropdown(win, title, options, default, callback, multi, icon)
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

	local initial = multi and {} or single
	if multi then
		for option in pairs(picks) do
			initial[#initial + 1] = option
		end
	end
	local row = win._row(mobile and 40 or 38)
	local name = caption(row, title)
	name.Size = UDim2.new(0.48, -20, 1, 0)
	name.TextSize = util.size(mobile and 11 or 12)
	local emblem
	if type(icon) == "string" and icon ~= "" then
		emblem = icons.image(row, icon, 14, values().muted)
		if emblem then
			emblem.AnchorPoint = Vector2.new(0, 0.5)
			emblem.Position = UDim2.new(0, 10, 0.5, 0)
			icons.layer(emblem, 4)
			name.Position = UDim2.fromOffset(28, 0)
			name.Size = UDim2.new(0.48, -38, 1, 0)
		end
	end

	local readout = util.new("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -29, 0.5, 0),
		Size = UDim2.new(0.4, 0, 1, 0),
		Font = font,
		Text = "None",
		TextColor3 = values().muted,
		TextSize = util.size(mobile and 10 or 11),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = row,
	})

	local chevron = util.chevron(row, mobile and 8 or 9, values().muted)
	chevron.AnchorPoint = Vector2.new(0.5, 0.5)
	chevron.Position = UDim2.new(1, -12, 0.5, 0)
	chevron.ZIndex = 3

	local count_badge
	if multi then
		count_badge = util.new("TextLabel", {
			Name = "count_badge",
			BackgroundColor3 = values().accent,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -24, 0.5, 0),
			Size = UDim2.fromOffset(mobile and 20 or 22, mobile and 16 or 18),
			Font = bold,
			Text = "0",
			TextColor3 = style.on(values().accent),
			TextSize = util.size(mobile and 9 or 10),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			Visible = false,
			ZIndex = 4,
			Parent = row,
		})
		util.corner(count_badge, 5)
	end

	local pad = mobile and 4 or 6
	local item_h = mobile and 34 or 32
	local bulk_h = (multi and #choices > 0) and (mobile and 28 or 30) or 0
	local bulk_gap = bulk_h > 0 and (mobile and 1 or 2) or 0
	local min_height = math.max(mobile and 32 or 42, pad * 2 + bulk_h + bulk_gap)
	local desired_height = math.clamp(#choices * item_h + pad * 2 + bulk_h + bulk_gap, mobile and 40 or 48, mobile and 226 or 260)
	local panel = util.new("Frame", {
		Name = "dropdown",
		Active = true,
		BackgroundColor3 = values().panel,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = UDim2.fromOffset(mobile and 200 or 240, 0),
		Visible = false,
		ZIndex = 10,
		Parent = env.modal,
	})
	util.corner(panel, 6)
	local edge = util.stroke(panel, values().line, 0.05)
	util.shadow(panel, 18, 0.4)
	win._popover(panel)

	local bulk_seam
	local select_all_action
	local clear_action
	local select_all_hit
	local clear_hit
	if bulk_h > 0 then
		local actions = util.new("Frame", {
			Name = "bulk_actions",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(pad, pad),
			Size = UDim2.new(1, -pad * 2, 0, bulk_h),
			ZIndex = 12,
			Parent = panel,
		})
		bulk_seam = util.new("Frame", {
			Name = "bulk_seam",
			BackgroundColor3 = values().line,
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 1, -1),
			Size = UDim2.new(1, 0, 0, 1),
			ZIndex = 13,
			Parent = actions,
		})
		local function action(name, text, width, offset)
			local btn = util.new("TextButton", {
				Name = name,
				BackgroundColor3 = values().hover,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, offset, 0.5, 0),
				Size = UDim2.fromOffset(width, bulk_h),
				Font = font,
				Text = text,
				TextColor3 = values().muted,
				TextSize = util.size(mobile and 9 or 10),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 13,
				Parent = actions,
			})
			util.corner(btn, 4)
			util.hover(btn)
			local hit
			if mobile then
				hit = util.new("TextButton", {
					Name = name .. "_hit",
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					AutoButtonColor = false,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, offset, 0.5, 0),
					Size = UDim2.fromOffset(width + 12, 36),
					Text = "",
					ZIndex = 12,
					Parent = actions,
				})
			end
			return btn, hit
		end
		clear_action, clear_hit = action("clear", "Clear", mobile and 42 or 48, 0)
		select_all_action, select_all_hit = action("select_all", "Select all", mobile and 58 or 64, -(mobile and 46 or 52))
	end

	local area = util.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(pad, pad + bulk_h + bulk_gap),
		Size = UDim2.new(1, -pad * 2, 1, -(pad * 2 + bulk_h + bulk_gap)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = mobile and 2 or 4,
		ScrollBarImageColor3 = values().muted,
		ScrollBarImageTransparency = 0.5,
		ZIndex = 11,
		Parent = panel,
	})
	util.new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = area,
	})

	local items = {}
	local checks = {}
	local marks = {}
	local mark_edges = {}
	local key

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
			local first_name
			for _, option in ipairs(choices) do
				if picks[option] then
					first_name = option
					break
				end
			end
			if picked == 0 then
				readout.Text = "None"
			elseif picked == 1 then
				readout.Text = first_name
			elseif picked == 2 then
				readout.Text = first_name .. " +1"
			else
				readout.Text = picked .. " selected"
			end
		else
			readout.Text = single or "None"
		end
		if multi then
			readout.TextColor3 = picked > 0 and values().accent or values().muted
		else
			readout.TextColor3 = single and values().text or values().muted
		end
		readout.Font = (multi and picked > 0 or single) and bold or font
		if count_badge then
			count_badge.Visible = picked > 0
			count_badge.Text = tostring(picked)
			local lane = picked > 0
			readout.Position = UDim2.new(1, lane and -48 or -29, 0.5, 0)
			readout.Size = UDim2.new(0.4, lane and -24 or 0, 1, 0)
		end
		if select_all_action then
			select_all_action.TextTransparency = picked < #choices and 0 or 0.55
			clear_action.TextTransparency = picked > 0 and 0 or 0.55
		end
		for option, item in pairs(items) do
			local on = multi and picks[option] or single == option
			item.TextColor3 = on and values().accent or values().text
			item.Font = on and bold or font
			if marks[option] then
				marks[option].BackgroundColor3 = on and values().accent or values().raised
				local mark_edge = mark_edges[option]
				if mark_edge then
					mark_edge.Color = on and values().accent or values().line
					mark_edge.Transparency = on and 1 or 0.25
				end
			end
			if checks[option] then
				checks[option].Visible = on
			end
		end
	end

	local function apply(value)
		if multi then
			picks = {}
			for _, option in ipairs(type(value) == "table" and value or {}) do
				picks[tostring(option)] = true
			end
		else
			single = value ~= nil and tostring(value) or nil
		end
		refresh()
	end

	if select_all_action then
		local function select_all()
			local changed = false
			for _, option in ipairs(choices) do
				if not picks[option] then
					picks[option] = true
					changed = true
				end
			end
			if not changed then
				return
			end
			refresh()
			local picked = current()
			win._store(key, picked)
			if callback then
				callback(picked)
			end
		end
		local function clear_all()
			local had = false
			for _, option in ipairs(choices) do
				if picks[option] then
					had = true
					break
				end
			end
			if not had then
				return
			end
			picks = {}
			refresh()
			win._store(key, {})
			if callback then
				callback(current())
			end
		end
		select_all_action.Activated:Connect(select_all)
		clear_action.Activated:Connect(clear_all)
		if select_all_hit then
			select_all_hit.Activated:Connect(select_all)
		end
		if clear_hit then
			clear_hit.Activated:Connect(clear_all)
		end
	end

	local open = false
	local set_open

	local function close()
		set_open(false)
	end

	function set_open(state)
		if state == open then
			return
		end
		open = state
		if open then
			modal.claim(close)
			local view = env.viewport()
			local pos, size = row.AbsolutePosition, row.AbsoluteSize
			local parent = panel.Parent
			local parent_pos = parent and parent.AbsolutePosition or Vector2.new()
			local win_anchor = win.Gui.AbsolutePosition
			local win_pos = win_anchor - parent_pos
			local win_size = win.Gui.AbsoluteSize
			local win_w = win_size.X > 20 and win_size.X or math.min(300, view.X)
			local win_h = win_size.Y > 20 and win_size.Y or view.Y
			local rel_x = pos.X - win_anchor.X
			local rel_y = pos.Y - win_anchor.Y
			local max_width = math.max(160, (mobile and win_w or view.X) - 16)
			local min_width = math.min(mobile and 180 or 240, max_width)
			local width = math.clamp(math.max(size.X + 8, min_width), min_width, max_width)
			local x
			if mobile then
				x = math.clamp(rel_x - 4, 6, math.max(6, win_w - width - 6))
			else
				x = math.clamp(pos.X, 8, math.max(8, view.X - width - 8)) - win_anchor.X
			end
			local top_limit = (win._head or 34) + 4
			local below = rel_y + size.Y + 4
			local available_below = win_h - below - 6
			local available_above = rel_y - top_limit - 4
			local height
			local y
			local use_below = available_below >= 44 and (available_below >= desired_height or available_below >= available_above)
			if use_below then
				height = math.clamp(desired_height, min_height, math.max(min_height, available_below))
				y = below
			else
				height = math.clamp(desired_height, min_height, math.max(min_height, available_above))
				y = rel_y - height - 4
			end
			height = math.floor(height)
			y = math.clamp(y, top_limit, math.max(top_limit, win_h - height - 6))
			panel.Position = UDim2.fromOffset(math.floor(win_pos.X + x), math.floor(win_pos.Y + y))
			panel.Size = UDim2.fromOffset(math.floor(width), 0)
			panel.Visible = true
			util.tween(panel, 0.13, { Size = UDim2.fromOffset(math.floor(width), math.floor(height)) })
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
			Size = UDim2.new(1, 0, 0, item_h),
			Font = font,
			Text = option,
			TextColor3 = values().text,
			TextSize = util.size(mobile and 11 or 12),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 12,
			Parent = area,
		})
		local mark_size = 16
		util.new("UIPadding", {
			PaddingLeft = UDim.new(0, multi and (mark_size + 20) or 12),
			PaddingRight = UDim.new(0, multi and 12 or 26),
			Parent = item,
		})
		util.hover(item)
		local check
		if multi then
			local mark = util.new("Frame", {
				Name = "mark",
				BackgroundColor3 = values().raised,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, -(mark_size + 10), 0.5, 0),
				Size = UDim2.fromOffset(mark_size, mark_size),
				ZIndex = 13,
				Parent = item,
			})
			util.corner(mark, 4)
			mark_edges[option] = util.stroke(mark, values().line, 0.25)
			check = icons.check(mark, mark_size - 5, style.on(values().accent))
			check.AnchorPoint = Vector2.new(0.5, 0.5)
			check.Position = UDim2.fromScale(0.5, 0.5)
			icons.layer(check, 4)
			marks[option] = mark
		else
			check = icons.check(item, 10, values().accent)
			check.AnchorPoint = Vector2.new(1, 0.5)
			check.Position = UDim2.new(1, -10, 0.5, 0)
			icons.layer(check, 4)
		end
		check.Visible = false
		checks[option] = check
		items[option] = item

		item.Activated:Connect(function()
			if multi then
				if picks[option] then
					picks[option] = nil
				else
					picks[option] = true
				end
				refresh()
				local picked = current()
				win._store(key, picked)
				if callback then
					callback(picked)
				end
			else
				single = option
				refresh()
				set_open(false)
				win._store(key, single)
				if callback then
					callback(option)
				end
			end
		end)
	end

	if #choices == 0 then
		local empty = util.new("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, item_h),
			Font = font,
			Text = "No options",
			TextColor3 = values().muted,
			TextSize = util.size(10),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 12,
			Parent = area,
		})
		util.new("UIPadding", { PaddingLeft = UDim.new(0, 12), Parent = empty })
	end

	key = win._bind(multi and "multi" or "dropdown", title, {
		set = apply,
	})

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
		set_open(not open)
	end)

	style.paint(function()
		panel.BackgroundColor3 = values().panel
		edge.Color = values().line
		area.ScrollBarImageColor3 = values().muted
		hit.BackgroundColor3 = values().hover
		if bulk_seam then
			bulk_seam.BackgroundColor3 = values().line
		end
		if count_badge then
			count_badge.BackgroundColor3 = values().accent
			count_badge.TextColor3 = style.on(values().accent)
		end
		if select_all_action then
			select_all_action.BackgroundColor3 = values().hover
			select_all_action.TextColor3 = values().muted
			clear_action.BackgroundColor3 = values().hover
			clear_action.TextColor3 = values().muted
		end
		if emblem then
			icons.tint(emblem, values().muted)
		end
		for option, item in pairs(items) do
			item.BackgroundColor3 = values().hover
			if marks[option] then
				local on = picks[option] == true
				marks[option].BackgroundColor3 = on and values().accent or values().raised
				local mark_edge = mark_edges[option]
				if mark_edge then
					mark_edge.Color = on and values().accent or values().line
					mark_edge.Transparency = on and 1 or 0.25
				end
			end
			if checks[option] then
				icons.tint(checks[option], marks[option] and style.on(values().accent) or values().accent)
			end
		end
		refresh()
	end)

	refresh()
	win._options(row, title, function()
		return {
			{ label = "Reset to default", icon = "arrow", run = function()
				apply(initial)
				win._store(key, current())
				if callback then
					callback(current())
				end
			end },
			{ label = "Clear selection", icon = "close", run = function()
				apply(multi and {} or nil)
				win._store(key, current())
				if callback then
					callback(current())
				end
			end },
		}
	end)
	win._fit(true)

	return {
		Set = function(_, value)
			apply(value)
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
			set_open(true)
		end,
		Close = function()
			set_open(false)
		end,
		Gui = row,
	}
end

function selects.colorpicker(win, title, default, callback, icon)
	local mobile = win._mobile
	local hue, sat, val = 0.58, 0.68, 1
	if typeof(default) == "Color3" then
		hue, sat, val = Color3.toHSV(default)
	end

	local initial = Color3.fromHSV(hue, sat, val)
	local row = win._row(mobile and 40 or 34)
	local name = caption(row, title)
	name.Size = UDim2.new(1, -58, 1, 0)
	local emblem
	if type(icon) == "string" and icon ~= "" then
		emblem = icons.image(row, icon, 14, values().muted)
		if emblem then
			emblem.AnchorPoint = Vector2.new(0, 0.5)
			emblem.Position = UDim2.new(0, 10, 0.5, 0)
			icons.layer(emblem, 4)
			name.Position = UDim2.fromOffset(28, 0)
			name.Size = UDim2.new(1, -76, 1, 0)
		end
	end

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
	local field_h = mobile and 100 or 94
	local panel_w = mobile and 240 or 226
	local bottom_y = pad + field_h + 29
	local panel_h = bottom_y + 36

	local panel = util.new("Frame", {
		Name = "colorpicker",
		Active = true,
		BackgroundColor3 = values().panel,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(panel_w, panel_h),
		Visible = false,
		ZIndex = 10,
		Parent = env.modal,
	})
	util.corner(panel, 6)
	local edge = util.stroke(panel, values().line, 0.05)
	util.shadow(panel, 18, 0.4)
	win._popover(panel)
	local pop = util.new("UIScale", { Parent = panel })

	local field = util.new("Frame", {
		BackgroundColor3 = Color3.fromHSV(hue, 1, 1),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(pad, pad),
		Size = UDim2.new(1, -pad * 2, 0, field_h),
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

	local field_hit = util.new("TextButton", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		ZIndex = 7,
		Parent = field,
	})

	local hue_bar = util.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 0, 0),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.new(0, pad, 0, pad + field_h + 8),
		Size = UDim2.new(1, -pad * 2, 0, 12),
		ZIndex = 3,
		Parent = panel,
	})
	util.corner(hue_bar, 2)
	for index = 0, 47 do
		util.new("Frame", {
			BackgroundColor3 = Color3.fromHSV(index / 48, 1, 1),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(index / 48, 0),
			Size = UDim2.new(1 / 48 + 0.004, 0, 1, 0),
			ZIndex = 3,
			Parent = hue_bar,
		})
	end

	local knob = util.new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(4, 18),
		ZIndex = 4,
		Parent = hue_bar,
	})
	util.corner(knob, 2)

	local hue_hit = util.new("TextButton", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Position = UDim2.new(0, pad, 0, pad + field_h + 5),
		Size = UDim2.new(1, -pad * 2, 0, 19),
		Text = "",
		ZIndex = 5,
		Parent = panel,
	})

	local preview = util.new("Frame", {
		BackgroundColor3 = Color3.fromHSV(hue, sat, val),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(pad, bottom_y),
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
		Position = UDim2.fromOffset(pad + 36, bottom_y),
		Size = UDim2.new(1, -(pad * 2 + 36), 0, 28),
		Text = "#000000",
		TextColor3 = values().text,
		TextSize = util.size(11),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		Parent = panel,
	})
	util.corner(hex, 3)
	local hex_edge = util.stroke(hex, values().line, 0.2)
	util.new("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 6),
		Parent = hex,
	})

	local function color()
		return Color3.fromHSV(hue, sat, val)
	end

	local key
	local function refresh(fire)
		cursor.Position = UDim2.fromScale(sat, 1 - val)
		knob.Position = UDim2.new(hue, 0, 0.5, 0)
		field.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
		preview.BackgroundColor3 = color()
		swatch.BackgroundColor3 = color()
		if not hex:IsFocused() then
			hex.Text = "#" .. string.upper(color():ToHex())
		end
		if fire then
			win._store(key, "#" .. string.upper(color():ToHex()))
			if callback then
				callback(color())
			end
		end
	end

	local function apply(value)
		local picked
		if typeof(value) == "Color3" then
			picked = value
		elseif type(value) == "string" then
			local raw = string.gsub(tostring(value), "#", "")
			if #raw == 3 then
				raw = string.sub(raw, 1, 1) .. string.sub(raw, 1, 1)
					.. string.sub(raw, 2, 2) .. string.sub(raw, 2, 2)
					.. string.sub(raw, 3, 3) .. string.sub(raw, 3, 3)
			end
			if #raw == 6 and tonumber(raw, 16) then
				picked = Color3.fromHex("#" .. raw)
			end
		end
		if picked then
			hue, sat, val = Color3.toHSV(picked)
			refresh(false)
		end
	end

	local field_drag = false
	local hue_drag = false

	local function read_field(x, y)
		sat = math.clamp((x - field.AbsolutePosition.X) / math.max(1, field.AbsoluteSize.X), 0, 1)
		val = 1 - math.clamp((y - field.AbsolutePosition.Y) / math.max(1, field.AbsoluteSize.Y), 0, 1)
		refresh(true)
	end

	local function read_hue(x)
		hue = math.clamp((x - hue_bar.AbsolutePosition.X) / math.max(1, hue_bar.AbsoluteSize.X), 0, 1)
		refresh(true)
	end

	field_hit.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			field_drag = true
			read_field(input.Position.X, input.Position.Y)
		end
	end)
	hue_hit.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			hue_drag = true
			read_hue(input.Position.X)
		end
	end)

	win._link(env.uis.InputChanged, function(input)
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.MouseMovement and kind ~= Enum.UserInputType.Touch then
			return
		end
		if field_drag then
			read_field(input.Position.X, input.Position.Y)
		elseif hue_drag then
			read_hue(input.Position.X)
		end
	end)

	win._link(env.uis.InputEnded, function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			field_drag = false
			hue_drag = false
		end
	end)

	local function commit_hex()
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
		hex_edge.Color = values().accent
		hex_edge.Transparency = 0.2
	end)
	hex.FocusLost:Connect(function()
		hex_edge.Color = values().line
		hex_edge.Transparency = 0.2
		commit_hex()
	end)

	local open = false
	local set_open

	local function close()
		set_open(false)
	end

	function set_open(state)
		if state == open then
			return
		end
		open = state
		if open then
			modal.claim(close)
			local view = env.viewport()
			local pos, size = row.AbsolutePosition, row.AbsoluteSize
			local parent_pos = panel.Parent and panel.Parent.AbsolutePosition or Vector2.new()
			local width = math.min(panel_w, view.X - 12)
			local x = math.clamp(pos.X + size.X - width, 6, math.max(6, view.X - width - 6))
			local y = pos.Y + size.Y + 2
			if y + panel_h > view.Y - 6 then
				y = pos.Y - panel_h - 2
			end
			y = math.clamp(y, 6, math.max(6, view.Y - panel_h - 6))
			panel.Position = UDim2.fromOffset(math.floor(x - parent_pos.X), math.floor(y - parent_pos.Y))
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
		set_open(not open)
	end)

	style.paint(function()
		panel.BackgroundColor3 = values().panel
		edge.Color = values().line
		hex.BackgroundColor3 = values().raised
		hex.TextColor3 = values().text
		hex_edge.Color = values().line
		hit.BackgroundColor3 = values().hover
		if emblem then
			icons.tint(emblem, values().muted)
		end
		refresh(false)
	end)

	refresh(false)
	key = win._bind("color", title, {
		set = apply,
	})
	win._options(row, title, function()
		return {
			{ label = "Open color picker", icon = "palette", accent = true, run = function() set_open(true) end },
			{ label = "Reset color", icon = "arrow", run = function()
				apply(initial)
				win._store(key, "#" .. string.upper(color():ToHex()))
				if callback then
					callback(color())
				end
			end },
		}
	end)
	win._fit(true)

	return {
		Set = function(_, value)
			apply(value)
		end,
		Get = function()
			return color()
		end,
		Open = function()
			set_open(true)
		end,
		Close = function()
			set_open(false)
		end,
		Gui = row,
	}
end

S.selects = selects
