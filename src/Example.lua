--[==[
	Nova GUI  ·  示例模块

	先执行 src/Nova.lua，再执行本文件（这是别人写功能模块的模板）。
	这里只演示 UI 用法，不含任何游戏功能 —— 功能回调由你自己填。
]==]

local Nova = getgenv().Nova or Nova

if not Nova then
	error('[Nova] 请先执行 Nova.lua')
end

--[[ 设置窗口 ]]

local settings = Nova:CreateWindow({
	Name = '设置',
	Icon = 'settings',
	Visible = false
})

settings:AddSection({Name = '界面'})

settings:AddDropdown({
	Name = '缩放模式',
	List = {'Percent', 'Uniform'},
	Default = Nova.Scale.Mode,
	Tooltip = 'Percent = 按屏幕百分比缩放；Uniform = 等比缩放（不会被拉伸）',
	Callback = function(value)
		Nova.Scale:SetMode(value)
	end
})

settings:AddSlider({
	Name = '主题色',
	Min = 0,
	Max = 100,
	Default = math.floor(Nova.Theme.Hue * 100),
	Suffix = '%',
	Callback = function(value)
		Nova.Theme:SetAccent(value / 100)
	end
})

settings:AddToggle({
	Name = '显示悬浮球',
	Default = true,
	Callback = function(value)
		Nova.Ball:SetVisible(value)
	end
})

settings:AddToggle({
	Name = '悬浮球贴边',
	Default = true,
	Tooltip = '拖动松手后自动吸附到屏幕左右边缘',
	Callback = function(value)
		Nova.Ball.Snap = value
	end
})

settings:AddSection({Name = '其它'})

settings:AddKeybind({
	Name = '开关按键',
	Default = Nova.ToggleKey,
	Tooltip = '点击后按下一个键；右键取消',
	Callback = function(key)
		if key then
			Nova:SetToggleKey(key)
		end
	end
})

settings:AddToggle({
	Name = '通知',
	Default = Nova.Notifications.Enabled,
	Callback = function(value)
		Nova.Notifications.Enabled = value
	end
})

settings:AddButton({
	Name = '发一条通知',
	Callback = function()
		Nova:Notify('Nova', '这是一条测试通知', 3)
	end
})

settings:AddButton({
	Name = '保存配置',
	Callback = function()
		Nova:Save()
		Nova:Notify('Nova', '配置已保存', 2)
	end
})

--[[ 控件演示窗口 ]]

local demo = Nova:CreateWindow({
	Name = '示例',
	Icon = 'icon_box',
	Visible = true
})

demo:AddSection({Name = '基础控件'})

demo:AddToggle({
	Name = '开关 Toggle',
	Default = false,
	Tooltip = '点一下试试',
	Callback = function(value)
		Nova:Notify('示例', 'Toggle = ' .. tostring(value), 2)
	end
})

demo:AddButton({
	Name = '按钮 Button',
	Callback = function()
		Nova:Notify('示例', '按钮被点击', 2)
	end
})

demo:AddSlider({
	Name = '滑块 Slider',
	Min = 0,
	Max = 100,
	Default = 50,
	Suffix = '%',
	Callback = function(value)
		print('[Nova] slider =', value)
	end
})

demo:AddDropdown({
	Name = '下拉 Dropdown',
	List = {'选项 A', '选项 B', '选项 C'},
	Default = '选项 A',
	Callback = function(value)
		print('[Nova] dropdown =', value)
	end
})

demo:AddTextBox({
	Name = '输入 TextBox',
	Placeholder = '随便写点什么',
	Callback = function(value)
		Nova:Notify('示例', '输入：' .. value, 2)
	end
})

demo:AddKeybind({
	Name = '绑定 Keybind',
	Tooltip = '点击后按下要绑定的键',
	Callback = function(key)
		Nova:Notify('示例', '绑定：' .. tostring(key and key.Name or '无'), 2)
	end
})

demo:AddSection({Name = '模块'})

-- 模块：左键开关，右键或右侧竖点展开选项
local module = demo:AddModule({
	Name = '示例模块',
	Tooltip = '左键开关 · 右键展开选项',
	Callback = function(enabled)
		Nova:Notify('示例模块', enabled and '已开启' or '已关闭', 2)
	end
})

module:AddToggle({Name = '模块内开关', Default = true})
module:AddSlider({Name = '模块内滑块', Min = 1, Max = 10, Default = 3})
module:AddDropdown({Name = '模块内下拉', List = {'一', '二', '三'}, Default = '一'})

demo:AddSection({Name = '提示'})

demo:AddLabel({Text = '按 ' .. tostring(Nova.ToggleKey.Name) .. ' 开关界面'})
demo:AddLabel({Text = '拖动窗口标题栏移动位置'})

return Nova
