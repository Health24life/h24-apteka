# Orders::Bookings — бронювання кошика

Бронь — це той самий запис `orders`, що й кошик, з тим самим `token`: бронювання переводить кошик зі стану `cart` у
`submitted` (або `submission_failed`). Оплати на сайті немає: самовивіз, оплата в аптеці. Модель відправленого
замовлення — `Order` з даними клієнта, згодою, власним номером, станом партнера й знімком.

## Ендпоінт

`POST /api/v1/orders/:order_token/booking` (`Api::V1::Orders::BookingsController`):

```json
{ "goods": [ { "goods_id": 812, "quantity": 2, "price": "162.50" } ],
  "customer": { "first_name": "Олена", "phone_number": "+380 67 123 45 67", "email": "…" },
  "personal_data_consent": true,
  "register_account": true,
  "cf-turnstile-response": "…" }
```

- `goods` — усі товари кошика з цінами, які бачив користувач; інший склад — `409 cart_changed`.
- Згода перевіряється сервером (`422 personal_data_consent_required`); телефон нормалізується до `380XXXXXXXXX`.
- `register_account` лише зберігається; акаунт не створюється.
- Той самий виклик повторює бронь у стані `submission_failed`; передана — `409 order_already_submitted`.

## Потік

```
Turnstile ─► Request.from ─► Find (token + OrderPolicy; cart | submission_failed) ─► пілотна аптека ─► склад = кошик
   ─► перепідтвердження: Orders::Offers in_drugstore без частки ліміту (Failure → 503 booking_check_*)
   ─► дані клієнта, момент першої згоди
   ─► вже має own_number? ─► звірка: Pharmapoint::Bookings#find_submitted ─► знайдено → submitted
   ─► PriceCheck: зросла ціна чи бракує → 409 booking_prices_changed з оновленими позиціями
   ─► own_number, save! (ще кошик) ─► Snapshot ─► store-pick-up-order
   ─► submitted + стан партнера   або   submission_failed → 502 booking_submission_failed
```

- **Звірка повтору — евристика.** Історія партнера не повертає наш `online_drugstore_order_number`, тож збігом
  вважається замовлення клієнта (за `Customer-Phone`) у тій самій аптеці, створене не раніше за першу згоду (з допуском
  на годинник), з тим самим складом і кількостями. Чи шукає `search` історії за нашим номером — відкрите питання до
  Pharmapoint.
- **Без явної транзакції.** Дані клієнта й власний номер зберігаються до звернення; знімок і стан — після нього, спершу
  замовлення, потім позиції. Збій посередині лишає кошик з власним номером, і наступний виклик іде через звірку.
- **Знімок** (`Snapshot`): назва, адреса й телефон аптеки; у позиціях — назва, виробник, форма, ідентифікатор товару в
  провайдера, ціна з живої перевірки й сума; доставка `pick_up`, оплата `cash_in_store`.
- **Пілот:** `APTEKA_BOOKING_DRUGSTORE_IDS` — ідентифікатори аптек довідника; порожнє значення вимикає бронювання. Аптека
  в списку аптек і в кошику має `booking_available`.
- **Turnstile** — гем `rails_cloudflare_turnstile`, як у `system_ruby`: поле `cf-turnstile-response`, ключі
  `CF_TURNSTILE_SITE_KEY` / `CF_TURNSTILE_SECRET_KEY`. Без ключів перевірка вимкнена: у dev і тестах проходить токен
  `mocked`, у production бронь відхиляється (`403 turnstile_failed`).

## Статуси й показ броні

- **Опитування:** вебхуків у партнера немає. `Orders::Bookings::StatusPollWorker` (cron `APTEKA_BOOKING_STATUS_POLL_CRON`,
  за замовчуванням кожні 10 хв; порожнє значення вимикає) ставить `StatusRefreshWorker` на кожну передану бронь, чий
  статус не фінальний (`APTEKA_BOOKING_FINAL_STATUSES`, `canceled`) і яку забронювали не раніше
  `APTEKA_BOOKING_STATUS_POLL_DAYS` днів (3). Задача — короткий `with_lock` рядка й `GET order/:order_number`; ліміт —
  перенесення на `Retry-After`. Збій лишає збережений статус.
- **`GET /api/v1/orders/:token`** віддає кошик, поки той не заброньований, а потім бронь (`Orders::Bookings::Open.owned`).
  Токен один, і він же — посилання, яким бронь шарять, щоб її забрала інша людина: відправлену бронь бачить будь-хто з
  токеном, а дані клієнта (ім'я, телефон, email) — лише користувач із сесією акаунта броні (`OrderPolicy#personal_data?`);
  гостю й тому, хто відкрив посилання, вони не віддаються. Статус, старший за `APTEKA_BOOKING_STATUS_STALE_MINUTES` (5),
  спершу оновлюється від партнера; партнер не відповів — показується збережений із `status.updated_at`.

## Скасування

`DELETE /api/v1/orders/:token` для броні (`Orders::Bookings::Cancel`; для кошика — очищення, як і раніше). Лише
користувач із сесією акаунта броні (`OrderPolicy#cancel?`): токен — це й посилання «Поділитися», тож самого токена
замало (`403 cancellation_needs_account`). Скасувати можна передану бронь із нефінальним статусом
(`409 order_not_cancellable`). Причина — необов'язкова, в тілі (`reason`, до 255 символів); без неї партнер отримує
«Скасовано клієнтом». `POST order/cancel` з `Customer-Phone`; відповідь партнера не задокументована, тож після неї статус
перечитується. Відмова партнера — `409 cancellation_refused`, недоступність — `503 cancellation_unavailable` /
`cancellation_busy`. Бронь лишається записом зі статусом партнера (`200`).

## Історія

`GET /api/v1/orders` (`Orders::Bookings::History`, `HistoryBlueprint`) — лише із сесією (`401` гостю): броні акаунта в
`submitted` і `submission_failed`, від нових до старих за моментом першої згоди, `page` / `per_page`
(`APTEKA_ORDERS_PER_PAGE` 20, `APTEKA_ORDERS_MAX_PER_PAGE` 50), `has_more` без `COUNT`. Партнера не питає. Рендер
relation з `preload:` позицій; індекс `index_orders_on_user_id_booked` — `(user_id, personal_data_consent_at)` поза кошиком.

## Тести

- Сервіси — `spec/services/orders/bookings/*` з фейковими адаптерами (`stub_offers_adapter`, `stub_bookings_adapter`);
  адаптер і читач — `spec/services/pharmapoint/bookings_spec.rb`, `…/readers/partner_orders_spec.rb`.
- Ендпоінти — rswag-спеки `spec/requests/api/v1/orders/booking_spec.rb`, `spec/requests/api/v1/orders_spec.rb` (історія,
  показ броні); після зміни — `mise run rswag`. Задачі —
  `spec/workers/orders/bookings/*`.
- Фікстури `partner_order_created.json`, `partner_order.json`, `partner_order_history.json` — з публічної колекції
  партнера, знеособлені; наживо не звірені.
