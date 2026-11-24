#!/usr/bin/env python3
"""Merge the researched domestic cups into assets/data/competitions.json.

The research files (`docs/research/competition-formats/cups-*.json`) cover the
main cup of many associations; the game asset only had the ones already ported.
Only countries without a cup record are touched, and the IDs are generated from
the cup name (unique, stable).

Usage:  python tools/import_cup_records.py [--dry-run]
"""
import argparse
import glob
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSET = ROOT / "assets" / "data" / "competitions.json"
RESEARCH = ROOT / "docs" / "research" / "competition-formats" / "cups-*.json"


def slug(name: str) -> str:
    words = re.findall(r"[A-Za-z0-9]+", name.upper())
    return "".join(word[:4] for word in words[:3]) or "CUP"


def record_for(row: dict) -> dict:
    cup = row.get("main_cup") or {}
    name = str(cup.get("name", "")).split(" (")[0].strip()
    two_legged = cup.get("two_legged_rounds") or []
    final_legs = 2 if "final" in two_legged else 1
    return {
        "kind": "cup",
        "label": name,
        "country": row.get("country", ""),
        "tiers": [],
        "start_md": str(cup.get("start_md", "")),
        "end_md": str(cup.get("end_md", "")),
        "two_legged": two_legged,
        "final_legs": final_legs,
        "champion": "winner",
        "source": str(cup.get("source", "")),
        "confidence": str(cup.get("confidence", "")),
        "note": str(cup.get("note", "")),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    payload = json.loads(ASSET.read_text(encoding="utf-8"))
    competitions = payload["competitions"]
    have = {str(value.get("country", "")) for value in competitions.values()}
    added = []
    for path in sorted(glob.glob(str(RESEARCH))):
        data = json.loads(Path(path).read_text(encoding="utf-8"))
        for row in data.get("countries", []):
            country = str(row.get("country", ""))
            if not country or country in have:
                continue
            record = record_for(row)
            if not record["label"] or not record["start_md"] or not record["end_md"]:
                continue
            base = slug(record["label"])
            competition_id = base
            suffix = 2
            while competition_id in competitions:
                competition_id = f"{base}{suffix}"
                suffix += 1
            competitions[competition_id] = record
            have.add(country)
            added.append((competition_id, country, record["label"]))
    print(f"added {len(added)} cups")
    for row in added:
        print("  ", row[0], "|", row[1], "|", row[2])
    if not args.dry_run:
        ASSET.write_text(json.dumps(payload, ensure_ascii=False, indent=1),
                         encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
