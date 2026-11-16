# Трансферы + скаутинг — план интеграции (оркестратор)

Дата: 2026-11-14. Scope: тикеты 06 (действия игрока), 07 (трансферы), 08 (входящие + мировой
рынок), 09 (скаутинг). Источник — `gf-career-prototype`, английские подписи.

## Верхняя навигация (паритет с прототипом)

Прототип: `Центр · Состав · Трансферы · Офис (disabled) · Сезон (disabled)`, скаутинг живёт
внутри «Трансферов» карточкой «Всемирная сеть». Решение из `00-inventory.md` §1:

- `CareerHubModel.TABS` → `CENTRE · SQUAD · TRANSFERS`; вкладка SCOUTING убирается.
- Таб TRANSFERS хостит `CareerTransfersView` (оркестратор), внутри — view stack:
  `hub → filters | results | centre | offer | contract | network | history`.
- Крошки подэкранов: `CAREER › TRANSFERS › <VIEW>`; полоса табов скрывается, как в SQUAD.

## Контракт подэкранов (все создают агенты)

Каждый подэкран — `Control`, строит себя в коде (как `career_squad_view.gd`), сам читает `UiNav`
и держит фокус; хост только показывает/скрывает его с анимацией и передаёт данные.

```
signal closed                      # B/Esc: вернуться в родительский view
signal navigate(view: String, payload: Dictionary)  # hub/filters/results/centre/offer/contract/network/history
signal changed                     # логика изменила Career → хосту нужно сохранить и пересобрать
func open(career: Career, catalog: TeamCatalog, payload := {}) -> void
func close() -> void               # гасит внутренние модалки/OSK
```

Модалки внутри подэкрана (`UiModal`, `UiOnScreenKeyboard`, `CareerAmountModal`) —
`UiNav.push_modal(self)` / `pop_modal(self)`, открытие/закрытие fade+scale 150/240.

## Навигация прототипа (что куда ведёт)

| Действие | Переход |
|---|---|
| TRANSFERS tab | `hub` (фид отчётов скаутов + карточки SEARCH PLAYERS / TRANSFER CENTRE / WORLD NETWORK / HISTORY) |
| SEARCH PLAYERS | `filters` → SEARCH → `results` |
| карточка игрока в results/centre | правая панель; A → actions modal (scout rows, shortlist, transfer/loan offer, discuss move) |
| SEND OFFER | `offer` (transfer/loan; amount modal, buyout) → submit → `centre`, tab SENT |
| ACCEPT COUNTER (sent) / NEGOTIATE | `contract` → sign → pending transfer |
| TRANSFER CENTRE | 4 вкладки: SHORTLIST / SENT / RECEIVED / LISTED; received открывает offers modal (accept/refuse/counter) |
| HISTORY | `history` |
| WORLD NETWORK | `network` (скаутинг: scouts / reports / map / tasks) |
| SQUAD → player → actions | 06: CONTRACT TALKS / SHIRT NUMBER / RELEASE (модальные экраны поверх хаба) |

## Логический контур (после раунда 1/2)

- `CareerSearch` — SQL-поиск по единой БД, profile, фильтры, туман скаутинга.
- `CareerTransfers` — шортлист, статусы, listed, отправленные офферы, история.
- `CareerTransferOffers` / `CareerTransferContracts` — офферы клубам и личный контракт,
  окна, `pending_transfers`, история.
- `CareerIncomingOffers` / `CareerWorldMarket` — входящие и AI-to-AI рынок.
- `CareerScouting` — скауты/задачи/сеть/отчёты.
- `CareerSquadActions` — продление, номер, освобождение (06).
- `CareerAdvance.tick(career, catalog, today) -> {events, changed}` — единая точка тика:
  офферы, контракты, входящие, мировой рынок, скаутинг. Хост зовёт её из
  `CareerSeason.advance_to/play_next_match` и при открытии хаба; события — в уведомления хаба.

## Файловая собственность

Оркестратор: `career_hub.gd/.tscn`, `career_hub_model.gd`, `career_transfers_view.gd`,
`ui_tokens.gd`, `tests/capture_career_shots.gd`, вики, `log.md`, финальная проводка
`CareerAdvance` и табов.

Агенты (только свои новые файлы + свои тесты):
- L1: `career_search.gd`, `career_transfers.gd`, `career_transfer_offers.gd`,
  `career_transfer_contracts.gd`, career-accessors; golden-фикстуры.
- L2: `career_incoming_offers.gd`, `career_world_market.gd`, `career_scouting.gd`,
  `career_squad_actions.gd`, `career_advance.gd`.
- U0: `career_player_card.gd`, `career_player_pane.gd`, `career_amount_modal.gd`,
  `career_transfer_filters.gd`.
- U1: `career_transfer_results.gd`, `career_player_actions.gd`, `career_scout_picker.gd`.
- U2: `career_transfer_offer.gd`, `career_transfer_contract.gd`.
- U3: `career_transfer_centre.gd` (+ карточки/детали офферов).
- U4: `career_transfer_hub.gd`, `career_transfer_history.gd`.
- U5: `career_scouting_view.gd` (+ карточки скаутов/отчётов/карта/задачи).
- U6: `career_negotiation.gd`, `career_shirt_number.gd`, `career_release.gd`.

## Приёмка

- 1920×1080, английские подписи, UiTokens, фокус инверсией, мышь = фокус.
- Все переходы/открытия/закрытия анимированы (150/240).
- Golden-тесты: поиск, оффер/контр-оффер, контракт, окно/исполнение, входящие, мировой
  рынок, скаутинг (эталон — Python-прототип на его `canon.db`).
- Старые сейвы грузятся; сейв восстанавливает все новые поля; повторный advance не дублирует.
- Зелёные: новые тесты + `check_career_hub/squad/advance/creation/save_store/ui/matchday`.
- Вики `карьера.md` + `log.md` обновлены оркестратором.

## Риски

- pytest прототипа сломан (23 стата вместо 22 в ratings JSON) — эталон снимаем через
  `create_app(canon.db)`, не через pytest.
- `assets/faces` gitignored — на чужой машине лица падают в `UiAssets` fallback.
- Общий `career_squad_view.gd` (3000 строк) не трогают агенты; действия игрока подключает
  оркестратор.
