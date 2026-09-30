# frozen_string_literal: true

class H24Core::ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  connects_to database: { writing: :h24_core, reading: :h24_core }
end
