#!/usr/bin/env python3
"""Give the three oversized leagues a zonal regular season.

`2DVB` (59 clubs), `LPL` (28) and `AR3F` (37) are stored as one league row, but
their real competitions are played in geographical zones: a double round-robin of
every club against 58/27/36 others cannot fit a season, which is why the calendar
audit found matches one day apart. A `format` with one group stage per zone keeps
the fixture count realistic (each club meets only its zone).

`rounds` is taken from the smallest zone so no pair meets three times; a slightly
larger zone then plays one or two second legs fewer, which is the lesser evil
against duplicate pairings.

Usage:  python tools/set_zone_formats.py [--dry-run]
"""
import argparse
import io
import json
import sqlite3
import sys
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent
REGULATIONS = ROOT / "assets" / "data" / "league_regulations.json"
DATABASE = ROOT / "data" / "databases" / "default" / "open_football.sqlite"

# league id -> number of zones
ZONES = {"2DVB": 4, "LPL": 2, "AR3F": 2}

# The real competition continues after the zones; the engine plays the zones and
# ranks them together, so the note says what is not modelled instead of pretending.
NOTES = {
    "2DVB": "The real 2. Division B continues with promotion play-offs; only the "
            "zone table is modelled.",
    "LPL": "The real two groups of 14 end in a final four; only the zone table "
           "is modelled.",
    "AR3F": "The real Torneo Federal A continues with the Campeonato and "
            "Revalida paths; only the zone table is modelled.",
}


def split(total: int, zones: int) -> list:
    base, extra = divmod(total, zones)
    return [base + (1 if index < extra else 0) for index in range(zones)]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    document = json.loads(REGULATIONS.read_text(encoding="utf-8"))
    leagues = document["leagues"]
    database = sqlite3.connect(DATABASE)
    for league_id, zones in ZONES.items():
        record = leagues.get(league_id)
        if record is None:
            print("no record", league_id)
            continue
        total = database.execute(
            "select count(*) from teams where league_id = ?", (league_id,)).fetchone()[0]
        if total < 2 * zones:
            print("too few clubs", league_id, total)
            continue
        sizes = split(total, zones)
        rounds = 2 * (min(sizes) - 1)
        record["format"] = {
            "season": str(record.get("_generated", "")) or "2026-27",
            "start_md": record.get("start_md"),
            "end_md": record.get("end_md"),
            "champion": "none",
            "stages": [{
                "id": "zones",
                "kind": "group",
                "label": "Zones",
                "rounds": rounds,
                "start_md": record.get("start_md"),
                "end_md": record.get("end_md"),
                "entrants": [{"rule": "all"}],
                "groups": {"sizes": sizes},
            }],
            "note": ("Zonal regular season: %d clubs in %d zones of %s, %d rounds "
                     "each; the zones are geographical, so the season table is a "
                     "combined ranking. %s" % (total, zones,
                                               "/".join(str(size) for size in sizes),
                                               rounds, NOTES[league_id])),
        }
        print("%-6s clubs %2d -> zones %s, %d rounds" % (
            league_id, total, sizes, rounds))
    if not args.dry_run:
        REGULATIONS.write_text(
            json.dumps(document, ensure_ascii=False, indent=1) + "\n",
            encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
