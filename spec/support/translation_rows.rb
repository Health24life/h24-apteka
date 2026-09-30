# frozen_string_literal: true

module TranslationRows
  def insert_translation_row(record, locale:)
    model = record.class
    ActiveRecord::Base.connection.execute(<<~SQL.squish)
      INSERT INTO #{model.translation_class.table_name}
        (#{model.translation_options[:foreign_key]}, locale, name, created_at, updated_at)
      VALUES (#{record.id}, '#{locale}', 'Назва', now(), now())
    SQL
  end
end
