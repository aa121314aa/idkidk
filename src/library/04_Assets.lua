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
