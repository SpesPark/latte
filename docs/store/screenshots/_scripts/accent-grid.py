#!/usr/bin/env python3
"""Compose the 6 accent cups into one 2880x1800 'coffee tones' showcase."""
import os
from PIL import Image, ImageFilter, ImageDraw, ImageFont

CW, CH = 2880, 1800
TOP, BOT = (32, 26, 22), (74, 52, 36)
SRC = "/tmp/latte-shots"
OUT = "/tmp/latte-shots/final/06-accents.png"
FONT = "/System/Library/Fonts/SFNS.ttf"
accents = [("espresso", "Espresso"), ("caramel", "Caramel"), ("mocha", "Mocha"),
           ("latte", "Latte"), ("matcha", "Matcha"), ("noir", "Noir")]

# gradient + glow
strip = Image.new("RGB", (1, CH))
for y in range(CH):
    t = y / (CH - 1)
    strip.putpixel((0, y), tuple(int(TOP[i] + (BOT[i] - TOP[i]) * t) for i in range(3)))
bg = strip.resize((CW, CH), Image.BICUBIC)
glow = Image.new("L", (CW, CH), 0)
ImageDraw.Draw(glow).ellipse([CW*0.18, CH*0.06, CW*0.82, CH*0.98], fill=40)
glow = glow.filter(ImageFilter.GaussianBlur(260))
bg = Image.composite(Image.new("RGB", (CW, CH), (110, 82, 56)), bg, glow)
canvas = bg.convert("RGBA")
draw = ImageDraw.Draw(canvas)

title_f = ImageFont.truetype(FONT, 92)
sub_f = ImageFont.truetype(FONT, 46)
label_f = ImageFont.truetype(FONT, 50)

def ctext(y, text, font, fill):
    w = draw.textbbox((0, 0), text, font=font)[2]
    draw.text(((CW - w) // 2, y), text, font=font, fill=fill)

ctext(118, "Make it yours", title_f, (245, 240, 235, 255))
ctext(232, "Six coffee tones to match your desktop", sub_f, (210, 195, 180, 230))

cols, rows = 3, 2
cup_scale = 1.15
grid_top, grid_bottom = 360, 1680
cell_w = CW // cols
row_h = (grid_bottom - grid_top) // rows

for i, (key, name) in enumerate(accents):
    img = Image.open(os.path.join(SRC, f"cup-{key}.png")).convert("RGBA")
    nw, nh = int(img.width * cup_scale), int(img.height * cup_scale)
    img = img.resize((nw, nh), Image.LANCZOS)
    col, row = i % cols, i // cols
    cx = col * cell_w + cell_w // 2
    cell_cy = grid_top + row * row_h + row_h // 2
    x = cx - nw // 2
    y = cell_cy - nh // 2 - 30  # leave room for label below
    # shadow
    sh = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
    sh.paste(Image.new("RGBA", (nw, nh), (0, 0, 0, 150)), (x, y + 16))
    sh = sh.filter(ImageFilter.GaussianBlur(34))
    canvas = Image.alpha_composite(canvas, sh)
    canvas.paste(img, (x, y), img)
    draw = ImageDraw.Draw(canvas)
    lw = draw.textbbox((0, 0), name, font=label_f)[2]
    draw.text((cx - lw // 2, y + nh + 18), name, font=label_f, fill=(235, 225, 215, 255))

canvas.convert("RGB").save(OUT, "PNG")
print(f"  06-accents.png  {CW}x{CH}  ({os.path.getsize(OUT)//1024} KB)")
