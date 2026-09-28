# h24-apteka

Бекенд розділу «Аптека» продукту Health24 (h24.ua). Публічний каталог і бронювання
товарів через партнерське API Pharmapoint.ua — без власної аптечної ліцензії, без
прийому оплати на сайті, без власної доставки.

## Документація

- `docs/sources/` — BRD, SRS/FSD, беклог бекенду.
- `docs/research/` — ER-діаграми, дослідницькі нотатки.
- `CLAUDE.md` — конвенції репозиторію (еталон: `../system_ruby`).

## Стек

Ruby 4.0.7, Rails ~> 8.1.4, PostgreSQL, Redis, RSpec.

## Порти (нестандартні, послідовні — `mise.toml`)

| Сервіс | Порт |
|---|---|
| Rails-застосунок | `2500` |
| PostgreSQL (Docker) | `2501` |
| Redis (Docker) | `2502` |

## Запуск

```bash
mise install
bundle install
mise run docker-up   # піднімає PostgreSQL (2501) і Redis (2502)
bin/rails db:create db:migrate
mise run server       # http://localhost:2500
```

## Тести

```bash
mise run test
```
