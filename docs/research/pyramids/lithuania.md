# Lithuania — football pyramid, 2026 (career year 2026-27)

Lithuania plays **calendar-year seasons**: the season overlapping the 2026-27 career year is the
**2026 season**, so the JSON uses `"season": "2026"`. Cups and UEFA competitions are out of scope.

The top flight was **renamed**: the A Lyga became **TOPLYGA** from 2026. Our name is right.

## At a glance

| Level | id | Competition | Clubs | Format | Rounds | Up | Down |
|---|---|---|---|---|---|---|---|
| 1 | LI1 | TOPLYGA | 10 | single round robin, four rounds | 36 | — (closed) | 1 direct + 1 play-off |
| 2 | LTU2 | I Lyga | 18 | single round robin | null | 1 direct + 1 play-off | 2 direct + 1 play-off (to level 3) |
| 3 | — | II Lyga A/B (not modelled) | 16 + 12 | two divisions | — | 2 + play-off | — |

## Level 1 — TOPLYGA

- 10 clubs. The schedule is four rounds (36 matches); because **Riteriai withdrew** mid-season with
  their results annulled, the other nine clubs each played 32 games.
- 10th is relegated directly. **9th plays the I Lyga runner-up over two legs** for the last top-flight
  place — in 2026 that was Šiauliai v Minija, still undecided on 20 November.
- Riteriai were also relegated (disqualified), so 2026 sent two clubs down for different reasons.

## Level 2 — I Lyga

- 18 clubs in 2026 (see the conflict note below), one round robin per the published calendar; the
  exact round count is not published on Wikipedia, so it is `null`.
- **Promotion:** champion up directly; runner-up into the two-legged tie with TOPLYGA 9th.
- **Relegation:** bottom two down to the II Lyga; 3rd-last plays a play-off against the 3rd-placed
  II Lyga club.
- Six of the 18 are **B teams** (Žalgiris B, Panevėžys B, Šiauliai B, Transinvest B, Kauno Žalgiris B,
  Hegelmann B). They cannot be promoted, so the "top two" promotion places can slide down the table.

## Check against our database

| id | our name | our level | real level | our size | real size 2026 | verdict |
|---|---|---|---|---|---|---|
| LI1 | Toplyga | 1 | 1 | 10 | 10 | correct |
| LTU2 | I Lyga | 2 | 2 | 16 | 18 | **size wrong** (see conflict) |

## Caveats

- Participation is finalised by **licensing**, not by the previous season's table: clubs collapse or
  are refused a licence most years, so the size of I Lyga moves between 14 and 18.
- Level 3 (II Lyga) is two divisions, A (16) and B (12), and is not modelled.

## Sources

- https://en.wikipedia.org/wiki/2026_Toplyga
- https://en.wikipedia.org/wiki/I_Lyga
- https://en.wikipedia.org/wiki/II_Lyga
