local S = ...

local config = {}

local ROOT = "spectrum/configs"
local profile = "default"
local data = {}
local windows = {}
local registry = {}
local window_counts = {}
local value_counts = {}
local scheduled = false
local auto_save_enabled = false

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
		return
	end
	local ok, parsed = pcall(function()
		return http:JSONDecode(body)
	end)
	if ok and type(parsed) == "table" then
		data = parsed
	end
	normalize()
end

function config.load(name)
	if name then
		profile = name_of(name)
	end
	data = fresh()
	if can_read() and isfile(path(profile)) then
		local ok, body = pcall(readfile, path(profile))
		if ok and type(body) == "string" and body ~= "" then
			decode(body)
		end
	elseif shared.SpectrumConfigs and type(shared.SpectrumConfigs[profile]) == "table" then
		data = copy(shared.SpectrumConfigs[profile])
		normalize()
	end
	auto_save_enabled = type(data.settings) == "table" and data.settings.auto_save == true
	return config.apply()
end

function config.save(name)
	if name then
		profile = name_of(name)
	end
	normalize()
	data.settings.auto_save = auto_save_enabled
	local body = encode()
	if body and can_write() then
		ensure(ROOT)
		pcall(writefile, path(profile), body)
	end
	shared.SpectrumConfigs = shared.SpectrumConfigs or {}
	shared.SpectrumConfigs[profile] = copy(data)
	return body ~= nil
end

function config.touch()
	if not auto_save_enabled then
		return
	end
	if scheduled then
		return
	end
	scheduled = true
	task.delay(0.8, function()
		scheduled = false
		if auto_save_enabled then
			config.save()
		end
	end)
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
		local saved = data.windows[win]
		if saved and api.restore then
			pcall(api.restore, saved)
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

S.config = config
