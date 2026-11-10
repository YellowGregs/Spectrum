local S = ...

local env = S.env
local util = S.util
local style = S.style
local modal = S.modal
local icons = S.icons
local config = S.config
local bold = Enum.Font.GothamBold
local font = Enum.Font.GothamMedium

local Window = {}
Window.roots = {}

local slots = 0
local top = 10

local function values()
	return style.values
end

local function spot(width)
	local vp = env.viewport()
	local perRow = math.max(1, math.floor((vp.X - 20) / (width + 8)))
	local index = slots
	slots = slots + 1
	local x = 10 + (index % perRow) * (width + 8)
	local y = 40 + math.floor(index / perRow) * 40
	if x + width > vp.X - 10 then
		x = math.max(10, vp.X - width - 10)
	end
	if y > vp.Y - 170 then
		y = 56
	end
	return UDim2.fromOffset(x, y)
end

function Window.new(title, opts)
	opts = opts or {}
	title = title or "Window"
	local mobile = env.mobile
	local vp = env.viewport()
	local key = config.windowKey(title)
	local saved = config.windowState(key)
	local width = opts.width or (mobile and math.min(272, vp.X - 20) or 276)
	if saved and type(saved.width) == "number" then
		width = saved.width
	end
	width = math.clamp(width, math.min(210, vp.X - 20), math.max(210, vp.X - 20))
	local head = mobile and 38 or 34
	local rowBase = mobile and 40 or 32
	local cap = math.max(140, math.floor(vp.Y * 0.62))
	local order = 0
	local open = not (saved and saved.open == false)
	local start = spot(width)
	if saved and type(saved.x) == "number" and type(saved.y) == "number" then
		start = UDim2.fromOffset(math.clamp(saved.x, -(width - 70), vp.X - 70), math.clamp(saved.y, 0, vp.Y - head - 4))
	end
	local links = {}
	local panels = {}
	local dragging = false
	local resizing = false
	local dragFrom, dragAt, resizeFrom, resizeAt

	local w = {}
	w._mobile = mobile
	w._rowBase = rowBase
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
		local emblem = icons.image(header, opts.icon, 13, values().accent)
		if emblem then
			mark.Visible = false
			emblem.Position = UDim2.fromOffset(10, head / 2 - 6)
			emblem.ZIndex = 4
			caption.Position = UDim2.fromOffset(29, 0)
			caption.Size = UDim2.new(1, -102, 1, 0)
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

	local foldHit = ghost(mobile and -37 or -33)
	local closeHit = ghost(-6)
	local foldBarH = util.new("Frame", {
		BackgroundColor3 = values().muted,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(9, 1),
		Parent = foldHit,
	})
	local foldBarV = util.new("Frame", {
		BackgroundColor3 = values().muted,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(1, 9),
		Parent = foldHit,
	})
	local closeA = util.new("Frame", {
		BackgroundColor3 = values().muted,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Rotation = 45,
		Size = UDim2.fromOffset(9, 1),
		Parent = closeHit,
	})
	local closeB = util.new("Frame", {
		BackgroundColor3 = values().muted,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Rotation = -45,
		Size = UDim2.fromOffset(9, 1),
		Parent = closeHit,
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
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = mobile and 3 or 2,
		ScrollBarImageColor3 = values().muted,
		ScrollBarImageTransparency = 0.55,
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
		Size = UDim2.fromOffset(mobile and 22 or 16, mobile and 22 or 16),
		Text = "",
		AutoButtonColor = false,
		ZIndex = 6,
		Parent = body,
	})
	local pips = {}
	for i = 1, 3 do
		pips[#pips + 1] = util.new("Frame", {
			BackgroundColor3 = values().muted,
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -2 - i * 3, 1, -2),
			Size = UDim2.fromOffset(1, i * 3),
			Parent = grip,
		})
	end

	local function fit(animate)
		local height = math.clamp(list.AbsoluteContentSize.Y + 2, 34, cap)
		scroll.Size = UDim2.new(1, 0, 0, height)
		local target = UDim2.fromOffset(width, head + (open and height or 0))
		if animate then
			util.tween(root, 0.2, { Size = target })
		else
			root.Size = target
		end
	end

	local function front()
		top = top + 1
		root.ZIndex = top
	end

	local function fold(state, save)
		if state == nil then
			state = not open
		end
		if state == open then
			return
		end
		open = state
		scroll.Visible = true
		util.tween(foldBarV, 0.15, { Size = UDim2.fromOffset(1, open and 9 or 0) })
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
		root:Destroy()
	end

	foldHit.Activated:Connect(function()
		fold()
	end)
	closeHit.Activated:Connect(close)

	grab.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			dragging = true
			dragFrom = input.Position
			dragAt = root.Position
			front()
			modal.dismiss()
		end
	end)

	grip.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			resizing = true
			resizeFrom = width
			resizeAt = input.Position.X
			front()
			modal.dismiss()
		end
	end)

	root.InputBegan:Connect(front)

	local function follow(input)
		local moving = input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
		if not moving then
			return
		end
		local view = env.viewport()
		if dragging then
			local delta = input.Position - dragFrom
			local x = math.clamp(dragAt.X.Offset + delta.X, -(width - 70), view.X - 70)
			local y = math.clamp(dragAt.Y.Offset + delta.Y, 0, view.Y - head - 4)
			root.Position = UDim2.fromOffset(x, y)
		elseif resizing then
			local nextWidth = math.clamp(resizeFrom + (input.Position.X - resizeAt), math.min(210, view.X - 20), view.X - 20)
			if math.abs(nextWidth - width) >= 1 then
				width = nextWidth
				root.Size = UDim2.fromOffset(width, root.Size.Y.Offset)
				fit(false)
			end
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
			dragging = false
			resizing = false
			if moved then
				remember()
			end
		end
	end)
	links[#links + 1] = stop

	local moved = env.uis.InputChanged:Connect(follow)
	links[#links + 1] = moved

	local measured = list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		fit(true)
	end)
	links[#links + 1] = measured

	function w._slot(height)
		order = order + 1
		return util.new("Frame", {
			Name = "slot",
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, height or rowBase),
			Parent = scroll,
		})
	end

	function w._row(height)
		local row = w._slot(height or rowBase)
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

	config.attachWindow(key, {
		restore = function(state)
			local view = env.viewport()
			if type(state.width) == "number" then
				width = math.clamp(state.width, math.min(210, view.X - 20), math.max(210, view.X - 20))
				root.Size = UDim2.fromOffset(width, root.Size.Y.Offset)
			end
			if type(state.x) == "number" and type(state.y) == "number" then
				root.Position = UDim2.fromOffset(math.clamp(state.x, -(width - 70), view.X - 70), math.clamp(state.y, 0, view.Y - head - 4)
				)
			end
			if state.open ~= nil then
				open = state.open ~= false
				scroll.Visible = open
				foldBarV.Size = UDim2.fromOffset(1, open and 9 or 0)
			end
			fit(false)
		end,
	})

	root.Destroying:Connect(function()
		remember()
		modal.dismiss()
		for _, conn in ipairs(links) do
			conn:Disconnect()
		end
		for _, panel in ipairs(panels) do
			panel:Destroy()
		end
	end)

	style.paint(function()
		body.BackgroundColor3 = values().background
		header.BackgroundColor3 = values().panel
		caption.TextColor3 = values().text
		mark.BackgroundColor3 = values().accent
		seam.BackgroundColor3 = values().line
		edge.Color = values().line
		foldBarH.BackgroundColor3 = values().muted
		foldBarV.BackgroundColor3 = values().muted
		closeA.BackgroundColor3 = values().muted
		closeB.BackgroundColor3 = values().muted
		scroll.ScrollBarImageColor3 = values().muted
		for _, pip in ipairs(pips) do
			pip.BackgroundColor3 = values().muted
		end
	end)

	fit(false)
	return w
end

S.window = Window
