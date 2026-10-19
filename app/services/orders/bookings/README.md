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

## Тести

- Сервіси — `spec/services/orders/bookings/*` з фейковими адаптерами (`stub_offers_adapter`, `stub_bookings_adapter`);
  адаптер і читач — `spec/services/pharmapoint/bookings_spec.rb`, `…/readers/partner_orders_spec.rb`.
- Ендпоінт — rswag-спека `spec/requests/api/v1/orders/booking_spec.rb`; після зміни — `mise run rswag`.
- Фікстури `partner_order_created.json`, `partner_order.json`, `partner_order_history.json` — з публічної колекції
  партнера, знеособлені; наживо не звірені.
