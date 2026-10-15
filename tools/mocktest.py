#!/usr/bin/env python3
"""
在模拟的 Roblox 环境里跑一遍 Nova GUI（不需要 Roblox）。

用来抓运行时错误：属性名写错、nil 调用、事件接线、百分比缩放刷新、
存档往返、以及"执行器不支持文件函数"时的资产回退。

    python3 tools/mocktest.py
"""

import json
import sys
from pathlib import Path

try:
    from lupa import LuaRuntime
except ImportError:
    sys.exit("需要 lupa：pip install lupa")

ROOT = Path(__file__).resolve().parents[1]
MOCK = (ROOT / "tools" / "mock_roblox.lua").read_text(encoding="utf-8")
LIB = (ROOT / "src" / "Nova.lua").read_text(encoding="utf-8")
EXAMPLE = (ROOT / "src" / "Example.lua").read_text(encoding="utf-8")


def lua_to_python(value):
    """把 Lua 表递归转成 Python 对象"""
    if hasattr(value, "items"):
        items = list(value.items())

        if items and all(isinstance(key, (int, float)) for key, _ in items):
            return [lua_to_python(item) for _, item in sorted(items, key=lambda pair: pair[0])]

        return {str(key): lua_to_python(item) for key, item in items}

    return value


def to_lua_literal(value) -> str:
    """把 Python 对象转成 Lua 字面量（只用于测试里的 JSON 回灌）"""
    if isinstance(value, dict):
        return "{" + ", ".join(
            "[%s]=%s" % (to_lua_literal(str(key)), to_lua_literal(item))
            for key, item in value.items()
        ) + "}"

    if isinstance(value, list):
        return "{" + ", ".join(to_lua_literal(item) for item in value) + "}"

    if isinstance(value, str):
        return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'

    if isinstance(value, bool):
        return "true" if value else "false"

    if value is None:
        return "nil"

    return repr(value)


def make_runtime(no_files: bool = False, json_backend=None):
    lua = LuaRuntime(unpack_returned_tuples=True)

    if no_files:
        lua.execute("MockNoFiles = true")

    lua.execute(MOCK)

    if json_backend:
        service = lua.eval("MockGlobal.services.HttpService")

        def json_encode(_, data):
            return json.dumps(lua_to_python(data))

        def json_decode(_, text):
            try:
                return lua.eval(to_lua_literal(json.loads(text)))
            except Exception:
                return None

        service.JSONEncode = json_encode
        service.JSONDecode = json_decode

    lua.globals().MockReloadLib = lua.compile(LIB)

    return lua


TEST_MAIN = """
local Nova = getgenv().Nova
local Mock = MockGlobal
assert(Nova and Nova.Loaded, 'Nova 没有初始化')

-- 1) 窗口 / 控件是否都建起来了
assert(Nova.MainWindow, '缺少主窗口')
assert(Nova.Ball and Nova.Ball.Object, '缺少悬浮球')
assert(Nova.Windows['设置'] and Nova.Windows['示例'], '示例窗口没建立')
local demo = Nova.Windows['示例']
assert(#demo.Widgets >= 8, '示例窗口控件数量不对: ' .. tostring(#demo.Widgets))

-- 2) 主窗口里应该列出所有窗口
local rows = 0
for _, child in ipairs(Nova.MainWindow.Body:GetChildren()) do
    if child.ClassName == 'TextButton' then rows = rows + 1 end
end
assert(rows >= 2, '主窗口列表行数不对: ' .. tostring(rows))

-- 3) 逐个调用控件 API
for _, widget in ipairs(demo.Widgets) do
    if widget.SetValue then widget:SetValue(widget.Value) end
    if widget.SetVisible then widget:SetVisible(true) widget:SetVisible(false) end
    if widget.Type == 'Module' then
        widget:SetEnabled(true)
        widget:SetOpen(true)
        widget:SetOpen(false)
        widget:SetEnabled(false)
    end
end

-- 4) 悬浮球：点击开关界面
local before = Nova.Visible
Mock:Click(Nova.Ball.Object)
assert(Nova.Visible ~= before, '点击悬浮球没有切换显示状态')
assert(Nova.Container.Visible == Nova.Visible, '容器可见性没跟上')

-- 5) 按键开关
Mock:FireKey(Enum.KeyCode.RightShift)
assert(Nova.Visible == before, '按键没有切换显示状态')

-- 6) 移动窗口
local window = Nova.Windows['示例']
window.Frac.X, window.Frac.Y = 0.2, 0.3
Nova.Scale:SetFollow(window.Object, 0.2, 0.3)
assert(math.abs(window.Object.Position.X.Offset - 0.2 * Mock.Screen.X) < 1, '窗口位置换算不对')

-- 7) 屏幕尺寸变化 -> 百分比缩放刷新
local widthBefore = window.Object.AbsoluteSize.X
Mock:Resize(3840, 2160)
local widthAfter = window.Object.AbsoluteSize.X
assert(widthAfter > widthBefore * 1.8, '放大屏幕后控件没有按比例变大: ' .. tostring(widthBefore) .. ' -> ' .. tostring(widthAfter))
assert(math.abs(window.Object.Position.X.Offset - 0.2 * 3840) < 1, '缩放后窗口位置没有跟着走')
Mock:Resize(1280, 720)
assert(window.Object.AbsoluteSize.X < widthAfter, '缩小屏幕后控件没有变小')

-- 8) Uniform 模式
Nova.Scale:SetMode('Uniform')
Mock:Resize(2560, 1080)
assert(Nova.Scale.Mode == 'Uniform', '模式没切换')
Nova.Scale:SetMode('Percent')
Mock:Resize(1920, 1080)

-- 9) 折叠 / 关闭 / 通知 / 存档
window:SetCollapsed(true)
assert(window.Collapsed, '折叠失败')
window:SetCollapsed(false)
window:SetVisible(true)
window:SetVisible(false)
Nova:Notify('测试', '通知内容', 2)
Nova:Save()
Nova:Load()
Nova:ApplySaved()

-- 10) 资产：模拟下载 + getcustomasset
assert(Nova.Assets:Get('close') ~= '', 'close 资源为空')
assert(string.find(tostring(Nova.Assets:Get('close')), 'rbxasset://mock/'), '没有走 getcustomasset 分支')

-- 11) 事件驱动：点击开关 / 按钮 / 下拉 / 模块
local toggle
for _, widget in ipairs(demo.Widgets) do
    if widget.Type == 'Toggle' then toggle = widget break end
end
assert(toggle, '示例窗口里没有 Toggle')

local beforeToggle = toggle.Enabled
Mock:Click(toggle.Object)
assert(toggle.Enabled ~= beforeToggle, '点击开关没有切换状态')

local dropdown, slider, module
for _, widget in ipairs(demo.Widgets) do
    if widget.Type == 'Dropdown' then dropdown = widget end
    if widget.Type == 'Slider' then slider = widget end
    if widget.Type == 'Module' then module = widget end
end
assert(dropdown and slider and module, '控件类型不全')

Mock:Click(dropdown.Object)
assert(dropdown.Open, '点击下拉没有展开')
Mock:Click(dropdown.Object)
assert(not dropdown.Open, '再次点击下拉没有收起')

-- 滑块拖动：按下 -> 移动 -> 松开
local bar = slider.Object.Hit
local press = Instance.new('InputObject')
press.UserInputType = Enum.UserInputType.MouseButton1
press.Position = Vector3.new(0, 0, 0)
press.UserInputState = Enum.UserInputState.Begin
bar.InputBegan:Fire(press)
local move = Instance.new('InputObject')
move.UserInputType = Enum.UserInputType.MouseMovement
move.Position = Vector3.new(bar.AbsolutePosition.X + bar.AbsoluteSize.X * 0.75, 0, 0)
Mock.services.UserInputService.InputChanged:Fire(move)
press.UserInputState = Enum.UserInputState.End
press.Changed:Fire()
assert(slider.Value > 50, '滑块拖动没有改变数值: ' .. tostring(slider.Value))

-- 模块：左键开关 + 展开选项
module:SetEnabled(false)
Mock:Click(module.Button)
assert(module.Enabled, '点击模块没有开启')
Mock:Click(module.Object.Button.DotsButton)
assert(module.Open, '点击竖点没有展开选项')

-- 窗口标题栏按钮
Mock:Click(window.Object.Topbar.CloseButton)
assert(not window.Visible, '点击关闭按钮后窗口仍然可见')
window:SetVisible(true)
Mock:Click(window.Object.Topbar.CollapseButton)
assert(window.Collapsed, '点击折叠按钮没有折叠')
Mock:Click(window.Object.Topbar.CollapseButton)
assert(not window.Collapsed, '再次点击没有展开')

-- 悬浮球拖动（含边缘吸附）
do
    local ball = Nova.Ball.Object
    local ballPress = Instance.new('InputObject')
    ballPress.UserInputType = Enum.UserInputType.MouseButton1
    ballPress.Position = Vector3.new(10, 10, 0)
    ballPress.UserInputState = Enum.UserInputState.Begin
    ball.InputBegan:Fire(ballPress)
    local ballMove = Instance.new('InputObject')
    ballMove.UserInputType = Enum.UserInputType.MouseMovement
    ballMove.Position = Vector3.new(1200, 400, 0)
    Mock.services.UserInputService.InputChanged:Fire(ballMove)
    ballPress.UserInputState = Enum.UserInputState.End
    ballPress.Changed:Fire()
    assert(Nova.Ball.Frac.X > 0.5, '悬浮球拖动后没有吸附到右边: ' .. tostring(Nova.Ball.Frac.X))
end

-- 提示气泡
toggle.Object.MouseEnter:Fire(10, 10)

-- 12) 存档往返（窗口位置 / 折叠状态）
window.Frac.X, window.Frac.Y = 0.42, 0.33
Nova.Scale:SetFollow(window.Object, 0.42, 0.33)
Nova:Save()
Nova.Scale:SetFollow(window.Object, 0.05, 0.05)
Nova.SavedWindows = nil
Nova:Load()
Nova:ApplySaved()
assert(math.abs(window.Object.Position.X.Offset - 0.42 * Mock.Screen.X) < 1,
    '存档没有还原窗口位置: ' .. tostring(window.Object.Position.X.Offset))

-- 13) 清理
Nova:Destroy()
assert(not Nova.Loaded, 'Destroy 之后状态没复位')

print('[phase1] 全功能环境：通过')
"""

TEST_FALLBACK = """
local Nova = getgenv().Nova
assert(Nova and Nova.Loaded, 'Nova 没有初始化')
assert(not Nova.Env.Features.CustomAsset, '这个环境不应该有 getcustomasset')
assert(not Nova.Env.Features.File, '这个环境不应该有文件函数')

-- 资产应该回退到 rbxassetid
assert(Nova.Assets:Get('close') == 'rbxassetid://121816018671466',
    '资产没有回退到 rbxassetid: ' .. tostring(Nova.Assets:Get('close')))
assert(Nova.Assets:Get('logo_small') == '', '没有 rbxassetid 的资产应该返回空字符串')

-- 没有文件函数时，存取配置必须静默跳过而不是报错
Nova:Save()
Nova:Load()

local window = Nova:CreateWindow({Name = '回退窗口', Icon = 'icon_eye', Visible = true})
window:AddToggle({Name = '开关', Default = true})
window:AddSlider({Name = '滑块', Min = 0, Max = 10, Default = 5})
assert(#window.Widgets == 2, '回退环境下控件没有创建')

Nova:Destroy()
print('[phase2] 无文件权限环境：通过')
"""


def run(name: str, lua, sources, test: str) -> list:
    try:
        for source in sources:
            lua.execute(source)
        lua.execute(test)
    except Exception as error:
        print("\n[%s] 失败：\n%s" % (name, error))

        for holder in ("MockGlobal.DebugLog", "MockGlobal.Warnings"):
            try:
                for item in lua.eval(holder).values():
                    print("  -", item)
            except Exception:
                pass

        sys.exit(1)

    warnings = []
    for holder in ("MockGlobal.DebugLog", "MockGlobal.Warnings"):
        try:
            warnings += list(lua.eval(holder).values())
        except Exception:
            pass

    return [str(item) for item in warnings]


def main() -> int:
    print("[mocktest] 载入 Nova.lua + Example.lua ...")
    warnings = run("phase1", make_runtime(json_backend=True), [LIB, EXAMPLE], TEST_MAIN)

    print("[mocktest] 模拟无文件权限的执行器 ...")
    warnings += run("phase2", make_runtime(no_files=True), [LIB], TEST_FALLBACK)

    if warnings:
        print("\n[mocktest] %d 条警告：" % len(warnings))
        for item in warnings:
            print("  -", item)

        return 2

    print("[mocktest] 没有警告")
    return 0


if __name__ == "__main__":
    sys.exit(main())
