#!/usr/bin/env python3
"""Match a Wikipedia "Teams" table to open_football.sqlite club ids.

The data is only a starting point: every unmatched club is printed with its
closest database candidates and must be resolved by hand (see ALIASES). The
matched rows feed assets/data/continental_2026.json.

Usage:
  python tools/build_continental_field.py --page <saved.md> --section Teams \
      --end Schedule --db data/databases/default/open_football.sqlite
"""
import argparse
import difflib
import io
import json
import re
import sqlite3
import sys
import unicodedata

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

# Source name -> database name, for clubs whose English Wikipedia name differs.
ALIASES = {
    ("Argentina", "Platense"): "Club Atlético Platense",
    ("Argentina", "Estudiantes"): "Club Estudiantes de La Plata",
    ("Argentina", "Racing"): "Racing Club de Avellaneda",
    ("Brazil", "Corinthians"): "Sport Club Corinthians Paulista",
    ("Brazil", "Palmeiras"): "Sociedade Esportiva Palmeiras",
    ("Brazil", "Cruzeiro"): "Cruzeiro Esporte Clube",
    ("Brazil", "Mirassol"): "Mirassol Futebol Clube (SP)",
    ("Brazil", "Bahia"): "Esporte Clube Bahia",
    ("Brazil", "Botafogo"): "Botafogo de Futebol e Regatas",
    ("Brazil", "São Paulo"): "São Paulo FC",
    ("Paraguay", "Libertad"): "Club Libertad Asunción",
    ("Colombia", "Santa Fe"): "Independiente Santa Fe",
    ("Uruguay", "Racing"): "Racing Club de Montevideo",
    ("Uruguay", "Nacional"): "Club Nacional de Football",
    ("Paraguay", "Nacional"): "Club Nacional Asunción",
    ("Argentina", "Tigre"): "Club Atlético Tigre",
    ("Bolivia", "Blooming"): "Blooming Santa Cruz",
    ("Bolivia", "Guabirá"): "Club Deportivo Guabirá",
    ("Brazil", "São Paulo"): "São Paulo Futebol Clube",
    ("Brazil", "Grêmio"): "Grêmio Foot-Ball Porto Alegrense",
}

STAGES = {
    "group stage": "group_stage",
    "first stage": "first_stage",
    "second stage": "second_stage",
    "third stage": "third_stage",
    "league stage": "league_stage",
    "play-off round": "playoff",
    "playoff": "playoff",
    "preliminary stage": "preliminary",
    "qualifying stage": "qualifying_stage",
    "round of 16": "round_of_16",
    "round one": "round_one",
}

LINK = re.compile(r"\[([^\]]+)\]\([^)]*\)")


def norm(text: str) -> str:
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode()
    return re.sub(r"\s+", " ", re.sub(r"[^a-z0-9 ]", " ", text.lower())).strip()


def stage_of(text: str) -> str:
    value = norm(text)
    for label, slug in STAGES.items():
        if norm(label) == value:
            return slug
    return ""


def parse(page: str, section: str, end: str) -> list:
    text = open(page, encoding="utf-8").read()
    start = text.find(section)
    stop = text.find(end, start + len(section)) if end else -1
    body = text[start:stop] if stop > 0 else text[start:]
    rows, association, last_stage = [], "", ""
    for line in body.splitlines():
        line = line.strip()
        if "|" not in line:
            continue
        cells = [cell.strip() for cell in line.strip("|").split("|")]
        stage = ""
        club_cell = ""
        assoc_cell = ""
        if len(cells) >= 4:
            assoc_cell, club_cell, stage_cell = cells[0], cells[1], cells[2]
            stage = stage_of(LINK.sub(lambda m: m.group(1), stage_cell))
        elif len(cells) == 2:
            club_cell = cells[0]
            stage = stage_of(LINK.sub(lambda m: m.group(1), cells[1]))
        else:
            continue
        if stage:
            last_stage = stage
        else:
            stage = last_stage
        clubs = LINK.findall(club_cell)
        club = clubs[-1] if clubs else re.sub(r"\(.*?\)", "", club_cell)
        assocs = LINK.findall(assoc_cell)
        if assocs:
            association = assocs[-1]
        if not club or norm(club) in ("team", "association"):
            continue
        rows.append({"association": association, "club": club.strip(),
                     "stage": stage})
    return rows


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--page", required=True)
    parser.add_argument("--section", default="## Teams")
    parser.add_argument("--end", default="## Schedule")
    parser.add_argument("--db", required=True)
    parser.add_argument("--out", default="")
    args = parser.parse_args()

    rows = parse(args.page, args.section, args.end)
    connection = sqlite3.connect(args.db)
    teams = connection.execute(
        "select t.id, t.name, c.name from teams t "
        "left join countries c on c.id = t.country_id").fetchall()
    by_country = {}
    for club_id, name, country in teams:
        if name.endswith((" U19", " U21", " II")) or not country:
            continue
        by_country.setdefault(country, []).append((str(club_id), name))

    matched, missing = [], []
    for row in rows:
        alias = ALIASES.get((row["association"], row["club"]))
        pool = by_country.get(row["association"], [])
        names = [name for _, name in pool]
        hit = ""
        if alias and alias in names:
            hit = alias
        else:
            found = difflib.get_close_matches(norm(row["club"]),
                                              [norm(name) for name in names],
                                              n=1, cutoff=0.6)
            if found:
                hit = names[[norm(name) for name in names].index(found[0])]
        entry = dict(row)
        if hit:
            entry["id"] = next(club_id for club_id, name in pool if name == hit)
            entry["db_name"] = hit
            matched.append(entry)
        else:
            entry["candidates"] = [name for _, name in pool][:12]
            missing.append(entry)

    print(f"rows {len(rows)} matched {len(matched)} missing {len(missing)}")
    for entry in matched:
        print(f"  {entry['stage'] or '?':15} {entry['association']:12} "
              f"{entry['club']:28} -> {entry['id']} {entry['db_name']}")
    for entry in missing:
        print(f"  MISS {entry['association']:12} {entry['club']:28} "
              f"have: {', '.join(entry['candidates'])}")
    if args.out:
        with open(args.out, "w", encoding="utf-8") as handle:
            json.dump({"matched": matched, "missing": missing}, handle,
                      ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
