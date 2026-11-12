local S = ...

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

function Library:Window(title, opts)
	local win = S.window.new(title, opts)
	win.Gui.Visible = menu_open

	win.button = function(self, text, callback, icon, opts)
		return S.inputs.button(self, text, callback, icon, opts)
	end
	win.toggle = function(self, text, a, b, opts)
		return S.inputs.toggle(self, text, a, b, opts)
	end
	win.slider = function(self, text, min, max, default, callback, step, icon, opts)
		return S.inputs.slider(self, text, min, max, default, callback, step, icon, opts)
	end
	win.keybind = function(self, text, default, callback, icon, opts)
		return S.inputs.keybind(self, text, default, callback, icon, opts)
	end
	win.dropdown = function(self, text, options, default, callback, multi, icon, opts)
		return S.selects.dropdown(self, text, options, default, callback, multi, icon, opts)
	end
	win.colorpicker = function(self, text, default, callback, icon, opts)
		return S.selects.colorpicker(self, text, default, callback, icon, opts)
	end
	win.textbox = function(self, text, default, callback, icon, opts)
		return S.text.textbox(self, text, default, callback, icon, opts)
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
