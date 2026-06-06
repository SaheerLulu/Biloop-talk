#!/usr/bin/env python3
"""Generate the desktop (Electron) Biloop icon set from the real logomark.

Outputs into branding/:
  icon.png   1024x1024 master (white rounded square + Biloop loop)
  icon.ico   multi-size Windows icon
  icon-<n>.png convenience sizes
"""
import os
from biloop_icons import BRANDING, load_logomark, square_icon

OUT = BRANDING


def main():
    mark = load_logomark()
    master = square_icon(1024, mark)
    master.save(os.path.join(OUT, "icon.png"))
    print("wrote branding/icon.png 1024x1024")

    ico_sizes = [16, 24, 32, 48, 64, 128, 256]
    master.save(os.path.join(OUT, "icon.ico"), sizes=[(s, s) for s in ico_sizes])
    print("wrote branding/icon.ico", ico_sizes)

    for s in (512, 256, 128, 64):
        square_icon(s, mark).save(os.path.join(OUT, f"icon-{s}.png"))
    print("wrote branding/icon-{512,256,128,64}.png")


if __name__ == "__main__":
    main()
