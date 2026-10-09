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

### Git-хуки (overcommit)

Перед кожним комітом хуки запускають RuboCop на змінених Ruby-файлах і Steep на всьому проєкті. Налаштування — у
`.overcommit.yml`, хук Steep — у `.git-hooks/pre_commit/steep.rb`. Команди йдуть через `mise exec`, тож хук знаходить
потрібний Ruby, навіть коли git запущено з IDE.

```bash
mise run hooks   # один раз після клону, і ще раз після зміни .overcommit.yml чи хуків
```

- Steep читає згенеровані сигнатури моделей з `.rbs_rails/`. Якщо її ще немає (свіжий клон), хук лише попереджає:
  згенеруй її командою `mise run rbs`.
- Пропустити хуки одноразово: `OVERCOMMIT_DISABLE=1 git commit …`. Це виняток, а не звичка.

## Типи (RBS + Steep)

Steep перевіряє власний код і моделі: `app/models`, `app/models_readonly`, `app/lib`, `app/services`,
`app/service_objects`, `app/value_objects`, `app/validators`, `lib` (перелік — у `Steepfile`). Контролери й політики
Steep-ом не перевіряються.

- **Згенероване для моделей і роутів** — сигнатури (атрибути, асоціації, скоупи, `enum`) генерує rbs_rails у заігнорену
  теку `.rbs_rails/`, у git вони не потрапляють. `mise run typecheck` перегенеровує їх сам, окремо — `mise run rbs`.
  Генерація читає колонки з БД, тож потрібні накочена dev-база і доступна база ядра.
- **Написане руками в моделях** — `.rbs` у `sig/app/models/...` за шляхом файлу (для `models_readonly` — у
  `sig/app/models_readonly/...`): константи, власні методи, `include` concern-ів і `extend` їхніх `ClassMethods`.
- **Concern-и** — окремий `.rbs`: тип `self`, інтерфейс того, чого concern потребує від моделі, `ClassMethods` і блок
  `included`. Спільні шими для Rails — `sig/shims/active_record.rbs`.
- **Власний код** — рукописний `.rbs` у `sig/` за шляхом файлу:
  `app/services/<namespace>/<name>.rb` → `sig/app/services/<namespace>/<name>.rbs`.
  Новий метод чи константа — у сигнатуру в тому самому коміті.
- **Гем без сигнатур** — шим у `sig/shims/<gem>.rbs`. Після зміни `Gemfile` запусти `mise run rbs`, щоб оновився
  `rbs_collection.lock.yaml`.
