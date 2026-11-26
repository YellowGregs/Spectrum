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
			local marked = false
			pcall(function()
				marked = item:GetAttribute("SpectrumLayer") == true
			end)
			if marked or string.sub(item.Name, 1, 8) == "Spectrum" then
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

local owned = {}
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

sweep(holder)

local function layer(name, order)
	local gui = Instance.new("ScreenGui")
	gui.Name = gui_name(name)
	pcall(function()
		gui:SetAttribute("SpectrumLayer", true)
	end)
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
	owned[#owned + 1] = gui
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

function env.sweep_layers()
	local mine = {}
	for _, gui in ipairs(owned) do
		if typeof(gui) == "Instance" then
			mine[gui] = true
			if gui.Parent then
				pcall(function()
					gui:Destroy()
				end)
			end
		end
	end
	if type(shared.SpectrumLayers) == "table" then
		for index = #shared.SpectrumLayers, 1, -1 do
			if mine[shared.SpectrumLayers[index]] then
				table.remove(shared.SpectrumLayers, index)
			end
		end
	end
	table.clear(owned)
end

S.env = env
end

do
local env = S.env
local style = {}

local font_enums = {}
do
	local ok, items = pcall(function()
		return Enum.Font:GetEnumItems()
	end)
	if ok then
		for _, item in ipairs(items) do
			font_enums[item.Name] = item
		end
	end
end

local function font_enum(name, fallback)
	return font_enums[name] or fallback
end

local function face(label, regular, bold, mono, medium)
	return {
		label = label,
		regular = regular,
		medium = medium or bold or regular,
		bold = bold or regular,
		mono = mono or Enum.Font.Code,
	}
end

local font_sets = {
	spectrum = face("Spectrum", Enum.Font.RobotoCondensed, Enum.Font.GothamBold, Enum.Font.RobotoMono, Enum.Font.GothamMedium),
	gotham = face("Gotham", Enum.Font.Gotham, Enum.Font.GothamBold, Enum.Font.RobotoMono, Enum.Font.GothamMedium),
	black = face("Gotham Black", Enum.Font.GothamBlack),
	roboto = face("Roboto", Enum.Font.Roboto, Enum.Font.Roboto, Enum.Font.RobotoMono),
	source = face("Source Sans", Enum.Font.SourceSans, Enum.Font.SourceSansBold, Enum.Font.Code, Enum.Font.SourceSansSemibold),
	code = face("Code", Enum.Font.Code, Enum.Font.Code, Enum.Font.Code),
	arial = face("Arial", Enum.Font.Arial, Enum.Font.ArialBold, Enum.Font.Code),
	bodoni = face("Bodoni", Enum.Font.Bodoni),
	garamond = face("Garamond", Enum.Font.Garamond),
	highway = face("Highway", Enum.Font.Highway),
	cartoon = face("Cartoon", Enum.Font.Cartoon),
	scifi = face("Sci-Fi", Enum.Font.SciFi),
	arcade = face("Arcade", Enum.Font.Arcade),
	fantasy = face("Fantasy", Enum.Font.Fantasy),
	antique = face("Antique", Enum.Font.Antique),
	legacy = face("Legacy", Enum.Font.Legacy),
	amatic = face("Amatic SC", Enum.Font.AmaticSC),
	bangers = face("Bangers", Enum.Font.Bangers),
	creepster = face("Creepster", Enum.Font.Creepster),
	denkone = face("Denk One", Enum.Font.DenkOne),
	fondamento = face("Fondamento", Enum.Font.Fondamento),
	fredoka = face("Fredoka One", Enum.Font.FredokaOne),
	grenze = face("Grenze Gotisch", Enum.Font.GrenzeGotisch),
	indie = face("Indie Flower", Enum.Font.IndieFlower),
	josefin = face("Josefin Sans", Enum.Font.JosefinSans),
	jura = face("Jura", Enum.Font.Jura),
	kalam = face("Kalam", Enum.Font.Kalam),
	luckiest = face("Luckiest Guy", Enum.Font.LuckiestGuy),
	merriweather = face("Merriweather", Enum.Font.Merriweather),
	michroma = face("Michroma", Enum.Font.Michroma),
	nunito = face("Nunito", Enum.Font.Nunito),
	oswald = face("Oswald", Enum.Font.Oswald),
	patrick = face("Patrick Hand", Enum.Font.PatrickHand),
	marker = face("Permanent Marker", Enum.Font.PermanentMarker),
	sarpanch = face("Sarpanch", Enum.Font.Sarpanch),
	specialelite = face("Special Elite", Enum.Font.SpecialElite),
	titillium = face("Titillium Web", Enum.Font.TitilliumWeb),
	ubuntu = face("Ubuntu", Enum.Font.Ubuntu),
	builder = face("Builder Sans", font_enum("BuilderSans", Enum.Font.SourceSans), font_enum("BuilderSansBold", Enum.Font.SourceSansBold), Enum.Font.Code, font_enum("BuilderSansMedium", Enum.Font.SourceSansSemibold)),
	arimo = face("Arimo", font_enum("Arimo", Enum.Font.Arial), font_enum("ArimoBold", Enum.Font.ArialBold), Enum.Font.Code),
}

local font_order = {
	"spectrum",
	"gotham",
	"black",
	"roboto",
	"source",
	"code",
	"arial",
	"bodoni",
	"garamond",
	"highway",
	"cartoon",
	"scifi",
	"arcade",
	"fantasy",
	"antique",
	"legacy",
	"amatic",
	"bangers",
	"creepster",
	"denkone",
	"fondamento",
	"fredoka",
	"grenze",
	"indie",
	"josefin",
	"jura",
	"kalam",
	"luckiest",
	"merriweather",
	"michroma",
	"nunito",
	"oswald",
	"patrick",
	"marker",
	"sarpanch",
	"specialelite",
	"titillium",
	"ubuntu",
	"builder",
	"arimo",
}

local defaults = {
	accent = Color3.fromRGB(105, 146, 170),
	background = Color3.fromRGB(13, 14, 16),
	panel = Color3.fromRGB(24, 26, 29),
	hover = Color3.fromRGB(35, 38, 42),
	raised = Color3.fromRGB(18, 20, 23),
	text = Color3.fromRGB(201, 204, 208),
	muted = Color3.fromRGB(126, 132, 138),
	line = Color3.fromRGB(52, 56, 62),
	good = Color3.fromRGB(116, 196, 122),
	warn = Color3.fromRGB(230, 174, 78),
	bad = Color3.fromRGB(176, 52, 46),
	ink = Color3.fromRGB(15, 13, 9),
	radius = 0,
	font_key = "spectrum",
	font = font_sets.spectrum.regular,
	font_medium = font_sets.spectrum.medium,
	font_bold = font_sets.spectrum.bold,
	font_mono = font_sets.spectrum.mono,
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

local function font_target(role)
	if role == "regular" then
		return values.font
	elseif role == "medium" then
		return values.font_medium
	elseif role == "bold" then
		return values.font_bold
	elseif role == "mono" then
		return values.font_mono
	end
end

function style.font_role(font)
	if not font then
		return nil
	end
	if values.font_bold ~= values.font and font == values.font_bold then
		return "bold"
	end
	if values.font_medium ~= values.font and font == values.font_medium then
		return "medium"
	end
	if font == values.font then
		return "regular"
	end
	if font == values.font_mono or font == Enum.Font.Code then
		return "mono"
	end
	if font == Enum.Font.GothamBold then
		return "bold"
	end
	if font == Enum.Font.GothamMedium then
		return "medium"
	end
	if font == Enum.Font.Gotham then
		return "regular"
	end
	if font == Enum.Font.RobotoCondensed or font == Enum.Font.Roboto then
		return "regular"
	end
	if font == Enum.Font.RobotoMono then
		return "mono"
	end
	return nil
end

local function refresh_fonts()
	local layers = { env and env.windows, env and env.notes, env and env.modal, env and env.launcher, env and env.splash }
	for _, layer in ipairs(layers) do
		if layer and layer.Parent then
			local ok, list = pcall(function()
				return layer:GetDescendants()
			end)
			if ok then
				for _, object in ipairs(list) do
					if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
						local role = object:GetAttribute("SpectrumFontRole")
						if role == nil then
							role = style.font_role(object.Font)
							if role then
								object:SetAttribute("SpectrumFontRole", role)
							end
						end
						local target = font_target(role)
						if target and object.Font ~= target then
							object.Font = target
						end
					end
				end
			end
		end
	end
end

local function apply_font(name)
	local set = font_sets[name]
	if not set then
		return false
	end
	if values.font_key == name then
		return true
	end
	values.font_key = name
	values.font = set.regular
	values.font_medium = set.medium
	values.font_bold = set.bold
	values.font_mono = set.mono
	refresh_fonts()
	return true
end

local function refit_windows()
	if S.window and S.window.windows then
		for _, win in ipairs(S.window.windows) do
			if win._fit then
				pcall(win._fit, true)
			end
		end
	end
end

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

function style.font_list()
	local list = {}
	for _, key in ipairs(font_order) do
		local set = font_sets[key]
		if set then
			list[#list + 1] = { key = key, label = set.label }
		end
	end
	return list
end

function style.font_key()
	return values.font_key, font_sets[values.font_key] and font_sets[values.font_key].label
end

function style.font_set(name)
	local set = font_sets[name]
	if not set then
		return nil
	end
	return {
		key = name,
		label = set.label,
		regular = set.regular,
		medium = set.medium,
		bold = set.bold,
		mono = set.mono,
	}
end

function style.set_font(name)
	if not apply_font(name) then
		return false
	end
	for _, painter in ipairs(painters) do
		pcall(painter)
	end
	refit_windows()
	return true
end

function style.apply(props)
	if type(props) ~= "table" then
		return style.copy()
	end
	local old_font = values.font_key
	local font_name = type(props.font) == "string" and props.font
		or (type(props.font_key) == "string" and props.font_key)
	if font_name then
		apply_font(font_name)
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
	if values.font_key ~= old_font then
		refit_windows()
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

local function block(parent, x, y, width, height, color, radius)
	local shape = util.new("Frame", {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromOffset(width, height),
		ZIndex = parent.ZIndex,
		Parent = parent,
	})
	if radius then
		util.corner(shape, radius)
	end
	return shape
end

local function outline(parent, x, y, width, height, color, radius, thickness)
	local shape = block(parent, x, y, width, height, color, radius)
	shape.BackgroundTransparency = 1
	local edge = util.stroke(shape, color, 0)
	edge.Thickness = thickness or 1
	return shape
end

local function glyph(parent, size, color, draw)
	size = size or 14
	local frame = shell(parent, size)
	draw(frame, size, color or values().muted)
	return frame
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

function icons.home(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		bar(frame, 0.5, 0.34, s * 0.58, math.max(1, s * 0.1), tint, 45)
		bar(frame, 0.5, 0.34, s * 0.58, math.max(1, s * 0.1), tint, -45)
		outline(frame, 0.5, 0.63, s * 0.52, s * 0.34, tint, 1, 1)
		block(frame, 0.5, 0.69, s * 0.14, s * 0.22, tint, 0)
	end)
end

function icons.star(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		local thick = math.max(1, math.floor(s * 0.1))
		bar(frame, 0.5, 0.5, s * 0.62, thick, tint)
		bar(frame, 0.5, 0.5, s * 0.62, thick, tint, 60)
		bar(frame, 0.5, 0.5, s * 0.62, thick, tint, 120)
		dot(frame, 0.5, 0.5, s * 0.18, tint)
	end)
end

function icons.heart(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		dot(frame, 0.36, 0.36, s * 0.3, tint)
		dot(frame, 0.64, 0.36, s * 0.3, tint)
		local point = block(frame, 0.5, 0.58, s * 0.42, s * 0.42, tint, 1)
		point.Rotation = 45
	end)
end

function icons.bell(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		ring(frame, 0.5, 0.38, s * 0.42, tint, math.max(1, s * 0.09))
		block(frame, 0.5, 0.58, s * 0.42, s * 0.24, tint, 1)
		dot(frame, 0.5, 0.78, s * 0.12, tint)
	end)
end

function icons.calendar(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		outline(frame, 0.5, 0.54, s * 0.66, s * 0.54, tint, 1, 1)
		bar(frame, 0.5, 0.25, s * 0.46, math.max(1, s * 0.08), tint)
		dot(frame, 0.36, 0.55, s * 0.1, tint)
		dot(frame, 0.64, 0.55, s * 0.1, tint)
		dot(frame, 0.36, 0.72, s * 0.1, tint)
	end)
end

function icons.clock(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		ring(frame, 0.5, 0.5, s * 0.7, tint, math.max(1, s * 0.08))
		bar(frame, 0.5, 0.42, math.max(1, s * 0.08), s * 0.24, tint)
		bar(frame, 0.58, 0.52, s * 0.2, math.max(1, s * 0.08), tint)
	end)
end

function icons.mail(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		outline(frame, 0.5, 0.52, s * 0.7, s * 0.5, tint, 1, 1)
		bar(frame, 0.34, 0.42, s * 0.32, math.max(1, s * 0.07), tint, 35)
		bar(frame, 0.66, 0.42, s * 0.32, math.max(1, s * 0.07), tint, -35)
	end)
end

function icons.phone(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		local thick = math.max(2, s * 0.12)
		bar(frame, 0.5, 0.5, s * 0.58, thick, tint, 45)
		dot(frame, 0.25, 0.25, s * 0.2, tint)
		dot(frame, 0.75, 0.75, s * 0.2, tint)
	end)
end

function icons.map(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		outline(frame, 0.28, 0.5, s * 0.24, s * 0.58, tint, 0, 1)
		outline(frame, 0.5, 0.5, s * 0.24, s * 0.58, tint, 0, 1)
		outline(frame, 0.72, 0.5, s * 0.24, s * 0.58, tint, 0, 1)
		bar(frame, 0.4, 0.5, math.max(1, s * 0.07), s * 0.5, tint)
		bar(frame, 0.6, 0.5, math.max(1, s * 0.07), s * 0.5, tint)
	end)
end

function icons.pin(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		ring(frame, 0.5, 0.36, s * 0.46, tint, math.max(1, s * 0.08))
		local point = block(frame, 0.5, 0.62, s * 0.24, s * 0.24, tint, 1)
		point.Rotation = 45
		dot(frame, 0.5, 0.36, s * 0.12, tint)
	end)
end

function icons.camera(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		block(frame, 0.5, 0.57, s * 0.7, s * 0.42, tint, 1)
		block(frame, 0.38, 0.3, s * 0.22, s * 0.1, tint, 1)
		ring(frame, 0.5, 0.57, s * 0.3, tint, math.max(1, s * 0.08))
	end)
end

function icons.picture(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		outline(frame, 0.5, 0.5, s * 0.7, s * 0.56, tint, 1, 1)
		dot(frame, 0.34, 0.36, s * 0.12, tint)
		bar(frame, 0.42, 0.62, s * 0.34, math.max(1, s * 0.08), tint, -28)
		bar(frame, 0.62, 0.6, s * 0.26, math.max(1, s * 0.08), tint, 32)
	end)
end

function icons.music(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		bar(frame, 0.62, 0.42, math.max(1, s * 0.09), s * 0.46, tint)
		dot(frame, 0.44, 0.76, s * 0.2, tint)
		bar(frame, 0.62, 0.28, s * 0.3, math.max(1, s * 0.09), tint, 18)
	end)
end

function icons.video(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		block(frame, 0.44, 0.5, s * 0.52, s * 0.46, tint, 1)
		local lens = block(frame, 0.76, 0.5, s * 0.2, s * 0.24, tint, 1)
		lens.Rotation = 0
		bar(frame, 0.44, 0.5, s * 0.24, math.max(1, s * 0.1), tint, 45)
		bar(frame, 0.44, 0.5, s * 0.24, math.max(1, s * 0.1), tint, -45)
	end)
end

function icons.play(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		bar(frame, 0.55, 0.5, s * 0.5, math.max(1, s * 0.1), tint, 45)
		bar(frame, 0.55, 0.5, s * 0.5, math.max(1, s * 0.1), tint, -45)
		bar(frame, 0.74, 0.5, math.max(1, s * 0.1), s * 0.42, tint)
	end)
end

function icons.pause(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		bar(frame, 0.38, 0.5, math.max(2, s * 0.12), s * 0.46, tint)
		bar(frame, 0.62, 0.5, math.max(2, s * 0.12), s * 0.46, tint)
	end)
end

function icons.download(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		bar(frame, 0.5, 0.42, math.max(1, s * 0.09), s * 0.34, tint)
		bar(frame, 0.5, 0.58, s * 0.32, math.max(1, s * 0.09), tint, 45)
		bar(frame, 0.5, 0.58, s * 0.32, math.max(1, s * 0.09), tint, -45)
		bar(frame, 0.5, 0.8, s * 0.56, math.max(1, s * 0.08), tint)
	end)
end

function icons.upload(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		bar(frame, 0.5, 0.42, math.max(1, s * 0.09), s * 0.34, tint)
		bar(frame, 0.5, 0.28, s * 0.32, math.max(1, s * 0.09), tint, 45)
		bar(frame, 0.5, 0.28, s * 0.32, math.max(1, s * 0.09), tint, -45)
		bar(frame, 0.5, 0.8, s * 0.56, math.max(1, s * 0.08), tint)
	end)
end

function icons.link(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		ring(frame, 0.34, 0.5, s * 0.36, tint, math.max(1, s * 0.08))
		ring(frame, 0.66, 0.5, s * 0.36, tint, math.max(1, s * 0.08))
		bar(frame, 0.5, 0.5, s * 0.3, math.max(1, s * 0.08), tint)
	end)
end

function icons.share(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		dot(frame, 0.24, 0.5, s * 0.16, tint)
		dot(frame, 0.76, 0.28, s * 0.16, tint)
		dot(frame, 0.76, 0.72, s * 0.16, tint)
		bar(frame, 0.5, 0.39, s * 0.38, math.max(1, s * 0.07), tint, -28)
		bar(frame, 0.5, 0.61, s * 0.38, math.max(1, s * 0.07), tint, 28)
	end)
end

function icons.edit(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		bar(frame, 0.52, 0.48, s * 0.56, math.max(2, s * 0.12), tint, -45)
		dot(frame, 0.26, 0.74, s * 0.14, tint)
	end)
end

function icons.filter(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		bar(frame, 0.5, 0.28, s * 0.62, math.max(1, s * 0.08), tint)
		bar(frame, 0.5, 0.5, s * 0.42, math.max(1, s * 0.08), tint)
		bar(frame, 0.5, 0.72, s * 0.22, math.max(1, s * 0.08), tint)
	end)
end

function icons.grid(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		for _, spot in ipairs({ { 0.32, 0.32 }, { 0.68, 0.32 }, { 0.32, 0.68 }, { 0.68, 0.68 } }) do
			block(frame, spot[1], spot[2], s * 0.24, s * 0.24, tint, 1)
		end
	end)
end

function icons.list(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		for index = 0, 2 do
			dot(frame, 0.24, 0.3 + index * 0.2, s * 0.1, tint)
			bar(frame, 0.56, 0.3 + index * 0.2, s * 0.4, math.max(1, s * 0.07), tint)
		end
	end)
end

function icons.layers(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		for index = 0, 2 do
			local layer = block(frame, 0.5, 0.32 + index * 0.2, s * 0.5, s * 0.24, tint, 1)
			layer.Rotation = 45
		end
	end)
end

function icons.database(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		outline(frame, 0.5, 0.5, s * 0.52, s * 0.54, tint, 4, 1)
		bar(frame, 0.5, 0.32, s * 0.52, math.max(1, s * 0.07), tint)
		bar(frame, 0.5, 0.5, s * 0.52, math.max(1, s * 0.07), tint)
		bar(frame, 0.5, 0.68, s * 0.52, math.max(1, s * 0.07), tint)
	end)
end

function icons.server(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		outline(frame, 0.5, 0.36, s * 0.62, s * 0.26, tint, 1, 1)
		outline(frame, 0.5, 0.68, s * 0.62, s * 0.26, tint, 1, 1)
		dot(frame, 0.3, 0.36, s * 0.08, tint)
		dot(frame, 0.3, 0.68, s * 0.08, tint)
	end)
end

function icons.cloud(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		dot(frame, 0.34, 0.48, s * 0.3, tint)
		dot(frame, 0.56, 0.38, s * 0.36, tint)
		dot(frame, 0.72, 0.52, s * 0.24, tint)
		bar(frame, 0.5, 0.64, s * 0.62, math.max(1, s * 0.14), tint)
	end)
end

function icons.wifi(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		bar(frame, 0.5, 0.48, s * 0.62, math.max(1, s * 0.08), tint, 30)
		bar(frame, 0.5, 0.48, s * 0.62, math.max(1, s * 0.08), tint, -30)
		bar(frame, 0.5, 0.36, s * 0.4, math.max(1, s * 0.08), tint, 30)
		bar(frame, 0.5, 0.36, s * 0.4, math.max(1, s * 0.08), tint, -30)
		dot(frame, 0.5, 0.72, s * 0.14, tint)
	end)
end

function icons.battery(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		outline(frame, 0.48, 0.5, s * 0.62, s * 0.38, tint, 1, 1)
		block(frame, 0.84, 0.5, s * 0.08, s * 0.18, tint, 1)
		block(frame, 0.42, 0.5, s * 0.3, s * 0.2, tint, 0)
	end)
end

function icons.power(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		ring(frame, 0.5, 0.52, s * 0.62, tint, math.max(1, s * 0.09))
		bar(frame, 0.5, 0.34, math.max(1, s * 0.09), s * 0.26, tint)
	end)
end

function icons.sun(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		dot(frame, 0.5, 0.5, s * 0.28, tint)
		for index = 0, 7 do
			local angle = math.rad(index * 45)
			bar(frame, 0.5 + math.cos(angle) * 0.38, 0.5 + math.sin(angle) * 0.38, s * 0.16, math.max(1, s * 0.07), tint, index * 45)
		end
	end)
end

function icons.fire(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		bar(frame, 0.5, 0.55, s * 0.38, math.max(1, s * 0.1), tint, 20)
		bar(frame, 0.42, 0.5, s * 0.34, math.max(1, s * 0.1), tint, -25)
		bar(frame, 0.58, 0.5, s * 0.34, math.max(1, s * 0.1), tint, 25)
		dot(frame, 0.5, 0.72, s * 0.18, tint)
	end)
end

function icons.drop(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		local shape = block(frame, 0.5, 0.56, s * 0.38, s * 0.38, tint, 1)
		shape.Rotation = 45
		dot(frame, 0.5, 0.62, s * 0.12, tint)
	end)
end

function icons.crown(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		bar(frame, 0.5, 0.66, s * 0.58, math.max(1, s * 0.1), tint)
		bar(frame, 0.3, 0.5, s * 0.18, math.max(1, s * 0.1), tint, 45)
		bar(frame, 0.5, 0.46, s * 0.18, math.max(1, s * 0.1), tint)
		bar(frame, 0.7, 0.5, s * 0.18, math.max(1, s * 0.1), tint, -45)
		dot(frame, 0.5, 0.7, s * 0.1, tint)
	end)
end

function icons.gem(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		local shape = outline(frame, 0.5, 0.5, s * 0.48, s * 0.48, tint, 1, 1)
		shape.Rotation = 45
		bar(frame, 0.5, 0.5, s * 0.3, math.max(1, s * 0.07), tint)
		bar(frame, 0.5, 0.5, s * 0.3, math.max(1, s * 0.07), tint, 90)
	end)
end

function icons.gift(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		block(frame, 0.5, 0.6, s * 0.58, s * 0.38, tint, 1)
		bar(frame, 0.5, 0.5, math.max(1, s * 0.1), s * 0.5, tint)
		bar(frame, 0.5, 0.5, s * 0.58, math.max(1, s * 0.08), tint)
		dot(frame, 0.35, 0.32, s * 0.16, tint)
		dot(frame, 0.65, 0.32, s * 0.16, tint)
	end)
end

function icons.tag(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		local shape = block(frame, 0.5, 0.5, s * 0.5, s * 0.5, tint, 1)
		shape.Rotation = 45
		dot(frame, 0.62, 0.38, s * 0.12, tint)
	end)
end

function icons.bookmark(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		block(frame, 0.5, 0.46, s * 0.4, s * 0.56, tint, 1)
		bar(frame, 0.38, 0.72, s * 0.18, math.max(1, s * 0.08), tint, 45)
		bar(frame, 0.62, 0.72, s * 0.18, math.max(1, s * 0.08), tint, -45)
	end)
end

function icons.flag(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		bar(frame, 0.3, 0.5, math.max(1, s * 0.09), s * 0.62, tint)
		block(frame, 0.56, 0.36, s * 0.4, s * 0.26, tint, 1)
		bar(frame, 0.56, 0.56, s * 0.4, math.max(1, s * 0.08), tint)
	end)
end

function icons.compass(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		ring(frame, 0.5, 0.5, s * 0.68, tint, math.max(1, s * 0.08))
		bar(frame, 0.5, 0.5, s * 0.3, math.max(1, s * 0.08), tint, 45)
		bar(frame, 0.5, 0.5, s * 0.3, math.max(1, s * 0.08), tint, -45)
	end)
end

function icons.rocket(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		block(frame, 0.5, 0.5, s * 0.28, s * 0.48, tint, 4)
		bar(frame, 0.36, 0.66, s * 0.2, math.max(1, s * 0.1), tint, 45)
		bar(frame, 0.64, 0.66, s * 0.2, math.max(1, s * 0.1), tint, -45)
		dot(frame, 0.5, 0.42, s * 0.12, tint)
		bar(frame, 0.5, 0.8, s * 0.14, math.max(1, s * 0.08), tint)
	end)
end

function icons.plane(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		bar(frame, 0.5, 0.5, s * 0.64, math.max(1, s * 0.1), tint, -18)
		bar(frame, 0.5, 0.5, s * 0.44, math.max(1, s * 0.1), tint, 72)
		bar(frame, 0.36, 0.6, s * 0.22, math.max(1, s * 0.08), tint, 45)
		bar(frame, 0.64, 0.4, s * 0.22, math.max(1, s * 0.08), tint, 45)
	end)
end

function icons.car(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		block(frame, 0.5, 0.55, s * 0.68, s * 0.24, tint, 2)
		bar(frame, 0.5, 0.42, s * 0.38, math.max(1, s * 0.08), tint)
		dot(frame, 0.32, 0.72, s * 0.14, tint)
		dot(frame, 0.68, 0.72, s * 0.14, tint)
	end)
end

function icons.smartphone(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		outline(frame, 0.5, 0.5, s * 0.38, s * 0.7, tint, 2, 1)
		dot(frame, 0.5, 0.74, s * 0.08, tint)
	end)
end

function icons.monitor(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		outline(frame, 0.5, 0.42, s * 0.66, s * 0.44, tint, 1, 1)
		bar(frame, 0.5, 0.72, s * 0.2, math.max(1, s * 0.08), tint)
		bar(frame, 0.5, 0.82, s * 0.38, math.max(1, s * 0.08), tint)
	end)
end

function icons.mouse(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		outline(frame, 0.5, 0.5, s * 0.36, s * 0.58, tint, 8, 1)
		bar(frame, 0.5, 0.34, math.max(1, s * 0.07), s * 0.18, tint)
	end)
end

function icons.keyboard(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		outline(frame, 0.5, 0.55, s * 0.7, s * 0.38, tint, 1, 1)
		for index = 0, 3 do
			dot(frame, 0.32 + index * 0.12, 0.48, s * 0.06, tint)
			dot(frame, 0.32 + index * 0.12, 0.62, s * 0.06, tint)
		end
	end)
end

function icons.gamepad(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		outline(frame, 0.5, 0.55, s * 0.68, s * 0.34, tint, 4, 1)
		bar(frame, 0.32, 0.55, s * 0.14, math.max(1, s * 0.08), tint)
		bar(frame, 0.32, 0.55, math.max(1, s * 0.08), s * 0.14, tint)
		dot(frame, 0.68, 0.48, s * 0.08, tint)
		dot(frame, 0.78, 0.62, s * 0.08, tint)
	end)
end

function icons.volume(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		block(frame, 0.3, 0.5, s * 0.18, s * 0.24, tint, 1)
		bar(frame, 0.46, 0.5, s * 0.22, math.max(1, s * 0.08), tint, 45)
		bar(frame, 0.46, 0.5, s * 0.22, math.max(1, s * 0.08), tint, -45)
		ring(frame, 0.56, 0.5, s * 0.42, tint, math.max(1, s * 0.07))
	end)
end

function icons.mic(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		block(frame, 0.5, 0.4, s * 0.22, s * 0.38, tint, 8)
		bar(frame, 0.5, 0.68, s * 0.32, math.max(1, s * 0.08), tint)
		bar(frame, 0.5, 0.8, math.max(1, s * 0.08), s * 0.16, tint)
	end)
end

function icons.headphones(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		ring(frame, 0.5, 0.44, s * 0.58, tint, math.max(1, s * 0.08))
		block(frame, 0.26, 0.58, s * 0.14, s * 0.28, tint, 2)
		block(frame, 0.74, 0.58, s * 0.14, s * 0.28, tint, 2)
	end)
end

function icons.terminal(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		outline(frame, 0.5, 0.5, s * 0.68, s * 0.54, tint, 1, 1)
		bar(frame, 0.34, 0.42, s * 0.14, math.max(1, s * 0.08), tint, 45)
		bar(frame, 0.34, 0.56, s * 0.14, math.max(1, s * 0.08), tint, -45)
		bar(frame, 0.62, 0.62, s * 0.2, math.max(1, s * 0.07), tint)
	end)
end

function icons.bug(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		block(frame, 0.5, 0.52, s * 0.26, s * 0.34, tint, 4)
		dot(frame, 0.5, 0.32, s * 0.14, tint)
		for index = 0, 2 do
			bar(frame, 0.5, 0.44 + index * 0.12, s * 0.52, math.max(1, s * 0.06), tint)
		end
	end)
end

function icons.skull(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		ring(frame, 0.5, 0.42, s * 0.54, tint, math.max(1, s * 0.09))
		dot(frame, 0.38, 0.42, s * 0.1, tint)
		dot(frame, 0.62, 0.42, s * 0.1, tint)
		block(frame, 0.5, 0.7, s * 0.26, s * 0.16, tint, 1)
	end)
end

function icons.ghost(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		ring(frame, 0.5, 0.46, s * 0.56, tint, math.max(1, s * 0.08))
		block(frame, 0.5, 0.66, s * 0.52, s * 0.2, tint, 2)
		dot(frame, 0.38, 0.44, s * 0.08, tint)
		dot(frame, 0.62, 0.44, s * 0.08, tint)
	end)
end

function icons.alien(parent, size, color)
	return glyph(parent, size, color, function(frame, s, tint)
		ring(frame, 0.5, 0.46, s * 0.56, tint, math.max(1, s * 0.08))
		dot(frame, 0.36, 0.46, s * 0.12, tint)
		dot(frame, 0.64, 0.46, s * 0.12, tint)
		bar(frame, 0.5, 0.7, s * 0.18, math.max(1, s * 0.07), tint)
	end)
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
	home = icons.home,
	house = icons.home,
	star = icons.star,
	favorite = icons.star,
	heart = icons.heart,
	like = icons.heart,
	bell = icons.bell,
	notification = icons.bell,
	calendar = icons.calendar,
	schedule = icons.calendar,
	clock = icons.clock,
	time = icons.clock,
	mail = icons.mail,
	email = icons.mail,
	phone = icons.phone,
	call = icons.phone,
	map = icons.map,
	pin = icons.pin,
	location = icons.pin,
	camera = icons.camera,
	photo = icons.camera,
	image = icons.picture,
	picture = icons.picture,
	music = icons.music,
	audio = icons.music,
	video = icons.video,
	film = icons.video,
	play = icons.play,
	pause = icons.pause,
	download = icons.download,
	upload = icons.upload,
	link = icons.link,
	share = icons.share,
	edit = icons.edit,
	pencil = icons.edit,
	filter = icons.filter,
	grid = icons.grid,
	apps = icons.grid,
	list = icons.list,
	rows = icons.list,
	layers = icons.layers,
	database = icons.database,
	data = icons.database,
	server = icons.server,
	host = icons.server,
	cloud = icons.cloud,
	wifi = icons.wifi,
	signal = icons.wifi,
	battery = icons.battery,
	power = icons.power,
	sun = icons.sun,
	light = icons.sun,
	fire = icons.fire,
	flame = icons.fire,
	drop = icons.drop,
	water = icons.drop,
	crown = icons.crown,
	gem = icons.gem,
	diamond = icons.gem,
	gift = icons.gift,
	present = icons.gift,
	tag = icons.tag,
	label = icons.tag,
	bookmark = icons.bookmark,
	flag = icons.flag,
	compass = icons.compass,
	rocket = icons.rocket,
	plane = icons.plane,
	car = icons.car,
	smartphone = icons.smartphone,
	mobile = icons.smartphone,
	monitor = icons.monitor,
	screen = icons.monitor,
	mouse = icons.mouse,
	keyboard = icons.keyboard,
	gamepad = icons.gamepad,
	controller = icons.gamepad,
	volume = icons.volume,
	sound = icons.volume,
	mic = icons.mic,
	microphone = icons.mic,
	headphones = icons.headphones,
	terminal = icons.terminal,
	console = icons.terminal,
	bug = icons.bug,
	skull = icons.skull,
	ghost = icons.ghost,
	alien = icons.alien,
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
	status = "none",
	error = nil,
}

local scales = {
	crop = Enum.ScaleType.Crop,
	fit = Enum.ScaleType.Fit,
	stretch = Enum.ScaleType.Stretch,
}

local hosts = {}
local requests = {}
local generation = 0
local probe
local type_cache = {}

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

local function numeric_id(source)
	if type(source) ~= "string" then
		return nil
	end
	local id = string.match(source, "^rbxassetid://(%d+)$")
	if not id then
		id = string.match(source, "[?&]id=(%d+)")
	end
	if not id and string.match(source, "^%d+$") then
		id = source
	end
	return id and tonumber(id) or nil
end

local function thumb(id)
	return string.format("rbxthumb://type=Asset&id=%d&w=420&h=420", id)
end

local function asset_type(id)
	if type_cache[id] ~= nil then
		return type_cache[id] or nil
	end
	local marketplace = game:GetService("MarketplaceService")
	local ok, info = pcall(function()
		return marketplace:GetProductInfoAsync(id, Enum.InfoType.Asset)
	end)
	if not ok then
		ok, info = pcall(function()
			return marketplace:GetProductInfo(id, Enum.InfoType.Asset)
		end)
	end
	local kind = ok and type(info) == "table" and tonumber(info.AssetTypeId) or nil
	type_cache[id] = kind or false
	return kind
end

local function resolve(source)
	local id = numeric_id(source)
	if not id then
		return source
	end
	local kind = asset_type(id)
	if kind == 1 then
		return source
	elseif kind == 13 or kind == nil then
		return thumb(id)
	end
	return nil, "That asset is not an image or a decal."
end

local function publish()
	for _, host in ipairs(hosts) do
		pcall(host, state)
	end
end

local function invoke(callback, result, ok, reason)
	if type(callback) ~= "function" then
		return
	end
	task.spawn(function()
		pcall(callback, result, ok, reason)
	end)
end

local function settle(token, ok, reason)
	if token ~= generation then
		return
	end
	state.status = ok and "applied" or "failed"
	state.error = ok and nil or reason
	publish()
	local callback = requests[token]
	requests[token] = nil
	invoke(callback, background.get(), ok, reason)
end

local function stop_probe()
	local current = probe
	probe = nil
	if current then
		pcall(function()
			current:Destroy()
		end)
	end
end

local function start_probe(source)
	local parent = S.env and S.env.windows
	if not parent then
		return nil
	end
	local label = Instance.new("ImageLabel")
	label.Name = "SpectrumBackgroundProbe"
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Image = source
	label.ImageColor3 = Color3.new(1, 1, 1)
	label.ImageTransparency = 0
	label.ScaleType = Enum.ScaleType.Stretch
	label.Position = UDim2.fromOffset(0, 0)
	label.Size = UDim2.fromOffset(1, 1)
	label.Visible = true
	label.ZIndex = 1000
	local placed = pcall(function()
		label.Parent = parent
	end)
	if not placed then
		label:Destroy()
		return nil
	end
	return label
end

local function validate(source, token)
	local label = start_probe(source)
	if not label then
		settle(token, false, "Could not check the image.")
		return
	end
	probe = label
	local provider = game:GetService("ContentProvider")
	local success = Enum.AssetFetchStatus.Success
	local failure = Enum.AssetFetchStatus.Failure
	local timed_out = Enum.AssetFetchStatus.TimedOut
	task.spawn(function()
		local deadline = os.clock() + 8
		local loaded = false
		while token == generation and probe == label and os.clock() < deadline do
			if not label.Parent then
				break
			end
			local read_ok, is_loaded = pcall(function()
				return label.IsLoaded
			end)
			if read_ok and is_loaded then
				loaded = true
				break
			end
			local status_ok, status = pcall(function()
				return provider:GetAssetFetchStatus(source)
			end)
			if status_ok then
				if status == success then
					loaded = true
					break
				elseif status == failure or status == timed_out then
					break
				end
			end
			task.wait(0.1)
		end
		if probe == label then
			probe = nil
		end
		pcall(function()
			label:Destroy()
		end)
		if token ~= generation then
			return
		end
		settle(token, loaded, loaded and nil or "The image could not be loaded. Check the asset ID and its permissions.")
	end)
end

local function cancel_pending(reason)
	local pending = requests
	requests = {}
	for _, callback in pairs(pending) do
		invoke(callback, background.get(), false, reason)
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

function background.set(asset, opts, callback)
	local source = asset_id(asset)
	generation = generation + 1
	local token = generation
	stop_probe()
	cancel_pending("replaced")
	if not source then
		state.asset = nil
		state.status = "none"
		state.error = nil
		publish()
		invoke(callback, background.get(), false, "Enter an image asset ID.")
		return background.get()
	end
	normalize(opts)
	state.asset = source
	state.status = "loading"
	state.error = nil
	publish()
	if callback then
		requests[token] = callback
	end
	task.spawn(function()
		local resolved, problem = resolve(source)
		if token ~= generation then
			return
		end
		if not resolved then
			settle(token, false, problem or "That asset is not an image or a decal.")
			return
		end
		if resolved ~= source then
			state.asset = resolved
			publish()
		end
		validate(resolved, token)
	end)
	return background.get()
end

function background.get()
	return {
		asset = state.asset,
		transparency = state.transparency,
		tint = state.tint,
		scrim = state.scrim,
		scale = state.scale,
		status = state.status,
		error = state.error,
	}
end

function background.clear()
	generation = generation + 1
	stop_probe()
	state.asset = nil
	state.status = "none"
	state.error = nil
	publish()
	cancel_pending("cancelled")
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
local sounds = S.sounds
local function bold()
	return style.values.font_bold
end
local function font()
	return style.values.font
end

local options = {}
local panel
local edge
local title_label
local close_hit
local action_list
local close_button
local active_play_sound

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
	util.depth(panel, 0.7)
	edge = util.stroke(panel, values().line, 0.05)
	util.shadow(panel, 28, 0.2)

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
		Font = bold(),
		Text = "OPTIONS",
		TextColor3 = values().text,
		TextSize = util.size(9),
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
	util.corner(close_hit, 0)
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
	if active_play_sound then
		active_play_sound("open")
	elseif sounds then
		sounds.play("open")
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

			title_label.Text = string.upper(tostring(title or "OPTIONS"))
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
			Font = font(),
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
		util.corner(row, 0)
		util.hover(row)

		local text = util.new("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(9, 0),
			Size = UDim2.new(1, -22, 1, 0),
			Font = action.accent and bold() or font(),
			Text = string.upper(label),
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
			if active_play_sound then
				active_play_sound("click")
			elseif sounds then
				sounds.play("click")
			end
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

function options.attach(row, title, build, play_sound)
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
			active_play_sound = type(play_sound) == "function" and play_sound or nil
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
local scheduled_thread
local auto_save_enabled = false
local dirty = false
local last_body
local error_message

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
		sections = {},
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
	data.sections = type(data.sections) == "table" and data.sections or {}
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
		return false
	end
	local ok, parsed = pcall(function()
		return http:JSONDecode(body)
	end)
	if not ok or type(parsed) ~= "table" then
		return false
	end
	data = parsed
	normalize()
	return true
end

function config.load(name)
	if name then
		local target = name_of(name)
		if target ~= profile and (dirty or auto_save_enabled) then
			config.save()
		end
		profile = target
	end
	local file = path(profile)
	data = fresh()
	if can_read() and isfile(file) then
		local ok, body = pcall(readfile, file)
		if ok and type(body) == "string" and body ~= "" then
			if not decode(body) then
				if can_write() then
					pcall(writefile, file .. ".corrupt", body)
				end
				local backup_file = file .. ".bak"
				if isfile(backup_file) then
					local ok_backup, backup_body = pcall(readfile, backup_file)
					if ok_backup and type(backup_body) == "string" then
						decode(backup_body)
					end
				end
			end
		end
	elseif shared.SpectrumConfigs and type(shared.SpectrumConfigs[profile]) == "table" then
		data = copy(shared.SpectrumConfigs[profile])
		normalize()
	end
	auto_save_enabled = type(data.settings) == "table" and data.settings.auto_save == true
	dirty = false
	last_body = nil
	return config.apply()
end

function config.save(name)
	if name then
		profile = name_of(name)
	end
	normalize()
	data.settings.auto_save = auto_save_enabled
	local file = path(profile)
	local body = encode()
	if not body then
		error_message = "profile could not be encoded"
		return false
	end
	shared.SpectrumConfigs = shared.SpectrumConfigs or {}
	shared.SpectrumConfigs[profile] = copy(data)
	if body == last_body and (type(isfile) ~= "function" or isfile(file)) then
		dirty = false
		return true
	end
	if not can_write() then
		error_message = "executor has no writefile or makefolder"
		return false
	end
	ensure(ROOT)
	local ok_previous, previous = pcall(readfile, file)
	if ok_previous and type(previous) == "string" and previous ~= "" then
		pcall(writefile, file .. ".bak", previous)
	end
	if not pcall(writefile, file, body) then
		error_message = "could not write " .. file
		dirty = true
		return false
	end
	last_body = body
	error_message = nil
	dirty = false
	return true
end

function config.touch()
	dirty = true
	if not auto_save_enabled then
		return
	end
	if scheduled then
		return
	end
	scheduled = true
	scheduled_thread = task.delay(0.8, function()
		scheduled = false
		scheduled_thread = nil
		if auto_save_enabled then
			config.save()
		end
	end)
end

function config.cancel()
	if scheduled_thread then
		pcall(task.cancel, scheduled_thread)
		scheduled_thread = nil
	end
	scheduled = false
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

function config.section_state(key, id)
	local sections = data.sections[key]
	if type(sections) ~= "table" then
		return nil
	end
	local value = sections[id]
	if value == nil then
		return nil
	end
	return value == true
end

function config.place_section(key, id, open)
	data.sections[key] = type(data.sections[key]) == "table" and data.sections[key] or {}
	data.sections[key][id] = open == true
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
		if api.restore then
			local saved = data.windows[win]
			pcall(api.restore, saved or {})
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

function config.featurelist_state()
	return data.settings and data.settings.feature_list
end

function config.sound_state()
	local state = data.settings and data.settings.sounds
	if type(state) ~= "table" then
		return nil
	end
	return {
		enabled = state.enabled ~= false,
		volume = math.clamp(tonumber(state.volume) or 0.4, 0, 1),
	}
end

function config.place_sounds(state)
	if type(state) ~= "table" then
		return
	end
	data.settings = type(data.settings) == "table" and data.settings or {}
	data.settings.sounds = {
		enabled = state.enabled ~= false,
		volume = math.clamp(tonumber(state.volume) or 0.4, 0, 1),
	}
	config.touch()
end

function config.place_featurelist(state)
	if type(state) ~= "table" then
		return
	end
	data.settings = type(data.settings) == "table" and data.settings or {}
	data.settings.feature_list = {
		v = 1,
		x = tonumber(state.x) or -12,
		y = tonumber(state.y) or 12,
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

function config.file()
	return path(profile)
end

function config.last_error()
	return error_message
end

function config.pending()
	return dirty
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
local SIZE = 40

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
	util.corner(button, 0)
	util.depth(button, 0.75)
	local edge = util.stroke(button, values().line, 0.05)
	util.shadow(button, 20, 0.32)

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
		edge.Transparency = open and 0.45 or 0.15
		menu.Visible = not open
		close.Visible = open
		icons.tint(menu, values().text)
		icons.tint(close, open and values().accent or values().text)
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
S.sounddata = {
	files = {
		["bubble_pop.mp3"] = {
			bytes = 3343,
			data = table.concat({
				"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",
				"ZgcYDEWAGMGBFAxUCpAwiBFgYRQiwiEQIhEBgRcIipgwIsIioBgRcDCIEX/4RCJ//wYET4RCJ+DAiwYEUDCIEQDCKKgGBFCIRQYEWEQigYqRUfAwiBF8IipAxUL4A+bQhAy2IzhEIgMCKEQiQiEUDCKdAD2nUgDX",
				"ydAGBF+ERUgaMpzgZbAigwIgAA2gAANAVMPQGIwBwFiEBH/NVuWQwJRTgUAQYBIFH+YYYOJgZBnGBKAoYCIC3+d0andtRgo4NC/+ZuDmZmxjoAYEBvq/P/5gYKCiIKgQkDJUvq7rs//+Agpk1UHATsRGHYzEZ3//",
				"/aSmM7KdNaMZY8rb/////noFIx2K8vyxrX9dx////9xAMXGmJ5mhmCQCxb792Ko3OFDc4VO+Hy5QLBk4CpW78oBBhwMFEhFip4t/4eB8uPPh8uj/tK2oIDQIAAAAGAmBeYZwFRgJgOGAgCD/mpDMsYAAmRgCANGA",
				"WBZ/mFeC+YGAYhgfgVGBOBl/ngH51rkYGNFYb/mbiZlp0CiYuTDNT/8wMBQDJjEwG9PMoB//8CgCeTA0HpP+5Tv///9bbvPG5Mvv1fxq7x////wZCncoVL7f47xq7pZT////90w8INISzNDcKhmdJh8RdVCc4Uri",
				"Cj3hgCFwiHj4NFlP/LicefD5coOaVnRKi7+GQQKDDgYKJ/qsLTxMQU1FMy4xMDCqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqr/+9JkAA/wAABpBwAA",
				"CAAADSDgAAEAAAGkAAAAIAAANIAAAARMQU1FMy4xMDCqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqTEFNRTMuMTAwqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqg==",
			}),
		},
		["click-soft.mp3"] = {
			bytes = 49319,
			data = table.concat({
				"//vQZAAABxs3toV7YAAAAA0goAABEVIjABnzgAgAADSDAAAAMGgP8yr0VTWzaPNrthU0jR9zJQUWNvZ+g3yGcDPeBsM6hOY01D7DLGGqMLYAswgwmQEG2YMgXhh3B8GG8E4cuymytpt7Sa6nmjn5nJqZiWmVlJk4",
				"+ZURGQDxjQwYoJGIBhhgUYQDGDAxggAYSCmBgYCAyzZbcuWgHQDpFoOIqJiJiKkVIuxdjEF3rvZ2ztnbluW5bvuQ5DkP4/j+P5DkYh+NxuNxuNxuNy+WUlJSUlJSUlJT09PT09PnT26SkpMMMMMMKentg+D4fiAE",
				"AQcsHwfggCAIO+UOf////qBDdxIcB8PmB2Ajpg6IuWYBKE/GEMpbJhDIJgY4sBimgLl4phlQGybNudzGA0jlB9byVMYsuSEmB1gNBQAMGE/AQhgHIBOYOsCSmAkgFA+ACt4SoNn3SSmt/////9v///rX3mVZHl5s",
				"clHKOYUlf/ufb+yd+n//////t/8y0ff///lAxNiJP//7XmigMoZFxE1ETEFNRTMuMTAwqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqv/70mQA",
				"CPRAecAHfaAAAAANIOAAAQ5Z2w0v9KcAAAA0gAAABDAJQCswLwBdMAcBbzB3gQgw1cJ2MM/OZjilxMw+WgjBMUOJZTGLwrwwoskmMP4D3DBpQAgwDkBkC4ByHAGCBEkABAQAvkw/29v39v1/+6+3+3V/ZXqX6C31",
				"GRq/GIgn6BR6mHYq2n7r+v9/V////+q3f6n9d/f1ooajYKv6Zsca1Y1kDrWW1hUYCEEAwEMBIMBIAXTAYwIowJoDlMEdBwDCrhRc0Ufn5MwyHXTgNXjHg0zjGYDY5ujMgXTEMHDBYBQEDSFL5vi+0ty0/b5Pr/9P",
				"Vf//3/+v3vwmvhIc9aMD9IX9vp9f//////6//+v7/P40Bk8cjdAsMyelMQU1FMy4xMDCqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqpMQU1FMy4xMDCqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqgABvdsRAAMATAJjAHwHUwD4C4MB3BGzBJAoQwd8//vSZA6I9SV2",
				"w9P7UvAAAA0gAAABEyHnDU+ZUUAAADSAAAAEarMka/MTf9yI8wuwLaMGaBljCuRHMwDgERPsRDPwMMMDGQVKxK8svMUzOHUgNr8Dyh35+UP5elcbvyiXz8MP5ZjcXmoxL7kYlmpXL7lJbKDwxR+PzjCdDGn0MdLX",
				"sZTV/nX7fZ25GStWkgbSLts76N//9/////19vr9fr+/mBr8vbniOKKiUcEzkZAABgJwBaTAeQsDUmCagFphEwEULFFxtHBIUei+A5GK/A1hguQVsYBmQGiEL7MADAuAIAjgUAkLAASoorOpNLmPyAGCrNANgpGAE",
				"Ocii5EiUDJHgqMkUUl6XOWbNV81nzdR11v1svt9vnX4yMbh67blEHvSJPuV919k//f/7J7f///X636/QxORARn+SFWtYPQ+5xpZcxUxBTUUzLjEwMFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",
				"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",
				"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",
				"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",
				"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVX/+9JkAAzz+XpEU/05",
				"wAAADSAAAAEO+dsQb/TnAAAANIAAAAQAAMFHACADAPgFEwD0BuMBGAqTAawRgwMgInMHrGTjLEvhA1mkgWNnnPMySCOfNTM31HM7RKMUAXMHQADANTOeRfDSYax7fb2VaK9P32rxMchinJ////dPNvxWzcdFx9JR",
				"xn3FXuZ+////////6f//t7fZeVCy9iZXzhCHdULUOSAAACAArMAcAYjAVQK0wJ4EmMEjCOTCeBkIzJPvqNk0IOj0O3zcV0Tqr6jO9VDNsRzEYEAEF4QBCG6ghdxU8Yz7fP9kZK3SdZL59W0ZWYz////ZPS/NfxQ7",
				"0o5D3EX7+yf///////0///+3r8wCpnmK/UTh2QrSmIKaimZcYmBgqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqTEFNRTMuMTAwqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqv/70mQACPSfecNT+1LgAAAN",
				"IAAAAQ755xNP9OcAAAA0gAAABAAASMaIAAMBXALAECGhAMeAgmgwiMAOMTYBCzaeRu09FAEqMVrCBzBewrswGYfyMBrC8DJL0wVICg6QhCHNWxnD3RmmsZ65T1b9ivlhvuGFLbqY50l22edJ0Y9Jiu3Nd5q/36X+",
				"3z/qj8XI+glM3Q4h9xW2sb72+3T6/////9un/5/2XqXO6ARnNuP0foI4c6IT1iw7OOIgIGAXgHRgFQCyYBmBFGAnAdZgSoOgYLYKvmPl5opqSg1uaisUZVCqcI3gZCHgZgBqYegUCgpCAWTNb9n7hSn9n9zU7HLz",
				"EX1+lsqzujbffp//T6fPZ+5Zvcl8a/T6//v/9v///1///+33XqJl8xH6icO+X0JiCmopmXGJgYVVVVVVVVVVVVVVVVVMQU1FMy4xMDBVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",
				"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",
				"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",
				"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",
				"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV//vSZAAJ85B6Q7P9OcAAAA0gAAAB",
				"EB3zBg5+osAAADSAAAAEAIRAAEIBMYBGAvmAuAUxgVIJCYJoEUGFTjBpnG3gia1GQdnplwG4zsHU/UmmC5maglGIYJgILAgC0NFN13v5T8/7/b6//T1T///9/r8/4678TtruWbWNvr/9f//////6+b9f39Po3mAG",
				"t5VPYTgz1L0qM2D81OHAN+SONGFZAEZi9oM4b4kNDH8+gYJjUwSwYPMGtGBBk1JgpgcqBj92AYMMYBIuAoFQiAg5MUuMQkm7fV9/dX1f/S77ev12+y/V9r8jE/Iabn91pF/rjm+6Hzn7+p+v+//2+v6/t9d/S9Tq",
				"6zV+ZCTpeWDjdIlRVdR1VdU+mIKaimZcYmBgqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqkxBTUUzLjEwMKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqr/+9JkAAvzXHnDK/05wAAADSAAAAEN9ecL",
				"D/TnAAAANIAAAAQAgAGAcAJZgGoDUYB4BSmAsgiRgVAQ6YM+MeGRHdXxsdI9kbAOKZjjgcxcaY9oqZyiAYmAmAg2DgNUk8kARGm52/////9P/////7p7m+OF/Vx7rG33/////////p///9/V15URPjtupUGeaWGA",
				"gAJzAIgFwwFsCjMCoBGDBMwhswqYXeM6J7QjUsCBo87tM29c86a2w1FXQzREsxABIBBeBgYBwBoOKANfjHf/////9P///9PdPX47biC1Kxb1YSfY32X///////+nv//+6e6dADV8eVuhUGdZaNQmIKaimZcYmBhV",
				"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVTEFNRTMuMTAwVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",
				"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",
				"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",
				"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",
				"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVf/70mQAD/PzecCDn6iwAAANIAAAAQ1N2wYP9ObA",
				"AAA0gAAABDM4+NNB83aBjugFMKJATDFlAgU3VUO7PrIA2DGQQi8wcUMnMB2JFjBrQ14DITfAwaWgCBWBUIBEAh+gyA3yWP63//9v//rbt/31av/ZXpK8mHbk0VEdR1RP+xBvY5/7K9f//+v/6v2/6vqW3uvqUn0h",
				"U0+5dO+ZlkYnRMjWsuYB2AnGAZAOJgHIFUYCkCPmBNhGRgvg0CY5326m2pD65r26xmkM5zj6BhkgBnYIJieCQCDkOA5M15wuKhr//////1////t9/qnnM3Hyz9ZT2En5/0////////r//6fV/t5URE85fYqDKiOl",
				"MQU1FMy4xMDBVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVMQU1FMy4xMDBVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",
				"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",
				"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",
				"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",
				"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV//vSZAAP84F5wIP9OcAAAA0gAAABEM3y+A5+osAAADSA",
				"AAAEGACQwC8BhMBsAqjAxQScwWQIyMMXGDTRrv7E0ssivPiMKN4H+Oy9dNom7M2hYMRwZMGACBwFoKKDtbhyn52+///1+nr//b7ff7fT4n+FVOrViLdhK92/b1+n/////9f/X6fX6mp0AJTyN+5UGehe9BnormsS",
				"EcEIJ5czGFgAg5jCYiQcAMJIH+5gJZjWwREYOQGvGAUk6phlwdeBoF6AYeM4GBRgAsFQagIOjFjFRJI9Upu9X1/X//6n77/9f9SvTX6avNDZ+alc9vQJfqRHb1zb6P1/V9bfb7/b7fS+j9f1K9bK6z6+ZCZJtyso",
				"+rROio9crV1TVMQU1FMy4xMDBVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVUxBTUUzLjEwMFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",
				"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",
				"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",
				"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",
				"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVX/+9JkAA/zY3a+g5+osAAADSAAAAERuebuD+zrAAAANIAAAAQx",
				"kTzEJ8MJMMwfRDAIAn8wF0d4MQt8EDiWSCIwOwIpHgicwpoR1MD6AWQODiYDKwJAOIQFgiGlClB0EaZf/////9X/////9vmSn5YNkfRQ6pW9kfqf//7f////q//9X7fS86RRHzyn6ljzk7kmAZgBJgOQCgYGKBDm",
				"C8AnRhOoV+YcYA2nM6+SxqeYuIY7GJYmEShp5hVQJkYd+GfHg1ZpCMYiImGAxgoOl4oI1+bi9ykllivLLGNcm5hhiGGMp6oYe8xp73PWjJ99v9Pbf9Pf46Y/EY56UYa9DxJ9kf3f////9f//p7//27MnRvNABR9C",
				"Q95UTgV8qWuLJiCmopmXGJgYKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqTEFNRTMuMTAwqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqownsLuME8BFzDrwoIxcYYtMWTESjZ0NlU/niLNOE34PDn/yG4w",
				"LM8pMiONwjQWRxAw5wLhMGZBpjA3AVk6g49n0QYDuUzXKwhgZ9Ua9QBlwUHmaNmUDsDMENMgLFgJfYw4gDCmdggKAQCfSqpZVBV/EExeJvmBISk6obUxSJdV0lAmIxhhyxoGdFYVlsoayxGBYkBIRl4gg1PiqDUR",
				"XByBsWi6JROfJIkqUwlE6hKEpUyST2h0YqWiUJS8kk11kQRFLxOPnqyVidCYu2aEJU0ZPMrXcaOncXLvZW80tW80ue1at9l2uLl3srntZd61rZa31W1lqvWXW1a71WVvWt9a21mvZa02+ta1mx07azyU4AkgwO1a",
				"hiXWZPUMAUsFr7eyYlEoLCVgVWAM1k8gyzEITInRcMV5IEwWUiDDrRxMhpAQzqSmTVYAdNhRJ81SWWjPQcJMwOXowxpiTIGlYNAGM817nf/70mSyCPksebOD+mNyAAANIAAAASvY9isvd3MAAAA0gAAABIjd7U7N",
				"w0So10EWzOZVeMeJaMwk3YjGHdBMuJvYz0WbzmDTjYKQjQVhzAxQDC5OQanBhul5kIiBnSXJqgDxrofZtK8xpJEZlLGxgtHJjNFxmfDZoU/RoO55jetphYkxhQh5hWhg4hZhggBjadJloVRnyJJoKQxm0cpkehBi",
				"MioFRQwnRExUQgxjQcxAQYwlP4w0PMxFPAwoPEl7jK+U1zSOPqTumo7AdOPcDUo8yGWC0yYRKGPypilEYBamuaprO8adymU8xU5TKNo1nJOIoDsWU6kYOGaTT4QyCPBsgYLHmQRhk8aY5hGR4RlF6ZfeGKXYgtjI",
				"600acNpfThFADepsaAZssmLsAIZxAzGFtJhDcMPJl0WZbIGFJYNShlHKwKpMQU1FMy4xMDCqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq//vSZAAP8AAAaQAAAAgAAA0gAAABAAABpAAAACAAADSAAAAETEFNRTMuMTAw",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqkxBTUUzLjEwMKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqr/+9JkAA/wAABpAAAACAAADSAAAAEAAAGkAAAAIAAANIAAAARMQU1FMy4xMDCqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqTEFNRTMuMTAwqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqv/70GQAD/AAAGkAAAAIAAANIAAAAQAAAaQAAAAgAAA0gAAABExBTUUzLjEwMKqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqkxBTUUzLjEwMKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqr/+9JkAA/wAABpAAAACAAADSAAAAEAAAGkAAAAIAAANIAAAARMQU1FMy4xMDCqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqTEFNRTMuMTAwqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqv/70mQAD/AAAGkAAAAIAAANIAAAAQAAAaQAAAAgAAA0gAAABExBTUUzLjEwMKqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqpMQU1FMy4xMDCqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq//vSZAAP8AAAaQAAAAgAAA0gAAABAAABpAAAACAAADSAAAAETEFNRTMuMTAwqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqkxBTUUzLjEwMKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqr/+9JkAA/wAABpAAAACAAADSAAAAEAAAGkAAAAIAAANIAAAARMQU1FMy4xMDCqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqTEFNRTMuMTAwqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqv/70mQAD/AAAGkAAAAIAAANIAAAAQAAAaQAAAAgAAA0gAAABExBTUUzLjEwMKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqpMQU1FMy4xMDCqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq//vSZAAP8AAAaQAAAAgAAA0gAAABAAABpAAAACAAADSAAAAETEFNRTMuMTAwqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqkxBTUUzLjEwMKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqr/+9JkAA/wAABpAAAACAAADSAAAAEAAAGkAAAAIAAANIAAAARMQU1FMy4xMDCqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqTEFNRTMuMTAwqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqv/70mQAD/AAAGkAAAAIAAANIAAAAQAAAaQAAAAgAAA0gAAABExBTUUzLjEwMKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqpM",
				"QU1FMy4xMDCqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq//vSZAAP8AAAaQAAAAgAAA0gAAABAAABpAAAACAAADSAAAAETEFNRTMuMTAwqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqkxBTUUz",
				"LjEwMKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqr/+9JkAA/wAABpAAAACAAADSAAAAEAAAGkAAAAIAAANIAAAARMQU1FMy4xMDCqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqTEFNRTMuMTAw",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqv/70mQAD/AAAGkAAAAIAAANIAAAAQAAAaQAAAAgAAA0gAAABExBTUUzLjEwMKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqpMQU1FMy4xMDCqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqq//vQZAAP8AAAaQAAAAgAAA0gAAABAAABpAAAACAAADSAAAAETEFNRTMuMTAwqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqTEFNRTMuMTAwqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqv/70mQAD/AAAGkAAAAIAAANIAAAAQAAAaQAAAAgAAA0gAAABExBTUUzLjEwMKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqpMQU1FMy4xMDCqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqq//vSZAAP8AAAaQAAAAgAAA0gAAABAAABpAAAACAAADSAAAAETEFNRTMuMTAwqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqkxBTUUzLjEwMKqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqr/+9JkAA/wAABpAAAACAAADSAAAAEAAAGkAAAAIAAANIAAAARMQU1FMy4xMDCqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqTEFNRTMuMTAwqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qv/70mQAD/AAAGkAAAAIAAANIAAAAQAAAaQAAAAgAAA0gAAABExBTUUzLjEwMKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqpMQU1FMy4xMDCqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq//vS",
				"ZAAP8AAAaQAAAAgAAA0gAAABAAABpAAAACAAADSAAAAETEFNRTMuMTAwqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqkxBTUUzLjEwMKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqr/+9JkAA/w",
				"AABpAAAACAAADSAAAAEAAAGkAAAAIAAANIAAAARMQU1FMy4xMDCqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqTEFNRTMuMTAwqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqv/70mQAD/AAAGkA",
				"AAAIAAANIAAAAQAAAaQAAAAgAAA0gAAABExBTUUzLjEwMKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqpMQU1FMy4xMDCqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq//vSZAAP8AAAaQAAAAgA",
				"AA0gAAABAAABpAAAACAAADSAAAAETEFNRTMuMTAwqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqkxBTUUzLjEwMKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqr/+9JkAA/wAABpAAAACAAADSAA",
				"AAEAAAGkAAAAIAAANIAAAARMQU1FMy4xMDCqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqTEFNRTMuMTAwqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqv/70mQAD/AAAGkAAAAIAAANIAAAAQAA",
				"AaQAAAAgAAA0gAAABExBTUUzLjEwMKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqpMQU1FMy4xMDCqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq//vSZAAP8AAAaQAAAAgAAA0gAAABAAABpAAA",
				"ACAAADSAAAAETEFNRTMuMTAwqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqkxBTUUzLjEwMKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqr/+9BkAA/wAABpAAAACAAADSAAAAEAAAGkAAAAIAAA",
				"NIAAAARMQU1FMy4xMDCqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqpMQU1FMy4xMDCqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq//vSZAAP8AAAaQAAAAgAAA0gAAABAAABpAAAACAAADSAAAAE",
				"TEFNRTMuMTAwqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqkxBTUUzLjEwMKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqr/+9JkAA/wAABpAAAACAAADSAAAAEAAAGkAAAAIAAANIAAAARMQU1F",
				"My4xMDCqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqTEFNRTMuMTAwqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqv/70mQAD/AAAGkAAAAIAAANIAAAAQAAAaQAAAAgAAA0gAAABExBTUUzLjEw",
				"MKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqpMQU1FMy4xMDCqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq//vSZAAP8AAAaQAAAAgAAA0gAAABAAABpAAAACAAADSAAAAETEFNRTMuMTAwqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqkxBTUUzLjEwMKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqr/+9JkAA/wAABpAAAACAAADSAAAAEAAAGkAAAAIAAANIAAAARMQU1FMy4xMDCqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqTEFNRTMuMTAwqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqv/70mQAD/AAAGkAAAAIAAANIAAAAQAAAaQAAAAgAAA0gAAABExBTUUzLjEwMKqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqpMQU1FMy4xMDCqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq//vSZAAP8AAAaQAAAAgAAA0gAAABAAABpAAAACAAADSAAAAETEFNRTMuMTAwqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqkxBTUUzLjEwMKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqr/+9JkAA/wAABpAAAACAAADSAAAAEAAAGkAAAAIAAANIAAAARMQU1FMy4xMDCqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqTEFNRTMuMTAwqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqv/70mQAD/AAAGkAAAAIAAANIAAAAQAAAaQAAAAgAAA0gAAABExBTUUzLjEwMKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqpMQU1FMy4xMDCqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq//vSZAAP8AAAaQAAAAgAAA0gAAABAAABpAAAACAAADSAAAAETEFNRTMuMTAwqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqkxBTUUzLjEwMKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqr/+9JkAA/wAABpAAAACAAADSAAAAEAAAGkAAAAIAAANIAAAARMQU1FMy4xMDCqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqTEFNRTMuMTAwqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqv/70GQAD/AAAGkAAAAIAAANIAAAAQAAAaQAAAAgAAA0gAAABExBTUUzLjEwMKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqkxBTUUzLjEwMKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqr/+9JkAA/wAABpAAAACAAADSAAAAEAAAGkAAAAIAAANIAAAARMQU1FMy4xMDCqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"TEFNRTMuMTAwqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqv/70mQAD/AAAGkAAAAIAAANIAAAAQAAAaQAAAAgAAA0gAAABExBTUUzLjEwMKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqpMQU1F",
				"My4xMDCqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq//vSZAAP8AAAaQAAAAgAAA0gAAABAAABpAAAACAAADSAAAAETEFNRTMuMTAwqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqkxBTUUzLjEw",
				"MKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqr/+9JkAA/wAABpAAAACAAADSAAAAEAAAGkAAAAIAAANIAAAARMQU1FMy4xMDCqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqTEFNRTMuMTAwqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqv/70mQAD/AAAGkAAAAIAAANIAAAAQAAAaQAAAAgAAA0gAAABExBTUUzLjEwMKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqpMQU1FMy4xMDCqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqq//vSZAAP8AAAaQAAAAgAAA0gAAABAAABpAAAACAAADSAAAAETEFNRTMuMTAwqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqkxBTUUzLjEwMKqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqr/+9JkAA/wAABpAAAACAAADSAAAAEAAAGkAAAAIAAANIAAAARMQU1FMy4xMDCqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqTEFNRTMuMTAwqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqv/70mQAD/AAAGkAAAAIAAANIAAAAQAAAaQAAAAgAAA0gAAABExBTUUzLjEwMKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqpMQU1FMy4xMDCqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqq//vSZAAP8AAAaQAAAAgAAA0gAAABAAABpAAAACAAADSAAAAETEFNRTMuMTAwqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqkxBTUUzLjEwMKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqo=",
			}),
		},
		["debug-sound.mp3"] = {
			bytes = 7680,
			data = table.concat({
				"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",
				"IEBIAAAIa0YIJtsOEGpNziaMgY5h6BmGR+CGaF6FZihkIGH6IgYBgGZhKAfBwARi9h+GGmGgLAUMXhuTAZp+BriJcTIqeGCBAOBlDK01F5RsBmkIXyEbNY6ksRyGQgbBwNrF37IsqOUGXhjRZJFSj/+MqK1MkyZM",
				"ie//y8ovF5oV/wVKnSv/4NWKAAAAQggAAObmI5ogzCw1MGAL/CHOYVAoJA6qv+FwwHBxNVEL/AOwBhSJuGFh0QFxADUEBRyS//vUZBsABuxzwcZyYAJoRScgz6wAAAABpBwAACAAADSDgAAEKcDGsDQcHSIkZEzw",
				"BiBowY1Cx8MTkYZE8OkmfiEA7RFg+cWYI+KpAiaNy6Y/iiCCYxozQjwZQa5wzWXSkZG38exbxWhHjIjJi5BliZMTQvGS2/47RcY6x9DsHAMuUh3DgSMTE1KRkfLpih/4545pJDMEoQ0d5Bx0GpCEHIo9E4o2MTFj",
				"JJNH/+QYlhzyNJoghFCPLZJjmFMgpJjmf//rUtaJkk5iKCqjOr1aAzj0OaMCqBKzAsgCL/MN2CrxQACMBDAHYC/yyI8ABNegv/C4ZInfIUfA9lSV/rGZCNmPy9p4sQ/iP/VefNLWuZ4//z7HUfVj+YCwMA6z+BBU",
				"DnAH/4JAMWADQI3/8qBEDyADSA5MQU1FMy4xMDCqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
			}),
		},
		["error.mp3"] = {
			bytes = 13056,
			data = table.concat({
				"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",
				"xwVIiRyuxxJgEkaAVAyT1/6fK3tUztZt1eOj5k9ou5r6rXWjJsyjrLMTX1hWsGS89TNmLZJRW0rDsPIHWz1kxdYAUURBXEorgAlAQhGfJJ8iTEFNRTMuMTAwqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
			}),
		},
		["loading-end-fail8.mp3"] = {
			bytes = 39288,
			data = table.concat({
				"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",
				"KbydpCYixIQ0tQNY72OGoGseFuAsIsSBIAWEWJAj7rDrHgeGF3sTgeAFhF2QI+6710QJAf/70mT4jMf5aTkbmmJzdE+24Xd4OFC5IOxsvMcLHrzdxZYaKbD13wPADDGIOvEGGMQfiPsPXe/clYexN+44wxiD8ULW",
				"GIPxQtbYm/ckawxN+6BrDEH4oWtsTdSZa2zt35prDOHcpnAZw7lVw2du/adtnbv0zsM4dyldtnDuUrts7d+mdhnDj2nYZw7ll92duPOvuzt37T6M4dychhrDuUT7s7cuXvHgAluJwCXVAAJlImEAdNhkhmoObS4H",
				"8PklpBUYTouSikTyuZrAIBIsRIkWBkv3qteZxjpxqrXNnXIo5VVTVWvM40znqteSVOaRljiUtRKnNIz5Iz6JVtVXmZ9TOHEktNI1skUcokSyiSWyajmJsI6MdFNhG5DcRcUVCCshuIrEVkNxG4ishgAvCkKmKsIa",
				"swRedGI1IY4ymrAUrUQi0Sm0NpeoquNHWGrtHVCBICQjMCEDYtQkkSSbEVQak1glCUfQkkyPrnIkntDISj3DoyPrnJie+cmJ7BIBEtOARKyIBIwSIkcOJEtNBSWmkSOHEiWHEiWmkSOSRI5RJLZOS2SJHKJI5RIl",
				"skSOyRI4xxKmOS1zUcaZljktc2tc1GWOJSxIkk5Eii5pFFjiVOcSpzSMscRljiSTmkaeZn1VeqrzM5Mz6qvNV5mfRxoUNBQZTEFNRTMuMTAwVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",
				"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",
				"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",
				"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",
			}),
		},
		["toggle.mp3"] = {
			bytes = 28416,
			data = table.concat({
				"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",
				"mHn8iEakr/wqlo5XWpauctMQ09lTJ7RWNPvD978X9lkol+GeEq1qyx+6/brtAnr+6kSx7vfN81jruu52KtleDdVMQU1FMy4xMDBVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",
				"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVWAMBvAsjABgUkwEURwNYvzpDC4k",
				"q43Tht/MQIDxDBTQZc97+OekDoVU5JGPhDjMwYGEZh+klmVQDmYIYAhgUgQGCcAyYuK2ByOhbmISBsHAwmAmAMqxY8gUWgZ85fLZZH67/yiBZm5R0sPP7Bd23Uh2T2YYnJfe+Aodkid0VVzO37rjS71+OUjnGIbp",
				"KSpFqO5Uu/Dkpv2LE32gxjljeEPTD+wHQTEkh+xC3MfuHW8ocseZ6gaIMChb7T8ucichpL5M8dABguMtwm5Y7BKAKq0udA0MXJiklTX6Oo+zqTXLNBRz+UxllWxwv550z7Y4/l8aqRx0GSUcniGcQgSJtXhmnhdH",
				"OXZVZqf24wqD983T28pqe91VB3lm2JVML11plDt5yTOh0dJgLcwIACMMCnDfTPJuY0xX0iSPmjFuTdjB8GlKDEnCVMEcJEGhOGAwESYB4G5IBIDAVTA0QPMMQFswCAFm//vUxLIDZNGxDC/vxoyjNiFB/2CxbmBg",
				"BYYq4n5zpjnGJCAaYGACBgOgCosIXRFXrxX7DZJ2e05FIzmB6OgtxS9FoXepa2VmkjURq22uV4U1JVojBhlK6S94XBJkhINpHRkU1zlFIrsA14Zl0F0DqV4x2gkH5S6chTGWlSigomGp6uzZfV7flM7Xnp/strQq",
				"n5VUyQNaqvBvy8qQVRmaElH3MKJSiWW0uOF+Wb0Mw1iepWxTj/4ajNep2/OYfj3LC7Sa723hqC5NxRpjzgT1BQJKItURflfQRDGQQAgOjlnuFSkV7Lsvrvw59nWHHaicUmWc1V9RTOaworOVdHsxpZVMQU1FMy4x",
				"MDBVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVMAMAOzAS",
				"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",
				"//vUxOuCbjnq+Mj7IEX/vN7B7WSRr3TkT8VtYuX8EglYkeAKGNGl4kDUKxoBqTfg4FeSr2PkoCscFq4HQ1LHkFji9XpEuM6CbsCtATWWi3KOFwgcMo8ClmstdjCuqZlLgyxiK/lcKkZ3DYkCw9erkJXlwEfGnytF",
				"5Z6PxnGuuBhAiEqDjSgsUj66TLgoGgqDSg48BMl5U5BEaiwsoeCWMoMypKdOB14EQeYizRV65E7V5PapKKPyzQICC4SQ6mpcV0VqqVPY6aloVEAyQiLGjWMA5c6UDapMgkoUCBhAOkyYS5fQEpI9pvCJs6pTktOQ",
				"l1QYKzZeymgYGBoYyp2FAAxMMCRGMwlBNi8NBBDj34fWq3FrrBXheBylkDpJMi/9NB0BxyWyaPwZM3aSU016DUxBTUUzLjEwMFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",
				"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",
				"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",
				"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVKQADhG9NjRIJTZyJSmxXcYyd5l5TGoxCaCFJiYZmogGrnoecOA7SAwDxWNjkZpDTDhKMVwooi+AsgVBVWXbA2QK4KlK1GkAW",
				"Kl4oiBjCA4WIUWNRRCws2BwmmxLAMuDsgUg6MaAGGBAUnliF0gsFDAoEBgoIljqh//vUxDwD7HHq4E5nCMAAADSAAAAETFVWW2tRPpTFnjFlAWEsEViUBUeWOnCXiEQ0304ErlouA1JdLSmjv+2rpQ+6rWnrhDvR",
				"KXxV2oLfhmygKWyyFvpgryZWx1TZTFVJlCvlMV8L3S5QDBYI6RDooOxSD5yfsZ5RpwW7NzaYzZiLAmqu23rlR+Qw1G2WqZKHLzXQt5TVeTW1+qmXk0txHOa6+0fnJ7LLtWSP+zVFYvKhxT0VOsxXy7YMhT+x2UT8",
				"tlVexPTM+11gTP2WLeU1UyUVZGuFQZfLkOc4sSlc8/skkbuwFD7LVMl9NbbxpzWXwft1WtQZA8Cw1QzkulNBeyVMQU1FMy4xMDBVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",
				"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",
				"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",
				"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",
				"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",
			}),
		},
	},
}
end

do
local env = S.env
local util = S.util

local sounds = {}
local DATA = S.sounddata and S.sounddata.files or {}

local ROOT = "Spectrum/sounds/v1"
local ASSETS = {
	click = { file = "click-soft.mp3", fallback = "rbxasset://sounds/button.mp3" },
	toggle = { file = "toggle.mp3", fallback = "rbxasset://sounds/switch.mp3" },
	success = { file = "bubble_pop.mp3", fallback = "rbxasset://sounds/electronicpingshort.mp3" },
	info = { file = "debug-sound.mp3", fallback = "rbxasset://sounds/electronicpingshort.mp3" },
	warning = { file = "loading-end-fail8.mp3", fallback = "rbxasset://sounds/clickfast.mp3" },
	error = { file = "error.mp3", fallback = "rbxasset://sounds/hit.mp3" },
}

local CUES = {
	click = { asset = "click", volume = 0.42, pitch = 1 },
	toggle_on = { asset = "toggle", volume = 0.55, pitch = 1.04 },
	toggle_off = { asset = "toggle", volume = 0.5, pitch = 0.92 },
	open = { asset = "success", volume = 0.32, pitch = 0.96 },
	close = { asset = "success", volume = 0.27, pitch = 0.84 },
	select = { asset = "click", volume = 0.36, pitch = 1.08 },
	tab = { asset = "click", volume = 0.32, pitch = 1.04 },
	slider = { asset = "click", volume = 0.2, pitch = 0.82 },
	info = { asset = "info", volume = 0.55, pitch = 1 },
	success = { asset = "success", volume = 0.6, pitch = 1.06 },
	warning = { asset = "warning", volume = 0.48, pitch = 1.08 },
	error = { asset = "error", volume = 0.56, pitch = 1 },
}

local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local alphabet_values = {}
for index = 1, #alphabet do
	alphabet_values[string.sub(alphabet, index, index)] = index - 1
end

local function decode(input)
	local output = {}
	for index = 1, #input, 4 do
		local a = alphabet_values[string.sub(input, index, index)] or 0
		local b = alphabet_values[string.sub(input, index + 1, index + 1)] or 0
		local trit = string.sub(input, index + 2, index + 2)
		local quad = string.sub(input, index + 3, index + 3)
		local c = trit ~= "=" and alphabet_values[trit] or nil
		local d = quad ~= "=" and alphabet_values[quad] or nil
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

local custom_supported
local asset_cache = {}
local voices = {}
local voice_sources = {}
local watchers = {}
local enabled = true
local master = 0.4

local folder = util.new("Folder", {
	Name = "sounds",
	Parent = env.notes,
})

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

local function ensure_folders()
	for _, name in ipairs({ "Spectrum", "Spectrum/sounds", ROOT }) do
		if type(isfolder) ~= "function" or not isfolder(name) then
			pcall(makefolder, name)
		end
	end
end

local function custom_asset(meta)
	local key = meta.file
	local cached = asset_cache[key]
	if cached ~= nil then
		return cached or nil
	end
	local source = DATA[key]
	if not custom_available() or type(source) ~= "table" or type(source.data) ~= "string" then
		asset_cache[key] = false
		return nil
	end
	if not pcall(ensure_folders) then
		asset_cache[key] = false
		return nil
	end

	local path = ROOT .. "/" .. key
	local reusable = false
	local checked, present = pcall(isfile, path)
	if checked and present then
		if type(readfile) == "function" then
			local read_ok, body = pcall(readfile, path)
			reusable = read_ok and type(body) == "string" and #body == source.bytes
		else
			reusable = true
		end
	end
	if not reusable then
		local body = decode(source.data)
		if #body ~= source.bytes or not pcall(writefile, path, body) then
			asset_cache[key] = false
			return nil
		end
	end

	local getter = getcustomasset or getsynasset
	local read_ok, asset = pcall(getter, path)
	if read_ok and type(asset) == "string" and asset ~= "" then
		asset_cache[key] = asset
		return asset
	end
	asset_cache[key] = false
	return nil
end

local function voice_for(name, meta)
	local source = custom_asset(meta) or meta.fallback
	if not source then
		return nil
	end
	local sound = voices[name]
	if not sound or not sound.Parent then
		local created, object = pcall(util.new, "Sound", {
			Name = name,
			SoundId = source,
			Volume = 0,
			Parent = folder,
		})
		if not created then
			return nil
		end
		sound = object
		voices[name] = sound
		voice_sources[name] = source
	elseif voice_sources[name] ~= source then
		sound.SoundId = source
		voice_sources[name] = source
	end
	return sound
end

local function persist()
	if S.config and S.config.place_sounds then
		S.config.place_sounds({ enabled = enabled, volume = master })
	end
end

local function announce()
	for index = #watchers, 1, -1 do
		local watcher = watchers[index]
		local ok = pcall(watcher, enabled, master)
		if not ok then
			table.remove(watchers, index)
		end
	end
end

function sounds.watch(fn)
	if type(fn) ~= "function" then
		return function() end
	end
	watchers[#watchers + 1] = fn
	pcall(fn, enabled, master)
	return function()
		for index, watcher in ipairs(watchers) do
			if watcher == fn then
				table.remove(watchers, index)
				break
			end
		end
	end
end

function sounds.play(name, opts)
	opts = type(opts) == "table" and opts or {}
	if master <= 0 or type(name) ~= "string" or (not enabled and opts.force ~= true) then
		return false
	end
	local cue = CUES[name]
	local meta = cue and ASSETS[cue.asset]
	if not cue or not meta then
		return false
	end
	local sound = voice_for(name, meta)
	if not sound then
		return false
	end
	local level = tonumber(opts.volume) or cue.volume or 0.5
	local volume = math.clamp(level * master, 0, 1)
	if volume <= 0 then
		return false
	end
	sound.Volume = volume
	sound.PlaybackSpeed = math.clamp(tonumber(opts.pitch) or cue.pitch or 1, 0.5, 2)
	pcall(function()
		sound.TimePosition = 0
	end)
	local ok = pcall(function()
		sound:Play()
	end)
	return ok
end

function sounds.notify(kind)
	local cue = kind == "good" and "success"
		or kind == "warn" and "warning"
		or kind == "bad" and "error"
		or "info"
	return sounds.play(cue)
end

function sounds.set_enabled(state, save)
	enabled = state ~= false
	if not enabled then
		for _, sound in pairs(voices) do
			pcall(function()
				sound:Stop()
			end)
		end
	end
	if save ~= false then
		persist()
	end
	announce()
	return enabled
end

function sounds.get_enabled()
	return enabled
end

function sounds.set_volume(value, save)
	master = math.clamp(tonumber(value) or master, 0, 1)
	if save ~= false then
		persist()
	end
	announce()
	return master
end

function sounds.get_volume()
	return master
end

function sounds.restore()
	local state = S.config and S.config.sound_state()
	if state then
		enabled = state.enabled
		master = state.volume
	end
	announce()
	return enabled, master
end

function sounds.destroy()
	enabled = false
	for _, sound in pairs(voices) do
		pcall(function()
			sound:Stop()
			sound:Destroy()
		end)
	end
	table.clear(voices)
	table.clear(voice_sources)
	table.clear(watchers)
	if folder and folder.Parent then
		folder:Destroy()
	end
end

task.spawn(function()
	task.wait(0.4)
	if not enabled then
		return
	end
	for _, meta in pairs(ASSETS) do
		pcall(custom_asset, meta)
	end
end)

S.sounds = sounds
end

do
local env = S.env
local util = S.util
local style = S.style
local icons = S.icons
local sounds = S.sounds
local function bold()
	return style.values.font_bold
end
local function font()
	return style.values.font
end
local TextService = game:GetService("TextService")

local right_bleed = 8
local bottom_gap = 24

local holder = util.new("Frame", {
	Name = "notifications",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, right_bleed, 1, -bottom_gap),
	Size = UDim2.fromOffset(env.mobile and 316 or 340, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Parent = env.notes,
})

util.new("UIListLayout", {
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	VerticalAlignment = Enum.VerticalAlignment.Bottom,
	Parent = holder,
})

local noted = 0
local kind_labels = {
	info = "INFO",
	good = "SUCCESS",
	warn = "WARNING",
	bad = "ERROR",
}
local kind_icons = {
	info = "info",
	good = "check",
	warn = "alert",
	bad = "cross",
}

local function wrapped_height(text, width, size)
	local ok, box = pcall(function()
		return TextService:GetTextSize(text, size or 10, font(), Vector2.new(width, 4096))
	end)
	if ok and typeof(box) == "Vector2" then
		return math.ceil(box.Y)
	end
	return (size or 10) + 2
end

local function fade_icon(object, alpha, time)
	if not object or not object.Parent then
		return
	end
	local items = { object }
	for _, child in ipairs(object:GetDescendants()) do
		items[#items + 1] = child
	end
	for _, child in ipairs(items) do
		local base = child:GetAttribute("SpectrumIconAlpha")
		if base == nil then
			if child:IsA("Frame") then
				base = child.BackgroundTransparency
			elseif child:IsA("ImageLabel") then
				base = child.ImageTransparency
			elseif child:IsA("TextLabel") then
				base = child.TextTransparency
			elseif child:IsA("UIStroke") then
				base = child.Transparency
			end
			if base ~= nil then
				child:SetAttribute("SpectrumIconAlpha", base)
			end
		end
		if base ~= nil then
			local target = base + (1 - base) * alpha
			local delay = math.max(0.01, time or 0.12)
			if child:IsA("Frame") then
				util.tween(child, delay, { BackgroundTransparency = target })
			elseif child:IsA("ImageLabel") then
				util.tween(child, delay, { ImageTransparency = target })
			elseif child:IsA("TextLabel") then
				util.tween(child, delay, { TextTransparency = target })
			elseif child:IsA("UIStroke") then
				util.tween(child, delay, { Transparency = target })
			end
		end
	end
end

local function notify(title, body, duration, kind)
	noted = noted + 1
	duration = duration or 3
	if sounds then
		sounds.notify(kind)
	end
	local tint = style.values.accent
	if kind == "good" then
		tint = style.values.good
	elseif kind == "warn" then
		tint = style.values.warn
	elseif kind == "bad" then
		tint = style.values.bad
	end

	local width = env.mobile and 316 or 340
	local pad = 20
	local chip_size = 28
	local chip_x = pad - 4
	local icon_size = 15
	local text_left = pad + chip_size + 8
	local title_size = util.size(12)
	local body_size = util.size(10)
	local caption_y = env.mobile and 29 or 28
	local caption_height = math.max(env.mobile and 15 or 14, wrapped_height(body or "", width - text_left - 20, body_size) + 2)
	local height = math.max(env.mobile and 64 or 60, caption_y + caption_height + 16)

	local face = util.new("Frame", {
		Name = "note",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		LayoutOrder = noted,
		Size = UDim2.new(1, 0, 0, 0),
		Parent = holder,
	})
	util.corner(face, 6)
	util.stroke(face, style.values.line, 0.55)
	util.depth(face, 0.8)
	util.shadow(face, 22, 0.32)

	local scrim = util.new("Frame", {
		Name = "scrim",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Parent = face,
	})
	util.corner(scrim, 6)

	local content = util.new("Frame", {
		Name = "content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(6, 0),
		Size = UDim2.new(1, 0, 0, height),
		ZIndex = 3,
		Parent = face,
	})
	local scale = util.new("UIScale", { Scale = 0.98, Parent = content })

	local chip = util.new("Frame", {
		Name = "chip",
		BackgroundColor3 = tint,
		BackgroundTransparency = 0.82,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(chip_x, env.mobile and 11 or 10),
		Size = UDim2.fromOffset(chip_size, chip_size),
		ZIndex = 4,
		Parent = content,
	})
	util.corner(chip, chip_size / 2)
	util.stroke(chip, tint, 0.4)
	local chip_scale = util.new("UIScale", { Scale = 0.7, Parent = chip })

	local badge = icons.image(chip, kind_icons[kind] or "info", icon_size, tint) or icons.kind(kind, chip, icon_size, tint)
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.fromScale(0.5, 0.5)
	icons.layer(badge, 5)
	fade_icon(chip, 1, 0.01)

	local heading = util.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(text_left, env.mobile and 10 or 9),
		Size = UDim2.new(1, -(text_left + 110), 0, 18),
		Font = bold(),
		Text = tostring(title or "Spectrum"),
		TextColor3 = style.values.text,
		TextSize = title_size,
		TextTransparency = 1,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 5,
		Parent = content,
	})

	local kind_label = util.new("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -34, 0, env.mobile and 12 or 11),
		Size = UDim2.fromOffset(64, 12),
		Font = bold(),
		Text = kind_labels[kind] or "INFO",
		TextColor3 = tint,
		TextSize = util.size(8),
		TextTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 6,
		Parent = content,
	})

	local caption = util.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(text_left, caption_y),
		Size = UDim2.new(1, -(text_left + 20), 0, caption_height),
		Font = font(),
		Text = body or "",
		TextColor3 = style.values.muted:Lerp(style.values.text, 0.5),
		TextSize = body_size,
		TextTransparency = 1,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		ZIndex = 5,
		Parent = content,
	})

	--[[
	local close_hit = util.new("TextButton", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 8),
		Size = UDim2.fromOffset(18, 18),
		Text = "",
		AutoButtonColor = false,
		ZIndex = 7,
		Parent = content,
	})
	local close_color = style.values.muted:Lerp(style.values.text, 0.35)
	local close_icon = icons.close(close_hit, 9, close_color)
	close_icon.AnchorPoint = Vector2.new(0.5, 0.5)
	close_icon.Position = UDim2.fromScale(0.5, 0.5)
	icons.layer(close_icon, 8)
	fade_icon(close_icon, 1, 0.01)
	close_hit.MouseEnter:Connect(function()
		icons.tint(close_icon, style.values.bad)
	end)
	close_hit.MouseLeave:Connect(function()
		icons.tint(close_icon, close_color)
	end)
	]]

	local rail = util.new("Frame", {
		BackgroundColor3 = style.values.line,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, -2),
		Size = UDim2.new(1, 0, 0, 2),
		ZIndex = 4,
		Parent = content,
	})

	local line = util.new("Frame", {
		BackgroundColor3 = tint,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
		Parent = rail,
	})
	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		if not face.Parent then
			return
		end
		util.cancel(line)
		util.tween(face, 0.16, { Size = UDim2.new(1, 0, 0, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		util.tween(content, 0.16, { Position = UDim2.fromOffset(6, -2) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		util.tween(scale, 0.16, { Scale = 0.96 })
		util.tween(scrim, 0.12, { BackgroundTransparency = 1 })
		util.tween(heading, 0.12, { TextTransparency = 1, TextStrokeTransparency = 1 })
		util.tween(kind_label, 0.12, { TextTransparency = 1 })
		util.tween(caption, 0.12, { TextTransparency = 1, TextStrokeTransparency = 1 })
		fade_icon(chip, 1, 0.12)
		-- fade_icon(close_icon, 1, 0.12)
		util.tween(rail, 0.12, { BackgroundTransparency = 1 })
		util.tween(line, 0.12, { BackgroundTransparency = 1 })
		task.delay(0.18, function()
			if face.Parent then
				face:Destroy()
			end
		end)
	end

	local hit = util.new("TextButton", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		AutoButtonColor = false,
		ZIndex = 3,
		Parent = content,
	})
	hit.Activated:Connect(close)
	-- close_hit.Activated:Connect(close)

	util.tween(face, 0.26, { Size = UDim2.new(1, 0, 0, height) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	util.tween(content, 0.28, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	util.tween(scale, 0.32, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	util.tween(chip_scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	util.tween(scrim, 0.22, { BackgroundTransparency = 0 })
	util.tween(heading, 0.2, { TextTransparency = 0, TextStrokeTransparency = 0.25 })
	task.delay(0.04, function()
		if closed or not face.Parent then
			return
		end
		util.tween(caption, 0.22, { TextTransparency = 0, TextStrokeTransparency = 0.35 })
		util.tween(kind_label, 0.2, { TextTransparency = 0 })
		fade_icon(chip, 0, 0.2)
		-- fade_icon(close_icon, 0, 0.2)
		util.tween(rail, 0.2, { BackgroundTransparency = 0.55 })
		util.tween(line, 0.2, { BackgroundTransparency = 0 })
	end)
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
local icons = S.icons
local function font()
	return style.values.font
end
local function bold()
	return style.values.font_bold
end

local tooltip = {}

local DELAY = 0.26
local GAP = 8
local EDGE = 10
local PAD = 9
local PAD_Y = 7
local MARK = 11
local MARK_GAP = 7
local MIN_TEXT = 40
local MAX_TEXT = 208
local LINE = 12

local TextService = game:GetService("TextService")

local function values()
	return style.values
end

local panel = util.new("Frame", {
	Name = "tooltip",
	Active = false,
	BackgroundColor3 = values().panel,
	BorderSizePixel = 0,
	Size = UDim2.fromOffset(0, 0),
	Visible = false,
	ZIndex = 60,
	Parent = env.modal,
})
util.corner(panel, 0)
util.depth(panel, 0.8)
local edge = util.stroke(panel, values().line, 0.18)
util.shadow(panel, 18, 0.4)

local mark = icons.image(panel, "info", MARK, values().muted)
if mark then
	mark.AnchorPoint = Vector2.new(0, 0)
	mark.Position = UDim2.fromOffset(PAD, PAD_Y)
	mark.ZIndex = 62
	icons.layer(mark, 62)
end

local kicker = util.new("TextLabel", {
	Name = "heading",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(PAD, PAD_Y),
	Size = UDim2.fromOffset(0, 0),
	Font = bold(),
	Text = "",
	TextColor3 = values().text,
	TextSize = util.size(9),
	TextTruncate = Enum.TextTruncate.AtEnd,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	ZIndex = 61,
	Parent = panel,
})

local body = util.new("TextLabel", {
	Name = "body",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(PAD, PAD_Y),
	Size = UDim2.fromOffset(0, 0),
	Font = font(),
	Text = "",
	TextColor3 = values().text,
	TextSize = util.size(10),
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	ZIndex = 61,
	Parent = panel,
})

local group_ok = pcall(function()
	panel.GroupTransparency = 0
end)

local current

local function measure(text, size, face, width)
	local ok, box = pcall(function()
		return TextService:GetTextSize(text, size, face, Vector2.new(width, 2048))
	end)
	if ok and typeof(box) == "Vector2" then
		return math.ceil(box.X), math.ceil(box.Y)
	end
	return math.min(width, math.ceil(#text * size * 0.52)), size + 2
end

local function split(value)
	value = string.gsub(value, "^\n+", "")
	value = string.gsub(value, "\n+$", "")
	local head, rest = string.match(value, "^([^\r\n]+)\r?\n(.+)$")
	return head, rest or value
end

local function render(value)
	local head, rest = split(value)
	local text_size = util.size(10)
	local head_size = util.size(9)
	local head_w, head_h = 0, 0
	if head then
		head = string.upper(head)
		head_w, head_h = measure(head, head_size, bold(), MAX_TEXT)
	end
	local body_w = measure(rest, text_size, font(), MAX_TEXT)
	local text_w = math.clamp(math.max(head_w, body_w), MIN_TEXT, MAX_TEXT)
	local _, wrapped_body = measure(rest, text_size, font(), text_w)
	local wrapped_head = head_h
	if head then
		local _, fit = measure(head, head_size, bold(), text_w)
		wrapped_head = math.max(1, fit)
	end
	local content = wrapped_body + (head and (wrapped_head + 2) or 0)
	content = math.max(content, LINE)

	local left = PAD + (mark and (MARK + MARK_GAP) or 0)
	local width = left + text_w + PAD + 2
	local height = content + PAD_Y * 2 + 1
	panel.Size = UDim2.fromOffset(math.floor(width + 0.5), math.floor(height + 0.5))

	kicker.Visible = head ~= nil
	kicker.Text = head or ""
	kicker.Position = UDim2.fromOffset(left, PAD_Y)
	kicker.Size = UDim2.fromOffset(text_w, wrapped_head + 2)

	body.Text = rest
	body.Position = UDim2.fromOffset(left, head and (PAD_Y + wrapped_head + 3) or PAD_Y)
	body.Size = UDim2.fromOffset(text_w, wrapped_body + 2)
	body.TextColor3 = head and values().muted or values().text

	if mark then
		local top = PAD_Y
		local block = head and wrapped_head or wrapped_body
		if block > MARK then
			top = PAD_Y + math.floor((block - MARK) * 0.5)
		end
		mark.Position = UDim2.fromOffset(PAD, top)
	end
end

local function mouse_position()
	local ok, pos = pcall(function()
		return env.uis:GetMouseLocation()
	end)
	if ok and typeof(pos) == "Vector2" then
		return pos
	end
end

local function place(target)
	local view = env.viewport()
	local width = panel.Size.X.Offset
	local height = panel.Size.Y.Offset
	if width <= 0 or height <= 0 then
		return
	end
	local mouse = mouse_position()
	local x
	local y
	if mouse then
		x = mouse.X - width * 0.5
		y = mouse.Y - height - GAP
		if y < EDGE then
			y = mouse.Y + GAP
		end
	else
		local pos = target.AbsolutePosition
		local size = target.AbsoluteSize
		x = pos.X + size.X * 0.5 - width * 0.5
		y = pos.Y - height - GAP
		if y < EDGE then
			y = pos.Y + size.Y + GAP
		end
	end
	x = math.clamp(x, EDGE, math.max(EDGE, view.X - width - EDGE))
	y = math.clamp(y, EDGE, math.max(EDGE, view.Y - height - EDGE))
	panel.Position = UDim2.fromOffset(math.floor(x + 0.5), math.floor(y + 0.5))
end

local function hide()
	current = nil
	if not panel.Parent then
		return
	end
	if group_ok then
		util.cancel(panel)
		panel.GroupTransparency = 0
	end
	panel.Visible = false
end

local function show(target, value)
	if type(value) ~= "string" or value == "" or not target.Parent then
		return
	end
	current = target
	render(value)
	place(target)
	panel.Visible = true
	if group_ok then
		panel.GroupTransparency = 1
		util.tween(panel, 0.12, { GroupTransparency = 0 }, Enum.EasingStyle.Quad)
	end
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
		local value = source()
		if not value then
			return
		end
		token = token + 1
		local mine = token
		task.delay(DELAY, function()
			if mine ~= token or not target.Parent then
				return
			end
			if current == target then
				place(target)
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

local input_link
local move_link

function tooltip.destroy()
	hide()
	if input_link then
		input_link:Disconnect()
		input_link = nil
	end
	if move_link then
		move_link:Disconnect()
		move_link = nil
	end
end

input_link = env.uis.InputBegan:Connect(function(input)
	local kind = input.UserInputType
	if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
		hide()
	end
end)

move_link = env.uis.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement and panel.Visible and current then
		place(current)
	end
end)

style.paint(function()
	panel.BackgroundColor3 = values().panel
	edge.Color = values().line
	kicker.TextColor3 = values().text
	body.TextColor3 = kicker.Visible and values().muted or values().text
	if mark then
		icons.tint(mark, values().muted)
	end
end)

S.tooltip = tooltip
end

do
local env = S.env
local util = S.util
local style = S.style
local function bold()
	return style.values.font_bold
end

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
util.corner(card, 0)
util.depth(card, 0.6)
util.new("UIPadding", {
	PaddingRight = UDim.new(0, 10),
	Parent = card,
})
local edge = util.stroke(card, values().line, 0.25)
util.shadow(card, 16, 0.4)
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
	Font = bold(),
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
	label.Text = string.upper(text)
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
local config = S.config

local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")

local featurelist = {}
local manual = {}
local manual_mode = false
local features = {}
local feature_seq = 0
local attach_seq = 0
local entries = {}
local rows = {}
local exiting = {}
local shown = true
local all_mode = false
local left_mode = false
local scheduled = false
local sort_dirty = true
local last_order = {}
local last_widths = {}
local visual_height = 0
local animation_time = 0.2
local dragging = false
local drag_moved = false
local drag_from
local drag_at
local rgb_mode = false
local rgb_link
local rgb_last = 0

local function values()
	return style.values
end

local base_width = env.mobile and 220 or 260
local top_offset = env.mobile and 90 or 12
local right_margin = 12
local rail_width = 4
local rail_gap = 0
local row_gap = 0
local row_transparency = 0.26

local base_row_height = util.size(20)
local base_text_size = util.size(13)
local base_value_size = util.size(13)
local base_pad_left = env.mobile and 9 or 10
local base_pad_right = env.mobile and 8 or 10
local base_label_gap = 6

local row_height = base_row_height
local pad_left = base_pad_left
local pad_right = base_pad_right
local label_gap = base_label_gap
local text_size = base_text_size
local value_size = base_value_size

local min_row_height = env.mobile and 14 or 13
local min_text_size = env.mobile and 11 or 10
local compact_after = env.mobile and 14 or 16

local function card_width()
	local view = env.viewport()
	return math.min(base_width, math.max(160, view.X - 24))
end

local function apply_density(count)
	local scale = 1
	if count > compact_after then
		scale = 1 - (count - compact_after) * 0.02
	end
	if count > 0 then
		local view = env.viewport()
		local available = math.max(96, view.Y - top_offset - 16)
		local fit = (available - (count - 1) * row_gap) / (count * base_row_height)
		scale = math.min(scale, fit)
	end
	scale = math.clamp(scale, 0.58, 1)
	row_height = math.max(min_row_height, math.floor(base_row_height * scale + 0.5))
	text_size = math.max(min_text_size, math.floor(base_text_size * scale + 0.5))
	value_size = math.max(min_text_size, math.floor(base_value_size * scale + 0.5))
	pad_left = math.max(6, math.floor(base_pad_left * scale + 0.5))
	pad_right = math.max(5, math.floor(base_pad_right * scale + 0.5))
	label_gap = math.max(4, math.floor(base_label_gap * scale + 0.5))
end

local function max_row_width()
	return math.max(80, card_width() - rail_width - rail_gap)
end

local card = util.new("Frame", {
	Name = "feature_list",
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -right_margin, 0, top_offset),
	Size = UDim2.fromOffset(card_width(), 0),
	Visible = false,
	ClipsDescendants = true,
	ZIndex = 2,
	Parent = env.notes,
})

local content = util.new("Frame", {
	Name = "content",
	BackgroundTransparency = 1,
	Size = UDim2.new(1, -(rail_width + rail_gap), 1, 0),
	ZIndex = 2,
	Parent = card,
})

local RGB_SEQUENCE = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 82, 82)),
	ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 178, 72)),
	ColorSequenceKeypoint.new(0.34, Color3.fromRGB(250, 242, 100)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(106, 230, 126)),
	ColorSequenceKeypoint.new(0.67, Color3.fromRGB(82, 198, 255)),
	ColorSequenceKeypoint.new(0.84, Color3.fromRGB(126, 120, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 82, 82)),
})

local ROW_SHEEN = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(0.55, Color3.fromRGB(238, 241, 245)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(205, 210, 217)),
})

local RAIL_SHADE = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(210, 215, 222)),
})

local rail = util.new("Frame", {
	Name = "rail",
	BackgroundColor3 = values().accent,
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 0),
	Size = UDim2.new(0, rail_width, 1, 0),
	ZIndex = 4,
	Parent = card,
})
util.corner(rail, 0)
local rail_gradient = util.new("UIGradient", {
	Name = "rgb",
	Color = RAIL_SHADE,
	Enabled = true,
	Rotation = 90,
	Parent = rail,
})

local function side_row(row)
	if left_mode then
		row.strip.AnchorPoint = Vector2.new(0, 0)
		row.strip.Position = UDim2.fromOffset(0, 0)
	else
		row.strip.AnchorPoint = Vector2.new(1, 0)
		row.strip.Position = UDim2.new(1, 0, 0, 0)
	end
end

local function apply_side()
	if left_mode then
		rail.AnchorPoint = Vector2.new(0, 0)
		rail.Position = UDim2.fromOffset(0, 0)
		content.Position = UDim2.fromOffset(rail_width + rail_gap, 0)
	else
		rail.AnchorPoint = Vector2.new(1, 0)
		rail.Position = UDim2.new(1, 0, 0, 0)
		content.Position = UDim2.fromOffset(0, 0)
	end
	content.Size = UDim2.new(1, -(rail_width + rail_gap), 1, 0)
	for _, row in ipairs(rows) do
		side_row(row)
	end
	for _, row in ipairs(exiting) do
		side_row(row)
	end
end

local function update_side(width, x)
	local view = env.viewport()
	width = width or card.Size.X.Offset
	x = x or card.Position.X.Offset
	local center = view.X + x - width / 2
	local left = center < view.X / 2
	if left ~= left_mode then
		left_mode = left
		apply_side()
	end
end

local function card_height()
	return math.max(card.Size.Y.Offset, visual_height)
end

local function clamp_position(width, height)
	local view = env.viewport()
	width = width or card.Size.X.Offset
	height = height or card_height()
	local x = math.clamp(card.Position.X.Offset, math.min(0, width - view.X), 0)
	local y = math.clamp(card.Position.Y.Offset, 0, math.max(0, view.Y - height))
	if x ~= card.Position.X.Offset or y ~= card.Position.Y.Offset then
		card.Position = UDim2.new(1, x, 0, y)
	end
	update_side(width, x)
end

local function remember()
	config.place_featurelist({
		x = card.Position.X.Offset,
		y = card.Position.Y.Offset,
	})
end

local drag = util.new("TextButton", {
	Name = "drag",
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
	Text = "",
	AutoButtonColor = false,
	Active = true,
	Selectable = false,
	ZIndex = 7,
	Parent = card,
})

local drag_begin = drag.InputBegan:Connect(function(input)
	local kind = input.UserInputType
	if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
		dragging = true
		drag_moved = false
		drag_from = input.Position
		drag_at = Vector2.new(card.Position.X.Offset, card.Position.Y.Offset)
	end
end)

local drag_move = env.uis.InputChanged:Connect(function(input)
	if not dragging then
		return
	end
	local kind = input.UserInputType
	if kind ~= Enum.UserInputType.MouseMovement and kind ~= Enum.UserInputType.Touch then
		return
	end
	local delta = input.Position - drag_from
	if delta.Magnitude < 1 then
		return
	end
	drag_moved = true
	local view = env.viewport()
	local width = card.Size.X.Offset
	local height = card_height()
	local x = math.clamp(drag_at.X + delta.X, math.min(0, width - view.X), 0)
	local y = math.clamp(drag_at.Y + delta.Y, 0, math.max(0, view.Y - height))
	card.Position = UDim2.new(1, x, 0, y)
	update_side(width, x)
end)

local drag_end = env.uis.InputEnded:Connect(function(input)
	local kind = input.UserInputType
	if dragging and (kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch) then
		dragging = false
		clamp_position()
		if drag_moved then
			remember()
		end
	end
end)

local function shorten(value)
	local text = tostring(value):gsub("%s+", " ")
	if #text > 22 then
		text = string.sub(text, 1, 20) .. "..."
	end
	return text
end

local function normalize(value, label)
	if value == nil or value == false then
		return nil
	end
	if type(value) == "table" then
		if value.active == false then
			return nil
		end
		local text = value.value
		if text == nil then
			text = value.text
		end
		local name = value.label or label
		if name == nil then
			return nil
		end
		return {
			label = tostring(name),
			value = text ~= nil and shorten(text) or nil,
		}
	end
	if value == true then
		if label == nil then
			return nil
		end
		return { label = tostring(label) }
	end
	if type(value) == "string" or type(value) == "number" then
		local text = shorten(value)
		if text == "" or label == nil then
			return nil
		end
		return { label = tostring(label), value = text }
	end
	return nil
end

local measured = {}
local measured_count = 0

local function measure(text, size, font)
	local value = tostring(text)
	if value == "" then
		return 0
	end
	local key = tostring(font) .. "|" .. tostring(size) .. "|" .. value
	local cached = measured[key]
	if cached then
		return cached
	end
	local width
	local ok, box = pcall(function()
		return TextService:GetTextSize(value, size, font, Vector2.new(2048, 128))
	end)
	if ok and typeof(box) == "Vector2" then
		width = math.ceil(box.X)
	else
		width = math.ceil(#value * size * 0.56)
	end
	if measured_count >= 512 then
		table.clear(measured)
		measured_count = 0
	end
	measured[key] = width
	measured_count = measured_count + 1
	return width
end

local function row_metrics(entry)
	local available = max_row_width() - pad_left - pad_right
	local label_w = measure(entry.label, text_size, values().font_medium)
	local value_w = entry.value and measure(entry.value, value_size, values().font) or 0
	if value_w > 0 then
		value_w = math.min(value_w, math.max(20, available - label_gap - 36))
		label_w = math.min(label_w, math.max(20, available - label_gap - value_w))
	else
		label_w = math.min(label_w, math.max(20, available))
	end
	local width = pad_left + label_w + (value_w > 0 and (label_gap + value_w) or 0) + pad_right
	return label_w, value_w, math.min(width, max_row_width())
end

local function apply_row_layout(row, instant)
	local label_w, value_w, width = row_metrics(row.entry)
	row.root.Size = UDim2.new(1, 0, 0, row_height)
	row.label.Size = UDim2.fromOffset(label_w, row_height)
	row.value.Size = UDim2.fromOffset(value_w, row_height)
	row.value.Position = UDim2.fromOffset(pad_left + label_w + (value_w > 0 and label_gap or 0), 0)
	row.value.Visible = value_w > 0
	row.target_width = width
	if instant and not row.appearing then
		row.strip.Size = UDim2.fromOffset(width, row_height)
	end
end

local function height()
	local count = #entries
	if count == 0 then
		return 0
	end
	return count * row_height + (count - 1) * row_gap
end

local function place_row(row, index, animate)
	local target = UDim2.fromOffset(0, (index - 1) * (row_height + row_gap))
	if row.slot ~= index then
		row.slot = index
		if animate and row.root.Parent then
			util.tween(row.root, animation_time, { Position = target }, Enum.EasingStyle.Quint)
		else
			row.root.Position = target
		end
	end
end

local function update_corners()
	for _, row in ipairs(rows) do
		local corner = row.corner
		if corner then
			corner.TopLeftRadius = UDim.new(0, 0)
			corner.TopRightRadius = UDim.new(0, 0)
			corner.BottomLeftRadius = UDim.new(0, 0)
			corner.BottomRightRadius = UDim.new(0, 0)
		end
	end
end

local function grow_row(row)
	if not row.strip.Parent then
		return
	end
	row.appearing = true
	row.grow_token = (row.grow_token or 0) + 1
	local token = row.grow_token
	util.tween(row.strip, animation_time, {
		Size = UDim2.fromOffset(row.target_width or 0, row_height),
	}, Enum.EasingStyle.Quint)
	task.delay(animation_time, function()
		if row.grow_token == token then
			row.appearing = false
		end
	end)
end

local function resize(hold, animate)
	local total = height()
	local rail_total = total
	if hold then
		total = math.max(total, visual_height)
	end
	local width = card_width()
	local changed = total ~= visual_height or card.Size.X.Offset ~= width
	visual_height = total
	if changed then
		local target = UDim2.fromOffset(width, total)
		if animate and card.Parent then
			util.tween(card, animation_time, { Size = target }, Enum.EasingStyle.Quint)
		else
			util.cancel(card)
			card.Size = target
		end
	end
	content.Size = UDim2.new(1, -(rail_width + rail_gap), 1, 0)
	local rail_target = UDim2.new(0, rail_width, 0, rail_total)
	if animate and card.Parent then
		util.tween(rail, animation_time, { Size = rail_target }, Enum.EasingStyle.Quint)
	else
		util.cancel(rail)
		rail.Size = rail_target
	end
	card.Visible = shown and total > 0
	clamp_position(width, total)
end

local function remove_exiting(row)
	for index, item in ipairs(exiting) do
		if item == row then
			table.remove(exiting, index)
			return
		end
	end
end

local function cancel_exit(row)
	if not row.removing then
		return
	end
	row.removing = false
	row.exit_token = (row.exit_token or 0) + 1
	remove_exiting(row)
	util.cancel(row.strip)
	util.cancel(row.label)
	util.cancel(row.value)
	row.root.ZIndex = 3
	row.strip.ZIndex = 3
	row.label.ZIndex = 3
	row.value.ZIndex = 3
	row.strip.BackgroundTransparency = row_transparency
	row.label.TextTransparency = 0
	row.value.TextTransparency = 0
	row.appearing = true
end

local function start_exit(row)
	if row.removing then
		return
	end
	row.removing = true
	row.appearing = false
	row.grow_token = (row.grow_token or 0) + 1
	row.exit_token = (row.exit_token or 0) + 1
	row.root.ZIndex = 2
	row.strip.ZIndex = 2
	row.label.ZIndex = 2
	row.value.ZIndex = 2
	local token = row.exit_token
	exiting[#exiting + 1] = row
	util.cancel(row.strip)
	util.tween(row.strip, animation_time, {
		Size = UDim2.fromOffset(0, row_height),
		BackgroundTransparency = 1,
	}, Enum.EasingStyle.Quint)
	util.tween(row.label, animation_time, { TextTransparency = 1 }, Enum.EasingStyle.Quint)
	util.tween(row.value, animation_time, { TextTransparency = 1 }, Enum.EasingStyle.Quint)
	if row.edge then
		util.tween(row.edge, animation_time, { Transparency = 1 }, Enum.EasingStyle.Quint)
	end
	task.delay(animation_time, function()
		if row.exit_token ~= token or not row.removing then
			return
		end
		row.removing = false
		remove_exiting(row)
		if row.root.Parent then
			row.root:Destroy()
		end
		if card.Parent and #exiting == 0 then
			resize(false, true)
		end
	end)
end

local function rgb_gradient(row)
	if row.rgb_gradient and row.rgb_gradient.Parent then
		return row.rgb_gradient
	end
	row.rgb_gradient = util.new("UIGradient", {
		Name = "rgb",
		Color = RGB_SEQUENCE,
		Enabled = false,
		Rotation = 90,
		Parent = row.label,
	})
	return row.rgb_gradient
end

local function rgb_value_gradient(row)
	if row.rgb_value_gradient and row.rgb_value_gradient.Parent then
		return row.rgb_value_gradient
	end
	row.rgb_value_gradient = util.new("UIGradient", {
		Name = "rgb_value",
		Color = RGB_SEQUENCE,
		Enabled = false,
		Rotation = 90,
		Parent = row.value,
	})
	return row.rgb_value_gradient
end

local function rgb_phase(phase)
	return (phase * 0.16) % 1
end

local RAIL_STEPS = 16

local function rail_sequence(base)
	local points = {}
	for index = 0, RAIL_STEPS do
		local position = index / RAIL_STEPS
		local hue = (base - position) % 1
		points[#points + 1] = ColorSequenceKeypoint.new(position, Color3.fromHSV(hue, 1, 1))
	end
	return ColorSequence.new(points)
end

local function paint_rgb(phase)
	local base = rgb_phase(phase or os.clock())
	rail.BackgroundColor3 = Color3.new(1, 1, 1)
	rail_gradient.Color = rail_sequence(base)
	rail_gradient.Enabled = true
	rail_gradient.Offset = Vector2.new(0, 0)
	local total = math.max(2, #rows + #exiting)
	local function paint_row(row, index)
		local hue = (base - index / total) % 1
		local next_hue = (base - (index + 1) / total) % 1
		row.label.TextColor3 = Color3.new(1, 1, 1)
		row.value.TextColor3 = Color3.new(1, 1, 1)
		local gradient = rgb_gradient(row)
		gradient.Enabled = true
		gradient.Offset = Vector2.new(0, 0)
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, 0.92, 1)),
			ColorSequenceKeypoint.new(1, Color3.fromHSV(next_hue, 0.92, 1)),
		})
		local value_gradient = rgb_value_gradient(row)
		value_gradient.Enabled = true
		value_gradient.Offset = Vector2.new(0, 0)
		value_gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, 0.52, 1)),
			ColorSequenceKeypoint.new(1, Color3.fromHSV(next_hue, 0.52, 1)),
		})
		if row.edge then
			row.edge.Color = Color3.new(1, 1, 1)
			row.edge.Transparency = 0.86
		end
	end
	for index, row in ipairs(rows) do
		paint_row(row, index)
	end
	for index, row in ipairs(exiting) do
		paint_row(row, #rows + index)
	end
end

local function stop_rgb()
	if rgb_link then
		rgb_link:Disconnect()
		rgb_link = nil
	end
end

local function start_rgb()
	if rgb_link or not card.Parent then
		return
	end
	rgb_last = 0
	rgb_link = RunService.Heartbeat:Connect(function()
		if not rgb_mode or not card.Parent then
			stop_rgb()
			return
		end
		local now = os.clock()
		if now - rgb_last < 0.03 then
			return
		end
		rgb_last = now
		if shown then
			paint_rgb(now)
		end
	end)
end

local function paint()
	rail.BackgroundColor3 = values().accent
	rail_gradient.Color = RAIL_SHADE
	rail_gradient.Offset = Vector2.new(0, 0)
	rail_gradient.Enabled = true
	for _, row in ipairs(rows) do
		side_row(row)
		row.root.ZIndex = 3
		row.strip.ZIndex = 3
		row.label.ZIndex = 3
		row.value.ZIndex = 3
		row.strip.BackgroundColor3 = values().panel
		row.strip.BackgroundTransparency = row_transparency
		row.label.Font = values().font_medium
		row.label.TextSize = text_size
		row.label.TextColor3 = values().accent
		row.label.TextTransparency = 0
		row.value.Font = values().font
		row.value.TextSize = value_size
		row.value.TextColor3 = values().text
		row.value.TextTransparency = 0
		apply_row_layout(row, true)
		if row.edge then
			row.edge.Color = values().line
			row.edge.Transparency = 0.8
		end
		if row.rgb_gradient then
			row.rgb_gradient.Enabled = false
		end
		if row.rgb_value_gradient then
			row.rgb_value_gradient.Enabled = false
		end
		if row.appearing then
			grow_row(row)
		end
	end
	for _, row in ipairs(exiting) do
		row.label.TextColor3 = values().accent
		row.value.TextColor3 = values().text
		if row.rgb_gradient then
			row.rgb_gradient.Enabled = false
		end
		if row.rgb_value_gradient then
			row.rgb_value_gradient.Enabled = false
		end
		if row.edge then
			row.edge.Color = values().line
			row.edge.Transparency = 0.8
		end
	end
	if rgb_mode then
		paint_rgb()
	end
end

local function collect()
	if manual_mode then
		local out = {}
		for index, item in ipairs(manual) do
			local entry = {
				label = item.label,
				value = item.value,
				id = "manual:" .. index,
				seq = index,
			}
			out[#out + 1] = entry
		end
		apply_density(#out)
		for _, entry in ipairs(out) do
			entry.width = select(3, row_metrics(entry))
		end
		last_widths = {}
		for _, entry in ipairs(out) do
			last_widths[entry.id] = entry.width
		end
		return out
	end

	local candidates = {}
	local has_explicit = false
	for _, feature in pairs(features) do
		local ok, value = pcall(feature.getter)
		if ok then
			local entry = normalize(value, feature.label)
			if entry then
				entry.id = feature.id
				entry.seq = feature.seq
				entry.order = feature.order
				entry.explicit_order = feature.explicit_order
				candidates[#candidates + 1] = entry
				if feature.explicit_order ~= nil then
					has_explicit = true
				end
			end
		end
	end
	apply_density(#candidates)
	for _, entry in ipairs(candidates) do
		entry.width = select(3, row_metrics(entry))
	end

	local widths = {}
	local width_changed = false
	for _, entry in ipairs(candidates) do
		local previous = last_widths[entry.id]
		if previous ~= nil and previous ~= entry.width then
			width_changed = true
		end
		widths[entry.id] = entry.width
	end
	last_widths = widths
	if width_changed then
		sort_dirty = true
	end

	local same_set = #last_order == #candidates
	if same_set then
		local present = {}
		for _, id in ipairs(last_order) do
			present[id] = true
		end
		for _, entry in ipairs(candidates) do
			if not present[entry.id] then
				same_set = false
				break
			end
		end
	end

	local function by_width(list)
		table.sort(list, function(a, b)
			if a.width ~= b.width then
				return a.width > b.width
			end
			return a.seq < b.seq
		end)
	end

	local function by_last(list)
		local position = {}
		for index, id in ipairs(last_order) do
			position[id] = index
		end
		table.sort(list, function(a, b)
			local pa = position[a.id] or math.huge
			local pb = position[b.id] or math.huge
			if pa ~= pb then
				return pa < pb
			end
			return a.seq < b.seq
		end)
	end

	if has_explicit then
		local explicit_list = {}
		local auto_list = {}
		for _, entry in ipairs(candidates) do
			if entry.explicit_order ~= nil then
				explicit_list[#explicit_list + 1] = entry
			else
				auto_list[#auto_list + 1] = entry
			end
		end
		table.sort(explicit_list, function(a, b)
			if a.explicit_order ~= b.explicit_order then
				return a.explicit_order < b.explicit_order
			end
			return a.seq < b.seq
		end)
		if sort_dirty or not same_set then
			by_width(auto_list)
			sort_dirty = false
		else
			by_last(auto_list)
		end
		local merged = {}
		for _, entry in ipairs(explicit_list) do
			merged[#merged + 1] = entry
		end
		for _, entry in ipairs(auto_list) do
			merged[#merged + 1] = entry
		end
		candidates = merged
	else
		if sort_dirty or not same_set then
			by_width(candidates)
			sort_dirty = false
		else
			by_last(candidates)
		end
	end

	local ids = {}
	for index, entry in ipairs(candidates) do
		ids[index] = entry.id
	end
	last_order = ids
	return candidates
end

local function create_row(entry)
	local root = util.new("Frame", {
		Name = "feature_row",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, row_height),
		ZIndex = 3,
		Parent = content,
	})
	local strip = util.new("Frame", {
		Name = "strip",
		BackgroundColor3 = values().panel,
		BackgroundTransparency = row_transparency,
		BorderSizePixel = 0,
		AnchorPoint = left_mode and Vector2.new(0, 0) or Vector2.new(1, 0),
		Position = left_mode and UDim2.fromOffset(0, 0) or UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(0, row_height),
		ClipsDescendants = true,
		ZIndex = 3,
		Parent = root,
	})
	local corner = util.new("UICorner", {
		CornerRadius = UDim.new(0, 0),
		Parent = strip,
	})
	local edge = util.stroke(strip, values().line, 0.8)
	local sheen = util.new("UIGradient", {
		Name = "sheen",
		Color = ROW_SHEEN,
		Rotation = 90,
		Parent = strip,
	})
	local label = util.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(pad_left, 0),
		Size = UDim2.fromOffset(0, row_height),
		Font = values().font_medium,
		Text = entry.label,
		TextColor3 = values().accent,
		TextSize = text_size,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0.72,
		ZIndex = 3,
		Parent = strip,
	})
	local value = util.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(pad_left, 0),
		Size = UDim2.fromOffset(0, row_height),
		Font = values().font,
		Text = entry.value or "",
		TextColor3 = values().text,
		TextSize = value_size,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0.8,
		Visible = false,
		ZIndex = 3,
		Parent = strip,
	})
	return {
		id = entry.id,
		entry = entry,
		root = root,
		strip = strip,
		corner = corner,
		edge = edge,
		sheen = sheen,
		label = label,
		value = value,
		appearing = false,
		removing = false,
		exit_token = 0,
		grow_token = 0,
	}
end

local function build()
	if not card.Parent then
		return
	end
	local next_entries = collect()
	local all = {}
	for _, row in ipairs(rows) do
		all[row.id] = row
	end
	for _, row in ipairs(exiting) do
		all[row.id] = row
	end

	local used = {}
	local next_rows = {}
	for index, entry in ipairs(next_entries) do
		local row = all[entry.id]
		if row then
			used[row] = true
			if row.removing then
				cancel_exit(row)
			end
			row.entry = entry
			row.label.Text = entry.label
			row.value.Text = entry.value or ""
			apply_row_layout(row, not row.appearing)
			next_rows[#next_rows + 1] = row
		else
			row = create_row(entry)
			row.entry = entry
			apply_row_layout(row, false)
			row.strip.Size = UDim2.fromOffset(0, row_height)
			row.root.Position = UDim2.fromOffset(0, (index - 1) * (row_height + row_gap))
			row.slot = index
			row.appearing = true
			next_rows[#next_rows + 1] = row
		end
	end

	for _, row in ipairs(rows) do
		if not used[row] then
			start_exit(row)
		end
	end

	rows = next_rows
	entries = next_entries
	update_corners()
	resize(#exiting > 0, true)
	paint()
	for index, row in ipairs(rows) do
		place_row(row, index, true)
	end
end

function featurelist.set(list)
	if type(list) == "string" then
		list = { list }
	end
	local next_manual = {}
	if type(list) == "table" then
		for _, item in ipairs(list) do
			local label
			local value
			if type(item) == "string" then
				label = item
			elseif type(item) == "table" then
				label = item.label or item.name or item[1]
				value = item.value
				if value == nil then
					value = item[2]
				end
			end
			if label ~= nil then
				next_manual[#next_manual + 1] = {
					label = tostring(label),
					value = value ~= nil and shorten(value) or nil,
				}
			end
		end
	end
	manual = next_manual
	manual_mode = #manual > 0
	sort_dirty = true
	if manual_mode then
		shown = true
	end
	build()
	return featurelist.get()
end

function featurelist.enabled(opts, auto)
	local spec = type(opts) == "table" and opts.feature
	if spec == false then
		return false
	end
	return auto == true or spec ~= nil or all_mode
end

function featurelist.bind(id, label, getter, opts)
	if type(id) ~= "string" or id == "" or type(getter) ~= "function" then
		return nil
	end
	opts = type(opts) == "table" and opts or {}
	feature_seq = feature_seq + 1
	local explicit = tonumber(opts.order)
	features[id] = {
		id = id,
		label = tostring(label or id),
		getter = getter,
		opts = opts,
		explicit_order = explicit,
		order = explicit or feature_seq,
		seq = feature_seq,
	}
	sort_dirty = true
	build()
	return {
		id = id,
		Update = function()
			featurelist.touch()
		end,
		Remove = function()
			featurelist.unbind(id)
		end,
	}
end

function featurelist.attach(win, kind, label, opts, getter, auto)
	local spec = type(opts) == "table" and opts.feature
	if spec == false then
		return nil
	end
	local settings = type(spec) == "table" and spec or {}
	local name = type(spec) == "string" and spec or settings.label or label
	attach_seq = attach_seq + 1
	local id = tostring(win and win._key or "window")
		.. "/"
		.. tostring(kind or "feature")
		.. "/"
		.. tostring(label)
		.. "/"
		.. attach_seq
	return featurelist.bind(id, name, function()
		if not featurelist.enabled(opts, auto) then
			return nil
		end
		return getter()
	end, {
		order = settings.order,
		kind = kind,
	})
end

function featurelist.unbind(id)
	if features[id] then
		features[id] = nil
		sort_dirty = true
		build()
	end
end

function featurelist.touch()
	if scheduled then
		return
	end
	scheduled = true
	task.defer(function()
		scheduled = false
		if card.Parent then
			build()
		end
	end)
end

function featurelist.touch_if(opts, auto)
	if featurelist.enabled(opts, auto) then
		featurelist.touch()
	end
end

function featurelist.all(state)
	if state ~= nil and state ~= all_mode then
		all_mode = state == true
		sort_dirty = true
		build()
	end
	return all_mode
end

function featurelist.restore()
	local saved = config.featurelist_state()
	if type(saved) == "table" and type(saved.x) == "number" and type(saved.y) == "number" then
		card.Position = UDim2.new(1, saved.x, 0, saved.y)
	end
	clamp_position()
end

function featurelist.rgb(state)
	if state ~= nil then
		local next_mode = state == true
		if next_mode ~= rgb_mode then
			rgb_mode = next_mode
			if rgb_mode then
				start_rgb()
				paint_rgb()
			else
				stop_rgb()
				paint()
			end
		end
	end
	return rgb_mode
end

function featurelist.visible(state)
	shown = state == true
	card.Visible = shown and visual_height > 0
	return shown
end

function featurelist.get()
	local copy = {}
	for index, entry in ipairs(entries) do
		copy[index] = {
			label = entry.label,
			value = entry.value,
		}
	end
	return copy, shown
end

style.paint(paint)
paint()
apply_side()

local camera_link
local function watch_viewport()
	if camera_link then
		camera_link:Disconnect()
		camera_link = nil
	end
	local camera = workspace.CurrentCamera
	if camera then
		camera_link = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if card.Parent then
				featurelist.touch()
				resize(#exiting > 0, false)
				paint()
			end
		end)
	end
end
watch_viewport()
card.Destroying:Connect(function()
	dragging = false
	rgb_mode = false
	stop_rgb()
	if camera_link then
		camera_link:Disconnect()
		camera_link = nil
	end
	if drag_begin then
		drag_begin:Disconnect()
		drag_begin = nil
	end
	if drag_move then
		drag_move:Disconnect()
		drag_move = nil
	end
	if drag_end then
		drag_end:Disconnect()
		drag_end = nil
	end
end)

S.featurelist = featurelist
end

do
local env = S.env
local util = S.util
local style = S.style
local brand = S.brand
local function bold()
	return style.values.font_bold
end
local function font()
	return style.values.font_medium
end
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
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(card_w, card_h),
		ZIndex = 3,
		Parent = gui,
	})
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
			Font = bold(),
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
		Font = bold(),
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
		Font = font(),
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
		Font = font(),
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
local sounds = S.sounds
local function bold()
	return style.values.font_bold
end
local function font()
	return style.values.font
end

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

local function preferred_set(list)
	local set = {}
	if type(list) == "table" then
		for _, name in ipairs(list) do
			set[tostring(name)] = true
		end
	end
	return set
end

local function tab_preferred(spec)
	local source = type(spec) == "table" and spec or {}
	local open_list = source.open
	local closed_list = source.closed
	if type(source.sections) == "table" then
		open_list = open_list or source.sections.open
		closed_list = closed_list or source.sections.closed
	end
	return { open = preferred_set(open_list), closed = preferred_set(closed_list) }
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
	local head = mobile and 40 or 36
	local row_base = mobile and 36 or 30
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
	w._sound_muted = saved and saved.sound_muted == true

	function w._play_sound(name, opts)
		if not sounds or w._sound_muted then
			return false
		end
		return sounds.play(name, opts)
	end

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
	local edge = util.stroke(body, values().line, 0.12)
	util.shadow(body, 30, 0.22)
	util.depth(body, 0.65)

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
		if not state.asset or state.status == "failed" then
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
	util.shadow(header, 12, 0.38)
	util.depth(header, 0.7)
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
		Size = UDim2.new(1, mobile and -148 or -112, 1, 0),
		Font = bold(),
		Text = string.upper(tostring(title or "Window")),
		TextColor3 = values().text,
		TextSize = util.size(10),
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
			caption.Size = UDim2.new(1, mobile and -160 or -124, 1, 0)
			style.paint(function()
				icons.tint(emblem, values().accent)
			end)
		end
	end

	style.paint(function()
		mark.BackgroundColor3 = values().accent
		caption.TextColor3 = values().text
	end)

	local function remember()
		config.place(key, {
			x = root.Position.X.Offset,
			y = root.Position.Y.Offset,
			width = width,
			height = height_override,
			open = open,
			sound_muted = w._sound_muted,
		})
	end

	local function ghost(offset)
		local hit = util.new("TextButton", {
			BackgroundColor3 = values().raised,
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, offset, 0.5, 0),
			Size = UDim2.fromOffset(mobile and 34 or 24, mobile and 34 or 24),
			Text = "",
			ZIndex = 5,
			Parent = header,
		})
		util.corner(hit, 0)
		util.hover(hit)
		return hit
	end

	local sound_hit = ghost(mobile and -82 or -60)
	local fold_hit = ghost(mobile and -44 or -33)
	local close_hit = ghost(-6)
	local sound_icon = icons.image(sound_hit, "volume", mobile and 16 or 14, values().muted)
	if sound_icon then
		sound_icon.AnchorPoint = Vector2.new(0.5, 0.5)
		sound_icon.Position = UDim2.fromScale(0.5, 0.5)
		icons.layer(sound_icon, 6)
	end
	local sound_slash = util.new("Frame", {
		BackgroundColor3 = values().bad,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Rotation = 45,
		Size = UDim2.fromOffset(mobile and 18 or 15, 1),
		Visible = false,
		ZIndex = 7,
		Parent = sound_hit,
	})
	local function paint_sound()
		local on = (not sounds or sounds.get_enabled()) and not w._sound_muted
		if sound_icon then
			icons.tint(sound_icon, on and values().accent or values().muted)
		end
		sound_slash.BackgroundColor3 = values().bad
		sound_slash.Visible = not on
	end
	if sounds and sounds.watch then
		local stop_sound_watch = sounds.watch(paint_sound)
		root.Destroying:Connect(stop_sound_watch)
	else
		paint_sound()
	end
	w._paint_sound = paint_sound

	local function toggle_window_sound()
		if not sounds then
			return
		end
		w._sound_muted = not w._sound_muted
		remember()
		paint_sound()
		if w._sound_muted then
			if sounds.get_enabled() then
				sounds.play("toggle_off", { force = true })
			end
		else
			w._play_sound("toggle_on")
		end
	end

	local function toggle_global_sound()
		if not sounds then
			return
		end
		if sounds.get_enabled() then
			sounds.set_enabled(false)
			sounds.play("toggle_off", { force = true })
		else
			sounds.set_enabled(true)
			sounds.play("toggle_on", { force = true })
		end
		paint_sound()
	end

	local hold_started = false
	local hold_fired = false
	local hold_token = 0
	sound_hit.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
			return
		end
		hold_started = true
		hold_fired = false
		hold_token = hold_token + 1
		local token = hold_token
		task.delay(0.55, function()
			if hold_started and hold_token == token and sound_hit.Parent and root.Parent then
				hold_started = false
				hold_fired = true
				toggle_global_sound()
			end
		end)
	end)
	sound_hit.InputEnded:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			hold_started = false
			hold_token = hold_token + 1
		end
	end)
	sound_hit.Activated:Connect(function()
		if hold_fired then
			hold_fired = false
			return
		end
		toggle_window_sound()
	end)
	if tooltip then
		tooltip.attach(sound_hit, "Tap to mute this window; hold to mute all sound")
	end
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
		Size = UDim2.fromOffset(1, open and 0 or 9),
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
	close_hit.MouseEnter:Connect(function()
		close_a.BackgroundColor3 = values().bad
		close_b.BackgroundColor3 = values().bad
	end)
	close_hit.MouseLeave:Connect(function()
		close_a.BackgroundColor3 = values().muted
		close_b.BackgroundColor3 = values().muted
	end)

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

	local tab_h = mobile and 36 or 32
	local tabs = {}
	local section_records = {}
	local default_tab = {
		name = "Main",
		icon = nil,
		slots = {},
		section_of = {},
		section_ids = {},
		preferred = { open = {}, closed = {} },
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
	util.shadow(strip, 10, 0.5)
	util.depth(strip, 0.55)

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
		tab.chip.BackgroundColor3 = values().raised
		tab.chip.BackgroundTransparency = on and 0.18 or 1
		tab.chip.TextColor3 = on and values().accent or values().muted
		if tab.chip_edge then
			tab.chip_edge.Color = on and values().accent or values().line
			tab.chip_edge.Transparency = on and 0.68 or 1
		end
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
			Size = UDim2.fromOffset(0, tab_h - 2),
			Font = font(),
			Text = string.upper(tab.name),
			TextColor3 = values().muted,
			TextSize = util.size(9),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 4,
			Parent = rail,
		})
		util.corner(chip, 0)
		local chip_edge = util.stroke(chip, values().line, 1)
		tab.chip_edge = chip_edge
		util.new("UISizeConstraint", {
			MaxSize = Vector2.new(mobile and 132 or 152, tab_h),
			Parent = chip,
		})
		local has_icon = type(tab.icon) == "string" and tab.icon ~= ""
		local pad_left = has_icon and 21 or 7
		local pad_right = 7
		local padding = util.new("UIPadding", {
			PaddingLeft = UDim.new(0, pad_left),
			PaddingRight = UDim.new(0, pad_right),
			Parent = chip,
		})
		local emblem
		if has_icon then
			emblem = icons.image(chip, tab.icon, 11, values().muted)
			if emblem then
				emblem.AnchorPoint = Vector2.new(0, 0.5)
				emblem.Position = UDim2.new(0, 7 - pad_left, 0.5, 0)
				icons.layer(emblem, 5)
			else
				padding.PaddingLeft = UDim.new(0, 7)
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
			if tab ~= active_tab then
				w._play_sound("tab")
			end
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

	local function make_tab(name, tab_icon, note, tab_order, spec)
		if not default_tab.chip then
			chip_for(default_tab)
		end
		local tab = {
			name = name,
			icon = tab_icon,
			tooltip = note,
			slots = {},
			section_of = {},
			section_ids = {},
			preferred = tab_preferred(spec),
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
		util.tween(fold_bar_v, 0.15, { Size = UDim2.fromOffset(1, open and 0 or 9) })
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
		w._play_sound("click")
		fold()
	end)
	close_hit.Activated:Connect(function()
		w._play_sound("close")
		close()
	end)

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
	end, w._play_sound)

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
		local changed = record.open ~= state
		record.open = state
		if changed and record.id then
			config.place_section(key, record.id, state)
		end
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

	local function new_section(tab, default_open, title, id)
		local name = tostring(title or "Section")
		local base = type(id) == "string" and id ~= "" and id or name
		local counts = tab.section_ids
		if not counts then
			counts = {}
			tab.section_ids = counts
		end
		local count = (counts[base] or 0) + 1
		counts[base] = count
		local ident = tostring(tab.name or "Tab") .. "/" .. (count == 1 and base or (base .. "#" .. count))
		local developer
		local preferred = tab.preferred
		if preferred then
			if preferred.closed and (preferred.closed[name] or preferred.closed[ident]) then
				developer = false
			elseif preferred.open and (preferred.open[name] or preferred.open[ident]) then
				developer = true
			end
		end
		if developer == nil then
			developer = default_open == true
		end
		local state = config.section_state(key, ident)
		if state == nil then
			state = developer
		end
		local record = { open = state == true, default_open = developer, slots = {}, tab = tab, id = ident }
		section_records[#section_records + 1] = record
		return record
	end

	function w._slot(height, ungrouped)
		return slot_for(active_tab, height, ungrouped)
	end

	function w._new_section(default_open, title, id)
		return new_section(active_tab, default_open, title, id)
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
			return S.options.attach(row, title, build, w._play_sound)
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
				return S.options.attach(row, caption, build, w._play_sound)
			end
		end

		function api._play_sound(name, opts)
			return w._play_sound(name, opts)
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

		function api._new_section(default_open, title, id)
			return new_section(tab, default_open, title, id)
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
		target.section = function(self, text, icon, opts)
			return S.text.section(self, text, icon, opts)
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
			tab.preferred = tab_preferred(spec)
			tab.implicit = false
			chip_for(tab)
		else
			tab = make_tab(label, tab_icon, note, #tabs + 1, spec)
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
				fold_bar_v.Size = UDim2.fromOffset(1, open and 0 or 9)
			end
			w._sound_muted = state.sound_muted == true
			if w._paint_sound then
				w._paint_sound()
			end
			for _, record in ipairs(section_records) do
				local saved = config.section_state(key, record.id)
				if saved ~= nil then
					record.open = saved
				else
					record.open = record.default_open == true
				end
				if record.chevron then
					record.chevron.Rotation = record.open and 180 or 0
				end
				for _, slot in ipairs(record.slots) do
					if slot.Parent then
						slot.Visible = record.tab == active_tab and record.open
					end
				end
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
		paint_sound()
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
local sounds = S.sounds
local function bold()
	return style.values.font_bold
end
local function font()
	return style.values.font
end
local function mono()
	return style.values.font_mono
end
local inputs = {}

local function values()
	return style.values
end

local function label(parent, text, y, height)
	return util.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, y or 0),
		Size = UDim2.new(1, -90, 0, height or 14),
		Font = font(),
		Text = string.upper(tostring(text or "")),
		TextColor3 = values().text,
		TextSize = util.size(10),
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
	local danger = variant == "danger" or variant == "destructive"
	local primary = not danger and variant ~= "secondary" and variant ~= "surface"
	local confirm = type(opts.confirm) == "string" and opts.confirm ~= "" and opts.confirm
		or (opts.confirm == true and "Click again to confirm" or nil)
	local function danger_ink()
		return values().bad:Lerp(Color3.new(1, 1, 1), 0.35)
	end
	local front = disabled and values().muted
		or (primary and values().accent)
		or (danger and danger_ink())
		or values().text
	local mobile = win._mobile
	local holder = win._slot(mobile and 46 or 32)
	local btn = util.new("TextButton", {
		Name = "button",
		BackgroundColor3 = values().raised,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = not disabled,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -16, 0, mobile and 36 or 24),
		Font = bold(),
		Text = string.upper(tostring(text or "Button")),
		TextColor3 = front,
		TextSize = util.size(mobile and 10 or 9),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = holder,
	})
	util.corner(btn)
	util.depth(btn, 0.8)
	util.shadow(btn, 11, 0.42)
	local edge = util.stroke(btn, values().line, 0.25)
	local held = false
	local function paint_edge()
		if disabled then
			edge.Color = values().line
			edge.Transparency = 0.25
			return
		end
		local tone = primary and values().accent or danger and values().bad
		edge.Color = tone or values().line
		edge.Transparency = tone and (held and 0.12 or 0.35) or 0.25
	end
	local emblem
	if type(icon) == "string" and icon ~= "" then
		emblem = icons.image(btn, icon, 14, front)
		if emblem then
			emblem.AnchorPoint = Vector2.new(0, 0.5)
			emblem.Position = UDim2.new(0, 10, 0.5, 0)
			icons.layer(emblem, 4)
		end
	end
	local pop = util.new("UIScale", { Parent = btn })
	local armed = false
	local arm_token = 0

	local function ink()
		if disabled then
			return values().muted
		end
		if held then
			if primary then
				return style.on(values().accent)
			end
			if danger then
				return style.on(values().bad)
			end
			return values().text
		end
		if primary then
			return values().accent
		end
		if danger then
			return danger_ink()
		end
		return values().text
	end

	local function face()
		if disabled then
			return values().raised
		end
		if held then
			if primary then
				return values().accent
			end
			if danger then
				return values().bad
			end
			return values().hover
		end
		return values().raised
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
			if sounds then
				win._play_sound("warning")
			end
			armed = true
			arm_token = arm_token + 1
			local mine = arm_token
			btn.Text = string.upper(confirm)
			task.delay(3, function()
				if btn.Parent and armed and arm_token == mine then
					armed = false
					btn.Text = string.upper(tostring(text or "Button"))
				end
			end)
			return
		end
		armed = false
		arm_token = arm_token + 1
		btn.Text = string.upper(tostring(text or "Button"))
		if sounds then
			win._play_sound("click")
		end
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
		util.tween(btn, 0.12, { BackgroundColor3 = face(), TextColor3 = ink() })
		if emblem then
			icons.tint(emblem, ink())
		end
		paint_edge()
	end)
	btn.MouseLeave:Connect(function()
		held = false
		util.tween(btn, 0.15, { BackgroundColor3 = face(), TextColor3 = ink() })
		if emblem then
			icons.tint(emblem, ink())
		end
		paint_edge()
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
			btn.Text = string.upper(tostring(text or "Button"))
			util.tween(pop, 0.1, { Scale = 1 })
		end
		if btn:GetAttribute("SpectrumDisabled") ~= disabled then
			btn:SetAttribute("SpectrumDisabled", disabled)
		end
		paint()
		paint_edge()
		if win._nav_refresh then
			win._nav_refresh()
		end
	end

	btn:SetAttribute("SpectrumDisabled", disabled)
	btn:GetAttributeChangedSignal("SpectrumDisabled"):Connect(function()
		set_disabled(btn:GetAttribute("SpectrumDisabled") == true)
	end)
	paint_edge()
	style.paint(paint)
	style.paint(paint_edge)

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
		local size = mobile and 18 or 15
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
		util.corner(box, 0)
		util.depth(box, 0.55)
		util.shadow(box, 5, 0.55)
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
		local width = mobile and 34 or 30
		local height = mobile and 16 or 14
		local thumb_size = height - 2
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
		util.corner(track, 0)
		util.inset(track, 0.65)
		util.shadow(track, 5, 0.58)
		local edge = util.stroke(track, state and values().accent or values().line, 0.25)
		local thumb = util.new("Frame", {
			Name = "switch_thumb",
			BackgroundColor3 = state and values().ink or values().muted,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, state and (width - thumb_size - 2) or 2, 0.5, 0),
			Size = UDim2.fromOffset(thumb_size, thumb_size),
			ZIndex = 4,
			Parent = track,
		})
		util.corner(thumb, 0)
		util.depth(thumb, 0.7)
		util.shadow(thumb, 4, 0.5)
		pop = util.new("UIScale", { Parent = track })

		sync = function()
			local x = state and (width - thumb_size - 2) or 2
			local accent = disabled and values().muted or values().accent
			util.tween(thumb, 0.16, {
				Position = UDim2.new(0, x, 0.5, 0),
				BackgroundColor3 = state and (disabled and values().muted or values().ink) or values().muted,
			}, Enum.EasingStyle.Quart)
			util.tween(track, 0.14, { BackgroundColor3 = state and accent or values().raised })
			edge.Color = state and accent or values().line
			edge.Transparency = 0.25
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
			if sounds then
				win._play_sound(state and "toggle_on" or "toggle_off")
			end
		end
		for _, listener in ipairs(listeners) do
			pcall(listener, state)
		end
		if S.featurelist then
			S.featurelist.touch_if(opts, true)
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
		if S.featurelist then
			S.featurelist.touch_if(opts, true)
		end
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

	if S.featurelist then
		local binder = S.featurelist.attach(win, "toggle", text, opts, function()
			if disabled then
				return nil
			end
			return state or nil
		end, true)
		if binder then
			row.Destroying:Connect(binder.Remove)
		end
	end

	return {
		Set = function(_, value, save)
			set(value, save == true)
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
	local feature_value = ""
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
		Font = mono(),
		Text = "",
		TextColor3 = values().muted,
		TextSize = util.size(9),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = row,
	})

	local track = util.new("Frame", {
		BackgroundColor3 = values().raised,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 10, 0, track_y),
		Size = UDim2.new(1, -20, 0, mobile and 4 or 3),
		ZIndex = 3,
		Parent = row,
	})
	util.corner(track, 0)
	util.inset(track, 0.68)
	util.shadow(track, 4, 0.62)

	local fill = util.new("Frame", {
		BackgroundColor3 = values().accent,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 4,
		Parent = track,
	})
	util.corner(fill, 0)

	local thumb = util.new("Frame", {
		BackgroundColor3 = values().accent,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(5, mobile and 15 or 12),
		ZIndex = 5,
		Parent = track,
	})
	util.corner(thumb, 0)
	util.depth(thumb, 0.7)
	util.shadow(thumb, 5, 0.46)

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
		feature_value = string.format("%." .. decimals .. "f", value)
		readout.TextColor3 = disabled and values().muted or (dragging and values().accent or values().muted)
		if S.featurelist then
			S.featurelist.touch_if(opts, false)
		end
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
		if sounds then
			win._play_sound("slider")
		end
		dragging = true
		win._scroll.ScrollingEnabled = false
		thumb.Size = UDim2.fromOffset(6, mobile and 16 or 13)
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
			thumb.Size = UDim2.fromOffset(5, mobile and 15 or 12)
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
			thumb.Size = UDim2.fromOffset(5, mobile and 15 or 12)
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

	if S.featurelist then
		local binder = S.featurelist.attach(win, "slider", text, opts, function()
			if disabled then
				return nil
			end
			return feature_value
		end)
		if binder then
			row.Destroying:Connect(binder.Remove)
		end
	end

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
		Size = UDim2.fromOffset(mobile and 96 or 84, mobile and 28 or 21),
		Font = mono(),
		Text = default or empty_text,
		TextColor3 = values().muted,
		TextSize = util.size(9),
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
		Parent = row,
	})
	util.corner(pill, 0)
	util.depth(pill, 0.55)
	util.shadow(pill, 6, 0.48)
	local edge = util.stroke(pill, values().line, 0.35)
	util.hover(pill)

	local key = default
	local listening = false
	local held = {}
	local stored
	local active = false
	local toggled = false
	local combo = opts.combo == true
	local capture = {}
	local ordered = {}

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
		if listening then
			if combo and #ordered > 0 then
				local parts = {}
				for _, id in ipairs(ordered) do
					parts[#parts + 1] = util.input_label(id)
				end
				pill.Text = table.concat(parts, "+")
			else
				pill.Text = "..."
			end
		else
			pill.Text = display(key)
		end
		pill.TextColor3 = tone
		pill.BackgroundColor3 = fill
		edge.Color = border
		edge.Transparency = border_alpha
		if S.featurelist then
			S.featurelist.touch_if(opts, false)
		end
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
		if sounds then
			win._play_sound(listening and "open" or "close")
		end
		S.binding = listening
		capture = {}
		ordered = {}
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
		capture = {}
		ordered = {}
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
			if combo then
				if not table.find(capture, id) then
					table.insert(capture, id)
				end
				if not table.find(ordered, id) then
					table.insert(ordered, id)
				end
				sync()
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
		if listening and combo and id then
			for index, entry in ipairs(capture) do
				if entry == id then
					table.remove(capture, index)
					break
				end
			end
			if #capture == 0 then
				if #ordered == 0 then
					sync()
					return
				end
				key = table.concat(ordered, "+")
				cancel_capture()
				win._store(stored, key)
				if on_change then
					on_change(key)
				end
				if callback then
					callback(key, true)
				end
				return
			end
			sync()
			return
		end
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

	if S.featurelist then
		local binder = S.featurelist.attach(win, "keybind", text, opts, function()
			if disabled then
				return nil
			end
			return key
		end)
		if binder then
			row.Destroying:Connect(binder.Remove)
		end
	end

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
local sounds = S.sounds
local function font()
	return style.values.font
end
local function mono()
	return style.values.font_mono
end
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
		Font = font(),
		Text = string.upper(tostring(title or "")),
		TextColor3 = values().text,
		TextSize = util.size(10),
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
	local clearable = opts.clearable ~= false
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
	local well = util.new("Frame", {
		Name = "field",
		BackgroundColor3 = values().raised,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(4, 3),
		Size = UDim2.new(1, -8, 1, -6),
		ZIndex = 2,
		Parent = row,
	})
	util.corner(well, 0)
	util.inset(well, 0.45)
	util.shadow(well, 8, 0.5)
	local field_edge = util.stroke(well, values().line, 0.55)
	local name = caption(row, title)
	name.Size = UDim2.new(0.48, -20, 1, 0)
	name.TextSize = util.size(10)
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
		Font = mono(),
		Text = placeholder,
		TextColor3 = values().muted,
		TextSize = util.size(9),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = row,
	})

	local chevron = util.chevron(row, mobile and 8 or 9, values().muted)
	chevron.AnchorPoint = Vector2.new(0.5, 0.5)
	chevron.Position = UDim2.new(1, -12, 0.5, 0)
	chevron.ZIndex = 3

	local pad = mobile and 4 or 6
	local item_h = mobile and 32 or 30
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
	util.corner(panel, 0)
	util.depth(panel, 0.7)
	local edge = util.stroke(panel, values().line, 0.05)
	util.shadow(panel, 30, 0.18)
	win._popover(panel)

	local bulk_seam
	local bulk_count
	local select_all_action
	local clear_action
	local select_all_hit
	local clear_hit
	if bulk_h > 0 then
		local actions = util.new("Frame", {
			Name = "bulk_actions",
			BackgroundColor3 = values().raised,
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(pad, pad),
			Size = UDim2.new(1, -pad * 2, 0, bulk_h),
			ZIndex = 12,
			Parent = panel,
		})
		bulk_count = util.new("TextLabel", {
			Name = "bulk_count",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(2, 0),
			Size = UDim2.new(1, mobile and -84 or -96, 1, 0),
			Font = font(),
			Text = "SELECT OPTIONS",
			TextColor3 = values().muted,
			TextSize = util.size(9),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 13,
			Parent = actions,
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
				Font = font(),
				Text = string.upper(text),
				TextColor3 = values().text,
				TextSize = util.size(mobile and 9 or 10),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 13,
				Parent = actions,
			})
			util.corner(btn, 0)
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
		clear_action, clear_hit = action("clear", "Clear", mobile and 40 or 44, 0)
		select_all_action, select_all_hit = action("select_all", "All", mobile and 26 or 30, -(mobile and 46 or 50))
	end

	local search
	local search_icon
	local search_clear
	if searchable then
		search = util.new("TextBox", {
			Name = "dropdown_search",
			BackgroundColor3 = values().raised,
			BorderSizePixel = 0,
			ClearTextOnFocus = false,
			Font = mono(),
			PlaceholderColor3 = values().muted,
			PlaceholderText = "SEARCH",
			Position = UDim2.fromOffset(pad, pad + bulk_h + bulk_gap),
			Size = UDim2.new(1, -pad * 2, 0, search_h),
			Text = "",
			TextColor3 = values().text,
			TextSize = util.size(10),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 13,
			Parent = panel,
		})
		util.corner(search, 0)
		util.inset(search, 0.58)
		util.shadow(search, 4, 0.7)
		util.new("UIPadding", {
			PaddingLeft = UDim.new(0, 24),
			PaddingRight = UDim.new(0, 22),
			Parent = search,
		})
		search_icon = icons.image(search, "search", 12, values().muted)
		if search_icon then
			search_icon.AnchorPoint = Vector2.new(0, 0.5)
			search_icon.Position = UDim2.new(0, -17, 0.5, 0)
			icons.layer(search_icon, 14)
		end
		search_clear = util.new("TextButton", {
			Name = "clear",
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 17, 0.5, 0),
			Size = UDim2.fromOffset(18, 18),
			Text = "",
			ZIndex = 14,
			Parent = search,
		})
		local clear_icon = icons.close(search_clear, 8, values().muted)
		if clear_icon then
			clear_icon.AnchorPoint = Vector2.new(0.5, 0.5)
			clear_icon.Position = UDim2.fromScale(0.5, 0.5)
			icons.layer(clear_icon, 15)
		end
		search_clear.Activated:Connect(function()
			if not disabled then
				search.Text = ""
			end
		end)
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
	local item_edges = {}
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
			local selected = (multi and picks[option]) or (not multi and single == option)
			item.BackgroundTransparency = option == active_option and 0 or (selected and 0.72 or 1)
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
		if search and search_clear then
			search_clear.Visible = search.Text ~= ""
		end
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
		local selectable = 0
		for _, option in ipairs(choices) do
			if picks[option] then
				picked = picked + 1
			end
			if not disabled_options[option] then
				selectable = selectable + 1
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
				readout.Text = string.upper(placeholder)
			elseif picked == 1 then
				readout.Text = string.upper(first_name)
			elseif picked == 2 then
				readout.Text = string.upper(first_name) .. " +1"
			else
				readout.Text = string.upper(first_name) .. " +" .. tostring(picked - 1)
			end
		else
			readout.Text = string.upper(single or placeholder)
		end
		if disabled then
			readout.TextColor3 = values().muted
		elseif (multi and picked > 0) or (not multi and single) then
			readout.TextColor3 = values().text
		else
			readout.TextColor3 = values().muted
		end
		util.font(readout, "regular")
		if bulk_count then
			if picked == 0 then
				bulk_count.Text = "SELECT OPTIONS"
				bulk_count.TextColor3 = values().muted
			elseif selectable > 0 and picked >= selectable then
				bulk_count.Text = "ALL SELECTED"
				bulk_count.TextColor3 = values().text
			else
				bulk_count.Text = tostring(picked) .. " SELECTED"
				bulk_count.TextColor3 = values().text
			end
		end
		if select_all_action then
			select_all_action.TextTransparency = picked < selectable and 0 or 0.55
			clear_action.TextTransparency = picked > 0 and 0 or 0.55
		end
		for option, item in pairs(items) do
			local on = multi and picks[option] or single == option
			local option_disabled = disabled_options[option] == true
			item.TextColor3 = option_disabled and values().muted or values().text
			util.font(item, "regular")
			item.BackgroundColor3 = on and values().hover:Lerp(values().accent, 0.12) or values().hover
			item.BackgroundTransparency = on and 0.55 or 1
			local item_edge = item_edges[option]
			if item_edge then
				item_edge.Transparency = on and 0.35 or 1
			end
			if marks[option] then
				marks[option].BackgroundColor3 = on and values().accent or values().raised
				local mark_edge = mark_edges[option]
				if mark_edge then
					mark_edge.Color = on and values().accent or values().line
					mark_edge.Transparency = on and 1 or 0.35
				end
			end
			if checks[option] then
				checks[option].Visible = on
			end
		end
		if active_option and items[active_option] then
			items[active_option].BackgroundTransparency = 0
		end
		if S.featurelist then
			S.featurelist.touch_if(opts, false)
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
		if sounds then
			win._play_sound("select")
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
			if clearable and single == option then
				single = nil
				refresh()
				set_open(false)
				win._store(key, nil)
				if callback then
					callback(nil)
				end
				return
			end
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
			if sounds then
				win._play_sound("select")
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
			if sounds then
				win._play_sound("select")
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
			if sounds then
				win._play_sound("open")
			end
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
			local width_cap = mobile and 300 or 360
			local width = math.clamp(math.min(size.X + 8, width_cap), min_width, max_width)
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
			field_edge.Color = values().accent
			field_edge.Transparency = 0.25
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
			field_edge.Color = values().line
			field_edge.Transparency = 0.55
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
			Font = font(),
			Text = string.upper(option),
			TextColor3 = values().text,
			TextSize = util.size(10),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 12,
			Parent = area,
		})
		local mark_size = 14
		local right_reserve = multi and (mark_size + 18) or 24
		item_edges[option] = util.stroke(item, values().accent, 1)
		util.new("UIPadding", {
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, right_reserve),
			Parent = item,
		})
		item.MouseEnter:Connect(function()
			if not disabled then
				item.BackgroundTransparency = 0
			end
		end)
		item.MouseLeave:Connect(refresh)
		item.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch and not disabled then
				item.BackgroundTransparency = 0
			end
		end)
		item.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				refresh()
			end
		end)
		local check
		if multi then
			local mark = util.new("Frame", {
				Name = "mark",
				BackgroundColor3 = values().raised,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, right_reserve - 10, 0.5, 0),
				Size = UDim2.fromOffset(mark_size, mark_size),
				ZIndex = 13,
				Parent = item,
			})
			util.corner(mark, 0)
			util.depth(mark, 0.55)
			util.shadow(mark, 4, 0.52)
			mark_edges[option] = util.stroke(mark, values().line, 0.35)
			check = icons.check(mark, mark_size - 4, style.on(values().accent))
			check.AnchorPoint = Vector2.new(0.5, 0.5)
			check.Position = UDim2.fromScale(0.5, 0.5)
			icons.layer(check, 4)
			marks[option] = mark
		else
			check = icons.check(item, 10, values().accent)
			check.AnchorPoint = Vector2.new(1, 0.5)
			check.Position = UDim2.new(1, right_reserve - 10, 0.5, 0)
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
			Font = font(),
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
			Font = font(),
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
			if search_icon then
				icons.tint(search_icon, values().muted)
			end
			if search_clear then
				for _, child in ipairs(search_clear:GetDescendants()) do
					if child:IsA("Frame") then
						child.BackgroundColor3 = values().muted
					end
				end
			end
		end
		well.BackgroundColor3 = values().raised
		field_edge.Color = open and values().accent or values().line
		if emblem then
			icons.tint(emblem, disabled and values().line or values().muted)
		end
		if bulk_count then
			bulk_count.Parent.BackgroundColor3 = values().raised
		end
		if bulk_seam then
			bulk_seam.BackgroundColor3 = values().line
		end
		if select_all_action then
			select_all_action.BackgroundColor3 = values().hover
			select_all_action.TextColor3 = values().text
			clear_action.BackgroundColor3 = values().hover
			clear_action.TextColor3 = values().text
		end
		for option, item in pairs(items) do
			item.BackgroundColor3 = values().hover
			if item_edges[option] then
				item_edges[option].Color = values().accent
			end
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

	if S.featurelist then
		local binder = S.featurelist.attach(win, "dropdown", title, opts, function()
			if disabled then
				return nil
			end
			if multi then
				local picked = current()
				if #picked == 0 then
					return nil
				end
				return table.concat(picked, ", ")
			end
			return single
		end)
		if binder then
			row.Destroying:Connect(binder.Remove)
		end
	end

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
	util.corner(swatch, 0)
	util.stroke(swatch, Color3.new(1, 1, 1), 0.7)

	local pad = 8
	local field_h = mobile and 100 or 94
	local panel_w = mobile and 240 or 226
	local bottom_y = pad + field_h + 29
	local rgb_h = 24
	local rgb_y = bottom_y + 34
	local swatch_size = mobile and 18 or 16
	local swatch_step = swatch_size + 6
	local swatch_y = rgb_y + rgb_h + 8
	local panel_h = swatch_y + preset_rows * 24 + 4

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
	util.corner(panel, 0)
	util.depth(panel, 0.7)
	local edge = util.stroke(panel, values().line, 0.05)
	util.shadow(panel, 30, 0.18)
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
	util.corner(field, 0)
	util.inset(field, 0.52)
	util.stroke(field, values().line, 0.45)

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
	util.corner(light, 0)

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
	util.corner(dark, 0)

	local cursor = util.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(mobile and 15 or 13, mobile and 15 or 13),
		ZIndex = 6,
		Parent = field,
	})
	util.corner(cursor, 0)
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
	util.corner(hue_bar, 0)
	for index = 0, 95 do
		util.new("Frame", {
			BackgroundColor3 = Color3.fromHSV(index / 96, 1, 1),
			BorderSizePixel = 0,
			Active = false,
			Position = UDim2.fromScale(index / 96, 0),
			Size = UDim2.new(1 / 96 + 0.002, 0, 1, 0),
			ZIndex = 3,
			Parent = hue_bar,
		})
	end
	util.stroke(hue_bar, values().line, 0.55)

	local knob = util.new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(4, 18),
		ZIndex = 4,
		Parent = hue_bar,
	})
	util.corner(knob, 0)

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
	util.corner(preview, 0)
	util.depth(preview, 0.65)
	util.stroke(preview, values().line, 0.2)
	util.shadow(preview, 8, 0.45)

	local hex = util.new("TextBox", {
		BackgroundColor3 = values().raised,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		TextEditable = not disabled,
		Font = mono(),
		Position = UDim2.fromOffset(pad + 36, bottom_y),
		Size = UDim2.new(1, -(pad * 2 + 36 + 2 * 28 + 8), 0, 28),
		Text = "#000000",
		TextColor3 = values().text,
		TextSize = util.size(11),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		Parent = panel,
	})
	util.corner(hex, 0)
	util.inset(hex, 0.55)
	local hex_edge = util.stroke(hex, values().line, 0.2)
	util.new("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 6),
		Parent = hex,
	})

	local function small_action(name, icon_name, x, tip)
		local btn = util.new("TextButton", {
			Name = name,
			BackgroundColor3 = values().raised,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Active = not disabled,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, x, 0, bottom_y),
			Size = UDim2.fromOffset(28, 28),
			Text = "",
			ZIndex = 3,
			Parent = panel,
		})
		util.corner(btn, 0)
		util.depth(btn, 0.55)
		util.shadow(btn, 5, 0.55)
		local stroke = util.stroke(btn, values().line, 0.3)
		local image = icons.image(btn, icon_name, 13, values().muted)
		if image then
			image.AnchorPoint = Vector2.new(0.5, 0.5)
			image.Position = UDim2.fromScale(0.5, 0.5)
			icons.layer(image, 4)
		end
		btn.MouseEnter:Connect(function()
			if btn.Active then
				util.tween(btn, 0.08, { BackgroundColor3 = values().hover })
			end
		end)
		btn.MouseLeave:Connect(function()
			util.tween(btn, 0.08, { BackgroundColor3 = values().raised })
		end)
		if tooltip and tip then
			tooltip.attach(btn, tip)
		end
		return btn, stroke, image
	end

	local copy_btn, copy_edge, copy_icon = small_action("copy_hex", "copy", -(pad + 28 + 4), "Copy the hex value")
	local random_btn, random_edge, random_icon = small_action("random_color", "refresh", -pad, "Pick a random color")

	local rgb_label = util.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(pad, rgb_y),
		Size = UDim2.fromOffset(30, rgb_h),
		Font = mono(),
		Text = "RGB",
		TextColor3 = values().muted,
		TextSize = util.size(8),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		Parent = panel,
	})
	local rgb = util.new("TextBox", {
		BackgroundColor3 = values().raised,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		TextEditable = not disabled,
		Font = mono(),
		Position = UDim2.fromOffset(pad + 30, rgb_y),
		Size = UDim2.new(1, -(pad * 2 + 30), 0, rgb_h),
		Text = "230, 162, 58",
		PlaceholderText = "R, G, B",
		PlaceholderColor3 = values().muted,
		TextColor3 = values().text,
		TextSize = util.size(9),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		Parent = panel,
	})
	util.corner(rgb, 0)
	util.inset(rgb, 0.55)
	local rgb_edge = util.stroke(rgb, values().line, 0.3)
	util.new("UIPadding", {
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		Parent = rgb,
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
			Position = UDim2.fromOffset(pad, swatch_y + (index - 1) * 24),
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
			util.corner(swatch, 0)
			util.depth(swatch, 0.2)
			util.stroke(swatch, values().line, 0.2)
			swatch.Activated:Connect(function()
				if disabled then
					return
				end
				if sounds then
					win._play_sound("select")
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
			util.corner(slot, 0)
			util.depth(slot, 0.2)
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
				if sounds then
					win._play_sound("select")
				end
				hue, sat, val = Color3.toHSV(Color3.fromHex("#" .. value))
				refresh(true)
				set_open(false)
			end)
		end
	end
	function refresh(fire)
		local picked = color()
		cursor.Position = UDim2.fromScale(sat, 1 - val)
		knob.Position = UDim2.new(hue, 0, 0.5, 0)
		field.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
		preview.BackgroundColor3 = picked
		swatch.BackgroundColor3 = picked
		if not hex:IsFocused() then
			hex.Text = "#" .. string.upper(picked:ToHex())
		end
		if not rgb:IsFocused() then
			local r = math.floor(picked.R * 255 + 0.5)
			local g = math.floor(picked.G * 255 + 0.5)
			local b = math.floor(picked.B * 255 + 0.5)
			rgb.Text = string.format("%d, %d, %d", r, g, b)
		end
		if fire then
			win._store(key, "#" .. string.upper(picked:ToHex()))
			if callback then
				callback(picked)
			end
		end
		if S.featurelist then
			S.featurelist.touch_if(opts, false)
		end
	end

	local function commit_rgb()
		local parts = {}
		for value in string.gmatch(rgb.Text, "%-?%d+") do
			parts[#parts + 1] = tonumber(value)
		end
		if #parts < 3 then
			refresh(false)
			return
		end
		local r = math.clamp(parts[1] or 0, 0, 255)
		local g = math.clamp(parts[2] or 0, 0, 255)
		local b = math.clamp(parts[3] or 0, 0, 255)
		hue, sat, val = Color3.toHSV(Color3.fromRGB(r, g, b))
		refresh(true)
		add_recent(color())
	end

	rgb.Focused:Connect(function()
		rgb_edge.Color = values().accent
		rgb_edge.Transparency = 0.15
	end)
	rgb.FocusLost:Connect(function()
		rgb_edge.Color = values().line
		rgb_edge.Transparency = 0.3
		if not disabled then
			commit_rgb()
		end
	end)

	copy_btn.Activated:Connect(function()
		if disabled or type(setclipboard) ~= "function" then
			return
		end
		pcall(function()
			setclipboard(hex.Text)
		end)
		if S.notify then
			S.notify("Color", "Copied " .. hex.Text, 1.5, "good")
		end
	end)

	random_btn.Activated:Connect(function()
		if disabled then
			return
		end
		if sounds then
			win._play_sound("select")
		end
		hue = math.random()
		sat = 0.45 + math.random() * 0.55
		val = 0.65 + math.random() * 0.35
		refresh(true)
		add_recent(color())
	end)

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
			if sounds then
				win._play_sound("open")
			end
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
		rgb.TextEditable = not disabled
		rgb.Active = not disabled
		copy_btn.Active = not disabled
		random_btn.Active = not disabled
		if disabled then
			set_open(false)
			field_drag = false
			hue_drag = false
			if hex:IsFocused() then
				hex:ReleaseFocus()
			end
		end
		hex.TextColor3 = disabled and values().muted or values().text
		rgb.TextColor3 = disabled and values().muted or values().text
		name.TextColor3 = disabled and values().muted or values().text
		if emblem then
			icons.tint(emblem, disabled and values().line or values().muted)
		end
		if copy_icon then
			icons.tint(copy_icon, disabled and values().line or values().muted)
		end
		if random_icon then
			icons.tint(random_icon, disabled and values().line or values().muted)
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
		rgb.BackgroundColor3 = values().raised
		rgb.TextColor3 = disabled and values().muted or values().text
		rgb.PlaceholderColor3 = values().muted
		rgb_edge.Color = values().line
		rgb_label.TextColor3 = values().muted
		copy_btn.BackgroundColor3 = values().raised
		copy_edge.Color = values().line
		random_btn.BackgroundColor3 = values().raised
		random_edge.Color = values().line
		if copy_icon then
			icons.tint(copy_icon, disabled and values().line or values().muted)
		end
		if random_icon then
			icons.tint(random_icon, disabled and values().line or values().muted)
		end
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

	if S.featurelist then
		local binder = S.featurelist.attach(win, "colorpicker", title, opts, function()
			if disabled then
				return nil
			end
			return "#" .. string.upper(color():ToHex())
		end)
		if binder then
			row.Destroying:Connect(binder.Remove)
		end
	end

	return {
		Set = function(_, value, save)
			apply(value)
			if save then
				win._store(key, "#" .. string.upper(color():ToHex()))
				if callback then
					callback(color())
				end
			end
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
local sounds = S.sounds
local function bold()
	return style.values.font_bold
end
local function font()
	return style.values.font
end
local function mono()
	return style.values.font_mono
end
local text = {}

local function values()
	return style.values
end

local function label(parent, title)
	return util.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -90, 0, 14),
		Font = font(),
		Text = string.upper(tostring(title or "")),
		TextColor3 = values().text,
		TextSize = util.size(10),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = parent,
	})
end

function text.section(win, title, icon, opts)
	if type(icon) == "table" then
		opts = icon
		icon = opts.icon
	end
	opts = type(opts) == "table" and opts or {}
	if icon == nil then
		icon = opts.icon
	end
	icon = type(icon) == "string" and icon ~= "" and icon or nil
	local height = win._mobile and 34 or 26
	local holder = win._slot(height, true)
	local record = win._new_section(opts.open == true, title, opts.id)
	local band = util.new("Frame", {
		BackgroundColor3 = values().raised,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = holder,
	})
	util.depth(band, 0.55)
	local tick = util.new("Frame", {
		BackgroundColor3 = values().accent,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, height / 2 - 6),
		Size = UDim2.fromOffset(2, 12),
		ZIndex = 3,
		Parent = band,
	})
	local top = util.new("Frame", {
		BackgroundColor3 = values().line,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, 0, 0, 1),
		ZIndex = 3,
		Parent = band,
	})
	local caption = util.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 0),
		Size = UDim2.new(1, -44, 1, 0),
		Font = bold(),
		Text = string.upper(tostring(title or "Section")),
		TextColor3 = values().text,
		TextSize = util.size(9),
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
	chevron.Rotation = record.open and 180 or 0
	record.chevron = chevron

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
		util.tween(band, 0.1, { BackgroundColor3 = on and values().hover or values().raised })
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
		if animate and sounds then
			win._play_sound(state and "open" or "close")
		end
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
		band.BackgroundColor3 = hovered and values().hover or values().raised
		tick.BackgroundColor3 = values().accent
		caption.TextColor3 = values().text
		top.BackgroundColor3 = values().line
		bottom.BackgroundColor3 = values().line
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
		Font = font(),
		Text = tostring(body or ""),
		TextColor3 = values().muted,
		TextSize = util.size(9),
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
			Font = mono(),
			PlaceholderColor3 = values().muted,
			PlaceholderText = placeholder,
			Position = UDim2.new(0, 10, 0, 27),
			Size = UDim2.new(1, -20, 0, 26),
			Text = tostring(default or ""),
			TextColor3 = values().text,
			TextSize = util.size(10),
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
			Font = mono(),
			PlaceholderColor3 = values().muted,
			PlaceholderText = placeholder,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.new(0.52, 0, 0, 21),
			Text = tostring(default or ""),
			TextColor3 = values().text,
			TextSize = util.size(10),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 3,
			Parent = row,
		})
	end
	util.corner(box)
	util.inset(box, 0.62)
	util.shadow(box, 8, 0.52)
	util.new("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = box,
	})
	local edge = util.stroke(box, values().line, 0.15)
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
	if S.featurelist then
		box:GetPropertyChangedSignal("Text"):Connect(function()
			S.featurelist.touch_if(opts, false)
		end)
	end

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
		if S.featurelist then
			S.featurelist.touch_if(opts, false)
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

	if S.featurelist then
		local binder = S.featurelist.attach(win, "textbox", title, opts, function()
			if disabled then
				return nil
			end
			local value = box.Text
			if value == "" then
				return nil
			end
			return value
		end)
		if binder then
			row.Destroying:Connect(binder.Remove)
		end
	end

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
Library.Version = "1.0"
Library.Build = "1.2.1"

local previous = shared.Spectrum
if type(previous) == "table" and previous ~= Library and type(previous.Destroy) == "function" then
	pcall(previous.Destroy, previous)
end

config.load()
if S.sounds and S.sounds.restore then
	S.sounds.restore()
end
if S.featurelist and S.featurelist.restore then
	S.featurelist.restore()
end
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
local destroyed = false
local close_link

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
	local was_open = menu_open
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
	if S.sounds and was_open ~= menu_open then
		S.sounds.play(menu_open and "open" or "close")
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

function Library:SetFont(name)
	return S.style.set_font(name)
end

function Library:GetFont()
	return S.style.font_key()
end

function Library:GetFonts()
	return S.style.font_list()
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

function Library:SetSoundsEnabled(state)
	return S.sounds.set_enabled(state)
end

function Library:GetSoundsEnabled()
	return S.sounds.get_enabled()
end

function Library:SetSoundVolume(value)
	return S.sounds.set_volume(value)
end

function Library:GetSoundVolume()
	return S.sounds.get_volume()
end

function Library:PlaySound(name)
	return S.sounds.play(name)
end

function Library:OnSoundsChanged(callback)
	return S.sounds.watch(callback)
end

function Library:SetBackground(asset, opts, callback)
	return S.background.set(asset, opts, callback)
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

function Library:SetFeatureList(lines)
	return S.featurelist.set(lines)
end

function Library:SetFeatureListVisible(state)
	return S.featurelist.visible(state)
end

function Library:GetFeatureList()
	return S.featurelist.get()
end

function Library:SetFeatureListAll(state)
	return S.featurelist.all(state)
end

function Library:GetFeatureListAll()
	return S.featurelist.all()
end

function Library:SetFeatureListRGB(state)
	return S.featurelist.rgb(state)
end

function Library:GetFeatureListRGB()
	return S.featurelist.rgb()
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

function Library:IsMobile()
	return env.mobile == true
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

function Library:GetConfigError()
	return config.last_error()
end

function Library:GetConfigPath()
	return config.file()
end

function Library:LoadConfig(name)
	config.load(name)
	if S.sounds and S.sounds.restore then
		S.sounds.restore()
	end
	if S.featurelist and S.featurelist.restore then
		S.featurelist.restore()
	end
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
	if destroyed then
		return
	end
	destroyed = true
	config.flush()
	if type(config.cancel) == "function" then
		config.cancel()
	end
	S.binding = false
	if menu_link then
		menu_link:Disconnect()
		menu_link = nil
	end
	if menu_release then
		menu_release:Disconnect()
		menu_release = nil
	end
	if S.tooltip then
		pcall(function()
			if S.tooltip.destroy then
				S.tooltip.destroy()
			else
				S.tooltip.hide()
			end
		end)
	end
	S.splash_open = false
	if splash and splash.destroy then
		pcall(splash.destroy)
		splash = nil
	end
	if mobile_launcher then
		pcall(mobile_launcher.destroy)
		mobile_launcher = nil
	end
	if S.modal then
		pcall(S.modal.dismiss)
	end
	if S.sounds and S.sounds.destroy then
		pcall(S.sounds.destroy)
	end
	if S.options then
		if type(S.options.destroy) == "function" then
			pcall(S.options.destroy)
		elseif type(S.options.close) == "function" then
			pcall(S.options.close)
		end
	end
	local roots = S.window and table.clone(S.window.roots) or {}
	if S.window then
		table.clear(S.window.roots)
		table.clear(S.window.windows)
	end
	for _, root in ipairs(roots) do
		pcall(function()
			if root.Parent then
				root:Destroy()
			end
		end)
	end
	if S.env then
		for _, layer in ipairs({ S.env.windows, S.env.modal, S.env.notes, S.env.launcher, S.env.splash }) do
			if layer then
				pcall(function()
					layer:Destroy()
				end)
			end
		end
		if type(S.env.sweep_layers) == "function" then
			pcall(S.env.sweep_layers)
		end
	end
	if close_link then
		pcall(function()
			close_link:Disconnect()
		end)
		close_link = nil
	end
	if shared.Spectrum == Library then
		shared.Spectrum = nil
	end
end

pcall(function()
	close_link = game:BindToClose(function()
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
