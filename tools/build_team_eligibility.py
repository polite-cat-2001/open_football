#!/usr/bin/env python3
"""Precompute the team picker's "can field eleven" cache.

GameplayFootball's TeamSelectPage lets SQLite evaluate a correlated
`count(*)` subquery per team. The Godot port reads SQLite with a GDScript
b-tree reader, where the same probe costs milliseconds per team and makes the
217-team National Teams list visible as a hitch. This tool computes the two
id sets once with Python's sqlite3 and writes them next to the database:

  databases/default/open_football_eligibility.json
  {"version": 1, "club": [ids...], "national": [ids...]}

TeamCatalog loads the file when present and falls back to the per-team index
probe when it is missing.
"""

from __future__ import annotations

import argparse
import json
import sqlite3
from pathlib import Path

DEFAULT_DATA_ROOT = Path(__file__).resolve().parent.parent / "data"
DATABASE_RELATIVE_PATH = Path("databases/default/open_football.sqlite")
OUTPUT_RELATIVE_PATH = Path("databases/default/open_football_eligibility.json")
MIN_MATCH_PLAYERS = 11


def build_eligibility(data_root: Path) -> dict:
    database = data_root / DATABASE_RELATIVE_PATH
    if not database.is_file():
        raise SystemExit(f"database not found: {database}")

    con = sqlite3.connect(str(database))
    try:
        club = [
            int(row[0])
            for row in con.execute(
                """
                select team_id
                from players
                where team_id is not null and team_id > 0
                group by team_id
                having count(*) >= ?
                order by team_id
                """,
                (MIN_MATCH_PLAYERS,),
            )
        ]
        national = [
            int(row[0])
            for row in con.execute(
                """
                select nationalteam_id
                from players
                where nationalteam_id is not null and nationalteam_id > 0
                group by nationalteam_id
                having count(*) >= ?
                order by nationalteam_id
                """,
                (MIN_MATCH_PLAYERS,),
            )
        ]
    finally:
        con.close()
    return {"version": 1, "club": club, "national": national}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--data-root",
        type=Path,
        default=DEFAULT_DATA_ROOT,
        help=f"GameplayFootball data root (default: {DEFAULT_DATA_ROOT})",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="output JSON (default: <data-root>/databases/default/team_eligibility.json)",
    )
    args = parser.parse_args()

    data_root = args.data_root.resolve()
    output = args.output or (data_root / OUTPUT_RELATIVE_PATH)
    payload = build_eligibility(data_root)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(payload, separators=(",", ":")), encoding="utf-8")
    print(
        f"wrote {output} ({len(payload['club'])} clubs, "
        f"{len(payload['national'])} national teams)"
    )


if __name__ == "__main__":
    main()
