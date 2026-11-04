#!/usr/bin/env python3
"""
generate_store_screenshots.py
-----------------------------
Generates 8 studio-grade, professional Google Play Store phone screenshots
for 'Paper Trading - Crypto' (com.acadriotrade).

Supports:
- 1080x1920 (Exact 9:16 aspect ratio for 100% Google Play Console compliance)
- 1080x2400 (Modern tall 20:9 ratio)

Features:
- Obsidian dark mode theme with dynamic colored ambient radial glow
- Sleek modern device chassis with metallic titanium rim, punch-hole camera & soft drop shadow
- Flagship status bar (9:41, full Wi-Fi, 5G, 100% battery)
- High-converting typography with pill badges, bold headers, and crisp subtitles
"""

import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

RAW_DIR = "store_assets/raw"
FONT_DIR = "store_assets/fonts"

DIR_9_16 = "store_assets/phone_1080x1920"
DIR_9_20 = "store_assets/phone_1080x2400"

os.makedirs(DIR_9_16, exist_ok=True)
os.makedirs(DIR_9_20, exist_ok=True)

# Typography
FONT_HEADLINE = "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"
FONT_BODY = os.path.join(FONT_DIR, "Inter-Variable.ttf")
if not os.path.exists(FONT_BODY):
    FONT_BODY = "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"

SLIDES = [
    {
        "id": "1_hero",
        "raw": "1_home.png",
        "badge": "ZERO FINANCIAL RISK",
        "title": "Master Crypto Trading\nWithout Real Risk",
        "subtitle": "Practice with ₹1.6 Cr virtual balance & live markets",
        "accent": (0, 230, 118),       # Neon Emerald
    },
    {
        "id": "2_charts",
        "raw": "2_chart.png",
        "badge": "PRO TRADINGVIEW CHARTS",
        "title": "Execute Trades With\nPro Candlestick Charts",
        "subtitle": "Live Binance data, multi-timeframe candles & order books",
        "accent": (0, 210, 255),       # Electric Cyan
    },
    {
        "id": "3_market",
        "raw": "3_market.png",
        "badge": "50+ CRYPTO MARKETS",
        "title": "Track 50+ Top Coins\nWith Live Sparklines",
        "subtitle": "Real-time prices, 24h gainers/losers & market volume",
        "accent": (168, 85, 247),      # Cyber Violet
    },
    {
        "id": "4_futures_pro",
        "raw": "4_leverage.png",
        "badge": "UP TO 100X MARGIN",
        "title": "Simulate Perpetual\nFutures Trading",
        "subtitle": "Test Long & Short orders with real-time depth & charts",
        "accent": (245, 158, 11),      # Amber Orange
    },
    {
        "id": "5_positions",
        "raw": "5_positions.png",
        "badge": "DYNAMIC MARGIN & ROE",
        "title": "Manage Active Positions\n& Real-Time P&L",
        "subtitle": "Monitor liquidation buffer, ROE% & Take-Profit targets",
        "accent": (16, 185, 129),      # Mint Green
    },
    {
        "id": "6_portfolio",
        "raw": "6_portfolio.png",
        "badge": "PORTFOLIO ANALYTICS",
        "title": "Deep Visual Portfolio\n& Asset Allocation",
        "subtitle": "Interactive donut allocation, win rate & performance analytics",
        "accent": (6, 182, 212),       # Neon Teal
    },
    {
        "id": "7_news",
        "raw": "7_news.png",
        "badge": "24/7 MARKET INTELLIGENCE",
        "title": "Breaking Crypto News\nAt Your Fingertips",
        "subtitle": "Curated headlines from CoinDesk, CoinTelegraph & more",
        "accent": (56, 189, 248),      # Sky Blue
    },
    {
        "id": "8_rewards",
        "raw": "8_rewards.png",
        "badge": "GAMIFIED REWARDS",
        "title": "Earn Daily Rewards,\nXP & Compete In Ranks",
        "subtitle": "Complete missions, maintain streaks & unlock trader badges",
        "accent": (234, 179, 8),       # Golden Yellow
    },
]

def create_background(width, height, accent_rgb, glow_center, glow_radius):
    """Creates modern dark obsidian background with vertical gradient and colored radial glow."""
    base = Image.new("RGBA", (width, height), (0, 0, 0, 255))
    draw = ImageDraw.Draw(base)

    top_color = (11, 17, 32)
    bot_color = (4, 7, 13)
    for y in range(height):
        t = y / height
        r = int(top_color[0] * (1 - t) + bot_color[0] * t)
        g = int(top_color[1] * (1 - t) + bot_color[1] * t)
        b = int(top_color[2] * (1 - t) + bot_color[2] * t)
        draw.line([(0, y), (width, y)], fill=(r, g, b, 255))

    glow_layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow_layer)
    cx, cy = glow_center

    steps = 45
    for i in range(steps, 0, -1):
        radius = int(glow_radius * (i / steps))
        alpha = int(55 * (1.0 - (i / steps)) ** 1.8)
        color = (accent_rgb[0], accent_rgb[1], accent_rgb[2], alpha)
        glow_draw.ellipse(
            [cx - radius, cy - radius, cx + radius, cy + radius],
            fill=color
        )

    glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(radius=65))
    base.alpha_composite(glow_layer)

    grid_overlay = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    grid_draw = ImageDraw.Draw(grid_overlay)
    grid_gap = 70
    for gx in range(35, width, grid_gap):
        for gy in range(35, 450, grid_gap):
            grid_draw.ellipse([gx-1, gy-1, gx+1, gy+1], fill=(255, 255, 255, 14))
    base.alpha_composite(grid_overlay)

    return base

def render_header(image, slide, width, pill_y, title_y, sub_y, title_size=58, sub_size=30, line_spacing=72):
    """Draws pill badge, bold headline, and subtitle tailored to canvas height."""
    draw = ImageDraw.Draw(image)
    accent = slide["accent"]
    badge_text = slide["badge"]
    title_text = slide["title"]
    subtitle_text = slide["subtitle"]

    font_b = ImageFont.truetype(FONT_HEADLINE, 22)
    font_t = ImageFont.truetype(FONT_HEADLINE, title_size)
    font_s = ImageFont.truetype(FONT_BODY, sub_size)

    # 1. Pill Badge
    badge_bbox = font_b.getbbox(badge_text)
    badge_w = badge_bbox[2] - badge_bbox[0]
    badge_h = badge_bbox[3] - badge_bbox[1]
    
    dot_radius = 5
    dot_spacing = 12
    pad_x = 24
    pad_y = 9
    pill_w = badge_w + dot_radius * 2 + dot_spacing + pad_x * 2
    pill_h = badge_h + pad_y * 2
    pill_x = (width - pill_w) // 2

    pill_layer = Image.new("RGBA", (width, image.height), (0, 0, 0, 0))
    pill_draw = ImageDraw.Draw(pill_layer)
    pill_draw.rounded_rectangle(
        [pill_x, pill_y, pill_x + pill_w, pill_y + pill_h],
        radius=pill_h // 2,
        fill=(accent[0], accent[1], accent[2], 30),
        outline=(accent[0], accent[1], accent[2], 160),
        width=2
    )
    dot_cx = pill_x + pad_x + dot_radius
    dot_cy = pill_y + pill_h // 2
    pill_draw.ellipse(
        [dot_cx - dot_radius, dot_cy - dot_radius, dot_cx + dot_radius, dot_cy + dot_radius],
        fill=accent
    )
    image.alpha_composite(pill_layer)

    text_x = dot_cx + dot_radius + dot_spacing
    draw.text(
        (text_x, pill_y + pad_y - 1),
        badge_text,
        font=font_b,
        fill=accent
    )

    # 2. Main Headline
    title_lines = title_text.split("\n")
    y_cursor = title_y
    for line in title_lines:
        line_bbox = font_t.getbbox(line)
        line_w = line_bbox[2] - line_bbox[0]
        line_x = (width - line_w) // 2
        draw.text((line_x, y_cursor), line, font=font_t, fill=(255, 255, 255, 255))
        y_cursor += line_spacing

    # 3. Subtitle
    sub_bbox = font_s.getbbox(subtitle_text)
    sub_w = sub_bbox[2] - sub_bbox[0]
    sub_x = (width - sub_w) // 2
    draw.text((sub_x, sub_y), subtitle_text, font=font_s, fill=(156, 172, 196, 255))

def round_corners(im, radius):
    """Antialiased rounded corners for screen image."""
    mask = Image.new("L", im.size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([(0, 0), im.size], radius=radius, fill=255)
    result = im.copy()
    result.putalpha(mask)
    return result

def overlay_pristine_status_bar(screen_img, width):
    """Draws a crisp modern status bar: 9:41 on left, 5G + Wi-Fi + 100% battery on right."""
    draw = ImageDraw.Draw(screen_img)
    font_clock = ImageFont.truetype(FONT_HEADLINE, 28)
    bar_h = 76
    
    draw.rectangle([(0, 0), (width, bar_h)], fill=(0, 0, 0, 255))
    draw.text((36, 22), "9:41", font=font_clock, fill=(255, 255, 255, 255))

    rx = width - 42
    bat_w, bat_h = 42, 20
    bat_x = rx - bat_w
    bat_y = 26
    draw.rounded_rectangle([bat_x, bat_y, bat_x + bat_w, bat_y + bat_h], radius=5, outline=(255, 255, 255, 200), width=2)
    draw.rectangle([bat_x + bat_w + 1, bat_y + 6, bat_x + bat_w + 3, bat_y + bat_h - 6], fill=(255, 255, 255, 180))
    draw.rounded_rectangle([bat_x + 3, bat_y + 3, bat_x + bat_w - 3, bat_y + bat_h - 3], radius=3, fill=(255, 255, 255, 240))

    wifi_x = bat_x - 36
    wifi_y = bat_y + 1
    draw.arc([wifi_x - 14, wifi_y - 4, wifi_x + 14, wifi_y + 24], start=210, end=330, fill=(255, 255, 255, 240), width=2)
    draw.arc([wifi_x - 9, wifi_y + 2, wifi_x + 9, wifi_y + 20], start=210, end=330, fill=(255, 255, 255, 240), width=2)
    draw.ellipse([wifi_x - 2, wifi_y + 13, wifi_x + 2, wifi_y + 17], fill=(255, 255, 255, 255))

    draw.text((wifi_x - 52, 24), "5G", font=font_clock, fill=(255, 255, 255, 230))

def render_device(image, raw_filename, canvas_w, canvas_h, phone_y, screen_w):
    """Renders the framed phone mockup onto the canvas."""
    raw_path = os.path.join(RAW_DIR, raw_filename)
    if not os.path.exists(raw_path):
        return

    raw_img = Image.open(raw_path).convert("RGBA")
    aspect = raw_img.height / raw_img.width
    screen_h = int(screen_w * aspect)

    resized_screen = raw_img.resize((screen_w, screen_h), Image.Resampling.LANCZOS)
    overlay_pristine_status_bar(resized_screen, screen_w)
    rounded_screen = round_corners(resized_screen, radius=46)

    bezel = 14
    chassis_w = screen_w + bezel * 2
    chassis_h = screen_h + bezel * 2
    chassis_radius = 58

    phone_x = (canvas_w - chassis_w) // 2

    # Drop shadows
    shadow_layer = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(shadow_layer)
    s_draw.rounded_rectangle(
        [phone_x - 12, phone_y + 18, phone_x + chassis_w + 12, phone_y + chassis_h + 36],
        radius=chassis_radius + 6,
        fill=(0, 0, 0, 160)
    )
    shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(radius=42))
    image.alpha_composite(shadow_layer)

    sharp_shadow = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
    ss_draw = ImageDraw.Draw(sharp_shadow)
    ss_draw.rounded_rectangle(
        [phone_x - 4, phone_y + 8, phone_x + chassis_w + 4, phone_y + chassis_h + 16],
        radius=chassis_radius,
        fill=(0, 0, 0, 180)
    )
    sharp_shadow = sharp_shadow.filter(ImageFilter.GaussianBlur(radius=16))
    image.alpha_composite(sharp_shadow)

    # Chassis
    chassis_layer = Image.new("RGBA", (chassis_w, chassis_h), (0, 0, 0, 0))
    c_draw = ImageDraw.Draw(chassis_layer)
    c_draw.rounded_rectangle([(0, 0), (chassis_w, chassis_h)], radius=chassis_radius, fill=(16, 22, 34, 255), outline=(52, 66, 92, 255), width=3)
    c_draw.rounded_rectangle([(3, 3), (chassis_w - 3, chassis_h - 3)], radius=chassis_radius - 2, outline=(26, 36, 52, 255), width=2)
    chassis_layer.alpha_composite(rounded_screen, (bezel, bezel))

    # Punch hole
    camera_w = 26
    camera_h = 26
    cam_x = chassis_w // 2 - camera_w // 2
    cam_y = bezel + 12
    c_draw.ellipse([cam_x, cam_y, cam_x + camera_w, cam_y + camera_h], fill=(6, 8, 12, 255), outline=(30, 38, 52, 255), width=1)
    c_draw.ellipse([cam_x + 6, cam_y + 6, cam_x + 10, cam_y + 10], fill=(36, 54, 90, 220))

    # Sheen
    sheen = Image.new("RGBA", (chassis_w, chassis_h), (0, 0, 0, 0))
    sh_draw = ImageDraw.Draw(sheen)
    sh_draw.polygon([(chassis_w - 200, bezel), (chassis_w - bezel, bezel), (chassis_w - bezel, 420), (chassis_w - 300, bezel)], fill=(255, 255, 255, 12))
    chassis_layer.alpha_composite(sheen)

    image.alpha_composite(chassis_layer, (phone_x, phone_y))

def build_set(width, height, out_dir, pill_y, title_y, sub_y, phone_y, screen_w, title_size, sub_size, line_spacing):
    print(f"\nBuilding {width}x{height} assets -> {out_dir}")
    for i, slide in enumerate(SLIDES, start=1):
        canvas = create_background(width, height, slide["accent"], (width // 2, height // 2 - 200), 500)
        render_header(canvas, slide, width, pill_y, title_y, sub_y, title_size, sub_size, line_spacing)
        render_device(canvas, slide["raw"], width, height, phone_y, screen_w)

        out_name = f"{i}_{slide['id']}.png"
        out_path = os.path.join(out_dir, out_name)
        rgb_canvas = canvas.convert("RGB")
        rgb_canvas.save(out_path, "PNG", optimize=True)
        size_kb = os.path.getsize(out_path) / 1024
        print(f"  [{i}/8] {out_name} ({size_kb:.1f} KB)")

def main():
    # 1. 1080x1920 (Pure 9:16 - 100% Google Play Console Compliant)
    build_set(
        width=1080,
        height=1920,
        out_dir=DIR_9_16,
        pill_y=55,
        title_y=140,
        sub_y=288,
        phone_y=385,
        screen_w=820,
        title_size=56,
        sub_size=28,
        line_spacing=70
    )

    # 2. 1080x2400 (Tall 20:9 Full-Chassis View)
    build_set(
        width=1080,
        height=2400,
        out_dir=DIR_9_20,
        pill_y=95,
        title_y=190,
        sub_y=352,
        phone_y=515,
        screen_w=840,
        title_size=62,
        sub_size=32,
        line_spacing=76
    )

    print("\n🎉 Both 1080x1920 and 1080x2400 Google Play Store asset sets generated successfully!")

if __name__ == "__main__":
    main()
