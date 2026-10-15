--[==[
	Nova GUI v1.0.0 — Roblox 客户端脚本 UI 库

	风格参考 Vape V4：暗色 + 细描边 + 像素小圆角 + 多窗口 + 悬浮球。
	本文件由 tools/build.py 从 src/library/*.lua 自动生成，不要直接改这里。

	用法（执行器里）：
		loadstring(game:HttpGet("https://raw.githubusercontent.com/aa121314aa/idkidk/main/src/Nova.lua", true))()

	加载后：
		local Nova = getgenv().Nova
		local win = Nova:CreateWindow({Name = "我的窗口", Icon = "icon_wrench", Visible = true})
		win:AddToggle({Name = "开关", Callback = function(v) print(v) end})
]==]


--[==[ 00_Core.lua ]==]
--[==[
	Nova GUI  ·  00_Core
	仓库库表定义。单文件构建时由 tools/build.py 拼接到一起；
	也可以由加载器逐个 loadstring，此时通过 getgenv().NovaLib 传递。
]==]

local getgenv = getgenv or function()
	return _G
end

local NovaLib = getgenv().NovaLib or {}
getgenv().NovaLib = NovaLib

NovaLib.Name = 'Nova'
NovaLib.Version = '1.0.0'
NovaLib.Repo = 'aa121314aa/idkidk'   -- 资产(assets)托管仓库
NovaLib.Ref = 'main'                 -- 拉取资产用的分支 / commit
NovaLib.Windows = {}                 -- 所有窗口
NovaLib.Modules = {}                 -- 所有模块(AddModule)
NovaLib.Loaded = false
NovaLib.Debug = false

function NovaLib:Log(...)
	if self.Debug then
		print('[Nova]', ...)
	end
end

--[==[ 01_Env.lua ]==]
--[==[
	Nova GUI  ·  01_Env
	执行器适配层：把不同执行器的 API 差异统一成一套接口。
	覆盖：Synapse X / Script-Ware / Krnl / Fluxus / Delta / Arceus X / Codex 等常见环境。
]==]

local Lib = NovaLib or getgenv().NovaLib
local env = {}
Lib.Env = env

local cloneref = cloneref or function(obj)
	return obj
end

env.cloneref = cloneref

local services = {}
function env:Service(name)
	if not services[name] then
		services[name] = cloneref(game:GetService(name))
	end

	return services[name]
end

env.TweenService = env:Service('TweenService')
env.InputService = env:Service('UserInputService')
env.TextService = env:Service('TextService')
env.HttpService = env:Service('HttpService')
env.RunService = env:Service('RunService')
env.GuiService = env:Service('GuiService')
env.Players = env:Service('Players')
env.LocalPlayer = env.Players.LocalPlayer

-- 相机可能在脚本执行时还没准备好
env.Camera = workspace.CurrentCamera or workspace:FindFirstChildOfClass('Camera')
workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
	env.Camera = workspace.CurrentCamera or env.Camera
end)

-- 执行器名字（仅用于提示，不参与逻辑）
do
	local name
	pcall(function()
		if identifyexecutor then
			name = select(1, identifyexecutor())
		elseif getexecutorname then
			name = getexecutorname()
		end
	end)
	env.Executor = name or 'Unknown'
end

-- 能力检测
env.Features = {
	File = type(isfile) == 'function' and type(writefile) == 'function' and type(readfile) == 'function',
	Folder = type(makefolder) == 'function' and type(isfolder) == 'function',
	CustomAsset = type(getcustomasset) == 'function',
	Request = type(request) == 'function' or (type(syn) == 'table' and type(syn.request) == 'function'),
	Clipboard = type(setclipboard) == 'function',
	Touch = env.InputService.TouchEnabled and not env.InputService.KeyboardEnabled
}

-- 任选一种可用的 HTTP 拉取方式
function env:HttpGet(url)
	local ok, data = pcall(function()
		return game:HttpGet(url, true)
	end)

	if ok and type(data) == 'string' and #data > 0 and not data:find('404: Not Found') then
		return data
	end

	local req = request or (type(syn) == 'table' and syn.request) or http_request
	if req then
		local ok2, res = pcall(function()
			return req({
				Url = url,
				Method = 'GET'
			})
		end)

		if ok2 and type(res) == 'table' and type(res.Body) == 'string' and #res.Body > 0 then
			return res.Body
		end
	end

	Lib:Log('HttpGet 失败:', url)
	return nil
end

function env:JSONEncode(tbl)
	return env.HttpService:JSONEncode(tbl)
end

function env:JSONDecode(str)
	local ok, data = pcall(function()
		return env.HttpService:JSONDecode(str)
	end)

	return ok and type(data) == 'table' and data or nil
end

-- 文件读写封装（没有文件功能的执行器直接返回 nil）
function env:MakeFolder(path)
	if not env.Features.Folder then return end

	pcall(function()
		if not isfolder(path) then
			makefolder(path)
		end
	end)
end

function env:IsFile(path)
	if not env.Features.File then return false end

	local ok, result = pcall(function()
		return isfile(path) and readfile(path) ~= nil and readfile(path) ~= ''
	end)

	return ok and result == true
end

function env:WriteFile(path, data)
	if not env.Features.File then return false end

	return pcall(function()
		writefile(path, data)
	end)
end

function env:ReadFile(path)
	if not env.Features.File then return nil end

	local ok, data = pcall(function()
		return readfile(path)
	end)

	return ok and data or nil
end

-- ScreenGui 挂载点
function env:Container()
	if gethui then
		local ok, holder = pcall(gethui)
		if ok and holder then return holder end
	end

	local ok, core = pcall(function()
		return cloneref(game:GetService('CoreGui'))
	end)
	if ok and core then return core end

	return env.LocalPlayer:WaitForChild('PlayerGui')
end

-- 老 Synapse 需要 protect_gui 才能隐藏 CoreGui 里的对象
function env:Protect(gui)
	pcall(function()
		if protect_gui then
			protect_gui(gui)
		elseif syn and syn.protect_gui then
			syn.protect_gui(gui)
		end
	end)
end

-- 线程身份修复（部分执行器需要 identity 8 才能操作 Roblox 内部）
env.ThreadFix = type(setthreadidentity) == 'function'
function env:Identity(func, ...)
	if not env.ThreadFix then
		return func(...)
	end

	local old = getthreadidentity and getthreadidentity() or 7
	setthreadidentity(8)
	local results = table.pack(pcall(func, ...))
	pcall(setthreadidentity, old)

	return table.unpack(results, 1, results.n)
end

-- 补间：同一个对象重复补间时自动取消上一条
local tweens = setmetatable({}, {__mode = 'k'})

function env:Tween(obj, info, props)
	local old = tweens[obj]
	if old then
		pcall(function()
			old:Cancel()
		end)
	end

	local ok, tween = pcall(function()
		return env.TweenService:Create(obj, info or Lib.Theme.Tween, props)
	end)

	if not ok then
		for prop, value in pairs(props) do
			obj[prop] = value
		end

		return nil
	end

	tweens[obj] = tween
	tween:Play()

	return tween
end

-- 随机字符串（用于隐藏 ScreenGui 名字）
function env:RandomString()
	local chars = {}
	for i = 1, math.random(12, 24) do
		chars[i] = string.char(math.random(97, 122))
	end

	return table.concat(chars)
end

-- 简易信号
function env:Signal()
	local signal = {Connections = {}}

	function signal:Connect(callback)
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

	function signal:Fire(...)
		for _, callback in ipairs(self.Connections) do
			task.spawn(callback, ...)
		end
	end

	return signal
end

-- 简易 maid（清理连接 / 实例 / 线程）
function env:Maid()
	local maid = {Tasks = {}}

	function maid:Add(item)
		table.insert(self.Tasks, item)
		return item
	end

	function maid:Clean()
		for _, item in ipairs(self.Tasks) do
			if typeof(item) == 'Instance' then
				pcall(function()
					item:ClearAllChildren()
					item:Destroy()
				end)
			elseif typeof(item) == 'RBXScriptConnection' then
				pcall(function()
					item:Disconnect()
				end)
			elseif type(item) == 'function' then
				pcall(item)
			elseif type(item) == 'thread' then
				pcall(function()
					if coroutine.status(item) ~= 'dead' then
						task.cancel(item)
					end
				end)
			end
		end

		table.clear(self.Tasks)
	end

	return maid
end

-- 安全调用：模块回调炸了也不能把 UI 带走
function env:Safe(func, ...)
	if type(func) ~= 'function' then return end

	local results = table.pack(pcall(func, ...))
	if not results[1] then
		warn('[Nova] 回调错误: ' .. tostring(results[2]))
	end

	return table.unpack(results, 1, results.n)
end

--[==[ 02_Scale.lua ]==]
--[==[
	Nova GUI  ·  02_Scale
	百分比缩放系统。

	所有控件只用「设计像素」描述（基准 1920x1080），由本模块换算并登记。
	屏幕尺寸变化时统一刷新 —— 因此窗口内部的控件同样按屏幕百分比变化，而不是被父级尺寸二次缩放。

		Percent 模式（默认）：X 按屏幕宽度百分比、Y 按屏幕高度百分比
		Uniform 模式：X / Y 都用同一个等比系数（Vape V4 的做法，不会被屏幕比例拉伸）

	字号 / 描边 / 内边距这类只能用像素表达的属性用等比系数(含 MinScale/MaxScale 保护)，
	圆角(UICorner)保持像素值不变 —— 也就是「像素圆角」。
]==]

local Lib = NovaLib or getgenv().NovaLib
local env = Lib.Env

local Scale = {
	BaseW = 1920,        -- 设计基准宽
	BaseH = 1080,        -- 设计基准高
	Mode = 'Percent',    -- 'Percent' | 'Uniform'
	MinScale = 0.6,      -- 最小缩放（小屏上防止文字过小）
	MaxScale = 2.5,
	List = {},           -- 登记项：{ obj, prop, build }
	Map = setmetatable({}, {__mode = 'k'})
}

Lib.Scale = Scale

function Scale:Viewport()
	local camera = env.Camera
	if camera then
		return camera.ViewportSize
	end

	return Vector2.new(self.BaseW, self.BaseH)
end

-- 等比系数（字号 / 描边 / 内边距用）
function Scale:Factor()
	local viewport = self:Viewport()

	return math.clamp(math.min(viewport.X / self.BaseW, viewport.Y / self.BaseH), self.MinScale, self.MaxScale)
end

-- 水平方向系数
function Scale:FactorX()
	if self.Mode == 'Uniform' then
		return self:Factor()
	end

	return self:Viewport().X / self.BaseW
end

-- 垂直方向系数
function Scale:FactorY()
	if self.Mode == 'Uniform' then
		return self:Factor()
	end

	return self:Viewport().Y / self.BaseH
end

-- 设计像素 -> 实际像素
function Scale:W(value)
	return value * self:FactorX()
end

function Scale:H(value)
	return value * self:FactorY()
end

function Scale:PX(value)
	return value * self:Factor()
end

-- 移除某个对象上已登记的同名属性（避免重复登记互相覆盖）
function Scale:Untrack(obj, prop)
	if not self.Map[obj] then return end

	for index = #self.List, 1, -1 do
		local entry = self.List[index]
		if entry.Object == obj and entry.Prop == prop then
			table.remove(self.List, index)
		end
	end

	local list = self.Map[obj]
	for index = #list, 1, -1 do
		if list[index].Prop == prop then
			table.remove(list, index)
		end
	end
end

-- 登记一个需要随屏幕变化的属性，build(self) 返回要写入的值
function Scale:Track(obj, prop, build)
	self:Untrack(obj, prop)

	local entry = {
		Object = obj,
		Prop = prop,
		Build = build
	}

	table.insert(self.List, entry)

	local list = self.Map[obj]
	if not list then
		list = {}
		self.Map[obj] = list
	end

	table.insert(list, entry)

	local ok, value = pcall(build, self)
	if ok then
		obj[prop] = value
	end

	return obj
end

-- 立刻重算某个对象的全部登记项
function Scale:Apply(obj)
	local list = self.Map[obj]
	if not list then return end

	for _, entry in ipairs(list) do
		pcall(function()
			entry.Object[entry.Prop] = entry.Build(self)
		end)
	end
end

function Scale:Cancel(obj)
	local list = self.Map[obj]
	if not list then return end

	for index = #self.List, 1, -1 do
		if self.List[index].Object == obj then
			table.remove(self.List, index)
		end
	end

	self.Map[obj] = nil
end

-- 刷新全部（屏幕尺寸变化时调用）
function Scale:Refresh()
	-- 先清掉被销毁的对象
	for index = #self.List, 1, -1 do
		if self.List[index].Object.Parent == nil then
			table.remove(self.List, index)
		end
	end

	-- 正序应用：后登记的覆盖先登记的
	for _, entry in ipairs(self.List) do
		pcall(function()
			entry.Object[entry.Prop] = entry.Build(self)
		end)
	end

	if self.OnRefresh then
		self:OnRefresh()
	end
end

--[[ 尺寸 ]]

function Scale:Size(obj, width, height)
	return self:Track(obj, 'Size', function(s)
		return UDim2.fromOffset(s:W(width), s:H(height))
	end)
end

function Scale:SizeW(obj, height)   -- 宽 100%
	return self:Track(obj, 'Size', function(s)
		return UDim2.new(1, 0, 0, s:H(height))
	end)
end

function Scale:SizeH(obj, width)    -- 高 100%
	return self:Track(obj, 'Size', function(s)
		return UDim2.new(0, s:W(width), 1, 0)
	end)
end

function Scale:SizeF(obj, widthScale, heightScale)  -- 直接用比例
	return self:Track(obj, 'Size', function()
		return UDim2.fromScale(widthScale, heightScale)
	end)
end

--[[ 位置 ]]

function Scale:Pos(obj, x, y)
	return self:Track(obj, 'Position', function(s)
		return UDim2.fromOffset(s:W(x), s:H(y))
	end)
end

function Scale:Position(obj, x, y)
	return self:Pos(obj, x, y)
end

-- 右对齐：X = 100% - x(设计像素)
function Scale:PosRight(obj, x, y)
	return self:Track(obj, 'Position', function(s)
		return UDim2.new(1, -s:W(x), 0, s:H(y))
	end)
end

function Scale:PosF(obj, x, y)  -- 0~1 屏幕比例，不登记（用于动画 / 拖拽）
	obj.Position = UDim2.fromScale(x, y)
	return obj
end

function Scale:PositionF(obj, x, y)
	return self:PosF(obj, x, y)
end

-- 跟随一个比例表：拖拽时只改 frac.X / frac.Y，屏幕变化时自动跟着走
function Scale:Follow(obj, frac)
	self:Track(obj, 'Position', function(s)
		local viewport = s:Viewport()

		return UDim2.new(0, frac.X * viewport.X, 0, frac.Y * viewport.Y)
	end)

	return frac
end

function Scale:SetFollow(obj, x, y)
	obj.Position = UDim2.new(0, x * self:Viewport().X, 0, y * self:Viewport().Y)
end

--[[ 像素类属性 ]]

function Scale:Text(obj, size)
	return self:Track(obj, 'TextSize', function(s)
		return s:PX(size)
	end)
end

function Scale:Thickness(obj, thickness)
	return self:Track(obj, 'Thickness', function(s)
		return s:PX(thickness)
	end)
end

function Scale:Spacing(obj, spacing)
	return self:Track(obj, 'Padding', function(s)
		return UDim.new(0, s:PX(spacing))
	end)
end

function Scale:Padding(obj, left, top, right, bottom)
	left, top, right, bottom = left or 0, top or 0, right or 0, bottom or 0

	self:Track(obj, 'PaddingLeft', function(s) return UDim.new(0, s:PX(left)) end)
	self:Track(obj, 'PaddingTop', function(s) return UDim.new(0, s:PX(top)) end)
	self:Track(obj, 'PaddingRight', function(s) return UDim.new(0, s:PX(right)) end)
	self:Track(obj, 'PaddingBottom', function(s) return UDim.new(0, s:PX(bottom)) end)

	return obj
end

-- 一次性取值（不登记，用于补间目标等）
function Scale:Dim(width, height)
	return UDim2.fromOffset(self:W(width), self:H(height))
end

--[[ 内容自适应 ]]

-- 目标高度 = 基础设计高度 + 内容高度，并限制最大高度（超出滚动）
-- 返回 update 函数；target 的 Size 会持续跟随内容变化
function Scale:BindContent(list, target, extra, maxHeight)
	local function update()
		local viewport = self:Viewport()
		local rendered = self:H(extra) + list.AbsoluteContentSize.Y
		local limit = maxHeight and self:H(maxHeight) or (viewport.Y * 0.78)

		target.Size = UDim2.fromOffset(target.AbsoluteSize.X, math.min(rendered, limit))
	end

	local connection = list:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(update)
	update()

	return update, connection
end

--[[ 初始化 ]]

function Scale:Mount(parent)
	local root = Instance.new('Frame')
	root.BackgroundTransparency = 1
	root.Name = 'Root'
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = parent

	self.Root = root

	if env.Camera then
		env.Camera:GetPropertyChangedSignal('ViewportSize'):Connect(function()
			self:Refresh()
		end)
	end

	return root
end

function Scale:SetMode(mode)
	if mode ~= 'Percent' and mode ~= 'Uniform' then return end
	self.Mode = mode
	self:Refresh()

	if Lib.OnScaleChanged then
		env:Safe(Lib.OnScaleChanged, mode)
	end
end

--[==[ 03_Theme.lua ]==]
--[==[
	Nova GUI  ·  03_Theme
	调色板 / 字体 / 圆角 / 补间。风格参考 Vape V4（暗色 + 细描边 + 小圆角）。
]==]

local Lib = NovaLib or getgenv().NovaLib

local Theme = {
	-- 主色
	Main = Color3.fromRGB(26, 25, 26),
	Text = Color3.fromRGB(200, 200, 200),
	Stroke = Color3.fromRGB(85, 85, 85),
	StrokeTransparency = 0.8,
	Divider = Color3.fromRGB(48, 48, 48),
	Shadow = Color3.fromRGB(0, 0, 0),

	-- 强调色（HSV，方便做彩虹 / 主题色）
	Hue = 0.46,
	Sat = 0.96,
	Val = 0.52,

	-- 圆角：像素值，不随屏幕缩放（"像素圆角"）
	Corner = 4,
	CornerSmall = 3,

	-- 尺寸（设计像素，实际显示按屏幕百分比换算）
	RowHeight = 30,        -- 普通控件行高
	ModuleHeight = 38,     -- 模块行高
	TopbarHeight = 34,     -- 窗口标题栏高度
	WindowWidth = 240,     -- 窗口默认宽度
	BallWidth = 104,       -- 悬浮球宽
	BallHeight = 40,       -- 悬浮球高（长方形）

	Tween = TweenInfo.new(0.16, Enum.EasingStyle.Linear),
	TweenFast = TweenInfo.new(0.1, Enum.EasingStyle.Linear),
	TweenSlow = TweenInfo.new(0.35, Enum.EasingStyle.Exponential)
}

Lib.Theme = Theme

-- 字体：优先 FontFace（支持字重），老执行器回退到 Font 枚举
do
	local ok = pcall(function()
		Theme.Font = Font.fromEnum(Enum.Font.Arial)
		Theme.FontSemiBold = Font.fromEnum(Enum.Font.Arial, Enum.FontWeight.SemiBold)
	end)

	if not ok or not Theme.Font then
		Theme.Font = nil
		Theme.FontSemiBold = nil
	end
end

function Theme:SetFont(obj, semiBold)
	if self.Font then
		local ok = pcall(function()
			obj.FontFace = semiBold and self.FontSemiBold or self.Font
		end)

		if ok then return obj end
	end

	obj.Font = Enum.Font.SourceSans
	return obj
end

-- 明暗调整（保持色相和饱和度，只动明度）
local Color = {}
Lib.Color = Color

function Color:Light(color, amount)
	local h, s, v = color:ToHSV()
	local base = select(3, Theme.Main:ToHSV()) > 0.5

	return Color3.fromHSV(h, s, math.clamp(base and v - amount or v + amount, 0, 1))
end

function Color:Dark(color, amount)
	local h, s, v = color:ToHSV()
	local base = select(3, Theme.Main:ToHSV()) > 0.5

	return Color3.fromHSV(h, s, math.clamp(base and v + amount or v - amount, 0, 1))
end

function Theme:Accent()
	return Color3.fromHSV(self.Hue, self.Sat, self.Val)
end

function Theme:DimText()
	return Color:Dark(self.Text, 0.16)
end

-- 强调色注册表：改主题色时统一刷新
Theme.AccentItems = setmetatable({}, {__mode = 'k'})

function Theme:RegisterAccent(obj, prop)
	self.AccentItems[obj] = prop
	obj[prop] = self:Accent()

	return obj
end

function Theme:ApplyAccent()
	local accent = self:Accent()

	for obj, prop in pairs(self.AccentItems) do
		obj[prop] = accent
	end
end

function Theme:SetAccent(hue, sat, val)
	self.Hue = hue or self.Hue
	self.Sat = sat or self.Sat
	self.Val = val or self.Val
	self:ApplyAccent()
end

--[==[ 04_Assets.lua ]==]
--[==[
	Nova GUI  ·  04_Assets
	资产加载：
	  1) 支持文件函数的执行器 -> 从仓库 raw 下载 PNG 到工作区，用 getcustomasset 加载（最稳、可换自己的图）
	  2) 不支持的执行器      -> 回退到 rbxassetid（公开 CC0 图标，来自 Vape V4 的资源表）
	  3) 都没有              -> 空字符串（控件会自动降级为纯文字）
	图标/图片直接放在仓库 assets/ 目录，改图不用改代码。
]==]

local Lib = NovaLib or getgenv().NovaLib
local env = Lib.Env

local Assets = {
	Folder = 'nova',
	Repo = Lib.Repo,
	Ref = Lib.Ref,
	Cache = {},
	Failed = {}
}

Lib.Assets = Assets

-- rbxassetid 回退表（CC0，来自 7GrandDadPGN/VapeV4ForRoblox）
Assets.Ids = {
	close = 121816018671466,
	min = 82175054487146,
	collapse = 94197751291504,
	expand = 86360332526471,
	chevron = 90289944682645,
	search = 115611852955611,
	settings = 73820177347303,
	dots = 130896840048276,
	back = 80523803497740,
	bind = 81399857677684,
	add = 121642387707174,
	edit = 105801951237137,
	pin = 92459145800579,
	check = 112336790299036,
	blur = 79246816170155,
	blur_noti = 124705876663719,
	noti_info = 102614825645099,
	noti_warning = 119631730212167,
	noti_alert = 82356478726846,
	notification = 90300780458781,
	icon_eye = 125472576898654,
	icon_wrench = 108303206513893,
	icon_globe = 118917453153459,
	icon_box = 93264756888499,
	icon_sword = 94762732349053,
	icon_players = 105137446428129,
	icon_profiles = 126051451865127,
	icon_theme = 111525258317113,
	icon_radar = 97983828696086
}

function Assets:URL(name)
	return string.format('https://raw.githubusercontent.com/%s/%s/assets/%s.png', self.Repo, self.Ref, name)
end

function Assets:Path(name)
	return self.Folder .. '/assets/' .. name .. '.png'
end

function Assets:SetRef(ref)
	self.Ref = ref
	table.clear(self.Cache)
	table.clear(self.Failed)
end

-- 文件模式：下载 -> 写文件 -> getcustomasset
function Assets:FromFile(name)
	if not (env.Features.File and env.Features.CustomAsset) then
		return nil
	end

	env:MakeFolder(self.Folder)
	env:MakeFolder(self.Folder .. '/assets')

	local path = self:Path(name)
	if not env:IsFile(path) then
		local data = env:HttpGet(self:URL(name))
		if not data then
			return nil
		end

		if not env:WriteFile(path, data) then
			return nil
		end
	end

	local ok, asset = pcall(function()
		return getcustomasset(path)
	end)

	if ok and type(asset) == 'string' and #asset > 0 then
		return asset
	end

	return nil
end

-- 同步获取（首次会阻塞下载，建议先 Prefetch）
function Assets:Get(name)
	if self.Cache[name] then
		return self.Cache[name]
	end

	if self.Failed[name] then
		return self:Id(name)
	end

	local asset = self:FromFile(name)
	if asset then
		self.Cache[name] = asset
		return asset
	end

	self.Failed[name] = true

	return self:Id(name)
end

function Assets:Id(name)
	local id = self.Ids[name]

	return id and ('rbxassetid://' .. id) or ''
end

-- 默认预下载的图标（自建 UI 用得到的那些；自己的图标可以再单独 Prefetch）
Assets.Core = {
	'logo_small', 'close', 'min', 'collapse', 'expand', 'chevron',
	'search', 'settings', 'dots', 'bind', 'check',
	'blur', 'blur_noti', 'noti_info', 'noti_warning', 'noti_alert', 'notification'
}

-- 后台预下载（不阻塞 UI 创建）
function Assets:Prefetch(names)
	if not (env.Features.File and env.Features.CustomAsset) then
		return
	end

	local list = names or self.Core

	for _, name in ipairs(list) do
		task.spawn(function()
			self:Get(name)
		end)
	end
end

-- 生成 9-slice 模糊底图（老执行器没有 UIShadow 时用）
function Assets:Blur(parent, noti)
	local blur = Instance.new('ImageLabel')
	blur.Name = 'Shadow'
	blur.BackgroundTransparency = 1
	blur.Image = self:Get(noti and 'blur_noti' or 'blur')
	blur.ImageTransparency = 0.4
	blur.ImageColor3 = Color3.new()
	blur.ScaleType = Enum.ScaleType.Slice
	blur.SliceCenter = Rect.new(52, 31, 261, 502)
	blur.ZIndex = 1
	blur.Parent = parent

	local scale = Lib.Scale
	scale:Track(blur, 'Size', function(s)
		return UDim2.new(1, s:PX(89), 1, s:PX(52))
	end)
	scale:Track(blur, 'Position', function(s)
		return UDim2.fromOffset(-s:PX(48), -s:PX(31))
	end)

	return blur
end

--[==[ 05_Util.lua ]==]
--[==[
	Nova GUI  ·  05_Util
	UI 工厂函数：圆角 / 描边 / 阴影 / 拖拽 / 悬停 / 提示气泡 / 文字测量
]==]

local Lib = NovaLib or getgenv().NovaLib
local env = Lib.Env
local Scale = Lib.Scale
local Theme = Lib.Theme
local Color = Lib.Color

local Util = {}
Lib.Util = Util

-- 创建对象（逐属性 pcall，老执行器缺属性也不会整段挂掉）
function Util:New(class, props)
	local obj = Instance.new(class)

	for prop, value in pairs(props or {}) do
		if prop ~= 'Parent' then
			pcall(function()
				obj[prop] = value
			end)
		end
	end

	if props and props.Parent then
		obj.Parent = props.Parent
	end

	return obj
end

-- 圆角：像素值，不随缩放变化
function Util:Corner(parent, radius)
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, radius or Theme.Corner)
	corner.Parent = parent

	return corner
end

-- 全圆（药丸形，用于开关、旋钮）
function Util:Pill(parent)
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = parent

	return corner
end

function Util:Stroke(parent, color, transparency, thickness)
	local stroke = Instance.new('UIStroke')
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color or Theme.Stroke
	stroke.Transparency = transparency or Theme.StrokeTransparency
	stroke.Thickness = thickness or 1
	stroke.Parent = parent

	Scale:Thickness(stroke, thickness or 1)

	return stroke
end

-- 阴影：优先 UIShadow（Roblox 新类），否则用 9-slice 模糊图
function Util:Shadow(parent, noti)
	if not noti then
		local ok, shadow = pcall(function()
			local shadow = Instance.new('UIShadow')
			shadow.BlurRadius = UDim.new(0, 13)
			shadow.Transparency = 0.3
			shadow.Parent = parent

			return shadow
		end)

		if ok and shadow then
			return shadow
		end
	end

	return Lib.Assets:Blur(parent, noti)
end

function Util:Font(obj, semiBold)
	return Theme:SetFont(obj, semiBold)
end

-- 文字宽度测量（用于自动尺寸）
function Util:TextBounds(text, size, semiBold)
	size = Scale:PX(size)

	local ok, bounds = pcall(function()
		local params = Instance.new('GetTextBoundsParams')
		params.Text = text
		params.Size = size
		params.Font = Theme.Font or Font.fromEnum(Enum.Font.Arial)
		params.Width = math.huge

		return env.TextService:GetTextBoundsAsync(params)
	end)

	if ok and bounds then
		return bounds
	end

	local ok2, bounds2 = pcall(function()
		return env.TextService:GetTextSize(text, size, Enum.Font.SourceSans, Vector2.new(999999, 999999))
	end)

	if ok2 then
		return bounds2
	end

	return Vector2.new(#text * size * 0.55, size)
end

-- 点击（鼠标 + 触摸统一）
function Util:Click(gui, callback)
	return gui.MouseButton1Click:Connect(function()
		env:Safe(callback)
	end)
end

function Util:RightClick(gui, callback)
	return gui.MouseButton2Click:Connect(function()
		env:Safe(callback)
	end)
end

-- 悬停（触摸设备无 hover，忽略即可）
function Util:Hover(gui, enter, leave)
	gui.MouseEnter:Connect(function()
		env:Safe(enter)
	end)

	gui.MouseLeave:Connect(function()
		env:Safe(leave)
	end)
end

-- 百分比拖拽：内部位置以「屏幕比例」保存，屏幕尺寸变化时自动跟着走
-- opts: { OnEnd = function(moved) end }
-- 返回比例表 frac，改 frac.X / frac.Y 后调用 Scale:SetFollow 生效
function Util:Drag(frame, handle, opts)
	opts = opts or {}
	local dragging = false
	local startMouse = Vector2.new()
	local startPos = Vector2.new()
	local moved = 0
	local moveConn, endConn

	local viewport = Scale:Viewport()
	local frac = {
		X = frame.Position.X.Scale + frame.Position.X.Offset / viewport.X,
		Y = frame.Position.Y.Scale + frame.Position.Y.Offset / viewport.Y
	}

	Scale:Follow(frame, frac)

	local function isDragInput(input)
		return input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
	end

	handle.InputBegan:Connect(function(input)
		if dragging or not isDragInput(input) then return end
		if frame.Visible == false then return end

		dragging = true
		moved = 0
		startMouse = Vector2.new(input.Position.X, input.Position.Y)
		startPos = Vector2.new(frac.X, frac.Y)

		moveConn = env.InputService.InputChanged:Connect(function(newInput)
			if newInput.UserInputType ~= Enum.UserInputType.MouseMovement
				and newInput.UserInputType ~= Enum.UserInputType.Touch then
				return
			end

			local size = Scale:Viewport()
			local delta = Vector2.new(newInput.Position.X, newInput.Position.Y) - startMouse
			moved = moved + delta.Magnitude

			-- 限制在屏幕内
			frac.X = math.clamp(startPos.X + delta.X / size.X, 0, math.max(1 - frame.AbsoluteSize.X / size.X, 0))
			frac.Y = math.clamp(startPos.Y + delta.Y / size.Y, 0, math.max(1 - frame.AbsoluteSize.Y / size.Y, 0))

			Scale:SetFollow(frame, frac.X, frac.Y)
		end)

		endConn = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false

				if moveConn then moveConn:Disconnect() end
				if endConn then endConn:Disconnect() end

				if opts.OnEnd then
					env:Safe(opts.OnEnd, moved)
				end
			end
		end)
	end)

	return frac
end

-- 提示气泡（Vape 风格：跟随鼠标的小黑条）
function Util:Tooltip(gui, text)
	if not text or text == '' then return end

	local tooltip = Util.TooltipObject
	if not tooltip then
		local root = Scale.Root
		if not root then return end

		tooltip = Instance.new('TextLabel')
		tooltip.BackgroundColor3 = Color:Dark(Theme.Main, 0.02)
		tooltip.Name = 'Tooltip'
		tooltip.Position = UDim2.fromScale(-1, -1)
		tooltip.RichText = true
		tooltip.Text = ''
		tooltip.TextColor3 = Color:Dark(Theme.Text, 0.16)
		tooltip.TextXAlignment = Enum.TextXAlignment.Left
		tooltip.Visible = false
		tooltip.ZIndex = 20
		tooltip.Parent = root
		Util:Corner(tooltip)
		Util:Stroke(tooltip, Theme.Stroke, 0.8)
		Util:Font(tooltip)
		Scale:Text(tooltip, 12)
		Util.TooltipObject = tooltip
	end

	local function show(x, y)
		tooltip.Text = text
		local bounds = Util:TextBounds(text, 12)
		local viewport = Scale:Viewport()
		local pixel = Scale:PX(1)

		tooltip.Size = UDim2.fromOffset(bounds.X + 12 * pixel, bounds.Y + 8 * pixel)

		local posX = x + 16 * pixel
		if posX + tooltip.AbsoluteSize.X > viewport.X - 8 then
			posX = x - tooltip.AbsoluteSize.X - 16 * pixel
		end

		tooltip.Position = UDim2.fromOffset(posX, y + 12 * pixel)
		tooltip.Visible = true
	end

	gui.MouseEnter:Connect(show)
	gui.MouseMoved:Connect(show)
	gui.MouseLeave:Connect(function()
		tooltip.Visible = false
	end)
end

-- 图标（按原始比例显示，不做拉伸）
function Util:Image(parent, name, width, height, color)
	local image = Instance.new('ImageLabel')
	image.BackgroundTransparency = 1
	image.Image = Lib.Assets:Get(name)
	image.ImageColor3 = color or Color:Light(Theme.Main, 0.37)
	image.Name = name
	image.Parent = parent
	Scale:Size(image, width, height or width)

	return image
end

-- 图标按钮：点击区域是正方形(size)，里面的图保持原始比例居中
-- right = true 时 x 表示「距离右边的距离」
function Util:IconButton(parent, name, x, y, size, imageWidth, imageHeight, right)
	size = size or 20
	imageWidth = imageWidth or size * 0.8
	imageHeight = imageHeight or imageWidth

	local button = Instance.new('TextButton')
	button.AutoButtonColor = false
	button.BackgroundTransparency = 1
	button.Name = (name:gsub('^%l', string.upper)) .. 'Button'
	button.Text = ''
	button.Parent = parent
	Scale:Size(button, size, size)

	if right then
		Scale:PosRight(button, x, y)
	else
		Scale:Pos(button, x, y)
	end

	local image = Util:Image(button, name, imageWidth, imageHeight)
	Scale:Pos(image, (size - imageWidth) / 2, (size - imageHeight) / 2)

	Util:Hover(button, function()
		image.ImageColor3 = Theme.Text
	end, function()
		image.ImageColor3 = Color:Light(Theme.Main, 0.37)
	end)

	return button, image
end

--[==[ 06_Ball.lua ]==]
--[==[
	Nova GUI  ·  06_Ball
	悬浮球：长方形 + 像素小圆角 + 百分比尺寸。
	  · 拖动：松手后自动吸附到屏幕左/右边缘
	  · 单击：开关整个 GUI（拖动过就不会触发点击）
	  · 右键：收起/展开所有窗口
]==]

local Lib = NovaLib or getgenv().NovaLib
local env = Lib.Env
local Scale = Lib.Scale
local Theme = Lib.Theme
local Color = Lib.Color
local Util = Lib.Util

function Lib:CreateBall(props)
	props = props or {}

	local existing = self.Ball
	if existing and existing.Object then
		existing.Object:Destroy()
	end

	local width = props.Width or Theme.BallWidth
	local height = props.Height or Theme.BallHeight

	local ball = {
		Moved = 0,
		Snap = props.Snap ~= false,
		Visible = true
	}

	local frame = Instance.new('TextButton')
	frame.AutoButtonColor = false
	frame.BackgroundColor3 = Color:Dark(Theme.Main, 0.02)
	frame.Name = 'Ball'
	frame.Text = ''
	frame.Parent = Scale.Root
	Scale:Size(frame, width, height)
	-- props.X / props.Y 是 0~1 的屏幕比例（悬浮球需要贴边）
	Scale:PositionF(frame, props.X or 0.012, props.Y or 0.46)

	Util:Corner(frame, props.Corner or Theme.Corner)
	Util:Shadow(frame)

	local stroke = Util:Stroke(frame, Theme.Stroke, 0.7)

	local iconSize = math.min(24, height - 8)
	local icon = Instance.new('ImageLabel')
	icon.BackgroundTransparency = 1
	icon.Image = Lib.Assets:Get('logo_small')
	icon.Name = 'Logo'
	icon.Parent = frame
	Scale:Size(icon, iconSize, iconSize)
	Scale:Position(icon, 9, (height - iconSize) / 2)

	local label = Instance.new('TextLabel')
	label.BackgroundTransparency = 1
	label.Name = 'Title'
	label.Text = props.Text or string.upper(Lib.Name)
	label.TextColor3 = Theme.Text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = frame
	Util:Font(label, true)
	Scale:Text(label, props.TextSize or 15)
	Scale:Size(label, width - iconSize - 20, height)
	Scale:Position(label, iconSize + 16, 0)

	ball.Object = frame
	ball.Stroke = stroke
	ball.Label = label

	function ball:SetVisible(visible)
		self.Visible = visible
		frame.Visible = visible
	end

	-- GUI 打开时描边变成强调色
	function ball:SetActive(active)
		local ok = pcall(function()
			env:Tween(stroke, Theme.Tween, {
				Color = active and Theme:Accent() or Theme.Stroke,
				Transparency = active and 0.35 or 0.7
			})
		end)

		if not ok then
			stroke.Color = active and Theme:Accent() or Theme.Stroke
		end
	end

	-- 位置存的是屏幕比例（不是像素），这样换分辨率也不会跑偏
	function ball:SavePosition()
		return {
			X = self.Frac and self.Frac.X or 0.012,
			Y = self.Frac and self.Frac.Y or 0.46
		}
	end

	function ball:LoadPosition(data)
		if type(data) ~= 'table' or not self.Frac then return end

		local viewport = Scale:Viewport()
		local sizeX = frame.AbsoluteSize.X / viewport.X
		local sizeY = frame.AbsoluteSize.Y / viewport.Y

		self.Frac.X = math.clamp(data.X or 0.012, 0, math.max(1 - sizeX, 0))
		self.Frac.Y = math.clamp(data.Y or 0.46, 0, math.max(1 - sizeY, 0))
		Scale:SetFollow(frame, self.Frac.X, self.Frac.Y)
	end

	-- 拖动 + 边缘吸附
	ball.Frac = Util:Drag(frame, frame, {
		OnEnd = function(moved)
			ball.Moved = moved

			if ball.Snap then
				local viewport = Scale:Viewport()
				local sizeX = frame.AbsoluteSize.X / viewport.X
				local x = ball.Frac.X
				local target = (x + sizeX / 2) < 0.5 and 0.008 or math.max(1 - sizeX - 0.008, 0)

				ball.Frac.X = target
				env:Tween(frame, TweenInfo.new(0.25, Enum.EasingStyle.Exponential), {
					Position = UDim2.new(0, target * viewport.X, 0, ball.Frac.Y * viewport.Y)
				})
			end

			if Lib.OnBallMoved then
				env:Safe(Lib.OnBallMoved)
			end

			if Lib.AutoSave then
				Lib:Save()
			end
		end
	})

	Util:Hover(frame, function()
		env:Tween(frame, Theme.Tween, {
			BackgroundColor3 = Color:Light(Theme.Main, 0.03)
		})
	end, function()
		env:Tween(frame, Theme.Tween, {
			BackgroundColor3 = Color:Dark(Theme.Main, 0.02)
		})
	end)

	frame.MouseButton1Down:Connect(function()
		ball.Moved = 0
	end)

	Util:Click(frame, function()
		if ball.Moved > 5 then return end

		Lib:ToggleGUI()
	end)

	Util:RightClick(frame, function()
		local opened = false
		for _, window in pairs(Lib.Windows) do
			if window.Visible then
				opened = true
				break
			end
		end

		if not opened and not Lib.Visible then
			Lib:SetVisible(true)
		end

		for _, window in pairs(Lib.Windows) do
			window:SetVisible(not opened)
		end
	end)

	self.Ball = ball

	return ball
end

--[==[ 07_Window.lua ]==]
--[==[
	Nova GUI  ·  07_Window
	多窗口系统：每个窗口都是独立可拖动 / 可折叠 / 可关闭的对象，
	窗口之间互不干扰，主窗口(MainWindow)里列出所有窗口并可单独开关。
]==]

local Lib = NovaLib or getgenv().NovaLib
local env = Lib.Env
local Scale = Lib.Scale
local Theme = Lib.Theme
local Color = Lib.Color
local Util = Lib.Util

local function cascade(index)
	return 40 + (index % 5) * 34, 110 + (index % 5) * 30
end

function Lib:CreateWindow(props)
	props = props or {}

	local index = 0
	for _ in pairs(self.Windows) do
		index = index + 1
	end

	local window = {
		Name = props.Name or ('Window' .. (index + 1)),
		Width = props.Width or Theme.WindowWidth,
		MaxHeight = props.MaxHeight,
		ShowInList = props.ShowInList ~= false,
		Icon = props.Icon,
		Visible = false,
		Collapsed = false,
		Widgets = {},
		Height = 0,
		Connections = {}
	}

	local frame = Instance.new('Frame')
	frame.BackgroundColor3 = Color:Dark(Theme.Main, 0.02)
	frame.Name = window.Name
	frame.Visible = false
	frame.Parent = self.Container
	Scale:Pos(frame, props.X or select(1, cascade(index)), props.Y or select(2, cascade(index)))
	Scale:Track(frame, 'Size', function(s)
		return UDim2.fromOffset(s:W(window.Width), window.Height)
	end)

	Util:Corner(frame, props.Corner or Theme.Corner)
	Util:Stroke(frame)
	Util:Shadow(frame)

	local topbar = Instance.new('TextButton')
	topbar.AutoButtonColor = false
	topbar.BackgroundTransparency = 1
	topbar.Name = 'Topbar'
	topbar.Text = ''
	topbar.Parent = frame
	Scale:SizeW(topbar, Theme.TopbarHeight)

	local iconWidth = 0
	if window.Icon then
		iconWidth = props.IconSize or 16
		local icon = Util:Image(topbar, window.Icon, iconWidth, props.IconHeight or iconWidth, Theme:Accent())
		Scale:Pos(icon, 11, (Theme.TopbarHeight - iconWidth) / 2)
		Theme:RegisterAccent(icon, 'ImageColor3')
	end

	local title = Instance.new('TextLabel')
	title.BackgroundTransparency = 1
	title.Name = 'Title'
	title.Text = window.Name
	title.TextColor3 = Theme.Text
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.Parent = topbar
	Util:Font(title, true)
	Scale:Text(title, 14)
	Scale:Size(title, window.Width - (iconWidth > 0 and iconWidth + 24 or 22) - 46, Theme.TopbarHeight)
	Scale:Pos(title, iconWidth > 0 and iconWidth + 22 or 11, 0)

	-- 分隔线
	local divider = Instance.new('Frame')
	divider.BackgroundColor3 = Theme.Divider
	divider.BorderSizePixel = 0
	divider.Name = 'Divider'
	divider.Parent = frame
	Scale:Track(divider, 'Size', function(s)
		return UDim2.new(1, 0, 0, math.max(s:PX(1), 1))
	end)
	Scale:Track(divider, 'Position', function(s)
		return UDim2.fromOffset(0, s:H(Theme.TopbarHeight) - math.max(s:PX(1), 1))
	end)

	-- 主体（内容超出最大高度时滚动）
	local body = Instance.new('ScrollingFrame')
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Name = 'Body'
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.ElasticBehavior = Enum.ElasticBehavior.Never
	body.ScrollBarImageColor3 = Color:Light(Theme.Main, 0.25)
	body.ScrollBarImageTransparency = 0.4
	body.ScrollingDirection = Enum.ScrollingDirection.Y
	body.Parent = frame
	Scale:Track(body, 'Position', function(s)
		return UDim2.fromOffset(0, s:H(Theme.TopbarHeight))
	end)
	Scale:Track(body, 'Size', function(s)
		return UDim2.new(1, 0, 0, math.max(window.Height - s:H(Theme.TopbarHeight), 0))
	end)
	Scale:Track(body, 'ScrollBarThickness', function(s)
		return s:PX(4)
	end)

	local list = Instance.new('UIListLayout')
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = body

	window.Object = frame
	window.Topbar = topbar
	window.Body = body
	window.List = list
	window.Title = title

	-- 高度：标题栏 + 内容，超过最大高度则滚动
	function window:UpdateHeight()
		local topbarHeight = Scale:H(Theme.TopbarHeight)
		local viewport = Scale:Viewport()
		local limit = self.MaxHeight and Scale:H(self.MaxHeight) or (viewport.Y * 0.78)
		local content = self.Collapsed and 0 or list.AbsoluteContentSize.Y

		self.Height = math.min(topbarHeight + content, limit)
		Scale:Apply(frame)
		Scale:Apply(body)
	end

	-- 控件都通过 :Update() 通知窗口重算高度
	function window:Update()
		self:UpdateHeight()
	end

	window:UpdateHeight()
	table.insert(window.Connections, list:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
		window:UpdateHeight()
	end))

	function window:SetVisible(visible)
		self.Visible = visible
		frame.Visible = visible

		if self.Row then
			self.Row:Update()
		end

		if Lib.AutoSave then
			Lib:Save()
		end
	end

	function window:Toggle()
		self:SetVisible(not self.Visible)
	end

	function window:SetCollapsed(collapsed)
		self.Collapsed = collapsed
		body.Visible = not collapsed
		self:UpdateHeight()

		if self.CollapseIcon then
			self.CollapseIcon.Image = Lib.Assets:Get(collapsed and 'expand' or 'collapse')
		end
	end

	function window:SetName(name)
		self.Name = name
		title.Text = name

		if self.Row then
			self.Row.Label.Text = name
		end
	end

	function window:Clear()
		for _, child in ipairs(body:GetChildren()) do
			if child:IsA('GuiObject') then
				child:Destroy()
			end
		end

		table.clear(self.Widgets)
		self:UpdateHeight()
	end

	function window:Destroy()
		for _, connection in ipairs(self.Connections) do
			pcall(function()
				connection:Disconnect()
			end)
		end

		if self.Row and self.Row.Destroy then
			self.Row:Destroy()
		end

		Scale:Cancel(frame)
		frame:Destroy()
		Lib.Windows[self.Name] = nil
	end

	-- 右上角的折叠 / 关闭
	local collapseButton, collapseIcon = Util:IconButton(topbar, 'collapse', 34, (Theme.TopbarHeight - 20) / 2, 20, 10, 5, true)
	window.CollapseIcon = collapseIcon

	Util:Click(collapseButton, function()
		window:SetCollapsed(not window.Collapsed)
	end)
	Util:Tooltip(collapseButton, '折叠 / 展开')

	local closeSize = 20
	local closeButton, closeIcon = Util:IconButton(topbar, 'close', 8, (Theme.TopbarHeight - closeSize) / 2, closeSize, 14, 14, true)

	Util:Click(closeButton, function()
		window:SetVisible(false)
	end)
	Util:Tooltip(closeButton, '隐藏窗口（主窗口里可以再打开）')

	-- 拖动：整个标题栏都可以拖
	window.Frac = Util:Drag(frame, topbar, {
		OnEnd = function()
			if Lib.AutoSave then
				Lib:Save()
			end
		end
	})

	-- 双击标题栏折叠
	Util:Click(topbar, function()
		if window.LastClick and tick() - window.LastClick < 0.3 then
			window:SetCollapsed(not window.Collapsed)
		end

		window.LastClick = tick()
	end)

	-- 挂上所有控件方法（AddToggle / AddButton / ...）
	for name, builder in pairs(Lib.Widgets or {}) do
		window['Add' .. name] = function(self, widgetProps)
			return builder(self, widgetProps or {})
		end
	end

	self.Windows[window.Name] = window

	if window.ShowInList and self.MainWindow then
		self.MainWindow:AddWindowRow(window)
	end

	if props.Visible then
		window:SetVisible(true)
	end

	if self.ApplyWindowState then
		self:ApplyWindowState(window)
	end

	return window
end

-- 主窗口：列出所有窗口
function Lib:CreateMainWindow(props)
	props = props or {}
	props.Name = props.Name or self.Name
	props.Icon = props.Icon or 'logo_small'
	props.IconSize = props.IconSize or 18
	props.ShowInList = false
	props.Width = props.Width or 220

	local main = self:CreateWindow(props)
	self.MainWindow = main

	-- 主窗口里已有的行（在我之前创建的窗口）
	function main:AddWindowRow(window)
		local row = {}

		local button = Instance.new('TextButton')
		button.AutoButtonColor = false
		button.BackgroundColor3 = Theme.Main
		button.BorderSizePixel = 0
		button.Name = window.Name
		button.Text = ''
		button.Parent = self.Body
		Scale:SizeW(button, 34)

		local iconWidth = 0
		if window.Icon then
			iconWidth = 16
			local icon = Util:Image(button, window.Icon, iconWidth, iconWidth, window.Visible and Theme:Accent() or Color:Light(Theme.Main, 0.37))
			Scale:Pos(icon, 12, 9)
			row.Icon = icon
		end

		local label = Instance.new('TextLabel')
		label.BackgroundTransparency = 1
		label.Name = 'Label'
		label.Text = window.Name
		label.TextColor3 = Color:Dark(Theme.Text, 0.16)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.Parent = button
		Util:Font(label)
		Scale:Text(label, 14)
		Scale:Size(label, self.Width - (iconWidth > 0 and iconWidth + 24 or 22) - 30, 34)
		Scale:Pos(label, iconWidth > 0 and iconWidth + 22 or 12, 0)

		-- 右侧状态点：窗口显示时点亮
		local dot = Instance.new('Frame')
		dot.BackgroundColor3 = Color:Light(Theme.Main, 0.14)
		dot.BorderSizePixel = 0
		dot.Name = 'Dot'
		dot.Parent = button
		Scale:Size(dot, 8, 8)
		Scale:PosRight(dot, 12, 13)
		Util:Pill(dot)

		row.Object = button
		row.Label = label
		row.Dot = dot
		row.IconWidth = iconWidth

		function row:Update()
			local enabled = window.Visible
			label.TextColor3 = enabled and Theme.Text or Color:Dark(Theme.Text, 0.16)
			button.BackgroundColor3 = enabled and Color:Light(Theme.Main, 0.04) or Theme.Main
			dot.BackgroundColor3 = enabled and Theme:Accent() or Color:Light(Theme.Main, 0.14)

			if row.Icon then
				row.Icon.ImageColor3 = enabled and Theme:Accent() or Color:Light(Theme.Main, 0.37)
			end
		end

		function row:Destroy()
			Scale:Cancel(button)
			button:Destroy()
		end

		Util:Hover(button, function()
			label.TextColor3 = Theme.Text
		end, function()
			row:Update()
		end)

		Util:Click(button, function()
			window:Toggle()
		end)

		Util:Tooltip(button, '开关「' .. window.Name .. '」窗口')

		window.Row = row
		row:Update()

		return row
	end

	for _, window in pairs(self.Windows) do
		if window ~= main and window.ShowInList then
			main:AddWindowRow(window)
		end
	end

	return main
end

-- 主窗口底部信息条
function Lib:AddCredit(window, text)
	window = window or self.MainWindow
	if not window then return end

	local label = Instance.new('TextLabel')
	label.BackgroundTransparency = 1
	label.Name = 'Credit'
	label.Text = text or (self.Name .. ' v' .. self.Version)
	label.TextColor3 = Color:Dark(Theme.Text, 0.5)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = window.Body
	Util:Font(label)
	Scale:Text(label, 12)
	Scale:SizeW(label, 24)
	Scale:Padding(label, 12, 0, 0, 0)

	return label
end

--[==[ 08_Widgets.lua ]==]
--[==[
	Nova GUI  ·  08_Widgets
	控件：分区 / 标签 / 开关 / 按钮 / 滑块 / 下拉 / 输入框 / 按键绑定 / 模块(可展开)
	每个控件的尺寸都用设计像素描述，随屏幕百分比变化。
]==]

local Lib = NovaLib or getgenv().NovaLib
local env = Lib.Env
local Scale = Lib.Scale
local Theme = Lib.Theme
local Color = Lib.Color
local Util = Lib.Util

local Widgets = {}
Lib.Widgets = Widgets

--[[ 公共工具 ]]

-- 自动高度：容器高度 = 子内容高度（屏幕尺寸变化时也会跟着重算）
local function bindHeight(frame, list, extra)
	Scale:Track(frame, 'Size', function(s)
		return UDim2.new(1, 0, 0, list.AbsoluteContentSize.Y + s:H(extra or 0))
	end)

	list:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
		Scale:Apply(frame)
	end)

	Scale:Apply(frame)
end

-- 基础行
local function row(container, height, props)
	props = props or {}

	local obj = Instance.new('TextButton')
	obj.AutoButtonColor = false
	obj.BackgroundColor3 = props.Darker and Color:Dark(Theme.Main, 0.02) or Theme.Main
	obj.BorderSizePixel = 0
	obj.Name = props.Name or 'Row'
	obj.Text = ''
	obj.Visible = props.Visible ~= false
	obj.Parent = container.Body
	Scale:SizeW(obj, height)

	return obj
end

-- 文字标签
local function text(parent, str, height, width, x, size, dim, semiBold)
	local label = Instance.new('TextLabel')
	label.BackgroundTransparency = 1
	label.Name = 'Label'
	label.Text = str
	label.TextColor3 = dim and Color:Dark(Theme.Text, 0.16) or Theme.Text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Parent = parent
	Util:Font(label, semiBold)
	Scale:Text(label, size or 14)
	Scale:Size(label, width, height)
	Scale:Pos(label, x or 12, 0)

	return label
end

-- 行底部分隔线
local function divider(parent, height)
	local line = Instance.new('Frame')
	line.BackgroundColor3 = Color:Dark(Theme.Main, 0.06)
	line.BorderSizePixel = 0
	line.Name = 'Line'
	line.Parent = parent
	Scale:Track(line, 'Size', function(s)
		return UDim2.new(1, 0, 0, math.max(s:PX(1), 1))
	end)
	Scale:Track(line, 'Position', function(s)
		return UDim2.fromOffset(0, s:H(height) - math.max(s:PX(1), 1))
	end)

	return line
end

-- 注册控件到容器
local function register(container, component)
	component.Parent = container
	table.insert(container.Widgets, component)

	if container.Update then
		container:Update()
	end

	return component
end

--[[ 分区标题 ]]

function Widgets:Section(props)
	local height = props.Height or 26

	local obj = Instance.new('Frame')
	obj.BackgroundColor3 = Color:Dark(Theme.Main, 0.03)
	obj.BorderSizePixel = 0
	obj.Name = props.Name or 'Section'
	obj.Visible = props.Visible ~= false
	obj.Parent = self.Body
	Scale:SizeW(obj, height)

	local label = text(obj, string.upper(props.Name or ''), height, self.Width - 24, 12, 11, true, true)
	label.TextTransparency = 0.15

	local component = {
		Type = 'Section',
		Name = props.Name or 'Section',
		Object = obj,
		Label = label
	}

	function component:SetName(name)
		self.Name = name
		label.Text = string.upper(name)
	end

	function component:SetVisible(visible)
		obj.Visible = visible
	end

	return register(self, component)
end

--[[ 普通文字标签 ]]

function Widgets:Label(props)
	local height = props.Height or 24

	local obj = row(self, height, props)
	local label = text(obj, props.Text or props.Name or '', height, self.Width - 24, 12, props.Size or 13, props.Dim ~= false)

	local component = {
		Type = 'Label',
		Name = props.Name or 'Label',
		Object = obj,
		Label = label
	}

	function component:SetText(value)
		label.Text = tostring(value)
	end

	function component:SetVisible(visible)
		obj.Visible = visible
	end

	return register(self, component)
end

--[[ 开关 ]]

function Widgets:Toggle(props)
	local height = props.Height or Theme.RowHeight
	local component = {
		Type = 'Toggle',
		Name = props.Name or 'Toggle',
		Enabled = props.Default == true,
		Callback = props.Callback
	}

	local obj = row(self, height, props)
	component.Object = obj

	text(obj, props.Name or 'Toggle', height, self.Width - 60, 12, 14, true)

	local holder = Instance.new('Frame')
	holder.BackgroundColor3 = Color:Light(Theme.Main, 0.14)
	holder.BorderSizePixel = 0
	holder.Name = 'Holder'
	holder.Parent = obj
	Scale:Size(holder, 22, 12)
	Scale:PosRight(holder, 11, (height - 12) / 2)
	Util:Pill(holder)

	local knob = Instance.new('Frame')
	knob.BackgroundColor3 = Theme.Main
	knob.BorderSizePixel = 0
	knob.Name = 'Knob'
	knob.Parent = holder
	Scale:Size(knob, 8, 8)
	Scale:Track(knob, 'Position', function(s)
		return UDim2.fromOffset(s:W(component.Enabled and 12 or 2), s:H(2))
	end)
	Util:Pill(knob)

	divider(obj, height)

	function component:SetEnabled(enabled, skipCallback)
		self.Enabled = enabled

		pcall(function()
			env:Tween(holder, Theme.Tween, {
				BackgroundColor3 = enabled and Theme:Accent() or Color:Light(Theme.Main, 0.14)
			})

			env:Tween(knob, Theme.Tween, {
				Position = UDim2.fromOffset(Scale:W(enabled and 12 or 2), Scale:H(2))
			})
		end)

		if not skipCallback and self.Callback then
			env:Safe(self.Callback, enabled)
		end
	end

	function component:Toggle()
		self:SetEnabled(not self.Enabled)
	end

	function component:SetValue(value)
		self:SetEnabled(value == true)
	end

	function component:SetVisible(visible)
		obj.Visible = visible
	end

	Util:Hover(obj, function()
		env:Tween(obj, Theme.Tween, {
			BackgroundColor3 = Color:Light(Theme.Main, 0.02)
		})
	end, function()
		env:Tween(obj, Theme.Tween, {
			BackgroundColor3 = props.Darker and Color:Dark(Theme.Main, 0.02) or Theme.Main
		})
	end)

	Util:Click(obj, function()
		component:Toggle()
	end)

	Util:Tooltip(obj, props.Tooltip)

	component:SetEnabled(component.Enabled, true)

	return register(self, component)
end

--[[ 按钮 ]]

function Widgets:Button(props)
	local height = props.Height or Theme.RowHeight
	local component = {
		Type = 'Button',
		Name = props.Name or 'Button',
		Callback = props.Callback
	}

	local obj = row(self, height, props)
	component.Object = obj

	text(obj, props.Name or 'Button', height, self.Width - 24, 12, 14, true)
	divider(obj, height)

	function component:Fire()
		if self.Callback then
			env:Safe(self.Callback)
		end
	end

	function component:SetName(name)
		self.Name = name
		obj.Label.Text = name
	end

	function component:SetVisible(visible)
		obj.Visible = visible
	end

	Util:Hover(obj, function()
		env:Tween(obj, Theme.Tween, {
			BackgroundColor3 = Color:Light(Theme.Main, 0.04)
		})
	end, function()
		env:Tween(obj, Theme.Tween, {
			BackgroundColor3 = props.Darker and Color:Dark(Theme.Main, 0.02) or Theme.Main
		})
	end)

	Util:Click(obj, function()
		component:Fire()
	end)

	Util:Tooltip(obj, props.Tooltip)

	return register(self, component)
end

--[[ 滑块 ]]

function Widgets:Slider(props)
	local height = props.Height or 42
	local min = props.Min or 0
	local max = props.Max or 100
	local decimals = props.Decimals or 0

	local component = {
		Type = 'Slider',
		Name = props.Name or 'Slider',
		Min = min,
		Max = max,
		Value = props.Default or min,
		Callback = props.Callback,
		Suffix = props.Suffix or ''
	}

	local obj = row(self, height, props)
	component.Object = obj

	text(obj, props.Name or 'Slider', 22, self.Width - 90, 12, 14, true)

	local valueLabel = Instance.new('TextLabel')
	valueLabel.BackgroundTransparency = 1
	valueLabel.Name = 'Value'
	valueLabel.TextColor3 = Color:Dark(Theme.Text, 0.02)
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	valueLabel.Parent = obj
	Util:Font(valueLabel, true)
	Scale:Text(valueLabel, 13)
	Scale:Size(valueLabel, 70, 22)
	Scale:PosRight(valueLabel, 12, 0)

	-- 命中区域（比细条高，方便拖动）
	local hit = Instance.new('TextButton')
	hit.AutoButtonColor = false
	hit.BackgroundTransparency = 1
	hit.Name = 'Hit'
	hit.Text = ''
	hit.Parent = obj
	Scale:Size(hit, self.Width - 24, 16)
	Scale:Pos(hit, 12, 22)

	local bar = Instance.new('Frame')
	bar.BackgroundColor3 = Color:Dark(Theme.Main, 0.1)
	bar.BorderSizePixel = 0
	bar.Name = 'Bar'
	bar.Parent = hit
	Scale:Size(bar, self.Width - 24, 4)
	Scale:Pos(bar, 0, 6)
	Util:Pill(bar)

	local fill = Instance.new('Frame')
	fill.BackgroundColor3 = Theme:Accent()
	fill.BorderSizePixel = 0
	fill.Name = 'Fill'
	fill.Parent = bar
	Scale:SizeH(fill, 0)
	Util:Pill(fill)
	Theme:RegisterAccent(fill, 'BackgroundColor3')

	local knob = Instance.new('Frame')
	knob.BackgroundColor3 = Theme.Text
	knob.BorderSizePixel = 0
	knob.Name = 'Knob'
	knob.Parent = bar
	Scale:Size(knob, 10, 10)
	Scale:Track(knob, 'Position', function(s)
		return UDim2.fromOffset(bar.AbsoluteSize.X * (component.Fraction or 0) - s:W(5), -s:H(3))
	end)
	Util:Pill(knob)

	divider(obj, height)

	local function round(value)
		local mult = 10 ^ decimals

		return math.floor(value * mult + 0.5) / mult
	end

	function component:SetValue(value, skipCallback)
		value = math.clamp(tonumber(value) or self.Min, self.Min, self.Max)
		self.Value = round(value)

		local fraction = (self.Value - self.Min) / math.max(self.Max - self.Min, 0.0001)
		self.Fraction = fraction
		valueLabel.Text = tostring(self.Value) .. self.Suffix

		pcall(function()
			fill.Size = UDim2.new(fraction, 0, 1, 0)
			knob.Position = UDim2.fromOffset(bar.AbsoluteSize.X * fraction - Scale:W(5), -Scale:H(3))
		end)

		if not skipCallback and self.Callback then
			env:Safe(self.Callback, self.Value)
		end
	end

	function component:SetVisible(visible)
		obj.Visible = visible
	end

	local function fromInput(inputX)
		local fraction = math.clamp((inputX - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
		component:SetValue(min + (max - min) * fraction)
	end

	local dragging = false

	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			fromInput(input.Position.X)

			local connection
			connection = env.InputService.InputChanged:Connect(function(newInput)
				if newInput.UserInputType == Enum.UserInputType.MouseMovement
					or newInput.UserInputType == Enum.UserInputType.Touch then
					fromInput(newInput.Position.X)
				end
			end)

			local release
			release = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					connection:Disconnect()
					release:Disconnect()
				end
			end)
		end
	end)

	Util:Tooltip(obj, props.Tooltip)
	component:SetValue(component.Value, true)

	return register(self, component)
end

--[[ 下拉 ]]

function Widgets:Dropdown(props)
	local height = props.Height or Theme.RowHeight
	local containerWidth = self.Width
	local component = {
		Type = 'Dropdown',
		Name = props.Name or 'Dropdown',
		List = props.List or {},
		Value = props.Default,
		Callback = props.Callback,
		Open = false,
		Options = {}
	}

	local obj = row(self, height, props)
	component.Object = obj

	text(obj, props.Name or 'Dropdown', height, self.Width - 90, 12, 14, true)

	local selected = Instance.new('TextLabel')
	selected.BackgroundTransparency = 1
	selected.Name = 'Selected'
	selected.TextColor3 = Color:Dark(Theme.Text, 0.02)
	selected.TextXAlignment = Enum.TextXAlignment.Right
	selected.TextTruncate = Enum.TextTruncate.AtEnd
	selected.Parent = obj
	Util:Font(selected)
	Scale:Text(selected, 13)
	Scale:Size(selected, 60, height)
	Scale:PosRight(selected, 26, 0)

	local chevron = Util:Image(obj, 'chevron', 10, 5)
	Scale:PosRight(chevron, 12, (height - 5) / 2)

	divider(obj, height)

	-- 展开后的选项容器
	local container = Instance.new('Frame')
	container.BackgroundColor3 = Color:Dark(Theme.Main, 0.03)
	container.BorderSizePixel = 0
	container.Name = 'Options'
	container.Visible = false
	container.Parent = self.Body

	local listLayout = Instance.new('UIListLayout')
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = container

	bindHeight(container, listLayout, 0)

	function component:SetValue(value, skipCallback)
		self.Value = value
		selected.Text = tostring(value or '')

		for name, option in pairs(self.Options) do
			local active = name == value
			option.Check.Visible = active
			option.Label.TextColor3 = active and Theme.Text or Color:Dark(Theme.Text, 0.16)
		end

		if not skipCallback and self.Callback then
			env:Safe(self.Callback, value)
		end
	end

	function component:SetList(list)
		self.List = list

		for _, option in pairs(self.Options) do
			option.Object:Destroy()
		end

		table.clear(self.Options)
		self:Build()
	end

	function component:Build()
		for _, value in ipairs(self.List) do
			local option = Instance.new('TextButton')
			option.AutoButtonColor = false
			option.BackgroundColor3 = Theme.Main
			option.BorderSizePixel = 0
			option.Name = tostring(value)
			option.Text = ''
			option.Parent = container
			Scale:SizeW(option, 26)

			local check = Util:Image(option, 'check', 12, 10, Theme:Accent())
			Scale:Pos(check, 14, 8)
			check.Visible = false
			Theme:RegisterAccent(check, 'ImageColor3')

			local label = text(option, tostring(value), 26, containerWidth - 60, 32, 13, true)

			self.Options[value] = {
				Object = option,
				Label = label,
				Check = check
			}

			Util:Hover(option, function()
				option.BackgroundColor3 = Color:Light(Theme.Main, 0.03)
			end, function()
				option.BackgroundColor3 = Theme.Main
			end)

			Util:Click(option, function()
				component:SetValue(value)
				component:SetOpen(false)
			end)
		end
	end

	function component:SetOpen(open)
		self.Open = open
		container.Visible = open
		chevron.Image = Lib.Assets:Get(open and 'collapse' or 'chevron')

		if self.Parent and self.Parent.Update then
			self.Parent:Update()
		end
	end

	function component:SetVisible(visible)
		obj.Visible = visible

		if not visible then
			container.Visible = false
		else
			container.Visible = self.Open
		end
	end

	Util:Hover(obj, function()
		env:Tween(obj, Theme.Tween, {
			BackgroundColor3 = Color:Light(Theme.Main, 0.03)
		})
	end, function()
		env:Tween(obj, Theme.Tween, {
			BackgroundColor3 = props.Darker and Color:Dark(Theme.Main, 0.02) or Theme.Main
		})
	end)

	Util:Click(obj, function()
		component:SetOpen(not component.Open)
	end)

	Util:Tooltip(obj, props.Tooltip)

	component:Build()
	component:SetValue(component.Value or component.List[1], true)

	return register(self, component)
end

--[[ 输入框 ]]

function Widgets:TextBox(props)
	local height = props.Height or Theme.RowHeight
	local component = {
		Type = 'TextBox',
		Name = props.Name or 'TextBox',
		Value = props.Default or '',
		Callback = props.Callback
	}

	local obj = row(self, height, props)
	component.Object = obj

	text(obj, props.Name or 'TextBox', height, self.Width - 120, 12, 14, true)

	local holder = Instance.new('Frame')
	holder.BackgroundColor3 = Color:Dark(Theme.Main, 0.06)
	holder.BorderSizePixel = 0
	holder.Name = 'Holder'
	holder.Parent = obj
	Scale:Size(holder, 100, 20)
	Scale:PosRight(holder, 12, (height - 20) / 2)
	Util:Corner(holder, Theme.CornerSmall)

	local input = Instance.new('TextBox')
	input.BackgroundTransparency = 1
	input.ClearTextOnFocus = false
	input.Name = 'Input'
	input.PlaceholderText = props.Placeholder or ''
	input.PlaceholderColor3 = Color:Dark(Theme.Text, 0.4)
	input.Text = component.Value
	input.TextColor3 = Theme.Text
	input.TextXAlignment = Enum.TextXAlignment.Left
	input.Parent = holder
	Util:Font(input)
	Scale:Text(input, 13)
	Scale:Size(input, 92, 20)
	Scale:Pos(input, 6, 0)

	divider(obj, height)

	function component:SetValue(value, skipCallback)
		self.Value = tostring(value)
		input.Text = self.Value

		if not skipCallback and self.Callback then
			env:Safe(self.Callback, self.Value)
		end
	end

	function component:SetVisible(visible)
		obj.Visible = visible
	end

	input.FocusLost:Connect(function(enterPressed)
		component:SetValue(input.Text)

		if props.ClearOnFocus then
			input.Text = ''
		end
	end)

	Util:Tooltip(obj, props.Tooltip)

	return register(self, component)
end

--[[ 按键绑定 ]]

function Widgets:Keybind(props)
	local height = props.Height or Theme.RowHeight
	local component = {
		Type = 'Keybind',
		Name = props.Name or 'Keybind',
		Value = props.Default,
		Callback = props.Callback
	}

	local obj = row(self, height, props)
	component.Object = obj

	text(obj, props.Name or 'Keybind', height, self.Width - 120, 12, 14, true)

	local holder = Instance.new('TextButton')
	holder.AutoButtonColor = false
	holder.BackgroundColor3 = Color:Light(Theme.Main, 0.14)
	holder.BorderSizePixel = 0
	holder.Name = 'Holder'
	holder.Text = ''
	holder.Parent = obj
	Scale:Size(holder, 90, 18)
	Scale:PosRight(holder, 12, (height - 18) / 2)
	Util:Corner(holder, Theme.CornerSmall)

	local valueLabel = Instance.new('TextLabel')
	valueLabel.BackgroundTransparency = 1
	valueLabel.Name = 'Value'
	valueLabel.Parent = holder
	valueLabel.TextColor3 = Theme.Text
	Util:Font(valueLabel, true)
	Scale:Text(valueLabel, 12)
	Scale:Size(valueLabel, 90, 18)

	divider(obj, height)

	function component:SetValue(key, skipCallback)
		self.Value = key
		valueLabel.Text = key and key.Name or 'None'

		if not skipCallback and self.Callback then
			env:Safe(self.Callback, key)
		end
	end

	function component:SetVisible(visible)
		obj.Visible = visible
	end

	local listening = false

	Util:Click(holder, function()
		if listening then return end

		listening = true
		valueLabel.Text = '...'

		local connection
		connection = env.InputService.InputBegan:Connect(function(input, gameProcessed)
			if input.UserInputType == Enum.UserInputType.Keyboard then
				if input.KeyCode == Enum.KeyCode.Escape then
					component:SetValue(nil)
				elseif input.KeyCode == Enum.KeyCode.Backspace then
					component:SetValue(nil)
				else
					component:SetValue(input.KeyCode)
				end

				listening = false
				connection:Disconnect()
			elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
				listening = false
				component:SetValue(component.Value)
				connection:Disconnect()
			end
		end)
	end)

	Util:Tooltip(obj, props.Tooltip)
	component:SetValue(component.Value, true)

	return register(self, component)
end

--[[ 模块：带开关 + 可展开选项（Vape 风格） ]]

function Widgets:Module(props)
	local height = props.Height or Theme.ModuleHeight
	local component = {
		Type = 'Module',
		Name = props.Name or 'Module',
		Enabled = false,
		Open = false,
		Callback = props.Callback,
		Widgets = {},
		Connections = {}
	}

	local obj = Instance.new('Frame')
	obj.BackgroundTransparency = 1
	obj.BorderSizePixel = 0
	obj.Name = props.Name or 'Module'
	obj.Parent = self.Body
	Scale:SizeW(obj, height)

	local listLayout = Instance.new('UIListLayout')
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = obj
	bindHeight(obj, listLayout, 0)

	local button = Instance.new('TextButton')
	button.AutoButtonColor = false
	button.BackgroundColor3 = Theme.Main
	button.BorderSizePixel = 0
	button.Name = 'Button'
	button.Text = ''
	button.Parent = obj
	Scale:SizeW(button, height)

	text(button, props.Name or 'Module', height, self.Width - 80, 16, 14, true)
	component.Label = button.Label

	-- 左侧小方块：开启时点亮
	local box = Instance.new('Frame')
	box.BackgroundColor3 = Color:Light(Theme.Main, 0.14)
	box.BorderSizePixel = 0
	box.Name = 'Box'
	box.Parent = button
	Scale:Size(box, 8, 8)
	Scale:Pos(box, 6, (height - 8) / 2)
	Util:Corner(box, 2)

	local dotsButton = Util:IconButton(button, 'dots', 0, 0, 26, 3, 16, true)
	Scale:PosRight(dotsButton, 6, (height - 26) / 2)

	divider(button, height)

	-- 选项容器
	local children = Instance.new('Frame')
	children.BackgroundColor3 = Color:Dark(Theme.Main, 0.03)
	children.BorderSizePixel = 0
	children.Name = 'Children'
	children.Visible = false
	children.Parent = obj
	Scale:SizeW(children, 0)

	local childrenList = Instance.new('UIListLayout')
	childrenList.SortOrder = Enum.SortOrder.LayoutOrder
	childrenList.Parent = children

	bindHeight(children, childrenList, 0)

	component.Object = obj
	component.Button = button
	component.Children = children
	component.Box = box

	-- 选项代理：模块里也能 AddToggle / AddSlider ...（不再嵌套模块）
	local proxy = {
		Body = children,
		Width = self.Width - 16,
		Widgets = component.Widgets,
		IsModule = true
	}

	for name, builder in pairs(Widgets) do
		if name ~= 'Module' then
			proxy['Add' .. name] = function(_, widgetProps)
				return builder(proxy, widgetProps or {})
			end

			-- 模块对象本身也能直接 AddToggle / AddSlider ...
			component['Add' .. name] = proxy['Add' .. name]
		end
	end

	function proxy:Update()
		if component.Parent and component.Parent.Update then
			component.Parent:Update()
		end
	end

	function proxy:SetEnabled(enabled)
		return component:SetEnabled(enabled)
	end

	function proxy:Toggle()
		return component:Toggle()
	end

	function proxy:SetOpen(open)
		return component:SetOpen(open)
	end

	function proxy:SetVisible(visible)
		return component:SetVisible(visible)
	end

	component.Proxy = proxy

	function component:SetEnabled(enabled, skipCallback)
		self.Enabled = enabled

		button.BackgroundColor3 = enabled and Theme:Accent() or Theme.Main
		component.Label.TextColor3 = enabled and Color3.fromRGB(30, 30, 30) or Color:Dark(Theme.Text, 0.16)
		box.BackgroundColor3 = enabled and Color3.fromRGB(30, 30, 30) or Color:Light(Theme.Main, 0.14)

		if not skipCallback and self.Callback then
			env:Safe(self.Callback, enabled)
		end
	end

	function component:Toggle()
		self:SetEnabled(not self.Enabled)
	end

	function component:SetOpen(open)
		self.Open = open
		children.Visible = open

		if self.Parent and self.Parent.Update then
			self.Parent:Update()
		end
	end

	function component:SetVisible(visible)
		obj.Visible = visible
	end

	function component:Update()
		if self.Parent and self.Parent.Update then
			self.Parent:Update()
		end
	end

	Util:Hover(button, function()
		if not component.Enabled then
			button.BackgroundColor3 = Color:Light(Theme.Main, 0.03)
			component.Label.TextColor3 = Theme.Text
		end
	end, function()
		if not component.Enabled then
			button.BackgroundColor3 = Theme.Main
			component.Label.TextColor3 = Color:Dark(Theme.Text, 0.16)
		end
	end)

	Util:Click(button, function()
		component:Toggle()
	end)

	Util:RightClick(button, function()
		component:SetOpen(not component.Open)
	end)

	Util:Click(dotsButton, function()
		component:SetOpen(not component.Open)
	end)

	Util:Tooltip(button, props.Tooltip)

	Lib.Modules[component.Name] = component

	return register(self, component)
end

--[==[ 09_Notify.lua ]==]
--[==[
	Nova GUI  ·  09_Notify
	右下角通知（Vape 风格：图标 + 标题 + 内容 + 进度条）
]==]

local Lib = NovaLib or getgenv().NovaLib
local env = Lib.Env
local Scale = Lib.Scale
local Theme = Lib.Theme
local Color = Lib.Color
local Util = Lib.Util

local Notify = {
	Enabled = true,
	Duration = 4,
	Limit = 5,
	Active = 0
}

Lib.Notifications = Notify

function Notify:Init(parent)
	local holder = Instance.new('Frame')
	holder.BackgroundTransparency = 1
	holder.Name = 'Notifications'
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = parent
	self.Holder = holder

	return holder
end

local function stripTags(text)
	return (tostring(text):gsub('<br%s*/>', '\n'):gsub('<[^<>]->', ''))
end

function Notify:Send(props)
	if not self.Enabled or not self.Holder then return end
	if self.Active >= self.Limit then return end

	if type(props) == 'string' then
		props = {Title = Lib.Name, Text = props}
	end

	props = props or {}
	local title = props.Title or Lib.Name
	local text = props.Text or ''
	local duration = props.Duration or self.Duration
	local kind = props.Type or props.Kind or 'info'

	self.Active = self.Active + 1
	local index = self.Active

	task.spawn(function()
		if env.ThreadFix then
			pcall(setthreadidentity, 8)
		end

		local frame = Instance.new('Frame')
		frame.BackgroundTransparency = 1
		frame.Name = 'Notification'
		frame.Parent = self.Holder
		Scale:Track(frame, 'Size', function(s)
			return UDim2.fromOffset(s:W(266), s:H(75))
		end)
		Scale:Track(frame, 'Position', function(s)
			return UDim2.new(1, -s:W(12), 1, -s:H(12) - s:H(78) * (index - 1))
		end)

		Util:Shadow(frame, true)

		local background = Instance.new('ImageLabel')
		background.BackgroundTransparency = 1
		background.Image = Lib.Assets:Get('notification')
		background.ImageColor3 = Color:Dark(Theme.Main, 0.02)
		background.Name = 'Background'
		background.ScaleType = Enum.ScaleType.Slice
		background.SliceCenter = Rect.new(7, 7, 9, 9)
		background.Size = UDim2.fromScale(1, 1)
		background.Parent = frame

		local icon = Instance.new('ImageLabel')
		icon.BackgroundTransparency = 1
		icon.Image = Lib.Assets:Get('noti_' .. kind)
		icon.Name = 'Icon'
		icon.Parent = frame
		Scale:Size(icon, 30, 30)
		Scale:Pos(icon, 12, 22)

		local titleLabel = Instance.new('TextLabel')
		titleLabel.BackgroundTransparency = 1
		titleLabel.Name = 'Title'
		titleLabel.Text = title
		titleLabel.TextColor3 = kind == 'alert' and Color3.fromRGB(250, 50, 56) or Theme.Text
		titleLabel.TextXAlignment = Enum.TextXAlignment.Left
		titleLabel.TextYAlignment = Enum.TextYAlignment.Top
		titleLabel.Parent = frame
		Util:Font(titleLabel, true)
		Scale:Text(titleLabel, 14)
		Scale:Size(titleLabel, 200, 20)
		Scale:Pos(titleLabel, 52, 14)

		local textLabel = Instance.new('TextLabel')
		textLabel.BackgroundTransparency = 1
		textLabel.Name = 'Text'
		textLabel.Text = stripTags(text)
		textLabel.TextColor3 = Color:Dark(Theme.Text, 0.16)
		textLabel.TextXAlignment = Enum.TextXAlignment.Left
		textLabel.TextYAlignment = Enum.TextYAlignment.Top
		textLabel.TextWrapped = true
		textLabel.Parent = frame
		Util:Font(textLabel)
		Scale:Text(textLabel, 13)
		Scale:Size(textLabel, 200, 36)
		Scale:Pos(textLabel, 52, 36)

		local progress = Instance.new('Frame')
		progress.BackgroundColor3 = kind == 'alert' and Color3.fromRGB(250, 50, 56)
			or kind == 'warning' and Color3.fromRGB(236, 129, 44)
			or Color3.new(1, 1, 1)
		progress.BorderSizePixel = 0
		progress.Name = 'Progress'
		progress.Parent = frame
		Scale:Track(progress, 'Position', function(s)
			return UDim2.new(0, s:W(10), 1, -s:H(10))
		end)
		Scale:Track(progress, 'Size', function(s)
			return UDim2.fromOffset(s:W(246), math.max(s:H(2), 1))
		end)

		-- 进入动画
		frame.Position = UDim2.new(1, Scale:W(266), 1, -Scale:H(12) - Scale:H(78) * (index - 1))
		Scale:Apply(frame)

		if env.Tween then
			env:Tween(frame, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {
				Position = UDim2.new(1, -Scale:W(12), 1, -Scale:H(12) - Scale:H(78) * (index - 1))
			})

			env:Tween(progress, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
				Size = UDim2.fromOffset(0, math.max(Scale:H(2), 1))
			})
		end

		task.wait(duration)

		-- 退出动画
		if env.Tween then
			env:Tween(frame, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {
				Position = UDim2.new(1, Scale:W(280), 1, -Scale:H(12) - Scale:H(78) * (index - 1))
			})
		end

		task.wait(0.3)
		Scale:Cancel(frame)
		frame:Destroy()
		self.Active = self.Active - 1
	end)
end

function Notify:Info(title, text, duration)
	self:Send({Title = title, Text = text, Duration = duration, Type = 'info'})
end

function Notify:Warning(title, text, duration)
	self:Send({Title = title, Text = text, Duration = duration, Type = 'warning'})
end

function Notify:Alert(title, text, duration)
	self:Send({Title = title, Text = text, Duration = duration, Type = 'alert'})
end

--[==[ 10_Init.lua ]==]
--[==[
	Nova GUI  ·  10_Init
	组装：ScreenGui / 根容器 / 窗口容器 / 悬浮球 / 主窗口 / 通知 / 按键 / 配置存取
]==]

local Lib = NovaLib or getgenv().NovaLib
local env = Lib.Env
local Scale = Lib.Scale
local Theme = Lib.Theme
local Assets = Lib.Assets
local Notify = Lib.Notifications

Lib.ConfigFile = 'nova/config.json'
Lib.AutoSave = true
Lib.ToggleKey = Enum.KeyCode.RightShift
Lib.Visible = false

--[[ 配置 ]]

function Lib:Save()
	if not env.Features.File then return end

	local data = {
		Version = 1,
		ScaleMode = Scale.Mode,
		Accent = {Theme.Hue, Theme.Sat, Theme.Val},
		Ball = self.Ball and self.Ball:SavePosition() or nil,
		Windows = {}
	}

	for name, window in pairs(self.Windows) do
		data.Windows[name] = {
			Visible = window.Visible,
			Collapsed = window.Collapsed,
			X = window.Frac and window.Frac.X or nil,
			Y = window.Frac and window.Frac.Y or nil
		}
	end

	env:MakeFolder('nova')
	env:WriteFile(self.ConfigFile, env:JSONEncode(data))
end

function Lib:Load()
	if not env.Features.File then return end

	local raw = env:ReadFile(self.ConfigFile)
	local data = raw and env:JSONDecode(raw)
	if type(data) ~= 'table' then return end

	if data.ScaleMode then
		Scale.Mode = data.ScaleMode
	end

	if type(data.Accent) == 'table' then
		Theme:SetAccent(data.Accent[1], data.Accent[2], data.Accent[3])
	end

	if data.Ball and self.Ball then
		self.Ball:LoadPosition(data.Ball)
	end

	self.SavedWindows = data.Windows
end

-- 窗口创建后套用保存的位置 / 状态
local function applySaved(window)
	local saved = Lib.SavedWindows and Lib.SavedWindows[window.Name]
	if type(saved) ~= 'table' then return end

	if saved.X and saved.Y and window.Frac then
		window.Frac.X = saved.X
		window.Frac.Y = saved.Y
		Scale:SetFollow(window.Object, saved.X, saved.Y)
	end

	if saved.Collapsed then
		window:SetCollapsed(true)
	end

	if saved.Visible then
		window:SetVisible(true)
	end
end

--[[ 显示 / 隐藏 ]]

function Lib:SetVisible(visible)
	self.Visible = visible
	self.Container.Visible = visible

	if self.Ball then
		self.Ball:SetActive(visible)
	end

	if self.AutoSave then
		self:Save()
	end

	if self.OnToggle then
		env:Safe(self.OnToggle, visible)
	end
end

function Lib:ToggleGUI()
	self:SetVisible(not self.Visible)
end

function Lib:SetToggleKey(key)
	self.ToggleKey = key
end

--[[ 通知便捷方法 ]]

function Lib:Notify(title, text, duration, kind)
	Notify:Send({Title = title, Text = text, Duration = duration, Type = kind})
end

--[[ 初始化 ]]

function Lib:Init(props)
	if self.Loaded then return self end

	props = props or {}

	if not game:IsLoaded() then
		game.Loaded:Wait()
	end

	self.SavedWindows = {}

	-- ScreenGui
	local gui = Instance.new('ScreenGui')
	gui.Name = env:RandomString()
	gui.DisplayOrder = 999999
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = env:Container()
	env:Protect(gui)
	self.Gui = gui

	-- 根容器（屏幕百分比基准）
	self.Root = Scale:Mount(gui)

	-- 悬浮球（先建，这样窗口永远盖在球上面）
	self:CreateBall(props.Ball)

	-- 窗口容器：整体开关
	local container = Instance.new('Frame')
	container.BackgroundTransparency = 1
	container.Name = 'Windows'
	container.Size = UDim2.fromScale(1, 1)
	container.Visible = false
	container.Parent = self.Root
	self.Container = container

	Lib.Notifications:Init(self.Root)

	-- 主窗口
	self:CreateMainWindow({
		Width = props.MainWidth or 220,
		X = props.X or 40,
		Y = props.Y or 110,
		Visible = true
	})

	Lib:AddCredit(self.MainWindow, Lib.Name .. ' v' .. Lib.Version .. '  ·  ' .. env.Executor)

	-- 读取配置（要等窗口都建好，所以放在最后由调用方执行 ApplySaved）
	self:Load()

	self.Loaded = true
	getgenv().Nova = self

	-- 按键开关
	env.InputService.InputBegan:Connect(function(input, processed)
		if processed then return end

		if input.KeyCode == self.ToggleKey then
			self:ToggleGUI()
		end
	end)

	-- 窗口 / 模块状态变化时自动保存
	self.OnBallMoved = function()
		if self.AutoSave then
			self:Save()
		end
	end

	-- 第一次用（没有存档）就直接把界面打开，省得找不到入口
	if not env:IsFile(self.ConfigFile) then
		self:SetVisible(true)
	end

	-- 后台下载图标资源
	Assets:Prefetch()

	if props.Notify ~= false then
		Lib:Notify(Lib.Name, '已加载 · 按 ' .. tostring(self.ToggleKey.Name) .. ' 开关界面', 4)
	end

	return self
end

-- 单个窗口套用存档（CreateWindow 结束时会自动调用）
function Lib:ApplyWindowState(window)
	applySaved(window)
end

-- 全部窗口套用存档
function Lib:ApplySaved()
	for _, window in pairs(self.Windows) do
		applySaved(window)
	end

	if self.Ball then
		self.Ball:SetActive(self.Visible)
	end
end

-- 彻底清理
function Lib:Destroy()
	for _, window in pairs(self.Windows) do
		pcall(function()
			window:Destroy()
		end)
	end

	if self.Gui then
		self.Gui:Destroy()
	end

	table.clear(self.Windows)
	self.Loaded = false
	getgenv().Nova = nil
end


--[==[ 自动初始化 ]==]

if NovaLib.AutoInit ~= false and not getgenv().NovaNoAutoInit then
	NovaLib:Init()
end

return NovaLib
