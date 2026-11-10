local BASE = "https://raw.githubusercontent.com/YellowGregs/Spectrum/"
local MODULES = {
	"src/core/env",
	"src/core/style",
	"src/core/util",
	"src/core/modal",
	"src/core/notify",
	"src/ui/window",
	"src/ui/inputs",
	"src/ui/selects",
	"src/ui/text",
	"src/init",
}

if not game:IsLoaded() then
	game.Loaded:Wait()
end

if shared.Spectrum then
	pcall(function()
		shared.Spectrum:Destroy()
	end)
	shared.Spectrum = nil
end

local function fetch(path)
	local ok, body = pcall(function()
		return game:HttpGet(BASE .. path .. ".lua", true)
	end)
	if not ok or type(body) ~= "string" or body == "" or body == "404: Not Found" then
		error("[Spectrum] could not fetch " .. path .. " -> " .. tostring(body), 0)
	end
	return body
end

local S = {}

for _, path in ipairs(MODULES) do
	local chunk, problem = loadstring(fetch(path), "Spectrum/" .. path)
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
