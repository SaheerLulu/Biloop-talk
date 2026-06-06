"""Shared helpers to build Biloop app icons from the real logomark.

The brand logomark (branding/source/logomark.png) is a wide infinity "loop" in
the Biloop purple gradient on a transparent background. App icons place it,
centered, on a white rounded background.
"""
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(__file__)
BRANDING = os.path.join(HERE, "..", "branding")
LOGOMARK = os.path.join(BRANDING, "source", "logomark.png")

# Brand palette (sampled from the official logos)
BRAND_PRIMARY = "#502C6F"      # "Biloop" wordmark purple
BRAND_GRADIENT_DARK = "#3D1063"
BRAND_GRADIENT_LIGHT = "#8445EE"
WHITE = (255, 255, 255, 255)

SS = 4  # supersample factor for crisp downscaling


def load_logomark():
    """Return just the purple "loop" symbol from the logo.

    The source asset is the full "Biloop" wordmark with white letters and the
    loop in the purple gradient, so we crop to the coloured (purple) pixels to
    isolate the loop mark for use as an app icon.
    """
    im = Image.open(LOGOMARK).convert("RGBA")
    px = im.load()
    w, h = im.size
    mask = Image.new("L", (w, h), 0)
    mp = mask.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a > 60 and b > 90 and (b - r) > 25:  # purple-ish, opaque
                mp[x, y] = 255
    bbox = mask.getbbox()
    return im.crop(bbox) if bbox else im


def _fit(mark, max_w, max_h):
    w, h = mark.size
    scale = min(max_w / w, max_h / h)
    return mark.resize((max(1, int(w * scale)), max(1, int(h * scale))), Image.LANCZOS)


def _paste_center(canvas, mark):
    x = (canvas.width - mark.width) // 2
    y = (canvas.height - mark.height) // 2
    canvas.alpha_composite(mark, (x, y))


def square_icon(size, mark=None, rounded=True, bg=WHITE, mark_frac=0.86):
    """White (rounded) square with the logomark centered."""
    mark = mark or load_logomark()
    S = size * SS
    canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    bg_img = Image.new("RGBA", (S, S), bg)
    if rounded:
        m = Image.new("L", (S, S), 0)
        ImageDraw.Draw(m).rounded_rectangle([0, 0, S - 1, S - 1], radius=int(S * 0.22), fill=255)
        canvas.paste(bg_img, (0, 0), m)
    else:
        canvas = bg_img
    fitted = _fit(mark, int(S * mark_frac), int(S * mark_frac))
    _paste_center(canvas, fitted)
    return canvas.resize((size, size), Image.LANCZOS)


def round_icon(size, mark=None, bg=WHITE, mark_frac=0.80):
    """White circle with the logomark centered."""
    mark = mark or load_logomark()
    S = size * SS
    canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    bg_img = Image.new("RGBA", (S, S), bg)
    m = Image.new("L", (S, S), 0)
    ImageDraw.Draw(m).ellipse([0, 0, S - 1, S - 1], fill=255)
    canvas.paste(bg_img, (0, 0), m)
    fitted = _fit(mark, int(S * mark_frac), int(S * mark_frac))
    _paste_center(canvas, fitted)
    return canvas.resize((size, size), Image.LANCZOS)


def foreground_icon(size, mark=None, mark_frac=0.62):
    """Logomark centered on transparent, for Android adaptive foreground.

    mark_frac is kept small so the wide loop stays inside the ~66dp safe zone.
    """
    mark = mark or load_logomark()
    S = size * SS
    canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    fitted = _fit(mark, int(S * mark_frac), int(S * mark_frac))
    _paste_center(canvas, fitted)
    return canvas.resize((size, size), Image.LANCZOS)
