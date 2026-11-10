local BASE = "https://raw.githubusercontent.com/YellowGregs/Spectrum/refs/heads/main/"
local MODULES = {
	"src/core/env",
	"src/core/style",
	"src/core/util",
	"src/core/icons",
	"src/core/modal",
	"src/core/options",
	"src/core/config",
	"src/core/launcher",
	"src/core/notify",
	"src/ui/window",
	"src/ui/inputs",
	"src/ui/selects",
	"src/ui/text",
	"src/init",
}
local CACHE_VERSION = "6"

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local function get(url)
	local ok, body = pcall(function()
		return game:HttpGet(url, true)
	end)
	if not ok or type(body) ~= "string" or body == "" or body == "404: Not Found" then
		return nil, body
	end
	return body
end

local function commit()
	local body = get("https://api.github.com/repos/YellowGregs/Spectrum/commits/main")
	if body then
		local sha = string.match(body, '"sha"%s*:%s*"(%x+)"')
		if sha and #sha == 40 then
			return sha
		end
	end
	local page = get("https://github.com/YellowGregs/Spectrum")
	if page then
		local sha = string.match(page, "currentOid[^%x]+(%x+)")
		if sha and #sha == 40 then
			return sha
		end
	end
end

local function Caches()
	return type(isfile) == "function"
		and type(readfile) == "function"
		and type(writefile) == "function"
		and type(makefolder) == "function"
end

local function ensure(folder)
	local built = ""
	for part in string.gmatch(folder, "[^/]+") do
		built = built == "" and part or (built .. "/" .. part)
		if type(isfolder) ~= "function" or not isfolder(built) then
			pcall(makefolder, built)
		end
	end
end

local pinned = Caches() and commit() or nil
local cache_root = pinned and ("spectrum/modules/" .. CACHE_VERSION .. "/" .. pinned .. "/") or nil
local caching = cache_root ~= nil

shared.SpectrumCache = {
	commit = pinned,
	root = cache_root,
	enabled = caching,
}

local function fetch(path)
	local url = BASE .. path .. ".lua"
	local file = cache_root and (cache_root .. path .. ".lua")
	if caching and isfile(file) then
		local ok, body = pcall(readfile, file)
		if ok and type(body) == "string" and body ~= "" and body ~= "404: Not Found" then
			return body
		end
	end

	local body, why = get(url)
	if not body then
		error("[Spectrum] could not fetch " .. url .. " -> " .. tostring(why), 0)
	end

	if caching then
		local folder = string.match(path, "^(.*)/")
		ensure(cache_root .. (folder or ""))
		pcall(writefile, file, body)
	end
	return body
end

if shared.Spectrum then
	pcall(function()
		shared.Spectrum:Destroy()
	end)
	shared.Spectrum = nil
end

local S = {}
for _, path in ipairs(MODULES) do
	local source = fetch(path)
	local chunk, problem = loadstring(source, "Spectrum/" .. path)
	if not chunk then
		error("[Spectrum] syntax error in " .. path .. " -> " .. tostring(problem), 0)
	end
	chunk(S)
end

if not S.library then
	error("[Spectrum] init.lua did not expose a library", 0)
end

shared.Spectrum = S.library
return S.library
