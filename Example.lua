--[[ spectrum example ]]--
local SOURCE = "https://raw.githubusercontent.com/YellowGregs/Spectrum/refs/heads/main/Spectrum.lua"

local request_ok, body = pcall(function()
	return game:HttpGet(SOURCE, true)
end)
if not request_ok or type(body) ~= "string" or body == "" or body == "404: Not Found" then
	error("[example] couldnt download Spectrum.lua: " .. tostring(body), 0)
end

local chunk, problem = loadstring(body, "Spectrum")
if not chunk then
	error("[example] couldnt compile Spectrum.lua: " .. tostring(problem), 0)
end

local run_ok, Library = pcall(chunk)
if not run_ok then
	error("[example] spectrum failed to load: " .. tostring(Library), 0)
end
Library = Library or shared.Spectrum
if type(Library) ~= "table" or type(Library.Window) ~= "function" then
	error("[example] spectrum returned no Library.", 0)
end
local function log(...)
	print("[example]", ...)
end

-- Window
local main = Library:Window("Spectrum Example", { icon = "sliders" })
local settings = Library:Window("Settings", { icon = "gear" })

-- section: a group row under a header
main:section("Basics", "sliders")

-- label: plain text
main:label("Here's a quick tour. Swap in your own callbacks when you're ready.")

-- button: runs its callback when clicked
main:button("Say hello", function()
	log("Hello from Spectrum.")
end, "arrow")

-- toggle: on/off switch
main:toggle("Enable feature", false, function(state)
	log("Feature:", state)
end, { icon = "check" })

-- slider: returns the current number
main:slider("Speed", 1, 100, 16, function(value)
	log("Speed:", value)
end, 1, "speed")

-- dropdown: returns the selected option
main:dropdown("Mode", { "Simple", "Compact", "Detailed" }, "Simple", function(picked)
	log("Mode:", picked)
end, false, "sliders")

-- textbox: returns the text you type
main:textbox("Name", "", function(text)
	log("Name:", text)
end, "user")

-- keybinds: captures a key, mouse button, or gamepad button
main:keybind("Action key", "F", function(key, pressed)
	log("Action key:", key, pressed)
end, "key")

-- multi dropdown: returns a list of selected options
main:section("Lists", "target")
main:dropdown("Channels", { "Alpha", "Bravo", "Charlie" }, { "Alpha" }, function(picks)
	log("Channels:", table.concat(picks, ", ")) end, true, "target", {
	searchable = true,
	placeholder = "Pick a few",
	disabledOptions = { "Charlie" },
})

-- colorpicker: returns a Color3.
settings:section("Appearance", "palette")
settings:label("Changes show up right away.")

local defaults = Library:GetDesign()
local accent = settings:colorpicker("Accent", defaults.accent, function(color)
	Library:Design({ accent = color })
end, "palette")
Library:Design({ accent = accent:Get() })

-- toggle corner radius
local compact = settings:toggle("Compact corners", false, function(state)
	Library:Design({ radius = state and 2 or 4 })
end, { icon = "sliders" })

-- just resets the theme and sync its controls
settings:button("Reset theme", function()
	Library:Design(defaults)
	accent:Set(defaults.accent)
	compact:Set(false)
	Library:Notify("Spectrum", "Theme reset.", 2, "info")
end, "refresh")

-- separator: a thin divider.
settings:separator()
settings:label("Disabled controls keep their value, but their callback won't run.")

-- disabled button: visible, but it won't run its callback, and idk why i added this
local locked = settings:button("Locked action", function()
	log("This should not run while the button is disabled.")
end, "lock", { disabled = true })

-- turns that disabled state on and off from code, this one too idk why i added this
settings:button("Toggle locked action", function()
	Library:SetDisabled(locked, not Library:GetDisabled(locked))
end, "lock")

-- close: unloads the library and its interface
settings:button("Close Spectrum", function()
	Library:Destroy()
end, "trash")

Library:Notify("Spectrum", "all set try something", 3, "good")
