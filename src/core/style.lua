local S = ...

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
	local layers = { env and env.windows, env and env.notes, env and env.overlay, env and env.modal, env and env.launcher, env and env.splash }
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
