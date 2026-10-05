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

База ядра Health24 (моделі `H24Core::*` у `app/models_readonly`) — це БД `system_ruby`, лише на читання.
Адреси — `H24_CORE_*_DB_URL` у `mise.toml`; локальні значення перевизначай у `mise.local.toml`.

## Перевірки перед комітом

```bash
mise run test
bundle exec rubocop
mise run typecheck
```

## Типи (RBS + Steep)

Типізуємо й перевіряємо лише **власний код**: `app/services`, `app/service_objects`, `app/value_objects`,
`app/validators`, `lib` (перелік — у `Steepfile`). Моделі, concern-и, контролери та решта Rails-коду не
описуються в RBS і Steep-ом не перевіряються.

- **Власний код** — рукописний `.rbs` у `sig/` за шляхом файлу:
  `app/services/<namespace>/<name>.rb` → `sig/app/services/<namespace>/<name>.rbs`.
  Новий метод чи константа — у сигнатуру в тому самому коміті.
- **Моделі й роути** — сигнатури генерує rbs_rails у заігнорену теку `.rbs_rails/`, у git вони не потрапляють.
  `mise run typecheck` перегенеровує їх сам, окремо — `mise run rbs`. Генерація читає колонки з БД, тож потрібні
  накочена dev-база і доступна база ядра.
- **Методи й константи моделей**, які викликає власний код, — мінімальний `.rbs` у `sig/app/models/...`, лише з тим,
  що реально використовується.
- **Гем без сигнатур**, який викликає власний код, — шим у `sig/shims/<gem>.rbs`. Після зміни `Gemfile` запусти
  `mise run rbs`, щоб оновився `rbs_collection.lock.yaml`.
