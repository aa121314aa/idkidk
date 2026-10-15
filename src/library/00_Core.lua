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
