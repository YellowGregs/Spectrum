local S = ...

local background = {}

local state = {
	asset = nil,
	transparency = 0.25,
	tint = Color3.new(1, 1, 1),
	scrim = 0.4,
	scale = "crop",
	status = "none",
	error = nil,
}

local scales = {
	crop = Enum.ScaleType.Crop,
	fit = Enum.ScaleType.Fit,
	stretch = Enum.ScaleType.Stretch,
}

local hosts = {}
local requests = {}
local generation = 0
local probe
local type_cache = {}

local function unit(value, fallback)
	value = tonumber(value)
	if value == nil then
		return fallback
	end
	return math.clamp(value, 0, 1)
end

local function normalize(opts)
	opts = type(opts) == "table" and opts or {}
	state.transparency = unit(opts.transparency, 0.25)
	state.scrim = unit(opts.scrim, 0.4)
	state.tint = typeof(opts.tint) == "Color3" and opts.tint or Color3.new(1, 1, 1)
	local scale = tostring(opts.scale or "crop"):lower()
	state.scale = scales[scale] and scale or "crop"
end

local function asset_id(value)
	if type(value) == "number" then
		return "rbxassetid://" .. tostring(math.floor(value))
	end
	if type(value) ~= "string" then
		return nil
	end
	value = string.gsub(value, "^%s+", "")
	value = string.gsub(value, "%s+$", "")
	if value == "" then
		return nil
	end
	if tonumber(value) then
		return "rbxassetid://" .. value
	end
	return value
end

local function numeric_id(source)
	if type(source) ~= "string" then
		return nil
	end
	local id = string.match(source, "^rbxassetid://(%d+)$")
	if not id then
		id = string.match(source, "[?&]id=(%d+)")
	end
	if not id and string.match(source, "^%d+$") then
		id = source
	end
	return id and tonumber(id) or nil
end

local function thumb(id)
	return string.format("rbxthumb://type=Asset&id=%d&w=420&h=420", id)
end

local function asset_type(id)
	if type_cache[id] ~= nil then
		return type_cache[id] or nil
	end
	local marketplace = game:GetService("MarketplaceService")
	local ok, info = pcall(function()
		return marketplace:GetProductInfoAsync(id, Enum.InfoType.Asset)
	end)
	if not ok then
		ok, info = pcall(function()
			return marketplace:GetProductInfo(id, Enum.InfoType.Asset)
		end)
	end
	local kind = ok and type(info) == "table" and tonumber(info.AssetTypeId) or nil
	type_cache[id] = kind or false
	return kind
end

local function resolve(source)
	local id = numeric_id(source)
	if not id then
		return source
	end
	local kind = asset_type(id)
	if kind == 1 then
		return source
	elseif kind == 13 or kind == nil then
		return thumb(id)
	end
	return nil, "That asset is not an image or a decal."
end

local function publish()
	for _, host in ipairs(hosts) do
		pcall(host, state)
	end
end

local function invoke(callback, result, ok, reason)
	if type(callback) ~= "function" then
		return
	end
	task.spawn(function()
		pcall(callback, result, ok, reason)
	end)
end

local function settle(token, ok, reason)
	if token ~= generation then
		return
	end
	state.status = ok and "applied" or "failed"
	state.error = ok and nil or reason
	publish()
	local callback = requests[token]
	requests[token] = nil
	invoke(callback, background.get(), ok, reason)
end

local function stop_probe()
	local current = probe
	probe = nil
	if current then
		pcall(function()
			current:Destroy()
		end)
	end
end

local function start_probe(source)
	local parent = S.env and S.env.windows
	if not parent then
		return nil
	end
	local label = Instance.new("ImageLabel")
	label.Name = "SpectrumBackgroundProbe"
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Image = source
	label.ImageColor3 = Color3.new(1, 1, 1)
	label.ImageTransparency = 0
	label.ScaleType = Enum.ScaleType.Stretch
	label.Position = UDim2.fromOffset(0, 0)
	label.Size = UDim2.fromOffset(1, 1)
	label.Visible = true
	label.ZIndex = 1000
	local placed = pcall(function()
		label.Parent = parent
	end)
	if not placed then
		label:Destroy()
		return nil
	end
	return label
end

local function validate(source, token)
	local label = start_probe(source)
	if not label then
		settle(token, false, "Could not check the image.")
		return
	end
	probe = label
	local provider = game:GetService("ContentProvider")
	local success = Enum.AssetFetchStatus.Success
	local failure = Enum.AssetFetchStatus.Failure
	local timed_out = Enum.AssetFetchStatus.TimedOut
	task.spawn(function()
		local deadline = os.clock() + 8
		local loaded = false
		while token == generation and probe == label and os.clock() < deadline do
			if not label.Parent then
				break
			end
			local read_ok, is_loaded = pcall(function()
				return label.IsLoaded
			end)
			if read_ok and is_loaded then
				loaded = true
				break
			end
			local status_ok, status = pcall(function()
				return provider:GetAssetFetchStatus(source)
			end)
			if status_ok then
				if status == success then
					loaded = true
					break
				elseif status == failure or status == timed_out then
					break
				end
			end
			task.wait(0.1)
		end
		if probe == label then
			probe = nil
		end
		pcall(function()
			label:Destroy()
		end)
		if token ~= generation then
			return
		end
		settle(token, loaded, loaded and nil or "The image could not be loaded. Check the asset ID and its permissions.")
	end)
end

local function cancel_pending(reason)
	local pending = requests
	requests = {}
	for _, callback in pairs(pending) do
		invoke(callback, background.get(), false, reason)
	end
end

function background.scale_type(name)
	return scales[name] or Enum.ScaleType.Crop
end

function background.watch(host)
	if type(host) ~= "function" then
		return function() end
	end
	hosts[#hosts + 1] = host
	pcall(host, state)
	return function()
		for index, entry in ipairs(hosts) do
			if entry == host then
				table.remove(hosts, index)
				break
			end
		end
	end
end

function background.set(asset, opts, callback)
	local source = asset_id(asset)
	generation = generation + 1
	local token = generation
	stop_probe()
	cancel_pending("replaced")
	if not source then
		state.asset = nil
		state.status = "none"
		state.error = nil
		publish()
		invoke(callback, background.get(), false, "Enter an image asset ID.")
		return background.get()
	end
	normalize(opts)
	state.asset = source
	state.status = "loading"
	state.error = nil
	publish()
	if callback then
		requests[token] = callback
	end
	task.spawn(function()
		local resolved, problem = resolve(source)
		if token ~= generation then
			return
		end
		if not resolved then
			settle(token, false, problem or "That asset is not an image or a decal.")
			return
		end
		if resolved ~= source then
			state.asset = resolved
			publish()
		end
		validate(resolved, token)
	end)
	return background.get()
end

function background.get()
	return {
		asset = state.asset,
		transparency = state.transparency,
		tint = state.tint,
		scrim = state.scrim,
		scale = state.scale,
		status = state.status,
		error = state.error,
	}
end

function background.clear()
	generation = generation + 1
	stop_probe()
	state.asset = nil
	state.status = "none"
	state.error = nil
	publish()
	cancel_pending("cancelled")
	return background.get()
end

function background.active()
	return state.asset ~= nil
end

S.background = background
