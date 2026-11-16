# Transfer domain — API for UI agents (L1)

Дата: 2026-11-14. Модули: `scripts/career/career_search.gd` (`CareerSearch`),
`career_transfers.gd` (`CareerTransfers`), `career_transfer_offers.gd`
(`CareerTransferOffers`), `career_transfer_contracts.gd` (`CareerTransferContracts`),
`career_rng.gd` (`CareerRng`). Всё — `class_name`, `static`, без autoload'ов и без
чтения `FootballConstants`. Источник поведения — `server/career/{transfers,
transfer_contracts,squad}.py`, `server/canon.py` (`search_players`), клиентские правила —
`web/src/lib/career/{constants,utils,state}/transfers*`.

Golden-фикстуры сняты с прототипа (`canon.db`) скриптом
`gf-career-prototype/tmp/oracle_transfers.py`:
```
cd C:\Users\Egor\Desktop\projects\gf-career-prototype
python tmp\oracle_transfers.py
```
Тесты: `tests/check_career_transfer_{search,offers,contracts}.gd`.

## 0. Общие правила

- Идентификаторы игроков/клубов/лиг/стран — **строки** (`"342229"`, `"131"`, `"ES1"`,
  `"157"`). Внутри БД это transfermarkt id (у лиг — код).
- Даты — ISO `"YYYY-MM-DD"` (у `career.date` и у полей `due`/`created_at`/`execute_on` —
  та же строка; `career.date` в сейве всегда без времени). `contract_expires` — та же форма,
  `""` у свободного агента.
- Деньги — целые в евро (`284700000`), зарплата — целые в евро в неделю.
- Оценки (`overall`, `pot`) — float с одним знаком (`91.0`).
- Команды (`submit`, `sign`, `accept_counter`, `open`, `withdraw`, ...) возвращают
  `{ok: bool, error: String, <payload>}`. Чтения (`search`, `profile`, `view`, `rows`,
  `state`) — просто данные.
- `error` — английская строка близко к прототипу (см. §6). Показывать её можно как есть.
- Сохранение: ничего не пишется в файл внутри модулей — вызвавший хост делает
  `CareerSaveStore.save(career)` (как и остальные career-модули).
- Числа в фикстурах сравнивать мягко: `is_equal_approx` для чисел, точное равенство для
  строк/массивов (в JSON `int`/`float` неразличимы).

## 1. `CareerSearch`

```gdscript
static func filters_default() -> Dictionary
static func filter_reference(catalog: TeamCatalog, league_id := "") -> Dictionary
static func search(catalog: TeamCatalog, career: Career, filters: Dictionary,
        limit := 40, offset := 0) -> Dictionary
static func profile(catalog: TeamCatalog, career: Career, player_id) -> Dictionary
static func contract_expiry(catalog: TeamCatalog, career: Career, player_id) -> String
static func group_of(position: String) -> String
static func is_scouted(career: Career, player_id) -> bool
static func current_club_id(career: Career, player_id, fallback := "") -> String
// ниже — финансовые хелперы, которые UI тоже может звать:
static func release_clause(career: Career, player: Dictionary, player_id := "") -> int
static func weekly_wage(career: Career, player: Dictionary, player_id := "") -> int
static func market_value(career: Career, player: Dictionary, player_id := "") -> int
static func expiry_for(career: Career, player: Dictionary, player_id := "") -> String
static func contract_months(career: Career, player: Dictionary, player_id := "") -> int
static func add_days(iso_date: String, days: int) -> String
static func date_diff_days(iso_date: String, other: String) -> int
static func round_money(value: float) -> int
static func python_round(value: float) -> int
```

### 1.1 Фильтры (`filters_default()`)

```gdscript
{
  "name": "", "group": "", "position": "",
  "age_min": null, "age_max": null,
  "citizenship": "", "country": "", "league": "", "club": "",
  "foot": "", "height_min": null, "height_max": null,
  "status": "", "sort": "name", "direction": "asc",
}
```

| ключ | значения | смысл |
|---|---|---|
| `name` | строка | подстрока имени, регистр не важен |
| `group` | `""`, `GK`, `DEF`, `MID`, `FWD` | группа ролей |
| `position` | `""` или `position` из БД (`"Centre-Back"`, `"Left Winger"`, ...) | точная позиция или альтернативная (`position_other`) |
| `age_min`/`age_max` | `null`/`0` = нет фильтра, иначе 0..99 | возраст на `career.date` (формула `julianday/365.2425`, как в SQL прототипа) |
| `citizenship` | `""` или гражданство (`"France"`) | членство в JSON-списке `citizenship` |
| `country` | `""` или id страны клуба | |
| `league` | `""` или id лиги клуба | |
| `club` | `""`/`0` или id клуба | |
| `foot` | `""`, `right`, `left`, `both` | |
| `height_min`/`height_max` | `null`/`0` = нет, иначе см | |
| `status` | `""`, `free`, `transfer`, `loan`, `blocked` | `free` = без клуба; `transfer`/`loan`/`blocked` = свои игроки с этим статусом |
| `sort` | `name`, `age`, `overall`, `position`, `value`, `wage` | `position` — порядок ролей GK→CF, `value` — `market_value`, `wage` — `market_value × возрастной коэффициент` |
| `direction` | `asc`, `desc` | сортировка; `null`-значения всегда в конце, тай-брейк — имя, потом id |

Планка фильтров `CareerTransferFilters` использует `country_id`/`league_id`/`club_id`
и `0` вместо `null`. Поиск принимает **оба** варианта имён (`country` ↔ `country_id`,
`league` ↔ `league_id`, `club` ↔ `club_id`); `""`, `null` и `0` для диапазонов = «нет фильтра».

### 1.2 `search(...) -> Dictionary`

```gdscript
{
  "items": Array,        // до limit элементов
  "total": int,          // всего совпадений (121927 без фильтров)
  "has_more": bool,      // offset + items.size() < total
  "limit": int, "offset": int,
}
```
По умолчанию страница — 40 (`PAGE_SIZE`). Пара `total` + `has_more` даёт пагинацию.

### 1.3 Item (ровно эти ключи, пункт за пунктом)

```gdscript
{
  "player_id": String,        // "342229"
  "name": String,             // "Kylian Mbappé"
  "age": int,                 // на career.date (календарный возраст)
  "position": String,         // "Centre-Forward"
  "position_group": String,   // "GK" | "DEF" | "MID" | "FWD"
  "club_id": String,          // "" у свободного агента; учитывает club_deltas
  "club_name": String, "club_logo": String,   // logo: путь для UiAssets.load_texture
  "league_id": String, "league_name": String,
  "country_id": String, "country_name": String,
  "citizenship": Array,       // ["France", "Cameroon"]
  "status": String,           // см. §1.5
  "release_clause": int,      // всегда видно
  "contract_expires": String, // всегда видно; "" у свободного агента
  "scouted": bool,
  "overall": float, "pot": float, "market_value": int, "weekly_wage": int,
  "foot": String, "height": int,               // height всегда видно (см)
  "stats": Dictionary,        // 22 стата, пусто без разведки
  "photo": int,               // tm_id для UiAssets.player_face
  "shortlisted": bool,
  "listed_for_transfer": bool // status == "transfer" или "loan"
}
```

Туман: если `scouted == false`, ключи остаются, но значения скрыты —
`overall 0.0`, `pot 0.0`, `market_value 0`, `weekly_wage 0`, `foot ""`, `stats {}`.
`scouted` = игрок в своём составе **или** есть в `scout_reports`/`scout_found`
(`CareerSearch.is_scouted`). `release_clause`, `contract_expires`, `height`, `age`,
`citizenship`, клуб/лига/страна видны всегда.

### 1.4 `profile(...)`

Всё из item плюс:

```gdscript
{
  "first_name": String, "last_name": String, "birth_date": "YYYY-MM-DD",
  "role": String,             // "CF", "GK", ...
  "weight": int,              // кг
  "weak_foot": int, "skill_moves": int,   // 0 без разведки
  "shirt_number": int,        // -1 если нет
  "stats": Dictionary,        // 22 стата, пусто без разведки
  "height": int,
}
```
Пустой словарь + `CareerSearch.last_error == "player not found"` для неизвестного id.
Контрактный блок (`can_discuss`, `contract_defaults`, `transfer_contract`,
`latest_offer`) в profile **не** входит — его отдаёт
`CareerTransferContracts.state(career, catalog, player_id)` (§4).

### 1.5 Статусы, которые вы увидите

- `"free"` — нет клуба (свободный агент; сборная не считается клубом).
- `"contracted"` — есть клуб, игрок не выставлен (это значение прототипа, не путать с `""`).
- `"transfer"`, `"loan"`, `"blocked"` — свои игроки, статус из
  `CareerTransfers.set_status`.
- `""` — только если у игрока есть клуб и в сейве нет записи, но `_item` всегда
  подставляет `"contracted"`/`"free"`, поэтому в item пусто не встречается.

### 1.6 `filter_reference(catalog, league_id := "")`

```gdscript
{
  "countries": [{"id": "157", "name": "Spain", "flag": "Spain", "tm_id": "157"}],
  "leagues":   [{"id": "ES1", "name": "LaLiga", "country_id": "157", "tier": 1,
                 "tier_rank": 1, "logo": "images_competitions/ES1.png"}],
  "clubs":     [{"id": "131", "name": "FC Barcelona", "logo": "/raster/teams_emblems/131.png"}],
}
```
`clubs` пуст, пока не передан `league_id` (в прототипе клуб выбирается после лиги).
Лига `National Teams` (синтетическая) в список не попадает.
Страны/лиги отсортированы как в прототипе (имя страны, затем тир и имя лиги).
Флаг: `flag` = имя страны (ключ для `UiAssets`-флагов по стране), `tm_id` — id страны.

## 2. `CareerTransfers`

```gdscript
static func toggle_shortlist(career, catalog, player_id) -> {ok, error, shortlisted: bool}
static func set_status(career, catalog, player_id, status) -> {ok, error, status: String}
static func shortlist(career, catalog) -> Array        // == shortlist_rows
static func shortlist_rows(career, catalog) -> Array   // profile-строки
static func listed(career, catalog) -> Array           // == listed_rows
static func listed_rows(career, catalog) -> Array      // profile-строки со status
static func sent_offer_rows(career, catalog) -> Array
static func history_rows(career, catalog) -> Array
static func offer_status_label(status) -> String
static func kind_label(kind) -> String
static func contract_status_label(status) -> String
```

- `toggle_shortlist`: добавляет/убирает, пишет журнал `shortlist.added`/`.removed`.
- `set_status` (**как клиент прототипа**): `"transfer"`, `"loan"`, `"blocked"` ставят статус,
  **повтор того же статуса снимает его**; `""`, `"none"`, `"clear"` — снять. Только свои
  игроки (`"player is not in this squad"`), неизвестный статус — `"unknown transfer status"`.
- `listed_rows` — свои игроки со статусом `transfer`/`loan`/`blocked` (в прототипе
  `blocked` в центре не показывался; здесь он в списке, `status` различает).

`sent_offer_rows` — новейшие сверху, каждая строка:
```gdscript
{
  "offer_id": String,
  "player": Dictionary,      // item из §1.3 (плюс profile-поля)
  "offer": Dictionary,       // view из §3.4
  "kind_label": "Transfer" | "Loan",
  "status_label": "Pending" | "Counter offer" | "Accepted" | "Refused" | "Withdrawn",
  "contract_status_label": "In talks" | "Counter offer" | "Agreed" | "Signed" | "",
  "fee": int,                // == offer.amount (для аренды — fee аренды)
  "due": String,
  "can_accept_counter": bool, "can_withdraw": bool,
  "can_reoffer": bool, "can_negotiate": bool,
}
```

`history_rows` — новейшие сверху (`date` desc, затем id desc):
```gdscript
{
  "id": String,               // offer_id или player_id
  "player_id": String, "player_name": String, "photo": int, "role": String,
  "overall": float,
  "from_club_id": String|null, "from_club_name": String, "from_club_logo": String,
  "to_club_id": String|null,   "to_club_name": String,   "to_club_logo": String,
  "fee": int,
  "kind": "transfer"|"loan", "kind_label": "Transfer"|"Loan",
  "status": "completed"|"signed",   // signed = ждёт окна
  "date": String,
}
```

## 3. `CareerTransferOffers`

```gdscript
static func proposal(career, catalog, player_id, kind := "transfer") -> Dictionary
static func submit(career, catalog, player_id, kind := "transfer",
        amount = null, loan_fee = null, wage_share = null, buyout := false)
        -> {ok, error, offer: Dictionary}
static func accept_counter(career, catalog, offer_id) -> {ok, error, offer}
static func withdraw(career, catalog, offer_id) -> {ok, error, offer}
static func process_due(career, catalog, today := "") -> Array    // события
static func view(career, offer: Dictionary) -> Dictionary         // §3.4
static func find_offer(career, offer_id) -> Dictionary            // {} если нет
static func active_for(career, player_id) -> Dictionary           // view или {}
static func latest(career, player_id) -> Dictionary               // §3.5
static func detail(career, catalog, offer_id) -> {ok, error, offer, player}
```

`amount`/`loan_fee`/`wage_share`: `null` = не задано (как `None` в Python); для
`buyout = true` сумма игнорируется и берётся `release_clause`.

### 3.1 `proposal(...)` — стартовые числа экрана оффера

```gdscript
{
  "fee": int,               // release_clause, иначе market_value, иначе 1_000_000
  "loan_fee": int,          // max(10_000, round(market_value*0.05 / 10_000)*10_000)
  "wage_share": 50,
  "buyout": false,
  "buyout_allowed": bool,   // есть клуб и release_clause > 0
  "release_clause": int, "market_value": int, "balance": int,
  "can_submit": bool, "reason": String,   // "" если можно
  "kind": "transfer"|"loan", "player_id": String,
}
```
`can_submit=false` + `reason`: `"you cannot make an offer for your own player"` или
`"offer amount is above the club balance"` (`"loan fee is above the club balance"` для аренды).

### 3.2 `submit(...)` — что проверяет

`"unknown offer kind"`, `"you cannot make an offer for your own player"`,
`"offer amount cannot be negative"`, `"offer amount is above the club balance"`,
`"release clause is not available for this player"` (buyout без клуба/клаусы),
`"buyout is only available for a transfer"`, `"loan fee cannot be negative"`,
`"loan fee is above the club balance"`, `"wage share must be between 0 and 100"`,
`"there is already an active offer for this player"` (pending или другой тип),
`"you can make another offer after YYYY-MM-DD"` (после отказа),
`"the club has already accepted an offer for this player"`.
Успешный submit заменяет прежний оффер по этому игроку (один активный оффер на игрока).

### 3.3 `process_due(career, catalog, today := "")` — ответ клуба

Зовётся при тике (`CareerAdvance`), `today` = `career.date` (пустая строка = `career.date`).
`responded_at` всегда `career.date`. Ждёт `due` = `created_at` + 2..4 дня (RNG).
Правила (прототип): buyout → принято; `fee >= demand` → принято; `fee*100 >= demand*65`
→ контр-оффер (`counter.amount = demand`); иначе отказ; больше двух контр-офферов → отказ.
Для аренды: `fee >= demand.fee and share >= demand.wage_share` → принято;
`fee*100 >= demand.fee*50 or share+20 >= demand.wage_share` → контр (fee = max, share = max);
иначе отказ (после 2 контр-офферов — отказ).
Отказ ставит `retry_after = responded_at + 7 дней`.
События (для уведомлений хаба):
```gdscript
{"type": "transfer.offer.accepted" | ".refused" | ".counter",
 "offer_id": String, "player_id": String, "player_name": String,
 "kind": "transfer"|"loan", "status": String, "message": String,
 "counter": Dictionary}   // {} если нет
```

### 3.4 Offer view (`view`, `submit().offer`, `sent_offer_rows[].offer`)

```gdscript
{
  "offer_id": String, "player_id": String,
  "kind": "transfer"|"loan",
  "amount": int, "loan_fee": int, "wage_share": int, "buyout": bool,
  "status": String,        // pending | counter | accepted | refused | withdrawn
  "due": String|null, "created_at": String|null, "responded_at": String|null,
  "counter_offers": int,
  "counter": Dictionary|null,  // {"amount":int} / {"amount","loan_fee","wage_share"} для аренды
  "retry_after": String|null,
  "message": String,       // английская фраза состояния (см. §6)
  "can_offer_again": bool, // counter/withdrawn всегда; refused — после retry_after
  "can_accept_counter": bool,
  "can_withdraw": bool,    // pending/counter, либо accepted и не signed
  "affordable": bool,
  "signed": bool, "signed_at": String|null, "execute_on": String|null,
  "contract_status": String|null,   // pending|counter|accepted|signed
  "can_negotiate": bool,   // accepted и не signed → экран контракта
}
```

### 3.5 `latest(career, player_id)`

`{"offer_id", "kind", "status", "signed", "execute_on", "can_negotiate"}` или `{}` —
последний оффер любого статуса (для кнопки «Negotiate / Continue talks» на карточке).

### 3.6 `accept_counter` / `withdraw`

`accept_counter` фиксирует только **сумму сделки** (`offer.amount`, для аренды ещё
`loan_fee`/`wage_share`) и журналит `transfer.offer.accepted`; личный контракт
открывается отдельно — `CareerTransferContracts.open(...)` (как в прототипе; автостарт
переговоров заблокировал бы ввод своих условий на 2–4 дня).
`withdraw` снимает оффер из `career.transfer_offers` (в списке он больше не появится),
чистит переговоры по игроку и журналит `transfer.offer.withdrawn`; ошибки —
`"offer not found"`, `"this offer cannot be withdrawn"`, `"there is no counter-offer to accept"`,
`"not enough money to accept these terms"`.

## 4. `CareerTransferContracts`

```gdscript
static func state(career, catalog, key) -> Dictionary     // экран контракта, §4.1
static func state_for(career, player_id) -> Dictionary    // сырое состояние или {}
static func can_discuss(catalog, career, player) -> bool
static func demand(catalog, career, player) -> Dictionary // требования игрока
static func contract_defaults(catalog, career, player) -> Dictionary
static func projected_role(player, squad_players) -> String
static func open(career, catalog, player_id, terms, offer_id := "") -> {ok, error, state}
static func submit(career, catalog, player_id, terms, offer_id := "") // == open
static func accept_counter(career, catalog, player_id) -> {ok, error, state}
static func sign(career, catalog, player_id) -> {ok, error, item}
static func process_due(career, catalog, today := "") -> Array
static func pending(career, catalog := null) -> Array
static func execute_pending(career, catalog, today := "") -> Array
static func window_open(day) -> bool
static func next_window(day) -> String
static func execution_date(day) -> String
static func transfer_contract_view(career, player_id) -> Dictionary
```

`key` в `state` — **player_id** (ключ прототипа) либо **offer_id** (то, что есть у экрана
оффера): оффер резолвится в игрока. `terms`:
`{"years": 1..5, "weekly_wage": 1000..2000000, "squad_role": "key"|"first"|"rotation"|
"squad"|"prospect", "release_clause": >= 0}`.

### 4.1 `state(...)`

```gdscript
{
  "error": "" | "player not found",
  "player_id": String, "player_name": String, "overall": float,
  "offer_id": String|null,          // оффер, если переговоры идут по трансферу
  "kind": "transfer"|"loan"|"free", // free = свободный агент без оффера
  "fee": int, "loan_fee": int, "wage_share": int,
  "status": "" | "pending" | "counter" | "accepted" | "refused",
  "offer": Dictionary|null,         // текущие предложенные условия
  "counter": Dictionary|null,       // контр-условия игрока
  "agreed": Dictionary|null,        // согласованные условия (status == accepted)
  "terms": Dictionary|null,         // agreed, иначе offer (что показывать)
  "due": String|null, "counter_offers": int, "message": String,
  "demand": Dictionary,             // требования игрока (wage/years/role/clause)
  "affordable": bool,
  "balance_after": int|null,        // balance − fee
  "can_sign": bool,                 // accepted и денег хватает
  "can_accept_counter": bool,       // status == counter
  "can_submit": bool,               // can_discuss и нет pending/accepted
  "can_discuss": bool,              // свободный агент или контракт истекает ≤ 6 мес
  "contract_defaults": Dictionary,  // стартовые условия экрана
  "latest_offer": Dictionary,       // §3.5
  "offer_accepted": bool,           // у оффера status == accepted
}
```

`contract_defaults` / `demand` = `{years, weekly_wage, squad_role, release_clause}`.
`can_discuss == false` → переговоры открываются только через принятый оффер.

### 4.2 `open` / `submit` / `accept_counter`

`open` = `start_transfer_contract` прототипа: валидирует свои/ожидающие/допустимость
переговоров, требует принятый оффер (если передан `offer_id`), считает требования и
срок ожидания (2–4 дня, `due = career.date + delay`), ставит `status = "pending"`.
Ошибки: `"player not found"`, `"offer not found"`, `"the player is already in your squad"`,
`"this transfer is already agreed and waiting for the window"`,
`"contract talks are only available for free agents or expiring contracts"`,
`"the club has not accepted an offer for this player"`,
`"this transfer has already been completed"`,
`"the contract is already agreed, confirm it first"`,
`"the player is still thinking about the current offer"`,
`"contract length must be between 1 and 5 years"`, `"weekly wage is out of range"`,
`"unknown squad role"`, `"release clause cannot be negative"`.
`state().can_submit` и `state().can_sign` — то, что нужно для блокировки кнопок.

### 4.3 `process_due` (личные переговоры)

Сравнивает `offer` с `demand`: зарплата/срок/роль/клауса (границы клаусы —
`1.2×value .. 2.0×value`). Нет расхождений → `accepted` (`agreed` = условия);
два контр-оффера уже было → `refused`; иначе `counter` (условия = максимум из
предложенного и требуемого) и сообщение о причине. `state.message` — английские фразы
(`"The player asks for a higher wage."` и т. п.). События:
```gdscript
{"type": "transfer.contract.accepted"|".counter"|".refused",
 "player_id": String, "player_name": String, "status": String,
 "message": String, "counter": Dictionary|null}
```

### 4.4 `sign(...)` и окна

`sign` требует `status == "accepted"`, проверяет баланс, списывает `fee`,
считает `execute_on = execution_date(career.date)` (внутри окна — сегодня; иначе
`next_window`: до июня → 1 июля этого года, иначе 1 января следующего).
В окне: игрок сразу в составе (`player_ids`, `player_contracts`, `player_values`,
`player_ages`, номер, `club_deltas`), оффер удаляется, история `status = "completed"`.
Вне окна: запись в `career.pending_transfers` (`execute_on`, `terms`, `fee`, ...),
оффер помечается `signed = true`, история `status = "signed"`.
Возвращает `{ok, error, item}`; `item`:
```gdscript
{"player_id", "from_club_id", "offer_id", "kind", "fee", "loan_fee", "wage_share",
 "terms", "market_value", "age", "agreed_at", "execute_on", "executed_at"?}
```
Ошибки: `"the contract is not agreed yet"`, `"player not found"`,
`"not enough money to complete this transfer"`.

`pending(career, catalog)` — `pending_transfers` (+ `player_name`, `photo`,
`from_club_name`, `to_club_name` при переданном каталоге).
`execute_pending(career, catalog, today)` — исполняет записи с `execute_on <= today`,
**только если окно открыто**; возвращает события
`{"type": "transfer.completed", "player_id", "player_name", "date"}`.
Хост зовёт `process_due` (офферы), `process_due` (контракты) и `execute_pending`
из `CareerAdvance.tick`.

## 5. Сейв (`Career`)

Новые ключи (ленивые: отсутствие ключа = «пусто», старые сейвы грузятся без миграции):

| ключ | тип | геттер/сеттер |
|---|---|---|
| `transfer_offers` | Array от view-подобных словарей | `career.transfer_offers` |
| `transfer_contracts` | Dictionary player_id → состояние | `career.transfer_contracts` |
| `pending_transfers` | Array item'ов §4.4 | `career.pending_transfers` |
| `transfer_history` | Array записей истории | `career.transfer_history` |
| `shortlist` | Array id | `career.shortlist` |
| `pending_departures` | Array (L2) | `career.pending_departures` |
| `incoming_offers` | Array (L2) | `career.incoming_offers` |
| `incoming_market_date` | String | `career.incoming_market_date` |
| `world_market_date` | String | `career.world_market_date` |
| `world_transfers` | Array (L2) | `career.world_transfers` |
| `club_deltas` | Dictionary club_id → {in, out} | `career.club_deltas` |

`Career.from_save` нормализует типы (JSON делает из int float), поэтому сейв
round-trip стабилен. `club_deltas` участвуют в `club_id` игрока (`current_club_id`):
если игрок в `in` клуба — его клуб этот; свои игроки всегда в `career.club_id`.

## 6. Английские строки, которые отдают модули

Сообщения состояний (`offer.message`, `state.message`):
`"The club is considering the offer."`, `"The club accepted the offer."`,
`"The club rejected the offer."`, `"The club proposes new terms."`,
`"Negotiations have ended."`, `"The player is thinking about the contract."`,
`"The player agrees. Confirm the signing."`, `"The player walked away from the talks."`,
`"The player asks for a higher wage."`, `"The player insists on a longer contract."`,
`"The player is not ready to lose his squad role."`, `"The player wants a higher release clause."`,
`"The release clause is too high; the player asks to lower it."`

Лейблы (`CareerTransfers`): статусы оффера `Pending/Counter offer/Accepted/Refused/Withdrawn`,
типы `Transfer/Loan`, контракт `In talks/Counter offer/Agreed/Signed`.
Тексты кнопок/заголовков UI берёт на себя — модули дают только `*_label` и `error`.

## 7. Что зовёт каждый экран

| Экран / view | Вызовы |
|---|---|
| `hub` | `CareerTransfers.sent_offer_rows` (счётчики), `pending(career, catalog)`, `history_rows(…).slice(0,3)` |
| `filters` | `CareerSearch.filters_default()`, `CareerSearch.filter_reference(catalog, league_id)` |
| `results` | `CareerSearch.search(catalog, career, filters, 40, offset)`; при выборе — `CareerSearch.profile` + `CareerTransferContracts.state(career, catalog, player_id)` |
| actions modal | `CareerTransfers.toggle_shortlist`, `CareerTransferOffers.proposal(player, kind)` → `offer` view |
| `offer` | `CareerTransferOffers.proposal`, `submit`, `CareerTransferContracts.state(...)` после принятия |
| `contract` | `CareerTransferContracts.state(career, catalog, player_id | offer_id)`, `open`, `accept_counter`, `sign` |
| `centre` (SHORTLIST / SENT / RECEIVED / LISTED) | `shortlist_rows`, `sent_offer_rows`, `listed_rows`, `received_*` (L2) |
| `history` | `CareerTransfers.history_rows(career, catalog)` |
| пауза/хаб после тика | `CareerTransferOffers.process_due`, `CareerTransferContracts.process_due`, `execute_pending` → события |

## 8. Расхождения с прототипом (осознанные)
1. **`CareerSearch.reference` → `filter_reference`**: `reference()` — нативный метод
   `RefCounted`, переопределить нельзя; переименовано, добавлен `league_id` для клубов.
2. **`contract_expiry(catalog, career, player_id)`** (нужен каталог, чтобы прочитать клуб
   игрока) — в задаче было `(career, player_id)`; без БД поле клуба недоступно.
3. **`accept_counter` не открывает переговоры автоматически** — в прототипе это отдельный
   шаг, а автостарт заблокировал бы ввод условий («the player is still thinking…»).
4. **`set_status` переключает** повторный статус (правило клиента прототипа
   `applyTransferStatus`), сервер прототипа просто перезаписывал.
5. **`status` может быть `"contracted"`** — значение прототипа для «есть клуб, не выставлен».
6. **`execute_pending` возвращает события** (в прототипе — список id), чтобы хаб показывал
   уведомления без второго запроса.
7. **Номер игрока пишется при подписании** (`CareerSquad.ensure_shirt_numbers`), прототип
   выдавал его при следующем рендере состава — результат тот же.
8. **Возраст для финансов** берётся из колонки `age` единой БД (прототип считал от
   «сегодня»); на выбранных игроках значения совпадают, но это единственное место, где
   «сегодня» не воспроизводится.
9. **RNG**: `CareerRng` — побайтовый CPython `random.Random` (MT19937 + sha512-сид),
   поэтому суммы/сроки/исходы совпадают с прототипом. `CareerSquad` теперь тоже использует
   его для контрактов (зарплаты/клаусы/сроки создаются как в прототипе).
10. **Поиск** делает один проход по 121k игроков при первом запросе (~7 с, кэш в каталоге),
    дальше ~1 с; страница собирается из кэша. `total` считается по всем совпадениям.

# Scouting domain — API for UI agents (ticket 09)

Дата: 2026-11-14. Модуль: `scripts/career/career_scouting.gd` (`class_name CareerScouting`,
все функции `static`, без autoload'ов). Источник поведения — `server/career/scouting.py`
(логика) и `server/app.py` (`scouting_snapshot`, действия `scout_*`); клиентские правила
прочитаны у `web/src/lib/career/state/scouting.svelte.js` и `scouting/*.svelte`, но UI здесь
нет. Спека — `.scratch/career-mode/issues/09-skauting.md`.

Golden-фикстура снята с прототипа (`canon.db`) скриптом `gf-career-prototype/tmp/oracle_scouting.py`:
```
cd C:\Users\Egor\Desktop\projects\gf-career-prototype
python tmp\oracle_scouting.py
```
(скрипт лежит в неотслеживаемом `tmp/`, как и `oracle_transfers.py` — коммитить не нужно).
Тест: `tests/check_career_scouting.gd` (676 проверок), фикстура
`tests/fixtures/career_scouting_golden.json`.

## 9. `CareerScouting`

```gdscript
// пул и найм
static func scout_pool(career: Career) -> Array          // 12 скаутов из seed
static func ensure_scouts(career: Career) -> void        // ленивые 2 стартовых
static func scout_candidates(career: Career) -> Array    // до 5 свободных (view)
static func hire(career, scout_id) -> {ok, error, scout}
static func dismiss(career, scout_id) -> {ok, error}
static func recall(career, scout_id) -> {ok, error}
static func assignable_scouts(career) -> Array           // скауты без задачи И без отчёта

// отчёты о игроке
static func assign(career, catalog: TeamCatalog, scout_id, player_id)
        -> {ok, error, report}
static func report_days(experience: int) -> int          // 6 − опыт, 1..5
static func report_for(career, player_id) -> Dictionary  // строка для экрана трансферов

// сети регионов
static func default_criteria() -> Dictionary
static func normalize_criteria(raw) -> Dictionary
static func network(career, catalog, scout_id, region_id, country_id, criteria := {})
        -> {ok, error, task}
static func set_task(career, scout_id, criteria) -> {ok, error, task}

// фид
static func ack(career) -> {ok, error}
static func remove(career, player_id) -> {ok, error}
static func forget_player(career, player_id) -> void     // хук подписания
static func forget_own_players(career) -> void
static func counts(career) -> Dictionary

// тик и снапшот
static func process_days(career, catalog, from_date: String, to_date: String) -> Array
static func snapshot(career, catalog) -> Dictionary
static func regions(catalog) -> Array
```

### 9.1 `snapshot(career, catalog)`

```gdscript
{
  "counts": {"new": int, "updates": int, "total": int, "found": int, "scouts": int},
  "scouts": [ScoutView],            // все нанятые, в порядке найма
  "candidates": [ScoutCandidate],   // до 5 свободных, порядок пула
  "tasks": [TaskView],              // плоский список задач (по одной на скаута)
  "reports": [Entry],               // завершённые отчёты, date desc + имя desc
  "recommendations": [Entry],       // найденные сетью, date desc + имя desc
  "feed": [Entry],                  // reports + recommendations, date desc + имя asc
  "found": [player_id],             // id всех найденных (порядок находок)
  "networks": [Network],
  "regions": [Region],
  "max_scouts": 6,
  "age_min": 16, "age_max": 35, "contract_min": 0, "contract_max": 5,
}
```

`ScoutView`:
```gdscript
{
  "id": "scout-1", "name": "Brian Smith", "nationality": "Canada",
  "nationality_id": "80",     // "" если страны нет в каталоге
  "flag": "Canada",           // ключ флага для UiAssets (= имя страны)
  "experience": int, "judgement": int, "price": int,
  "hired_at": "YYYY-MM-DD", "hired": true,
  "free": bool,               // ни задачи, ни отчёта
  "busy": bool, "current_task": "" | "network" | "report",
  "task": TaskView | null,
  "report": ReportView | null,
}
```

`ScoutCandidate` = `id, name, nationality, nationality_id, flag, experience, judgement, price,
affordable` (без `task`/`report`; `affordable` = `balance >= price`).

`TaskView`:
```gdscript
{
  "kind": "network",
  "region_id": "south-europe", "region_name": "Southern Europe",
  "country_id": "157", "country_name": "Spain",
  "criteria": {"role": ""|"GK"|"DEF"|"MID"|"FWD",
               "age_min": int|null, "age_max": int|null,
               "contract_min": int|null, "contract_max": int|null},
  "started_at": "YYYY-MM-DD", "days_worked": int, "found_count": int,
  // в "tasks" дополнительно:
  "scout_id": "scout-2", "scout_name": "Daniel Perez",
}
```

`ReportView` (отчёт в работе, внутри `scouts[].report`):
```gdscript
{
  "player_id": "342229", "player_name": "Kylian Mbappé",
  "player_photo": int,        // tm id для UiAssets.player_face (у прототипа — путь)
  "started_at": String, "due_at": String,
  "days_total": int, "days_left": int, "days_worked": int,
  "progress": float,          // 0..1, 3 знака
}
```

`Entry` (завершённый отчёт/рекомендация, фид и списки):
```gdscript
{
  "player": Dictionary,       // CareerSearch.profile: карточка игрока целиком
  "kind": "report" | "recommendation",
  "scout_id": String, "scout_name": String,
  "date": "YYYY-MM-DD",       // completed_at / found_at
  "acknowledged": bool,
  "duration": int,            // дни изучения (report), 0 у рекомендации
}
```
`player` — ровно та форма, что отдаёт `CareerSearch.profile`/`search` (ключ **`player_id`**,
поля тумана уже раскрыты, потому что игрок в `scout_reports`/`scout_found`), поэтому карточки
`CareerPlayerCard`/`CareerPlayerPane` рендерят её без адаптера.

`Network` = `{region_id, region_name, country_id, country_name, created_at, scout_id}`
(одна запись на страну; повторный запуск сети в ту же страну её не дублирует).

`Region`:
```gdscript
{"id": "south-europe", "name": "Southern Europe", "x": 53, "y": 42,
 "countries": [{"id": "157", "name": "Spain", "flag": "Spain"}]}
```
`x`/`y` — проценты карты (как в прототипе). Страны без лиг в каталоге порта в регион не
попадают (в прототипе они были — см. §12.2).

### 9.2 Действия, цены и ошибки

- `hire`: максимум 6 слотов; цена из пула списывается с `career.balance` (если баланс `null` —
  бесплатно, как в прототипе); журнал `scouting.hired`. Ошибки: `"all scout slots are occupied"`,
  `"scout is not available"`, `"scout is already hired"`, `"not enough money to hire this scout"`.
- `dismiss`: убирает скаута и его задачу/отчёт, кандидат возвращается в пул (деньги не
  возвращаются), журнал `scouting.dismissed`. Ошибка: `"scout not found"`.
- `recall`: снимает и сеть, и отчёт скаута, найденные игроки остаются; журнал
  `scouting.recalled`. Ошибки: `"scout not found"`, `"this scout has no active task"`.
- `assign`: `"you cannot scout your own player"`, `"player not found"`, `"scout not found"`,
  `"this scout is already studying a player"`, `"this player is already being studied"`,
  `"this player has already been studied"`; журнал `scouting.report_started`. Отчёт и сеть у
  одного скаута сосуществуют (как в прототипе).
- `network`: `"scout not found"`, `"region not found"`, `"country is not in this region"`;
  журнал `scouting.network_started`. Одна сеть на скаута (новая заменяет прежнюю).
- `set_task`: `"this scout has no network task"`; журнал `scouting.task_updated`. Критерии
  нормализуются (`role` в верхний регистр и только из списка, границы зажимаются и меняются
  местами при min > max).
- `remove`: `"report is still in progress"`, `"player is not in any report"`; убирает игрока из
  `scout_reports`/`scout_found` и из `found` всех задач (туман возвращается), журнал
  `scouting.removed`.
- `ack`: помечает прочитанными все отчёты и рекомендации (журнала нет, как в прототипе).
- Ошибки отдаются в `{ok: false, error: "<строка>"}`, успех — `{ok: true, error: ""}` плюс
  payload (`scout` у `hire`, `report` у `assign`, `task` у `network`/`set_task`).

### 9.3 `process_days(career, catalog, from_date, to_date)`

Тик, который зовёт `CareerAdvance.tick` (оркестратор). `to_date` — «сегодня» (`career.date`
после перевода часов), `from_date` — прежняя дата; при `to_date <= from_date` тик ничего не
делает. Внутри:
1. отчёты с `due_at <= to_date` завершаются (`completed_at = due_at`, скаут освобождается);
2. каждая сеть докручивает **каждый день** от `last_tick + 1` до `to_date`: цель на день —
   `min(20, найдено + rate)`, `rate = 1 + judgement / 2`; кандидаты страны фильтруются
   возрастом/ролью/контрактом, перемешиваются CPython-совместимым `random.Random("<seed>:found:
   <scout>:<day>")` и добавляются по одному; занятые/свои/уже найденные пропускаются;
3. `last_tick` = `to_date`.

Идемпотентность: повторный тик на ту же дату не находит никого и не завершает отчётов дважды
(проверка `last_tick` + удаление assignment). Возвращает события для уведомлений хаба:
```gdscript
{"type": "scouting.report.ready" | "scouting.found",
 "message": "Brian Smith completed the scouting report on Kylian Mbappé.",
 "player_id": String, "player_name": String, "scout_id": String}
```
Детерминизм: пул скаутов и находки считаются от `career.seed`, поэтому одинаковый сейв и
одинаковый диапазон дат дают одинаковые находки.

### 9.4 Сейв

Ключи — ровно как в прототипе (`Career.to_save`/`from_save` их не трогают, версия остаётся 1):

| ключ | тип |
|---|---|
| `scouts` | Array скаутов (`hired_at` внутри) |
| `scout_assignments` | Dictionary scout_id → `{player_id, scout_id, started_at, due_at, days_total, acknowledged}` |
| `scout_tasks` | Dictionary scout_id → задача (`kind, region_id, region_name, country_id, country_name, criteria, started_at, last_tick, found[]`) |
| `scout_reports` | Dictionary player_id → `{scout_id, completed_at, acknowledged}` |
| `scout_found` | Dictionary player_id → `{scout_id, found_at, acknowledged}` |
| `scout_networks` | Array записей Network |

Старый сейв без этих ключей грузится без миграции: первый `snapshot`/`counts`/`process_days`
создаёт двух стартовых скаутов (`hired_at` = `career.date`). Доступ к ключам — через
`career.data` внутри модуля (отдельных accessor'ов в `career.gd` нет намеренно, чтобы не
плодить геттеры, которые никто не читает).

### 9.5 Что зовёт каждый экран

| Экран / view | Вызовы |
|---|---|
| панель «Всемирная сеть» (hub, счётчик «new») | `CareerScouting.snapshot(career, catalog)` → `counts` |
| сетка скаутов | `snapshot().scouts`, `scout_candidates` (он же `candidates`) |
| найм | `hire(career, id)` |
| карточка скаута → действия | `recall`, `dismiss`, `assignable_scouts` |
| отчёты/фид | `snapshot().feed` / `reports` / `recommendations`, `ack`, `remove`, `report_for` |
| карта и назначение сети | `snapshot().regions` → `network(career, catalog, scout, region, country)`, `snapshot().networks` |
| редактор задачи | `default_criteria()` / `normalize_criteria`, `set_task` |
| карточка игрока (трансферы) | `report_for(career, player_id)` для строки «scouting» |
| после тика | `process_days` → события `scouting.*` в уведомления хаба |

Оркестратору: `CareerAdvance.tick` зовёт `CareerScouting.process_days(career, catalog, from,
to)`; подписание игрока должно звать `CareerScouting.forget_player(career, player_id)`
(сейчас `CareerTransferContracts.forget_scouting` чистит только `scout_reports`/`scout_found` —
assignment и `found` в задачах остаются, это надо перевести на `forget_player`).

## 12. Расхождения со скаутингом прототипа (осознанные)

1. **Названия регионов — английские** (`British Isles`, `Southern Europe`, …): подписи в порте
   английские, id/x/y совпадают с прототипом 1:1.
2. **Страны региона** берутся из каталога порта (`TeamCatalog.countries()` отдаёт только
   страны с лигами), поэтому страны без лиг (Faroe Islands, San Marino, Andorra, Gibraltar, …)
   в регион не попадают; в прототипе они были. Игроков там всё равно нет.
3. **`flag`** — имя страны (ключ `UiAssets`), в прототипе — путь `/raster/country_flags/...`.
   `player_photo` — tm id (`int`), в прототипе — путь к лицу.
4. **Карточка игрока в `Entry.player`** — форма `CareerSearch.profile` (`player_id`, без
   `latest_offer`); прототип отдавал свой `scouting_player` с ключом `id`.
5. **`report_for(career, player_id)`** — новый хелпер для экрана трансферов: `{}` либо
   `{player_id, kind: "studying"|"report"|"recommendation", scout_id, scout_name, date,
   acknowledged, duration, days_left}`.
6. **`counts`** дополнен `found` (сколько найдено сетями) и `scouts` (сколько нанято) — для
   бейджей; `new`/`updates`/`total` считаются как в прототипе.
7. **`snapshot`** дополнительно отдаёт плоский `tasks`, `feed` и `found` — прототип складывал
   задачи внутрь скаутов, а фид сортировал уже клиент.
8. **`dismiss`** не возвращает деньги (как в прототипе), но вернувшийся кандидат снова доступен
   для найма по той же цене.
9. **Тик** принимает `from_date`/`to_date` явно и не пишет `career.date` сам — часы двигает
   `CareerAdvance`. Прототип читал `career.date` из сейва.
10. **Тай-брейк кандидатов сети**: SQL прототипа сортирует по `overall DESC, name COLLATE NOCASE`,
    `CareerSearch` добавляет третьим ключом `id`. Совпадения имени и overall почти невозможны,
    но именно здесь теоретически может разойтись порядок перемешивания.
11. **`career.gd` не тронут**: accessor'ы для `scouts`/`scout_*` не добавлены (см. §9.4).


---

# L2: входящие офферы, мировой рынок, действия состава, единый тик

Дата: 2026-11-14. Модули: `career_incoming_offers.gd` (`CareerIncomingOffers`),
`career_world_market.gd` (`CareerWorldMarket`), `career_squad_actions.gd`
(`CareerSquadActions`), `career_advance.gd` (`CareerAdvance`). Источник —
`server/career/{incoming_offers,world_market,squad,actions}.py` и `app.py`
(`load_career`). Всё — `class_name`, `static`, без autoload'ов.

Golden-фикстуры сняты с прототипа (`canon.db`):
```
cd C:\Users\Egor\Desktop\projects\gf-career-prototype
python tmp\oracle_career_l2.py
```
Файлы: `tests/fixtures/career_incoming_offers_golden.json`,
`career_world_market_golden.json`, `career_squad_actions_golden.json`,
`career_advance_tick_golden.json`.
Тесты: `tests/check_career_incoming_offers.gd`,
`check_career_world_market.gd`, `check_career_squad_actions.gd`,
`check_career_advance_tick.gd`.

## 0. Общие правила

- Мутации возвращают `{ok: bool, error: String, <payload>}`; чтения — просто данные.
  `error` — английская строка прототипа (показывать как есть).
- Идентификаторы — строки, суммы — целые евро, даты — ISO `"YYYY-MM-DD"`.
- Все случайные величины идут через `CareerRng`: тот же seed даёт те же суммы,
  даты, клубы и **те же id** (`offer_id`, id мировых переходов), что у прототипа.
- Модули ничего не пишут в файл: хост зовёт `CareerSaveStore.save(career)`.
- Новые ключи сейва (`incoming_offers`, `pending_departures`,
  `incoming_market_date`, `world_market_date`, `world_transfers`, `club_deltas`,
  `negotiations`) — ленивые: старый сейв грузится, геттеры создают ключ при первой
  записи. Версия сейва остаётся 1.

## 1. `CareerIncomingOffers`

```gdscript
static func process_days(career, catalog, from_date, to_date) -> Array   // события
static func generate(career, from_date, to_date, players, clubs, roles,
        club_stats := {}) -> Array                                       // без БД
static func create_offer(career, day, players, clubs, roles, club_stats) -> Dictionary
static func received_rows(career, catalog) -> Array
static func row(career, catalog, offer) -> Dictionary
static func detail(career, catalog, offer_id) -> {ok, error, row}
static func unread_count(career) -> int
static func accept(career, catalog, offer_id) -> {ok, error, row}
static func refuse(career, catalog, offer_id) -> {ok, error, row}
static func counter(career, offer_id, amount, catalog := null) -> {ok, error, row}
static func ack(career, offer_id, catalog := null) -> {ok, error, row}
static func resolve(career) -> Array                                     // события
static func execute_pending_departures(career, catalog, today := "") -> Array
static func find_offer(career, offer_id) -> Dictionary                   // {} если нет
static func find_active(career, player_id, club_id) -> Dictionary
```

### 1.1 `process_days`

Генерация по дням из `(from_date, to_date]`, затем `resolve`. `from_date` пустой →
`career.incoming_market_date`; `to_date` пустой → `career.date`. Маркер
`career.incoming_market_date = to_date` ставится всегда, поэтому повторный тик за
тот же день офферов не добавляет.

Ритм (`incoming_offers.py`): в окне (январь, июль–август) — 1–2 оффера в неделю
(бакеты по 7 дней от начала окна, смотрят 6 дней назад), в последний день окна —
3–5 офферов без дневного лимита; вне окна — 1 оффер в две недели (lookback 13).
Не больше 2 офферов в день (кроме последнего дня окна), 24 попытки на оффер.

### 1.2 Строка (`received_rows`, `detail().row`, `accept/refuse/counter/ack().row`)

```gdscript
{
  "offer_id": String,
  "player": Dictionary,        // CareerSearch.profile (item + profile-поля)
  "club_id": String, "club_name": String, "club_logo": String,
  "kind": "transfer"|"loan", "kind_label": "Transfer"|"Loan",
  "amount": int, "loan_fee": int, "wage_share": int,
  "demand": {"amount": int, "loan_fee": int, "wage_share": int},   // вариативно
  "status": "pending"|"counter"|"accepted"|"refused"|"expired",
  "created_at": String, "expires_at": String, "due": String|null,
  "counter": {"amount": int, "loan_fee": int, "wage_share": int}|null,
  "unread": bool,              // == not acknowledged
  "message": String,           // английская фраза состояния
  "can_accept": bool,          // pending, игрок в составе, в составе > 11
  "can_refuse": bool, "can_counter": bool,
  // доп. поля для модалки оффера:
  "overall": float,
  "club_country_id": String, "club_country_name": String, "club_league_name": String,
  "responded_at": String|null, "counter_offers": int,
  "execute_on": String|null, "executed_at": String|null,
}
```

`received_rows` — только активные (`pending`/`counter`), новейшие сверху (как список
RECEIVED прототипа). Любой статус доступен через `detail` и результат действия.
`unread_count` считает все непрочитанные офферы (бейдж хаба).

### 1.3 Действия

- `accept`: pending → `_complete_accept`. В окне игрок уходит сразу (фикс `fee` на
  баланс, `club_deltas`, история `completed`), вне окна — запись в
  `pending_departures` (`execute_on` = первый день следующего окна, история `agreed`).
  Ошибки: `offer not found`, `this offer cannot be accepted`,
  `player is not in this squad`, `the squad cannot drop below 11 players`.
- `refuse`: pending → `refused`, `acknowledged = true`, `responded_at = career.date`.
  Ошибка `this offer cannot be refused`.
- `counter`: pending, один контр-оффер, сумма строго больше текущей. `due` — через
  2–4 дня (RNG по id оффера). Ошибки: `this offer cannot be countered`,
  `only one counter-offer is allowed`, `counter-offer amount must be positive`,
  `counter-offer must be higher than the current offer`.
- `ack`: снимает бейдж (`acknowledged = true`).
- `execute_pending_departures`: только когда окно открыто (`window_open`); исполняет
  записи с `execute_on <= today`, возвращает события `transfer.departure`.

Ответ клуба на контр-оффер (`resolve`, встроен в `process_days`): если сумма ≤
`demand.amount` и в составе > 11 — принято (игрок уходит сразу / ждёт окна), иначе
отказ. Истёкшие (`career.date >= expires_at`) → `expired`.

### 1.4 События (для уведомлений хаба)

```gdscript
{"type": "transfer.received", "offer_id", "player_id", "club_id", "club_name",
 "kind", "amount", "message"}
{"type": "transfer.incoming.expired"|".accepted"|".refused", "offer_id",
 "player_id", "club_id", "club_name", "status", "message"}
{"type": "transfer.departure", "player_id", "player_name", "club_id", "fee",
 "date", "message"}
```

### 1.5 Журнал и английские сообщения

Журнал: `transfer.received`, `transfer.incoming.accepted`, `.refused`, `.countered`,
`.response`, `transfer.departure`.
Сообщения (`row.message`): `The club is waiting for your answer.`,
`The club is considering the counter-offer.`, `The offer has been accepted.`,
`You refused the offer.`, `The offer has expired.`,
`The club accepted the counter-offer.`, `The club rejected the counter-offer.`,
`The transfer is agreed and will go through on YYYY-MM-DD.`

## 2. `CareerWorldMarket`

```gdscript
static func process_days(career, catalog, from_date, to_date) -> Array   // события
static func run_batch(career, catalog, batch, batch_clubs := 120) -> Array
static func window_bounds(day) -> Array            // [] | [start, end]
static func batch_schedule(window_start, window_end) -> Array
static func batches_between(previous_date, target_date) -> Array
static func club_value(players) -> int
static func club_budget(players) -> int            // 10% стоимости состава
static func role_counts(players) -> Dictionary
static func effective_players(career, club_id, base_players, lookup := Callable()) -> Array
static func current_club_id(career, player_id, fallback := "") -> String
// данные мира (кэш на каталог, один проход по teams и один по players):
static func clubs(catalog) -> Array                 // 4406 клубов
static func squads(catalog) -> Dictionary           // club_id -> Array игроков
static func free_agents(catalog) -> Array           // 2000 по id (строкой)
static func club_role_stats(catalog) -> Dictionary  // как canon.club_role_stats
static func club_market_stats(catalog) -> Dictionary
static func player_by_id(catalog, player_id) -> Dictionary
static func weighted_choice(rng, items, weights)    // random.choices(k=1)
static func apply_delta(career, club_id, player_id, attach)
```

`process_days`: батчи с триггером в `(from, to]` (пустой `from` → берётся
`career.world_market_date`, затем границы окна), затем `career.world_market_date =
to_date`. Окно = 1–31 января и 1 июля–31 августа; четыре батча: opening (день 1),
middle (середина окна), last_week (за 6 дней до конца), last_day (последний день).
`batch_schedule` даёт `{key, name, date, period_start, period_end, window_start,
window_end}`.

Батч: детерминированная выборка ≤120 клубов (сортировка по id + `random.sample`),
0–3 продажи и 0–3 покупки на клуб за окно, состав 18..30, бюджет 10% стоимости
состава, покупка только у другого клуба или свободный агент за 0, `club_deltas`
(`in`/`out`) обновляются сразу — по ним считаются составы в силе/составах
(`effective_players`). `career.world_transfers`: `{id, player_id, player_name,
overall, from_club_id|null, to_club_id, fee, kind: "transfer"|"free_agent", date}`.

События: `{"type": "world.transfer", "player_id", "player_name", "from_club_id",
"to_club_id", "fee", "kind", "date", "message"}`.

Важно: данные мира строятся из `career_search_rows()` (один проход по игрокам) и
**одного прохода по таблице `teams`** — поиндексный выбор команд в `TeamCatalog`
теряет по одному клубу в 14 лигах, из-за чего мировой рынок не совпадал бы с
прототипом. Кэш живёт на каталог (статический), сбрасывается при смене каталога.

## 3. `CareerSquadActions`

```gdscript
static func negotiation_state(career, catalog, player_id) -> Dictionary
static func negotiation_rows(career, catalog) -> Array       // по одному на переговоры
static func unread_count(career) -> int                      // бейдж хаба
static func demand(catalog, career, player) -> Dictionary    // требование игрока
static func start(career, catalog, player_id, terms) -> {ok, error, state}
static func submit(career, catalog, player_id, terms) -> {ok, error, state}   // == start
static func accept_counter(career, catalog, player_id) -> {ok, error, contract, state}
static func ack(career, catalog, player_id) -> {ok, error, state}
static func sign(career, catalog, player_id) -> {ok, error, contract, state}
static func process_due(career, catalog, today := "") -> Array    // события
static func set_shirt_number(career, player_id, number, catalog := null)
        -> {ok, error, player_id, number}
static func shirt_number_rows(career, catalog) -> Array
static func free_shirt_numbers(career, player_id) -> Array
static func release_preview(career, catalog, player_id) -> Dictionary
static func release_player(career, catalog, player_id) -> {ok, error, player_id, player_name}
```

### 3.1 `negotiation_state` (и элементы `negotiation_rows`)

```gdscript
{
  "error": "" | "player is not in this squad",
  "player_id": String, "player_name": String, "overall": float,
  "squad_role": "key"|"first"|"rotation"|"squad"|"prospect",
  "contract": {"years": int, "weekly_wage": int, "release_clause": int},
  "status": "" | "pending" | "counter" | "accepted" | "refused",
  "offer": Dictionary|null, "counter": Dictionary|null,
  "terms": Dictionary|null,          // что показывать в форме: counter, иначе offer
  "due": String|null, "rounds": int, "counter_offers": int,
  "message": String, "acknowledged": bool,
  "unread": bool,                    // status != pending и not acknowledged
  "demand": {years, weekly_wage, squad_role, release_clause},
  "affordable": bool,                // месячный фонд зарплат (4 недели) <= balance
  "can_submit": bool, "can_accept_counter": bool, "can_sign": bool,
}
```

`terms` (условия): `{"years": 1..5, "weekly_wage": 1000..2000000,
"squad_role": <один из пяти>, "release_clause": >= 0}`.

### 3.2 Правила переговоров

- `start`: ошибки `player is not in this squad`,
  `the contract is already agreed, confirm it first`,
  `the player is still thinking about the current offer`,
  `contract length must be between 1 and 5 years`, `weekly wage is out of range`,
  `unknown squad role`, `release clause cannot be negative`.
  `due = career.date + 2..4` дня (RNG `:thinking:<pid>:<rounds>`), игрок отвечает в
  `process_due`.
- Ответ: нет расхождений с `demand` → `accepted`; два контр-оффера уже было →
  `refused`; иначе `counter` (максимум из предложенного и требуемого; клауса
  1.2×…2.0× стоимости). Сообщения: `The player thinks…`, `…agrees. Confirm the
  signing.`, `…walked away…`, `The player asks for a higher wage.` и т.д.
- `accept_counter` / `sign`: месячный фонд (сумма зарплат состава × 4) должен
  помещаться в баланс. Ошибки: `there is no counter-offer to accept`,
  `not enough money to accept these terms`, `the contract is not agreed yet`,
  `not enough money to sign this contract`.
- `ack`: ошибки `there is no negotiation for this player`,
  `the player is still thinking about the current offer`.
- Журнал: `contract.negotiation`, `contract.negotiation.acknowledged`,
  `contract.signed` (`{player_id, contract}`).

События `process_due`: `{"type": "contract.negotiation.counter"|".accepted"|
".refused", "player_id", "player_name", "status", "message", "counter"}`.

### 3.3 Номер и освобождение

- `set_shirt_number`: `catalog` нужен только чтобы досоздать номера старого сейва
  (`career_shirt_numbers` пуст); ошибки `player is not in this squad`,
  `shirt number is required`, `shirt number must be between 1 and 99`,
  `shirt number is already taken`. Журнал `player.shirt_number`.
- `shirt_number_rows` — `{player_id, player_name, overall, number}`, отсортировано по
  номеру (без номера — в конце). `free_shirt_numbers` — 1..99 минус номера других
  игроков состава (правило клиента прототипа; для карусели номера).
- `release_preview` — `{player_id, player_name, overall, market_value, weekly_wage,
  years, squad_size, can_release, reason}`; `reason` =
  `""` / `player is not in this squad` / `the squad cannot drop below 11 players`.
- `release_player`: та же проверка 11, игрок вычищается из `player_ids`, линии,
  скамейки, контрактов, стоимостей, возрастов, номеров, статусов, переговоров,
  ролей и `club_deltas`; журнал `player.released`.

## 4. `CareerAdvance`

```gdscript
static func tick(career, catalog, today := "") -> {events: Array, changed: bool}
```

Один датированный шаг; порядок: входящие (`process_days`) → мировой рынок
(`process_days`) → `CareerTransferOffers.process_due` →
`CareerTransferContracts.process_due` → `execute_pending` →
`CareerSquadActions.process_due` → `execute_pending_departures` → скаутинг
(`career_scouting.gd` грузится по пути; если файла нет или в нём нет
`process_days`, шаг пропускается).

- `today` пишется в `career.date` (тик и есть шаг календаря), пустой → `career.date`.
- Идемпотентность — на маркерах `incoming_market_date`/`world_market_date` и на
  `due`/`execute_on`: второй тик за тот же день даёт `events: []`, `changed: false`.
- `events` — плоские словари для уведомлений хаба: у каждого есть `type` и
  `message` (английский); остальные ключи — id/имена из шага.
- `changed` — грубый слепок (размеры списков + баланс + размер состава), чтобы хост
  решал, надо ли сохранять и перестраивать экран.

## 5. Что зовёт каждый экран

| Экран / view | Вызовы |
|---|---|
| `hub` (бейджи) | `CareerIncomingOffers.unread_count`, `CareerSquadActions.unread_count`, `CareerTransfers.sent_offer_rows` |
| `centre` → RECEIVED | `CareerIncomingOffers.received_rows`; открытие оффера → `detail` |
| offers modal | `accept` / `refuse` / `counter` / `ack` → `row` |
| SQUAD → player → CONTRACT TALKS | `CareerSquadActions.negotiation_state`, `demand`, `start`/`submit`, `accept_counter`, `ack`, `sign` |
| SQUAD → player → SHIRT NUMBER | `shirt_number_rows`, `free_shirt_numbers`, `set_shirt_number` |
| SQUAD → player → RELEASE | `release_preview`, `release_player` |
| после advance/play/open | `CareerAdvance.tick(career, catalog)`; `events` → уведомления, `changed` → сохранить и перестроить |

## 6. Фикстуры и расхождения

- Фикстуры сняты на клубе `131`, seed 42, `created_at = 2026-07-01T00:00:00Z`.
  Входящие: неделя окна (1 оффер), вторая неделя (+1), вне окна (1 за две недели),
  accept внутри/вне окна, контр-оффер (3 дня → принят), отказ, дедлайн-берст,
  истечение 30 дней. Мировой рынок: окно 2026-07-01..08-31 целиком (505 переходов,
  первые 40 + хвост + `club_deltas`). Действия: требование, три раунда (2 контр-оффера
  → отказ), принятие по требованию + подпись, принятие контр-оффера, номер, релиз,
  фонд зарплат. Тик: неделя окна, повтор, следующее окно (+140 переходов).
- **`received_rows` отдаёт только активные офферы** (как список RECEIVED прототипа);
  остальные статусы — через `detail`/результат действия. Сам прототип в снапшоте
  тоже фильтрует `pending`; здесь добавлен `counter`, чтобы оффер не исчезал, пока
  клуб думает.
- **`counter(career, offer_id, amount, catalog := null)`**: `catalog` — необязательный
  последний аргумент, только чтобы собрать `row` с блоком `player`.
- **`CareerAdvance.tick` двигает `career.date`** (тик — шаг календаря). Маркер
  скаутинга не заводится: модуль скаутинга сам идемпотентен по `last_tick`.
- **События `transfer.*` и `world.transfer`** — расширение порта (у прототипа их нет),
  чтобы хаб показывал уведомления без второго запроса.
- **Список клубов мирового рынка** строится проходом по `teams`, а не через
  `TeamCatalog` поиндексно: тот теряет по одному клубу в 14 лигах (пре-существующее
  поведение выбора команд, не трогалось).
- **`negotiations`** — новый геттер `Career.negotiations` (+ нормализация в
  `from_save`: условия обратно в int, лишние ключи не добавляются).
