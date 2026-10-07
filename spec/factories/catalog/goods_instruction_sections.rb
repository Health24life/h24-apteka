# frozen_string_literal: true

FactoryBot.define do
  factory :catalog_goods_instruction_section, class: 'Catalog::GoodsInstructionSection' do
    goods { association :catalog_goods }
    sequence(:position) { it }
    code { 'pokazannia' }
    sequence(:anchor) { "pokazannia-#{it}" }
    source_title { 'Показання' }
    body_html_uk { '<p>Біль.</p>' }
  end
end

# == Schema Information
#
# Table name: catalog_goods_instruction_sections
#
#  id           :bigint           not null, primary key
#  anchor       :string           not null
#  code         :string           not null
#  position     :integer          not null
#  source_title :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  goods_id     :bigint           not null
#
# Indexes
#
#  index_catalog_instruction_sections_on_goods_and_anchor    (goods_id,anchor) UNIQUE
#  index_catalog_instruction_sections_on_goods_and_position  (goods_id,position) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (goods_id => catalog_goods.id)
#
# Check Constraints
#
#  catalog_goods_instruction_sections_anchor_check    (anchor::text ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text)
#  catalog_goods_instruction_sections_position_check  ("position" >= 1)
#
