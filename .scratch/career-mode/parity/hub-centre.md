# Паритет: вкладка Centre (центр карьеры)

Скоуп: `NextTile`, `TableTile`, `CareerHubOverlay` (+ переиспользуемые `CareerRow`/`CareerSpotlight`) на канве
карьеры 1664×680.4. Эталон — прототип `gf-career-prototype` на 1920×1080 (DOM-замеры `getBoundingClientRect()`
+ `getComputedStyle()` с выключенными анимациями), Godot — окно 1920×1080 через `SubViewport`.

## Скриншоты

| что | файл |
| --- | --- |
| прототип, Centre (idle) | `.scratch/ui_shots/proto/centre_1920x1080.png` |
| прототип, Centre (`:focus` на hero) | `.scratch/ui_shots/proto/centre_focus_1920x1080.png` |
| прототип, Centre (карьера «Parity Shots», autofocus) | `.scratch/ui_shots/proto/hub_centre_1920x1080.png` |
| прототип, турнирный оверлей | `.scratch/ui_shots/proto/centre_overlay_1920x1080.png` |
| Godot ДО | `.scratch/ui_shots/career_hub_centre_before_1920x1080.png`, `career_hub_centre_idle_before_1920x1080.png`, `career_hub_centre_overlay_before_1920x1080.png` |
| Godot ПОСЛЕ | `.scratch/ui_shots/career_hub_centre_1920x1080.png` (focus), `career_hub_centre_idle_1920x1080.png`, `career_hub_centre_overlay_1920x1080.png` |

Прототип снят на сохранении AFC Bournemouth (28.02.2027, тур 35 — **не** матчевый день): это тот же класс
состояния, что и у Godot-капчи (свежая карьера, `CareerFactory.create(..., 131, ...)`, тур 1), т.е. виден
календарный hero, а не плитки PLAY/SIMULATION. Геометрия подтверждена и по `hub_centre_1920x1080.png`.
Проверки вьюпорта: `innerWidth===1920`, `matchMedia('(max-width:1200px)')===false`,
`matchMedia('(max-height:800px)')===false`.

## Таблица паритета

| элемент | прототип (замер) | Godot (после) | статус |
| --- | --- | --- | --- |
| Карточка hero | 827×293.6, padding `18px 20px`, `gap 8`, `space-between` по вертикали | 827×293.2 (канва −0.4), padding 20/18, блоки распределены тем же правилом | ✅ |
| Eyebrow | 16px Inter 600, tracking .08em, `ink-2`, (20, 18), строка 23.2 | 16px Inter 600, tracking 1px, `INK_2`, (20, 18), 23.2 | ✅ |
| Заголовок | 52px Barlow 800, line-height .92 (47.84), ls −.26px, (20, 49.2), max-width 72% | 52px Barlow 800, бокс 47.84 в (20, 49.2), ширина 72% | ✅ |
| Месяц | 16px Inter 600, tracking .06em, справа по padding (правый край 807) | 16px, tracking 1px, правый край 807 | ✅ |
| Полоса дней | 787×55 в y=114.2; 7 колонок по 112.43, ячейка 106.4 (поля 3), шаг 112.43 | 787×55 в y=114.1; ячейка 106.4, шаг 112.43 | ✅ |
| День: будний день | 16px Inter 600, line-height 1, tracking .06em, `ink-2`, y+7, h16 | 16px, tracking 1px, `INK_2`, y+7, h16 | ✅ |
| День: число | 24px Barlow 700, line-height 1, y+25, h24 | 24px Barlow 700, y+25, h24 | ✅ |
| День: фон | `ink` .055 / сегодня .12 / матч .18; в фокусе `focus-ink` .08/.16/.22 | те же значения | ✅ (было .035/.10/.10, без разделения today/match) |
| День: герб | 22×22, absolute top 4 / right 5 | 22×22 в (cell_w−27, 4) | ✅ |
| Матч: строка | y=186.4, h=42, прижата влево, зазоры 10 (герб↔имя) и 16 (имя↔VS↔имя) | y=186.1, h=42, та же упаковка (сжатие имён при переполнении) | ✅ (было: home слева / away по правому краю) |
| Матч: герб | 42×42 | 42×42 | ✅ |
| Матч: имя | 24px Barlow 700, uppercase, tracking .02em | 24px Barlow 700, uppercase | ✅ |
| Матч: VS | 16px Inter 600, tracking .14em, `ink-2` | 16px Inter 600, tracking 2px, `INK_2` | ✅ |
| Низ: meta | 16px Inter 500, `ink-2`, строка 23.2, низ по padding (y 252.4) | 16px, `INK_2`, y 252.0, низ 275.2 | ✅ (было y = size−44) |
| Низ: форма | пилюли 30×30, gap 6, фон `ink` .12 / в фокусе `focus-ink` .14, текст `ink-2` / `focus-ink` | 30×30, gap 6, те же цвета | ✅ (было 28×28, 15px, текст `ink`) |
| Фокус hero | фон `#171b3f`, scale 1.008, заголовок `focus-mark`, eyebrow/month/VS/meta/week `focus-ink-2` | то же (плюс заголовок теперь `FOCUS_MARK`, раньше `FOCUS_INK`) | ✅ |
| Таблица: карточка | padding 18, gap 8 | padding 18 | ✅ (было 22) |
| Таблица: заголовок | 30px Barlow 700, lh .92 (27.6), (18, 18) | 30px, (18, 18), 27.6 | ✅ |
| Таблица: лига | 16px Inter 600, tracking .04em, (18, 47.6) | 16px, tracking 1px, y 47.6 | ✅ (было y 52) |
| Таблица: тур | 16px Inter 600, tracking .06em, справа сверху | 16px, tracking 1px, правый верх | ✅ |
| Таблица: шапка | h 18, 16px Inter 600 uppercase, tracking .06em, `ink-2`, сетка 24/24/1fr/30/34, gap 8, padding 0 6 | h 18 в y 78.8, те же колонки/типографика | ✅ (было y 80, h=строка) |
| Таблица: строки | h 24.47, gap 1, 16px Inter 400; имя `ink` 400, место/И `ink-2`, О 700 `ink` | h 24.4, gap 1, те же веса/цвета | ✅ (было: 500/600, отступ 12 слева) |
| Таблица: своя команда | фон `rgba(29,33,56,.10)`, inset-рейл 2px `rgba(29,33,56,.18)`, имя и О 700 | `Color(INK,.10)`, рейл 2px `Color(INK,.18)`, имя/О 700 | ✅ (было: розовый `TABLE_ROW_OWN`, рейл `RAIL`) |
| Таблица: разделители | нет (ни `border`, ни `box-shadow`) | убраны | ✅ (было 1px `ink` .10) |
| Таблица: точки | 5×(16×16), gap 2, марка 6×6 радиус 3, правый низ, отступ 18 | те же позиции (y 259.2, правый край 809) | ✅ (было y 255.2) |
| Таблица: placeholder | «Skoro» влево, по центру по вертикали, 16px `ink-2` | влево + вертикальный центр | ✅ (было по центру) |
| Секции | TABLE, SCORERS, FIXTURES, TOP TRANSFERS, NEW TRANSFERS | те же (модель уже совпадала) | ✅ |
| Оверлей: карточка | 1664×645.2, padding `12px 20px 10px 24px` | 1664×644.4, padding 12/20/10/24 | ✅ (−0.8 — канва) |
| Оверлей: eyebrow | 16px Inter 600, tracking .08em, (24, 12), h20 | 16px, tracking 1px, (24, 12) | ✅ (было y 16) |
| Оверлей: разделитель | 1px `ink` .15 на y 38 | 1px `Color(INK,.15)` на y 38 | ✅ (было 2px на y 44) |
| Оверлей: таблица | от y 39.7, ширина 1620 (4px справа), шапка 28, строки 25 | от y 39, ширина 1620, шапка 28, строки 25 | ✅ (было строки 27.3, шапка 26) |
| Оверлей: колонки | # 52 центр, CLUB 34% влево (герб 18 + gap 8), 7 равных по центру, PTS 58 центр | то же | ✅ (было 40/26/50/50/50/50/60/60/70/60, числа справа) |
| Оверлей: шапка | 16px Inter 600 uppercase, tracking .04em, `ink-2`, низ 1px `ink` .15 | 16px 600 tracking 1px, тот же разделитель | ✅ (было 15px) |
| Оверлей: строки | 16px Inter 400, низ 1px `ink` .08 | 16px 400, тот же разделитель | ✅ |
| Оверлей: своя команда | фон `#171b3f`, текст `focus-ink`, вес 600 по всем ячейкам | `FOCUS_FILL` + `FOCUS_INK` 600 | ✅ (было розовое) |
| Оверлей: скролл | 48px на шаг стрелки | `SCROLL_STEP = 48` | ✅ (было = высота строки) |
| Оверлей: закрытие/открытие | fade+scale 150/240 у `UiTransition` (владелец — хаб) | без изменений | ✅ |
| Плитки `is-soon` | padding 18, заголовок 32px, eyebrow «ПЕРЕГОВОРЫ», plain «СКОРО» справа сверху, glyph 68/64 в right 18 / bottom 14, sub max 30ch | 22/24, 44px, без eyebrow, чип-панель слева снизу, glyph 76, sub 340 | ⛔ общий виджет (см. ниже) |
| Матчевые плитки PLAY/SIMULATION | `.home-action`: eyebrow «МАТЧ», заголовок, герб 64, meta-строка, foot «vs … / лига» | `set_copy(title, sub, meta, tags)` в 4 поля BentoTile | ⛔ общий виджет (см. ниже) |

## Что изменено

`scripts/ui/career_hub_next_tile.gd`
- Геометрия переписана с фиксированных координат (24/14/34/106/176) на CSS-модель: padding 20/18, блоки
  eyebrow+заголовок → полоса дней → матч → подвал, остаток высоты делится между блоками (аналог
  `space-between` при `gap: 8`), поэтому координаты совпадают при любой высоте плитки.
- Полоса дней: 7 колонок шагом `inner/7`, ячейка −6 (поля 3), будний день 16px/24px вместо 10px/22px,
  герб 22×22 на top 4/right 5.
- Матч: упаковка влево как у flex-строки прототипа (крест, имя, VS, имя, крест; имена сжимаются при
  переполнении) вместо «home слева / away по правому краю».
- Подвал: meta по низу padding, пилюли 30×30, текст пилюль `ink-2` (в фокусе `focus-ink`).
- Фокус: заголовок → `FOCUS_MARK`; тона дней разделены (today/match/обычный, обычный/фокус).
- `setup()` теперь всегда пересчитывает раскладку (ширины имён зависят от текста).

`scripts/ui/career_hub_table_tile.gd`
- padding 22 → 18; заголовок 27.6 и лига на 47.6 (было 34/52); округление строки перенесено.
- Доска: шапка 18 + 6 строк по 24.4 с зазором 1 (было «шапка = строка»), строки шириной ровно
  `inner` (791) с внутренним отступом 6.
- Колонки 24/24/1fr/30/34 с gap 8 → позиции 6/38/70/713/751 (совпадают с прототипом до десятых).
- Веса: место 400, имя 400 (у своей — 700), И 400 `ink`, О 700; разделители строк убраны.
- Своя строка: `Color(INK, .10)` + рейл 2px `Color(INK, .18)` вместо розовых токенов.
- Точки опущены на 4.4px (y 259.2), плейсхолдер «SOON» выровнен влево + вертикальный центр.
- Стили строк вынесены в `_style_row()`/`_row_box()`, чтобы фокус и own-строка не дублировали код.

`scripts/ui/career_hub_overlay.gd`
- Паддинги карточки 12/20/10/24, eyebrow на 12, разделитель 1px на 38, скролл с 39 и на 10 выше низа.
- Таблица: `table-layout: fixed`-модель — # 52, CLUB 34%, 7 равных, PTS 58; шапка 28, строки 25 (сжатие
  только если клубов больше, чем помещается), верхний отступ 4.
- Числовые колонки по центру (были справа), шапка 16px/600 с трекингом 1px, тело 16px/400.
- Своя команда: `FOCUS_FILL` + `FOCUS_INK` + вес 600 (было розовое); разделители шапки .15 и строк .08.
- `scroll_step` — 48px на нажатие (как `input.js` в прототипе).

`scripts/ui/career_row.gd`, `scripts/ui/career_spotlight.gd` — **не менялись**: `CareerRow` — это `.gf-row`
для списка сохранений (`career_load.gd`), `CareerSpotlight` — карточка клуба в `career_new.gd`; в Centre-вкладке
(и в турнирном оверлее, который строит свои строки сам) они не участвуют.

Тесты: новый `tests/check_career_hub_centre.gd` (собирает обе плитки и оверлей без сцены хаба, ~46 проверок
геометрии/типографики/цветов) и `tests/capture_career_hub_centre_shots.gd` (состояния `centre`, `centre_idle`,
`centre_overlay` + печать прямоугольников и кеглей).

## Проверка трёх утверждений из задачи

1. **«Полоса дней: активный день — залитая тёмная ячейка, остальные тусклые»** — по числам не так:
   фон ячейки — альфа `ink` поверх светлой плитки: обычная `.055`, сегодня `.12`, матч `.18` (в фокусе —
   `focus-ink` `.08/.16/.22`). В autofocus-состоянии (`hub_centre_1920x1080.png`) все ячейки светлее плитки,
   сильнее всех — день матча. Структура «будний день над числом» подтверждена: 16px/600 над 24px/700,
   y+7 и y+25.
2. **«Строка своего клуба в таблице розовая с маджента-рейлом»** — это состояние *текущего Godot*, а не
   прототипа. В прототипе: `background rgba(29,33,56,0.1)` + `box-shadow: inset 2px 0 0 rgba(29,33,56,0.18)`,
   т.е. серый тон с серым рейлом (скриншот `hub_centre_1920x1080.png`, строка Arsenal FC). Исправлено.
3. **«Подсказки внизу — простой текст без клавишных плашек»** — не подтверждается: в разметке
   `<kbd>`-плашки, замер `background rgba(255,255,255,0.14)`, `padding 4px 8px`, шрифт 16px/600, без
   скругления; подпись 16px `rgba(246,248,251,0.86)`. Т.е. виджет с плашками правильный, но кегль/рамка
   у Godot другие — см. раздел общих файлов.

## Тесты

| тест | результат |
| --- | --- |
| `godot --headless --quit` | PASS (нет `SCRIPT ERROR` / `Parse Error`) |
| `tests/check_career_hub.gd` | `== check_career_hub: PASS (0 failures) ==` |
| `tests/check_career_canvas.gd` | `== check_career_canvas: PASS (0 failures) ==` |
| `tests/check_main_menu_ui.gd` | `== check_main_menu_ui: PASS ==` |
| `tests/check_career_hub_centre.gd` | `== check_career_hub_centre: PASS (0 failures) ==` |
| `tests/check_career_advance.gd` (регресс, hero после симуляции) | `== check_career_advance: PASS (0 failures) ==` |
| `tests/check_career_matchday.gd` (регресс, матчевый день) | `== check_career_matchday: PASS (0 failures) ==` |
| `tests/capture_career_hub_centre_shots.gd` (окно) | 3 PNG + печать замеров, без ошибок |

Печать капчи (совпадает с замером прототипа): `days pos (20.0, 114.1) size (787.0, 55.0) cell 106.4
step 115.4`, `fixture pos (20.0, 186.1)`, `meta pos (20.0, 252.0)`, `board head pos (18.0, 78.8)
size (791.0, 18.0) first row (791.0, 24.4)`, `columns pos x 6.0 crest x 38.0 name x 70.0 played x 713.0
pts x 751.0`, `overlay eyebrow (24.0, 12.0) scroll (24.0, 39.0) size (1620.0, 595.4)`,
`row head (0.0, 4.0) size (1616.0, 28.0) row data (0.0, 32.0) size (1616.0, 25.0)`.

## Требуется правка общих файлов (не мои файлы)

1. `scripts/ui/bento_tile.gd` — **рейл перевёрнут**: `_rail.visible = not _selected` рисует рейл у *невыбранной*
   плитки, а прототип показывает его только на фокусе (`.gf-tile::before` opacity 0 → 1). Плюс
   `UiTokens.RAIL_W = 6`, в CSS `--rail-w: 2px`. По пикселям: в PNG прототипа маджента на кромке плиток
   отсутствует и в idle, и в фокусе (проверено выборкой пикселей), т.е. нужен либо 2px-рейл только на
   фокусе, либо ничего. Сейчас Godot рисует 6px розовую полосу на каждой спокойной плитке.
2. `bento_tile.gd` + `ui_theme.gd` — плитки `is-soon` (`TRANSFER CENTRE`, `URGENT NEWS`, `TRAINING`):
   паддинг 24/22 → 18; заголовок `TileTitle` 44 → 32px (`.home-tile.is-soon .gf-tile__title`); нет eyebrow
   (у transfer он «NEGOTIATIONS», 16px/600, tracking .08em `ink-2`); `chip="SOON"` рисуется `SoonChip`
   (панель 12px слева снизу), в прототипе это простой текст 16px/600 tracking .08em `ink-2` в
   `top:18 right:18`; glyph `GLYPH_SMALL` 76 → 68 (transfer/news) и 64 (training) в `right:18 / bottom:14`,
   цвет `ink-2` с opacity .72; sub max-width 340 → 30ch (309.8).
3. `bento_tile.gd` — матчевые `PLAY`/`SIMULATION` (`.home-action`): нужен eyebrow («MATCH»), заголовок
   32px, герб 64 справа сверху, meta-строка «ROUND n · date · HOME/AWAY» 16px и foot
   «vs OPP | LEAGUE» 16px uppercase. Сейчас `set_copy(title, sub, meta, tags)` кладёт всё в 4 разных
   места (заголовок, sub, meta снизу, tags справа) — структурно не то же самое. Правится только в
   `bento_tile.gd`/сцене хаба.
4. `shaders/ui_hatch.gdshader` + `bento_tile.gd`: штриховка hero начинается с `size.x * 0.48`, в CSS — 52%
   (`inset: 0 0 0 auto; width: 52%`), и `line_color` берётся из цвета заголовка, поэтому в фокусе штрихи
   лаймовые; в прототипе `currentColor` = цвет текста плитки (`focus-ink`).
5. `ui_legend.gd`/`ui_theme.gd`/`ui_tokens.gd` (подсказки): плашка `kbd` 12px с рамкой `KBD_BORDER` 1px и
   content-margin 8/2 против прототипа 16px/600 без рамки, `padding 4px 8px` (высота 23); подпись 15px
   против 16px. `UiTokens.SIZE_KBD = 12 → 16`, `SIZE_LEGEND = 15 → 16`, рамку убрать.

## Не проверено / риски

- Наведение мыши, `disabled` и анимации 140ms на цветах (`transition: color/background 140ms linear`) в
  Godot не воспроизводятся — состояния переключаются мгновенно (как и было во всём порте).
- Клиппинг длинных имён в строке матча и в колонке клуба оверлея проверен только кодом (`clip_text`,
  уменьшение ширины при переполнении), на длинных названиях вживую не смотрел.
- Сезон-комплит состояние hero (`.home-season` + `home-cta`) сверено только по разметке: в Godot модель
  отдаёт «SEASON / SEASON COMPLETE» и мета-строку, отдельного блока CTA нет (это состояние модели, не вёрстки).
- Турнирный оверлей: смена секций (SCORERS/…), счётчик турниров (`1 / N`) и Q/E-хинт в Godot не
  реализованы — в порте всегда одна лига; хинт-бар показывает только scroll/back.
- Капча зависела от соседнего агента: `career_squad_view.gd` в процессе правки ломал загрузку хаба
  (ошибка разбора на его стороне). Финальные прогоны — уже на его рабочей версии; мои файлы от него не зависят.
- Замер `getBoundingClientRect` для оверлея снят при открытии через `.home-table` (клик по действию
  карьеры не нажимался).
