#!/usr/bin/env python3
"""
把 UI 画成一张预览图（不需要 Roblox）。

用的是库里的真实数值：设计分辨率 1920x1080、同一套配色、同一批 assets 图标。
改了 Theme / 尺寸之后重跑一次就能看到效果：

    python3 tools/preview.py
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
OUT = ROOT / "preview" / "ui-preview.png"

FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

# 与 src/library/03_Theme.lua 保持一致
MAIN = (26, 25, 26)
TEXT = (200, 200, 200)
STROKE = (85, 85, 85)
ACCENT_HSV = (0.46, 0.96, 0.52)
CORNER = 4

W_WIDTH, W_TOPBAR = 240, 34
ROW, MODULE, SECTION = 30, 38, 26


def hsv_to_rgb(h: float, s: float, v: float):
    import colorsys

    r, g, b = colorsys.hsv_to_rgb(h, s, v)

    return int(r * 255), int(g * 255), int(b * 255)


ACCENT = hsv_to_rgb(*ACCENT_HSV)


def dark(color, amount: float):
    import colorsys

    h, s, v = colorsys.rgb_to_hsv(*[c / 255 for c in color])

    return hsv_to_rgb(h, s, max(v - amount, 0))


def light(color, amount: float):
    import colorsys

    h, s, v = colorsys.rgb_to_hsv(*[c / 255 for c in color])

    return hsv_to_rgb(h, s, min(v + amount, 1))


WINDOW_BG = dark(MAIN, 0.02)
CHILD_BG = dark(MAIN, 0.03)
TEXT_DIM = dark(TEXT, 0.16)
ICON = light(MAIN, 0.37)
HOLDER_OFF = light(MAIN, 0.14)
HOVER = light(MAIN, 0.03)

_fonts = {}


def font(size: int, bold: bool = False):
    key = (size, bold)
    if key not in _fonts:
        _fonts[key] = ImageFont.truetype(FONT_BOLD if bold else FONT, size)

    return _fonts[key]


_icons = {}


def icon(name: str, size: int, color=(255, 255, 255), keep_colors: bool = False):
    """读取 assets 里的图标并按目标颜色着色"""
    if keep_colors:
        source = Image.open(ASSETS / (name + ".png")).convert("RGBA")
        if source.size != (size, size):
            source = source.resize((size, size), Image.LANCZOS)

        return source

    key = (name, size, color)
    if key in _icons:
        return _icons[key]

    source = Image.open(ASSETS / (name + ".png")).convert("RGBA")
    if source.size != (size, size):
        source = source.resize((size, size), Image.LANCZOS)

    mask = source.split()[3].point(lambda value: min(255, int(value * 1.3)))
    tinted = Image.new("RGBA", source.size, color + (0,))
    tinted.putalpha(mask)
    _icons[key] = tinted

    return tinted


class Canvas:
    def __init__(self):
        self.image = Image.new("RGB", (1920, 1080), (18, 18, 18))
        self.draw = ImageDraw.Draw(self.image, "RGBA")
        self.background()

    def background(self):
        """随便画点背景，暗示这是游戏画面"""
        draw = self.draw
        for y in range(1080):
            t = y / 1080
            draw.line([(0, y), (1920, y)], fill=(int(34 - 16 * t), int(34 - 16 * t), int(38 - 18 * t)))

        for index, (cx, cy, radius) in enumerate([(300, 900, 520), (1200, 980, 700), (1750, 880, 460)]):
            draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=(26, 26, 30))

        draw.rectangle([0, 700, 1920, 1080], fill=(22, 22, 24))
        draw.line([(0, 700), (1920, 700)], fill=(40, 40, 44), width=2)

    def rr(self, box, radius=CORNER, fill=None, outline=None, width=1):
        self.draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)

    def text(self, xy, value, size=14, color=TEXT, bold=False, anchor="lm"):
        self.draw.text(xy, value, font=font(size, bold), fill=color, anchor=anchor)

    def paste(self, image, xy):
        self.image.paste(image, xy, image)

    def save(self):
        OUT.parent.mkdir(parents=True, exist_ok=True)
        self.image.save(OUT)
        print("saved", OUT.relative_to(ROOT), self.image.size)


def draw_ball(canvas: Canvas, x: int, y: int):
    width, height = 104, 40
    canvas.rr([x, y, x + width, y + height], fill=WINDOW_BG, outline=STROKE + (60,))
    canvas.paste(icon("logo_small", 24, keep_colors=True), (x + 9, y + (height - 24) // 2))
    canvas.text((x + 40, y + height // 2), "NOVA", size=15, color=TEXT, bold=True)


def draw_window(canvas: Canvas, x: int, y: int, width: int, body_height: int, title: str, icon_name: str):
    height = W_TOPBAR + body_height
    canvas.rr([x, y, x + width, y + height], fill=WINDOW_BG, outline=STROKE + (60,))

    if icon_name:
        canvas.paste(icon(icon_name, 16, ACCENT, keep_colors=(icon_name == "logo_small")),
                     (x + 11, y + (W_TOPBAR - 16) // 2))

    canvas.text((x + 11 + 16 + 11, y + W_TOPBAR // 2), title, size=14, bold=True)

    # 右上角：折叠 / 关闭
    canvas.paste(icon("collapse", 10, ICON), (x + width - 34 - 5 + 5, y + (W_TOPBAR - 5) // 2))
    canvas.paste(icon("close", 14, ICON), (x + width - 8 - 14, y + (W_TOPBAR - 14) // 2))

    canvas.draw.line([(x, y + W_TOPBAR - 1), (x + width, y + W_TOPBAR - 1)], fill=(48, 48, 48))

    return y + W_TOPBAR


def row_divider(canvas: Canvas, x: int, y: int, width: int):
    canvas.draw.line([(x, y - 1), (x + width, y - 1)], fill=(36, 36, 36))


def draw_toggle(canvas: Canvas, x: int, y: int, width: int, label: str, enabled: bool):
    canvas.rr([x, y, x + width, y + ROW], fill=MAIN)
    canvas.text((x + 12, y + ROW // 2), label, size=14, color=TEXT_DIM)

    holder_x = x + width - 11 - 22
    canvas.rr([holder_x, y + 9, holder_x + 22, y + 21], radius=6, fill=ACCENT if enabled else HOLDER_OFF)
    knob_x = holder_x + (12 if enabled else 2)
    canvas.rr([knob_x, y + 11, knob_x + 8, y + 19], radius=4, fill=MAIN)
    row_divider(canvas, x, y + ROW, width)


def draw_button(canvas: Canvas, x: int, y: int, width: int, label: str):
    canvas.rr([x, y, x + width, y + ROW], fill=HOVER)
    canvas.text((x + 12, y + ROW // 2), label, size=14, color=TEXT_DIM)
    row_divider(canvas, x, y + ROW, width)


def draw_slider(canvas: Canvas, x: int, y: int, width: int, label: str, value: float, max_value=100):
    canvas.rr([x, y, x + width, y + 42], fill=MAIN)
    canvas.text((x + 12, y + 11), label, size=14, color=TEXT_DIM)
    canvas.text((x + width - 12, y + 11), "%d%%" % value, size=13, color=dark(TEXT, 0.02), anchor="rm")

    bar_x, bar_w = x + 12, width - 24
    canvas.rr([bar_x, y + 28, bar_x + bar_w, y + 32], radius=2, fill=dark(MAIN, 0.1))
    fill_w = int(bar_w * value / max_value)
    canvas.rr([bar_x, y + 28, bar_x + fill_w, y + 32], radius=2, fill=ACCENT)
    canvas.rr([bar_x + fill_w - 5, y + 25, bar_x + fill_w + 5, y + 35], radius=5, fill=TEXT)
    row_divider(canvas, x, y + 42, width)


def draw_dropdown(canvas: Canvas, x: int, y: int, width: int, label: str, value: str):
    canvas.rr([x, y, x + width, y + ROW], fill=MAIN)
    canvas.text((x + 12, y + ROW // 2), label, size=14, color=TEXT_DIM)
    canvas.text((x + width - 26, y + ROW // 2), value, size=13, color=dark(TEXT, 0.02), anchor="rm")
    canvas.paste(icon("chevron", 10, ICON), (x + width - 12 - 10, y + (ROW - 5) // 2))
    row_divider(canvas, x, y + ROW, width)


def draw_textbox(canvas: Canvas, x: int, y: int, width: int, label: str, placeholder: str):
    canvas.rr([x, y, x + width, y + ROW], fill=MAIN)
    canvas.text((x + 12, y + ROW // 2), label, size=14, color=TEXT_DIM)
    holder_x = x + width - 12 - 100
    canvas.rr([holder_x, y + 5, holder_x + 100, y + 25], radius=3, fill=dark(MAIN, 0.06))
    canvas.text((holder_x + 6, y + ROW // 2), placeholder, size=13, color=TEXT_DIM)
    row_divider(canvas, x, y + ROW, width)


def draw_keybind(canvas: Canvas, x: int, y: int, width: int, label: str, value: str):
    canvas.rr([x, y, x + width, y + ROW], fill=MAIN)
    canvas.text((x + 12, y + ROW // 2), label, size=14, color=TEXT_DIM)
    holder_x = x + width - 12 - 90
    canvas.rr([holder_x, y + 6, holder_x + 90, y + 24], radius=3, fill=HOLDER_OFF)
    canvas.text((holder_x + 45, y + ROW // 2), value, size=12, color=TEXT, bold=True, anchor="mm")
    row_divider(canvas, x, y + ROW, width)


def draw_section(canvas: Canvas, x: int, y: int, width: int, label: str):
    canvas.rr([x, y, x + width, y + SECTION], fill=CHILD_BG)
    canvas.text((x + 12, y + SECTION // 2), label.upper(), size=11, color=(150, 150, 150), bold=True)


def draw_module(canvas: Canvas, x: int, y: int, width: int, label: str, enabled: bool, children=None):
    canvas.rr([x, y, x + width, y + MODULE], fill=ACCENT if enabled else MAIN)
    canvas.rr([x + 6, y + 15, x + 14, y + 23], radius=2, fill=(40, 40, 40) if enabled else HOLDER_OFF)
    canvas.text((x + 16, y + MODULE // 2), label, size=14,
                color=(40, 40, 40) if enabled else TEXT_DIM)
    canvas.paste(icon("dots", 3, (40, 40, 40) if enabled else ICON), (x + width - 6 - 3, y + 11))
    row_divider(canvas, x, y + MODULE, width)

    if children:
        canvas.rr([x, y + MODULE, x + width, y + MODULE + children], fill=CHILD_BG)


def draw_notification(canvas: Canvas, x: int, y: int, title: str, text: str, kind="info"):
    canvas.rr([x, y, x + 266, y + 75], radius=7, fill=WINDOW_BG, outline=STROKE + (60,))
    canvas.paste(icon("noti_" + kind, 30), (x + 12, y + 22))
    canvas.text((x + 52, y + 18), title, size=14, bold=True)
    canvas.text((x + 52, y + 40), text, size=13, color=TEXT_DIM)
    canvas.rr([x + 10, y + 65, x + 256, y + 67], radius=1, fill=(255, 255, 255))


def main():
    canvas = Canvas()

    # 主窗口：列出所有窗口
    main_rows = [("Demo", "icon_box", True), ("Settings", "settings", False), ("About", "icon_eye", False)]
    body = len(main_rows) * 34 + 24
    top = draw_window(canvas, 40, 110, 220, body, "Nova", "logo_small")

    for index, (name, icon_name, enabled) in enumerate(main_rows):
        y = top + index * 34
        canvas.rr([40, y, 260, y + 34], fill=HOVER if enabled else MAIN)
        canvas.paste(icon(icon_name, 16, ACCENT if enabled else ICON), (52, y + 9))
        canvas.text((40 + 38, y + 17), name, size=14, color=TEXT if enabled else TEXT_DIM)
        dot_x = 260 - 12 - 8
        canvas.rr([dot_x, y + 13, dot_x + 8, y + 21], radius=4,
                  fill=ACCENT if enabled else HOLDER_OFF)

    canvas.text((52, top + len(main_rows) * 34 + 12), "Nova v1.0.0  ·  Executor", size=12,
                color=dark(TEXT, 0.5))

    # 悬浮球
    draw_ball(canvas, 23, 497)

    # 示例窗口
    x, width = 300, W_WIDTH
    top = draw_window(canvas, x, 140, width, 26 + ROW + 42 + ROW + ROW + ROW + 26 + MODULE + 72 + 24, "Demo", "icon_box")

    y = top
    draw_section(canvas, x, y, width, "controls")
    y += SECTION
    draw_toggle(canvas, x, y, width, "Toggle", True)
    y += ROW
    draw_button(canvas, x, y, width, "Button")
    y += ROW
    draw_slider(canvas, x, y, width, "Slider", 62)
    y += 42
    draw_dropdown(canvas, x, y, width, "Dropdown", "Option A")
    y += ROW
    draw_textbox(canvas, x, y, width, "TextBox", "type here")
    y += ROW
    draw_keybind(canvas, x, y, width, "Keybind", "RightShift")
    y += ROW
    draw_section(canvas, x, y, width, "modules")
    y += SECTION
    draw_module(canvas, x, y, width, "Demo Module", True, children=72)
    y += MODULE
    draw_toggle(canvas, x, y, width, "Inner Toggle", True)
    y += ROW
    draw_slider(canvas, x, y, width, "Inner Slider", 4, max_value=10)

    # 通知
    draw_notification(canvas, 1920 - 12 - 266, 1080 - 12 - 75, "Nova", "Loaded. Press RightShift to toggle.")

    canvas.save()


if __name__ == "__main__":
    main()
