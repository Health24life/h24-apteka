# frozen_string_literal: true

module Catalog
  SLUG_FORMAT = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/
  SLUG_MAX_LENGTH = 100

  def self.table_name_prefix
    'catalog_'
  end
end
