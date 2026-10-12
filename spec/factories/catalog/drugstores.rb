# frozen_string_literal: true

FactoryBot.define do
  factory :catalog_drugstore, class: 'Catalog::Drugstore' do
    drugstore_legal_entity_name { 'ТОВ «Аптека»' }
    drugstore_legal_entity_code { '01234567' }
    week_working_hours { [ '08:00-21:00' ] * 7 }
  end
end

# == Schema Information
#
# Table name: catalog_drugstores
#
#  id                          :bigint           not null, primary key
#  drugstore_legal_entity_code :string           not null
#  drugstore_legal_entity_name :string           not null
#  email                       :string
#  hidden                      :boolean          default(FALSE), not null
#  incomplete                  :boolean          default(FALSE), not null
#  mobile_phone                :string
#  name                        :string
#  phone                       :string
#  week_working_hours          :jsonb            not null
#  withdrawn                   :boolean          default(FALSE), not null
#  work_with_reimbursement     :boolean          default(FALSE), not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  brand_id                    :bigint
#  ext_drugstore_id            :string
#
# Indexes
#
#  index_catalog_drugstores_on_brand_id  (brand_id)
#
# Foreign Keys
#
#  fk_rails_...  (brand_id => catalog_drugstore_brands.id)
#
# Check Constraints
#
#  catalog_drugstores_legal_entity_code_check  (drugstore_legal_entity_code::text ~ '^[0-9]{8}([0-9]{2})?$'::text)
#  catalog_drugstores_week_hours_check         (jsonb_array_length(week_working_hours) = ANY (ARRAY[0, 7]))
#
