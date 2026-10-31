# 18: LAN

**What to build:** Два игрока на разных машинах (или двух процессах на одной) проводят матч по
localhost/LAN: host создаёт игру, client подключается по IP:порту, оба выбирают стороны и команды,
host запускает матч. В C++ уже всё есть (`NetServer`/`NetClient`/`NetMatchSession`, `netlib`);
портируется только shell-слой: API моста, лобби-экраны и in-match оверлеи сети.

**Blocked by:** 11, 17

**Status:** ready-for-agent

**Что уже есть в `of_port` (не переписывать):** boost::asio TCP control + UDP snapshots,
handshake (protocol/build/data/animation хэши), host-authoritative симуляция, thin client, лобби
`LobbyState` (Sides/Teams), side select, `MatchSetup`, input delay, pause vote, halftime vote,
disconnect/rejoin, keepalive. Спека: `GameplayFootball-of_port/docs/specs/2026-09-11-lan-match-design.md`.

**Ограничения v1:** протокол не меняем. По сети едут только `teamId[2]` (same-data): обе машины
имеют одинаковую `database.sqlite` и одинаковый data hash, матч строится из локальных данных.
Кастомные составы, формации и опции прематча по сети **не** передаются — играем дефолтными
составами, параметры матча host-authoritative. Full-setup (`tm_id`) — вне этого тикета.

- [ ] Мост: `net_host(port, name)`, `net_join(address, port, name)`, `net_leave()`,
      `net_lobby()` (стороны, ready, teamId, ошибки), `net_action(side/ready/team cursor/commit)`,
      `net_start()`.
- [ ] Черновое лобби в Godot по `src/menu/network/*`: Host/Join/Lobby/Sides; раскладка и
      управление из оригинала, вид не полируем.
- [ ] Host: матч из выбранных `teamId`; client: получает `MatchSetup`, собирает локальный пакет
      по тем же id и строит удалённый `Match`.
- [ ] In-match: пауза-голосование, перерыв, side-select на паузе, баннеры дисконнекта/rejoin.
- [ ] Два процесса на localhost: полный матч виден обоим, счёт/время совпадают.
- [ ] Headless/CLI-харнесс запускает host + client и проверяет лобби, старт, паузу и выход.
- [ ] Ручная проверка на двух машинах (или двух окнах) с реальным геймпадом.

**DoD:** матч на двух процессах проходит без расхождения счёта, пауза требует голоса обоих,
выход клиента не ломает host, лобби-ошибки читаемы.

> **UI-политика:** если этому тикету нужен UI, портировать соответствующий экран/элемент из
> оригинала (`GameplayFootball-of_port/src/menu/...`) — та же раскладка, подписи, иконки,
> управление и порядок экранов. Godot-UI не изобретать заново; отступления документировать.
