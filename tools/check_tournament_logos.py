#!/usr/bin/env python3
"""Check the tournament logo files in the data root.

The UI reads `data/raster/tournaments/<id>.png` and falls back to a monogram, so a
hand-made file must be a PNG with a transparent background: a JPEG or an opaque
PNG shows as a white box next to the Transfermarkt logos (139x181, RGBA).

Usage:  python tools/check_tournament_logos.py
"""
import json
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATABASE = ROOT / "data" / "databases" / "default" / "open_football.sqlite"
FOLDER = ROOT / "data" / "raster" / "tournaments"
CONTINENTAL = ["CL", "EL", "UCOL", "CLI", "CS", "RECO", "CCL", "ACLE", "ACL2", "AFCP"]


def known_ids() -> list:
    ids = [str(row[0]) for row in sqlite3.connect(DATABASE).execute(
        "select id from leagues order by id") if str(row[0]) != "NAT"]
    competitions = json.loads((ROOT / "assets" / "data" / "competitions.json")
                              .read_text(encoding="utf-8"))["competitions"]
    ids += [str(key) for key in competitions]
    return ids + CONTINENTAL


def main() -> None:
    try:
        from PIL import Image
    except ImportError:
        sys.exit("Pillow is required: pip install pillow")

    missing = []
    broken = []
    for competition_id in known_ids():
        path = FOLDER / ("%s.png" % competition_id)
        if not path.exists():
            missing.append(competition_id)
            continue
        with Image.open(path) as image:
            image.load()
            if image.format != "PNG":
                broken.append((competition_id, "%s instead of PNG" % image.format))
                continue
            alpha = image.convert("RGBA").getchannel("A")
            if alpha.getextrema()[0] == 255:
                broken.append((competition_id,
                               "no transparent pixel (%dx%d)" % image.size))
    print("ok: %d, missing: %d, not usable: %d" % (
        len(known_ids()) - len(missing) - len(broken), len(missing), len(broken)))
    if broken:
        print("not usable:")
        for competition_id, reason in broken:
            print("  %-14s %s" % (competition_id, reason))
    if missing:
        print("missing:", ", ".join(missing))


if __name__ == "__main__":
    main()
