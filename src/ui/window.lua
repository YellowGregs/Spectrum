local S = ...

local env = S.env
local util = S.util
local style = S.style
local modal = S.modal
local icons = S.icons
local config = S.config
local tooltip = S.tooltip
local background = S.background
local bold = Enum.Font.GothamBold
local font = Enum.Font.GothamMedium

local Window = {}
Window.roots = {}
Window.windows = {}

local nav = { owner = nil }

local function nav_claim(win)
	local previous = nav.owner
	if previous and previous ~= win and previous._nav_clear then
		previous._nav_clear()
	end
	nav.owner = win
end

local function nav_target()
	if nav.owner and nav.owner._nav_available and nav.owner._nav_available() then
		return nav.owner
	end
	local best
	for _, win in ipairs(Window.windows) do
		if win._nav_available and win._nav_available() and (not best or win.Gui.ZIndex > best.Gui.ZIndex) then
			best = win
		end
	end
	return best
end

local slots = 0
local top = 10
local GuiService = game:GetService("GuiService")
local inset_ok, inset = pcall(function()
	return GuiService:GetGuiInset()
end)
local safe_top = (inset_ok and inset and math.max(env.mobile and 70 or 80, math.floor(inset.Y + 2))) or (env.mobile and 70 or 80)

local function content_cap(view, header_height)
	return math.max(120, math.floor(math.min(view.Y * 0.56, view.Y - safe_top - header_height - 16)))
end

local function max_body_height(view, header_height)
	return math.max(60, math.floor(view.Y - safe_top - header_height - 12))
end

local function values()
	return style.values
end

local function spot(width)
	local vp = env.viewport()
	local per_row = math.max(1, math.floor((vp.X - 20) / (width + 8)))
	local index = slots
	slots = slots + 1
	local x = 10 + (index % per_row) * (width + 8)
	local base_y = safe_top + (env.mobile and 52 or 0)
	local y = base_y + math.floor(index / per_row) * 40
	if x + width > vp.X - 10 then
		x = math.max(10, vp.X - width - 10)
	end
	if y > vp.Y - 170 then
		y = base_y
	end
	return UDim2.fromOffset(x, y)
end

function Window.new(title, opts)
	opts = opts or {}
	title = title or "Window"
	local mobile = env.mobile
	local vp = env.viewport()
	local key = config.window_key(title)
	local saved = config.window_state(key)
	local preferred = opts.width or (mobile and math.min(272, vp.X - 20) or 320)
	if saved and type(saved.width) == "number" then
		preferred = saved.width
	end
	local head = mobile and 38 or 34
	local row_base = mobile and 40 or 32
	local min_width = math.min(mobile and 210 or 252, math.max(160, vp.X - 20))
	local width = math.clamp(preferred, min_width, math.max(min_width, vp.X - 20))
	local cap = content_cap(vp, head)
	local height_override
	if saved and type(saved.height) == "number" then
		height_override = math.clamp(saved.height, 34, max_body_height(vp, head))
	end
	local order = 0
	local open = not (saved and saved.open == false)
	local start = spot(width)
	if saved and type(saved.x) == "number" and type(saved.y) == "number" then
		start = UDim2.fromOffset(math.clamp(saved.x, -(width - 70), vp.X - 70), math.clamp(saved.y, safe_top, vp.Y - head - 4))
	end
	local links = {}
	local panels = {}
	local dragging = false
	local resizing = false
	local drag_from, drag_at
	local resize_from, resize_from_height, resize_at, resize_at_y

	local w = {}
	w._mobile = mobile
	w._rowBase = row_base
	w._head = head
	w._scroll = nil
	w._key = key

	top = top + 1
	local root = util.new("Frame", {
		Name = "Window",
		Active = true,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(width, head + 60),
		Position = start,
		ZIndex = top,
		Parent = env.windows,
	})
	Window.roots[#Window.roots + 1] = root
	w.Gui = root

	local body = util.new("Frame", {
		Name = "body",
		BackgroundColor3 = values().background,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = root,
	})
	local edge = util.stroke(body, values().line, 0.3)
	util.shadow(body, 18, 0.5)

	local backdrop = util.new("Frame", {
		Name = "backdrop",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 1,
		Parent = body,
	})
	local backdrop_image = util.new("ImageLabel", {
		Name = "image",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = "",
		ImageColor3 = Color3.new(1, 1, 1),
		ImageTransparency = 0.25,
		ScaleType = Enum.ScaleType.Crop,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Parent = backdrop,
	})
	local backdrop_scrim = util.new("Frame", {
		Name = "scrim",
		BackgroundColor3 = values().background,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = backdrop,
	})

	local function apply_backdrop(state)
		if not state.asset then
			backdrop.Visible = false
			backdrop_image.Image = ""
			return
		end
		backdrop_image.Image = state.asset
		backdrop_image.ImageTransparency = state.transparency
		backdrop_image.ImageColor3 = state.tint
		backdrop_image.ScaleType = background.scale_type(state.scale)
		backdrop_scrim.BackgroundTransparency = state.scrim
		backdrop.Visible = true
	end

	if background then
		local stop = background.watch(apply_backdrop)
		links[#links + 1] = { Disconnect = stop }
	end

	local header = util.new("Frame", {
		Name = "header",
		BackgroundColor3 = values().panel,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, head),
		ZIndex = 3,
		Parent = body,
	})
	local seam = util.new("Frame", {
		BackgroundColor3 = values().line,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, -1),
		Size = UDim2.new(1, 0, 0, 1),
		ZIndex = 4,
		Parent = header,
	})
	local mark = util.new("Frame", {
		BackgroundColor3 = values().accent,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, head / 2 - 6),
		Size = UDim2.fromOffset(3, 12),
		ZIndex = 4,
		Parent = header,
	})
	local caption = util.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(19, 0),
		Size = UDim2.new(1, -92, 1, 0),
		Font = bold,
		Text = title or "Window",
		TextColor3 = values().text,
		TextSize = util.size(11),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 4,
		Parent = header,
	})

	if type(opts.icon) == "string" and opts.icon ~= "" then
		local emblem = icons.image(header, opts.icon, 15, values().accent)
		if emblem then
			mark.Visible = false
			emblem.Position = UDim2.fromOffset(10, head / 2 - 7)
			emblem.ZIndex = 4
			caption.Position = UDim2.fromOffset(31, 0)
			caption.Size = UDim2.new(1, -104, 1, 0)
			style.paint(function()
				icons.tint(emblem, values().accent)
			end)
		end
	end

	local function remember()
		config.place(key, {
			x = root.Position.X.Offset,
			y = root.Position.Y.Offset,
			width = width,
			height = height_override,
			open = open,
		})
	end

	local function ghost(offset)
		local hit = util.new("TextButton", {
			BackgroundColor3 = values().raised,
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, offset, 0.5, 0),
			Size = UDim2.fromOffset(mobile and 28 or 24, mobile and 28 or 24),
			Text = "",
			ZIndex = 5,
			Parent = header,
		})
		util.corner(hit, 3)
		util.hover(hit)
		return hit
	end

	local fold_hit = ghost(mobile and -37 or -33)
	local close_hit = ghost(-6)
	local fold_bar_h = util.new("Frame", {
		BackgroundColor3 = values().muted,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(9, 1),
		Parent = fold_hit,
	})
	local fold_bar_v = util.new("Frame", {
		BackgroundColor3 = values().muted,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(1, 9),
		Parent = fold_hit,
	})
	local close_a = util.new("Frame", {
		BackgroundColor3 = values().muted,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Rotation = 45,
		Size = UDim2.fromOffset(9, 1),
		Parent = close_hit,
	})
	local close_b = util.new("Frame", {
		BackgroundColor3 = values().muted,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Rotation = -45,
		Size = UDim2.fromOffset(9, 1),
		Parent = close_hit,
	})

	local grab = util.new("TextButton", {
		Name = "grab",
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.new(1, -70, 1, 0),
		ZIndex = 4,
		Parent = header,
	})

	local scroll = util.new("ScrollingFrame", {
		Name = "content",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, head),
		Size = UDim2.new(1, 0, 0, 60),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.None,
		ClipsDescendants = true,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = mobile and 4 or 3,
		ScrollBarImageColor3 = values().muted,
		ScrollBarImageTransparency = 0.2,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		ZIndex = 3,
		Parent = body,
	})
	w._scroll = scroll

	local list = util.new("UIListLayout", {
		Padding = UDim.new(0, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = scroll,
	})

	local grip = util.new("TextButton", {
		Name = "resize",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, 0),
		Size = UDim2.fromOffset(mobile and 34 or 26, mobile and 14 or 16),
		Text = "",
		AutoButtonColor = false,
		ZIndex = 8,
		Parent = body,
	})
	local pips = {}
	for i = 1, 3 do
		pips[#pips + 1] = util.new("Frame", {
			BackgroundColor3 = values().muted,
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -3, 1, -3 - (i - 1) * 3),
			Size = UDim2.fromOffset(3 + i * 3, 1),
			Parent = grip,
		})
	end
	local grip_hot = false
	local function paint_grip()
		for _, pip in ipairs(pips) do
			pip.BackgroundColor3 = grip_hot and values().accent or values().muted
			pip.BackgroundTransparency = grip_hot and 0.25 or 0.55
		end
	end
	grip.MouseEnter:Connect(function()
		grip_hot = true
		paint_grip()
	end)
	grip.MouseLeave:Connect(function()
		grip_hot = false
		paint_grip()
	end)
	style.paint(paint_grip)

	local tab_h = mobile and 34 or 30
	local tabs = {}
	local default_tab = {
		name = "Main",
		icon = nil,
		slots = {},
		section_of = {},
		scroll = 0,
		order = 1,
		implicit = true,
	}
	tabs[1] = default_tab
	local active_tab = default_tab
	local strip_visible = false

	local strip = util.new("Frame", {
		Name = "tabs",
		BackgroundColor3 = values().raised,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, head),
		Size = UDim2.new(1, 0, 0, tab_h),
		Visible = false,
		ZIndex = 3,
		Parent = body,
	})
	local rail = util.new("ScrollingFrame", {
		Name = "rail",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ClipsDescendants = true,
		ScrollBarThickness = 0,
		ScrollBarImageTransparency = 1,
		ScrollingDirection = Enum.ScrollingDirection.X,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 4,
		Parent = strip,
	})
	util.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Parent = rail,
	})
	util.new("UIPadding", {
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		Parent = rail,
	})
	local strip_seam = util.new("Frame", {
		BackgroundColor3 = values().line,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, -1),
		Size = UDim2.new(1, 0, 0, 1),
		ZIndex = 5,
		Parent = strip,
	})

	local function chrome()
		return head + (strip_visible and tab_h or 0)
	end

	local function layout_chrome()
		strip_visible = #tabs > 1
		strip.Visible = strip_visible
		scroll.Position = UDim2.fromOffset(0, chrome())
		w._head = chrome()
		for _, entry in ipairs(tabs) do
			if entry.facade then
				entry.facade._head = chrome()
			end
		end
	end

	local function fit(animate)
		cap = content_cap(env.viewport(), chrome())
		local content_height = math.max(0, list.AbsoluteContentSize.Y + 2)
		local height
		if height_override then
			height = math.clamp(height_override, 34, max_body_height(env.viewport(), chrome()))
		else
			height = math.clamp(content_height, 34, cap)
		end
		scroll.CanvasSize = UDim2.fromOffset(0, content_height)
		scroll.Size = UDim2.new(1, 0, 0, height)
		grip.Visible = open
		local target = UDim2.fromOffset(width, chrome() + (open and height or 0))
		if animate then
			util.tween(root, 0.2, { Size = target })
		else
			root.Size = target
		end
	end

	local function paint_tab(tab)
		if not tab.chip then
			return
		end
		local on = tab == active_tab
		tab.chip.BackgroundColor3 = values().hover
		tab.chip.BackgroundTransparency = 1
		tab.chip.TextColor3 = on and values().text or values().muted
		tab.bar.Visible = on
		tab.bar.BackgroundColor3 = values().accent
		if tab.emblem then
			icons.tint(tab.emblem, on and values().accent or values().muted)
		end
	end

	local set_tab

	local function chip_for(tab)
		local chip = util.new("TextButton", {
			Name = "tab",
			BackgroundColor3 = values().hover,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = tab.order,
			Size = UDim2.fromOffset(0, tab_h - 4),
			Font = font,
			Text = tab.name,
			TextColor3 = values().muted,
			TextSize = util.size(10),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 4,
			Parent = rail,
		})
		util.corner(chip, 4)
		util.new("UISizeConstraint", {
			MaxSize = Vector2.new(mobile and 132 or 152, tab_h),
			Parent = chip,
		})
		local pad_left = tab.icon and 25 or 10
		local pad_right = 10
		util.new("UIPadding", {
			PaddingLeft = UDim.new(0, pad_left),
			PaddingRight = UDim.new(0, pad_right),
			Parent = chip,
		})
		local emblem
		if tab.icon then
			emblem = icons.image(chip, tab.icon, 12, values().muted)
			if emblem then
				emblem.AnchorPoint = Vector2.new(0, 0.5)
				emblem.Position = UDim2.new(0, 9 - pad_left, 0.5, 0)
				icons.layer(emblem, 5)
			end
		end
		local bar = util.new("Frame", {
			BackgroundColor3 = values().accent,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, -pad_left, 1, -3),
			Size = UDim2.new(1, pad_left + pad_right, 0, 2),
			Visible = false,
			ZIndex = 5,
			Parent = chip,
		})
		tab.chip = chip
		tab.bar = bar
		tab.emblem = emblem
		chip.MouseEnter:Connect(function()
			if tab ~= active_tab then
				util.tween(chip, 0.1, { BackgroundTransparency = 0.86 })
			end
		end)
		chip.MouseLeave:Connect(function()
			if tab ~= active_tab then
				util.tween(chip, 0.12, { BackgroundTransparency = 1 })
			end
		end)
		chip.Activated:Connect(function()
			set_tab(tab)
		end)
		if tooltip and tab.tooltip then
			tooltip.attach(chip, tab.tooltip)
		end
		return chip
	end

	set_tab = function(tab, force)
		if not tab or (tab == active_tab and not force) then
			paint_tab(active_tab)
			return
		end
		if active_tab then
			active_tab.scroll = scroll.CanvasPosition.Y
		end
		active_tab = tab
		for _, entry in ipairs(tabs) do
			for _, slot in ipairs(entry.slots) do
				if slot.Parent then
					local record = entry.section_of[slot]
					slot.Visible = entry == tab and (record == nil or record.open)
				end
			end
			paint_tab(entry)
		end
		layout_chrome()
		if tooltip then
			tooltip.hide()
		end
		modal.dismiss()
		if w._nav_clear then
			w._nav_clear()
		end
		fit(false)
		local target = tab.scroll or 0
		task.defer(function()
			if active_tab == tab and scroll.Parent then
				scroll.CanvasPosition = Vector2.new(0, target)
			end
		end)
	end

	local function make_tab(name, tab_icon, note, tab_order)
		if not default_tab.chip then
			chip_for(default_tab)
		end
		local tab = {
			name = name,
			icon = tab_icon,
			tooltip = note,
			slots = {},
			section_of = {},
			scroll = 0,
			order = tab_order,
			implicit = false,
		}
		tabs[#tabs + 1] = tab
		chip_for(tab)
		return tab
	end

	local function front()
		top = top + 1
		root.ZIndex = top
		nav_claim(w)
	end
	w._front = front

	local function fold(state, save)
		if state == nil then
			state = not open
		end
		if state == open then
			return
		end
		open = state
		scroll.Visible = true
		util.tween(fold_bar_v, 0.15, { Size = UDim2.fromOffset(1, open and 9 or 0) })
		fit(true)
		if not open then
			task.delay(0.24, function()
				if not open and scroll.Parent then
					scroll.Visible = false
				end
			end)
		end
		if save ~= false then
			remember()
		end
	end

	local function close()
		remember()
		modal.dismiss()
		if tooltip then
			tooltip.hide()
		end
		root:Destroy()
	end

	fold_hit.Activated:Connect(function()
		fold()
	end)
	close_hit.Activated:Connect(close)

	grab.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			dragging = true
			drag_from = input.Position
			drag_at = root.Position
			front()
			modal.dismiss()
		end
	end)

	grip.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			resizing = true
			util.cancel(root)
			resize_from = width
			resize_from_height = root.Size.Y.Offset - chrome()
			resize_at = input.Position.X
			resize_at_y = input.Position.Y
			front()
			modal.dismiss()
		end
	end)

	root.InputBegan:Connect(front)
	S.options.attach(grab, title, function()
		return {
			{ label = open and "Collapse window" or "Expand window", run = function() fold() end },
			{ label = "Close window", run = close },
		}
	end)

	local resize_to
	local resize_pending = false

	local function commit_resize()
		resize_pending = false
		if not resizing or not resize_to then
			return
		end
		local view = env.viewport()
		local min_width = math.min(mobile and 210 or 252, math.max(160, view.X - 20))
		local next_width = math.clamp(resize_from + (resize_to.X - resize_at), min_width, math.max(min_width, view.X - 20))
		local delta_y = resize_to.Y - resize_at_y
		resize_to = nil
		local width_changed = math.abs(next_width - width) >= 1
		local height_changed = math.abs(delta_y) >= 1
		if not width_changed and not height_changed then
			return
		end
		if width_changed then
			width = next_width
			preferred = width
		end
		if height_changed then
			height_override = math.clamp(resize_from_height + delta_y, 34, max_body_height(view, chrome()))
		end
		local body_height = height_override or math.max(34, root.Size.Y.Offset - chrome())
		body_height = math.clamp(body_height, 34, max_body_height(view, chrome()))
		scroll.Size = UDim2.new(1, 0, 0, body_height)
		root.Size = UDim2.fromOffset(width, chrome() + (open and body_height or 0))
	end

	local function schedule_resize()
		if resize_pending then
			return
		end
		resize_pending = true
		task.defer(commit_resize)
	end

	local function follow(input)
		local moving = input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
		if not moving then
			return
		end
		local view = env.viewport()
		if dragging then
			local delta = input.Position - drag_from
			local x = math.clamp(drag_at.X.Offset + delta.X, -(width - 70), view.X - 70)
			local y = math.clamp(drag_at.Y.Offset + delta.Y, safe_top, view.Y - chrome() - 4)
			root.Position = UDim2.fromOffset(x, y)
		elseif resizing then
			resize_to = input.Position
			schedule_resize()
		end
	end

	w._link = function(signal, fn)
		local conn = signal:Connect(fn)
		links[#links + 1] = conn
		return conn
	end

	local stop = env.uis.InputEnded:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			local moved = dragging or resizing
			local was_resizing = resizing
			if was_resizing and resize_to then
				commit_resize()
			end
			dragging = false
			resizing = false
			resize_pending = false
			resize_to = nil
			if moved then
				if was_resizing then
					fit(false)
				end
				remember()
			end
		end
	end)
	links[#links + 1] = stop

	local moved = env.uis.InputChanged:Connect(follow)
	links[#links + 1] = moved

	local measured = list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		if resizing then
			return
		end
		fit(true)
	end)
	links[#links + 1] = measured

	local function refit()
		local view = env.viewport()
		if view.X <= 0 or view.Y <= 0 then
			return
		end
		local min_width = math.min(mobile and 210 or 252, math.max(160, view.X - 20))
		width = math.clamp(preferred, min_width, math.max(min_width, view.X - 20))
		cap = content_cap(view, chrome())
		if height_override then
			height_override = math.clamp(height_override, 34, max_body_height(view, chrome()))
		end
		root.Position = UDim2.fromOffset(
			math.clamp(root.Position.X.Offset, -math.max(0, width - 70), math.max(0, view.X - 70)),
			math.clamp(root.Position.Y.Offset, safe_top, math.max(safe_top, view.Y - chrome() - 4))
		)
		root.Size = UDim2.fromOffset(width, root.Size.Y.Offset)
		fit(false)
	end

	local camera_link
	local function watch_camera()
		if camera_link then
			camera_link:Disconnect()
			camera_link = nil
		end
		local camera = workspace.CurrentCamera
		if camera then
			camera_link = camera:GetPropertyChangedSignal("ViewportSize"):Connect(refit)
			links[#links + 1] = camera_link
		end
		refit()
	end
	watch_camera()
	local camera_switch = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watch_camera)
	links[#links + 1] = camera_switch

	local function slot_for(tab, height, ungrouped)
		order = order + 1
		local slot = util.new("Frame", {
			Name = "slot",
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, height or row_base),
			Parent = scroll,
		})
		tab.slots[#tab.slots + 1] = slot
		if tab.cursor and not ungrouped then
			tab.cursor.slots[#tab.cursor.slots + 1] = slot
			tab.section_of[slot] = tab.cursor
		end
		local record = tab.section_of[slot]
		slot.Visible = tab == active_tab and (record == nil or record.open)
		return slot
	end

	local function toggle_section(record, state)
		if not record then
			return
		end
		if state == nil then
			state = not record.open
		end
		record.open = state
		for _, slot in ipairs(record.slots) do
			if slot.Parent then
				slot.Visible = state and record.tab == active_tab
			end
		end
		if w._nav_refresh then
			w._nav_refresh()
		end
		if w._fit then
			task.defer(function()
				if w.Gui and w.Gui.Parent and w._fit then
					w._fit(true)
				end
			end)
		end
	end

	function w._slot(height, ungrouped)
		return slot_for(active_tab, height, ungrouped)
	end

	function w._new_section()
		return { open = true, slots = {}, tab = active_tab }
	end

	function w._focus_section(record)
		active_tab.cursor = record
	end

	function w._toggle_section(record, state)
		toggle_section(record, state)
	end

	function w._row(height)
		local row = w._slot(height or row_base)
		row.BackgroundColor3 = values().hover
		row.BackgroundTransparency = 1
		local line = util.divider(row)
		style.paint(function()
			row.BackgroundColor3 = values().hover
			line.BackgroundColor3 = values().line
		end)
		return row
	end

	function w._hover(row)
		util.hover(row)
	end

	function w._options(row, title, build)
		if S.options then
			return S.options.attach(row, title, build)
		end
	end

	function w._popover(panel)
		panels[#panels + 1] = panel
		return panel
	end

	w._fit = fit
	w._modal = modal

	function w._bind(kind, label, api)
		return config.bind(key, kind, label, api)
	end

	function w._store(id, value)
		config.put(key, id, value)
	end

	w._nav_available = function()
		return root.Visible and root.Parent ~= nil and open
	end

	local nav_items = {}
	local nav_current

	local function shown(object)
		local node = object
		while node do
			if node.Visible == false then
				return false
			end
			if node == scroll then
				return true
			end
			node = node.Parent
		end
		return true
	end

	local function nav_item_available(item)
		local row = item.row
		if not row or not row.Parent or not shown(row) or row.AbsoluteSize.Y <= 0 then
			return false
		end
		if item.is_enabled and not item.is_enabled() then
			return false
		end
		return true
	end

	local function nav_scroll(item)
		local row = item.row
		if not row or not row.Parent or not scroll.Parent then
			return
		end
		local top = row.AbsolutePosition.Y - scroll.AbsolutePosition.Y + scroll.CanvasPosition.Y
		local view_top = scroll.CanvasPosition.Y
		local view_bottom = view_top + scroll.AbsoluteSize.Y
		if top < view_top then
			scroll.CanvasPosition = Vector2.new(scroll.CanvasPosition.X, math.max(0, top - 2))
		elseif top + row.AbsoluteSize.Y > view_bottom then
			scroll.CanvasPosition = Vector2.new(scroll.CanvasPosition.X, math.max(0, top + row.AbsoluteSize.Y - scroll.AbsoluteSize.Y + 2))
		end
	end

	local function nav_clear()
		if nav_current then
			if nav_current.edge then
				nav_current.edge.Transparency = 1
			end
			if nav_current.bar then
				nav_current.bar.Visible = false
			end
		end
		nav_current = nil
	end

	w._nav_clear = nav_clear

	local function nav_focus(item)
		if nav_current and nav_current ~= item then
			if nav_current.edge then
				nav_current.edge.Transparency = 1
			end
			if nav_current.bar then
				nav_current.bar.Visible = false
			end
		end
		nav_current = item
		if item.edge then
			item.edge.Transparency = 0.15
		end
		if item.bar then
			item.bar.Visible = true
		end
		nav_scroll(item)
	end

	local function nav_walk(index, direction)
		local count = #nav_items
		if count == 0 then
			return
		end
		for _ = 1, count do
			index = index + direction
			if index > count then
				index = 1
			elseif index < 1 then
				index = count
			end
			local item = nav_items[index]
			if nav_item_available(item) then
				nav_focus(item)
				return
			end
		end
		nav_clear()
	end

	local function nav_step(direction)
		local index = nav_current and nav_current.index or (direction > 0 and 0 or #nav_items + 1)
		nav_walk(index, direction)
	end

	local function nav_edge(direction)
		nav_walk(direction > 0 and 0 or #nav_items + 1, direction)
	end

	local function nav_activate()
		local item = nav_current
		if not item or not item.activate or not nav_item_available(item) then
			nav_clear()
			return
		end
		task.defer(function()
			if nav_current == item and nav_item_available(item) then
				item.activate()
			end
		end)
	end

	local function nav_adjust(direction)
		local item = nav_current
		if item and item.adjust and nav_item_available(item) then
			item.adjust(direction)
		end
	end

	function w._nav_register(row, opts)
		opts = opts or {}
		local nav_edge = util.new("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = values().accent,
			Thickness = 1,
			Transparency = 1,
			Parent = row,
		})
		local bar = util.new("Frame", {
			Name = "nav_focus_bar",
			BackgroundColor3 = values().accent,
			Active = false,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 2, 1, 0),
			Visible = false,
			ZIndex = 20,
			Parent = row,
		})
		style.paint(function()
			nav_edge.Color = values().accent
			bar.BackgroundColor3 = values().accent
		end)
		local item = {
			row = row,
			edge = nav_edge,
			bar = bar,
			activate = opts.activate,
			adjust = opts.adjust,
			is_enabled = opts.is_enabled,
			kind = opts.kind,
			label = opts.label,
			index = #nav_items + 1,
		}
		nav_items[#nav_items + 1] = item
		return item
	end

	function w._nav_refresh()
		if nav_current and not nav_item_available(nav_current) then
			nav_clear()
		end
	end

	local function nav_ready()
		return root.Visible and root.Parent ~= nil and open and not S.splash_open and not util.focused_text_box() and not S.binding and not modal.current
	end

	local function nav_here()
		if nav_target() ~= w then
			return false
		end
		if nav.owner ~= w then
			nav_claim(w)
		end
		return true
	end

	local nav_input = env.uis.InputBegan:Connect(function(input, processed)
		if processed or not nav_ready() or not nav_here() then
			return
		end
		local code = input.KeyCode
		local kind = input.UserInputType
		if kind == Enum.UserInputType.Keyboard then
			if code == Enum.KeyCode.Down or code == Enum.KeyCode.Tab then
				nav_step(1)
			elseif code == Enum.KeyCode.Up then
				nav_step(-1)
			elseif code == Enum.KeyCode.Home then
				nav_edge(1)
			elseif code == Enum.KeyCode.End then
				nav_edge(-1)
			elseif code == Enum.KeyCode.Return or code == Enum.KeyCode.KeypadEnter then
				nav_activate()
			elseif code == Enum.KeyCode.Left then
				nav_adjust(-1)
			elseif code == Enum.KeyCode.Right then
				nav_adjust(1)
			elseif code == Enum.KeyCode.Escape then
				nav_clear()
			end
		elseif string.match(kind.Name, "^Gamepad") then
			if code == Enum.KeyCode.DPadDown then
				nav_step(1)
			elseif code == Enum.KeyCode.DPadUp then
				nav_step(-1)
			elseif code == Enum.KeyCode.DPadLeft then
				nav_adjust(-1)
			elseif code == Enum.KeyCode.DPadRight then
				nav_adjust(1)
			elseif code == Enum.KeyCode.ButtonA then
				nav_activate()
			elseif code == Enum.KeyCode.ButtonB then
				nav_clear()
			end
		end
	end)
	links[#links + 1] = nav_input

	local stick_latched = false
	local stick_next = 0
	local nav_changed = env.uis.InputChanged:Connect(function(input)
		if not string.match(input.UserInputType.Name, "^Gamepad") then
			stick_latched = false
			return
		end
		if not nav_ready() or not nav_here() then
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
		nav_step(direction)
		stick_latched = true
		stick_next = now + 0.18
	end)
	links[#links + 1] = nav_changed

	local function surface(tab)
		local api = {}
		api._tab = tab
		tab.facade = api
		api._mobile = mobile
		api._head = chrome()
		api._scroll = scroll
		api.Gui = root

		function api._slot(height, ungrouped)
			return slot_for(tab, height, ungrouped)
		end

		function api._row(height)
			local row = api._slot(height or row_base)
			row.BackgroundColor3 = values().hover
			row.BackgroundTransparency = 1
			local line = util.divider(row)
			style.paint(function()
				row.BackgroundColor3 = values().hover
				line.BackgroundColor3 = values().line
			end)
			return row
		end

		function api._hover(row)
			util.hover(row)
		end

		function api._options(row, caption, build)
			if S.options then
				return S.options.attach(row, caption, build)
			end
		end

		function api._popover(panel)
			panels[#panels + 1] = panel
			return panel
		end

		api._fit = fit
		api._modal = modal

		function api._bind(kind, caption, handler)
			return config.bind(key, kind, caption, handler)
		end

		function api._store(id, value)
			config.put(key, id, value)
		end

		function api._link(signal, fn)
			return w._link(signal, fn)
		end

		function api._nav_register(row, spec)
			return w._nav_register(row, spec)
		end

		function api._nav_refresh()
			w._nav_refresh()
		end

		function api._nav_clear()
			w._nav_clear()
		end

		function api._new_section()
			return { open = true, slots = {}, tab = tab }
		end

		function api._focus_section(record)
			tab.cursor = record
		end

		function api._toggle_section(record, state)
			toggle_section(record, state)
		end

		return api
	end

	local function decorate(target)
		target.button = function(self, text, callback, icon, spec)
			return S.inputs.button(self, text, callback, icon, spec)
		end
		target.toggle = function(self, text, a, b, spec)
			return S.inputs.toggle(self, text, a, b, spec)
		end
		target.slider = function(self, text, min, max, default, callback, step, icon, spec)
			return S.inputs.slider(self, text, min, max, default, callback, step, icon, spec)
		end
		target.keybind = function(self, text, default, callback, icon, spec)
			return S.inputs.keybind(self, text, default, callback, icon, spec)
		end
		target.dropdown = function(self, text, options, default, callback, multi, icon, spec)
			return S.selects.dropdown(self, text, options, default, callback, multi, icon, spec)
		end
		target.colorpicker = function(self, text, default, callback, icon, spec)
			return S.selects.colorpicker(self, text, default, callback, icon, spec)
		end
		target.textbox = function(self, text, default, callback, icon, spec)
			return S.text.textbox(self, text, default, callback, icon, spec)
		end
		target.section = function(self, text, icon)
			return S.text.section(self, text, icon)
		end
		target.label = function(self, text)
			return S.text.label(self, text)
		end
		target.separator = function(self)
			return S.text.separator(self)
		end
		return target
	end

	function w.Tab(self, name, spec)
		spec = type(spec) == "table" and spec or {}
		local label = tostring(name or "Tab")
		local tab_icon = type(spec.icon) == "string" and spec.icon ~= "" and spec.icon or nil
		local note = type(spec.tooltip) == "string" and spec.tooltip ~= "" and spec.tooltip or nil
		local tab
		if #tabs == 1 and default_tab.implicit and #default_tab.slots == 0 then
			tab = default_tab
			tab.name = label
			tab.icon = tab_icon
			tab.tooltip = note
			tab.implicit = false
			chip_for(tab)
		else
			tab = make_tab(label, tab_icon, note, #tabs + 1)
		end
		layout_chrome()
		set_tab(tab, true)
		return decorate(surface(tab))
	end

	function w:SetTitle(text)
		caption.Text = tostring(text)
	end

	function w:Toggle(state)
		fold(state)
	end

	function w:Destroy()
		remember()
		root:Destroy()
	end

	function w:Close()
		close()
	end

	decorate(w)

	config.attach_window(key, {
		restore = function(state)
			local view = env.viewport()
			if type(state.width) == "number" then
				local min_width = math.min(mobile and 210 or 252, math.max(160, view.X - 20))
				width = math.clamp(state.width, min_width, math.max(min_width, view.X - 20))
				root.Size = UDim2.fromOffset(width, root.Size.Y.Offset)
			end
			if type(state.height) == "number" then
				height_override = math.clamp(state.height, 34, max_body_height(view, chrome()))
			end
			if type(state.x) == "number" and type(state.y) == "number" then
				root.Position = UDim2.fromOffset(math.clamp(state.x, -(width - 70), view.X - 70), math.clamp(state.y, safe_top, math.max(safe_top, view.Y - chrome() - 4))
				)
			end
			if state.open ~= nil then
				open = state.open ~= false
				scroll.Visible = open
				fold_bar_v.Size = UDim2.fromOffset(1, open and 9 or 0)
			end
			fit(false)
		end,
	})

	root.Destroying:Connect(function()
		remember()
		modal.dismiss()
		if tooltip then
			tooltip.hide()
		end
		for index, entry in ipairs(Window.windows) do
			if entry == w then
				table.remove(Window.windows, index)
				break
			end
		end
		for index, entry in ipairs(Window.roots) do
			if entry == root then
				table.remove(Window.roots, index)
				break
			end
		end
		if nav.owner == w then
			nav.owner = nil
		end
		for _, conn in ipairs(links) do
			if conn then
				pcall(function()
					conn:Disconnect()
				end)
			end
		end
		for _, panel in ipairs(panels) do
			if panel.Parent then
				panel:Destroy()
			end
		end
	end)

	style.paint(function()
		body.BackgroundColor3 = values().background
		header.BackgroundColor3 = values().panel
		strip.BackgroundColor3 = values().raised
		strip_seam.BackgroundColor3 = values().line
		backdrop_scrim.BackgroundColor3 = values().background:Lerp(Color3.new(0, 0, 0), 0.7)
		caption.TextColor3 = values().text
		mark.BackgroundColor3 = values().accent
		seam.BackgroundColor3 = values().line
		edge.Color = values().line
		fold_bar_h.BackgroundColor3 = values().muted
		fold_bar_v.BackgroundColor3 = values().muted
		close_a.BackgroundColor3 = values().muted
		close_b.BackgroundColor3 = values().muted
		scroll.ScrollBarImageColor3 = values().muted
		for _, pip in ipairs(pips) do
			pip.BackgroundColor3 = values().muted
		end
		for _, entry in ipairs(tabs) do
			paint_tab(entry)
		end
	end)

	layout_chrome()
	fit(false)
	Window.windows[#Window.windows + 1] = w
	return w
end

S.window = Window
