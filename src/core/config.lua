local S = ...

local config = {}

local ROOT = "spectrum/configs"
local profile = "default"
local data = {}
local windows = {}
local registry = {}
local windowCounts = {}
local valueCounts = {}
local scheduled = false

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

local function nameOf(value)
	local out = tostring(value or "default"):gsub("[^%w_%- ]", "_")
	if out == "" then
		out = "default"
	end
	return out
end

local function path(name)
	return ROOT .. "/" .. name .. ".json"
end

local function canRead()
	return type(isfile) == "function" and type(readfile) == "function"
end

local function canWrite()
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

local function normalize()
	data.windows = type(data.windows) == "table" and data.windows or {}
	data.values = type(data.values) == "table" and data.values or {}
	data.settings = type(data.settings) == "table" and data.settings or {}
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
		profile = nameOf(name)
	end
	data = fresh()
	if canRead() and isfile(path(profile)) then
		local ok, body = pcall(readfile, path(profile))
		if ok and type(body) == "string" and body ~= "" then
			decode(body)
		end
	elseif shared.SpectrumConfigs and type(shared.SpectrumConfigs[profile]) == "table" then
		data = copy(shared.SpectrumConfigs[profile])
		normalize()
	end
	return config.apply()
end

function config.save(name)
	if name then
		profile = nameOf(name)
	end
	normalize()
	local body = encode()
	if body and canWrite() then
		ensure(ROOT)
		pcall(writefile, path(profile), body)
	end
	shared.SpectrumConfigs = shared.SpectrumConfigs or {}
	shared.SpectrumConfigs[profile] = copy(data)
	return body ~= nil
end

function config.touch()
	if scheduled then
		return
	end
	scheduled = true
	task.delay(0.8, function()
		scheduled = false
		config.save()
	end)
end

function config.windowKey(title)
	local name = tostring(title or "Window")
	local count = (windowCounts[name] or 0) + 1
	windowCounts[name] = count
	if count == 1 then
		return name
	end
	return name .. "#" .. count
end

function config.windowState(key)
	return data.windows[key]
end

function config.place(key, state)
	data.windows[key] = state
	config.touch()
end

function config.attachWindow(key, api)
	windows[key] = api
	local saved = data.windows[key]
	if saved and api.restore then
		pcall(api.restore, saved)
	end
end

function config.bind(win, kind, label, api)
	local base = kind .. ":" .. tostring(label or "")
	valueCounts[win] = valueCounts[win] or {}
	local count = (valueCounts[win][base] or 0) + 1
	valueCounts[win][base] = count
	local key = count == 1 and base or (base .. "#" .. count)
	registry[win] = registry[win] or {}
	registry[win][key] = api
	local saved = data.values[win] and data.values[win][key]
	if saved ~= nil and api.set then
		pcall(api.set, saved)
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
				if value ~= nil and api.set then
					pcall(api.set, value)
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

function config.toggleKey(value)
	if value ~= nil then
		data.settings.toggleKey = tostring(value)
		config.touch()
	end
	return data.settings and data.settings.toggleKey
end

function config.flush()
	config.save()
end

function config.profile()
	return profile
end

S.config = config
