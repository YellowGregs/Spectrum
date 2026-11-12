local S = {}

do

local cloneref = cloneref or function(obj)
	return obj
end

local Players = cloneref(game:GetService("Players"))
local CoreGui = cloneref(game:GetService("CoreGui"))
local Workspace = cloneref(game:GetService("Workspace"))
local tws = cloneref(game:GetService("TweenService"))
local uis = cloneref(game:GetService("UserInputService"))
local HttpService = cloneref(game:GetService("HttpService"))

local thread_fix = type(setthreadidentity) == "function"
if thread_fix then
	local ok = pcall(setthreadidentity, 8)
	if not ok then
		thread_fix = false
	end
end

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

local function hash_name(text)
	local value = 5381
	for index = 1, #text do
		value = (value * 33 + string.byte(text, index)) % 4294967296
	end
	return string.format("%08x", math.floor(value))
end

local session_name
do
	local ok, guid = pcall(function()
		return HttpService:GenerateGUID(false)
	end)
	if ok and type(guid) == "string" then
		session_name = string.gsub(guid, "-", ""):sub(1, 12)
	else
		session_name = string.format("%08x%04x", math.floor(os.clock() * 1000) % 4294967296, math.random(0, 0xFFFF))
	end
end

local function gui_name(label)
	return session_name .. "_" .. hash_name(tostring(label))
end
env.gui_name = gui_name

local previous_layers = shared.SpectrumLayers
if type(previous_layers) == "table" then
	for _, gui in ipairs(previous_layers) do
		pcall(function()
			if typeof(gui) == "Instance" and gui.Parent then
				gui:Destroy()
			end
		end)
	end
end
shared.SpectrumLayers = {}

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

local function can_parent(parent)
	if not parent then
		return false
	end
	local probe = Instance.new("ScreenGui")
	local placed = pcall(function()
		probe.Parent = parent
	end)
	probe:Destroy()
	return placed
end

local holder = nil
if thread_fix then
	local ok, hidden = pcall(function()
		return type(gethui) == "function" and gethui() or nil
	end)
	if ok and typeof(hidden) == "Instance" and can_parent(hidden) then
		holder = hidden
	elseif can_parent(CoreGui) then
		holder = CoreGui
	end
end

if not holder then
	holder = player_gui()
end
if not holder then
	error("[Spectrum] no PlayerGui available for the interface", 0)
end

local function layer(name, order)
	local gui = Instance.new("ScreenGui")
	gui.Name = gui_name(name)
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = order
	pcall(function()
		gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	end)
	if thread_fix then
		pcall(setthreadidentity, 8)
		pcall(function()
			gui.OnTopOfCoreBlur = true
		end)
	end
	gui.Parent = holder
	shared.SpectrumLayers[#shared.SpectrumLayers + 1] = gui
	return gui
end

env.windows = layer("windows", 10)
env.notes = layer("notes", 15)
env.modal = layer("modal", 20)
env.launcher = layer("launcher", 30)
env.splash = layer("splash", 40)

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

function style.variant(kind)
	local name = tostring(kind or "primary"):lower()
	if name == "danger" or name == "destructive" then
		return values.bad, style.on(values.bad)
	end
	if name == "secondary" or name == "surface" then
		return values.raised, values.text
	end
	return values.accent, style.on(values.accent)
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
end

do

local util = S.util
local style = S.style
local icons = {}

local lucide = {
	gear = "settings",
	settings = "settings",
	user = "user",
	target = "target",
	crosshair = "crosshair",
	key = "key",
	arrow = "arrow-right",
	menu = "menu",
	close = "x",
	plus = "plus",
	search = "search",
	sliders = "sliders-horizontal",
	eye = "eye",
	render = "eye",
	globe = "globe",
	world = "globe",
	bag = "shopping-bag",
	inventory = "shopping-bag",
	wrench = "wrench",
	utility = "wrench",
	bolt = "zap",
	speed = "zap",
	combat = "swords",
	palette = "palette",
	check = "check",
	cross = "x",
	save = "save",
	folder = "folder",
	code = "code",
	shield = "shield",
	alert = "triangle-alert",
	info = "info",
	copy = "copy",
	trash = "trash",
	refresh = "refresh-cw",
	move = "move",
	lock = "lock",
}

local ICON_ROOT = "Spectrum/icons/v1"
local SHEET_URL = "https://molto.pages.dev/spritesheets/lucide/%d.png"
local PNG_SIGNATURE = "\137PNG\r\n\26\n"
local SHEETS = {
	[1] = { width = 1024, height = 1024, bytes = 489862 },
	[2] = { width = 1024, height = 1024, bytes = 147010 },
}
local sprites = {
	["settings"] = { sheet = 1, x = 925, y = 925, w = 24, h = 24 },
	["user"] = { sheet = 2, x = 200, y = 475, w = 24, h = 24 },
	["target"] = { sheet = 2, x = 350, y = 200, w = 24, h = 24 },
	["crosshair"] = { sheet = 1, x = 825, y = 25, w = 24, h = 24 },
	["key"] = { sheet = 1, x = 625, y = 500, w = 24, h = 24 },
	["arrow-right"] = { sheet = 1, x = 0, y = 300, w = 24, h = 24 },
	["menu"] = { sheet = 1, x = 775, y = 500, w = 24, h = 24 },
	["x"] = { sheet = 2, x = 475, y = 275, w = 24, h = 24 },
	["plus"] = { sheet = 1, x = 925, y = 600, w = 24, h = 24 },
	["search"] = { sheet = 1, x = 950, y = 850, w = 24, h = 24 },
	["sliders-horizontal"] = { sheet = 2, x = 200, y = 25, w = 24, h = 24 },
	["eye"] = { sheet = 1, x = 200, y = 700, w = 24, h = 24 },
	["globe"] = { sheet = 1, x = 800, y = 250, w = 24, h = 24 },
	["shopping-bag"] = { sheet = 2, x = 125, y = 0, w = 24, h = 24 },
	["wrench"] = { sheet = 2, x = 525, y = 225, w = 24, h = 24 },
	["zap"] = { sheet = 2, x = 400, y = 350, w = 24, h = 24 },
	["swords"] = { sheet = 2, x = 350, y = 175, w = 24, h = 24 },
	["palette"] = { sheet = 1, x = 975, y = 450, w = 24, h = 24 },
	["check"] = { sheet = 1, x = 125, y = 525, w = 24, h = 24 },
	["save"] = { sheet = 1, x = 800, y = 900, w = 24, h = 24 },
	["folder"] = { sheet = 1, x = 350, y = 650, w = 24, h = 24 },
	["code"] = { sheet = 1, x = 400, y = 400, w = 24, h = 24 },
	["shield"] = { sheet = 2, x = 100, y = 0, w = 24, h = 24 },
	["triangle-alert"] = { sheet = 2, x = 350, y = 275, w = 24, h = 24 },
	["info"] = { sheet = 1, x = 975, y = 150, w = 24, h = 24 },
	["copy"] = { sheet = 1, x = 525, y = 300, w = 24, h = 24 },
	["trash"] = { sheet = 2, x = 575, y = 50, w = 24, h = 24 },
	["refresh-cw"] = { sheet = 1, x = 750, y = 850, w = 24, h = 24 },
	["move"] = { sheet = 1, x = 900, y = 475, w = 24, h = 24 },
	["lock"] = { sheet = 1, x = 700, y = 525, w = 24, h = 24 },
}

local custom_sheets = {}
local custom_failures = {}
local custom_supported
local cache_ready

local function custom_available()
	if custom_supported ~= nil then
		return custom_supported
	end
	custom_supported = (type(getcustomasset) == "function" or type(getsynasset) == "function")
		and type(writefile) == "function"
		and type(isfile) == "function"
		and type(makefolder) == "function"
	return custom_supported
end

local function prepare_cache()
	if cache_ready ~= nil then
		return cache_ready
	end
	cache_ready = false
	if not custom_available() then
		return false
	end
	local ok = pcall(function()
		for _, folder in ipairs({ "Spectrum", "Spectrum/icons", ICON_ROOT }) do
			if type(isfolder) ~= "function" or not isfolder(folder) then
				pcall(makefolder, folder)
			end
		end
	end)
	if ok then
		cache_ready = true
	end
	return cache_ready
end

local function png_size(data)
	if type(data) ~= "string" or #data < 24 or data:sub(1, #PNG_SIGNATURE) ~= PNG_SIGNATURE then
		return nil
	end
	local width = 0
	local height = 0
	for index = 0, 3 do
		width = width * 256 + data:byte(17 + index)
		height = height * 256 + data:byte(21 + index)
	end
	return width, height
end

local function valid_sheet(data, meta)
	if type(data) ~= "string" or #data ~= meta.bytes then
		return false
	end
	local width, height = png_size(data)
	return width == meta.width and height == meta.height
end

local function sheet_file(sheet)
	return ICON_ROOT .. "/lucide-" .. sheet .. ".png"
end

local function read_sheet(path, meta)
	if type(readfile) ~= "function" then
		return true
	end
	local ok, data = pcall(readfile, path)
	return ok and valid_sheet(data, meta)
end

local function download_sheet(sheet, path, meta)
	local ok, data = pcall(function()
		return game:HttpGet(string.format(SHEET_URL, sheet), true)
	end)
	if not ok or not valid_sheet(data, meta) then
		return false
	end
	return pcall(writefile, path, data)
end

local function custom_sheet(sheet)
	local cached = custom_sheets[sheet]
	if cached then
		return cached
	end
	if custom_failures[sheet] or not prepare_cache() then
		return nil
	end
	local meta = SHEETS[sheet]
	local path = sheet_file(sheet)
	local exists = false
	local ok, result = pcall(isfile, path)
	if ok and result == true then
		exists = read_sheet(path, meta)
	end
	if not exists and not download_sheet(sheet, path, meta) then
		custom_failures[sheet] = true
		return nil
	end
	local getter = getcustomasset or getsynasset
	local read_ok, asset = pcall(getter, path)
	if (not read_ok or type(asset) ~= "string" or asset == "") and download_sheet(sheet, path, meta) then
		read_ok, asset = pcall(getter, path)
	end
	if read_ok and type(asset) == "string" and asset ~= "" then
		custom_sheets[sheet] = asset
		return asset
	end
	custom_failures[sheet] = true
	return nil
end

local function sprite_label(parent, sprite, size, color)
	local source = custom_sheet(sprite.sheet)
	if not source then
		return nil
	end
	return util.new("ImageLabel", {
		Name = "image",
		BackgroundTransparency = 1,
		Image = source,
		ImageColor3 = color or style.values.muted,
		ImageTransparency = 0,
		ImageRectSize = Vector2.new(sprite.w, sprite.h),
		ImageRectOffset = Vector2.new(sprite.x, sprite.y),
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromOffset(size or 14, size or 14),
		ZIndex = (parent and parent.ZIndex or 1) + 1,
		Parent = parent,
	})
end

local function image_label(parent, source, size, color)
	return util.new("ImageLabel", {
		Name = "image",
		BackgroundTransparency = 1,
		Image = source,
		ImageColor3 = color or style.values.muted,
		ImageTransparency = 0,
		ImageRectSize = Vector2.new(),
		ImageRectOffset = Vector2.new(),
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromOffset(size or 14, size or 14),
		ZIndex = (parent and parent.ZIndex or 1) + 1,
		Parent = parent,
	})
end

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
	alert = icons.alert,
	info = icons.info,
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
	local lucide_name = lucide[asset]
	if lucide_name then
		local sprite = sprites[lucide_name]
		if sprite then
			local label = sprite_label(parent, sprite, size, color)
			if label then
				return label
			end
		end
		local build = named[asset]
		if build then
			return build(parent, size, color)
		end
		return nil
	end
	local build = named[asset]
	if build then
		return build(parent, size, color)
	end
	if tonumber(asset) then
		asset = "rbxassetid://" .. asset
	end
	if not (
		asset:match("^rbxassetid://%d+$")
		or asset:match("^rbxthumb://")
		or asset:match("^rbxasset://")
		or asset:match("^https?://")
	) then
		return nil
	end
	return image_label(parent, asset, size, color)
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

local brand = {}
local DATA = table.concat({
	"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",
	"z2P8+PGy76tUKmE2m3HZZZdhyJAh2LVrV4MRsE4GAbgJwJcAzI1B/vkxxlLcTf7hqbshISHCijtK/eWaOD8/n8LCwkilUolc7Ftu",
	"uYUA0MiRI4mI6M477ySNRkO5ubk0dOhQUcE1evTo5jrnvcly1NVqNa1fv96tY9Klx5xzfsXRHHFLl5yc7NJ5jDwjjlvkwsJCKi0t",
	"JZ1OZxMJZGVl0fbt22n//v20b98+OnToEJ06dYpOnDhB27dvp/z8fCovL6eamhqXv6M7vIPUNeFt5Y1GI+3fv9+pG8nnxlbzkGZI",
	"DOJoXAugR0NzAdzSj/Qk9s8hJIfsrjb84B17uK+1e/duAXtXrVpFRUVFBICefvppWrdunSCoXn/9dYqLi2u1PACfA966ytUj0ywJ",
	"1qKiImrXrp1Doopv3HHjxsmUs1arpdLSUiopKSGz2UyVlZW0a9cuWrt2LW3YsIG2b99OJ06coMLCQrtsP+/SlJaWZvM+q6qq7BKF",
	"3F/X6/VUV1dHer1edlkSiO6OJUuWOBVcvg5jxoyxMmpc2eXl5Yl+lU2wF7kb8LinOQEOFQBj7E0L1tGtDbty5UqH5J90g9XU1FDn",
	"zp0JAH3//fdERDR27Fjh8xIRzZ49m1QqFeXm5tKwYcNIoVBQcnIyfffdd+Tv799UDGyzMP5PPfWUW5bfnpJ9/vnnHfIB/PN4piXv",
	"x3D06FE6ePAgZWVliR6LNTU1HgmbVLi58Hr6Ps6+c1VVFVVUVFBpaSnl5+dTVlYWpaen09mzZ+nIkSO0fv16mjt3riBJne0fjgJ4",
	"GrplRICIaNq0aWIum6hMeDPcOEVI5QL8N9U/7yp3oQX3v6Kjo4WvxBMnHPmbq1atQnp6Otq2bYsbbrgBP/zwAzZv3gzGGO644w5U",
	"V1fjk08+wUMPPYT09HTs2rULANC/f39s2bIFOp2uqfyuJhs8iWrKlClYtGiR8Fc9TeYhIlx11VV46aWXbM4T94nDwsKwYMEC8XhI",
	"SAiSk5Ot7o3zD9x/Z4yJyxkfwJ9nuTeMRiPq6upQUVGBuro61NXVobi4GLW1tdDr9SgvL0dpaSn0ej10Oh2KiopQU1MDvV4vXlde",
	"Xi7+rqyshMlkgslkgtFohNFohMlkAhGhtrbW5hy5wsUsXrwYY8aMkX1XPgc33XQTfvzxx6bgovjkXQ4gEcDZ+sfMDfGmfSWW3+yu",
	"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",
}, "")

local ROOT = "Spectrum/brand/v1"
local FILE = ROOT .. "/AFLogo.png"
local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local values = {}
for index = 1, #alphabet do
	values[string.sub(alphabet, index, index)] = index - 1
end

local function decode(input)
	local output = {}
	for index = 1, #input, 4 do
		local a = values[string.sub(input, index, index)] or 0
		local b = values[string.sub(input, index + 1, index + 1)] or 0
		local c = values[string.sub(input, index + 2, index + 2)]
		local d = values[string.sub(input, index + 3, index + 3)]
		local value = a * 262144 + b * 4096 + (c or 0) * 64 + (d or 0)
		output[#output + 1] = string.char(math.floor(value / 65536) % 256)
		if c then
			output[#output + 1] = string.char(math.floor(value / 256) % 256)
		end
		if d then
			output[#output + 1] = string.char(value % 256)
		end
	end
	return table.concat(output)
end

local cached
local failed = false

local function available()
	return (type(getcustomasset) == "function" or type(getsynasset) == "function")
		and type(writefile) == "function"
		and type(isfile) == "function"
		and type(makefolder) == "function"
end

local function ensure_folders()
	for _, folder in ipairs({ "Spectrum", "Spectrum/brand", ROOT }) do
		if type(isfolder) ~= "function" or not isfolder(folder) then
			pcall(makefolder, folder)
		end
	end
end

function brand.logo()
	if cached then
		return cached
	end
	if failed or not available() then
		failed = true
		return nil
	end
	local ok = pcall(ensure_folders)
	if not ok then
		failed = true
		return nil
	end
	local exists = false
	local checked, present = pcall(isfile, FILE)
	if checked and present then
		exists = true
	end
	if not exists then
		local wrote = pcall(writefile, FILE, decode(DATA))
		if not wrote then
			failed = true
			return nil
		end
	end
	local getter = getcustomasset or getsynasset
	local read_ok, asset = pcall(getter, FILE)
	if not read_ok or type(asset) ~= "string" or asset == "" then
		failed = true
		return nil
	end
	cached = asset
	return cached
end

S.brand = brand
end

do

local background = {}

local state = {
	asset = nil,
	transparency = 0.25,
	tint = Color3.new(1, 1, 1),
	scrim = 0.4,
	scale = "crop",
}

local scales = {
	crop = Enum.ScaleType.Crop,
	fit = Enum.ScaleType.Fit,
	stretch = Enum.ScaleType.Stretch,
}

local hosts = {}

local function unit(value, fallback)
	value = tonumber(value)
	if value == nil then
		return fallback
	end
	return math.clamp(value, 0, 1)
end

local function normalize(opts)
	opts = type(opts) == "table" and opts or {}
	state.transparency = unit(opts.transparency, 0.25)
	state.scrim = unit(opts.scrim, 0.4)
	state.tint = typeof(opts.tint) == "Color3" and opts.tint or Color3.new(1, 1, 1)
	local scale = tostring(opts.scale or "crop"):lower()
	state.scale = scales[scale] and scale or "crop"
end

local function asset_id(value)
	if type(value) == "number" then
		return "rbxassetid://" .. tostring(math.floor(value))
	end
	if type(value) ~= "string" then
		return nil
	end
	value = string.gsub(value, "^%s+", "")
	value = string.gsub(value, "%s+$", "")
	if value == "" then
		return nil
	end
	if tonumber(value) then
		return "rbxassetid://" .. value
	end
	return value
end

local function publish()
	for _, host in ipairs(hosts) do
		pcall(host, state)
	end
end

function background.scale_type(name)
	return scales[name] or Enum.ScaleType.Crop
end

function background.watch(host)
	if type(host) ~= "function" then
		return function() end
	end
	hosts[#hosts + 1] = host
	pcall(host, state)
	return function()
		for index, entry in ipairs(hosts) do
			if entry == host then
				table.remove(hosts, index)
				break
			end
		end
	end
end

function background.set(asset, opts)
	local source = asset_id(asset)
	if not source then
		return background.clear()
	end
	state.asset = source
	normalize(opts)
	publish()
	return background.get()
end

function background.get()
	return {
		asset = state.asset,
		transparency = state.transparency,
		tint = state.tint,
		scrim = state.scrim,
		scale = state.scale,
	}
end

function background.clear()
	if state.asset == nil then
		return background.get()
	end
	state.asset = nil
	publish()
	return background.get()
end

function background.active()
	return state.asset ~= nil
end

S.background = background
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
local auto_save_enabled = false

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
	auto_save_enabled = type(data.settings) == "table" and data.settings.auto_save == true
	return config.apply()
end

function config.save(name)
	if name then
		profile = name_of(name)
	end
	normalize()
	data.settings.auto_save = auto_save_enabled
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
	if not auto_save_enabled then
		return
	end
	if scheduled then
		return
	end
	scheduled = true
	task.delay(0.8, function()
		scheduled = false
		if auto_save_enabled then
			config.save()
		end
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
	if saved ~= nil then
		if api.apply then
			pcall(api.apply, saved)
		elseif api.set then
			pcall(api.set, saved)
		end
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
				if value ~= nil then
					if api.apply then
						pcall(api.apply, value)
					elseif api.set then
						pcall(api.set, value)
					end
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

function config.panic_key(value)
	if value ~= nil then
		data.settings = type(data.settings) == "table" and data.settings or {}
		if value == false or value == "" then
			data.settings.panic_key = nil
		else
			data.settings.panic_key = tostring(value)
		end
		config.touch()
	end
	return data.settings and data.settings.panic_key
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
	if auto_save_enabled then
		config.save()
	end
end

function config.auto_save()
	return auto_save_enabled
end

function config.set_auto_save(enabled)
	enabled = enabled == true
	if auto_save_enabled == enabled then
		return auto_save_enabled
	end
	auto_save_enabled = enabled
	data.settings = type(data.settings) == "table" and data.settings or {}
	data.settings.auto_save = enabled
	config.save()
	return auto_save_enabled
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
	Size = UDim2.fromOffset(env.mobile and 272 or 260, 0),
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
local font = Enum.Font.GothamMedium

local tooltip = {}

local DELAY = 0.35
local GAP = 6
local EDGE = 6

local function values()
	return style.values
end

local panel = util.new("Frame", {
	Name = "tooltip",
	Active = false,
	BackgroundColor3 = values().panel,
	BorderSizePixel = 0,
	AutomaticSize = Enum.AutomaticSize.XY,
	Size = UDim2.fromOffset(0, 0),
	Visible = false,
	ZIndex = 60,
	Parent = env.modal,
})
util.corner(panel, 4)
local edge = util.stroke(panel, values().line, 0.15)
util.shadow(panel, 12, 0.4)
util.new("UISizeConstraint", {
	MaxSize = Vector2.new(260, 320),
	Parent = panel,
})
util.new("UIPadding", {
	PaddingTop = UDim.new(0, 6),
	PaddingBottom = UDim.new(0, 6),
	PaddingLeft = UDim.new(0, 8),
	PaddingRight = UDim.new(0, 8),
	Parent = panel,
})

local label = util.new("TextLabel", {
	Name = "body",
	BackgroundTransparency = 1,
	AutomaticSize = Enum.AutomaticSize.Y,
	Size = UDim2.fromOffset(0, 0),
	Font = font,
	Text = "",
	TextColor3 = values().text,
	TextSize = util.size(10),
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	ZIndex = 61,
	Parent = panel,
})

local current

local function hide()
	current = nil
	if panel.Parent then
		panel.Visible = false
	end
end

local function place(target)
	local view = env.viewport()
	local pos = target.AbsolutePosition
	local size = target.AbsoluteSize
	local width = panel.AbsoluteSize.X
	local height = panel.AbsoluteSize.Y
	if width <= 0 or height <= 0 then
		return
	end
	local x = pos.X + size.X * 0.5 - width * 0.5
	x = math.clamp(x, EDGE, math.max(EDGE, view.X - width - EDGE))
	local y = pos.Y + size.Y + GAP
	if y + height > view.Y - EDGE then
		y = pos.Y - height - GAP
	end
	y = math.clamp(y, EDGE, math.max(EDGE, view.Y - height - EDGE))
	panel.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
end

local function show(target, body)
	if type(body) ~= "string" or body == "" or not target.Parent then
		return
	end
	current = target
	label.Text = body
	label.Size = UDim2.fromOffset(math.clamp(math.floor(#body * 5.6) + 6, 44, 236), 0)
	panel.Visible = true
	place(target)
	task.defer(function()
		if current == target and panel.Parent and panel.Visible then
			place(target)
		end
	end)
end

function tooltip.attach(target, text)
	if not target or (type(text) ~= "string" and type(text) ~= "function") then
		return
	end
	if type(text) == "string" and text == "" then
		return
	end
	local token = 0

	local function source()
		if type(text) == "function" then
			local ok, value = pcall(text)
			if ok and type(value) == "string" and value ~= "" then
				return value
			end
			return nil
		end
		return text
	end

	target.MouseEnter:Connect(function()
		local body = source()
		if not body then
			return
		end
		token = token + 1
		local mine = token
		task.delay(DELAY, function()
			if mine ~= token or current == target or not target.Parent then
				return
			end
			show(target, source())
		end)
	end)

	target.MouseLeave:Connect(function()
		token = token + 1
		if current == target then
			hide()
		end
	end)

	target.Destroying:Connect(function()
		token = token + 1
		if current == target then
			hide()
		end
	end)
end

function tooltip.hide()
	hide()
end

env.uis.InputBegan:Connect(function(input)
	local kind = input.UserInputType
	if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
		hide()
	end
end)

style.paint(function()
	panel.BackgroundColor3 = values().panel
	edge.Color = values().line
	label.TextColor3 = values().text
end)

S.tooltip = tooltip
end

do

local env = S.env
local util = S.util
local style = S.style
local bold = Enum.Font.GothamBold

local watermark = {}

local function values()
	return style.values
end

local text = ""
local shown = false

local card = util.new("Frame", {
	Name = "watermark",
	BackgroundColor3 = values().panel,
	BackgroundTransparency = 0.12,
	BorderSizePixel = 0,
	AutomaticSize = Enum.AutomaticSize.X,
	Position = UDim2.fromOffset(12, 12),
	Size = UDim2.fromOffset(0, 24),
	Visible = false,
	ZIndex = 2,
	Parent = env.notes,
})
util.corner(card, 4)
util.new("UIPadding", {
	PaddingRight = UDim.new(0, 10),
	Parent = card,
})
local edge = util.stroke(card, values().line, 0.25)
util.shadow(card, 10, 0.55)
local tick = util.new("Frame", {
	BackgroundColor3 = values().accent,
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 10, 0.5, 0),
	Size = UDim2.fromOffset(2, 12),
	ZIndex = 3,
	Parent = card,
})
local label = util.new("TextLabel", {
	BackgroundTransparency = 1,
	AutomaticSize = Enum.AutomaticSize.X,
	Position = UDim2.fromOffset(19, 0),
	Size = UDim2.fromOffset(0, 24),
	Font = bold,
	Text = "",
	TextColor3 = values().text,
	TextSize = util.size(10),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Center,
	ZIndex = 3,
	Parent = card,
})

local function paint()
	card.Visible = shown and text ~= ""
	card.BackgroundColor3 = values().panel
	edge.Color = values().line
	tick.BackgroundColor3 = values().accent
	label.TextColor3 = values().text
end

function watermark.set(value)
	text = type(value) == "string" and value or ""
	shown = text ~= ""
	paint()
	return watermark.get()
end

function watermark.visible(state)
	shown = state == true
	paint()
	return shown
end

function watermark.get()
	return text, shown
end

style.paint(paint)
paint()

S.watermark = watermark
end

do

local env = S.env
local util = S.util
local style = S.style
local brand = S.brand
local bold = Enum.Font.GothamBold
local font = Enum.Font.GothamMedium
local splash = {}

local function values()
	return style.values
end

function splash.mount()
	if not env.splash then
		return nil
	end

	local gui = util.new("TextButton", {
		Name = "startup_splash",
		BackgroundColor3 = values().background,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		ZIndex = 1,
		Parent = env.splash,
	})

	local card_w = env.mobile and 194 or 218
	local card_h = env.mobile and 224 or 242
	local card = util.new("Frame", {
		Name = "splash_card",
		BackgroundColor3 = values().panel,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(card_w, card_h),
		ZIndex = 3,
		Parent = gui,
	})
	local edge = util.stroke(card, values().line, 0.15)
	util.shadow(card, 22, 0.35)
	local scale = util.new("UIScale", { Scale = 0.9, Parent = card })

	local plate_size = env.mobile and 100 or 112
	local plate = util.new("Frame", {
		Name = "logo_plate",
		BackgroundColor3 = values().hover,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, env.mobile and 15 or 18),
		Size = UDim2.fromOffset(plate_size, plate_size),
		ZIndex = 4,
		Parent = card,
	})
	util.corner(plate, plate_size / 2)
	local plate_edge = util.stroke(plate, values().line, 0.35)

	local logo = brand and brand.logo()
	local fallback_label
	if logo then
		local image = util.new("ImageLabel", {
			Name = "logo",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(plate_size - 8, plate_size - 8),
			Image = logo,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 5,
			Parent = plate,
		})
		image.ImageColor3 = Color3.new(1, 1, 1)
	else
		local fallback = util.new("Frame", {
			Name = "logo_fallback",
			BackgroundColor3 = values().raised,
			BackgroundTransparency = 0.05,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(plate_size - 16, plate_size - 16),
			ZIndex = 5,
			Parent = plate,
		})
		util.corner(fallback, (plate_size - 16) / 2)
		fallback_label = util.new("TextLabel", {
			BackgroundTransparency = 1,
			Font = bold,
			Size = UDim2.fromScale(1, 1),
			Text = "AF",
			TextColor3 = values().text,
			TextSize = util.size(22),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			ZIndex = 6,
			Parent = fallback,
		})
	end

	local title_y = (env.mobile and 15 or 18) + plate_size + (env.mobile and 8 or 10)
	local title = util.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, title_y),
		Size = UDim2.new(1, 0, 0, 18),
		Font = bold,
		Text = "AdvanceFalling",
		TextColor3 = values().text,
		TextSize = util.size(15),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 4,
		Parent = card,
	})
	local subtitle = util.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, title_y + 20),
		Size = UDim2.new(1, 0, 0, 12),
		Font = font,
		Text = "SPECTRUM",
		TextColor3 = values().muted,
		TextSize = util.size(9),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 4,
		Parent = card,
	})

	local rail_y = card_h - (env.mobile and 38 or 42)
	local rail = util.new("Frame", {
		Name = "splash_progress",
		BackgroundColor3 = values().line,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, rail_y),
		Size = UDim2.fromOffset(card_w - 48, 2),
		ZIndex = 4,
		Parent = card,
	})
	local fill = util.new("Frame", {
		BackgroundColor3 = values().accent,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 5,
		Parent = rail,
	})

	util.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, rail_y + 12),
		Size = UDim2.new(1, 0, 0, 12),
		Font = font,
		Text = "Loading UI",
		TextColor3 = values().muted,
		TextSize = util.size(9),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 4,
		Parent = card,
	})

	local closed = false
	local function dismiss()
		if closed then
			return
		end
		closed = true
		S.splash_open = false
		util.tween(gui, 0.26, { BackgroundTransparency = 1 })
		util.tween(card, 0.26, { BackgroundTransparency = 1 })
		for _, item in ipairs(card:GetDescendants()) do
			if item:IsA("TextLabel") then
				util.tween(item, 0.26, { TextTransparency = 1 })
			elseif item:IsA("ImageLabel") then
				util.tween(item, 0.26, { ImageTransparency = 1 })
			elseif item:IsA("Frame") then
				util.tween(item, 0.26, { BackgroundTransparency = 1 })
			elseif item:IsA("UIStroke") then
				util.tween(item, 0.26, { Transparency = 1 })
			end
		end
		task.delay(0.3, function()
			if gui.Parent then
				gui:Destroy()
			end
		end)
	end

	util.tween(scale, 0.34, { Scale = 1 }, Enum.EasingStyle.Back)
	util.tween(fill, 1.45, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Linear)
	style.paint(function()
		if closed then
			return
		end
		gui.BackgroundColor3 = values().background
		card.BackgroundColor3 = values().panel
		plate.BackgroundColor3 = values().hover
		plate_edge.Color = values().line
		edge.Color = values().line
		title.TextColor3 = values().text
		subtitle.TextColor3 = values().muted
		rail.BackgroundColor3 = values().line
		fill.BackgroundColor3 = values().accent
		for _, item in ipairs(card:GetDescendants()) do
			if item:IsA("TextLabel") and item ~= title and item ~= subtitle and item ~= fallback_label then
				item.TextColor3 = values().muted
			end
		end
	end)

	gui.Activated:Connect(dismiss)
	task.delay(1.75, dismiss)
	S.splash_open = true

	return {
		Gui = gui,
		dismiss = dismiss,
		destroy = function()
			S.splash_open = false
			closed = true
			if gui.Parent then
				gui:Destroy()
			end
		end,
	}
end

S.splash = splash
end

do

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
		strip_visible = #tabs > 1 and open
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
		tab.chip = chip
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
		layout_chrome()
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
end

do

local env = S.env
local util = S.util
local style = S.style
local icons = S.icons
local tooltip = S.tooltip
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

function inputs.button(win, text, callback, icon, opts)
	if type(icon) == "table" and opts == nil then
		opts = icon
		icon = opts.icon
	end
	opts = type(opts) == "table" and opts or {}
	local disabled = opts.disabled == true
	local variant = tostring(opts.variant or opts.style or "primary"):lower()
	local confirm = type(opts.confirm) == "string" and opts.confirm ~= "" and opts.confirm
		or (opts.confirm == true and "Click again to confirm" or nil)
	local _, front = style.variant(variant)
	local mobile = win._mobile
	local holder = win._slot(mobile and 46 or 32)
	local btn = util.new("TextButton", {
		Name = "button",
		BackgroundColor3 = values().accent,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = not disabled,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -16, 0, mobile and 36 or 24),
		Font = bold,
		Text = tostring(text or "Button"),
		TextColor3 = front,
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
	local armed = false
	local arm_token = 0

	local function ink()
		if disabled then
			return values().muted
		end
		local _, tone = style.variant(variant)
		return tone
	end

	local function face()
		if disabled then
			return values().raised
		end
		local back = style.variant(variant)
		if held then
			return back:Lerp(Color3.new(1, 1, 1), 0.14)
		end
		return back
	end

	local function paint()
		btn.BackgroundColor3 = face()
		btn.TextColor3 = ink()
		if emblem then
			icons.tint(emblem, ink())
		end
	end

	local function run()
		if disabled then
			return
		end
		if confirm and not armed then
			armed = true
			arm_token = arm_token + 1
			local mine = arm_token
			btn.Text = confirm
			task.delay(3, function()
				if btn.Parent and armed and arm_token == mine then
					armed = false
					btn.Text = tostring(text or "Button")
				end
			end)
			return
		end
		armed = false
		arm_token = arm_token + 1
		btn.Text = tostring(text or "Button")
		if callback then
			callback()
		end
	end

	if tooltip and opts.tooltip then
		tooltip.attach(btn, opts.tooltip)
	end

	btn.MouseEnter:Connect(function()
		if disabled then
			return
		end
		held = true
		util.tween(btn, 0.12, { BackgroundColor3 = face() })
	end)
	btn.MouseLeave:Connect(function()
		held = false
		util.tween(btn, 0.15, { BackgroundColor3 = face() })
	end)
	btn.Activated:Connect(run)
	btn.MouseButton1Down:Connect(function()
		if disabled then
			return
		end
		util.tween(pop, 0.08, { Scale = 0.97 }, Enum.EasingStyle.Quad)
	end)
	btn.MouseButton1Up:Connect(function()
		if disabled then
			return
		end
		util.tween(pop, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	end)

	local function set_disabled(value)
		disabled = value == true
		btn.Active = not disabled
		if disabled then
			held = false
			armed = false
			btn.Text = tostring(text or "Button")
			util.tween(pop, 0.1, { Scale = 1 })
		end
		if btn:GetAttribute("SpectrumDisabled") ~= disabled then
			btn:SetAttribute("SpectrumDisabled", disabled)
		end
		paint()
		if win._nav_refresh then
			win._nav_refresh()
		end
	end

	btn:SetAttribute("SpectrumDisabled", disabled)
	btn:GetAttributeChangedSignal("SpectrumDisabled"):Connect(function()
		set_disabled(btn:GetAttribute("SpectrumDisabled") == true)
	end)
	style.paint(paint)

	win._options(holder, text, function()
		return {
			{ label = "Run action", icon = "arrow", accent = true, run = run },
		}
	end)

	win._nav_register(holder, {
		kind = "button",
		label = text,
		is_enabled = function()
			return not disabled
		end,
		activate = run,
	})

	win._fit(true)
	return btn
end

function inputs.toggle(win, text, a, b, opts)
	local mobile = win._mobile
	local listeners = {}
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
	local disabled = opts.disabled == true
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
		Active = not disabled,
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
			local accent = disabled and values().muted or values().accent
			local tint = state and accent or values().raised
			util.tween(box, 0.12, { BackgroundColor3 = tint })
			edge.Color = state and accent or values().line
			edge.Transparency = state and 1 or 0.15
			local ink = state and (disabled and values().ink or style.on(values().accent)) or values().ink
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
			local accent = disabled and values().muted or values().accent
			util.tween(thumb, 0.16, {
				Position = UDim2.new(0, x, 0.5, 0),
				BackgroundColor3 = state and (disabled and values().muted or Color3.new(1, 1, 1)) or values().muted,
			}, Enum.EasingStyle.Quart)
			util.tween(track, 0.14, { BackgroundColor3 = state and accent or values().raised })
			edge.Color = state and accent or values().line
			edge.Transparency = state and 1 or 0.2
		end
	end

	local key
	local function set(value, fire)
		if disabled and fire then
			return
		end
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
		for _, listener in ipairs(listeners) do
			pcall(listener, state)
		end
	end

	hit.Activated:Connect(function()
		if disabled then
			return
		end
		set(not state, true)
	end)

	local function set_disabled(value)
		disabled = value == true
		hit.Active = not disabled
		heading.TextColor3 = disabled and values().muted or values().text
		if emblem then
			icons.tint(emblem, disabled and values().line or values().muted)
		end
		sync()
		if win._nav_refresh then
			win._nav_refresh()
		end
	end

	style.paint(function()
		row.BackgroundColor3 = values().hover
		hit.BackgroundColor3 = values().hover
		heading.TextColor3 = disabled and values().muted or values().text
		if emblem then
			icons.tint(emblem, disabled and values().line or values().muted)
		end
		sync()
	end)

	sync()
	key = win._bind("toggle", text, {
		set = function(value)
			set(value, false)
		end,
		apply = function(value)
			set(value, false)
			if changed then
				local next = state
				task.defer(function()
					if changed then
						changed(next)
					end
				end)
			end
		end,
	})
	win._options(row, text, function()
		return {
			{ label = state and "Turn off" or "Turn on", icon = "sliders", accent = true, run = function() set(not state, true) end },
			{ label = "Reset to default", icon = "arrow", run = function() set(initial, true) end },
		}
	end)
	win._nav_register(row, {
		kind = "toggle",
		label = text,
		is_enabled = function()
			return not disabled
		end,
		activate = function()
			set(not state, true)
		end,
		adjust = function(direction)
			set(direction > 0, true)
		end,
	})
	if tooltip and opts.tooltip then
		tooltip.attach(row, opts.tooltip)
	end
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
		OnChanged = function(_, fn)
			if type(fn) ~= "function" then
				return function() end
			end
			listeners[#listeners + 1] = fn
			return function()
				for index, entry in ipairs(listeners) do
					if entry == fn then
						table.remove(listeners, index)
						break
					end
				end
			end
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

function inputs.slider(win, text, min, max, default, callback, step, icon, opts)
	opts = type(opts) == "table" and opts or {}
	local disabled = opts.disabled == true
	local mobile = win._mobile
	local compact = opts.compact == true
	local suffix = type(opts.suffix) == "string" and opts.suffix or ""
	local show_max = opts.showMax == true or opts.hideMax == false
	local row = win._row(compact and (mobile and 40 or 34) or (mobile and 46 or 40))
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
	local precision = tonumber(opts.decimals)
	local decimals = math.clamp(
		math.floor(precision ~= nil and precision or (notch >= 1 and 0 or (notch >= 0.1 and 1 or 2))),
		0,
		3
	)
	local label_y = compact and 3 or (mobile and 7 or 5)
	local track_y = compact and (mobile and 24 or 22) or (mobile and 31 or 27)

	local emblem = row_emblem(row, icon, 14, values().muted, label_y)
	local name = label(row, text, label_y, 14)
	if emblem then
		name.Position = UDim2.fromOffset(28, label_y)
		name.Size = UDim2.new(1, -120, 0, 14)
	else
		name.Size = UDim2.new(1, -100, 0, 14)
	end

	local readout = util.new("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, compact and 2 or (mobile and 6 or 4)),
		Size = UDim2.fromOffset(88, 14),
		Font = bold,
		Text = "",
		TextColor3 = values().muted,
		TextSize = util.size(10),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = row,
	})

	local track = util.new("Frame", {
		BackgroundColor3 = values().raised,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 10, 0, track_y),
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
		Active = not disabled,
		Position = UDim2.new(0, 4, 0, math.max(0, track_y - 10)),
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
		local shown = string.format("%." .. decimals .. "f", value) .. suffix
		if show_max then
			shown = shown .. " / " .. string.format("%." .. decimals .. "f", high) .. suffix
		end
		readout.Text = shown
		readout.TextColor3 = disabled and values().muted or (dragging and values().accent or values().muted)
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
		if disabled then
			return
		end
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
		if disabled or not dragging then
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
		fill.BackgroundColor3 = disabled and values().muted or values().accent
		thumb.BackgroundColor3 = disabled and values().muted or values().accent
		name.TextColor3 = disabled and values().muted or values().text
		readout.TextColor3 = disabled and values().muted or (dragging and values().accent or values().muted)
		if emblem then
			icons.tint(emblem, disabled and values().line or values().muted)
		end
	end)

	local function set_disabled(value)
		disabled = value == true
		hit.Active = not disabled
		if disabled and dragging then
			dragging = false
			win._scroll.ScrollingEnabled = true
			thumb.Size = UDim2.fromOffset(6, mobile and 16 or 13)
		end
		fill.BackgroundColor3 = disabled and values().muted or values().accent
		thumb.BackgroundColor3 = disabled and values().muted or values().accent
		name.TextColor3 = disabled and values().muted or values().text
		if emblem then
			icons.tint(emblem, disabled and values().line or values().muted)
		end
		paint_value(false)
		if win._nav_refresh then
			win._nav_refresh()
		end
	end

	paint_value(false)
	key = win._bind("slider", text, {
		set = function(value)
			apply(value, false)
		end,
		apply = function(value)
			apply(value, false)
			if callback then
				local next = value
				task.defer(function()
					callback(next)
				end)
			end
		end,
	})
	win._options(row, text, function()
		return { -- you can change this if you want
			{ label = "Reset to default", icon = "arrow", run = function()
				if not disabled then
					apply(initial, true)
				end
			end },
			{ label = "Set minimum", run = function()
				if not disabled then
					apply(low, true)
				end
			end },
			{ label = "Set maximum", run = function()
				if not disabled then
					apply(high, true)
				end
			end },
		}
	end)
	win._nav_register(row, {
		kind = "slider",
		label = text,
		is_enabled = function()
			return not disabled
		end,
		adjust = function(direction)
			if not disabled then
				apply(math.clamp(value + direction * notch, low, high), true)
			end
		end,
	})
	if tooltip and opts.tooltip then
		tooltip.attach(row, opts.tooltip)
	end
	win._fit(true)

	return {
		Set = function(_, next)
			apply(next, false)
		end,
		Get = function()
			return value
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

function inputs.keybind(win, text, default, callback, icon, opts)
	if type(icon) == "table" and opts == nil then
		opts = icon
		icon = opts.icon
	end
	opts = type(opts) == "table" and opts or {}
	local on_change = type(opts.onChange) == "function" and opts.onChange or nil
	local on_press = type(opts.onPress) == "function" and opts.onPress or nil
	local on_release = type(opts.onRelease) == "function" and opts.onRelease or nil
	local mirror_toggle = type(opts.syncToggle) == "table" and opts.syncToggle or nil
	local mode = tostring(opts.mode or (on_release and "hold" or "toggle")):lower()
	if mode ~= "hold" and mode ~= "toggle" then
		mode = "hold"
	end
	local action = on_press ~= nil or on_release ~= nil or mirror_toggle ~= nil or opts.mode ~= nil
	local empty_text = type(opts.emptyText) == "string" and opts.emptyText ~= "" and opts.emptyText or "None"
	local disabled = opts.disabled == true
	local allow_mouse = opts.allowMouse ~= false
	local allow_gamepad = opts.allowGamepad ~= false
	local clear_on_delete = opts.clearOnDelete ~= false
	local mobile = win._mobile
	local row = win._row(mobile and 40 or 34)
	row.ClipsDescendants = true
	local initial = default
	local reset_key = opts.resetKey ~= nil and opts.resetKey or initial
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
		Active = not disabled,
		ClipsDescendants = true,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(mobile and 96 or 84, mobile and 30 or 22),
		Font = bold,
		Text = default or empty_text,
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
	local active = false
	local toggled = false

	local function display(value)
		if value == nil or value == "" then
			return empty_text
		end
		local label = util.input_label(value)
		if #label > 14 then
			label = string.sub(label, 1, 12) .. "..."
		end
		return label
	end

	local function sync()
		local fill = values().raised
		local tone = key and values().text or values().muted
		local border = values().line
		local border_alpha = 0.35
		if disabled then
			tone = values().muted
		elseif listening then
			tone = values().accent
			border = values().accent
			border_alpha = 0.2
		elseif active then
			tone = style.on(values().accent)
			fill = values().accent
			border = values().accent
			border_alpha = 1
		end
		pill.Text = listening and "..." or display(key)
		pill.TextColor3 = tone
		pill.BackgroundColor3 = fill
		edge.Color = border
		edge.Transparency = border_alpha
	end

	local function release_action()
		if not active then
			return
		end
		active = false
		sync()
		if on_release then
			pcall(on_release)
		end
	end

	local function press_action()
		if not action then
			return
		end
		if mode == "toggle" then
			toggled = not toggled
			active = toggled
			sync()
			if mirror_toggle then
				pcall(function()
					if type(mirror_toggle.Toggle) == "function" then
						mirror_toggle:Toggle()
					else
						mirror_toggle:Set(toggled)
					end
				end)
			end
			if on_press then
				pcall(on_press, toggled)
			end
		else
			active = true
			sync()
			if on_press then
				pcall(on_press, true)
			end
		end
	end

	local function mirror_state()
		if not mirror_toggle then
			return
		end
		local ok, value = pcall(function()
			return mirror_toggle:Get()
		end)
		if ok and type(value) == "boolean" and value ~= toggled then
			toggled = value
			if mode == "toggle" then
				active = value
				sync()
			end
		end
	end

	if mirror_toggle and type(mirror_toggle.OnChanged) == "function" then
		local stop = mirror_toggle:OnChanged(function(value)
			toggled = value == true
			if mode == "toggle" then
				active = toggled
				sync()
			end
		end)
		if type(stop) == "function" then
			row.Destroying:Connect(stop)
		end
	end

	local function toggle_capture()
		if disabled then
			return
		end
		listening = not listening
		S.binding = listening
		sync()
	end

	pill.Activated:Connect(toggle_capture)

	row.Destroying:Connect(function()
		if listening then
			listening = false
			S.binding = false
		end
		if active then
			active = false
			if on_release then
				pcall(on_release)
			end
		end
	end)

	local function cancel_capture()
		listening = false
		S.binding = false
		sync()
	end

	local function clear_key()
		key = nil
		toggled = false
		release_action()
		cancel_capture()
		win._store(stored, key)
		if on_change then
			on_change(nil)
		end
		if callback then
			callback(nil, false)
		end
	end

	win._link(env.uis.InputBegan, function(input, processed)
		if disabled then
			return
		end
		local id = util.input_id(input)
		if listening then
			if not id then
				return
			end
			local kind_name = input.UserInputType.Name
			local is_keyboard = input.UserInputType == Enum.UserInputType.Keyboard
			if is_keyboard and input.KeyCode == Enum.KeyCode.Escape then
				cancel_capture()
				return
			end
			if is_keyboard and clear_on_delete and (input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Delete) then
				clear_key()
				return
			end
			local is_mouse = string.match(kind_name, "^MouseButton%d+$") ~= nil
			local is_gamepad = string.match(kind_name, "^Gamepad%d+$") ~= nil
			if (is_mouse and not allow_mouse) or (is_gamepad and not allow_gamepad) then
				return
			end
			key = id
			cancel_capture()
			win._store(stored, key)
			held[id] = true
			if on_change then
				on_change(key)
			end
			if callback then
				callback(key, true)
			end
			return
		end
		if processed or util.focused_text_box() or S.splash_open or not win.Gui.Visible then
			return
		end
		if key and id == key and not held[id] then
			held[id] = true
			mirror_state()
			press_action()
			if callback then
				callback(key, true)
			end
		end
	end)

	win._link(env.uis.InputEnded, function(input)
		if disabled then
			return
		end
		local id = util.input_id(input)
		if id and id == key and held[id] then
			held[id] = nil
			release_action()
			if callback then
				callback(key, false)
			end
		end
	end)

	style.paint(function()
		caption.TextColor3 = disabled and values().muted or values().text
		if emblem then
			icons.tint(emblem, disabled and values().line or values().muted)
		end
		sync()
	end)

	if tooltip and opts.tooltip then
		tooltip.attach(row, opts.tooltip)
	end

	local function set_disabled(value)
		disabled = value == true
		pill.Active = not disabled
		if disabled then
			if listening then
				listening = false
				S.binding = false
			end
			held = {}
			if active then
				active = false
				if on_release then
					pcall(on_release)
				end
			end
		end
		sync()
		if win._nav_refresh then
			win._nav_refresh()
		end
	end

	sync()
	stored = win._bind("key", text, {
		set = function(value)
			if key == value then
				return
			end
			key = value
			sync()
			if on_change then
				on_change(key)
			end
		end,
	})
	win._options(row, text, function()
		return {
			{ label = "Clear key", icon = "close", run = function()
				if disabled then
					return
				end
				key = nil
				toggled = false
				release_action()
				sync()
				win._store(stored, key)
				if on_change then
					on_change(nil)
				end
				if callback then
					callback(key, false)
				end
			end },
			{ label = "Reset to default", icon = "arrow", run = function()
				if disabled then
					return
				end
				key = reset_key
				sync()
				win._store(stored, key)
				if on_change then
					on_change(reset_key)
				end
			end },
		}
	end)
	win._nav_register(row, {
		kind = "keybind",
		label = text,
		is_enabled = function()
			return not disabled
		end,
		activate = toggle_capture,
	})
	win._fit(true)

	return {
		Set = function(_, next)
			if key == next then
				return
			end
			key = next
			sync()
			win._store(stored, key)
			if on_change then
				on_change(key)
			end
		end,
		Get = function()
			return key
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

S.inputs = inputs
end

do

local env = S.env
local util = S.util
local style = S.style
local modal = S.modal
local icons = S.icons
local tooltip = S.tooltip
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
	local name = caption(row, title)
	name.Size = UDim2.new(0.48, -20, 1, 0)
	name.TextSize = util.size(mobile and 11 or 12)
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
		Text = placeholder,
		TextColor3 = values().muted,
		TextSize = util.size(mobile and 10 or 11),
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
			Font = bold,
			Text = "0",
			TextColor3 = style.on(values().accent),
			TextSize = util.size(mobile and 9 or 10),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			Visible = false,
			ZIndex = 4,
			Parent = row,
		})
		util.corner(count_badge, 5)
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
				TextSize = util.size(mobile and 9 or 10),
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
		clear_action, clear_hit = action("clear", "Clear", mobile and 42 or 48, 0)
		select_all_action, select_all_hit = action("select_all", "Select all", mobile and 58 or 64, -(mobile and 46 or 52))
	end

	local search
	if searchable then
		search = util.new("TextBox", {
			Name = "dropdown_search",
			BackgroundColor3 = values().raised,
			BorderSizePixel = 0,
			ClearTextOnFocus = false,
			Font = font,
			PlaceholderColor3 = values().muted,
			PlaceholderText = "Search...",
			Position = UDim2.fromOffset(pad, pad + bulk_h + bulk_gap),
			Size = UDim2.new(1, -pad * 2, 0, search_h),
			Text = "",
			TextColor3 = values().text,
			TextSize = util.size(10),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 13,
			Parent = panel,
		})
		util.corner(search, 4)
		util.new("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			Parent = search,
		})
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
			item.BackgroundTransparency = option == active_option and 0 or 1
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
				readout.Text = placeholder
			elseif picked == 1 then
				readout.Text = first_name
			elseif picked == 2 then
				readout.Text = first_name .. " +1"
			else
				readout.Text = picked .. " selected"
			end
		else
			readout.Text = single or placeholder
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
			Text = option,
			TextColor3 = values().text,
			TextSize = util.size(mobile and 11 or 12),
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
		end
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
	util.corner(swatch, 3)
	util.stroke(swatch, Color3.new(1, 1, 1), 0.7)

	local pad = 8
	local field_h = mobile and 100 or 94
	local panel_w = mobile and 240 or 226
	local bottom_y = pad + field_h + 29
	local swatch_size = mobile and 18 or 16
	local swatch_step = swatch_size + 6
	local panel_h = bottom_y + 36 + preset_rows * 24

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
	util.corner(panel, 6)
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
	util.corner(preview, 3)
	util.stroke(preview, values().line, 0.2)

	local hex = util.new("TextBox", {
		BackgroundColor3 = values().raised,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		TextEditable = not disabled,
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
			Position = UDim2.fromOffset(pad, bottom_y + 34 + (index - 1) * 24),
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
			util.corner(swatch, 3)
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
			util.corner(slot, 3)
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
		if disabled then
			set_open(false)
			field_drag = false
			hue_drag = false
			if hex:IsFocused() then
				hex:ReleaseFocus()
			end
		end
		hex.TextColor3 = disabled and values().muted or values().text
		name.TextColor3 = disabled and values().muted or values().text
		if emblem then
			icons.tint(emblem, disabled and values().line or values().muted)
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
end

do

local env = S.env
local util = S.util
local style = S.style
local icons = S.icons
local tooltip = S.tooltip
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

	win._nav_register(holder, {
		kind = "section",
		label = title,
		is_enabled = function()
			return true
		end,
		activate = function()
			set_open(nil, true)
		end,
	})

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

function text.textbox(win, title, default, callback, icon, opts)
	if type(icon) == "table" and opts == nil then
		opts = icon
		icon = opts.icon
	end
	opts = type(opts) == "table" and opts or {}
	local disabled = opts.disabled == true
	local placeholder = type(opts.placeholder) == "string" and opts.placeholder ~= "" and opts.placeholder or "Enter text"
	local numeric = opts.numericOnly == true or opts.numbersOnly == true
	local max_length = tonumber(opts.maxLength)
	if max_length then
		max_length = math.max(1, math.floor(max_length))
	end
	local submit = opts.submitOnEnter ~= false
	local clear_focus = opts.clearOnFocus == true
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
			ClearTextOnFocus = clear_focus,
			Active = not disabled,
			TextEditable = not disabled,
			Font = font,
			PlaceholderColor3 = values().muted,
			PlaceholderText = placeholder,
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
			ClearTextOnFocus = clear_focus,
			Active = not disabled,
			TextEditable = not disabled,
			Font = font,
			PlaceholderColor3 = values().muted,
			PlaceholderText = placeholder,
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
	local fixing = false

	box:GetPropertyChangedSignal("Text"):Connect(function()
		if fixing or disabled then
			return
		end
		local current = box.Text
		local next_text = current
		if numeric then
			next_text = string.gsub(next_text, "[^%d%.%-]", "")
			local dot = string.find(next_text, "%.", 1, false)
			if dot then
				next_text = string.sub(next_text, 1, dot) .. string.gsub(string.sub(next_text, dot + 1), "%.", "")
			end
			local minus = string.find(next_text, "-", 1, false)
			if minus then
				next_text = (minus == 1 and "-" or "") .. string.gsub(next_text, "%-", "")
			end
		end
		if max_length and #next_text > max_length then
			next_text = string.sub(next_text, 1, max_length)
		end
		if next_text ~= current then
			fixing = true
			box.Text = next_text
			fixing = false
		end
	end)

	box.Focused:Connect(function()
		edge.Color = values().accent
		edge.Transparency = 0.2
	end)
	box.FocusLost:Connect(function(enter_pressed)
		edge.Color = values().line
		edge.Transparency = 0.2
		if disabled then
			return
		end
		if enter_pressed and not submit then
			return
		end
		win._store(stored, box.Text)
		if callback then
			callback(box.Text)
		end
	end)

	win._link(env.uis.InputBegan, function(input)
		if not box:IsFocused() then
			return
		end
		local code = input.KeyCode
		local kind = input.UserInputType
		local keyboard_release = kind == Enum.UserInputType.Keyboard
			and (code == Enum.KeyCode.Escape or (submit and (code == Enum.KeyCode.Return or code == Enum.KeyCode.KeypadEnter)))
		local gamepad_release = string.match(kind.Name, "^Gamepad") and code == Enum.KeyCode.ButtonB
		if keyboard_release or gamepad_release then
			box:ReleaseFocus()
		end
	end)

	style.paint(function()
		box.BackgroundColor3 = values().raised
		box.TextColor3 = disabled and values().muted or values().text
		box.PlaceholderColor3 = values().muted
		edge.Color = values().line
		name.TextColor3 = disabled and values().muted or values().text
		if emblem then
			icons.tint(emblem, disabled and values().line or values().muted)
		end
	end)

	local function set_disabled(value)
		disabled = value == true
		box.TextEditable = not disabled
		box.Active = not disabled
		if disabled and box:IsFocused() then
			box:ReleaseFocus()
		end
		box.TextColor3 = disabled and values().muted or values().text
		name.TextColor3 = disabled and values().muted or values().text
		if emblem then
			icons.tint(emblem, disabled and values().line or values().muted)
		end
		if win._nav_refresh then
			win._nav_refresh()
		end
	end

	stored = win._bind("text", title, {
		set = function(value)
			box.Text = tostring(value)
		end,
		apply = function(value)
			box.Text = tostring(value)
			if callback then
				local next = box.Text
				task.defer(function()
					callback(next)
				end)
			end
		end,
	})
	win._options(row, title, function()
		return {
			{ label = "Clear text", icon = "close", run = function()
				if disabled then
					return
				end
				box.Text = ""
				win._store(stored, "")
				if callback then
					callback("")
				end
			end },
			{ label = "Reset to default", icon = "arrow", run = function()
				if disabled then
					return
				end
				box.Text = tostring(initial or "")
				win._store(stored, box.Text)
				if callback then
					callback(box.Text)
				end
			end },
		}
	end)
	win._nav_register(row, {
		kind = "textbox",
		label = title,
		is_enabled = function()
			return not disabled
		end,
		activate = function()
			if not disabled then
				box:CaptureFocus()
			end
		end,
	})
	if tooltip and opts.tooltip then
		tooltip.attach(row, opts.tooltip)
	end
	win._fit(true)

	return {
		Set = function(_, value)
			box.Text = tostring(value)
		end,
		Get = function()
			return box.Text
		end,
		Focus = function()
			if not disabled then
				box:CaptureFocus()
			end
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

S.text = text
end

do

local env = S.env
local config = S.config
local util = S.util
local Library = {}
Library.Version = "3.1"

config.load()
local DEFAULT_MENU_KEY = "RightControl+LeftShift"
local menu_key = DEFAULT_MENU_KEY
local panic_key
local panic_callback
local panic_held = {}
local panic_fired = false
local menu_open = true
local mobile_launcher
local splash
local menu_held = {}
local combo_fired = false

local function normalize_key(value)
	local text = tostring(value or ""):gsub("%s+", "")
	if text == "" then
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
	local parts = {}
	for part in string.gmatch(tostring(value or ""), "[^+]+") do
		parts[#parts + 1] = util.input_label(part)
	end
	return table.concat(parts, "+")
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

local function panic_keys()
	local keys = {}
	if not panic_key then
		return keys
	end
	for part in string.gmatch(panic_key, "[^+]+") do
		keys[#keys + 1] = part
	end
	return keys
end

local function all_panic_held()
	local keys = panic_keys()
	if #keys == 0 then
		return false
	end
	for _, key in ipairs(keys) do
		if not panic_held[key] then
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

local saved_panic = config.panic_key()
if saved_panic then
	panic_key = tostring(saved_panic)
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
		if S.tooltip then
			S.tooltip.hide()
		end
	end
	if mobile_launcher then
		mobile_launcher.set_open(menu_open)
	end
	return menu_open
end

local function fire_panic()
	if panic_callback then
		local callback = panic_callback
		task.spawn(function()
			pcall(callback, panic_key)
		end)
	else
		set_menu(false)
	end
end

function Library:Design(props)
	return S.style.apply(props)
end

function Library:GetDesign()
	return S.style.copy()
end

function Library:SetDisabled(control, value)
	if type(control) == "table" and type(control.SetDisabled) == "function" then
		control:SetDisabled(value)
	elseif typeof(control) == "Instance" and control:GetAttribute("SpectrumDisabled") ~= nil then
		control:SetAttribute("SpectrumDisabled", value == true)
	end
	return control
end

function Library:GetDisabled(control)
	if type(control) == "table" and type(control.GetDisabled) == "function" then
		return control:GetDisabled() == true
	end
	if typeof(control) == "Instance" then
		return control:GetAttribute("SpectrumDisabled") == true
	end
	return false
end

function Library:Notify(title, body, duration, kind)
	return S.notify(title, body, duration, kind)
end

function Library:SetBackground(asset, opts)
	return S.background.set(asset, opts)
end

function Library:GetBackground()
	return S.background.get()
end

function Library:ClearBackground()
	return S.background.clear()
end

function Library:SetWatermark(text)
	return S.watermark.set(text)
end

function Library:SetWatermarkVisible(state)
	return S.watermark.visible(state)
end

function Library:GetWatermark()
	return S.watermark.get()
end

function Library:Window(title, opts)
	local win = S.window.new(title, opts)
	win.Gui.Visible = menu_open
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

function Library:GetMobileButton()
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

function Library:SetPanicKey(key, callback)
	if type(key) == "table" then
		key = table.concat(key, "+")
	end
	if key == nil or key == false then
		panic_key = nil
		config.panic_key(false)
	else
		local text = tostring(key):gsub("%s+", "")
		panic_key = text ~= "" and text or nil
		config.panic_key(panic_key or false)
	end
	if callback ~= nil then
		panic_callback = type(callback) == "function" and callback or nil
	end
	panic_held = {}
	panic_fired = false
	return panic_key
end

function Library:GetPanicKey()
	return panic_key
end

function Library:SaveConfig(name)
	return config.save(name)
end

function Library:SetAutoSave(enabled)
	return config.set_auto_save(enabled)
end

function Library:GetAutoSave()
	return config.auto_save()
end

function Library:LoadConfig(name)
	config.load(name)
	menu_key = normalize_key(config.toggle_key())
	menu_held = {}
	combo_fired = false
	panic_key = config.panic_key()
	if panic_key then
		panic_key = tostring(panic_key)
	end
	panic_held = {}
	panic_fired = false
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

local menu_link = env.uis.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if S.splash_open or S.binding or focused_text_box() then
		return
	end
	local name = util.input_id(input)
	if not name then
		return
	end
	menu_held[name] = true
	if panic_key then
		panic_held[name] = true
		if not panic_fired and all_panic_held() then
			panic_fired = true
			fire_panic()
			return
		end
	end
	if not combo_fired and all_held() then
		combo_fired = true
		Library:ToggleUI()
	end
end)

local menu_release = env.uis.InputEnded:Connect(function(input)
	local name = util.input_id(input)
	if not name then
		return
	end
	menu_held[name] = nil
	if panic_key then
		panic_held[name] = nil
		if not all_panic_held() then
			panic_fired = false
		end
	end
	if not all_held() then
		combo_fired = false
	end
end)

function Library:Destroy()
	config.flush()
	S.splash_open = false
	if splash and splash.destroy then
		splash.destroy()
		splash = nil
	end
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
	S.env.splash:Destroy()
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

local splash_ok, splash_handle = pcall(function()
	return S.splash.mount()
end)
splash = splash_ok and splash_handle or nil
if not splash_ok then
	S.splash_open = false
end

shared.Spectrum = Library
S.library = Library
end

return S.library
