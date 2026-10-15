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
