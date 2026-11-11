# 03: Хаб карьеры — Centre и табы

**What to build:** Хаб карьеры с верхними табами Centre / Squad / Transfers / Scouting и
центральной вкладкой Centre: Next Match, Overview (место в таблице, последние результаты,
бомбардиры), Tournament overlay, Save и Exit. Навигация `L1/R1`, стрелки/D-pad, A/B — как в
прототипе. Данные — расписание сезона, таблица и снимок карьеры.

**Blocked by:** 02

**Status:** done (2026-11-10)

**Resolution:** `career_hub` — шапка `UiTabBar` (CENTRE/SQUAD/TRANSFERS/SCOUTING) + клубная плашка,
bento-центр (`CareerHubNextTile`: недельная лента, фикстура, форма; `CareerHubTableTile`: окно
таблицы и точки секций; три «скоро»-плитки) и `CareerHubOverlay` с полной таблицей лиги. Ввод —
`UiNav` (`L1/R1`/`Q/E` — табы, стрелки, A/Enter, B/Esc), активный таб хранится в `Career.hub_tab`;
`S`/`Start` сохраняет, Esc с Centre сохраняет и выходит в меню. Read-model — `CareerHubModel`,
сезон в `CareerFactory` получил `played_round`/`last_result`/`form`/`promotion_places`/
`relegation_places`, гербы — карьерные эмблемы. Тесты: `check_career_hub` (golden
`tests/fixtures/career_hub_golden.json` + навигация/overlay/save/exit), PASS — `check_career_ui`,
`check_career_creation`, `check_career_save_store`, `check_career_delete`, `check_main_menu_ui`,
`check_main_menu_layout`.

- [x] Шапка-хаб с табами и переключением `L1/R1`; активный таб и фокус совпадают с прототипом.
- [x] Centre: Next Match (соперник, дата, турнир, кнопка матча), Overview (таблица, форма, бомбардиры), Tournament overlay.
- [x] Save сохраняет карьеру; Exit возвращает в главное меню без потери прогресса.
- [x] Расписание сезона и таблица строятся из единой БД; promotion/relegation данные доступны.
- [x] Состояние хаба восстанавливается из сейва; повторный вход показывает тот же экран.
- [x] Headless-тест навигации и golden-снимок хаба.
