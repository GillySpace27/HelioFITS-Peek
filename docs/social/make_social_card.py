#!/usr/bin/env python3
"""Build the 1280 x 640 GitHub social preview card for a HelioFITS repository.

Usage (from the repository root):  python3 docs/social/make_social_card.py <peek|studio|suite>
Needs Pillow. Writes docs/social/social-<name>.png. Upload it under
Settings > Social preview. The same file lives in all three repositories.
Icons are the shipped app icons (violet ground, AIA 171 Sun); paths are
relative to the repository root.
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

W, H = 1280, 640
TOP, BOT = (47, 34, 99), (21, 16, 42)  # violet ground #2F2263 to #15102A
FONTS = ["/usr/share/fonts/opentype/inter/Inter-Bold.otf", "/Library/Fonts/Arial Bold.ttf",
         "/System/Library/Fonts/Helvetica.ttc", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"]
FONTS_REG = ["/usr/share/fonts/opentype/inter/Inter-Regular.otf", "/Library/Fonts/Arial.ttf",
             "/System/Library/Fonts/Helvetica.ttc", "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"]

CARDS = {
    "peek": dict(icons=["docs/social/peek_icon.png"], title="HelioFITS Peek",
                 pitch="Solar FITS files, previewable in Finder and Quick Look.",
                 foot="doi 10.5281/zenodo.23749496  |  BSD-2-Clause  |  gilly.space/heliofits"),
    "studio": dict(icons=["resources/images/HFStudio_icon_512.png"], title="HelioFITS Studio",
                   pitch="A desktop viewer for coronagraph and wide-field solar imagery.",
                   foot="doi 10.5281/zenodo.23541893  |  MPL-2.0  |  gilly.space/heliofits-studio"),
    "suite": dict(icons=["docs/social/peek_icon.png", "docs/social/studio_512.png"], title="HelioFITS Suite",
                  pitch="Peek and Studio: software for looking at solar imagery, with one DOI to cite.",
                  foot="doi 10.5281/zenodo.23524598  |  CC-BY-4.0  |  gilly.space/heliosoftware"),
}


def font(paths, size):
    for p in paths:
        try:
            return ImageFont.truetype(p, size)
        except OSError:
            continue
    return ImageFont.load_default()


def wrap(draw, text, f, width):
    lines, cur = [], ""
    for w in text.split():
        t = (cur + " " + w).strip()
        if draw.textlength(t, font=f) <= width:
            cur = t
        else:
            lines.append(cur)
            cur = w
    return lines + [cur]


def main(name):
    root = Path(__file__).resolve().parents[2]
    c = CARDS[name]
    img = Image.new("RGB", (W, H), TOP)
    px = ImageDraw.Draw(img)
    for y in range(H):
        t = y / (H - 1)
        px.line([(0, y), (W, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOT)))
    size = 280 if len(c["icons"]) == 1 else 220
    x = 90
    for ip in c["icons"]:
        ic = Image.open(root / ip).convert("RGBA").resize((size, size), Image.LANCZOS)
        img.paste(ic, (x, (H - size) // 2 - 30), ic)
        x += size + 30
    tx = x + 40
    d = ImageDraw.Draw(img)
    d.text((tx, 190), c["title"], font=font(FONTS, 76), fill="white")
    f = font(FONTS_REG, 38)
    y = 300
    for line in wrap(d, c["pitch"], f, W - tx - 70):
        d.text((tx, y), line, font=f, fill=(214, 207, 240))
        y += 54
    d.text((90, H - 80), c["foot"], font=font(FONTS_REG, 26), fill=(160, 150, 205))
    out = root / "docs" / "social" / f"social-{name}.png"
    img.save(out, optimize=True)
    print(out)


if __name__ == "__main__":
    if len(sys.argv) != 2 or sys.argv[1] not in CARDS:
        sys.exit("usage: make_social_card.py <%s>" % "|".join(CARDS))
    main(sys.argv[1])
