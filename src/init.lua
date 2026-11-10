local S = ...

local env = S.env
local config = S.config
local Library = {}
Library.Version = "3.1"

config.load()
local menuKey = config.toggleKey() or "RightShift"
local menuOpen = true

local function setMenu(state)
	menuOpen = state ~= false
	for _, root in ipairs(S.window.roots) do
		if root.Parent then
			root.Visible = menuOpen
		end
	end
	if not menuOpen then
		S.modal.dismiss()
	end
	return menuOpen
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
	win.Gui.Visible = menuOpen

	win.button = function(self, text, callback, icon)
		return S.inputs.button(self, text, callback, icon)
	end
	win.toggle = function(self, text, a, b)
		return S.inputs.toggle(self, text, a, b)
	end
	win.slider = function(self, text, min, max, default, callback, step)
		return S.inputs.slider(self, text, min, max, default, callback, step)
	end
	win.keybind = function(self, text, default, callback)
		return S.inputs.keybind(self, text, default, callback)
	end
	win.dropdown = function(self, text, options, default, callback, multi)
		return S.selects.dropdown(self, text, options, default, callback, multi)
	end
	win.colorpicker = function(self, text, default, callback)
		return S.selects.colorpicker(self, text, default, callback)
	end
	win.textbox = function(self, text, default, callback)
		return S.text.textbox(self, text, default, callback)
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
		state = not menuOpen
	end
	return setMenu(state)
end

function Library:SetToggleKey(key)
	menuKey = tostring(key or "RightShift")
	config.toggleKey(menuKey)
	S.notify("Spectrum", "Menu key set to " .. menuKey, 2, "info")
end

function Library:GetToggleKey()
	return menuKey
end

function Library:SaveConfig(name)
	return config.save(name)
end

function Library:LoadConfig(name)
	config.load(name)
	local saved = config.toggleKey()
	if saved then
		menuKey = saved
	end
	return true
end

function Library:SetProfile(name)
	return Library:LoadConfig(name)
end

function Library:GetProfile()
	return config.profile()
end

local menuLink = env.uis.InputBegan:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	if S.binding then
		return
	end
	if input.KeyCode.Name ~= menuKey then
		return
	end
	local focused
	pcall(function()
		focused = env.uis:GetFocusedTextBox()
	end)
	if focused then
		return
	end
	Library:ToggleUI()
end)

function Library:Destroy()
	config.flush()
	if menuLink then
		menuLink:Disconnect()
		menuLink = nil
	end
	for _, root in ipairs(S.window.roots) do
		if root.Parent then
			root:Destroy()
		end
	end
	S.env.windows:Destroy()
	S.env.modal:Destroy()
	S.env.notes:Destroy()
	if shared.Spectrum == Library then
		shared.Spectrum = nil
	end
end

pcall(function()
	game:BindToClose(function()
		config.flush()
	end)
end)

task.defer(function()
	S.notify("Spectrum", "Press " .. menuKey .. " to toggle the menu.", 3.5, "info")
end)

S.library = Library
