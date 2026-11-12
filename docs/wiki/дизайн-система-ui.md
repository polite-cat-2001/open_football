# Дизайн-система UI, главное меню и выбор сторон

Перенос визуального языка прототипа `gf-ui-prototype` (Svelte + один `web/src/app.css`) в Godot.
Действует с 2026-11-02. Исходная спека — `docs/superpowers/specs/2026-11-02-ui-design-system-main-menu.md`;
источник истины по числам — **`app.css` прототипа**, а не его вики (вики расходится с кодом).

## Что уже переведено

- **Главное меню** (`scenes/main_menu.tscn`, `scripts/ui/main_menu.gd`).
- **Выбор сторон** — `controller_select` и `network_sides` через общий
  `SideSelectView` (`scenes/ui/side_select_view.tscn`); локальный и сетевой адаптеры только
  поставляют данные и обрабатывают действия.
- **Выбор команд** — `team_select` и `network_lobby` через общий `TeamSelectView`
  (`scenes/ui/team_select_view.tscn`); локальный адаптер — `TeamCatalog`/`ShellState`, сетевой —
  снапшот лобби + `NET_SHELL.action(...)`.
- **Выбор форм** — `kit_select` и `network_kit_select` через общий `KitSelectView`
  (`scenes/ui/kit_select_view.tscn`): 4 комплекта на сторону, карусель и статичное 3D-превью
  матча. Локальный адаптер — `KitCatalog`/`ShellState`, сетевой — снапшот лобби (киты локальные,
  не синхронизируются).
- **Предматчевый хаб** — `prematch` и `network_match_hub` через общий `MatchHubView`
  (`scenes/ui/match_hub_view.tscn`): две колонки стартовых составов, scoreboard, четыре
  command-ячейки, полноэкранные Game Plan / Options оверлеи. Поток:
  Team Select → Kit Select → Match Hub. Локальный адаптер собирает пакет, сетевой — снапшот
  лобби.
- **Сетевые меню** — `network_menu`, `network_host`, `network_join` на `UiScreen`/`UiStage`:
  две wide-плитки Host/Join без Back, отдельные формы с общим `UiOnScreenKeyboard` и
  `UiFormRow`, inline-ошибки и `Connecting...`. Back-цепочка `sides → teams → kit` идёт через
  общий `NetworkBackVote` (диалог у второго пира), Back из хаба остаётся локальным.
- Остальной шелл (`squad`) и in-match UI пока живут по-старому.
- **Тема не глобальная**: `ui_theme.tres` назначается на корень экрана, а не через
  `gui/theme/custom`. Поэтому HUD, пауза и серия пенальти не меняются, пока их не переведут отдельно.
- UI меню — **английский**; русские строки in-match остаются на дефолтном шрифте.

## Файлы

```
scripts/ui/ui_tokens.gd      — все цвета/размеры/шрифты/тайминги (1920×1080)
scripts/ui/ui_theme.gd       — сборка Theme из токенов; источник .tres
assets/ui/theme/ui_theme.tres — сгенерированный артефакт (не править руками)
scripts/ui/ui_nav.gd         — autoload UiNav: единый роутер ввода шелл-UI
scripts/ui/ui_transition.gd  — autoload UiTransition: fade/scale между сценами
scripts/ui/ui_stage.gd       — общий фон: Photo + Scrim + Overlay
scenes/ui/ui_stage.tscn      — инстанс фона для экранов
scripts/ui/ui_screen.gd      — база UiScreen: Stage + Design 1920×1080 и равномерный scale
scripts/ui/bento_tile.gd     — тайл бенто (Button + Panel/StyleBox + rail/hatch/иконка)
scripts/ui/bento_grid.gd     — ручная сетка 4×2 (не Container: selected-тайл уезжает)
scripts/ui/ui_tab_bar.gd     — табы с измеряемым маркером
scripts/ui/ui_legend.gd      — нижняя легенда, переключается по устройству
scripts/ui/ui_hints_bar.gd   — общий блок status + legend для всех shell-экранов
scenes/ui/ui_hints_bar.tscn  — инстанс UiHintsBar (фиксированные 24/12/24)
scripts/ui/ui_breadcrumb.gd  — скошенная плашка пути (custom _draw)
scripts/ui/ui_menu_row.gd    — строка панели (88 px, инверсия по фокусу)
scripts/ui/ui_menu_panel.gd  — note + rows/static для подменю
scripts/ui/ui_icon.gd        — белые SVG из assets/ui/icons, тонируются modulate
scripts/ui/side_select_view.gd — общий экран выбора сторон (данные + сигналы)
scenes/ui/side_select_view.tscn — сцена SideSelectView (шапка/body/трек/легенда)
scripts/ui/side_select_vertical_label.gd — вертикальные HOME/AWAY через _draw
scripts/ui/team_select_view.gd — общий экран выбора команд (состояние + сигналы)
scenes/ui/team_select_view.tscn — сцена TeamSelectView (две карточки/status/legend)
scripts/ui/team_panel.gd     — одна карточка HOME/AWAY, cues у арта
scenes/ui/team_panel.tscn    — инстанс карточки
scripts/ui/team_block.gd     — блок карточки: градиент/фокус
scripts/ui/team_stars.gd     — звёзды рейтинга (full/half/empty)
scripts/data/team_ratings.gd — чистая формула рейтинга из состава
scripts/ui/kit_select_view.gd — общий экран выбора форм (состояние + сигналы)
scenes/ui/kit_select_view.tscn — сцена KitSelectView (две панели/preview/status/legend)
scripts/ui/kit_panel.gd      — одна панель HOME/AWAY с каруселью
scripts/ui/kit_art.gd        — SVG-подобная форма из kit spec (_draw)
scripts/ui/kit_arrow.gd      — стрелка карусели
scripts/ui/kit_preview.gd    — средняя колонка: заголовок, 3D-превью, подписи
scripts/ui/kit_preview_3d.gd — статичная сцена поля и 22 тел с kit-шейдером
scripts/data/kit_catalog.gd  — чтение `databases/default/kits.json` + fallback
scripts/data/kit_texture.gd  — kit spec → kit-shader на UV-атласе тела
shaders/kit_uv.gdshader      — перекраска UV-маски + паттерн формы
scripts/ui/match_hub_view.gd — общий предматчевый хаб (состояние + сигналы)
scenes/ui/match_hub_view.tscn — сцена MatchHubView (колонки/scoreboard/command/оверлеи)
scripts/ui/hub_lineup_column.gd — колонка 11 стартовых (номер/фамилия/роль/капитан)
scripts/ui/hub_scoreboard.gd — scoreboard: мета, два клуба, гербы, звёзды, ATT/MID/DEF
scripts/ui/hub_command_cell.gd — command-ячейка (фокус/hover/клик)
scripts/ui/match_options_overlay.gd — duration/difficulty + заглушки Stadium/Weather/Camera/System
scripts/ui/hub_value_slider.gd — слайдер дизайн-системы для Options
scripts/ui/match_hub_state.gd — общие снапшот-хелперы локального и сетевого адаптеров
scripts/ui/network_menu.gd   — меню сети: две wide-плитки Host/Join, breadcrumb, без Back
scripts/ui/network_host.gd   — форма Host: port/name, OSK, inline-ошибки, реальный net_host
scripts/ui/network_join.gd   — форма Join: address/port/name, OSK, Connecting/reject
scripts/ui/ui_form_row.gd    — фокусируемая строка формы (label/value/hint/error)
scripts/ui/ui_on_screen_keyboard.gd — общий OSK: QWERTY+символы, SPACE/DEL/CLEAR/APPLY
scenes/ui/ui_on_screen_keyboard.tscn — сцена OSK (modal, scrim, display)
scripts/net/network_settings.gd — user://network.cfg: отдельные host/join значения
scripts/net/network_validation.gd — IPv4/hostname/port/name и фильтры ввода
scripts/net/network_back_vote.gd — общий Back-голос через hubvote + диалог LEAVE TOO/STAY
scripts/ui/prematch.gd       — локальный адаптер MatchHubView
scripts/ui/network_match_hub.gd — сетевой адаптер MatchHubView
tools/import_prototype_kits.py — specs прототипа → `databases/default/kits.json`
tools/build_ui_theme.gd      — пересборка ui_theme.tres
shaders/ui_scrim.gdshader    — три слоя затемнения фона
shaders/ui_hatch.gdshader    — диагональная штриховка hero-тайла
```

Пересобрать тему после правок `UiTokens`/`UiTheme`:

```powershell
& "C:\Users\Egor\Desktop\Godot\Godot_v4.7.2-stable_win64_console.exe" `
  --path "C:\Users\Egor\Desktop\projects\open_football" `
  --headless -s res://tools/build_ui_theme.gd
```

## Токены (ключевое)

- Поверхность `--tile` = `rgba(245,247,250,.95)`, инверсия `#171b3f`, текст `#1d2138`/`#5a5f78`,
  на инверсии `#f6f8fb`, magenta `#e6236e`, lime `#c9f227`.
- Холст 1920×1080: поля 44, панель 1480, зазор 10, таб-бар 52, сетка 626.4, hero 735×626.4,
  wide 735×308.2, малые 362.5×308.2.
- Типографика: Barlow Condensed 64/52/44 для заголовков тайлов (800/700/700), Inter 17/18 sub,
  Inter 15 meta, Barlow 23 табы, Barlow 26 бренд.
- Тайминг: уход 150 мс, вход 240 мс, маркер таба 280 мс, инверсия тайла 140–180 мс,
  вход тайлов 380 мс со стаггером 28 мс. Фон статичный (дрейф убран).

Значения живут в `UiTokens`; не дублируй их в экранах.

`BentoGrid` принимает `columns`/`rows` (по умолчанию 4×2; пауза матча — 2×3), а `BentoTile`
умеет менять страницу слота (`set_page`, `set_pages` + точки-индикатор), заголовок
(`set_heading`) и нижнюю meta-строку (`set_note`).

## Theme

Варианты типов (`theme_type_variation`):

`HeroTitle`, `WideTitle`, `TileTitle`, `TileSub`, `TileSubWide`, `TileMeta`, `MatchValue`,
`TabButton`, `Brand`, `BrandAccent`, `RowTitle`, `RowSub`, `PanelNote`, `Crumbs`,
`CrumbsCurrent`, `Kbd`, `SoonChipLabel`, `LegendLabel`, `SideTitle`, `SideName`,
`SidePlayerName`, `SideStatus`, `SideStatusError`.

StyleBox-варианты: `KbdBox`, `SoonChip`, `PanelNoteBox`, `SideHead`. Фоны тайлов/маркеров/строк
собираются `StyleBoxFlat` в коде (тени `shadow_size/offset` — приближение CSS `box-shadow`).

## Главное меню

Сцена: `Stage` (фото + скрим) → `Design` (холст 1920×1080, равномерный scale) → `PanelWrap`
(группа `ui_transition_target`) → `TabBar` + `PlayGrid`/`SettingsGrid` + `Breadcrumb`/`MenuPanel` +
`Legend` + `Brand`.

- `Play`: hero `QuickMatchTile` 2×2 (Controller Select), `ContinueCareerTile` 2×1 disabled,
  `CareerTile` 1×1 disabled, `NetworkTile` 1×1 (NetworkMenu). Disabled-тайлы приглушены, с чипом
  `SOON`, `focus_mode = NONE`, мышь их игнорирует.
- `Settings`: 4 тайла 2×1; клик открывает панель с breadcrumb `PLAY > SETTINGS > <SECTION>`,
  note-плашкой и static-строкой `SECTION IN PROGRESS`.
- Панель открывается вместо табов и сетки; вся связка (breadcrumb + panel + legend)
  центрируется вертикально как блок. `B/Esc` закрывает и возвращает фокус на тайл-источник.
- Навигация по сетке: `Up` с верхнего ряда → таб-бар, с нижнего — тайл над ним
  (`Audio → Controls`, `Graphics → Gameplay`); `Down` с табов → первый тайл активной вкладки.
  В Play `Up` с `Network` идёт на hero, `Up` с hero — в табы.

## Выбор сторон

Сцена: `scenes/ui/side_select_view.tscn` (`SideSelectView`) — `Stage` (stadium + scrim) →
`Design` 1920×1080 с равномерным scale → `PanelWrap` (группа `ui_transition_target`) →
`Head` 56 px / `Body` 691.2 px / `Status` / `Legend`. В `resume_mode` фото и scrim скрыты,
остаётся полупрозрачный слой поверх замороженного матча.

Геометрия (design space): body `clamp(440, 64vh, 700)` = 691.2; track с inset 8; device 112×112,
glyph 92; edge inset 260 → home x=260, center 684, away 1108; gap между строками 6. Иконки
крупнее и ход короче, чем в прототипе (`84×84/104`), — сознательное отступление по просьбе
владельца. Строки идут **компактной стопкой сверху вниз** (`row_layout = "stack"`): высота
строки 112 + 16 pad (+ 4+18 под имя в сети), поэтому первый девайс у верхнего края, каждый
следующий сразу под ним; при нехватке высоты — равномерная раскладка. ready-бейдж 24 рисуется
на стороне **без стрелки**, по вертикали по центру (как стрелка): home — слева, away — справа;
center (обе стрелки) — по центру сверху. Tween `left` 340 мс `TRANS_CUBIC/EASE_OUT`
(`UiTokens.SIDE_DEVICE_MOVE`).
Подписи HOME/AWAY — Barlow 800/64 с трекингом, цвет `INK` 0.22; шапка — Barlow 700/24,
трекинг 3 px.

Шов: `setup(rows, options)`; строка `{id, kind, device, name, side, ready, local, tone_index}`;
сигналы `row_move_requested(id, delta, input)`, `row_confirm_requested(id, input)`,
`row_cancel_requested(id, input)`, `back_requested`. Вью не меняет данные сама — адаптер
возвращает новый снапшот в `apply_rows`, поэтому лобби остаётся host-authoritative.

Ввод — только `UiNav`: Left/Right двигает строку **своего** устройства (клавиатура → строка
клавиатуры, каждый геймпад → своя), Up/Down ничего не делают, A/Enter — ready, B/Esc — снять
ready или назад. `UiNav.last_device_id()`/`last_input_gamepad()` различают устройства.
Мышь **сознательно инертна**: кликов ready/back и наведения-фокуса нет (решение владельца,
отступление от прототипа и исходного ТЗ).

Адаптеры:

- `scripts/ui/controller_select.gd` — `InputSetup.available_devices()` + `ShellState.controllers`;
  одинокий keyboard стартует home, несколько устройств — в центре; ready требуется от каждой
  не-центральной строки; коммит пишет `ShellState.controllers` и всегда ведёт в Team Select
  через `UiTransition`. **Hot-plug:** `Input.joy_connection_changed` → `_sync_participants()`:
  новый геймпад появляется в центре, отключённый исчезает, существующие строки сохраняют
  side/ready. Порядок строк сверху вниз — порядок подключения (клавиатура первая, новые
  геймпады добавляются в конец).
- `scripts/ui/network_sides.gd` — снапшот лобби (имена, YOU, ready, device), `resume_mode`
  (не выходит из сессии), host-authoritative commit, resume-голосование, disconnect/join
  статусы. Оверлей в матче — тот же view с `overlay=true`; `gpf_slice` анимирует
  только `Design/PanelWrap`, а stage/scrim появляется сразу — иначе на 150/240 мс
  просвечивает ярко-зелёный газон матча (моргание при открытии).

Цвета устройств — по номеру участника: blue `#2f6df6`, magenta `#e6236e`, orange `#f08c00`,
green `#0f9d76` (`UiTokens.SIDE_TONES`); клавиатура тоже получает тон по индексу.
Ready-бейдж — lime `FOCUS_MARK` с тёмной галочкой (`ReadyMark`), у имени в сети — светлая
обводка, чтобы читалось на прозрачном низе градиента.

## Выбор команд

Сцена: `scenes/ui/team_select_view.tscn` (`TeamSelectView`) — `Stage` (общий фон) →
`Design` 1920×1080 с равномерным scale → `PanelWrap` (группа `ui_transition_target`) →
`Teams` с двумя `TeamPanel` + `Status` + `Legend`. Шапки нет (как в прототипе), фон не
анимируется: `UiTransition` трогает только `PanelWrap`.

Геометрия (design space): панель 1480, две колонки по 735, карточка `512×820` с центрированием
в колонке (x=111.5 и 856.5), зазор 10. Внутри карточки три блока: Country 155.8 (19%),
Team 431 (1fr), Competition 213.2 (26%). `--col` прототипа = 210: герб 210×210, звёзды 210×35,
статы 3 колонки в 210 (gap 8). Флаг стоит на y=60; все флаги одной высоты 64 px, ширина = aspect×64, max 120; имя страны —
на y=8 (как padding-top 8 в CSS). Лого лиги 118.8 px (max 170) — на y=49.2, по центру нижнего
блока; под обводку картинка получает padding 10 source px и рисуется в контейнере 180×128.8
(`TEAM_COMP_ART_*`). В сети
имя владельца слота — мелкая строка внизу верхнего блока. Cues — lime-треугольники 12×18 по бокам art-колонки 210:
основание в 20 px от неё, острие — 32 px; по вертикали центр флага/герба/лого (92/198/108.6),
не центр блока. Cues показываются только если в поле больше одного варианта: в National Teams
лига одна (заглушка) — стрелок нет, как и при единственной лиге/команде. Вокруг лого лиги — тонкая белая обводка, запечённая в
`images_leagues_outline/<id>.png` (`tools/outline_league_logos.py`: дилатация alpha + blur,
padding 10; аналог четырёх `drop-shadow` CSS). National Teams
использует тот же globe-SVG прототипа (`assets/ui/icons/globe.svg`), а не `nationalteams.png`.
Карточка без фокуса — светлый вертикальный градиент `TEAM_BLOCK_TOP/BOTTOM`, фокус —
`TEAM_BLOCK_FOCUS` (#171b3f 0.96), ready — `TEAM_BLOCK_DARK` (0.66). Неактивная панель —
`modulate.a = TEAM_IDLE_ALPHA` (0.5), как `.team.is-idle`.

Ready-модель «как в прототипе»: отдельного Ready-ряда нет. `A/Enter` на любом блоке делает
панель ready: верхний блок показывает `HOME`/`AWAY`, нижний — `READY!`, средний остаётся
с гербом/звёздами/статами. `B/Esc` на своей ready-панели снимает ready; в 1P на away при ready
home — снимает ready home и возвращает на home; иначе — назад/выход. В сети ready-панель
принадлежит своему chooser-слоту.

Без сохранённого выбора локальный экран открывается на **FC Barcelona vs Real Madrid**
(Spain/LaLiga); при возврате из хаба восстанавливает прежнюю пару.

Фокус: `Up/Down` двигает блок внутри панели (кладём: country → team → competition),
`Left/Right` меняет значение выбранного блока (зациклено). В 1P активна одна панель, вторая
видна приглушённой; в 2P каждое устройство правит свою. В сети локальный игрок правит только
свои `chooser`-слоты; если оба слота его — `Tab` переключает панель. Мышь инертна, `V`
(просмотр состава) убран с этого экрана.

Шов: `setup(state, options)` / `apply_state(state)`; состояние — массив двух сторон:
`{label, owner, ready, live, editable, device, country{name,texture}, competition{...},
team{...}, rating{stars,attack,midfield,defence}}` плюс `status/status_error/error`. Сигналы:
`side_move_requested(side, field, delta, input)`, `side_confirm_requested(side, input)`,
`side_cancel_requested(side, input)`, `back_requested`, `retry_requested`. Вью не меняет данные —
адаптер возвращает новый снапшот.

Данные: `TeamCatalog` читает базу лениво, как оригинальный `TeamSelectPage`: при открытии только
валидирует файл/таблицы, страны/лиги/команды запрашиваются по требованию и кэшируются; состав и
рейтинг читаются только для выбранной команды. Список команд лиги **не** проверяет число игроков
(это стоило ~0.8 с на 217 сборных и подвешивало экран); проверка `>= 11` перенесена на ready:
`TeamCatalog.can_field_eleven(team_id)` для двух выбранных команд. Текстуры стран/лиг/команд
загружаются лениво только для выбранного элемента, а не для всего списка.

Рейтинг — `TeamRatings.from_players`: `overall = base_stat×100` (в прототипе это и есть `overall`;
среднее 22 игровых статов насыщается у 1.0 и давало почти всем клубам 4.5–5 звёзд), лучшие 11,
линии `CF/LW/RW/ST/LM/RM` (ATT), `DM/CM/AM` (MID), `CB/LB/RB` (DEF), пустая линия — средний
топ-11; звёзды `1+(avg−59)/7`, шаг 0.5, clamp 0.5..5. Флаги/гербы/лого берутся из
`databases/default/images_{teams,leagues,countries}` (заполняются
`tools/import_prototype_images.py` из `gf-ui-prototype/data/raster`, ~4644/4652 команд,
279/280 лиг, 106/107 стран) с прежним `logo_url`-путём в приоритете; если картинки нет —
белый глиф `globe`/`shirt` (оранжевый placeholder оригинала на карточках не используется).

Адаптеры:

- `scripts/ui/team_select.gd` — lazy `TeamCatalog`, индексы country/league/team, восстановление
  выбранных команд из `ShellState`, 1P home → CPU away и 2P parallel, ready обеих → Kit Select.
- `scripts/ui/network_lobby.gd` — снапшот лобби, `set_selection(side, kind, index)` /
  `set_team_ready`, seed дефолтов (пара `ShellState.DEFAULT_HOME_TEAM_ID`/`DEFAULT_AWAY_TEAM_ID`,
  как в Quick Match), имена/`YOU`, disconnect/join статусы, phase 0 → sides,
  phase 2 → Kit Select → Match Hub. Раскладка и ввод в адаптерах не дублируются.

## Выбор форм

Сцена: `scenes/ui/kit_select_view.tscn` (`KitSelectView`) — `Stage` → `Design` 1920×1080 →
`PanelWrap` (группа `ui_transition_target`) → `Kits` с двумя `KitPanel` и `KitPreview` + `Status` +
`Legend`. Шапки нет; фон не анимируется, `UiTransition` трогает только `PanelWrap`.

Геометрия (design space): панель 1480, высота 420, gap 10; колонки
`minmax(0,1.15fr) minmax(320px,0.9fr) minmax(0,1.15fr)` — home/away по 524.7, preview 410.6.
Панель: padding `18 26 20`, head 26 (лого 22 + имя 14/600 uppercase, счётчик Barlow 19), имя
комплекта Barlow 32/800, карусель `34 / 0.45fr / 1.9fr / 0.45fr / 34`, соседи 58% высоты,
стрелки 18×26, точки 26×4 gap 8, ready 40/800. Focus — `#171b3f .96`, сдвиг home −6/away +6,
scale 1.008; ready — `.66`. Фокусная панель рисует стрелки lime, ready их и точки прячет.
Комплекты: `main/white/black/reserve` → `HOME/AWAY/THIRD/FOURTH`; home по умолчанию main,
away — домашняя (main) форма, если её контраст с домашней формой хозяев близок к лучшему
(≥72% максимума); иначе самый контрастный комплект. Один комплект — счётчик `1 / 1`,
стрелки и точки скрыты.
`KitArt` рисует силуэт футболки с тонким тёмным кантом (без белой обводки).

Средняя колонка — `KitPreview`: заголовок `MATCH PREVIEW` / `TOP CAMERA`, статичный 3D-снимок
(`SubViewport` 640×480, собственный `World3D`) и подписи команд с `VS`. Внутри — большое поле
с полной разметкой и газоном вокруг (без стадиона; камера приближена, опущена и наклонена вниз,
дальняя боковая линия выше кадра, поэтому за полем ничего не видно), 22 тела
`gpf_fullbody` в компактной 4-3-3, мяч, broadcast-камера и свет матча. При смене любой формы
`KitTexture` переустанавливает kit-shader, и игроки в превью переодеваются. Это не симуляция:
позы статичные, сцена не тикает. `KitCatalog` и текстуры поля кэшируются статически, формы
рисует `shaders/kit_uv.gdshader` (без попиксельной генерации), а 3D-сцена строится отложенно
после раскладки панели — открытие экрана не блокируется тяжёлой сборкой.

Шов: `setup(state, options)` / `apply_state(state)`; стороны —
`{label, team{name,texture}, kits[], kit_index, ready, live, editable, device, choices, kit}`,
плюс `preview {home{name,kit}, away{name,kit}}`, `status/status_error/error`. Сигналы:
`side_move_requested(side, delta, input)`, `side_confirm_requested(side, input)`,
`side_cancel_requested(side, input)`, `back_requested`, `retry_requested`. Вью не меняет данные:
адаптер возвращает новый снапшот.

Ввод — только `UiNav`: `Left/Right` листает комплект live-панели, `A/Enter` — ready, `B/Esc` —
снять ready/назад; `Up/Down` ничего не делают. В 1P человек по очереди выбирает home, затем away
(как команды); в 2P каждое устройство правит свою панель (`moved_gamepad`); в сети каждый пир
локально правит обе формы как в 1P (home → away), потому что киты не синхронизируются. Мышь
инертна.

Данные: `tools/import_prototype_kits.py` читает `specs.json`/`national_specs.json` прототипа и
пишет `databases/default/kits.json` по `tm_id` (у игровых команд `TeamCatalog` теперь отдаёт
`tm_id`). `KitCatalog.kits_for(team)` возвращает 4 нормализованных кита или fallback из
`color1/color2`; нет файла — fallback, битый JSON — статус + retry. `UiAssets` даёт лого команды.
`ShellState.kit_home`/`kit_away` хранят выбранные спеки; `MatchPackage` кладёт их в
`team.kit`, а `GpfActors` применяет `KitTexture` к поверхностям `gpf_kit` — матч показывает
выбранные формы, а не только цвета.

Адаптеры:

- `scripts/ui/kit_select.gd` — локальный: `KitCatalog` + `ShellState.home/away_team`, дефолтные
  индексы 0/1, 1P home→away и 2P parallel, ready обеих → Match Hub.
- `scripts/ui/network_kit_select.gd` — сетевой: локальный шаг; обе формы
  редактируются локально как в 1P (home → away), киты не синхронизируются;
  после ready обеих открывает `network_match_hub` (phase 2 не меняется).
  Back из хаба возвращает на этот же экран, не меняя фазу.

## Предматчевый хаб (MatchHubView)

Сцена: `scenes/ui/match_hub_view.tscn` (`MatchHubView`) — `Stage` → `Design` 1920×1080 →
`PanelWrap` (группа `ui_transition_target`) → `HubTop` (HomeLineup / Scoreboard / AwayLineup) +
`Command` + `Status` + `Legend`; полноэкранные оверлеи — `Design/Overlay` (Options,
Game Plan). Шапки нет, как в прототипе; фон не анимируется.

Геометрия (design space): панель 1480; хаб 680 = top 530 + gap 40 + command 110; колонки
составов 362.5, scoreboard 735, gap 10; command-ячейки 362.5×110. Составы — 11 строк с
номером слота, фамилией (при одинаковых фамилиях — инициал), ролью и меткой капитана; `GK`
рисуется инвертированной плашкой. Scoreboard: мета-строка (лига/`FRIENDLY`/`INTERNATIONAL`,
difficulty, длительность), два клуба с гербом (или white `shirt`-глифом), звёздами
(`TeamStars`) и ATT/MID/DEF. Command-ячейки: `START MATCH`, `TEAM MANAGEMENT`, `MATCH OPTIONS`,
`EXIT`; фокус — инверсия в `FOCUS_FILL`, выбранная ячейка scale 1.008, глиф
`RAIL`, невыбранный — тёмный `INK`.

Шов: `setup(state, options)` / `apply_state(state)`; состояние — `meta`, `sides` (team,
crest texture, rating, kit, device, owner, 11 lineup rows), `options`, `flags`
(`can_start`, `can_manage`, `can_options`, `network`, `host`,
`client`, `local_two_player`, `start_label`, `start_votes`, `start_votes_needed`),
`status/status_error`. Сигналы: `start_requested(input)`, `back_requested(input)`,
`game_plan_requested`, `lineup_changed`, `option_changed(field, value)`,
`exit_requested`. Вью не меняет данные: адаптер возвращает новый снапшот.

Экраны потока: `scenes/prematch.tscn` (локальный адаптер) и
`scenes/network_match_hub.tscn` (сетевой). Локально 1P Start собирает `MatchPackage` и
открывает `gpf_slice`; в 2P каждое локальное устройство голосует Start, повторное нажатие/Back
отзывает голос, статус `START x/y`. Сеть: host правит difficulty/match length (`set_match_options`)
и стартует (`NetworkMatch.build_package` + `runtime.net_start()`); client видит read-only
options/Start `WAITING FOR HOST`, ждёт `MatchSetup`. Back из хаба → Kit Select (в сети — та же
фаза 2), Back из китов → Teams.

Оверлеи: `MATCH OPTIONS` — два слайдера + disabled-заглушки Stadium/Weather/Camera/System
с чипом `SOON`; в сети редактирует только host. `EXIT` выходит в главное меню (в сети
предварительно закрывает LAN-сессию). `TEAM MANAGEMENT` открывает существующий
`GpfGamePlan` полноэкранно (половинные панели, вкладки SQUAD/FORMATIONS/ROLES, READY —
[[план-игры]]); правки `MatchLineup` сразу обновляют колонки, закрытие возвращает
фокус на ячейку.

Ввод — только `UiNav`: Left/Right и Tab/LB-RB листают command-ячейки, A/Enter активирует,
B/Esc — назад/закрывает оверлей, Up/Down в Options выбирают строку, Left/Right меняют
значение; в Game Plan действия маршрутизируются в `GpfGamePlan.handle_ui_action` (`Q/E`/`LB/RB`
— вкладки, `Y` — details, `B` — READY). Мышь работает: hover/click по command-ячейкам,
слайдеры, клик по скриму закрывает оверлей.

Адаптеры:

- `scripts/ui/prematch.gd` — `TeamCatalog`/`ShellState`, `MatchLineup.from_squad`, рейтинги,
  `KitCatalog` defaults; local 2P Start одним нажатием (общее подтверждение — READY плана);
  `MatchPackage`; Game Plan; Exit → main menu; Back → Kit.
- `scripts/ui/network_match_hub.gd` — снапшот лобби (`NET_SHELL.lobby`), host-only options,
  двусторонний Start (`hubvote`, 2/2), client `net_take_match_setup`, Back → Network Kit,
  Exit → main menu (с `net_leave`), disconnect → Network Menu. Game Plan синхронизирует
  `planswap`/`planscheme`/`planrole` через pre-match `MatchData` ([[план-игры]]).

## Сетевые меню и OSK

Сцена меню: `Stage` → `Design` 1920×1080 → `PanelWrap` (`ui_transition_target`) →
`Breadcrumb` (`PLAY > NETWORK`) + `Grid` с двумя wide-плитками 735×308 + `Legend`. Плитки
`HOST GAME` и `JOIN GAME` — обычные `BentoTile`; Back-кнопки нет, `Esc/B` возвращает в главное
меню. Мышь работает: наведение/клик по плиткам.

Host и Join — **отдельные сцены**, но с общей формой: `PanelWrap` с `UiBreadcrumb`
(`PLAY > NETWORK > HOST/JOIN`), светлая `FormPanel` 980 px и строками `UiFormRow` (label слева,
value/hint/error справа, фокус — инверсия, клик открывает OSK), затем action-строки
`UiMenuRow`. Breadcrumb и нижняя legend выравниваются по **левому краю** `FormPanel`, а не по
ширине `PanelWrap`.
 Host: Port, Name, `OPEN LOBBY`. Join: Address, Port, Name, `CONNECT`.
Back — только `Esc/B` (строки Back в формах нет). Ошибки — под значением поля
(`UiTokens.ERROR_PINK`) и общей status-строкой под панелью;
Join показывает `CONNECTING TO ...`, причину отказа и отменяет клиент по Back без зависания.
Значения читаются/пишутся `NetworkSettings` (`user://network.cfg`, секции `[host]`/`[join]`)
после успешного `net_host`/`net_join`.

`UiOnScreenKeyboard` (`scenes/ui/ui_on_screen_keyboard.tscn`) — модальный оверлей 880 px:
scrim, дисплей, ряды `QWERTYUIOP / ASDFGHJKL / ZXCVBNM` + служебный `1234567890.-_`,
колонка `SPACE/DEL/CLEAR/APPLY`. Открывается по `A/Enter` на поле, первый фокус — первый
**разрешённый** символ (для port это `1`, для имени/адреса `Q`); физическая клавиатура и мышь
работают, backdrop/Esc закрывают, Apply отдаёт текст и возвращает фокус на поле. Фильтры:
port — только цифры (5), address — `A-Za-z0-9.-` (64), name — буквы/цифры/пробел/`_` (16).
`UiNav` считает OSK/диалог модальными: экран под ними не обрабатывает тот же Enter/Esc
(`event_was_modal()`), поэтому закрытие OSK не срабатывает как Back.

Back-цепочка в сети: `network_sides → network_menu`, `network_lobby → sides`,
`network_kit_select → teams` требуют согласия обоих пиров, `network_match_hub → kit` —
индивидуально. `NetworkBackVote` шлёт `hubvote` (значения синхронизированы с `e_NetHubVote`),
второй пир видит модальный диалог `LEAVE TOO / STAY`; при согласии сервер меняет фазу
(`BackToSides`/`BackToTeams`) или оба уходят в меню (`LeaveSession`). В C++ голосование
разрешено в Sides/Teams/Options; `BackToTeams` из китов по-прежнему применяет `MenuTask`.

## Пауза матча (PauseScreen)

`scenes/match/pause_screen.tscn` (`scripts/ui/pause_screen.gd`, `PauseScreen`) — дизайн-системный
порт `IngamePage`; носитель — `GpfPauseMenu` (`scripts/match/gpf_pause_menu.gd`, CanvasLayer над
замороженным 3D-матчем). Ширина блока — `PAUSE_W` 1700 (шире shell-панели 1480, как в референсе).
Сцена живёт постоянно, `open()`/`close()` показывают/прячут её; `hide_for_submenu()`/`dismiss()` —
без resume. Открытие/закрытие — те же 150/240 мс fade+scale через `UiTransition.show_target`/
`hide_target` (весь `Content` — `ui_transition_target`; скрим статичен). Ввод — через форвардер
`gpf_slice` (`handle_key`/`handle_joy`): экран **не** входит в `ui_shell`, иначе UiNav-поллинг
обрабатывал бы то же нажатие вторым шагом (Left с Replay улетал на lineup). Правый стик для
пагинации — в `PauseScreen._input`; мышь — через `BentoTile`/стрелки.

- Шапка `PauseScoreboard` (`scripts/ui/pause_scoreboard.gd`): тёмная полоса `PAUSE_W × 156`,
  гербы (сначала `logo_url` пакета, затем импортированный `images_teams/<team_id>.png` через
  `UiAssets.team_logo`), названия, `score0/score1`, часы `match_time_ms`.
- Карточка состава — `BentoTile` + `PauseLineup` (`scripts/ui/pause_lineup.gd`): перспективное
  поле, 11 фишек (`KitArt`-футболка, рейтинг, фамилия). Данные — те же, что в плане игры
  предматчевого хаба: `package.players` + `package.formation` (нормализованные позиции) и
  `base_stat` (добавлен в пакет); позиция карточки повторяет `GpfGamePlan._build_cards` (GK −0.74,
  защита −0.40, остальные ×0.82/0.68 и `y×0.8`), поэтому ЦЗ не садятся на линию вратаря.
  Заголовок — имя команды, подзаголовок — формация. Показывается команда человека, открывшего
  паузу (`_pause_team`: устройство Start в 2P, иначе первый human); нажатие/Enter → game plan.
- Сетка 2×3: Continue, Replay, Player Ratings (SOON), Match Info (SOON), Settings, Quit Match.
  Слот может содержать несколько страниц: у Quit их три (`QUIT MATCH` + `RESTART MATCH` /
  `CHANGE TEAMS` SOON). Страницы листаются `Q/E`, правым стиком геймпада или мышью по
  `<- -> • • •` в правом нижнем углу плитки (стрелки и точки кликабельны, точки крупные);
  `Left/Right` двигают фокус между плитками. В сети Continue получает meta
  `WAITING FOR RIVAL n/m` (`set_waiting`); нажатие Continue/Esc/B только шлёт голос и
  меняет эту meta — меню не закрывается и не открывается заново (иначе экран моргал у
  первого проголосовавшего). Карточка состава не «прыгает» при фокусе
  (`BentoTile.still`).
- Settings — вторая страница того же экрана: шапка скрыта, breadcrumb `PAUSE MENU > SETTINGS`,
  сетка 4×2 поднимается под крошку (низ общий с меню-страницей); живая только Side Selection
  (сетевой матч), остальное SOON. Переход туда/обратно — `UiTransition.change_content`
  (fade+scale 150/240), ввод на время перехода игнорируется (`_switching`).
  camera/visual/system в матче больше не выведены.
- Quit — подтверждение `UiModal` (`scripts/ui/ui_modal.gd`, переиспользуемый компонент): скрим
  на весь вьюпорт + светло-серая плашка сообщения (Inter 600/28, тёмный текст) и полноширинные
  строки действий (фокус — navy + lime + кейкап-подсказка, остальные — белые с тёмным текстом).
  Компонент добавляется в **корень экрана**, не в `Design`, иначе скрим не покроет letterbox;
  `z_index=100`, поэтому тайлы/пагинатор его не перекрывают. Esc закрывает.
- Проверки: `tests/check_gpf_pause.gd` (фокус, сетка, settings, пагинация, подтверждение,
  ожидание), `check_gpf_slice_ui` (Esc → пауза → lineup → game plan → возврат),
  `check_gpf_net_ui` (голосование и side selection).

## Конец матча (MatchOverScreen)

Общая база `scripts/ui/match_over_screen.gd` (`MatchOverScreen`) — скорборд `PauseScoreboard`,
мелкая строка турнира (`package.home.league`), блок «2×2 плитки + правая панель», `UiHintsBar`
и те же 150/240 мс fade+scale. Носитель — `GpfMatchOver` (`scripts/match/gpf_match_over.gd`,
CanvasLayer 7) поверх замороженного матча; открытие и выбор экрана — по снапшоту в `gpf_slice`
(`game_over` → результат; брейк `phase_break_next_phase == 3` при равном счёте → выбор ничьей).
Ввод модальный; выбор ничьей принадлежит хосту / P1 (в сети клиент видит `WAITING FOR HOST`).

- Результат — `scenes/match/match_result.tscn` (`MatchResultScreen`): `ADVANCE` (главное меню),
  `RESTART MATCH` (тот же пакет; в сети disabled с чипом `ONLINE LOBBY`), `MATCH HIGHLIGHTS` и
  `PERFORMANCE` — `SOON`; справа SOON-панель `PLAYER PERFORMANCE`. Хедер: часы заменены на
  `FULL TIME`, у финала серии — подпись `PENALTIES x – y`.
- Выбор ничьей — `scenes/match/match_choice.tscn` (`MatchChoiceScreen`): `CLASSIC` (доп. время +
  пенальти), `GOLDEN GOAL` (SOON), `PENALTIES` (серия сразу), `DRAW` (сразу результат). Правая
  панель — `MATCH INFO` (SOON). Открывается вместо брейк-экрана паузы на 90:00 при равном счёте;
  `classic` → `continue_after_phase_break()`, `penalties` → `start_shootout()`,
  `draw` → `debug_force_game_over()`.
- Старые «чёрные окна» (`GpfHud` phase menu, `GpfShootoutView` КОНЕЦ МАТЧА) удалены.
- Проверки: `check_match_result_ui`, `check_match_choice_ui`, `check_gpf_result_flow`,
  `check_gpf_slice_ui`, `check_gpf_game_shell`; стенд — состояния `RESULT`, `DECISION` в `ui_lab`.

## Подсказки (UiHintsBar)

**Правило:** нижний блок статуса и подсказок управления на любом shell-экране — только
`UiHintsBar` (`scenes/ui/ui_hints_bar.tscn`). Не создавай локальные `Status`/`UiLegend` и не
задавай свой отступ сверху. Все экраны главного меню, быстрого и сетевого матча
(`main_menu`, `network_menu`, `network_host`, `network_join`, `SideSelectView`,
`TeamSelectView`, `KitSelectView`, `MatchHubView`) используют один и тот же инстанс.

Геометрия: `Status` 24 px + gap 12 + `Legend` 24 px = 60 px; статус занимает слот всегда (даже
пустой), поэтому легенда стоит на одном и том же расстоянии от контента. Экран кладёт
`Hints` через `UiTokens.HINTS_GAP` (16 px) от низа своего контента и выравнивает по его
**левому краю и ширине**: на Host/Join — `FormPanel` (980 px), на Team Select — обе карточки
(1257 px от x=111.5), на остальных — `PANEL_W` (1480 px). API: `setup(hints)`,
`set_status(text, error)`, `height()`, `status_label`, `legend`. Адаптеры могут держать
`status_label`/`legend` как алиасы для старых тестов, но вёрстку и отступ задаёт только
`UiHintsBar`.

## Ввод (UiNav)

`UiNav` — autoload, активен только пока в дереве есть узел в группе **`ui_shell`**
(главное меню и выбор сторон добавляют себя в `_ready`; меню паузы — только пока открыто).
Вне открытого меню он молчит, поэтому геймплейный InputMap не задет.

- Направления читаются из стрелок, D-pad и левого стика (порог 0.5); первое нажатие сразу,
  удержание — повтор через 320 мс, далее каждые 220 мс.
- Направления геймпадов дополнительно идут по-устройственно — `moved_gamepad(direction, device)`
  с собственным автоповтором на каждый pad; это даёт независимое движение строк в 2P
  (`SideSelectView` слушает его, а `moved` с геймпада игнорирует).
- `Enter/Space/A` → `confirmed`; `Esc/B` → `cancelled`; `LB/RB` (и `Tab`) → табы.
- Мышь: наведение на тайл/таб = `grab_focus`, клик = обычный `pressed`. Любое движение мыши
  переключает легенду на клавиатурную.
- События навигации поглощаются, чтобы встроенная фокус-навигация Godot не двигала фокус дважды:
  стрелки, D-pad и **движение левого стика** (`InputEventJoypadMotion`, оси 0/1) не доходят до
  `ui_*`-навигации; направления стика читаются в `_process`.
- Экран подписывается на сигналы и сам решает, что делать; кнопки не полагаются на `ui_accept`
  (в Godot 4.7 в нём нет кнопки геймпада).
- `UiNav` умеет модальные оверлеи (`push_modal`/`pop_modal`, `is_modal`): OSK и диалог Back
  забирают ввод, а экран под ними проверяет `event_was_modal()` — иначе Esc, закрывший OSK,
  тем же событием вызвал бы Back, а Enter на Apply переоткрыл бы клавиатуру.

## Переходы (UiTransition)

Фон отделён от контента файлами: `scenes/ui/ui_stage.tscn` (Photo + Scrim + Overlay) и
`scripts/ui/ui_screen.gd` (Stage + Design 1920×1080 с равномерным scale). `main_menu`,
`side_select_view` и `team_select_view` инстанцируют один и тот же Stage; в группе
`ui_transition_target` лежит только `Design/PanelWrap`. Поэтому между экранами анимируется
контент (fade 150/240 мс + scale 0.96), а стадион и scrim остаются на месте. Это не autoload:
каждая сцена держит свой инстанс общего файла, а перекрытие сцен в `_swap_overlap` делает
подмену незаметной.

`UiTransition.change_scene(path)` / `change_scene_packed(packed)`:

1. 150 мс: `modulate.a → 0`, `scale → 0.96` (цель — узел в группе `ui_transition_target`,
   иначе корень сцены).
2. Новая сцена инстанцируется **поверх** старой: её `ui_transition_target` сразу получает
   `alpha 0`, остальная сцена (Stage/фон) уже видна и закрывает старую; через кадр старая сцена
   удаляется. Так между сценами нет пустого кадра с clear color.
3. 240 мс: `modulate.a → 1`, `scale → 1`.

Если у новой сцены нет `ui_transition_target`, остаётся прямой cut; clear color проекта —
`#0a1020` (`STAGE_BG`), поэтому зазора «серого экрана» нет.

В headless (`DisplayServer.get_name() == "headless"`) переход мгновенный — существующие тесты
синхронны. Во время перехода `UiNav` заблокирован.

`UiTransition.change_content(target, swap_callable)` — то же 150/240 для содержимого внутри
экрана. Открытие/закрытие панели Settings анимирует весь `PanelWrap` (табы/сетка/легенда):
150 мс fade+scale наружу → `swap()` меняет видимость и раскладку → 240 мс вход. В headless
`swap()` вызывается сразу.

Смена таба **не** гасит весь экран: сетка проигрывает вход тайлов
(`BentoGrid.play_entrance(direction)`) — 380 мс, стаггер 28 мс, сдвиг 64 px со стороны
направления таба; выбранный тайл приезжает сразу с инверсией.

## Как перевести следующий экран

1. Повесить `ui_theme.tres` на корень экрана (или `theme = UiTheme.load_or_build()` в `_ready`).
2. Добавить корень в группу `ui_shell` и (если нужен общий fade) контейнер контента в
   `ui_transition_target`.
3. Подписаться на `UiNav.moved/confirmed/cancelled`; для устройства — `UiNav.device_changed`.
4. Строить раскладку от `UiTokens`, не хардкодить цвета/размеры.
5. Прогнать `check_ui_layout` и добавить экран в `tests/capture_ui_shots.gd`.

## Проверки

```powershell
godot --headless --path . -s res://tests/check_main_menu_ui.gd
godot --headless --path . -s res://tests/check_main_menu_layout.gd
godot --headless --path . -s res://tests/check_controller_select_ui.gd
godot --headless --path . -s res://tests/check_side_select_view.gd
godot --headless --path . -s res://tests/check_team_select_view.gd
godot --headless --path . -s res://tests/check_team_select_ui.gd
godot --headless --path . -s res://tests/check_kit_select_view.gd
godot --headless --path . -s res://tests/check_kit_select_ui.gd
godot --headless --path . -s res://tests/check_kit_texture.gd
godot --headless --path . -s res://tests/check_match_hub_view.gd
godot --headless --path . -s res://tests/check_prematch_ui.gd
godot --headless --path . -s res://tests/check_prematch_vote.gd
godot --headless --path . -s res://tests/check_prematch_exit.gd
godot --headless --path . -s res://tests/check_ui_on_screen_keyboard.gd
godot --headless --path . -s res://tests/check_network_setup.gd
godot --headless --path . -s res://tests/check_network_ui.gd
godot --headless --path . -s res://tests/check_network_back_vote.gd
godot --headless --path . -s res://tests/check_gpf_net_back_vote_live.gd
godot --headless --path . -s res://tests/check_ui_hints_bar.gd
godot --headless --path . -s res://tests/check_ui_layout.gd
godot --headless --path . -s res://tests/check_gpf_pause.gd
```

- `check_main_menu_layout` — геометрия ±2 px на 1920×1080 и при масштабе 2/3, фокус
  hero→Network, disabled-тайлы, LB/RB, открытие/закрытие панели, `UiTransition.instant`.
- `check_controller_select_ui` — реальный экран: keyboard home → centre → away, центр не
  подтверждается, ready пишет `ShellState` и ведёт в Team Select; проверяется геометрия
  шапки/body/устройства и тон по индексу.
- `check_side_select_view` — общий view с фикстурой 2P: 56/691.2/84/104, позиции 104/698/1292,
  куи, ready-бейдж, tween 340 мс, сигналы `UiNav`, resume-оверлей, имена сети и scale 2/3 на
  1280×720.
- `check_team_select_view` — общий TeamSelectView с фикстурой: карточка 512×820, позиции
  111.5/856.5, блоки 155.8/431/213.2, фокус/cues/ready/idle, звёзды, ввод `UiNav`, 2P-геймпад,
  Tab между слотами, error/retry, scale 2/3.
- `check_team_select_ui` — реальный локальный экран: lazy-каталог, фокус, ready home → CPU away,
  ready away → Kit Select + `ShellState`, ошибка базы и повторная загрузка.
- `check_kit_select_view` — общий KitSelectView с фикстурой: 1480/420, колонки 524.7/410.6,
  панель/карусель/точки/ready, focus и ready-состояния, один комплект, 2P-геймпад, Tab,
  error/retry, scale 2/3.
- `check_kit_select_ui` — реальный локальный путь: `kits.json` и `tm_id`, дефолтные main/white,
  Left/Right, ready home → away, ready away → Match Hub, `ShellState.kit_*` и `package.team.kit`,
  Esc → Team Select.
- `check_kit_texture` — данные и матч-путь: `TeamCatalog.tm_id`, импортированные спеки, fallback
  из цветов, kit-shader на `gpf_kit` реального `gpf_fullbody` и CPU-атлас из `texture_for`.
- `check_match_hub_view` — общий MatchHubView с фикстурой: геометрия 1480/680/530/110,
  колонки 362.5/735, 11 строк, звёзды, command-ячейки, UiNav+мышь, Options/Exit, 2P
  vote, client read-only, scale 2/3.
- `check_prematch_ui` — локальный путь: scoreboard/колонки из каталога, Back → Kit, Options →
  `ShellState`, Game Plan → правка состава → пакет → runtime, Start → `gpf_slice`.
- `check_prematch_vote` — 2P: голос устройства, повторное нажатие отзывает, матч стартует только
  когда проголосовали все локальные устройства.
- `check_prematch_exit` — четвёртая ячейка `EXIT` возвращает в главное меню.
- `check_gpf_net_ui` — LAN-путь теперь идёт через `NetworkMatchHub`: host options/Start,
  client ждёт `MatchSetup` (в одном процессе — host-плечо); Host/Join формы используют
  `UiFormRow`, проверяются inline-ошибки и сохранение host-значений; сетевой Kit Select
  стартует на home, меняет home/away и требует ready обеих форм.
- `check_ui_on_screen_keyboard` — общий OSK: строки/actions, фильтры, лимиты, физическая
  клавиатура (буквы/пробел/backspace), `UiNav`-навигация, modal ownership, Apply/backdrop/cancel.
- `check_network_setup` — чистая валидация IPv4/hostname/port/name, фильтры и round-trip
  `NetworkSettings` (host/join отдельно, дефолты, битые значения, reset).
- `check_network_ui` — реальные экраны: меню без Back, Host/Join формы, OSK из поля, возврат
  фокуса, Esc/Enter не проваливаются сквозь OSK, Connecting/ошибка, персистентность join.
- `check_ui_hints_bar` — правило общего нижнего блока: все shell-экраны (main/network/host/join
  и общие Side/Team/Kit/Hub view) содержат `Hints` типа `UiHintsBar`; проверяются единая высота
  60 px, `setup`/`set_status`, слот статуса и легенда.
- `check_network_back_vote` — локальный голос, зеркальный echo, согласие, входящий диалог,
  `LEAVE TOO`/`STAY`, `LeaveSession`, `clear_server_vote`.
- `check_gpf_net_back_vote_live` — два процесса: реальный Host-экран + реальный Join-экран
  (child), ready → Teams → BackToSides → Sides → LeaveSession → меню.
- Скриншоты главного меню: `.scratch/ui_shots/main_menu_{play,panel,gamepad}_1920x1080.png`
  (генерируются временным скриптом; в `capture_ui_shots.gd` состояния меню ещё не добавлены).
- Скриншоты выбора сторон: `.scratch/ui_shots/side_select_{1p,2p,ready,network,network_resume}_{1920x1080,1280x720}.png`
  — `godot --path . -s res://tests/capture_side_select_shots.gd` (фикстуры —
  `tests/side_select_fixture.gd`).
- Скриншоты выбора команд: `.scratch/ui_shots/team_select_{local_1p_home,local_1p_away,local_2p,network,network_ready,error,real,real_club,real_club_competition}_{1920x1080,1280x720}.png`
  — `godot --path . -s res://tests/capture_team_select_shots.gd` (фикстуры —
  `tests/team_select_fixture.gd`; `real` — настоящий экран с lazy-каталогом).
- Скриншоты выбора форм: `.scratch/ui_shots/kit_select_{local_1p_home,local_1p_away,local_2p,network,network_ready,one_kit,error,real}_{1920x1080,1280x720}.png`
  — `godot --path . -s res://tests/capture_kit_select_shots.gd` (фикстуры —
  `tests/kit_select_fixture.gd`; `real` — Barcelona/Real Madrid с imported kit specs).
- Скриншоты хаба: `.scratch/ui_shots/match_hub_{local_1p,local_2p,network_host,network_client,game_plan,options,exit_selected}_{1920x1080,1280x720}.png`
  — `godot --path . -s res://tests/capture_match_hub_shots.gd` (фикстура —
  `tests/match_hub_fixture.gd`).
- Скриншоты сетевых экранов: `.scratch/ui_shots/network_{menu,host,host_osk,join,join_osk,join_connecting,join_error,back_dialog}_{1920x1080,1280x720}.png`
  — `godot --path . -s res://tests/capture_network_shots.gd`.

## Известные ограничения

- Главное меню, выбор сторон, выбор команд, выбор форм, предматчевый хаб и сетевые меню
  (меню/Host/Join/OSK/Back-голосование) переведены; состав и in-match UI пока живут по-старому.
  Kit стоит отдельным шагом перед хабом.
- На выборе сторон **мышь инертна** (решение владельца): нет кликов по половинам устройства,
  ready-галочке или back. Ready/back — только клавиатура (`Enter`/`Esc`) и геймпад (`A`/`B`).
  На выборе команд и форм мышь тоже инертна, а `V` (состав) убран.
- На выборе команд, форм и хабе нет шапки (как в прототипе); уровни читаются по блокам/панелям.
- В сетевом хабе Game Plan правит состав через `planswap`/`planscheme`/`planrole` в общей
  pre-match `MatchData`; `start_match` использует её, поэтому LAN-пакет стартует с
  согласованными составами. EXIT закрывает LAN-сессию и возвращает в главное меню.
- Команды с <11 игроками не попадают в список Team Select (`can_field_eleven` через
  `players.team_id`/`nationalteam_id` индексы или готовый `team_eligibility.json`); хаб получает
  только валидные составы и не имеет
  собственного error-состояния.
- 3D-превью форм — статичный диорама-снимок без стадиона и без симуляции; это не полноценный
  рендер матча. Камера подобрана так, чтобы за кромкой поля был газон, а не пустота.
- В сети киты не синхронизируются: каждый участник локально выбирает обе формы (home → away, как
  в 1P), поэтому у разных пиров матч может выглядеть в разных формах (решение владельца). Отдельного kit-ready в
  лобби нет: host стартует из хаба, не дожидаясь, пока клиент закончит локальный Kit Select;
  Back из хаба возвращает на Kit Select в той же фазе 2.
- Рейтинги/звёзды считаются из состава только выбранных команд; у команд без логотипа показывается
  глиф-заглушка, у стран без флага — `globe`.
- `UiMenuPanel.setup` рассчитан на короткие note-строки без автопереноса; длинный текст надо
  переносить вручную.
- `text-wrap: balance`, `clip-path` и CSS `box-shadow` не имеют прямых аналогов: переносы
  заголовков задаются копирайтом, breadcrumb рисуется `_draw`, тени подбираются по `StyleBoxFlat`.
- Смена таба сбрасывает выбор на первый тайл (как в прототипе); возврат назад по истории
  не сохраняет выбор между экранами.
- Геймпад-навигация в прототипе на главном меню отсутствовала — поведение спроектировано здесь
  (см. спеку).
