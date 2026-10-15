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
