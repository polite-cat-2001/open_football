# -*- coding: utf-8 -*-
"""Drop the Supercopa Peruana: its cup has not been played since 2021.

The record pairs the Liga 1 champion with the Copa Bicentenario winner, and that
competition stopped in 2021, so the super cup has no real second participant. The
engine therefore never builds it. Keeping a tournament that cannot exist is worse
than not having it; the cup itself (CBII) stays, as the rest of the cup research.

Usage:  python tools/drop_defunct_super_cup.py [--dry-run]
"""
import argparse
import io
import json
import sys
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent
COMPETITIONS = ROOT / "assets" / "data" / "competitions.json"
DROPPED = {
    "PUSC": "Supercopa Peruana: the Copa Bicentenario it is paired with has not "
            "been played since 2021, so the super cup has no real participant.",
}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    document = json.loads(COMPETITIONS.read_text(encoding="utf-8"))
    competitions = document["competitions"]
    for competition_id in DROPPED:
        record = competitions.pop(competition_id, None)
        print("dropped", competition_id, "-", (record or {}).get("label", "?"))
    document.setdefault("_dropped", {})
    document["_dropped"].update(DROPPED)
    if not args.dry_run:
        COMPETITIONS.write_text(
            json.dumps(document, ensure_ascii=False, indent=1) + "\n",
            encoding="utf-8", newline="\n")
    print("records now", len(competitions))


if __name__ == "__main__":
    main()
