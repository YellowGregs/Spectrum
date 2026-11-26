local S = ...

local env = S.env
local util = S.util
local style = S.style

local featurelist = {}
local manual = {}
local manual_mode = false
local features = {}
local feature_seq = 0
local attach_seq = 0
local entries = {}
local rows = {}
local header_root
local header_title
local header_count
local header_tick
local header_line
local shown = true
local scheduled = false

local function values()
	return style.values
end

local base_width = env.mobile and 190 or 216
local top_offset = env.mobile and 90 or 12
local pad_x = 10
local pad_right = 14
local pad_y = 8
local row_height = util.size(17)
local header_height = util.size(18)
local divider_height = 1
local gap = 1
local value_width = env.mobile and 68 or 78

local function card_width()
	local view = env.viewport()
	return math.min(base_width, math.max(150, view.X - 24))
end

local card = util.new("Frame", {
	Name = "feature_list",
	BackgroundColor3 = values().panel,
	BackgroundTransparency = 0.06,
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, top_offset),
	Size = UDim2.fromOffset(card_width(), 0),
	Visible = false,
	ClipsDescendants = true,
	ZIndex = 2,
	Parent = env.notes,
})
util.corner(card, 5)
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

local function height()
	local count = #entries
	if count == 0 then
		return 0
	end
	return pad_y * 2
		+ header_height
		+ divider_height
		+ count * row_height
		+ (count + 1) * gap
end

local function paint()
	card.BackgroundColor3 = values().panel
	edge.Color = values().line
	bar.BackgroundColor3 = values().accent
	if header_title then
		header_title.TextColor3 = values().muted
		header_count.TextColor3 = values().accent
		header_tick.BackgroundColor3 = values().accent
		header_line.BackgroundColor3 = values().line
	end
	for _, row in ipairs(rows) do
		row.dot.BackgroundColor3 = values().accent
		row.label.TextColor3 = values().text
		row.value.TextColor3 = values().text
	end
end

local function clear()
	for _, row in ipairs(rows) do
		if row.root.Parent then
			row.root:Destroy()
		end
	end
	table.clear(rows)
	if header_root and header_root.Parent then
		header_root:Destroy()
	end
	if header_line and header_line.Parent then
		header_line:Destroy()
	end
	header_root = nil
	header_line = nil
	header_title = nil
	header_count = nil
	header_tick = nil
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
		LayoutOrder = index + 1,
		ZIndex = 3,
		Parent = content,
	})
	local dot = util.new("Frame", {
		BackgroundColor3 = values().accent,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(3, 3),
		ZIndex = 3,
		Parent = root,
	})
	util.corner(dot, 1)
	local has_value = entry.value ~= nil
	local label = util.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(9, 0),
		Size = has_value and UDim2.new(1, -(value_width + 12), 1, 0) or UDim2.new(1, -12, 1, 0),
		Font = values().font,
		Text = entry.label,
		TextColor3 = values().text,
		TextSize = util.size(10),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = root,
	})
	local value = util.new("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(value_width, row_height),
		Font = values().font_mono,
		Text = entry.value or "",
		TextColor3 = values().text,
		TextSize = util.size(10),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Visible = has_value,
		ZIndex = 3,
		Parent = root,
	})
	return {
		root = root,
		dot = dot,
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
			row.value.Visible = entry.value ~= nil
			row.label.Size = entry.value ~= nil
				and UDim2.new(1, -(value_width + 12), 1, 0)
				or UDim2.new(1, -12, 1, 0)
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
		local total = height()
		card.Size = UDim2.fromOffset(card_width(), total)
		content.Size = UDim2.new(1, -(pad_x + pad_right), 0, math.max(0, total - pad_y * 2))
		card.Visible = shown and #entries > 0
		return
	end

	entries = next_entries
	clear()
	if #entries == 0 then
		card.Size = UDim2.fromOffset(card_width(), 0)
		card.Visible = false
		return
	end

	header_root = util.new("Frame", {
		Name = "feature_header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, header_height),
		LayoutOrder = 0,
		ZIndex = 3,
		Parent = content,
	})
	header_tick = util.new("Frame", {
		BackgroundColor3 = values().accent,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.fromOffset(2, 10),
		ZIndex = 3,
		Parent = header_root,
	})
	header_title = util.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(9, 0),
		Size = UDim2.new(1, -44, 1, 0),
		Font = values().font_bold,
		Text = "FEATURES",
		TextColor3 = values().muted,
		TextSize = util.size(9),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 3,
		Parent = header_root,
	})
	header_count = util.new("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(30, header_height),
		Font = values().font_mono,
		Text = tostring(#entries),
		TextColor3 = values().accent,
		TextSize = util.size(9),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 3,
		Parent = header_root,
	})
	header_line = util.new("Frame", {
		BackgroundColor3 = values().line,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, divider_height),
		LayoutOrder = 1,
		ZIndex = 3,
		Parent = content,
	})
	for index, entry in ipairs(entries) do
		rows[#rows + 1] = create_row(entry, index)
	end

	local total = height()
	card.Size = UDim2.fromOffset(card_width(), total)
	content.Size = UDim2.new(1, -(pad_x + pad_right), 0, math.max(0, total - pad_y * 2))
	card.Visible = shown
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
				local total = height()
				card.Size = UDim2.fromOffset(card_width(), total)
				content.Size = UDim2.new(1, -(pad_x + pad_right), 0, math.max(0, total - pad_y * 2))
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
