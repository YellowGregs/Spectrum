local S = ...

local background = {}

local state = {
	asset = nil,
	transparency = 0.25,
	tint = Color3.new(1, 1, 1),
	scrim = 0.4,
	scale = "crop",
}

local scales = {
	crop = Enum.ScaleType.Crop,
	fit = Enum.ScaleType.Fit,
	stretch = Enum.ScaleType.Stretch,
}

local hosts = {}

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

local function publish()
	for _, host in ipairs(hosts) do
		pcall(host, state)
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

function background.set(asset, opts)
	local source = asset_id(asset)
	if not source then
		return background.clear()
	end
	state.asset = source
	normalize(opts)
	publish()
	return background.get()
end

function background.get()
	return {
		asset = state.asset,
		transparency = state.transparency,
		tint = state.tint,
		scrim = state.scrim,
		scale = state.scale,
	}
end

function background.clear()
	if state.asset == nil then
		return background.get()
	end
	state.asset = nil
	publish()
	return background.get()
end

function background.active()
	return state.asset ~= nil
end

S.background = background
