# Poland — football pyramid 2026-27

Scope: levels 1–4 only. No cups, no UEFA competitions.
Research date: 2026-11-20. Season in progress (matchday ~15/16 of 34), so team lists are real but final standings are not.

## Pyramid at a glance

| id | League | Level | Clubs | Rounds | Shape |
|----|--------|-------|-------|--------|-------|
| PL1 | PKO BP Ekstraklasa | 1 | 18 | 34 | single table, double round-robin |
| PL2 | Betclic 1 Liga | 2 | 18 | 34 | single table, double round-robin |
| PL2L | Betclic 2 Liga | 3 | 18 | 34 | single table, double round-robin |
| PL31–PL34 | Betclic 3 Liga, groups I–IV | 4 | 18 each (72 total) | 34 per group | 4 parallel groups, double round-robin |

Every level is a plain double round-robin: 18 clubs → 34 rounds, no split, no points carried, no apertura/clausura. Nothing is decided by average points or a "promedio".

**Our database rows are all correct for 2026-27**: 18 / 18 / 18 / 18×4. The only thing our schema flattens is that level 4 is one competition (III liga) split into four territorial groups — the four `PL31..PL34` rows are the four groups, not four separate leagues.

## Boundaries

### 1 ↔ 2 (Ekstraklasa ↔ 1 Liga)

- Down: Ekstraklasa 16th, 17th, 18th are relegated (3). Confirmed by the 2026-27 Ekstraklasa table (`result16..18=REL`) and by the 1 Liga 2026-27 entry list, which carries "16. Lechia Gdańsk, 17. Arka Gdynia, 18. Bruk-Bet Termalica" from the 2025-26 Ekstraklasa.
- Up: 1 Liga top 2 go up directly (1st and 2nd = `AWA`, "awans do Ekstraklasy"), and 3rd–6th play a promotion play-off for the third place (`BRZ`, "baraże o Ekstraklasę").
- Play-off format: single-leg semi-finals paired 3v6 and 4v5, then a single-leg final. In every match the higher-placed club is the host. No return legs. 2025-26 example: Wieczysta Kraków (play-off winner) beat Chrobry Głogów in the final on 31 May 2026 and went up as the third promoted club.

### 2 ↔ 3 (1 Liga ↔ 2 Liga)

Identical mechanics, one level down:

- Down: 1 Liga 16th–18th relegated (3).
- Up: 2 Liga 1st and 2nd promoted directly; 3rd–6th play the same single-leg 3v6 / 4v5 bracket with a single-leg final, higher-placed club hosting.

### 3 ↔ 4 (2 Liga ↔ III liga) — the interesting one

This is the only boundary in the Polish pyramid that is **not a fixed number**.

Up from level 4:

1. The **champion of each of the four groups is promoted directly** — 4 clubs, one per group, no play-off.
2. The **four runners-up** (2nd in each group) enter a two-round play-off:
   - Round 1: a single match, paired by the PZPN bracket as group I v group III and group IV v group II, hosted by... in practice the pairing is fixed by the bracket, one match only.
   - Round 2: the two winners play **two legs** against the **13th and 14th placed clubs of 2 Liga**, the II-liga club hosting the second leg.
3. So **4 to 6 clubs** go up, depending on how many III-liga runners-up win their two-legged tie. In 2025-26 both 2 Liga clubs (Resovia 13th, Sokół Kleczew 14th) defended their places, so exactly 4 went up (Legia II Warszawa, Zawisza Bydgoszcz, Lechia Zielona Góra, Avia Świdnik — one per group). The runners-up that lost round 1 (ŁKS Łomża, Wikęd Luzino) had no further route.

Down from level 3: 2 Liga 15th–18th are relegated directly (4), and 13th/14th are the two clubs in the survival ties described above (0–2 of them go down). Total movement is therefore 4, 5 or 6 in each direction, and always symmetric — the same two ties produce one relegation and one promotion each.

**Do the groups exchange clubs?** Yes, and continuously. Group membership is purely territorial by voivodeship:

- Group I: łódzkie, mazowieckie, podlaskie, warmińsko-mazurskie
- Group II: kujawsko-pomorskie, pomorskie, wielkopolskie, zachodniopomorskie
- Group III: dolnośląskie, lubuskie, opolskie, śląskie
- Group IV: lubelskie, małopolskie, podkarpackie, świętokrzyskie

A club never "belongs" to a group in the way it belongs to a league: it is placed in the group that covers its voivodeship each season. A club relegated from 2 Liga drops into the group covering its region; a club promoted from a regional IV liga enters the same group as its voivodeship's IV-liga group. That is why the groups are stable at 18 clubs even though 4–6 leave upward every year: if a group receives a relegated II-liga club, that group sends **one extra club down to IV liga** (so 5 instead of the usual 4) — this is stated explicitly in the III liga regulations summary ("w przypadku spadku drużyn z II ligi do danej grupy III ligi, liczba spadkowiczów z III ligi wzrosła").

Consequence for a career sim: level 4 cannot be modelled as four independent closed leagues with a fixed 1-up-1-down each. The group is a placement decision driven by geography, and the number of clubs leaving a group depends on what arrives from above.

## Reserve teams

2 Liga 2026-27 contains two reserve sides: **Legia II Warszawa** and **Śląsk II Wrocław**. No reserve team has ever played in the Polish second tier, and the historical promotion rule barred reserve teams of Ekstraklasa/1 Liga clubs from promotion to 1 Liga. Treat promotion of a reserve team from level 3 to level 2 as blocked, but verify against the 2026-27 PZPN regulation before hard-coding it — I did not open the regulation PDF itself.

## Sources

- https://pl.wikipedia.org/wiki/Ekstraklasa_w_pi%C5%82ce_no%C5%BCnej_(2026/2027) — 18 clubs, 34 rounds, `result16-18=REL`
- https://pl.wikipedia.org/wiki/Ekstraklasa_w_pi%C5%82ce_no%C5%BCnej — competition overview, 18 clubs, relegation to 1 Liga
- https://pl.wikipedia.org/wiki/I_liga_polska_w_pi%C5%82ce_no%C5%BCnej_(2026/2027) — 18 clubs, 34 rounds, `AWA`/`BRZ`/`REL` columns, 2025-26 relegated trio, promoted trio
- https://pl.wikipedia.org/wiki/I_liga_polska_w_pi%C5%82ce_no%C5%BCnej_(2025/2026) — play-off description ("pary 3–6 i 4–5", single final, higher-placed hosts)
- https://pl.wikipedia.org/wiki/II_liga_polska_w_pi%C5%82ce_no%C5%BCnej_(2026/2027) — 18 clubs, 34 rounds; `result1-2=AWA`, `result3-6=APO`, `result13-14=RPO`, `result15-18=REL`
- https://pl.wikipedia.org/wiki/II_liga_polska_w_pi%C5%82ce_no%C5%BCnej_(2025/2026) — full text of both play-off systems ("Baraże o I ligę", "Baraże o II ligę": runners-up round 1 single match, round 2 two legs v 13th/14th)
- https://pl.wikipedia.org/wiki/III_liga_polska_w_pi%C5%82ce_no%C5%BCnej_(2026/2027) — 72 clubs, 4 groups of 18, territorial split, "mistrzowie każdej z grup uzyskali awans", runners-up play-offs, 4 relegated per group
- https://pl.wikipedia.org/wiki/III_liga_polska_w_pi%C5%82ce_no%C5%BCnej — group structure and 2016 reform
- https://pl.wikipedia.org/wiki/II_liga_polska_w_pi%C5%82ce_no%C5%BCnej — 2019/20 play-off introduction, 2024/25 relegation play-off (13th–14th) introduction, reserve-team promotion condition
- https://pl.wikipedia.org/wiki/I_liga_polska_w_pi%C5%82ce_no%C5%BCnej — "drużyny rezerw nigdy nie zagrały na drugim poziomie ligowym"

## Confidence

High for the structure and every count above. Open items, all flagged rather than guessed:

- The exact 2 Liga relegation count is 4 + (0–2), i.e. variable; the JSON stores the maximum (6) with `*_playoff` marking the 2 variable places.
- Reserve-team promotion to level 2: rule inferred from regulation history, not read from the 2026-27 PDF.
- Level 4 → level 5 (IV liga) is out of scope and not modelled.
