# frozen_string_literal: true

ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.uncountable 'goods'
  # Uncountable rules match whole words, and the underscore joins a table name into one word.
  inflect.uncountable 'catalog_goods'
end
