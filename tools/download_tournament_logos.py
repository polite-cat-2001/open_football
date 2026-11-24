#!/usr/bin/env python3
"""Download the official tournament logos from Transfermarkt.

Every tournament id is a Transfermarkt competition code (see
`tools/rename_tournament_ids.py`), so the logo URL is built from the id itself:
`GB1` -> `logo/header/gb1.png`. The mapping (`assets/data/tournament_logos.json`)
is tracked; the PNG files go to `data/raster/tournaments/<id>.png`, which is
gitignored. A competition Transfermarkt has no logo for stays missing and the UI
falls back to a generated monogram.

Usage:  python tools/download_tournament_logos.py [--dry-run]
"""
import argparse
import json
import sqlite3
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSET = ROOT / "assets" / "data" / "tournament_logos.json"
DATABASE = ROOT / "data" / "databases" / "default" / "open_football.sqlite"
OUT = ROOT / "data" / "raster" / "tournaments"
LOGO = "https://img.a.transfermarkt.technology/logo/header/{}.png"

# Continental competitions; they have no record in competitions.json.
CONTINENTAL = ["CL", "EL", "UCOL", "CLI", "CS", "RECO", "CCL", "ACLE", "ACL2",
               "AFCP"]


def head(url: str) -> int:
    try:
        request = urllib.request.Request(url, method="HEAD")
        with urllib.request.urlopen(request, timeout=20) as response:
            return response.status
    except Exception:
        return 0


def download(url: str, target: Path) -> bool:
    if target.exists():
        return True
    try:
        request = urllib.request.Request(url)
        with urllib.request.urlopen(request, timeout=60) as response:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(response.read())
        return True
    except Exception:
        return False


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    ids = [str(row[0]) for row in
           sqlite3.connect(DATABASE).execute("select id from leagues order by id")
           if str(row[0]) != "NAT"]
    competitions = json.loads((ROOT / "assets" / "data" / "competitions.json")
                              .read_text(encoding="utf-8"))["competitions"]
    ids += [str(key) for key in competitions]
    ids += CONTINENTAL

    mapping = {}
    missing = []
    for competition_id in ids:
        url = LOGO.format(competition_id.lower())
        if head(url) == 200:
            mapping[competition_id] = url
        else:
            missing.append(competition_id)
    downloaded = 0
    if not args.dry_run:
        for competition_id, url in mapping.items():
            if download(url, OUT / f"{competition_id}.png"):
                downloaded += 1
        ASSET.write_text(json.dumps(mapping, ensure_ascii=False, indent=1,
                                    sort_keys=True), encoding="utf-8", newline="\n")
    print(f"mapped {len(mapping)}, downloaded {downloaded}, missing {len(missing)}")
    print("missing:", missing)


if __name__ == "__main__":
    main()
