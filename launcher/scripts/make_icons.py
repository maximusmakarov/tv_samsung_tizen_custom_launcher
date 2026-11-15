#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AiTV icon generator.

Draws every launcher tile icon plus the two package icons (icon_117.png /
icon_512.png) with Pillow. The app ships no trademarked artwork: the tiles are
our own monograms / geometric glyphs on dark tinted tiles.

Usage:  python3 scripts/make_icons.py
Output: AiTV/icons/app/*.png, AiTV/icons/icon_{117,512}.png,
        HomeKey/icons/icon_{117,512}.png, preview/icons-sheet.png
"""

import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AITV = os.path.join(ROOT, "AiTV")
HOMEKEY = os.path.join(ROOT, "HomeKey")

S = 1024                 # supersampled master canvas
TILE = 176               # shipped tile size (1080p dock tiles are ~90 px; 176 keeps it crisp with less memory)
RADIUS = int(S * 0.225)  # tvOS-like corner radius

FONT_SETS = {
    # geometric, premium monogram face
    "default": [
        ("/System/Library/Fonts/Avenir Next.ttc", 8),        # Avenir Next Heavy
        ("/System/Library/Fonts/Avenir Next.ttc", 0),        # Bold
        ("/System/Library/Fonts/HelveticaNeue.ttc", 1),      # Helvetica Neue Bold
        ("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 0),
    ],
    # faces with Cyrillic coverage
    "cyrillic": [
        ("/System/Library/Fonts/HelveticaNeue.ttc", 1),
        ("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 0),
        ("/System/Library/Fonts/Supplemental/Tahoma Bold.ttf", 0),
        ("/System/Library/Fonts/Supplemental/Verdana Bold.ttf", 0),
    ],
}


# ---------------------------------------------------------------- helpers ---
def hex_rgb(value):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def vgradient(size, top, bottom):
    """Vertical gradient image (size x size)."""
    top, bottom = hex_rgb(top), hex_rgb(bottom)
    img = Image.new("RGB", (1, size), top)
    px = img.load()
    for y in range(size):
        t = y / float(size - 1)
        px[0, y] = tuple(int(round(top[i] + (bottom[i] - top[i]) * t)) for i in range(3))
    return img.resize((size, size), Image.BILINEAR)


def radial_glow(size, color, cx, cy, radius, peak=0.55):
    """RGBA image: soft radial light."""
    small = 192
    img = Image.new("L", (small, small), 0)
    px = img.load()
    for y in range(small):
        for x in range(small):
            dx = (x + 0.5) / small - cx
            dy = (y + 0.5) / small - cy
            d = math.sqrt(dx * dx + dy * dy) / radius
            if d < 1.0:
                px[x, y] = int(round(255 * peak * (1.0 - d) ** 2.2))
    img = img.resize((size, size), Image.BICUBIC).filter(ImageFilter.GaussianBlur(size // 60))
    out = Image.new("RGBA", (size, size), hex_rgb(color) + (0,))
    out.putalpha(img)
    return out


def rounded_mask(size, radius, inset=0):
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [inset, inset, size - 1 - inset, size - 1 - inset],
        radius=max(1, radius - inset), fill=255,
    )
    return mask


def over(base, layer, pos):
    """Composite an RGBA layer over an RGBA base at pos (no deprecated APIs)."""
    tmp = Image.new("RGBA", base.size, (0, 0, 0, 0))
    tmp.paste(layer, (int(pos[0]), int(pos[1])))
    return Image.alpha_composite(base, tmp)


def load_font(size, style="default"):
    for path, index in FONT_SETS[style]:
        try:
            font = ImageFont.truetype(path, size, index=index)
            bbox = font.getbbox("N")
        except Exception:
            continue
        if bbox and bbox[2] - bbox[0] > 4:
            return font
    raise RuntimeError("No usable font found")


def _mask_bytes(font, ch):
    m = font.getmask(ch)
    return (m.size, bytes(m))


def has_glyph(font, ch):
    """True only for a real glyph: missing chars render the .notdef box, and
    every missing char renders the same box as U+FFFF."""
    try:
        return _mask_bytes(font, ch) != _mask_bytes(font, "\uffff")
    except Exception:
        return False


def text_mask(text, target_h=None, target_w=None, pad=10, style="default"):
    """Rasterise text into an L mask, tightly cropped around the ink."""
    probe = load_font(120, style)
    bbox = probe.getbbox(text)
    h = max(1, bbox[3] - bbox[1])
    w = max(1, bbox[2] - bbox[0])
    scale = 1.0
    if target_h:
        scale = target_h / float(h)
    if target_w:
        scale = min(scale, target_w / float(w))
    size = max(16, int(120 * scale))
    font = load_font(size, style)
    bbox = font.getbbox(text)
    w = bbox[2] - bbox[0]
    h = bbox[3] - bbox[1]
    mask = Image.new("L", (w + pad * 2, h + pad * 2), 0)
    ImageDraw.Draw(mask).text((pad - bbox[0], pad - bbox[1]), text, font=font, fill=255)
    return mask


def glyph_layer(mask, color_top, color_bottom, glow_color, glow=0.45,
                glow_blur=None, shadow=True):
    """Ink mask -> gradient glyph with soft glow and a drop shadow."""
    w, h = mask.size
    pad = 44
    canvas = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))

    if shadow:
        sh = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        sh.paste((0, 0, 0, 165), (0, 0), mask)
        sh = sh.filter(ImageFilter.GaussianBlur(max(4, w // 45)))
        canvas = over(canvas, sh, (pad, pad + 14))

    if glow > 0:
        gl = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        gl.paste(hex_rgb(glow_color) + (int(255 * glow),), (0, 0), mask)
        gl = gl.filter(ImageFilter.GaussianBlur(glow_blur or max(6, w // 16)))
        canvas = over(canvas, gl, (pad, pad))

    grad = vgradient(max(w, h) + 8, color_top, color_bottom).resize((w, h), Image.BILINEAR)
    fill = grad.convert("RGBA")
    fill.putalpha(mask)
    canvas = over(canvas, fill, (pad, pad))
    return canvas


def compose(base, layer, center=(0.5, 0.5), offset=(0, 0)):
    x = int(S * center[0] - layer.size[0] / 2.0 + offset[0])
    y = int(S * center[1] - layer.size[1] / 2.0 + offset[1])
    return over(base, layer, (x, y))


# ------------------------------------------------------------------- tiles ---
def tile_base(top, bottom, accent, glow_peak=0.30):
    img = vgradient(S, top, bottom).convert("RGBA")
    img = over(img, radial_glow(S, accent, 0.5, 0.30, 0.85, peak=glow_peak), (0, 0))
    img = over(img, radial_glow(S, "#000000", 0.5, 1.02, 0.70, peak=0.55), (0, 0))
    # top glass highlight
    hl = Image.new("L", (1, S), 0)
    hl_px = hl.load()
    for y in range(S):
        v = max(0.0, 1.0 - (y / float(S)) / 0.42) ** 1.6
        hl_px[0, y] = int(round(255 * 0.085 * v))
    hl = hl.resize((S, S), Image.BILINEAR)
    white = Image.new("RGBA", (S, S), (255, 255, 255, 0))
    white.putalpha(hl)
    img = over(img, white, (0, 0))
    # faint edge light
    edge = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(edge).rounded_rectangle(
        [3, 3, S - 4, S - 4], radius=RADIUS - 3,
        outline=(255, 255, 255, 26), width=6,
    )
    return over(img, edge, (0, 0))


def letter_tile(letters, accent, light, top, bottom, fit_h=0.52, fit_w=0.64,
                style="default"):
    probe = load_font(120, style)
    if not all(has_glyph(probe, ch) for ch in letters):
        return None
    img = tile_base(top, bottom, accent)
    mask = text_mask(letters, target_h=int(S * fit_h), target_w=int(S * fit_w),
                     style=style)
    glyph = glyph_layer(mask, light, accent, accent, glow=0.42)
    return compose(img, glyph, (0.5, 0.505))


def triangle_tile(accent, light, top, bottom):
    img = tile_base(top, bottom, accent)
    w, h = int(S * 0.47), int(S * 0.42)
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).polygon(
        [(0, 0), (0, h - 1), (w - 1, h // 2)], fill=255,
    )
    mask = mask.filter(ImageFilter.GaussianBlur(1.6))
    glyph = glyph_layer(mask, light, accent, accent, glow=0.42)
    return compose(img, glyph, (0.5, 0.5), (int(S * 0.03), 0))


def grid_tile(light, top, bottom):
    img = tile_base(top, bottom, light, glow_peak=0.16)
    cell = int(S * 0.135)
    gap = int(S * 0.058)
    total = cell * 3 + gap * 2
    ox = (S - total) // 2
    oy = (S - total) // 2
    alphas = [[255, 150, 210], [210, 105, 150], [150, 90, 210]]
    mask = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(mask)
    for row in range(3):
        for col in range(3):
            x = ox + col * (cell + gap)
            y = oy + row * (cell + gap)
            d.rounded_rectangle([x, y, x + cell, y + cell],
                                radius=int(cell * 0.32), fill=alphas[row][col])
    mask = mask.filter(ImageFilter.GaussianBlur(1.2))
    glyph = glyph_layer(mask, "#FFFFFF", "#D9DCE6", light, glow=0.30)
    return compose(img, glyph, (0.5, 0.5))


def rings_tile(accent, light, top, bottom):
    img = tile_base(top, bottom, accent)
    mask = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(mask)
    cx = cy = S // 2
    r_out = int(S * 0.315)
    stroke = int(S * 0.062)
    d.ellipse([cx - r_out, cy - r_out, cx + r_out, cy + r_out], outline=255, width=stroke)
    r_mid = int(S * 0.155)
    d.ellipse([cx - r_mid, cy - r_mid, cx + r_mid, cy + r_mid],
              outline=255, width=int(stroke * 0.8))
    r_dot = int(S * 0.055)
    d.ellipse([cx - r_dot, cy - r_dot, cx + r_dot, cy + r_dot], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(1.4))
    glyph = glyph_layer(mask, light, accent, accent, glow=0.40)
    return compose(img, glyph, (0.5, 0.5))


def bars_tile(accent, light, top, bottom):
    img = tile_base(top, bottom, accent)
    mask = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(mask)
    heights = [0.34, 0.58, 0.46, 0.72]
    bar_w = int(S * 0.082)
    gap = int(S * 0.052)
    total = len(heights) * bar_w + (len(heights) - 1) * gap
    ox = (S - total) // 2
    cy = S // 2
    for i, h in enumerate(heights):
        hh = int(S * h)
        x = ox + i * (bar_w + gap)
        d.rounded_rectangle([x, cy - hh // 2, x + bar_w, cy + hh // 2],
                            radius=bar_w // 2, fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(1.4))
    glyph = glyph_layer(mask, light, accent, accent, glow=0.42)
    return compose(img, glyph, (0.5, 0.5))


def dots_tile(accent, light, top, bottom):
    img = tile_base(top, bottom, accent)
    mask = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(mask)
    pts = [(0.50, 0.255), (0.255, 0.705), (0.745, 0.705)]
    px = [(int(S * x), int(S * y)) for x, y in pts]
    lw = int(S * 0.030)
    for a, b in [(0, 1), (1, 2), (2, 0)]:
        d.line([px[a], px[b]], fill=255, width=lw)
    r = int(S * 0.088)
    for x, y in px:
        d.ellipse([x - r, y - r, x + r, y + r], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(1.6))
    glyph = glyph_layer(mask, light, accent, accent, glow=0.45)
    return compose(img, glyph, (0.5, 0.5))


def square_tile(accent, light, top, bottom):
    img = tile_base(top, bottom, accent)
    mask = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(mask)
    box = int(S * 0.29)
    stroke = int(S * 0.052)
    cx = cy = S // 2
    d.rounded_rectangle([cx - box, cy - box, cx + box, cy + box],
                        radius=int(S * 0.075), outline=255, width=stroke)
    inner = int(S * 0.125)
    d.rounded_rectangle([cx - inner, cy - inner, cx + inner, cy + inner],
                        radius=int(S * 0.028), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(1.4))
    glyph = glyph_layer(mask, light, accent, accent, glow=0.35)
    return compose(img, glyph, (0.5, 0.5))


# ------------------------------------------------------------- tile specs ---
TILES = [
    dict(file="netflix", kind="letter", text="N",
         accent="#FF2D3C", light="#FF6B6B",
         top="#331018", bottom="#0C0709", fit_h=0.53, fit_w=0.52),
    dict(file="youtube", kind="triangle",
         accent="#FF3B30", light="#FF7568",
         top="#331014", bottom="#0C0709"),
    dict(file="prime", kind="letter", text="P",
         accent="#00A8E1", light="#6FD8FF",
         top="#0B2430", bottom="#06090C", fit_h=0.53, fit_w=0.48),
    dict(file="kinopoisk", kind="letter", text="К", style="cyrillic",
         accent="#FF5C1A", light="#FFA36B",
         top="#331A0B", bottom="#0C0906", fit_h=0.53, fit_w=0.52),
    dict(file="ivi", kind="letter", text="IVI",
         accent="#FF2E63", light="#FF7B9E",
         top="#33101E", bottom="#0C070A", fit_h=0.32, fit_w=0.60),
    dict(file="wink", kind="letter", text="W",
         accent="#1ED7A5", light="#74FFD6",
         top="#0B2E28", bottom="#060B0A", fit_h=0.53, fit_w=0.58),
    dict(file="okko", kind="letter", text="OK",
         accent="#9B5CFF", light="#C79BFF",
         top="#241033", bottom="#0A070C", fit_h=0.36, fit_w=0.58),
    dict(file="rutube", kind="letter", text="R",
         accent="#00B956", light="#6BFFB0",
         top="#0B2E1B", bottom="#060B08", fit_h=0.53, fit_w=0.52),
    dict(file="moretv", kind="letter", text="M",
         accent="#00C2FF", light="#7FE3FF",
         top="#0B2433", bottom="#060A0C", fit_h=0.53, fit_w=0.56),
    dict(file="premier", kind="letter", text="П", style="cyrillic",
         accent="#E53935", light="#FF867F",
         top="#331012", bottom="#0C0708", fit_h=0.53, fit_w=0.52),
    dict(file="amediateka", kind="letter", text="A",
         accent="#FF6B00", light="#FFB370",
         top="#331A0B", bottom="#0C0906", fit_h=0.53, fit_w=0.52),
    dict(file="peers", kind="letter", text="PTV",
         accent="#00B0FF", light="#82D9FF",
         top="#0B2030", bottom="#06090C", fit_h=0.30, fit_w=0.62),
    dict(file="megafon", kind="letter", text="М", style="cyrillic",
         accent="#00C853", light="#6BFFA8",
         top="#0B2E1B", bottom="#060B08", fit_h=0.53, fit_w=0.52),
    dict(file="mts", kind="letter", text="МТС", style="cyrillic",
         accent="#E30611", light="#FF6B72",
         top="#33100F", bottom="#0C0707", fit_h=0.30, fit_w=0.62),
    dict(file="browser", kind="rings",
         accent="#4DA3FF", light="#93C9FF",
         top="#10203A", bottom="#070A0F"),
    dict(file="kids", kind="letter", text="K",
         accent="#FFD028", light="#FFE86B",
         top="#332A0B", bottom="#0C0A06", fit_h=0.53, fit_w=0.52),
    dict(file="twitch", kind="letter", text="T",
         accent="#9146FF", light="#BC85FF",
         top="#241033", bottom="#0A070C", fit_h=0.53, fit_w=0.52),
    dict(file="spotify", kind="bars",
         accent="#1ED760", light="#6BFF9E",
         top="#0B2E1B", bottom="#060B08"),
    dict(file="smartthings", kind="dots",
         accent="#23C4FF", light="#78E0FF",
         top="#0B2433", bottom="#060A0C"),
    dict(file="hdmi", kind="square",
         accent="#C9D1DC", light="#EDF1F7",
         top="#22252B", bottom="#0A0B0D"),
    dict(file="smarthub", kind="letter", text="SH",
         accent="#4A90FF", light="#9CC4FF",
         top="#0B1B33", bottom="#060A0F", fit_h=0.34, fit_w=0.58),
    dict(file="allapps", kind="grid",
         accent="#F2F3F7", light="#FFFFFF",
         top="#1A1A1F", bottom="#0A0A0C"),
]


def render_tile(spec):
    kind = spec["kind"]
    if kind == "letter":
        img = letter_tile(spec["text"], spec["accent"], spec["light"],
                          spec["top"], spec["bottom"],
                          fit_h=spec.get("fit_h", 0.52), fit_w=spec.get("fit_w", 0.64),
                          style=spec.get("style", "default"))
    elif kind == "triangle":
        img = triangle_tile(spec["accent"], spec["light"], spec["top"], spec["bottom"])
    elif kind == "grid":
        img = grid_tile(spec["light"], spec["top"], spec["bottom"])
    elif kind == "rings":
        img = rings_tile(spec["accent"], spec["light"], spec["top"], spec["bottom"])
    elif kind == "bars":
        img = bars_tile(spec["accent"], spec["light"], spec["top"], spec["bottom"])
    elif kind == "dots":
        img = dots_tile(spec["accent"], spec["light"], spec["top"], spec["bottom"])
    elif kind == "square":
        img = square_tile(spec["accent"], spec["light"], spec["top"], spec["bottom"])
    else:
        raise ValueError(kind)
    if img is None:
        raise RuntimeError("icon %s could not be rendered" % spec["file"])
    img.putalpha(Image.composite(img.getchannel("A"),
                                 Image.new("L", (S, S), 0),
                                 rounded_mask(S, RADIUS)))
    return img.resize((TILE, TILE), Image.LANCZOS)


# --------------------------------------------------------- package icons ---
def package_icon(size, kind):
    if kind == "aitv":
        img = vgradient(S, "#2B1E5E", "#0B0814").convert("RGBA")
        img = over(img, radial_glow(S, "#7B5CFF", 0.5, 0.28, 0.85, peak=0.34), (0, 0))
        img = over(img, radial_glow(S, "#000000", 0.5, 1.02, 0.7, peak=0.55), (0, 0))
        mask = text_mask("Ai", target_h=int(S * 0.44), target_w=int(S * 0.58))
        glyph = glyph_layer(mask, "#FFFFFF", "#C9C2FF", "#8A72FF", glow=0.35)
        img = compose(img, glyph, (0.5, 0.455))
        bar = Image.new("RGBA", (int(S * 0.34), int(S * 0.034)), (0, 0, 0, 0))
        ImageDraw.Draw(bar).rounded_rectangle(
            [0, 0, bar.size[0] - 1, bar.size[1] - 1],
            radius=bar.size[1] // 2, fill=hex_rgb("#FF4D6D") + (235,))
        bar = bar.filter(ImageFilter.GaussianBlur(2))
        img = compose(img, bar, (0.5, 0.755))
    else:  # homekey
        img = vgradient(S, "#2E2417", "#0B0A08").convert("RGBA")
        img = over(img, radial_glow(S, "#FFB86B", 0.5, 0.30, 0.85, peak=0.26), (0, 0))
        img = over(img, radial_glow(S, "#000000", 0.5, 1.02, 0.7, peak=0.55), (0, 0))
        mask = Image.new("L", (S, S), 0)
        d = ImageDraw.Draw(mask)
        apex = (S // 2, int(S * 0.245))
        eave_l = (int(S * 0.215), int(S * 0.505))
        eave_r = (int(S * 0.785), int(S * 0.505))
        body_l = int(S * 0.275)
        body_r = int(S * 0.725)
        body_top = int(S * 0.505)
        body_bot = int(S * 0.785)
        roof_th = int(S * 0.072)
        d.line([eave_l, apex], fill=255, width=roof_th)
        d.line([apex, eave_r], fill=255, width=roof_th)
        d.ellipse([apex[0] - roof_th // 2, apex[1] - roof_th // 2,
                   apex[0] + roof_th // 2, apex[1] + roof_th // 2], fill=255)
        wall_th = int(S * 0.060)
        d.line([(body_l, body_top), (body_l, body_bot)], fill=255, width=wall_th)
        d.line([(body_r, body_top), (body_r, body_bot)], fill=255, width=wall_th)
        d.line([(body_l, body_bot), (body_r, body_bot)], fill=255, width=wall_th)
        d.line([(body_l, body_top), (body_l + int(S * 0.06), body_top - int(S * 0.055))],
               fill=255, width=wall_th)
        d.line([(body_r - int(S * 0.06), body_top - int(S * 0.055)), (body_r, body_top)],
               fill=255, width=wall_th)
        for cx, cy in [(body_l, body_top), (body_l, body_bot), (body_r, body_top), (body_r, body_bot)]:
            r = wall_th // 2
            d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
        mask = mask.filter(ImageFilter.GaussianBlur(1.5))
        glyph = glyph_layer(mask, "#FBF6EC", "#E7D9C4", "#FFB86B", glow=0.30)
        img = compose(img, glyph, (0.5, 0.505))
        dot = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        r = int(S * 0.042)
        cx, cy = S // 2, int(S * 0.655)
        ImageDraw.Draw(dot).ellipse([cx - r, cy - r, cx + r, cy + r],
                                    fill=hex_rgb("#FFB86B") + (255,))
        dot = dot.filter(ImageFilter.GaussianBlur(int(S * 0.006)))
        img = over(img, dot, (0, 0))
    img.putalpha(Image.composite(img.getchannel("A"),
                                 Image.new("L", (S, S), 0),
                                 rounded_mask(S, RADIUS)))
    return img.resize((size, size), Image.LANCZOS)


# --------------------------------------------------------------- pipeline ---
def main():
    os.makedirs(os.path.join(AITV, "icons", "app"), exist_ok=True)
    os.makedirs(os.path.join(HOMEKEY, "icons"), exist_ok=True)

    sheet_tiles = []
    for spec in TILES:
        img = render_tile(spec)
        out = os.path.join(AITV, "icons", "app", spec["file"] + ".png")
        img.save(out, "PNG", optimize=True)
        sheet_tiles.append((spec["file"], img))
        print("tile  ", out)

    for size in (512, 117):
        out = os.path.join(AITV, "icons", "icon_%d.png" % size)
        package_icon(size, "aitv").save(out, "PNG", optimize=True)
        print("aitv  ", out)
        out = os.path.join(HOMEKEY, "icons", "icon_%d.png" % size)
        package_icon(size, "homekey").save(out, "PNG", optimize=True)
        print("home  ", out)

    cols, cell, pad = 7, 200, 12
    rows = int(math.ceil(len(sheet_tiles) / float(cols)))
    sheet = Image.new("RGB", (cols * (cell + pad) + pad, rows * (cell + pad) + pad),
                      (16, 17, 21))
    for i, (name, img) in enumerate(sheet_tiles):
        x = pad + (i % cols) * (cell + pad)
        y = pad + (i // cols) * (cell + pad)
        sheet.paste(img.convert("RGB"), (x, y))
    out = os.path.join(ROOT, "preview", "icons-sheet.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sheet.save(out, "PNG")
    print("sheet ", out)


if __name__ == "__main__":
    sys.exit(main())
