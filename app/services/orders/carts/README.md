# Orders::Carts — API кошика

Кошик «Аптеки» для вебу й застосунку. Кошик — це замовлення в стані `cart`, прив'язане з першим товаром до однієї
аптеки й провайдера (модель — `Order`, `Order::Item`). Ціна й наявність **ніколи не зберігаються**: кожен показ і кожна
зміна питають провайдера наживо через `Orders::Offers::Adapters` (для Pharmapoint — `Pharmapoint::Offers`,
`order/get-drugstore-for-order-goods`). Аптеку для першого товару фронт бере зі списку `POST /api/v1/goods/:id/drugstores`
(`Orders::Offers::Nearby`).

## Ендпоінти

Кошик — це замовлення в стані `cart`, тож маршрути — ресурс `orders`. Власник доходить до кошика за `token` у шляху;
кошик акаунта відкривається лише із сесією його користувача. `share_token` — для посилання, за яким будь-хто лише
дивиться.

| Запит | Що робить |
|---|---|
| `POST /api/v1/orders` | Перший товар: `goods_id`, `drugstore_id`, `quantity`; створює кошик (`201`, `token` і `share_token`). Користувач, у якого кошик уже є, кладе товар у нього (`200`) |
| `GET /api/v1/orders/current` | Кошик користувача з сесією — звідси він бере `token` |
| `GET /api/v1/orders/:token` | Кошик з живими цінами; провайдер не відповів — `200` без цін, `prices_available: false` |
| `DELETE /api/v1/orders/:token` | `204`, кошик видалено з позиціями |
| `POST /api/v1/orders/:order_token/items` | Товар у кошик, лише для його аптеки |
| `PATCH /api/v1/orders/:order_token/items/:id` | Нова кількість, перевірена наживо |
| `DELETE /api/v1/orders/:order_token/items/:id` | `204`; кошик іде разом з останньою позицією |
| `GET /api/v1/shared/orders/:share_token` | Кошик за посиланням: аптека, позиції, живі ціни, без `token` |

## Потік

```
CartActions (owner: token зі шляху + сесія)
   │
   ▼
Find ── за токеном: гостьовий — будь-кому з токеном, акаунта — лише з сесією його користувача; без токена — кошик
   │    користувача. Сесія відкриває гостьовий кошик, а в акаунта кошика немає → гостьовий переходить в акаунт
   │
   ▼
Opening / Tidy ── вимкнений провайдер чи прихована аптека → кошик видалено, 404 cart_not_found + reason;
   │              прихований чи знятий SKU (або група) → позицію видалено, у відповіді в `removed`
   ▼
Show ── in_drugstore про всі позиції → View (ItemView: available, price, total)
AddItem / ChangeQuantity ── зміна в пам'яті → Check (in_drugstore про весь кошик зі зміною) → save! → View
```

- **Перевірка** (`Check`) вирішує лише за SKU, що додається чи змінюється: непокритий — `goods_not_in_drugstore`,
  більше за залишок — `quantity_exceeds_stock` з `details.available_quantity`. Немає даних (`order: null`) чи збій —
  `503 cart_check_unavailable`; ліміт — `503 cart_check_busy` + `Retry-After`. Нічого не зберігається, доки перевірка не
  пройшла; відповідь перевірки йде в показ кошика після зміни, тож провайдера питають один раз.
- **Позиція, якої зараз немає**, з кошика не видаляється: `available: false`, без ціни й без внеску в `total`.
- **Кількість** — лише цілі упаковки (`invalid_quantity` ще до звернення до провайдера).
- **Помилки** — `Orders::Carts::Refused` (код, статус, деталі, `retry_after`), які `CartActions` перетворює на відповідь.

## Покинуті кошики

`Orders::Carts::AbandonedCleanupWorker` (cron `ORDERS_CART_CLEANUP_CRON`, за замовчуванням `40 4 * * *`; порожнє значення
вимикає) видаляє гостьові кошики без змін довше за `APTEKA_GUEST_CART_TTL_DAYS` днів (7). Кошики акаунтів і відправлені
замовлення не чіпає. Час зміни кошика оновлюють позиції (`touch: true`).

## Тести

- Сервіси — `spec/services/orders/carts/*` з фейковим адаптером (`stub_offers_adapter`, `offer_for`);
- ендпоінти — rswag-спеки `spec/requests/api/v1/orders_spec.rb`, `spec/requests/api/v1/orders/items_spec.rb` і
  `spec/requests/api/v1/shared/orders_spec.rb` на заглушці
  Pharmapoint (`stub_drugstore_offers`); після зміни — `mise run rswag`.
