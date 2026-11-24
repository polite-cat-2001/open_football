#!/usr/bin/env python3
"""Turn a hand-made tournament logo into the file the UI expects.

The UI reads `data/raster/tournaments/<id>.png` and falls back to a monogram. A
logo that matches the Transfermarkt pack has a transparent background and sits on
the same 139x181 canvas, so this tool:

  * drops a plain white background (only the white connected to the border, so
    white letters inside the emblem survive) unless --keep-background is given
    for a designed colour tile;
  * crops the transparent margins and fits the mark into the shared canvas;
  * writes PNG into the data root.

Usage:
  python tools/prepare_tournament_logo.py --id NIGEFEDECUP --file incoming/nigeria.jpg
  python tools/prepare_tournament_logo.py --id GHANAFACUP --file incoming/ghana.jpg --keep-background
"""
import argparse
import sys
from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "data" / "raster" / "tournaments"
CANVAS = (139, 181)
MARGIN = 4


def remove_white(image, tolerance: int):
    rgba = image.convert("RGBA")
    width, height = rgba.size
    pixels = rgba.load()
    seen = bytearray(width * height)
    queue = deque()

    def white(x: int, y: int) -> bool:
        r, g, b, a = pixels[x, y]
        return a > 0 and r >= 255 - tolerance and g >= 255 - tolerance \
            and b >= 255 - tolerance

    def push(x: int, y: int) -> None:
        if 0 <= x < width and 0 <= y < height and not seen[y * width + x]:
            if white(x, y):
                seen[y * width + x] = 1
                queue.append((x, y))

    for x in range(width):
        push(x, 0)
        push(x, height - 1)
    for y in range(height):
        push(0, y)
        push(width - 1, y)
    while queue:
        x, y = queue.popleft()
        pixels[x, y] = (0, 0, 0, 0)
        push(x + 1, y)
        push(x - 1, y)
        push(x, y + 1)
        push(x, y - 1)
    return rgba


def crop_to_content(image):
    box = image.getbbox()
    return image.crop(box) if box else image


def fit_canvas(image):
    usable = (CANVAS[0] - MARGIN * 2, CANVAS[1] - MARGIN * 2)
    fitted = image.copy()
    fitted.thumbnail(usable, 1)  # 1 = LANCZOS
    canvas = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    canvas.paste(fitted, ((CANVAS[0] - fitted.width) // 2,
                          (CANVAS[1] - fitted.height) // 2), fitted)
    return canvas


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--id", required=True)
    parser.add_argument("--file", required=True)
    parser.add_argument("--keep-background", action="store_true")
    parser.add_argument("--tolerance", type=int, default=18)
    args = parser.parse_args()

    with Image.open(args.file) as source:
        source.load()
        image = source.convert("RGBA")
        original = "%s %dx%d" % (source.format, source.width, source.height)
    transparent = image.getchannel("A").getextrema()[0] < 255
    if not args.keep_background and not transparent:
        image = remove_white(image, args.tolerance)
    image = fit_canvas(crop_to_content(image))
    OUT.mkdir(parents=True, exist_ok=True)
    target = OUT / ("%s.png" % args.id)
    image.save(target, "PNG", optimize=True)
    print("%-14s %s -> %s" % (args.id, original, target))


if __name__ == "__main__":
    main()
