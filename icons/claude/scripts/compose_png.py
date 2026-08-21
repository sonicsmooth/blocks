#!/usr/bin/env python3
"""Composite final PNGs: PIL-drawn gradient badge (smooth, no banding) +
IM-rasterized glyph (solid white shapes, no gradients -> renders cleanly).

Style: squared-off corners, no gloss/shine, a small offset drop shadow and
thin top/bottom bevel lines for subtle 3D relief -- matching gen_icons.py's
SVG output (rounded rect rx=7, feDropShadow dy=1.1 stdDeviation=0.8)."""
import json, os, subprocess
from PIL import Image, ImageDraw, ImageFilter

ICONS_DIR = os.path.join("..", "icons")
GLYPH_DIR = os.path.join(ICONS_DIR, "_glyph_only")
PNG_DIR = os.path.join(ICONS_DIR, "png")
os.makedirs(PNG_DIR, exist_ok=True)

SS = 4                    # supersample factor for antialiasing
SIZE = 128 * SS
SCALE = SIZE / 64         # px per SVG unit (matches gen_icons.py's 64x64 viewBox)
R = SCALE * 7             # squared-off corner radius
PAD = SCALE * 2
SHADOW_DY = SCALE * 1.1
SHADOW_BLUR = SCALE * 0.8
SHADOW_OPACITY = int(0.38 * 255)


def hex2rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))


def make_gradient(size, c0, c1):
    """Diagonal (top-left -> bottom-right) linear gradient, RGBA."""
    c0, c1 = hex2rgb(c0), hex2rgb(c1)
    base = Image.new('RGB', (size, size))
    px = base.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            r = int(c0[0] + (c1[0] - c0[0]) * t)
            g = int(c0[1] + (c1[1] - c0[1]) * t)
            b = int(c0[2] + (c1[2] - c0[2]) * t)
            px[x, y] = (r, g, b)
    return base.convert('RGBA')


def rounded_mask(size, x0, y0, x1, y1, radius):
    m = Image.new('L', (size, size), 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([x0, y0, x1, y1], radius=radius, fill=255)
    return m


with open(os.path.join(ICONS_DIR, "_manifest.json")) as f:
    manifest = json.load(f)

badge_x0, badge_y0 = PAD, PAD
badge_x1, badge_y1 = SIZE - 1 - PAD, SIZE - 1 - PAD

for name, spec in manifest.items():
    c0, c1 = spec["grad"]

    # 1) rasterize the glyph-only svg at supersampled size via ImageMagick
    glyph_svg = os.path.join(GLYPH_DIR, f"{name}.svg")
    glyph_png = os.path.join(GLYPH_DIR, f"{name}_raster.png")
    subprocess.run([
        "convert", "-background", "none", "-density", "768",
        glyph_svg, "-resize", f"{SIZE}x{SIZE}", glyph_png
    ], check=True)
    glyph = Image.open(glyph_png).convert('RGBA')
    if glyph.size != (SIZE, SIZE):
        canvas = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
        ox, oy = (SIZE - glyph.width) // 2, (SIZE - glyph.height) // 2
        canvas.paste(glyph, (ox, oy), glyph)
        glyph = canvas

    badge_mask = rounded_mask(SIZE, badge_x0, badge_y0, badge_x1, badge_y1, R)

    # 2) small offset drop shadow for a bit of relief off the page
    shadow_alpha = Image.new('L', (SIZE, SIZE), 0)
    shadow_alpha.paste(badge_mask, (0, int(round(SHADOW_DY))))
    shadow_alpha = shadow_alpha.filter(ImageFilter.GaussianBlur(SHADOW_BLUR))
    shadow_layer = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    shadow_layer.putalpha(shadow_alpha.point(lambda a: int(a * SHADOW_OPACITY / 255)))
    final = Image.alpha_composite(Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0)), shadow_layer)

    # 3) gradient badge, masked to the (now squarer) rounded rect
    grad = make_gradient(SIZE, c0, c1)
    badge = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    badge.paste(grad, (0, 0), badge_mask)
    final = Image.alpha_composite(final, badge)

    # 4) thin top highlight / bottom shadow bevel lines (relief, not shine)
    bevel = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bevel)
    bx0, bx1 = badge_x0 + R, badge_x1 - R
    lw = max(1, int(round(SCALE * 1.4)))
    bd.line([(bx0, badge_y0 + SCALE * 1.3), (bx1, badge_y0 + SCALE * 1.3)],
            fill=(255, 255, 255, 56), width=lw)
    bd.line([(bx0, badge_y1 - SCALE * 1.3), (bx1, badge_y1 - SCALE * 1.3)],
            fill=(0, 0, 0, 46), width=lw)
    final = Image.alpha_composite(final, bevel)

    # 5) subtle outer border
    border = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    bd2 = ImageDraw.Draw(border)
    bd2.rounded_rectangle([badge_x0, badge_y0, badge_x1, badge_y1], radius=R,
                           outline=(0, 0, 0, 30), width=max(1, SIZE // 220))
    final = Image.alpha_composite(final, border)

    # 6) composite glyph on top
    final = Image.alpha_composite(final, glyph)

    # 7) downsample for smooth antialiasing
    final_128 = final.resize((128, 128), Image.LANCZOS)
    final_128.save(os.path.join(PNG_DIR, f"{name}.png"))
    final.resize((256, 256), Image.LANCZOS).save(os.path.join(PNG_DIR, f"{name}@2x.png"))
    # Save the full supersampled image as the ICO source (512px, pre-downsample).
    # Going 512→16/32/48 in one LANCZOS step is far sharper than resampling
    # from the 256px @2x PNG a second time.
    final.save(os.path.join(PNG_DIR, f"{name}_src512.png"))

print("Composited", len(manifest), "PNGs into", PNG_DIR)
