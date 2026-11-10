local S = ...

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
