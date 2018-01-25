
--imgui over nw and cairo integration.
--Written by Cosmin Apreutesei. Public Domain.

if not ... then require'imgui_demo'; return end

local imgui = require'imgui'
local nw = require'nw'
local cairo = require'cairo'
local time = require'time'

local imgui_nw_cairo = {}

local app = nw:app()

local function fps_function()
	local count_per_sec = 2
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

function imgui_nw_cairo:bind_window(win, imgui_instance)

	local imgui = imgui_instance or imgui:new()

	--mouse state
	imgui.mousex = win:mouse'x' or 0
	imgui.mousey = win:mouse'y' or 0
	imgui.lbutton = win:mouse'left'
	imgui.rbutton = win:mouse'right'

	function imgui:window()
		return win
	end

	function win:imgui()
		return imgui
	end
	function imgui:render() end --stub, user app code event

	function imgui:_backend_render_frame()
		imgui:render()
		win:fire('imgui_render', imgui)
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

	function imgui:_backend_clock()
		return time.clock()
	end

	function imgui:_backend_keypressed(keyname)
		return app:key(keyname)
	end

	win:on('repaint', function(self)

		imgui.cw, imgui.ch = self:client_size()

		local bmp = self:bitmap()
		local cr = bmp:cairo()
		imgui.cr = cr

		imgui:_render_frame()

		--set the window title
		local title = imgui.title
			or string.format('Cairo %s', cairo.version_string())
		if imgui.continuous_rendering then
			title = string.format('%s - %d fps', title, fps())
		end
		self:title(title)

		--set the cursor
		self:cursor(imgui.cursor or 'arrow')

	end)

	win:on('mousemove', function(self, x, y)
		imgui.mousex = x
		imgui.mousey = y
		self:invalidate()
	end)

	local function mousemove(self, x, y)
		imgui.mousex = x
		imgui.mousey = y
		imgui.lbutton = self:mouse'left'
		imgui.rbutton = self:mouse'right'
		self:invalidate()
	end

	win:on('mousemove', mousemove)
	win:on('mouseenter', mousemove)

	win:on('mouseleave', function(self)
		self:invalidate()
	end)

	win:on('mousedown', function(self, button, x, y)
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

	win:on('mouseup', function(self, button, x, y)
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

	win:on('click', function(self, button, count, x, y)
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

	win:on('mousewheel', function(self, delta, x, y)
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
	win:on('keydown', function(self, key)
		key_event(self, key, true)
	end)
	win:on('keyup', function(self, key)
		key_event(self, key, false)
	end)
	win:on('keypress', function(self, key)
		key_event(self, key, true)
	end)

	local function key_char_event(self, char, down)
		imgui.char = down and char or nil
		self:invalidate()
	end
	win:on('keychar', function(self, char)
		key_char_event(self, char, true)
	end)

	app:runevery(0, function()
		if imgui.continuous_rendering or next(imgui.stopwatches) then
			win:invalidate()
		end
	end)

	return imgui
end

return imgui_nw_cairo
