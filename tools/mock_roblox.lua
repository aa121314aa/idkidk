--[==[
	Nova GUI  ·  模拟 Roblox 环境（开发/自测用，不属于运行时代码）

	配合 tools/mocktest.py + lupa 在本机跑一遍整个库，
	用来抓运行时错误：拼错的属性名、nil 调用、事件接线错误等。

	用法：python3 tools/mocktest.py
]==]

local Mock = {}

-- 屏幕大小（测试里可以改）
Mock.Screen = {X = 1920, Y = 1080}   -- 真正的 Vector2 在下面定义后会被替换

--[[ 基础类型 ]]

local function struct(fields)
	local mt = {}
	mt.__index = mt

	function mt.__tostring(self)
		local parts = {}
		for _, key in ipairs(fields) do
			parts[#parts + 1] = key .. '=' .. tostring(self[key])
		end

		return '(' .. table.concat(parts, ', ') .. ')'
	end

	return function(...)
		local values = {...}
		local self = {}
		for index, key in ipairs(fields) do
			self[key] = values[index] or 0
		end

		return setmetatable(self, mt)
	end
end

UDim = {new = struct({'Scale', 'Offset'})}
UDim2 = {}
function UDim2.new(xScale, xOffset, yScale, yOffset)
	return {X = UDim.new(xScale or 0, xOffset or 0), Y = UDim.new(yScale or 0, yOffset or 0)}
end
function UDim2.fromOffset(x, y)
	return UDim2.new(0, x, 0, y)
end
function UDim2.fromScale(x, y)
	return UDim2.new(x, 0, y, 0)
end

-- 补一些 Roblox 有而 LuaJIT 没有的全局
function tick()
	return os.clock()
end

Vector2 = {}
local Vector2MT = {}
Vector2MT.__index = Vector2MT
function Vector2MT.__sub(a, b)
	return Vector2.new(a.X - b.X, a.Y - b.Y)
end
function Vector2MT.__add(a, b)
	return Vector2.new(a.X + b.X, a.Y + b.Y)
end
function Vector2MT.__tostring(self)
	return string.format('(%g, %g)', self.X, self.Y)
end

function Vector2.new(x, y)
	local self = setmetatable({X = x or 0, Y = y or 0}, Vector2MT)
	self.Magnitude = math.sqrt((self.X ^ 2) + (self.Y ^ 2))

	return self
end

Vector3 = {}
local Vector3MT = {}
Vector3MT.__index = Vector3MT
function Vector3.new(x, y, z)
	return setmetatable({X = x or 0, Y = y or 0, Z = z or 0}, Vector3MT)
end

local Color3MT = {}
Color3MT.__index = Color3MT
function Color3MT:ToHSV()
	local r, g, b = self.R, self.G, self.B
	local max, min = math.max(r, g, b), math.min(r, g, b)
	local h, s, v = 0, 0, max
	local d = max - min

	if d > 0 then
		s = d / max

		if max == r then
			h = (g - b) / d % 6
		elseif max == g then
			h = (b - r) / d + 2
		else
			h = (r - g) / d + 4
		end

		h = h / 6
	end

	return h, s, v
end
function Color3MT.__tostring(self)
	return string.format('(%g, %g, %g)', self.R, self.G, self.B)
end

local function color(r, g, b)
	return setmetatable({R = r or 0, G = g or 0, B = b or 0}, Color3MT)
end

Color3 = {
	new = color,
	fromRGB = function(r, g, b)
		return color(r / 255, g / 255, b / 255)
	end,
	fromHSV = function(h, s, v)
		h, s, v = h % 1, math.clamp(s, 0, 1), math.clamp(v, 0, 1)
		local i = math.floor(h * 6)
		local f = h * 6 - i
		local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
		local sector = i % 6

		if sector == 0 then return color(v, t, p) end
		if sector == 1 then return color(q, v, p) end
		if sector == 2 then return color(p, v, t) end
		if sector == 3 then return color(p, q, v) end
		if sector == 4 then return color(t, p, v) end

		return color(v, p, q)
	end
}

Rect = {}
function Rect.new(x0, y0, x1, y1)
	return {Min = Vector2.new(x0, y0), Max = Vector2.new(x1, y1)}
end

TweenInfo = {}
function TweenInfo.new(time, style, direction)
	return {Time = time or 0, EasingStyle = style, EasingDirection = direction}
end

-- 任意 Enum.Xxx.Yyy 都能取到，且同名返回同一个对象（保证 == 比较成立）
Enum = setmetatable({}, {
	__index = function(self, name)
		local enumType = setmetatable({}, {
			__index = function(typeTable, item)
				local value = {Name = item, EnumType = name}
				typeTable[item] = value

				return value
			end
		})

		self[name] = enumType

		return enumType
	end
})

--[[ 实例系统 ]]

local VALID = {
	Name = true, Parent = true, Size = true, Position = true, AnchorPoint = true,
	BackgroundColor3 = true, BackgroundTransparency = true, BorderColor3 = true, BorderSizePixel = true,
	ZIndex = true, Visible = true, ClipsDescendants = true, LayoutOrder = true, AutomaticSize = true,
	SizeConstraint = true, Rotation = true, Active = true, Selectable = true, Archivable = true,
	Text = true, TextColor3 = true, TextSize = true, Font = true, FontFace = true, TextTransparency = true,
	TextXAlignment = true, TextYAlignment = true, TextTruncate = true, TextWrapped = true, TextScaled = true,
	RichText = true, TextStrokeTransparency = true, TextStrokeColor3 = true,
	PlaceholderText = true, PlaceholderColor3 = true, ClearTextOnFocus = true, TextEditable = true, MultiLine = true,
	Image = true, ImageColor3 = true, ImageTransparency = true, ScaleType = true, SliceCenter = true,
	SliceScale = true, ImageRectSize = true, ImageRectOffset = true, TileSize = true,
	AutoButtonColor = true, Modal = true, Selected = true, ImageRectSize2 = true,
	CanvasSize = true, CanvasPosition = true, AutomaticCanvasSize = true, ScrollBarThickness = true,
	ScrollBarImageColor3 = true, ScrollBarImageTransparency = true, ScrollingDirection = true,
	ScrollingEnabled = true, ElasticBehavior = true, ScrollBarInset = true,
	SortOrder = true, Padding = true, HorizontalAlignment = true, VerticalAlignment = true, FillDirection = true,
	CornerRadius = true, Color = true, Thickness = true, Transparency = true, ApplyStrokeMode = true,
	LineJoinMode = true, PaddingLeft = true, PaddingTop = true, PaddingRight = true, PaddingBottom = true,
	Scale = true, BlurRadius = true, Enabled = true, Offset = true,
	DisplayOrder = true, IgnoreGuiInset = true, ResetOnSpawn = true, ZIndexBehavior = true, OnTopOfCoreBlur = true,
	ViewportSize = true, CameraType = true, CFrame = true, FieldOfView = true,
	Width = true, Height = true, MaxValue = true, MinValue = true, Value = true,
	LocalPlayer = true, CurrentCamera = true, Create = true, GetTextBoundsAsync = true,
	UserInputType = true, UserInputState = true, KeyCode = true, Delta = true, Text2 = true,
	GetTextSize = true, JSONEncode = true, JSONDecode = true, GetGuiInset = true,
	GetMouseLocation = true, IsKeyDown = true, GetFocusedTextBox = true, SetRobloxGuiFocused = true,
	TouchEnabled = true, KeyboardEnabled = true, MouseEnabled = true, MouseIconEnabled = true,
	TextStrokeTransparency2 = true, Interactable = true
}

local EVENTS = {
	MouseButton1Click = true, MouseButton2Click = true, MouseButton1Down = true, MouseButton1Up = true,
	MouseEnter = true, MouseLeave = true, MouseMoved = true, MouseWheelBackward = true, MouseWheelForward = true,
	InputBegan = true, InputChanged = true, InputEnded = true, FocusLost = true, Focused = true,
	Changed = true, TouchTap = true, TouchLongPress = true, AncestryChanged = true, DescendantAdded = true
}

Mock.Warnings = {}
Mock.Objects = {}

local function isGui(class)
	return not class:match('^UI')
end

local Signal = {}
Signal.__index = Signal
function Signal.new()
	return setmetatable({Connections = {}}, Signal)
end
function Signal:Connect(callback)
	table.insert(self.Connections, callback)

	return {
		Disconnect = function()
			local index = table.find(self.Connections, callback)
			if index then
				table.remove(self.Connections, index)
			end
		end
	}
end
function Signal:Fire(...)
	for _, callback in ipairs(self.Connections) do
		callback(...)
	end
end

function Signal:Wait()
	return nil
end
Mock.Signal = Signal

local InstanceMT = {}
InstanceMT.__index = function(self, key)
	local props = rawget(self, 'Props')

	if props[key] ~= nil then
		return props[key]
	end

	if rawget(self, 'Methods')[key] then
		return rawget(self, 'Methods')[key]
	end

	local class = rawget(self, 'ClassName')

	-- 计算属性
	if key == 'AbsoluteSize' then
		local size = props.Size or UDim2.new()
		return Vector2.new(
			size.X.Offset + size.X.Scale * Mock.Screen.X,
			size.Y.Offset + size.Y.Scale * Mock.Screen.Y
		)
	end

	if key == 'AbsolutePosition' then
		local position = props.Position or UDim2.new()
		local parent = props.Parent
		local base = parent and parent.AbsolutePosition or Vector2.new(0, 0)
		return Vector2.new(
			base.X + position.X.Offset + position.X.Scale * (parent and parent.AbsoluteSize.X or Mock.Screen.X),
			base.Y + position.Y.Offset + position.Y.Scale * (parent and parent.AbsoluteSize.Y or Mock.Screen.Y)
		)
	end

	if key == 'AbsoluteContentSize' then
		local height = 0
		local width = 0
		for _, child in ipairs(rawget(self, 'Children')) do
			if child.ClassName ~= 'UIListLayout' and child.Props.Visible ~= false then
				height = height + child.AbsoluteSize.Y
				width = math.max(width, child.AbsoluteSize.X)
			end
		end

		return Vector2.new(width, height + (props.Padding and props.Padding.Offset or 0) * math.max(#rawget(self, 'Children') - 1, 0))
	end

	-- 方法
	if key == 'Destroy' then
		return function(obj)
			local parent = obj.Props.Parent
			if parent then
				local children = rawget(parent, 'Children')
				local index = table.find(children, obj)
				if index then table.remove(children, index) end
			end

			obj.Props.Parent = nil
			rawset(obj, 'Destroyed', true)
			for index = #Mock.Objects, 1, -1 do
				if Mock.Objects[index] == obj then table.remove(Mock.Objects, index) end
			end
		end
	end

	if key == 'ClearAllChildren' then
		return function(obj)
			local children = rawget(obj, 'Children')
			for index = #children, 1, -1 do
				children[index].Props.Parent = nil
				table.remove(children, index)
			end
		end
	end

	if key == 'GetChildren' then
		return function(obj)
			return rawget(obj, 'Children')
		end
	end

	if key == 'IsA' then
		return function(obj, name)
			if name == 'GuiObject' then return isGui(obj.ClassName) end
			return obj.ClassName == name or name == 'Instance'
		end
	end

	if key == 'FindFirstChild' or key == 'FindFirstChildOfClass' or key == 'WaitForChild' then
		return function(obj, name)
			if name == 'Camera' and Mock.Camera then
				return Mock.Camera
			end

			for _, child in ipairs(rawget(obj, 'Children')) do
				if child.Props.Name == name or child.ClassName == name then
					return child
				end
			end

			if key == 'WaitForChild' then
				local found = Mock:Instance(key == 'WaitForChild' and 'Folder' or 'Folder')
				found.Props.Name = name

				return found
			end
		end
	end

	if key == 'GetPropertyChangedSignal' then
		return function(obj, prop)
			if type(obj) ~= 'table' then
				Mock.DebugLog = Mock.DebugLog or {}
				table.insert(Mock.DebugLog, 'GetPropertyChangedSignal obj type=' .. type(obj) .. ' prop=' .. tostring(prop))
				table.insert(Mock.DebugLog, debug.traceback())

				return Signal.new()
			end

			local signals = rawget(obj, 'Signals')
			if not signals[prop] then
				signals[prop] = Signal.new()
			end

			return signals[prop]
		end
	end

	if key == 'Clone' then
		return function(obj)
			return Mock:Instance(obj.ClassName)
		end
	end

	if key == 'GetFullName' then
		return function(obj) return obj.Props.Name or obj.ClassName end
	end

	if EVENTS[key] then
		local signals = rawget(self, 'Signals')

		if not signals[key] then
			signals[key] = Signal.new()
		end

		return signals[key]
	end

	-- Roblox 支持用子对象名字直接索引
	for _, child in ipairs(rawget(self, 'Children')) do
		if child.Props.Name == key then
			return child
		end
	end

	return nil
end

InstanceMT.__newindex = function(self, key, value)
	local props = rawget(self, 'Props')

	if type(value) == 'function' then
		rawget(self, 'Methods')[key] = value

		return
	end

	if not VALID[key] then
		table.insert(Mock.Warnings, string.format('未知属性: %s.%s (类 %s)', props.Name or '?', key, rawget(self, 'ClassName')))
	end

	if key == 'Parent' then
		local old = props.Parent
		if old and rawget(old, 'Children') then
			local children = rawget(old, 'Children')
			local index = table.find(children, self)
			if index then table.remove(children, index) end
		end

		props.Parent = value

		if value and rawget(value, 'Children') then
			table.insert(rawget(value, 'Children'), self)
		end

		return
	end

	props[key] = value
end

function Mock:Instance(class)
	local obj = {
		ClassName = class,
		Props = {Name = class, Visible = true},
		Children = {},
		Signals = {},
		Methods = {}
	}

	setmetatable(obj, InstanceMT)
	table.insert(Mock.Objects, obj)

	return obj
end

Instance = {new = function(class) return Mock:Instance(class) end}

--[[ 字体 ]]

Font = {
	fromEnum = function(font, weight)
		return {Family = 'mock', Weight = weight, Font = font}
	end,
	fromId = function(id)
		return {Family = tostring(id)}
	end,
	new = function(family, weight)
		return {Family = family, Weight = weight}
	end
}

--[[ 服务 ]]

local function makeService(name, extra)
	local service = Mock:Instance('Service')
	service.Props.Name = name

	for key, value in pairs(extra or {}) do
		service.Props[key] = value
	end

	return service
end

local camera = Mock:Instance('Camera')
camera.Props.Name = 'Camera'
camera.Props.ViewportSize = Mock.Screen

workspace = Mock:Instance('Workspace')
workspace.Props.Name = 'Workspace'
workspace.Props.CurrentCamera = camera
camera.Props.Parent = workspace
Mock.Camera = camera

local services = {
	UserInputService = makeService('UserInputService', {
		TouchEnabled = false,
		KeyboardEnabled = true,
		MouseEnabled = true
	}),
	TweenService = makeService('TweenService'),
	TextService = makeService('TextService'),
	HttpService = makeService('HttpService'),
	RunService = makeService('RunService'),
	GuiService = makeService('GuiService'),
	Players = makeService('Players'),
	CoreGui = makeService('CoreGui')
}

function services.TweenService.Create(_, obj, info, props)
	local tween = {Instance = obj, TweenInfo = info, Props = props}

	function tween:Play()
		for key, value in pairs(props) do
			obj[key] = value
		end
	end

	function tween:Cancel() end

	return tween
end

function services.TextService.GetTextBoundsAsync(_, params)
	local text = tostring(params.Text or '')

	return Vector2.new(#text * (params.Size or 14) * 0.55, params.Size or 14)
end

function services.TextService.GetTextSize(_, text, size)
	return Vector2.new(#text * size * 0.55, size)
end

function services.HttpService.JSONEncode(_, data)
	if type(data) ~= 'table' then return 'null' end

	local parts = {}
	for key, value in pairs(data) do
		parts[#parts + 1] = string.format('%q:%q', tostring(key), tostring(value))
	end

	return '{' .. table.concat(parts, ',') .. '}'
end

function services.HttpService.JSONDecode(_, str)
	if str == '{}' then return {} end

	return nil
end

function services.GuiService.GetGuiInset(_)
	return Vector2.new(0, 36)
end

function services.UserInputService.GetMouseLocation(_)
	return Vector2.new(100, 100)
end

function services.UserInputService.IsKeyDown(_)
	return false
end

function services.UserInputService.GetFocusedTextBox(_)
	return nil
end

local player = Mock:Instance('Player')
player.Props.Name = 'LocalPlayer'
local playerGui = Mock:Instance('PlayerGui')
playerGui.Props.Parent = player
services.Players.LocalPlayer = player

game = {
	PlaceId = 0,
	GameId = 0,
	Loaded = Signal.new(),
	GetService = function(_, name)
		return services[name] or makeService(name)
	end,
	IsLoaded = function()
		return true
	end,
	HttpGet = function(_, url)
		-- 模拟"下载成功"，用来走通 writefile + getcustomasset 分支
		Mock.Downloads = (Mock.Downloads or 0) + 1

		return string.rep('\137PNG', 8)
	end
}

--[[ 执行器环境（模拟支持文件函数的执行器） ]]

Mock.Files = {}

function getgenv()
	return _G
end

function isfile(path)
	return Mock.Files[path] ~= nil
end

function readfile(path)
	return Mock.Files[path]
end

function writefile(path, data)
	Mock.Files[path] = data
end

function makefolder(path)
	Mock.Folders = Mock.Folders or {}
	Mock.Folders[path] = true
end

function isfolder(path)
	Mock.Folders = Mock.Folders or {}

	return Mock.Folders[path] == true
end

function getcustomasset(path)
	return 'rbxasset://mock/' .. path
end

function identifyexecutor()
	return 'Mock', '1.0'
end

-- 模拟"不支持文件函数"的执行器：把相关全局删掉，走 rbxassetid 回退
if MockNoFiles then
	isfile, readfile, writefile, makefolder, isfolder, getcustomasset = nil, nil, nil, nil, nil, nil
end

--[[ 标准库补齐（Roblox 有、LuaJIT 没有的） ]]

if not math.clamp then
	function math.clamp(value, min, max)
		if value < min then return min end
		if value > max then return max end

		return value
	end
end

if not table.find then
	function table.find(tbl, value)
		for index, item in ipairs(tbl) do
			if item == value then return index end
		end
	end
end

if not table.clear then
	function table.clear(tbl)
		for key in pairs(tbl) do
			tbl[key] = nil
		end
	end
end

if not table.pack then
	function table.pack(...)
		return {n = select('#', ...), ...}
	end
end

table.unpack = table.unpack or unpack

task = {
	spawn = function(func, ...)
		func(...)
	end,
	defer = function(func, ...)
		func(...)
	end,
	delay = function(_, func, ...)
		func(...)
	end,
	wait = function()
		return 0
	end,
	cancel = function() end
}

function typeof(value)
	if type(value) == 'table' and rawget(value, 'ClassName') then
		return 'Instance'
	end

	if type(value) == 'table' and rawget(value, 'Props') then
		return 'Instance'
	end

	return type(value)
end

function warn(...)
	table.insert(Mock.Warnings, table.concat({...}, ' '))
end

Mock.game = game
Mock.workspace = workspace
Mock.services = services
Mock.Screen = Vector2.new(1920, 1080)
camera.Props.ViewportSize = Mock.Screen

-- 测试辅助：改屏幕大小并触发刷新
function Mock:Resize(width, height)
	Mock.Screen = Vector2.new(width, height)
	camera.Props.ViewportSize = Mock.Screen
	camera:GetPropertyChangedSignal('ViewportSize'):Fire()
end

-- 测试辅助：按下某个键（传 Enum.KeyCode.Xxx）
function Mock:FireKey(keyCode)
	services.UserInputService.InputBegan:Fire({
		KeyCode = keyCode,
		UserInputType = Enum.UserInputType.Keyboard,
		UserInputState = Enum.UserInputState.Begin
	}, false)
end

-- 测试辅助：点击某个实例
function Mock:Click(instance)
	instance.MouseButton1Click:Fire()
end

-- 测试辅助：触发属性变化（例如让窗口重算内容高度）
function Mock:FireChanged(instance, prop)
	instance:GetPropertyChangedSignal(prop):Fire()
end

MockGlobal = Mock

return Mock
