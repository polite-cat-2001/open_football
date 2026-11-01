# 21: HUD выбора исполнителя стандарта

**What to build:** Довести черновой оверлей `GpfHud` до оригинала `SetPieceTakerPage`
(`src/menu/ingame/setpiecetaker.cpp`): заголовок «set-piece taker», список всех активных игроков
бьющей команды с отметкой `*` у текущего, подсказка «enter: apply / escape: close», выбор
стрелками с повтором, применение через `RequestSetPieceTaker`. Меню открывается только у
human-исполнителя (его устройством), авто-закрывается при ударе/смене исполнителя/конце стандарта.

**Blocked by:** 11, 17

**Status:** done

- [x] Раскладка/тексты/иконки как в `SetPieceTakerPage` (или осознанное отступление в тикете).
- [x] Только устройство исполнителя управляет меню; в 2P второй человек не может его открыть.
- [x] Открытие: Tab/Select (клавиатура/геймпад), авто-закрытие на удар и по концу стандарта.
- [x] Текущий исполнитель помечен; выбор применяется, управление остаётся у открывшего.
- [x] Для away-человека меню показывает игроков его команды (использовать
      `set_piece_hud_player`/тейкера, а не первого human).
- [x] `ui_lab`-состояние + скриншоты 1920/1280; layout/focus-тест.
- [x] Headless-тест: открытие/навигация/применение для home и away.

## As-built (2026-11-01)

Компонент `scripts/match/gpf_set_piece_taker.gd` (`GpfSetPieceTakerMenu`) — порт
`SetPieceTakerPage`; `GpfHud` владеет им и оставляет прежний API (`toggle_taker_menu`,
`handle_taker_menu_key/joy[_motion]`, `close_taker_menu`), `gpf_slice` только маршрутизирует ввод.

- Заголовок «set-piece taker», список 11 активных игроков бьющей команды, `(GK)` у вратаря,
  `*` у текущего, подсказка «enter: apply   escape: close».
- Открытие: `Tab` (клавиатура) / `Select` (геймпад). Проверка владельца: сторона стандарта по
  `set_piece_hud_player`/`referee_taker` из `get_player_ids` (fallback `referee_team`), затем
  `ShellState.controllers`; клавиатура/геймпад должны совпасть с устройством этой стороны.
- Навигация: стрелки/D-pad/левый стик, повтор 220 мс (как `takerMenuMoveDelay_ms` у оригинала).
  A/Enter применяет (`request_set_piece_taker`), B/Esc закрывает, W/A/S/D и X/Y закрывают без
  удара. Чужое устройство не открывает, не листает и не закрывает меню (в 2P).
- Авто-закрытие: `set_piece_taker_menu_open`/`set_piece_local_taker`/`set_piece_human_taker`/
  `in_set_piece` из снапшота (удар, конец стандарта, потеря human-исполнителя).
- HUD-легенда и подсказка скрываются под оверлеем; подсказка показывает `Select` для геймпада.

### Допустимые отступления от оригинала

- Оригинал в `SetPieceTakerPage` не рисует blackout — оверлей прозрачный; так же и здесь
  (кнопки полупрозрачные, матч виден). В оригинале это Gui2-скин; у нас Godot `Button` с
  полупрозрачным `StyleBoxFlat`, чтобы читался на газоне.
- Шрифт и пиксельные отступы Gui2 не воспроизведены один в один: пропорции 15/93%/30–70%
  сохранены, размер шрифта масштабируется от высоты окна (нужно для 1280×720).
- Оригинал закрывает меню по любой кик-кнопке; у нас на клавиатуре это W/A/S/D, на геймпаде X/Y
  (A занята применением, B — закрытием).
- Меню использует `Control`-оверлей и фокус Godot, а не `Gui2Page`; порядок/подписи/состав
  совпадают, иконок в оригинале нет.
- `set_piece_taker_menu_available` в снапшоте бывает `false` на кадр после закрытия (C++ latch
  `setPieceTakerMenuSwallow`); HUD не считает это новым состояние и не переоткрывает меню.

### Тесты / приёмка

- `tests/check_gpf_set_piece_taker.gd` — PASS: home/away списки, `*`/`(GK)`, навигация/apply,
  2P-владение (в т.ч. чужой Tab/Select ничего не делает), авто-закрытие; реальный runtime с
  человеком на away — форсированный штрафной, список away, смена тейкера, управление остаётся.
- `tests/check_gpf_slice_ui.gd` — PASS (title/hint/`*`/`(GK)`/владелец/apply).
- `tests/check_ui_layout.gd` — PASS на 1920×1080 и 1280×720 (state 15).
- Скриншоты: `.scratch/ui_shots/ui_lab_set-piece_taker_1920x1080.png`,
  `.scratch/ui_shots/ui_lab_set-piece_taker_1280x720.png` (просмотрены), плюс живой кадр
  `.scratch/ui_shots/live_set_piece_taker.png`.
- Живой прогон MCP: кикофф → `F` (штрафной) → `Tab` → `Down` (ровно один шаг) → `Enter` →
  тейкер сменился, меню закрыто; кик-кнопка закрывает без удара; `UiHarness.tap_joy_button`
  чужим pad не меняет открытое меню. Геймпад проверен и headless-тестом 2P; отдельный живой
  матч «away + pad» не поднимался (виртуальный pad регистрируется в C++ SDL, а
  `InputSetup` нормализует устройства по `Input.get_connected_joypads()`).
- Прогнаны: `check_gpf_pause`, `check_gpf_game_plan`, `check_gpf_game_shell`, `check_gpf_input`,
  `check_gpf_setpieces` (free/taker), `check_ui_layout`; `match.tscn` — только baseline.

> **UI-политика:** если этому тикету нужен UI, портировать соответствующий экран/элемент из
> оригинала (`GameplayFootball-of_port/src/menu/...`) — та же раскладка, подписи, иконки,
> управление и порядок экранов. Godot-UI не изобретать заново; отступления документировать.
