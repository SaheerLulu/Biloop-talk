#!/usr/bin/env python3
"""Generate the iOS app-icon master from the Biloop logomark.

iOS app icons must be a flat, fully opaque, square image with no alpha and no
rounded corners (iOS applies the mask). Output: branding/ios/AppIcon.png (1024).
"""
import os
from PIL import Image
from biloop_icons import BRANDING, load_logomark, square_icon

OUT = os.path.join(BRANDING, "ios")


def main():
    os.makedirs(OUT, exist_ok=True)
    # White square (not rounded), logomark centered, flattened to RGB (no alpha).
    icon = square_icon(1024, load_logomark(), rounded=False, mark_frac=0.82)
    flat = Image.new("RGB", icon.size, (255, 255, 255))
    flat.paste(icon, (0, 0), icon)
    flat.save(os.path.join(OUT, "AppIcon.png"))
    print("wrote branding/ios/AppIcon.png 1024x1024 (flat, opaque)")


if __name__ == "__main__":
    main()
