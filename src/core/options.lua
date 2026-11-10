local S = ...

local env = S.env
local util = S.util
local style = S.style
local icons = S.icons
local modal = S.modal
local bold = Enum.Font.GothamBold
local font = Enum.Font.GothamMedium

local options = {}
local panel
local edge
local title_label
local close_hit
local action_list
local close_button

local function values()
	return style.values
end

local function ensure()
	if panel and panel.Parent then
		return
	end

	panel = util.new("Frame", {
		Name = "row_options",
		Active = true,
		BackgroundColor3 = values().panel,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = UDim2.fromOffset(194, 78),
		Visible = false,
		ZIndex = 20,
		Parent = env.modal,
	})
	edge = util.stroke(panel, values().line, 0.05)
	util.shadow(panel, 18, 0.4)

	local header = util.new("Frame", {
		Name = "header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 31),
		ZIndex = 21,
		Parent = panel,
	})
	util.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(11, 0),
		Size = UDim2.new(1, -42, 1, 0),
		Font = bold,
		Text = "Options",
		TextColor3 = values().text,
		TextSize = util.size(10),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 22,
		Parent = header,
	})
	title_label = header:FindFirstChildOfClass("TextLabel")
	close_hit = util.new("TextButton", {
		Name = "close",
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(25, 25),
		Text = "",
		ZIndex = 23,
		Parent = header,
	})
	util.corner(close_hit, 3)
	util.hover(close_hit)
	close_button = icons.image(close_hit, "close", 9, values().muted)
	if close_button then
		close_button.AnchorPoint = Vector2.new(0.5, 0.5)
		close_button.Position = UDim2.fromScale(0.5, 0.5)
		icons.layer(close_button, 24)
	end

	util.new("Frame", {
		BackgroundColor3 = values().line,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 31),
		Size = UDim2.new(1, 0, 0, 1),
		ZIndex = 21,
		Parent = panel,
	})

	action_list = util.new("Frame", {
		Name = "actions",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(6, 37),
		Size = UDim2.new(1, -12, 1, -42),
		ZIndex = 21,
		Parent = panel,
	})
	util.new("UIListLayout", {
		Padding = UDim.new(0, 3),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = action_list,
	})
end

local function close()
	if not panel or not panel.Visible then
		return
	end
	panel.Visible = false
	modal.drop(close)
end

function options.close()
	close()
end

function options.open(title, actions, anchor)
	ensure()
	if type(actions) ~= "table" or #actions == 0 then
		return
	end

	for _, child in ipairs(action_list:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local view = env.viewport()
	local parent_pos = panel.Parent and panel.Parent.AbsolutePosition or Vector2.new()
	local width = math.min(202, view.X - 12)
	local action_h = 28
	local height = 39 + #actions * (action_h + 3) + 4
	local x, y = 8, 8
	if typeof(anchor) == "Vector2" then
		x, y = anchor.X, anchor.Y
	elseif typeof(anchor) == "Instance" and anchor:IsA("GuiObject") then
		x = anchor.AbsolutePosition.X
		y = anchor.AbsolutePosition.Y + anchor.AbsoluteSize.Y + 5
	end
	x = math.clamp(x, 6, math.max(6, view.X - width - 6))
	if y + height > view.Y - 6 then
		if typeof(anchor) == "Instance" and anchor:IsA("GuiObject") then
			y = anchor.AbsolutePosition.Y - height - 5
		else
			y = view.Y - height - 6
		end
	end
	y = math.clamp(y, 6, math.max(6, view.Y - height - 6))

	title_label.Text = tostring(title or "Options")
	panel.Size = UDim2.fromOffset(width, height)
	panel.Position = UDim2.fromOffset(math.floor(x - parent_pos.X), math.floor(y - parent_pos.Y))

	for index, action in ipairs(actions) do
		local label = tostring(action.label or "Action")
		local row = util.new("TextButton", {
			Name = label,
			BackgroundColor3 = values().hover,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, action_h),
			Font = font,
			Text = "",
			TextColor3 = values().text,
			TextSize = util.size(10),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 22,
			Parent = action_list,
		})
		if action.accent then
			row.TextColor3 = values().accent
		end
		util.corner(row, 4)
		util.hover(row)

		local text = util.new("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(9, 0),
			Size = UDim2.new(1, -22, 1, 0),
			Font = action.accent and bold or font,
			Text = label,
			TextColor3 = action.accent and values().accent or values().text,
			TextSize = util.size(10),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 23,
			Parent = row,
		})
		if action.icon then
			local emblem = icons.image(row, action.icon, 12, values().muted)
			if emblem then
				emblem.AnchorPoint = Vector2.new(0, 0.5)
				emblem.Position = UDim2.new(0, 9, 0.5, 0)
				icons.layer(emblem, 23)
				text.Position = UDim2.fromOffset(27, 0)
				text.Size = UDim2.new(1, -38, 1, 0)
			end
		end

		row.Activated:Connect(function()
			if type(action.run) == "function" then
				local ok, err = pcall(action.run)
				if not ok then
					warn("[Spectrum] row option failed: " .. tostring(err))
				end
			end
			close()
		end)
	end

	panel.Visible = true
	panel.ZIndex = 20
	if modal.current ~= close then
		modal.claim(close)
	end
end

local function hook(object, open)
	if not object or not object:IsA("GuiObject") then
		return
	end
	local start
	local active = false
	object.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton2 then
			open()
			return
		end
		if kind ~= Enum.UserInputType.Touch then
			return
		end
		start = input.Position
		active = true
		task.delay(0.42, function()
			if active and object.Parent then
				open()
			end
		end)
	end)
	object.InputEnded:Connect(function(done)
		if done.UserInputType == Enum.UserInputType.Touch then
			active = false
		end
	end)
	object.InputChanged:Connect(function(move)
		if active and start and move.UserInputType == Enum.UserInputType.Touch and (move.Position - start).Magnitude > 8 then
			active = false
		end
	end)
end

function options.attach(row, title, build)
	if not row or type(build) ~= "function" then
		return
	end
	local last_open = 0
	local function open()
		if os.clock() - last_open < 0.12 then
			return
		end
		last_open = os.clock()
		local ok, actions = pcall(build)
		if ok and type(actions) == "table" then
			options.open(title, actions, row)
		end
	end
	hook(row, open)
	for _, child in ipairs(row:GetDescendants()) do
		if child:IsA("GuiObject") then
			hook(child, open)
		end
	end
	return open
end

style.paint(function()
	if not panel or not panel.Parent then
		return
	end
	panel.BackgroundColor3 = values().panel
	edge.Color = values().line
	title_label.TextColor3 = values().text
	if close_button then
		icons.tint(close_button, values().muted)
	end
	for _, child in ipairs(action_list:GetChildren()) do
		if child:IsA("TextButton") then
			child.BackgroundColor3 = values().hover
		end
	end
end)

S.options = options
