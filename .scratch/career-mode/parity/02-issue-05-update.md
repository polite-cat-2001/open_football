
## 2026-11-13 — визуальный паритет (сделано)

Сверено с `gf-career-prototype` в браузере на 1920×1080 (Playwright, скриншоты в
`.scratch/ui_shots/proto/`), отчёты — `.scratch/career-mode/parity/squad-centre.md` и
`hub-centre.md`.

Сделано:

- [x] Канва карьеры 1664×680.4 / шапка 38 / тело 596.4 (`UiTokens.CAREER_*`), start/load/new
      переведены; регресс `tests/check_career_canvas.gd`.
- [x] Крошки в подэкранах хаба (`CAREER › SQUAD › SQUAD CENTRE|GAME PLAN`).
- [x] Squad Centre: плашки всех вкладок, STATUS (настроение, `Actual/Planned`, травма),
      STATISTICS (`SEASON TOTAL` + карточки турниров из `competition_stats`),
      ATTRIBUTES (радар вратаря, звёзды `Skill moves`/`Weak foot`, `Contract`, пейджер `‹ R ›`),
      FINANCE (мета-строка, шапка 36, строки 50/53).
- [x] Обзор состава и Details выровнены по прототипу (шапка клуба, поле, StrengthBadge,
      страницы GENERAL/STATS 1/STATS 2/SEASON).
- [x] Centre-плитки: hero (дни 7×112.43/ячейка 106.4, матч 42px, пилюли 30×30), таблица
      (шапка 18, строки 24.4, своя строка `INK` 10% + рейл 2px), турнирный оверлей
      (колонки `# 52 / CLUB 34% / 7 равных / PTS 58`, шапка 28, строки 25, шаг 48).
- [x] «Скоро»-плитки: паддинг 18, заголовок 32, eyebrow, плоский `SOON` справа сверху,
      glyph 68/64 (через новые поля `BentoTile`).
- [x] Тесты: `check_career_canvas`, `check_career_hub_centre`, `check_career_squad_centre`.

Осталось (не входит в этот пакет):

- [ ] `bento_tile.gd`: матчевые плитки PLAY/SIMULATION (`.home-action`) — своя структура
      eyebrow/герб/meta/foot вместо `set_copy`.
- [ ] Штриховка hero начинается с 48% вместо 52% и красится цветом заголовка
      (`shaders/ui_hatch.gdshader`).
- [ ] Подсказки: kbd 12px с рамкой против 16px/600 без рамки (`ui_legend.gd`,
      `SIZE_KBD`, `SIZE_LEGEND`).
- [ ] Внутренние `View.PLAN`/`View.DETAILS` в `career_squad_view.gd` недостижимы из хаба
      (хаб открывает общий `GpfGamePlan`, у которого свой Details) — решить: удалить или
      связать.
- [ ] Анимации цвета 140 мс (hover/disabled) в порте не воспроизводятся.
- [ ] Карточки на поле — майки вместо `PlayerCard` с фото (общий `PauseLineup`).
