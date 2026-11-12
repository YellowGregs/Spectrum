local S = ...

local cloneref = cloneref or function(obj)
	return obj
end

local Players = cloneref(game:GetService("Players"))
local CoreGui = cloneref(game:GetService("CoreGui"))
local Workspace = cloneref(game:GetService("Workspace"))
local tws = cloneref(game:GetService("TweenService"))
local uis = cloneref(game:GetService("UserInputService"))
local HttpService = cloneref(game:GetService("HttpService"))

local thread_fix = type(setthreadidentity) == "function"
if thread_fix then
	local ok = pcall(setthreadidentity, 8)
	if not ok then
		thread_fix = false
	end
end

local env = {}
env.tws = tws
env.uis = uis
env.mobile = uis.TouchEnabled and not uis.KeyboardEnabled

local function player_gui()
	if env.player_gui and env.player_gui.Parent then
		return env.player_gui
	end
	local player = Players.LocalPlayer
	if not player then
		return env.player_gui
	end
	local gui = player:FindFirstChildOfClass("PlayerGui")
	if not gui then
		gui = player:WaitForChild("PlayerGui")
	end
	env.player_gui = gui
	return gui
end

env.player_gui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")

local function hash_name(text)
	local value = 5381
	for index = 1, #text do
		value = (value * 33 + string.byte(text, index)) % 4294967296
	end
	return string.format("%08x", math.floor(value))
end

local session_name
do
	local ok, guid = pcall(function()
		return HttpService:GenerateGUID(false)
	end)
	if ok and type(guid) == "string" then
		session_name = string.gsub(guid, "-", ""):sub(1, 12)
	else
		session_name = string.format("%08x%04x", math.floor(os.clock() * 1000) % 4294967296, math.random(0, 0xFFFF))
	end
end

local function gui_name(label)
	return session_name .. "_" .. hash_name(tostring(label))
end
env.gui_name = gui_name

local previous_layers = shared.SpectrumLayers
if type(previous_layers) == "table" then
	for _, gui in ipairs(previous_layers) do
		pcall(function()
			if typeof(gui) == "Instance" and gui.Parent then
				gui:Destroy()
			end
		end)
	end
end
shared.SpectrumLayers = {}

local function sweep(holder)
	if not holder then
		return
	end
	pcall(function()
		for _, item in ipairs(holder:GetChildren()) do
			if string.sub(item.Name, 1, 8) == "Spectrum" then
				item:Destroy()
			end
		end
	end)
end

sweep(CoreGui)
sweep(player_gui())

local function can_parent(parent)
	if not parent then
		return false
	end
	local probe = Instance.new("ScreenGui")
	local placed = pcall(function()
		probe.Parent = parent
	end)
	probe:Destroy()
	return placed
end

local holder = nil
if thread_fix then
	local ok, hidden = pcall(function()
		return type(gethui) == "function" and gethui() or nil
	end)
	if ok and typeof(hidden) == "Instance" and can_parent(hidden) then
		holder = hidden
	elseif can_parent(CoreGui) then
		holder = CoreGui
	end
end

if not holder then
	holder = player_gui()
end
if not holder then
	error("[Spectrum] no PlayerGui available for the interface", 0)
end

local function layer(name, order)
	local gui = Instance.new("ScreenGui")
	gui.Name = gui_name(name)
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = order
	pcall(function()
		gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	end)
	if thread_fix then
		pcall(setthreadidentity, 8)
		pcall(function()
			gui.OnTopOfCoreBlur = true
		end)
	end
	gui.Parent = holder
	shared.SpectrumLayers[#shared.SpectrumLayers + 1] = gui
	return gui
end

env.windows = layer("windows", 10)
env.notes = layer("notes", 15)
env.modal = layer("modal", 20)
env.launcher = layer("launcher", 30)
env.splash = layer("splash", 40)

function env.viewport()
	local camera = Workspace.CurrentCamera
	local size = camera and camera.ViewportSize
	if not size or size.X < 64 or size.Y < 64 then
		return Vector2.new(1280, 720)
	end
	return size
end

S.env = env
