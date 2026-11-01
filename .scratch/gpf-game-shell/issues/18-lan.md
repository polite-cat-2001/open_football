# 18: LAN

**What to build:** Два игрока на разных машинах (или двух процессах на одной) проводят матч по
localhost/LAN: host создаёт игру, client подключается по IP:порту, оба выбирают стороны и команды,
host запускает матч. В C++ уже всё есть (`NetServer`/`NetClient`/`NetMatchSession`, `netlib`);
портируется только shell-слой: API моста, лобби-экраны и in-match оверлеи сети.

**Blocked by:** 11, 17

**Status:** in-progress (2026-11-01; lobby UI + match entry + pause/break votes)

**Что уже есть в `of_port` (не переписывать):** boost::asio TCP control + UDP snapshots,
handshake (protocol/build/data/animation хэши), host-authoritative симуляция, thin client, лобби
`LobbyState` (Sides/Teams), side select, `MatchSetup`, input delay, pause vote, halftime vote,
disconnect/rejoin, keepalive. Спека: `GameplayFootball-of_port/docs/specs/2026-09-11-lan-match-design.md`.

**Ограничения v1:** протокол не меняем. По сети едут только `teamId[2]` (same-data): обе машины
имеют одинаковую `database.sqlite` и одинаковый data hash, матч строится из локальных данных.
Кастомные составы, формации и опции прематча по сети **не** передаются — играем дефолтными
составами, параметры матча host-authoritative. Full-setup (`tm_id`) — вне этого тикета.

- [x] Мост: `net_host(port, name)`, `net_join(address, port, name)`, `net_leave()`,
      `net_lobby()` (стороны, ready, teamId, ошибки), `net_action(side/ready/team cursor/commit)`,
      `net_start()`, `net_take_match_setup()`, `is_net_active/host/client`.
- [x] Черновое лобби в Godot по `src/menu/network/*`: Host/Join/Lobby/Sides + Match options;
      раскладка и управление из оригинала, вид не полируем.
- [x] Host: матч из выбранных `teamId`; client: получает `MatchSetup`, собирает локальный пакет
      по тем же id и строит удалённый `Match` (UI-лобби + headless-харнесс).
- [ ] In-match: пауза-голосование и перерыв — [x]; осталось side-select на паузе и баннеры
      дисконнекта/rejoin.
- [ ] Два процесса на localhost: полный матч виден обоим, счёт/время совпадают.
- [x] Headless/CLI-харнесс запускает host + client и проверяет лобби, старт, кикофф,
      remote time/score, пауза-голосование обоих и `net_leave`.
- [ ] Ручная проверка на двух машинах (или двух окнах) с реальным геймпадом.

**DoD:** матч на двух процессах проходит без расхождения счёта, пауза требует голоса обоих,
выход клиента не ломает host, лобби-ошибки читаемы.

## Сделано (2026-11-01, foundation)

- `GpfRuntimeNode`: net-поля, `net_host/net_join/net_leave`, `net_lobby` (players, sides,
  teamId/country/league, chooser/cursor/scroll, options, revision/phase/sideSelect/hubVote,
  connection/reject), `net_action` (принимает int enum или имя вида `set_side`/`set_ready`),
  `net_start` (сверяет пакет с `lobby.teamId`, broadcast `NetMatchSetup`, `SetTeamIDs`,
  `start_match`), `net_take_match_setup`, `is_net_*`.
- `get_snapshot()`: `net_active`, `net_is_host`, `net_is_client`, `net_phase_state`,
  `net_local_id`, `net_connection`.
- Грабля, которую пришлось закрыть: `apply_controller_setup()` в net-матче не применяет
  shell-раскладку (иначе затирает `NetHIDDevice`/`DelayedHIDDevice`); перед `StartMatch`
  очередь контроллеров очищается, чтобы `Match` не создал лишних локальных `HumanGamer`.
  `step_one_tick`/`_process` в net-режиме продолжают крутить `GameTask` на паузе (голоса
  resume и snapshots), а не замирают, как локальный матч. Client в bridge-ветке 90:00 не
  форсит `GameOver` — финал приходит snapshot'ом.
- Тесты: `tests/check_gpf_net_lobby.gd` (host bind, lobby, действия, host net_start, leave,
  повторный bind того же порта) и `tests/check_gpf_net_two_process.gd` +
  `tests/gpf_net_client_probe.gd` (child process: connect, sides/ready, teams, `MatchSetup`,
  package по id, remote match, remote time/score; host берёт кикофф).
- Ограничение следующего шага: мост требует уже стартованный runtime (`MenuTask`), поэтому
  лобби до матча должно жить там, где `GpfRuntimeNode` уже поднят (решить при порте UI:
  держать runtime-узел в главном меню/автозагрузке или выделить отдельный lobby runtime).
- Отступление: `net_lobby()` отдаёт числовые enum'ы (phase/connection/reason/side) — UI-слой
  переводит их в подписи; `net_action` дополнительно понимает строковые имена.
- На момент foundation-среза ещё не было Godot-экранов и in-match оверлеев; следующий
  раздел закрывает лобби, Options и паузу/перерыв.

## Сделано (2026-11-01, lobby UI + match entry + pause)

- Runtime без матча: `auto_start_match` (`GpfRuntimeNode`) — menu/LAN поднимают C++ runtime
  с `MenuTask`/`NetServer`, но без `Match`; `NetShell.runtime()` находит узел в группе
  `gpf_runtime` или создаёт его и стартует в этом режиме. Матчевая сцена использует тот же
  узел; host уже стартовал матч в `net_start()` и `gpf_slice` цепляет к нему презентацию,
  client строит удалённый матч на входе в сцену.
- Экраны (порты оригинальных страниц): `scenes/network_menu.tscn` (Host/Join/Back) →
  `network_host` (Port/Name/Open lobby) / `network_join` (Address/Port/Name/Connect,
  «Connecting…», читаемая причина отказа) → `network_sides` (сетевой `SideSelectPage`:
  зеркальные игроки, HOME/AWAY/centre, ready-тоггл, Esc/B; Home/центр/Away идёт по шагам,
  device keyboard/gamepad уходит в лобби и регистрируется в runtime) → `network_lobby`
  (сетевой `NetworkLobbyPage`: HOME/AWAY-панели, Country/Competition/Team, Ready; правит
  только локальный chooser, Tab/Y переключает панели, если chooser выбирает обе стороны) →
  `network_match_options` (порт `NetworkMatchOptionsPage`: difficulty/duration только у
  host, Start match; client ждёт `MatchSetup`). В главном меню добавлена кнопка **Network**.
- Отступление от текущего `of_port`-флоу: фаза Options использует существующую страницу
  `NetworkMatchOptionsPage` (в оригинале она не подключена; рабочая — PreMatch hub), а не
  полный `PreMatchPage`. Составы/формации — дефолтные (same-data v1), поэтому Game plan и
  кастомизация лайнапов в LAN пока недоступны; difficulty/duration host-authoritative.
- Матч: `gpf_slice` принимает живой host-матч вместо безусловного `restart_match`; client
  строит `Match` из `MatchSetup`-id с дефолтным пакетом (`NetworkMatch`). Выход в меню
  делает `net_leave`; «Начать заново» в сетевом матче заблокирован (иначе desync).
- Пауза: `Esc`/Start на любом peer ставит матч на паузу; у второго peer меню открывается по
  `snapshot.paused`. Continue/Esc — голос `set_resume_ready`, меню показывает `resume ready
  n/total` и закрывается, когда host снял паузу после голосов обоих (проверено двумя
  процессами). Перерыв/HALF TIME: HUD-оверлей открывается по `phase_break` на обоих; Continue
  тоже голос, host снимает паузу после всех, `clear_phase_break_pending()` снимает латч на
  host; на client заголовок фазы берётся из `match_phase`, если `phase_break_next_phase` нет.
- Геймпад: последнее устройство peer'а (`note_local_device`) регистрируется в runtime и
  уходит в лобби как `device`; host биндит его в `NetMatchSession`, client форвардит через
  `InputSetup`-слоты. Ручная проверка реальным pad'ом ещё нужна.
- Тесты: `tests/check_gpf_net_ui.gd` (весь host-путь Main menu → Network → Host → Sides →
  Teams → Options → GpfSlice, пауза-голос/перерыв, выход с `net_leave`); two-process харнесс
  дополнительно проверяет паузу: один голос не снимает паузу, два — снимают. Регрессии:
  `check_gpf_net_lobby`, `check_gpf_net_two_process`, `check_gpf_pause`,
  `check_gpf_match_cycle`, `check_gpf_slice_ui`, `check_gpf_game_shell`,
  `check_main_menu_ui`, `check_prematch_ui`.
- Не сделано: in-match side selection (пункт меню паузы — заглушка), controller-select
  оверлей, баннеры disconnect/rejoin, полный матч на двух процессах, ручная проверка на двух
  машинах/окнах.
- Исправлено (2026-11-01): thin client брал «своего» игрока по стороне лобби, поэтому
  подсветка/подпись/ретикул могли указывать не на управляемого. Теперь `get_player_ids`/
  `build_player` отдают `owner_id` (host: `GetControllingPeerId`, client:
  `Player::GetRemoteOwnerId`), а `get_human_player_id/ids/team` фильтруют по локальному
  owner'у. Правило подсветки: **host и client показывают только своего выбранного игрока**
  (на host клиентский NetHIDDevice-owner исключается), **локальный 2P показывает обоих**
  (у обоих локальных геймеров owner 0 == localPeerId). `gpf_slice._pick_controlled` сначала
  берёт `owner_id`, затем падает на сторону. Это же чинит `set_piece_role`/
  `set_piece_aim_point` и меню исполнителя стандарта на клиенте: снапшот пенальти теперь
  отдаёт Kicker + aim, и жёлтый ретикул появляется. Two-process harness принудительно ставит
  пенальти команде клиента и проверяет `human == owner`, `role == Kicker`, непустой
  `aim_point`, `local_taker`; host проверяет, что подсвечен только его игрок. Новый
  `check_gpf_local_2p_highlights` проверяет две подсветки в локальном 2P.
- Риски для ручной проверки: `NetMatchSession` выбирает геймпад по типу (`FindLocalDevice(1)` —
  первый в списке), а extension держит собственный SDL virtual joystick; при физическом pad'е
  рядом виртуальным возможен неверный выбор. Клавиатура проверена; pad требует ручного прогона
  и, при необходимости, отдельного хука в `of_port` (не протокол).

> **UI-политика:** если этому тикету нужен UI, портировать соответствующий экран/элемент из
> оригинала (`GameplayFootball-of_port/src/menu/...`) — та же раскладка, подписи, иконки,
> управление и порядок экранов. Godot-UI не изобретать заново; отступления документировать.
