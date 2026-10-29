#!/usr/bin/env python3
"""GitHub social preview card for HelioFITS Peek: the shipped app icon on the family violet ground.

  python3 docs/social/make_social_card.py   ->  docs/social/social-card.png (1280 x 640)
Needs Pillow. The font is macOS Helvetica Neue.
"""
import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "social-card.png")
W, H, SS = 1280, 640, 4
TOP, BOTTOM = (0x2F, 0x22, 0x63), (0x15, 0x10, 0x2A)
WHITE, PITCH, SMALL = (255, 255, 255), (0xCF, 0xCA, 0xEA), (0xA9, 0xA3, 0xCC)
FONT = "/System/Library/Fonts/HelveticaNeue.ttc"       # 0 Regular, 1 Bold, 10 Medium
MARGIN = 96                                            # GitHub's safe area is 40 px; stay well inside it
DOI_LINE = "DOI 10.5281/zenodo.{doi} · {lic}"


def font(index, size):
    return ImageFont.truetype(FONT, size, index=index)


def ground():
    im = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(im)
    for y in range(H):
        t = y / (H - 1)
        d.line([(0, y), (W, y)], fill=tuple(round(a * (1 - t) + b * t) for a, b in zip(TOP, BOTTOM)))
    return im


def icon(path, size):
    """Shipped icon, as is, scaled to `size` px tall. An opaque square gets the macOS rounded corners the
    OS would apply; a pre-shaped icon (alpha) is cropped to its visible shape."""
    im = Image.open(path).convert("RGBA")
    if im.getchannel("A").getextrema()[0] == 255:
        mask = Image.new("L", (im.width * 2, im.height * 2), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, im.width * 2 - 1, im.height * 2 - 1],
                                               radius=round(0.2237 * im.width * 2), fill=255)
        im.putalpha(mask.resize(im.size, Image.LANCZOS))
    im = im.crop(im.getchannel("A").getbbox())
    return im.resize((round(im.width * size / im.height), size), Image.LANCZOS)


def wrap(text, fnt, width, draw):
    lines, cur = [], ""
    for word in text.split():
        trial = (cur + " " + word).strip()
        if draw.textlength(trial, font=fnt) <= width or not cur:
            cur = trial
        else:
            lines.append(cur)
            cur = word
    return lines + [cur]


def card(icons, name, pitch, doi, lic, icon_h, gap=0):
    im = ground()
    d = ImageDraw.Draw(im)
    x = MARGIN
    for p in icons:
        ic = icon(p, icon_h)
        im.paste(ic, (x, (H - icon_h) // 2), ic)
        x += ic.width + gap
    tx, tw = x - gap + 64, W - 72 - (x - gap + 64)
    size = 88
    while d.textlength(name, font=font(1, size)) > tw:
        size -= 2
    nf, pf = font(1, size), font(0, 30)
    lines = wrap(pitch, pf, tw, d)
    assert len(lines) <= 2, f"pitch wraps to {len(lines)} lines"
    name_h, line_h = round(size * 1.15), 42
    top = (H - (name_h + 14 + line_h * len(lines))) // 2
    d.text((tx, top), name, font=nf, fill=WHITE)
    for i, ln in enumerate(lines):
        d.text((tx, top + name_h + 14 + i * line_h), ln, font=pf, fill=PITCH)
    d.text((tx, H - 72 - 28), DOI_LINE.format(doi=doi, lic=lic), font=font(10, 24), fill=SMALL)
    im.save(OUT)
    print(f"wrote {OUT} {im.size}, name {size} px")


if __name__ == "__main__":
    ICON = os.path.join(HERE, "..", "..", "HelioFITS", "Assets.xcassets", "AppIcon.appiconset", "icon_512x512@2x.png")
    card([ICON], "HelioFITS Peek", "Solar FITS thumbnails and previews in macOS Finder and Quick Look.",
         "23749496", "BSD-2-Clause", 384)
