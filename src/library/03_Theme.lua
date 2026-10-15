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
