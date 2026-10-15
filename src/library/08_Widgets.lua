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
