#!/usr/bin/env python3
"""Generate Biloop Talk Android launcher icons into branding/android/.

Outputs:
  branding/android/drawable/ic_launcher_background.xml      (solid purple vector)
  branding/android/drawable-<dpi>/ic_launcher_foreground.png (white "B", transparent)
  branding/android/mipmap-<dpi>/ic_launcher.png             (full square icon)
  branding/android/mipmap-<dpi>/ic_launcher_round.png       (full round icon)
"""
import os
from PIL import Image, ImageDraw, ImageFont

PURPLE = (108, 43, 217, 255)    # #6C2BD9
PURPLE_DK = (78, 28, 160, 255)
WHITE = (255, 255, 255, 255)

OUT = os.path.join(os.path.dirname(__file__), "..", "branding", "android")

# Android density buckets
LEGACY = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
# Adaptive foreground canvas is 108dp
FG = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}

SS = 4  # supersample


def load_font(px):
    for path in [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    ]:
        try:
            return ImageFont.truetype(path, px)
        except Exception:
            pass
    return ImageFont.load_default()


def vgradient(size, top, bottom):
    img = Image.new("RGBA", (size, size), top)
    px = img.load()
    for y in range(size):
        t = y / (size - 1)
        px_row = (
            int(top[0] + (bottom[0] - top[0]) * t),
            int(top[1] + (bottom[1] - top[1]) * t),
            int(top[2] + (bottom[2] - top[2]) * t),
            255,
        )
        for x in range(size):
            px[x, y] = px_row
    return img


def draw_B(draw, S, color, frac=0.62, dy=0.0):
    font = load_font(int(S * frac))
    bbox = draw.textbbox((0, 0), "B", font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    tx = (S - tw) / 2 - bbox[0]
    ty = (S - th) / 2 - bbox[1] + dy * S
    draw.text((tx, ty), "B", font=font, fill=color)


def make_square(size):
    S = size * SS
    radius = int(S * 0.22)
    bg = vgradient(S, PURPLE, PURPLE_DK)
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=radius, fill=255)
    icon = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    icon.paste(bg, (0, 0), mask)
    draw_B(ImageDraw.Draw(icon), S, WHITE, frac=0.6)
    return icon.resize((size, size), Image.LANCZOS)


def make_round(size):
    S = size * SS
    bg = vgradient(S, PURPLE, PURPLE_DK)
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, S - 1, S - 1], fill=255)
    icon = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    icon.paste(bg, (0, 0), mask)
    draw_B(ImageDraw.Draw(icon), S, WHITE, frac=0.55)
    return icon.resize((size, size), Image.LANCZOS)


def make_foreground(size):
    # White "B" centered within the adaptive safe zone (~66/108), transparent bg.
    S = size * SS
    icon = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    # 0.40 keeps the glyph inside the 66dp safe circle of the 108dp canvas.
    draw_B(ImageDraw.Draw(icon), S, WHITE, frac=0.40)
    return icon.resize((size, size), Image.LANCZOS)


def save(img, *parts):
    path = os.path.join(OUT, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print("wrote", os.path.relpath(path, os.path.join(OUT, "..", "..")))


def main():
    for dpi, px in LEGACY.items():
        save(make_square(px), f"mipmap-{dpi}", "ic_launcher.png")
        save(make_round(px), f"mipmap-{dpi}", "ic_launcher_round.png")
    for dpi, px in FG.items():
        save(make_foreground(px), f"drawable-{dpi}", "ic_launcher_foreground.png")

    # Solid purple background as a vector drawable.
    bg_dir = os.path.join(OUT, "drawable")
    os.makedirs(bg_dir, exist_ok=True)
    with open(os.path.join(bg_dir, "ic_launcher_background.xml"), "w") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
            '    android:width="108dp" android:height="108dp"\n'
            '    android:viewportWidth="108" android:viewportHeight="108">\n'
            '    <path android:fillColor="#6C2BD9" android:pathData="M0,0h108v108h-108z"/>\n'
            '</vector>\n'
        )
    print("wrote branding/android/drawable/ic_launcher_background.xml")


if __name__ == "__main__":
    main()
