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

function util.shadow(object, blur, transparency)
	local built = pcall(function()
		local shade = Instance.new("UIShadow")
		shade.BlurRadius = blur or 14
		shade.Transparency = transparency or 0.55
		shade.Offset = Vector2.new(0, 4)
		shade.Color = Color3.new(0, 0, 0)
		shade.Parent = object
	end)
	if not built then
		return
	end
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
