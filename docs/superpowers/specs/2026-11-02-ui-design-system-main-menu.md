# UI-фундамент и главный экран — дизайн (порт gf-ui-prototype)

**Дата:** 2026-11-02
**Статус:** к реализации (решения зафиксированы grilling-сессией 2026-11-02).
**Источник дизайна:** `C:\Users\Egor\Desktop\projects\gf-ui-prototype` (Svelte 5 + `web/src/app.css`).
Источник истины по значениям — **`app.css`, а не вики прототипа**: вики расходится с кодом
(`--safe` 48 vs 44, отступы тайла 24 vs 22/24, размеры заголовков завышены).

## Что делаем

Первый этап переноса визуального языка прототипа в OpenFootball: **фундамент дизайн-системы**
(токены, `Theme`, общий навигатор ввода, переходы, компоненты) **и главный экран** — бенто-меню
`Play`/`Settings` с полной поддержкой клавиатуры, геймпада и мыши.

Остальной шелл (`controller_select`, `team_select`, `prematch`, `squad`, `network_*`) и in-match UI
в этом этапе **не переводятся** на новую тему — они получают её следующими этапами. Тема
подключается к корням шелл-экранов, а не через `gui/theme/custom`, чтобы не перекрасить
HUD/паузу/серию пенальти, свёрстанные под дефолтный шрифт.

## Контекст (факты, проверено по коду)

- Прототип: Svelte 5 + Vite, один глобальный `app.css` (~1588 строк), без Tailwind/роутера/
  иконочных библиотек. Главное меню собрано прямо в `web/src/App.svelte` из `TabBar` +
  `TileGrid`; панели подменю — `Breadcrumb` + `MenuPanel` в том же `panel-wrap`, легенда остаётся.
- Токены прототипа (полный набор): `--tile rgba(245,247,250,.95)`, `--focus-fill #171b3f`,
  `--ink #1d2138`, `--ink-2 #5a5f78`, `--focus-ink #f6f8fb`, `--focus-ink-2 rgba(246,248,251,.66)`,
  `--rail #e6236e`, `--focus-mark #c9f227`, `--gap 10px`, `--rail-w 6px`, `--safe 44px`.
- Иконки — инлайн-SVG в `web/src/lib/Glyph.svelte` (`shirt`, `play`, `trophy`, `network`,
  `sliders`, `gamepad`, `globe`, `keyboard`, `monitor`, `volume`, `pitch`, `tactics`, `sides`),
  stroke 1.5, `currentColor`. Иконочных файлов нет.
- Фон — единственный ассет `web/public/stadium.jpg` (2560×1750, 687 КБ), бесплатный сток
  (подтверждено владельцем). Наложены три градиента-скрима, дрейф 42 с.
- Шрифты грузятся с Google Fonts: Barlow Condensed 500/600/700/800 + Inter 300/400/500/600 +
  JetBrains Mono (не используется). **У Barlow Condensed нет кириллицы** — русские заголовки в
  прототипе фактически падают в системный sans-serif.
- Главное меню прототипа **не поддерживает геймпад** (только клавиатура и мышь); на
  sides/teams/kits/hub геймпад есть частично. Навигацию для меню проектируем с нуля.
- В OpenFootball сейчас: нет `Theme`, нет токенов, нет локализации; каждый экран строит UI кодом
  в `_build_ui()` + `_layout()`, стили инлайновые; единственный шрифт —
  `assets/ui/fonts/AlegreyaSansSC-ExtraBold.ttf`. Геймпад обрабатывается на каждом экране
  отдельно, потому что в Godot 4.7 у дефолтного `ui_accept` нет кнопки геймпада.
- Виртуальный холст проекта — 1920×1080 (`canvas_items` + `expand`). Существующий
  `tests/check_ui_layout.gd` требует неотрицательных размеров, попадания в вьюпорт и
  непересечения элементов на 1920×1080 и 1280×720.

## Принятые решения

1. **Сначала фундамент**, затем главный экран. Остальной шелл — следующими этапами.
2. **Язык UI — английский.** Шрифты: **Barlow Condensed** (заголовки) + **Inter** (текст), обе
   SIL OFL, кладутся локально в `assets/ui/fonts/`. Кириллица не требуется для меню; русские
   строки in-match (серия пенальти) остаются на дефолтном шрифте до этапа in-match UI.
3. **Субстрат:** `Theme` (.tres) + модуль токенов `UiTokens` + общий `UiNav`; экраны — нормальные
   `.tscn` с `Control`-деревом, стили из темы (не `add_theme_*_override` на каждом листе).
4. **Разрешение:** дизайн-холст 1920×1080, раскладка по замерам `app.css` на 1920, равномерный
   масштаб движком. CSS-клампы `vw/vh` не портируются. Панель центрируется, `max width 1480`;
   лишняя ширина на 16:10/21:9 уходит в фон.
5. **Контент сетки:** форма бенто 4×2 сохраняется; hero 2×2 — **Quick Match** (единственный
   рабочий основной путь). `Continue Career` (wide 2×1) и `Career` (1×1) — **disabled**.
   `Network Match` (1×1) — рабочий. Disabled-состояние проектируется сразу.
6. **Навигация:** `Control`-фокус с явным графом соседей; единый `UiNav` для A/B/Start/LB/RB и
   автоповтора направлений; мышь: hover = фокус, клик = активация.
7. **Фон:** `stadium.jpg` из прототипа + дрейф 42 с + скрим. 3D-стадион в фоне — будущая задача.
8. **Приёмка:** headless-тест геометрии (прямоугольники против CSS ±2px) + глазная сверка
   скриншотов 1920×1080 и 1280×720.
9. **Старые пункты меню:** `Start Match` → hero Quick Match (тот же путь Controller Select →
   Team Select → PreMatch); `Network` → тайл Network; `Select Teams` и `Classic Match (legacy)`
   из меню убираются (сцены остаются в репозитории для отладки).
10. **Вход:** при загрузке выбран hero; `Enter/Space/A` открывает Quick Match.
11. **Esc/B и Start в корне меню ничего не делают.** Выхода из игры через UI нет; диалог выхода
    отложен до этапа Settings.
12. **Табы:** `Up` с сетки → таб-бар; `Left/Right` и `LB/RB` переключают; `Down/A/Enter` → hero.
    Смена таба сбрасывает выбор на hero и проигрывает вход тайлов (380 мс, стаггер 28 мс).
13. **Settings:** вкладка с 4 тайлами `Gameplay/Controls/Graphics/Audio`, каждый открывает панель
    `Section in progress.` — это же даёт рабочий MenuPanel + Breadcrumb для будущей Career.
14. **Disabled-тайлы:** приглушены, в meta чип `SOON`, **исключены из навигации** (фокус не
    заходит). Клик/наведение на них не выбирают тайл.
15. **Переходы:** общий `UiTransition` (150 мс уход / 240 мс вход, scale 0.96), в headless —
    мгновенно, иначе существующие тесты ломаются на асинхронности.
16. **Тест-контракт:** узлы переименовываются в семантичные (`QuickMatchTile`, `NetworkTile`,
    `TabBar`, `TabPlay`, `TabSettings`, …), тесты правятся по смыслу, алиасы не сохраняются.

## Визуальная спецификация (значения на холсте 1920×1080)

### Цвета

| Роль | Значение |
|---|---|
| Поверхность тайла/строки | `rgba(245,247,250,0.95)` |
| Инверсия (selected/фокус) | `#171b3f` |
| Основной текст | `#1d2138` |
| Вторичный текст | `#5a5f78` |
| Текст на инверсии | `#f6f8fb` |
| Вторичный на инверсии | `rgba(246,248,251,0.66)` |
| Magenta (rail, активный глиф) | `#e6236e` |
| Lime (заголовок selected, underline) | `#c9f227` |
| Фон сцены | `#0a1020` |
| Ошибка | `#ff9ba8` |

### Типографика (1920)

| Элемент | Шрифт | Размер / вес / трекинг |
|---|---|---|
| Hero-заголовок | Barlow Condensed | 64 / 800 / `-0.005em`, line-height 0.92, uppercase |
| Wide-заголовок | Barlow Condensed | 52 / 700, uppercase |
| Маленький заголовок | Barlow Condensed | 44 / 700, uppercase |
| Sub тайла | Inter | 17 / 500 / 1.35 (wide — 18) |
| Meta / теги тайла | Inter | 15 / 600 / `0.02em`, uppercase |
| Match value | Barlow Condensed | 26 / 700, uppercase |
| Таб | Barlow Condensed | 23 / 700 / `0.015em`, uppercase |
| Бренд | Barlow Condensed | 26 / 800 / `0.1em`, uppercase |
| Заголовок строки панели | Barlow Condensed | 34 / 700, uppercase |
| Sub строки | Inter | 15 / 500 |
| Note панели | Inter | 16 / 400 / 1.35 |
| Крошки | Barlow Condensed | 22 / 600 (текущая — 800), uppercase |
| Легенда | Inter | 15 / 500 (цвет `rgba(246,248,251,0.86)`) |
| Kbd | Inter | 12 / 600 |

Uppercase выполняется **в копирайте** (Godot `Label` не умеет `text-transform`). `text-wrap:
balance` не переносится — для известных строк задаём ручные переносы.

### Раскладка

- Внешние поля `44` слева/справа; панель `min(1480, ширина − 88)` по центру.
- Таб-бар: высота `52`, `margin-bottom 10`, фон `rgba(245,247,250,0.3)`; табы `padding 0 32`.
  Маркер — плашка с `inset bottom 4px` цвета rail; при фокусе таб-бара маркер инвертируется
  (`#171b3f` + lime underline), активный текст lime. Вне фокуса активный таб — `--ink`,
  неактивный — `rgba(20,25,52,0.62)`.
- Сетка: 4 колонки, зазор `10`, высота `626.4` (`58vh`), 2 равные строки. Ширина колонки
  `362.5`; hero `735×626.4`; wide `735×308.2`; малые `362.5×308.2`.
- Тайл: `padding 22 24`, `gap 10`, тень `0 18 44 rgba(4,9,20,.3)`; selected: тень
  `0 28 64 rgba(4,9,20,.44)`, `scale 1.008`, сдвиг ±6 px от центра сетки, rail скрыт.
  Rail — 6 px magenta у левого края (скрыт у selected/disabled).
- Hero hatch: правые 52% ширины, диагональ `115°`, штрих 1.5 px, шаг 17 px, opacity 0.09,
  маска с прозрачностью слева (fade к 55%).
- Глифы: 152 (hero), 120 (wide), 76 (малые).
- Легенда: `margin-top 16`, зазор между подсказками 24, внутри подсказки 8; `kbd` min-width 26,
  padding `2 8`, фон `rgba(255,255,255,0.14)`, рамка `1px rgba(255,255,255,0.22)`.
- Бренд: справа 44, снизу 18; `OPEN` цветом `--focus-ink`, `FOOTBALL` — lime.
- Note панели: `padding 12 24`, фон `rgba(245,247,250,0.86)`.
- Строка панели: высота 88, `padding 0 24`, зазор 10 между строками и 10 до списка, rail 6 px;
  static-строка — без тени, текст `--ink-2`, rail `rgba(29,33,56,0.22)`.
- Крошки: высота 52, `padding 0 40 0 24`, зазор 16, фон `rgba(245,247,250,0.92)`, скошенный
  правый край на 22 px; разделитель — шеврон 7×7 из двух линий 2 px, поворот 45°, opacity 0.45.

### Фон

- Подложка `#0a1020`; фото `inset -8%`, `116%`, cover, фильтр
  `saturate(.85) brightness(.82) contrast(1.02)`, дрейф `scale 1 → 1.07` + `translate(-1.2%,-1%)`,
  `42s ease-in-out infinite alternate`.
- Скрим тремя слоями: вертикальный `rgba(9,16,38,.5) → прозрачный 40% → rgba(6,12,26,.46)`,
  радиальный вигнет `rgba(6,12,26,.5)` от 36%, плоский `rgba(24,34,80,.16)`.

### Анимации

| Что | Длительность / кривая |
|---|---|
| Уход экрана | 150 мс, `cubic-bezier(.4,0,1,1)`, opacity 1→0 + scale 1→0.96 |
| Вход экрана | 240 мс, `cubic-bezier(.2,.72,.2,1)`, opacity 0→1 + scale .96→1 |
| Маркер таба | 280 мс, `.2,.72,.2,1`; цвет 180 мс linear |
| Цвет таба | 220 мс linear |
| Тайл: фон/текст 140 мс linear; тень 180 мс ease; сдвиг/scale 180 мс `.2,.72,.2,1` |
| Rail | opacity 120 мс linear |
| Вход тайлов | 380 мс `.22,.68,.2,1`, стаггер 28 мс, сдвиг 64 px по направлению таба |
| Дрейф фона | 42 с alternate |

В Godot ближайшие кривые: `.2,.72,.2,1` → `TRANS_CUBIC/EASE_OUT`, `.4,0,1,1` →
`TRANS_QUAD/EASE_IN`, `.22,.68,.2,1` → `TRANS_CUBIC/EASE_OUT`. Значения живут в
`UiTokens.Motion` и правятся в одном месте.

### Disabled-тайл (в прототипе отсутствует — проектируем)

Поверхность `rgba(245,247,250,0.72)`, текст и sub — `--ink-2`, глиф с opacity 0.35, rail
отсутствует, уменьшенная тень `0 10 26 rgba(4,9,20,.18)`. В meta — чип `SOON`
(Inter 600/12, фон `rgba(29,33,56,0.12)`, текст `--ink-2`, padding `3 8`). Не фокусируется,
не кликается, hover не меняет вид.

## Главный экран

### Дерево сцены

```
MainMenu (Control, full rect, theme = ui_theme.tres)
├─ Stage (Control, mouse ignore)
│  ├─ StadiumPhoto (TextureRect, drift shader)
│  └─ Scrim (Control, scrim shader / ColorRect)
├─ Frame (Control, safe 44)
│  └─ PanelWrap (Control, width<=1480, центр, группа ui_transition_target)
│     ├─ TabBar (UiTabBar, h 52)                 # Play tab
│     │  ├─ TabStrip, TabMarker (+rail)
│     │  ├─ TabPlay, TabSettings
│     ├─ Content
│     │  ├─ PlayGrid (BentoGrid)                 # 4 колонки × 2 строки
│     │  │  ├─ QuickMatchTile (2×2)
│     │  │  ├─ ContinueCareerTile (2×1, disabled)
│     │  │  ├─ CareerTile (1×1, disabled)
│     │  │  └─ NetworkTile (1×1)
│     │  └─ SettingsGrid (BentoGrid)             # 4 × (2×1)
│     │     ├─ GameplayTile, ControlsTile, GraphicsTile, AudioTile
│     ├─ Breadcrumb + MenuPanel                  # вместо табов и сетки
│     └─ Legend (UiLegend)
└─ Brand (Label, bottom-right)
```

При открытом подменю таб-бар и сетка **заменяются** на `Breadcrumb` + `MenuPanel` (как в
`App.svelte:623-632`); легенда остаётся. `PlayGrid` и `SettingsGrid` — один и тот же
`Content`-контейнер, переключаются с анимацией входа.

### Контент и копирайт

| Слот | Заголовок | Sub | Meta | Глиф | Действие |
|---|---|---|---|---|---|
| hero 2×2 | `QUICK MATCH` | `One player, two players, or AI vs AI` | `1 PLAYER · 2 PLAYERS · AI` | `play` | `controller_select.tscn` |
| wide 2×1 | `CONTINUE CAREER` | `Return to your last save` | `SOON` | `trophy` | disabled |
| 1×1 | `CAREER` | `New, continue, load` | `SOON` | `shirt` | disabled |
| 1×1 | `NETWORK MATCH` | `Host or join` | — | `network` | `network_menu.tscn` |

Settings:

| Тайл | Заголовок | Note панели |
|---|---|---|
| Gameplay | `GAMEPLAY` | `Difficulty, assists and match length.` |
| Controls | `CONTROLS` | `Keyboard layout and gamepad functions.` |
| Graphics | `GRAPHICS` | `Resolution, quality and effects.` |
| Audio | `AUDIO` | `Music, commentary and effects.` |

Панель без строк показывает static-строку `SECTION IN PROGRESS` / `It will arrive in a later
build.`. Крошки: `PLAY` (текущая — `SETTINGS` / название раздела).

Табы: `PLAY`, `SETTINGS`. Легенда: клавиатура — `← ↑ ↓ →` move, `ENTER` select, `ESC` back;
геймпад — `D-PAD` move, `A` select, `B` back, `LB/RB` tabs. Легенда переключается по последнему
использованному устройству; мышь считается клавиатурой.

Бренд: `OPENFOOTBALL` (второе слово lime).

Верхняя строка статуса из прототипа (`канон: N клубов`) **не переносится** — нет API.

## Навигация и ввод

- **Единый роутер `UiNav`** (autoload). Потребляет навигационные события шелл-UI и эмитит:
  `move(dir)`, `confirm`, `back`, `tab_prev`, `tab_next`, `device_changed(kind)`.
  Кнопки не полагаются на встроенную фокус-навигацию Godot — направление двигает экран по
  явному графу, `confirm` вызывает `pressed.emit()` у текущего фокуса.
- **Автоповтор:** первое нажатие сразу, удержание — повтор через 320 мс, далее каждые 220 мс.
  Работает для стрелок, D-pad и левого стика (порог 0.5). Клавиатурный echo не используется.
- **Мышь:** `mouse_entered` тайла/таба/строки → `grab_focus()`; клик — обычный `Button.pressed`.
  Мышь не создаёт отдельного выделения.
- **Граф фокуса Play-таба:** hero ↔ Network по горизонтали (disabled пропущены); `Up` с любого
  тайла → активный таб; `Down` с табов → hero. `Left/Right` на табах переключают, `LB/RB`
  переключают из любого места. `Down/A/Enter` на табах → hero.
- **Граф фокуса Settings-таба:** Gameplay ↔ Controls, Graphics ↔ Audio, Up/Down между строками;
  `Up` с верхней строки → таб-бар; `Down` с нижней остаётся на месте.
- **Панель:** Up/Down по строкам (клампится, без wrap); `A/Enter` открывает строку;
  `B/Esc` возвращает на уровень выше (панель → сетка). В корне меню `B/Esc/Start` ничего не
  делают.
- `UiNav` активен только на шелл-экранах; в матче его нет (там своя обработка).

## Архитектура

### Autoloads (`project.godot`)

- `UiNav = res://scripts/ui/ui_nav.gd`
- `UiTransition = res://scripts/ui/ui_transition.gd`

### Файлы

```
assets/ui/fonts/BarlowCondensed-{600,700,800}.ttf
assets/ui/fonts/Inter-{400,500,600}.ttf
assets/ui/fonts/OFL-*.txt                  # лицензии рядом со шрифтами
assets/ui/theme/ui_theme.tres
assets/ui/menu/stadium.jpg                 # копия web/public/stadium.jpg
assets/ui/icons/{play,trophy,shirt,network,sliders,gamepad,monitor,volume}.svg
shaders/ui_stage_drift.gdshader
shaders/ui_scrim.gdshader                  # либо три ColorRect с градиентами
shaders/ui_hatch.gdshader

scripts/ui/ui_tokens.gd       # class_name UiTokens: цвета, размеры, шрифты, Motion
scripts/ui/ui_nav.gd          # autoload
scripts/ui/ui_transition.gd   # autoload
scripts/ui/ui_icon.gd         # загрузка SVG + модуляция
scripts/ui/bento_grid.gd      # ручная раскладка 4×2 (не Container), ячейки col/row/span
scripts/ui/bento_tile.gd      # Button-производный: стили, rail, hatch, glyph, disabled
scripts/ui/ui_tab_bar.gd      # маркер по ширине текста, зоны grid/tabs
scripts/ui/ui_menu_panel.gd   # note + rows/static
scripts/ui/ui_breadcrumb.gd   # custom _draw скошенной плашки + шевроны
scripts/ui/ui_legend.gd       # подсказки, last_input
scenes/main_menu.tscn         # заменяется по месту
scripts/ui/main_menu.gd       # оркестратор экрана
```

### Theme

`ui_theme.tres` (default font — Inter 16) с type variations:

`Heading`, `TileTitleHero` (Barlow 800/64), `TileTitleWide` (700/52), `TileTitle` (700/44),
`TileSub`, `TileSubWide` (18), `TileMeta`, `MatchValue`, `TabLabel`, `Brand`, `RowTitle`,
`RowSub`, `PanelNote`, `Crumbs`, `CrumbsCurrent`, `Kbd`, `SoonChip`, `Legend`.

StyleBox'ы: `TileNormal`, `TileSelected`, `TileDisabled`, `TabStrip`, `TabMarker`,
`TabMarkerFocused`, `RowNormal`, `RowSelected`, `RowStatic`, `CrumbsPlate`, `PanelNoteBox`,
`SoonChip`, `KbdBox`.

Тени — `StyleBoxFlat.shadow_color/size/offset`; точное размытие CSS недостижимо, подбираем
визуально (ориентир: normal `size 22`, `offset (0,18)`, alpha 0.30; selected `size 32`,
`offset (0,28)`, alpha 0.44).

Тема вешается на корень `MainMenu`; в `project.godot` `gui/theme/custom` **не задаётся**.

### Компоненты

- **BentoGrid** — собственный `Control` с ручной раскладкой (не `Container`), потому что
  selected-тайл должен уезжать на ±6 px и масштабироваться, а контейнер перезаписывает
  `position`. На ресайзе пересчитывает базовые прямоугольники и заново применяет сдвиг.
- **BentoTile** — `Button` (`flat`, `focus_mode=ALL`) с дочерними `Label`/`TextureRect`
  (`mouse_filter=IGNORE`); стили через тему; по `focus_entered/exited` — инверсия и tween
  сдвига/scale; disabled — `disabled=true` и исключение из графа.
- **UiTabBar** — маркер позиционируется по `Font.get_string_size` активного таба + padding 32
  (вместо DOM-измерения); tween 280 мс.
- **UiBreadcrumb** — `_draw` полигона со скосом 22 px и шевронов; текст — дочерние `Label`.
- **UiIcon** — SVG переписаны на белый stroke, импорт с `svg/scale=8` (192 px), цвет через
  `modulate`; альтернатива при проблемах импорта — `_draw` векторно.

## Тесты и проверки

Обновить:

- `tests/check_main_menu_ui.gd` — hero в фокусе на входе, `A` открывает Controller Select,
  `Enter`/клик работают, фокус не заходит в disabled.
- `tests/check_gpf_game_shell.gd` — путь стартует с `QuickMatchTile`.
- `tests/check_gpf_net_ui.gd` — `NetworkTile` ведёт в NetworkMenu.
- `tests/check_ui_layout.gd` — новый набор узлов; непересечение на 1920×1080 и 1280×720.

Добавить `tests/check_main_menu_layout.gd`:

- 1920×1080: панель 1480 по центру (x=220), таб-бар 52, зазор 10, сетка 626.4, колонка 362.5,
  hero 735×626.4, wide 735×308.2, малые 362.5×308.2 — допуск ±2 px.
- 1280×720: те же значения × 2/3 (равномерный масштаб), допуск ±2 px.
- Размеры шрифтов: 64/52/44, таб 23, бренд 26.
- Граф фокуса: hero → Network, Network → hero, `Up` → TabPlay, `Down` → hero; LB/RB меняют таб;
  disabled-тайлы не входят в цепочку.
- `UiTransition.instant == true` в headless; смена сцены происходит в том же кадре.

Скриншоты: добавить в `tests/capture_ui_shots.gd` состояния `main_menu_play`, `main_menu_tabs`,
`main_menu_settings`, `main_menu_panel` на 1920×1080 и 1280×720.

## Порядок работ

1. Ассеты: шрифты + OFL, `stadium.jpg`, SVG-иконки (белые), лицензии в `ASSET_CREDITS.md`.
2. `UiTokens` + `ui_theme.tres` (все варианты и StyleBox'ы).
3. `UiNav`, `UiTransition`, `UiIcon`, `UiLegend`.
4. `BentoTile`, `BentoGrid`, `UiMenuPanel`, `UiBreadcrumb`, `UiTabBar`.
5. `main_menu.tscn` + `main_menu.gd`: табы, сетка, Settings, бренд, фон, потоки.
6. Тесты: обновление существующих + `check_main_menu_layout.gd`; скриншоты.
7. Вики: страница `docs/wiki/дизайн-система-ui.md`, ссылка из `index.md`, запись в `log.md`,
   обновление `AGENTS.md` (раздел UI-политики — новая точка входа).

## Критерии приёмки

- Геометрия 1920×1080 совпадает с CSS ±2 px; на 1280×720 — те же значения × 2/3.
- Клавиатура, геймпад (D-pad/стик/A/B/LB/RB) и мышь работают на всех элементах меню;
  легенда переключается по последнему устройству.
- Disabled-тайлы видны, но недостижимы фокусом и кликом.
- Тайминги переходов и анимаций — из таблицы; дрейф фона 42 с.
- Все существующие headless-тесты зелёные (в обновлённом виде).
- Скриншоты 1920/1280 в `.scratch/ui_shots/` совпадают с прототипом по композиции на глаз.

## Вне scope

- Перевод `controller_select`, `team_select`, `prematch`, `squad`, `network_*` на новую тему.
- In-match UI (HUD, пауза, Game Plan, меню исполнителя, серия пенальти) и русские строки там.
- Глобальная тема проекта (`gui/theme/custom`).
- Реальные настройки, карьера/сейвы, диалог выхода, i18n.
- «Живой» 3D-фон со стадионом.
- Мобильная/портретная раскладка (прототип её не имеет).
- Звук UI.

## Риски и допущения

- **Метрики Barlow Condensed** в Godot отличаются от браузера: line-height 0.92 и
  `letter-spacing` придётся подгонять (`FontVariation.spacing_glyph`, `line_spacing`), допуск
  геометрии ±2 px может потребовать +1 px в отдельных местах.
- **Тени** `StyleBoxFlat` не равны CSS `box-shadow` по размытию — подбираются визуально.
- **Нет `clip-path` и `text-wrap: balance`** — breadcrumb рисуется `_draw`, переносы заголовков
  задаются вручную.
- **SVG `currentColor`** не поддерживается импортом — иконки переписываются на белый stroke и
  тонируются `modulate`.
- `stretch=expand`: на 16:10/21:9 панель остаётся 1480 и центрируется; фон добирается по краям.
- `UiNav` потребляет навигационные события только на шелл-экранах; будущие экраны с `LineEdit`
  (network host/join) при переходе на новый роутер потребуют явного режима «текстовый ввод».
- Тема не глобальная, поэтому in-match UI не меняется и не может сломаться от этого этапа.

## Ссылки

- Прототип: `web/src/app.css`, `web/src/App.svelte`, `web/src/lib/{TabBar,TileGrid,MenuPanel,Breadcrumb,Controls,Glyph}.svelte`.
- Вики прототипа: `docs/wiki/визуальный-стиль.md`, `docs/wiki/ui-система.md`
  (значения сверять с CSS).
- Текущий шелл: `AGENTS.md` («Оболочка матча»), `docs/wiki/конвенции.md`.
