local S = ...

local env = S.env
local util = S.util
local modal = {}

modal.gui = env.modal
modal.current = nil

local blocker = util.new("TextButton", {
	Name = "blocker",
	BackgroundTransparency = 1,
	Text = "",
	AutoButtonColor = false,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
	ZIndex = 1,
	Parent = env.modal,
})
modal.blocker = blocker

function modal.dismiss()
	local closer = modal.current
	modal.current = nil
	blocker.Visible = false
	if closer then
		closer()
	end
end

function modal.claim(closer)
	local previous = modal.current
	modal.current = nil
	if previous then
		previous()
	end
	modal.current = closer
	blocker.Visible = true
end

function modal.drop(closer)
	if modal.current == closer then
		modal.current = nil
		blocker.Visible = false
	end
end

blocker.Activated:Connect(modal.dismiss)
S.modal = modal
