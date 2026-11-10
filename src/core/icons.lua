local S = ...

local util = S.util
local style = S.style
local icons = {}

-- Lucide icon assets that i didnt skid off at all from somewhere hehe
local assets = {
	gear = "rbxassetid://10734950309",
	settings = "rbxassetid://10734950309",
	user = "rbxassetid://10747373176",
	target = "rbxassetid://10734977012",
	crosshair = "rbxassetid://10709818534",
	key = "rbxassetid://10723416652",
	arrow = "rbxassetid://10709768347",
	menu = "rbxassetid://10734887784",
	close = "rbxassetid://10747384394",
	plus = "rbxassetid://10734924532",
	search = "rbxassetid://10734943674",
	sliders = "rbxassetid://10734963191",
	eye = "rbxassetid://10723346959",
	render = "rbxassetid://10723346959",
	globe = "rbxassetid://10723404337",
	world = "rbxassetid://10723404337",
	bag = "rbxassetid://10734952273",
	inventory = "rbxassetid://10734952273",
	wrench = "rbxassetid://10747383470",
	utility = "rbxassetid://10747383470",
	bolt = "rbxassetid://10723345749",
	speed = "rbxassetid://10723345749",
	combat = "rbxassetid://10734975692",
	palette = "rbxassetid://10734910430",
	check = "rbxassetid://10709790644",
	cross = "rbxassetid://10747384394",
	save = "rbxassetid://10734941499",
	folder = "rbxassetid://10723387563",
	code = "rbxassetid://10709810463",
	shield = "rbxassetid://10734951847",
	alert = "rbxassetid://10709753149",
	info = "rbxassetid://10723415903",
	copy = "rbxassetid://10709812159",
	trash = "rbxassetid://10747362241",
	refresh = "rbxassetid://10734933222",
	move = "rbxassetid://10734900011",
	lock = "rbxassetid://10723434711",
}

local function values()
	return style.values
end

local function shell(parent, size)
	return util.new("Frame", {
		Name = "icon",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		ZIndex = (parent and parent.ZIndex or 1) + 1,
		Parent = parent,
	})
end

local function bar(parent, x, y, width, height, color, rotation)
	return util.new("Frame", {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Rotation = rotation or 0,
		Size = UDim2.new(0, width, 0, height),
		ZIndex = parent.ZIndex,
		Parent = parent,
	})
end

local function dot(parent, x, y, size, color)
	local mark = util.new("Frame", {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromOffset(size, size),
		ZIndex = parent.ZIndex,
		Parent = parent,
	})
	util.corner(mark, size / 2)
	return mark
end

local function ring(parent, x, y, size, color, thickness)
	local shape = util.new("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromOffset(size, size),
		ZIndex = parent.ZIndex,
		Parent = parent,
	})
	util.corner(shape, size / 2)
	local edge = util.stroke(shape, color, 0)
	edge.Thickness = thickness or 1
	return shape
end

function icons.check(parent, size, color)
	size = size or 14
	local frame = shell(parent, size)
	local tint = color or values().good
	local thick = math.max(1, math.floor(size * 0.13))
	bar(frame, 0.3, 0.58, size * 0.34, thick, tint, 45)
	bar(frame, 0.62, 0.46, size * 0.58, thick, tint, -45)
	return frame
end

function icons.cross(parent, size, color)
	size = size or 14
	local frame = shell(parent, size)
	local tint = color or values().bad
	local thick = math.max(1, math.floor(size * 0.13))
	bar(frame, 0.5, 0.5, size * 0.66, thick, tint, 45)
	bar(frame, 0.5, 0.5, size * 0.66, thick, tint, -45)
	return frame
end

function icons.alert(parent, size, color)
	size = size or 14
	local frame = shell(parent, size)
	local tint = color or values().warn
	local thick = math.max(1, math.floor(size * 0.16))
	bar(frame, 0.5, 0.4, thick, size * 0.42, tint)
	dot(frame, 0.5, 0.8, thick, tint)
	return frame
end

function icons.info(parent, size, color)
	size = size or 14
	local frame = shell(parent, size)
	local tint = color or values().accent
	local thick = math.max(1, math.floor(size * 0.16))
	dot(frame, 0.5, 0.25, thick, tint)
	bar(frame, 0.5, 0.61, thick, size * 0.34, tint)
	return frame
end

function icons.gear(parent, size, color)
	size = size or 14
	local frame = shell(parent, size)
	local tint = color or values().muted
	ring(frame, 0.5, 0.5, size * 0.5, tint, math.max(1, size * 0.11))
	for index = 0, 7 do
		local angle = math.rad(index * 45)
		bar(
			frame,
			0.5 + math.cos(angle) * 0.35,
			0.5 + math.sin(angle) * 0.35,
			size * 0.17,
			math.max(1, size * 0.11),
			tint,
			index * 45
		)
	end
	return frame
end

function icons.user(parent, size, color)
	size = size or 14
	local frame = shell(parent, size)
	local tint = color or values().muted
	dot(frame, 0.5, 0.3, size * 0.3, tint)
	local body = util.new("Frame", {
		BackgroundColor3 = tint,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.75),
		Size = UDim2.new(0, size * 0.56, 0, size * 0.26),
		Parent = frame,
	})
	util.corner(body, size)
	return frame
end

function icons.target(parent, size, color)
	size = size or 14
	local frame = shell(parent, size)
	local tint = color or values().muted
	ring(frame, 0.5, 0.5, size * 0.76, tint, 1)
	ring(frame, 0.5, 0.5, size * 0.38, tint, 1)
	dot(frame, 0.5, 0.5, size * 0.14, tint)
	return frame
end

function icons.key(parent, size, color)
	size = size or 14
	local frame = shell(parent, size)
	local tint = color or values().muted
	local thick = math.max(1, size * 0.13)
	ring(frame, 0.28, 0.5, size * 0.38, tint, thick)
	bar(frame, 0.66, 0.5, size * 0.4, thick, tint)
	bar(frame, 0.75, 0.62, thick, size * 0.16, tint)
	return frame
end

function icons.arrow(parent, size, color)
	size = size or 14
	local frame = shell(parent, size)
	local tint = color or values().muted
	local thick = math.max(1, size * 0.13)
	bar(frame, 0.45, 0.5, size * 0.36, thick, tint)
	bar(frame, 0.55, 0.5, size * 0.28, thick, tint, 45)
	bar(frame, 0.55, 0.5, size * 0.28, thick, tint, -45)
	return frame
end

function icons.menu(parent, size, color)
	size = size or 14
	local frame = shell(parent, size)
	local tint = color or values().text
	local thick = math.max(1, math.floor(size * 0.11))
	for index = 0, 2 do
		bar(frame, 0.5, 0.28 + index * 0.22, size * 0.6, thick, tint)
	end
	return frame
end

function icons.close(parent, size, color)
	size = size or 14
	local frame = shell(parent, size)
	local tint = color or values().muted
	local thick = math.max(1, math.floor(size * 0.12))
	bar(frame, 0.5, 0.5, size * 0.66, thick, tint, 45)
	bar(frame, 0.5, 0.5, size * 0.66, thick, tint, -45)
	return frame
end

function icons.plus(parent, size, color)
	size = size or 14
	local frame = shell(parent, size)
	local tint = color or values().muted
	local thick = math.max(1, math.floor(size * 0.13))
	bar(frame, 0.5, 0.5, size * 0.62, thick, tint)
	bar(frame, 0.5, 0.5, thick, size * 0.62, tint)
	return frame
end

function icons.search(parent, size, color)
	size = size or 14
	local frame = shell(parent, size)
	local tint = color or values().muted
	local thick = math.max(1, math.floor(size * 0.12))
	ring(frame, 0.43, 0.43, size * 0.52, tint, thick)
	bar(frame, 0.73, 0.73, size * 0.32, thick, tint, 45)
	return frame
end

function icons.sliders(parent, size, color)
	size = size or 14
	local frame = shell(parent, size)
	local tint = color or values().muted
	local thick = math.max(1, math.floor(size * 0.1))
	bar(frame, 0.5, 0.28, size * 0.62, thick, tint)
	bar(frame, 0.5, 0.5, size * 0.62, thick, tint)
	bar(frame, 0.5, 0.72, size * 0.62, thick, tint)
	dot(frame, 0.32, 0.28, size * 0.18, tint)
	dot(frame, 0.68, 0.5, size * 0.18, tint)
	dot(frame, 0.43, 0.72, size * 0.18, tint)
	return frame
end

function icons.eye(parent, size, color)
	size = size or 14
	local frame = shell(parent, size)
	local tint = color or values().muted
	local thick = math.max(1, math.floor(size * 0.11))
	bar(frame, 0.5, 0.35, size * 0.66, thick, tint, 12)
	bar(frame, 0.5, 0.65, size * 0.66, thick, tint, -12)
	dot(frame, 0.5, 0.5, size * 0.24, tint)
	return frame
end

function icons.globe(parent, size, color)
	size = size or 14
	local frame = shell(parent, size)
	local tint = color or values().muted
	local thick = math.max(1, math.floor(size * 0.085))
	ring(frame, 0.5, 0.5, size * 0.72, tint, thick)
	bar(frame, 0.5, 0.5, size * 0.62, thick, tint)
	bar(frame, 0.38, 0.5, math.max(1, thick * 0.8), size * 0.4, tint)
	bar(frame, 0.62, 0.5, math.max(1, thick * 0.8), size * 0.4, tint)
	return frame
end

function icons.bag(parent, size, color)
	size = size or 14
	local frame = shell(parent, size)
	local tint = color or values().muted
	local body = util.new("Frame", {
		BackgroundColor3 = tint,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.new(0, size * 0.58, 0, size * 0.42),
		ZIndex = frame.ZIndex,
		Parent = frame,
	})
	util.corner(body, 2)
	ring(frame, 0.5, 0.35, size * 0.4, tint, math.max(1, size * 0.09))
	return frame
end

function icons.wrench(parent, size, color)
	size = size or 14
	local frame = shell(parent, size)
	local tint = color or values().muted
	local thick = math.max(1, math.floor(size * 0.11))
	bar(frame, 0.52, 0.52, size * 0.56, thick, tint, -45)
	ring(frame, 0.28, 0.28, size * 0.34, tint, thick)
	ring(frame, 0.72, 0.72, size * 0.22, tint, thick)
	return frame
end

function icons.bolt(parent, size, color)
	size = size or 14
	local frame = shell(parent, size)
	local tint = color or values().muted
	local thick = math.max(1, math.floor(size * 0.11))
	bar(frame, 0.57, 0.34, size * 0.4, thick, tint, 64)
	bar(frame, 0.5, 0.5, size * 0.3, thick, tint)
	bar(frame, 0.43, 0.66, size * 0.4, thick, tint, 64)
	return frame
end

function icons.combat(parent, size, color)
	size = size or 14
	local frame = shell(parent, size)
	local tint = color or values().muted
	local thick = math.max(2, math.floor(size * 0.085))
	bar(frame, 0.5, 0.5, size * 0.72, thick, tint, 45)
	bar(frame, 0.5, 0.5, size * 0.72, thick, tint, -45)
	bar(frame, 0.27, 0.73, size * 0.23, thick, tint, -45)
	bar(frame, 0.73, 0.73, size * 0.23, thick, tint, 45)
	dot(frame, 0.18, 0.82, math.max(2, math.floor(size * 0.13)), tint)
	dot(frame, 0.82, 0.82, math.max(2, math.floor(size * 0.13)), tint)
	return frame
end

function icons.palette(parent, size, color)
	size = size or 14
	local frame = shell(parent, size)
	local tint = color or values().muted
	local thick = math.max(1, math.floor(size * 0.08))
	ring(frame, 0.5, 0.48, size * 0.68, tint, thick)
	dot(frame, 0.37, 0.37, size * 0.15, tint)
	dot(frame, 0.63, 0.37, size * 0.15, tint)
	dot(frame, 0.5, 0.65, size * 0.15, tint)
	return frame
end

function icons.save(parent, size, color)
	size = size or 14
	local frame = shell(parent, size)
	local tint = color or values().muted
	local body = util.new("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size * 0.62, size * 0.62),
		ZIndex = frame.ZIndex,
		Parent = frame,
	})
	util.corner(body, 2)
	local outline = util.stroke(body, tint, 0)
	outline.Thickness = 1
	bar(frame, 0.5, 0.3, size * 0.24, math.max(1, size * 0.1), tint)
	bar(frame, 0.5, 0.7, size * 0.3, math.max(1, size * 0.1), tint)
	return frame
end

function icons.folder(parent, size, color)
	size = size or 14
	local frame = shell(parent, size)
	local tint = color or values().muted
	local tab = util.new("Frame", {
		BackgroundColor3 = tint,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.36, 0.31),
		Size = UDim2.new(0, size * 0.3, 0, size * 0.16),
		ZIndex = frame.ZIndex,
		Parent = frame,
	})
	util.corner(tab, 2)
	local body = util.new("Frame", {
		BackgroundColor3 = tint,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.59),
		Size = UDim2.new(0, size * 0.68, 0, size * 0.4),
		ZIndex = frame.ZIndex,
		Parent = frame,
	})
	util.corner(body, 2)
	return frame
end

function icons.code(parent, size, color)
	size = size or 14
	local frame = shell(parent, size)
	local tint = color or values().muted
	local thick = math.max(1, math.floor(size * 0.095))
	bar(frame, 0.3, 0.43, size * 0.22, thick, tint, -45)
	bar(frame, 0.3, 0.57, size * 0.22, thick, tint, 45)
	bar(frame, 0.7, 0.43, size * 0.22, thick, tint, 45)
	bar(frame, 0.7, 0.57, size * 0.22, thick, tint, -45)
	bar(frame, 0.5, 0.5, size * 0.34, thick, tint, 68)
	return frame
end

function icons.shield(parent, size, color)
	size = size or 14
	local frame = shell(parent, size)
	local tint = color or values().muted
	local body = util.new("Frame", {
		BackgroundColor3 = tint,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.new(0, size * 0.56, 0, size * 0.45),
		ZIndex = frame.ZIndex,
		Parent = frame,
	})
	util.corner(body, 4)
	local point = util.new("Frame", {
		BackgroundColor3 = tint,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.61),
		Rotation = 45,
		Size = UDim2.fromOffset(size * 0.34, size * 0.34),
		ZIndex = frame.ZIndex,
		Parent = frame,
	})
	util.corner(point, 2)
	return frame
end

local named = {
	gear = icons.gear,
	settings = icons.gear,
	user = icons.user,
	target = icons.target,
	crosshair = icons.target,
	key = icons.key,
	arrow = icons.arrow,
	menu = icons.menu,
	close = icons.close,
	plus = icons.plus,
	search = icons.search,
	sliders = icons.sliders,
	eye = icons.eye,
	render = icons.eye,
	globe = icons.globe,
	world = icons.globe,
	bag = icons.bag,
	inventory = icons.bag,
	wrench = icons.wrench,
	utility = icons.wrench,
	bolt = icons.bolt,
	speed = icons.bolt,
	combat = icons.combat,
	palette = icons.palette,
	check = icons.check,
	cross = icons.cross,
	save = icons.save,
	folder = icons.folder,
	code = icons.code,
	shield = icons.shield,
}

function icons.kind(kind, parent, size, color)
	if kind == "good" then
		return icons.check(parent, size, color)
	elseif kind == "bad" then
		return icons.cross(parent, size, color)
	elseif kind == "warn" then
		return icons.alert(parent, size, color)
	end
	return icons.info(parent, size, color)
end

function icons.image(parent, asset, size, color)
	if type(asset) ~= "string" or asset == "" then
		return nil
	end
	local source = assets[asset]
	if source then
		asset = source
	else
		local build = named[asset]
		if build then
			return build(parent, size, color)
		end
	end
	if tonumber(asset) then
		asset = "rbxassetid://" .. asset
	end
	return util.new("ImageLabel", {
		Name = "image",
		BackgroundTransparency = 1,
		Image = asset,
		ImageColor3 = color or values().muted,
		ImageTransparency = 0,
		ImageRectSize = Vector2.new(),
		ImageRectOffset = Vector2.new(),
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromOffset(size or 14, size or 14),
		ZIndex = (parent and parent.ZIndex or 1) + 1,
		Parent = parent,
	})
end

function icons.layer(object, z)
	if not object then
		return
	end
	object.ZIndex = z
	local ok, descendants = pcall(function()
		return object:GetDescendants()
	end)
	if not ok then
		return
	end
	for _, child in ipairs(descendants) do
		if child:IsA("GuiObject") then
			child.ZIndex = z
		end
	end
end

function icons.tint(object, color)
	if not object then
		return
	end
	if object:IsA("ImageLabel") then
		object.ImageColor3 = color
		return
	end
	for _, child in ipairs(object:GetDescendants()) do
		if child:IsA("ImageLabel") then
			child.ImageColor3 = color
		elseif child:IsA("Frame") and child.BackgroundTransparency < 1 then
			child.BackgroundColor3 = color
		elseif child:IsA("UIStroke") then
			child.Color = color
		end
	end
end

S.icons = icons
