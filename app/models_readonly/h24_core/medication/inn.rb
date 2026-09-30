# frozen_string_literal: true

class H24Core::Medication::Inn < H24Core::ApplicationRecord
  include H24Core::HstoreTranslated

  self.table_name = 'medication_inns'

  # The dictionary keeps case variants of one name; the eHealth-backed row wins.
  scope :by_original, lambda { |name|
    where('lower(title_original) = ?', name.to_s.downcase.strip).order(in_ehealth: :desc, id: :asc)
  }

  hstore_translated :title, :title_translations
end

# == Schema Information
#
# Table name: medication_inns
#
#  id                 :integer          not null, primary key
#  in_ehealth         :boolean          default(FALSE)
#  title_original     :string
#  title_translations :hstore
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  ehealth_api_id     :string
#
# Indexes
#
#  idx_medication_inns_title_tr_en  (lower((title_translations -> 'en'::text)))
#  idx_medication_inns_title_tr_ru  (lower((title_translations -> 'ru'::text)))
#  idx_medication_inns_title_tr_uk  (lower((title_translations -> 'uk'::text)))
#
