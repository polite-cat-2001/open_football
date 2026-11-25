# -*- coding: utf-8 -*-
"""Add the Spanish pyramid rows; the totals come from audit_pyramid_totals.py."""
import io
import json
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

PATH = r"C:\Users\Egor\.local\share\opencode\worktree\fa15ca\career-regulations\assets\data\league_pyramids.json"

LEAGUES = {
    "ES1": {"level": 1, "size": 20, "closed_up": True, "closed_down": False,
            "format": {"kind": "single", "rounds": 38}, "playoff": None,
            "country": "Spain", "confidence": "high",
            "note": "LaLiga: 20 clubs, double round-robin, bottom three relegated."},
    "ES2": {"level": 2, "size": 22, "closed_up": False, "closed_down": False,
            "format": {"kind": "single", "rounds": 42},
            "playoff": {"kind": "promotion", "entries": "3rd-6th", "legs": 2,
                        "note": "two-legged semi-finals and final"},
            "country": "Spain", "confidence": "high",
            "note": "LaLiga 2: top two up directly, 3rd-6th play off for the "
                    "third place; the bottom four are relegated."},
}

BOUNDARIES = [
    {"country": "Spain", "upper": 1, "lower": 2,
     "up": 2, "up_playoff": 1, "down": 3, "down_playoff": 0,
     "allocation": "free", "selection": "bottom_n",
     "note": "LaLiga 2: top two promoted directly, 3rd-6th play off for the "
             "third place. LaLiga: bottom three relegated, no play-out.",
     "confidence": "high"},
    {"country": "Spain", "upper": 2, "lower": 3,
     "up": 4, "up_playoff": 2, "down": 4, "down_playoff": 0,
     "allocation": "free", "selection": "bottom_n",
     "note": "Primera Federación: the two group champions go up directly and "
             "the two play-off winners join them. LaLiga 2: the bottom four "
             "are relegated.",
     "confidence": "high"},
]

# Two rows whose note states a range are settled on the number the game needs:
# the floor of the range for Poland (4 guaranteed each way) and the resolved
# 3/3 of 2026-27 for Ukraine. The Dutch L3-4 row stays unverified (2-3 each way).
def main() -> None:
    document = json.load(open(PATH, encoding="utf-8"))
    leagues = document["leagues"]
    for league_id, row in LEAGUES.items():
        leagues.setdefault(league_id, row)
    known = {(row["country"], row["upper"], row["lower"])
             for row in document["boundaries"]}
    for row in BOUNDARIES:
        if (row["country"], row["upper"], row["lower"]) not in known:
            document["boundaries"].append(row)
    open(PATH, "w", encoding="utf-8", newline="\n").write(
        json.dumps(document, ensure_ascii=False, indent=1) + "\n")
    print("leagues:", len(leagues), "boundaries:", len(document["boundaries"]))
    for row in document["boundaries"]:
        if row.get("totals_source") == "unverified":
            print("  still unverified: %s L%s-%s" % (
                row["country"], row["upper"], row["lower"]))


if __name__ == "__main__":
    main()
