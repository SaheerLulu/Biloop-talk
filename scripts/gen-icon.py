from PIL import Image, ImageDraw, ImageFont
import math

PURPLE = (108, 43, 217, 255)   # #6C2BD9
PURPLE_DK = (78, 28, 160, 255)  # darker for gradient
WHITE = (255, 255, 255, 255)

def rounded_mask(size, radius):
    m = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([0, 0, size-1, size-1], radius=radius, fill=255)
    return m

def vgradient(size, top, bottom):
    base = Image.new("RGBA", (size, size), top)
    top_a = [top[0], top[1], top[2]]
    bot_a = [bottom[0], bottom[1], bottom[2]]
    px = base.load()
    for y in range(size):
        t = y / (size - 1)
        r = int(top_a[0] + (bot_a[0]-top_a[0]) * t)
        g = int(top_a[1] + (bot_a[1]-top_a[1]) * t)
        b = int(top_a[2] + (bot_a[2]-top_a[2]) * t)
        for x in range(size):
            px[x, y] = (r, g, b, 255)
    return base

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

def make_icon(size):
    SS = 4  # supersample
    S = size * SS
    radius = int(S * 0.22)
    bg = vgradient(S, PURPLE, PURPLE_DK)
    mask = rounded_mask(S, radius)
    icon = Image.new("RGBA", (S, S), (0,0,0,0))
    icon.paste(bg, (0,0), mask)

    d = ImageDraw.Draw(icon)
    # Letter B
    font = load_font(int(S * 0.62))
    txt = "B"
    bbox = d.textbbox((0,0), txt, font=font)
    tw, th = bbox[2]-bbox[0], bbox[3]-bbox[1]
    tx = (S - tw)/2 - bbox[0]
    ty = (S - th)/2 - bbox[1]
    # subtle shadow
    d.text((tx, ty + S*0.012), txt, font=font, fill=(40, 10, 90, 90))
    d.text((tx, ty), txt, font=font, fill=WHITE)

    # speech-bubble dot accent (Talk cue): small white circle lower-right
    r = int(S * 0.055)
    cx, cy = int(S*0.70), int(S*0.70)
    d.ellipse([cx-r, cy-r, cx+r, cy+r], fill=(255,255,255,235))

    return icon.resize((size, size), Image.LANCZOS)

# Master 1024
master = make_icon(1024)
master.save("branding/icon.png")
print("wrote branding/icon.png 1024x1024")

# Multi-size ICO for Windows
ico_sizes = [16, 24, 32, 48, 64, 128, 256]
master.save("branding/icon.ico", sizes=[(s, s) for s in ico_sizes])
print("wrote branding/icon.ico", ico_sizes)

# A few PNGs for convenience / Linux
for s in (512, 256, 128, 64):
    make_icon(s).save(f"branding/icon-{s}.png")
print("wrote branding/icon-{512,256,128,64}.png")
