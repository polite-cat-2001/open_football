#!/usr/bin/env python3
"""Rename the tournament ids to their Transfermarkt competition codes.

The leagues already used TM codes as their primary key. The cups, super cups and
continental competitions were written from research with our own keys, so this
one-time script maps them to the TM code of the same competition (resolved
through the TM search index, see the comment on `MISSING`).

After the rename the id *is* the TM code, so the logo downloader no longer has to
search by name and any future data update can join on the id directly.

The rename also bumps `Career.SAVE_VERSION`: a save written with the old keys is
rejected instead of being migrated, because the game has no players yet.

Usage:  python tools/rename_tournament_ids.py [--dry-run]
"""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "assets" / "data"

# Domestic cups.
CUPS = {
    "ESCUP": "CDR", "ENGFA": "FAC", "ENGLC": "CGB", "GERPOK": "DFB",
    "ITACOP": "CIT", "FRACOP": "FRC", "NETHERLANDSCUP": "NLP",
    "PORTUGALCUP": "POPO", "TURKEYCUP": "TRP", "BRAZILCUP": "BRC",
    "ARGENTINACUP": "ARCA", "MEXICOCUP": "CPMX", "USACUP": "MLSP",
    "JAPANCUP": "JEMP", "CHINACUP": "CHFA", "EGYPTCUP": "EGYP",
    "SAUDIARABIACUP": "SAKC", "AUSTRALIACUP": "FFAC", "ALBANIACUP": "ALBP",
    "ANDORRACUP": "ANDP", "ARMENIACUP": "ARPO", "AUSTRIACUP": "ofb",
    "AZERBAIJANCUP": "ASPK", "BELARUSCUP": "WRPO", "BELGIUMCUP": "CCB",
    "BULGARIACUP": "BULP", "CROATIACUP": "KRC", "CYPRUSCUP": "CPO1",
    "CZECHREPUBLICCUP": "TSP", "DENMARKCUP": "DKP", "ESTONIACUP": "ESTP",
    "FAROEISLANDSCUP": "FAPO", "FINLANDCUP": "FIS", "GEORGIACUP": "GEP1",
    "GIBRALTARCUP": "GIRC", "GREECECUP": "GRP", "HUNGARYCUP": "UNGP",
    "ICELANDCUP": "ISP", "ISRAELCUP": "ISPO", "KAZAKHSTANCUP": "KAZP",
    "KOSOVOCUP": "KOP1", "LATVIACUP": "LETP", "LITHUANIACUP": "LTVP",
    "LUXEMBOURGCUP": "LUXP", "MALTACUP": "MALC", "MOLDOVACUP": "MWP1",
    "MONTENEGROCUP": "MNEC", "NORTHMACEDONIACUP": "NMAP",
    "NORTHERNIRELANDCUP": "NIRC", "NORWAYCUP": "NOPO", "POLANDCUP": "POPU",
    "IRELANDCUP": "IRPO", "ROMANIACUP": "ROMP", "RUSSIACUP": "RUP",
    "SANMARINOCUP": "SMP1", "SCOTLANDCUP": "SFA", "SERBIACUP": "SERP",
    "SLOVAKIACUP": "SKC", "SLOVENIACUP": "SLP", "SWEDENCUP": "SEC",
    "SWITZERLANDCUP": "SCC", "UKRAINECUP": "UKRP", "WALESCUP": "WALE",
    "BOSNIAANDHERZEGOVINACUP": "BIHP", "LIECHTENSTEINCUP": "LIEP",
    "ALGECUP": "ALGP", "THROCUP": "MARP", "NEDBCUP": "NEDC",
    "TUNICUP": "TUNP", "COPABOLI": "BVC1", "CANACHAM": "CAN",
    "COPACHIL": "CH1C", "COPACOLO": "COPO", "TORNDECOPA": "CRPO",
    "COPAECUA": "ECUP", "COPAPRIM": "CNIC", "COPAPARA": "PYC1",
    "COPABICE": "CBII", "COPAAUFURUG": "URP1", "COPAVENE": "VEC1",
    "TAIWPRESFA": "TWC1", "HONGKONGFA": "HKFA", "AIFFSUPECUP": "INSC",
    "PIALINDO": "INPI", "HAZFCUP": "IRNP", "IRAQFACUP": "IRQC",
    "MALAFACUP": "MYSP", "COPAPAULALCA": "PHPO", "AMIRCUP": "QEC1",
    "SINGCUP": "SINP", "THAIFACUP": "THFA", "UAEPRESS": "UAEP",
    "UZBECUP": "KOBU", "VIETNATICUP": "VPO1", "CHATCUP": "NZP1",
}

# Super cups.
SUPER_CUPS = {
    "ESPSC": "SUC", "ENGCS": "GBCS", "GERSC": "DFL", "ITASC": "SCI",
    "FRASC": "FRCH", "IRANSUP": "IRSC", "IRAQSUP": "IKSC", "THAISUP": "THCC",
    "UZBESUP": "UZSC", "UAESUP": "UASC", "SUPERCOP": "CSUC",
    "SUPERLIG": "COSP", "RECOPADE": "CSC2", "SUPERCOP2": "ECSC",
    "SUPERCOP3": "PYSC", "SUPERCOP4": "PUSC", "SUPERCOP5": "URSC",
    "JORDANSU": "JOSC", "LEBANESE": "LBSC", "PIALASUM": "MYSC",
    "SINGAPOR": "SPCS", "VIETNAME": "VSCU", "SUPERKUP": "ALBS",
    "SUPERCOP7": "ANSC", "ARMENIAN": "ARSC", "SUPERKUB": "WRSP",
    "BELGIANS": "BESC", "SUPERCUP": "BULS", "HRVATSKI": "HRSC",
    "CYPRIOTS": "CYSC", "EESTISUP": "ESTS", "STRSTEYP": "FASC",
    "GEORGIAN": "GESC", "PEPEREYE": "GISC", "SUPERBET": "GRSC",
    "MEISTARA": "ISLS", "ALUFHAAL": "IRLP", "KAZAKHST": "KASC",
    "SUPERKUP2": "SKKO", "LITHUANI": "LTSC", "MALTESES": "MALS",
    "MOLDOVAN": "MOSC", "NIFLCHAR": "NSC", "POLISHSU": "PLSC",
    "PRESIDEN": "IRPC", "SUPERCUP2": "ROMS", "RUSSIANS": "RUSS",
}

# Continental competitions (our former engine keys).
CONTINENTAL = {
    "ucl": "CL", "uel": "EL", "uecl": "UCOL",
    "UCL": "CL", "UEL": "EL", "UECL": "UCOL",
    "libertadores": "CLI", "sudamericana": "CS", "recopa": "RECO",
    "champions_cup": "CCL", "acl_elite": "ACLE", "acl_two": "ACL2",
    "afc_challenge_league": "AFCP",
}

# Competitions Transfermarkt does not list at all (checked against the TM
# country index and the raw search page): they keep our key and the UI falls
# back to the generated monogram, because guessing a code would be worse.
MISSING = ["ETHICUP", "GHANFACUP", "LIBYCUP", "NIGEFEDECUP", "COUPDUSENE",
           "UGANCUP", "JFFCHAMCUP", "TORNDECOPA2", "COPALUISVILL",
           "HUNSENCUP", "JORDFACUP", "LEBAFACUP", "GENEAUNGSAN",
           "SULTQABOCUP", "SUPERCOP6", "OMANSUPE", "SZUPERKU"]

# Two records described the same competition (the FAI Cup); keep one.
DUPLICATES = {"REPUBLICOFIRELANDCUP": "IRELANDCUP"}

MAP = {}
MAP.update(CUPS)
MAP.update(SUPER_CUPS)
MAP.update(CONTINENTAL)


def rename_keys(raw, mapping):
    out = {}
    for key, value in raw.items():
        out[mapping.get(key, key)] = value
    return out


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    competitions_path = DATA / "competitions.json"
    document = json.loads(competitions_path.read_text(encoding="utf-8"))
    records = document["competitions"]
    renamed = {}
    for old_id, record in records.items():
        if old_id in DUPLICATES:
            continue
        new_id = MAP.get(old_id, old_id)
        if new_id != old_id:
            record = dict(record)
        cup = record.get("cup")
        if cup in MAP:
            record["cup"] = MAP[cup]
        if new_id in renamed:
            raise SystemExit(f"duplicate id after rename: {old_id} -> {new_id}")
        renamed[new_id] = record
    document["competitions"] = renamed

    continental_path = DATA / "continental_2026.json"
    continental = json.loads(continental_path.read_text(encoding="utf-8"))
    for confederation in ("CONCACAF", "CONMEBOL", "AFC"):
        block = continental.get(confederation, {})
        block["competitions"] = rename_keys(block.get("competitions", {}), MAP)

    europe_path = DATA / "europe_2026_27.json"
    europe = json.loads(europe_path.read_text(encoding="utf-8"))
    europe["competitions"] = rename_keys(europe.get("competitions", {}), MAP)
    europe["replacements"] = rename_keys(europe.get("replacements", {}), MAP)

    # confederations.json is nested: every competition key appears in bands,
    # cup slots, drop-downs, title holders and entry round sizes.
    confederations_path = DATA / "confederations.json"
    confederations = json.loads(confederations_path.read_text(encoding="utf-8"))

    def walk(node):
        if isinstance(node, dict):
            return {MAP.get(str(k), k) if isinstance(k, str) else k: walk(v)
                    for k, v in node.items()}
        if isinstance(node, list):
            return [walk(item) for item in node]
        return node

    confederations = walk(confederations)

    logos_path = DATA / "tournament_logos.json"
    logos = json.loads(logos_path.read_text(encoding="utf-8"))
    logos = {MAP.get(key, key): value for key, value in logos.items()}

    if args.dry_run:
        print("cups mapped:", len(CUPS), "super cups:", len(SUPER_CUPS),
              "continental:", len(CONTINENTAL))
        print("no TM competition:", MISSING)
        return

    for path, payload in ((competitions_path, document),
                          (continental_path, continental),
                          (europe_path, europe),
                          (confederations_path, confederations),
                          (logos_path, logos)):
        path.write_text(json.dumps(payload, ensure_ascii=False, indent=1) + "\n",
                        encoding="utf-8", newline="\n")
    print("renamed", len(renamed), "competition records")
    print("no TM competition:", MISSING)


if __name__ == "__main__":
    main()
