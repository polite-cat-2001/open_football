# Дизайн-система UI и главное меню

Перенос визуального языка прототипа `gf-ui-prototype` (Svelte + один `web/src/app.css`) в Godot.
Действует с 2026-11-02. Исходная спека — `docs/superpowers/specs/2026-11-02-ui-design-system-main-menu.md`;
источник истины по числам — **`app.css` прототипа**, а не его вики (вики расходится с кодом).

## Что уже переведено

- **Главное меню** (`scenes/main_menu.tscn`, `scripts/ui/main_menu.gd`) — единственный экран на новой
  системе. Остальной шелл (`controller_select`, `team_select`, `prematch`, `squad`, `network_*`) и
  in-match UI пока живут по-старому.
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
scripts/ui/bento_tile.gd     — тайл бенто (Button + Panel/StyleBox + rail/hatch/иконка)
scripts/ui/bento_grid.gd     — ручная сетка 4×2 (не Container: selected-тайл уезжает)
scripts/ui/ui_tab_bar.gd     — табы с измеряемым маркером
scripts/ui/ui_legend.gd      — нижняя легенда, переключается по устройству
scripts/ui/ui_breadcrumb.gd  — скошенная плашка пути (custom _draw)
scripts/ui/ui_menu_row.gd    — строка панели (88 px, инверсия по фокусу)
scripts/ui/ui_menu_panel.gd  — note + rows/static для подменю
scripts/ui/ui_icon.gd        — белые SVG из assets/ui/icons, тонируются modulate
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
`CrumbsCurrent`, `Kbd`, `SoonChipLabel`, `LegendLabel`.

StyleBox-варианты: `KbdBox`, `SoonChip`, `PanelNoteBox`. Фоны тайлов/маркеров/строк собираются
`StyleBoxFlat` в коде (тени `shadow_size/offset` — приближение CSS `box-shadow`).

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

## Ввод (UiNav)

`UiNav` — autoload, активен только пока в дереве есть узел в группе **`ui_shell`**
(главное меню добавляет себя в `_ready`). В матче он молчит, поэтому геймплейный InputMap не задет.

- Направления читаются из стрелок, D-pad и левого стика (порог 0.5); первое нажатие сразу,
  удержание — повтор через 320 мс, далее каждые 220 мс.
- `Enter/Space/A` → `confirmed`; `Esc/B` → `cancelled`; `LB/RB` (и `Tab`) → табы.
- Мышь: наведение на тайл/таб = `grab_focus`, клик = обычный `pressed`. Любое движение мыши
  переключает легенду на клавиатурную.
- События навигации поглощаются, чтобы встроенная фокус-навигация Godot не двигала фокус дважды:
  стрелки, D-pad и **движение левого стика** (`InputEventJoypadMotion`, оси 0/1) не доходят до
  `ui_*`-навигации; направления стика читаются в `_process`.
- Экран подписывается на сигналы и сам решает, что делать; кнопки не полагаются на `ui_accept`
  (в Godot 4.7 в нём нет кнопки геймпада).

## Переходы (UiTransition)

`UiTransition.change_scene(path)` / `change_scene_packed(packed)`:

1. 150 мс: `modulate.a → 0`, `scale → 0.96` (цель — узел в группе `ui_transition_target`,
   иначе корень сцены).
2. Смена сцены, ожидание двух кадров.
3. 240 мс: `modulate.a → 1`, `scale → 1`.

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
godot --headless --path . -s res://tests/check_ui_layout.gd
```

- `check_main_menu_layout` — геометрия ±2 px на 1920×1080 и при масштабе 2/3, фокус
  hero→Network, disabled-тайлы, LB/RB, открытие/закрытие панели, `UiTransition.instant`.
- Скриншоты главного меню: `.scratch/ui_shots/main_menu_{play,panel,gamepad}_1920x1080.png`
  (генерируются временным скриптом; в `capture_ui_shots.gd` состояния меню ещё не добавлены).

## Известные ограничения

- Остальной шелл не переведён: тема и `UiNav` на нём пока не подключены.
- `UiMenuPanel.setup` рассчитан на короткие note-строки без автопереноса; длинный текст надо
  переносить вручную.
- `text-wrap: balance`, `clip-path` и CSS `box-shadow` не имеют прямых аналогов: переносы
  заголовков задаются копирайтом, breadcrumb рисуется `_draw`, тени подбираются по `StyleBoxFlat`.
- Смена таба сбрасывает выбор на первый тайл (как в прототипе); возврат назад по истории
  не сохраняет выбор между экранами.
- Геймпад-навигация в прототипе на главном меню отсутствовала — поведение спроектировано здесь
  (см. спеку).
