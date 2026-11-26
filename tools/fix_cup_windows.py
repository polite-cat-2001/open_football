#!/usr/bin/env python3
"""Replace the broken cup windows with the league calendar of their country.

Fifteen cup records carry `"None"` (a leftover of the importer that stringified a
missing value) or a truncated month. A cup without a window gets no planned dates,
so its fixtures were dated on an empty day. When the source does not state the
cup's window, the honest default is the country's top-flight window: the cup then
runs inside the same season, which is what the engine falls back to anyway.

Usage:  python tools/fix_cup_windows.py [--dry-run]
"""
import argparse
import json
import re
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
COMPETITIONS = ROOT / "assets" / "data" / "competitions.json"
REGULATIONS = ROOT / "assets" / "data" / "league_regulations.json"
DATABASE = ROOT / "data" / "databases" / "default" / "open_football.sqlite"
PATTERN = re.compile(r"^\d{2}-\d{2}$")
NOTE = " Calendar window taken from the country's top league: the source did not state the cup's own dates."


def valid(value) -> bool:
    return isinstance(value, str) and bool(PATTERN.match(value))


def top_league_windows() -> dict:
    regulations = json.loads(REGULATIONS.read_text(encoding="utf-8"))["leagues"]
    database = sqlite3.connect(DATABASE)
    rows = database.execute(
        "select c.name, l.id from leagues l join countries c on c.id = l.country_id"
        " where l.tier = 1 order by l.id")
    windows = {}
    for country, league_id in rows:
        record = regulations.get(league_id, {})
        if valid(record.get("start_md")) and valid(record.get("end_md")):
            windows.setdefault(country, [record["start_md"], record["end_md"]])
    return windows


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    document = json.loads(COMPETITIONS.read_text(encoding="utf-8"))
    competitions = document["competitions"]
    windows = top_league_windows()
    fixed, missing = [], []
    for competition_id, record in competitions.items():
        if valid(record.get("start_md")) and valid(record.get("end_md")):
            continue
        country = str(record.get("country", ""))
        window = windows.get(country)
        if window is None:
            missing.append([competition_id, country])
            continue
        record["start_md"], record["end_md"] = window[0], window[1]
        record["note"] = (str(record.get("note", "")).rstrip() + NOTE).strip()
        fixed.append(competition_id)
    if not args.dry_run:
        COMPETITIONS.write_text(
            json.dumps(document, ensure_ascii=False, indent=1) + "\n",
            encoding="utf-8", newline="\n")
    print("fixed", len(fixed), fixed)
    if missing:
        print("no league window to borrow:", missing)


if __name__ == "__main__":
    main()
