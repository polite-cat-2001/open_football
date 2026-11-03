#!/usr/bin/env python3
"""Add the lookup indexes the lazy shell catalog relies on.

The shipped GameplayFootball database only indexes players(team_id/nationalteam_id).
The Godot reader scans the whole teams/leagues table for every country/league switch
(~90 ms for the 4652-team table), which is noticeable on the team-select screen.
These two indexes are data-neutral and make `select_indexed` fast:

    teams(league_id), leagues(country_id)

Run after refreshing the game data tree:

    python tools/optimize_game_db.py
"""

from __future__ import annotations

import argparse
import os
import sqlite3
from pathlib import Path

DEFAULT_DATA = Path("C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data")
DATABASE = "databases/default/database.sqlite"

INDEXES = {
    "idx_teams_league": "CREATE INDEX IF NOT EXISTS idx_teams_league ON teams(league_id)",
    "idx_leagues_country": "CREATE INDEX IF NOT EXISTS idx_leagues_country "
                           "ON leagues(country_id)",
}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data-root", type=Path,
                        default=Path(os.environ.get("GPF_DATA_ROOT", DEFAULT_DATA)))
    args = parser.parse_args()
    database = args.data_root / DATABASE
    if not database.is_file():
        print(f"game database not found: {database}")
        return 1
    connection = sqlite3.connect(database)
    try:
        for name, statement in INDEXES.items():
            connection.execute(statement)
            print(f"ok: {name}")
        connection.commit()
    finally:
        connection.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
