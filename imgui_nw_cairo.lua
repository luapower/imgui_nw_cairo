
--imgui nw+cairo driver.
--Written by Cosmin Apreutesei. Public Domain.

if not ... then require'imgui_demo'; return end

local imgui = require'imgui'
local nw = require'nw'
local cairo = require'cairo'
local freetype = require'freetype'
local time = require'time'
local gfonts = require'gfonts'

local imgui_nw_cairo = {}

local app = nw:app()
local ft = freetype:new()

local function fps_function()
	local count_per_sec = 1
	local frame_count, last_frame_count, last_time = 0, 0
	return function()
		last_time = last_time or time.clock()
		frame_count = frame_count + 1
		local time = time.clock()
		if time - last_time > 1 / count_per_sec then
			last_frame_count, frame_count = frame_count, 0
			last_time = time
		end
		return last_frame_count * count_per_sec
	end
end

function imgui_nw_cairo:bind(win, imgui_class)

	local imgui = (imgui_class or imgui):new()

	function imgui:window()
		return win
	end

	function win:imgui()
		return imgui
	end

	function imgui:unbind()
		win:off'.imgui'
		win.imgui = nil
	end

	function imgui:_backend_clock()
		return time.clock()
	end

	function imgui:_backend_mouse_state()
		return
			win:mouse'x',
			win:mouse'y',
			win:mouse'left',
			win:mouse'right'
	end

	function imgui:_backend_key_state(keyname)
		return app:key(keyname)
	end

	function imgui:_backend_client_size()
		return win:client_size()
	end

	local fps = fps_function()

	function imgui:_backend_set_title(title)
		title = title or string.format('Cairo %s', cairo.version_string())
		if imgui.continuous_rendering then
			title = string.format('%s - %d fps', title, fps())
		end
		win:title(title)
	end

	function imgui:_backend_set_cursor(cursor)
		win:cursor(cursor or 'arrow')
	end

	function imgui:_backend_render_frame()
		win:fire('imgui_render', imgui)
	end

	win:on('repaint.imgui', function(self)
		local bmp = self:bitmap()
		local cr = bmp:cairo()
		imgui.cr = cr
		imgui:_render_frame(cr)
	end)

	--stub file-finding implementation based on gfonts module
	function win:imgui_find_font_file(name, weight, slant)
		return gfonts.font_file(name, weight, slant)
		--local file = string.format('media/fonts/%s.ttf', name)
	end

	local cache = {} --{name -> face}
	local cur_id, cur_face
	function imgui:_backend_load_font(name, weight, slant)
		if not name then
			self.cr:font_face(cairo.NULL)
			cur_id, cur_face = nil
			return
		end
		local id =
			name:lower() .. '|' ..
			tostring(weight):lower() .. '|'
			.. slant:lower()
		if cur_id == id then
			return
		end
		local face = cache[id]
		if face == nil then
			local file = win:imgui_find_font_file(name, weight, slant)
			if file then
				local ft_face = ft:face(file)
				face = cairo.ft_font_face(ft_face) -- TODO: weight, slant
				cache[id] = face
			else
				cache[id] = false
			end
		end
		if face then
			self.cr:font_face(face)
			cur_id, cur_face = id, face
		end
	end

	win:on('mousemove.imgui', function(self, x, y)
		imgui:_backend_event('_backend_mousemove', x, y)
		self:invalidate()
	end)

	win:on('mouseenter.imgui', function(self, x, y)
		imgui:_backend_event('_backend_mouseenter', x, y)
		self:invalidate()
	end)

	win:on('mouseleave.imgui', function(self)
		self:invalidate()
	end)

	win:on('mousedown.imgui', function(self, button, x, y)
		if button == 'left' then
			if not imgui.lbutton then
				imgui.lpressed = true
			end
			imgui.lbutton = true
			imgui.clicked = false
			self:invalidate()
		elseif button == 'right' then
			if not imgui.rbutton then
				imgui.rpressed = true
			end
			imgui.rbutton = true
			imgui.rightclick = false
			self:invalidate()
		end
	end)

	win:on('mouseup.imgui', function(self, button, x, y)
		if button == 'left' then
			imgui.lpressed = false
			imgui.lbutton = false
			imgui.clicked = true
			self:invalidate()
		elseif button == 'right' then
			imgui.rpressed = false
			imgui.rbutton = false
			imgui.rightclick = true
			self:invalidate()
		end
	end)

	win:on('click.imgui', function(self, button, count, x, y)
		if count == 2 then
			imgui.doubleclicked = true
			self:invalidate()
			if not imgui.tripleclicks then
				return true
			end
		elseif count == 3 then
			imgui.tripleclicked = true
			self:invalidate()
			return true
		end
	end)

	win:on('mousewheel.imgui', function(self, delta, x, y)
		imgui.wheel_delta = imgui.wheel_delta + (delta / 120 or 0)
		self:invalidate()
	end)

	local function key_event(self, key, down)
		imgui.key = down and key or nil
		imgui.shift = app:key'shift'
		imgui.ctrl = app:key'ctrl'
		imgui.alt = app:key'alt'
		self:invalidate()
	end
	win:on('keydown.imgui', function(self, key)
		key_event(self, key, true)
	end)
	win:on('keyup.imgui', function(self, key)
		key_event(self, key, false)
	end)
	win:on('keypress.imgui', function(self, key)
		key_event(self, key, true)
	end)

	local function key_char_event(self, char, down)
		imgui.char = down and char or nil
		self:invalidate()
	end
	win:on('keychar.imgui', function(self, char)
		key_char_event(self, char, true)
	end)

	app:runevery(0, function()
		if imgui.continuous_rendering or next(imgui.stopwatches) then
			win:invalidate()
		end
	end)

	return imgui
end

function imgui_nw_cairo:unbind(win)
	win:imgui():unbind()
end

return imgui_nw_cairo
