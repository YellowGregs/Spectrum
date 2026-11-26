local S = ...

local env = S.env
local style = S.style
local white = Color3.new(1, 1, 1)
local running = {}
local util = {}

function util.new(class, props)
	local object = Instance.new(class)
	if props then
		for property, value in pairs(props) do
			if property ~= "Parent" then
				object[property] = value
			end
		end
		object.Parent = props.Parent
	end
	if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
		local role = style.font_role(object.Font)
		if role then
			object:SetAttribute("SpectrumFontRole", role)
		end
	end
	return object
end

function util.font(object, role)
	local font
	if role == "regular" then
		font = style.values.font
	elseif role == "medium" then
		font = style.values.font_medium
	elseif role == "bold" then
		font = style.values.font_bold
	elseif role == "mono" then
		font = style.values.font_mono
	end
	if font then
		object.Font = font
	end
	if role then
		object:SetAttribute("SpectrumFontRole", role)
	end
	return object
end

local themed = {}

function util.corner(object, radius)
	local corner = util.new("UICorner", {
		CornerRadius = UDim.new(0, radius or style.values.radius),
		Parent = object,
	})
	if radius == nil then
		themed[#themed + 1] = corner
	end
	return corner
end

function util.stroke(object, color, transparency)
	return util.new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = color or white,
		Transparency = transparency or 0.85,
		Thickness = 1,
		Parent = object,
	})
end

local function has_layout(parent)
	if not parent then
		return true
	end
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("UILayout") then
			return true
		end
	end
	return false
end

function util.shadow(object, blur, transparency)
	if not object then
		return
	end
	blur = math.max(4, blur or 18)
	transparency = math.clamp(transparency or 0.42, 0.05, 0.95)
	local shade
	local built = pcall(function()
		shade = Instance.new("UIShadow")
		shade.BlurRadius = blur
		shade.Transparency = transparency
		shade.Offset = Vector2.new(0, math.max(2, math.floor(blur / 5)))
		shade.Color = Color3.new(0, 0, 0)
		shade.Parent = object
		pcall(function()
			shade.Spread = math.clamp(blur / 28, 0, 2)
		end)
		pcall(function()
			shade.Enabled = true
		end)
	end)

	local parent = object.Parent
	if parent and not has_layout(parent) then
		local offset = math.max(2, math.floor(blur / 18) + 1)
		local layer = util.new("Frame", {
			Name = "drop_shadow",
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = math.clamp(transparency + 0.25, 0.42, 0.92),
			BorderSizePixel = 0,
			AnchorPoint = object.AnchorPoint,
			Position = UDim2.new(
				object.Position.X.Scale,
				object.Position.X.Offset + offset,
				object.Position.Y.Scale,
				object.Position.Y.Offset + offset
			),
			Size = object.Size,
			Active = false,
			ZIndex = math.max(0, (object.ZIndex or 1) - 1),
			Parent = parent,
		})
		local corner = object:FindFirstChildOfClass("UICorner")
		if corner then
			pcall(function()
				local copy = Instance.new("UICorner")
				copy.CornerRadius = corner.CornerRadius
				copy.Parent = layer
			end)
		end

		local links = {}
		local function sync()
			if not layer.Parent then
				return
			end
			layer.AnchorPoint = object.AnchorPoint
			layer.Position = UDim2.new(
				object.Position.X.Scale,
				object.Position.X.Offset + offset,
				object.Position.Y.Scale,
				object.Position.Y.Offset + offset
			)
			layer.Size = object.Size
			layer.Visible = object.Visible
			layer.ZIndex = math.max(0, (object.ZIndex or 1) - 1)
		end
		for _, property in ipairs({ "Position", "Size", "AnchorPoint", "Visible", "ZIndex" }) do
			links[#links + 1] = object:GetPropertyChangedSignal(property):Connect(sync)
		end
		links[#links + 1] = object:GetPropertyChangedSignal("Parent"):Connect(function()
			if object.Parent and not has_layout(object.Parent) then
				layer.Parent = object.Parent
				sync()
			else
				layer:Destroy()
			end
		end)
		object.Destroying:Connect(function()
			for _, link in ipairs(links) do
				pcall(function()
					link:Disconnect()
				end)
			end
			layer:Destroy()
		end)
		sync()
	end

	if not built then
		return
	end
	return shade
end

function util.depth(object, strength)
	if not object then
		return
	end
	strength = math.clamp(strength or 1, 0.1, 2)
	local z = (object.ZIndex or 1) + 1
	local top_alpha = math.clamp(0.9 - 0.42 * strength, 0.34, 0.94)
	local bottom_alpha = math.clamp(0.72 - 0.32 * strength, 0.28, 0.9)
	local side_alpha = math.clamp(top_alpha + 0.08, 0.38, 0.96)
	local top = util.new("Frame", {
		Name = "depth_top",
		BackgroundColor3 = white,
		BackgroundTransparency = top_alpha,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, 0, 0, 1),
		Active = false,
		ZIndex = z,
		Parent = object,
	})
	local bottom = util.new("Frame", {
		Name = "depth_bottom",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = bottom_alpha,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -1),
		Size = UDim2.new(1, 0, 0, 1),
		Active = false,
		ZIndex = z,
		Parent = object,
	})
	local left = util.new("Frame", {
		Name = "depth_left",
		BackgroundColor3 = white,
		BackgroundTransparency = side_alpha,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 1),
		Size = UDim2.new(0, 1, 1, -2),
		Active = false,
		ZIndex = z,
		Parent = object,
	})
	local right = util.new("Frame", {
		Name = "depth_right",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = math.clamp(bottom_alpha + 0.06, 0.32, 0.94),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -1, 0, 1),
		Size = UDim2.new(0, 1, 1, -2),
		Active = false,
		ZIndex = z,
		Parent = object,
	})
	return top, bottom, left, right
end

function util.inset(object, strength)
	if not object then
		return
	end
	strength = math.clamp(strength or 1, 0.1, 2)
	local z = (object.ZIndex or 1) + 1
	local top_alpha = math.clamp(0.62 - 0.18 * strength, 0.34, 0.88)
	local bottom_alpha = math.clamp(0.88 - 0.2 * strength, 0.44, 0.96)
	local side_alpha = math.clamp(top_alpha + 0.08, 0.38, 0.94)
	local top = util.new("Frame", {
		Name = "inset_top",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = top_alpha,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1),
		Active = false,
		ZIndex = z,
		Parent = object,
	})
	local bottom = util.new("Frame", {
		Name = "inset_bottom",
		BackgroundColor3 = white,
		BackgroundTransparency = bottom_alpha,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -1),
		Size = UDim2.new(1, 0, 0, 1),
		Active = false,
		ZIndex = z,
		Parent = object,
	})
	local left = util.new("Frame", {
		Name = "inset_left",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = side_alpha,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 1),
		Size = UDim2.new(0, 1, 1, -2),
		Active = false,
		ZIndex = z,
		Parent = object,
	})
	local right = util.new("Frame", {
		Name = "inset_right",
		BackgroundColor3 = white,
		BackgroundTransparency = math.clamp(bottom_alpha + 0.18, 0.58, 0.98),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -1, 0, 1),
		Size = UDim2.new(0, 1, 1, -2),
		Active = false,
		ZIndex = z,
		Parent = object,
	})
	return top, bottom, left, right
end

function util.tween(object, time, props, ease, direction)
	local names = {}
	for name in pairs(props) do
		names[#names + 1] = name
	end
	table.sort(names)
	local id = table.concat(names, ",")
	local bucket = running[object]
	if not bucket then
		bucket = {}
		running[object] = bucket
	end
	if bucket[id] then
		bucket[id]:Cancel()
	end
	local spin = env.tws:Create(object, TweenInfo.new(time or 0.15, ease or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out), props)
	bucket[id] = spin
	spin:Play()
	return spin
end

function util.cancel(object)
	local bucket = running[object]
	if not bucket then
		return
	end
	for key, spin in pairs(bucket) do
		if spin and spin.Cancel then
			spin:Cancel()
		end
		bucket[key] = nil
	end
end

function util.hover(row, enter, leave)
	local function inside()
		util.tween(row, 0.1, { BackgroundTransparency = 0 })
		if enter then
			enter()
		end
	end
	local function outside()
		util.tween(row, 0.15, { BackgroundTransparency = 1 })
		if leave then
			leave()
		end
	end
	row.MouseEnter:Connect(inside)
	row.MouseLeave:Connect(outside)
	row.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			inside()
		end
	end)
	row.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			outside()
		end
	end)
end

function util.divider(parent)
	return util.new("Frame", {
		BackgroundColor3 = style.values.line,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 10, 1, -1),
		Size = UDim2.new(1, -20, 0, 1),
		ZIndex = 2,
		Parent = parent,
	})
end

function util.chevron(parent, size, color)
	local box = util.new("Frame", {
		Name = "chevron",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		Parent = parent,
	})
	local arm = size * 0.52
	util.new("Frame", {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, -size * 0.19, 0.5, 0),
		Rotation = 45,
		Size = UDim2.new(0, arm, 0, math.max(1, size * 0.14)),
		Parent = box,
	})
	util.new("Frame", {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, size * 0.19, 0.5, 0),
		Rotation = -45,
		Size = UDim2.new(0, arm, 0, math.max(1, size * 0.14)),
		Parent = box,
	})
	return box
end

function util.size(base)
	return base + (env.mobile and 1 or 0)
end

function util.input_id(input)
	if not input or not input.UserInputType then
		return nil
	end
	local kind = input.UserInputType
	local kind_name = kind.Name
	if kind == Enum.UserInputType.Keyboard then
		local name = input.KeyCode and input.KeyCode.Name or "Unknown"
		return name ~= "Unknown" and name or nil
	end
	if string.match(kind_name, "^MouseButton%d+$") then
		return kind_name
	end
	if string.match(kind_name, "^Gamepad%d+$") then
		local name = input.KeyCode and input.KeyCode.Name or "Unknown"
		return name ~= "Unknown" and name or nil
	end
	return nil
end

function util.input_label(value)
	local label = tostring(value or "None")
	local mouse = {
		MouseButton1 = "LMB",
		MouseButton2 = "RMB",
		MouseButton3 = "MMB",
	}
	if mouse[label] then
		return mouse[label]
	end
	label = label:gsub("^Button", "Pad ")
	label = label:gsub("RightControl", "RCtrl")
	label = label:gsub("LeftControl", "LCtrl")
	label = label:gsub("RightShift", "RShift")
	label = label:gsub("LeftShift", "LShift")
	label = label:gsub("RightAlt", "RAlt")
	label = label:gsub("LeftAlt", "LAlt")
	label = label:gsub("Backspace", "Bksp")
	label = label:gsub("Escape", "Esc")
	return label
end

function util.focused_text_box()
	local ok, box = pcall(function()
		return env.uis:GetFocusedTextBox()
	end)
	return ok and box or nil
end

style.paint(function()
	for _, corner in ipairs(themed) do
		if corner.Parent then
			corner.CornerRadius = UDim.new(0, style.values.radius)
		end
	end
end)

util.viewport = env.viewport
util.mobile = env.mobile
S.util = util
