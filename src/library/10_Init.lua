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
