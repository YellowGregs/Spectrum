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

main:section("Basics", "sliders") -- section: a group row under a header

main:label("Here is a quick tour, just swap in your own callbacks when you are ready") -- label: plain text

main:button("Say hello", function() -- button: runs its callback when clicked
	log("Hello from Spectrum.")
end, "arrow")

main:toggle("Enable feature", false, function(state) -- toggle: on/off switch
	log("Feature:", state)
end, { icon = "check" })

main:slider("Speed", 1, 100, 16, function(value) -- slider: returns the current number
	log("Speed:", value)
end, 1, "speed")

main:dropdown("Mode", { "Simple", "Compact", "Detailed" }, "Simple", function(picked) -- dropdown: returns the selected option
	log("Mode:", picked)
end, false, "sliders")

main:textbox("Name", "", function(text) -- textbox: returns the text you type
	log("Name:", text)
end, "user")

main:keybind("Action key", "F", function(key, pressed) -- keybinds: captures a key, mouse button, or gamepad button
	log("Action key:", key, pressed)
end, "key")

main:section("Lists", "target") -- multi dropdown: returns a list of selected options
main:dropdown("Channels", { "Alpha", "Bravo", "Charlie" }, { "Alpha" }, function(picks)
	log("Channels:", table.concat(picks, ", ")) end, true, "target", {
	searchable = true,
	placeholder = "Pick a few",
	disabledOptions = { "Charlie" },
})

-- colorpicker: returns a Color3.
settings:section("Appearance", "palette")
settings:label("Changes show up right away")

local defaults = Library:GetDesign()
local accent = settings:colorpicker("Accent", defaults.accent, function(color)
	Library:Design({ accent = color })
end, "palette")
Library:Design({ accent = accent:Get() })

local compact = settings:toggle("Compact corners", false, function(state) -- toggle corner radius
	Library:Design({ radius = state and 2 or 4 })
end, { icon = "sliders" })

settings:button("Reset theme", function() -- just resets the theme and sync its controls
	Library:Design(defaults)
	accent:Set(defaults.accent)
	compact:Set(false)
	Library:Notify("Spectrum", "Theme reset.", 2, "info")
end, "refresh")


settings:separator() -- separator: a thin divider.
settings:label("disabled controls keep their value, but their callback won't run.")

local locked = settings:button("Locked action", function()-- disabled button: visible, but it won't run its callback
	log("This should not run while the button is disabled.")
end, "lock", { disabled = true })

settings:button("Toggle locked action", function() -- turns that disabled state on and off from code
	Library:SetDisabled(locked, not Library:GetDisabled(locked))
end, "lock")

settings:button("Close Spectrum", function() -- close: unloads the library and its interface
	Library:Destroy()
end, "trash")

Library:Notify("Spectrum", "all set try something", 3, "good")
