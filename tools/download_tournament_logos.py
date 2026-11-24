#!/usr/bin/env python3
"""Download the official tournament logos from Transfermarkt into the data root.

The mapping (`assets/data/tournament_logos.json`) is tracked; the PNG files go
to `data/raster/tournaments/<id>.png`, which is gitignored. Missing logos stay
missing and the UI falls back to a generated monogram.

Sources:
  * leagues  - the league id is the Transfermarkt competition code (GB1 -> gb1.png)
  * cups     - resolved by name through the local Transfermarkt API, with a
               manual override map for the names the search gets wrong
  * continental - fixed Transfermarkt codes

Usage:  python tools/download_tournament_logos.py [--dry-run]
"""
import argparse
import json
import re
import sqlite3
import sys
import unicodedata
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSET = ROOT / "assets" / "data" / "tournament_logos.json"
DATABASE = ROOT / "data" / "databases" / "default" / "open_football.sqlite"
OUT = ROOT / "data" / "raster" / "tournaments"
API = "http://127.0.0.1:8001"
LOGO = "https://img.a.transfermarkt.technology/logo/header/{}.png"

CONTINENTAL = {
    "ucl": "CL", "uel": "EL", "uecl": "UCOL",
    "libertadores": "CLI", "sudamericana": "CS", "recopa": "RECO",
    "champions_cup": "CCL", "acl_elite": "ACLE", "acl_two": "ACL2",
    "afc_challenge_league": "AFCP",
}

# Names the TM search resolves badly.
OVERRIDES = {
    "FA Cup": "FAC", "Copa del Rey": "CDR", "Coppa Italia": "CIT",
    "DFB-Pokal": "DFB", "Coupe de France": "FRC", "Taça de Portugal": "POPO",
    "KNVB Beker": "NLP", "Scottish Cup": "SFA", "Supercopa de España": "SCI",
}


def norm(text: str) -> str:
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode()
    return re.sub(r"\s+", " ", re.sub(r"[^a-z0-9 ]", " ", text.lower())).strip()


def head(url: str):
    try:
        request = urllib.request.Request(url, method="HEAD")
        with urllib.request.urlopen(request, timeout=20) as response:
            return response.status, int(response.headers.get("Content-Length") or 0)
    except Exception:
        return None, 0


def search(name: str) -> str:
    try:
        with urllib.request.urlopen(API + "/competitions/search/" +
                                    urllib.parse.quote(name), timeout=40) as response:
            data = json.loads(response.read().decode("utf-8"))
    except Exception:
        return ""
    wanted = norm(name)
    for row in data.get("results") or []:
        if norm(str(row.get("name", ""))) == wanted:
            return str(row.get("id", ""))
    return ""


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
    mapping = {}
    missing = []
    database = sqlite3.connect(DATABASE)
    for league_id, in database.execute("select id from leagues order by id"):
        code = str(league_id)
        if code == "NAT":
            continue
        url = LOGO.format(code.lower())
        status, _ = head(url)
        if status == 200:
            mapping[code] = url
        else:
            missing.append(code)
    competitions = json.loads((ROOT / "assets" / "data" / "competitions.json")
                              .read_text(encoding="utf-8"))["competitions"]
    for competition_id, record in competitions.items():
        label = str(record.get("label", ""))
        code = OVERRIDES.get(label) or search(label)
        if not code:
            missing.append(competition_id)
            continue
        url = LOGO.format(code.lower())
        status, _ = head(url)
        if status == 200:
            mapping[competition_id] = url
        else:
            missing.append(competition_id)
    for competition_id, code in CONTINENTAL.items():
        url = LOGO.format(code.lower())
        status, _ = head(url)
        if status == 200:
            mapping[competition_id] = url
        else:
            missing.append(competition_id)
    downloaded = 0
    if not args.dry_run:
        for competition_id, url in mapping.items():
            if download(url, OUT / f"{competition_id}.png"):
                downloaded += 1
        ASSET.write_text(json.dumps(mapping, ensure_ascii=False, indent=1, sort_keys=True),
                         encoding="utf-8", newline="\n")
    print(f"mapped {len(mapping)}, downloaded {downloaded}, missing {len(missing)}")
    print("missing:", missing)


if __name__ == "__main__":
    main()
