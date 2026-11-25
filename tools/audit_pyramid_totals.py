# -*- coding: utf-8 -*-
"""Audit the pyramid boundaries and store explicit totals.

Every row already carries a `note` that states the real movement; the numeric
columns were filled under two different conventions ("direct places" vs "total"),
so the totals are taken from the note instead. `up_total`/`down_total` are the
NOMINAL number of clubs that change level each way, which is what the career has
to reproduce; where the note says the number varies between seasons, the row is
left without totals and the engine keeps its fallback.

Every row balances (`up_total == down_total`) except Albania, whose own note records
a published 3 up / 2 down that does not balance while the top flight is mid-reform.

Rows audited: 105 of 108. Left without totals (variable or contradictory):
  - Netherlands L3-4  (2-3 each way, depends on the play-off)
  - Poland L3-4       (4 is the floor, 6 the maximum)
  - Ukraine L1-2      (nominal 2+2, 2026-27 resolved as 3/3)
"""
import io
import json
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

PATH = r"C:\Users\Egor\.local\share\opencode\worktree\fa15ca\career-regulations\assets\data\league_pyramids.json"

# (country, upper, lower): (up_total, down_total)
TOTALS = {
    ("Albania", 1, 2): (3, 2),
    ("Argentina", 1, 2): (2, 2),
    ("Argentina", 2, 3): (4, 4),
    ("Armenia", 1, 2): (1, 1),
    ("Australia", 1, 2): (0, 0),
    ("Belarus", 1, 2): (3, 3),
    ("Belgium", 1, 2): (2, 2),
    ("Belgium", 2, 3): (2, 2),
    ("Bulgaria", 1, 2): (3, 3),
    ("Chile", 1, 2): (2, 2),
    ("Chile", 2, 3): (1, 1),
    ("China", 1, 2): (2, 2),
    ("China", 2, 3): (3, 3),
    ("Chinese Taipei", 1, 2): (1, 1),
    ("Colombia", 1, 2): (2, 2),
    ("Croatia", 1, 2): (1, 1),
    ("Cyprus", 1, 2): (3, 3),
    ("Czech Republic", 1, 2): (3, 3),
    ("Czech Republic", 2, 3): (2, 2),
    ("Denmark", 1, 2): (2, 2),
    ("Denmark", 2, 3): (2, 2),
    ("Denmark", 3, 4): (2, 2),
    ("Ecuador", 1, 2): (2, 2),
    ("England", 1, 2): (3, 3),
    ("England", 2, 3): (3, 3),
    ("England", 3, 4): (4, 4),
    ("England", 4, 5): (2, 2),
    ("England", 5, 6): (4, 4),
    ("Estonia", 1, 2): (2, 2),
    ("Estonia", 2, 3): (3, 3),
    ("Faroe Islands", 1, 2): (2, 2),
    ("Finland", 1, 2): (2, 2),
    ("Finland", 2, 3): (2, 2),
    ("France", 1, 2): (3, 3),
    ("France", 2, 3): (3, 3),
    ("France", 3, 4): (3, 3),
    ("France", 4, 5): (8, 8),
    ("Georgia", 1, 2): (3, 3),
    ("Germany", 1, 2): (3, 3),
    ("Germany", 2, 3): (3, 3),
    ("Germany", 3, 4): (4, 4),
    ("Greece", 1, 2): (2, 2),
    ("Hongkong", 1, 2): (1, 1),
    ("Hongkong", 2, 3): (2, 2),
    ("Hungary", 1, 2): (2, 2),
    ("Iceland", 1, 2): (2, 2),
    ("Iceland", 2, 3): (2, 2),
    ("India", 1, 2): (1, 1),
    ("India", 2, 3): (2, 2),
    ("Indonesia", 1, 2): (3, 3),
    ("Indonesia", 2, 3): (3, 3),
    ("Iran", 1, 2): (3, 3),
    ("Iran", 2, 3): (3, 3),
    ("Israel", 1, 2): (2, 2),
    ("Italy", 1, 2): (3, 3),
    ("Italy", 2, 3): (4, 4),
    ("Japan", 1, 2): (3, 3),
    ("Japan", 2, 3): (3, 3),
    ("Japan", 3, 4): (1, 1),
    ("Kazakhstan", 1, 2): (2, 2),
    ("Latvia", 1, 2): (2, 2),
    ("Lithuania", 1, 2): (2, 2),
    ("Luxembourg", 1, 2): (4, 4),
    ("Malaysia", 1, 2): (2, 2),
    ("Malta", 1, 2): (2, 2),
    ("Malta", 2, 3): (2, 2),
    ("Mexico", 1, 2): (0, 0),
    ("Moldova", 1, 2): (2, 2),
    ("Montenegro", 1, 2): (3, 3),
    ("Netherlands", 1, 2): (3, 3),
    ("Netherlands", 2, 3): (0, 0),
    ("Nicaragua", 1, 2): (2, 2),
    ("Northern Ireland", 1, 2): (2, 2),
    ("Norway", 1, 2): (3, 3),
    ("Norway", 2, 3): (3, 3),
    ("Norway", 3, 4): (6, 6),
    ("Paraguay", 1, 2): (2, 2),
    ("Peru", 1, 2): (2, 2),
    ("Peru", 2, 3): (2, 2),
    ("Poland", 1, 2): (3, 3),
    ("Poland", 2, 3): (3, 3),
    ("Portugal", 1, 2): (3, 3),
    ("Portugal", 2, 3): (3, 3),
    ("Portugal", 3, 4): (4, 4),
    ("Qatar", 1, 2): (2, 2),
    ("Romania", 1, 2): (4, 4),
    ("Saudi Arabia", 1, 2): (3, 3),
    ("Scotland", 1, 2): (2, 2),
    ("Scotland", 2, 3): (2, 2),
    ("Scotland", 3, 4): (2, 2),
    ("Senegal", 1, 2): (2, 2),
    ("Serbia", 1, 2): (2, 2),
    ("Slovakia", 1, 2): (2, 2),
    ("Slovenia", 1, 2): (2, 2),
    ("Sweden", 1, 2): (3, 3),
    ("Sweden", 2, 3): (4, 4),
    ("Switzerland", 1, 2): (2, 2),
    ("Switzerland", 2, 3): (1, 1),
    ("Thailand", 1, 2): (3, 3),
    ("Ukraine", 2, 3): (2, 2),
    ("United Arab Emirates", 1, 2): (2, 2),
    ("Uruguay", 1, 2): (3, 3),
    ("Uzbekistan", 1, 2): (3, 3),
    ("Venezuela", 1, 2): (1, 1),
    ("Wales", 1, 2): (3, 3),
}


def main() -> None:
    document = json.load(open(PATH, encoding="utf-8"))
    rows = document["boundaries"]
    seen = set()
    audited = 0
    for row in rows:
        key = (row["country"], row["upper"], row["lower"])
        if key in TOTALS:
            up, down = TOTALS[key]
            row["up_total"] = up
            row["down_total"] = down
            row["totals_source"] = "note"
            audited += 1
            seen.add(key)
        else:
            row["up_total"] = None
            row["down_total"] = None
            row["totals_source"] = "unverified"
    unknown = set(TOTALS) - seen
    if unknown:
        raise SystemExit("audited rows not in the file: %s" % sorted(unknown))
    document["_comment"] = (
        document["_comment"].rstrip()
        + " `up_total`/`down_total` are the nominal number of clubs that change level each way, "
          "taken from each row's own note (the numeric columns mixed two conventions); "
          "`totals_source: unverified` means the note states a range, so the career keeps its fallback."
    )
    open(PATH, "w", encoding="utf-8", newline="\n").write(
        json.dumps(document, ensure_ascii=False, indent=1) + "\n")
    print("audited %d of %d rows, unverified %d" % (audited, len(rows), len(rows) - audited))
    for row in rows:
        if row.get("totals_source") == "unverified":
            print("  unverified: %s L%s-%s" % (row["country"], row["upper"], row["lower"]))


if __name__ == "__main__":
    main()
