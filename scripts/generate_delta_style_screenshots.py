#!/usr/bin/env python3
"""
generate_delta_style_screenshots.py
-----------------------------------
Generates ultra-professional, Delta-by-eToro inspired Google Play Store
phone listing screenshots (1080x1920, exact 9:16 aspect ratio).

Design Philosophy:
- Heavyweight geometric uppercase display typography (Montserrat Black)
- Elegant subtitle in title-case (Montserrat Bold / Slate)
- Delta-style dynamic background ribbons, organic curved waves & accent geometric shapes
- Sleek modern smartphone mockup with metallic titanium chassis & drop shadow
- Floating notification / feature cards overlaying the device for high visual depth
- 100% compliant with Google Play Console (1080x1920, PNG < 8MB)
"""

import os
import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

CANVAS_W = 1080
CANVAS_H = 1920

RAW_DIR = "store_assets/raw"
OUTPUT_DIR = "store_assets/phone_delta_style"
FONT_DIR = "store_assets/fonts"

os.makedirs(OUTPUT_DIR, exist_ok=True)

# Fonts
FONT_BLACK = os.path.join(FONT_DIR, "Montserrat-Black.ttf")
FONT_BOLD = os.path.join(FONT_DIR, "Montserrat-Bold.ttf")
FONT_EXTRA = os.path.join(FONT_DIR, "Montserrat-ExtraBold.ttf")

font_headline = ImageFont.truetype(FONT_BLACK, 66)
font_subtitle = ImageFont.truetype(FONT_BOLD, 30)
font_badge = ImageFont.truetype(FONT_EXTRA, 22)
font_card_title = ImageFont.truetype(FONT_EXTRA, 26)
font_card_body = ImageFont.truetype(FONT_BOLD, 22)
font_clock = ImageFont.truetype(FONT_BOLD, 28)

SLIDES = [
    {
        "id": "1_hero",
        "raw": "1_home.png",
        "title": "YOUR TRADING\nSUPERPOWER",
        "subtitle": "Practice risk-free with $170,000+ virtual capital",
        "ribbon_color": (99, 102, 241),      # Indigo Violet
        "accent_shape": (16, 185, 129),      # Mint Emerald
        "floating_card": {
            "title": "100% RISK-FREE TRADING",
            "subtitle": "Real market volatility • Zero financial loss",
            "tag": "FREE",
            "tag_color": (16, 185, 129),
        }
    },
    {
        "id": "2_charts",
        "raw": "2_chart.png",
        "title": "REAL-TIME\nCANDLE CHARTS",
        "subtitle": "Live TradingView candles, MA lines & volume depth",
        "ribbon_color": (6, 182, 212),       # Electric Cyan
        "accent_shape": (59, 130, 246),      # Sky Blue
        "floating_card": {
            "title": "TRADINGVIEW POWERED",
            "subtitle": "15m, 1H, 4H, 1D live multi-timeframes",
            "tag": "PRO",
            "tag_color": (6, 182, 212),
        }
    },
    {
        "id": "3_markets",
        "raw": "3_market.png",
        "title": "TRACK 50+\nCRYPTO PAIRS",
        "subtitle": "Live Binance market prices, sparklines & 24h stats",
        "ribbon_color": (168, 85, 247),      # Cyber Violet
        "accent_shape": (16, 185, 129),      # Emerald
        "floating_card": {
            "title": "SPOT WATCHLIST & FILTERS",
            "subtitle": "Layer 1, Layer 2, DeFi & top volume gainers",
            "tag": "LIVE",
            "tag_color": (168, 85, 247),
        }
    },
    {
        "id": "4_futures",
        "raw": "4_leverage.png",
        "title": "100X FUTURES\nSIMULATOR",
        "subtitle": "Simulate high-leverage perpetuals with zero risk",
        "ribbon_color": (245, 158, 11),      # Amber
        "accent_shape": (239, 68, 68),       # Crimson Red
        "floating_card": {
            "title": "UP TO 100X MARGIN",
            "subtitle": "Instant Long/Short execution & real order books",
            "tag": "PERP",
            "tag_color": (245, 158, 11),
        }
    },
    {
        "id": "5_positions",
        "raw": "5_positions.png",
        "title": "ACTIVE POSITIONS\n& REAL-TIME P&L",
        "subtitle": "Monitor liquidation buffer, ROE% & Take-Profit targets",
        "ribbon_color": (16, 185, 129),      # Emerald Green
        "accent_shape": (234, 179, 8),       # Gold
        "floating_card": {
            "title": "+4,227% ROE RECORDED",
            "subtitle": "Dynamic liquidation alert • Auto TP/SL safety",
            "tag": "WIN",
            "tag_color": (16, 185, 129),
        }
    },
    {
        "id": "6_portfolio",
        "raw": "6_portfolio.png",
        "title": "POWERFUL\nANALYTICS",
        "subtitle": "Interactive asset allocation & portfolio diversity",
        "ribbon_color": (14, 165, 233),      # Sky Cyan
        "accent_shape": (168, 85, 247),      # Violet
        "floating_card": {
            "title": "VISUAL ALLOCATION DONUT",
            "subtitle": "67% Cash • 19% SOL • 8% BTC • Instant Breakdown",
            "tag": "ANALYTICS",
            "tag_color": (14, 165, 233),
        }
    },
    {
        "id": "7_news",
        "raw": "7_news.png",
        "title": "BREAKING\nCRYPTO NEWS",
        "subtitle": "Curated headlines from CoinDesk & CoinTelegraph",
        "ribbon_color": (59, 130, 246),      # Electric Blue
        "accent_shape": (249, 115, 22),      # Orange
        "floating_card": {
            "title": "24/7 MARKET PULSE",
            "subtitle": "Breaking headlines & sentiment alerts in real time",
            "tag": "ALERTS",
            "tag_color": (59, 130, 246),
        }
    },
    {
        "id": "8_blitz",
        "raw": "9_blitz.png",
        "title": "1V1 BLITZ\nDUEL ARENA",
        "subtitle": "Compete in live 3-minute PvP trading battles",
        "ribbon_color": (139, 92, 246),      # Purple
        "accent_shape": (16, 185, 129),      # Neon Green
        "floating_card": {
            "title": "PVP TRADING BATTLE",
            "subtitle": "3-Minute Fast Matches • Climb Global ELO Ranks",
            "tag": "DUEL",
            "tag_color": (139, 92, 246),
        }
    },
    {
        "id": "9_ai_signals",
        "raw": "AI_analysis.png",
        "title": "AI-POWERED\nTRADE SIGNALS",
        "subtitle": "Algorithmic entry zones & smart profit targets",
        "ribbon_color": (236, 72, 153),      # Cyber Pink / Fuchsia
        "accent_shape": (99, 102, 241),      # Indigo
        "floating_card": {
            "title": "PRO UNLOCKED SIGNALS",
            "subtitle": "Take Profit / Lighten alerts with confidence metrics",
            "tag": "AI",
            "tag_color": (236, 72, 153),
        }
    },
    {
        "id": "10_rewards",
        "raw": "8_rewards.png",
        "title": "EARN REWARDS\n& CLIMB RANKS",
        "subtitle": "Complete missions, maintain streaks & unlock XP",
        "ribbon_color": (234, 179, 8),       # Gold
        "accent_shape": (249, 115, 22),      # Amber
        "floating_card": {
            "title": "LEVEL 22 STRATEGY CAPTAIN",
            "subtitle": "7-Day Daily Streak • Badges & Trading Missions",
            "tag": "REWARDS",
            "tag_color": (234, 179, 8),
        }
    },
]

def create_delta_background(slide):
    """
    Creates Delta-style dark background with sweeping colorful organic ribbons,
    soft geometric rounded shapes, and atmospheric vignetting.
    """
    base = Image.new("RGBA", (CANVAS_W, CANVAS_H), (7, 9, 18, 255))
    draw = ImageDraw.Draw(base)

    # 1. Subtle deep gradient
    top_c = (14, 18, 32)
    bot_c = (5, 7, 14)
    for y in range(CANVAS_H):
        t = y / CANVAS_H
        r = int(top_c[0] * (1 - t) + bot_c[0] * t)
        g = int(top_c[1] * (1 - t) + bot_c[1] * t)
        b = int(top_c[2] * (1 - t) + bot_c[2] * t)
        draw.line([(0, y), (CANVAS_W, y)], fill=(r, g, b, 255))

    ribbon_rgb = slide["ribbon_color"]
    accent_rgb = slide["accent_shape"]

    # 2. Delta Sweeping Curved Ribbon (Top right to top left wave)
    ribbon_layer = Image.new("RGBA", (CANVAS_W, CANVAS_H), (0, 0, 0, 0))
    r_draw = ImageDraw.Draw(ribbon_layer)

    # Upper curved wave band
    r_draw.polygon(
        [
            (CANVAS_W - 380, 0),
            (CANVAS_W + 100, 0),
            (CANVAS_W + 100, 280),
            (CANVAS_W - 120, 220),
            (CANVAS_W - 420, 90),
        ],
        fill=(ribbon_rgb[0], ribbon_rgb[1], ribbon_rgb[2], 230)
    )
    # Smooth curved ellipse over the polygon
    r_draw.ellipse(
        [CANVAS_W - 460, -100, CANVAS_W + 200, 320],
        fill=(ribbon_rgb[0], ribbon_rgb[1], ribbon_rgb[2], 240)
    )

    # 3. Delta Accent Geometric Pebble / Rounded Shape (mid left or lower background)
    r_draw.ellipse(
        [-80, 520, 180, 780],
        fill=(accent_rgb[0], accent_rgb[1], accent_rgb[2], 210)
    )
    # Small floating pill accent
    r_draw.rounded_rectangle(
        [CANVAS_W - 140, 680, CANVAS_W + 40, 840],
        radius=40,
        fill=(ribbon_rgb[0], ribbon_rgb[1], ribbon_rgb[2], 180)
    )

    # Blur shapes slightly for that smooth vector graphic look
    ribbon_layer = ribbon_layer.filter(ImageFilter.GaussianBlur(radius=8))
    base.alpha_composite(ribbon_layer)

    # 4. Deep ambient lighting behind device
    glow_layer = Image.new("RGBA", (CANVAS_W, CANVAS_H), (0, 0, 0, 0))
    g_draw = ImageDraw.Draw(glow_layer)
    cx, cy = CANVAS_W // 2, 950
    for i in range(35, 0, -1):
        radius = int(520 * (i / 35))
        alpha = int(45 * (1.0 - (i / 35)) ** 1.8)
        color = (ribbon_rgb[0], ribbon_rgb[1], ribbon_rgb[2], alpha)
        g_draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=color)

    glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(radius=75))
    base.alpha_composite(glow_layer)

    return base

def render_delta_header(image, slide):
    """Draws Delta-style high-impact uppercase headline and modern subtitle."""
    draw = ImageDraw.Draw(image)
    title_text = slide["title"]
    subtitle_text = slide["subtitle"]

    # 1. Headline (Left aligned or centered - Delta is centered, high impact)
    title_lines = title_text.split("\n")
    y_cursor = 100
    line_spacing = 74

    for line in title_lines:
        bbox = font_headline.getbbox(line)
        w = bbox[2] - bbox[0]
        x = (CANVAS_W - w) // 2
        # Drop shadow for text
        draw.text((x + 2, y_cursor + 3), line, font=font_headline, fill=(0, 0, 0, 180))
        draw.text((x, y_cursor), line, font=font_headline, fill=(255, 255, 255, 255))
        y_cursor += line_spacing

    # 2. Subtitle
    y_cursor += 16
    s_bbox = font_subtitle.getbbox(subtitle_text)
    sw = s_bbox[2] - s_bbox[0]
    sx = (CANVAS_W - sw) // 2
    draw.text((sx + 1, y_cursor + 2), subtitle_text, font=font_subtitle, fill=(0, 0, 0, 160))
    draw.text((sx, y_cursor), subtitle_text, font=font_subtitle, fill=(203, 213, 225, 255))

def round_corners(im, radius):
    """Antialiased rounded corners for screen image."""
    mask = Image.new("L", im.size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([(0, 0), im.size], radius=radius, fill=255)
    result = im.copy()
    result.putalpha(mask)
    return result

def overlay_pristine_status_bar(screen_img, width):
    """Modern flagship status bar matching Delta's look."""
    draw = ImageDraw.Draw(screen_img)
    bar_h = 76
    draw.rectangle([(0, 0), (width, bar_h)], fill=(0, 0, 0, 255))
    draw.text((36, 22), "09:41", font=font_clock, fill=(255, 255, 255, 255))

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

def render_device(image, raw_filename, phone_y=420, screen_w=820):
    """Renders the framed phone mockup onto the canvas."""
    raw_path = os.path.join(RAW_DIR, raw_filename)
    if not os.path.exists(raw_path):
        return

    raw_img = Image.open(raw_path).convert("RGBA")
    aspect = raw_img.height / raw_img.width
    screen_h = int(screen_w * aspect)

    resized_screen = raw_img.resize((screen_w, screen_h), Image.Resampling.LANCZOS)
    overlay_pristine_status_bar(resized_screen, screen_w)
    rounded_screen = round_corners(resized_screen, radius=48)

    bezel = 14
    chassis_w = screen_w + bezel * 2
    chassis_h = screen_h + bezel * 2
    chassis_radius = 60

    phone_x = (CANVAS_W - chassis_w) // 2

    # Deep drop shadow
    shadow_layer = Image.new("RGBA", (CANVAS_W, CANVAS_H), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(shadow_layer)
    s_draw.rounded_rectangle(
        [phone_x - 12, phone_y + 18, phone_x + chassis_w + 12, phone_y + chassis_h + 36],
        radius=chassis_radius + 6,
        fill=(0, 0, 0, 180)
    )
    shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(radius=45))
    image.alpha_composite(shadow_layer)

    # Chassis
    chassis_layer = Image.new("RGBA", (chassis_w, chassis_h), (0, 0, 0, 0))
    c_draw = ImageDraw.Draw(chassis_layer)
    c_draw.rounded_rectangle([(0, 0), (chassis_w, chassis_h)], radius=chassis_radius, fill=(18, 23, 35, 255), outline=(55, 68, 96, 255), width=3)
    c_draw.rounded_rectangle([(3, 3), (chassis_w - 3, chassis_h - 3)], radius=chassis_radius - 2, outline=(28, 38, 54, 255), width=2)
    chassis_layer.alpha_composite(rounded_screen, (bezel, bezel))

    # Punch hole camera
    camera_w = 26
    camera_h = 26
    cam_x = chassis_w // 2 - camera_w // 2
    cam_y = bezel + 12
    c_draw.ellipse([cam_x, cam_y, cam_x + camera_w, cam_y + camera_h], fill=(6, 8, 12, 255), outline=(32, 40, 56, 255), width=1)
    c_draw.ellipse([cam_x + 6, cam_y + 6, cam_x + 10, cam_y + 10], fill=(36, 54, 90, 220))

    # Sheen
    sheen = Image.new("RGBA", (chassis_w, chassis_h), (0, 0, 0, 0))
    sh_draw = ImageDraw.Draw(sheen)
    sh_draw.polygon([(chassis_w - 220, bezel), (chassis_w - bezel, bezel), (chassis_w - bezel, 420), (chassis_w - 320, bezel)], fill=(255, 255, 255, 12))
    chassis_layer.alpha_composite(sheen)

    image.alpha_composite(chassis_layer, (phone_x, phone_y))

def render_floating_card(image, card_info):
    """
    Renders Delta's signature floating insight notification card
    overlaying the bottom portion of the smartphone mockup.
    """
    if not card_info:
        return

    card_w = 880
    card_h = 135
    card_x = (CANVAS_W - card_w) // 2
    card_y = CANVAS_H - 225

    # Card shadow
    card_shadow = Image.new("RGBA", (CANVAS_W, CANVAS_H), (0, 0, 0, 0))
    cs_draw = ImageDraw.Draw(card_shadow)
    cs_draw.rounded_rectangle(
        [card_x - 4, card_y + 10, card_x + card_w + 4, card_y + card_h + 20],
        radius=28,
        fill=(0, 0, 0, 220)
    )
    card_shadow = card_shadow.filter(ImageFilter.GaussianBlur(radius=24))
    image.alpha_composite(card_shadow)

    # Elevated Glassmorphic Card Container
    card_layer = Image.new("RGBA", (CANVAS_W, CANVAS_H), (0, 0, 0, 0))
    c_draw = ImageDraw.Draw(card_layer)
    c_draw.rounded_rectangle(
        [card_x, card_y, card_x + card_w, card_y + card_h],
        radius=26,
        fill=(22, 27, 42, 245),
        outline=(60, 75, 105, 220),
        width=2
    )

    # Left Badge Pill
    tag_text = card_info["tag"]
    tag_color = card_info["tag_color"]
    tag_bbox = font_badge.getbbox(tag_text)
    tw = tag_bbox[2] - tag_bbox[0]
    th = tag_bbox[3] - tag_bbox[1]
    
    badge_pad_x = 16
    badge_pad_y = 6
    bw = tw + badge_pad_x * 2
    bh = th + badge_pad_y * 2
    bx = card_x + 30
    by = card_y + (card_h - bh) // 2

    c_draw.rounded_rectangle(
        [bx, by, bx + bw, by + bh],
        radius=8,
        fill=(tag_color[0], tag_color[1], tag_color[2], 40),
        outline=(tag_color[0], tag_color[1], tag_color[2], 200),
        width=2
    )
    c_draw.text((bx + badge_pad_x, by + badge_pad_y - 1), tag_text, font=font_badge, fill=tag_color)

    # Title & Subtitle text inside card
    tx = bx + bw + 24
    ty1 = card_y + 32
    ty2 = card_y + 72

    c_draw.text((tx, ty1), card_info["title"], font=font_card_title, fill=(255, 255, 255, 255))
    c_draw.text((tx, ty2), card_info["subtitle"], font=font_card_body, fill=(148, 163, 184, 255))

    image.alpha_composite(card_layer)

def generate_all():
    print(f"\n🎨 Generating Delta-Inspired Google Play Store Screenshots ({CANVAS_W}x{CANVAS_H})...")
    
    for i, slide in enumerate(SLIDES, start=1):
        print(f"[{i}/{len(SLIDES)}] Rendering {slide['id']} ({slide['raw']})...")
        canvas = create_delta_background(slide)
        render_delta_header(canvas, slide)
        render_device(canvas, slide["raw"], phone_y=395, screen_w=820)
        render_floating_card(canvas, slide.get("floating_card"))

        out_name = f"{i}_{slide['id']}.png"
        out_path = os.path.join(OUTPUT_DIR, out_name)
        rgb_canvas = canvas.convert("RGB")
        rgb_canvas.save(out_path, "PNG", optimize=True)
        size_kb = os.path.getsize(out_path) / 1024
        print(f"  -> Saved {out_path} ({size_kb:.1f} KB)")

    print(f"\n✅ All {len(SLIDES)} Delta-style store screenshots generated in {OUTPUT_DIR}/")

if __name__ == "__main__":
    generate_all()
