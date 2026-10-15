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
