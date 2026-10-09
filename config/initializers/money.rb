# frozen_string_literal: true

Money.locale_backend = :currency

MoneyRails.configure do |config|
  config.default_currency = :uah
  config.rounding_mode = BigDecimal::ROUND_HALF_UP
end
