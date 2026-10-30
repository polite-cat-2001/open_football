# 10: Controller Select / Side Select + геймпад (1P)

**What to build:** Godot показывает подключённые устройства, даёт выбрать сторону и устройство.
C++ получает настройку контроллеров и отдельный ввод на игрока — оси и кнопки, а не общее
клавиатурное состояние. Матч играется и с геймпада, и с клавиатуры.

**Blocked by:** 01, 06

**Status:** done

- [x] Godot перечисляет клавиатуру и геймпады.
- [x] Можно выбрать сторону и устройство.
- [x] C++ получает настройку контроллеров и отдельный ввод на игрока.
- [x] Матч играется с геймпада и с клавиатуры.
- [x] Headless-тест подставляет ввод и проверяет, что управляемый игрок реагирует.
- [ ] Ручная проверка геймпада.

**As-built (2026-10-30, UI-ревизия):** экран портирован из оригинала — `SideSelectPage`
(`GameplayFootball-of_port/src/menu/sideselect.cpp`): `scenes/controller_select.tscn` /
`scripts/ui/controller_select.gd` с иконками `keyboard_small.png` / `controller_small.png`,
шрифтом Alegreya, колонками Team 1/Team 2, зелёной ready-галочкой, управлением
Left/Right + Enter/A + Esc/B. Поток как в оригинале: **Start Match → Controller Select →
Team Select → PreMatch** (если пара команд уже выбрана, controller screen ведёт сразу в прематч —
уступка оболочке). Премате вернулся к прежней высоте, лишний блок выбора из него убран.

`controller_select` кладёт в `ShellState.controllers` только участников с выбранной стороной;
`InputSetup` перечисляет устройства и передаёт setup в C++ (`register_gamepad` /
`set_controller_setup`), `gpf_slice` маршрутизирует сырые оси/кнопки (`set_gamepad_button` /
`set_gamepad_axis`). В меню повтор/перерыв/серия/исполнитель A/Start/B/D-pad/Back транслируются
в Enter/Esc/стрелки/Tab. C++ (`GpfRuntimeNode`) хранит setup у себя и переприменяет его перед
каждым тиком; геймпад — extension-owned SDL virtual joystick, ввод идёт через synthetic
`InputSDLEvent`. GameplayFootball (`of_port`) не меняется. Игрок может играть за away.

Отступления от оригинала: ready на центральной (spectator) строке заблокирован с подсказкой
«Choose a side first» — иначе можно уйти в матч без HumanGamer; при нескольких устройствах все
строки стартуют в центре (в оригинале первый геймпад сразу home), чтобы неактивная строка не
блокировала чужой ready.

Тесты: `tests/check_gpf_input.gd` (клавиатура home + виртуальный геймпад away, движение игрока),
`tests/check_controller_select_ui.gd` (раскладка/движение стороны/ready/commit), обновлённые
`check_prematch_ui`, `check_gpf_game_shell`. Вики — `docs/wiki/ввод-и-контроллеры.md`.

**Ручная проверка (нужна):** подключить геймпад → Start Match → на экране выбора стороны
стиком/D-pad выбрать Team 1/Team 2, A — ready; проверить кикофф, перерыв (Start/A) и меню
исполнителя (Back).
