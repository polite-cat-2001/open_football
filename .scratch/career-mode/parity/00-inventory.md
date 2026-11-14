# Career Mode — инвентаризация и матрица покрытия

Дата: 2026-11-13. Источники: `gf-career-prototype` (эталон), `open_football_career` (Godot).

## 0. Методика сравнения

- Вьюпорт прототипа строго **1920×1080**. Встроенный браузер OpenCode даёт панель ~1160×886
  (срабатывает `@media (max-width: 1200px)`), поэтому эталон снимается одним из двух способов:
  1. **browse/Playwright** (`page.setViewportSize({width:1920,height:1080})`) — основной путь;
  2. фолбэк встроенного браузера: `document.documentElement.innerHTML` заменяется обёрткой
     `<iframe id="f src="http://localhost:8765" width/height=1920×1080>`, затем
     `browser.screenshot(fullPage:true)` — даёт ровно 1920×1080 без брейкпоинтов, внутри
     iframe медиазапросы считаются от 1920×1080. Действия — синтетические `KeyboardEvent`
     внутри frame (`ArrowUp/Down/Left/Right`, `Enter`, `Escape`, `Q/E` — вкладки).
- Godot: `-s res://tests/capture_career_shots.gd` → SubViewport 1920×1080 →
  `.scratch/ui_shots/career_<state>_1920x1080.png`.
- Скриншоты прототипа: `.scratch/ui_shots/proto/<screen>_1920x1080.png`.
- Геометрия/цвета не на глаз: `getBoundingClientRect()` + `getComputedStyle()` в прототипе,
  значения из `UiTokens` в Godot.

Токены прототипа (`web/src/styles/theme.css`): `--tile rgba(245,247,250,.95)`,
`--focus-fill #171b3f`, `--ink #1d2138`, `--ink-2 #5a5f78`, `--rail #e6236e`,
`--focus-mark #c9f227`, `--gap 10px`, `--rail-w 2px`, `--mark-win/loss/warn`,
`--pos-gk/def/mid/fwd`, `--shadow-tile 0 18px 44px rgba(4,9,20,.3)`.
В Godot это `UiTokens` (`TILE`, `FOCUS_FILL`, `INK`, `INK_2`, `RAIL`, `FOCUS_MARK`, `GAP`,
`RAIL_W`, `SHADOW`, `TAB_STRIP`, …) — палитра уже совпадает, расхождения в раскладке/размерах.

## 0.1 Канва Career UI (решено и сделано)

Замер прототипа в 1920×1080 без анимаций (`getBoundingClientRect`):

| элемент | прототип | было в Godot | стало |
|---|---|---|---|
| панель хаба | 1664×680.4, x=128, y=210.6 | 1480×? у=центр | 1664×680.4, y=210.6 |
| нижняя полоса (легенда) | 22.8, отступ 12 | 24, отступ 16 | 24, отступ 12 |
| шапка (вкладки/крошки) | 38, шрифт 20 | 52, шрифт 23 | 38, шрифт 20 |
| тело хаба | 597.2 | 626.4 | 596.4 |
| бенто-сетка | 4 колонки по 408.5, зазор 10, плитка 293.6 | 4×362.5 | 4×408.5, плитка 293.2 |
| экран Start | 1664×709.6 по центру (y=185.2), тело 626.4 | 1480×? | 1664, тело 626.4, y по центру |
| экран Load | 1664×680.4, y=210.6, строки 93.6 | как хаб | как хаб |

Введены токены `UiTokens.CAREER_*` (панель, шапка, тело, отступ подсказок, размеры
вкладок и крошек). `UiTabBar` и `UiBreadcrumb` получили необязательные поля метрик
(дефолты не изменились, главное меню и сетевые экраны остались на 1480/52).
Крошки в подэкранах хаба включены (`CAREER › SQUAD › SQUAD CENTRE|GAME PLAN|CONTRACT TALKS`),
полоса вкладок в подэкране скрывается, как в прототипе. Регресс — `tests/check_career_canvas.gd`.

## 1. Матрица покрытия

Статус: **есть** — экран работает и близок к эталону; **частично** — экран есть, но
структура/размеры/тексты расходятся (список в §3); **нет** — отсутствует.

| # | Экран / вкладка / модалка (прототип) | Svelte | CSS | Godot | Статус |
|---|---|---|---|---|---|
| 1 | Start (Continue / New Career / Load) | `StartScreen.svelte` | `creation.css` | `scenes/career_start.tscn`, `scripts/ui/career_start.gd` | есть |
| 2 | Load (список сейвов, удаление) | `LoadScreen.svelte` | `load.css` | `career_load.tscn/.gd` | есть |
| 3 | New Career (страна/лига/клуб/менеджер/формы) | `NewCareer.svelte` | `creation.css` | `career_new.tscn/.gd` | есть |
| 4 | Hub shell: TabBar, breadcrumb, hints | `Hub.svelte`, `ui/TabBar`, `ui/Breadcrumb`, `ui/AppShell` | `hub.css`, `theme.css` | `career_hub.tscn/.gd`, `UiTabBar`, `UiBreadcrumb` | частично |
| 5 | Centre tab: Next Match, Spotlight, Table, overlay | `Hub.svelte`, `career/centre/*` | `hub.css` | `career_hub.gd`, `career_hub_next_tile.gd`, `career_hub_table_tile.gd`, `career_hub_overlay.gd`, `career_spotlight.gd`, `career_row.gd` | есть |
| 6 | Squad Overview: плитки + ростер | `squad/SquadOverview`, `SquadTile`, `SquadRoster`, `SquadRosterRow` | `squad.css` | `career_squad_view.gd` (View.OVERVIEW) | есть |
| 7 | Squad Plan: поле, скамейка, схемы, роли | `squad/PlanView`, `PitchBoard`, `BenchDrawer`, `SchemesPanel`, `RolesPanel`, `RoleGlyph` | `squad-players.css` | `career_squad_view.gd` (PLAN) + `GpfGamePlan` | частично |
| 8 | Details (4 страницы, пейджер) | `Hub.svelte` → `details-panel`, `shared/PlayerBlock`, `shared/RadarChart` | `squad-players.css` | `career_squad_view.gd` (DETAILS) | частично |
| 9 | Squad Centre: 4 вкладки (Status/Statistics/Attributes/Finance) | `squad/SquadCentre`, `SquadCentreTabs`, `Player*Pane` | `squad.css`, `squad-players.css` | `career_squad_view.gd` (CENTRE) | частично |
| 10 | Squad actions (ряд действий над игроком) | `shared/SquadActions.svelte` | `squad.css` | — | нет |
| 11 | Player actions modal | `PlayerActionsModal.svelte` | `modals.css` | — | нет |
| 12 | Negotiation screen (контракт) | `squad/NegotiationScreen.svelte` | `modals.css` | — | нет |
| 13 | Number screen (игровой номер) | `squad/NumberScreen.svelte` | `modals.css` | — | нет |
| 14 | Release screen (расторжение) | `squad/ReleaseScreen.svelte` | `modals.css` | — | нет |
| 15 | Amount modal (зарплата/отступные/сумма) | `shared/AmountModal.svelte` | `modals.css` | — | нет |
| 16 | Transfers hub (карточки разделов, фид отчётов) | `transfers/TransfersTab`, `TransferHub`, `TransferHubCard`, `TransferPlayers`, `TransferHistory` | `transfers.css` | — (плитка «TRANSFER CENTRE · soon») | нет |
| 17 | Transfer filters + results (+ OSK поиска) | `TransferFilters`, `TransferFilterTile`, `TransferResults`, `transfers/OnScreenKeyboard` | `transfers.css` | — | нет |
| 18 | Transfer Centre (shortlist/listed/received/sent, офферы) | `TransferCentre`, `TransferListed`, `Sent|ReceivedOfferCard|Detail` | `transfer-centre.css` | — | нет |
| 19 | Transfer offer / contract screens + ScoutPicker | `TransferOfferScreen`, `TransferContractScreen`, `ScoutPicker` | `transfers.css` | — | нет |
| 20 | Scouting (задания, карта, отчёты, скауты) | `Scouting.svelte`, `career/scouting/*` | `scouting.css`, `scouting-reports.css` | — (вкладка SCOUTING пустая) | нет |
| 21 | Matchday (результаты → таблица после тура) | `career/match/MatchdayOverlay`, `MatchdayScreen.svelte` | `matchday.css` | `career_match_overlay.gd` | есть |
| 22 | Match simulation (setup → live → final) | `career/match/MatchSimulationOverlay`, `MatchScreen.svelte` | `match.css` | `career_match_overlay.gd` | есть |
| 23 | Season review (2 шага) | `career/match/SeasonReview.svelte` | `match.css` | — | нет |
| 24 | Bench drawer (скамейка поверх поля) | `BenchDrawer.svelte`, `BenchPlayerCard.svelte` | `squad-players.css` | `career_squad_view.gd` (`_draw_bench_drawer`) | есть |

Общие виджеты прототипа (`web/src/lib/ui/*`, `career/shared/*`): `AppShell`, `TabBar`,
`Breadcrumb`, `Tile`, `Row`, `Glyph`, `Legend`, `PlayerPhoto`, `portal`/`modalFocus`,
`RadarChart`, `MoraleFace`, `StrengthBadge`, `StandingsTable`, `CentreProfile`,
`CentreInfoRow`, `ContractTerms` — в Godot им соответствуют `UiStage`/`UiScreen`,
`UiTabBar`, `UiBreadcrumb`, `BentoTile`, `UiHintsBar`, `UiModal`, `UiOnScreenKeyboard`,
`GpfGamePlan`, `PauseLineup`, а радар/мораль/сила/таблица нарисованы внутри
`career_squad_view.gd` / `career_hub_table_tile.gd`.

Структурное расхождение (важно): в прототипе верхние вкладки — `Центр · Состав ·
Трансферы · Офис (disabled) · Сезон (disabled)`, а скаутинг живёт **внутри** Трансферов
(«Сеть поиска»). В Godot вкладки — `CENTRE · SQUAD · TRANSFERS · SCOUTING`, то есть
SCOUTING вынесен на верхний уровень. Решение по паритету — пакет C: трансферы+скаутинг
получают свою внутреннюю навигацию как в прототипе; верхние вкладки ужимаются до
`CENTRE · SQUAD · TRANSFERS`.

## 2. Пакеты работ (файловая собственность)

Правило: у каждого пакета свои файлы; общие файлы (`ui_tokens.gd`, `career_hub.gd`,
`career_hub.tscn`, `capture_career_shots.gd`, `log.md`, wiki, `career_hub_model.gd`)
правит только оркестратор после слияния.

### Пакет A — паритет существующего (приоритет 1)

| Агент | Задача | Вправе менять | Не трогает |
|---|---|---|---|
| A1 | Squad Centre: полоса вкладок, STATUS, STATISTICS, ATTRIBUTES, FINANCE, детали | `scripts/ui/career_squad_view.gd`, `tests/check_career_squad_centre.gd` (новый) | `career_hub*`, `ui_*`, `career_*.gd` (логика), `tests/capture_career_shots.gd`, `gpf_game_plan.gd` |
| A2 | Plan/Details в режиме карьеры (поле, скамейка, схемы, роли, details-страницы) | `scripts/ui/career_squad_plan.gd` (выделить из `career_squad_view.gd`, если нужно), `tests/check_career_squad_plan.gd` | всё остальное |
| O (оркестратор) | Хлебные крошки хаба, регистрация подэкранов, `capture_career_shots.gd`, токены, вики | `career_hub.gd/.tscn`, `ui_tokens.gd`, `ui_breadcrumb.gd` | пакетные файлы агентов |

Замечание: `career_squad_view.gd` — один файл на 2976 строк, поэтому A1 и A2 **нельзя**
запускать параллельно на нём. Порядок: A1 → слияние → A2 (после решения о выделении
Plan/Details в отдельный контрол).

### Пакет B — вход и модалки

`scripts/ui/career_start.gd`, `career_load.gd`, `career_new.gd`, новые
`career_player_actions.gd`, `career_negotiation.gd`, `career_number.gd`,
`career_release.gd`, `career_amount_modal.gd`; логика — `scripts/career/career_contract.gd`
(новый, чистые функции из `server/career/contracts.py`), тесты `tests/check_career_*.gd`.
Не трогает: `career_hub.gd` (регистрацию делает оркестратор), `career_squad_view.gd`
(вызов модалки добавляет оркестратор), `ui_*`.

### Пакет C — Трансферы и Скаутинг

`scripts/career/career_transfers.gd`, `career_scouting.gd` (новые, порт `server/career/*`
и `state/transfers.svelte.js`), `scripts/ui/career_transfers_*.gd`,
`scripts/ui/career_scouting_*.gd`, тесты. Внутренняя навигация — как в прототипе
(hub → filters/results/centre/offer/contract/network/history). Не трогает: `career_hub*`
(вкладки/крошки — оркестратор), `career_squad_view.gd`.

### Пакет D — Сезон и матчдэй

`scripts/ui/career_match_overlay.gd`, новый `career_season_review.gd`,
`scripts/career/career_season.gd` (+`career_match.gd` при необходимости), тесты.
Не трогает: `career_hub.gd` (маршрутизация — оркестратор), `career_squad_view.gd`.

Порядок исполнения: **A1 → (A2 ∥ O) → B → C → D**. B/C/D начинаются только после того, как
пакет A зелёный, чтобы не плодить конфликты в `career_hub`.

## 3. Известные расхождения пакета A (проверяются и добиваются, не считаются сделанными)

Проверено по `career_squad_centre_1920x1080.png` и коду `career_squad_view.gd`:

1. **Крошки** — в подэкранах хаба нет строки `КАРЬЕРА › СОСТАВ › ЦЕНТР СОСТАВОВ`
   (в прототипе `Breadcrumb` заменяет `TabBar` при `subview`). Godot: `career_hub.gd`
   всегда показывает `tab_bar`. → пакет O.
2. **Полоса вкладок центра** — в `career_squad_view.gd` активная вкладка на светлой
   плашке, остальные просто текст на фоне поля; в прототипе вся полоса на `--tile`
   (`TAB_STRIP`) высотой та же, что в хабе. → A1.
3. **STATISTICS** — нет заголовка `SEASON TOTAL`, другой порядок плиток, блок по
   турнирам мёртв: UI читает `player.competition_stats`, а `CareerSquad.enrich_players()`
   поле не отдаёт, хотя `stats_by_competition` в состоянии есть. Карточка турнира должна
   показывать `N И · N мин` + метрики (сухие/голы/ассисты, ЖК, КК) на фоне. → A1
   (+ правка `scripts/career/career_squad.gd` — за оркестратором, чтобы не пересекаться).
4. **ATTRIBUTES** — нет радара у вратаря (сейчас текст `GOALKEEPER PROFILE`), нет звёзд
   «Финты»/«Слабая нога» (`weak_foot`/`skill_moves` в данных есть), нет «Контракт»,
   лишний `APPS`, пейджер должен быть внизу слева `‹ R ›` + точки (сейчас две стрелки
   справа сверху). → A1.
5. **FINANCE** — нет строки-меты под шапкой панели (позиция · возраст · амплуа · настрой),
   шапка таблицы 36px на `--tile` с тенью (сейчас тонированная полоса 28px), строки 50px
   (сейчас 44), карточки-сводки 32px/14×18. → A1.
6. **STATUS** — нет бейджа травмы «+» на портрете в списке и в таблице финансов, строки
   панели без белых плашек, имя в шапке 28px (сейчас 24), вторая строка морали всегда
   `Expected N% of time`. → A1.
7. **Везде** — скроллбар списка, тень панели, подсказки (в прототипе инлайн-текст без
   плашек, с пунктом «Сохранить» и «Страницы» на характеристиках). → A1 (подсказки —
   только контент `hints()`, сам виджет `UiHintsBar` не менять).

## 4. Критерий приёмки (на экран)

- 1920×1080: совпадают структура, порядок элементов, английские подписи, размеры шрифтов
  и блоков, отступы, цвета из токенов.
- Открытие/закрытие экранов, модалок и дроверов анимировано (`UiTransition` + tween).
- Скриншот «до/после» прототип ↔ Godot, тест `tests/check_career_<screen>.gd` зелёный,
  `--headless --quit` без новых ошибок.
