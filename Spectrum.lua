local S = {}

do
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local tws = game:GetService("TweenService")
local uis = game:GetService("UserInputService")

local env = {}
env.tws = tws
env.uis = uis
env.mobile = uis.TouchEnabled and not uis.KeyboardEnabled

local function player_gui()
	if env.player_gui and env.player_gui.Parent then
		return env.player_gui
	end
	local player = Players.LocalPlayer
	if not player then
		return env.player_gui
	end
	local gui = player:FindFirstChildOfClass("PlayerGui")
	if not gui then
		gui = player:WaitForChild("PlayerGui")
	end
	env.player_gui = gui
	return gui
end

env.player_gui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")

local function sweep(holder)
	if not holder then
		return
	end
	pcall(function()
		for _, item in ipairs(holder:GetChildren()) do
			if string.sub(item.Name, 1, 8) == "Spectrum" then
				item:Destroy()
			end
		end
	end)
end

sweep(CoreGui)
sweep(player_gui())

local holder = nil
do
	local probe = Instance.new("ScreenGui")
	local placed = pcall(function()
		probe.Parent = CoreGui
	end)
	if placed then
		holder = CoreGui
	else
		holder = player_gui()
	end
	probe:Destroy()
end
if not holder then
	holder = player_gui()
end
if not holder then
	error("[Spectrum] no PlayerGui available for the interface", 0)
end

local function layer(name, order)
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = order
	pcall(function()
		gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	end)
	gui.Parent = holder
	return gui
end

env.windows = layer("Spectrum", 10)
env.notes = layer("SpectrumNotes", 15)
env.modal = layer("SpectrumModal", 20)
env.launcher = layer("SpectrumLauncher", 30)

function env.viewport()
	local camera = Workspace.CurrentCamera
	local size = camera and camera.ViewportSize
	if not size or size.X < 64 or size.Y < 64 then
		return Vector2.new(1280, 720)
	end
	return size
end

S.env = env
end

do
local style = {}

local defaults = {
	accent = Color3.fromRGB(10, 132, 255),
	background = Color3.fromRGB(16, 17, 20),
	panel = Color3.fromRGB(28, 29, 33),
	hover = Color3.fromRGB(37, 38, 43),
	raised = Color3.fromRGB(23, 24, 28),
	text = Color3.fromRGB(238, 239, 242),
	muted = Color3.fromRGB(148, 150, 158),
	line = Color3.fromRGB(46, 48, 54),
	good = Color3.fromRGB(90, 214, 154),
	warn = Color3.fromRGB(255, 190, 100),
	bad = Color3.fromRGB(255, 96, 112),
	ink = Color3.fromRGB(12, 15, 22),
	radius = 4,
}

local values = {}
for key, value in pairs(defaults) do
	values[key] = value
end

local painters = {}
local color_keys = {
	"accent",
	"background",
	"panel",
	"hover",
	"raised",
	"text",
	"muted",
	"line",
	"good",
	"warn",
	"bad",
	"ink",
}

function style.paint(fn)
	painters[#painters + 1] = fn
	fn()
end

function style.copy()
	local copy = {}
	for key, value in pairs(values) do
		copy[key] = value
	end
	return copy
end

function style.apply(props)
	if type(props) ~= "table" then
		return style.copy()
	end
	for _, key in ipairs(color_keys) do
		if typeof(props[key]) == "Color3" then
			values[key] = props[key]
		end
	end
	if typeof(props.radius) == "number" then
		values.radius = math.clamp(props.radius, 0, 12)
	end
	for _, painter in ipairs(painters) do
		pcall(painter)
	end
	return style.copy()
end

function style.on(color)
	local luma = color.R * 0.299 + color.G * 0.587 + color.B * 0.114
	if luma > 0.6 then
		return values.ink
	end
	return Color3.new(1, 1, 1)
end

style.values = values
S.style = style
end

do
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
	local shade = util.new("ImageLabel", {
		Name = "shade",
		Active = false,
		BackgroundTransparency = 1,
		Image = "rbxassetid://5554236805",
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(23, 23, 277, 277),
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = (transparency or 0.55) - 0.05,
		Visible = object.Visible,
		Parent = object.Parent,
	})
	local function sync_shade()
		shade.Position = UDim2.new(
			object.Position.X.Scale,
			object.Position.X.Offset - 10,
			object.Position.Y.Scale,
			object.Position.Y.Offset - 8
		)
		shade.Size = UDim2.new(
			object.Size.X.Scale,
			object.Size.X.Offset + 20,
			object.Size.Y.Scale,
			object.Size.Y.Offset + 22
		)
		shade.ZIndex = math.max(object.ZIndex - 1, 0)
		shade.Visible = object.Visible
	end
	sync_shade()
	for _, property in ipairs({ "Position", "Size", "ZIndex", "Visible" }) do
		object:GetPropertyChangedSignal(property):Connect(sync_shade)
	end
	object.Destroying:Connect(function()
		if shade.Parent then
			shade:Destroy()
		end
	end)
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
end

do
local util = S.util
local style = S.style
local icons = {}

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
end

do
local env = S.env
local util = S.util
local modal = {}

modal.gui = env.modal
modal.current = nil

local blocker = util.new("TextButton", {
	Name = "blocker",
	BackgroundTransparency = 1,
	Text = "",
	AutoButtonColor = false,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
	ZIndex = 1,
	Parent = env.modal,
})
modal.blocker = blocker

function modal.dismiss()
	local closer = modal.current
	modal.current = nil
	blocker.Visible = false
	if closer then
		closer()
	end
end

function modal.claim(closer)
	local previous = modal.current
	modal.current = nil
	if previous then
		previous()
	end
	modal.current = closer
	blocker.Visible = true
end

function modal.drop(closer)
	if modal.current == closer then
		modal.current = nil
		blocker.Visible = false
	end
end

blocker.Activated:Connect(modal.dismiss)
S.modal = modal
end

do
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
end

do
local config = {}

local ROOT = "spectrum/configs"
local profile = "default"
local data = {}
local windows = {}
local registry = {}
local window_counts = {}
local value_counts = {}
local scheduled = false

local http
do
	local ok, service = pcall(function()
		return game:GetService("HttpService")
	end)
	if ok then
		http = service
	end
end

local function fresh()
	return {
		version = 1,
		windows = {},
		values = {},
		settings = {},
	}
end

data = fresh()

local function name_of(value)
	local out = tostring(value or "default"):gsub("[^%w_%- ]", "_")
	if out == "" then
		out = "default"
	end
	return out
end

local function path(name)
	return ROOT .. "/" .. name .. ".json"
end

local function can_read()
	return type(isfile) == "function" and type(readfile) == "function"
end

local function can_write()
	return type(writefile) == "function" and type(makefolder) == "function"
end

local function ensure(folder)
	if type(makefolder) ~= "function" then
		return
	end
	local built = ""
	for part in string.gmatch(folder, "[^/]+") do
		built = built == "" and part or (built .. "/" .. part)
		if type(isfolder) ~= "function" or not isfolder(built) then
			pcall(makefolder, built)
		end
	end
end

local function snake_key(key)
	return string.lower(string.gsub(key, "(%l)(%u)", "%1_%2"))
end

local function normalize()
	data.windows = type(data.windows) == "table" and data.windows or {}
	data.values = type(data.values) == "table" and data.values or {}
	data.settings = type(data.settings) == "table" and data.settings or {}
	local keys = {}
	for key in pairs(data.settings) do
		keys[#keys + 1] = key
	end
	for _, key in ipairs(keys) do
		if type(key) == "string" then
			local normalized = snake_key(key)
			if normalized ~= key then
				if data.settings[normalized] == nil then
					data.settings[normalized] = data.settings[key]
				end
				data.settings[key] = nil
			end
		end
	end

end

local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for key, item in pairs(value) do
		out[key] = copy(item)
	end
	return out
end

local function encode()
	if not http then
		return nil
	end
	local ok, body = pcall(function()
		return http:JSONEncode(data)
	end)
	return ok and body or nil
end

local function decode(body)
	if not http then
		return
	end
	local ok, parsed = pcall(function()
		return http:JSONDecode(body)
	end)
	if ok and type(parsed) == "table" then
		data = parsed
	end
	normalize()
end

function config.load(name)
	if name then
		profile = name_of(name)
	end
	data = fresh()
	if can_read() and isfile(path(profile)) then
		local ok, body = pcall(readfile, path(profile))
		if ok and type(body) == "string" and body ~= "" then
			decode(body)
		end
	elseif shared.SpectrumConfigs and type(shared.SpectrumConfigs[profile]) == "table" then
		data = copy(shared.SpectrumConfigs[profile])
		normalize()
	end
	return config.apply()
end

function config.save(name)
	if name then
		profile = name_of(name)
	end
	normalize()
	local body = encode()
	if body and can_write() then
		ensure(ROOT)
		pcall(writefile, path(profile), body)
	end
	shared.SpectrumConfigs = shared.SpectrumConfigs or {}
	shared.SpectrumConfigs[profile] = copy(data)
	return body ~= nil
end

function config.touch()
	if scheduled then
		return
	end
	scheduled = true
	task.delay(0.8, function()
		scheduled = false
		config.save()
	end)
end

function config.window_key(title)
	local name = tostring(title or "Window")
	local count = (window_counts[name] or 0) + 1
	window_counts[name] = count
	if count == 1 then
		return name
	end
	return name .. "#" .. count
end

function config.window_state(key)
	return data.windows[key]
end

function config.place(key, state)
	data.windows[key] = state
	config.touch()
end

function config.attach_window(key, api)
	windows[key] = api
	local saved = data.windows[key]
	if saved and api.restore then
		pcall(api.restore, saved)
	end
end

function config.bind(win, kind, label, api)
	local base = kind .. ":" .. tostring(label or "")
	value_counts[win] = value_counts[win] or {}
	local count = (value_counts[win][base] or 0) + 1
	value_counts[win][base] = count
	local key = count == 1 and base or (base .. "#" .. count)
	registry[win] = registry[win] or {}
	registry[win][key] = api
	local saved = data.values[win] and data.values[win][key]
	if saved ~= nil and api.set then
		pcall(api.set, saved)
	end
	return key
end

function config.put(win, key, value)
	data.values[win] = data.values[win] or {}
	data.values[win][key] = value
	config.touch()
end

function config.apply()
	for win, items in pairs(registry) do
		local saved = data.values[win]
		if saved then
			for key, api in pairs(items) do
				local value = saved[key]
				if value ~= nil and api.set then
					pcall(api.set, value)
				end
			end
		end
	end
	for win, api in pairs(windows) do
		local saved = data.windows[win]
		if saved and api.restore then
			pcall(api.restore, saved)
		end
	end
	return true
end

function config.toggle_key(value)
	if value ~= nil then
		data.settings.toggle_key = tostring(value)
		config.touch()
	end
	return data.settings and data.settings.toggle_key
end

function config.launcher_state()
	return data.settings and data.settings.launcher
end

function config.place_launcher(state)
	if type(state) ~= "table" then
		return
	end
	data.settings.launcher = {
		v = 2,
		x = tonumber(state.x) or 12,
		y = tonumber(state.y) or 720,
	}
	config.touch()
end

function config.flush()
	config.save()
end

function config.profile()
	return profile
end

S.config = config
end

do
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
		Name = "SpectrumLauncher",
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

	table.insert(
		links,
		env.uis.InputChanged:Connect(function(input)
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
		end)
	)

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
end

do
local env = S.env
local util = S.util
local style = S.style
local icons = S.icons
local bold = Enum.Font.GothamBold
local font = Enum.Font.GothamMedium

local holder = util.new("Frame", {
	Name = "notifications",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -12, 1, -12),
	Size = UDim2.fromOffset(env.mobile and 268 or 250, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Parent = env.notes,
})

util.new("UIListLayout", {
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	VerticalAlignment = Enum.VerticalAlignment.Bottom,
	Parent = holder,
})

local noted = 0

local function notify(title, body, duration, kind)
	noted = noted + 1
	duration = duration or 3
	local tint = style.values.accent
	if kind == "good" then
		tint = style.values.good
	elseif kind == "warn" then
		tint = style.values.warn
	elseif kind == "bad" then
		tint = style.values.bad
	end

	local height = env.mobile and 64 or 58
	local wrap = util.new("Frame", {
		Name = "note",
		BackgroundTransparency = 1,
		LayoutOrder = noted,
		Size = UDim2.new(1, 0, 0, height),
		Parent = holder,
	})

	local face = util.new("Frame", {
		Name = "face",
		BackgroundColor3 = style.values.panel,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.fromScale(1, 1),
		Parent = wrap,
	})
	util.corner(face, 6)
	local edge = util.stroke(face, style.values.line, 1)
	util.shadow(face, 14, 0.55)

	local chip = util.new("Frame", {
		Name = "chip",
		BackgroundColor3 = tint,
		BackgroundTransparency = 0.84,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
		Parent = face,
	})
	util.corner(chip, 7)
	local chip_edge = util.stroke(chip, tint, 0.45)
	local badge = icons.kind(kind, chip, 14, tint)
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.new(0.5, 0, 0.5, 0)
	icons.layer(badge, 2)

	local heading = util.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(48, 8),
		Size = UDim2.new(1, -68, 0, 14),
		Font = bold,
		Text = title or "Spectrum",
		TextColor3 = style.values.text,
		TextSize = 11,
		TextTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = face,
	})

	local caption = util.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(48, 25),
		Size = UDim2.new(1, -68, 0, 26),
		Font = font,
		Text = body or "",
		TextColor3 = style.values.muted,
		TextSize = 10,
		TextTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = face,
	})

	local close_hit = util.new("TextButton", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(18, 18),
		Text = "",
		AutoButtonColor = false,
		ZIndex = 5,
		Parent = face,
	})
	local close_icon = icons.close(close_hit, 10, style.values.muted)
	close_icon.AnchorPoint = Vector2.new(0.5, 0.5)
	close_icon.Position = UDim2.new(0.5, 0, 0.5, 0)
	icons.layer(close_icon, 6)

	local rail = util.new("Frame", {
		BackgroundColor3 = style.values.line,
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 12, 1, -5),
		Size = UDim2.new(1, -24, 0, 2),
		Parent = face,
	})

	local line = util.new("Frame", {
		BackgroundColor3 = tint,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = rail,
	})

	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		util.tween(face, 0.16, { BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 4) })
		util.tween(edge, 0.16, { Transparency = 1 })
		util.tween(heading, 0.14, { TextTransparency = 1 })
		util.tween(caption, 0.14, { TextTransparency = 1 })
		util.tween(chip, 0.14, { BackgroundTransparency = 1 })
		util.tween(chip_edge, 0.14, { Transparency = 1 })
		util.tween(rail, 0.14, { BackgroundTransparency = 1 })
		util.tween(line, 0.14, { BackgroundTransparency = 1 })
		for _, child in ipairs(badge:GetDescendants()) do
			if child:IsA("Frame") then
				util.tween(child, 0.14, { BackgroundTransparency = 1 })
			end
		end
		for _, child in ipairs(close_icon:GetDescendants()) do
			if child:IsA("Frame") then
				util.tween(child, 0.14, { BackgroundTransparency = 1 })
			end
		end
		task.delay(0.18, function()
			wrap:Destroy()
		end)
	end

	local hit = util.new("TextButton", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		AutoButtonColor = false,
		ZIndex = 1,
		Parent = face,
	})
	hit.Activated:Connect(close)
	close_hit.Activated:Connect(close)

	util.tween(face, 0.2, { BackgroundTransparency = 0, Position = UDim2.fromOffset(0, 0) })
	util.tween(edge, 0.2, { Transparency = 0.8 })
	util.tween(heading, 0.2, { TextTransparency = 0 })
	util.tween(caption, 0.2, { TextTransparency = 0 })
	util.tween(line, duration, { Size = UDim2.fromScale(0, 1) }, Enum.EasingStyle.Linear, Enum.EasingDirection.In)
	task.delay(duration, close)

	return close
end
S.notify = notify
end

do
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
local GuiService = game:GetService("GuiService")
local inset_ok, inset = pcall(function()
	return GuiService:GetGuiInset()
end)
local safe_top = (inset_ok and inset and math.max(env.mobile and 70 or 80, math.floor(inset.Y + 2))) or (env.mobile and 70 or 80)

local function content_cap(view, header_height)
	return math.max(120, math.floor(math.min(view.Y * 0.56, view.Y - safe_top - header_height - 16)))
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
	local preferred = opts.width or (mobile and math.min(272, vp.X - 20) or 276)
	if saved and type(saved.width) == "number" then
		preferred = saved.width
	end
	local width = math.clamp(preferred, math.min(210, vp.X - 20), math.max(210, vp.X - 20))
	local head = mobile and 38 or 34
	local row_base = mobile and 40 or 32
	local cap = content_cap(vp, head)
	local order = 0
	local open = not (saved and saved.open == false)
	local start = spot(width)
	if saved and type(saved.x) == "number" and type(saved.y) == "number" then
		start = UDim2.fromOffset(math.clamp(saved.x, -(width - 70), vp.X - 70), math.clamp(saved.y, safe_top, vp.Y - head - 4))
	end
	local links = {}
	local panels = {}
	local section_cursor
	local dragging = false
	local resizing = false
	local drag_from, drag_at, resize_from, resize_at

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
		Size = UDim2.fromOffset(mobile and 34 or 24, mobile and 12 or 10),
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

	local function fit(animate)
		local content_height = math.max(0, list.AbsoluteContentSize.Y + 2)
		local height = math.clamp(content_height, 34, cap)
		scroll.CanvasSize = UDim2.fromOffset(0, content_height)
		scroll.Size = UDim2.new(1, 0, 0, height)
		grip.Visible = open
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
			resize_from = width
			resize_at = input.Position.X
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

	local function follow(input)
		local moving = input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
		if not moving then
			return
		end
		local view = env.viewport()
		if dragging then
			local delta = input.Position - drag_from
			local x = math.clamp(drag_at.X.Offset + delta.X, -(width - 70), view.X - 70)
			local y = math.clamp(drag_at.Y.Offset + delta.Y, safe_top, view.Y - head - 4)
			root.Position = UDim2.fromOffset(x, y)
		elseif resizing then
			local next_width = math.clamp(resize_from + (input.Position.X - resize_at), math.min(210, view.X - 20), view.X - 20)
			if math.abs(next_width - width) >= 1 then
				width = next_width
				preferred = width
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

	local function refit()
		local view = env.viewport()
		if view.X <= 0 or view.Y <= 0 then
			return
		end
		width = math.clamp(preferred, math.min(210, view.X - 20), math.max(210, view.X - 20))
		cap = content_cap(view, head)
		root.Position = UDim2.fromOffset(
			math.clamp(root.Position.X.Offset, -math.max(0, width - 70), math.max(0, view.X - 70)),
			math.clamp(root.Position.Y.Offset, safe_top, math.max(safe_top, view.Y - head - 4))
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

	function w._slot(height, ungrouped)
		order = order + 1
		local slot = util.new("Frame", {
			Name = "slot",
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, height or row_base),
			Parent = scroll,
		})
		if section_cursor and not ungrouped then
			section_cursor.slots[#section_cursor.slots + 1] = slot
			slot.Visible = section_cursor.open
		end
		return slot
	end

	function w._new_section()
		return { open = true, slots = {} }
	end

	function w._focus_section(record)
		section_cursor = record
	end

	function w._toggle_section(record, state)
		if not record then
			return
		end
		if state == nil then
			state = not record.open
		end
		record.open = state
		for _, slot in ipairs(record.slots) do
			if slot.Parent then
				slot.Visible = state
			end
		end
		if w._fit then
			task.defer(function()
				if w.Gui and w.Gui.Parent and w._fit then
					w._fit(true)
				end
			end)
		end
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

	config.attach_window(key, {
		restore = function(state)
			local view = env.viewport()
			if type(state.width) == "number" then
				width = math.clamp(state.width, math.min(210, view.X - 20), math.max(210, view.X - 20))
				root.Size = UDim2.fromOffset(width, root.Size.Y.Offset)
			end
			if type(state.x) == "number" and type(state.y) == "number" then
				root.Position = UDim2.fromOffset(math.clamp(state.x, -(width - 70), view.X - 70), math.clamp(state.y, safe_top, math.max(safe_top, view.Y - head - 4))
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
		fold_bar_h.BackgroundColor3 = values().muted
		fold_bar_v.BackgroundColor3 = values().muted
		close_a.BackgroundColor3 = values().muted
		close_b.BackgroundColor3 = values().muted
		scroll.ScrollBarImageColor3 = values().muted
		for _, pip in ipairs(pips) do
			pip.BackgroundColor3 = values().muted
		end
	end)

	fit(false)
	return w
end

S.window = Window
end

do
local env = S.env
local util = S.util
local style = S.style
local icons = S.icons
local bold = Enum.Font.GothamBold
local font = Enum.Font.GothamMedium
local inputs = {}

local function values()
	return style.values
end

local function label(parent, text, y, height)
	return util.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, y or 0),
		Size = UDim2.new(1, -90, 0, height or 14),
		Font = font,
		Text = tostring(text or ""),
		TextColor3 = values().text,
		TextSize = util.size(11),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = parent,
	})
end

local function row_emblem(parent, icon, size, color, y)
	if type(icon) ~= "string" or icon == "" then
		return nil
	end
	local emblem = icons.image(parent, icon, size or 14, color or values().muted)
	if not emblem then
		return nil
	end
	if y then
		emblem.AnchorPoint = Vector2.new(0, 0)
		emblem.Position = UDim2.fromOffset(10, y)
	else
		emblem.AnchorPoint = Vector2.new(0, 0.5)
		emblem.Position = UDim2.new(0, 10, 0.5, 0)
	end
	icons.layer(emblem, 4)
	return emblem
end

function inputs.button(win, text, callback, icon)
	local mobile = win._mobile
	local holder = win._slot(mobile and 46 or 32)
	local btn = util.new("TextButton", {
		Name = "button",
		BackgroundColor3 = values().accent,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -16, 0, mobile and 36 or 24),
		Font = bold,
		Text = tostring(text or "Button"),
		TextColor3 = style.on(values().accent),
		TextSize = util.size(mobile and 11 or 9),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = holder,
	})
	util.corner(btn)
	local emblem
	if type(icon) == "string" and icon ~= "" then
		emblem = icons.image(btn, icon, 14, style.on(values().accent))
		if emblem then
			emblem.AnchorPoint = Vector2.new(0, 0.5)
			emblem.Position = UDim2.new(0, 10, 0.5, 0)
			icons.layer(emblem, 4)
		end
	end
	local pop = util.new("UIScale", { Parent = btn })
	local held = false

	local function face()
		if held then
			return values().accent:Lerp(Color3.new(1, 1, 1), 0.14)
		end
		return values().accent
	end

	btn.MouseEnter:Connect(function()
		held = true
		util.tween(btn, 0.12, { BackgroundColor3 = face() })
	end)
	btn.MouseLeave:Connect(function()
		held = false
		util.tween(btn, 0.15, { BackgroundColor3 = face() })
	end)
	btn.Activated:Connect(function()
		if callback then
			callback()
		end
	end)
	btn.MouseButton1Down:Connect(function()
		util.tween(pop, 0.08, { Scale = 0.97 }, Enum.EasingStyle.Quad)
	end)
	btn.MouseButton1Up:Connect(function()
		util.tween(pop, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	end)

	style.paint(function()
		btn.BackgroundColor3 = face()
		btn.TextColor3 = style.on(values().accent)
		if emblem then
			icons.tint(emblem, style.on(values().accent))
		end
	end)

	win._options(holder, text, function()
		return {
			{ label = "Run action", icon = "arrow", accent = true, run = callback },
		}
	end)

	win._fit(true)
	return btn
end
function inputs.toggle(win, text, a, b, opts)
	local mobile = win._mobile
	local state, changed
	if type(a) == "function" then
		changed = a
		state = false
	else
		state = a == true
		changed = b
	end
	if type(opts) == "string" then
		opts = { style = opts }
	elseif type(opts) ~= "table" then
		opts = {}
	end
	local kind = tostring(opts.style or "switch"):lower()
	local checkbox = kind == "checkbox" or kind == "check"
	local row = win._row()
	local initial = state
	local heading = label(row, text, 0)
	local emblem = row_emblem(row, opts.icon, 14, values().muted)
	local inset = checkbox and 44 or 64
	if emblem then
		inset = inset + 18
		heading.Position = UDim2.fromOffset(28, 0)
	end
	heading.Size = UDim2.new(1, -inset, 1, 0)

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

	local pop
	local sync
	if checkbox then
		local size = mobile and 20 or 16
		local box = util.new("Frame", {
			Name = "checkbox",
			BackgroundColor3 = values().raised,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(size, size),
			ZIndex = 3,
			Parent = row,
		})
		util.corner(box, 3)
		local edge = util.stroke(box, values().line, 0.15)
		pop = util.new("UIScale", { Parent = box })
		local check = util.new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 4,
			Parent = box,
		})
		local short = util.new("Frame", {
			BackgroundColor3 = values().ink,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.34, 0.6),
			Rotation = 45,
			Size = UDim2.new(0, size * 0.3, 0, math.max(1, size * 0.11)),
			ZIndex = 5,
			Parent = check,
		})
		local long = util.new("Frame", {
			BackgroundColor3 = values().ink,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.59, 0.51),
			Rotation = -45,
			Size = UDim2.new(0, size * 0.52, 0, math.max(1, size * 0.11)),
			ZIndex = 5,
			Parent = check,
		})

		sync = function()
			check.Visible = state
			local tint = state and values().accent or values().raised
			util.tween(box, 0.12, { BackgroundColor3 = tint })
			edge.Color = state and values().accent or values().line
			edge.Transparency = state and 1 or 0.15
			local ink = state and style.on(values().accent) or values().ink
			short.BackgroundColor3 = ink
			long.BackgroundColor3 = ink
		end
	else
		local width = mobile and 40 or 36
		local height = mobile and 20 or 18
		local thumb_size = height - 4
		local track = util.new("Frame", {
			Name = "switch_track",
			BackgroundColor3 = state and values().accent or values().raised,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(width, height),
			ZIndex = 3,
			Parent = row,
		})
		util.corner(track, height / 2)
		local edge = util.stroke(track, state and values().accent or values().line, state and 1 or 0.2)
		local thumb = util.new("Frame", {
			Name = "switch_thumb",
			BackgroundColor3 = state and Color3.new(1, 1, 1) or values().muted,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, state and (width - thumb_size - 2) or 2, 0.5, 0),
			Size = UDim2.fromOffset(thumb_size, thumb_size),
			ZIndex = 4,
			Parent = track,
		})
		util.corner(thumb, thumb_size / 2)
		pop = util.new("UIScale", { Parent = track })

		sync = function()
			local x = state and (width - thumb_size - 2) or 2
			util.tween(thumb, 0.16, {
				Position = UDim2.new(0, x, 0.5, 0),
				BackgroundColor3 = state and Color3.new(1, 1, 1) or values().muted,
			}, Enum.EasingStyle.Quart)
			util.tween(track, 0.14, { BackgroundColor3 = state and values().accent or values().raised })
			edge.Color = state and values().accent or values().line
			edge.Transparency = state and 1 or 0.2
		end
	end

	local key
	local function set(value, fire)
		state = value == true
		sync()
		pop.Scale = 0.9
		util.tween(pop, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
		if fire then
			win._store(key, state)
			if changed then
				changed(state)
			end
		end
	end

	hit.Activated:Connect(function()
		set(not state, true)
	end)

	style.paint(function()
		row.BackgroundColor3 = values().hover
		hit.BackgroundColor3 = values().hover
		heading.TextColor3 = values().text
		if emblem then
			icons.tint(emblem, values().muted)
		end
		sync()
	end)

	sync()
	key = win._bind("toggle", text, {
		set = function(value)
			set(value, false)
		end,
	})
	win._options(row, text, function()
		return {
			{ label = state and "Turn off" or "Turn on", icon = "sliders", accent = true, run = function() set(not state, true) end },
			{ label = "Reset to default", icon = "arrow", run = function() set(initial, true) end },
		}
	end)
	win._fit(true)

	return {
		Set = function(_, value)
			set(value, false)
		end,
		Get = function()
			return state
		end,
		Toggle = function()
			set(not state, true)
		end,
		Gui = row,
	}
end

function inputs.slider(win, text, min, max, default, callback, step, icon)
	local mobile = win._mobile
	local row = win._row(mobile and 46 or 40)
	local low = tonumber(min) or 0
	local high = tonumber(max) or 100
	if high <= low then
		high = low + 1
	end
	local notch = tonumber(step) or 1
	if notch <= 0 then
		notch = 1
	end
	local initial = math.clamp(tonumber(default) or low, low, high)
	local value = initial
	local decimals = notch >= 1 and 0 or (notch >= 0.1 and 1 or 2)

	local emblem = row_emblem(row, icon, 14, values().muted, mobile and 7 or 5)
	local name = label(row, text, mobile and 7 or 5, 14)
	if emblem then
		name.Position = UDim2.fromOffset(28, mobile and 7 or 5)
		name.Size = UDim2.new(1, -100, 0, 14)
	else
		name.Size = UDim2.new(1, -80, 0, 14)
	end

	local readout = util.new("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, mobile and 6 or 4),
		Size = UDim2.fromOffset(62, 14),
		Font = bold,
		Text = "",
		TextColor3 = values().muted,
		TextSize = util.size(10),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 3,
		Parent = row,
	})

	local track = util.new("Frame", {
		BackgroundColor3 = values().raised,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 10, 0, mobile and 31 or 27),
		Size = UDim2.new(1, -20, 0, mobile and 5 or 4),
		ZIndex = 3,
		Parent = row,
	})
	util.corner(track, 3)

	local fill = util.new("Frame", {
		BackgroundColor3 = values().accent,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 4,
		Parent = track,
	})
	util.corner(fill, 3)

	local thumb = util.new("Frame", {
		BackgroundColor3 = values().accent,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(6, mobile and 16 or 13),
		ZIndex = 5,
		Parent = track,
	})
	util.corner(thumb, 3)

	local hit = util.new("TextButton", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Position = UDim2.new(0, 4, 0, mobile and 20 or 17),
		Size = UDim2.new(1, -8, 0, 22),
		Text = "",
		ZIndex = 2,
		Parent = row,
	})

	local dragging = false
	local key
	local function paint_value(fire)
		local alpha = (value - low) / (high - low)
		fill.Size = UDim2.fromScale(alpha, 1)
		thumb.Position = UDim2.new(alpha, 0, 0.5, 0)
		readout.Text = string.format("%." .. decimals .. "f", value)
		readout.TextColor3 = dragging and values().accent or values().muted
		if fire then
			win._store(key, value)
			if callback then
				callback(value)
			end
		end
	end

	local function apply(next, fire)
		value = math.clamp(tonumber(next) or value, low, high)
		paint_value(fire)
	end

	local function snap(x)
		local alpha = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
		local raw = low + (high - low) * alpha
		local stepped = math.floor((raw - low) / notch + 0.5) * notch + low
		return math.clamp(math.floor(stepped * 1000 + 0.5) / 1000, low, high)
	end

	local function begin(input)
		dragging = true
		win._scroll.ScrollingEnabled = false
		thumb.Size = UDim2.fromOffset(7, mobile and 18 or 15)
		value = snap(input.Position.X)
		paint_value(true)
	end

	hit.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			begin(input)
		end
	end)

	win._link(env.uis.InputChanged, function(input)
		if not dragging then
			return
		end
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseMovement or kind == Enum.UserInputType.Touch then
			value = snap(input.Position.X)
			paint_value(true)
		end
	end)

	win._link(env.uis.InputEnded, function(input)
		local kind = input.UserInputType
		if dragging and (kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch) then
			dragging = false
			win._scroll.ScrollingEnabled = true
			thumb.Size = UDim2.fromOffset(6, mobile and 16 or 13)
			paint_value(false)
		end
	end)

	style.paint(function()
		track.BackgroundColor3 = values().raised
		fill.BackgroundColor3 = values().accent
		thumb.BackgroundColor3 = values().accent
		name.TextColor3 = values().text
		readout.TextColor3 = dragging and values().accent or values().muted
		if emblem then
			icons.tint(emblem, values().muted)
		end
	end)

	paint_value(false)
	key = win._bind("slider", text, {
		set = function(value)
			apply(value, false)
		end,
	})
	win._options(row, text, function()
		return {
			{ label = "Reset to default", icon = "arrow", run = function() apply(initial, true) end },
			{ label = "Set minimum", run = function() apply(low, true) end },
			{ label = "Set maximum", run = function() apply(high, true) end },
		}
	end)
	win._fit(true)

	return {
		Set = function(_, next)
			apply(next, false)
		end,
		Get = function()
			return value
		end,
		Gui = row,
	}
end

function inputs.keybind(win, text, default, callback, icon)
	local mobile = win._mobile
	local row = win._row(mobile and 40 or 34)
	row.ClipsDescendants = true
	local initial = default
	local emblem = row_emblem(row, icon, 14, values().muted)
	local caption = label(row, text, 0)
	if emblem then
		caption.Position = UDim2.fromOffset(28, 0)
		caption.Size = UDim2.new(1, -136, 1, 0)
	else
		caption.Size = UDim2.new(1, -128, 1, 0)
	end

	local pill = util.new("TextButton", {
		BackgroundColor3 = values().raised,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		ClipsDescendants = true,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(mobile and 96 or 84, mobile and 30 or 22),
		Font = bold,
		Text = default or "None",
		TextColor3 = values().muted,
		TextSize = util.size(9),
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
		Parent = row,
	})
	util.corner(pill, 3)
	local edge = util.stroke(pill, values().line, 0.35)
	util.hover(pill)

	local key = default
	local listening = false
	local held = {}
	local stored

	local function display(value)
		if value == nil or value == "" then
			return "None"
		end
		local label = tostring(value)
		label = label:gsub("RightControl", "RCtrl")
		label = label:gsub("LeftControl", "LCtrl")
		label = label:gsub("RightShift", "RShift")
		label = label:gsub("LeftShift", "LShift")
		label = label:gsub("RightAlt", "RAlt")
		label = label:gsub("LeftAlt", "LAlt")
		label = label:gsub("Backspace", "Bksp")
		label = label:gsub("Escape", "Esc")
		if #label > 14 then
			label = string.sub(label, 1, 12) .. "..."
		end
		return label
	end

	local function sync()
		pill.Text = listening and "..." or display(key)
		pill.TextColor3 = listening and values().accent or (key and values().text or values().muted)
		edge.Color = listening and values().accent or values().line
	end

	pill.Activated:Connect(function()
		listening = not listening
		S.binding = listening
		sync()
	end)

	row.Destroying:Connect(function()
		if listening then
			listening = false
			S.binding = false
		end
	end)

	win._link(env.uis.InputBegan, function(input)
		if listening then
			if input.UserInputType == Enum.UserInputType.Keyboard then
				local code = input.KeyCode
				if code == Enum.KeyCode.Escape then
					listening = false
					S.binding = false
					sync()
					return
				end
				key = code.Name
				listening = false
				S.binding = false
				sync()
				win._store(stored, key)
				held[code] = true
				if callback then
					callback(key, true)
				end
			end
			return
		end
		if key and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode.Name == key then
			held[input.KeyCode] = true
			if callback then
				callback(key, true)
			end
		end
	end)

	win._link(env.uis.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode.Name == key and held[input.KeyCode] then
			held[input.KeyCode] = nil
			if callback then
				callback(key, false)
			end
		end
	end)

	style.paint(function()
		edge.Color = listening and values().accent or values().line
		pill.BackgroundColor3 = values().raised
		caption.TextColor3 = values().text
		if emblem then
			icons.tint(emblem, values().muted)
		end
		sync()
	end)

	sync()
	stored = win._bind("key", text, {
		set = function(value)
			key = value
			sync()
		end,
	})
	win._options(row, text, function()
		return {
			{ label = "Clear key", icon = "close", run = function()
				key = nil
				sync()
				win._store(stored, key)
				if callback then
					callback(key, false)
				end
			end },
			{ label = "Reset to default", icon = "arrow", run = function()
				key = initial
				sync()
				win._store(stored, key)
			end },
		}
	end)
	win._fit(true)

	return {
		Set = function(_, next)
			key = next
			sync()
		end,
		Get = function()
			return key
		end,
		Gui = row,
	}
end
S.inputs = inputs
end

do
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
	local row = win._row(mobile and 40 or 34)
	local name = caption(row, title)
	name.Size = UDim2.new(0.48, -20, 1, 0)
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
		TextSize = util.size(10),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = row,
	})

	local chevron = util.chevron(row, 8, values().muted)
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
			Size = UDim2.fromOffset(20, 16),
			Font = bold,
			Text = "0",
			TextColor3 = style.on(values().accent),
			TextSize = util.size(9),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			Visible = false,
			ZIndex = 4,
			Parent = row,
		})
		util.corner(count_badge, 5)
	end

	local pad = 4
	local item_h = mobile and 34 or 28
	local bulk_h = (multi and #choices > 0) and (mobile and 28 or 24) or 0
	local bulk_gap = bulk_h > 0 and 1 or 0
	local min_height = math.max(32, pad * 2 + bulk_h + bulk_gap)
	local desired_height = math.clamp(#choices * item_h + pad * 2 + bulk_h + bulk_gap, 40, mobile and 226 or 190)
	local panel = util.new("Frame", {
		Name = "dropdown",
		Active = true,
		BackgroundColor3 = values().panel,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = UDim2.fromOffset(200, 0),
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
				TextSize = util.size(9),
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
		clear_action, clear_hit = action("clear", "Clear", mobile and 42 or 38, 0)
		select_all_action, select_all_hit = action("select_all", "Select all", mobile and 58 or 54, -(mobile and 46 or 42))
	end

	local area = util.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(pad, pad + bulk_h + bulk_gap),
		Size = UDim2.new(1, -pad * 2, 1, -(pad * 2 + bulk_h + bulk_gap)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 2,
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
			local width = math.min(math.max(size.X + 8, 180), math.max(160, win_w - 12))
			local x = math.clamp(rel_x - 4, 6, math.max(6, win_w - width - 6))
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
			TextSize = util.size(11),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 12,
			Parent = area,
		})
		local mark_size = mobile and 16 or 14
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
end

do
local util = S.util
local style = S.style
local icons = S.icons
local bold = Enum.Font.GothamBold
local font = Enum.Font.GothamMedium
local text = {}

local function values()
	return style.values
end

local function label(parent, title)
	return util.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -90, 0, 14),
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

function text.section(win, title, icon)
	local height = win._mobile and 32 or 28
	local holder = win._slot(height, true)
	local record = win._new_section()
	local band = util.new("Frame", {
		BackgroundColor3 = values().panel,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = holder,
	})
	local tick = util.new("Frame", {
		BackgroundColor3 = values().accent,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, height / 2 - 6),
		Size = UDim2.fromOffset(2, 12),
		ZIndex = 3,
		Parent = band,
	})
	local caption = util.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 0),
		Size = UDim2.new(1, -44, 1, 0),
		Font = bold,
		Text = tostring(title or "Section"),
		TextColor3 = values().text,
		TextSize = util.size(11),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = band,
	})
	local emblem
	if type(icon) == "string" and icon ~= "" then
		emblem = icons.image(band, icon, 14, values().accent)
		if emblem then
			tick.Visible = false
			emblem.Position = UDim2.fromOffset(10, height / 2 - 7)
			emblem.ZIndex = 3
			caption.Position = UDim2.fromOffset(29, 0)
			caption.Size = UDim2.new(1, -53, 1, 0)
		end
	end
	local bottom = util.new("Frame", {
		BackgroundColor3 = values().line,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, -1),
		Size = UDim2.new(1, 0, 0, 1),
		ZIndex = 3,
		Parent = band,
	})
	local chevron = util.chevron(band, 8, values().muted)
	chevron.AnchorPoint = Vector2.new(0.5, 0.5)
	chevron.Position = UDim2.new(1, -14, 0.5, 0)
	chevron.ZIndex = 4
	chevron.Rotation = 180

	local hit = util.new("TextButton", {
		BackgroundColor3 = values().hover,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		ZIndex = 7,
		Parent = band,
	})
	local hovered = false
	local function tint_band(on)
		hovered = on
		util.tween(band, 0.1, { BackgroundColor3 = on and values().hover or values().panel })
	end
	hit.MouseEnter:Connect(function()
		tint_band(true)
	end)
	hit.MouseLeave:Connect(function()
		tint_band(false)
	end)
	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			tint_band(true)
		end
	end)
	hit.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			tint_band(false)
		end
	end)

	local function set_open(state, animate)
		if state == nil then
			state = not record.open
		end
		win._toggle_section(record, state)
		if animate then
			util.tween(chevron, 0.15, { Rotation = state and 180 or 0 })
		else
			chevron.Rotation = state and 180 or 0
		end
	end

	hit.Activated:Connect(function()
		set_open(nil, true)
	end)

	style.paint(function()
		band.BackgroundColor3 = values().panel
		tick.BackgroundColor3 = values().accent
		caption.TextColor3 = values().text
		bottom.BackgroundColor3 = values().line
		band.BackgroundColor3 = hovered and values().hover or values().panel
		if emblem then
			icons.tint(emblem, values().accent)
		end
	end)

	win._focus_section(record)
	win._fit(true)

	return {
		Header = caption,
		Toggle = function(_, state)
			set_open(state, true)
		end,
		Open = function()
			set_open(true, true)
		end,
		Close = function()
			set_open(false, true)
		end,
		IsOpen = function()
			return record.open
		end,
	}
end
function text.label(win, body)
	local holder = win._slot(0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	util.new("UIPadding", {
		PaddingTop = UDim.new(0, 7),
		PaddingBottom = UDim.new(0, 7),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 12),
		Parent = holder,
	})
	local caption = util.new("TextLabel", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		Font = font,
		Text = tostring(body or ""),
		TextColor3 = values().muted,
		TextSize = util.size(10),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 2,
		Parent = holder,
	})

	style.paint(function()
		caption.TextColor3 = values().muted
	end)

	win._fit(true)
	return caption
end

function text.separator(win)
	local holder = win._slot(9)
	local bar = util.new("Frame", {
		BackgroundColor3 = values().line,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 0, 1),
		Parent = holder,
	})

	style.paint(function()
		bar.BackgroundColor3 = values().line
	end)

	win._fit(true)
	return bar
end

function text.textbox(win, title, default, callback, icon)
	local mobile = win._mobile
	local row = win._row(mobile and 58 or 34)
	row.ClipsDescendants = true
	local initial = default
	local name = label(row, title)
	local emblem
	if type(icon) == "string" and icon ~= "" then
		emblem = icons.image(row, icon, 14, values().muted)
		if emblem then
			icons.layer(emblem, 4)
			if mobile then
				emblem.AnchorPoint = Vector2.new(0, 0)
				emblem.Position = UDim2.fromOffset(10, 7)
			else
				emblem.AnchorPoint = Vector2.new(0, 0.5)
				emblem.Position = UDim2.new(0, 10, 0.5, 0)
			end
		end
	end
	if mobile then
		name.Position = UDim2.fromOffset(emblem and 28 or 10, 7)
		name.Size = UDim2.new(1, emblem and -46 or -20, 0, 14)
	else
		name.Position = UDim2.fromOffset(emblem and 28 or 10, 0)
		name.Size = UDim2.new(0.4, emblem and -34 or -16, 1, 0)
	end
	local box
	if mobile then
		box = util.new("TextBox", {
			Name = "textbox",
			BackgroundColor3 = values().raised,
			BorderSizePixel = 0,
			ClearTextOnFocus = false,
			Font = font,
			PlaceholderColor3 = values().muted,
			PlaceholderText = "Enter text",
			Position = UDim2.new(0, 10, 0, 27),
			Size = UDim2.new(1, -20, 0, 26),
			Text = tostring(default or ""),
			TextColor3 = values().text,
			TextSize = util.size(11),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 3,
			Parent = row,
		})
	else
		box = util.new("TextBox", {
			Name = "textbox",
			BackgroundColor3 = values().raised,
			BorderSizePixel = 0,
			ClearTextOnFocus = false,
			Font = font,
			PlaceholderColor3 = values().muted,
			PlaceholderText = "Enter text",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.new(0.52, 0, 0, 22),
			Text = tostring(default or ""),
			TextColor3 = values().text,
			TextSize = util.size(11),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 3,
			Parent = row,
		})
	end
	util.corner(box)
	util.new("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = box,
	})
	local edge = util.stroke(box, values().line, 0.2)
	local stored

	box.Focused:Connect(function()
		edge.Color = values().accent
		edge.Transparency = 0.2
	end)
	box.FocusLost:Connect(function()
		edge.Color = values().line
		edge.Transparency = 0.2
		win._store(stored, box.Text)
		if callback then
			callback(box.Text)
		end
	end)

	style.paint(function()
		box.BackgroundColor3 = values().raised
		box.TextColor3 = values().text
		box.PlaceholderColor3 = values().muted
		edge.Color = values().line
		name.TextColor3 = values().text
		if emblem then
			icons.tint(emblem, values().muted)
		end
	end)

	stored = win._bind("text", title, {
		set = function(value)
			box.Text = tostring(value)
		end,
	})
	win._options(row, title, function()
		return {
			{ label = "Clear text", icon = "close", run = function()
				box.Text = ""
				win._store(stored, "")
				if callback then
					callback("")
				end
			end },
			{ label = "Reset to default", icon = "arrow", run = function()
				box.Text = tostring(initial or "")
				win._store(stored, box.Text)
				if callback then
					callback(box.Text)
				end
			end },
		}
	end)
	win._fit(true)

	return {
		Set = function(_, value)
			box.Text = tostring(value)
		end,
		Get = function()
			return box.Text
		end,
		Focus = function()
			box:CaptureFocus()
		end,
		Gui = row,
	}
end

S.text = text
end

do
local env = S.env
local config = S.config
local Library = {}
Library.Version = "3.1"

config.load()
local DEFAULT_MENU_KEY = "RightControl+LeftShift"
local menu_key = DEFAULT_MENU_KEY
local menu_open = true
local mobile_launcher
local menu_held = {}
local combo_fired = false

local function normalize_key(value)
	local text = tostring(value or ""):gsub("%s+", "")
	if text == "" then
		return DEFAULT_MENU_KEY
	end
	if text == "RightShift" then
		return DEFAULT_MENU_KEY
	end
	return text
end

local function combo_keys()
	local keys = {}
	for part in string.gmatch(menu_key, "[^+]+") do
		keys[#keys + 1] = part
	end
	return keys
end

local function combo_label(value)
	local label = tostring(value or "")
	label = label:gsub("LeftControl", "LCtrl")
	label = label:gsub("RightControl", "RCtrl")
	label = label:gsub("LeftShift", "LShift")
	label = label:gsub("RightShift", "RShift")
	label = label:gsub("LeftAlt", "LAlt")
	label = label:gsub("RightAlt", "RAlt")
	return label
end

local function all_held()
	local keys = combo_keys()
	if #keys == 0 then
		return false
	end
	for _, key in ipairs(keys) do
		if not menu_held[key] then
			return false
		end
	end
	return true
end

local saved_toggle = config.toggle_key()
if saved_toggle then
	menu_key = normalize_key(saved_toggle)
end
if config.toggle_key() ~= menu_key then
	config.toggle_key(menu_key)
end

local function set_menu(state)
	menu_open = state ~= false
	for _, root in ipairs(S.window.roots) do
		if root.Parent then
			root.Visible = menu_open
		end
	end
	env.notes.Enabled = menu_open
	if not menu_open then
		S.modal.dismiss()
	end
	if mobile_launcher then
		mobile_launcher.set_open(menu_open)
	end
	return menu_open
end

function Library:Design(props)
	return S.style.apply(props)
end

function Library:GetDesign()
	return S.style.copy()
end

function Library:Notify(title, body, duration, kind)
	return S.notify(title, body, duration, kind)
end

function Library:Window(title, opts)
	local win = S.window.new(title, opts)
	win.Gui.Visible = menu_open

	win.button = function(self, text, callback, icon)
		return S.inputs.button(self, text, callback, icon)
	end
	win.toggle = function(self, text, a, b, opts)
		return S.inputs.toggle(self, text, a, b, opts)
	end
	win.slider = function(self, text, min, max, default, callback, step, icon)
		return S.inputs.slider(self, text, min, max, default, callback, step, icon)
	end
	win.keybind = function(self, text, default, callback, icon)
		return S.inputs.keybind(self, text, default, callback, icon)
	end
	win.dropdown = function(self, text, options, default, callback, multi, icon)
		return S.selects.dropdown(self, text, options, default, callback, multi, icon)
	end
	win.colorpicker = function(self, text, default, callback, icon)
		return S.selects.colorpicker(self, text, default, callback, icon)
	end
	win.textbox = function(self, text, default, callback, icon)
		return S.text.textbox(self, text, default, callback, icon)
	end
	win.section = function(self, text, icon)
		return S.text.section(self, text, icon)
	end
	win.label = function(self, text)
		return S.text.label(self, text)
	end
	win.separator = function(self)
		return S.text.separator(self)
	end

	return win
end

function Library:ToggleUI(state)
	if state == nil then
		state = not menu_open
	end
	return set_menu(state)
end

function Library:SetMobileButton(enabled)
	if enabled == nil then
		enabled = not mobile_launcher
	end
	if enabled then
		if not mobile_launcher then
			mobile_launcher = S.launcher.mount(function()
				Library:ToggleUI()
			end)
		end
		if mobile_launcher then
			mobile_launcher.set_open(menu_open)
		end
	elseif mobile_launcher then
		mobile_launcher.destroy()
		mobile_launcher = nil
	end
	return mobile_launcher ~= nil
end

function Library:SetToggleKey(key)
	if type(key) == "table" then
		key = table.concat(key, "+")
	end
	menu_key = normalize_key(key)
	config.toggle_key(menu_key)
	menu_held = {}
	combo_fired = false
	S.notify("Spectrum", "Menu key set to " .. combo_label(menu_key), 2, "info")
end

function Library:GetToggleKey()
	return menu_key
end

function Library:SaveConfig(name)
	return config.save(name)
end

function Library:LoadConfig(name)
	config.load(name)
	menu_key = normalize_key(config.toggle_key())
	menu_held = {}
	combo_fired = false
	return true
end

function Library:SetProfile(name)
	return Library:LoadConfig(name)
end

function Library:GetProfile()
	return config.profile()
end

local function focused_text_box()
	local focused
	pcall(function()
		focused = env.uis:GetFocusedTextBox()
	end)
	return focused ~= nil
end

local menu_link = env.uis.InputBegan:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	if S.binding or focused_text_box() then
		return
	end
	local name = input.KeyCode.Name
	if name == "Unknown" then
		return
	end
	menu_held[name] = true
	if not combo_fired and all_held() then
		combo_fired = true
		Library:ToggleUI()
	end
end)

local menu_release = env.uis.InputEnded:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	menu_held[input.KeyCode.Name] = nil
	if not all_held() then
		combo_fired = false
	end
end)

function Library:Destroy()
	config.flush()
	if menu_link then
		menu_link:Disconnect()
		menu_link = nil
	end
	if menu_release then
		menu_release:Disconnect()
		menu_release = nil
	end
	if mobile_launcher then
		mobile_launcher.destroy()
		mobile_launcher = nil
	end
	for _, root in ipairs(S.window.roots) do
		if root.Parent then
			root:Destroy()
		end
	end
	S.env.windows:Destroy()
	S.env.modal:Destroy()
	S.env.notes:Destroy()
	S.env.launcher:Destroy()
	if shared.Spectrum == Library then
		shared.Spectrum = nil
	end
end

pcall(function()
	game:BindToClose(function()
		config.flush()
	end)
end)

if env.mobile then
	mobile_launcher = S.launcher.mount(function()
		Library:ToggleUI()
	end)
	if mobile_launcher then
		mobile_launcher.set_open(menu_open)
	end
end

S.library = Library
end
