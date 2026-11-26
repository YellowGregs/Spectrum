local S = ...

local env = S.env
local util = S.util
local style = S.style

local featurelist = {}
local entries = {}
local rows = {}
local shown = false

local function values()
	return style.values
end

local base_width = env.mobile and 164 or 184
local top_offset = env.mobile and 90 or 12
local pad_x = 10
local pad_right = 12
local pad_y = 7
local row_height = util.size(15)
local gap = 2

local function card_width()
	local view = env.viewport()
	return math.min(base_width, math.max(120, view.X - 24))
end

local card = util.new("Frame", {
	Name = "feature_list",
	BackgroundColor3 = values().panel,
	BackgroundTransparency = 0.12,
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, top_offset),
		Size = UDim2.fromOffset(card_width(), 0),
	Visible = false,
	ClipsDescendants = true,
	ZIndex = 2,
	Parent = env.notes,
})
util.corner(card, 4)
local edge = util.stroke(card, values().line, 0.35)

local content = util.new("Frame", {
	Name = "content",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(pad_x, pad_y),
	Size = UDim2.new(1, -(pad_x + pad_right), 0, 0),
	ZIndex = 2,
	Parent = card,
})
util.new("UIListLayout", {
	FillDirection = Enum.FillDirection.Vertical,
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	Padding = UDim.new(0, gap),
	Parent = content,
})

local bar = util.new("Frame", {
	Name = "edge",
	BackgroundColor3 = values().accent,
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -2, 0, 0),
	Size = UDim2.new(0, 2, 1, 0),
	ZIndex = 4,
	Parent = card,
})
util.corner(bar, 1)

local function hex(color)
	return string.format(
		"#%02X%02X%02X",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

local function escape(text)
	return tostring(text):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
end

local function line_text(entry)
	local line = '<b><font color="' .. hex(values().accent) .. '">' .. escape(entry.label) .. "</font></b>"
	if entry.value and entry.value ~= "" then
		line = line .. ' <font color="' .. hex(values().text) .. '">' .. escape(entry.value) .. "</font>"
	end
	return line
end

local function height()
	local count = #entries
	if count == 0 then
		return 0
	end
	return pad_y * 2 + count * row_height + math.max(0, count - 1) * gap
end

local function paint()
	card.BackgroundColor3 = values().panel
	edge.Color = values().line
	bar.BackgroundColor3 = values().accent
	for _, row in ipairs(rows) do
		if row.text.Parent then
			row.text.Text = line_text(row.entry)
		end
	end
end

local function clear()
	for _, row in ipairs(rows) do
		if row.text.Parent then
			row.text:Destroy()
		end
	end
	table.clear(rows)
end

local function build()
	clear()
	for index, entry in ipairs(entries) do
		local text = util.new("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, row_height),
			Font = values().font,
			Text = "",
			TextColor3 = values().text,
			TextSize = util.size(10),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
			RichText = true,
			LayoutOrder = index,
			ZIndex = 3,
			Parent = content,
		})
		rows[#rows + 1] = { entry = entry, text = text }
	end

	local total = height()
	card.Size = UDim2.fromOffset(card_width(), total)
	content.Size = UDim2.new(1, -(pad_x + pad_right), 0, math.max(0, total - pad_y * 2))
	card.Visible = shown and #entries > 0
	paint()
end

function featurelist.set(list)
	if type(list) == "string" then
		list = { list }
	end
	local next_entries = {}
	if type(list) == "table" then
		for _, item in ipairs(list) do
			local entry
			if type(item) == "string" then
				entry = { label = item }
			elseif type(item) == "table" then
				local label = item.label or item.name or item[1]
				local value = item.value
				if value == nil then
					value = item[2]
				end
				if label ~= nil then
					entry = {
						label = tostring(label),
						value = value ~= nil and tostring(value) or nil,
					}
				end
			end
			if entry then
				next_entries[#next_entries + 1] = entry
			end
		end
	end
	entries = next_entries
	shown = #entries > 0
	build()
	return featurelist.get()
end

function featurelist.visible(state)
	shown = state == true
	card.Visible = shown and #entries > 0
	return shown
end

function featurelist.get()
	local copy = {}
	for index, entry in ipairs(entries) do
		copy[index] = { label = entry.label, value = entry.value }
	end
	return copy, shown
end

style.paint(paint)
paint()

local camera_link
local function watch_viewport()
	if camera_link then
		camera_link:Disconnect()
		camera_link = nil
	end
	local camera = workspace.CurrentCamera
	if camera then
		camera_link = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if card.Parent then
				card.Size = UDim2.fromOffset(card_width(), height())
			end
		end)
	end
end
watch_viewport()
card.Destroying:Connect(function()
	if camera_link then
		camera_link:Disconnect()
		camera_link = nil
	end
end)

S.featurelist = featurelist
