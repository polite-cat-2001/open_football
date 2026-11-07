"""Copy Transfermarkt face cutouts into assets/faces for the game-plan UI.

The cutouts are keyed by Transfermarkt id (players.tm_id), which is also how the
C++ menu loads databases/default/faces/<tm_id>.png. Godot must not import these
thousands of PNGs, so assets/faces is gitignored and carries a .gdignore; the
runtime loads them through UiAssets.player_face() with a silhouette fallback.

Usage:
  python tools/import_player_faces.py
  python tools/import_player_faces.py --source <dir> --limit 50
"""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path


DEFAULT_SOURCES = [
    Path(r"C:/Users/Egor/Desktop/projects/gf-career-prototype/data/raster/players_faces_cutout"),
    Path(r"C:/Users/Egor/Desktop/projects/GameplayFootball/data/databases/default/faces"),
]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=None)
    parser.add_argument("--dest", type=Path,
                        default=Path(__file__).resolve().parents[1] / "assets" / "faces")
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    source = args.source
    if source is None:
        for candidate in DEFAULT_SOURCES:
            if candidate.is_dir():
                source = candidate
                break
    if source is None or not source.is_dir():
        raise SystemExit(f"face source not found; pass --source (tried {DEFAULT_SOURCES})")

    args.dest.mkdir(parents=True, exist_ok=True)
    args.dest.joinpath(".gdignore").touch()
    copied = skipped = 0
    for src in sorted(source.glob("*.png")):
        dst = args.dest / src.name
        if dst.exists() and not args.force:
            skipped += 1
            continue
        shutil.copy2(src, dst)
        copied += 1
        if args.limit and copied >= args.limit:
            break
    print(f"faces: {copied} copied, {skipped} already present -> {args.dest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
