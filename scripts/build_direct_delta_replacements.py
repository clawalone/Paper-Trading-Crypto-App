#!/usr/bin/env python3
"""
build_direct_delta_replacements.py
---------------------------------
Directly adapts the official Delta by eToro Google Play store listing templates
by replacing the phone screens with the user's authentic USD crypto paper trading
app screenshots, and adapting headings and subtitles to match the application.
"""

import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

CANVAS_W = 1080
CANVAS_H = 1920

REF_DIR = "store_assets/delta_reference"
RAW_DIR = "store_assets/raw"
OUTPUT_DIR = "store_assets/play_store_delta_direct"
FONT_DIR = "store_assets/fonts"

os.makedirs(OUTPUT_DIR, exist_ok=True)

# Fonts
FONT_BLACK = os.path.join(FONT_DIR, "Montserrat-Black.ttf")
FONT_BOLD = os.path.join(FONT_DIR, "Montserrat-Bold.ttf")
FONT_EXTRA = os.path.join(FONT_DIR, "Montserrat-ExtraBold.ttf")
FONT_SUBTITLE = os.path.join(FONT_DIR, "PlusJakartaSans.ttf")

f_hero_headline = ImageFont.truetype(FONT_BLACK, 94)
f_slide_headline = ImageFont.truetype(FONT_BLACK, 84)
f_slide_headline_sm = ImageFont.truetype(FONT_BLACK, 74)
f_subtitle = ImageFont.truetype(FONT_SUBTITLE, 34)
f_market_headline = ImageFont.truetype(FONT_BLACK, 68)
f_market_sub = ImageFont.truetype(FONT_SUBTITLE, 38)

def get_perspective_coeffs(src_pts, dst_pts):
    """Gaussian elimination to find 8 perspective transform coefficients."""
    matrix = []
    for (x, y), (u, v) in zip(dst_pts, src_pts):
        matrix.append([x, y, 1, 0, 0, 0, -u*x, -u*y, u])
        matrix.append([0, 0, 0, x, y, 1, -v*x, -v*y, v])
    for i in range(8):
        max_row = i
        for k in range(i+1, 8):
            if abs(matrix[k][i]) > abs(matrix[max_row][i]):
                max_row = k
        matrix[i], matrix[max_row] = matrix[max_row], matrix[i]
        pivot = matrix[i][i]
        for j in range(i, 9):
            matrix[i][j] /= pivot
        for k in range(8):
            if k != i:
                factor = matrix[k][i]
                for j in range(i, 9):
                    matrix[k][j] -= factor * matrix[i][j]
    return [matrix[i][8] for i in range(8)]

def draw_straight_screen(base_img, raw_img_name, y_offset=691, radius=48):
    """
    Pastes a raw screen into the centered straight phone chassis of delta_3/4/5/6/7.
    Preserves outer chassis, camera punch hole, and shadows.
    """
    raw_path = os.path.join(RAW_DIR, raw_img_name)
    raw_img = Image.open(raw_path).convert("RGBA")
    
    target_w = 801
    target_h = 1920 - y_offset
    
    raw_w, raw_h = raw_img.size
    scale = target_w / raw_w
    scaled_h = int(raw_h * scale)
    scaled_screen = raw_img.resize((target_w, scaled_h), Image.Resampling.LANCZOS)
    cropped_screen = scaled_screen.crop((0, 0, target_w, target_h))
    
    # Rounded top corners mask
    mask = Image.new("L", (target_w, target_h), 255)
    m_draw = ImageDraw.Draw(mask)
    m_draw.rectangle([0, 0, target_w, radius + 10], fill=0)
    m_draw.rounded_rectangle([0, 0, target_w, target_h], radius=radius, fill=255)
    
    # Paste inside phone frame
    base_img.paste(cropped_screen, (137, y_offset), mask)
    
    # Camera punch hole
    cam_x = 540
    cam_y = y_offset + 63
    cam_r = 13
    d = ImageDraw.Draw(base_img)
    d.ellipse([cam_x - cam_r, cam_y - cam_r, cam_x + cam_r, cam_y + cam_r], fill=(0, 0, 0, 255))
    d.ellipse([cam_x - cam_r + 3, cam_y - cam_r + 3, cam_x + cam_r - 3, cam_y + cam_r - 3], fill=(12, 16, 28, 255))
    d.ellipse([cam_x - 3, cam_y - 3, cam_x + 1, cam_y + 1], fill=(40, 60, 110, 220))

def build_slide_1():
    print("[1/8] Generating Slide 1: YOUR TRADING SUPERPOWER...")
    base = Image.open(f"{REF_DIR}/delta_1.png").convert("RGBA")
    
    # 1. Perspective warp raw 1_home.png onto the tilted phone
    raw_home = Image.open(f"{RAW_DIR}/1_home.png").convert("RGBA")
    dst_pts = [(152, 335), (812, 230), (1036, 1642), (376, 1747)]
    sw, sh = raw_home.size
    src_pts = [(0, 0), (sw, 0), (sw, sh), (0, sh)]
    coeffs = get_perspective_coeffs(src_pts, dst_pts)
    warped = raw_home.transform((CANVAS_W, CANVAS_H), Image.PERSPECTIVE, coeffs, Image.Resampling.BICUBIC)
    
    mask = Image.new("L", (CANVAS_W, CANVAS_H), 0)
    m_draw = ImageDraw.Draw(mask)
    m_draw.polygon(dst_pts, fill=255)
    
    # Composite screen
    base = Image.composite(warped, base, mask)
    
    # 2. Re-render the headline on top of the phone (giving 3D overlapping depth)
    d = ImageDraw.Draw(base)
    # Delta's exact positioning:
    # Line 1: YOUR (x=92, y=135)
    # Line 2: TRADING (x=92, y=240)
    # Line 3: SUPERPOWER (x=92, y=345)
    # We clear the text region by sampling background:
    # Actually the text is on top! In delta_1, the old text was YOUR FINANCIAL SUPERPOWER.
    # To replace FINANCIAL with TRADING cleanly:
    # Clear old text area:
    clean_box = Image.new("RGBA", (CANVAS_W, 460), (0, 0, 0, 0))
    cb_draw = ImageDraw.Draw(clean_box)
    cb_draw.rectangle([0, 0, 720, 460], fill=(11, 0, 33, 255))
    
    # Blend with original top-right purple wave
    base.alpha_composite(clean_box, (0, 0))
    # Redo the screen composite in the non-cleared area:
    base = Image.composite(warped, base, mask)
    
    # Draw new headline in crisp pure white with subtle drop shadow
    d = ImageDraw.Draw(base)
    hx = 92
    lines = ["YOUR", "TRADING", "SUPERPOWER"]
    y_starts = [135, 238, 342]
    
    for line, y in zip(lines, y_starts):
        # Subtle shadow
        d.text((hx, y + 3), line, font=f_hero_headline, fill=(0, 0, 0, 140))
        d.text((hx, y), line, font=f_hero_headline, fill=(255, 255, 255, 255))
    
    out_path = f"{OUTPUT_DIR}/1_hero.png"
    base.convert("RGB").save(out_path, "PNG", optimize=True)
    print(f"  -> Saved {out_path}")

def build_slide_2():
    print("[2/8] Generating Slide 2: CRYPTO SPOT & FUTURES...")
    base = Image.open(f"{REF_DIR}/delta_2.png").convert("RGBA")
    
    # In delta_2, phone is on left tilted, text is on right
    # Screen warp for 3_market.png
    raw_mkt = Image.open(f"{RAW_DIR}/3_market.png").convert("RGBA")
    # Coordinates of phone on left in delta_2:
    dst_pts = [(-200, 335), (460, 230), (684, 1642), (24, 1747)]
    sw, sh = raw_mkt.size
    src_pts = [(0, 0), (sw, 0), (sw, sh), (0, sh)]
    coeffs = get_perspective_coeffs(src_pts, dst_pts)
    warped = raw_mkt.transform((CANVAS_W, CANVAS_H), Image.PERSPECTIVE, coeffs, Image.Resampling.BICUBIC)
    
    mask = Image.new("L", (CANVAS_W, CANVAS_H), 0)
    m_draw = ImageDraw.Draw(mask)
    m_draw.polygon(dst_pts, fill=255)
    base = Image.composite(warped, base, mask)
    
    # Right side text:
    # Clear old text
    d = ImageDraw.Draw(base)
    d.rectangle([580, 520, 1050, 1150], fill=(11, 0, 33, 255))
    
    tx = 610
    d.text((tx, 540), "Track & trade", font=f_market_sub, fill=(203, 213, 225, 255))
    d.text((tx, 610), "CRYPTO", font=f_market_headline, fill=(255, 255, 255, 255))
    d.text((tx, 690), "FUTURES", font=f_market_headline, fill=(255, 255, 255, 255))
    d.text((tx, 770), "SPOT", font=f_market_headline, fill=(255, 255, 255, 255))
    d.text((tx, 850), "& MORE", font=f_market_headline, fill=(255, 255, 255, 255))
    
    out_path = f"{OUTPUT_DIR}/2_markets.png"
    base.convert("RGB").save(out_path, "PNG", optimize=True)
    print(f"  -> Saved {out_path}")

def build_slide_3():
    print("[3/8] Generating Slide 3: POWERFUL ANALYTICS...")
    base = Image.open(f"{REF_DIR}/delta_3.png").convert("RGBA")
    draw_straight_screen(base, "6_portfolio.png")
    out_path = f"{OUTPUT_DIR}/3_analytics.png"
    base.convert("RGB").save(out_path, "PNG", optimize=True)
    print(f"  -> Saved {out_path}")

def build_slide_4():
    print("[4/8] Generating Slide 4: WHAT'S GOING ON? (AI Analysis)...")
    base = Image.open(f"{REF_DIR}/delta_4.png").convert("RGBA")
    
    # Draw straight screen with AI_analysis.png
    draw_straight_screen(base, "AI_analysis.png")
    
    # Edit subtitle to "AI-powered market analysis"
    d = ImageDraw.Draw(base)
    # Clean subtitle area (y=370 to 450)
    bg_color = base.getpixel((50, 50))
    d.rectangle([100, 370, 980, 460], fill=bg_color)
    
    sub = "AI-powered market analysis"
    bbox = f_subtitle.getbbox(sub)
    sw = bbox[2] - bbox[0]
    sx = (CANVAS_W - sw) // 2
    d.text((sx, 385), sub, font=f_subtitle, fill=(241, 245, 249, 255))
    
    out_path = f"{OUTPUT_DIR}/4_ai_analysis.png"
    base.convert("RGB").save(out_path, "PNG", optimize=True)
    print(f"  -> Saved {out_path}")

def build_slide_5():
    print("[5/8] Generating Slide 5: INSTANT UPDATES (Live Charts)...")
    base = Image.open(f"{REF_DIR}/delta_5.png").convert("RGBA")
    
    # Save the floating card from delta_5 before pasting screen!
    # The floating card is at bottom: y=1680 to 1900, x=50 to 1030
    floating_card = base.crop((50, 1680, 1030, 1910))
    
    # Draw screen
    draw_straight_screen(base, "2_chart.png")
    
    # Paste floating card back on top!
    base.paste(floating_card, (50, 1680), floating_card)
    
    # Edit subtitle
    d = ImageDraw.Draw(base)
    bg_color = base.getpixel((50, 50))
    d.rectangle([100, 370, 980, 460], fill=bg_color)
    
    sub = "Live candlestick charts & indicators"
    bbox = f_subtitle.getbbox(sub)
    sw = bbox[2] - bbox[0]
    sx = (CANVAS_W - sw) // 2
    d.text((sx, 385), sub, font=f_subtitle, fill=(241, 245, 249, 255))
    
    out_path = f"{OUTPUT_DIR}/5_charts.png"
    base.convert("RGB").save(out_path, "PNG", optimize=True)
    print(f"  -> Saved {out_path}")

def build_slide_6():
    print("[6/8] Generating Slide 6: 100X FUTURES SIMULATOR...")
    base = Image.open(f"{REF_DIR}/delta_6.png").convert("RGBA")
    
    # Draw screen with 4_leverage.png
    draw_straight_screen(base, "4_leverage.png")
    
    # Edit text: replace "SECURE CONNECTIONS With auto-syncing"
    d = ImageDraw.Draw(base)
    bg_color = (246, 247, 249, 255)
    d.rectangle([100, 370, 980, 620], fill=bg_color)
    
    # Lock icon is at y=320, we draw:
    # "100X FUTURES"
    # "SIMULATOR"
    h1 = "100X FUTURES"
    h2 = "SIMULATOR"
    sub = "Simulate high-leverage trades with zero risk"
    
    w1 = f_slide_headline_sm.getbbox(h1)[2] - f_slide_headline_sm.getbbox(h1)[0]
    w2 = f_slide_headline_sm.getbbox(h2)[2] - f_slide_headline_sm.getbbox(h2)[0]
    w_sub = f_subtitle.getbbox(sub)[2] - f_subtitle.getbbox(sub)[0]
    
    d.text(((CANVAS_W - w1) // 2, 385), h1, font=f_slide_headline_sm, fill=(11, 0, 33, 255))
    d.text(((CANVAS_W - w2) // 2, 465), h2, font=f_slide_headline_sm, fill=(11, 0, 33, 255))
    d.text(((CANVAS_W - w_sub) // 2, 565), sub, font=f_subtitle, fill=(71, 85, 105, 255))
    
    out_path = f"{OUTPUT_DIR}/6_futures.png"
    base.convert("RGB").save(out_path, "PNG", optimize=True)
    print(f"  -> Saved {out_path}")

def build_slide_7():
    print("[7/8] Generating Slide 7: PRO REWARDS & RANKS...")
    base = Image.open(f"{REF_DIR}/delta_7.png").convert("RGBA")
    
    # Save the bottom floating card
    floating_card = base.crop((50, 1600, 1030, 1910))
    
    # Draw screen with 8_rewards.png
    draw_straight_screen(base, "8_rewards.png")
    
    # Paste floating card back
    base.paste(floating_card, (50, 1600), floating_card)
    
    # Edit subtitle
    d = ImageDraw.Draw(base)
    bg_color = base.getpixel((50, 50))
    d.rectangle([100, 380, 980, 480], fill=bg_color)
    
    sub = "Level up your trading game"
    bbox = f_subtitle.getbbox(sub)
    sw = bbox[2] - bbox[0]
    sx = (CANVAS_W - sw) // 2
    d.text((sx, 395), sub, font=f_subtitle, fill=(241, 245, 249, 255))
    
    out_path = f"{OUTPUT_DIR}/7_rewards.png"
    base.convert("RGB").save(out_path, "PNG", optimize=True)
    print(f"  -> Saved {out_path}")

def build_slide_8():
    print("[8/8] Generating Slide 8: 1V1 BLITZ DUEL ARENA...")
    # Use delta_4 base for dark purple theme
    base = Image.open(f"{REF_DIR}/delta_4.png").convert("RGBA")
    
    draw_straight_screen(base, "9_blitz.png")
    
    d = ImageDraw.Draw(base)
    bg_color = base.getpixel((50, 50))
    d.rectangle([100, 180, 980, 480], fill=bg_color)
    
    h1 = "1V1 BLITZ"
    h2 = "ARENA"
    sub = "Real-time PvP crypto trading duels"
    
    w1 = f_slide_headline.getbbox(h1)[2] - f_slide_headline.getbbox(h1)[0]
    w2 = f_slide_headline.getbbox(h2)[2] - f_slide_headline.getbbox(h2)[0]
    w_sub = f_subtitle.getbbox(sub)[2] - f_subtitle.getbbox(sub)[0]
    
    d.text(((CANVAS_W - w1) // 2, 230), h1, font=f_slide_headline, fill=(255, 255, 255, 255))
    d.text(((CANVAS_W - w2) // 2, 315), h2, font=f_slide_headline, fill=(255, 255, 255, 255))
    d.text(((CANVAS_W - w_sub) // 2, 420), sub, font=f_subtitle, fill=(241, 245, 249, 255))
    
    out_path = f"{OUTPUT_DIR}/8_blitz_arena.png"
    base.convert("RGB").save(out_path, "PNG", optimize=True)
    print(f"  -> Saved {out_path}")

if __name__ == "__main__":
    build_slide_1()
    build_slide_2()
    build_slide_3()
    build_slide_4()
    build_slide_5()
    build_slide_6()
    build_slide_7()
    build_slide_8()
    print(f"\n🎉 All 8 direct Delta-adapted screenshots successfully generated in {OUTPUT_DIR}/")
