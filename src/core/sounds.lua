local S = ...

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
