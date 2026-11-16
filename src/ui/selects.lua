local S = ...

local env = S.env
local util = S.util
local style = S.style
local modal = S.modal
local icons = S.icons
local tooltip = S.tooltip
local bold = Enum.Font.GothamBold
local font = Enum.Font.RobotoCondensed
local mono = Enum.Font.RobotoMono
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
		Text = string.upper(tostring(title or "")),
		TextColor3 = values().text,
		TextSize = util.size(10),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = parent,
	})
end

function selects.dropdown(win, title, options, default, callback, multi, icon, opts)
	if type(icon) == "table" and opts == nil then
		opts = icon
		icon = opts.icon
	end
	opts = type(opts) == "table" and opts or {}
	local mobile = win._mobile
	local choices = {}
	for _, option in ipairs(options or {}) do
		choices[#choices + 1] = tostring(option)
	end
	local disabled = opts.disabled == true
	local placeholder = tostring(opts.placeholder or "None")
	local searchable = opts.searchable
	if searchable == nil then
		searchable = #choices >= 10
	end
	local disabled_options = {}
	for key, value in pairs(opts.disabledOptions or {}) do
		if value == true then
			disabled_options[tostring(key)] = true
		elseif type(key) == "number" then
			disabled_options[tostring(value)] = true
		end
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
	local well = util.new("Frame", {
		Name = "field",
		BackgroundColor3 = values().raised,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(4, 3),
		Size = UDim2.new(1, -8, 1, -6),
		ZIndex = 2,
		Parent = row,
	})
	util.corner(well, 0)
	util.depth(well, 0.35)
	util.shadow(well, 6, 0.9)
	util.stroke(well, values().line, 0.55)
	local name = caption(row, title)
	name.Size = UDim2.new(0.48, -20, 1, 0)
	name.TextSize = util.size(10)
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
		Font = mono,
		Text = placeholder,
		TextColor3 = values().muted,
		TextSize = util.size(9),
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
			Font = mono,
			Text = "0",
			TextColor3 = style.on(values().accent),
			TextSize = util.size(9),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			Visible = false,
			ZIndex = 4,
			Parent = row,
		})
		util.corner(count_badge, 0)
		util.depth(count_badge, 0.35)
	end

	local pad = mobile and 4 or 6
	local item_h = mobile and 34 or 32
	local bulk_h = (multi and #choices > 0) and (mobile and 28 or 30) or 0
	local bulk_gap = bulk_h > 0 and (mobile and 1 or 2) or 0
	local search_h = searchable and (mobile and 30 or 26) or 0
	local search_gap = searchable and 4 or 0
	local chrome_h = bulk_h + bulk_gap + search_h + search_gap
	local min_height = math.max(mobile and 32 or 42, pad * 2 + chrome_h)
	local desired_height = math.clamp(#choices * item_h + pad * 2 + chrome_h, mobile and 40 or 48, mobile and 226 or 260)
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
	util.corner(panel, 0)
	util.depth(panel, 0.4)
	local edge = util.stroke(panel, values().line, 0.05)
	util.shadow(panel, 24, 0.28)
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
				Text = string.upper(text),
				TextColor3 = values().muted,
				TextSize = util.size(mobile and 9 or 10),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 13,
				Parent = actions,
			})
			util.corner(btn, 0)
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

	local search
	local search_icon
	local search_clear
	if searchable then
		search = util.new("TextBox", {
			Name = "dropdown_search",
			BackgroundColor3 = values().raised,
			BorderSizePixel = 0,
			ClearTextOnFocus = false,
			Font = mono,
			PlaceholderColor3 = values().muted,
			PlaceholderText = "SEARCH",
			Position = UDim2.fromOffset(pad, pad + bulk_h + bulk_gap),
			Size = UDim2.new(1, -pad * 2, 0, search_h),
			Text = "",
			TextColor3 = values().text,
			TextSize = util.size(10),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 13,
			Parent = panel,
		})
		util.corner(search, 0)
		util.inset(search, 0.3)
		util.new("UIPadding", {
			PaddingLeft = UDim.new(0, 24),
			PaddingRight = UDim.new(0, 22),
			Parent = search,
		})
		search_icon = icons.image(search, "search", 12, values().muted)
		if search_icon then
			search_icon.AnchorPoint = Vector2.new(0, 0.5)
			search_icon.Position = UDim2.new(0, -17, 0.5, 0)
			icons.layer(search_icon, 14)
		end
		search_clear = util.new("TextButton", {
			Name = "clear",
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 17, 0.5, 0),
			Size = UDim2.fromOffset(18, 18),
			Text = "",
			ZIndex = 14,
			Parent = search,
		})
		local clear_icon = icons.close(search_clear, 8, values().muted)
		if clear_icon then
			clear_icon.AnchorPoint = Vector2.new(0.5, 0.5)
			clear_icon.Position = UDim2.fromScale(0.5, 0.5)
			icons.layer(clear_icon, 15)
		end
		search_clear.Activated:Connect(function()
			if not disabled then
				search.Text = ""
			end
		end)
	end

	local area = util.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(pad, pad + chrome_h),
		Size = UDim2.new(1, -pad * 2, 1, -(pad * 2 + chrome_h)),
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
	local open = false
	local set_open
	local active_option
	local no_results

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

	local function visible_options()
		local out = {}
		for _, option in ipairs(choices) do
			if not search or search.Text == "" or string.find(string.lower(option), string.lower(search.Text), 1, true) then
				out[#out + 1] = option
			end
		end
		return out
	end

	local function option_available(option)
		return disabled_options[option] ~= true
	end

	local function paint_active()
		for option, item in pairs(items) do
			local selected = (multi and picks[option]) or (not multi and single == option)
			item.BackgroundTransparency = option == active_option and 0 or (selected and 0.72 or 1)
		end
	end

	local function scroll_active()
		if not active_option then
			return
		end
		local list = visible_options()
		local index
		for position, option in ipairs(list) do
			if option == active_option then
				index = position
				break
			end
		end
		if not index then
			return
		end
		local top = (index - 1) * item_h
		local view = area.AbsoluteSize.Y
		local canvas = area.CanvasPosition.Y
		if top < canvas then
			area.CanvasPosition = Vector2.new(0, top)
		elseif top + item_h > canvas + view then
			area.CanvasPosition = Vector2.new(0, math.max(0, top + item_h - view))
		end
	end

	local function reset_active()
		local list = visible_options()
		active_option = nil
		for _, option in ipairs(list) do
			if option_available(option) and ((multi and picks[option]) or (not multi and single == option)) then
				active_option = option
				break
			end
		end
		if not active_option then
			for _, option in ipairs(list) do
				if option_available(option) then
					active_option = option
					break
				end
			end
		end
		paint_active()
		scroll_active()
	end

	local function move_active(delta)
		local list = visible_options()
		if #list == 0 then
			active_option = nil
			paint_active()
			return
		end
		local index = 1
		for position, option in ipairs(list) do
			if option == active_option then
				index = position
				break
			end
		end
		for _ = 1, #list do
			index = index + delta
			if index > #list then
				index = 1
			elseif index < 1 then
				index = #list
			end
			local option = list[index]
			if option_available(option) then
				active_option = option
				paint_active()
				scroll_active()
				return
			end
		end
	end

	local function apply_filter()
		if search and search_clear then
			search_clear.Visible = search.Text ~= ""
		end
		for option, item in pairs(items) do
			local show = not search or search.Text == "" or string.find(string.lower(option), string.lower(search.Text), 1, true) ~= nil
			item.Visible = show
			item.Size = UDim2.new(1, 0, 0, show and item_h or 0)
		end
		if no_results then
			local empty = #visible_options() == 0
			no_results.Visible = empty
			no_results.Size = UDim2.new(1, 0, 0, empty and item_h or 0)
		end
		reset_active()
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
				readout.Text = string.upper(placeholder)
			elseif picked == 1 then
				readout.Text = string.upper(first_name)
			elseif picked == 2 then
				readout.Text = string.upper(first_name) .. " +1"
			else
				readout.Text = tostring(picked) .. " SELECTED"
			end
		else
			readout.Text = string.upper(single or placeholder)
		end
		if disabled then
			readout.TextColor3 = values().muted
		elseif multi then
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
			local option_disabled = disabled_options[option] == true
			item.TextColor3 = option_disabled and values().muted or (on and values().accent or values().text)
			item.Font = (on and not option_disabled) and bold or font
			item.BackgroundColor3 = on and values().hover:Lerp(values().accent, 0.12) or values().hover
			item.BackgroundTransparency = on and 0.72 or 1
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
		if active_option and items[active_option] then
			items[active_option].BackgroundTransparency = 0
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

	local function choose(option)
		if disabled or disabled_options[option] then
			return
		end
		active_option = option
		paint_active()
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
	end

	if select_all_action then
		local function select_all()
			if disabled then
				return
			end
			local changed = false
			for _, option in ipairs(choices) do
				if not disabled_options[option] and not picks[option] then
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
			if disabled then
				return
			end
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

	local function close()
		set_open(false)
	end

	function set_open(state)
		if state and disabled then
			return
		end
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
			local row_top = pos.Y - parent_pos.Y
			local row_left = pos.X - parent_pos.X
			local row_bottom = row_top + size.Y
			local head_limit = math.max(6, win_pos.Y + (win._head or 34) + 4)
			local limit_bottom = math.max(head_limit, view.Y - 6)
			local max_width = math.max(160, view.X - 16)
			local min_width = math.min(mobile and 180 or 240, max_width)
			local width = math.clamp(math.max(size.X + 8, min_width), min_width, max_width)
			local x = math.clamp(mobile and (row_left - 4) or row_left, 8, math.max(8, view.X - width - 8))
			local room_below = math.max(0, limit_bottom - row_bottom - 4)
			local room_above = math.max(0, row_top - 4 - head_limit)
			local room = math.max(room_below, room_above)
			local min_visible = math.min(desired_height, math.max(min_height, math.floor(view.Y * 0.5)))
			local height = math.min(desired_height, math.max(room, min_visible))
			height = math.floor(height)
			local y
			if room_below >= room_above then
				y = row_bottom + 4
			else
				y = row_top - height - 4
			end
			y = math.clamp(y, 6, math.max(6, view.Y - height - 6))
			panel.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
			panel.Size = UDim2.fromOffset(math.floor(width), 0)
			panel.Visible = true
			util.tween(panel, 0.13, { Size = UDim2.fromOffset(math.floor(width), math.floor(height)) })
			util.tween(chevron, 0.15, { Rotation = 180 })
			if search then
				search.Text = ""
				apply_filter()
				if not mobile then
					task.defer(function()
						if open then
							search:CaptureFocus()
						end
					end)
				end
			end
			reset_active()
		else
			if search and search:IsFocused() then
				search:ReleaseFocus()
			end
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
			Text = string.upper(option),
			TextColor3 = values().text,
			TextSize = util.size(10),
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
		item.MouseEnter:Connect(function()
			if not disabled then
				item.BackgroundTransparency = 0
			end
		end)
		item.MouseLeave:Connect(refresh)
		item.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch and not disabled then
				item.BackgroundTransparency = 0
			end
		end)
		item.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				refresh()
			end
		end)
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
			util.corner(mark, 0)
			util.depth(mark, 0.3)
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
			choose(option)
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

	if search then
		no_results = util.new("TextLabel", {
			BackgroundTransparency = 1,
			LayoutOrder = #choices + 1,
			Size = UDim2.new(1, 0, 0, 0),
			Font = font,
			Text = "No matches",
			TextColor3 = values().muted,
			TextSize = util.size(10),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 12,
			Visible = false,
			Parent = area,
		})
		util.new("UIPadding", { PaddingLeft = UDim.new(0, 12), Parent = no_results })
		search:GetPropertyChangedSignal("Text"):Connect(apply_filter)
	end

	key = win._bind(multi and "multi" or "dropdown", title, {
		set = apply,
		apply = function(value)
			apply(value)
			if callback then
				local picked = current()
				task.defer(function()
					callback(picked)
				end)
			end
		end,
	})

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
	hit.Activated:Connect(function()
		if disabled then
			return
		end
		set_open(not open)
	end)

	local function set_disabled(value)
		disabled = value == true
		hit.Active = not disabled
		if disabled then
			set_open(false)
		end
		name.TextColor3 = disabled and values().muted or values().text
		if emblem then
			icons.tint(emblem, disabled and values().line or values().muted)
		end
		refresh()
		if win._nav_refresh then
			win._nav_refresh()
		end
	end

	win._link(env.uis.InputBegan, function(input)
		if not open or disabled then
			return
		end
		local kind = input.UserInputType
		local code = input.KeyCode
		if kind == Enum.UserInputType.Keyboard then
			if code == Enum.KeyCode.Down then
				move_active(1)
			elseif code == Enum.KeyCode.Up then
				move_active(-1)
			elseif code == Enum.KeyCode.Home then
				local list = visible_options()
				active_option = nil
				for _, option in ipairs(list) do
					if option_available(option) then
						active_option = option
						break
					end
				end
				paint_active()
				scroll_active()
			elseif code == Enum.KeyCode.End then
				local list = visible_options()
				active_option = nil
				for index = #list, 1, -1 do
					if option_available(list[index]) then
						active_option = list[index]
						break
					end
				end
				paint_active()
				scroll_active()
			elseif code == Enum.KeyCode.Return or code == Enum.KeyCode.KeypadEnter then
				if active_option then
					choose(active_option)
				end
			elseif code == Enum.KeyCode.Escape then
				set_open(false)
			end
		elseif string.match(kind.Name, "^Gamepad") then
			if code == Enum.KeyCode.DPadDown then
				move_active(1)
			elseif code == Enum.KeyCode.DPadUp then
				move_active(-1)
			elseif code == Enum.KeyCode.ButtonA then
				if active_option then
					choose(active_option)
				end
			elseif code == Enum.KeyCode.ButtonB then
				set_open(false)
			end
		end
	end)

	local stick_latched = false
	local stick_next = 0
	win._link(env.uis.InputChanged, function(input)
		if not open or disabled or not string.match(input.UserInputType.Name, "^Gamepad") then
			stick_latched = false
			return
		end
		local y = input.Position.Y
		local direction = y > 0.55 and -1 or (y < -0.55 and 1 or 0)
		if direction == 0 then
			stick_latched = false
			return
		end
		local now = os.clock()
		if stick_latched and now < stick_next then
			return
		end
		move_active(direction)
		stick_latched = true
		stick_next = now + 0.18
	end)

	style.paint(function()
		panel.BackgroundColor3 = values().panel
		edge.Color = values().line
		area.ScrollBarImageColor3 = values().muted
		hit.BackgroundColor3 = values().hover
		name.TextColor3 = disabled and values().muted or values().text
		if search then
			search.BackgroundColor3 = values().raised
			search.TextColor3 = values().text
			search.PlaceholderColor3 = values().muted
			if search_icon then
				icons.tint(search_icon, values().muted)
			end
			if search_clear then
				for _, child in ipairs(search_clear:GetDescendants()) do
					if child:IsA("Frame") then
						child.BackgroundColor3 = values().muted
					end
				end
			end
		end
		well.BackgroundColor3 = values().raised
		if emblem then
			icons.tint(emblem, disabled and values().line or values().muted)
		end
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
				if disabled then
					return
				end
				apply(initial)
				win._store(key, current())
				if callback then
					callback(current())
				end
			end },
			{ label = "Clear selection", icon = "close", run = function()
				if disabled then
					return
				end
				apply(multi and {} or nil)
				win._store(key, current())
				if callback then
					callback(current())
				end
			end },
		}
	end)
	win._nav_register(row, {
		kind = "dropdown",
		label = title,
		is_enabled = function()
			return not disabled
		end,
		activate = function()
			set_open(true)
		end,
	})
	if tooltip and opts.tooltip then
		tooltip.attach(row, opts.tooltip)
	end
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
			if not disabled then
				set_open(true)
			end
		end,
		Close = function()
			set_open(false)
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

function selects.colorpicker(win, title, default, callback, icon, opts)
	if type(icon) == "table" and opts == nil then
		opts = icon
		icon = opts.icon
	end
	opts = type(opts) == "table" and opts or {}
	local disabled = opts.disabled == true
	local mobile = win._mobile
	local hue, sat, val = 0.58, 0.68, 1
	if typeof(default) == "Color3" then
		hue, sat, val = Color3.toHSV(default)
	end

	local initial = Color3.fromHSV(hue, sat, val)
	local function parse_color(value)
		if typeof(value) == "Color3" then
			return value
		end
		if type(value) == "string" then
			local raw = string.gsub(value, "#", "")
			if #raw == 3 then
				raw = string.sub(raw, 1, 1) .. string.sub(raw, 1, 1)
					.. string.sub(raw, 2, 2) .. string.sub(raw, 2, 2)
					.. string.sub(raw, 3, 3) .. string.sub(raw, 3, 3)
			end
			if #raw == 6 and tonumber(raw, 16) then
				return Color3.fromHex("#" .. raw)
			end
		end
	end

	local presets = {}
	for _, entry in ipairs(type(opts.presets) == "table" and opts.presets or {}) do
		local picked = parse_color(entry)
		if picked and #presets < 10 then
			presets[#presets + 1] = picked
		end
	end
	local recent_enabled = opts.recent == true
	local recent_list = {}
	local recent_slots = {}
	local preset_rows = (#presets > 0 and 1 or 0) + (recent_enabled and 1 or 0)

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
	util.corner(swatch, 0)
	util.stroke(swatch, Color3.new(1, 1, 1), 0.7)

	local pad = 8
	local field_h = mobile and 100 or 94
	local panel_w = mobile and 240 or 226
	local bottom_y = pad + field_h + 29
	local rgb_h = 24
	local rgb_y = bottom_y + 34
	local swatch_size = mobile and 18 or 16
	local swatch_step = swatch_size + 6
	local swatch_y = rgb_y + rgb_h + 8
	local panel_h = swatch_y + preset_rows * 24 + 4

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
	util.corner(panel, 0)
	util.depth(panel, 0.4)
	local edge = util.stroke(panel, values().line, 0.05)
	util.shadow(panel, 24, 0.28)
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
	util.corner(field, 0)
	util.inset(field, 0.25)
	util.stroke(field, values().line, 0.45)

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
	util.corner(light, 0)

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
	util.corner(dark, 0)

	local cursor = util.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(mobile and 15 or 13, mobile and 15 or 13),
		ZIndex = 6,
		Parent = field,
	})
	util.corner(cursor, 0)
	local ring = util.stroke(cursor, Color3.new(1, 1, 1), 0.15)
	ring.Thickness = 2

	local field_hit = util.new("TextButton", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = not disabled,
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
	util.corner(hue_bar, 0)
	local hue_stops = {}
	for index = 0, 12 do
		hue_stops[#hue_stops + 1] = ColorSequenceKeypoint.new(index / 12, Color3.fromHSV(index / 12, 1, 1))
	end
	util.new("UIGradient", {
		Color = ColorSequence.new(hue_stops),
		Parent = hue_bar,
	})
	util.stroke(hue_bar, values().line, 0.55)

	local knob = util.new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(4, 18),
		ZIndex = 4,
		Parent = hue_bar,
	})
	util.corner(knob, 0)

	local hue_hit = util.new("TextButton", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = not disabled,
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
	util.corner(preview, 0)
	util.depth(preview, 0.4)
	util.stroke(preview, values().line, 0.2)
	util.shadow(preview, 6, 0.8)

	local hex = util.new("TextBox", {
		BackgroundColor3 = values().raised,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		TextEditable = not disabled,
		Font = Enum.Font.Code,
		Position = UDim2.fromOffset(pad + 36, bottom_y),
		Size = UDim2.new(1, -(pad * 2 + 36 + 2 * 28 + 8), 0, 28),
		Text = "#000000",
		TextColor3 = values().text,
		TextSize = util.size(11),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		Parent = panel,
	})
	util.corner(hex, 0)
	util.inset(hex, 0.3)
	local hex_edge = util.stroke(hex, values().line, 0.2)
	util.new("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 6),
		Parent = hex,
	})

	local function small_action(name, icon_name, x, tip)
		local btn = util.new("TextButton", {
			Name = name,
			BackgroundColor3 = values().raised,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Active = not disabled,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, x, 0, bottom_y),
			Size = UDim2.fromOffset(28, 28),
			Text = "",
			ZIndex = 3,
			Parent = panel,
		})
		util.corner(btn, 0)
		util.depth(btn, 0.3)
		local stroke = util.stroke(btn, values().line, 0.3)
		local image = icons.image(btn, icon_name, 13, values().muted)
		if image then
			image.AnchorPoint = Vector2.new(0.5, 0.5)
			image.Position = UDim2.fromScale(0.5, 0.5)
			icons.layer(image, 4)
		end
		btn.MouseEnter:Connect(function()
			if btn.Active then
				util.tween(btn, 0.08, { BackgroundColor3 = values().hover })
			end
		end)
		btn.MouseLeave:Connect(function()
			util.tween(btn, 0.08, { BackgroundColor3 = values().raised })
		end)
		if tooltip and tip then
			tooltip.attach(btn, tip)
		end
		return btn, stroke, image
	end

	local copy_btn, copy_edge, copy_icon = small_action("copy_hex", "copy", -(pad + 28 + 4), "Copy the hex value")
	local random_btn, random_edge, random_icon = small_action("random_color", "refresh", -pad, "Pick a random color")

	local rgb_label = util.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(pad, rgb_y),
		Size = UDim2.fromOffset(30, rgb_h),
		Font = mono,
		Text = "RGB",
		TextColor3 = values().muted,
		TextSize = util.size(8),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		Parent = panel,
	})
	local rgb = util.new("TextBox", {
		BackgroundColor3 = values().raised,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		TextEditable = not disabled,
		Font = mono,
		Position = UDim2.fromOffset(pad + 30, rgb_y),
		Size = UDim2.new(1, -(pad * 2 + 30), 0, rgb_h),
		Text = "230, 162, 58",
		PlaceholderText = "R, G, B",
		PlaceholderColor3 = values().muted,
		TextColor3 = values().text,
		TextSize = util.size(9),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		Parent = panel,
	})
	util.corner(rgb, 0)
	util.inset(rgb, 0.3)
	local rgb_edge = util.stroke(rgb, values().line, 0.3)
	util.new("UIPadding", {
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		Parent = rgb,
	})

	local function color()
		return Color3.fromHSV(hue, sat, val)
	end

	local key = nil
	local refresh
	local set_open

	local function paint_recent()
		for index, slot in ipairs(recent_slots) do
			local value = recent_list[index]
			slot.Visible = value ~= nil
			if value then
				slot.BackgroundColor3 = Color3.fromHex("#" .. value)
			end
		end
	end

	local function add_recent(picked)
		if not recent_enabled or typeof(picked) ~= "Color3" then
			return
		end
		local hex = string.upper(picked:ToHex())
		for index, entry in ipairs(recent_list) do
			if entry == hex then
				table.remove(recent_list, index)
				break
			end
		end
		table.insert(recent_list, 1, hex)
		while #recent_list > #recent_slots do
			table.remove(recent_list)
		end
		paint_recent()
	end

	local function swatch_holder(index)
		return util.new("Frame", {
			Name = "swatches",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(pad, swatch_y + (index - 1) * 24),
			Size = UDim2.new(1, -pad * 2, 0, swatch_size),
			ZIndex = 3,
			Parent = panel,
		})
	end

	local row_index = 0
	if #presets > 0 then
		row_index = row_index + 1
		local holder = swatch_holder(row_index)
		for index, preset in ipairs(presets) do
			local swatch = util.new("TextButton", {
				Name = "preset",
				BackgroundColor3 = preset,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Active = not disabled,
				Position = UDim2.fromOffset((index - 1) * swatch_step, 0),
				Size = UDim2.fromOffset(swatch_size, swatch_size),
				Text = "",
				ZIndex = 3,
				Parent = holder,
			})
			util.corner(swatch, 0)
			util.depth(swatch, 0.2)
			util.stroke(swatch, values().line, 0.2)
			swatch.Activated:Connect(function()
				if disabled then
					return
				end
				hue, sat, val = Color3.toHSV(preset)
				refresh(true)
				add_recent(preset)
				set_open(false)
			end)
		end
	end

	if recent_enabled then
		row_index = row_index + 1
		local holder = swatch_holder(row_index)
		for index = 1, 6 do
			local slot = util.new("TextButton", {
				Name = "recent",
				BackgroundColor3 = values().raised,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Active = not disabled,
				Position = UDim2.fromOffset((index - 1) * swatch_step, 0),
				Size = UDim2.fromOffset(swatch_size, swatch_size),
				Text = "",
				Visible = false,
				ZIndex = 3,
				Parent = holder,
			})
			util.corner(slot, 0)
			util.depth(slot, 0.2)
			util.stroke(slot, values().line, 0.2)
			recent_slots[index] = slot
			slot.Activated:Connect(function()
				if disabled then
					return
				end
				local value = recent_list[index]
				if not value then
					return
				end
				hue, sat, val = Color3.toHSV(Color3.fromHex("#" .. value))
				refresh(true)
				set_open(false)
			end)
		end
	end
	function refresh(fire)
		local picked = color()
		cursor.Position = UDim2.fromScale(sat, 1 - val)
		knob.Position = UDim2.new(hue, 0, 0.5, 0)
		field.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
		preview.BackgroundColor3 = picked
		swatch.BackgroundColor3 = picked
		if not hex:IsFocused() then
			hex.Text = "#" .. string.upper(picked:ToHex())
		end
		if not rgb:IsFocused() then
			local r = math.floor(picked.R * 255 + 0.5)
			local g = math.floor(picked.G * 255 + 0.5)
			local b = math.floor(picked.B * 255 + 0.5)
			rgb.Text = string.format("%d, %d, %d", r, g, b)
		end
		if fire then
			win._store(key, "#" .. string.upper(picked:ToHex()))
			if callback then
				callback(picked)
			end
		end
	end

	local function commit_rgb()
		local parts = {}
		for value in string.gmatch(rgb.Text, "%-?%d+") do
			parts[#parts + 1] = tonumber(value)
		end
		if #parts < 3 then
			refresh(false)
			return
		end
		local r = math.clamp(parts[1] or 0, 0, 255)
		local g = math.clamp(parts[2] or 0, 0, 255)
		local b = math.clamp(parts[3] or 0, 0, 255)
		hue, sat, val = Color3.toHSV(Color3.fromRGB(r, g, b))
		refresh(true)
		add_recent(color())
	end

	rgb.Focused:Connect(function()
		rgb_edge.Color = values().accent
		rgb_edge.Transparency = 0.15
	end)
	rgb.FocusLost:Connect(function()
		rgb_edge.Color = values().line
		rgb_edge.Transparency = 0.3
		if not disabled then
			commit_rgb()
		end
	end)

	copy_btn.Activated:Connect(function()
		if disabled or type(setclipboard) ~= "function" then
			return
		end
		pcall(function()
			setclipboard(hex.Text)
		end)
		if S.notify then
			S.notify("Color", "Copied " .. hex.Text, 1.5, "good")
		end
	end)

	random_btn.Activated:Connect(function()
		if disabled then
			return
		end
		hue = math.random()
		sat = 0.45 + math.random() * 0.55
		val = 0.65 + math.random() * 0.35
		refresh(true)
		add_recent(color())
	end)

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
		if disabled then
			return
		end
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			field_drag = true
			read_field(input.Position.X, input.Position.Y)
		end
	end)
	hue_hit.InputBegan:Connect(function(input)
		if disabled then
			return
		end
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
			if field_drag or hue_drag then
				add_recent(color())
			end
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
			add_recent(picked)
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
		if not disabled then
			commit_hex()
		end
	end)

	local open = false

	local function close()
		set_open(false)
	end

	function set_open(state)
		if state and disabled then
			return
		end
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
		Active = not disabled,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		ZIndex = 1,
		Parent = row,
	})
	util.hover(hit)
	hit.Activated:Connect(function()
		if disabled then
			return
		end
		set_open(not open)
	end)

	win._link(env.uis.InputBegan, function(input)
		if not open then
			return
		end
		local code = input.KeyCode
		local kind = input.UserInputType
		local keyboard_close = kind == Enum.UserInputType.Keyboard and code == Enum.KeyCode.Escape
		local gamepad_close = string.match(kind.Name, "^Gamepad") and code == Enum.KeyCode.ButtonB
		if keyboard_close or gamepad_close then
			set_open(false)
		end
	end)

	local function set_disabled(value)
		disabled = value == true
		hit.Active = not disabled
		field_hit.Active = not disabled
		hue_hit.Active = not disabled
		hex.TextEditable = not disabled
		rgb.TextEditable = not disabled
		rgb.Active = not disabled
		copy_btn.Active = not disabled
		random_btn.Active = not disabled
		if disabled then
			set_open(false)
			field_drag = false
			hue_drag = false
			if hex:IsFocused() then
				hex:ReleaseFocus()
			end
		end
		hex.TextColor3 = disabled and values().muted or values().text
		rgb.TextColor3 = disabled and values().muted or values().text
		name.TextColor3 = disabled and values().muted or values().text
		if emblem then
			icons.tint(emblem, disabled and values().line or values().muted)
		end
		if copy_icon then
			icons.tint(copy_icon, disabled and values().line or values().muted)
		end
		if random_icon then
			icons.tint(random_icon, disabled and values().line or values().muted)
		end
		swatch.BackgroundTransparency = disabled and 0.4 or 0
		if win._nav_refresh then
			win._nav_refresh()
		end
	end

	style.paint(function()
		panel.BackgroundColor3 = values().panel
		edge.Color = values().line
		hex.BackgroundColor3 = values().raised
		hex.TextColor3 = disabled and values().muted or values().text
		hex_edge.Color = values().line
		rgb.BackgroundColor3 = values().raised
		rgb.TextColor3 = disabled and values().muted or values().text
		rgb.PlaceholderColor3 = values().muted
		rgb_edge.Color = values().line
		rgb_label.TextColor3 = values().muted
		copy_btn.BackgroundColor3 = values().raised
		copy_edge.Color = values().line
		random_btn.BackgroundColor3 = values().raised
		random_edge.Color = values().line
		if copy_icon then
			icons.tint(copy_icon, disabled and values().line or values().muted)
		end
		if random_icon then
			icons.tint(random_icon, disabled and values().line or values().muted)
		end
		hit.BackgroundColor3 = values().hover
		name.TextColor3 = disabled and values().muted or values().text
		if emblem then
			icons.tint(emblem, disabled and values().line or values().muted)
		end
		swatch.BackgroundTransparency = disabled and 0.4 or 0
		refresh(false)
	end)

	refresh(false)
	key = win._bind("color", title, {
		set = apply,
		apply = function(value)
			apply(value)
			if callback then
				local picked = color()
				task.defer(function()
					callback(picked)
				end)
			end
		end,
	})
	win._options(row, title, function()
		return {
			{ label = "Open color picker", icon = "palette", accent = true, run = function()
				if not disabled then
					set_open(true)
				end
			end },
			{ label = "Reset color", icon = "arrow", run = function()
				if disabled then
					return
				end
				apply(initial)
				win._store(key, "#" .. string.upper(color():ToHex()))
				if callback then
					callback(color())
				end
			end },
		}
	end)
	win._nav_register(row, {
		kind = "colorpicker",
		label = title,
		is_enabled = function()
			return not disabled
		end,
		activate = function()
			set_open(true)
		end,
	})
	if tooltip and opts.tooltip then
		tooltip.attach(row, opts.tooltip)
	end
	win._fit(true)

	return {
		Set = function(_, value)
			apply(value)
		end,
		Get = function()
			return color()
		end,
		Open = function()
			if not disabled then
				set_open(true)
			end
		end,
		Close = function()
			set_open(false)
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

S.selects = selects
