#!/usr/bin/env python3
"""Copy the prototype's flag/crest/league images into the game data tree.

The GameplayFootball data snapshot ships without `images_teams`,
`images_leagues` or `images_countries`.  The gf-ui-prototype checkout has a
complete raster set; its IDs are not the same as the game database, so this
tool matches rows by (normalized name, country) and copies:

    <prototype>/data/raster/teams_emblems/<id>.png
        -> <data>/databases/default/images_teams/<game team id>.png
    <prototype>/data/raster/teams_flags/<id>.png
        -> ... (national teams without an emblem)
    <prototype>/data/raster/leagues/<canon league id>.png
        -> <data>/databases/default/images_leagues/<game league id>.png
    <prototype>/data/raster/country_flags/<canon country id>.png
        -> <data>/databases/default/images_countries/<tm_id>.png

Run it once after refreshing either data tree:

    python tools/import_prototype_images.py
    python tools/import_prototype_images.py --force

The images stay outside git (the game data tree is external).  `UiAssets`
looks in the standard `logo_url` path first, then in these imported folders.
"""

from __future__ import annotations

import argparse
import os
import shutil
import sqlite3
from pathlib import Path

DEFAULT_PROTOTYPE = Path("C:/Users/Egor/Desktop/projects/gf-ui-prototype")
DEFAULT_DATA = Path("C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data")
DATABASE = "databases/default/database.sqlite"
CANON_DATABASE = "canon.db"


def key(name) -> str:
    return " ".join(str(name or "").strip().lower().split())


def country_key(name, country) -> tuple[str, str]:
    return (key(name), key(country))


def open_readonly(path: Path) -> sqlite3.Connection:
    connection = sqlite3.connect(f"file:{path.as_posix()}?mode=ro", uri=True)
    connection.row_factory = sqlite3.Row
    return connection


def relative_raster(path: str) -> str:
    return str(path or "").replace("/raster/", "", 1)


def copy_image(source: Path, destination: Path, force: bool) -> str:
    if not source.is_file():
        return "missing"
    if destination.is_file() and not force:
        return "existing"
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)
    return "copied"


def load_country_names(connection: sqlite3.Connection, table: str) -> dict[int, str]:
    return {
        int(row["id"]): str(row["name"])
        for row in connection.execute(f"select id, name from {table}")
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prototype-root", type=Path,
                        default=Path(os.environ.get("GF_UI_PROTOTYPE_ROOT", DEFAULT_PROTOTYPE)))
    parser.add_argument("--data-root", type=Path,
                        default=Path(os.environ.get("GPF_DATA_ROOT", DEFAULT_DATA)))
    parser.add_argument("--force", action="store_true", help="overwrite existing images")
    parser.add_argument("--dry-run", action="store_true", help="only report what would be copied")
    args = parser.parse_args()

    game_db = args.data_root / DATABASE
    canon_db = args.prototype_root / CANON_DATABASE
    raster = args.prototype_root / "data" / "raster"
    if not game_db.is_file():
        print(f"game database not found: {game_db}")
        return 1
    if not canon_db.is_file():
        print(f"prototype canon.db not found: {canon_db}")
        return 1

    game = open_readonly(game_db)
    canon = open_readonly(canon_db)
    game_countries = load_country_names(game, "countries")
    canon_countries = load_country_names(canon, "countries")

    game_leagues = {
        int(row["id"]): (str(row["name"]), game_countries.get(int(row["country_id"] or 0), ""))
        for row in game.execute("select id, name, country_id from leagues")
    }
    canon_league_by_key = {
        country_key(name, country): str(row["logo"] or "")
        for row in canon.execute("select id, name, country_id, logo from leagues")
        for name, country in [(str(row["name"]), canon_countries.get(int(row["country_id"] or 0), ""))]
    }
    canon_club_by_key = {
        country_key(row["name"], canon_countries.get(int(row["country_id"] or 0), "")): str(row["logo"] or "")
        for row in canon.execute("select id, name, country_id, logo from clubs")
    }
    canon_national: dict[str, tuple[str, str]] = {}
    for row in canon.execute("select id, name, flag from national_teams"):
        national_id = str(row["id"])
        emblem = raster / "teams_emblems" / f"{national_id}.png"
        image = f"/raster/teams_emblems/{national_id}.png" if emblem.is_file() else str(row["flag"] or "")
        canon_national[key(row["name"])] = (national_id, image)

    stats = {"teams": {"copied": 0, "existing": 0, "missing": 0},
             "leagues": {"copied": 0, "existing": 0, "missing": 0},
             "countries": {"copied": 0, "existing": 0, "missing": 0}}
    missing_teams: list[str] = []
    missing_leagues: list[str] = []

    for row in game.execute("select id, name, league_id from teams"):
        team_id = int(row["id"])
        league = game_leagues.get(int(row["league_id"] or 0), ("", ""))
        club_image = canon_club_by_key.get(country_key(row["name"], league[1]))
        national = canon_national.get(key(row["name"]))
        if club_image:
            image = club_image
        elif national:
            image = national[1]
        else:
            stats["teams"]["missing"] += 1
            missing_teams.append(str(row["name"]))
            continue
        source = raster / relative_raster(image)
        destination = args.data_root / "databases" / "default" / "images_teams" / f"{team_id}.png"
        if args.dry_run:
            result = "missing" if not source.is_file() else (
                "existing" if destination.is_file() and not args.force else "copied")
        else:
            result = copy_image(source, destination, args.force)
        stats["teams"][result] += 1

    for league_id, (name, country) in game_leagues.items():
        image = canon_league_by_key.get(country_key(name, country))
        if not image:
            stats["leagues"]["missing"] += 1
            missing_leagues.append(name)
            continue
        source = raster / relative_raster(image)
        destination = args.data_root / "databases" / "default" / "images_leagues" / f"{league_id}.png"
        if args.dry_run:
            result = "missing" if not source.is_file() else (
                "existing" if destination.is_file() and not args.force else "copied")
        else:
            result = copy_image(source, destination, args.force)
        stats["leagues"][result] += 1

    canon_country_by_name = {
        key(row["name"]): str(row["flag"] or "")
        for row in canon.execute("select name, flag from countries")
    }
    for row in game.execute("select id, name, tm_id from countries"):
        tm_id = str(row["tm_id"] or "")
        image = canon_country_by_name.get(key(row["name"]))
        if not tm_id or not image:
            stats["countries"]["missing"] += 1
            continue
        source = raster / relative_raster(image)
        destination = args.data_root / "databases" / "default" / "images_countries" / f"{tm_id}.png"
        if args.dry_run:
            result = "missing" if not source.is_file() else (
                "existing" if destination.is_file() and not args.force else "copied")
        else:
            result = copy_image(source, destination, args.force)
        stats["countries"][result] += 1

    print(f"prototype: {args.prototype_root}")
    print(f"data root: {args.data_root}")
    for category in ("teams", "leagues", "countries"):
        values = stats[category]
        print(f"{category}: copied={values['copied']} existing={values['existing']} "
              f"missing={values['missing']}")
    if missing_teams:
        print(f"teams without a prototype image: {len(missing_teams)} "
              f"({', '.join(ascii(name) for name in missing_teams[:8])})")
    if missing_leagues:
        print(f"leagues without a prototype image: {len(missing_leagues)} "
              f"({', '.join(ascii(name) for name in missing_leagues[:8])})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
