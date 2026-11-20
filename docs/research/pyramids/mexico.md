# Mexico — football pyramid, 2026-27

Verdict up front: the ticket's note is **right for now and wrong on the law**. Liga MX has no
promotion or relegation in 2026-27, but that is a contested political decision, not a settled rule.

## The closed-league story

1. April 2020: Ascenso MX folded; promotion and relegation between Liga MX and the second tier were
   suspended for six years.
2. 4 September 2025: the **Court of Arbitration for Sport** ruled that relegation must return from the
   2026-27 season, with the FMF still free to set promotion requirements.
3. 16 July 2026: Liga MX split from the FMF and published regulations that **indefinitely suspend**
   promotion and relegation and formalise a closed league. Second-tier clubs protested.
4. 20 August 2026: the FMF's new model makes Liga de Expansión the top of *its own* pyramid (with
   promotion to Liga Premier below), while Liga MX stays closed, entry only by buying a franchise.
5. September 2026: a Senate bill to make promotion/relegation mandatory is pending.

So: **closed today, could reopen.** Atlante are in the 2026-27 Liga MX not because they won anything
but because they bought Mazatlán's registration.

## At a glance

| Level | id | Competition | Clubs | Format | Rounds | Up | Down |
|---|---|---|---|---|---|---|---|
| 1 | MEXA | Liga MX | 18 | Apertura + Clausura | 17 each | — (closed) | — (closed) |
| 2 | MEX2 | Liga de Expansión MX | 16 | Apertura + Clausura | 17 each | — (closed) | — (closed) |
| youth | M191 | Liga MX Sub-19 | 18 | Apertura + Clausura | null | — | — |
| youth | M21A | Liga MX Sub-21 | 18 | Apertura + Clausura | null | — | — |

## Level 1 — Liga MX

- 18 clubs, Apertura (July–December) and Clausura (January–May), each a single table of 17 rounds.
- Top eight go straight to a two-legged liguilla. **The play-in was abolished permanently from
  Apertura 2026** — that is a recent change worth knowing if old data shows a 7th-10th round.
- No relegation, no promotion. `selection` for the (empty) boundary is `other`, `allocation` `none`.

## Level 2 — Liga de Expansión MX

- 16 clubs for 2026-27, same Apertura/Clausura + top-eight liguilla shape.
- Membership moved by franchise sales in 2026: Celaya's place became Piratas (Veracruz), Cimarrones'
  became Jaiba Brava, and Cruz Azul Hidalgo entered as an affiliate.
- No promotion up; promotion/relegation to Liga Premier (level 3) is being kept under the FMF model.

## Youth rows (M191, M21A)

- Sub-19 and Sub-21 are **Fuerzas Básicas** categories, one team per Liga MX club — hence 18 each,
  matching the senior league.
- They run their own Apertura/Clausura calendars (the 2026 Apertura reached matchday 18), so the round
  count is left `null` rather than guessed.
- No promotion or relegation by design; level 99 is our marker for a youth competition.

## Check against our database

| id | our name | our level | our size | real | verdict |
|---|---|---|---|---|---|
| MEXA | Liga MX Apertura | 1 | 18 | 18 | correct size; name is one tournament |
| MEX2 | Liga de Expansión MX Clausura | 2 | 16 | 16 | correct size; name is one tournament |
| M191 | Liga MX U19 Apertura | 99 | 18 | 18 | correct |
| M21A | Liga MX U21 Apertura | 99 | 18 | 18 | correct |

Nothing to correct except the `Apertura`/`Clausura` suffixes, which name a half-season.

## Sources

- https://en.wikipedia.org/wiki/Liga_MX
- https://en.wikipedia.org/wiki/2026%E2%80%9327_Liga_MX_season
- https://en.wikipedia.org/wiki/Liga_de_Expansi%C3%B3n_MX
- https://sub19.ligamx.net/
- https://www.ceroacero.es/competicion/liga-mx-fuerzas-basicas-sub-19
