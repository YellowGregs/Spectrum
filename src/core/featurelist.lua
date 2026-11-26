local S = ...

local env = S.env
local util = S.util
local style = S.style

local TextService = game:GetService("TextService")

local featurelist = {}
local manual = {}
local manual_mode = false
local features = {}
local feature_seq = 0
local attach_seq = 0
local entries = {}
local rows = {}
local shown = true
local scheduled = false

local function values()
	return style.values
end

local base_width = env.mobile and 220 or 260
local top_offset = env.mobile and 90 or 12
local right_margin = 12
local rail_width = 4
local rail_gap = 0
local row_height = util.size(20)
local row_gap = 0
local pad_left = env.mobile and 9 or 10
local pad_right = env.mobile and 8 or 10
local label_gap = 6
local text_size = util.size(13)
local value_size = util.size(13)

local function card_width()
	local view = env.viewport()
	return math.min(base_width, math.max(160, view.X - 24))
end

local function max_row_width()
	return math.max(80, card_width() - rail_width - rail_gap)
end

local card = util.new("Frame", {
	Name = "feature_list",
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -right_margin, 0, top_offset),
	Size = UDim2.fromOffset(card_width(), 0),
	Visible = false,
	ClipsDescendants = true,
	ZIndex = 2,
	Parent = env.notes,
})

local content = util.new("Frame", {
	Name = "content",
	BackgroundTransparency = 1,
	Size = UDim2.new(1, -(rail_width + rail_gap), 1, 0),
	ZIndex = 2,
	Parent = card,
})
util.new("UIListLayout", {
	FillDirection = Enum.FillDirection.Vertical,
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	VerticalAlignment = Enum.VerticalAlignment.Top,
	Padding = UDim.new(0, row_gap),
	Parent = content,
})

local rail = util.new("Frame", {
	Name = "rail",
	BackgroundColor3 = values().accent,
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 0),
	Size = UDim2.new(0, rail_width, 1, 0),
	ZIndex = 4,
	Parent = card,
})

local function shorten(value)
	local text = tostring(value):gsub("%s+", " ")
	if #text > 22 then
		text = string.sub(text, 1, 20) .. "..."
	end
	return text
end

local function normalize(value, label)
	if value == nil or value == false then
		return nil
	end
	if type(value) == "table" then
		if value.active == false then
			return nil
		end
		local text = value.value
		if text == nil then
			text = value.text
		end
		local name = value.label or label
		if name == nil then
			return nil
		end
		return {
			label = tostring(name),
			value = text ~= nil and shorten(text) or nil,
		}
	end
	if value == true then
		if label == nil then
			return nil
		end
		return { label = tostring(label) }
	end
	if type(value) == "string" or type(value) == "number" then
		local text = shorten(value)
		if text == "" or label == nil then
			return nil
		end
		return { label = tostring(label), value = text }
	end
	return nil
end

local measured = {}
local measured_count = 0

local function measure(text, size, font)
	local value = tostring(text)
	if value == "" then
		return 0
	end
	local key = tostring(font) .. "|" .. tostring(size) .. "|" .. value
	local cached = measured[key]
	if cached then
		return cached
	end
	local width
	local ok, box = pcall(function()
		return TextService:GetTextSize(value, size, font, Vector2.new(2048, 128))
	end)
	if ok and typeof(box) == "Vector2" then
		width = math.ceil(box.X)
	else
		width = math.ceil(#value * size * 0.56)
	end
	if measured_count >= 512 then
		table.clear(measured)
		measured_count = 0
	end
	measured[key] = width
	measured_count = measured_count + 1
	return width
end

local function row_metrics(entry)
	local available = max_row_width() - pad_left - pad_right
	local label_w = measure(entry.label, text_size, values().font_medium)
	local value_w = entry.value and measure(entry.value, value_size, values().font) or 0
	if value_w > 0 then
		value_w = math.min(value_w, math.max(20, available - label_gap - 36))
		label_w = math.min(label_w, math.max(20, available - label_gap - value_w))
	else
		label_w = math.min(label_w, math.max(20, available))
	end
	local width = pad_left + label_w + (value_w > 0 and (label_gap + value_w) or 0) + pad_right
	return label_w, value_w, math.min(width, max_row_width())
end

local function layout_row(row)
	local label_w, value_w, width = row_metrics(row.entry)
	row.strip.Size = UDim2.fromOffset(width, row_height)
	row.label.Size = UDim2.fromOffset(label_w, row_height)
	row.value.Size = UDim2.fromOffset(value_w, row_height)
	row.value.Position = UDim2.fromOffset(pad_left + label_w + (value_w > 0 and label_gap or 0), 0)
	row.value.Visible = value_w > 0
end

local function height()
	local count = #entries
	if count == 0 then
		return 0
	end
	return count * row_height + (count - 1) * row_gap
end

local function resize()
	local total = height()
	card.Size = UDim2.fromOffset(card_width(), total)
	content.Size = UDim2.new(1, -(rail_width + rail_gap), 1, 0)
	card.Visible = shown and #entries > 0
end

local function paint()
	rail.BackgroundColor3 = values().accent
	for _, row in ipairs(rows) do
		row.strip.BackgroundColor3 = values().panel
		row.label.Font = values().font_medium
		row.label.TextColor3 = values().accent
		row.value.Font = values().font
		row.value.TextColor3 = values().text
		layout_row(row)
	end
end

local function clear()
	for _, row in ipairs(rows) do
		if row.root.Parent then
			row.root:Destroy()
		end
	end
	table.clear(rows)
end

local function collect()
	local out = {}
	if manual_mode then
		for _, entry in ipairs(manual) do
			out[#out + 1] = entry
		end
		return out
	end

	local ordered = {}
	for _, feature in pairs(features) do
		ordered[#ordered + 1] = feature
	end
	table.sort(ordered, function(a, b)
		if a.order ~= b.order then
			return a.order < b.order
		end
		return a.seq < b.seq
	end)
	for _, feature in ipairs(ordered) do
		local ok, value = pcall(feature.getter)
		if ok then
			local entry = normalize(value, feature.label)
			if entry then
				out[#out + 1] = entry
			end
		end
	end
	return out
end

local function same_structure(a, b)
	if #a ~= #b then
		return false
	end
	for index = 1, #a do
		if a[index].label ~= b[index].label then
			return false
		end
	end
	return true
end

local function create_row(entry, index)
	local root = util.new("Frame", {
		Name = "feature_row",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, row_height),
		LayoutOrder = index,
		ZIndex = 3,
		Parent = content,
	})
	local strip = util.new("Frame", {
		Name = "strip",
		BackgroundColor3 = values().panel,
		BackgroundTransparency = 0.28,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(0, row_height),
		ZIndex = 3,
		Parent = root,
	})
	local label = util.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(pad_left, 0),
		Size = UDim2.fromOffset(0, row_height),
		Font = values().font_medium,
		Text = entry.label,
		TextColor3 = values().accent,
		TextSize = text_size,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0.72,
		ZIndex = 3,
		Parent = strip,
	})
	local value = util.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(pad_left, 0),
		Size = UDim2.fromOffset(0, row_height),
		Font = values().font,
		Text = entry.value or "",
		TextColor3 = values().text,
		TextSize = value_size,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0.8,
		Visible = false,
		ZIndex = 3,
		Parent = strip,
	})
	return {
		root = root,
		strip = strip,
		label = label,
		value = value,
		entry = entry,
	}
end

local function update_rows()
	for index, entry in ipairs(entries) do
		local row = rows[index]
		if row then
			row.entry = entry
			row.label.Text = entry.label
			row.value.Text = entry.value or ""
		end
	end
	paint()
end

local function build()
	if not card.Parent then
		return
	end
	local next_entries = collect()
	if #rows > 0 and same_structure(entries, next_entries) then
		entries = next_entries
		update_rows()
		resize()
		return
	end

	entries = next_entries
	clear()
	if #entries == 0 then
		resize()
		return
	end
	for index, entry in ipairs(entries) do
		rows[#rows + 1] = create_row(entry, index)
	end
	resize()
	paint()
end

function featurelist.set(list)
	if type(list) == "string" then
		list = { list }
	end
	local next_manual = {}
	if type(list) == "table" then
		for _, item in ipairs(list) do
			local label
			local value
			if type(item) == "string" then
				label = item
			elseif type(item) == "table" then
				label = item.label or item.name or item[1]
				value = item.value
				if value == nil then
					value = item[2]
				end
			end
			if label ~= nil then
				next_manual[#next_manual + 1] = {
					label = tostring(label),
					value = value ~= nil and shorten(value) or nil,
				}
			end
		end
	end
	manual = next_manual
	manual_mode = #manual > 0
	if manual_mode then
		shown = true
	end
	build()
	return featurelist.get()
end

function featurelist.bind(id, label, getter, opts)
	if type(id) ~= "string" or id == "" or type(getter) ~= "function" then
		return nil
	end
	opts = type(opts) == "table" and opts or {}
	feature_seq = feature_seq + 1
	features[id] = {
		id = id,
		label = tostring(label or id),
		getter = getter,
		opts = opts,
		order = tonumber(opts.order) or feature_seq,
		seq = feature_seq,
	}
	build()
	return {
		id = id,
		Update = function()
			featurelist.touch()
		end,
		Remove = function()
			featurelist.unbind(id)
		end,
	}
end

function featurelist.attach(win, kind, label, opts, getter, auto)
	local spec = type(opts) == "table" and opts.feature
	if spec == false or (not spec and not auto) then
		return nil
	end
	local settings = type(spec) == "table" and spec or {}
	local name = type(spec) == "string" and spec or settings.label or label
	attach_seq = attach_seq + 1
	local id = tostring(win and win._key or "window")
		.. "/"
		.. tostring(kind or "feature")
		.. "/"
		.. tostring(label)
		.. "/"
		.. attach_seq
	return featurelist.bind(id, name, getter, {
		order = settings.order,
		kind = kind,
	})
end

function featurelist.unbind(id)
	if features[id] then
		features[id] = nil
		build()
	end
end

function featurelist.touch()
	if scheduled then
		return
	end
	scheduled = true
	task.defer(function()
		scheduled = false
		if card.Parent then
			build()
		end
	end)
end

function featurelist.visible(state)
	shown = state == true
	card.Visible = shown and #entries > 0
	return shown
end

function featurelist.get()
	local copy = {}
	for index, entry in ipairs(entries) do
		copy[index] = {
			label = entry.label,
			value = entry.value,
		}
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
				resize()
				paint()
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
