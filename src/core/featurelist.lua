local S = ...

local env = S.env
local util = S.util
local style = S.style
local config = S.config

local TextService = game:GetService("TextService")

local featurelist = {}
local manual = {}
local manual_mode = false
local features = {}
local feature_seq = 0
local attach_seq = 0
local entries = {}
local rows = {}
local exiting = {}
local shown = true
local all_mode = false
local left_mode = false
local scheduled = false
local sort_dirty = true
local last_order = {}
local visual_height = 0
local animation_time = 0.2
local dragging = false
local drag_moved = false
local drag_from
local drag_at

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
local row_transparency = 0.28
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
util.corner(rail, 2)

local function side_row(row)
	if left_mode then
		row.strip.AnchorPoint = Vector2.new(0, 0)
		row.strip.Position = UDim2.fromOffset(0, 0)
	else
		row.strip.AnchorPoint = Vector2.new(1, 0)
		row.strip.Position = UDim2.new(1, 0, 0, 0)
	end
end

local function apply_side()
	if left_mode then
		rail.AnchorPoint = Vector2.new(0, 0)
		rail.Position = UDim2.fromOffset(0, 0)
		content.Position = UDim2.fromOffset(rail_width + rail_gap, 0)
	else
		rail.AnchorPoint = Vector2.new(1, 0)
		rail.Position = UDim2.new(1, 0, 0, 0)
		content.Position = UDim2.fromOffset(0, 0)
	end
	content.Size = UDim2.new(1, -(rail_width + rail_gap), 1, 0)
	for _, row in ipairs(rows) do
		side_row(row)
	end
	for _, row in ipairs(exiting) do
		side_row(row)
	end
end

local function update_side(width, x)
	local view = env.viewport()
	width = width or card.Size.X.Offset
	x = x or card.Position.X.Offset
	local center = view.X + x - width / 2
	local left = center < view.X / 2
	if left ~= left_mode then
		left_mode = left
		apply_side()
	end
end

local function card_height()
	return math.max(card.Size.Y.Offset, visual_height)
end

local function clamp_position(width, height)
	local view = env.viewport()
	width = width or card.Size.X.Offset
	height = height or card_height()
	local x = math.clamp(card.Position.X.Offset, math.min(0, width - view.X), 0)
	local y = math.clamp(card.Position.Y.Offset, 0, math.max(0, view.Y - height))
	if x ~= card.Position.X.Offset or y ~= card.Position.Y.Offset then
		card.Position = UDim2.new(1, x, 0, y)
	end
	update_side(width, x)
end

local function remember()
	config.place_featurelist({
		x = card.Position.X.Offset,
		y = card.Position.Y.Offset,
	})
end

local drag = util.new("TextButton", {
	Name = "drag",
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
	Text = "",
	AutoButtonColor = false,
	Active = true,
	Selectable = false,
	ZIndex = 7,
	Parent = card,
})

local drag_begin = drag.InputBegan:Connect(function(input)
	local kind = input.UserInputType
	if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
		dragging = true
		drag_moved = false
		drag_from = input.Position
		drag_at = Vector2.new(card.Position.X.Offset, card.Position.Y.Offset)
	end
end)

local drag_move = env.uis.InputChanged:Connect(function(input)
	if not dragging then
		return
	end
	local kind = input.UserInputType
	if kind ~= Enum.UserInputType.MouseMovement and kind ~= Enum.UserInputType.Touch then
		return
	end
	local delta = input.Position - drag_from
	if delta.Magnitude < 1 then
		return
	end
	drag_moved = true
	local view = env.viewport()
	local width = card.Size.X.Offset
	local height = card_height()
	local x = math.clamp(drag_at.X + delta.X, math.min(0, width - view.X), 0)
	local y = math.clamp(drag_at.Y + delta.Y, 0, math.max(0, view.Y - height))
	card.Position = UDim2.new(1, x, 0, y)
	update_side(width, x)
end)

local drag_end = env.uis.InputEnded:Connect(function(input)
	local kind = input.UserInputType
	if dragging and (kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch) then
		dragging = false
		clamp_position()
		if drag_moved then
			remember()
		end
	end
end)

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

local function apply_row_layout(row, instant)
	local label_w, value_w, width = row_metrics(row.entry)
	row.label.Size = UDim2.fromOffset(label_w, row_height)
	row.value.Size = UDim2.fromOffset(value_w, row_height)
	row.value.Position = UDim2.fromOffset(pad_left + label_w + (value_w > 0 and label_gap or 0), 0)
	row.value.Visible = value_w > 0
	row.target_width = width
	if instant and not row.appearing then
		row.strip.Size = UDim2.fromOffset(width, row_height)
	end
end

local function height()
	local count = #entries
	if count == 0 then
		return 0
	end
	return count * row_height + (count - 1) * row_gap
end

local function place_row(row, index, animate)
	local target = UDim2.fromOffset(0, (index - 1) * (row_height + row_gap))
	if row.slot ~= index then
		row.slot = index
		if animate and row.root.Parent then
			util.tween(row.root, animation_time, { Position = target }, Enum.EasingStyle.Quint)
		else
			row.root.Position = target
		end
	end
end

local function update_corners()
	local count = #rows
	for index, row in ipairs(rows) do
		local top = index == 1 and 3 or 0
		local bottom = index == count and 3 or 0
		local corner = row.corner
		if corner then
			corner.TopLeftRadius = UDim.new(0, top)
			corner.TopRightRadius = UDim.new(0, top)
			corner.BottomLeftRadius = UDim.new(0, bottom)
			corner.BottomRightRadius = UDim.new(0, bottom)
		end
	end
end

local function grow_row(row)
	if not row.strip.Parent then
		return
	end
	row.appearing = true
	row.grow_token = (row.grow_token or 0) + 1
	local token = row.grow_token
	util.tween(row.strip, animation_time, {
		Size = UDim2.fromOffset(row.target_width or 0, row_height),
	}, Enum.EasingStyle.Quint)
	task.delay(animation_time, function()
		if row.grow_token == token then
			row.appearing = false
		end
	end)
end

local function resize(hold, animate)
	local total = height()
	local rail_total = total
	if hold then
		total = math.max(total, visual_height)
	end
	local width = card_width()
	local changed = total ~= visual_height or card.Size.X.Offset ~= width
	visual_height = total
	if changed then
		local target = UDim2.fromOffset(width, total)
		if animate and card.Parent then
			util.tween(card, animation_time, { Size = target }, Enum.EasingStyle.Quint)
		else
			util.cancel(card)
			card.Size = target
		end
	end
	content.Size = UDim2.new(1, -(rail_width + rail_gap), 1, 0)
	local rail_target = UDim2.new(0, rail_width, 0, rail_total)
	if animate and card.Parent then
		util.tween(rail, animation_time, { Size = rail_target }, Enum.EasingStyle.Quint)
	else
		util.cancel(rail)
		rail.Size = rail_target
	end
	card.Visible = shown and total > 0
	clamp_position(width, total)
end

local function remove_exiting(row)
	for index, item in ipairs(exiting) do
		if item == row then
			table.remove(exiting, index)
			return
		end
	end
end

local function cancel_exit(row)
	if not row.removing then
		return
	end
	row.removing = false
	row.exit_token = (row.exit_token or 0) + 1
	remove_exiting(row)
	util.cancel(row.strip)
	util.cancel(row.label)
	util.cancel(row.value)
	row.root.ZIndex = 3
	row.strip.ZIndex = 3
	row.label.ZIndex = 3
	row.value.ZIndex = 3
	row.strip.BackgroundTransparency = row_transparency
	row.label.TextTransparency = 0
	row.value.TextTransparency = 0
	row.appearing = true
end

local function start_exit(row)
	if row.removing then
		return
	end
	row.removing = true
	row.appearing = false
	row.grow_token = (row.grow_token or 0) + 1
	row.exit_token = (row.exit_token or 0) + 1
	row.root.ZIndex = 2
	row.strip.ZIndex = 2
	row.label.ZIndex = 2
	row.value.ZIndex = 2
	local token = row.exit_token
	exiting[#exiting + 1] = row
	util.cancel(row.strip)
	util.tween(row.strip, animation_time, {
		Size = UDim2.fromOffset(0, row_height),
		BackgroundTransparency = 1,
	}, Enum.EasingStyle.Quint)
	util.tween(row.label, animation_time, { TextTransparency = 1 }, Enum.EasingStyle.Quint)
	util.tween(row.value, animation_time, { TextTransparency = 1 }, Enum.EasingStyle.Quint)
	task.delay(animation_time, function()
		if row.exit_token ~= token or not row.removing then
			return
		end
		row.removing = false
		remove_exiting(row)
		if row.root.Parent then
			row.root:Destroy()
		end
		if card.Parent and #exiting == 0 then
			resize(false, true)
		end
	end)
end

local function paint()
	rail.BackgroundColor3 = values().accent
	for _, row in ipairs(rows) do
		side_row(row)
		row.root.ZIndex = 3
		row.strip.ZIndex = 3
		row.label.ZIndex = 3
		row.value.ZIndex = 3
		row.strip.BackgroundColor3 = values().panel
		row.strip.BackgroundTransparency = row_transparency
		row.label.Font = values().font_medium
		row.label.TextColor3 = values().accent
		row.label.TextTransparency = 0
		row.value.Font = values().font
		row.value.TextColor3 = values().text
		row.value.TextTransparency = 0
		apply_row_layout(row, true)
		if row.appearing then
			grow_row(row)
		end
	end
end

local function collect()
	if manual_mode then
		local out = {}
		for index, item in ipairs(manual) do
			local entry = {
				label = item.label,
				value = item.value,
				id = "manual:" .. index,
				seq = index,
			}
			entry.width = select(3, row_metrics(entry))
			out[#out + 1] = entry
		end
		return out
	end

	local candidates = {}
	local has_explicit = false
	for _, feature in pairs(features) do
		local ok, value = pcall(feature.getter)
		if ok then
			local entry = normalize(value, feature.label)
			if entry then
				entry.id = feature.id
				entry.seq = feature.seq
				entry.order = feature.order
				entry.explicit_order = feature.explicit_order
				entry.width = select(3, row_metrics(entry))
				candidates[#candidates + 1] = entry
				if feature.explicit_order ~= nil then
					has_explicit = true
				end
			end
		end
	end

	local same_set = #last_order == #candidates
	if same_set then
		local present = {}
		for _, id in ipairs(last_order) do
			present[id] = true
		end
		for _, entry in ipairs(candidates) do
			if not present[entry.id] then
				same_set = false
				break
			end
		end
	end

	local function by_width(list)
		table.sort(list, function(a, b)
			if a.width ~= b.width then
				return a.width > b.width
			end
			return a.seq < b.seq
		end)
	end

	local function by_last(list)
		local position = {}
		for index, id in ipairs(last_order) do
			position[id] = index
		end
		table.sort(list, function(a, b)
			local pa = position[a.id] or math.huge
			local pb = position[b.id] or math.huge
			if pa ~= pb then
				return pa < pb
			end
			return a.seq < b.seq
		end)
	end

	if has_explicit then
		local explicit_list = {}
		local auto_list = {}
		for _, entry in ipairs(candidates) do
			if entry.explicit_order ~= nil then
				explicit_list[#explicit_list + 1] = entry
			else
				auto_list[#auto_list + 1] = entry
			end
		end
		table.sort(explicit_list, function(a, b)
			if a.explicit_order ~= b.explicit_order then
				return a.explicit_order < b.explicit_order
			end
			return a.seq < b.seq
		end)
		if sort_dirty or not same_set then
			by_width(auto_list)
			sort_dirty = false
		else
			by_last(auto_list)
		end
		local merged = {}
		for _, entry in ipairs(explicit_list) do
			merged[#merged + 1] = entry
		end
		for _, entry in ipairs(auto_list) do
			merged[#merged + 1] = entry
		end
		candidates = merged
	else
		if sort_dirty or not same_set then
			by_width(candidates)
			sort_dirty = false
		else
			by_last(candidates)
		end
	end

	local ids = {}
	for index, entry in ipairs(candidates) do
		ids[index] = entry.id
	end
	last_order = ids
	return candidates
end

local function create_row(entry)
	local root = util.new("Frame", {
		Name = "feature_row",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, row_height),
		ZIndex = 3,
		Parent = content,
	})
	local strip = util.new("Frame", {
		Name = "strip",
		BackgroundColor3 = values().panel,
		BackgroundTransparency = row_transparency,
		BorderSizePixel = 0,
		AnchorPoint = left_mode and Vector2.new(0, 0) or Vector2.new(1, 0),
		Position = left_mode and UDim2.fromOffset(0, 0) or UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(0, row_height),
		ClipsDescendants = true,
		ZIndex = 3,
		Parent = root,
	})
	local corner = util.new("UICorner", {
		CornerRadius = UDim.new(0, 0),
		Parent = strip,
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
		id = entry.id,
		entry = entry,
		root = root,
		strip = strip,
		corner = corner,
		label = label,
		value = value,
		appearing = false,
		removing = false,
		exit_token = 0,
		grow_token = 0,
	}
end

local function build()
	if not card.Parent then
		return
	end
	local next_entries = collect()
	local all = {}
	for _, row in ipairs(rows) do
		all[row.id] = row
	end
	for _, row in ipairs(exiting) do
		all[row.id] = row
	end

	local used = {}
	local next_rows = {}
	for index, entry in ipairs(next_entries) do
		local row = all[entry.id]
		if row then
			used[row] = true
			if row.removing then
				cancel_exit(row)
			end
			row.entry = entry
			row.label.Text = entry.label
			row.value.Text = entry.value or ""
			apply_row_layout(row, not row.appearing)
			next_rows[#next_rows + 1] = row
		else
			row = create_row(entry)
			row.entry = entry
			apply_row_layout(row, false)
			row.strip.Size = UDim2.fromOffset(0, row_height)
			row.root.Position = UDim2.fromOffset(0, (index - 1) * (row_height + row_gap))
			row.slot = index
			row.appearing = true
			next_rows[#next_rows + 1] = row
		end
	end

	for _, row in ipairs(rows) do
		if not used[row] then
			start_exit(row)
		end
	end

	rows = next_rows
	entries = next_entries
	update_corners()
	resize(#exiting > 0, true)
	paint()
	for index, row in ipairs(rows) do
		place_row(row, index, true)
	end
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
	sort_dirty = true
	if manual_mode then
		shown = true
	end
	build()
	return featurelist.get()
end

function featurelist.enabled(opts, auto)
	local spec = type(opts) == "table" and opts.feature
	if spec == false then
		return false
	end
	return auto == true or spec ~= nil or all_mode
end

function featurelist.bind(id, label, getter, opts)
	if type(id) ~= "string" or id == "" or type(getter) ~= "function" then
		return nil
	end
	opts = type(opts) == "table" and opts or {}
	feature_seq = feature_seq + 1
	local explicit = tonumber(opts.order)
	features[id] = {
		id = id,
		label = tostring(label or id),
		getter = getter,
		opts = opts,
		explicit_order = explicit,
		order = explicit or feature_seq,
		seq = feature_seq,
	}
	sort_dirty = true
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
	if spec == false then
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
	return featurelist.bind(id, name, function()
		if not featurelist.enabled(opts, auto) then
			return nil
		end
		return getter()
	end, {
		order = settings.order,
		kind = kind,
	})
end

function featurelist.unbind(id)
	if features[id] then
		features[id] = nil
		sort_dirty = true
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

function featurelist.touch_if(opts, auto)
	if featurelist.enabled(opts, auto) then
		featurelist.touch()
	end
end

function featurelist.all(state)
	if state ~= nil and state ~= all_mode then
		all_mode = state == true
		sort_dirty = true
		build()
	end
	return all_mode
end

function featurelist.restore()
	local saved = config.featurelist_state()
	if type(saved) == "table" and type(saved.x) == "number" and type(saved.y) == "number" then
		card.Position = UDim2.new(1, saved.x, 0, saved.y)
	end
	clamp_position()
end

function featurelist.visible(state)
	shown = state == true
	card.Visible = shown and visual_height > 0
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
apply_side()

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
				resize(#exiting > 0, false)
				paint()
			end
		end)
	end
end
watch_viewport()
card.Destroying:Connect(function()
	dragging = false
	if camera_link then
		camera_link:Disconnect()
		camera_link = nil
	end
	if drag_begin then
		drag_begin:Disconnect()
		drag_begin = nil
	end
	if drag_move then
		drag_move:Disconnect()
		drag_move = nil
	end
	if drag_end then
		drag_end:Disconnect()
		drag_end = nil
	end
end)

S.featurelist = featurelist
