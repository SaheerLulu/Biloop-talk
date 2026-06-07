#!/usr/bin/env python3
"""Generate the macOS DMG installer background for Biloop Talk.

A purple gradient with the white "Biloop" wordmark near the top, leaving the
centre clear for the app icon + Applications alias. Output:
  branding/dmg-background.png  (1320x800 master; resized to match upstream at build)
"""
import os
from PIL import Image
from biloop_icons import BRANDING

W, H = 1320, 800
TOP = (61, 16, 99)      # #3D1063
MID = (80, 44, 111)     # #502C6F
BOT = (132, 69, 238)    # #8445EE


def vgradient(w, h):
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        t = y / (h - 1)
        if t < 0.5:
            a, b, tt = TOP, MID, t / 0.5
        else:
            a, b, tt = MID, BOT, (t - 0.5) / 0.5
        row = tuple(int(a[i] + (b[i] - a[i]) * tt) for i in range(3))
        for x in range(w):
            px[x, y] = row
    return img


def main():
    bg = vgradient(W, H).convert("RGBA")
    wordmark = Image.open(os.path.join(BRANDING, "source", "wordmark-white.png")).convert("RGBA")
    bbox = wordmark.split()[3].getbbox()
    if bbox:
        wordmark = wordmark.crop(bbox)
    target_w = int(W * 0.42)
    scale = target_w / wordmark.width
    wm = wordmark.resize((target_w, max(1, int(wordmark.height * scale))), Image.LANCZOS)
    bg.alpha_composite(wm, ((W - wm.width) // 2, int(H * 0.12)))
    out = os.path.join(BRANDING, "dmg-background.png")
    bg.convert("RGB").save(out)
    print("wrote branding/dmg-background.png", (W, H))


if __name__ == "__main__":
    main()
