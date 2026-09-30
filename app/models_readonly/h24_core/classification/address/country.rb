# frozen_string_literal: true

class H24Core::Classification::Address::Country < H24Core::ApplicationRecord
  include H24Core::HstoreTranslated

  self.table_name = 'countries'

  hstore_translated :title, :title_translations
end

# == Schema Information
#
# Table name: countries
#
#  id                 :bigint           not null, primary key
#  code               :string
#  title_translations :hstore
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
