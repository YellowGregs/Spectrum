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
	if built or not object.Parent then
		return
	end
	util.new("ImageLabel", {
		Name = "shade",
		BackgroundTransparency = 1,
		Image = "rbxassetid://5554236805",
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(23, 23, 277, 277),
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = (transparency or 0.55) - 0.05,
		Position = UDim2.fromOffset(-10, -8),
		Size = UDim2.new(1, 20, 1, 22),
		ZIndex = math.max(object.ZIndex - 1, 0),
		Parent = object.Parent,
	})
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
