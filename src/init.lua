local S = ...

local Library = {}
Library.Version = "3.0"

function Library:Design(props)
	return S.style.apply(props)
end

function Library:GetDesign()
	return S.style.copy()
end

function Library:Notify(title, body, duration, kind)
	return S.notify(title, body, duration, kind)
end

function Library:Window(title, opts)
	local win = S.window.new(title, opts)

	win.button = function(self, text, callback)
		return S.inputs.button(self, text, callback)
	end
	win.toggle = function(self, text, a, b)
		return S.inputs.toggle(self, text, a, b)
	end
	win.slider = function(self, text, min, max, default, callback, step)
		return S.inputs.slider(self, text, min, max, default, callback, step)
	end
	win.keybind = function(self, text, default, callback)
		return S.inputs.keybind(self, text, default, callback)
	end
	win.dropdown = function(self, text, options, default, callback, multi)
		return S.selects.dropdown(self, text, options, default, callback, multi)
	end
	win.colorpicker = function(self, text, default, callback)
		return S.selects.colorpicker(self, text, default, callback)
	end
	win.textbox = function(self, text, default, callback)
		return S.text.textbox(self, text, default, callback)
	end
	win.section = function(self, text)
		return S.text.section(self, text)
	end
	win.label = function(self, text)
		return S.text.label(self, text)
	end
	win.separator = function(self)
		return S.text.separator(self)
	end

	return win
end

function Library:Destroy()
	for _, root in ipairs(S.window.roots) do
		if root.Parent then
			root:Destroy()
		end
	end
	S.env.windows:Destroy()
	S.env.modal:Destroy()
	S.env.notes:Destroy()
end

S.library = Library
