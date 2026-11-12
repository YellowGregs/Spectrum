local S = ...

local env = S.env
local util = S.util
local style = S.style
local brand = S.brand
local bold = Enum.Font.GothamBold
local font = Enum.Font.GothamMedium
local splash = {}

local function values()
	return style.values
end

function splash.mount()
	if not env.splash then
		return nil
	end

	local gui = util.new("TextButton", {
		Name = "startup_splash",
		BackgroundColor3 = values().background,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		ZIndex = 1,
		Parent = env.splash,
	})

	local card_w = env.mobile and 194 or 218
	local card_h = env.mobile and 224 or 242
	local card = util.new("Frame", {
		Name = "splash_card",
		BackgroundColor3 = values().panel,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(card_w, card_h),
		ZIndex = 3,
		Parent = gui,
	})
	local edge = util.stroke(card, values().line, 0.15)
	util.shadow(card, 22, 0.35)
	local scale = util.new("UIScale", { Scale = 0.9, Parent = card })

	local plate_size = env.mobile and 100 or 112
	local plate = util.new("Frame", {
		Name = "logo_plate",
		BackgroundColor3 = values().hover,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, env.mobile and 15 or 18),
		Size = UDim2.fromOffset(plate_size, plate_size),
		ZIndex = 4,
		Parent = card,
	})
	util.corner(plate, plate_size / 2)
	local plate_edge = util.stroke(plate, values().line, 0.35)

	local logo = brand and brand.logo()
	local fallback_label
	if logo then
		local image = util.new("ImageLabel", {
			Name = "logo",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(plate_size - 8, plate_size - 8),
			Image = logo,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 5,
			Parent = plate,
		})
		image.ImageColor3 = Color3.new(1, 1, 1)
	else
		local fallback = util.new("Frame", {
			Name = "logo_fallback",
			BackgroundColor3 = values().raised,
			BackgroundTransparency = 0.05,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(plate_size - 16, plate_size - 16),
			ZIndex = 5,
			Parent = plate,
		})
		util.corner(fallback, (plate_size - 16) / 2)
		fallback_label = util.new("TextLabel", {
			BackgroundTransparency = 1,
			Font = bold,
			Size = UDim2.fromScale(1, 1),
			Text = "AF",
			TextColor3 = values().text,
			TextSize = util.size(22),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			ZIndex = 6,
			Parent = fallback,
		})
	end

	local title_y = (env.mobile and 15 or 18) + plate_size + (env.mobile and 8 or 10)
	local title = util.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, title_y),
		Size = UDim2.new(1, 0, 0, 18),
		Font = bold,
		Text = "AdvanceFalling",
		TextColor3 = values().text,
		TextSize = util.size(15),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 4,
		Parent = card,
	})
	local subtitle = util.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, title_y + 20),
		Size = UDim2.new(1, 0, 0, 12),
		Font = font,
		Text = "SPECTRUM",
		TextColor3 = values().muted,
		TextSize = util.size(9),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 4,
		Parent = card,
	})

	local rail_y = card_h - (env.mobile and 38 or 42)
	local rail = util.new("Frame", {
		Name = "splash_progress",
		BackgroundColor3 = values().line,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, rail_y),
		Size = UDim2.fromOffset(card_w - 48, 2),
		ZIndex = 4,
		Parent = card,
	})
	local fill = util.new("Frame", {
		BackgroundColor3 = values().accent,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 5,
		Parent = rail,
	})

	util.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, rail_y + 12),
		Size = UDim2.new(1, 0, 0, 12),
		Font = font,
		Text = "Loading UI",
		TextColor3 = values().muted,
		TextSize = util.size(9),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 4,
		Parent = card,
	})

	local closed = false
	local function dismiss()
		if closed then
			return
		end
		closed = true
		S.splash_open = false
		util.tween(gui, 0.26, { BackgroundTransparency = 1 })
		util.tween(card, 0.26, { BackgroundTransparency = 1 })
		for _, item in ipairs(card:GetDescendants()) do
			if item:IsA("TextLabel") then
				util.tween(item, 0.26, { TextTransparency = 1 })
			elseif item:IsA("ImageLabel") then
				util.tween(item, 0.26, { ImageTransparency = 1 })
			elseif item:IsA("Frame") then
				util.tween(item, 0.26, { BackgroundTransparency = 1 })
			elseif item:IsA("UIStroke") then
				util.tween(item, 0.26, { Transparency = 1 })
			end
		end
		task.delay(0.3, function()
			if gui.Parent then
				gui:Destroy()
			end
		end)
	end

	util.tween(scale, 0.34, { Scale = 1 }, Enum.EasingStyle.Back)
	util.tween(fill, 1.45, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Linear)
	style.paint(function()
		if closed then
			return
		end
		gui.BackgroundColor3 = values().background
		card.BackgroundColor3 = values().panel
		plate.BackgroundColor3 = values().hover
		plate_edge.Color = values().line
		edge.Color = values().line
		title.TextColor3 = values().text
		subtitle.TextColor3 = values().muted
		rail.BackgroundColor3 = values().line
		fill.BackgroundColor3 = values().accent
		for _, item in ipairs(card:GetDescendants()) do
			if item:IsA("TextLabel") and item ~= title and item ~= subtitle and item ~= fallback_label then
				item.TextColor3 = values().muted
			end
		end
	end)

	gui.Activated:Connect(dismiss)
	task.delay(1.75, dismiss)
	S.splash_open = true

	return {
		Gui = gui,
		dismiss = dismiss,
		destroy = function()
			S.splash_open = false
			closed = true
			if gui.Parent then
				gui:Destroy()
			end
		end,
	}
end

S.splash = splash
