#!/usr/bin/env python3
from PIL import Image, ImageDraw, ImageFont
import math

# Create 1024x1024 image
img = Image.new('RGBA', (1024, 1024), (26, 26, 26, 255))
draw = ImageDraw.Draw(img)

# Colors
orange = (255, 107, 53)
white = (255, 255, 255)
gray = (102, 102, 102)
gold = (255, 215, 0)

# Draw background circle
draw.ellipse([32, 32, 992, 992], fill=(*orange, 26))

# Draw beer mug body
mug_points = [(392, 300), (392, 650), (632, 650), (632, 300)]
draw.rectangle([392, 300, 632, 650], fill=orange, outline=(26, 26, 26), width=8)

# Draw foam (ellipses)
draw.ellipse([352, 240, 672, 340], fill=(247, 247, 247))
draw.ellipse([432, 220, 592, 290], fill=white)
draw.ellipse([512, 225, 652, 285], fill=white)

# Draw beer inside (semi-transparent)
for i in range(5):
    alpha = int(255 * 0.08)
    draw.rectangle([402, 320, 622, 640], fill=(*orange, alpha))

# Draw handle
draw.arc([632, 380, 732, 520], 270, 90, fill=orange, width=20)

# Draw text
try:
    font_large = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 80)
    font_medium = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 60)
except:
    font_large = ImageFont.load_default()
    font_medium = ImageFont.load_default()

draw.text((512, 720), "PINTS", fill=orange, font=font_large, anchor="mm")
draw.text((512, 800), "LEAGUE", fill=gray, font=font_medium, anchor="mm")

# Save
img.save('assets/images/splash_logo.png')
print("✅ Splash logo created!")
