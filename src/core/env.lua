local S = ...

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local tws = game:GetService("TweenService")
local uis = game:GetService("UserInputService")

local env = {}
env.tws = tws
env.uis = uis
env.mobile = uis.TouchEnabled and not uis.KeyboardEnabled
env.playerGui = Players.LocalPlayer and Players.LocalPlayer:WaitForChild("PlayerGui")

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
sweep(env.playerGui)

local holder = CoreGui
do
	local probe = Instance.new("ScreenGui")
	local placed = pcall(function()
		probe.Parent = CoreGui
	end)
	if not placed then
		holder = env.playerGui
	end
	probe:Destroy()
end

local function layer(name, order)
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = order
	pcall(function()
		gui.ScreenInsets = Enum.ScreenInsets.None
	end)
	gui.Parent = holder
	return gui
end

env.windows = layer("Spectrum", 10)
env.notes = layer("SpectrumNotes", 15)
env.modal = layer("SpectrumModal", 20)

function env.viewport()
	local camera = Workspace.CurrentCamera
	return camera and camera.ViewportSize or Vector2.new(1280, 720)
end

S.env = env
