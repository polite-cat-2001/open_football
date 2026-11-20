# Norway — football pyramid, 2026 (career year 2026-27)

Norway plays **calendar-year seasons**, so there is no "2026-27 season": the season that overlaps
the 2026-27 career year is the **2026 season**. The JSON uses `"season": "2026-27"` only as the
dataset label requested for the career; every competition fact below is the 2026 season. Cups and
UEFA competitions are out of scope.

Names matter here: level 2 is **OBOS-ligaen** (sponsor name for 1. divisjon), level 3 is
**2. divisjon**, level 4 is **3. divisjon** (sponsor name **Norsk Tipping-ligaen**). 2. divisjon was
called *PostNord-ligaen* from 2016 to 2025, but that sponsorship ended — since 2026 it is officially
just "2. divisjon". Our database still says "PostNord-ligaen", which is out of date.

## At a glance

| Level | id | Competition | Clubs | Format | Rounds | Up | Down |
|---|---|---|---|---|---|---|---|
| 1 | NO1 | Eliteserien | 16 | single round robin | 30 | — (closed) | 2 direct + 1 play-off |
| 2 | NO2 | OBOS-ligaen | 16 | single round robin | 30 | 2 direct + 1 play-off | 2 direct + 1 play-off |
| 3 | NO31/NO32 | 2. divisjon, 2 avdelinger | 14 + 14 = 28 | 2 groups, double round robin | 26 | 2 group winners + 1 play-off | 3 per group = 6 |
| 4 | NO41–NO46 | 3. divisjon, 6 avdelinger | 6 × 14 = 84 | 6 groups, double round robin | 26 | 6 group winners | 3 per group (to level 5) |
| 5 | — | 4. divisjon (not modelled) | 24 krets groups | regional | — | krets quotas | — |

All modelled levels are open both ways. Level 4's downward route exists (to 4. divisjon) but level 5
is not in our database.

## Level 1 — Eliteserien

- 16 clubs, 30 rounds.
- 15th and 16th are relegated directly.
- 14th plays the winner of the OBOS-ligaen promotion play-offs over **two legs**; winner plays in
  Eliteserien next season, loser in OBOS-ligaen. So 3 places, 1 of them contested.

## Level 2 — OBOS-ligaen

- 16 clubs, 30 rounds.
- **Promotion:** top 2 direct. 3rd–6th play a **single-leg** ladder: 5th hosts 6th; that winner
  plays away to 4th; that winner plays away to 3rd. The ladder winner then meets the Eliteserien
  14th over two legs.
- **Relegation:** 15th and 16th direct. 14th plays the winner of the 2. divisjon play-offs over
  **two legs** for the last OBOS place.
- Net: 3 up, 3 down (one of each contested).

## Level 3 — 2. divisjon (PostNord-ligaen until 2025)

- 28 clubs in **two avdelinger of 14**, 26 rounds. The split is geographical and NFF re-balances it
  each season: in 2026 avdeling 1 is centred on southern and western Norway (Agder, Rogaland,
  Vestland, Møre, Telemark/Vestfold), avdeling 2 on Oslo/Akershus, Innlandet, Trøndelag and the
  north. Edge clubs (e.g. Hønefoss, Kvik Halden) show it is a travel decision, not a fixed map.
- **Promotion:** the winner of each avdeling goes up directly (2). The two runners-up play each
  other over two legs, and that winner plays the OBOS-ligaen 14th over two legs for the last place
  (1). So 3 places, 1 contested — and if the OBOS club wins, only 2 level-3 clubs go up.
- **Relegation:** the bottom 3 in each avdeling go down directly (6). There is no play-out.

## Level 4 — 3. divisjon (Norsk Tipping-ligaen)

- 84 clubs in **six avdelinger of 14**, 26 rounds.
- Each avdeling winner is promoted directly — **6 up in total**, one per group. There is no
  runner-up route at this level.
- The bottom 3 in each avdeling are relegated to 4. divisjon (level 5, krets-run, not modelled).

### How the six level-4 groups feed level 3

The six winners are not paired to a fixed avdeling by regulation; NFF places them **by geography and
travel**, and because each 2. divisjon avdeling must replace exactly the 3 clubs it loses, the
outcome is always **3 promoted clubs into avdeling 1 and 3 into avdeling 2**. There is no
group→avdeling table to hardcode; the placement is published with the next season's fixture list.

Going the other way, 2. divisjon's six relegated clubs (3 per avdeling) are placed into the six
3. divisjon groups by geography, not by a one-per-group rule.

2026 group winners (all promoted): Asker (avd. 1), Volda (2), Os (3), Madla (4), Fløya (5),
Lillehammer (6). No 2027 season page or placement list exists yet, so the JSON records the rule,
not a guessed mapping.

## Check against our database

| id | our name | our level | real level | our size | real size 2026 | verdict |
|---|---|---|---|---|---|---|
| NO1 | Eliteserien | 1 | 1 | 16 | 16 | correct |
| NO2 | OBOS-ligaen | 2 | 2 | 16 | 16 | correct |
| NO31 | PostNord-ligaen Avd. 1 | 3 | 3 | 14 | 14 | size/level correct, **name outdated** (2. divisjon avdeling 1) |
| NO32 | PostNord-ligaen Avd. 2 | 3 | 3 | 14 | 14 | size/level correct, **name outdated** (2. divisjon avdeling 2) |
| NO41–NO46 | Norsk Tipping-Ligaen avdeling 1–6 | 4 | 4 | 14 each | 14 each | correct (Norsk Tipping-ligaen is the current sponsor alias of 3. divisjon) |

Only real conflict: the PostNord name. Everything else matches.

## Caveats

- The 2026 season is still finishing as of 20 November 2026: the Eliteserien run-in and the
  November qualification ties (OBOS 14th v 2. divisjon play-off winner, Eliteserien 14th v OBOS
  play-off winner) decide the last places, so 2027 compositions are not final.
- Reserve teams (e.g. Brann 2, Rosenborg 2, Vålerenga 2) cannot play above level 3, so a promoted
  reserve cannot follow its parent into Eliteserien or OBOS-ligaen. This only matters if the sim
  treats reserve sides as ordinary clubs.
- Level 5 and below are krets-administered with variable group counts, so any "pyramid" below
  level 4 should not be modelled as a fixed shape.

## Sources

- https://no.wikipedia.org/wiki/Eliteserien_i_fotball_for_menn_2026
- https://no.wikipedia.org/wiki/OBOS-ligaen_2026
- https://no.wikipedia.org/wiki/2._divisjon_fotball_for_menn_2026
- https://no.wikipedia.org/wiki/3._divisjon_fotball_for_menn_2026
- https://no.wikipedia.org/wiki/2._divisjon_fotball_for_menn
- https://no.wikipedia.org/wiki/3._divisjon_fotball_for_menn
- https://no.wikipedia.org/wiki/Det_norske_seriesystemet_i_fotball_for_menn
- https://no.wikipedia.org/wiki/Kvalifisering_til_1._divisjon_fotball_for_menn_2027
- https://en.wikipedia.org/wiki/2026_Eliteserien
- https://en.wikipedia.org/wiki/2026_Norwegian_First_Division
- https://en.wikipedia.org/wiki/2026_Norwegian_Second_Division
- https://en.wikipedia.org/wiki/2026_Norwegian_Third_Division
