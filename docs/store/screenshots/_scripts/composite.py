#!/usr/bin/env python3
"""Composite each captured Latte window onto a 2880x1800 brand-gradient canvas
(App Store macOS required size) with a soft drop shadow."""
import os
from PIL import Image, ImageFilter, ImageDraw

CW, CH = 2880, 1800
TOP = (32, 26, 22)     # dark espresso
BOT = (74, 52, 36)     # warm caramel-brown
SRC = "/tmp/latte-shots"
DST = "/tmp/latte-shots/final"
os.makedirs(DST, exist_ok=True)

# vertical gradient via a 1xCH strip resized to full width
strip = Image.new("RGB", (1, CH))
for y in range(CH):
    t = y / (CH - 1)
    strip.putpixel((0, y), tuple(int(TOP[i] + (BOT[i] - TOP[i]) * t) for i in range(3)))
BG = strip.resize((CW, CH), Image.BICUBIC)

# subtle centered warm glow for depth
glow = Image.new("L", (CW, CH), 0)
ImageDraw.Draw(glow).ellipse([CW * 0.18, CH * 0.06, CW * 0.82, CH * 0.98], fill=42)
glow = glow.filter(ImageFilter.GaussianBlur(260))
warm = Image.new("RGB", (CW, CH), (110, 82, 56))
BG = Image.composite(warm, BG, glow)


def place(src_name, out_name, max_scale=1.65, crop_bottom=0.0):
    win = Image.open(os.path.join(SRC, src_name)).convert("RGBA")
    if crop_bottom > 0:
        win = win.crop((0, 0, win.width, int(win.height * (1 - crop_bottom))))
    maxw, maxh = int(CW * 0.70), int(CH * 0.80)
    scale = min(maxw / win.width, maxh / win.height, max_scale)
    nw, nh = int(win.width * scale), int(win.height * scale)
    win = win.resize((nw, nh), Image.LANCZOS)
    x, y = (CW - nw) // 2, (CH - nh) // 2

    canvas = BG.convert("RGBA")
    shadow = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
    shadow.paste(Image.new("RGBA", (nw, nh), (0, 0, 0, 165)), (x, y + 22))
    shadow = shadow.filter(ImageFilter.GaussianBlur(44))
    canvas = Image.alpha_composite(canvas, shadow)
    canvas.paste(win, (x, y), win)
    out = os.path.join(DST, out_name)
    canvas.convert("RGB").save(out, "PNG")
    print(f"  {out_name}  {canvas.width}x{canvas.height}  ({os.path.getsize(out)//1024} KB)")


jobs = [
    ("1-cup.png",        "01-cup.png",      3.0,  0.0),   # brand hero (flat vector)
    ("M-menubar-off.png","02-menubar.png",  1.40, 0.0),   # CORE — keep awake controls
    ("3-triggers.png",   "03-triggers.png", 1.65, 0.0),   # automation differentiator
    ("2-general.png",    "04-general.png",  1.65, 0.0),
    ("4b-activity.png",  "05-activity.png", 1.65, 0.075),  # trim cut-off 14d sliver
    ("A-language.png",   "06-language.png", 1.55, 0.0),   # 11-language i18n
    ("5-about.png",      "07-about.png",    1.8,  0.0),
]
print("== composited 2880x1800 ==")
for s, o, ms, cb in jobs:
    place(s, o, ms, cb)
