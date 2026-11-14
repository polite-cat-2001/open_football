# SQUAD → Squad Centre + Details: паритет с прототипом

Файл: `scripts/ui/career_squad_view.gd` (единственный изменённый файл UI).
Эталон: `gf-career-prototype` на 1920×1080, карьера «Parity Shots» (Arsenal FC, +5 туров).
Все числа ниже — из `getBoundingClientRect()` / `getComputedStyle()` прототипа (анимации
выключены: `*{animation:none!important;transition:none!important}`) и из `print()` в
`tests/capture_career_squad_shots.gd`.

## Таблица сравнения

| элемент | прототип | Godot (было → стало) | статус |
|---|---|---|---|
| канвас подвью | `.squad-overview` 1664×597.2 при y=258.6 (тело 596.4) | 1664×596.4 при локальном y=48 (тот же body) | ок (0.8px — разница канваса, см. ниже) |
| полоса табов `.centre-tabs` | 38px, gap 6, `padding 0 20` | 38px, gap 6, ширина = текст+40 | ок |
| плашка таба (неактивный) | `rgba(245,247,250,.72)` | рисовалась только активная → добавлена плашка `Color(TILE,.72)` | ок |
| плашка таба (активный) | `var(--tile)` + `inset 0 -4px 0 var(--rail)` | маркер = TILE + 4px RAIL | ок |
| шрифт таба | Barlow Condensed 20/700 | Barlow 700, 20 | ок |
| колонки тела `.centre-body` | 1.05fr/0.95fr → 868.3 / 785.6 | 868.35 / 785.65 | ок |
| строка списка `.centre-player-row` | 50px, шаг 53, `padding 4 10 4 12`, grid `32 / 1fr / 40 / 28`, gap 8 | 50 / 53, фото 12,5 32×40 | ок |
| имя строки | Barlow 19/700, y +6 | 19/700, y +6 | ок |
| мета строки (поз-бейдж + роль) | Inter 14, бейдж в цвете позиции, gap 8 | 14, бейдж `_role_color`, x = 60 + ширина бейджа | ок |
| OVR в строке | Barlow 20/700, центр колонки 40, x = right−10−28−8−40 | та же формула | ок |
| лицо настроения в строке | MoraleFace 20px (круг-обводка + глаза + рот), `—` если нет expected_minutes | штрихованный круг + глаза + рот по морale, `—` при 0 | ок |
| бейдж травмы `+` | 20×20, `mark-loss`, top-right фото | было 16×16 → 20×20 (список, фин-таблица, профиль панели) | ок |
| профиль в панели | фото 64×78 при +18/+14; kicker 13/600; имя Barlow 28/700 lh 27.4; sub 14/500 | было 24/15 → 28/700, 14/500, блок центрируется по фото | ок |
| блок настроения | плашка `ink 5%`, `padding 8 10`, gap 4, h 59.5; MORALE 14/600; значение Barlow 22; лицо 20px | было 66 высотой, «Actual … Planned … % expected» одной строкой → 59.5, лицо + значение справа, две строки | ок |
| вторая строка настроения | слева `Факт N · План N мин`, справа `Ожидается N% времени` | `Actual N · Planned N min` / `Expected N% of time` (реальные числа из `expected_share`) | ок |
| заголовок секции `.centre-block-head` | 13/600 uppercase, `padding-bottom 4`, линия `inset 0 -2px` ink 12% | было 14 + линия на +24 → 13/600, линия на дне блока (2px) | ок |
| строки блока `.gf-info-row` | белая плашка `rgba(255,255,255,.6)`, `padding 3 8`, h 23.5; label 14/600 uppercase ink-2, value 14/600 ink | рисовался только текст → добавлена плашка и размеры | ок |
| сетка итогов `.centre-total-grid` | `padding-top 8`, gap 10, карточка 75.2 (`padding 10 6`), значение Barlow 28, подпись 16 uppercase по центру | было карточка 88, 30/13 → 75.2, 28/16 | ок |
| порядок плиток | вратарь: Игры, Сухие, Минуты; поле: Игры, Голы, Ассисты, Минуты | было APPS/MINUTES/CLEAN_SHEETS и APPS/MINUTES/GOALS/ASSISTS → порядок прототипа (`_season_metrics`) | ок |
| заголовки статистики | «Итого в сезоне» / «По турнирам» | `SEASON TOTAL` / `BY COMPETITION` через новый `_draw_section_head` | ок |
| карточка турнира `.competition-card` | `margin-top 8`, `padding 12 14`, `ink 5%`, gap 8; имя Barlow 20/700 uppercase; мета 16 ink-2; метрики 16 uppercase, значения 18/700, «сухие» — `mark-win` | было списком строк → карточка h 87.1 с мета `N APP · N MIN` и метриками `CLEAN SHEETS / GOALS / ASSISTS / YELLOW / RED` на тонированной плашке | ок |
| радар во вкладке ATTRIBUTES | `RadarChart` 150×150 для всех, включая вратарей (viewBox 164, R44, подписи на 58) | было «GOALKEEPER PROFILE» текстом → радар; радиус 44/164, подписи 58/164, шрифт подписи 19·(w/164) | ок |
| пейджер `.centre-pager` | `left 18, bottom 14`, 138×30, `ink 5%`; `‹`/`›` 22×26, «R» 22×22, точки 6px через 4 | было две стрелки в правом верхнем углу → пейджер внизу слева с точками и «R» | ок |
| GENERAL (ATTRIBUTES) | заголовок 16/600 (27.2), факты `поз-бейдж · позиция · Age N · роль` (16), gap 8 между блоками | было 6 строк «AGE/SQUAD ROLE/…» в две колонки → одна строка фактов | ок |
| признаки (traits) | 2 колонки, gap 2/20, ячейка 31.2: Morale, Skill moves ★, Weak foot ★, Potential, Value, Contract | было APPS и без звёзд → звёзды 18px (`mark-warn` / ink 20%), `CONTRACT` добавлен, `APPS` убран | ок |
| RADAR-грид | 2 колонки, ячейка 31.2, label 16 ink-2 + 16/700 ink | так же | ок |
| страницы характеристик | `attribute-rows`: 2 колонки, gap 0/24, чип значения `min-width 38`, `padding 2 8`, `ink 6%`, 16/700 в цвете `statTone` | было без чипов, Barlow 16 → чипы | ок |
| фин-сводка `.finance-summary` | 3 карточки 89.2 (`padding 14 18`, gap 6): label 16/600 uppercase, значение Barlow 32, «/ нед.» 16/500 ink-2 | было 72 высотой, 15/28 → 89.2, 16/32 + суффикс `/ WEEK` другим начертанием | ок |
| шапка фин-таблицы | 36px, `padding 0 10 0 12`, плашка `--tile` + `--shadow-tile`, 16/500, POS и PLAYER слева, остальные справа | было 28px на тонированной полосе, 13/600 → 36px плашка-тайл, 16/500 | ок |
| строки фин-таблицы | 50px, шаг 53, grid `52 / 1fr / 52 / 104 / 104 / 84`, gap 12 | было 44/46 и другой grid → 50/53, колонки 12 / 76 / 571.6 / 635.6 / 751.6 / 867.6 | ок |
| фин-панель: мета-строка | поз-бейдж · Age N · роль · Настрой N% (16/500) | добавлена (`_draw_finance_meta`) | ок |
| колонки фин-тела | `1fr / 0.72fr` → 961.6 / 692.4 | было 1.05/2 → 961.6 / 692.4 | ок |
| обзор: шапка клуба | kicker 16/600, имя Barlow 40/700 (39.2), sub 16/500, действие 16/600 по центру шапки 88.8 | было имя 34, sub на +58, действие по верху → 40/700, +24.8 и +68, действие центрировано | ок |
| обзор: поле | y = верх + 20 + 88.8 + 12, h = 597.2−169.6 = 427.6 | было +132 и −193 → 120.8 и size−169.6 | ок |
| обзор: фут-строка | 16/500 на 16px от низа | так же (было 21) | ок |
| обзор: StrengthBadge | в правом верхнем углу поля (12/12 от края, 79.7×44) | не рисовался → добавлен | ок |
| обзор: заметка тайла | ширина колонки метки, прижата к 16px от низа, переносится | было фикс-блок 42 с центровкой → перенос по ширине колонки и выравнивание по низу | ок |
| обзор: выбранный тайл | лого 60×60 + галочка 18×18 под ним (gap 8), в заметке — имя клуба | было лого по центру и заметка «Current first team» → лого сверху колонки, галочка под ним, заметка = имя клуба | ок |
| обзор: иконки тайлов | 44×44 по центру по вертикали, 18px от правого края | было со сдвигом −10 → по центру | ок |
| Details (R) | 4 страницы: «Общая информация» / «Статы 1» / «Статы 2» / «Сезон» | было ATTRIBUTES/STATUS/STATISTICS/FINANCE → `GENERAL` / `STATS 1` / `STATS 2` / `SEASON` | ок (см. оговорку о доступности) |
| Details: заголовок | Barlow 26/700, `padding 18 22 16`, заголовок на +18 | было +16 → +18 | ок |
| Details: строки инфо/сезона | значение 16/600 слева, подпись 16/400 по центру, шаг 37.2 | было 28/28 и подпись по 35–65% → 37.2, подпись центрирована в 130px | ок |
| Details: страницы статов | 2 колонки по 382.5, gap 18; заголовок группы `padding 10 0 4` + линия; строка 39.2, чип 46×27.2 + подпись 16/400 | было 3 колонки с Barlow → 2 колонки с чипами | ок |
| Details: точки | 8×8, gap 6, по центру, 24px от низа | было 26 и 14 шаг → 8×8, шаг 14, −24 | ок |
| подсказки | обзор: Tabs, Game plan, Back, Save; центр: Player, [Pages], Tabs, Back, Save; details: To pitch, Game plan, Pages, Save | было без Save, без Pages, «Navigate»/«Select»/«Clear» → набор прототипа (`hints()`) | ок |
| плашки табов плана | неактивный `rgba(245,247,250,.55)` | не рисовались → добавлены | ок |

## Список правок (`scripts/ui/career_squad_view.gd`)

1. `_draw_centre` / `_draw_centre_tab`: плашки всех табов (активная — маркер, неактивная `Color(TILE,.72)`), цвет фокуса+активного — `FOCUS_MARK`.
2. `_draw_centre_roster`: геометрия строки из CSS (имя +6, мета +27, бейдж-колонка по ширине текста, OVR по формуле `40/28/8`, лицо 26×20), бейдж травмы 20×20.
3. `_draw_morale_face`: порт `MoraleFace.svelte` (обводка, глаза, рот по настроению).
4. `_draw_morale_block` + новый `_morale_lines`: высота 59.5, лицо+значение, две строки с `Expected N% of time`.
5. Новый `_draw_section_head` (13/16/600 + линия 2px) вместо локальных заголовков; `_draw_pane_block` переписан на белые плашки 23.5.
6. `_draw_centre_pane`: профиль по центру фото (kicker 13, имя 28, sub 14), контент начинается через 5px под фото; панель ATTRIBUTES без стрелок сверху.
7. `_draw_total_grid` (75.2, 28/16, порядок по роли) + новый `_season_metrics`; новый `_draw_competition_cards` (карточка 87.1 с метриками) — на `competition_stats`.
8. `_draw_attribute_pane` + `_draw_attribute_overview`, `_draw_attribute_rows`, `_draw_stars`, `_draw_attribute_pager`: радар 150 и для вратарей, GENERAL/признаки/звёзды/CONTRACT, RADAR-грид, чипы, пейджер `‹ R ›` + точки внизу слева.
9. `_draw_finance_summary` (89.2, 16/32, суффикс), `_draw_finance_table` (36px шапка-плашка, 50/53 строки, 14px ячейки, фото+бейдж), `_finance_columns` (grid 52/1fr/52/104/104/84), `_draw_finance_meta`.
10. `_centre_metrics`: фин-раскладка `1fr/0.72fr`, сводка 89.2, таблица на 99.2.
11. `_draw_overview`: StrengthBadge в поле; `_draw_team_tile` (40/700, 88.8 шапка, фут 20.8); `_team_pitch_rect`; `_draw_squad_tile` (заметка с переносом по низу, иконки/лого/галочка по колонке 44/60, заметка выбранного = имя клуба).
12. `_draw_details` + `_draw_details_rows`, `_draw_details_groups`, `_details_info_rows`, `_details_season_rows`: страницы прототипа и их сетки; `DETAIL_PAGES = ["GENERAL","STATS 1","STATS 2","SEASON"]`; удалены `_draw_attributes_page/_draw_status_page/_draw_statistics_page/_draw_finance_page/_draw_info_rows` и хелперы `_general_rows`/`_season_rows`.
13. `hints()`: набор прототипа (Save везде, Pages на ATTRIBUTES и в details, labels Player/Tabs/Back/To pitch/Game plan/Compare/Swap/View/Cancel).
14. `_draw_plan`: плашки неактивных табов плана (0.55).
15. `_rebuild_elements`/`_ensure_centre_visible`: новые прямоугольники пейджера и фин-строк (36/50/53).
16. `_draw_radar`: пропорции `RadarChart.svelte` (44/164, подписи 58/164, шрифт 19·scale).
17. `_open_plan`: скрывает `_lineup_preview` (иначе обзорное поле оставалось поверх details-панели).

Новые файлы: `tests/check_career_squad_centre.gd`, `tests/capture_career_squad_shots.gd`.

## Скриншоты

Прототип (`.scratch/ui_shots/proto/`):

- `squad_overview_1920x1080.png`
- `squad_centre_status_1920x1080.png`, `squad_centre_stats_1920x1080.png`,
  `squad_centre_attrs_1920x1080.png`, `squad_centre_finance_1920x1080.png`
- `details_general_1920x1080.png`, `details_stats_1920x1080.png`,
  `details_stats2_1920x1080.png`, `details_season_1920x1080.png`
- `plan_squad_1920x1080.png` (шапка плана), `measure.json` / `measure_extra.json` — дампы
  `getBoundingClientRect()`/`getComputedStyle()` по всем элементам выше.

Godot (`.scratch/ui_shots/`):

- `career_squad_overview_1920x1080.png` ↔ `proto/squad_overview_1920x1080.png`
- `career_squad_centre_status_1920x1080.png` ↔ `proto/squad_centre_status_1920x1080.png`
- `career_squad_centre_stats_1920x1080.png` ↔ `proto/squad_centre_stats_1920x1080.png`
- `career_squad_centre_attrs_1920x1080.png` ↔ `proto/squad_centre_attrs_1920x1080.png`
- `career_squad_centre_finance_1920x1080.png` ↔ `proto/squad_centre_finance_1920x1080.png`
- `career_squad_details_1920x1080.png` ↔ `proto/details_general_1920x1080.png`

## Измеренные числа (Godot, `capture_career_squad_shots.gd`)

```
view centre (0, 48) (1664, 596.4)
tabs:  38 высота, gap 6, ширина = текст+40
list   [P: (0, 48), S: (868.35, 548.4)]
panel  [P: (878.35, 48), S: (785.65, 548.4)]
finance summary [P: (0, 48), S: (1664, 89.2)]
finance table   [P: (0, 147.2), S: (961.63, 449.2)]
finance columns pos 12, player 76, age 571.63, value 635.63, wage 751.63, years 867.63
```

## Тесты

| тест | результат |
|---|---|
| `tests/check_career_squad_centre.gd` (новый) | PASS (0 failures) |
| `tests/check_career_squad.gd` | PASS (0 failures) |
| `tests/check_career_canvas.gd` | PASS (0 failures) |
| `tests/check_career_hub.gd` | PASS (0 failures) |
| `godot --path . --headless --quit` | exit 0, только `[godot-mcp-runtime] Failed to listen …` |

`check_career_squad_centre.gd` проверяет: ширину колонок 868.3/785.6, 38px-плашки табов с
gap 6 и `padding 0 20`, строки 50/53, строку настроения `Expected N% of time` и `Actual …`,
порядок плиток по роли, наличие `competition_stats`, непустой радар у вратаря, пейджер внизу
слева (панель+26 / панель.end−42, вторая стрелка +82), фин-сводку 89.2 и таблицу на 99.2 с
колонками 12/76/571.6/635.6/751.6/867.6, страницы details (`GENERAL/STATS 1/STATS 2/SEASON`,
11 строк общей, 7 строк сезона, Weak foot/Skill moves), открытие details по `handle_details`,
листание `Q/E` и наборы подсказок (с Save, с Pages).

## Что не проверено / требует правки общих файлов

1. **Имя турнира в карточке**: показывается сырой id (`ES1`) вместо названия лиги. Причина —
   `CareerSquad.competition_stats()` подставляет `league_name` только когда
   `competition_id == career.league_id`; в этой карьере ключ блока не совпал. Правка —
   `scripts/career/career_squad.gd` (не мой файл): брать название из `career.data.league`
   либо из справочника лиг по id.
2. **Details и внутренний план недостижимы из хаба.** `handle_confirmed()` на плитке клуба
   эмитит `plan_requested` → хаб открывает общий `GpfGamePlan` оверлей, а `handle_details()`
   входит в detail-страницы только из `View.PLAN`. Поэтому `R` в хабе ничего не делает, и
   переделанные страницы видно только через API вью (тест/капчур вызывают `_open_plan()`
   + `handle_details()`). Решение — за `career_hub.gd`: либо роутить `R`/подтверждение в
   собственный план вью, либо убрать внутренние PLAN/DETAILS как мёртвый код.
3. **Карточки на поле** (обзор и план) — это `PauseLineup`/`_draw_pitch` с футболками, а в
   прототипе `PlayerCard` с фото игрока, чипом роли и именем. Общий компонент поля, не
   правил (см. issue 11 про унификацию плана).
4. **Канвас 0.8px**: тело хаба 596.4 против 597.2 в прототипе, поэтому всё, что прижато к
   низу (поле обзора, фин-таблица), на 0.8px короче; значения считаются от `size`, тест
   проверяет относительные величины.
5. **letter-spacing** (0.4px у табов, 0.52px у меток тайлов, 0.96px у фин-меток) не
   применяется: у `draw_string` нет трекинга, а рисовать по буквам — лишний код.
6. **Плашки клавиш подсказок**: прототип рисует клавиши почти без рамок, `UiHintsBar`
   рисует `KbdBox` — по заданию не трогал.
7. **Скроллбары** списков (7px) не рисуются — общая конвенция порта.
8. **Раскрывающиеся действия игрока** (`SquadActions`, is-open) в порте отсутствуют — не
   было и до этой задачи, вне паритета строк.
9. Живые скриншоты сфотографированы на карьере без сыгранных матчей: у всех игроков
   `expected_minutes = 0`, поэтому настроение в строках — `—` и мораль `—`. Условие то же,
   что в `SquadRosterRow.svelte`; на карьере прототипа (есть минуты) рисуется лицо.
