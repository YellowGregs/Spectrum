local S = ...

local env = S.env
local util = S.util
local style = S.style
local icons = S.icons
local config = S.config

local launcher = {}
local SIZE = 46

local function values()
	return style.values
end

function launcher.mount(on_toggle)
	local saved = config.launcher_state()
-- just ignores old states once and start fresh
	if type(saved) == "table" and saved.v == 2 then
		local sx, sy = tonumber(saved.x), tonumber(saved.y)
		if not sx or not sy or sx < 0 then
			saved = nil
		else
			saved = { x = sx, y = sy }
		end
	else
		saved = nil
	end

	local GuiService = game:GetService("GuiService")
	local inset_ok, inset = pcall(function()
		return GuiService:GetGuiInset()
	end)
	local safe_top = math.max(0, (inset_ok and inset and inset.Y or 0) + 8)

	local function centered(view)
		return math.floor((view.X - SIZE) / 2), safe_top + SIZE
	end

	local function clamp_position(x, y)
		local next_view = env.viewport()
		local min_y = safe_top + SIZE
		return math.clamp(tonumber(x) or 12, 0, math.max(0, next_view.X - SIZE)),
			math.clamp(tonumber(y) or min_y, min_y, math.max(min_y, next_view.Y))
	end

	local view = env.viewport()
	local start_x, start_y = centered(view)
	if saved then
		start_x, start_y = saved.x, saved.y
	end
	start_x, start_y = clamp_position(start_x, start_y)
	local user_moved = saved ~= nil

	local button = util.new("TextButton", {
		Name = env.gui_name("launcher_button"),
		BackgroundColor3 = values().panel,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromOffset(start_x, start_y),
		Size = UDim2.fromOffset(SIZE, SIZE),
		Text = "",
		ZIndex = 2,
		Parent = env.launcher,
	})
	util.corner(button, 13)
	local edge = util.stroke(button, values().line, 0.05)
	util.shadow(button, 14, 0.5)

	local menu = icons.image(button, "menu", 19, values().text)
	menu.AnchorPoint = Vector2.new(0.5, 0.5)
	menu.Position = UDim2.new(0.5, 0, 0.5, 0)
	icons.layer(menu, 4)

	local close = icons.image(button, "close", 15, values().text)
	close.AnchorPoint = Vector2.new(0.5, 0.5)
	close.Position = UDim2.new(0.5, 0, 0.5, 0)
	close.Visible = false
	icons.layer(close, 4)

	local pop = util.new("UIScale", { Parent = button })
	local open = true
	local alive = true
	local dragging = false
	local moved = false
	local drag_from = Vector2.new()
	local drag_at = Vector2.new()
	local links = {}

	local function sync()
		if not alive then
			return
		end
		button.BackgroundColor3 = values().panel
		edge.Color = open and values().accent or values().line
		menu.Visible = not open
		close.Visible = open
		icons.tint(menu, values().text)
		icons.tint(close, values().text)
	end

	local function remember()
		config.place_launcher({
			x = button.Position.X.Offset,
			y = button.Position.Y.Offset,
		})
	end

	local function animate()
		pop.Scale = 0.9
		util.tween(pop, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	end

	button.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			dragging = true
			moved = false
			drag_from = input.Position
			drag_at = Vector2.new(button.Position.X.Offset, button.Position.Y.Offset)
		end
	end)

	table.insert(links, env.uis.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.MouseMovement and kind ~= Enum.UserInputType.Touch then
			return
		end
		local delta = input.Position - drag_from
		if not moved and delta.Magnitude < 4 then
			return
		end
		moved = true
		user_moved = true
		button.Position = UDim2.fromOffset(clamp_position(drag_at.X + delta.X, drag_at.Y + delta.Y))
	end))

	table.insert(
		links,
		env.uis.InputEnded:Connect(function(input)
			if not dragging then
				return
			end
			local kind = input.UserInputType
			if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
				return
			end
			dragging = false
			if moved then
				remember()
			else
				animate()
				if on_toggle then
					on_toggle()
				end
			end
		end)
	)

	local camera
	local camera_link
	local function watch_camera()
		if camera_link then
			camera_link:Disconnect()
			camera_link = nil
		end
		camera = workspace.CurrentCamera
		if camera then
			camera_link = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				if user_moved then
					button.Position = UDim2.fromOffset(clamp_position(button.Position.X.Offset, button.Position.Y.Offset))
				else
					button.Position = UDim2.fromOffset(clamp_position(centered(env.viewport())))
				end
			end)
		end
	end
	watch_camera()
	table.insert(links, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watch_camera))

	style.paint(sync)
	sync()

	return {
		Gui = button,
		Position = function()
			return button.Position
		end,
		set_open = function(state)
			open = state ~= false
			sync()
		end,
		destroy = function()
			alive = false
			for _, link in ipairs(links) do
				pcall(function()
					link:Disconnect()
				end)
			end
			table.clear(links)
			if camera_link then
				pcall(function()
					camera_link:Disconnect()
				end)
				camera_link = nil
			end
			button:Destroy()
		end,
	}
end

S.launcher = launcher
