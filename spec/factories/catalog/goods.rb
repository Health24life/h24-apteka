# frozen_string_literal: true

FactoryBot.define do
  factory :catalog_goods, class: 'Catalog::Goods' do
    goods_group { association :catalog_goods_group }
    sequence(:name_uk) { |n| "Препарат #{n}" }
  end
end

# == Schema Information
#
# Table name: catalog_goods
#
#  id                                    :bigint           not null, primary key
#  composition                           :text
#  dosage                                :string
#  hidden                                :boolean          default(FALSE), not null
#  image_paths                           :jsonb            not null
#  in_medication_program                 :boolean          default(FALSE), not null
#  instruction_html                      :text
#  is_recipe                             :boolean          default(FALSE), not null
#  is_strict_recipe                      :boolean          default(FALSE), not null
#  mnn                                   :string
#  morion_code                           :string
#  pack_quantity_in_pack                 :integer
#  pack_quantity_in_unit                 :integer
#  pack_quantity_unit_in_pack            :integer
#  pack_unit_name                        :string
#  release_form                          :string
#  slug                                  :string           not null
#  withdrawn                             :boolean          default(FALSE), not null
#  created_at                            :datetime         not null
#  updated_at                            :datetime         not null
#  adult_restriction_id                  :bigint
#  child_restriction_id                  :bigint
#  core_inn_id                           :integer
#  diabetic_restriction_id               :bigint
#  driver_restriction_id                 :bigint
#  form_id                               :bigint
#  goods_group_id                        :bigint           not null
#  measure_id                            :bigint
#  pregnant_and_lactating_restriction_id :bigint
#  price_group_id                        :bigint
#  temperature_mode_id                   :bigint
#
# Indexes
#
#  index_catalog_goods_on_goods_group_id  (goods_group_id)
#  index_catalog_goods_on_slug            (slug) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (adult_restriction_id => catalog_goods_restrictions.id)
#  fk_rails_...  (child_restriction_id => catalog_goods_restrictions.id)
#  fk_rails_...  (diabetic_restriction_id => catalog_goods_restrictions.id)
#  fk_rails_...  (driver_restriction_id => catalog_goods_restrictions.id)
#  fk_rails_...  (form_id => catalog_goods_forms.id)
#  fk_rails_...  (goods_group_id => catalog_goods_groups.id)
#  fk_rails_...  (measure_id => catalog_goods_measures.id)
#  fk_rails_...  (pregnant_and_lactating_restriction_id => catalog_goods_restrictions.id)
#  fk_rails_...  (price_group_id => catalog_goods_price_groups.id)
#  fk_rails_...  (temperature_mode_id => catalog_goods_temperature_modes.id)
#
# Check Constraints
#
#  catalog_goods_image_paths_check   (jsonb_typeof(image_paths) = 'array'::text)
#  catalog_goods_in_pack_check       (pack_quantity_in_pack IS NULL OR pack_quantity_in_pack >= 0)
#  catalog_goods_in_unit_check       (pack_quantity_in_unit IS NULL OR pack_quantity_in_unit >= 0)
#  catalog_goods_slug_check          (slug::text ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text AND length(slug::text) <= 100)
#  catalog_goods_unit_in_pack_check  (pack_quantity_unit_in_pack IS NULL OR pack_quantity_unit_in_pack >= 0)
#
