"""
Generates modern Windows 11 Fluent Cyber Shield icon suite for ProksiFi v2.0
Multi-resolution ICOs (16, 20, 24, 32, 48, 64, 128, 256) with pixel-perfect clarity.
"""

from PIL import Image, ImageDraw

def draw_fluent_shield(size=16, state="active"):
    scale = 16
    S = size * scale
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    cx = S / 2.0
    cy = S / 2.0

    margin_x = S * 0.125
    margin_top = S * 0.08
    margin_bot = S * 0.92
    h = margin_bot - margin_top
    w = S - 2 * margin_x

    # Symmetrical Fluent Shield Coordinates
    left_pts = [
        (cx, margin_top),
        (margin_x + w * 0.15, margin_top + h * 0.02),
        (margin_x, margin_top + h * 0.12),
        (margin_x, margin_top + h * 0.52),
        (cx, margin_bot)
    ]
    right_pts = [
        (cx, margin_top),
        (S - margin_x - w * 0.15, margin_top + h * 0.02),
        (S - margin_x, margin_top + h * 0.12),
        (S - margin_x, margin_top + h * 0.52),
        (cx, margin_bot)
    ]
    full_shield = [
        (cx, margin_top),
        (margin_x + w * 0.15, margin_top + h * 0.02),
        (margin_x, margin_top + h * 0.12),
        (margin_x, margin_top + h * 0.52),
        (cx, margin_bot),
        (S - margin_x, margin_top + h * 0.52),
        (S - margin_x, margin_top + h * 0.12),
        (S - margin_x - w * 0.15, margin_top + h * 0.02),
    ]

    if state == "active":
        c_left = (0, 230, 118, 255)   # #00E676 Electric Emerald
        c_right = (0, 180, 80, 255)   # #00B450 Deep Emerald
        c_border = (0, 120, 50, 255)
    elif state == "stopped":
        c_left = (148, 163, 184, 255) # #94A3B8 Slate Silver
        c_right = (100, 116, 139, 255)# #64748B Deep Slate
        c_border = (51, 65, 85, 255)
    else: # checking
        c_left = (251, 191, 36, 255)  # #FBBF24 Amber Gold
        c_right = (217, 119, 6, 255)  # #D97706 Deep Amber
        c_border = (180, 83, 9, 255)

    # 1. Base shield with duotone lighting
    d.polygon(left_pts, fill=c_left)
    d.polygon(right_pts, fill=c_right)
    d.polygon(full_shield, outline=c_border, width=int(1.2 * scale))

    # 2. Central Symbol
    if state == "active":
        # Lightning Bolt (pure crisp white, symbolizing bypass speed & live connection)
        bolt = [
            (cx + S * 0.04, margin_top + h * 0.16),
            (cx - S * 0.18, margin_top + h * 0.46),
            (cx - S * 0.01, margin_top + h * 0.46),
            (cx - S * 0.06, margin_top + h * 0.78),
            (cx + S * 0.18, margin_top + h * 0.42),
            (cx + S * 0.02, margin_top + h * 0.42),
        ]
        d.polygon(bolt, fill=(255, 255, 255, 255))
    elif state == "stopped":
        # Modern Pause Bars (symbolizing bypass paused / standby)
        bw = S * 0.08
        bh = S * 0.32
        d.rounded_rectangle([cx - S*0.14, cy - bh/2, cx - S*0.14 + bw, cy + bh/2], radius=int(0.5*scale), fill=(255, 255, 255, 255))
        d.rounded_rectangle([cx + S*0.06, cy - bh/2, cx + S*0.06 + bw, cy + bh/2], radius=int(0.5*scale), fill=(255, 255, 255, 255))
    else:
        # Checking: Pulse dot
        d.ellipse([cx - S*0.11, cy - S*0.11, cx + S*0.11, cy + S*0.11], fill=(255, 255, 255, 255))

    return img.resize((size, size), Image.Resampling.LANCZOS)

def create_ico(filename, state):
    sizes = [16, 20, 24, 32, 48, 64, 128, 256]
    images = [draw_fluent_shield(size=s, state=state) for s in sizes]
    images[0].save(
        filename,
        format="ICO",
        sizes=[(s, s) for s in sizes],
        append_images=images[1:]
    )
    print(f"Generated {filename} ({len(sizes)} resolutions)")

def main():
    print("Generating ProksiFi v2.0 pixel-perfect Fluent Shield icons...")
    create_ico(r"c:\Users\JURAPC.DESKTOP-ADFG5MI\Desktop\NEW PROKSI\src\icon_active.ico", "active")
    create_ico(r"c:\Users\JURAPC.DESKTOP-ADFG5MI\Desktop\NEW PROKSI\src\icon_stopped.ico", "stopped")
    create_ico(r"c:\Users\JURAPC.DESKTOP-ADFG5MI\Desktop\NEW PROKSI\src\icon_checking.ico", "checking")

    # Master app.ico for Explorer executable icon
    import shutil
    shutil.copyfile(
        r"c:\Users\JURAPC.DESKTOP-ADFG5MI\Desktop\NEW PROKSI\src\icon_active.ico",
        r"c:\Users\JURAPC.DESKTOP-ADFG5MI\Desktop\NEW PROKSI\src\app.ico"
    )
    print("Master app.ico generated!")

if __name__ == "__main__":
    main()
