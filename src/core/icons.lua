local S = ...

local util = S.util
local style = S.style
local icons = {}

-- Named icons are rendered from locally cached Lucide spritesheets instead
-- of rbxassetid:// references. The cache keeps internal image asset IDs out of
-- the GUI; executors without local file assets fall back to the drawn icons.
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
