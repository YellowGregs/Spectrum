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
local scheduled_thread
local auto_save_enabled = false
local dirty = false
local last_body
local error_message

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
		sections = {},
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
	data.sections = type(data.sections) == "table" and data.sections or {}
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
		return false
	end
	local ok, parsed = pcall(function()
		return http:JSONDecode(body)
	end)
	if not ok or type(parsed) ~= "table" then
		return false
	end
	data = parsed
	normalize()
	return true
end

function config.load(name)
	if name then
		local target = name_of(name)
		if target ~= profile and (dirty or auto_save_enabled) then
			config.save()
		end
		profile = target
	end
	local file = path(profile)
	data = fresh()
	if can_read() and isfile(file) then
		local ok, body = pcall(readfile, file)
		if ok and type(body) == "string" and body ~= "" then
			if not decode(body) then
				if can_write() then
					pcall(writefile, file .. ".corrupt", body)
				end
				local backup_file = file .. ".bak"
				if isfile(backup_file) then
					local ok_backup, backup_body = pcall(readfile, backup_file)
					if ok_backup and type(backup_body) == "string" then
						decode(backup_body)
					end
				end
			end
		end
	elseif shared.SpectrumConfigs and type(shared.SpectrumConfigs[profile]) == "table" then
		data = copy(shared.SpectrumConfigs[profile])
		normalize()
	end
	auto_save_enabled = type(data.settings) == "table" and data.settings.auto_save == true
	dirty = false
	last_body = nil
	return config.apply()
end

function config.save(name)
	if name then
		profile = name_of(name)
	end
	normalize()
	data.settings.auto_save = auto_save_enabled
	local file = path(profile)
	local body = encode()
	if not body then
		error_message = "profile could not be encoded"
		return false
	end
	shared.SpectrumConfigs = shared.SpectrumConfigs or {}
	shared.SpectrumConfigs[profile] = copy(data)
	if body == last_body and (type(isfile) ~= "function" or isfile(file)) then
		dirty = false
		return true
	end
	if not can_write() then
		error_message = "executor has no writefile or makefolder"
		return false
	end
	ensure(ROOT)
	local ok_previous, previous = pcall(readfile, file)
	if ok_previous and type(previous) == "string" and previous ~= "" then
		pcall(writefile, file .. ".bak", previous)
	end
	if not pcall(writefile, file, body) then
		error_message = "could not write " .. file
		dirty = true
		return false
	end
	last_body = body
	error_message = nil
	dirty = false
	return true
end

function config.touch()
	dirty = true
	if not auto_save_enabled then
		return
	end
	if scheduled then
		return
	end
	scheduled = true
	scheduled_thread = task.delay(0.8, function()
		scheduled = false
		scheduled_thread = nil
		if auto_save_enabled then
			config.save()
		end
	end)
end

function config.cancel()
	if scheduled_thread then
		pcall(task.cancel, scheduled_thread)
		scheduled_thread = nil
	end
	scheduled = false
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

function config.section_state(key, id)
	local sections = data.sections[key]
	if type(sections) ~= "table" then
		return nil
	end
	local value = sections[id]
	if value == nil then
		return nil
	end
	return value == true
end

function config.place_section(key, id, open)
	data.sections[key] = type(data.sections[key]) == "table" and data.sections[key] or {}
	data.sections[key][id] = open == true
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
		if api.restore then
			local saved = data.windows[win]
			pcall(api.restore, saved or {})
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

function config.panic_key(value)
	if value ~= nil then
		data.settings = type(data.settings) == "table" and data.settings or {}
		if value == false or value == "" then
			data.settings.panic_key = nil
		else
			data.settings.panic_key = tostring(value)
		end
		config.touch()
	end
	return data.settings and data.settings.panic_key
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

function config.featurelist_state()
	return data.settings and data.settings.feature_list
end

function config.place_featurelist(state)
	if type(state) ~= "table" then
		return
	end
	data.settings = type(data.settings) == "table" and data.settings or {}
	data.settings.feature_list = {
		v = 1,
		x = tonumber(state.x) or -12,
		y = tonumber(state.y) or 12,
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

function config.file()
	return path(profile)
end

function config.last_error()
	return error_message
end

function config.pending()
	return dirty
end

S.config = config
