local SOURCE = "https://raw.githubusercontent.com/YellowGregs/Spectrum/refs/heads/main/Spectrum.lua"

local body
local remote_url = SOURCE .. "?v=" .. tostring(os.time()) .. tostring(math.random(100000, 999999))
local request_ok, remote_body = pcall(function()
	return game:HttpGet(remote_url, true)
end)

if request_ok and type(remote_body) == "string" and remote_body ~= "" and remote_body ~= "404: Not Found" then
	body = remote_body
end

if not body and type(readfile) == "function" and type(isfile) == "function" and isfile("Spectrum.lua") then
	local local_ok, local_body = pcall(readfile, "Spectrum.lua")
	if local_ok and type(local_body) == "string" and local_body ~= "" then
		body = local_body
	end
end

if not body then
	error("[Spectrum] Failed to load Spectrum.lua: " .. tostring(remote_body), 0)
end

local chunk, problem = loadstring(body, "Spectrum")
if not chunk then
	error("[Spectrum] Failed to compile Spectrum.lua: " .. tostring(problem), 0)
end

local run_ok, Library = pcall(chunk)
if not run_ok then
	error("[Spectrum] Failed to initialize: " .. tostring(Library), 0)
end

Library = Library or shared.Spectrum
if type(Library) ~= "table" or type(Library.Window) ~= "function" then
	error("[Spectrum] Library was not returned correctly.", 0)
end

local function log(...)
	print("[Spectrum]", ...)
end

local main = Library:Window("Spectrum", { icon = "sliders" })

local basics = main:Tab("Basics", {
	icon = "sliders",
	tooltip = "Basic controls",
	open = { "Basics" },
})

basics:section("Basics", "sliders")

basics:label("A few examples of what you can do with Spectrum.")

basics:button("Say hello", function()
	log("Hello!")
end, "arrow", { tooltip = "Prints a message to the console." })

basics:button("Secondary action", function()
	log("Secondary action ran.")
end, "save", { variant = "secondary", tooltip = "Another button style." })

basics:button("Danger action", function()
	log("Danger action ran.")
end, "trash", {
	variant = "danger",
	confirm = "Click again to confirm",
	tooltip = "Requires a second click.",
})

basics:toggle("Enable feature", false, function(state)
	log("Feature:", state)
end, { icon = "check", tooltip = "Turn the feature on or off." })

basics:slider("Speed", 1, 100, 16, function(value)
	log("Speed:", value)
end, 1, "speed", { suffix = " studs", tooltip = "Change the speed." })

basics:dropdown("Mode", { "Simple", "Compact", "Detailed" }, "Simple", function(picked)
	log("Mode:", picked)
end, false, "sliders", { tooltip = "Choose a mode." })

basics:textbox("Name", "", function(text)
	log("Name:", text)
end, "user", { placeholder = "Enter a name", maxLength = 24, tooltip = "Up to 24 characters." })

basics:textbox("Amount", "10", function(text)
	log("Amount:", text)
end, "code", { numericOnly = true, placeholder = "0", tooltip = "Numbers only." })

local keybinds_section = basics:section("Keybinds", "key")
basics:label("Click a keybind to change it. Hold and Toggle modes are also supported.")

basics:button("Toggle section", function()
	keybinds_section:Toggle()
end, "key", { variant = "secondary", tooltip = "Opens or closes the keybind section." })

local boost = basics:toggle("Boost", false, function(state)
	log("Boost:", state)
end, { icon = "bolt", tooltip = "Controlled by the keybind below." })

basics:keybind("Boost key", "G", nil, "bolt", {
	mode = "toggle",
	syncToggle = boost,
	tooltip = "Press to toggle Boost.",
})

basics:keybind("Hold to log", "LeftShift", nil, "key", {
	mode = "hold",
	tooltip = "Logs while the key is held.",
	onPress = function(state)
		log("Held:", state)
	end,
	onRelease = function()
		log("Released")
	end,
})

local lists = main:Tab("Lists", {
	icon = "inventory",
	tooltip = "Dropdown examples",
	open = { "Lists" },
})

lists:section("Lists", "target")

lists:dropdown("Channels", { "Alpha", "Bravo", "Charlie" }, { "Alpha" }, function(picks)
	log("Channels:", table.concat(picks, ", "))
end, true, "target", {
	searchable = true,
	placeholder = "Select channels",
	disabledOptions = { "Charlie" },
	tooltip = "Select multiple channels.",
})

local second = Library:Window("Player", { icon = "user" })

local player_tab = second:Tab("Player", {
	icon = "user",
	tooltip = "Player settings",
	open = { "Movement" },
})

player_tab:section("Movement", "activity")

player_tab:label("Player movement settings.")

player_tab:toggle("Walk speed", false, function(state)
	local character = game.Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if humanoid then
		humanoid.WalkSpeed = state and 32 or 16
	end
end, { icon = "zap", tooltip = "Change your walking speed." })

player_tab:slider("Jump power", 0, 150, 50, function(value)
	local character = game.Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if humanoid then
		humanoid.UseJumpPower = true
		humanoid.JumpPower = value
	end
end, 1, "arrow-up", { tooltip = "Adjust jump power." })

player_tab:section("Other", "settings")

player_tab:button("Reset movement", function()
	local character = game.Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if humanoid then
		humanoid.WalkSpeed = 16
		humanoid.UseJumpPower = true
		humanoid.JumpPower = 50
	end

	Library:Notify("Player", "Movement reset.", 2, "good")
end, "refresh", { tooltip = "Restore default movement values." })

local settings_window = Library:Window("Settings", { icon = "gear" })

local settings = settings_window:Tab("Settings", {
	icon = "gear",
	tooltip = "Interface settings",
	open = { "Appearance", "Config" },
})

settings:section("Appearance", "palette")
settings:label("Customize the look of the interface.")

local defaults = Library:GetDesign()

local accent = settings:colorpicker("Accent color", defaults.accent, function(color)
	Library:Design({ accent = color })
end, "palette", {
	presets = {
		Color3.fromRGB(230, 162, 58),
		Color3.fromRGB(197, 84, 54),
		Color3.fromRGB(214, 72, 66),
		Color3.fromRGB(105, 146, 170),
	},
	recent = true,
	tooltip = "Choose an accent color.",
})

Library:Design({ accent = accent:Get() })

local compact = settings:toggle("Square corners", true, function(state)
	Library:Design({ radius = state and 0 or 3 })
end, { icon = "sliders", tooltip = "Change the corner style." })

settings:button("Reset theme", function()
	Library:Design(defaults)
	accent:Set(defaults.accent, true)
	compact:Set(true, true)
	Library:Notify("Spectrum", "Theme reset.", 2, "info")
end, "refresh", { tooltip = "Restore the default appearance." })

settings:section("Background", "render")
settings:label("Add an image behind the interface.")

local image = settings:textbox("Image ID", "", nil, "render", {
	placeholder = "Image or Decal ID",
	tooltip = "Enter an image or decal asset ID.",
})

settings:button("Apply background", function()
	local state = Library:SetBackground(image:Get(), {
		transparency = 0.25,
		scrim = 0.45,
		scale = "crop",
	}, function(_, ok, reason)
		if ok then
			Library:Notify("Background", "Background applied.", 2, "good")
		elseif reason ~= "replaced" and reason ~= "cancelled" then
			Library:Notify("Background", reason or "Couldn't load the image.", 3, "bad")
		end
	end)

	if state.status == "loading" then
		Library:Notify("Background", "Loading image...", 2, "info")
	end
end, "render", { tooltip = "Apply the background image." })

settings:button("Remove background", function()
	Library:ClearBackground()
end, "close", { variant = "secondary", tooltip = "Remove the current background." })

settings:section("Watermark", "info")

settings:toggle("Show watermark", false, function(state)
	if state then
		Library:SetWatermark("Spectrum")
	else
		Library:SetWatermarkVisible(false)
	end
end, { icon = "info", tooltip = "Show or hide the watermark." })

settings:section("Mobile", "menu")
settings:label("The mobile button appears automatically on touch devices.")

local mobile_button
mobile_button = settings:toggle("Mobile button", Library:GetMobileButton(), function(state)
	mobile_button:Set(Library:SetMobileButton(state))
end, { icon = "menu", tooltip = "Show or hide the mobile button." })

settings:section("Config", "save")
settings:label("Save your settings and restore them next time.")

local autosave

local function sync_autosave()
	if autosave then
		autosave:Set(Library:GetAutoSave())
	end
end

autosave = settings:toggle("Auto-save", Library:GetAutoSave(), function(state)
	Library:SetAutoSave(state)
	sync_autosave()
end, { icon = "save", tooltip = "Save changes automatically." })

settings:button("Save changes", function()
	Library:SaveConfig()
	Library:Notify("Spectrum", "Settings saved.", 2, "good")
end, "save", { variant = "secondary", tooltip = "Save the current settings." })

settings:separator()
settings:label("Disabled controls won't run their callbacks.")

local locked = settings:button("Locked action", function()
	log("This should not run while the button is disabled.")
end, "lock", { disabled = true, tooltip = "This button is disabled." })

settings:button("Toggle locked action", function()
	Library:SetDisabled(locked, not Library:GetDisabled(locked))
end, "lock", { variant = "secondary", tooltip = "Toggle the disabled state." })

settings:button("Close Settings", function()
	settings_window:Destroy()
end, "trash", { variant = "danger", confirm = "Click again to close" })

Library:Notify("Spectrum", "Loaded successfully.", 3, "good")
