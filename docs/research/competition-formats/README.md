# National cups and super cups — format families

Checked **2026-11-20**. Sample: 17 countries across UEFA, CONMEBOL, CONCACAF,
AFC and CAF. Data: [`national-cups.json`](national-cups.json).

Purpose: tell the career engine which **stage kinds** a cup needs, not to
catalogue every competition. One representative season per country (2025 or
2025–26, whichever season article was complete and sourced).

## Table

| Country | Cup | Cup format | Replays | Two-legged rounds | Super cup |
|---|---|---|---|---|---|
| England | FA Cup | single-leg knockout | no (abolished 2024–25) | — | 2 teams, one match (Community Shield) |
| Spain | Copa del Rey | single-leg knockout | no | preliminary, semi | 4 teams, mini-tournament |
| Italy | Coppa Italia | single-leg knockout | no | semi | 4 teams, mini-tournament |
| Germany | DFB-Pokal | single-leg knockout | no | — | 2 teams, one match |
| France | Coupe de France | single-leg knockout | no | — | 2 teams, one match |
| Netherlands | KNVB Cup | single-leg knockout | no | — | 2 teams, one match |
| Portugal | Taça de Portugal | single-leg knockout | no | semi | 2 teams, one match |
| Turkey | Turkish Cup | KO → 3×8 groups → KO | no | — | 4 teams, mini-tournament |
| Brazil | Copa do Brasil | two-leg knockout from R3 | no | R3, R16, QF, SF, final | 2 teams, one match |
| Argentina | Copa Argentina | single-leg knockout | no | — | 2 teams, one match |
| Mexico | — (Copa MX suspended since 2020) | none | — | — | 2 teams, one match (Campeón de Campeones) |
| USA | U.S. Open Cup | single-leg knockout | no | — | none |
| Japan | Emperor's Cup | single-leg knockout | no | — | 2 teams, one match |
| China | Chinese FA Cup | single-leg knockout | no | — | 2 teams, one match |
| Egypt | Egypt Cup | single-leg knockout | no | — | 4 teams, mini-tournament |
| Saudi Arabia | King's Cup | single-leg knockout | no | — | 4 teams, mini-tournament |
| Australia | Australia Cup | single-leg knockout | no | — | none |

## Format families found

### 1. Pure single-leg knockout, no replays (the default)

One match per round, extra time + penalties, no second leg, no replay.
Final at a neutral venue: **England** (Wembley), **Germany** (Berlin),
**France** (Stade de France), **Netherlands** (De Kuip), **Italy** (Olimpico),
**Spain** (La Cartuja), **Argentina**, **USA**, **Japan** (National Stadium),
**China** (Suzhou), **Saudi Arabia** (Jeddah), **Egypt** (Cairo),
**Australia** (rotating). Neutral venue is not the same as "bigger stadium":
Germany's and England's finals are fixed, Australia's rotates.

Entry is staggered with byes: Premier League/Championship at R3 (England),
top-8 Serie A at R16 (Italy), Supercopa four at R32 (Spain), Ligue 1 at R64
(France), Primeira Liga at R3 with 38 byes (Portugal), CSL at R3 (China),
Nile Premier League at R32 (Egypt), J1 at R16 (Japan).

### 2. Single-leg knockout with a two-legged round

Same family, but one or two named rounds are home-and-away:
**Portugal** (semi), **Italy** (semi), **Spain** (preliminary + semi).
This is the "cup needs a `two_legged_round` stage kind attached to specific
rounds" case, not a separate competition format.

### 3. Two-leg knockout throughout the later rounds

**Brazil**: R1–R2 single match, then R3/R16/QF/SF/**final** all two-legged.
The final is *not* a neutral single match — it is a home/away pair decided by
aggregate. This is the only sample country whose final is two-legged.

### 4. Knockout → group stage → knockout

**Turkey** is the outlier: four single-leg preliminary rounds, then 24 clubs in
3 groups of 8 (round robin), then 8 qualifiers (3 winners + 3 runners-up + 2
best third-placed) into QF/SF/final. A cup engine needs a real `group_stage`
stage for this, not just byes.

Beware false friends: Spain's "Group 1–4" and France's "three groups" in the
round of 64 are **draw pots by geography**, not group tables.

### 5. No national cup

**Mexico** — Copa MX has been on hiatus since 2020. The super cup
(Campeón de Campeones) still runs.

### 6. Super cup: two-team single match

**England, Germany, France, Netherlands, Portugal, Brazil, Argentina, Mexico,
Japan, China.** Neutral venue varies: Wembley / national stadium / abroad
(Kuwait, USA), but Germany and the Netherlands play at the **home ground of
one entrant** (cup winner / league champion). Entrants are league champion vs
cup winner, with a runner-up substitution when one club wins both.

### 7. Super cup: four-team mini-tournament

**Spain, Italy, Turkey, Egypt, Saudi Arabia.** Two single-leg semi-finals plus
a final, all at one neutral/foreign venue (Saudi Arabia for Spain and Italy,
UAE for Egypt, Hong Kong for Saudi Arabia, Turkey at home). Qualification is
"top two of the league + top two of the cup" for Spain/Italy/Saudi, "league top
three + cup runner-up" for Turkey, and "three competition winners + one
federation invite" for Egypt. Turkey switched from 2 to 4 teams in 2025 —
a format that can change between seasons.

### 8. No super cup

**USA** and **Australia** have no super cup. Do not synthesise one.

## What this means for the engine

Stage kinds needed: `single_leg_knockout` (all countries), `two_legged_knockout`
(Brazil; attachable per round for Spain/Italy/Portugal), `group_stage`
(Turkey only), and a 4-team `mini_tournament` for the super cup. Replays are
not needed: **no country in the sample uses them** in the checked season
(England abolished them from 2024–25; the FA Cup qualifying rounds are outside
this dataset). A replay stage kind would be dead code for this sample.

## Caveats

- Seasons differ: 2025–26 for Europe/Egypt/Saudi, 2025 calendar year for
  Brazil/Argentina/USA/Japan/China/Australia/Mexico.
- France's window starts **2025-05-11** on fr.wikipedia (regional round 1);
  en.wikipedia counts from the third round (2025-09-13). Both are "day"
  precision, different definitions of round one.
- Australia's window includes preliminary rounds; the 32-club main draw starts
  later.
- Netherlands participation numbers are reconstructed from the round schedule
  (64 → 32 → 16), hence `medium` confidence on `participants`.
- Egypt: the cup winner's CAF Confederation Cup berth was not verified in the
  sources used; only the Egyptian Super Cup berth is quoted. Super cup has
  **4 matches** (semi-finals, third place, final).
- Saudi Arabia's cup winner now gets **AFC Champions League Two**, not Elite.
  Japan's gets ACL Two; China's gets ACL Elite. Do not hard-code "AFC Elite".
- Prize/qualification rules change between seasons; re-check the season article
  when the career advances a year.
