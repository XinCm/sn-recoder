#!/usr/bin/env python3
"""Draws the MemoBar app icon and packs it into MemoBar/Resources/AppIcon.icns."""
import os
import subprocess
from PIL import Image, ImageDraw, ImageFilter, ImageFont

SIZE = 1024
OUT = os.path.join(os.path.dirname(__file__), "..", "MemoBar", "Resources")

img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

# Rounded background with a vertical blue gradient, clipped to the shape.
bg_mask = Image.new("L", (SIZE, SIZE), 0)
ImageDraw.Draw(bg_mask).rounded_rectangle((40, 40, SIZE - 40, SIZE - 40), radius=220, fill=255)
gradient = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
grad_draw = ImageDraw.Draw(gradient)
top = (94, 170, 255)
bottom = (10, 104, 245)
for y in range(40, SIZE - 40):
    t = (y - 40) / max(1, SIZE - 80)
    color = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,)
    grad_draw.line([(0, y), (SIZE, y)], fill=color)
img.paste(gradient, (0, 0), bg_mask)

# Calendar sheet with a soft drop shadow.
sheet_box = (188, 236, 836, 812)
shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
ImageDraw.Draw(shadow).rounded_rectangle(
    (sheet_box[0] + 6, sheet_box[1] + 26, sheet_box[2] + 6, sheet_box[3] + 34),
    radius=92,
    fill=(0, 30, 80, 120),
)
shadow = shadow.filter(ImageFilter.GaussianBlur(28))
img = Image.alpha_composite(img, shadow)

sheet_mask = Image.new("L", (SIZE, SIZE), 0)
ImageDraw.Draw(sheet_mask).rounded_rectangle(sheet_box, radius=92, fill=255)
sheet = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
sheet_draw = ImageDraw.Draw(sheet)
sheet_draw.rounded_rectangle(sheet_box, radius=92, fill=(255, 255, 255, 255))
# Red header band along the very top of the sheet; the sheet mask rounds its top corners.
sheet_draw.rectangle((sheet_box[0], sheet_box[1], sheet_box[2], sheet_box[1] + 140), fill=(255, 90, 94, 255))
img.paste(sheet, (0, 0), sheet_mask)

# Date number.
font_path = "/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf"
font = ImageFont.truetype(font_path, 300)
draw = ImageDraw.Draw(img)
text = "24"
bbox = draw.textbbox((0, 0), text, font=font)
text_width = bbox[2] - bbox[0]
text_height = bbox[3] - bbox[1]
x = (SIZE - text_width) / 2 - bbox[0]
body_top = sheet_box[1] + 140
body_center = (body_top + sheet_box[3]) / 2
y = body_center - text_height / 2 - bbox[1]
draw.text((x, y), text, font=font, fill=(21, 58, 112, 255))

# Three binder dots in the header band.
for index in range(3):
    cx = SIZE / 2 + (index - 1) * 84
    cy = sheet_box[1] + 70
    draw.ellipse((cx - 15, cy - 15, cx + 15, cy + 15), fill=(255, 255, 255, 215))

os.makedirs(OUT, exist_ok=True)
img.save(os.path.join(OUT, "AppIcon-1024.png"))

iconset = os.path.join(OUT, "AppIcon.iconset")
os.makedirs(iconset, exist_ok=True)
for base in (16, 32, 128, 256, 512):
    for scale in (1, 2):
        px = base * scale
        name = f"icon_{base}x{base}{'@2x' if scale == 2 else ''}.png"
        img.resize((px, px), Image.LANCZOS).save(os.path.join(iconset, name))

subprocess.run(["iconutil", "-c", "icns", iconset, "-o", os.path.join(OUT, "AppIcon.icns")], check=True)
print("Wrote", os.path.join(OUT, "AppIcon.icns"))
