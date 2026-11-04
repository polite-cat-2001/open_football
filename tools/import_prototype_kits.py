#!/usr/bin/env python3
"""Import the prototype's kit specs into the game data tree.

The gf-ui-prototype raster set keeps kit specifications in
``data/raster/teams_kits/{specs,national_specs}.json``.  Their ids are the
Transfermarkt ids already stored in the game database (``teams.tm_id``), so no
name matching is needed for clubs; national teams fall back to a name match
because their prototype ids are the national_teams ids (also carried by tm_id,
but the name match keeps older data trees working).

The output is a compact ``databases/default/kits.json`` consumed by
``KitCatalog``:

    { "version": 1,
      "teams": { "<tm_id>": { "name": "...", "kits": [
          {"id": "main", "shirt": "#...", "shorts": "#...",
           "pattern": "plain", "pattern_color": null}, ... ] } } }

Only the four outfield kits are exported; the goalkeeper kits are not part of
the kit select screen.  The game data tree is external and is not committed.

Run it once after refreshing either data tree:

    python tools/import_prototype_kits.py
    python tools/import_prototype_kits.py --force
"""

from __future__ import annotations

import argparse
import json
import os
import sqlite3
from pathlib import Path

DEFAULT_PROTOTYPE = Path("C:/Users/Egor/Desktop/projects/gf-ui-prototype")
DEFAULT_DATA = Path("C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data")
DATABASE = "databases/default/database.sqlite"
OUTPUT = "databases/default/kits.json"
KIT_IDS = ("main", "white", "black", "reserve")
KIT_PATTERNS = {"plain", "stripes", "halves", "hoops", "sash"}
FALLBACK_PALETTE = ["#F5F7FA", "#171B3F", "#5A5F78", "#1D2138"]
FALLBACK_KITS = {
    "main": {"shirt": 0, "shorts": 1, "pattern": "plain", "pattern_color": None},
    "white": {"shirt": 0, "shorts": 0, "pattern": "plain", "pattern_color": None},
    "black": {"shirt": 1, "shorts": 1, "pattern": "plain", "pattern_color": None},
    "reserve": {"shirt": 2, "shorts": 1, "pattern": "plain", "pattern_color": None},
}


def key(name) -> str:
    return " ".join(str(name or "").strip().lower().split())


def open_readonly(path: Path) -> sqlite3.Connection:
    connection = sqlite3.connect(f"file:{path.as_posix()}?mode=ro", uri=True)
    connection.row_factory = sqlite3.Row
    return connection


def palette_color(palette: list[str], index, fallback: str) -> str:
    if isinstance(index, int) and 0 <= index < len(palette):
        return palette[index]
    return fallback


def kit_colors(palette: list[str], spec: dict | None) -> dict:
    spec = spec or {}
    pattern = spec.get("pattern")
    if pattern not in KIT_PATTERNS:
        pattern = "plain"
    pattern_color = palette_color(palette, spec.get("pattern_color"), "#000000")
    return {
        "shirt": palette_color(palette, spec.get("shirt"), FALLBACK_PALETTE[0]),
        "shorts": palette_color(palette, spec.get("shorts"), FALLBACK_PALETTE[0]),
        "pattern": pattern,
        "pattern_color": pattern_color if pattern != "plain" else None,
    }


def compact_kits(spec: dict) -> list[dict]:
    palette = spec.get("palette") or FALLBACK_PALETTE
    kits = []
    for kit_id in KIT_IDS:
        entry = spec.get(kit_id) or FALLBACK_KITS[kit_id]
        kits.append({"id": kit_id, **kit_colors(palette, entry)})
    return kits


def load_specs(path: Path) -> list[dict]:
    if not path.is_file():
        return []
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prototype-root", type=Path,
                        default=Path(os.environ.get("GF_UI_PROTOTYPE_ROOT", DEFAULT_PROTOTYPE)))
    parser.add_argument("--data-root", type=Path,
                        default=Path(os.environ.get("GPF_DATA_ROOT", DEFAULT_DATA)))
    parser.add_argument("--force", action="store_true",
                        help="overwrite an existing kits.json")
    parser.add_argument("--dry-run", action="store_true",
                        help="only report what would be written")
    args = parser.parse_args()

    game_db = args.data_root / DATABASE
    raster = args.prototype_root / "data" / "raster" / "teams_kits"
    if not game_db.is_file():
        print(f"game database not found: {game_db}")
        return 1
    output = args.data_root / OUTPUT
    if output.is_file() and not args.force:
        print(f"output already exists: {output} (use --force to overwrite)")
        return 0

    club_specs = {str(row["id"]): row for row in load_specs(raster / "specs.json")}
    national_specs = {key(row["name"]): row for row in load_specs(raster / "national_specs.json")}

    game = open_readonly(game_db)
    teams = {}
    missing = 0
    for row in game.execute("select id, name, tm_id from teams order by id"):
        tm_id = str(row["tm_id"] or "").strip()
        spec = club_specs.get(tm_id) or national_specs.get(key(row["name"]))
        if spec is None:
            missing += 1
            continue
        teams[tm_id] = {"name": str(row["name"]), "kits": compact_kits(spec)}

    payload = {"version": 1, "teams": teams}
    text = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
    if args.dry_run:
        print(f"would write {len(teams)} teams to {output} ({len(text)} bytes)")
        print(f"teams without a prototype kit spec: {missing}")
        return 0

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(text, encoding="utf-8")
    print(f"wrote {len(teams)} teams to {output} ({len(text)} bytes)")
    print(f"teams without a prototype kit spec: {missing}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
