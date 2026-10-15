--[==[
	Nova GUI  ·  07_Window
	多窗口系统：每个窗口都是独立可拖动 / 可折叠 / 可关闭的对象，
	窗口之间互不干扰，主窗口(MainWindow)里列出所有窗口并可单独开关。
]==]

local Lib = NovaLib or getgenv().NovaLib
local env = Lib.Env
local Scale = Lib.Scale
local Theme = Lib.Theme
local Color = Lib.Color
local Util = Lib.Util

local function cascade(index)
	return 40 + (index % 5) * 34, 110 + (index % 5) * 30
end

function Lib:CreateWindow(props)
	props = props or {}

	local index = 0
	for _ in pairs(self.Windows) do
		index = index + 1
	end

	local window = {
		Name = props.Name or ('Window' .. (index + 1)),
		Width = props.Width or Theme.WindowWidth,
		MaxHeight = props.MaxHeight,
		ShowInList = props.ShowInList ~= false,
		Icon = props.Icon,
		Visible = false,
		Collapsed = false,
		Widgets = {},
		Height = 0,
		Connections = {}
	}

	local frame = Instance.new('Frame')
	frame.BackgroundColor3 = Color:Dark(Theme.Main, 0.02)
	frame.Name = window.Name
	frame.Visible = false
	frame.Parent = self.Container
	Scale:Pos(frame, props.X or select(1, cascade(index)), props.Y or select(2, cascade(index)))
	Scale:Track(frame, 'Size', function(s)
		return UDim2.fromOffset(s:W(window.Width), window.Height)
	end)

	Util:Corner(frame, props.Corner or Theme.Corner)
	Util:Stroke(frame)
	Util:Shadow(frame)

	local topbar = Instance.new('TextButton')
	topbar.AutoButtonColor = false
	topbar.BackgroundTransparency = 1
	topbar.Name = 'Topbar'
	topbar.Text = ''
	topbar.Parent = frame
	Scale:SizeW(topbar, Theme.TopbarHeight)

	local iconWidth = 0
	if window.Icon then
		iconWidth = props.IconSize or 16
		local icon = Util:Image(topbar, window.Icon, iconWidth, props.IconHeight or iconWidth, Theme:Accent())
		Scale:Pos(icon, 11, (Theme.TopbarHeight - iconWidth) / 2)
		Theme:RegisterAccent(icon, 'ImageColor3')
	end

	local title = Instance.new('TextLabel')
	title.BackgroundTransparency = 1
	title.Name = 'Title'
	title.Text = window.Name
	title.TextColor3 = Theme.Text
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.Parent = topbar
	Util:Font(title, true)
	Scale:Text(title, 14)
	Scale:Size(title, window.Width - (iconWidth > 0 and iconWidth + 24 or 22) - 46, Theme.TopbarHeight)
	Scale:Pos(title, iconWidth > 0 and iconWidth + 22 or 11, 0)

	-- 分隔线
	local divider = Instance.new('Frame')
	divider.BackgroundColor3 = Theme.Divider
	divider.BorderSizePixel = 0
	divider.Name = 'Divider'
	divider.Parent = frame
	Scale:Track(divider, 'Size', function(s)
		return UDim2.new(1, 0, 0, math.max(s:PX(1), 1))
	end)
	Scale:Track(divider, 'Position', function(s)
		return UDim2.fromOffset(0, s:H(Theme.TopbarHeight) - math.max(s:PX(1), 1))
	end)

	-- 主体（内容超出最大高度时滚动）
	local body = Instance.new('ScrollingFrame')
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Name = 'Body'
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.ElasticBehavior = Enum.ElasticBehavior.Never
	body.ScrollBarImageColor3 = Color:Light(Theme.Main, 0.25)
	body.ScrollBarImageTransparency = 0.4
	body.ScrollingDirection = Enum.ScrollingDirection.Y
	body.Parent = frame
	Scale:Track(body, 'Position', function(s)
		return UDim2.fromOffset(0, s:H(Theme.TopbarHeight))
	end)
	Scale:Track(body, 'Size', function(s)
		return UDim2.new(1, 0, 0, math.max(window.Height - s:H(Theme.TopbarHeight), 0))
	end)
	Scale:Track(body, 'ScrollBarThickness', function(s)
		return s:PX(4)
	end)

	local list = Instance.new('UIListLayout')
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = body

	window.Object = frame
	window.Topbar = topbar
	window.Body = body
	window.List = list
	window.Title = title

	-- 高度：标题栏 + 内容，超过最大高度则滚动
	function window:UpdateHeight()
		local topbarHeight = Scale:H(Theme.TopbarHeight)
		local viewport = Scale:Viewport()
		local limit = self.MaxHeight and Scale:H(self.MaxHeight) or (viewport.Y * 0.78)
		local content = self.Collapsed and 0 or list.AbsoluteContentSize.Y

		self.Height = math.min(topbarHeight + content, limit)
		Scale:Apply(frame)
		Scale:Apply(body)
	end

	-- 控件都通过 :Update() 通知窗口重算高度
	function window:Update()
		self:UpdateHeight()
	end

	window:UpdateHeight()
	table.insert(window.Connections, list:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
		window:UpdateHeight()
	end))

	function window:SetVisible(visible)
		self.Visible = visible
		frame.Visible = visible

		if self.Row then
			self.Row:Update()
		end

		if Lib.AutoSave then
			Lib:Save()
		end
	end

	function window:Toggle()
		self:SetVisible(not self.Visible)
	end

	function window:SetCollapsed(collapsed)
		self.Collapsed = collapsed
		body.Visible = not collapsed
		self:UpdateHeight()

		if self.CollapseIcon then
			self.CollapseIcon.Image = Lib.Assets:Get(collapsed and 'expand' or 'collapse')
		end
	end

	function window:SetName(name)
		self.Name = name
		title.Text = name

		if self.Row then
			self.Row.Label.Text = name
		end
	end

	function window:Clear()
		for _, child in ipairs(body:GetChildren()) do
			if child:IsA('GuiObject') then
				child:Destroy()
			end
		end

		table.clear(self.Widgets)
		self:UpdateHeight()
	end

	function window:Destroy()
		for _, connection in ipairs(self.Connections) do
			pcall(function()
				connection:Disconnect()
			end)
		end

		if self.Row and self.Row.Destroy then
			self.Row:Destroy()
		end

		Scale:Cancel(frame)
		frame:Destroy()
		Lib.Windows[self.Name] = nil
	end

	-- 右上角的折叠 / 关闭
	local collapseButton, collapseIcon = Util:IconButton(topbar, 'collapse', 34, (Theme.TopbarHeight - 20) / 2, 20, 10, 5, true)
	window.CollapseIcon = collapseIcon

	Util:Click(collapseButton, function()
		window:SetCollapsed(not window.Collapsed)
	end)
	Util:Tooltip(collapseButton, '折叠 / 展开')

	local closeSize = 20
	local closeButton, closeIcon = Util:IconButton(topbar, 'close', 8, (Theme.TopbarHeight - closeSize) / 2, closeSize, 14, 14, true)

	Util:Click(closeButton, function()
		window:SetVisible(false)
	end)
	Util:Tooltip(closeButton, '隐藏窗口（主窗口里可以再打开）')

	-- 拖动：整个标题栏都可以拖
	window.Frac = Util:Drag(frame, topbar, {
		OnEnd = function()
			if Lib.AutoSave then
				Lib:Save()
			end
		end
	})

	-- 双击标题栏折叠
	Util:Click(topbar, function()
		if window.LastClick and tick() - window.LastClick < 0.3 then
			window:SetCollapsed(not window.Collapsed)
		end

		window.LastClick = tick()
	end)

	-- 挂上所有控件方法（AddToggle / AddButton / ...）
	for name, builder in pairs(Lib.Widgets or {}) do
		window['Add' .. name] = function(self, widgetProps)
			return builder(self, widgetProps or {})
		end
	end

	self.Windows[window.Name] = window

	if window.ShowInList and self.MainWindow then
		self.MainWindow:AddWindowRow(window)
	end

	if props.Visible then
		window:SetVisible(true)
	end

	if self.ApplyWindowState then
		self:ApplyWindowState(window)
	end

	return window
end

-- 主窗口：列出所有窗口
function Lib:CreateMainWindow(props)
	props = props or {}
	props.Name = props.Name or self.Name
	props.Icon = props.Icon or 'logo_small'
	props.IconSize = props.IconSize or 18
	props.ShowInList = false
	props.Width = props.Width or 220

	local main = self:CreateWindow(props)
	self.MainWindow = main

	-- 主窗口里已有的行（在我之前创建的窗口）
	function main:AddWindowRow(window)
		local row = {}

		local button = Instance.new('TextButton')
		button.AutoButtonColor = false
		button.BackgroundColor3 = Theme.Main
		button.BorderSizePixel = 0
		button.Name = window.Name
		button.Text = ''
		button.Parent = self.Body
		Scale:SizeW(button, 34)

		local iconWidth = 0
		if window.Icon then
			iconWidth = 16
			local icon = Util:Image(button, window.Icon, iconWidth, iconWidth, window.Visible and Theme:Accent() or Color:Light(Theme.Main, 0.37))
			Scale:Pos(icon, 12, 9)
			row.Icon = icon
		end

		local label = Instance.new('TextLabel')
		label.BackgroundTransparency = 1
		label.Name = 'Label'
		label.Text = window.Name
		label.TextColor3 = Color:Dark(Theme.Text, 0.16)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.Parent = button
		Util:Font(label)
		Scale:Text(label, 14)
		Scale:Size(label, self.Width - (iconWidth > 0 and iconWidth + 24 or 22) - 30, 34)
		Scale:Pos(label, iconWidth > 0 and iconWidth + 22 or 12, 0)

		-- 右侧状态点：窗口显示时点亮
		local dot = Instance.new('Frame')
		dot.BackgroundColor3 = Color:Light(Theme.Main, 0.14)
		dot.BorderSizePixel = 0
		dot.Name = 'Dot'
		dot.Parent = button
		Scale:Size(dot, 8, 8)
		Scale:PosRight(dot, 12, 13)
		Util:Pill(dot)

		row.Object = button
		row.Label = label
		row.Dot = dot
		row.IconWidth = iconWidth

		function row:Update()
			local enabled = window.Visible
			label.TextColor3 = enabled and Theme.Text or Color:Dark(Theme.Text, 0.16)
			button.BackgroundColor3 = enabled and Color:Light(Theme.Main, 0.04) or Theme.Main
			dot.BackgroundColor3 = enabled and Theme:Accent() or Color:Light(Theme.Main, 0.14)

			if row.Icon then
				row.Icon.ImageColor3 = enabled and Theme:Accent() or Color:Light(Theme.Main, 0.37)
			end
		end

		function row:Destroy()
			Scale:Cancel(button)
			button:Destroy()
		end

		Util:Hover(button, function()
			label.TextColor3 = Theme.Text
		end, function()
			row:Update()
		end)

		Util:Click(button, function()
			window:Toggle()
		end)

		Util:Tooltip(button, '开关「' .. window.Name .. '」窗口')

		window.Row = row
		row:Update()

		return row
	end

	for _, window in pairs(self.Windows) do
		if window ~= main and window.ShowInList then
			main:AddWindowRow(window)
		end
	end

	return main
end

-- 主窗口底部信息条
function Lib:AddCredit(window, text)
	window = window or self.MainWindow
	if not window then return end

	local label = Instance.new('TextLabel')
	label.BackgroundTransparency = 1
	label.Name = 'Credit'
	label.Text = text or (self.Name .. ' v' .. self.Version)
	label.TextColor3 = Color:Dark(Theme.Text, 0.5)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = window.Body
	Util:Font(label)
	Scale:Text(label, 12)
	Scale:SizeW(label, 24)
	Scale:Padding(label, 12, 0, 0, 0)

	return label
end
