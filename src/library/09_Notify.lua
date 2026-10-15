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
