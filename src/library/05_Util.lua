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
