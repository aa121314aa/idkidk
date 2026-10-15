#!/usr/bin/env python3
"""
把 src/library/*.lua 拼成单个可执行文件 src/Nova.lua。

执行器里一般只能 loadstring 一段脚本，单文件最省事；
开发时仍然按模块分文件维护，改完跑一次：

    python3 tools/build.py
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "src" / "library"
OUT = ROOT / "src" / "Nova.lua"

HEADER = """--[==[
	Nova GUI v%s — Roblox 客户端脚本 UI 库

	风格参考 Vape V4：暗色 + 细描边 + 像素小圆角 + 多窗口 + 悬浮球。
	本文件由 tools/build.py 从 src/library/*.lua 自动生成，不要直接改这里。

	用法（执行器里）：
		loadstring(game:HttpGet("https://raw.githubusercontent.com/aa121314aa/idkidk/main/src/Nova.lua", true))()

	加载后：
		local Nova = getgenv().Nova
		local win = Nova:CreateWindow({Name = "我的窗口", Icon = "icon_wrench", Visible = true})
		win:AddToggle({Name = "开关", Callback = function(v) print(v) end})
]==]

"""

FOOTER = """
--[==[ 自动初始化 ]==]

if NovaLib.AutoInit ~= false and not getgenv().NovaNoAutoInit then
	NovaLib:Init()
end

return NovaLib
"""


def main() -> None:
    version = "0.0.0"
    core = (LIB / "00_Core.lua").read_text(encoding="utf-8")
    for line in core.splitlines():
        if "NovaLib.Version" in line:
            version = line.split("'")[1]
            break

    parts = [HEADER % version]
    for path in sorted(LIB.glob("*.lua")):
        text = path.read_text(encoding="utf-8").rstrip("\n")
        parts.append("--[==[ %s ]==]\n%s\n" % (path.name, text))

    parts.append(FOOTER)

    OUT.write_text("\n".join(parts), encoding="utf-8")
    print("built %s (%d bytes, %d modules)" % (OUT.relative_to(ROOT), OUT.stat().st_size, len(list(LIB.glob("*.lua")))))


if __name__ == "__main__":
    main()
