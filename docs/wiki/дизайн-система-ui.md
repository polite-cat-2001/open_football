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
- Остальной шелл (`prematch`, `squad`, `network_menu`, `network_host/join` и т.д.)
  и in-match UI пока живут по-старому. Выбор форм — следующий этап: сейчас Kit остаётся вкладкой
  прематча, отдельного `KitSelectView` ещё нет.
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
  не-центральной строки; коммит пишет `ShellState.controllers` и ведёт в Team Select/Prematch
  через `UiTransition`. **Hot-plug:** `Input.joy_connection_changed` → `_sync_participants()`:
  новый геймпад появляется в центре, отключённый исчезает, существующие строки сохраняют
  side/ready. Порядок строк сверху вниз — порядок подключения (клавиатура первая, новые
  геймпады добавляются в конец).
- `scripts/ui/network_sides.gd` — снапшот лобби (имена, YOU, ready, device), `resume_mode`
  (не выходит из сессии), host-authoritative commit, resume-голосование, disconnect/join
  статусы. Оверлей в матче — тот же view с `overlay=true`.

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
  выбранных команд из `ShellState`, 1P home → CPU away и 2P parallel, ready обеих → прематч.
- `scripts/ui/network_lobby.gd` — снапшот лобби, `set_selection(side, kind, index)` /
  `set_team_ready`, seed дефолтов, имена/`YOU`, disconnect/join статусы, phase 0 → sides,
  phase 2 → options. Раскладка и ввод в адаптерах не дублируются.

## Ввод (UiNav)

`UiNav` — autoload, активен только пока в дереве есть узел в группе **`ui_shell`**
(главное меню и выбор сторон добавляют себя в `_ready`). В матче он молчит, поэтому геймплейный
InputMap не задет (кроме resume-оверлея, который живёт в группе только пока открыт).

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
godot --headless --path . -s res://tests/check_ui_layout.gd
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
  ready away → прематч + `ShellState`, ошибка базы и повторная загрузка.
- Скриншоты главного меню: `.scratch/ui_shots/main_menu_{play,panel,gamepad}_1920x1080.png`
  (генерируются временным скриптом; в `capture_ui_shots.gd` состояния меню ещё не добавлены).
- Скриншоты выбора сторон: `.scratch/ui_shots/side_select_{1p,2p,ready,network,network_resume}_{1920x1080,1280x720}.png`
  — `godot --path . -s res://tests/capture_side_select_shots.gd` (фикстуры —
  `tests/side_select_fixture.gd`).
- Скриншоты выбора команд: `.scratch/ui_shots/team_select_{local_1p_home,local_1p_away,local_2p,network,network_ready,error,real,real_club,real_club_competition}_{1920x1080,1280x720}.png`
  — `godot --path . -s res://tests/capture_team_select_shots.gd` (фикстуры —
  `tests/team_select_fixture.gd`; `real` — настоящий экран с lazy-каталогом).

## Известные ограничения

- Главное меню, выбор сторон и выбор команд переведены; прематч, состав, сетевые меню и in-match
  UI пока живут по-старому. Отдельного экрана выбора форм ещё нет — Kit остаётся вкладкой прематча.
- На выборе сторон **мышь инертна** (решение владельца): нет кликов по половинам устройства,
  ready-галочке или back. Ready/back — только клавиатура (`Enter`/`Esc`) и геймпад (`A`/`B`).
  На выборе команд мышь тоже инертна, а `V` (состав) убран.
- На выборе команд нет шапки (как в прототипе); уровни читаются по блокам, а не по заголовкам.
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
