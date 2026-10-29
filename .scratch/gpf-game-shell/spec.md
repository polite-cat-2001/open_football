# gpf-game-shell — превращение среза в игру

**Статус:** утверждено 2026-10-29
**Цель:** превратить GDExtension-срез в игру: оболочка, данные из SQLite в Godot, ввод,
HUD, звук, камера. C++ остаётся матч-движком.

## Решения

- **Трекер локальный:** `.scratch/gpf-game-shell/issues/`, один файл на тикет.
- **Godot читает SQLite** и владеет каталогом лиг, команд и игроков.
- **Godot считает статы и формацию** по формулам оригинала и отправляет в C++ готовый пакет матча.
- **C++ принимает пакет** и строит матчевую модель; для матча базу не читает.
- **Замены:** Godot решает, C++ применяет.
- **Усталость и карточки:** C++ считает, Godot показывает.
- **Управление:** C++ держит `HumanController`; Godot даёт устройства, стороны и ввод на игрока.
- **HUD и звук:** Godot. **Камера:** живая переезжает в Godot, камера стандартов пока остаётся в C++.
- **Пауза:** C++ замораживает матч, Godot рисует меню.
- **Сеть:** C++ позже, вне этого набора.
- **Внешность игроков** (киты, кожа, волосы, рост) — позже.
- **Лига и карьера** — вне этого набора.
- **Runtime чинится в C++**, а не перезапуском процесса.
- **Временных RNG-заглушек нет.** Первый сдвиг случайной последовательности — переход данных
  (тикет 06), второй — камера (тикет 16). После каждого сдвига — ручная проверка геймплея.

## Границы

C++ владеет правилами матча, ИИ, судьёй, физикой, стандартами, заменам, усталостью, карточками,
человеческими контроллерами, паузой, камерой стандартов и сетью. Godot владеет данными, экранами,
вводом с устройств, HUD, звуком, камерой и визуалом.

## Порядок работ

Сначала префактор презентации и починка runtime, затем данные и пакет матча, затем состав, ввод,
HUD, пауза, звук и камера. Точные зависимости — в тикетах.

## GitHub

Тикеты продублированы в GitHub Issues для внешнего трекинга:

| Локальный | GitHub |
|---|---|
| 01 | [#13](https://github.com/polite-cat-2001/open_football/issues/13) |
| 02 | [#14](https://github.com/polite-cat-2001/open_football/issues/14) |
| 03 | [#16](https://github.com/polite-cat-2001/open_football/issues/16) |
| 04 | [#15](https://github.com/polite-cat-2001/open_football/issues/15) |
| 05 | [#17](https://github.com/polite-cat-2001/open_football/issues/17) |
| 06 | [#18](https://github.com/polite-cat-2001/open_football/issues/18) |
| 07 | [#19](https://github.com/polite-cat-2001/open_football/issues/19) |
| 08 | [#20](https://github.com/polite-cat-2001/open_football/issues/20) |
| 09 | [#21](https://github.com/polite-cat-2001/open_football/issues/21) |
| 10 | [#22](https://github.com/polite-cat-2001/open_football/issues/22) |
| 11 | [#23](https://github.com/polite-cat-2001/open_football/issues/23) |
| 12 | [#24](https://github.com/polite-cat-2001/open_football/issues/24) |
| 13 | [#25](https://github.com/polite-cat-2001/open_football/issues/25) |
| 14 | [#26](https://github.com/polite-cat-2001/open_football/issues/26) |
| 15 | [#27](https://github.com/polite-cat-2001/open_football/issues/27) |
| 16 | [#28](https://github.com/polite-cat-2001/open_football/issues/28) |
