#!/usr/bin/env python3
"""Generate Biloop Talk Android launcher icons from the real logomark.

Outputs into branding/android/:
  drawable/ic_launcher_background.xml       (solid white vector)
  drawable-<dpi>/ic_launcher_foreground.png (Biloop loop, transparent bg)
  mipmap-<dpi>/ic_launcher.png              (white square + loop)
  mipmap-<dpi>/ic_launcher_round.png        (white circle + loop)
"""
import os
from biloop_icons import BRANDING, load_logomark, square_icon, round_icon, foreground_icon

OUT = os.path.join(BRANDING, "android")

LEGACY = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
FG = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}


def save(img, *parts):
    path = os.path.join(OUT, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print("wrote", os.path.relpath(path, os.path.join(OUT, "..", "..")))


def main():
    mark = load_logomark()
    for dpi, px in LEGACY.items():
        save(square_icon(px, mark), f"mipmap-{dpi}", "ic_launcher.png")
        save(round_icon(px, mark), f"mipmap-{dpi}", "ic_launcher_round.png")
    for dpi, px in FG.items():
        save(foreground_icon(px, mark), f"drawable-{dpi}", "ic_launcher_foreground.png")

    bg_dir = os.path.join(OUT, "drawable")
    os.makedirs(bg_dir, exist_ok=True)
    with open(os.path.join(bg_dir, "ic_launcher_background.xml"), "w") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
            '    android:width="108dp" android:height="108dp"\n'
            '    android:viewportWidth="108" android:viewportHeight="108">\n'
            '    <path android:fillColor="#FFFFFF" android:pathData="M0,0h108v108h-108z"/>\n'
            '</vector>\n'
        )
    print("wrote branding/android/drawable/ic_launcher_background.xml")


if __name__ == "__main__":
    main()
