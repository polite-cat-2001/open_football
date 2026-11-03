#!/usr/bin/env python3
"""Bake a thin white outline into the imported league logos.

A runtime shader dilates the logo's alpha at texture resolution; the league
logos are small bitmaps, so the result follows their pixel steps and looks
jagged. This tool does the same dilation once, with a sub-pixel blur, and
writes padded RGBA images:

    <data>/databases/default/images_leagues/<id>.png
        -> <data>/databases/default/images_leagues_outline/<id>.png

`UiAssets.league_logo` prefers the outlined image. Run after
`import_prototype_images.py` (or whenever the league logos change):

    python tools/outline_league_logos.py

Requires Pillow (`pip install pillow`).
"""

from __future__ import annotations

import argparse
import os
from pathlib import Path

from PIL import Image, ImageFilter

DEFAULT_DATA = Path("C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data")
SOURCE = "databases/default/images_leagues"
OUTPUT = "databases/default/images_leagues_outline"
PADDING = 10
DILATE_RADIUS = 3


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data-root", type=Path,
                        default=Path(os.environ.get("GPF_DATA_ROOT", DEFAULT_DATA)))
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()
    source_dir = args.data_root / SOURCE
    output_dir = args.data_root / OUTPUT
    if not source_dir.is_dir():
        print(f"source directory not found: {source_dir}")
        return 1
    output_dir.mkdir(parents=True, exist_ok=True)
    copied = 0
    skipped = 0
    for source_path in sorted(source_dir.glob("*.png")):
        output_path = output_dir / source_path.name
        if output_path.is_file() and not args.force:
            skipped += 1
            continue
        source = Image.open(source_path).convert("RGBA")
        # Pad first, then dilate: a logo that touches its own bitmap edge must
        # still get an outline in the padding instead of being clipped by the
        # source rectangle.
        canvas = Image.new("RGBA",
                           (source.width + PADDING * 2, source.height + PADDING * 2),
                           (0, 0, 0, 0))
        canvas.paste(source, (PADDING, PADDING), source)
        alpha = canvas.getchannel("A")
        dilated = alpha.filter(ImageFilter.MaxFilter(DILATE_RADIUS * 2 + 1))
        dilated = dilated.filter(ImageFilter.GaussianBlur(0.5))
        white = Image.new("RGBA", canvas.size, (255, 255, 255, 0))
        white.putalpha(dilated)
        outlined = Image.alpha_composite(white, canvas)
        outlined.save(output_path, "PNG", optimize=True)
        copied += 1
    print(f"league logos: outlined={copied} skipped={skipped} -> {output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
