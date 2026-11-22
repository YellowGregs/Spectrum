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
	error("[Spectrum] Could not load Spectrum.lua: " .. tostring(remote_body), 0)
end

local chunk, problem = loadstring(body, "Spectrum")
if not chunk then
	error("[Spectrum] Could not compile Spectrum.lua: " .. tostring(problem), 0)
end

local run_ok, Library = pcall(chunk)
if not run_ok then
	error("[Spectrum] Spectrum failed to load: " .. tostring(Library), 0)
end
Library = Library or shared.Spectrum
if type(Library) ~= "table" or type(Library.Window) ~= "function" then
	error("[Spectrum] Spectrum returned no Library.", 0)
end

local function log(...)
	print("[Example]", ...)
end

local function joined(value)
	if type(value) == "table" then
		return table.concat(value, ", ")
	end
	return tostring(value)
end

if Library.Build then
	log("Build", Library.Build)
end

local main = Library:Window("Spectrum UI", { icon = "sliders", width = 340 })

local basics = main:Tab("Basics", {
	icon = "sliders",
	tooltip = "Buttons, toggles, sliders, sections",
	open = { "Buttons", "Toggles", "Sliders", "Sections" },
	closed = { "Sections" },
})
basics:label("hover to see tooltips and right-click values for options")

basics:section("Buttons", "arrow")
basics:button("Primary button", function()
	log("Primary button ran.")
end, "bolt", { tooltip = "Accent button." })

basics:button("Secondary button", function()
	log("Secondary button ran.")
end, "save", { variant = "secondary", tooltip = "Quieter action" })

basics:button("Danger button with confirm", function()
	log("Confirmed danger action ran")
end, "trash", {
	variant = "danger",
	confirm = "Click again to confirm",
	tooltip = "First click arms, second runs",
})

local locked_button = basics:button("Disabled button", function()
	log("This should never print.")
end, "lock", { disabled = true, tooltip = "disabled = true" })

basics:button("Enable or disable that button", function()
	local next_state = not Library:GetDisabled(locked_button)
	Library:SetDisabled(locked_button, next_state)
	log("Locked button disabled:", next_state)
end, "lock", { variant = "secondary" })

basics:section("Toggles", "check")
local feature = basics:toggle("Switch toggle", true, function(state)
	log("Switch toggle:", state)
end, { icon = "check", tooltip = "Slider switch, on by default" })

basics:toggle("Checkbox toggle", false, function(state)
	log("Checkbox toggle:", state)
end, { style = "checkbox", icon = "check", tooltip = "Square check" })

local watched = basics:toggle("Toggle with a listener", false, function(state)
	log("Callback:", state)
end, { icon = "eye", tooltip = "OnChanged fires after the callback" })

local unwatch = watched:OnChanged(function(state)
	log("OnChanged listener:", state)
end)

basics:button("Programmatic Toggle(): flips the row", function()
	watched:Toggle()
end, "refresh", { variant = "secondary", tooltip = "Calls the handle, not the row" })

basics:button("Remove the OnChanged listener", function()
	if unwatch then
		unwatch()
		unwatch = nil
		log("OnChanged listener removed.")
	end
end, "close", { variant = "secondary", tooltip = "OnChanged returns its own unsubscribe" })

basics:button("Read Set/Get values", function()
	log("Switch toggle:", feature:Get(), "Watched:", watched:Get())
end, "code", { variant = "secondary" })

basics:section("Sliders", "speed")
local speed = basics:slider("Speed", 1, 100, 16, function(value)
	log("Speed:", value)
end, 1, "speed", { suffix = " studs", showMax = true, tooltip = "Shows value and max" })

basics:slider("Sensitivity", 0.1, 2, 0.8, function(value)
	log("Sensitivity:", value)
end, 0.1, "sliders", {
	decimals = 2,
	compact = true,
	suffix = "x",
	tooltip = "Compact, two decimals.",
})

basics:button("Set speed to 75 without firing the callback", function()
	speed:Set(75)
	log("Speed is now:", speed:Get())
end, "code", { variant = "secondary" })

basics:section("Sections", "folder")
basics:label("The Showcase section below is driven by these rows.")
local section_status = basics:label("Showcase is open.")
local showcase
basics:button("Showcase: Open()", function()
	showcase:Open()
	section_status.Text = "Showcase is open: " .. tostring(showcase:IsOpen())
end, "arrow", { variant = "secondary" })

basics:button("Showcase: Close()", function()
	showcase:Close()
	section_status.Text = "Showcase is open: " .. tostring(showcase:IsOpen())
end, "arrow", { variant = "secondary" })

basics:button("Showcase: Toggle()", function()
	showcase:Toggle()
	section_status.Text = "Showcase is open: " .. tostring(showcase:IsOpen())
end, "refresh", { variant = "secondary" })

basics:separator()

showcase = basics:section("Showcase", "folder", { id = "showcase", open = true })
basics:label("These rows vanish when Showcase collapses.")
local showcase_toggle = basics:toggle("Inner toggle", false, function(state)
	log("Showcase toggle:", state)
end, { icon = "check" })

basics:button("Check the inner toggle", function()
	log("Showcase IsOpen:", showcase:IsOpen(), "Inner toggle:", showcase_toggle:Get())
end, "code", { variant = "secondary" })

basics:section("Disabled states", "lock")
basics:label("All start disabled. The button below flips them together.")
local disabled_toggle = basics:toggle("Disabled toggle", true, function(state)
	log("Disabled toggle:", state)
end, { icon = "check", disabled = true })
local disabled_slider = basics:slider("Disabled slider", 0, 100, 40, function(value)
	log("Disabled slider:", value)
end, 1, "speed", { disabled = true })
local disabled_box = basics:textbox("Disabled textbox", "locked", function(text)
	log("Disabled textbox:", text)
end, "lock", { disabled = true, placeholder = "Cannot type" })

basics:button("Toggle every disabled state", function()
	local next_state = not Library:GetDisabled(disabled_toggle)
	for _, control in ipairs({ disabled_toggle, disabled_slider, disabled_box, locked_button }) do
		Library:SetDisabled(control, next_state)
	end
	log("All controls disabled:", next_state)
end, "lock", { variant = "secondary", tooltip = "SetDisabled handles both buttons and controls" })

basics:section("This window", "render")
basics:label("the style and config are separate windows so you can drag and fold it on their own")
basics:button("Rename this window", function()
	main:SetTitle("Spectrum Example (renamed)")
end, "code", { variant = "secondary" })

basics:button("Fold or unfold this window", function()
	main:Toggle()
end, "arrow", { variant = "secondary" })

local fields = main:Tab("Fields", {
	icon = "code",
	tooltip = "Text, dropdowns, and color pickers",
	open = { "Text fields", "Dropdowns", "Colorpicker" },
})

fields:section("Text fields", "code")
fields:label("Fields submit on blur. submitOnEnter = false makes Enter just release focus.")

local name_box = fields:textbox("Display name", "", function(text)
	log("Display name:", text)
end, "user", { placeholder = "Type a name", maxLength = 24, tooltip = "Capped at 24 chars." })

fields:textbox("Search tag", "spectrum", function(text)
	log("Search tag:", text)
end, "search", { clearOnFocus = true, tooltip = "Selects existing text on focus" })

fields:textbox("Amount", "10", function(text)
	log("Amount:", text)
end, "code", { numericOnly = true, placeholder = "0", maxLength = 8, tooltip = "Digits, one dot, optional leading minus" })

fields:textbox("Deferred submit", "", function(text)
	log("Submitted on blur:", text)
end, "arrow", { submitOnEnter = false, tooltip = "Enter just releases focus." })

fields:button("Focus the name field from code", function()
	name_box:Focus()
end, "user", { variant = "secondary" })

fields:button("Set the name field from code", function()
	name_box:Set("Spectrum")
	log("Name field is now:", name_box:Get())
end, "code", { variant = "secondary" })

fields:section("Dropdowns", "target")
fields:label("Single and multi share a row. Arrow keys, Home/End, Enter, Escape work in open lists")

local mode = fields:dropdown("Mode", { "Simple", "Compact", "Detailed" }, "Simple", function(picked)
	log("Mode:", picked)
end, false, "sliders", { tooltip = "Single choice." })

local channels = fields:dropdown("Channels", { "Alpha", "Bravo", "Charlie", "Delta" }, { "Alpha", "Bravo" }, function(picks)
	log("Channels:", joined(picks))
end, true, "target", {
	searchable = true,
	placeholder = "Pick channels",
	disabledOptions = { "Delta" },
	tooltip = "Multi with search and one disabled option",
})

fields:button("Set Mode to Detailed from code", function()
	mode:Set("Detailed")
	log("Mode now:", mode:Get())
end, "refresh", { variant = "secondary" })

fields:button("SetList to a single channel", function()
	channels:SetList({ "Charlie" })
	log("Channels now:", joined(channels:Get()))
end, "refresh", { variant = "secondary" })

fields:button("Open the Mode dropdown", function()
	mode:Open()
end, "arrow", { variant = "secondary" })

fields:button("Close the Mode dropdown", function()
	mode:Close()
end, "arrow", { variant = "secondary" })

fields:button("Read both dropdowns", function()
	log("Mode:", mode:Get(), "Channels:", joined(channels:Get()))
end, "code", { variant = "secondary" })

fields:section("Colorpicker", "palette")
fields:label("Presets, recents, RGB entry, copy, or roll random.")
local defaults = Library:GetDesign()
local accent = fields:colorpicker("Accent", defaults.accent, function(color)
	Library:Design({ accent = color })
end, "palette", {
	presets = {
		Color3.fromRGB(230, 162, 58),
		Color3.fromRGB(197, 84, 54),
		"#69A9FF",
		"#74C47A",
	},
	recent = true,
	tooltip = "Presets, recents, RGB, copy, random.",
})
Library:Design({ accent = accent:Get() })

fields:button("Open the accent picker", function()
	accent:Open()
end, "palette", { variant = "secondary" })

fields:button("Set a color from code", function()
	accent:Set(Color3.fromRGB(105, 146, 170), true)
	log("Accent is now:", accent:Get())
end, "refresh", { variant = "secondary" })

local keys = main:Tab("Keys", {
	icon = "key",
	tooltip = "Rebinding and action modes",
	open = { "Rebinding", "Actions" },
})
keys:label("Click the pill, press a key. Escape cancels. Backspace/Delete clears unless clearOnDelete = false.")

keys:section("Rebinding", "key")
local quick_bind = keys:keybind("Quick bind", "F", nil, "key", {
	onChange = function(key)
		log("Quick bind is now:", key)
	end,
	tooltip = "Logs the new key.",
})

keys:keybind("Chord bind", "RightControl+LeftShift", nil, "key", {
	combo = true,
	allowMouse = false,
	allowGamepad = false,
	onChange = function(key)
		log("Chord bind is now:", key)
	end,
	tooltip = "Captures every key held before release.",
})

local soft_bind = keys:keybind("Clearable bind", "H", nil, "key", {
	combo = true,
	clearOnDelete = false,
	emptyText = "Unbound",
	resetKey = "H",
	onChange = function(key)
		log("Clearable bind is now:", key)
	end,
	tooltip = "Backspace won't clear; use Reset.",
})

keys:button("Reset the quick bind from code", function()
	quick_bind:Set("F")
	log("Quick bind reset:", quick_bind:Get())
end, "refresh", { variant = "secondary" })

keys:button("Clear the clearable bind with Set(nil)", function()
	soft_bind:Set(nil)
	log("Clearable bind:", tostring(soft_bind:Get()))
end, "close", { variant = "secondary" })

keys:section("Actions", "bolt")

local boost = keys:toggle("Boost", false, function(state)
	log("Boost toggle:", state)
end, { icon = "bolt" })

keys:keybind("Boost key", "G", nil, "bolt", {
	mode = "toggle",
	syncToggle = boost,
	tooltip = "Toggles Boost, mirrors state.",
})

keys:keybind("Hold to log", "LeftShift", nil, "key", {
	mode = "hold",
	onPress = function(state)
		log("Held:", state)
	end,
	onRelease = function()
		log("Released")
	end,
	tooltip = "onPress on hold, onRelease on release.",
})

keys:keybind("Standalone toggle action", "J", nil, "refresh", {
	mode = "toggle",
	onPress = function(state)
		log("Standalone action:", state)
	end,
	tooltip = "Action without a toggle row.",
})

keys:keybind("Disabled keybind", "K", nil, "lock", {
	disabled = true,
	emptyText = "Locked",
	tooltip = "Disabled keybind.",
})

keys:label("Actions ignore textbox focus and keybind capture, and stays quiet while the UI is hidden")

local style = Library:Window("Style", { icon = "palette", width = 320 })

style:section("Theme", "palette", { open = true })
style:label("Design applies whitelisted tokens and repaints every open window.")
local square = style:toggle("Square corners", true, function(state)
	Library:Design({ radius = state and 0 or 3 })
end, { icon = "sliders", tooltip = "Radius clamped 0..12." })

style:button("Reset the theme", function()
	Library:Design(defaults)
	accent:Set(defaults.accent, true)
	square:Set(true, true)
	Library:Notify("Spectrum", "Theme reset.", 2, "info")
end, "refresh", { tooltip = "Default palette and radius." })

style:button("Log the current design tokens", function()
	local tokens = Library:GetDesign()
	log("Accent:", tokens.accent, "Radius:", tokens.radius)
end, "code", { variant = "secondary" })

style:section("Notifications", "info", { open = true })
style:label("Each kind has its own icon and color. Duration in seconds.")
style:button("Send info notification", function()
	Library:Notify("Spectrum", "Info: the operation is running.", 3, "info")
end, "info", { variant = "secondary" })

style:button("Send success notification", function()
	Library:Notify("Spectrum", "Success: everything applied cleanly.", 3, "good")
end, "check")

style:button("Send warning notification", function()
	Library:Notify("Spectrum", "Warning: the plot has not loaded yet.", 4, "warn")
end, "alert", { variant = "secondary" })

style:button("Send error notification", function()
	Library:Notify("Spectrum", "Error: the request was rejected.", 4, "bad")
end, "trash", { variant = "danger" })

style:section("Background", "render")
style:label("Paste an Image or Decal ID and apply")

local background_image = style:textbox("Image", "", nil, "render", {
	placeholder = "Image or Decal asset ID",
	tooltip = "rbxassetid:// or a raw numeric ID.",
})

local background_alpha = style:slider("Image transparency", 0, 0.9, 0.25, nil, 0.05, "eye", {
	decimals = 2,
	suffix = "",
	tooltip = "0 is opaque.",
})

local background_scrim = style:slider("Scrim darkness", 0, 1, 0.4, nil, 0.05, "render", {
	decimals = 2,
	compact = true,
	tooltip = "Keeps text readable over images",
})

local background_tint = style:colorpicker("Tint", Color3.fromRGB(255, 255, 255), nil, "palette", {
	presets = { Color3.fromRGB(255, 255, 255), "#B8C4D6", "#E6A23A" },
	tooltip = "Multiplied over the image before the scrim.",
})

local background_scale = style:dropdown("Scale", { "crop", "fit", "stretch" }, "crop", nil, false, "render", {
	tooltip = "Unknown names fall back to crop.",
})

style:button("Apply background", function()
	local state = Library:SetBackground(background_image:Get(), {
		transparency = background_alpha:Get(),
		tint = background_tint:Get(),
		scrim = background_scrim:Get(),
		scale = background_scale:Get(),
	}, function(_, ok, reason)
		if ok then
			Library:Notify("Background", "Image applied to every window.", 2, "good")
		elseif reason ~= "replaced" and reason ~= "cancelled" then
			Library:Notify("Background", reason or "Image could not be loaded.", 3, "bad")
		end
	end)
	if state.status == "loading" then
		Library:Notify("Background", "Loading image…", 2, "info")
	elseif state.status == "failed" then
		Library:Notify("Background", state.error or "Image could not be loaded.", 3, "bad")
	end
end, "render", { tooltip = "Applies to existing and future windows." })

style:button("Log background state", function()
	local state = Library:GetBackground()
	log("Background:", state.status, tostring(state.asset), tostring(state.scale))
end, "code", { variant = "secondary" })

style:button("Clear background", function()
	Library:ClearBackground()
end, "close", { variant = "secondary" })

style:section("Watermark", "info")
local watermark_box
local watermark_toggle
watermark_toggle = style:toggle("Show watermark", false, function(state)
	if state then
		Library:SetWatermark(watermark_box and watermark_box:Get() or "Spectrum Example")
	else
		Library:SetWatermarkVisible(false)
	end
end, { icon = "info", tooltip = "Card in the top-left." })

watermark_box = style:textbox("Watermark text", "Spectrum Example", function(text)
	if watermark_toggle:Get() then
		Library:SetWatermark(text ~= "" and text or "Spectrum")
	end
end, "code", { placeholder = "Spectrum", tooltip = "Updates the card while it's visible." })

style:button("Read the watermark", function()
	local text, visible = Library:GetWatermark()
	log("Watermark:", tostring(text), "Visible:", tostring(visible))
end, "code", { variant = "secondary" })

local setup = Library:Window("Config", { icon = "save", width = 320 })
setup:label("Values, positions, and section state are stored per profile. Autosave is off by default.")

setup:section("Profiles", "save", { open = true })
setup:label("SaveConfig writes the active profile and keeps a .bak. LoadConfig reapplies values and runs their callbacks.")

local profile_box = setup:textbox("Profile name", Library:GetProfile(), function(name)
	log("Profile field:", name)
end, "folder", { placeholder = "default", tooltip = "File name under spectrum/configs." })

local autosave
autosave = setup:toggle("Auto-save", Library:GetAutoSave(), function(state)
	Library:SetAutoSave(state)
	if autosave then
		autosave:Set(Library:GetAutoSave())
	end
end, { icon = "save", tooltip = "Writes changes as they happen." })

setup:button("Save now", function()
	local name = profile_box:Get()
	local ok = Library:SaveConfig(name ~= "" and name or nil)
	if ok then
		Library:Notify("Config", "Saved " .. Library:GetProfile() .. ".", 2, "good")
	else
		Library:Notify("Config", Library:GetConfigError() or "Could not save.", 3, "bad")
	end
end, "save", { tooltip = "False when the executor can't write." })

setup:button("Load profile", function()
	local name = profile_box:Get()
	Library:LoadConfig(name ~= "" and name or nil)
	Library:Notify("Config", "Loaded " .. Library:GetProfile() .. ".", 2, "info")
end, "folder", { variant = "secondary" })

setup:button("Switch to the combat profile", function()
	Library:SetProfile("combat")
	profile_box:Set(Library:GetProfile())
	Library:Notify("Config", "Profile: " .. Library:GetProfile(), 2, "info")
end, "arrow", { variant = "secondary", tooltip = "SetProfile saves pending changes first." })

setup:button("Log path, profile, and last error", function()
	log("Profile:", Library:GetProfile())
	log("Path:", Library:GetConfigPath())
	log("Last error:", tostring(Library:GetConfigError()))
end, "code", { variant = "secondary" })

setup:section("Menu and panic", "key", { open = true })
setup:label("Menu key toggles all windows. Panic key is opt-in and saved in the profile.")

if Library:IsMobile() then
	setup:label("Touch device: the floating button opens and closes the UI.")
else
	local default_menu_key = "RightControl+LeftShift"
	local menu_bind
	menu_bind = setup:keybind("Open/close UI", Library:GetToggleKey(), nil, "key", {
		combo = true,
		allowMouse = false,
		resetKey = default_menu_key,
		tooltip = "Click, then hold the chord.",
		onChange = function(key)
			if not key or key == "" then
				Library:SetToggleKey(default_menu_key)
				if menu_bind then
					menu_bind:Set(default_menu_key)
				end
				return
			end
			if key ~= Library:GetToggleKey() then
				Library:SetToggleKey(key)
			end
		end,
	})
end

local panic_bind
panic_bind = setup:keybind("Panic key", Library:GetPanicKey(), nil, "shield", {
	emptyText = "Unbound",
	resetKey = "End",
	allowMouse = true,
	allowGamepad = true,
	tooltip = "Hides the UI by default and bind it to unload features instead",
	onChange = function(key)
		if key and key ~= "" then
			Library:SetPanicKey(key)
		else
			Library:SetPanicKey(nil)
		end
	end,
})

setup:button("Bind panic to End", function()
	Library:SetPanicKey("End")
	panic_bind:Set("End")
	log("Panic key:", tostring(Library:GetPanicKey()))
end, "shield", { variant = "secondary" })

setup:button("Disable the panic key", function()
	Library:SetPanicKey(false)
	panic_bind:Set(nil)
end, "close", { variant = "secondary" })

setup:button("Hide the interface", function()
	Library:ToggleUI(false)
end, "eye", { variant = "secondary", tooltip = "Reopen with the menu key or mobile button" })

setup:button("Show the interface", function()
	Library:ToggleUI(true)
end, "eye", { variant = "secondary" })

setup:section("Mobile", "menu")
if Library:IsMobile() then
	setup:label("IsMobile() says touch-only, so rows and targets are bigger heh")
else
	setup:label("Desktop for IsMobile() is false, so force the launcher to test.")
end

local mobile_button
mobile_button = setup:toggle("Mobile button", Library:GetMobileButton(), function(state)
	local mounted = Library:SetMobileButton(state)
	if mobile_button then
		mobile_button:Set(mounted)
	end
end, { icon = "menu", tooltip = "you should know what this is" })

setup:button("Read the launcher state", function()
	log("Mobile button mounted:", Library:GetMobileButton(), "Mobile:", Library:IsMobile())
end, "code", { variant = "secondary" })

setup:section("Teardown", "trash")
setup:label("Destroy unloads everything, and just reruns to rebuild")
setup:button("Destroy Spectrum", function()
	Library:Destroy()
end, "trash", { variant = "danger", confirm = "Click again to unload everything" })

Library:Notify("Spectrum", "Loaded.", 4, "good")
