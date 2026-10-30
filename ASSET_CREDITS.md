# Asset Credits

| Asset | Source | Author | License | Notes |
|---|---|---|---|---|
| assets/models/footballer.glb | Adobe Mixamo | Adobe | Mixamo (royalty-free) | Модель + idle/run, собрано в игровую форму .glb; сырые FBX не распространяются |

## GameplayFootball animation dataset (assets/gpf/)

- Источник: GameplayFootball, © Bastiaan Konings Schuiling. Данные взяты из форка FootballCPP (github.com/Churikov0112/FootballCPP); первоисточник-форк — github.com/vi3itor/GameplayFootball.
- Файлы: `assets/gpf/animations/**` (293 `.anim` + 3 `.anim.util`), `assets/gpf/player.object`.
- Лицензия: Apache License 2.0 — текст в `assets/gpf/LICENSE-GameplayFootball`.
- Клубные лого/киты из оригинала НЕ копировались (трейдмарки).

## GameplayFootball media (assets/gpf/media/)

- Источник и лицензия — те же, что у датасета анимаций выше (Apache 2.0,
  `assets/gpf/LICENSE-GameplayFootball`).
- Пути **зеркалят оригинал**: `data/media/<путь>` → `assets/gpf/media/<путь>`. Благодаря этому
  якоря `media/...` внутри `.ase` и в комментариях порта остаются честными, а конвейер сборки
  `.glb` читает исходники из репозитория, без второго проекта на диске.
- Что лежит (100 файлов, фаза 7 порта): все 29 `.ase` и все 7 `.object`-обёрток оригинала;
  58 текстур фазы — всё, на что ссылаются `*BITMAP` четырёх `.ase` стадиона/поля/ворот/мяча,
  плюс вход генератора газона (`textures/pitch/seamlessgrass08.png`, `overlay.png`), набор из
  16 адбордов, фолбэк диффуза `textures/orange.jpg`; все 6 `.wav`.
- Чего нет: текстуры меню (`menu/`), гербы команд и соревнований, шрифты (`fonts/`), текстуры
  игроков и причёсок — это фазы 8 и 10. Клубные лого/киты не поедут никогда (трейдмарки).
- Файлы помечены read-only: это исходники оригинала, правится не они, а порт. Атрибут локальный,
  git его не переносит — на свежем клоне выставляется заново (`.import`-сайдкары Godot трогать
  нельзя, движок их перезаписывает):

  ```powershell
  Get-ChildItem -Recurse -File assets/gpf/media |
      Where-Object { $_.Extension -ne '.import' } |
      ForEach-Object { $_.IsReadOnly = $true }
  ```
- Границу набора стережёт `tests/check_gpf_media.gd`.

## Окружение GDExtension-слайса (assets/models/gpf_stadium.glb, gpf_pitch.glb, gpf_goals.glb)

- Источник: GameplayFootball, `data/media/objects/stadiums/test/test.ase`, `pitch.ase` и `data/media/objects/goals/goals.ase`; Apache 2.0 (см. `assets/gpf/LICENSE-GameplayFootball`).
- `gpf_stadium.glb` собран `tools/build_gpf_stadium.py`; текстуры (`greenish_floor`, `concrete`, `floor01wall`, `seat01`, рекламные щиты) запечены в GLB.
- `gpf_pitch.glb` хранит только геометрию четырёх чанков; видимую траву и разметку генерирует процедурный C++-генератор.
- `gpf_goals.glb` — `mat00_white` (белая рамка обоих ворот) и статическая сетка; статическая сетка скрыта, её заменяет динамическая C++ NetSim.

## Модель игрока-заглушки (assets/models/gpf_fullbody.glb)

- Источник: та же GameplayFootball, Apache 2.0 (лицензия там же). Геометрия и веса —
  `data/media/objects/players/models/fullbody.ase`, текстуры кожи, бутс и подошв —
  `data/media/objects/players/textures/{skin.jpg,shoe.jpg,shoe_sole.jpg}`.
- Собирается `tools/build_gpf_fullbody.py` из локальной копии оригинала (в репозиторий
  сам `.ase` не кладётся, только результат сборки).
- Кит (футболка/шорты/гетры) **не из оригинала**: клубные формы `databases/default/images_teams/`
  — трейдмарки, не берём. Текстура кита рисуется скриптом по раскладке, документированной
  в `databases/default/template_kit.png`.

## UI-ассеты Controller Select (assets/ui/)

- Источник: GameplayFootball, `data/media/menu/controller/keyboard_small.png` и
  `controller_small.png`, шрифт `data/media/fonts/alegreya/AlegreyaSansSC-ExtraBold.ttf`;
  Apache 2.0 (см. `assets/gpf/LICENSE-GameplayFootball`).
- Используются экраном `scenes/controller_select.tscn` (порт `SideSelectPage`).
