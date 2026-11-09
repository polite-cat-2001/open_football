#!/usr/bin/env python3
"""Build the unified `open_football.sqlite` from the game database and the career canon.

The game's `database.sqlite` and the career prototype's `canon.db` describe the
same clubs and players (transfermarkt ids). This tool merges them into one
read-only database for the whole game:

  * one primary key per entity: `id` = transfermarkt id (leagues use their
    transfermarkt competition code, e.g. `MEXA`);
  * club/player identity, formation, tactics, kits, faces and match fields come
    from the game database;
  * market values, potential, overall, birth dates, shirt numbers, stadiums,
    league tiers and free agents come from canon;
  * duplicate "club row + national-team row" players collapse into one row.

Outputs next to the database: eligibility (team picker) and a manifest.
The tool is a dev-time build step; the game only reads the produced files.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import sqlite3
import sys
from pathlib import Path

DEFAULT_DATA_ROOT = Path(__file__).resolve().parent.parent / "data"
DEFAULT_CANON = Path(
    r"C:/Users/Egor/Desktop/projects/gf-career-prototype/canon.db"
)
GAME_DATABASE = Path("databases/default/database.sqlite")
OUTPUT_DATABASE = Path("databases/default/open_football.sqlite")
OUTPUT_ELIGIBILITY = Path("databases/default/open_football_eligibility.json")
OUTPUT_MANIFEST = Path("databases/default/open_football_manifest.json")

INTERNATIONAL_ID = 1
INTERNATIONAL_NAME = "International"
NATIONAL_LEAGUE_ID = "NAT"
NATIONAL_LEAGUE_NAME = "National Teams"
MIN_MATCH_PLAYERS = 11
SNAPSHOT_FALLBACK = "2026-09-09"

# Canon roles -> the game's role vocabulary (ST/LW/RW are used by the match).
ROLE_MAP = {"CF": "ST", "LM": "LM", "RM": "RM"}


SCHEMA = """
create table countries (
    id integer primary key,
    name text not null,
    flag text
);

create table leagues (
    id text primary key,
    legacy_id integer,
    name text not null,
    country_id integer,
    tier integer,
    tier_rank integer,
    tier_name text,
    logo_url text
);

create table teams (
    id integer primary key,
    league_id text not null,
    country_id integer,
    name text not null,
    shortname text,
    color1 text,
    color2 text,
    colors text,
    logo_url text,
    career_logo text,
    kit_url text,
    formation_xml text,
    formation_factory_xml text,
    tactics_xml text,
    tactics_factory_xml text,
    stadium_name text,
    stadium_seats integer,
    founded_on text
);

create table players (
    id integer primary key,
    team_id integer,
    nationalteam_id integer,
    name text not null,
    firstname text,
    lastname text,
    birth_date text,
    age integer,
    role text,
    career_role text,
    position text,
    position_other text,
    height real,
    height_cm integer,
    weight real,
    foot text,
    strong_foot integer,
    weak_foot integer,
    skill_moves integer,
    citizenship text,
    shirt_number integer,
    market_value integer,
    overall real,
    pot real,
    base_stat real,
    profile_xml text,
    stats text,
    skincolor integer,
    hairstyle text,
    haircolor text,
    formationorder integer,
    nationalteamformationorder integer
);

create table meta (
    key text primary key,
    value text
);

create index idx_leagues_country on leagues(country_id);
create index idx_teams_league on teams(league_id);
create index idx_teams_country on teams(country_id);
create index idx_players_team on players(team_id);
create index idx_players_national on players(nationalteam_id);
"""


def connect_read_only(path: Path) -> sqlite3.Connection:
    connection = sqlite3.connect(f"file:{path.as_posix()}?mode=ro", uri=True)
    connection.row_factory = sqlite3.Row
    return connection


def json_list(value) -> list:
    if not value:
        return []
    try:
        parsed = json.loads(value)
    except (TypeError, json.JSONDecodeError):
        return []
    return parsed if isinstance(parsed, list) else []


def age_from_birth_date(birth_date: str | None, reference: str) -> int | None:
    if not birth_date:
        return None
    try:
        born = dt.date.fromisoformat(birth_date)
        ref = dt.date.fromisoformat(reference)
    except ValueError:
        return None
    return ref.year - born.year - ((ref.month, ref.day) < (born.month, born.day))


def synth_profile_xml(stats: str | None) -> str:
    if not stats:
        return ""
    try:
        values = json.loads(stats)
    except json.JSONDecodeError:
        return ""
    if not isinstance(values, dict):
        return ""
    return "".join(
        f"<{key}>{max(0.0, min(1.0, float(value) / 100.0)):.6f}</{key}>"
        for key, value in values.items()
    )


def load_game(game: sqlite3.Connection) -> dict:
    leagues = {}
    national_league_game_id = -1
    for row in game.execute("select id, name, country_id, tier, tm_id, logo_url from leagues"):
        if row["name"] == NATIONAL_LEAGUE_NAME:
            national_league_game_id = int(row["id"])
        tm_id = str(row["tm_id"] or "").strip()
        if tm_id:
            leagues[tm_id] = dict(row)

    teams = {}
    for row in game.execute("select * from teams"):
        tm_id = str(row["tm_id"] or "").strip()
        if tm_id:
            teams[tm_id] = dict(row)

    if national_league_game_id < 0:
        raise SystemExit("game database has no 'National Teams' league")

    players: dict[str, dict] = {}
    for row in game.execute("select * from players"):
        tm_id = str(row["tm_id"] or "").strip()
        if not tm_id:
            continue
        bucket = players.setdefault(tm_id, {})
        if row["team_id"] is not None:
            bucket["club"] = dict(row)
        else:
            bucket["national"] = dict(row)
    return {
        "leagues": leagues,
        "teams": teams,
        "players": players,
        "national_league_game_id": national_league_game_id,
    }


def load_canon(canon: sqlite3.Connection) -> dict:
    return {
        "countries": [dict(row) for row in canon.execute(
            "select id, name, flag from countries order by name")],
        "leagues": [dict(row) for row in canon.execute(
            "select id, name, country_id, tier, tier_rank, logo from leagues "
            "order by country_id, tier_rank, name")],
        "clubs": [dict(row) for row in canon.execute(
            "select id, name, league_id, country_id, logo, colors, stadium_name, "
            "stadium_seats, founded_on from clubs order by id")],
        "players": [dict(row) for row in canon.execute(
            "select id, name, first_name, last_name, birth_date, height, foot, "
            "citizenship, position, position_other, club_id, national_team_id, "
            "shirt_number, market_value, overall, pot, weight, weak_foot, "
            "skill_moves, role, stats from players order by id")],
        "national_teams": {str(row["id"]): dict(row) for row in canon.execute(
            "select id, name, flag from national_teams")},
        "meta": {row["key"]: row["value"] for row in canon.execute(
            "select key, value from meta")},
    }


def build_countries(connection: sqlite3.Connection, canon: dict) -> int:
    rows = [(int(row["id"]), row["name"], row["flag"]) for row in canon["countries"]]
    if not any(row[0] == INTERNATIONAL_ID for row in rows):
        rows.append((INTERNATIONAL_ID, INTERNATIONAL_NAME, None))
    connection.executemany(
        "insert into countries (id, name, flag) values (?, ?, ?)", rows)
    return len(rows)


def build_leagues(connection: sqlite3.Connection, canon: dict, game: dict) -> int:
    count = 0
    for row in canon["leagues"]:
        code = str(row["id"])
        gpf = game["leagues"].get(code, {})
        connection.execute(
            "insert into leagues (id, legacy_id, name, country_id, tier, tier_rank, "
            "tier_name, logo_url) values (?, ?, ?, ?, ?, ?, ?, ?)",
            (
                code,
                int(gpf["id"]) if gpf else None,
                row["name"],
                int(row["country_id"]),
                int(gpf["tier"]) if gpf else 99,
                int(row["tier_rank"] or 99),
                row["tier"],
                gpf.get("logo_url", ""),
            ),
        )
        count += 1
    connection.execute(
        "insert into leagues (id, legacy_id, name, country_id, tier, tier_rank, "
        "tier_name, logo_url) values (?, 280, ?, null, 100, 99, ?, ?)",
        (NATIONAL_LEAGUE_ID, NATIONAL_LEAGUE_NAME, NATIONAL_LEAGUE_NAME,
         "media/textures/nationalteams.png"),
    )
    return count + 1


def build_teams(connection: sqlite3.Connection, canon: dict, game: dict) -> int:
    rows = []
    for club in canon["clubs"]:
        team_id = str(club["id"])
        gpf = game["teams"].get(team_id, {})
        rows.append((
            int(team_id),
            str(club["league_id"]),
            int(club["country_id"]),
            club["name"],
            gpf.get("shortname", ""),
            gpf.get("color1", ""),
            gpf.get("color2", ""),
            club["colors"],
            gpf.get("logo_url", ""),
            club["logo"],
            gpf.get("kit_url", ""),
            gpf.get("formation_xml", ""),
            gpf.get("formation_factory_xml", ""),
            gpf.get("tactics_xml", ""),
            gpf.get("tactics_factory_xml", ""),
            club["stadium_name"],
            club["stadium_seats"],
            club["founded_on"],
        ))
    for team_id, gpf in game["teams"].items():
        if int(gpf["league_id"]) != game["national_league_game_id"]:
            continue
        rows.append((
            int(team_id),
            NATIONAL_LEAGUE_ID,
            None,
            gpf["name"],
            gpf.get("shortname", ""),
            gpf.get("color1", ""),
            gpf.get("color2", ""),
            None,
            gpf.get("logo_url", ""),
            None,
            gpf.get("kit_url", ""),
            gpf.get("formation_xml", ""),
            gpf.get("formation_factory_xml", ""),
            gpf.get("tactics_xml", ""),
            gpf.get("tactics_factory_xml", ""),
            None,
            None,
            None,
        ))
    connection.executemany(
        "insert into teams (id, league_id, country_id, name, shortname, color1, "
        "color2, colors, logo_url, career_logo, kit_url, formation_xml, "
        "formation_factory_xml, tactics_xml, tactics_factory_xml, stadium_name, "
        "stadium_seats, founded_on) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, "
        "?, ?, ?, ?, ?, ?)",
        rows,
    )
    return len(rows)


def build_players(connection: sqlite3.Connection, canon: dict, game: dict,
                  reference_date: str) -> tuple[int, int]:
    rows = []
    synthesised = 0
    for player in canon["players"]:
        player_id = str(player["id"])
        bucket = game["players"].get(player_id, {})
        club = bucket.get("club")
        national = bucket.get("national")
        base = club or national
        if base is None:
            synthesised += 1
            firstname, lastname = player["first_name"], player["last_name"]
        else:
            firstname = base.get("firstname") or ""
            lastname = base.get("lastname") or ""
        birth_date = player["birth_date"]
        age = base.get("age") if base else age_from_birth_date(
            birth_date, reference_date)
        height_cm = int(player["height"] or 0)
        height = float(base["height"]) if base and base.get("height") else (
            round(height_cm / 100.0, 2) if height_cm else None)
        weight = float(base["weight"]) if base and base.get("weight") else player["weight"]
        role = base.get("role") if base and base.get("role") else ROLE_MAP.get(
            player["role"], player["role"])
        carrier = national or club
        if base is None:
            base_stat = round(float(player["overall"] or 0) / 100.0, 6)
            profile_xml = synth_profile_xml(player["stats"])
            skincolor = 1
            hairstyle = ""
            haircolor = ""
            strong_foot = 0
            formationorder = 0
            nationalteamformationorder = 0
        else:
            base_stat = float(base.get("base_stat") or 0.0)
            profile_xml = base.get("profile_xml") or ""
            skincolor = int(base.get("skincolor") or 1)
            hairstyle = base.get("hairstyle") or ""
            haircolor = base.get("haircolor") or ""
            strong_foot = int(base.get("strong_foot") or 0)
            formationorder = int(base.get("formationorder") or 0)
            nationalteamformationorder = int(
                (carrier or {}).get("nationalteamformationorder") or 0)
        rows.append((
            int(player_id),
            int(player["club_id"]) if player["club_id"] else None,
            int(player["national_team_id"]) if player["national_team_id"] else None,
            player["name"],
            firstname,
            lastname,
            birth_date,
            age,
            role,
            player["role"],
            player["position"],
            player["position_other"],
            height,
            height_cm or None,
            weight,
            player["foot"],
            strong_foot,
            player["weak_foot"],
            player["skill_moves"],
            player["citizenship"],
            player["shirt_number"],
            player["market_value"],
            player["overall"],
            player["pot"],
            base_stat,
            profile_xml,
            player["stats"],
            skincolor,
            hairstyle,
            haircolor,
            formationorder,
            nationalteamformationorder,
        ))
    connection.executemany(
        "insert into players (id, team_id, nationalteam_id, name, firstname, "
        "lastname, birth_date, age, role, career_role, position, position_other, "
        "height, height_cm, weight, foot, strong_foot, weak_foot, skill_moves, "
        "citizenship, shirt_number, market_value, overall, pot, base_stat, "
        "profile_xml, stats, skincolor, hairstyle, haircolor, formationorder, "
        "nationalteamformationorder) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, "
        "?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        rows,
    )
    return len(rows), synthesised


def count_players(connection: sqlite3.Connection, column: str) -> list[int]:
    return [
        int(row[0])
        for row in connection.execute(
            f"select {column} from players where {column} is not null "
            f"group by {column} having count(*) >= ? order by {column}",
            (MIN_MATCH_PLAYERS,),
        )
    ]


def write_json(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, separators=(",", ":")), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data-root", type=Path, default=DEFAULT_DATA_ROOT)
    parser.add_argument("--canon", type=Path, default=DEFAULT_CANON)
    parser.add_argument("--output", type=Path, default=None)
    args = parser.parse_args()

    data_root = args.data_root.resolve()
    game_path = data_root / GAME_DATABASE
    output = args.output or (data_root / OUTPUT_DATABASE)
    if not game_path.is_file():
        raise SystemExit(f"game database not found: {game_path}")
    if not args.canon.is_file():
        raise SystemExit(f"canon database not found: {args.canon}")

    game = connect_read_only(game_path)
    canon = connect_read_only(args.canon)
    try:
        game_rows = load_game(game)
        canon_rows = load_canon(canon)
    finally:
        game.close()
        canon.close()

    snapshot = canon_rows["meta"].get("source_snapshot_date") or SNAPSHOT_FALLBACK
    temp = output.with_suffix(".building")
    if temp.exists():
        temp.unlink()
    connection = sqlite3.connect(str(temp))
    try:
        connection.execute("pragma journal_mode = off")
        connection.execute("pragma synchronous = off")
        connection.executescript(SCHEMA)
        with connection:
            countries = build_countries(connection, canon_rows)
            leagues = build_leagues(connection, canon_rows, game_rows)
            teams = build_teams(connection, canon_rows, game_rows)
            players, synthesised = build_players(
                connection, canon_rows, game_rows, snapshot)
            connection.executemany(
                "insert into meta (key, value) values (?, ?)",
                [
                    ("schema_version", "1"),
                    ("source_snapshot_date", snapshot),
                    ("built_at", dt.datetime.now(dt.timezone.utc).isoformat()),
                    ("countries", str(countries)),
                    ("leagues", str(leagues)),
                    ("teams", str(teams)),
                    ("players", str(players)),
                    ("synthesised_players", str(synthesised)),
                ],
            )
        club_ids = count_players(connection, "team_id")
        national_ids = count_players(connection, "nationalteam_id")
        connection.commit()
    finally:
        connection.close()

    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        output.unlink()
    temp.replace(output)
    write_json(output.parent / OUTPUT_ELIGIBILITY.name,
               {"version": 1, "club": club_ids, "national": national_ids})
    write_json(output.parent / OUTPUT_MANIFEST.name, {
        "schema_version": 1,
        "data_version": snapshot,
        "coverage": {
            "countries": countries,
            "leagues": leagues,
            "teams": teams,
            "players": players,
            "clubs": len(canon_rows["clubs"]),
            "national_teams": teams - len(canon_rows["clubs"]),
        },
    })
    print(f"wrote {output}")
    print(f"  countries={countries} leagues={leagues} teams={teams} "
          f"players={players} synthesised={synthesised}")
    print(f"  clubs={len(club_ids)} national={len(national_ids)} fieldable")
    print(f"wrote {output.parent / OUTPUT_ELIGIBILITY.name}")
    print(f"wrote {output.parent / OUTPUT_MANIFEST.name}")


if __name__ == "__main__":
    main()
