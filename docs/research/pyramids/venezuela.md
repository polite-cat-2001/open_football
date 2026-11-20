# Venezuela — football pyramid, 2026

Calendar-year season: 29 January → December 2026.

| Level | Competition | Clubs | Shape | Rounds |
|---|---|---|---|---|
| 1 | Liga FUTVE (our row: "Clausura") | 14 | Apertura + Clausura, each 13 rounds + top-8 groups + final | 13 + 3 + 1 per half |
| 2 | Liga FUTVE 2 | 17 (unverified) | not verified | - |

Our level-1 size (14) is correct. Our level-2 size (17) could not be confirmed.

## Level 1 — two tournaments, one season

The season is played as **two separate tournaments**, Apertura (29 January - 7 June) and Clausura
(from 31 July), and each is a complete mini-season:

1. **Regular stage**: all 14 clubs, single round-robin, 13 matches.
2. **Final stages**: the top eight split into two groups of four (the 1st and 2nd seeds head the
   groups), each group plays a single round-robin of three matches; the two group winners meet in
   a **single final**, hosted by the better-placed finalist.
3. The Apertura winner and the Clausura winner then play the season's **grand final** for the title
   (2026 Apertura was won by Carabobo, 2-1 over Academia Puerto Cabello).

So the "Clausura" in our id is not a separate league: it is the second half of the same 14-club
competition. A career sim that treats `VZ1C` as an ordinary 26-round league will be wrong twice
over — the table resets at mid-year, and there is a group phase plus two finals.

## Relegation

Relegation is decided by an **aggregate table over the whole season** (both tournaments), and in
recent practice **one club goes down**: Yaracuyanos finished last in 2025 and were replaced by the
Liga FUTVE 2 champion Trujillanos; Anzoátegui are already marked relegated for 2026. The league
article's summary still says "the two lowest placed teams", which is out of date relative to the
two most recent seasons.

## Level 2 — Liga FUTVE 2

Level 2, 16 clubs according to the league's infobox, **17 in our row**. The 2026 season page does
not exist, so 17 could not be verified; the champion is promoted (Trujillanos in 2025, after
beating Titanes in the final, which implies a play-off finish rather than a plain table). Below it
sits the Tercera División, which is not in our rows. Because the lower division is outside the
model, `closed_down` is true.

## Boundary as numbers

| Boundary | Up | of which play-off | Down | of which play-off | Allocation |
|---|---|---|---|---|---|
| 1 ↔ 2 | 1 | 0 | 1 | 0 | free |

One up, one down. The "no play-off" on the promotion side is only true of the final result — the
second tier's season ends in a final, so the promoted club is the play-off winner in practice; the
row records one promotion place, however it is decided.

## Data problems in our rows

1. `VZ1C` "Liga FUTVE Clausura" — the name describes one half of a season, but the row is the whole
   level-1 competition. Either rename it "Liga FUTVE" or keep the name and model the two tournaments
   inside one league (recommended: the latter, so the aggregate table stays in one place).
2. `VZ1C` size 14 — correct.
3. `VN2A` size 17 — unconfirmed (infobox says 16). Left at our value and flagged.
4. Relegation: one club, not two, in 2025 and 2026.

## Confidence

High on level 1 (14 clubs, 13-round halves, top-8 groups, finals, one relegation place, the 2026
relegated club). Medium on level 2's size — the only number I could not confirm, hence the flag.

## Sources

- https://en.wikipedia.org/wiki/Liga_FUTVE (14 clubs, Apertura/Clausura history, relegation summary)
- https://en.wikipedia.org/wiki/2026_Liga_FUTVE (14 clubs, 13-match regular stages, two groups of four, finals, Anzoátegui relegated, Trujillanos promoted)
- https://en.wikipedia.org/wiki/Liga_FUTVE_2 (level 2, 16 clubs per infobox, champion promoted, Tercera División below)
