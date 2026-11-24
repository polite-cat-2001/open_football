#!/usr/bin/env python3
"""Add the researched super cups to assets/data/competitions.json.

The research stores `super_cup` either as a plain name (no dates, skipped) or as
a dict with dates/format (used). Discontinued competitions and mini-tournaments
are skipped; a missing date falls back to seven days before the league start.

The engine's `_super_entry` only handles a two-club, one- or two-leg match, so
run `tools/import_super_cups.py --dry-run` and add countries in batches while
`tests/check_career_season.gd` stays green.

Usage:  python tools/import_super_cups.py [--dry-run]
"""
import argparse
import datetime
import glob
import json
import re
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSET = ROOT / "assets" / "data" / "competitions.json"
RESEARCH = ROOT / "docs" / "research" / "competition-formats" / "cups-*.json"
DATABASE = ROOT / "data" / "databases" / "default" / "open_football.sqlite"
REGULATIONS = ROOT / "assets" / "data" / "league_regulations.json"
SKIP_WORDS = ("discontinued", "not held", "not currently", "suspended", "dormant",
              "no current")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    payload = json.loads(ASSET.read_text(encoding="utf-8"))
    competitions = payload["competitions"]
    have = {str(value.get("country", "")) for value in competitions.values()
            if str(value.get("kind", "")) == "super_cup"}
    database = sqlite3.connect(DATABASE)
    tier1 = {}
    for league_id, country_id, tier in database.execute(
            "select id, country_id, tier from leagues"):
        if int(tier or 0) != 1:
            continue
        row = database.execute("select name from countries where id = ?",
                               (country_id,)).fetchone()
        if row:
            tier1[row[0]] = league_id
    regulations = json.loads(REGULATIONS.read_text(encoding="utf-8"))["leagues"]
    added = []
    for path in sorted(glob.glob(str(RESEARCH))):
        source = json.loads(Path(path).read_text(encoding="utf-8"))
        for row in source.get("countries", []):
            country = str(row.get("country", ""))
            cup = row.get("super_cup")
            if country in have or not isinstance(cup, dict):
                continue
            text = (str(cup.get("note", "")) + " " + str(cup.get("quote", ""))).lower()
            if any(word in text for word in SKIP_WORDS):
                continue
            name = str(cup.get("name", "")).strip()
            start_md = str(cup.get("start_md") or "")
            if not start_md:
                league_start = str((regulations.get(tier1.get(country)) or {})
                                   .get("start_md", ""))
                if not league_start:
                    continue
                start_md = (datetime.date(2026, int(league_start[:2]),
                                          int(league_start[3:5]))
                            - datetime.timedelta(days=7)).strftime("%m-%d")
            legs = max(1, int(cup.get("legs", 2 if str(cup.get("format", "")) == "two_legs" else 1)))
            base = "".join(re.findall(r"[A-Z0-9]+", name.upper()))[:8] or "SUPER"
            key = base
            suffix = 2
            while key in competitions:
                key = f"{base}{suffix}"
                suffix += 1
            cup_id = next((cid for cid, value in competitions.items()
                           if str(value.get("country", "")) == country
                           and str(value.get("kind", "")) == "cup"), "")
            competitions[key] = {
                "kind": "super_cup", "label": name, "country": country,
                "teams": max(2, int(cup.get("teams", 2))),
                "cup": cup_id,
                "start_md": start_md, "end_md": start_md, "final_legs": legs,
                "champion": "winner", "source": str(cup.get("source", "")),
                "confidence": str(cup.get("confidence", "")),
                "note": "super cup from the research; date from the source or "
                        "the league start",
            }
            have.add(country)
            added.append((key, country, name, start_md, legs))
    print(f"would add {len(added)} super cups")
    for item in added:
        print("  ", item)
    if not args.dry_run:
        ASSET.write_text(json.dumps(payload, ensure_ascii=False, indent=1),
                         encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
